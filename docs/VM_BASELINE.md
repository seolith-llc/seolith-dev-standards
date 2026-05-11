# VM Baseline

This is the default VM guidance for SEOlith build, staging, and small production workloads. Prefer boring, repeatable hosts before adding orchestration.

## Cost-Effective Defaults

| Role | Recommended shape | Disk | Notes |
| --- | --- | --- | --- |
| Build runner | 4 vCPU, 16 GB RAM | 200 GB SSD | Windows 11 Pro or Windows Server. Docker Desktop or Docker Engine as needed. |
| Small app host | 2 vCPU, 4-8 GB RAM | 80-120 GB SSD | Good for one or two low-traffic apps behind Cloudflare. |
| Shared app host | 4 vCPU, 16 GB RAM | 160-250 GB SSD | Good default for multiple .NET/Node apps plus Traefik. |
| Database host | 2-4 vCPU, 8-16 GB RAM | 200+ GB SSD with backups | Keep separate once data matters. Prefer managed Postgres when budget allows. |
| Observability host | 2 vCPU, 8 GB RAM | 150+ GB SSD | Seq/Grafana/Prometheus/Loki for internal use. |

Start with one build runner and one shared app host. Split databases and observability when CPU, disk IO, backups, or blast radius justify it.

## Provider Selection

Use this decision order:

1. Cloudflare Pages/Workers for static PWAs and edge APIs.
2. Managed PaaS for apps that need fast deployment and low ops burden.
3. Small Linux VMs for containerized .NET/Node production services.
4. Dedicated Windows VM only when Windows-specific build or runtime requirements exist.
5. Managed database before self-hosted database for production customer data when possible.

## Recommended Production Linux Host

- Ubuntu 24.04 LTS.
- Docker Engine and Compose plugin.
- Cloudflare Tunnel or Traefik behind Cloudflare proxy.
- Unattended security upgrades enabled.
- `ufw` allowing only SSH from admin IPs and HTTP/HTTPS if not using tunnel-only ingress.
- Non-root deployment user in the `docker` group.
- App data in `/srv/seolith/<app>`.
- Backups for volumes, databases, and object storage manifests.

Bootstrap:

```bash
sudo APP_USER=seolith APP_ROOT=/srv/seolith ./scripts/bootstrap-linux-app-vm.sh
```

## Recommended Windows Build Host

- Windows 11 Pro or Windows Server 2022/2025.
- Git, PowerShell 7, .NET 8 and 10 SDKs, Node 24, Java 21 if Android builds are needed.
- Docker Desktop with WSL2 backend when Docker builds are required.
- Android Studio command line tools for Android packaging.
- Xcode builds must happen on macOS; use a Mac mini or hosted macOS runner for iOS native packaging.
- GitHub Actions runner installed as a service with labels: `self-hosted`, `windows`, `x64`, `seolith-build`, `node24`, `dotnet10`.
- No production secrets stored on disk. Use GitHub environments, Cloudflare secrets, or host-level secret stores.

Bootstrap from an elevated PowerShell prompt:

```powershell
.\scripts\bootstrap-windows-build-vm.ps1 -RunnerName seolith-build-01 -InstallRunner
```

## iOS and Android Form Factors

| Target | Best first path | When to add native packaging |
| --- | --- | --- |
| Android | Installable PWA plus Trusted Web Activity later | Push notifications, Play Store presence, deeper device APIs |
| iOS | Installable PWA | App Store presence, native push flows, subscriptions, device APIs |
| Desktop | Responsive PWA | Offline-first workflows or local file integration |

iOS native builds require macOS. Keep Windows as the main build server, then add one small macOS runner only for iOS packaging.

## Security Baseline

- Cloudflare proxy or tunnel in front of public HTTP services.
- TLS everywhere.
- SSH key auth only; disable password SSH.
- Per-app environment files readable only by deployment user.
- Daily database backups and at least weekly restore test.
- OS and container patch cadence: weekly for normal updates, same day for critical CVEs.
- Central logs with retention and access control.
- Separate staging and production secrets.
- Protected GitHub environments for production deployment.

## Performance Baseline

- Prefer container images with pinned major runtime versions.
- Add health/readiness endpoints and container health checks.
- Keep Node/Angular/Next builds off production VMs; build on the runner and deploy artifacts/images.
- Put static assets on Cloudflare where practical.
- Use Postgres connection pooling for multi-app hosts.
- Track CPU, memory, disk, restart count, p95 latency, 5xx rate, and queue depth where applicable.

## Manageability Baseline

Every VM needs:

- Name, provider, region, IP/domain, owner, monthly budget, and retirement condition.
- Bootstrap notes in this repo or the app repo.
- Backup location and restore command.
- Patch procedure.
- Deployment command.
- Rollback command.
- Monitoring dashboard link.

## First SEOlith VM Layout

Recommended starting point:

1. Keep the current Windows box as `seolith-build-01`.
2. Add one Linux shared app host as `seolith-prod-app-01`.
3. Keep Cloudflare Workers/Pages for edge PWAs such as PraiseIt.
4. Use managed Postgres for production data where possible; otherwise isolate Postgres on `seolith-prod-db-01`.
5. Add a macOS runner only when native iOS packaging becomes mandatory.
