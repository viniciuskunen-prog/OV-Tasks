# Implementation roadmap

**Status (2026-10-22):** M0/M1 accepted. M2 core passed native XCTest 13/13, zero failures and was merged to `main` as PR #5. M2.5 synthetic UI bridge/provider pagination passed real Mac smoke, native build and dark-mode visual/filter QA; PR #6 has been synchronized with `main` and awaits final review. M3+ real providers remain planned; keyboard accessibility #3 remains a public-release blocker.

| Milestone | Goal | Acceptance / exit criteria |
| --- | --- | --- |
| M0 — Documentation baseline | Public repo, developer docs and governance | README, architecture, provider contract, UI spec, security, contributing guide, no secrets |
| M1 — Native shell (accepted with keyboard access debt) | SwiftUI menu bar app with mocked states | Physical Mac build, popover/theme/settings, scenario persistence, demo link dialog, Quit verified; keyboard/VoiceOver reserved for mandatory pre-release QA (#3) |
| M2 — Domain engine (accepted/merged PR #5) | Normalized models, counters, diff, SQLite cache, poll planning | Local `swift test` passes, baseline/duplicate/DST/account-isolation tests pass; M2 is core-only (no live scheduler or UI data binding) |
| M2.5 — UI core bridge (QA passed, PR #6 review pending) | Core-computed synthetic counters/feed plus typed complete-scope provider ingestion | Mac compile + demo screenshot, pagination/failure smoke; absolutely no real account access |
| M3 — ClickUp | First end-to-end provider integration | Authorized scoped tasks, pagination, read-only mapping and links; secrets never in bundle; auth release path documented |
| M4 — Trello | Board/card synchronization | Per-board status mapping, due behavior, scoped connection and links; quota tests |
| M5 — NanoTask | Authenticated least-privilege client | Dedicated API contract, RLS/isolation tests, no publication of private NanoTask internals |
| M6 — Notifications and hardening | Event notifications and trust | Quiet hours, dedup after relaunch, offline/wake, account revocation, local data deletion, accessibility |
| M7 — v1 public release | Release-quality macOS package | Signing/notarization strategy, checksum, reproducible documented local build, smoke on clean Mac, changelog, LICENSE, privacy notice |

See [M1_PROTOTYPE.md](M1_PROTOTYPE.md) for M1 UI evidence, [M2_CORE.md](M2_CORE.md) for M2 core testing, and [M25_PREVIEW_BRIDGE.md](M25_PREVIEW_BRIDGE.md) for the stacked M2.5 preview.

## M0 exit caveat
Publishing the documentation alone is **not** a product release and does not validate third-party API behavior. Choose an open-source license and verify brand assets before distributing binaries or claiming permitted software reuse.

## Release gates
No v1 tag until all public connector claims are backed by tested behavior or clearly feature-gated. No passing test assertions without actual execution evidence. No copy of confidential NanoTask materials in this public repo.

## Later backlog
Read-only declarative REST adapter builder, Asana/Jira/Notion/GitHub providers, opt-in hosted webhook relay, consolidated summaries, cross-device notifications, OV Monitor/remote-machine status, optional AI summarization, localization expansion.

## Work conventions
Prefer small branches + PR with goals, non-goals, reproduction/validation, observed evidence and rollback. PR changes to docs do not warrant macOS CI. Local builds and selective tests first; avoid hosted GitHub Actions expense on every commit.
