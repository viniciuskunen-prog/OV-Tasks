# Provider adapter contract — v0.1

**Status:** `ProviderAdapter`, `ProviderPage`, `ProviderCapabilities`, `ProviderSyncError` and `SnapshotIngestor` implemented in source on the M2.5 branch. **Verified by direct Swift compilation/execution and synthetic multi-page tests on a physical Mac on 2026-10-22 (success, second-page failure retaining cache, repeated cursor detection).** ClickUp, Trello and NanoTask real adapters and authorization are still planned.

## Boundary

Each provider supplies read-only, already normalized task pages for an **authorized, explicitly watched scope**. It never controls the UI or notifications, and must never hold another provider's credentials. The app's authentication layer will be separate, with access tokens in the macOS Keychain. No remote service or user token is present in M2.5.

```swift
public protocol ProviderAdapter: Sendable {
    var providerID: String { get }
    var capabilities: ProviderCapabilities { get }
    func fetchPage(for scope: WatchedScope, cursor: String?) async throws -> ProviderPage
}

public struct ProviderPage: Sendable {
    public let tasks: [TaskSummary]
    public let nextCursor: String?
}
```

`ProviderCapabilities` declares support for comments, assignments, reliable completion timestamps, incremental synchronization, and source events. It documents capabilities rather than silently manufacturing missing fields.

## Correct sync semantics

1. Validate that the adapter provider matches the watched scope; reject empty scope identifiers.
2. Query page 1, then follow `nextCursor` until `nil`. Never commit page 1 as if it were a complete board.
3. Validate every task belongs to the watched scope and has a stable identity. Reject duplicate identities and repeated pagination cursors.
4. Bound memory/time by `maxPages` (default 100) and `maxTasks` (default 25,000), with cancellation checks between pages.
5. On **fully successful** paging, call `SQLiteSnapshotStore.applyCompleteSnapshot` once. Its transaction updates the snapshot and corresponding change events together.
6. A thrown API error, cancellation, invalid page, repeated cursor or exceeded bound leaves the **last good snapshot** untouched and does not invent task deletions.
7. A first successful scope snapshot is a silent baseline, not a burst of notifications.

The ingestor is a **library function**, not an automatic polling service. Network transport, authorization, rate-limit backoff, provider-specific URL host allowlists and background timers remain to be implemented.

## Fake adapters and tests

The branch includes `Tests/M25StandaloneSmoke.swift`, which creates a synthetic two-page adapter and deliberately fails on its second page or repeats a cursor. No external URLs are fetched, no real credentials exist and tests operate on disposable SQLite files.

To run, follow [M2.5 preview verification](M25_PREVIEW_BRIDGE.md). The CLT-only SwiftPM manifest issue was overcome by installing Xcode 27.1. The core's existing 13 XCTest cases passed, but **these adapter contract cases were exercised by `test-m25-direct.sh`, not by XCTest**. Add equivalent XCTest tests for adapter cases before production provider integrations.

## Extensibility decisions

Version this interface when two real adapters have exercised it. Preserve separate authentication and restrict future community extensions to reviewed, compiled adapters; do not execute arbitrary downloaded scripts, plugins or untrusted declarative URLs by default. A future REST adapter wizard must add HTTPS/domain validation, credential isolation, SSRF prevention and paginated fixture testing.

Stable task IDs are provider/account/workspace/task, with scope ownership validated separately. A task URL is a presentation field, not a key. Real navigation requires a verified HTTPS URL and provider-specific destination policy.
