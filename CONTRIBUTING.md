# Contributing to OV Tasks

The project is in the **design phase**. Issues proposing provider support, UX changes, test cases and platform reliability improvements are welcome.

## Before coding
Read [PRODUCT](docs/PRODUCT.md), [ARCHITECTURE](docs/ARCHITECTURE.md), [PROVIDER_CONTRACT](docs/PROVIDER_CONTRACT.md), [SECURITY](docs/SECURITY.md) and [DOCUMENTATION_POLICY](docs/DOCUMENTATION_POLICY.md). Do not treat planned behavior as an implemented feature.

## PR requirements
- One understandable goal, explicit non-goals and named affected modules.
- Minimal changes; add/update public docs for changed behavior or external contracts.
- For bug fixes: reproducer and regression test failing before and passing after, or documented reason a manual check is required.
- Record **actual** commands run and observed outcomes; don't fabricate green CI or hardware tests.
- Synthetic fixtures only. No user tokens, task payloads, workspace names or credentials in commits, logs, screenshots or PR comments.
- Explain security/permission effects, backward compatibility, rollback and why dependencies are warranted.

## Local-first CI budget
Prefer local Swift builds/tests. Do not introduce costly automatic hosted macOS builds, release pipelines or new credential requirements without a concrete proposal and review. All CI additions must explain triggers, branch restrictions and expected costs.

## Provider contributions
Implement the typed adapter and capability flags, source URL validation, pagination, quota handling, error classification and test fixtures. A connector must not need access to another provider's credentials or the user's private file system.

## Development status
No Xcode project and no executable code are present at the documentation bootstrap milestone. Build instructions will be added and verified when the shell is implemented.
