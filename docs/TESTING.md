# Quality and verification plan

**M1 local compilation and selected smoke tests completed on 2026-10-22; keyboard navigation failed and extended accessibility verification remains open.** This document describes future gates; see [M1_PROTOTYPE.md](M1_PROTOTYPE.md) for evidence and remaining checks.

## M2.5 local integration validation — 2026-10-22

The contributor ran `zsh ./test-m25-direct.sh` on a physical Mac: synthetic core-backed dashboard 18/6/3/5 and four change events PASS; paginated fake adapter, preservation of last valid SQLite snapshot after second-page failure, and repeated-cursor rejection PASS. `zsh ./build.sh` compiled and signed the app, and post-relaunch screenshots verified header M2.5, feed/four metrics, and Important filter reducing four events to three. Light appearance, all M2.5 view scenarios, keyboard/VoiceOver remain unverified on the M2.5 binary and must be checked before public release. See [M25_PREVIEW_BRIDGE.md](M25_PREVIEW_BRIDGE.md).

## M2 native XCTest — accepted and merged 2026-10-22

With Xcode 27.1 installed, the contributor ran `swift test --jobs 2` twice on physical Apple Silicon macOS. Native XCTest: 9 DomainTests + 4 StoreTests, **13 tests passed, 0 failures**, shell exit code **0**. The separate Swift Testing runner showed zero tests because the project uses XCTest. M2 additionally passed five direct-swiftc regression groups; PR #5 has been merged into `main`. See [M2_CORE.md](M2_CORE.md) for exact QA evidence.

## M3A ClickUp foundation — XCTest PASSED 2026-10-22

Four new synthetic XCTest methods in `ClickUpReadTests.swift` passed on the user's physical Mac with Xcode 27.1: read-only identity/discovery, status/date/link normalization, fully paged ingestion with HTTP 429 preserving the SQLite snapshot, and unknown status/scope/cursor rejection. Full package XCTest **17 passed, 0 failures** (4 ClickUp, 9 Domain, 4 Store); separate M2.5 smoke script passed and demo macOS app compiled. **No live ClickUp requests, no Keychain credential roundtrip through a signed app, and no ClickUp UI integration tested.** See [M3A guide](M3_CLICKUP_FOUNDATION.md).

## M3B native UI and real provider acceptance — NOT YET TESTED

M3B adds macOS Settings SecureField, explicit ClickUp Workspace/Space/list consent, local Keychain access, manual paginated sync to Application Support SQLite, connected-only metrics/activity and local disconnect. **No native compile or UI/Keychain/live API result has been received yet.** From the M3B branch run existing 17 XCTest cases (M3A/core), then `zsh ./build.sh`, which now compiles the real connection UI. Only after build success perform controlled account verification entirely inside the running app, without ever pasting tokens/task names in GitHub, Drive or chat. Include cancel/offline/429, cache restart, selection and disconnect tests; see [M3B guide](M3B_CLICKUP_CONNECTION.md). Do not merge/release based on earlier M3A XCTest alone.

## Test matrix
| Area | Cases |
| --- | --- |
| Counting | Status groups; Pending contains In progress/Overdue; 7-day Done window; unknown statuses not falsely Done |
| Due dates | Timezone, DST, midnight date-only, missing due date, changed/removed due |
| Event engine | First sync baseline, repeated polls, status transitions, failed partial pages, same task in multiple scopes |
| Notifications | Permission denied/allowed; once-per-threshold; quiet hours; sleep-resume digest; click opens validated URL |
| Credentials | OAuth state, expired/revoked token, Keychain isolation, per-account logout, no secret logs |
| Connectors | JSON fixture validity, pagination, rate limits, 429 retry-after, 401, malformed responses, scoped filtering |
| UI | Empty, loading, offline, stale, partial outage, reconnect, light/dark, long names, dynamic text, VoiceOver |
| Storage | Atomic sync updates, restart persistence, upgrades/migrations, erase local data, crash recovery |

## Strategy
- Pure unit tests for domain and notification decisions via Swift Testing/XCTest.
- Adapter contract tests with minimal **synthetic** fixtures; no production API responses in Git.
- Optional integration against dedicated dev accounts with credentials in Keychain or secrets manager.
- Manual macOS smoke test on supported OS/hardware; validate menu bar lifecycle and notification action when popover is closed.
- Keep structured records of the specific test command, system version, commit SHA, observed pass/fail and limitations for PR/release.

## Non-goals
Do not run costly hosted macOS build matrices on every source or documentation push. Do not claim real-time coverage while laptop is asleep. Do not report “validated” from source review alone.

## Initial M1 smoke checklist

**M1 observation:** compiled and launched locally; dark/light panel, filters, scenarios, demo-link dialogs, retained Offline scenario and Quit validated by user. Keyboard-only navigation reported not working (issue #3); VoiceOver and large-text checks pending, mandatory before stable release.

Compile via `zsh ./build.sh` on a Mac with Xcode Command Line Tools; record exact success/failure output. Demo link buttons deliberately show an alert instead of opening fictional provider task URLs.
Launch app → menu icon appears → open/close popover → app remains alive → counters/feed use fixtures → each state renders → Settings opens → VoiceOver reads event and source URL action → Quit terminates app.
