import Foundation
import XCTest
@testable import OVTasksCore

private struct StubClickUpTransport: ClickUpHTTPTransport {
    let reply: @Sendable (URLRequest) throws -> ClickUpHTTPResult

    func get(_ request: URLRequest) async throws -> ClickUpHTTPResult {
        try reply(request)
    }
}

private struct StubClickUpCredentials: ClickUpCredentialSource {
    let value: String

    func token(for accountID: String) async throws -> String {
        guard accountID == "22" else { throw ClickUpKeychainError.missingCredential }
        return value
    }
}

final class ClickUpReadTests: XCTestCase {
    private let scope = WatchedScope(providerID: "clickup", accountID: "22", scopeID: "1234")

    private static func json(_ dictionary: [String: Any]) -> Data {
        // Only synthetic values. Never fixture-dump a live provider response.
        try! JSONSerialization.data(withJSONObject: dictionary)
    }

    private func task(_ id: Int, name: String = "Example", type: String = "open") -> [String: Any] {
        [
            "id": String(id), "name": name,
            "status": ["status": "Raw arbitrary label", "type": type],
            "date_updated": "1800000000000",
            "list": ["id": "1234"],
            "assignees": [["id": 47]]
        ]
    }

    private func makeAdapter(_ transport: StubClickUpTransport) -> ClickUpListAdapter {
        ClickUpListAdapter(
            client: ClickUpReadClient(transport: transport),
            credentials: StubClickUpCredentials(value: "fixture-only"),
            accountID: "22", workspaceID: "99", listID: "1234",
            dueTimeZoneID: "America/Sao_Paulo",
            statusMapping: StatusMapping(["Raw arbitrary label": .inProgress])
        )
    }

    func testReadOnlyDiscoveryAndIdentityParsing() async throws {
        let transport = StubClickUpTransport { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "fixture-only")
            XCTAssertEqual(request.url?.host, "api.clickup.com")
            switch request.url?.path {
            case "/api/v2/user":
                return ClickUpHTTPResult(statusCode: 200, data: Self.json([
                    "user": ["id": 22, "username": "Test user"]
                ]))
            case "/api/v2/team":
                return ClickUpHTTPResult(statusCode: 200, data: Self.json([
                    "teams": [["id": "99", "name": "Example Workspace"]]
                ]))
            case "/api/v2/team/99/space":
                return ClickUpHTTPResult(statusCode: 200, data: Self.json([
                    "spaces": [["id": 77, "name": "Studio"]]
                ]))
            case "/api/v2/space/77/folder":
                return ClickUpHTTPResult(statusCode: 200, data: Self.json([
                    "folders": [["id": "5", "name": "Clients"]]
                ]))
            case "/api/v2/folder/5/list":
                return ClickUpHTTPResult(statusCode: 200, data: Self.json([
                    "lists": [["id": "1234", "name": "Tasks"]]
                ]))
            default:
                return ClickUpHTTPResult(statusCode: 404, data: Data())
            }
        }
        let client = ClickUpReadClient(transport: transport)
        let profile = try await client.authorizedUser(token: "fixture-only")
        XCTAssertEqual(profile.id.value, "22")
        let workspaces = try await client.workspaces(token: "fixture-only")
        let spaces = try await client.spaces(workspaceID: "99", token: "fixture-only")
        let folders = try await client.folders(spaceID: "77", token: "fixture-only")
        let lists = try await client.lists(folderID: "5", token: "fixture-only")
        XCTAssertEqual(workspaces.first?.id.value, "99")
        XCTAssertEqual(spaces.first?.id.value, "77")
        XCTAssertEqual(folders.first?.id.value, "5")
        XCTAssertEqual(lists.first?.id.value, "1234")
    }

    func testStatusDateAndLinkNormalization() async throws {
        var example = task(10)
        example["due_date"] = "1800000000000"
        example["due_date_time"] = false
        example["url"] = "https://app.clickup.com/t/10"
        example["date_done"] = "1800000000000"
        var completed = task(11, name: "Finished", type: "closed")
        completed["date_done"] = "1800000000000"
        completed["url"] = "https://unexpected.example/redirect"
        let payload = Self.json(["tasks": [example, completed], "last_page": true])
        let client = makeAdapter(StubClickUpTransport { request in
            XCTAssertEqual(request.httpMethod, "GET")
            return ClickUpHTTPResult(statusCode: 200, data: payload)
        })
        let result = try await client.fetchPage(for: scope, cursor: nil)
        XCTAssertNil(result.nextCursor)
        XCTAssertEqual(result.tasks.count, 2)
        XCTAssertEqual(result.tasks[0].status, .inProgress)
        XCTAssertEqual(result.tasks[0].identity.workspaceID, "99")
        XCTAssertEqual(result.tasks[0].originalURL?.host, "app.clickup.com")
        if case .calendarDay(let day)? = result.tasks[0].deadline {
            XCTAssertEqual(day.timeZoneID, "America/Sao_Paulo")
        } else { XCTFail("Date-only deadline should be a local calendar day") }
        XCTAssertEqual(result.tasks[1].status, .done,
                       "ClickUp terminal status must override arbitrary name mapping.")
        XCTAssertNil(result.tasks[1].originalURL)
        XCTAssertNotNil(result.tasks[1].completedAt,
                        "A completed task's real completion timestamp must be retained.")
    }

    func testCompletePaginationThenFailureDoesNotEraseCache() async throws {
        let firstPage = Self.json(["tasks": (0..<100).map { task($0) }, "last_page": false])
        let secondPage = Self.json(["tasks": [task(100)], "last_page": true])
        let goodTransport = StubClickUpTransport { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(where: { $0.name == "include_closed" && $0.value == "true" }))
            XCTAssertTrue(query.contains(where: { $0.name == "subtasks" && $0.value == "true" }))
            let page = query.first(where: { $0.name == "page" })?.value
            return ClickUpHTTPResult(statusCode: 200, data: page == "0" ? firstPage : secondPage)
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClickUpTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteSnapshotStore(databaseURL: root.appendingPathComponent("cache.sqlite"))
        let initial = try await SnapshotIngestor.ingest(
            adapter: makeAdapter(goodTransport), scope: scope, into: store,
            at: Date(timeIntervalSince1970: 1_800_000_001)
        )
        XCTAssertTrue(initial.isEmpty, "A first complete snapshot is a silent baseline.")
        let firstSnapshot = try await store.snapshot(for: scope)
        XCTAssertEqual(firstSnapshot?.count, 101)

        let failedTransport = StubClickUpTransport { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "page" })?.value
            if page == "0" { return ClickUpHTTPResult(statusCode: 200, data: firstPage) }
            return ClickUpHTTPResult(statusCode: 429, data: Data(),
                                      rateLimitReset: Date(timeIntervalSince1970: 1_800_000_100))
        }
        do {
            _ = try await SnapshotIngestor.ingest(
                adapter: makeAdapter(failedTransport), scope: scope, into: store,
                at: Date(timeIntervalSince1970: 1_800_000_010)
            )
            XCTFail("429 must abort without updating the stored snapshot")
        } catch ClickUpAPIError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, Date(timeIntervalSince1970: 1_800_000_100))
        }
        let restored = try await store.snapshot(for: scope)
        XCTAssertEqual(restored?.count, 101)
        XCTAssertEqual(restored?.map(\.identity.taskID), firstSnapshot?.map(\.identity.taskID))
    }

    func testProviderRejectsInvalidScopeAndUnknownStatusWithoutGuessing() async throws {
        let synthetic = Self.json(["tasks": [task(30, type: "custom")], "last_page": true])
        let adapter = ClickUpListAdapter(
            client: ClickUpReadClient(transport: StubClickUpTransport { _ in
                ClickUpHTTPResult(statusCode: 200, data: synthetic)
            }),
            credentials: StubClickUpCredentials(value: "fixture-only"),
            accountID: "22", workspaceID: "99", listID: "1234",
            dueTimeZoneID: "America/Sao_Paulo"
        )
        let response = try await adapter.fetchPage(for: scope, cursor: nil)
        XCTAssertEqual(response.tasks[0].status, .unknown)
        do {
            _ = try await adapter.fetchPage(
                for: WatchedScope(providerID: "clickup", accountID: "22", scopeID: "wrong"),
                cursor: nil
            )
            XCTFail("Scope mismatch must be rejected")
        } catch ProviderSyncError.invalidScope { }
        do {
            _ = try await adapter.fetchPage(for: scope, cursor: "-1")
            XCTFail("Invalid cursor should fail")
        } catch ClickUpAPIError.invalidPageCursor { }
    }
}
