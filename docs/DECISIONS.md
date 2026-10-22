# Architecture decision register

Public **technical decisions** belong here (and later can migrate into individual ADR files). Internal meeting history, access credential references, business priorities, private account links and work checkpoints do **not** belong in this repository.

| ID | Decision | Status | Rationale |
| --- | --- | --- | --- |
| D-001 | Native macOS menu bar app, Swift/SwiftUI | Proposed | Small native utility, no Electron runtime |
| D-002 | Local-first; optional server later | Accepted (product) | Useful to any GitHub installer without author's infrastructure |
| D-003 | Read-only v1; direct links to providers | Accepted (product) | Avoid duplicating source task management |
| D-004 | Normalized tasks/events behind provider adapters | Accepted (architecture direction) | Independent UI and additional providers |
| D-005 | First baseline sync suppresses historical alerts | Accepted (product) | No notification floods |
| D-006 | Keychain for tokens; no secrets in source/memory/docs | Accepted (security policy) | Minimize leaked credential risk |
| D-007 | Four overlapping metrics, Done within 7-day window | Proposed (requires UX sign-off) | Clear dashboard labels without misleading sum |
| D-008 | ClickUp OAuth via secure confidential exchange or opt-in user token fallback | Under investigation | Provider flow needs client secret; cannot embed it |
| D-009 | Trello OAuth 2.0 public-client suitability for standalone native macOS | Under investigation | Official public clients exist, but native callback/client policy needs validation |
| D-010 | Persistence backend: direct SQLite vs vetted wrapper | Open | Choose after first domain spike |
| D-011 | Open-source license MIT vs Apache-2.0 | Open | LICENSE must be selected before redistribution |
| D-012 | Polling around 5 min while awake | Proposed | To validate against quotas and power usage |
| D-013 | No hosted GitHub Actions by default | Accepted (engineering policy) | Prefer local QA and selective release gates |

Record amendments with date, motivation, alternatives and follow-up tests. The operational owner checkpoint is not reproduced here.
