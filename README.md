# SEOlith Development Standards

## Core Standards

- [Fleet theming standard](docs/THEMING_STANDARD.md): every app supports dark, light, and geo-city themes using shared semantic tokens.
Centralized hub for ecosystem standards: DevContainers, CI/CD templates, Linting/Formatting, and Design System.

## Operating Docs

- [Architecture standard](docs/ARCHITECTURE_STANDARD.md) — tiering, gates, split/consolidate criteria, decision log
- [AI agent handover](docs/AI_AGENT_HANDOVER.md) — when a repo is agent-ready, CLAUDE.md schema, agent permission model
- [Branch hygiene](docs/BRANCH_HYGIENE.md)
- [CI/CD standard](docs/CI_CD_STANDARD.md)
- [Common services standard](docs/COMMON_SERVICES_STANDARD.md)
- [Tester v1 standard](docs/TESTER_V1_STANDARD.md) — private manual QA catalog, offline evidence, host adoption and conformance criteria; rollout is recorded per app
- [Estate convergence plan](docs/CONVERGENCE_PLAN.md) — 2026-09-01 adoption audit + wave-ordered plan to retire duplicated auth/mail/logging across the fleet
- [Deployment inventory](docs/DEPLOYMENT_INVENTORY.md)
- [PWA launch checklist](docs/PWA_LAUNCH_CHECKLIST.md)
- [Observability standard](docs/OBSERVABILITY_STANDARD.md)
- [Site essentials standard](docs/SITE_ESSENTIALS_STANDARD.md) — 20-point compliance baseline every web repo must meet (legal pages, security headers, SEO, accessibility, performance, forms); audits run from seolith-ops-control
- [Batch 3 rollout: link check + Lighthouse budgets](docs/BATCH3_ROLLOUT.md) — caller setup for the shared `link-check.yml` (item 16) and `lighthouse.yml` (item 12) reusable lanes, and how to flip from report-only to enforced
- [VM baseline](docs/VM_BASELINE.md)
- [Project board workflow standard](docs/PROJECT_BOARD_WORKFLOW.md) — standard Kanban columns and workflow for GitHub Project boards.

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

## Org-Wide Secret Sweep

`.github/workflows/org-secret-scan.yml` runs every Sunday 03:47 UTC (and on
`workflow_dispatch`) and sweeps **every non-archived repo in seolith-llc** —
including repos that never adopted the per-repo `secret-scan.yml` gate. The
gate blocks PRs; the sweep reports drift:

- Working-tree gitleaks (same pinned, checksum-verified 8.30.1 binary as the
  gate), `--redact`, per-repo batched matrix jobs on the `linux-build` pool.
- Each repo is scanned with its own `.gitleaks.toml` when present (repo-local
  allowlists are respected), else the canonical config from this repo.
- Findings are **reported, not gated**: the job fails only on scanner
  infrastructure errors (clone/scanner failures), never on findings.
- Output: a job summary plus an `org-secret-sweep-report` artifact
  (`summary.md`, `findings.jsonl` with repo/rule/file:line, values redacted),
  including drift lists — repos without the PR gate and repos without a
  repo-local config.

Cross-repo access uses the dedicated `seolith-secret-sweep` GitHub App
(contents: read-only; GITHUB_TOKEN cannot enumerate or clone the org's private
repos). Provisioning it is a one-time owner action — see
[docs/OWNER_ACTIONS.md](docs/OWNER_ACTIONS.md). Until then the sweep fails
fast with that pointer rather than silently scanning only public repos.

## 🛡️ Built-in Security (AgentShield)
All reusable CI/CD workflows (`.github/workflows/*.yml`) in this repository are pre-configured with **AgentShield**. 
When an application inherits these workflows, it automatically gets:
- Secrets detection (API keys, tokens)
- Misconfiguration auditing
- Dependency vulnerability scanning
- Node/Angular/.NET/PWA build validation through reusable workflows

If a critical vulnerability is found, the CI build will fail automatically (`--fail-on-critical`), preventing insecure code from being merged or deployed.
