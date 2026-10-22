# OV Tasks

Open-source macOS menu bar dashboard for task activity across multiple services.

> **Status (2026-10-22):** M1 native preview validated; M2 domain/SQLite core passed 13 native XCTest cases (0 failures) and five independent local regression groups. M2.5 synthetic UI bridge validated in a stacked draft PR, pending integration. No stable public release or live provider connections.

OV Tasks answers two questions: **How much work is pending?** and **What changed while I was working?** It intentionally does not replace a task manager.

## Planned experience

- Compact macOS menu bar dashboard with **Pending**, **In progress**, **Overdue** and **Completed (last 7 days)** counters.
- Recent activity: concise status changes, due dates and assignments, each with a direct link to the original task.
- Native, actionable macOS notifications with deduplication and quiet hours.
- Read-only connectors planned for **ClickUp, Trello and NanoTask**; a provider-adapter architecture for future services.
- Local-first operation without requiring the maintainer's Mac mini or a permanent server.

## Try the M1 interface preview

On macOS 14+ with Xcode Command Line Tools, from a checkout:

```zsh
zsh ./build.sh
open ./build/OVTasks.app
```

The build output is local, unsigned for distribution (ad-hoc only), and uses fictional data exclusively. **No login, network sync or native notifications** are implemented yet. See [M1 prototype and QA guide](docs/M1_PROTOTYPE.md).

## M2 core tests (development branch)

The M2 branch introduces `OVTasksCore` as a separate Swift Package with normalized task models, scoped counters, baseline-safe event diffs, atomic SQLite snapshots and deterministic tests. **This core is not yet connected to the M1 popover.** Run `swift test` on a Mac with Command Line Tools; see [M2 core and QA](docs/M2_CORE.md). Its correctness is **not yet validated** until those tests pass.

## Project documentation

- [M1 native interface preview / build / visual QA](docs/M1_PROTOTYPE.md)
- [M2 core, local persistence and Swift test guide](docs/M2_CORE.md)
- [Product specification](docs/PRODUCT.md)
- [System architecture](docs/ARCHITECTURE.md)
- [User experience and layout](docs/UI_UX.md)
- [Provider integrations](docs/INTEGRATIONS.md)
- [Provider adapter contract](docs/PROVIDER_CONTRACT.md)
- [Notifications and event rules](docs/NOTIFICATIONS.md)
- [Data model and metrics](docs/DATA_MODEL.md)
- [Security and privacy](docs/SECURITY.md)
- [Roadmap and acceptance criteria](docs/ROADMAP.md)
- [Testing strategy](docs/TESTING.md)
- [Architecture decision records](docs/DECISIONS.md)
- [Public/private documentation policy](docs/DOCUMENTATION_POLICY.md)
- [Contributor guidelines](CONTRIBUTING.md)
- [Agent instructions](AGENTS.md)

## Scope boundaries

The first release is **read-only**. No task editing, Kanban, time tracker, LLM cloud dependency or mandatory hosted service. Some authentication or real-time features may need optional services; these will be clearly labeled as optional.

## Contributing

Contributions and proposals are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). The initial architecture is a design, not an assertion that features already exist.

**Licensing decision pending.** Do not assume the source is licensed for redistribution until the project publishes a LICENSE file.

