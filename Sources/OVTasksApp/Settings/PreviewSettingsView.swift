import SwiftUI

struct PreviewSettingsView: View {
    @EnvironmentObject private var preview: PreviewStore

    var body: some View {
        Form {
            Section("Protótipo") {
                Picker("Cenário para testar", selection: $preview.scenario) {
                    ForEach(PreviewScenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                Picker("Filtro de eventos", selection: $preview.activityFilter) {
                    ForEach(ActivityFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                Text("Todos os nomes, contadores, mudanças e prazos são fictícios. Nenhum acesso externo é realizado.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Integrações planejadas") {
                providerRow("ClickUp")
                providerRow("Trello")
                providerRow("NanoTask")
                Text("Conectar contas estará disponível depois que os adaptadores e fluxos de autenticação forem implementados.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Alertas planejados") {
                Label("Notificações do macOS ainda não estão habilitadas.", systemImage: "bell.slash")
                    .foregroundStyle(.secondary)
                Text("O estágio M1 é somente uma prévia visual. Não agenda notificações nem executa sincronização.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 510, height: 460)
    }

    private func providerRow(_ name: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text("Não conectado")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}
