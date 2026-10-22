import Foundation
import XCTest
@testable import OVTasksCore

final class DomainTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testStableKeysDistinguishNilEmptyAndSeparators() {
        let base = TaskIdentity(providerID: "a", accountID: "b", taskID: "x:y")
        let emptyWorkspace = TaskIdentity(providerID: "a", accountID: "b", workspaceID: "", taskID: "x:y")
        let different = TaskIdentity(providerID: "a:b", accountID: "", taskID: "x:y")
        XCTAssertNotEqual(base.storageKey, emptyWorkspace.storageKey)
        XCTAssertNotEqual(base.storageKey, different.storageKey)
        XCTAssertEqual(base.storageKey, base.storageKey)
    }

    func testStatusesOnlyRecognizedByExplicitMapping() {
        let mapping = StatusMapping(["  EM PROGRESSO ": .inProgress, "Entregue": .done])
        XCTAssertEqual(mapping.status(for: "em progresso"), .inProgress)
        XCTAssertEqual(mapping.status(for: " ENTREGUE "), .done)
        XCTAssertEqual(mapping.status(for: "Done"), .unknown)
        XCTAssertFalse(TaskStatus.unknown.isPending)
        XCTAssertTrue(TaskStatus.blocked.isPending)
    }

    func testCalendarOnlyDeadlineExpiresNextLocalMidnight() {
        let date = LocalDueDay(year: 2026, month: 3, day: 8, timeZoneID: "America/New_York")
        let deadline = TaskDeadline.calendarDay(date)
        guard let expiration = date.expiresAt else { return XCTFail("Expected valid day") }
        XCTAssertFalse(deadline.isOverdue(at: expiration.addingTimeInterval(-1)))
        XCTAssertTrue(deadline.isOverdue(at: expiration))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))!
        XCTAssertEqual(expiration.timeIntervalSince(start), 23 * 3600, accuracy: 0.1)
    }

    func testInvalidTimezoneAndCalendarDayDoNotBecomeOverdue() {
        XCTAssertNil(LocalDueDay(year: 2026, month: 2, day: 30, timeZoneID: "UTC").expiresAt)
        XCTAssertNil(LocalDueDay(year: 2026, month: 10, day: 22, timeZoneID: "not-a-zone").expiresAt)
        XCTAssertFalse(TaskDeadline.calendarDay(
            LocalDueDay(year: 2026, month: 2, day: 30, timeZoneID: "UTC")
        ).isOverdue(at: now))
    }

    func testMetricsOverlapWithSevenDayWindowAndUnknownCompletion() {
        let scope = fixtureScope()
        let tasks = [
            fixtureTask(id: "a", status: .open),
            fixtureTask(id: "b", status: .inProgress, due: .at(now.addingTimeInterval(-100))),
            fixtureTask(id: "c", status: .blocked, due: .at(now.addingTimeInterval(-2))),
            fixtureTask(id: "d", status: .done, completedAt: now.addingTimeInterval(-6 * 86_400)),
            fixtureTask(id: "e", status: .done, completedAt: now.addingTimeInterval(-8 * 86_400)),
            fixtureTask(id: "f", status: .done),
            fixtureTask(id: "g", status: .canceled, due: .at(now.addingTimeInterval(-10))),
            fixtureTask(id: "h", status: .unknown, due: .at(now.addingTimeInterval(-10)))
        ]
        let metrics = MetricsCalculator.calculate(tasks: tasks, watchedScopes: [scope], now: now)
        XCTAssertEqual(metrics.pending, 3)
        XCTAssertEqual(metrics.inProgress, 1)
        XCTAssertEqual(metrics.overdue, 2)
        XCTAssertEqual(metrics.completed, 1)
        XCTAssertFalse(metrics.completedIsComplete)
    }

    func testMetricsOnlyIncludeWatchedScopesAndDedupSameIdentity() {
        let one = fixtureScope(scopeID: "a")
        let two = fixtureScope(scopeID: "b")
        let other = fixtureScope(accountID: "someone-else", scopeID: "a")
        let tasks = [
            fixtureTask(id: "shared", scope: one, status: .open, updatedAt: now.addingTimeInterval(-60)),
            fixtureTask(id: "shared", scope: two, status: .inProgress, updatedAt: now),
            fixtureTask(id: "hidden", scope: other, status: .open)
        ]
        let metrics = MetricsCalculator.calculate(tasks: tasks, watchedScopes: [one, two], now: now)
        XCTAssertEqual(metrics.pending, 1)
        XCTAssertEqual(metrics.inProgress, 1)
        XCTAssertEqual(metrics.completed, 0)
        XCTAssertTrue(metrics.completedIsComplete)
    }

    func testChangeDetectionSkipsBaselineAndRepeatedSnapshot() {
        let first = fixtureTask(id: "one", status: .open)
        XCTAssertTrue(SnapshotDiffer.changes(
            previous: nil, current: [first], detectedAt: now, syncSequence: 1
        ).isEmpty)
        XCTAssertTrue(SnapshotDiffer.changes(
            previous: [first], current: [first], detectedAt: now, syncSequence: 2
        ).isEmpty)
        let second = fixtureTask(id: "two")
        let events = SnapshotDiffer.changes(
            previous: [first], current: [first, second], detectedAt: now, syncSequence: 3
        )
        XCTAssertEqual(events.map(\.kind), [.taskCreated])
    }

    func testChangeDetectionClassifiesTransitionsWithoutExposingAssigneeIDs() {
        let before = fixtureTask(id: "a", status: .inProgress, due: nil, assigneeIDs: ["someone"])
        let after = fixtureTask(id: "a", status: .done,
                                due: .calendarDay(LocalDueDay(year: 2026, month: 10, day: 22, timeZoneID: "UTC")),
                                completedAt: now, updatedAt: now,
                                assigneeIDs: ["another"])
        let events = SnapshotDiffer.changes(
            previous: [before], current: [after], detectedAt: now, syncSequence: 2
        )
        XCTAssertEqual(Set(events.map(\.kind)), Set([.completed, .dueDateChanged, .assignmentChanged]))
        XCTAssertEqual(Set(events.map(\.id)).count, 3)
        XCTAssertFalse(events.contains { $0.previousValue == "someone" || $0.nextValue == "another" })
    }

    func testSyncPlannerHonorsCadenceBackoffAndDisconnected() {
        let now = Date(timeIntervalSince1970: 100_000)
        XCTAssertNil(SyncPlanner.nextEligiblePoll(state: PollState(isConnected: false), now: now))
        XCTAssertEqual(SyncPlanner.nextEligiblePoll(
            state: PollState(isConnected: true), now: now), now)
        XCTAssertEqual(SyncPlanner.nextEligiblePoll(
            state: PollState(isConnected: true, lastAttemptAt: now.addingTimeInterval(-30)),
            now: now, interval: 5), now.addingTimeInterval(30))
        XCTAssertEqual(SyncPlanner.nextEligiblePoll(
            state: PollState(isConnected: true, lastAttemptAt: now.addingTimeInterval(-30),
                             retryAfter: now.addingTimeInterval(900)),
            now: now), now.addingTimeInterval(900))
    }
}
