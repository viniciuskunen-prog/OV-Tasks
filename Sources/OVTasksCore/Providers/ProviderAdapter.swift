import Foundation

/// A connector supplies normalized, read-only pages for ONE authorized and watched scope.
/// Authentication, credentials and HTTP transport live in future provider-specific packages.
public protocol ProviderAdapter: Sendable {
    var providerID: String { get }
    var capabilities: ProviderCapabilities { get }

    func fetchPage(for scope: WatchedScope, cursor: String?) async throws -> ProviderPage
}

public struct ProviderCapabilities: Sendable, Equatable {
    public let supportsComments: Bool
    public let supportsAssignments: Bool
    public let supportsCompletionTimestamp: Bool
    public let supportsIncrementalSync: Bool
    public let supportsSourceEvents: Bool

    public init(
        supportsComments: Bool = false,
        supportsAssignments: Bool = false,
        supportsCompletionTimestamp: Bool = false,
        supportsIncrementalSync: Bool = false,
        supportsSourceEvents: Bool = false
    ) {
        self.supportsComments = supportsComments
        self.supportsAssignments = supportsAssignments
        self.supportsCompletionTimestamp = supportsCompletionTimestamp
        self.supportsIncrementalSync = supportsIncrementalSync
        self.supportsSourceEvents = supportsSourceEvents
    }
}

/// Each call returns a complete page, NOT a snapshot ready to persist.
/// A nil nextCursor indicates the end of the paginated snapshot.
public struct ProviderPage: Sendable {
    public let tasks: [TaskSummary]
    public let nextCursor: String?

    public init(tasks: [TaskSummary], nextCursor: String?) {
        self.tasks = tasks
        self.nextCursor = nextCursor
    }
}

public enum ProviderSyncError: Error, Equatable {
    case providerMismatch
    case invalidScope
    case repeatedCursor
    case exceededPageLimit
    case exceededTaskLimit
    case duplicateTask
}

/// Collects an entire normalized scope before writing to the SQLite cache.
/// Partial pages, thrown provider errors and cancellation never replace valid data.
public enum SnapshotIngestor {
    @discardableResult
    public static func ingest(
        adapter: any ProviderAdapter,
        scope: WatchedScope,
        into store: SQLiteSnapshotStore,
        at detectedAt: Date,
        maxPages: Int = 100,
        maxTasks: Int = 25_000
    ) async throws -> [ChangeEvent] {
        guard adapter.providerID == scope.providerID else {
            throw ProviderSyncError.providerMismatch
        }
        guard !scope.providerID.isEmpty, !scope.accountID.isEmpty, !scope.scopeID.isEmpty else {
            throw ProviderSyncError.invalidScope
        }
        guard maxPages > 0 else { throw ProviderSyncError.exceededPageLimit }
        guard maxTasks > 0 else { throw ProviderSyncError.exceededTaskLimit }

        var tasks: [TaskSummary] = []
        var seenTasks = Set<TaskIdentity>()
        var seenCursors = Set<String>()
        var cursor: String?
        var pages = 0

        repeat {
            try Task.checkCancellation()
            if pages >= maxPages { throw ProviderSyncError.exceededPageLimit }

            let page = try await adapter.fetchPage(for: scope, cursor: cursor)
            pages += 1

            for task in page.tasks {
                guard task.scope == scope else { throw ProviderSyncError.invalidScope }
                guard seenTasks.insert(task.identity).inserted else {
                    throw ProviderSyncError.duplicateTask
                }
                if tasks.count >= maxTasks { throw ProviderSyncError.exceededTaskLimit }
                tasks.append(task)
            }

            if let next = page.nextCursor {
                guard !next.isEmpty, seenCursors.insert(next).inserted, next != cursor else {
                    throw ProviderSyncError.repeatedCursor
                }
            }
            cursor = page.nextCursor
        } while cursor != nil

        try Task.checkCancellation()
        return try await store.applyCompleteSnapshot(scope: scope, tasks: tasks, detectedAt: detectedAt)
    }
}
