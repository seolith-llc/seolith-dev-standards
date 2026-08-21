# Hosting Consolidation Plan

Goal: least hosting charges without reliability loss. From the 2026-08-19 audit:
everything is self-hosted on AWS EC2 (us-east-2) + ECR + nginx/Traefik, including
purely static sites. Cloudflare already manages ~30 estate domains and hosts
Workers (hype-buddy telemetry, fishbowl push) — Pages is the missing free tier.

## Target architecture

| Workload | Where | Why |
|---|---|---|
| Static sites / PWAs (no server state) | **Cloudflare Pages** ($0, unlimited bandwidth) | ~15 repos serve files; EC2 charges instance-hours for that |
| Small .NET vertical APIs (low traffic) | **seolith-domain-suite pattern** — multi-domain single runtime, or N apps per EC2 host | One host serves many low-traffic verticals |
| Stateful SaaS (Postgres-backed, multi-tenant) | **EC2 as-is** (eventkeep, pto-admin, goptr, tax-manager, second-chance-leads, omnifield, main-site, twbb, portal) | Real state, real traffic |
| Shared infra (Authentik, Seq, Traefik, vault, Stalwart mail) | **EC2 as-is** (seolith-shared VM) | Core estate services |
| React Native / Capacitor mobile | app stores, unchanged | — |

## Pages migration candidates (static/PWA)

- `seolith-reference-sites` — 10 Astro marketing sites; the single biggest win (one repo, 10 Pages projects). Also already has a workers/ dir.
- `seolith-hindi-buddy`, `seolith-learn-tamil-letters`, `critter-path-adventures`, `seolith-praiseit` (partially on Workers already), `seolith-debug-dojo`, `hype-buddy`, `seolith-fishbowl` (site app), `vroom-boom-app`, `vroom-boom-buggies`, `seolith-next-gen-site`, `pci-hvac` (static mirror)
- `sight-fix`, `seolith-teselith` frontends (static PWA shells; their APIs, if any, stay or consolidate)
- NOT `seolith-box-breathing` (removed from the 2026-08-21 pilot): its vinext build
  emits a Cloudflare **Worker** (`dist/server/wrangler.json`) with D1/R2 bindings,
  so `pages deploy` cannot host it. It needs a Workers lane with provisioned
  D1/R2 resources — separate, deliberate work, not part of the static sweep.

## Migration procedure per app

1. Add a caller of `pages-deploy.yml` (this repo, @v1.1.1+): build + deploy on push to main.
   The lane auto-creates the Pages project when missing and publishes
   `https://<project>.pages.dev`. If the repo's lockfile pulls `@seolith-llc/*`
   from GitHub Packages, also pass `packages-read-token: ${{ secrets.PACKAGES_READ_TOKEN }}`.
2. Verify the pages.dev URL (health-check the site; PWAs check the service worker).
3. Custom domain cutover (deliberate, per domain): Pages project settings → add custom
   domain; Cloudflare DNS flips automatically since CF already manages the zone.
   Old EC2/nginx vhost stays up until DNS TTLs expire — zero-downtime by construction.
4. Decommission: remove the app's container/vhost from the EC2 host; note it in
   DEPLOYMENT_INVENTORY.md with the new target.

## EC2 consolidation (do after Pages migrations)

1. Inventory per-host containers (`docker ps` per host; the deploy workflows name them).
2. Retire containers serving Pages-migrated sites; downsize or terminate hosts that go idle.
3. Merge remaining low-traffic APIs onto fewer hosts (target: 1 shared apps host + 1
   shared-infra host + per-flagship hosts as load demands).

## Secrets setup (one-time, human step)

Create org secrets so every repo can call `pages-deploy.yml`:

```bash
gh secret set CLOUDFLARE_PAGES_ACCOUNT_ID --org seolith-llc --visibility all ...
gh secret set CLOUDFLARE_PAGES_API_TOKEN  --org seolith-llc --visibility all ...
```

Use a token scoped to **Pages: Edit** only. The per-repo `CLOUDFLARE_API_TOKEN`
secrets (fishbowl, praiseit) stay for their Workers lanes.

## Cost model

- Pages: $0 (free tier: unlimited bandwidth, 500 builds/mo — estate is far under).
- EC2: each retired static-site container + idle host removed is direct savings;
  expected outcome: static/marketing estate (~15 properties) off EC2 entirely.
