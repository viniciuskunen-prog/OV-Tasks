# M2 — Domain engine and local snapshot cache

**Status (2026-10-22): M2 core acceptance PASS. Physical Mac: five direct-swiftc smoke groups PASS, and full native XCTest suite PASS — 13 tests (9 DomainTests + 4 StoreTests), zero failures and exit code 0. Xcode 27.1 resolved the earlier CLT-only manifest/toolchain blocker. No live provider integration or stable release.**

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

## SwiftPM manifest-link error: Command Line Tools

On a contributor Apple Silicon Mac on 2026-10-22, `swift test` failed **before compiling the package target**, with:

```text
error: 'ov-tasks': Invalid manifest
Undefined symbols for architecture arm64:
  PackageDescription.Package.__allocating_init(... defaultLocalization: ... swiftLanguageVersions: ...)
```

The manifest compiler was located in `/Library/Developer/CommandLineTools/usr/bin/swiftc`. This exact undefined symbol has been reported outside this project in [Swift Forums](https://forums.swift.org/t/how-to-setup-swift-on-macos/79105), with Command Line Tools reinstallation resolving the reporter's machine. An unverified local toolchain/configuration mismatch is therefore suspected; **do not automatically rewrite Package.swift or claim this proves source code is broken**.

Inspect the active developer tools safely:

```zsh
xcode-select -p
xcrun swift --version
swift package --version
```

If the full Xcode developer tools are installed at the default location, test with them **without changing the system-wide selection**:

```zsh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift test
```

If Xcode is absent, the built-in Swift compiler may still independently type-check the M2 core without invoking SwiftPM:

```zsh
xcrun swiftc -parse-as-library -typecheck -module-name OVTasksCore \
  Sources/OVTasksCore/Models/TaskModels.swift \
  Sources/OVTasksCore/Metrics/MetricsCalculator.swift \
  Sources/OVTasksCore/Events/SnapshotDiffer.swift \
  Sources/OVTasksCore/Sync/SyncPlanner.swift \
  Sources/OVTasksCore/Persistence/SQLiteSnapshotStore.swift
```

This type-check is **not equivalent to running `swift test`** and provides no XCTest evidence. If developer tools need repair, use a compatible official Apple toolchain / CLT update process only after checking the installed versions and macOS release. Do not delete Command Line Tools blindly, disable security mechanisms, or introduce hosted GitHub Actions as a workaround.

## SwiftPM manifest experiment outcome and isolated diagnosis — 2026-10-22

An attempted compatibility change to `// swift-tools-version: 6.0` plus `swiftLanguageModes: [.v5]` **failed** on the contributor's Command Line Tools. After checking out the updated parent M2 branch, the real `swift package dump-package` output was:

```text
Package.swift:24:25: error: extra argument 'swiftLanguageModes' in call
Package.swift:24:27: error: reference to member 'v5' cannot be resolved without a contextual type
error: invalid manifests
```

No XCTest code was compiled. Although current PackageDescription documentation describes `swiftLanguageModes`, the local SwiftPM 6.4-dev/Command Line Tools manifest interface did not recognize it. The experimental manifest edit was **reverted** to the original portable tools version 5.9. Its older manifest still fails to link a `PackageDescription.Package` initializer on this Mac.

To distinguish a broken toolchain from a particular initializer ABI mismatch, the parent M2 branch now includes `diagnose-swiftpm.sh`. It creates three **disposable, minimal** packages in `${TMPDIR}`: a Swift Tools 5.9 minimal package, an explicitly older 5.9 constructor overload, and a Swift Tools 6.0 minimal package. It runs `swift package dump-package` on each and summarizes independent failures. The script does not alter the OV Tasks source tree, `xcode-select`, any global developer tools or the installed app. It also reports whether a native `xctest` runner is available.

```zsh
cd ~/Projects/OV-Tasks
git fetch origin
git switch feat/m2-domain-store
git pull --ff-only
zsh ./diagnose-swiftpm.sh
```

**Isolated diagnostic ACTUALLY RAN twice on 2026-10-22 and failed independently of OV Tasks:**

```text
Developer directory: /Library/Developer/CommandLineTools
Apple Swift 6.4 (swiftlang-6.4.0.34.1), arm64-apple-macosx27.0.0
Swift Package Manager - Swift 6.4.0-dev
Native xctest runner: not found with active developer tools
FAIL: tools59-minimal — manifest failed without any OV Tasks source
FAIL: tools59-legacy-overload — manifest failed without any OV Tasks source
FAIL: tools60-minimal — manifest failed without any OV Tasks source
Diagnostic complete: 0 passed; 3 failed.
```

All three manifest link failures name the same unavailable `PackageDescription.Package.__allocating_init(... swiftLanguageVersions: ...)` symbol. Even the independent `Package(name: "Probe", targets: ...)` SwiftPM minimal package fails, so **the failure is proven independent of the repository's source and particular manifest options**. This strongly suggests that the current local Command Line Tools installation has an incompatible Swift compiler/PackageDescription runtime or a related packaging issue. **The exact mismatched component has not yet been proven.**

The current active tools do not expose `xctest` using `xcrun --find xctest`. This adds another reason not to claim that XCTest could run on this specific setup even after the manifest is fixed. It does not by itself prove that all Command Line Tools installations lack XCTest.

### Safe next step — inventory official tools updates (no changes)

```zsh
pkgutil --pkg-info=com.apple.pkg.CLTools_Executables
softwareupdate --list
```

These commands report the currently installed Command Line Tools package receipt and any Apple-supported updates available for that Mac; they do not install or uninstall anything. Apple recommends checking for a Command Line Tools version compatible with the macOS release and using Software Update or the official Apple Developer downloads. See [Apple: Installing the command-line tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools).

**Actual inventory on the contributor Mac (2026-10-22):**

```text
package-id: com.apple.pkg.CLTools_Executables
version: 27.0.0.0.1788430756
Software Update Tool
Finding available software
No new software available.
```

No update is offered through `softwareupdate`. This does not prove that a separately downloadable Command Line Tools installer is unavailable on Apple Developer Downloads.

**Recommended lower-risk way to isolate the broken CLI installation:** use a separate **stable full Xcode 27.1** bundle (released 2026-10-15), if disk space allows. The [Apple Xcode system requirements](https://developer.apple.com/xcode/system-requirements) list Xcode 27.1 as compatible with macOS Tahoe 26.6 or later, Swift 6.4 and macOS 27 SDKs; first check the real host system version with `sw_vers -productVersion`. Apple links: [stable Xcode 27.1 release](https://developer.apple.com/news/releases/?id=10152026a), [official Apple developer downloads](https://developer.apple.com/download/all/), or [Mac App Store](https://apps.apple.com/us/app/xcode/id497799835?mt=12). Prefer the stable 27.1 release over the separate 27.2 RC for this project. **The user has not installed this Xcode as part of our tests.**

After installing and opening Xcode once to finish first-launch components/licenses, run the checks below with a **per-command developer directory override**. This keeps the global `xcode-select -p` pointing at CLT, avoiding changes to other projects:

```zsh
sw_vers -productVersion
df -h /Applications
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild -version
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun --find xctest

cd ~/Projects/OV-Tasks
git fetch origin
git switch feat/m2-domain-store
git pull --ff-only

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift package dump-package >/dev/null && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift test --jobs 2
```

These commands are **future instructions, not completed test results**. If SwiftPM fails with Xcode's toolchain too, inspect it separately; do not assume installation guarantees success. If disk space prevents a full Xcode installation, compare Apple's officially available `Command Line Tools for Xcode 27.1` or compatible package **only if such a download is actually listed**, but note that installing CLT packages replaces the single system-wide CLT installation and could affect other work. Avoid `sudo rm -rf /Library/Developer/CommandLineTools` unless intentionally following an approved repair plan.



After repairing the toolchain, rerun `zsh ./diagnose-swiftpm.sh`. Only after a minimal probe passes should we retry `swift test --jobs 2` and then resolve any XCTest compilation/logic failures separately. The M2 five-group runtime smoke and M2.5 demo/UI smoke already **passed** with direct `swiftc` and remain valid for their tested scenarios.

**Acceptance:** parent PR #5 and stacked PR #6 remain drafts. No GitHub Actions run; don't alter project code to accommodate a demonstrably failing global PackageDescription installation.

## Alternative direct-`swiftc` executable smoke test (CLT-only)

The contributor's 2026-10-22 terminal result established:
- `xcode-select -p`: `/Library/Developer/CommandLineTools`
- `xcrun swift --version`: Apple Swift **6.4**, target arm64-apple-macosx27.0.0
- `swift package --version`: Swift Package Manager 6.4.0-dev
- Full Xcode not present in `/Applications/Xcode.app`
- Direct `swiftc -parse-as-library -typecheck` of **all five `OVTasksCore` sources succeeded**.

The `swift test` failure is therefore limited to SwiftPM's **manifest link stage** at this time. As a low-risk workaround, this branch adds `Tests/M2StandaloneSmoke.swift` and `test-m2-direct.sh`. The shell script compiles the *same core sources* with `xcrun swiftc -lsqlite3` and runs a **standalone synthetic-data regression binary**, bypassing the SwiftPM manifest.

```zsh
cd ~/Projects/OV-Tasks
git fetch origin
git switch feat/m2-domain-store
git pull --ff-only
zsh ./test-m2-direct.sh
```

It covers five groups: identifier/status mapping, DST/deadline/metrics, baseline-safe event diffs, poll scheduling, and SQLite atomic snapshot persistence/account isolation. The runner is an actual executable — it is **not merely type-checking** — but **it is not a substitute for the full XCTest suite**. If it passes, record the exact output and still keep the SwiftPM/XCTest issue as a separate tooling acceptance item. The standalone smoke test **has now been executed successfully** on the contributor's Mac; record below. This does **not** validate the separate XCTest suite.

Avoid changing global toolchain selection or installing a second Xcode just to run this fallback. The compiled smoke executable remains under `.build/m2-direct-smoke/` and no data leaves the Mac.

## Actual macOS regression run — 2026-10-22

The contributor switched to the `feat/m2-domain-store` branch, fast-forwarded from origin, and executed `zsh ./test-m2-direct.sh`. Terminal transcript:

```text
Building OVTasksCore regression runner with swiftc (no Swift Package Manager)...
Running synthetic-data regression checks...
PASS: 5 smoke groups — identity/status, dates/metrics, events, scheduling, SQLite
NOTE: XCTest suite has NOT been executed; this is a targeted direct-swiftc regression.

Direct Swift smoke checks succeeded. XCTest / 'swift test' remains pending.
```

**Verified in this run:** successful compilation and execution of the stand-alone regression executable using the real M2 implementation plus SQLite3, with five synthetic-data check groups. Prior `swiftc -typecheck` also passed for all five core source files.

**Not verified:** every existing XCTest case; SwiftPM manifest loading; performance/stress; migration/upgrades; crash recovery; provider APIs; background scheduling; UI binding. The SwiftPM error is not caused by any proven source-level failure; do not claim all future SwiftPM tests will pass.

**Acceptance status:** runtime smoke **PASS**, full `swift test` **BLOCKED by local SwiftPM manifest/link environment**, M2 remains in draft pending full QA or an explicit revised release gate. No GitHub Actions, service credentials or modifications to the M1 menu bar app were involved.

## XCTest cases included (NOT executed yet)

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

## Actual XCTest acceptance — 2026-10-22

On a physical Apple Silicon Mac running macOS 27.0.1, the contributor installed **Xcode 27.1 (build 27A9275)**. The first invocation required Apple SDK license acceptance. After setup, `swift test --jobs 2` completed and a second identical run captured the entire output in `/tmp/ovtasks-m2-tests.log`.

**Exact observed summary of the second run:**

```text
Test Suite 'DomainTests' passed.
    Executed 9 tests, with 0 failures (0 unexpected)
Test Suite 'StoreTests' passed.
    Executed 4 tests, with 0 failures (0 unexpected)
Test Suite 'OVTasksCoreTests.xctest' passed.
    Executed 13 tests, with 0 failures (0 unexpected)
Test Suite 'All tests' passed.
    Executed 13 tests, with 0 failures (0 unexpected)
✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.
Código de saída: 0
```

The `0 tests in 0 suites` line is the separate **Swift Testing** runner; it does not contradict the 13 **XCTest** tests reported immediately above. This was an actual completed local run, not a simulated or inferred success.

```zsh
cd ~/Projects/OV-Tasks
git switch feat/m2-domain-store
swift test --jobs 2
```

For a subsequent portable invocation without depending on global developer-tool selection, use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift test --jobs 2`.

**Resolution:** the previous 3/3 failed minimal SwiftPM package probes were performed using the macOS Command Line Tools 27.0's SwiftPM runtime. After installation/configuration of full Xcode 27.1, the package built and XCTest executed. This validates the *M2 test suite*, not any hypothesis about exactly which CLT library symbol was missing. Leave the historic diagnostics below for reproducibility; they represent the earlier toolchain state and are no longer current blockers.

**Remaining release gaps:** M2 is a backend core milestone, not the complete app; provider API authentication, background scheduling, notification delivery, UI accessibility (#3), and full public packaging remain future acceptance requirements.

## Acceptance for M2

**ACCEPTED for M2:** full local `swift test --jobs 2` passed (13 XCTest, zero failures, exit code 0) and is recorded above, alongside five passing independent smoke groups. The M2.5 child PR implements the separate synthetic UI bridge and will be integrated on its own review/QA gate. Provider APIs, credentials and live sync remain unimplemented.

No GitHub Actions are configured or executed for this milestone.
