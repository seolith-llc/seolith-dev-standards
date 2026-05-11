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
- `.github/workflows/node-pwa-build.yml`

Production-facing app repos should also satisfy the [common services standard](COMMON_SERVICES_STANDARD.md) before promotion to production.

## Required Gates

- Checkout on `actions/checkout@v5`.
- Node setup on `actions/setup-node@v5`, Node 24 for JavaScript apps.
- .NET setup on `actions/setup-dotnet@v5`.
- High-severity dependency audit where the ecosystem supports it.
- AgentShield scan through the reusable workflows.
- Build artifact validation, not only install/lint.

## Recommended App Workflows

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
