# Documentation ownership and publishing policy

The project uses **two sources of truth** with different audiences, not mirrored copies.

## Public GitHub — for anyone developing or using OV Tasks
Maintain here: purpose and scope, architecture, source layout, protocol/API contracts, data model, UI behavior, security/privacy guarantees, configuration examples with fake values, installation/build, tests, contribution instructions, technical ADRs, public roadmap, known limitations and release notes.

Documentation should remain accurate and use explicit labels:
- **Implemented** — code exists in the repository.
- **Validated** — tested with linked evidence/environment.
- **Planned** — approved scope, not yet built.
- **Investigating** — hypothesis requiring verification.

Technical decisions that directly affect contributors belong in GitHub ADRs, not only in private notes. A GitHub commit or PR is the audit trail of public code changes.

## Private operational checkpoint — not in GitHub
Private Drive maintains chronological progress, responsible people, decisions on timing/resources, what was attempted, what passed/failed, work sessions, task priorities, private blockers, internal accounts/links, support requests, and next actions. Link to specific public commits/PRs/docs instead of copying the full public architecture into Drive.

**Important security exception:** secrets are never stored in plaintext in either repository **or** Drive, ChatGPT memory, documents, or task comments. Store access tokens/refresh tokens/OAuth client secrets/webhook signing keys in Keychain or a managed secrets vault. Private checkpoint may list an opaque credential **reference** (`Keychain: OVTasks/ClickUp/<account-label>`), where/why it is used and rotation status — without the value. No secret may be placed in a prompt for preservation.

## Update protocol
For each implementation stage:
1. Edit the affected public docs when interfaces/expected behavior change.
2. Implement in a branch and attach truthful local test evidence to the PR.
3. After merge, update private checkpoint with PR/SHA, what changed, remaining blockers, next step, and reference IDs (never secrets).
4. If a public doc and private notes disagree on code behavior, **public code/tests/docs win**; if progress status conflicts, verify the latest source and update the private checkpoint.
5. Review staged docs against the sensitive-data checklist before publishing.

## Public publishing checklist
No user names, private customer identifiers, production board/task URLs, credentials, billing details, internal SSH hosts, service role configurations or copy-pasted private NanoTask code. Prefer synthetic data. Audit screenshots and sample payloads. Document external service requirements without assuming the viewer has maintainer's personal integrations.
