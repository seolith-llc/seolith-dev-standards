# SEOlith Self-Hosted GitHub Actions Runner

Use an organization-level runner for heavy SEOlith builds so private repo CI does not depend on GitHub-hosted minutes.

## Recommended Runner

- Scope: `seolith-llc` organization runner.
- Runner group: `seolith-core-build` preferred; `Default` is acceptable while bootstrapping.
- Labels: `self-hosted`, `windows`, `x64`, `seolith-build`, `docker`, `dotnet10`, `node24`.
- OS: Windows 11 Pro, Windows Server 2022, or Windows Server 2025.
- Size: 4-8 vCPU, 16-32 GB RAM, 150+ GB disk.

## Security Rules

- Do not allow untrusted fork pull requests to run on this runner.
- Keep production deploy jobs behind protected branches and protected environments.
- Run the runner as a dedicated low-privilege local user when possible.
- Give Docker access only if the build requires Docker.
- Do not store production secrets in runner files.
- Rotate the runner if a workflow or dependency is suspected compromised.

## Install

On this Windows build box, open PowerShell as Administrator:

```powershell
.\scripts\install-github-runner.ps1 -Organization seolith-llc -RunnerName seolith-build-01
```

If the `seolith-core-build` runner group already exists, use:

```powershell
.\scripts\install-github-runner.ps1 -Organization seolith-llc -RunnerName seolith-build-01 -RunnerGroup seolith-core-build
```

The script prints a GitHub URL and asks for a short-lived registration token. Generate the token from:

`https://github.com/organizations/seolith-llc/settings/actions/runners/new?arch=x64&os=win`

Choose Windows x64, then copy only the registration token into the script prompt.

The older Linux bootstrap remains available at `scripts/install-github-runner.sh` if you add a Linux runner later.

## Workflow Usage

Reusable workflows accept a JSON `runs-on` input:

```yaml
jobs:
  dotnet-build-test:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/dotnet-build-test.yml@main
    with:
      runs-on: '["self-hosted","windows","x64","seolith-build"]'
```

If the runner is offline, jobs using that label will queue. Temporarily remove the `runs-on` input to fall back to GitHub-hosted runners.
