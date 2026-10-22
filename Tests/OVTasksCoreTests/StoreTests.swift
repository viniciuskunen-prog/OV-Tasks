import Foundation
import XCTest
@testable import OVTasksCore

final class StoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func temporaryDatabase() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("OVTasksTest-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("snapshots.sqlite")
    }

    func testBaselineIsSilentAndStateSurvivesDatabaseReopen() async throws {
        let url = temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let scope = fixtureScope()
        let first = fixtureTask(id: "alpha")
        let store = try SQLiteSnapshotStore(databaseURL: url)

        let baseline = try await store.applyCompleteSnapshot(scope: scope, tasks: [first], detectedAt: now)
        XCTAssertTrue(baseline.isEmpty)
        let saved = try await store.snapshot(for: scope)
        XCTAssertEqual(saved, [first])
        let timestamp = try await store.lastSuccessfulSync(for: scope)
        XCTAssertEqual(timestamp, now)

        let reopened = try SQLiteSnapshotStore(databaseURL: url)
        let persisted = try await reopened.snapshot(for: scope)
        XCTAssertEqual(persisted, [first])
        let changed = fixtureTask(id: "alpha", status: .done, completedAt: now, updatedAt: now)
        let changes = try await reopened.applyCompleteSnapshot(
            scope: scope, tasks: [changed], detectedAt: now.addingTimeInterval(60)
        )
        XCTAssertEqual(changes.map(\.kind), [.completed])
        let events = try await store.recentEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.id, changes.first?.id)
    }

    func testRepeatedSnapshotDoesNotCreateDuplicateEvents() async throws {
        let url = temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let scope = fixtureScope()
        let store = try SQLiteSnapshotStore(databaseURL: url)
        try await store.applyCompleteSnapshot(scope: scope, tasks: [fixtureTask(id: "one")], detectedAt: now)
        let changed = fixtureTask(id: "one", status: .inProgress, updatedAt: now)
        let one = try await store.applyCompleteSnapshot(
            scope: scope, tasks: [changed], detectedAt: now.addingTimeInterval(30)
        )
        let zero = try await store.applyCompleteSnapshot(
            scope: scope, tasks: [changed], detectedAt: now.addingTimeInterval(60)
        )
        XCTAssertEqual(one.count, 1)
        XCTAssertTrue(zero.isEmpty)
        let history = try await store.recentEvents()
        XCTAssertEqual(history.count, 1)
        let metrics = try await store.metrics(scopes: [scope], now: now)
        XCTAssertEqual(metrics.inProgress, 1)
    }

    func testInvalidOrDuplicateSnapshotLeavesLastGoodStateIntact() async throws {
        let url = temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let scope = fixtureScope()
        let old = fixtureTask(id: "safe")
        let store = try SQLiteSnapshotStore(databaseURL: url)
        try await store.applyCompleteSnapshot(scope: scope, tasks: [old], detectedAt: now)

        do {
            try await store.applyCompleteSnapshot(
                scope: scope,
                tasks: [fixtureTask(id: "unrelated", scope: fixtureScope(scopeID: "other"))],
                detectedAt: now
            )
            XCTFail("Expected rejected scope")
        } catch SnapshotStoreError.invalidScope {
            // Expected; no write occurred.
        }

        do {
            try await store.applyCompleteSnapshot(
                scope: scope, tasks: [old, old], detectedAt: now
            )
            XCTFail("Expected duplicate task rejection")
        } catch SnapshotStoreError.duplicateTask {
            // Expected; no write occurred.
        }
        let stillPresent = try await store.snapshot(for: scope)
        XCTAssertEqual(stillPresent, [old])
        let events = try await store.recentEvents()
        XCTAssertTrue(events.isEmpty)
    }

    func testEmptyCompleteSnapshotAndAccountIsolationAndErasure() async throws {
        let url = temporaryDatabase()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let a = fixtureScope(accountID: "account-a")
        let b = fixtureScope(accountID: "account-b")
        let store = try SQLiteSnapshotStore(databaseURL: url)
        let taskA = fixtureTask(id: "a", scope: a)
        let taskB = fixtureTask(id: "b", scope: b)
        let beforeAnySync = try await store.snapshot(for: a)
        XCTAssertNil(beforeAnySync)
        try await store.applyCompleteSnapshot(scope: a, tasks: [taskA], detectedAt: now)
        try await store.applyCompleteSnapshot(scope: b, tasks: [taskB], detectedAt: now)
        try await store.applyCompleteSnapshot(scope: a, tasks: [], detectedAt: now.addingTimeInterval(1))
        let emptyButInitialized = try await store.snapshot(for: a)
        XCTAssertEqual(emptyButInitialized, [])
        let other = try await store.snapshot(for: b)
        XCTAssertEqual(other, [taskB])

        try await store.removeAccount(providerID: "trello", accountID: "account-a")
        let removedSnapshot = try await store.snapshot(for: a)
        let preservedOtherAccount = try await store.snapshot(for: b)
        XCTAssertNil(removedSnapshot)
        XCTAssertEqual(preservedOtherAccount, [taskB])
    }
}
