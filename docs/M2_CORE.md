# M2 — Domain engine and local snapshot cache

**Status:** source code prepared for local macOS Swift Package tests. **Not compiled or tested on a Mac yet.** Do not treat this as a successful test result.

## Scope implemented in code

The new standalone Swift package `OVTasksCore` is written in Foundation and SQLite3, without SwiftUI, networking, background services, accounts or credentials.

- **Normalized tasks:** provider/account/workspace/task identifiers, scoped source identity, raw + mapped normalized status, canonical due date and optional completion timestamp. Task IDs use collision-resistant length-prefixed composite keys.
- **Canonical statuses:** OPEN, IN_PROGRESS, BLOCKED, DONE, CANCELED and UNKNOWN, with explicit case/whitespace-normalized mappings per provider. Unmapped statuses remain UNKNOWN.
- **Deadlines:** exact timestamps and date-only due days bound to an explicit IANA timezone. Date-only is overdue at the **start of the next local calendar day**, including DST boundaries.
- **Metrics:** Pending (OPEN/IN_PROGRESS/BLOCKED), In progress, Overdue (subset of Pending), Completed in last rolling 7×24 hours. No guesses for unavailable completion timestamps: `completedIsComplete=false` if any DONE task lacks one. Dedupe tasks visible across watched scopes.
- **Change detection:** first successful complete snapshot is a **silent baseline**. Later completed snapshots classify task creation, status changes, completion, due-date changes and assignee changes. Missing tasks are not reported as definitively deleted; unchanged snapshots produce no new events.
- **SQLite storage:** one local DB with `PRAGMA user_version=1`, per-scope snapshots, metadata and persistent event feed. Snapshot replacement and new events are committed in one transaction. A failed/invalid snapshot leaves the prior good state. Account-specific purge deletes only that account's cache and events.
- **Poll policy:** pure next-eligible time calculation with minimum 60-second floor and retry-after support, not an active background timer.

## Architecture boundary

```text
Package.swift
Sources/OVTasksCore/
  Models/TaskModels.swift
  Metrics/MetricsCalculator.swift
  Events/SnapshotDiffer.swift
  Persistence/SQLiteSnapshotStore.swift
  Sync/SyncPlanner.swift
Tests/OVTasksCoreTests/
  TestFixtures.swift
  DomainTests.swift
  StoreTests.swift
```

The existing **M1 menu bar interface remains unmodified**, still showing hard-coded synthetic data. M2 has **not yet connected** the core package to that UI: doing so before read-only providers exist could make mock data look genuine. The future integration needs a view model with an explicit “no account connected” state.

No `URLSession`, OAuth, Supabase, Trello, ClickUp, native notifications, background fetch or external services are included here. A future sync orchestrator must supply **fully paginated successful scope snapshots** to `applyCompleteSnapshot`; never commit partial pages.

## Run tests locally on macOS

From a checkout of `feat/m2-domain-store`:

```zsh
cd ~/Projects/OV-Tasks
git fetch origin
git switch feat/m2-domain-store 2>/dev/null || git switch --track origin/feat/m2-domain-store
git pull --ff-only
swift test
```

Use a Mac with Xcode Command Line Tools; `swift test` builds the package and test executable using the installed Swift toolchain. SQLite3 is provided by the macOS SDK and linked via SwiftPM. The tests use **only synthetic task data and temporary SQLite files** and do not modify `/Applications` or connect to any real account.

If `swift test` fails, collect the full output and:

```zsh
xcrun swift --version
xcode-select -p
sw_vers -productVersion
```

Do not rerun blindly or enable costly hosted GitHub Actions. Correct the smallest reproducible issue in the M2 branch through the connector and repeat locally.

## Tests included (NOT executed yet)

- Composite ID safety (nil/empty/delimiter); explicit unmapped status UNKNOWN.
- Exact calendar-day expiration, invalid dates/timezones, 23-hour DST transition.
- Overlapping metrics, 7-day completion window, unknown completion and multi-scope deduplication.
- Silent baseline, no duplicate event on unchanged snapshot, due/assignment/status transitions.
- Poll cadence, minimum interval, retry-after and disconnected state.
- SQLite persistence across reopen, first baseline, idempotent repeated imports, full empty scope, account erasure and invalid/duplicate snapshot rejection.

## Technical limitations

- This is **not** a provider-sync service; a pure scheduler policy exists but no running timer.
- The local event history has no retention purge yet; retention controls and delivery ledger belong to M6.
- The event payload uses task titles and status summaries for user-facing history; no attachment/description/comment content is persisted.
- `validatedOriginalURL` checks basic HTTPS syntax; provider-specific allowlists and deep-link validation are still required when adding real adapters.
- `updatedAt` is used only for reconciling duplicate task identities from overlapping watched scopes. It is never substituted for missing `completedAt`.
- SQLite is used directly with a single actor-confined connection; this avoids unreviewed third-party database dependencies. Schema upgrades beyond v1 must be explicitly migrated and tested.
- The 7-day window uses **168 hours**, not seven local calendar midnights, as specified in docs/DATA_MODEL.md.
- Keyboard-only navigation in the M1 UI remains a separate pre-release accessibility debt: issue #3.

## Acceptance for M2

`swift test` must pass locally and its result must be recorded. Any compiler or test errors are blockers for M2. A small data-flow demo linking M1's UI to persisted summaries is **not required** for this core milestone; real UI binding will be integrated in the first provider milestone or a dedicated subsequent PR, with clear connection states.

No GitHub Actions are configured or executed for this milestone.
