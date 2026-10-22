import Foundation
import SwiftUI

enum PreviewScenario: String, CaseIterable, Identifiable {
    case overview
    case empty
    case offline
    case reconnect
    case loading

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Resumo"
        case .empty: "Sem tarefas"
        case .offline: "Offline"
        case .reconnect: "Reconectar conta"
        case .loading: "Carregamento"
        }
    }

    var statusText: String {
        switch self {
        case .overview: "Dados ilustrativos"
        case .empty: "Nenhuma atividade ilustrativa"
        case .offline: "Offline simulado · cache fictício"
        case .reconnect: "Autorização simulada expirada"
        case .loading: "Carregamento simulado"
        }
    }

    var statusIcon: String {
        switch self {
        case .overview: "circle.dotted.circle"
        case .empty: "tray"
        case .offline: "wifi.slash"
        case .reconnect: "exclamationmark.arrow.circlepath"
        case .loading: "arrow.triangle.2.circlepath"
        }
    }
}

enum ActivityFilter: String, CaseIterable, Identifiable {
    case all
    case important

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Todas"
        case .important: "Importantes"
        }
    }
}

enum PreviewProvider: String {
    case trello
    case clickup
    case nanoTask

    var name: String {
        switch self {
        case .trello: "Trello"
        case .clickup: "ClickUp"
        case .nanoTask: "NanoTask"
        }
    }

    static func from(_ providerID: String) -> PreviewProvider? {
        switch providerID {
        case "trello": .trello
        case "clickup": .clickup
        case "nanotask": .nanoTask
        default: nil
        }
    }

}

struct PreviewMetrics {
    let pending: Int
    let inProgress: Int
    let overdue: Int
    let completed: Int

    static let sample = PreviewMetrics(pending: 18, inProgress: 6, overdue: 3, completed: 5)
    static let empty = PreviewMetrics(pending: 0, inProgress: 0, overdue: 0, completed: 0)
}

struct PreviewEvent: Identifiable {
    let id: String
    let typeLabel: String
    let taskName: String
    let summary: String
    let provider: PreviewProvider
    let systemImage: String
    let isImportant: Bool
    let occurredAt: Date

    static let samples: [PreviewEvent] = [
        PreviewEvent(
            id: "clickup-status-1",
            typeLabel: "Status alterado",
            taskName: "Revisar apresentação visual",
            summary: "Em andamento → Concluída",
            provider: .clickup,
            systemImage: "checkmark.circle",
            isImportant: false,
            occurredAt: Date(timeIntervalSinceNow: -12 * 60)
        ),
        PreviewEvent(
            id: "trello-due-1",
            typeLabel: "Prazo vencendo",
            taskName: "Preparar peças de divulgação",
            summary: "Vence em 2 horas",
            provider: .trello,
            systemImage: "calendar.badge.exclamationmark",
            isImportant: true,
            occurredAt: Date(timeIntervalSinceNow: -35 * 60)
        ),
        PreviewEvent(
            id: "nanotask-status-1",
            typeLabel: "Nova etapa",
            taskName: "Revisar plano de testes",
            summary: "Em andamento → Em revisão",
            provider: .nanoTask,
            systemImage: "arrow.triangle.branch",
            isImportant: true,
            occurredAt: Date(timeIntervalSinceNow: -72 * 60)
        ),
        PreviewEvent(
            id: "trello-overdue-1",
            typeLabel: "Prazo vencido",
            taskName: "Finalizar revisão de conteúdo",
            summary: "Venceu ontem",
            provider: .trello,
            systemImage: "exclamationmark.circle",
            isImportant: true,
            occurredAt: Date(timeIntervalSinceNow: -4 * 3600)
        ),
        PreviewEvent(
            id: "clickup-comment-1",
            typeLabel: "Novo comentário",
            taskName: "Conferir documentação do projeto",
            summary: "Há uma nova atualização na tarefa",
            provider: .clickup,
            systemImage: "bubble.left",
            isImportant: false,
            occurredAt: Date(timeIntervalSinceNow: -7 * 3600)
        )
    ]
}

extension PreviewEvent {
    static func from(_ change: ChangeEvent) -> PreviewEvent? {
        guard let provider = PreviewProvider.from(change.taskIdentity.providerID) else {
            return nil
        }
        let typeLabel: String
        let summary: String
        let systemImage: String
        let isImportant: Bool
        switch change.kind {
        case .taskCreated:
            typeLabel = "Nova tarefa"
            summary = "Tarefa adicionada à lista"
            systemImage = "plus.circle"
            isImportant = false
        case .completed:
            typeLabel = "Tarefa concluída"
            summary = "Status alterado para Concluída"
            systemImage = "checkmark.circle"
            isImportant = false
        case .statusChanged:
            typeLabel = "Status alterado"
            let from = TaskStatus(rawValue: change.previousValue ?? "")?.label ?? "Anterior"
            let to = TaskStatus(rawValue: change.nextValue ?? "")?.label ?? "Novo"
            summary = "\(from) → \(to)"
            systemImage = "arrow.left.arrow.right"
            isImportant = true
        case .dueDateChanged:
            typeLabel = "Prazo alterado"
            summary = "Data de entrega atualizada"
            systemImage = "calendar.badge.clock"
            isImportant = true
        case .assignmentChanged:
            typeLabel = "Atribuição alterada"
            summary = "Participantes da tarefa atualizados"
            systemImage = "person.badge.plus"
            isImportant = true
        }
        return PreviewEvent(
            id: change.id,
            typeLabel: typeLabel,
            taskName: change.taskTitle,
            summary: summary,
            provider: provider,
            systemImage: systemImage,
            isImportant: isImportant,
            occurredAt: change.detectedAt
        )
    }
}

private extension TaskStatus {
    var label: String {
        switch self {
        case .open: "Pendente"
        case .inProgress: "Em andamento"
        case .blocked: "Bloqueada"
        case .done: "Concluída"
        case .canceled: "Cancelada"
        case .unknown: "Desconhecido"
        }
    }
}

@MainActor
final class PreviewStore: ObservableObject {
    @Published var scenario: PreviewScenario = .overview
    @Published var activityFilter: ActivityFilter = .all
    @Published var selectedEvent: PreviewEvent?

    @Published private(set) var demoReady = false
    @Published private(set) var demoFailure: String?
    @Published private var calculatedMetrics: PreviewMetrics = .empty
    @Published private var calculatedEvents: [PreviewEvent] = []

    init() {
        Task { [weak self] in
            await self?.loadSyntheticCoreDemo()
        }
    }

    private func loadSyntheticCoreDemo() async {
        do {
            let snapshot = try await CoreDemoFactory.build()
            calculatedMetrics = PreviewMetrics(
                pending: snapshot.metrics.pending,
                inProgress: snapshot.metrics.inProgress,
                overdue: snapshot.metrics.overdue,
                completed: snapshot.metrics.completed
            )
            calculatedEvents = snapshot.events.compactMap(PreviewEvent.from)
            demoFailure = nil
            demoReady = true
        } catch {
            demoFailure = "Não foi possível calcular a demonstração."
            demoReady = false
        }
    }

    var metrics: PreviewMetrics {
        switch scenario {
        case .empty, .loading: .empty
        case .overview, .offline, .reconnect: calculatedMetrics
        }
    }

    var activities: [PreviewEvent] {
        guard scenario != .empty && scenario != .loading else { return [] }
        switch activityFilter {
        case .all: return calculatedEvents
        case .important: return calculatedEvents.filter(\.isImportant)
        }
    }
}
