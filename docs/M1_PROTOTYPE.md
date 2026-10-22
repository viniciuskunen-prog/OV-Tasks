# M1 — Native menu bar visual prototype

**Status: source implemented, native compilation and visual validation pending.**

M1 is intentionally a **design/interaction preview**. All counter values, task titles, events, timestamps and provider badges are generated from synthetic in-memory fixtures. There are no API calls, account connections, background sync, macOS notification scheduling, database files or saved credentials. A future milestone will implement those systems.

## Run on macOS 14+

Requirements: Apple Silicon or Intel Mac running macOS 14+ and Apple's Xcode Command Line Tools (a full Xcode install also works).

From a clean checkout of this branch:

\`\`\`zsh
cd OV-Tasks
zsh ./build.sh
open ./build/OVTasks.app
\`\`\`

The local build uses \`xcrun swiftc\`, assembles \`build/OVTasks.app\` in the checkout and signs it **ad hoc for local testing** if \`codesign\` is available. It **does not** install into \`/Applications\`, require a developer team, run GitHub Actions, create a GitHub Release or notarize a distributable binary.

\`build/\` is ignored by Git. The app is labeled \`OV Tasks Preview\`, separate from a future stable app identity.

## Inspect the popover

1. Find the checklist icon in the macOS menu bar; click it to open the panel.
2. Confirm compact dimensions (design target: ~428×584 pt) and four counters: Pending, In progress, Overdue, Completed.
3. Read the activity feed, change the **All/Important** filter.
4. Click **Open in [provider]** on a synthetic event. A **demo alert** explains that there is no real destination yet. This verifies a clickable control without pretending that a real task URL exists.
5. Use the slider/control icon at top-right to switch the scenario between **Overview**, **Empty**, **Offline**, **Reconnect**, and **Loading**.
6. Open **Settings** using the gear icon; change the same scenario and filter there. Confirm the connection and notification sections are clearly labeled as future features.
7. Close the panel; reopen from menu bar. The utility should remain running.
8. Use **Quit** in the footer to terminate.

**UI strings are currently PT-BR.** English docs describe the behavior for contributors; localization is a future task.

## Visual QA requested

Capture screenshots for each scenario in dark and light mode (do not include personal task data, since none are used). Check:

- All four metric titles remain legible; no clipping near the menu bar/screen edges.
- A long task title truncates intentionally; date/source/action remain visible.
- Text scale and VoiceOver actions can reach scenario menu, settings link, event action, filter and Quit.
- Clicking the Settings link actually opens the Settings scene when running as an LSUIElement app.
- Reopening the popover doesn't reset the selected scenario unexpectedly.
- The macOS app stays running when the popover closes.

If compiler diagnostics occur, record the full error and output of:

\`\`\`zsh
sw_vers -productVersion
xcrun swiftc --version
xcode-select -p
\`\`\`

Do not claim M1 was compiled or passed until the real Mac build and smoke results are recorded.

## Code layout

\`\`\`text
Sources/OVTasksApp/
  OVTasksApp.swift                  # SwiftUI MenuBarExtra and Settings scenes
  Preview/PreviewData.swift        # synthetic data and scenarios
  Views/DashboardView.swift        # dashboard, feed and clickable simulated links
  Settings/PreviewSettingsView.swift # state switches and planned integrations
build.sh                            # local .app bundle generator
\`\`\`

## Not included (deliberate)

ClickUp/Trello/NanoTask OAuth, token storage, API fetch, background timers, persistence, notifications, onboarding workflows, live status, and real task URL launches.

## Known potential refinements

The visual prototype uses a fixed size and a 4-column metrics row. Verify legibility at increased macOS text scaling; if it clips, use adaptive 2-column layout. Verify the menu bar menu style, SettingsLink availability and macOS accessibility behavior on a physical Mac.

## Gate to M2

M1 is acceptable only when the owner has visually approved both system appearances and a local smoke test has confirmed menu bar lifecycle and settings interaction. M2 can then introduce model/store/event unit tests without changing the public UI contract prematurely.
