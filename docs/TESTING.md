# Quality and verification plan

**M1 local compilation and selected smoke tests completed on 2026-10-22; keyboard navigation failed and extended accessibility verification remains open.** This document describes future gates; see [M1_PROTOTYPE.md](M1_PROTOTYPE.md) for evidence and remaining checks.

## M2 native XCTest — accepted 2026-10-22

Full suite executed twice on a physical Apple Silicon Mac, after installing Xcode 27.1. The second run of `swift test --jobs 2` on `feat/m2-domain-store` reported 9 DomainTests, 4 StoreTests, 13 total XCTest tests, **zero failures** and **exit code 0**. The separate Swift Testing runner reported zero tests because this package uses XCTest. Previously five direct-swiftc core regression groups passed as well. These verify domain/storage implementation with synthetic inputs, not live provider APIs. See [M2_CORE.md](M2_CORE.md) for evidence.

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
