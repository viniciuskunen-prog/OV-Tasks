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
            taskName: "Banner — Creatina",
            summary: "Em andamento → Concluída",
            provider: .clickup,
            systemImage: "checkmark.circle",
            isImportant: false,
            occurredAt: Date(timeIntervalSinceNow: -12 * 60)
        ),
        PreviewEvent(
            id: "trello-due-1",
            typeLabel: "Prazo vencendo",
            taskName: "Programação de sexta-feira",
            summary: "Vence em 2 horas",
            provider: .trello,
            systemImage: "calendar.badge.exclamationmark",
            isImportant: true,
            occurredAt: Date(timeIntervalSinceNow: -35 * 60)
        ),
        PreviewEvent(
            id: "nanotask-status-1",
            typeLabel: "Nova etapa",
            taskName: "Revisão de testes de integração",
            summary: "Em andamento → Em revisão",
            provider: .nanoTask,
            systemImage: "arrow.triangle.branch",
            isImportant: true,
            occurredAt: Date(timeIntervalSinceNow: -72 * 60)
        ),
        PreviewEvent(
            id: "trello-overdue-1",
            typeLabel: "Prazo vencido",
            taskName: "Atualizar campanha de lançamento",
            summary: "Venceu ontem",
            provider: .trello,
            systemImage: "exclamationmark.circle",
            isImportant: true,
            occurredAt: Date(timeIntervalSinceNow: -4 * 3600)
        ),
        PreviewEvent(
            id: "clickup-comment-1",
            typeLabel: "Novo comentário",
            taskName: "Revisão da página institucional",
            summary: "Há uma nova atualização na tarefa",
            provider: .clickup,
            systemImage: "bubble.left",
            isImportant: false,
            occurredAt: Date(timeIntervalSinceNow: -7 * 3600)
        )
    ]
}

@MainActor
final class PreviewStore: ObservableObject {
    @Published var scenario: PreviewScenario = .overview
    @Published var activityFilter: ActivityFilter = .all
    @Published var selectedEvent: PreviewEvent?

    var metrics: PreviewMetrics {
        switch scenario {
        case .empty, .loading: .empty
        case .overview, .offline, .reconnect: .sample
        }
    }

    var activities: [PreviewEvent] {
        guard scenario != .empty && scenario != .loading else { return [] }
        switch activityFilter {
        case .all: return PreviewEvent.samples
        case .important: return PreviewEvent.samples.filter(\.isImportant)
        }
    }
}
