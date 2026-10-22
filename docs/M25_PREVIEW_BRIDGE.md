# M2.5 — bridge between M2 core and macOS preview

**Status (2026-10-22): direct-swiftc M2.5 integration smoke PASS, native macOS bundle compiled and launched, dark-mode Overview/Important screenshots reviewed successfully. Parent M2 PR #5 has now passed native XCTest (13/13, zero failures) and was merged into `main`. M2.5 PR #6 was retargeted and synchronized with `main` at branch head `307bf0b` on 2026-10-22; its final review/merge is separate.**

## Why this milestone exists

M1 proved the menu bar UX with hard-coded fixture numbers/events. M2 introduced normalized task models, scoped metrics, change detection and SQLite. M2.5 connects them **without presenting test data as a connected account**. It also establishes the interface real provider adapters will implement, without writing Trello/ClickUp/NanoTask HTTP calls yet.

M2.5 **depends on M2**. It originated from `feat/m2-domain-store`; its parent PR #5 passed 13 native XCTest checks and was merged to `main` on 2026-10-22. The child PR #6 was retargeted to `main`, and the contributor merged `origin/main` into `feat/m25-preview-bridge` using the Git `ort` strategy (commit `307bf0b`). GitHub comparison subsequently confirmed **ahead, behind 0 and a clean merge state**, with 15 M2.5-related files changed. No M2 core implementation was replaced.

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

Expected output, **actually observed on the contributor Mac**:

```text
PASS: core-backed demo metrics 18 / 6 / 3 / 5 and four change events
PASS: adapter pagination + baseline, atomic preservation on failure, cursor loop detection
RESULT: M2.5 standalone smoke PASS.
```

The M2.5 application was compiled and opened successfully. Submitted screenshots confirm the new demo heading/footer and the four calculated totals, plus the filter reducing the four simulated events to three important ones. See the verification log below for remaining gaps.

## Actual local verification — 2026-10-22

Contributor terminal evidence (Apple Silicon macOS, Apple Swift 6.4):

```text
Compiling M2.5 provider contract and core-backed synthetic preview...
Running real-core demo and provider pagination regression...
PASS: core-backed demo metrics 18 / 6 / 3 / 5 and four change events
PASS: adapter pagination + baseline, atomic preservation on failure, cursor loop detection
RESULT: M2.5 standalone smoke PASS. SwiftPM/XCTest and SwiftUI app build remain separate pending checks.
Building OV Tasks M2.5 (core-backed synthetic preview)...
.../build/OVTasks.app/Contents/Info.plist: OK
.../build/OVTasks.app: replacing existing signature
Local preview created at: .../build/OVTasks.app
```

Initially, `open` reused the old running **M1** process; its screenshots showed `Protótipo M1`, the prior event feed and `3 fontes de demonstração`. This was *not* a core/compilation failure. After choosing **Sair** and reopening the newly built `build/OVTasks.app`, two new screenshots confirmed the M2.5 application was active:

- **New version unmistakable:** header `Protótipo M2.5 · Dados fictícios`, footer `3 fontes simuladas · SQLite local`, and no real-sync claim.
- **Dashboard:** 18 Pending, 6 In progress, 3 Overdue, 5 Completed, matching the core's tested generated snapshot.
- **All activity:** four simulated changes exist: assignment (NanoTask), completion (ClickUp), due-date (Trello) and status (Trello). The last row is partially visible and accessible by scrolling; this is expected feed overflow.
- **Important filter:** three remaining events — assignment, due-date, status. The completed event is excluded by the intentional `isImportant` rule.
- **Visual review:** dark-mode panel, metrics and activity list legible; no visible heading collision or unintended overlap in supplied screenshots.

**Evidence limits:** M2.5 light appearance, all five scenario switches, Settings link, demo task-link alert and Quit were **not retested for this build** (they passed in M1, which is a different binary). Larger accessibility text and keyboard/VoiceOver remain open (#3). The screenshots are evidence of UI binding to the generated demo fixture *in combination with the passing smoke code path*, not proof of real provider sync. The event timestamps near `10 seg` reflect synthetic events created on app launch, not source-reported times.

**Result:** standalone integration smoke PASS; native compilation PASS; primary M2.5 dark-mode UI and filter smoke PASS. The M2 parent separately passed the native 13-case XCTest suite (0 failures, exit code 0) with Xcode 27.1 and was merged into `main`. The new M2.5 adapter code is covered by the direct smoke, not yet by an XCTest-specific suite. No GitHub Actions or real API calls.


## Explicit non-goals / known risks

- No real ClickUp/Trello/NanoTask account sign-in, webhooks, API polling, OAuth, Keychain credentials, remote server, provider link navigation, live notifications or running scheduling timer.
- No persistent user SQLite history. Preview SQLite is random and disposable; a future genuine cache uses Application Support only after connection and privacy controls.
- M2 parent XCTest is no longer blocked: **13 tests passed** with Xcode 27.1. M2.5 adapter smoke was run independently with direct Swift compilation and is **not equivalent to an added adapter XCTest suite**.
- Native keyboard navigation (#3) and formatting refinements (#4) remain separate pre-release items.
- Core change events currently cover status, completion, assignment, due-date changes and creation; **due-soon and overdue notifications are not yet event-engine features**.
- Provider adapters must never write a partial page to the cache; retry/backoff and real API pagination limits will be added per provider later.
- Event feed shows source names, but real task URLs are not provided until secure source-specific adapters exist.

## Acceptance

The direct runner, native app build and primary dark-mode UI/filter validation passed. The parent M2 #5 also passed its native XCTest gate and was merged to `main`. PR #6 has been synchronized with `main` and its final diff is under review. Keep the distinction between milestone acceptance and a public release. Additional UI scenario, light-theme and accessibility checks (#3) remain mandatory before any public release. No GitHub Actions used.
