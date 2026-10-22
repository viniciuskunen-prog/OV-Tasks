import Foundation

public struct DashboardMetrics: Equatable, Sendable {
    public let pending: Int
    public let inProgress: Int
    public let overdue: Int
    public let completed: Int
    /// False if a DONE task has no reliable completion time. Never fill in a fabricated date.
    public let completedIsComplete: Bool

    public init(pending: Int, inProgress: Int, overdue: Int, completed: Int, completedIsComplete: Bool) {
        self.pending = pending
        self.inProgress = inProgress
        self.overdue = overdue
        self.completed = completed
        self.completedIsComplete = completedIsComplete
    }
}

public enum MetricsCalculator {
    /// Counts only explicitly selected scopes, deduplicating a task visible in multiple scopes.
    /// Pending includes both in-progress and overdue tasks; the cards are intentionally overlapping.
    public static func calculate(
        tasks: [TaskSummary],
        watchedScopes: Set<WatchedScope>,
        now: Date,
        completedWindow: TimeInterval = 7 * 24 * 60 * 60
    ) -> DashboardMetrics {
        var byIdentity: [TaskIdentity: TaskSummary] = [:]
        for task in tasks where watchedScopes.contains(task.scope) {
            if let existing = byIdentity[task.identity] {
                let oldDate = existing.updatedAt ?? .distantPast
                let newDate = task.updatedAt ?? .distantPast
                if newDate > oldDate {
                    byIdentity[task.identity] = task
                }
            } else {
                byIdentity[task.identity] = task
            }
        }

        var pending = 0
        var inProgress = 0
        var overdue = 0
        var completed = 0
        var completedIsComplete = true
        let windowStart = now.addingTimeInterval(-completedWindow)

        for task in byIdentity.values {
            if task.status.isPending {
                pending += 1
                if task.status == .inProgress { inProgress += 1 }
                if task.deadline?.isOverdue(at: now) == true { overdue += 1 }
            } else if task.status == .done {
                if let finished = task.completedAt {
                    if finished >= windowStart && finished <= now { completed += 1 }
                } else {
                    completedIsComplete = false
                }
            }
        }
        return DashboardMetrics(
            pending: pending,
            inProgress: inProgress,
            overdue: overdue,
            completed: completed,
            completedIsComplete: completedIsComplete
        )
    }
}
