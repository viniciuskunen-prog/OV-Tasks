import Foundation
import Darwin

enum PreviewSmokeFailure: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self {
        case .failed(let why): why
        }
    }
}

private enum FakeMode: Sendable {
    case complete
    case failedSecondPage
    case repeatedCursor
}

private struct FakeAdapter: ProviderAdapter {
    let providerID = "trello"
    let capabilities = ProviderCapabilities(
        supportsAssignments: true,
        supportsCompletionTimestamp: true
    )
    let mode: FakeMode

    func fetchPage(for scope: WatchedScope, cursor: String?) async throws -> ProviderPage {
        if cursor == nil {
            return ProviderPage(tasks: [makeTask("a", scope: scope)], nextCursor: "second")
        }
        switch mode {
        case .complete:
            return ProviderPage(tasks: [makeTask("b", scope: scope)], nextCursor: nil)
        case .failedSecondPage:
            throw PreviewSmokeFailure.failed("synthetic provider second page unavailable")
        case .repeatedCursor:
            return ProviderPage(tasks: [makeTask("b", scope: scope)], nextCursor: "second")
        }
    }
}

private func makeTask(_ name: String, scope: WatchedScope) -> TaskSummary {
    TaskSummary(
        identity: TaskIdentity(providerID: scope.providerID,
                               accountID: scope.accountID,
                               workspaceID: scope.scopeID,
                               taskID: name),
        sourceScopeID: scope.scopeID, title: "Synthetic \(name)",
        rawStatus: TaskStatus.open.rawValue, status: .open
    )
}

@main
struct M25Smoke {
    static func main() async {
        do {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let demo = try await CoreDemoFactory.build(now: now)
            try require(demo.metrics.pending == 18, "Synthetic Pending expected 18")
            try require(demo.metrics.inProgress == 6, "Synthetic In progress expected 6")
            try require(demo.metrics.overdue == 3, "Synthetic Overdue expected 3")
            try require(demo.metrics.completed == 5, "Synthetic Completed expected 5")
            try require(demo.metrics.completedIsComplete, "Synthetic completion timestamps missing")
            try require(demo.events.count == 4, "Expected four simulated source changes")
            try require(demo.events.allSatisfy { ["trello", "clickup", "nanotask"].contains($0.taskIdentity.providerID) },
                        "Synthetic event from unexpected provider")
            print("PASS: core-backed demo metrics 18 / 6 / 3 / 5 and four change events")

            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("OVTasksProviderSmoke-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let store = try SQLiteSnapshotStore(databaseURL: dir.appendingPathComponent("scoped.sqlite"))
            let scope = WatchedScope(providerID: "trello", accountID: "synthetic", scopeID: "scope-1")

            let baseline = try await SnapshotIngestor.ingest(
                adapter: FakeAdapter(mode: .complete), scope: scope, into: store, at: now
            )
            try require(baseline.isEmpty, "First import must not generate events")
            let initial = try await store.snapshot(for: scope)
            try require(initial?.count == 2, "Two pages did not produce two cached tasks")

            do {
                _ = try await SnapshotIngestor.ingest(
                    adapter: FakeAdapter(mode: .failedSecondPage),
                    scope: scope, into: store, at: now.addingTimeInterval(60)
                )
                throw PreviewSmokeFailure.failed("Partial provider failure was accepted")
            } catch PreviewSmokeFailure.failed(let reason) where reason == "synthetic provider second page unavailable" {
                // Expected synthetic provider error.
            }
            let afterError = try await store.snapshot(for: scope)
            try require(afterError == initial, "Partial page failure erased last valid snapshot")

            do {
                _ = try await SnapshotIngestor.ingest(
                    adapter: FakeAdapter(mode: .repeatedCursor),
                    scope: scope, into: store, at: now
                )
                throw PreviewSmokeFailure.failed("Repeated cursor was accepted")
            } catch ProviderSyncError.repeatedCursor {
                // Expected cursor loop defense.
            }
            let afterLoop = try await store.snapshot(for: scope)
            try require(afterLoop == initial, "Cursor loop changed persisted snapshot")

            print("PASS: adapter pagination + baseline, atomic preservation on failure, cursor loop detection")
            print("RESULT: M2.5 standalone smoke PASS. SwiftPM/XCTest and SwiftUI app build remain separate pending checks.")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ reason: String) throws {
        if !condition() { throw PreviewSmokeFailure.failed(reason) }
    }
}
