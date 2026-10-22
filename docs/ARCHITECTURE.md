# System architecture (proposed)

**Status: proposal — components not yet implemented.**

## Runtime
A Swift/SwiftUI macOS menu-bar-only app targeting macOS 14+ (target to validate on first native build). Use `MenuBarExtra` or an `NSStatusItem` bridge only if status badge behavior requires it; SwiftUI window for Settings; `UserNotifications`, `URLSession`, `Security`/Keychain and a tested local SQLite-backed persistence layer. Prefer a Swift Package for business logic to keep it testable independent of AppKit. No Electron. No external server or Mac mini required.

The **process** must remain alive when the popover closes. Sync scheduling must not depend on popover visibility. The system cannot guarantee background execution when the Mac sleeps, is shut down, or networking is restricted.

## Responsibilities

| Module | Owns | Must not own |
| --- | --- | --- |
| AppShell / Settings | Menu bar, popover, navigation, permission UI | Provider HTTP code |
| Presentation | View models, visible cards/feed/empty states | Authentication tokens |
| Domain | Pure models, counters, status mapping, event diff | Network or UI |
| ConnectorRegistry | Adapter discovery and declared capabilities | Provider-specific display logic |
| SyncCoordinator | Scheduling, pagination, retries, stale status and cursors | Notification text rendering |
| EventEngine | Snapshot diff, event normalization, deduplication | Provider credentials |
| AlertEngine | Urgency rules, quiet hours, delivery ledger | Fetching source data |
| Persistence | Scoped cache, snapshots, events, migrations | Secret storage |
| CredentialStore | Keychain item lifecycle and identity references | Raw-task storage |
| Connectors | Auth integration, scoped fetch, normalization, task URL | AppKit UI |
| Diagnostics | Redacted operational health and support bundle | Private payload dumps |

## Suggested repository layout
```text
Sources/
  OVTasksApp/{OVTasksApp.swift,MenuBar/,Settings/,ViewModels/}
  OVTasksCore/{Models/,Metrics/,Events/,Sync/,Notifications/,Persistence/,Security/}
  OVTasksConnectors/{ClickUp/,Trello/,NanoTask/}
Tests/
  CoreTests/
  ConnectorContractTests/
  NotificationTests/
Tests/Fixtures/{clickup,trello,nanotask}/
docs/
README.md
CONTRIBUTING.md
AGENTS.md
.gitignore
```
Only create paths when their code is implemented; this is a target design, not an existing tree.

## Data flow
1. User authorizes a provider; token/refresh material goes to Keychain only.
2. User selects permitted workspaces/boards/lists and mapping preferences.
3. Coordinator requests paginated snapshots through a provider adapter, respecting provider quotas.
4. Normalize to canonical task models and atomically commit snapshot + cursor.
5. Diff against previous baseline and calculate alert candidates.
6. Deduplicate, apply urgency/quiet-hour rules, persist delivery ledger.
7. Update dashboard and (if allowed) schedule local macOS notifications.
8. Click event opens a validated source URL.

## Offline, concurrency, errors
Serial updates per account/scope; avoid overlapping polls; async networking off main thread; atomic local writes; cooperative cancellation; exponential backoff with jitter for retryable errors, honor server retry-after; pause expired authorizations, surface “Reconnect”; isolate provider outages. Do not drop last good snapshot on HTTP failure.

## Extendability
Define a stable typed ProviderAdapter contract (see [PROVIDER_CONTRACT](PROVIDER_CONTRACT.md)). v1 embeds reviewed adapters. Later declarative REST integrations may be supported via an explicitly designed sandboxed parser; never directly load unknown dynamic code from an untrusted directory.

## Optional later architecture
An opt-in hosted relay may facilitate webhook ingestion and confidential OAuth grants. Its costs, authentication, event verification, data retention and threat model require a separate design/release. Local mode must remain viable.

## Open engineering choices
SQLite3 directly vs reviewed SQLite wrapper, final menu bar primitive, login-item lifecycle, signing/notarization and minimum macOS version require spikes; don't claim benchmark or compatibility until tested.
