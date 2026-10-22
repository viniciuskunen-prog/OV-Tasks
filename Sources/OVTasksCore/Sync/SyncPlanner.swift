import Foundation

/// Pure scheduling policy. The actual timer, provider fetch and sleep/wake handling
/// are deliberately left to the platform integration milestone.
public struct PollState: Sendable {
    public let isConnected: Bool
    public let lastAttemptAt: Date?
    public let retryAfter: Date?

    public init(isConnected: Bool, lastAttemptAt: Date? = nil, retryAfter: Date? = nil) {
        self.isConnected = isConnected
        self.lastAttemptAt = lastAttemptAt
        self.retryAfter = retryAfter
    }
}

public enum SyncPlanner {
    public static func nextEligiblePoll(
        state: PollState,
        now: Date,
        interval: TimeInterval = 300
    ) -> Date? {
        guard state.isConnected else { return nil }
        // Even a user-specified interval cannot poll an external service more than
        // once every 60 seconds without explicit provider-specific approval.
        let cadence = max(interval, 60)
        let afterLastAttempt = state.lastAttemptAt?.addingTimeInterval(cadence) ?? now
        return max(now, afterLastAttempt, state.retryAfter ?? now)
    }
}
