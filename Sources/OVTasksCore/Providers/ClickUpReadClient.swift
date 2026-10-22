import Foundation

// The ClickUp API v2 is intentionally restricted to GET requests on one fixed host.
// This module does not print responses, headers, credentials or private task payloads.
public enum ClickUpAPIError: Error, Equatable {
    case invalidIdentifier
    case invalidPageCursor
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(retryAfter: Date?)
    case serverUnavailable
    case httpStatus(Int)
}

public struct ClickUpHTTPResult: Sendable {
    public let statusCode: Int
    public let data: Data
    public let rateLimitReset: Date?

    public init(statusCode: Int, data: Data, rateLimitReset: Date? = nil) {
        self.statusCode = statusCode
        self.data = data
        self.rateLimitReset = rateLimitReset
    }
}

public protocol ClickUpHTTPTransport: Sendable {
    func get(_ request: URLRequest) async throws -> ClickUpHTTPResult
}

// Authorization must never be forwarded to an unexpected host after a redirect.
private final class ClickUpRejectRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct ClickUpURLSessionTransport: ClickUpHTTPTransport {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration,
                             delegate: ClickUpRejectRedirects(),
                             delegateQueue: nil)
    }

    public func get(_ request: URLRequest) async throws -> ClickUpHTTPResult {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClickUpAPIError.invalidResponse
        }
        let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset")
            .flatMap(TimeInterval.init)
            .map(Date.init(timeIntervalSince1970:))
        return ClickUpHTTPResult(statusCode: http.statusCode, data: data, rateLimitReset: reset)
    }
}

// User IDs, workspace IDs and list IDs may arrive as JSON strings or integers.
// IDs are strings throughout domain storage to avoid truncation and collisions.
public struct ClickUpID: Decodable, Hashable, Sendable, CustomStringConvertible {
    public let value: String

    public var description: String { value }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let string = try? value.decode(String.self), !string.isEmpty {
            self.value = string
        } else if let number = try? value.decode(Int64.self) {
            self.value = String(number)
        } else {
            throw DecodingError.dataCorruptedError(in: value, debugDescription: "Invalid identifier")
        }
    }
}

// Dates from ClickUp v2 are epoch milliseconds; the API sometimes uses JSON strings.
public struct ClickUpEpochMilliseconds: Decodable, Sendable {
    public let date: Date

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        let milliseconds: Int64?
        if let integer = try? value.decode(Int64.self) {
            milliseconds = integer
        } else if let string = try? value.decode(String.self) {
            milliseconds = Int64(string)
        } else {
            milliseconds = nil
        }
        guard let milliseconds, milliseconds >= 0, milliseconds <= 253_402_300_799_999 else {
            throw DecodingError.dataCorruptedError(in: value, debugDescription: "Invalid epoch milliseconds")
        }
        self.date = Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}

public struct ClickUpDirectoryItem: Decodable, Sendable, Identifiable {
    public let id: ClickUpID
    public let name: String
    public let archived: Bool?

    public var displayID: String { id.value }
}

public struct ClickUpProfile: Decodable, Sendable {
    public let id: ClickUpID
    public let username: String?
    public let email: String?
}

public struct ClickUpUserEnvelope: Decodable, Sendable {
    public let user: ClickUpProfile
}

public struct ClickUpDirectoryEnvelope: Decodable, Sendable {
    public let teams: [ClickUpDirectoryItem]?
    public let spaces: [ClickUpDirectoryItem]?
    public let folders: [ClickUpDirectoryItem]?
    public let lists: [ClickUpDirectoryItem]?
}

public struct ClickUpTaskStatus: Decodable, Sendable {
    public let status: String
    public let type: String
}

public struct ClickUpTaskAssignee: Decodable, Sendable {
    public let id: ClickUpID
}

public struct ClickUpTaskList: Decodable, Sendable {
    public let id: ClickUpID
}

public struct ClickUpTaskWire: Decodable, Sendable {
    public let id: ClickUpID
    public let name: String
    public let status: ClickUpTaskStatus
    public let due_date: ClickUpEpochMilliseconds?
    public let due_date_time: Bool?
    public let date_done: ClickUpEpochMilliseconds?
    public let date_closed: ClickUpEpochMilliseconds?
    public let date_updated: ClickUpEpochMilliseconds?
    public let assignees: [ClickUpTaskAssignee]?
    public let url: String?
    public let list: ClickUpTaskList?
}

public struct ClickUpTasksEnvelope: Decodable, Sendable {
    public let tasks: [ClickUpTaskWire]
    public let last_page: Bool?
}

public struct ClickUpReadClient: Sendable {
    private let transport: any ClickUpHTTPTransport
    private static let origin = "https://api.clickup.com"

    public init(transport: any ClickUpHTTPTransport = ClickUpURLSessionTransport()) {
        self.transport = transport
    }

    // Treat all tokens as temporary function parameters. Never persist them here.
    private func fetch<T: Decodable>(
        _ type: T.Type,
        path: String,
        query: [URLQueryItem] = [],
        token: String
    ) async throws -> T {
        guard !token.isEmpty, !token.contains("\n"), !token.contains("\r") else {
            throw ClickUpAPIError.unauthorized
        }
        var components = URLComponents(string: Self.origin)!
        components.path = "/api/v2/" + path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url, url.scheme == "https",
              url.host == "api.clickup.com" else { throw ClickUpAPIError.invalidResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let response = try await transport.get(request)
        switch response.statusCode {
        case 200: break
        case 401: throw ClickUpAPIError.unauthorized
        case 403: throw ClickUpAPIError.forbidden
        case 404: throw ClickUpAPIError.notFound
        case 429: throw ClickUpAPIError.rateLimited(retryAfter: response.rateLimitReset)
        case 500...599: throw ClickUpAPIError.serverUnavailable
        default: throw ClickUpAPIError.httpStatus(response.statusCode)
        }
        do {
            return try JSONDecoder().decode(type, from: response.data)
        } catch {
            // Deliberately omit raw JSON and URL: tasks may be confidential.
            throw ClickUpAPIError.invalidResponse
        }
    }

    private static func safeNumericID(_ value: String) throws -> String {
        guard !value.isEmpty, value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              value.count <= 32 else { throw ClickUpAPIError.invalidIdentifier }
        return value
    }

    public func authorizedUser(token: String) async throws -> ClickUpProfile {
        try await fetch(ClickUpUserEnvelope.self, path: "user", token: token).user
    }

    public func workspaces(token: String) async throws -> [ClickUpDirectoryItem] {
        try await fetch(ClickUpDirectoryEnvelope.self, path: "team", token: token).teams
            ?? []
    }

    public func spaces(workspaceID: String, token: String) async throws -> [ClickUpDirectoryItem] {
        let id = try Self.safeNumericID(workspaceID)
        return try await fetch(ClickUpDirectoryEnvelope.self,
                               path: "team/\(id)/space",
                               query: [URLQueryItem(name: "archived", value: "false")],
                               token: token).spaces ?? []
    }

    public func folders(spaceID: String, token: String) async throws -> [ClickUpDirectoryItem] {
        let id = try Self.safeNumericID(spaceID)
        return try await fetch(ClickUpDirectoryEnvelope.self,
                               path: "space/\(id)/folder",
                               query: [URLQueryItem(name: "archived", value: "false")],
                               token: token).folders ?? []
    }

    public func folderlessLists(spaceID: String, token: String) async throws -> [ClickUpDirectoryItem] {
        let id = try Self.safeNumericID(spaceID)
        return try await fetch(ClickUpDirectoryEnvelope.self,
                               path: "space/\(id)/list",
                               query: [URLQueryItem(name: "archived", value: "false")],
                               token: token).lists ?? []
    }

    public func lists(folderID: String, token: String) async throws -> [ClickUpDirectoryItem] {
        let id = try Self.safeNumericID(folderID)
        return try await fetch(ClickUpDirectoryEnvelope.self,
                               path: "folder/\(id)/list",
                               query: [URLQueryItem(name: "archived", value: "false")],
                               token: token).lists ?? []
    }

    public func tasks(listID: String, page: Int, token: String) async throws -> ClickUpTasksEnvelope {
        let id = try Self.safeNumericID(listID)
        guard page >= 0 && page < 100 else { throw ClickUpAPIError.invalidPageCursor }
        return try await fetch(ClickUpTasksEnvelope.self, path: "list/\(id)/task", query: [
            URLQueryItem(name: "archived", value: "false"),
            URLQueryItem(name: "include_closed", value: "true"),
            URLQueryItem(name: "subtasks", value: "true"),
            URLQueryItem(name: "include_timl", value: "false"),
            URLQueryItem(name: "order_by", value: "id"),
            URLQueryItem(name: "page", value: String(page))
        ], token: token)
    }
}

/// Credential resolution is intentionally separate from the HTTP adapter.
/// The native app must implement this with macOS Keychain, not UserDefaults.
public protocol ClickUpCredentialSource: Sendable {
    func token(for accountID: String) async throws -> String
}

public struct ClickUpListAdapter: ProviderAdapter {
    public let providerID = "clickup"
    public let capabilities = ProviderCapabilities(
        supportsAssignments: true,
        supportsCompletionTimestamp: true
    )

    private let client: ClickUpReadClient
    private let credentials: any ClickUpCredentialSource
    private let accountID: String
    private let workspaceID: String
    private let listID: String
    private let dueTimeZoneID: String
    private let statusMapping: StatusMapping

    public init(
        client: ClickUpReadClient,
        credentials: any ClickUpCredentialSource,
        accountID: String,
        workspaceID: String,
        listID: String,
        dueTimeZoneID: String,
        statusMapping: StatusMapping = StatusMapping([:])
    ) {
        self.client = client
        self.credentials = credentials
        self.accountID = accountID
        self.workspaceID = workspaceID
        self.listID = listID
        self.dueTimeZoneID = dueTimeZoneID
        self.statusMapping = statusMapping
    }

    public func fetchPage(for scope: WatchedScope, cursor: String?) async throws -> ProviderPage {
        guard scope == WatchedScope(providerID: "clickup", accountID: accountID, scopeID: listID),
              !workspaceID.isEmpty,
              TimeZone(identifier: dueTimeZoneID) != nil else {
            throw ProviderSyncError.invalidScope
        }
        let pageIndex: Int
        if let cursor {
            guard let candidate = Int(cursor), candidate >= 0, candidate < 100,
                  String(candidate) == cursor else { throw ClickUpAPIError.invalidPageCursor }
            pageIndex = candidate
        } else {
            pageIndex = 0
        }
        let token = try await credentials.token(for: accountID)
        let wire = try await client.tasks(listID: listID, page: pageIndex, token: token)
        guard wire.tasks.count <= 100 else { throw ClickUpAPIError.invalidResponse }

        var summaries: [TaskSummary] = []
        summaries.reserveCapacity(wire.tasks.count)
        for task in wire.tasks {
            if let actualList = task.list?.id.value, actualList != listID {
                // Tasks in multiple lists are deliberately disabled for this first adapter.
                throw ProviderSyncError.invalidScope
            }
            let rawStatus = task.status.status
            let explicit = statusMapping.status(for: rawStatus)
            let status: TaskStatus
            // Terminal provider category takes priority: no optional name mapping
            // may turn an explicitly completed task back into an open task.
            switch task.status.type.lowercased() {
            case "closed", "done": status = .done
            case "open": status = explicit == .unknown ? .open : explicit
            default: status = explicit // Unknown remains unknown without explicit mapping.
            }

            let deadline: TaskDeadline?
            if let due = task.due_date?.date {
                if task.due_date_time == false {
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = TimeZone(identifier: dueTimeZoneID)!
                    let parts = calendar.dateComponents([.year, .month, .day], from: due)
                    if let y = parts.year, let m = parts.month, let d = parts.day {
                        deadline = .calendarDay(LocalDueDay(year: y, month: m, day: d,
                                                            timeZoneID: dueTimeZoneID))
                    } else {
                        throw ClickUpAPIError.invalidResponse
                    }
                } else {
                    deadline = .at(due)
                }
            } else {
                deadline = nil
            }

            var taskURL: URL?
            if let value = task.url, let url = URL(string: value),
               url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
               ["app.clickup.com", "clickup.com"].contains(url.host?.lowercased() ?? "") {
                taskURL = url
            }
            summaries.append(TaskSummary(
                identity: TaskIdentity(providerID: "clickup", accountID: accountID,
                                       workspaceID: workspaceID, taskID: task.id.value),
                sourceScopeID: listID,
                title: task.name,
                originalURL: taskURL,
                rawStatus: rawStatus,
                status: status,
                deadline: deadline,
                completedAt: status == .done ? (task.date_done?.date ?? task.date_closed?.date) : nil,
                updatedAt: task.date_updated?.date,
                assigneeIDs: task.assignees?.map(\.id.value) ?? []
            ))
        }

        // ClickUp documents 100 tasks per page with a zero-based page index.
        // A full page is conservatively followed by another GET to avoid data loss.
        // An explicit last_page flag, when present, takes precedence.
        let hasMore = wire.last_page.map { !$0 } ?? (wire.tasks.count == 100)
        let nextCursor = hasMore ? String(pageIndex + 1) : nil
        return ProviderPage(tasks: summaries, nextCursor: nextCursor)
    }
}
