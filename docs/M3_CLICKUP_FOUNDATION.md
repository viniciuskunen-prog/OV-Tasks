# M3A — ClickUp read-only foundation (developer candidate)

**Status 2026-10-22: local core QA PASSED.** Contributor's physical Mac (Xcode 27.1) compiled and ran the package: **17 XCTest methods passed (4 ClickUp, 9 Domain, 4 Store), zero failures**. Separately, M2.5 direct integration smoke and the existing macOS preview build passed. **No real ClickUp account connected and no live sync performed**; M3A remains the tested connector foundation, not an end-to-end feature.

## Scope and official API verification

ClickUp currently documents:
- Personal tokens for individual development/testing; OAuth Authorization Code for third-party distribution. OAuth token exchange requires an app **client secret**, so it cannot be safely embedded in a public desktop executable.
- `GET /api/v2/user` to verify an authorized user. Discovery via `GET /api/v2/team`, `/team/{id}/space`, `/space/{id}/folder`, `/space/{id}/list` and `/folder/{id}/list`.
- `GET /api/v2/list/{id}/task`: zero-based `page`, 100 tasks per page, optional `include_closed`, `subtasks` and `include_timl`.
- Token rate limiting. A `429` response supplies `X-RateLimit-Reset` as a Unix timestamp. Free/Unlimited/Business are currently 100 requests per minute per token; higher plan limits exist.

Sources: [authentication](https://developer.clickup.com/docs/authentication), [get tasks](https://developer.clickup.com/reference/gettasks), [get user](https://developer.clickup.com/reference/getauthorizeduser), [rate limits](https://developer.clickup.com/docs/rate-limits), [folders](https://developer.clickup.com/reference/getfolders).

## Implemented

- `ClickUpReadClient.swift`: API v2 **GET-only** URLSession client pinned to `https://api.clickup.com` and redirect rejection to prevent Authorization header forwarding; ephemeral session with no cookie store. A typed HTTP interface allows fixture-only tests.
- Discovery methods: user, workspaces, spaces, folders, folderless lists and lists in a folder. IDs are validated and not inserted into raw query strings.
- `ClickUpListAdapter`: implements the existing `ProviderAdapter` for exactly one **explicitly selected** list, uses injectable `ClickUpCredentialSource` and converts responses into `TaskSummary`. Page 0 is the first; a full 100-task page triggers another GET unless the API explicitly flags the last page.
- Query includes `include_closed=true`, `subtasks=true`, `archived=false` and `include_timl=false` (home-list-only; no membership expansion or duplicates). SnapshotIngestor persists **only if all pages pass**; HTTP 429, 401, corrupt JSON, invalid list, cancellation and page-limit conditions must preserve the last good cache.
- Completion: terminal ClickUp `status.type` closed/done maps to `DONE`, taking precedence over arbitrary names; custom status labels require **explicit per-list mapping** or remain UNKNOWN rather than being guessed. Missing reliable `date_done/date_closed` stays unknown completion time. Millisecond epoch strings and numbers supported.
- Date-only deadline with `due_date_time=false` uses the selected timezone and `LocalDueDay`; exact deadline uses a timestamp. Note: timezone behavior still needs **comparison with live ClickUp UI** before claiming a production-correct all-day deadline.
- Verified HTTPS task links restricted to `app.clickup.com` and `clickup.com`; malformed or other-origin links are dropped.
- `ClickUpKeychain.swift`: actor-backed per-account local generic-password item; accessible only when unlocked and only on this device; updates atomically, no plaintext token in repo/SQLite/preferences.
- `ClickUpReadTests.swift`: four synthetic XCTest checks for workspace/list discovery, decoding/status/due/link mapping, full two-page ingestion with 429 preserving cache, and unknown statuses/scope/cursor rejection. **All four passed on the contributor's Mac on 2026-10-22.**

## Explicit non-goals

No new UI has been wired up yet, no account has connected, no ClickUp request has actually been issued, and **no personal token is requested in chat**. Do not copy credentials from a ChatGPT/ClickUp connector into the OV Tasks code. Do not store any user token in GitHub, Drive or documents.

Before M3 can be accepted, a separate M3B implementation must supply explicit account connection, token submission directly into an app `SecureField`, authorized identity verification, Keychain save, read-only list selection and user-triggered synchronization to persistent local SQLite, with disconnect cleanup. Public-release OAuth needs a carefully audited secret-handling backend or provider-supported public-client flow. No OAuth client secret may appear in this public repo.

Other gaps: rate-limit retry/backoff integration, per-list status mapping UX, all-day timezone validation against ClickUp UI, more exhaustive page/duplicate/reconnect tests, provider-specific link/deep-link actions, and accessibility issue #3. No background polling or notifications in M3A.

## Actual local acceptance — 2026-10-22

Contributor pulled `feat/m3a-clickup-readonly-foundation` to the physical Apple Silicon Mac and ran:

```zsh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift test --jobs 2
zsh ./test-m25-direct.sh
zsh ./build.sh
```

Observed native XCTest summary:

```text
Build complete! (3,18 seg)
Test Suite 'ClickUpReadTests' passed.
    Executed 4 tests, with 0 failures (0 unexpected)
Test Suite 'DomainTests' passed.
    Executed 9 tests, with 0 failures (0 unexpected)
Test Suite 'StoreTests' passed.
    Executed 4 tests, with 0 failures (0 unexpected)
Test Suite 'OVTasksCoreTests.xctest' passed.
    Executed 17 tests, with 0 failures (0 unexpected)
Test Suite 'All tests' passed.
    Executed 17 tests, with 0 failures (0 unexpected)
```

A subsequent Swift Testing runner reported `0 tests in 0 suites`; this is separate from XCTest and not an XCTest failure.

Direct core-backed smoke reported **PASS** for metrics `18 / 6 / 3 / 5`, four change events, pagination, atomic snapshot retention on failure and repeated-cursor detection. `zsh ./build.sh` completed, with `Info.plist: OK` and ad-hoc app signing. **That app build is still the unchanged M2.5 synthetic preview; the ClickUp HTTP/Keychain code was compiled as Swift Package sources by XCTest, not integrated into the preview app.**

**QA verdict: M3A foundation accepted for its documented synthetic test scope.** Keychain roundtrip with real signed app, live ClickUp API contract, auth UI, real account/scope selection, rate-limit backoff, real first sync and public OAuth are *not* covered. No tokens used, and no GitHub Actions were run.

## Reproduce the local test (optional)

Use full Xcode 27.1 for `swift test`, which previously passed the 13 M2 core XCTest cases.

```zsh
cd ~/Projects/OV-Tasks
git fetch origin
git switch --track origin/feat/m3a-clickup-readonly-foundation
git pull --ff-only

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift test --jobs 2
zsh ./test-m25-direct.sh
zsh ./build.sh
git status --short
```

**Observed on 2026-10-22:** 17 XCTest passed (0 failures), M2.5 direct smoke PASS and demo app build PASS. Further testing is required for real signed-app Keychain access and provider requests, neither of which this milestone claims.

No GitHub Actions are configured or consumed by this work.
