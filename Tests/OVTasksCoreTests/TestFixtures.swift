import Foundation
@testable import OVTasksCore

func fixtureScope(
    providerID: String = "trello",
    accountID: String = "account-demo",
    scopeID: String = "board-demo"
) -> WatchedScope {
    WatchedScope(providerID: providerID, accountID: accountID, scopeID: scopeID)
}

func fixtureTask(
    id: String,
    scope: WatchedScope = fixtureScope(),
    workspaceID: String? = "workspace-demo",
    status: TaskStatus = .open,
    rawStatus: String = "To Do",
    due: TaskDeadline? = nil,
    completedAt: Date? = nil,
    updatedAt: Date? = nil,
    assigneeIDs: [String] = []
) -> TaskSummary {
    TaskSummary(
        identity: TaskIdentity(providerID: scope.providerID, accountID: scope.accountID,
                               workspaceID: workspaceID, taskID: id),
        sourceScopeID: scope.scopeID,
        title: "Example task \(id)",
        originalURL: URL(string: "https://example.org/tasks/\(id)"),
        rawStatus: rawStatus, status: status,
        deadline: due, completedAt: completedAt,
        updatedAt: updatedAt, assigneeIDs: assigneeIDs
    )
}
