# M2.5 — bridge between M2 core and macOS preview

**Status: source prepared in a stacked development branch. Native compilation, runtime QA and XCTest have not been performed for M2.5.**

## Why this milestone exists

M1 proved the menu bar UX with hard-coded fixture numbers/events. M2 introduced normalized task models, scoped metrics, change detection and SQLite. M2.5 connects them **without presenting test data as a connected account**. It also establishes the interface real provider adapters will implement, without writing Trello/ClickUp/NanoTask HTTP calls yet.

M2.5 **depends on M2**. The branch `feat/m25-preview-bridge` was created from `feat/m2-domain-store`; its eventual PR targets the M2 branch, not `main`. Do not merge the child PR before the M2 parent is ready, and do not accidentally merge unvalidated parent code.

## Implemented in source

1. `Sources/OVTasksCore/Demo/CoreDemoFactory.swift`: generates 18 synthetic pending tasks, six in progress, three overdue and five completed in the previous 168 hours across three fake provider scopes. Writes a first silent baseline and changed second snapshots to a **randomly named temporary SQLite database**, then reads counters and four change events from the real M2 store. Removes the test directory after assembling the display model. This is **not an API sync**.
2. `Sources/OVTasksApp/Preview/PreviewData.swift`: converts core metrics/change events into compact SwiftUI presentation rows, while keeping All/Important filters and the five M1 view scenarios. Observable changes load asynchronously. On failure, the UI reports a local demo error instead of claiming a successful sync.
3. `Sources/OVTasksApp/Views/DashboardView.swift` and `Settings/PreviewSettingsView.swift`: clearly state that this is a **synthetic** preview; show a loading state while computing the core demo. Source-link buttons remain non-navigating informational demo dialogs.
4. `Sources/OVTasksCore/Providers/ProviderAdapter.swift`: typed read-only provider capability/page interface, safe completion of pagination, scope/identity checks and atomic store commit only after all pages succeed. A partial provider response cannot erase a prior good scope.
5. `build.sh`: compiles the existing SwiftUI menu app alongside the core sources with direct `swiftc` and system SQLite3. Does not run `swift test` or install globally.
6. `Tests/M25StandaloneSmoke.swift` and `test-m25-direct.sh`: synthetic real-core integration runner with checks for demo counters/events, successful two-page snapshot, second-page failure preserving cache and repeated-cursor rejection.

## Validate locally on an Apple Silicon Mac

From the checkout:

```zsh
cd ~/Projects/OV-Tasks
git fetch origin
git switch feat/m25-preview-bridge 2>/dev/null || git switch --track origin/feat/m25-preview-bridge
git pull --ff-only

# Step 1: Compile and execute a non-UI integration runner (no SwiftPM manifest):
zsh ./test-m25-direct.sh

# Step 2: If the smoke is green, compile and launch the menu bar preview:
zsh ./build.sh
open ./build/OVTasks.app
```

Expected **if successful**, not yet observed:

```text
PASS: core-backed demo metrics 18 / 6 / 3 / 5 and four change events
PASS: adapter pagination + baseline, atomic preservation on failure, cursor loop detection
RESULT: M2.5 standalone smoke PASS.
```

The app should show a **M2.5 / fictitious data** label, four calculated numbers, recent simulated status/completion/due/assignment changes, filter working, and simulated links. Confirm the original Empty, Offline, Reconnect and Loading scenarios still work, and Quit functions. Do not claim UI was built or run until the actual Mac terminal and screenshots are supplied.

## Explicit non-goals / known risks

- No real ClickUp/Trello/NanoTask account sign-in, webhooks, API polling, OAuth, Keychain credentials, remote server, provider link navigation, live notifications or running scheduling timer.
- No persistent user SQLite history. Preview SQLite is random and disposable; a future genuine cache uses Application Support only after connection and privacy controls.
- M2 `swift test` / XCTest remains blocked by the contributor's local SwiftPM manifest-link issue; the direct Swift runner does **not replace XCTest**.
- Native keyboard navigation (#3) and formatting refinements (#4) remain separate pre-release items.
- Core change events currently cover status, completion, assignment, due-date changes and creation; **due-soon and overdue notifications are not yet event-engine features**.
- Provider adapters must never write a partial page to the cache; retry/backoff and real API pagination limits will be added per provider later.
- Event feed shows source names, but real task URLs are not provided until secure source-specific adapters exist.

## Acceptance

The stacked PR remains a draft until both the direct runner and the macOS menu UI compile and the owner reviews the preview. M2's parent still needs its full QA gate or an explicitly revised documented one. No GitHub Actions used.
