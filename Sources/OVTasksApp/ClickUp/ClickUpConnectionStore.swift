import Foundation
import SwiftUI

/// Non-secret labels and identifiers are local preferences. Tokens stay in Keychain.
/// One ClickUp account, one Workspace/Space and up to 20 explicitly selected lists
/// in the first native connection workflow. No automatic polling or writes.
struct ClickUpWatchedList: Codable, Hashable, Identifiable {
    let id: String
    let name: String
}

struct ClickUpSavedConnection: Codable {
    let accountID: String
    let displayName: String
    let workspaceID: String
    let spaceID: String
    let lists: [ClickUpWatchedList]
}

struct ClickUpPickerItem: Identifiable, Hashable {
    let id: String
    let name: String
}

@MainActor
final class ClickUpConnectionStore: ObservableObject {
    @Published private(set) var connection: ClickUpSavedConnection?
    @Published private(set) var workspaces: [ClickUpPickerItem] = []
    @Published private(set) var spaces: [ClickUpPickerItem] = []
    @Published private(set) var availableLists: [ClickUpPickerItem] = []
    @Published private(set) var browsingWorkspaceID = ""
    @Published private(set) var browsingSpaceID = ""
    @Published private(set) var draftSelectedListIDs = Set<String>()
    @Published private(set) var metrics: DashboardMetrics?
    @Published private(set) var activities: [PreviewEvent] = []
    @Published private(set) var lastSuccessfulSync: Date?
    @Published private(set) var unmappedStatusCount = 0
    @Published private(set) var isBusy = false
    @Published private(set) var message = "Nenhuma conta ClickUp conectada."
    @Published private(set) var errorMessage: String?

    private let client: ClickUpReadClient
    private let credentials: ClickUpKeychain
    private let defaults: UserDefaults
    private let persistenceKey = "OVTasks.ClickUp.selection.v1"
    private var eventLinks: [String: URL] = [:]
    private var store: SQLiteSnapshotStore?

    init(
        client: ClickUpReadClient = ClickUpReadClient(),
        credentials: ClickUpKeychain = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.credentials = credentials
        self.defaults = defaults
        if let data = defaults.data(forKey: persistenceKey),
           let saved = try? JSONDecoder().decode(ClickUpSavedConnection.self, from: data) {
            connection = saved
            browsingWorkspaceID = saved.workspaceID
            browsingSpaceID = saved.spaceID
            draftSelectedListIDs = Set(saved.lists.map(\.id))
            message = "Seleção anterior restaurada. Atualize manualmente quando desejar."
            Task { [weak self] in await self?.loadCachedData() }
        }
    }

    var isConnected: Bool { connection != nil }
    var hasSelectedLists: Bool { !(connection?.lists.isEmpty ?? true) }
    var watchedCount: Int { connection?.lists.count ?? 0 }

    private func database() throws -> SQLiteSnapshotStore {
        if let store { return store }
        let location = try SQLiteSnapshotStore.defaultDatabaseURL()
        let created = try SQLiteSnapshotStore(databaseURL: location)
        store = created
        return created
    }

    private func userMessage(_ error: Error) -> String {
        switch error {
        case ClickUpAPIError.unauthorized, ClickUpKeychainError.missingCredential:
            return "Autorização inválida ou expirada. Reconecte sua conta."
        case ClickUpAPIError.forbidden:
            return "O ClickUp não permitiu acessar este recurso."
        case ClickUpAPIError.notFound:
            return "Uma lista ou espaço não está mais disponível."
        case ClickUpAPIError.rateLimited(let date):
            if let date, date > Date() {
                return "Limite da API atingido. Tente novamente após \(date.formatted(date: .omitted, time: .shortened))."
            }
            return "Limite da API atingido. Tente novamente mais tarde."
        case ClickUpKeychainError.osStatus:
            return "O Chaves do macOS não permitiu acessar esta credencial."
        case ClickUpAPIError.invalidResponse, ClickUpAPIError.invalidIdentifier,
             ClickUpAPIError.invalidPageCursor,
             ProviderSyncError.exceededPageLimit, ProviderSyncError.exceededTaskLimit:
            return "O ClickUp retornou dados inesperados ou uma lista muito grande. Dados anteriores preservados."
        case CancellationError:
            return "Operação cancelada. Dados anteriores preservados."
        default:
            return "Falha de conexão ou leitura local. Os dados anteriores foram preservados."
        }
    }

    func connect(personalToken: String) async {
        guard !isBusy, !personalToken.isEmpty else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            // Check identity first; never persist an unverified token.
            let profile = try await client.authorizedUser(token: personalToken)
            if let existing = connection, existing.accountID != profile.id.value {
                errorMessage = "Desconecte a conta atual antes de conectar outra."
                return
            }
            let remoteWorkspaces = try await client.workspaces(token: personalToken)
            guard !remoteWorkspaces.isEmpty else {
                errorMessage = "Nenhum workspace autorizado foi encontrado."
                return
            }
            try await credentials.save(personalToken, for: profile.id.value)
            let displayName = profile.username ?? "Conta \(profile.id.value)"
            let old = connection
            connection = ClickUpSavedConnection(
                accountID: profile.id.value, displayName: displayName,
                workspaceID: old?.workspaceID ?? "", spaceID: old?.spaceID ?? "",
                lists: old?.lists ?? []
            )
            persistSelection()
            workspaces = remoteWorkspaces.map { ClickUpPickerItem(id: $0.id.value, name: $0.name) }
            message = "Conta verificada. Selecione um workspace, um espaço e as listas."
            if let saved = connection, !saved.workspaceID.isEmpty {
                browsingWorkspaceID = saved.workspaceID
                browsingSpaceID = saved.spaceID
            }
        } catch {
            errorMessage = userMessage(error)
        }
    }

    func loadWorkspaces() async {
        guard !isBusy, let accountID = connection?.accountID else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let token = try await credentials.token(for: accountID)
            let records = try await client.workspaces(token: token)
            workspaces = records.map { ClickUpPickerItem(id: $0.id.value, name: $0.name) }
            message = "Selecione um workspace para carregar os espaços."
        } catch {
            errorMessage = userMessage(error)
        }
    }

    func chooseWorkspace(_ id: String) async {
        guard !isBusy, !id.isEmpty, workspaces.contains(where: { $0.id == id }),
              let accountID = connection?.accountID else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let token = try await credentials.token(for: accountID)
            let records = try await client.spaces(workspaceID: id, token: token)
            browsingWorkspaceID = id
            browsingSpaceID = ""
            spaces = records.map { ClickUpPickerItem(id: $0.id.value, name: $0.name) }
            availableLists = []
            draftSelectedListIDs = []
            message = "Selecione um espaço para escolher as listas."
        } catch {
            errorMessage = userMessage(error)
        }
    }

    func chooseSpace(_ id: String) async {
        guard !isBusy, !id.isEmpty, spaces.contains(where: { $0.id == id }),
              let accountID = connection?.accountID else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let token = try await credentials.token(for: accountID)
            // Do not expose an incomplete list chooser after a failed folder request.
            let topLevel = try await client.folderlessLists(spaceID: id, token: token)
            let folders = try await client.folders(spaceID: id, token: token)
            guard folders.count <= 100 else { throw ClickUpAPIError.invalidResponse }
            var candidates = topLevel.map {
                ClickUpPickerItem(id: $0.id.value, name: $0.name)
            }
            for folder in folders {
                try Task.checkCancellation()
                let nested = try await client.lists(folderID: folder.id.value, token: token)
                candidates += nested.map {
                    ClickUpPickerItem(id: $0.id.value, name: "\(folder.name) / \($0.name)")
                }
                guard candidates.count <= 2000 else { throw ClickUpAPIError.invalidResponse }
            }
            var seen = Set<String>()
            let unique = candidates.filter { seen.insert($0.id).inserted }
            browsingSpaceID = id
            availableLists = unique.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            if connection?.workspaceID == browsingWorkspaceID &&
               connection?.spaceID == id {
                draftSelectedListIDs = Set(connection?.lists.map(\.id) ?? [])
            } else {
                draftSelectedListIDs = []
            }
            message = "\(availableLists.count) listas disponíveis. Marque as que deseja acompanhar."
        } catch {
            errorMessage = userMessage(error)
        }
    }

    func setDraftList(_ id: String, enabled: Bool) {
        guard availableLists.contains(where: { $0.id == id }) else { return }
        if enabled {
            guard draftSelectedListIDs.count < 20 else {
                errorMessage = "Selecione no máximo 20 listas nesta versão."
                return
            }
            draftSelectedListIDs.insert(id)
        } else {
            draftSelectedListIDs.remove(id)
        }
        errorMessage = nil
    }

    func saveWatchedLists() {
        guard !isBusy, let current = connection,
              !browsingWorkspaceID.isEmpty, !browsingSpaceID.isEmpty,
              !draftSelectedListIDs.isEmpty,
              draftSelectedListIDs.count <= 20 else {
            errorMessage = "Escolha um workspace, um espaço e pelo menos uma lista."
            return
        }
        let lists = availableLists.filter { draftSelectedListIDs.contains($0.id) }
        guard lists.count == draftSelectedListIDs.count else {
            errorMessage = "Recarregue as listas antes de salvar a seleção."
            return
        }
        connection = ClickUpSavedConnection(
            accountID: current.accountID, displayName: current.displayName,
            workspaceID: browsingWorkspaceID, spaceID: browsingSpaceID,
            lists: lists.map { ClickUpWatchedList(id: $0.id, name: $0.name) }
        )
        persistSelection()
        metrics = nil
        activities = []
        eventLinks = [:]
        lastSuccessfulSync = nil
        unmappedStatusCount = 0
        errorMessage = nil
        message = "\(lists.count) listas selecionadas. Use Sincronizar agora."
        Task { [weak self] in await self?.loadCachedData() }
    }

    private func persistSelection() {
        guard let connection, let data = try? JSONEncoder().encode(connection) else { return }
        defaults.set(data, forKey: persistenceKey)
    }

    private func watchedScopes(_ saved: ClickUpSavedConnection) -> Set<WatchedScope> {
        Set(saved.lists.map {
            WatchedScope(providerID: "clickup", accountID: saved.accountID, scopeID: $0.id)
        })
    }

    func loadCachedData() async {
        guard let saved = connection, !saved.lists.isEmpty else { return }
        do {
            let db = try database()
            let scopes = watchedScopes(saved)
            let calculated = try await db.metrics(scopes: scopes, now: Date())
            let rawEvents = try await db.recentEvents(limit: 500)
            var allowed = Set<TaskIdentity>()
            var unknownByIdentity = Set<TaskIdentity>()
            var linkByIdentity: [TaskIdentity: URL] = [:]
            var latest: Date?
            for scope in scopes {
                if let tasks = try await db.snapshot(for: scope) {
                    for task in tasks {
                        allowed.insert(task.identity)
                        if task.status == .unknown { unknownByIdentity.insert(task.identity) }
                        linkByIdentity[task.identity] = task.validatedOriginalURL
                    }
                }
                if let date = try await db.lastSuccessfulSync(for: scope) {
                    latest = max(latest ?? date, date)
                }
            }
            // The events table does not store scope IDs, so filter by identities
            // present in the selected cached snapshots. Unselected data is excluded.
            let scoped = rawEvents.filter { allowed.contains($0.taskIdentity) }
            let mapped = scoped.compactMap(PreviewEvent.from)
            let urls = Dictionary(uniqueKeysWithValues: scoped.compactMap { event in
                linkByIdentity[event.taskIdentity].map { (event.id, $0) }
            })
            guard connection?.accountID == saved.accountID,
                  connection?.workspaceID == saved.workspaceID,
                  connection?.spaceID == saved.spaceID,
                  connection?.lists == saved.lists else { return }
            metrics = calculated
            activities = mapped
            eventLinks = urls
            lastSuccessfulSync = latest
            unmappedStatusCount = unknownByIdentity.count
        } catch {
            errorMessage = userMessage(error)
        }
    }

    func taskURL(for eventID: String) -> URL? { eventLinks[eventID] }

    func reportMissingTaskLink() {
        errorMessage = "Esta tarefa não possui um link ClickUp seguro disponível."
    }

    func synchronize() async {
        guard !isBusy, let saved = connection, !saved.lists.isEmpty else {
            errorMessage = "Selecione e salve ao menos uma lista antes de sincronizar."
            return
        }
        isBusy = true
        errorMessage = nil
        message = "Consultando \(saved.lists.count) listas..."
        defer { isBusy = false }
        do {
            let db = try database()
            var failures = 0
            var successes = 0
            for list in saved.lists {
                if Task.isCancelled { throw CancellationError() }
                let adapter = ClickUpListAdapter(
                    client: client, credentials: credentials,
                    accountID: saved.accountID, workspaceID: saved.workspaceID,
                    listID: list.id,
                    dueTimeZoneID: TimeZone.current.identifier
                )
                let scope = WatchedScope(
                    providerID: "clickup", accountID: saved.accountID, scopeID: list.id
                )
                do {
                    _ = try await SnapshotIngestor.ingest(
                        adapter: adapter, scope: scope, into: db, at: Date()
                    )
                    successes += 1
                } catch {
                    failures += 1
                    errorMessage = userMessage(error)
                    // A failed list retains its last complete snapshot.
                    // Rate limiting should stop further network requests.
                    if case ClickUpAPIError.rateLimited = error { break }
                    if case ClickUpAPIError.unauthorized = error { break }
                }
            }
            // Always render cached data even if only some lists synchronized.
            await loadCachedData()
            if failures == 0 {
                message = "\(successes) listas sincronizadas. Apenas leitura."
            } else {
                message = "\(successes) listas atualizadas; houve falha em outras. Cache preservado."
            }
        } catch {
            errorMessage = userMessage(error)
            message = "Sincronização interrompida."
        }
    }

    func disconnectAndErase() async {
        guard !isBusy, let saved = connection else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            // Erase cached account rows and linked event history before removing
            // the last recoverable credential; if either fails, allow retry.
            let db = try database()
            try await db.removeAccount(providerID: "clickup", accountID: saved.accountID)
            try await credentials.remove(for: saved.accountID)
            defaults.removeObject(forKey: persistenceKey)
            connection = nil
            workspaces = []
            spaces = []
            availableLists = []
            browsingWorkspaceID = ""
            browsingSpaceID = ""
            draftSelectedListIDs = []
            metrics = nil
            activities = []
            eventLinks = [:]
            lastSuccessfulSync = nil
            unmappedStatusCount = 0
            message = "Conta desconectada. Cache e credencial local removidos."
        } catch {
            errorMessage = userMessage(error)
        }
    }
}
