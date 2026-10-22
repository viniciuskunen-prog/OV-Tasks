import SwiftUI

struct PreviewSettingsView: View {
    @EnvironmentObject private var preview: PreviewStore
    @EnvironmentObject private var clickUp: ClickUpConnectionStore
    @State private var personalToken = ""
    @State private var confirmingErase = false

    var body: some View {
        Form {
            Section("ClickUp · Conexão local") {
                if let connected = clickUp.connection {
                    Label("Conectado: \(connected.displayName)", systemImage: "checkmark.shield")
                    Text("Acesso somente de leitura pelo OV Tasks. A credencial permanece no Chaves deste Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Conecte seu ClickUp com um token pessoal. Cole-o somente neste aplicativo; não envie por chat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    SecureField(clickUp.isConnected ? "Substituir token pessoal" : "Token pessoal ClickUp",
                                text: $personalToken)
                        .textContentType(.password)
                        .accessibilityLabel("Token pessoal do ClickUp")
                    Button(clickUp.isConnected ? "Verificar novo token" : "Verificar e conectar") {
                        let submitted = personalToken
                        personalToken = ""
                        Task { await clickUp.connect(personalToken: submitted) }
                    }
                    .disabled(personalToken.isEmpty || clickUp.isBusy)
                }

                Text("O token pessoal pode ter mais permissões no ClickUp. Nosso cliente executa apenas GET. OAuth para outros usuários terá fluxo separado.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let error = clickUp.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(clickUp.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if clickUp.isBusy {
                    ProgressView("Operação em andamento")
                        .controlSize(.small)
                }
            }

            if clickUp.isConnected {
                Section("Listas acompanhadas · Escolha explícita") {
                    HStack {
                        Text("\(clickUp.watchedCount) listas salvas")
                            .font(.caption)
                        Spacer()
                        Button("Carregar Workspaces") {
                            Task { await clickUp.loadWorkspaces() }
                        }
                        .disabled(clickUp.isBusy)
                    }

                    if !clickUp.workspaces.isEmpty {
                        Picker("Workspace", selection: Binding(
                            get: { clickUp.browsingWorkspaceID },
                            set: { id in Task { await clickUp.chooseWorkspace(id) } }
                        )) {
                            Text("Selecione").tag("")
                            ForEach(clickUp.workspaces) { workspace in
                                Text(workspace.name).tag(workspace.id)
                            }
                        }
                    }

                    if !clickUp.browsingWorkspaceID.isEmpty && clickUp.spaces.isEmpty {
                        Button("Carregar Spaces deste Workspace") {
                            Task { await clickUp.chooseWorkspace(clickUp.browsingWorkspaceID) }
                        }
                        .disabled(clickUp.isBusy)
                    }

                    if !clickUp.spaces.isEmpty {
                        Picker("Space", selection: Binding(
                            get: { clickUp.browsingSpaceID },
                            set: { id in Task { await clickUp.chooseSpace(id) } }
                        )) {
                            Text("Selecione").tag("")
                            ForEach(clickUp.spaces) { space in
                                Text(space.name).tag(space.id)
                            }
                        }
                    }

                    if !clickUp.browsingSpaceID.isEmpty && clickUp.availableLists.isEmpty {
                        Button("Carregar listas deste Space") {
                            Task { await clickUp.chooseSpace(clickUp.browsingSpaceID) }
                        }
                        .disabled(clickUp.isBusy)
                    }

                    if !clickUp.availableLists.isEmpty {
                        Text("Marque até 20 listas. Nada será sincronizado sem salvar a seleção.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(Array(clickUp.availableLists.prefix(200))) { list in
                                    Toggle(list.name, isOn: Binding(
                                        get: { clickUp.draftSelectedListIDs.contains(list.id) },
                                        set: { clickUp.setDraftList(list.id, enabled: $0) }
                                    ))
                                    .toggleStyle(.checkbox)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 150)
                        Button("Salvar seleção") {
                            clickUp.saveWatchedLists()
                        }
                        .disabled(clickUp.isBusy || clickUp.draftSelectedListIDs.isEmpty)
                        if clickUp.availableLists.count > 200 {
                            Text("Mostrando as primeiras 200 listas. Refinar seleção será necessário para espaços maiores.")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    if let connection = clickUp.connection, !connection.lists.isEmpty {
                        Text(connection.lists.map(\.name).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Section("Sincronização manual e privacidade") {
                    HStack {
                        Button("Sincronizar agora") {
                            Task { await clickUp.synchronize() }
                        }
                        .disabled(clickUp.isBusy || !clickUp.hasSelectedLists)
                        if let last = clickUp.lastSuccessfulSync {
                            Text("Último cache atualizado: \(last.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("O primeiro carregamento cria uma linha de base, sem falsos alertas históricos. O cache fica no Application Support deste Mac. Não há sincronização automática.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("Desconectar e apagar dados locais", role: .destructive) {
                        confirmingErase = true
                    }
                    .disabled(clickUp.isBusy)
                }
            }

            Section("Modo de demonstração") {
                Picker("Cenário fictício", selection: $preview.scenario) {
                    ForEach(PreviewScenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                Picker("Filtro de eventos", selection: $preview.activityFilter) {
                    ForEach(ActivityFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                Text("Se o ClickUp estiver conectado, o painel usa somente dados reais/cache. Os cenários fictícios ficam ocultos até a desconexão.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Outras integrações e alertas") {
                Label("Trello e NanoTask ainda não conectam contas.", systemImage: "link.badge.plus")
                    .foregroundStyle(.secondary)
                Label("Notificações e sincronização automática ainda não estão habilitadas.", systemImage: "bell.slash")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 590, height: 650)
        .confirmationDialog(
            "Desconectar ClickUp e apagar cache e credencial deste Mac?",
            isPresented: $confirmingErase,
            titleVisibility: .visible
        ) {
            Button("Desconectar e apagar", role: .destructive) {
                Task { await clickUp.disconnectAndErase() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação remove as tarefas e eventos armazenados localmente para essa conta. Não altera tarefas no ClickUp.")
        }
    }
}
