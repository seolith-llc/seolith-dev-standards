# SEOlith Self-Hosted GitHub Actions Runner

Use an organization-level runner for heavy SEOlith builds so private repo CI does not depend on GitHub-hosted minutes.

## Recommended Runner

- Scope: `seolith-llc` organization runner.
- Runner group: `seolith-core-build`.
- Labels: `self-hosted`, `linux`, `x64`, `seolith-build`, `docker`, `dotnet10`, `node24`.
- OS: Ubuntu 24.04 LTS.
- Size: 4-8 vCPU, 16-32 GB RAM, 150+ GB disk.

## Security Rules

- Do not allow untrusted fork pull requests to run on this runner.
- Keep production deploy jobs behind protected branches and protected environments.
- Run the runner as an unprivileged `github-runner` user.
- Give Docker access only if the build requires Docker.
- Do not store production secrets in runner files.
- Rotate the runner if a workflow or dependency is suspected compromised.

## Install

On the build VM:

```bash
sudo ./scripts/install-github-runner.sh seolith-llc seolith-build-01
```

The script prints a GitHub URL and asks for a short-lived registration token. Generate the token from:

`https://github.com/organizations/seolith-llc/settings/actions/runners/new?arch=x64&os=linux`

Choose Linux x64, then copy only the registration token into the script prompt.

## Workflow Usage

Reusable workflows accept a JSON `runs-on` input:

```yaml
jobs:
  dotnet-build-test:
    uses: seolith-llc/seolith-dev-standards/.github/workflows/dotnet-build-test.yml@main
    with:
      runs-on: '["self-hosted","linux","x64","seolith-build"]'
```

If the runner is offline, jobs using that label will queue. Temporarily remove the `runs-on` input to fall back to GitHub-hosted runners.
