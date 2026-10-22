import Foundation
import Darwin

// Dependency-free native regression smoke runner.
// Compile with sources directly using swiftc; this file MUST NOT be added
// to Package.swift, because XCTest remains the full test suite.
enum SmokeFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message): return message
        }
    }
}

@main
struct CoreSmokeRunner {
    static func main() async {
        do {
            try testIdentifiersAndMappings()
            try testDatesAndMetrics()
            try testEventDifferences()
            try testScheduling()
            try await testSQLitePersistence()
            print("PASS: 5 smoke groups — identity/status, dates/metrics, events, scheduling, SQLite")
            print("NOTE: XCTest suite has NOT been executed; this is a targeted direct-swiftc regression.")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func check(_ predicate: @autoclosure () -> Bool, _ message: String) throws {
        guard predicate() else { throw SmokeFailure.assertion(message) }
    }

    private static func scope(_ account: String = "smoke-a", board: String = "board") -> WatchedScope {
        WatchedScope(providerID: "trello", accountID: account, scopeID: board)
    }

    private static func task(
        _ id: String,
        scope: WatchedScope = scope(),
        status: TaskStatus = .open,
        deadline: TaskDeadline? = nil,
        completedAt: Date? = nil,
        updatedAt: Date? = nil,
        assignees: [String] = []
    ) -> TaskSummary {
        TaskSummary(
            identity: TaskIdentity(providerID: scope.providerID, accountID: scope.accountID,
                                   workspaceID: "workspace", taskID: id),
            sourceScopeID: scope.scopeID,
            title: "Synthetic task \(id)",
            originalURL: URL(string: "https://example.org/tasks/\(id)"),
            rawStatus: status.rawValue,
            status: status,
            deadline: deadline,
            completedAt: completedAt,
            updatedAt: updatedAt,
            assigneeIDs: assignees
        )
    }

    private static func testIdentifiersAndMappings() throws {
        let key1 = TaskIdentity(providerID: "a", accountID: "b", taskID: "x:y")
        let key2 = TaskIdentity(providerID: "a", accountID: "b", workspaceID: "", taskID: "x:y")
        let key3 = TaskIdentity(providerID: "a:b", accountID: "", taskID: "x:y")
        try check(key1.storageKey != key2.storageKey, "Nil/empty identifiers collide")
        try check(key1.storageKey != key3.storageKey, "Delimited identifiers collide")

        let mapping = StatusMapping(["  EM ANDAMENTO ": .inProgress, "entregue": .done])
        try check(mapping.status(for: "em andamento") == .inProgress, "Explicit status mapping failed")
        try check(mapping.status(for: "Entregue") == .done, "Completed status mapping failed")
        try check(mapping.status(for: "done") == .unknown, "Unknown source status inferred incorrectly")

        let unsafe = TaskSummary(
            identity: key1, sourceScopeID: "board", title: "Sample",
            originalURL: URL(string: "file:///tmp/token"), rawStatus: "To do", status: .open
        )
        try check(unsafe.validatedOriginalURL == nil, "Unsafe task URL was accepted")
    }

    private static func testDatesAndMetrics() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let localDay = LocalDueDay(year: 2026, month: 3, day: 8, timeZoneID: "America/New_York")
        guard let midnight = localDay.expiresAt else {
            throw SmokeFailure.assertion("Failed to construct a valid date-only deadline")
        }
        let due = TaskDeadline.calendarDay(localDay)
        try check(!due.isOverdue(at: midnight.addingTimeInterval(-1)), "Date-only deadline expired early")
        try check(due.isOverdue(at: midnight), "Date-only deadline missed next midnight")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        guard let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)) else {
            throw SmokeFailure.assertion("Calendar did not return a start date")
        }
        try check(abs(midnight.timeIntervalSince(start) - 23 * 3600) < 1, "DST date-only day length incorrect")
        try check(LocalDueDay(year: 2026, month: 2, day: 30, timeZoneID: "UTC").expiresAt == nil,
                  "Invalid calendar day accepted")

        let tracked = scope()
        let other = scope("other-account")
        let all = [
            task("open", scope: tracked),
            task("doing", scope: tracked, status: .inProgress, deadline: .at(now.addingTimeInterval(-60))),
            task("blocked", scope: tracked, status: .blocked, deadline: .at(now.addingTimeInterval(-2))),
            task("finished", scope: tracked, status: .done, completedAt: now.addingTimeInterval(-6 * 86_400)),
            task("unknown-date", scope: tracked, status: .done),
            task("old-finished", scope: tracked, status: .done, completedAt: now.addingTimeInterval(-8 * 86_400)),
            task("unmapped", scope: tracked, status: .unknown, deadline: .at(now.addingTimeInterval(-30))),
            task("hidden", scope: other)
        ]
        let metric = MetricsCalculator.calculate(tasks: all, watchedScopes: [tracked], now: now)
        try check(metric.pending == 3 && metric.inProgress == 1 && metric.overdue == 2,
                  "Dashboard overlap/scope counts incorrect")
        try check(metric.completed == 1 && !metric.completedIsComplete,
                  "Seven-day completions/unknown completedAt incorrect")
    }

    private static func testEventDifferences() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = task("task", status: .open)
        let updated = task(
            "task", status: .done, deadline: .at(now.addingTimeInterval(100)),
            completedAt: now, updatedAt: now, assignees: ["assignee-synthetic"]
        )
        try check(SnapshotDiffer.changes(previous: nil, current: [old],
                                         detectedAt: now, syncSequence: 1).isEmpty,
                  "First sync generated events")
        let changes = SnapshotDiffer.changes(previous: [old], current: [updated],
                                             detectedAt: now, syncSequence: 2)
        try check(Set(changes.map(\.kind)) == Set([.completed, .dueDateChanged, .assignmentChanged]),
                  "Change types incorrectly classified")
        try check(Set(changes.map(\.id)).count == 3, "Event keys collided")
        try check(SnapshotDiffer.changes(previous: [updated], current: [updated],
                                         detectedAt: now, syncSequence: 3).isEmpty,
                  "Unchanged snapshot generated events")
    }

    private static func testScheduling() throws {
        let now = Date(timeIntervalSince1970: 100_000)
        try check(SyncPlanner.nextEligiblePoll(state: PollState(isConnected: false), now: now) == nil,
                  "Disconnected provider scheduled a poll")
        let next = SyncPlanner.nextEligiblePoll(
            state: PollState(isConnected: true, lastAttemptAt: now.addingTimeInterval(-30)),
            now: now, interval: 1
        )
        try check(next == now.addingTimeInterval(30), "Minimum 60-second interval not honored")
        let retry = SyncPlanner.nextEligiblePoll(
            state: PollState(isConnected: true, retryAfter: now.addingTimeInterval(900)),
            now: now
        )
        try check(retry == now.addingTimeInterval(900), "Retry-after not honored")
    }

    private static func testSQLitePersistence() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("OVTasksM2Smoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: path) }
        let url = path.appendingPathComponent("snapshots.sqlite")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let primary = scope()
        let other = scope("smoke-b")
        let first = task("first")
        let second = task("second", scope: other)
        let store = try SQLiteSnapshotStore(databaseURL: url)

        let baseline = try await store.applyCompleteSnapshot(scope: primary, tasks: [first], detectedAt: now)
        try check(baseline.isEmpty, "First SQLite import generated alerts")
        let initial = try await store.snapshot(for: primary)
        try check(initial == [first], "Initial SQLite snapshot differs")

        try await store.applyCompleteSnapshot(scope: other, tasks: [second], detectedAt: now)
        let changed = task("first", status: .inProgress, updatedAt: now)
        let events = try await store.applyCompleteSnapshot(
            scope: primary, tasks: [changed], detectedAt: now.addingTimeInterval(60)
        )
        try check(events.count == 1 && events[0].kind == .statusChanged, "Transition not persisted")

        let noChange = try await store.applyCompleteSnapshot(
            scope: primary, tasks: [changed], detectedAt: now.addingTimeInterval(120)
        )
        try check(noChange.isEmpty, "Repeated snapshot emitted duplicate event")
        let persistedEvents = try await store.recentEvents()
        try check(persistedEvents.count == 1, "Duplicate event stored")

        do {
            try await store.applyCompleteSnapshot(scope: primary, tasks: [changed, changed], detectedAt: now)
            throw SmokeFailure.assertion("Duplicate payload unexpectedly accepted")
        } catch SnapshotStoreError.duplicateTask {
            // Correct rejection.
        }

        let unchanged = try await store.snapshot(for: primary)
        try check(unchanged == [changed], "Invalid snapshot corrupted cache")
        let reopened = try SQLiteSnapshotStore(databaseURL: url)
        let persisted = try await reopened.snapshot(for: primary)
        try check(persisted == [changed], "SQLite data not durable across reopened connections")

        try await reopened.removeAccount(providerID: "trello", accountID: "smoke-a")
        let erased = try await reopened.snapshot(for: primary)
        let surviving = try await reopened.snapshot(for: other)
        try check(erased == nil && surviving == [second], "Account-specific deletion leaked data")
    }
}
