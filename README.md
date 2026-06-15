# SEOlith Development Standards

## Core Standards

- [Fleet theming standard](docs/THEMING_STANDARD.md): every app supports dark, light, and geo-city themes using shared semantic tokens.
Centralized hub for ecosystem standards: DevContainers, CI/CD templates, Linting/Formatting, and Design System.

## Operating Docs

- [Branch hygiene](docs/BRANCH_HYGIENE.md)
- [CI/CD standard](docs/CI_CD_STANDARD.md)
- [Common services standard](docs/COMMON_SERVICES_STANDARD.md)
- [Deployment inventory](docs/DEPLOYMENT_INVENTORY.md)
- [PWA launch checklist](docs/PWA_LAUNCH_CHECKLIST.md)
- [Observability standard](docs/OBSERVABILITY_STANDARD.md)
- [VM baseline](docs/VM_BASELINE.md)

## Local Repo Audit

From this repo:

```powershell
.\scripts\audit-local-repos.ps1 -Root C:\src\seolith
.\scripts\audit-common-services.ps1 -Root C:\src\seolith
.\scripts\test-fleet-urls.ps1 -AllowProtected
```

`test-fleet-urls.ps1` reads the Apps Showcase catalog seed by default, checks every public URL, and classifies responses as app, protected, placeholder, or broken. Omit `-AllowProtected` when protected/auth-gated catalog entries should fail the check.

## Local Pre-Commit Hooks

Install the standard local `gitleaks` pre-commit hook into every Git repo under the fleet root:

```powershell
.\scripts\install-precommit-hooks.ps1 -Root C:\src\seolith
```

Use `-Force` when existing hooks should be replaced with the current standard hook.

## 🛡️ Built-in Security (AgentShield)
All reusable CI/CD workflows (`.github/workflows/*.yml`) in this repository are pre-configured with **AgentShield**. 
When an application inherits these workflows, it automatically gets:
- Secrets detection (API keys, tokens)
- Misconfiguration auditing
- Dependency vulnerability scanning
- Node/Angular/.NET/PWA build validation through reusable workflows

If a critical vulnerability is found, the CI build will fail automatically (`--fail-on-critical`), preventing insecure code from being merged or deployed.
