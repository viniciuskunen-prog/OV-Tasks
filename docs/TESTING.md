# Quality and verification plan

**Native compilation, visual validation and tests have not yet been performed for the M1 OV Tasks SwiftUI source as of 2026-10-22.** This document describes gates; see [M1_PROTOTYPE.md](M1_PROTOTYPE.md) for the manual smoke procedure.

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

Compile via `zsh ./build.sh` on a Mac with Xcode Command Line Tools; record exact success/failure output. Demo link buttons deliberately show an alert instead of opening fictional provider task URLs.
Launch app → menu icon appears → open/close popover → app remains alive → counters/feed use fixtures → each state renders → Settings opens → VoiceOver reads event and source URL action → Quit terminates app.
