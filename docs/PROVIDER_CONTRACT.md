# Provider adapter contract (design)

**Not implemented.** Version this contract after the first two real adapters demonstrate adequate generality.

## Goals
A provider supplies just enough information for dashboard metrics, feed events and links. A provider does not own UI presentation, notification permissions or the global cache. All connector operations are asynchronous and cancelable.

## Proposed Swift sketch
```swift
struct ProviderCapabilities: Sendable {
    let supportsComments: Bool
    let supportsAssignments: Bool
    let supportsCompletionTimestamp: Bool
    let supportsIncrementalSync: Bool
    let supportsEvents: Bool
}

struct WatchedScope: Sendable, Hashable {
    let providerID: String
    let accountID: String
    let sourceScopeID: String
}

struct SnapshotPage: Sendable {
    let tasks: [TaskSummary]
    let nextPageCursor: String?
    let isComplete: Bool
}

protocol ProviderAdapter: Sendable {
    var id: String { get }
    var capabilities: ProviderCapabilities { get }

    func availableScopes(accountID: String) async throws -> [WatchedScope]
    func fetchPage(
        scope: WatchedScope,
        cursor: String?,
        since: Date?
    ) async throws -> SnapshotPage
    func validatedTaskURL(for task: TaskSummary) -> URL?
}
```
`TaskSummary` will be the pure domain type specified in [DATA_MODEL](DATA_MODEL.md); do not compile this sketch as-is without defining it. Authentication is owned by a separate per-provider `AuthorizationProvider` that uses the Keychain, not an adapter storing plaintext secrets.

## Adapter quality bar
1. Fetch only explicitly watched resources, honoring account authorization.
2. Cap page sizes, implement documented pagination, and never silently return only the first page.
3. Preserve source IDs and timestamps. Normalize status via user-configurable mapping where necessary.
4. Explicitly declare absent/unsupported capabilities.
5. Validate task links; do not accept arbitrary file/javascript URL schemes.
6. Consistently classify `unauthorized`, `rateLimited(retryAfter)`, `transient`, `notFound`, `malformedPayload`; do not treat all failures as “0 tasks.”
7. Ship synthetic fixtures that cover pagination, empty scopes, custom statuses, inaccessible resources and date-only deadlines.
8. Provide a README and integration test instructions; no real API tokens or customer tasks in fixtures.

## Extensibility roadmap
Built-in adapters compiled with the app in v1; new providers added via reviewed PR and feature flags. A later declarative JSON/REST mapping system would need schema validation, allowlisted HTTPS domains, quota controls, no eval/shell/dynamic downloaded code and secure per-provider secret handling. Custom webhooks require their own authenticated receiver or relay.

## Stable identifiers
Use `providerID/accountID/scopeID/taskID` instead of task title or task URL for joins and deduplication. Scope removal must not leak stale tasks as newly assigned.
