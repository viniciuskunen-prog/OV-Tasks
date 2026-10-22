import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var preview: PreviewStore

    private let panelWidth: CGFloat = 428
    private let panelHeight: CGFloat = 584

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            dashboard
            Divider()
                .padding(.top, 14)

            activityHeader

            if preview.scenario == .loading {
                placeholder(
                    symbol: "arrow.triangle.2.circlepath",
                    title: "Carregando dados fictícios",
                    explanation: "Estado de carregamento para avaliação do layout."
                )
            } else if preview.activities.isEmpty {
                placeholder(
                    symbol: "tray",
                    title: preview.scenario == .empty ? "Nenhuma tarefa por aqui" : "Sem atividade neste filtro",
                    explanation: preview.scenario == .empty
                        ? "Conecte um serviço futuramente para acompanhar suas tarefas."
                        : "Não há eventos importantes nesta amostra."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(preview.activities) { event in
                            ActivityRow(event: event) {
                                preview.selectedEvent = event
                            }

                            if event.id != preview.activities.last?.id {
                                Divider()
                                    .padding(.leading, 38)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            footer
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(.regularMaterial)
        .alert(item: $preview.selectedEvent) { event in
            Alert(
                title: Text("Link de demonstração"),
                message: Text(
                    "“\(event.taskName)” é uma tarefa fictícia do \(event.provider.name). " +
                    "Quando a integração estiver pronta, este botão abrirá o link real da tarefa."
                ),
                dismissButton: .default(Text("Entendi"))
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("OV Tasks")
                    .font(.system(size: 16, weight: .semibold))
                Text("Protótipo M1 · Dados fictícios")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Menu {
                ForEach(PreviewScenario.allCases) { scenario in
                    Button {
                        preview.scenario = scenario
                    } label: {
                        if preview.scenario == scenario {
                            Label(scenario.title, systemImage: "checkmark")
                        } else {
                            Text(scenario.title)
                        }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .help("Alternar cenário da prévia")
            .accessibilityLabel("Alternar cenário da prévia")

            SettingsLink {
                Image(systemName: "gearshape")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Configurações do protótipo")
            .accessibilityLabel("Abrir configurações")
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: preview.scenario.statusIcon)
                Text(preview.scenario.statusText)
                    .lineLimit(1)
                Spacer()
                Text("Sem sync real")
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(preview.scenario == .offline || preview.scenario == .reconnect
                ? Color.orange : Color.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 74), spacing: 8), count: 4),
                spacing: 8
            ) {
                MetricCard(label: "Pendentes", value: preview.metrics.pending, symbol: "tray.full")
                MetricCard(label: "Em curso", value: preview.metrics.inProgress, symbol: "clock")
                MetricCard(label: "Atrasadas", value: preview.metrics.overdue, symbol: "exclamationmark.circle")
                MetricCard(label: "Concluídas", value: preview.metrics.completed, symbol: "checkmark.circle")
            }

            if preview.scenario == .offline {
                banner(
                    symbol: "wifi.slash",
                    message: "Você está vendo dados de cache simulados. As atualizações ficam pausadas."
                )
            } else if preview.scenario == .reconnect {
                banner(
                    symbol: "lock.trianglebadge.exclamationmark",
                    message: "ClickUp precisa ser reconectado (cenário fictício)."
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var activityHeader: some View {
        HStack(spacing: 12) {
            Text("Atividade recente")
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            Picker("Eventos", selection: $preview.activityFilter) {
                ForEach(ActivityFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 165)
        }
        .padding(.horizontal, 17)
        .padding(.top, 14)
        .padding(.bottom, 9)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.dotted")
                .foregroundStyle(.secondary)
            Text("3 fontes de demonstração")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Sair") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
    }

    private func banner(symbol: String, message: String) -> some View {
        Label(message, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private func placeholder(symbol: String, title: String, explanation: String) -> some View {
        VStack(spacing: 9) {
            if preview.scenario == .loading {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 26))
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}

private struct MetricCard: View {
    let label: String
    let value: Int
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct ActivityRow: View {
    let event: PreviewEvent
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: event.systemImage)
                .font(.system(size: 15))
                .foregroundStyle(event.isImportant ? Color.orange : Color.secondary)
                .frame(width: 25, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(event.typeLabel)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(event.occurredAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Text(event.taskName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(event.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Button(action: onOpen) {
                    HStack(spacing: 5) {
                        Text("Ver no \(event.provider.name)")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .font(.caption)
                }
                .buttonStyle(.link)
                .help("Demonstração: mostra o comportamento futuro do link para a tarefa")
                .accessibilityLabel("Ver no \(event.provider.name), demonstração de \(event.taskName)")
                .padding(.top, 3)
            }
        }
        .padding(.vertical, 10)
    }
}
