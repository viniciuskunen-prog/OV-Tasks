import Foundation

/// Purely synthetic demonstration. Exercises the *real* M2 metric/diff/SQLite
/// pipeline but never calls a provider, creates credentials or sends notifications.
/// Every app launch uses a new disposable temporary database.
public struct DemoDashboardSnapshot: Sendable {
    public let metrics: DashboardMetrics
    public let events: [ChangeEvent]

    public init(metrics: DashboardMetrics, events: [ChangeEvent]) {
        self.metrics = metrics
        self.events = events
    }
}

public enum CoreDemoFactory {
    public static func build(now: Date = Date()) async throws -> DemoDashboardSnapshot {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OVTasksSynthetic-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteSnapshotStore(
            databaseURL: directory.appendingPathComponent("preview.sqlite")
        )

        let scopes = [
            WatchedScope(providerID: "trello", accountID: "example-trello", scopeID: "board-demo"),
            WatchedScope(providerID: "clickup", accountID: "example-clickup", scopeID: "list-demo"),
            WatchedScope(providerID: "nanotask", accountID: "example-nanotask", scopeID: "workspace-demo")
        ]

        for (providerIndex, scope) in scopes.enumerated() {
            var first: [TaskSummary] = []
            var current: [TaskSummary] = []

            for localIndex in 0..<6 {
                let index = providerIndex * 6 + localIndex
                var status: TaskStatus = [2, 5, 8, 11, 14].contains(index) ? .inProgress : .open
                let id = "open-\(index)"
                var deadline: TaskDeadline? = [3, 9, 15].contains(index)
                    ? .at(now.addingTimeInterval(-3 * 3600)) : nil
                let identity = TaskIdentity(
                    providerID: scope.providerID,
                    accountID: scope.accountID,
                    workspaceID: scope.scopeID,
                    taskID: id
                )
                var assignees: [String] = []

                let base = TaskSummary(
                    identity: identity, sourceScopeID: scope.scopeID,
                    title: "Tarefa de exemplo \(index + 1)",
                    rawStatus: status.rawValue, status: status,
                    deadline: deadline, updatedAt: now.addingTimeInterval(-3600)
                )
                first.append(base)

                if index == 0 { status = .inProgress }
                if index == 1 { deadline = .at(now.addingTimeInterval(3600)) }
                if index == 16 { assignees = ["synthetic-assignee"] }
                current.append(TaskSummary(
                    identity: identity, sourceScopeID: scope.scopeID,
                    title: displayTitle(index),
                    rawStatus: status.rawValue, status: status,
                    deadline: deadline, updatedAt: now,
                    assigneeIDs: assignees
                ))
            }

            let finishedCount = providerIndex == 2 ? 1 : 2
            for item in 0..<finishedCount {
                let identity = TaskIdentity(
                    providerID: scope.providerID, accountID: scope.accountID,
                    workspaceID: scope.scopeID, taskID: "done-\(providerIndex)-\(item)"
                )
                let completedAt = now.addingTimeInterval(-TimeInterval(item + 1) * 86_400)
                let final = TaskSummary(
                    identity: identity, sourceScopeID: scope.scopeID,
                    title: "Entrega de exemplo \(item + 1)",
                    rawStatus: TaskStatus.done.rawValue, status: .done,
                    completedAt: completedAt, updatedAt: now
                )
                current.append(final)

                if providerIndex == 1 && item == 0 {
                    first.append(TaskSummary(
                        identity: identity, sourceScopeID: scope.scopeID,
                        title: final.title, rawStatus: TaskStatus.inProgress.rawValue,
                        status: .inProgress, updatedAt: now.addingTimeInterval(-3600)
                    ))
                } else {
                    first.append(final)
                }
            }

            // Baseline first: synthetic old tasks must not create historical alerts.
            _ = try await store.applyCompleteSnapshot(
                scope: scope, tasks: first,
                detectedAt: now.addingTimeInterval(-60)
            )
            _ = try await store.applyCompleteSnapshot(
                scope: scope, tasks: current, detectedAt: now
            )
        }

        return try await DemoDashboardSnapshot(
            metrics: store.metrics(scopes: Set(scopes), now: now),
            events: store.recentEvents(limit: 25)
        )
    }

    private static func displayTitle(_ index: Int) -> String {
        switch index {
        case 0: "Revisar peças de divulgação"
        case 1: "Preparar agenda de conteúdo"
        case 8: "Revisar apresentação visual"
        case 13: "Acompanhar revisão técnica"
        case 16: "Conferir documentação do projeto"
        default: "Tarefa de exemplo \(index + 1)"
        }
    }
}
