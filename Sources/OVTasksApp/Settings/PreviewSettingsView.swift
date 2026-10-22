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

                Text("Os dados continuam fictícios, mas os contadores e eventos agora são calculados pelo núcleo M2 e SQLite temporário. Nenhuma conexão externa é realizada.")
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
                Text("Este protótipo M2.5 não agenda notificações nem sincroniza contas reais.")
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
