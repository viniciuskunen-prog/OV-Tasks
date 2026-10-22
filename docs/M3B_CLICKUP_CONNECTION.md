# M3B — ClickUp native connection and manual read-only synchronization

**Status (2026-10-22):** Source implemented in \`feat/m3b-clickup-connection-ui\` but **NOT YET COMPILED OR TESTED on the contributor's Mac**. Do not claim live sync success or merge before native UI compilation and explicit safe QA.

## What was implemented

- \`ClickUpConnectionStore\` is one \`@MainActor\` observable coordinator injected into both menu-bar Dashboard and Settings. It requests credentials only when the user presses **Verificar e conectar**. It validates the token with \`GET /api/v2/user\`, lists authorized Workspaces and writes the verified personal token to the existing macOS Keychain service. Token text is never persisted by the UI/metadata layer, displayed, or printed.
- Settings has a local \`SecureField\`. Saved account ID, display label, Workspace/Space IDs and selected list IDs/names are **non-secret metadata** stored in local UserDefaults; **the token stays only in Keychain**. Account selection is restored on relaunch; no HTTP requests run automatically at startup.
- Explicit hierarchy browsing: load Workspaces; choose Workspace → Spaces; choose Space → folders, folderless lists, and folder lists. The chooser allows up to **20 lists in one Space of one Workspace** for this first version. No list is fetched merely by browsing or toggling. A separate **Salvar seleção** action is required before task synchronization. For very large spaces, the UI shows only the first 200 names and warns that its picker is limited.
- **Sincronizar agora** uses the M3A \`ClickUpListAdapter\`, fetches complete pages using GET and invokes M2.5 \`SnapshotIngestor\` for each saved list. Every individual list remains atomic: incomplete pages and API errors retain that list's last successful snapshot; other lists can succeed separately. On HTTP 429 or authorization failure it stops additional requests. There is **no automatic retry, polling or notification delivery**.
- Persistent SQLite at \`~/Library/Application Support/OVTasks/snapshots.sqlite\`. Only watched scopes contribute to dashboard metrics and event feed; task URLs are opened only on explicit click and only if validated against ClickUp's HTTPS origins by M3A.
- First complete sync of each list is a silent baseline, so no historical false change notifications. Subsequent successful syncs can show real changes. Connected UI **never mixes fictitious M2.5 cards/events with ClickUp data**; on disconnected mode it retains the synthetic demonstration. Offline, API and parsing failures display a bounded status; they never print raw provider JSON or credentials.
- Custom statuses without an explicit mapping stay \`UNKNOWN\` and are explicitly counted as unclassified; completed tasks without a reliable completion timestamp cause a warning that the last-7-days total may be incomplete. **The custom-status mapping UI and provider all-day timezone cross-check are not finished**, so do not treat the counters as fully accurate for all ClickUp setups.
- \`Desconectar e apagar dados locais\` requires confirmation, invokes the existing \`removeAccount\` SQLite logical deletion (including cascaded tasks/events), removes the per-account Keychain entry, and removes connection metadata. This is logical data deletion from the app's live database; it **does not guarantee forensic erasure** of SQLite free pages, Time Machine backups or other copies. When an error occurs, the flow can be retried.

## Security caveats and release boundary

Personal ClickUp tokens may have write privileges. The app's own network code exposes **GET-only** methods; the token itself is **not provider-scoped read-only**. Do not copy a token into ChatGPT, GitHub, Google Drive, Terminal commands or commit history. Enter it only into the app's SecureField after reviewing and locally compiling the source.

The local app bundle is **ad-hoc signed** by \`build.sh\`, not signed with a stable Developer ID. Depending on macOS Keychain access control, a later rebuild may prompt again for access or require reconnecting. Keychain behavior, app identity across upgrades, and error recovery require actual testing before customer distribution.

Production requirements still include OAuth secret exchange external to the open-source app, first-party status mapping, rigorous offline tests, live provider contract validation, per-account logout/backoff, stable signing/notarization, privacy review and keyboard/VoiceOver issue #3. This is a **developer preview**, not a stable release.

## First real Mac validation — 2026-10-22 (partial)

User checked out `feat/m3b-clickup-connection-ui` and executed `swift test --jobs 2 && zsh ./test-m25-direct.sh && zsh ./build.sh` on the physical Mac.

**Observed:**
- Swift Package XCTest **17/17 passed (0 failures)**: ClickUpReadTests 4, DomainTests 9, StoreTests 4.
- `test-m25-direct.sh` **PASS**, including synthetic metrics/events, pagination, cache preservation and repeated-cursor detection.
- Native `build.sh` **FAILED** (the new M3B UI was not built). Compiler reported `Sources/OVTasksApp/ClickUp/ClickUpConnectionStore.swift:99:14: error: 'is' keyword required to pattern match against type name` for `case CancellationError:`.

**Correction committed:** `3992d0e` changes the line to `case is CancellationError:`. This is a Swift pattern-match correction, not a change to provider behavior. **The corrected M3B native app has NOT been recompiled or tested yet.** It is possible subsequent compiler diagnostics will surface; report the entire new compiler output without supplying any ClickUp token. PR #8 remains draft and no real provider data has been accessed.

## Local acceptance — rerun after correction

\`\`\`zsh
cd ~/Projects/OV-Tasks
git fetch origin
git switch feat/m3b-clickup-connection-ui 2>/dev/null || \
  git switch --track origin/feat/m3b-clickup-connection-ui
git pull --ff-only

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/swift test --jobs 2
zsh ./test-m25-direct.sh
zsh ./build.sh
git status --short
\`\`\`

Expected native package count remains 17 XCTest cases **only if they actually compile/pass**. The native \`build.sh\` step is now the first check that compiles the **new Settings, dashboard, Keychain and network connector into the actual app bundle**; M3A's prior build did not do this.

Do not enter a real token until **the native build passes**. For a later, controlled real-world verification: quit any old M1/M2.5 menu bar process; \`open ./build/OVTasks.app\`; open Settings; enter token in SecureField; verify identity; select Workspace → Space → lists; save; click Synchronize; verify real counters and last sync; repeat to observe diff; disconnect and inspect that account data no longer appears. Do not send token, task names, screenshots of private customer data or raw API responses in chat.

Use public-safe summaries for bug reports (errors, counts, no credentials). No GitHub Actions used.

**Acceptance still pending**: XCTest, native build, first authenticated read, Keychain roundtrip/relaunch, list selection after restart, status mapping accuracy, multiple-page/bad-network real behavior, offline/cache, disconnect cleanup and UI/accessibility.
