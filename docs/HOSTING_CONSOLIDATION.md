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

DONE and verified live on pages.dev (deploy-on-push from main):

- `seolith-reference-sites` — 10 Astro marketing sites (refsite-01..10); repo-local
  matrix lane (pnpm workspace doesn't fit the reusable). Batch 1.
- Batch 1 (reusable callers): `seolith-hindi-buddy`, `learn-tamil-letters` (project
  `learn-tamil-letters`), `critter-path-adventures`.
- Batch 2 (reusable callers): `seolith-debug-dojo` (project `debug-dojo`),
  `seolith-praiseit` (project `praiseit`; its Workers API lane is separate).
- Batch 2 (repo-local, no `npm ci` possible/needed): `seolith-next-gen-site`
  (pure static `public/`), `pci-hvac` (static mirror `PlumbingCareInc/`),
  `vroom-boom-buggies` (dependency-free build script).

REMAINING:

- `seolith-fishbowl` (site app) — pnpm workspace; needs a reference-sites-style
  repo-local lane (root install, per-app build).
- `sight-fix` frontend — npm workspaces + Angular 22; decide static-vs-SSR first.
- `seolith-teselith` frontends (static PWA shells; their APIs, if any, stay or consolidate)
- `vroom-boom-app` — Capacitor shell, no web build output; skip unless a web
  build is added.
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
3. Custom domain cutover (deliberate, per domain) — PROVEN on hindibuddy.online
   2026-08-24. Steps (all automatable from a workflow using the org CF secrets):
   a. POST `/accounts/{acct}/pages/projects/{project}/domains` with `{"name": domain}`
      — attaches the domain (status goes `pending`, "CNAME record not set" is
      normal at this point).
   b. In the zone, DELETE the old A/AAAA records for the hostname and CREATE a
      proxied `CNAME -> <project>.pages.dev`. Cloudflare does NOT override
      existing records automatically — this is the step that actually flips traffic.
   c. Verify: the live URL must serve the same asset hash as `<project>.pages.dev`
      (`curl -s <url> | grep -oE 'src="/assets/index-[^"]*"'`). PWAs: also check sw.js.
   Old EC2/nginx vhost can stay up during this — the DNS flip is atomic per hostname.
   NOTE: the org token needs Pages:Edit + Zone:Read + Zone DNS:Edit (upgraded
   2026-08-24 for exactly this).
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

Use a token scoped to **Pages: Edit + Zone: Read + Zone DNS: Edit** (zone
permissions are required for custom-domain cutovers; Pages-only cannot touch
DNS). The per-repo `CLOUDFLARE_API_TOKEN` secrets (fishbowl, praiseit) stay for
their Workers lanes.

## Cutover status

DONE: `hindibuddy.online` + `www` → hindi-buddy Pages project (verified
2026-08-24, asset hash + sw.js match pages.dev). EC2 origin was 3.14.169.232 —
vhost retirement tracked under EC2 consolidation.

TODO (origin confirmed EC2 by asset-hash fingerprint 2026-08-23):
`debugdojo.com` (+www) → debug-dojo, `staging-tamil-letters.seolith.com` →
learn-tamil-letters, `beta-pcihvac.seolith.com` → pci-hvac (currently an nginx
302), `seolith.com` (+www) → seolith-next-gen-site (PRODUCT DECISION NEEDED:
live is an older Angular app, Pages build is the new static redesign).
Remaining Pages projects (refsite-01..10, critter-path-adventures, praiseit,
vroom-boom-buggies) have no known production domains yet — cut over if/when
domains are assigned.

## Cost model

- Pages: $0 (free tier: unlimited bandwidth, 500 builds/mo — estate is far under).
- EC2: each retired static-site container + idle host removed is direct savings;
  expected outcome: static/marketing estate (~15 properties) off EC2 entirely.
