import Foundation

/// Identifiers are scoped to a provider and connected account; no task URLs are used as primary keys.
public struct TaskIdentity: Hashable, Codable, Sendable {
    public let providerID: String
    public let accountID: String
    public let workspaceID: String?
    public let taskID: String

    public init(providerID: String, accountID: String, workspaceID: String? = nil, taskID: String) {
        self.providerID = providerID
        self.accountID = accountID
        self.workspaceID = workspaceID
        self.taskID = taskID
    }

    public var storageKey: String {
        StableKey.join([providerID, accountID, workspaceID, taskID])
    }
}

public struct WatchedScope: Hashable, Codable, Sendable {
    public let providerID: String
    public let accountID: String
    public let scopeID: String

    public init(providerID: String, accountID: String, scopeID: String) {
        self.providerID = providerID
        self.accountID = accountID
        self.scopeID = scopeID
    }

    public var storageKey: String {
        StableKey.join([providerID, accountID, scopeID])
    }
}

enum StableKey {
    /// Length-prefixed components avoid delimiter collisions and distinguish nil from "".
    static func join(_ pieces: [String?]) -> String {
        pieces.map { component in
            guard let component else { return "N;" }
            return "S\(component.utf8.count):\(component);"
        }.joined()
    }
}

public enum TaskStatus: String, Codable, Sendable {
    case open = "OPEN"
    case inProgress = "IN_PROGRESS"
    case blocked = "BLOCKED"
    case done = "DONE"
    case canceled = "CANCELED"
    case unknown = "UNKNOWN"

    public var isPending: Bool {
        switch self {
        case .open, .inProgress, .blocked: return true
        case .done, .canceled, .unknown: return false
        }
    }
}

/// Provider statuses are arbitrary. Never infer "done" from a list name unless mapped.
public struct StatusMapping: Sendable {
    private let normalized: [String: TaskStatus]

    public init(_ mapping: [String: TaskStatus]) {
        self.normalized = Dictionary(mapping.map { ($0.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0.value) },
                                     uniquingKeysWith: { latest, _ in latest })
    }

    public func status(for rawValue: String) -> TaskStatus {
        normalized[rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? .unknown
    }
}

/// A calendar day is due through the end of that day in the explicitly selected timezone.
/// It expires exactly when the *next local day* begins, including 23/25-hour DST days.
public struct LocalDueDay: Hashable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let timeZoneID: String

    public init(year: Int, month: Int, day: Int, timeZoneID: String) {
        self.year = year
        self.month = month
        self.day = day
        self.timeZoneID = timeZoneID
    }

    public var expiresAt: Date? {
        guard let timeZone = TimeZone(identifier: timeZoneID) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: day)
        guard let first = calendar.date(from: components) else { return nil }
        let verify = calendar.dateComponents([.year, .month, .day], from: first)
        guard verify.year == year && verify.month == month && verify.day == day else { return nil }
        return calendar.date(byAdding: .day, value: 1, to: first)
    }
}

public enum TaskDeadline: Hashable, Codable, Sendable {
    case at(Date)
    case calendarDay(LocalDueDay)

    public var expiresAt: Date? {
        switch self {
        case .at(let date): return date
        case .calendarDay(let day): return day.expiresAt
        }
    }

    public func isOverdue(at instant: Date) -> Bool {
        guard let expiresAt else { return false }
        return instant >= expiresAt
    }
}

public struct TaskSummary: Hashable, Codable, Sendable, Identifiable {
    public let identity: TaskIdentity
    public let sourceScopeID: String
    public let title: String
    public let originalURL: URL?
    public let rawStatus: String
    public let status: TaskStatus
    public let deadline: TaskDeadline?
    public let completedAt: Date?
    public let updatedAt: Date?
    public let assigneeIDs: [String]

    public var id: String { identity.storageKey }

    public init(
        identity: TaskIdentity,
        sourceScopeID: String,
        title: String,
        originalURL: URL? = nil,
        rawStatus: String,
        status: TaskStatus,
        deadline: TaskDeadline? = nil,
        completedAt: Date? = nil,
        updatedAt: Date? = nil,
        assigneeIDs: [String] = []
    ) {
        self.identity = identity
        self.sourceScopeID = sourceScopeID
        self.title = title
        self.originalURL = originalURL
        self.rawStatus = rawStatus
        self.status = status
        self.deadline = deadline
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.assigneeIDs = assigneeIDs
    }

    public var scope: WatchedScope {
        WatchedScope(providerID: identity.providerID, accountID: identity.accountID, scopeID: sourceScopeID)
    }

    /// Only HTTPS task URLs can become eventual open-in-provider actions.
    public var validatedOriginalURL: URL? {
        guard let originalURL, originalURL.scheme?.lowercased() == "https",
              originalURL.host != nil,
              originalURL.user == nil, originalURL.password == nil else { return nil }
        return originalURL
    }
}
