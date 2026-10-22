# Integrations, authentication and capabilities

**Status (2026-10-22):** M3A ClickUp GET-only transport, normalized paginated adapter and macOS Keychain store now exist as **untested branch source**. No connection UI or authorized real sync is wired to the app yet. Trello/NanoTask adapters remain planned.

## Shared contract
Each account is independently authorized and limited to selected workspaces/boards. Connector returns normalized task snapshots/events and capability flags. If comments/events/completion timestamps are unavailable, explicitly report unsupported rather than filling in guesses. Tokens are stored in macOS Keychain. **ChatGPT connector credentials are not available to the app and must never be copied into it.**

| Provider | Task object | Status and due dates | Connection plan | Real-time |
| --- | --- | --- | --- | --- |
| ClickUp | Task within list/workspace | Custom statuses; due dates and assignees | Individual API token for developer/testing; OAuth for general users | Webhooks require reachable HTTPS callback |
| Trello | Card within board/list | Status requires per-board list mapping; due/date-complete | Trello-supported authorization; validate OAuth 2.0 public-client route vs app restrictions | Webhooks require reachable callback |
| NanoTask | Authorized task | Status/column and due fields from published contract | Scoped official NanoTask API or authenticated access with enforced RLS | Supabase Realtime may be evaluated |

## ClickUp
ClickUp documents personal API tokens for individual use and OAuth 2.0 Authorization Code for integrations distributed to users. Token exchange uses a **client secret**; it must not be embedded in an open-source macOS bundle. A secure, optional token-exchange backend is one route for frictionless OAuth. A user-supplied individual token may serve a local-first fallback if provider terms permit.

V1 adapter target: list authorized workspaces/lists; fetch paginated tasks with changed timestamps where possible; map arbitrary status categories; link to task URL; track due and completion signals only when confirmed. Handle account-level scopes, pagination and quota. No write API in v1.

**Current M3A source:** `ClickUpReadClient` supports authorized identity and hierarchy discovery, typed GET-only HTTP, complete-scope list pagination and conservative status/date mapping. `ClickUpKeychain` stores individual tokens separately from SQLite. This code is **not yet compiled/tested** and cannot currently be used in the Settings UI; see [M3A acceptance](M3_CLICKUP_FOUNDATION.md). User-supplied personal tokens still carry whatever permissions the ClickUp account grants; the read-only constraint is enforced by *our client methods*, not by narrowing the underlying token's permissions. Public OAuth requires an external confidential token-exchange mechanism, so no client secret is embedded.

Official references:
- https://developer.clickup.com/docs/authentication
- https://developer.clickup.com/docs/webhooks

## Trello
Trello supports token authorization and newer OAuth 2.0 with different **public vs confidential** client configurations. The public client has no secret but may have product constraints; verify that a standalone native menu bar app can register and use the intended flow, callback URLs, refresh and required read scopes before treating OAuth as solved. Trello list names are user-defined; “Done” must be mapped per board/list instead of hard-coded.

V1 target: enumerate authorized boards/lists/cards, statuses, due/dueComplete, member, task URLs and actions if permissions allow. Trello webhooks require a reachable callback URL and verification, so **not mandatory in local-only v1**.

Official references:
- https://developer.atlassian.com/cloud/trello/guides/rest-api/authorization/
- https://developer.atlassian.com/cloud/trello/guides/rest-api/oauth-2-client-configuration/
- https://developer.atlassian.com/cloud/trello/guides/rest-api/webhooks/

## NanoTask
NanoTask is a separate private codebase using Supabase Auth, PostgreSQL/RLS and a PWA. The OV Tasks public repo must not copy proprietary/private implementation or include tenant IDs, endpoints containing secrets, private schema dumps, service-role keys or real customer records. Design a **minimal public authenticated read contract** with per-user authorization checks, stable task URLs, pagination, status/due/completion fields and eventual change stream. Verify these capabilities rather than assuming the existing ChatGPT MCP interface is a public client API.

## Sync policy
Polling is the default. Initial proposed cadence: every 5 minutes while awake, subject to each provider's documented rate limits and user settings. Retry-after and exponential backoff are mandatory. Do not poll when disconnected; do not erase last-good data on failure. Webhooks and hosted OAuth broker are optional separate milestones.

## Adding providers later
Review [PROVIDER_CONTRACT](PROVIDER_CONTRACT.md). Community Swift adapters can be contributed by PR; do not load arbitrary third-party code dynamically in v1. A future declarative REST adapter wizard is a separate feature with input validation, credential isolation and SSRF defenses.
