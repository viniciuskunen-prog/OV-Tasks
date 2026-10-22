# Product specification

**Status: design only. No implementation or release.** Last reviewed: 2026-10-22.

## Purpose
A small macOS menu bar *monitor* of work spread across task platforms. Answer, without opening a task manager: (1) how much unfinished work is relevant to me, (2) what changed, and (3) what needs attention now.

## Target users
Individuals and small teams with tasks distributed between Trello, ClickUp, NanoTask and future platforms. Multiple accounts, workspaces and boards may be connected and filtered. User must opt into watched scopes and task ownership rules.

## Version 1.0
- Status item in menu bar with a compact popover and subtle optional unread indicator.
- Four dashboard metrics: **Pending**, **In progress**, **Overdue**, **Completed in last 7 days**.
- Chronological notification/event feed (task title, concise event, local timestamp, source provider, **clickable original task link**).
- Native macOS notifications; click opens original task; category/urgency, user-configured lead time and quiet hours, deduplication.
- Three read-only connectors targeted: ClickUp, Trello, NanoTask. Source-specific capabilities and auth may be gated or explicitly labeled until ready.
- Settings: connect/disconnect, watched scopes, status mapping, notification preferences, local-data removal and diagnostics.
- Local-first. The app runs for anyone with a supported Mac; no dependence on a specific other computer.

## Explicitly not in v1
Full task details, kanban, task modification, Pomodoro/time billing, LLM processing, complex plugin execution, mandatory cloud synchronization, organization-admin dashboards.

## Product invariants
- Task details remain in the source platform; links open there.
- No surprises: initial imports do not produce a flood of “new task” notifications.
- Don't suggest the app is “live” if an account has not synced; show time of last successful sync.
- Counts reflect eligible tasks in selected scopes, not all work accessible to an account.
- “Pending” contains “In progress” and “Overdue”; metric cards **must not** be added together.
- Must remain useful while offline, displaying last cached results with an offline/stale label.
- Clear, reversible, least-privilege connection flow; read-only integration in v1.

## Release acceptance
Three provider integrations validated against authorized real accounts or explicitly marked unsupported until implemented; correct scoped counters; source links work; notification permissions handled; no duplicated alerts after restart; safe logout/delete-local-data; VoiceOver and light/dark support; local installation smoke tests; privacy and license published.

See [ROADMAP](ROADMAP.md) for milestones and [TESTING](TESTING.md) for verification.
