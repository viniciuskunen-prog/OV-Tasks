# Security and privacy model

**Status (2026-10-22):** M3A development branch adds an **untested** macOS Keychain token store and pinned read-only ClickUp client. Security audit, live connection review and release controls remain mandatory.

## Principles
Local-first, read-only, least privilege, transparent source selection and data minimization. This public repository **must not contain secrets, real task data, private customer information, personal access links or internal operational history**.

## Secrets (strict)
Never commit or paste into GitHub, issues, PRs, app logs, design documents or a model memory:
- access/refresh tokens, private OAuth client secrets, webhook signing secrets
- API keys with privileged access, passwords, session cookies
- NanoTask Supabase service-role key, private database URLs, SSH keys or personal tokens

Runtime provider credentials must live in **macOS Keychain**, not UserDefaults, plaintext files, a spreadsheet, Google Docs or chat history. M3A contains a per-account Keychain implementation that must be verified with real app signing/access before actual tokens are accepted. Hosted confidential OAuth or webhook endpoints, if introduced later, use a managed secrets store/secret environment, rotation and strict per-service authorization. The private operator checkpoint may describe **credential name/reference, owner, account, scope, expiration or where it is kept**, but **never the credential value**.

If a secret is exposed, revoke/rotate it, remove unauthorized storage, assess any access and record an incident without pasting the secret again. Git history removal alone is not a substitute for rotation.

## Authentication
Every connected account has its own token isolation and explicit resource selection. Validate OAuth state, callback origin/redirect registration, token lifetime/refresh, revocation behavior and granted scopes against official documentation. ClickUp OAuth client secret must never ship in a desktop bundle. Trello authentication must be validated for native application distribution. NanoTask reads require documented authenticated endpoints with RLS and tenant-isolation tests; do not use server/service-role credentials as an end-user integration.

## Network
Allow HTTPS only for known providers and explicit user-approved custom integrations. Validate redirects, endpoint hostnames and schema; protect a future REST mapping wizard from SSRF/internal IP access. Enforce reasonable timeouts, pagination and rate limits. Do not log URLs containing tokens/query credentials.

## Local data
Store only task summaries, event metadata, selected scopes and sync cursors needed by the product. Exclude detailed descriptions, attachments, comments bodies and personal email unless specifically necessary and consented to. Local SQLite/SwiftData file protected by macOS access controls; evaluate stronger encryption if threat model requires it. Clear per-account cache and Keychain entries on disconnect; offer **Erase local data** in settings. Suggested event retention: 30 days, subject to user approval, tests and privacy policy.

## Notifications
Task titles can expose confidential details on a shared/locked screen. Provide generic-title option, quiet hours, per-source filtering, suppression by default for low priority. URL actions must only open validated task links.

## Build and distribution
Use code-signing/notarization when feasible and publish checksums for releases. Never recommend disabling Gatekeeper, SIP or quarantine as a normal install path. Static and integration tests should run locally where possible; expensive GitHub Actions must be explicitly reviewed. Public plugins cannot be loaded as untrusted dynamic code in v1.

## Reporting
Security issues: use the repo's private security reporting when configured; until then avoid publishing proof-of-exploit payloads or credentials in issues. Confirm a contact process before first public release.
