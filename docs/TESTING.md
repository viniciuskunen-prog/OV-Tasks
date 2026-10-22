# Quality and verification plan

**M1 local compilation and selected smoke tests completed on 2026-10-22; keyboard navigation failed and extended accessibility verification remains open.** This document describes future gates; see [M1_PROTOTYPE.md](M1_PROTOTYPE.md) for evidence and remaining checks.

## M2.5 local integration validation — 2026-10-22

The contributor ran `zsh ./test-m25-direct.sh` on a physical Mac: synthetic core-backed dashboard 18/6/3/5 and four change events PASS; paginated fake adapter, preservation of last valid SQLite snapshot after second-page failure, and repeated-cursor rejection PASS. `zsh ./build.sh` compiled and signed the app, and post-relaunch screenshots verified header M2.5, feed/four metrics, and Important filter reducing four events to three. Light appearance, all M2.5 view scenarios, keyboard/VoiceOver remain unverified on the M2.5 binary and must be checked before public release. See [M25_PREVIEW_BRIDGE.md](M25_PREVIEW_BRIDGE.md).

## M2 native XCTest — accepted and merged 2026-10-22

With Xcode 27.1 installed, the contributor ran `swift test --jobs 2` twice on physical Apple Silicon macOS. Native XCTest: 9 DomainTests + 4 StoreTests, **13 tests passed, 0 failures**, shell exit code **0**. The separate Swift Testing runner showed zero tests because the project uses XCTest. M2 additionally passed five direct-swiftc regression groups; PR #5 has been merged into `main`. See [M2_CORE.md](M2_CORE.md) for exact QA evidence.

## M3A ClickUp foundation — UNVERIFIED source

Four new synthetic XCTest methods in `ClickUpReadTests.swift` cover read-only identity/discovery, raw status/date normalization, fully paged imports with rate-limit failure preserving existing SQLite data, and unknown status/scope rejection. The Keychain implementation has not been smoke-tested with a real signed binary. **No M3A XCTest or native compilation result has been received yet.** From the M3A branch run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift test --jobs 2`; the expected count is 17 only if compilation/execution succeeds. See [M3A guide](M3_CLICKUP_FOUNDATION.md).

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
