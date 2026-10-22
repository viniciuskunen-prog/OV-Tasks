# Agent instructions for OV Tasks

Public development instructions for code assistants and human contributors.

1. Read README and docs/PRODUCT.md, ARCHITECTURE.md, SECURITY.md, DATA_MODEL.md, PROVIDER_CONTRACT.md and ROADMAP.md before modifications.
2. Distinguish *planned*, *implemented* and *validated*. Never claim compilation, test success, service availability or real-time capability without evidence.
3. The v1 app is read-only, locally operable and compact; do not add task editing, an obligatory server, broad LLM features or third-party plugin execution without explicit scope change.
4. Preserve public/private documentation split in docs/DOCUMENTATION_POLICY.md. Never copy or publish internal checkpoints, private NanoTask source, real account data or credentials.
5. Never include tokens, OAuth client secrets, keys, passwords, private file paths, or URLs containing secrets in source, logs, PRs, documentation or chat memory. Use Keychain / managed secrets. Do not turn off Gatekeeper/SIP for convenience.
6. Scope each task: what to change, what not to change, how to test before, and verifiable outcome. Prefer small reversible commits and PRs.
7. Add a reproducing test for each fix where feasible. Test domain logic with fixtures, then run scoped local smoke checks. Identify what could not be tested.
8. No automatic costly GitHub Actions or paid runner usage. Hosted builds only by explicit opt-in and budget review; default to local checks and manual release validation.
9. Treat provider API payloads as untrusted. Validate identifiers, URLs, timezones, status mapping, rate limits, cursors, permissions and error cases.
10. Respect macOS sleep/offline limits. Never promise immediate notifications when an app cannot execute.

Do not include internal Drive links, credentials or private operation history in this file.
