# Batch 3 rollout: link checking + Lighthouse budgets

Shared reusable workflows implementing two items of the
[site essentials standard](SITE_ESSENTIALS_STANDARD.md):

- **Item 16 (broken links)** → `.github/workflows/link-check.yml` (lychee)
- **Item 12 (page load speed budget)** → `.github/workflows/lighthouse.yml` (Lighthouse CI)

Both are `workflow_call` lanes consumed from
`seolith-llc/seolith-dev-standards`, exactly like `node-build` /
`dotnet-build-test`. Both ship **report-only by default** during rollout:
findings are written to the job summary and to artifacts, but the check
stays green until the caller opts into enforcement.

## Runner selection (estate rule)

- **Private repos** (the majority): omit `runs-on` — the default is the
  self-hosted Linux pool (`["self-hosted","Linux","X64","seolith-local","node-capable"]`).
- **Public repos**: pass `runs-on: '["ubuntu-latest"]'`. Self-hosted runner
  groups do not accept public repos, and the estate rule forbids it anyway.
  The `resolve-runner` guard job runs on `ubuntu-latest` for all callers so
  public repos never wait on a self-hosted label.

## link-check.yml (standard item 16)

Caller (`.github/workflows/link-check.yml` in the consuming repo):

```yaml
name: Link Check

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  link-check:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/link-check.yml@main
    with:
      scan-path: "."                 # repo markdown+HTML; or "dist" / "landing" for built output
      # args: "--base https://example.com"   # extra lychee CLI args
      # runs-on: '["ubuntu-latest"]'         # REQUIRED for public repos
      # fail-on-error: true                  # enforcement (see below)
```

Notes:

- Estate defaults exclude mailto:, localhost/loopback, and RFC1918/private
  links, and retry 3× with a 20s timeout. Add host-specific exceptions via
  a `.lycheeignore` in your repo (lychee reads it automatically), not by
  weakening the shared defaults.
- Results are always in the job summary and the `lychee-results` artifact.
- **Flip to enforced:** set `fail-on-error: true`. Per the standard,
  marketing sites must enforce; app repos with frequently changing external
  references may stay report-only.

## lighthouse.yml (standard item 12)

Caller (`.github/workflows/lighthouse.yml` in the consuming repo):

```yaml
name: Lighthouse Budgets

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  lighthouse:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/lighthouse.yml@main
    with:
      project-path: "client"                 # where package.json lives
      # install-command: "npm ci"            # default; "" skips (plain static sites)
      # build-command: "npm run build"       # default; "" skips
      output-dir: "dist/client/browser"      # relative to project-path
      urls: |                                # paths served locally, or absolute URLs
        /
        /privacy
      budget-preset: "marketing"             # marketing >= 0.90 | app >= 0.75; LCP < 2.5s on both
      # budget-file: "lighthouserc.json"     # custom lhci config (ci.assert); overrides preset
      # runs: 3                              # raise from 1 when enforcing, for score stability
      # continue-on-error: false             # enforcement (see below)
      # runs-on: '["ubuntu-latest"]'         # REQUIRED for public repos
    secrets:
      PACKAGES_READ_TOKEN: ${{ secrets.PACKAGES_READ_TOKEN }}  # only if npm deps come from GitHub Packages
```

Notes:

- The lane builds, serves `output-dir` statically (SPA fallback enabled),
  runs Lighthouse mobile + simulated throttling against each URL, and
  asserts the budget. HTML/JSON reports land in the `lighthouse-results`
  artifact; per-URL report links go to the job summary via temporary public
  storage.
- **Flip to enforced:** set `continue-on-error: false` (and consider
  `runs: 3`). The standard requires budget regressions to block release for
  marketing pages.
- Custom budgets: `budget-file` must be a lighthouserc-style JSON with a
  top-level `ci.assert` block (score assertions like the presets, or
  `ci.assert.budgetsFile` pointing at a classic Lighthouse budgets.json).

## Rollout sequence per repo

1. Add both callers in report-only mode (defaults). Open the PR, read the
   job summaries, fix or `.lycheeignore` the noise.
2. When a run is clean (or the remaining findings are accepted), flip
   `fail-on-error: true` / `continue-on-error: false` in a follow-up PR.
3. Tick items 12 and 16 in the README compliance table (standard, bottom).

Copy-ready callers also live in `templates/link-check.yml` and
`templates/lighthouse.yml` in this repo.
