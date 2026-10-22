import Foundation

public enum ChangeKind: String, Codable, Sendable {
    case taskCreated = "TASK_CREATED"
    case statusChanged = "STATUS_CHANGED"
    case completed = "COMPLETED"
    case dueDateChanged = "DUE_DATE_CHANGED"
    case assignmentChanged = "ASSIGNED"
}

public struct ChangeEvent: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let taskIdentity: TaskIdentity
    public let taskTitle: String
    public let kind: ChangeKind
    public let detectedAt: Date
    public let occurredAt: Date?
    public let previousValue: String?
    public let nextValue: String?

    public init(
        id: String,
        taskIdentity: TaskIdentity,
        taskTitle: String,
        kind: ChangeKind,
        detectedAt: Date,
        occurredAt: Date?,
        previousValue: String?,
        nextValue: String?
    ) {
        self.id = id
        self.taskIdentity = taskIdentity
        self.taskTitle = taskTitle
        self.kind = kind
        self.detectedAt = detectedAt
        self.occurredAt = occurredAt
        self.previousValue = previousValue
        self.nextValue = nextValue
    }
}

/// Pure snapshot diff; only a complete, successful provider snapshot may be passed in.
/// Pass nil for a scope's first synchronization to suppress historical notifications.
public enum SnapshotDiffer {
    public static func changes(
        previous: [TaskSummary]?,
        current: [TaskSummary],
        detectedAt: Date,
        syncSequence: Int
    ) -> [ChangeEvent] {
        guard let previous else { return [] }
        let oldByIdentity = Dictionary(previous.map { ($0.identity, $0) },
                                       uniquingKeysWith: { _, latest in latest })
        var result: [ChangeEvent] = []

        for task in current.sorted(by: { $0.identity.storageKey < $1.identity.storageKey }) {
            guard let old = oldByIdentity[task.identity] else {
                result.append(event(for: task, kind: .taskCreated, old: nil, new: nil,
                                    detectedAt: detectedAt, sequence: syncSequence))
                continue
            }

            if old.status != task.status {
                result.append(event(for: task,
                                    kind: task.status == .done ? .completed : .statusChanged,
                                    old: old.status.rawValue,
                                    new: task.status.rawValue,
                                    detectedAt: detectedAt, sequence: syncSequence))
            }
            if old.deadline != task.deadline {
                result.append(event(for: task, kind: .dueDateChanged,
                                    old: describe(old.deadline), new: describe(task.deadline),
                                    detectedAt: detectedAt, sequence: syncSequence))
            }
            let oldAssignees = Set(old.assigneeIDs)
            let newAssignees = Set(task.assigneeIDs)
            if oldAssignees != newAssignees {
                // Counts avoid exposing account identifiers in user-facing event text.
                result.append(event(for: task, kind: .assignmentChanged,
                                    old: String(oldAssignees.count),
                                    new: String(newAssignees.count),
                                    detectedAt: detectedAt, sequence: syncSequence))
            }
        }
        // A missing task in a fully-scoped snapshot is removed from the cache, but
        // no deletion is asserted: it may have been archived or permissions changed.
        return result
    }

    private static func event(
        for task: TaskSummary, kind: ChangeKind, old: String?, new: String?,
        detectedAt: Date, sequence: Int
    ) -> ChangeEvent {
        let key = StableKey.join([
            task.identity.storageKey, kind.rawValue, String(sequence)
        ])
        return ChangeEvent(
            id: key,
            taskIdentity: task.identity,
            taskTitle: task.title,
            kind: kind,
            detectedAt: detectedAt,
            occurredAt: task.updatedAt,
            previousValue: old,
            nextValue: new
        )
    }

    private static func describe(_ deadline: TaskDeadline?) -> String? {
        guard let deadline else { return nil }
        switch deadline {
        case .at(let date):
            return "UTC:\(date.timeIntervalSince1970)"
        case .calendarDay(let local):
            return "DAY:\(local.year)-\(local.month)-\(local.day)@\(local.timeZoneID)"
        }
    }
}
