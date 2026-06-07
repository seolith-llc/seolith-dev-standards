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
```

## 🛡️ Built-in Security (AgentShield)
All reusable CI/CD workflows (`.github/workflows/*.yml`) in this repository are pre-configured with **AgentShield**. 
When an application inherits these workflows, it automatically gets:
- Secrets detection (API keys, tokens)
- Misconfiguration auditing
- Dependency vulnerability scanning
- Node/Angular/.NET/PWA build validation through reusable workflows

If a critical vulnerability is found, the CI build will fail automatically (`--fail-on-critical`), preventing insecure code from being merged or deployed.
