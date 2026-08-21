# CI/CD Standard

## Runner Standard

Use the organization Windows self-hosted runner for private SEOlith builds:

```yaml
runs-on: ${{ fromJSON('["self-hosted","windows","x64"]') }}
env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
```

Prefer reusable workflows from this repo:

- `.github/workflows/dotnet-build-test.yml`
- `.github/workflows/angular-build-lint.yml`
- `.github/workflows/node-build.yml`
- `.github/workflows/node-pwa-build.yml`

Production-facing app repos should also satisfy the [common services standard](COMMON_SERVICES_STANDARD.md) before promotion to production.

## Security Gates

A 2026-08-19 estate audit found Dependabot in 1 of 96 repos, zero SAST anywhere, no dependency-review gate, and the conformance script unwired from CI. These gates close that. Adopt them in each repo's PR workflow (the caller's own workflow file sets `on: pull_request`); pin to the current immutable release rather than `@main`.

M1 permits GitHub-hosted runners only in the read-only `security-gates.yml` workflow. Build and deployment workflows remain subject to the self-hosted runner requirement; this exception keeps security analysis isolated from production credentials while avoiding a persistent runner for untrusted PR code.

### Conformance (M1–M10 MUST rules)

Runs `scripts/seolith-conformance.sh` against the calling repo. Default mode `--new-only` fails only on findings not in the committed `.seolith-conformance-baseline` — run the script locally with `--write-baseline` once and commit the result before wiring the gate. Waivers live in the repo's `.seolith-waivers` (see the script header).

```yaml
jobs:
  conformance:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/conformance.yml@v1.0.2
```

### CodeQL (SAST)

Default languages `javascript-typescript` (no build required). .NET repos: C# needs a build to extract — pass `languages: csharp` and prefer a repo-local workflow with restore/build steps between init and analyze.

```yaml
jobs:
  codeql:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/codeql.yml@v1.0.2
```

### Dependency review (PR gate)

Fails the PR when a changed dependency introduces a vulnerability of moderate severity or higher.

```yaml
jobs:
  dependency-review:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/dependency-review.yml@v1.0.2
```

### Dependabot

Dependabot cannot be a reusable workflow — copy [templates/dependabot.yml](../templates/dependabot.yml) to `.github/dependabot.yml` in each repo and uncomment the blocks for the repo's stack. Weekly cadence, 5 open PRs max.

## Required Gates

- Checkout on `actions/checkout@v5`.
- Node setup on `actions/setup-node@v5`, Node 24 for JavaScript apps.
- .NET setup on `actions/setup-dotnet@v5`.
- High-severity dependency audit where the ecosystem supports it.
- AgentShield scan through the reusable workflows.
- Build artifact validation, not only install/lint.

## Recommended App Workflows

### Node PWA

### Node App

```yaml
jobs:
  node:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/node-build.yml@main
    with:
      project-path: .
```

### Node PWA

```yaml
jobs:
  pwa:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/node-pwa-build.yml@main
    with:
      project-path: .
      output-path: dist
```

For Next static exports, set `output-path: out`. For nested apps, set `project-path: frontend` or the app directory.

### Angular

```yaml
jobs:
  angular:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/angular-build-lint.yml@main
    with:
      runs-on: '["self-hosted","windows","x64"]'
      node-version: "24"
      project-path: angular
```

### .NET

```yaml
jobs:
  dotnet:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/dotnet-build-test.yml@main
    with:
      runs-on: '["self-hosted","windows","x64"]'
      dotnet-version: 10.0.300-preview.0.26177.108
      project-path: YourSolution.sln
```

## Deployment Requirements

Every production deployment should document:

- Production URL.
- Build artifact or image tag.
- Hosting target.
- Required secrets.
- Health check URL.
- Rollback command.
- Owner or escalation path.
