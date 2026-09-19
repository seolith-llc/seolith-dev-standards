# seolith-dev-standards

Central standards hub for the SEOlith estate: reusable GitHub Actions
workflows (Angular/.NET/Node/PWA builds, ECR push, staging deploy, secret
scan), fleet audit scripts, runner install scripts, and the operating docs
every other repo links to. Consumed estate-wide via `@main`.
Tier: platform, P0 (see estate map in seolith-ops-control)

## Build & test

Nothing to build — this repo is workflows, scripts, and Markdown. There is no
CI on the repo itself; the two smoke workflows are manual:

- `self-hosted-runner-smoke.yml` / `self-hosted-windows-runner-smoke.yml`
  (workflow_dispatch) verify the runner pools.

Fleet audits run from a checkout (PowerShell):

```powershell
.\scripts\audit-local-repos.ps1 -Root D:\src\seolith
.\scripts\audit-common-services.ps1 -Root D:\src\seolith
.\scripts\test-fleet-urls.ps1 -AllowProtected
.\scripts\install-precommit-hooks.ps1 -Root D:\src\seolith
```

Validate workflow edits with a consumer repo's PR run — there is no local
harness for `workflow_call` lanes.

## Layout

- `.github/workflows/` — the reusable lanes: `angular-build-lint`,
  `dotnet-build-test`, `node-build`, `node-pwa-build`, `build-push-ecr`,
  `deploy-staging`, `secret-scan` (all `workflow_call`), the weekly org-wide
  `org-secret-scan` sweep (schedule + `workflow_dispatch`), plus the two smokes
- `scripts/` — fleet audit, VM bootstrap, runner install, pre-commit hooks
- `docs/` — CI/CD, branch hygiene, theming, observability, VM baseline,
  deployment inventory, PWA checklist standards
- `templates/` — currently only `.gitleaks.toml` (template gitleaks config;
  the secret-scan lane reads `.gitleaks.toml` from each consumer repo)
- `devcontainers/universal/` — shared devcontainer definition

## Do not touch

- `templates/.gitleaks.toml` loosening: it is the template consumer repos
  copy; a weakened rule propagates to new adopters' secret-scan gates.
- Estate cost constraints (these docs define them, and edits here propagate):
  no new paid services; no snapshots/backups until the first paying customer;
  deploys via OIDC from main only.
- Runner install scripts encode the shared-pool labels other repos'
  `runs-on` depends on — renaming a label breaks consumers estate-wide.

## Deploy

Not deployed. This repo IS deploy machinery: consumers call
`seolith-llc/seolith-dev-standards/.github/workflows/<lane>.yml@main`.
Merging to main is the release.

## Landmines

- Every consumer pins `@main`, and this repo has no CI of its own — a broken
  edit to a reusable workflow ships instantly to every consuming repo's next
  run with no gate in between. Treat workflow edits as production changes;
  they also execute on SEOlith-owned self-hosted hardware.
- `templates/` looks empty in a plain listing — its one file is dotfile
  `.gitleaks.toml`.
- Runner pools are heterogeneous (one Linux host resolves npm to a Windows
  binary through WSL interop); lanes that must be host-independent run in
  containers — preserve that pattern when editing them.
