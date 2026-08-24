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

DONE:

- `hindibuddy.online` + `www` + `hindi-buddy.seolith.com` → hindi-buddy Pages
  project (verified 2026-08-24, asset hash + sw.js match pages.dev).
  EC2 container `hindi-buddy-prod` on seolith-prod-app-host-02 RETIRED
  (docker compose down, /opt/seolith/prod-host02-static-batch/hindi-buddy).
- `debugdojo.com` + `www` → debug-dojo Pages project (verified 2026-08-24,
  asset hash + sw.js match). Also cut over: `debug-dojo.seolith.com` and
  `staging.debugdojo.com` (staging lost its Google-auth gate — accepted; Pages
  has no auth gating). EC2 containers retired: `debug-dojo-prod` +
  `debug-dojo-auth-proxy` on prod-app-host-02, AND `debug-dojo-staging` +
  `debug-dojo-auth-proxy-staging` on **seolith-staging-app-host-01**
  (i-072321eac21205fcf, 18.190.201.241 — a second, staging-dedicated host
  discovered during this cutover; it runs ~40 staging containers plus shared
  infra: Authentik, Seq, Vault, Dozzle, Traefik).

- `staging-tamil-letters.seolith.com` + `tamil-letters.seolith.com` →
  learn-tamil-letters Pages project (verified 2026-08-24). EC2 containers
  retired: `tamil-letters-prod` on prod-app-host-02 AND `tamil-letters-staging`
  on the staging host.
- `beta-pcihvac.seolith.com` → pci-hvac Pages project (verified 2026-08-24,
  title matches Pages build). Old origin was 162.241.224.194 — a THIRD origin
  IP, neither EC2 host (likely the shared host serving the WordPress original;
  this repo is the static mirror). The real `pcihvac.com` does not resolve at
  all — assigning it to the Pages project is an open decision.

- `seolith.com` + `www.seolith.com` → seolith-next-gen-site Pages project
  (cut over 2026-08-24, verified: new title on both hostnames, 5 service
  pages + /privacy 200, lead form E2E through Pages Function →
  `main-site.seolith.com` → .NET API → Postgres returned the upstream
  success string, honeypot fake-succeeds, GA property G-DLRJ1TKJRV
  unchanged). API continuity: the .NET MainSite API is Host-agnostic, so
  `main-site.seolith.com` was added to the `seolith-main-prod-web` Traefik
  rule (repo `seolith-main-site` deploy/docker-compose.prod.yml, applied to
  the live release on prod-app-host-02) and its A record still points at
  3.14.169.232 — the Pages Function proxies there. Legacy redirects ported
  to `public/_redirects`: WordPress paths (`/wp-json/*`, `/xmlrpc.php`,
  `/wp-admin/*`, `/feed*`, `/hello-world/`, `/category/uncategorized/`) and
  retired Angular sections (`/blog/*`, `/careers/*`) all 301 to `/`.
  `site-admin.seolith.com` (oauth2-proxy admin console) untouched and still
  on EC2 — the admin surface + Postgres remain the system of record for
  leads/blog/jobs. `seolith-main-prod-web` now serves only the API and
  admin proxy; its Angular statics are no longer public-facing but the
  container stays up for /api + site-admin. Rollback: re-point apex/www A
  records to 3.14.169.232.
- Remaining Pages projects (refsite-01..10, critter-path-adventures, praiseit,
  vroom-boom-buggies) have no known production domains yet — cut over if/when
  domains are assigned.

## Cost model

- Pages: $0 (free tier: unlimited bandwidth, 500 builds/mo — estate is far under).
- EC2: each retired static-site container + idle host removed is direct savings;
  expected outcome: static/marketing estate (~15 properties) off EC2 entirely.

## EC2 estate (inventoried 2026-08-24, all us-east-2 unless noted)

- `seolith-prod-app-host-01` (i-049e358ee9ea8118a, t3.large, 18.190.199.160):
  ~100 containers — the stateful production workhorse: alexlopezva (blue+green),
  app-builder, appshowcase, bos (omnifield-ai), domain-suite,
  drishyavaak, eventkeep, lks (prod), omnifield (prod, ClickHouse),
  premonition-play, pto-admin, ops-control, portal, touch-n-go, twbb,
  plus shared infra (Traefik, Authentik, Seq, Vault, Dozzle, backup).
  Disk was 96% → 80% after image/build-cache prune, truncating the 3.5GB
  Traefik access.log, and deleting the stale unmounted
  `/opt/seolith/prod/shared/data` copy (5GB; verified 0 container mounts).
  Live shared-infra data is `/opt/seolith/ssi/data`.
  Seq `seq_data` is 9.6GB — set a retention policy in the Seq UI to stop
  regrowth; Traefik access.log needs logrotate or it regrows too.
  The `demo01` stack (demo01.seolith.com "Builder" demo) was brought down
  2026-08-24 (volumes kept; restart via /opt/seolith/prod/demo01).
- `seolith-prod-app-host-02` (i-03186641877827f53, t3.medium, 3.14.169.232):
  29 containers, lean after static-site retirements (apsis, chaipaani,
  critter-crawl, cropfight, cubelith, goptru, hype-buddy, memorize-world,
  one-prompt-lab, release/feelgood, main-site API+DB+admin, Traefik).
  Disk 34%, load <1. Healthy.
- `seolith-staging-app-host-01` (i-072321eac21205fcf, t3.large,
  18.190.201.241): staging stacks + a second shared-infra stack. Disk was
  85% → 64% after prune. Retired 2026-08-24 (compose down, volumes kept):
  `hindi-buddy-staging` (on Pages), `eventkeep-staging`, `apsis-staging`,
  `sportmed-staging`, `domain-suite-staging` (all ~zero traffic in the
  trailing 2 weeks per Traefik access-log analysis; active stacks: portal,
  alexlopezva, lks-ads, lks-site-and-portal, second-chance-leads, twbb,
  one-prompt-lab, pto-admin, omnifield, appshowcase, memorize-world,
  goptru, critter-crawl, premonition-play, refrilog, app-builder,
  money-app). Removed 6 stale exited containers (seolith-ops-*-staging,
  alexlopezva bootstrap). Deploy snapshots in /opt/seolith/staging
  (.pre-*/.backup.*) total only ~358MB — left alone. Memory 4.4/7.6GB
  after retirements; t3.medium downsize is within reach if a couple more
  stacks retire. NOTE: `monetization.amtocsoft.com` (money-app) is served
  from this STAGING host — client-facing traffic on the staging box.
- `orgqa-demo` (i-0b91d234c8b8ce97b, t3.medium, us-east-1): served an
  "Organization Q&A" demo (nginx, TLS, also reachable via
  `org-answers.seolith.com` A 34.233.234.251). STOPPED 2026-08-24
  (restartable; EBS + EIP retained, EIP keeps its ~$3.65/mo IPv4 charge).
  Saves ~$30/mo. No IAM instance profile — not SSM-manageable.
- No unattached EBS volumes, no unassociated EIPs, no other regions in use.
- `deploy_seolith_main_prod_postgres` shows in `docker volume ls -f
  dangling=true` on host-01 even though main-site prod runs — do NOT bulk
  `docker volume prune` without verifying each volume first.
- Committed baseline was ~2×t3.large + 2×t3.medium ≈ $180/mo on-demand,
  now ~$150/mo after orgqa-demo stop; a 1-year Compute Savings Plan would
  cut that ~28% once the estate settles.

## seolith.com zone notes (full inventory 2026-08-24)

- `*.seolith.com` is a proxied CNAME → `workportal.seolith.com` (host-01).
  Any unmatched subdomain serves the workportal app — likely intentional
  tenant routing, but it means deleting an explicit record makes that
  hostname fall through to workportal instead of 404ing. Do NOT delete
  "stale" staging records (staging-apsis/eventkeep/sportmed/debug-dojo)
  unless the wildcard is rethought first.
- Subdomains hosted OUTSIDE the three known hosts: 34.239.73.154 serves
  14 client sites (copperline, elowen, havenmark, ironpeak, lumessa,
  northvent, onyxhaus, smartfight, terravine, vitalume, voltari, walkin
  +admins); 3.222.183.150 (foxy, invoices); 3.214.251.135 (email-manager);
  3.133.57.145 (ortho, platform-auth, platform-logs); 44.204.104.184
  (admin-twbb); 18.218.248.26 (auth-new). None are in this AWS account's
  running instances — audit where these live and what they cost.
- `tesselith.seolith.com` CNAMEs to custom-domains.chatgpt.site.
- `staging-hindi-buddy.seolith.com` explicit A record deleted 2026-08-24
  (container retired; wildcard still answers it — see above).
