import Foundation
import SQLite3

public enum SnapshotStoreError: Error, Equatable {
    case invalidScope
    case duplicateTask
    case unsupportedSchema(Int)
    case sqlite(String)
}

/// Actor-confined SQLite snapshot cache. Contains task summaries/events, never credentials.
/// A successful complete-scope import atomically replaces the scope and appends events.
/// Partial pages and provider failures must never call applyCompleteSnapshot.
public actor SQLiteSnapshotStore {
    private let db: OpaquePointer
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var opened: OpaquePointer?
        let result = sqlite3_open_v2(
            databaseURL.path, &opened,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, let opened else {
            let reason = opened.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let opened { sqlite3_close(opened) }
            throw SnapshotStoreError.sqlite(reason)
        }
        self.db = opened
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .millisecondsSince1970
        self.decoder.dateDecodingStrategy = .millisecondsSince1970

        do {
            sqlite3_busy_timeout(opened, 3000)
            try Self.execute(opened, "PRAGMA journal_mode=WAL;")
            try Self.execute(opened, "PRAGMA foreign_keys=ON;")
            let version = try Self.schemaVersion(opened)
            guard version <= 1 else { throw SnapshotStoreError.unsupportedSchema(version) }
            if version == 0 {
                try Self.execute(opened, """
                    CREATE TABLE IF NOT EXISTS scopes (
                        scope_key TEXT PRIMARY KEY NOT NULL,
                        provider_id TEXT NOT NULL,
                        account_id TEXT NOT NULL,
                        sequence INTEGER NOT NULL,
                        last_synced REAL NOT NULL
                    );
                    CREATE TABLE IF NOT EXISTS tasks (
                        scope_key TEXT NOT NULL,
                        task_key TEXT NOT NULL,
                        payload TEXT NOT NULL,
                        PRIMARY KEY (scope_key, task_key),
                        FOREIGN KEY (scope_key) REFERENCES scopes(scope_key) ON DELETE CASCADE
                    );
                    CREATE TABLE IF NOT EXISTS events (
                        scope_key TEXT NOT NULL,
                        event_key TEXT NOT NULL,
                        detected_at REAL NOT NULL,
                        payload TEXT NOT NULL,
                        PRIMARY KEY (scope_key, event_key),
                        FOREIGN KEY (scope_key) REFERENCES scopes(scope_key) ON DELETE CASCADE
                    );
                    CREATE INDEX IF NOT EXISTS idx_events_time ON events(detected_at DESC);
                    PRAGMA user_version = 1;
                """)
            }
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: databaseURL.path)
        } catch {
            sqlite3_close(opened)
            throw error
        }
    }

    deinit {
        sqlite3_close(db)
    }

    public static func defaultDatabaseURL() throws -> URL {
        let library = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return library.appendingPathComponent("OVTasks", isDirectory: true)
            .appendingPathComponent("snapshots.sqlite", isDirectory: false)
    }

    /// COMPLETE paginated source result, not a partial API page.
    /// First import is a baseline and produces zero events.
    @discardableResult
    public func applyCompleteSnapshot(
        scope: WatchedScope,
        tasks: [TaskSummary],
        detectedAt: Date
    ) throws -> [ChangeEvent] {
        guard !scope.providerID.isEmpty, !scope.accountID.isEmpty, !scope.scopeID.isEmpty,
              tasks.allSatisfy({ $0.scope == scope && !$0.identity.taskID.isEmpty }) else {
            throw SnapshotStoreError.invalidScope
        }

        var seen = Set<TaskIdentity>()
        for task in tasks {
            guard seen.insert(task.identity).inserted else { throw SnapshotStoreError.duplicateTask }
        }

        let previous = try snapshot(for: scope)
        let sequence = (try scopeSequence(for: scope) ?? 0) + 1
        let changes = SnapshotDiffer.changes(
            previous: previous, current: tasks,
            detectedAt: detectedAt, syncSequence: sequence
        )
        let scopeKey = scope.storageKey

        try Self.execute(db, "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try statement("""
                INSERT INTO scopes (scope_key, provider_id, account_id, sequence, last_synced)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(scope_key) DO UPDATE SET
                  sequence=excluded.sequence, last_synced=excluded.last_synced;
                """) { stmt in
                try bind(scopeKey, to: stmt, index: 1)
                try bind(scope.providerID, to: stmt, index: 2)
                try bind(scope.accountID, to: stmt, index: 3)
                sqlite3_bind_int64(stmt, 4, Int64(sequence))
                sqlite3_bind_double(stmt, 5, detectedAt.timeIntervalSince1970)
                try stepDone(stmt)
            }
            try statement("DELETE FROM tasks WHERE scope_key = ?;") { stmt in
                try bind(scopeKey, to: stmt, index: 1)
                try stepDone(stmt)
            }
            for task in tasks {
                let json = try encode(task)
                try statement("INSERT INTO tasks(scope_key, task_key, payload) VALUES (?, ?, ?);") { stmt in
                    try bind(scopeKey, to: stmt, index: 1)
                    try bind(task.identity.storageKey, to: stmt, index: 2)
                    try bind(json, to: stmt, index: 3)
                    try stepDone(stmt)
                }
            }
            for event in changes {
                let json = try encode(event)
                try statement("""
                    INSERT OR IGNORE INTO events(scope_key, event_key, detected_at, payload)
                    VALUES (?, ?, ?, ?);
                    """) { stmt in
                    try bind(scopeKey, to: stmt, index: 1)
                    try bind(event.id, to: stmt, index: 2)
                    sqlite3_bind_double(stmt, 3, event.detectedAt.timeIntervalSince1970)
                    try bind(json, to: stmt, index: 4)
                    try stepDone(stmt)
                }
            }
            try Self.execute(db, "COMMIT;")
            return changes
        } catch {
            try? Self.execute(db, "ROLLBACK;")
            throw error
        }
    }

    /// nil means the scope has never successfully synced; [] means a successful empty snapshot.
    public func snapshot(for scope: WatchedScope) throws -> [TaskSummary]? {
        guard try scopeSequence(for: scope) != nil else { return nil }
        var result: [TaskSummary] = []
        try statement("SELECT payload FROM tasks WHERE scope_key = ? ORDER BY task_key;") { stmt in
            try bind(scope.storageKey, to: stmt, index: 1)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let json = try columnText(stmt, index: 0)
                result.append(try decode(TaskSummary.self, from: json))
            }
        }
        return result
    }

    public func metrics(scopes: Set<WatchedScope>, now: Date) throws -> DashboardMetrics {
        var all: [TaskSummary] = []
        for scope in scopes {
            if let loaded = try snapshot(for: scope) { all.append(contentsOf: loaded) }
        }
        return MetricsCalculator.calculate(tasks: all, watchedScopes: scopes, now: now)
    }

    public func recentEvents(limit: Int = 100) throws -> [ChangeEvent] {
        guard limit > 0 else { return [] }
        var result: [ChangeEvent] = []
        try statement("""
            SELECT payload FROM events ORDER BY detected_at DESC, event_key DESC LIMIT ?;
            """) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(min(limit, 1000)))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let json = try columnText(stmt, index: 0)
                result.append(try decode(ChangeEvent.self, from: json))
            }
        }
        return result
    }

    public func lastSuccessfulSync(for scope: WatchedScope) throws -> Date? {
        var value: Date?
        try statement("SELECT last_synced FROM scopes WHERE scope_key = ?;") { stmt in
            try bind(scope.storageKey, to: stmt, index: 1)
            if sqlite3_step(stmt) == SQLITE_ROW {
                value = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0))
            }
        }
        return value
    }

    /// Erases account-specific cached summaries and events; Keychain cleanup is a separate layer.
    public func removeAccount(providerID: String, accountID: String) throws {
        try Self.execute(db, "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try statement("DELETE FROM scopes WHERE provider_id = ? AND account_id = ?;") { stmt in
                try bind(providerID, to: stmt, index: 1)
                try bind(accountID, to: stmt, index: 2)
                try stepDone(stmt)
            }
            try Self.execute(db, "COMMIT;")
        } catch {
            try? Self.execute(db, "ROLLBACK;")
            throw error
        }
    }

    private func scopeSequence(for scope: WatchedScope) throws -> Int? {
        var value: Int?
        try statement("SELECT sequence FROM scopes WHERE scope_key = ?;") { stmt in
            try bind(scope.storageKey, to: stmt, index: 1)
            if sqlite3_step(stmt) == SQLITE_ROW {
                value = Int(sqlite3_column_int64(stmt, 0))
            }
        }
        return value
    }

    private func statement(_ sql: String, perform: (OpaquePointer) throws -> Void) throws {
        var prepared: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &prepared, nil) == SQLITE_OK,
              let prepared else {
            throw SnapshotStoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(prepared) }
        try perform(prepared)
    }

    private func bind(_ value: String, to stmt: OpaquePointer, index: Int32) throws {
        guard sqlite3_bind_text(stmt, index, value, -1, Self.transient) == SQLITE_OK else {
            throw SnapshotStoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func stepDone(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SnapshotStoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func columnText(_ stmt: OpaquePointer, index: Int32) throws -> String {
        guard let text = sqlite3_column_text(stmt, index) else {
            throw SnapshotStoreError.sqlite("Unexpected NULL payload")
        }
        return String(cString: text)
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SnapshotStoreError.sqlite("Unable to encode UTF-8 payload")
        }
        return text
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try decoder.decode(type, from: Data(json.utf8))
    }

    private static func schemaVersion(_ handle: OpaquePointer) throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK,
              let stmt else { throw SnapshotStoreError.sqlite(String(cString: sqlite3_errmsg(handle))) }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw SnapshotStoreError.sqlite("Unable to read database schema")
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private static func execute(_ handle: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw SnapshotStoreError.sqlite(String(cString: sqlite3_errmsg(handle)))
        }
    }
}
