# Estate Convergence Plan

Audit of the seolith-llc estate, 2026-09-01 (35+ repos, all pulled to latest main).
The shared platform exists — this plan is about **adoption** and removing duplicated
implementations. Waves are ordered by leverage: cheapest mechanical wins first,
risky identity migrations last.

## Audit summary

### Verdicts

| Repo | Verdict | Key gaps |
| --- | --- | --- |
| seolith-portal | PARTIAL | Uses 5 Platform packages; custom JWT/Fido2 auth, custom mail, no Seq |
| seolith-apps-showcase | PARTIAL | Authentik OIDC + standard health, but shadow local JWT/BCrypt login, custom mail, no Seq |
| seolith-saas-template | CONFORMING | Reference stack; frontend auth is a deliberate stub |
| seolith-platform | CONFORMING | Is the standard; gaps listed below |
| seolith-sdk | CONFORMING | Is the JS standard |
| seolith-hindi-buddy, seolith-learn-tamil-letters, critter-path-adventures | CONFORMING | ui-react adopted, pinned CI; single `/health` only |
| beta-pcihvac.seolith.com | PARTIAL | CI conforming; **contact form posts to a nonexistent API** — losing leads |
| seolith-next-gen-site | CONFORMING | Static; lead capture correctly delegated to main-site |
| seolith-eventkeep | PARTIAL | Authentik hand-wired (not Platform.Auth), no Seq, no mail, leftover Keycloak artifacts |
| seolith-twbb | PARTIAL | Authentik hand-wired, MockEmailService, no Seq, missing secret-scan |
| seolith-main-site | PARTIAL | oauth2-proxy header trust, custom audit, stale CI pin v1.0.2, no secret-scan |
| seolith-money-app | CUSTOM | Magic-link + cookie auth, custom email trio, no Serilog at all |
| amtocsoft-ceo-guide | CUSTOM | Custom magic-link JWT, custom SES sender, no Serilog |
| seolith-tax-manager | CUSTOM | Argon2+JWT+TOTP custom identity, email senders copy-pasted from money-app |
| seolith-omnifield | CUSTOM | Custom JWT, custom EmailService, custom tenancy/rate-limit/audit; Seq is the one bright spot |
| alex-lopez-va | CUSTOM | Authentik but largest hand-rolled infra surface (auth tree, 9-file audit, outbox, rate limit) |
| pto-admin | CUSTOM | Fully custom symmetric JWT, custom email queue, no health checks, missing secret-scan |
| amtoc-mailserver | CUSTOM | Keycloak (not Authentik), custom SMTP sender, logs to Postgres not Seq, fully custom CI |
| seolith-email-manager | PARTIAL | Custom JWT (documented decision), no Serilog, missing secret-scan |
| seolith-reference-sites | CUSTOM | Per-brand JWT ×10, local `@seolith/*` shadow packages instead of `@seolith-llc/*` SDK |
| walk-in | CUSTOM | NextAuth credentials + JSON-file user store, dead SES dep, no CI gates |
| debug-dojo-academy | CUSTOM | 52-file copy-pasted shadcn tree, Supabase auth, no gates, committed `.env` |
| eyezen | CUSTOM | No CI at all, dead Supabase dep |
| seolith-praiseit | PARTIAL | CI conforming but duplicate ci.yml; custom D1 analytics; no ui-react |
| amtocsoft-www | CUSTOM | No CI, custom analytics beacons to a dead endpoint; consolidation candidate |
| amtocsoft-content | N/A | Content repo; ~30 copy-paste image-gen scripts to consolidate |

### Duplication clusters (delete targets)

- **Self-issued JWT auth, 8 copies**: omnifield (`Core/JwtHelper.cs`), money-app, ceo-guide, tax-manager, portal, apps-showcase (shadow path), pto-admin, email-manager, reference-sites (×10 brands).
- **Email senders, 7 copies**: omnifield `Services/EmailService.cs`, money-app + tax-manager `Email/{Smtp,Ses}EmailSender.cs` (near-identical), ceo-guide `SesMagicLinkSender.cs`, portal `NotificationService.cs`, alex-lopez-va inline SES, pto-admin `Infrastructure/Email/Class1.cs` (misnamed file).
- **Hand-wired Authentik JwtBearer, 4 copies**: eventkeep, twbb, apps-showcase, alex-lopez-va.
- **Hand-rolled Angular OIDC, 3 copies**: eventkeep, twbb, pto-admin (all `oidc-client-ts`) → `@seolith-llc/auth`.
- **Audit subsystems, 4 copies**: alex-lopez-va `api/Audit/` (9 files), pto-admin, amtoc-mailserver, main-site.
- **Duplicated workflow YAML**: ~2,600 active lines + ~950 in `legacy/` dirs (apps-showcase, eventkeep, pto-admin, critter-path).
- **`regen-lockfile.yml`**: identical ~68-line file in 4+ repos → promote to a shared workflow.
- **Health endpoint conventions**: `/health`, `/healthz`, `/api/health`, `/ready` — 5 variants; standard is `/health/live` + `/health/ready`.

### Platform/SDK gaps to close (before mass adoption)

- `Seolith.Platform.Mail` and `Documents` template layers are interface-only stubs.
- `DatabaseHealthCheck` duplicated between HealthChecks and Telemetry packages — delete one.
- No tests for Mail, Documents, HealthChecks, Cors, RateLimiting, ErrorHandling, Migration.
- seolith-platform README stale (old versions, names wrong consumers, references superseded local-feed plan).
- Two `@seolith-llc/*` publishers (seolith-sdk and seolith-platform/angular) — document who owns what.

## Wave 0 — hygiene (no behavior change)

1. Pin ALL repos to dev-standards workflows at **one tag: `v1.1.4`** (current pins range v1.0.0–v1.1.4, plus alex-lopez-va secret-scan on `@main` and main-site on stale `@v1.0.2`).
2. Add missing `secret-scan.yml` / `security-gates.yml` to: seolith-omnifield (has inline gitleaks to remove), pto-admin, seolith-twbb, seolith-email-manager, seolith-main-site, walk-in, debug-dojo-academy, eyezen.
3. Delete duplicate custom `ci.yml` alongside pinned `ci-standard.yml`: seolith-praiseit, critter-path-adventures.
4. Purge `.github/workflows/legacy/` dirs: apps-showcase, eventkeep, pto-admin, critter-path-adventures.
5. Promote `regen-lockfile.yml` to a shared dev-standards workflow.
6. Platform gaps (above): dedupe DatabaseHealthCheck, fill Mail/Documents templates, backfill tests, fix README, write the "who publishes what" doc.

## Wave 1 — mechanical adoption

7. `Seolith.Platform.HealthChecks` + `Seolith.Platform.Telemetry` (Serilog→Seq) into every .NET API: omnifield, money-app, ceo-guide, tax-manager, apps-showcase, portal, eventkeep, pto-admin, twbb, alex-lopez-va, main-site, email-manager, amtoc-mailserver. Seq URL comes from environment config; verify events land in logs.seolith.com.
8. Fill `Seolith.Platform.Mail` template renderer, then adopt it in the 7 custom sender sites. SMTP settings point at the shared Mailpit (dev/staging capture; prod relay via Mail Manager ingress in account 819168518599).

## Wave 2 — auth convergence (Authentik via Platform.Auth + @seolith-llc/auth)

9. Already-on-Authentik swaps: eventkeep, twbb, apps-showcase (delete the local JWT/BCrypt login path), alex-lopez-va (replace hand-rolled tree, keep break-glass).
10. Self-issued-JWT migrations with account linking (live users — one at a time, feature-flagged): money-app, ceo-guide, tax-manager, pto-admin, portal, email-manager, reference-sites.
11. Keycloak outliers → Authentik: amtoc-mailserver; remove Keycloak artifacts from eventkeep/twbb.

## Wave 3 — stragglers and dead weight

12. debug-dojo-academy: replace 52-file shadcn tree with `@seolith-llc/ui-react`; resolve committed `.env`.
13. seolith-reference-sites: drop local `@seolith/*` packages, consume published `@seolith-llc/*`.
14. gs-apsis-app: delete the 3 re-export shims.
15. **beta-pcihvac contact form posts to a nonexistent `/api/contact`** — wire to a real lead endpoint (main-site `/api/site/leads` pattern) or remove the form. Losing leads today.
16. amtocsoft-www: consolidate into main-site/next-gen-site or give it standard CI; analytics beacon endpoint is dead.
17. walk-in: replace JSON-file user store + NextAuth with Authentik OIDC; remove dead SES dep; add CI gates.
18. eyezen: add CI; remove dead Supabase dep.

## Status log

### 2026-09-04

- Wave 0: complete — all 19 active repos pinned to shared workflows, secret-scan/security-gates
  everywhere, legacy workflow dirs purged, `regen-lockfile.yml` promoted to dev-standards.
- Wave 0 platform gaps: DatabaseHealthCheck deduped, package tests backfilled, README refreshed
  (seolith-platform #69). Mail/Documents template layers still stubs — Mail completion in flight.
- Wave 1 HealthChecks + Telemetry: **13/13 repos on main** (money-app was already merged by
  seolithcomgh as #76). Post-merge fallout fixed and merged: seolith-eventkeep#93 (BuildKit-secret
  feed auth for in-container restore), seolith-omnifield#349 (`.dockerignore` + `dotnet publish
  --no-restore`), seolith-apps-showcase#109 (mask OIDC AWS creds in GITHUB_ENV),
  alex-lopez-va#72 (operational-contract gate accepts `MapSeolithHealthEndpoints`).
- Org secret `PACKAGES_READ_TOKEN` granted to all consuming repos (was the cause of several
  red CI runs with 403 feed errors).
- seolith-money-app#77: Testcontainers flake root-caused (Docker Desktop port proxy severs
  idle pooled Npgsql connections) and fixed via `Pooling=false` test helper; merged.
- amtoc-mailserver#44: dead SSH deploy (SG allows only a stale home IP; box actually runs
  seolith-email-manager) gated to `workflow_dispatch`; product retire-vs-SSM decision pending.
- Known red: amtocsoft-ceo-guide main deploy — `ssh-keyscan` to the prod box fails from the
  self-hosted runner (host unreachable on :22; SG/instance check in progress).
- Blocked: seolith-portal deploy waits on `Seolith.Platform.Telemetry` nupkg upload to
  `s3://seolith-prod-backups-819168518599/shared-nuget/seolith-platform/1.0.0/`.
- Platform packages publish `1.0.<run_number>` on main push; consumers float `1.0.*`.

### 2026-09-05

- Platform.Mail shipped (seolith-platform#73) and feed publish fixed (#74): all 14 packages at
  1.0.26. Mail adoption merged **7/7**: money-app#79, tax-manager#83, portal#974, pto-admin#107,
  amtocsoft-ceo-guide#48, alex-lopez-va#73 (+#74 npm audit), seolith-omnifield#368 (AWSSDK 3.x→4.x).
- W2 first auth swap merged: seolith-twbb#83 — Platform.Auth + `GroupRoleClaimsTransformation`
  (Authentik `seolith-prod-admins` → Admin/SuperAdmin); Keycloak purged.
- Deploy pipelines converted from dead SSH to SSM + OIDC and proven green end-to-end:
  amtocsoft-ceo-guide#46-#52 (run 33912681880), seolith-tax-manager#84, pto-admin#108
  (v2.7.0 pipeline validation green), walk-in#12.
- seolith-portal deploy pipeline root-caused through 11 attempts; fixes merged: #976 (vendored
  NuGet 1.0.26, stale-cache poisoning), #977 (localhost in prod AllowedHosts for container
  healthchecks), #978 (interactive `docker compose run` consumed the SSM-piped script from
  stdin, silently ending deploys after the migrate step — now `-T < /dev/null`), #979 (comment
  inserted between env-prefix continuation backslash and the command un-exported the compose
  env), #980 (stale-router cleanup compared short vs full container ids and matched a greedy
  router-name regex, removing the ACTIVE portal containers + omnifield containers + bos_api
  post-deploy — now skips by name and matches only the exact `Host()` rule). Contract tests
  pin every one of these regressions.
- Estate OIDC discovery: some repos emit a customized subject claim
  (`repo:seolith-llc@194135913/<repo>@<id>:*`). New deploy roles must trust BOTH the plain and
  the custom sub format (walk-in needed it; pto-admin emits plain). `github-ssm-deploy-pto-admin`
  and `github-ssm-deploy-walk-in` created with both patterns.
- Seq ingestion verified on prod-01 (CLEF raw POST → 201); the query API is auth-protected
  (good), UI spot-check outstanding.
- bos_api (prod-01) was an orphaned container from a June one-off `/tmp` deploy — no compose
  definition or image survives on the box; unrecoverable, presumed retired.
- Deploy-lesson patterns now canonical for the estate: base64 script over SSM with tee-log,
  no interactive docker commands in piped scripts, BuildKit `gh_packages_token` secret for
  box-built .NET images, OIDC roles over static AWS keys.

### 2026-09-05 (evening)

- **Leads intake is live**: the main-site stack (down since Jun 3) was revived on prod-01 with
  its surviving `.env` and postgres volume; `POST https://api.seolith.com/api/site/leads`
  returns 200 and rows record. Root cause of the long outage: `seolith.com` is the static
  Pages marketing site (POSTs 405) and `api.seolith.com` was a placeholder nginx. Durable
  config: seolith-main-site#51 (traefik PathPrefix router at priority 200 above the
  placeholder + BuildKit feed auth). beta-pcihvac.seolith.com#33/#34 wire the (pre-launch)
  Angular contact form to it. The LIVE beta-pcihvac WordPress form (MetForm) is confirmed
  broken upstream (`401 Unauthorized submission`) — fix needs WP admin; migration is the way out.
- **Public repos cannot consume the private shared workflows.** amtocsoft-www (the org's only
  public repo) failed every reusable-workflow call at expansion (zero jobs, "workflow file
  issue") against two dev-standards SHAs while identical callers pass from private repos.
  It now runs repo-local gates (gitleaks CLI full-history + static hygiene) — amtocsoft-www#2.
  If more repos go public: same treatment, or make dev-standards public.
- W2 auth swaps merged: seolith-apps-showcase#115 (dual-scheme issuer forwarding — Authentik
  bearer via Platform.Auth + legacy local JWTs during transition; break-glass = the existing
  password login; group-claim shim with 7 tests). Follow-up recorded in the PR: frontend
  oidc-client-ts swap, then delete local minting. Earlier: seolith-eventkeep#534 (committed
  `EventKeep#Admin03` seeder killed; prod cutover is a manual dispatch pending Authentik
  group assignment).
- serwist migration done: eyezen#2, walk-in#13 — next-pwa 5.6 (dead since 2022) replaced by
  @serwist/next 9.5.12; API routes are now strictly NetworkOnly in both service workers
  (they were NetworkFirst-cached — a stale-data hazard). eyezen pins `next build --webpack`
  until serwist#339 (Turbopack precache) is fixed.
- pto-admin v2.8.0 shipped the convergence wave to prod (HealthChecks+Telemetry+Platform.Mail)
  — deploy green, `/health` Healthy.
- PACKAGES_READ_TOKEN granted to debug-dojo-academy and seolith-reference-sites;
  regen-lockfile reusable workflow now handles pnpm-lock.yaml/yarn.lock (dev-standards#97);
  debug-dojo ui-react adoption (#6/#7) and reference-sites SDK adoption (#29/#30) merged.
- W2 auth migrations (dual-scheme `AuthentikOrLocal` template from apps-showcase#115):
  amtocsoft-ceo-guide#53 and seolith-tax-manager#85 merged AND deployed to prod
  (ceo-guide `/api/ready` green; invoices+foxy 200 on root/health/login). tax-manager
  notes: MediatR 12→14 forced by Platform.Auth; permission-claim model means Authentik
  tokens are fail-closed until group→permission mapping lands with the frontend swap.
  eventkeep#535 removed the Keycloak remnants (services, realm-export, nginx /auth/ proxy).
  money-app/pto-admin/email-manager migrations in flight; portal is an ops cutover
  (Authentik already enabled), not a code migration.
- `/cp/v1/feedback` verdict: NOT broken — 401 on invalid key, 405 on GET (POST-only).
  Needs a minted `cpk_` key for the e2e test (owner action).
- walk-in serwist deploy green end-to-end (test → ECR push → SSM deploy on prod-01);
  eyezen.app deploys via Vercel git integration (outside estate CI).

### 2026-09-05 (late)

- **W2 code wave complete (8/8 apps)**: money-app#80 (cookie/PKCE variant — sessions
  linked by email, no migration needed), pto-admin#109 (estate group → Admin+SuperAdmin),
  seolith-email-manager#44 merged. ceo-guide#53 + tax-manager#85 already deployed and
  prod-verified; pto-admin v2.9.0 deployed with the migration (inert until the Authentik
  app is registered); email-manager images published for the next routine pull. All
  cutover work is batched as one Authentik admin session in docs/OWNER_ACTIONS.md (3b).
- Security: seolith-platform#75 deleted `docs/notes.md`, which held LIVE
  POSTGRES_PASSWORD + AUTHENTIK_SECRET_KEY (predated the diff-only scan gate). Both
  values remain in history and are queued for rotation (OWNER_ACTIONS #0). A full
  ~240-repo `git grep` sweep for PASSWORD/SECRET_KEY/API_KEY-shaped values found only
  placeholders and one CI dummy — the estate tree is otherwise clean.
- money-app gap flagged: no production deploy pipeline; monetization.amtocsoft.com →
  18.190.201.241 (DNS-only, not one of the four managed boxes — identify the host
  before building the pipeline).

### 2026-09-05 (cutovers)

- **OWNER_ACTIONS #0 done**: POSTGRES_PASSWORD/AUTHENTIK_SECRET_KEY rotated on BOTH
  authentik instances. Discovery during rotation: auth.seolith.com is served by the
  prod-01 ssi stack (`seolith-authentik*`, project `shared`); the /srv/authentik stack
  on platform-prod is a secondary instance. Both rotated; both verified healthy. On
  prod-01 the server+worker containers were owned by compose project `ssi` while
  db/redis were `shared` — a `compose up` name-conflict mid-rotation left the server
  briefly stale; fixed by removing the stale containers and recreating under `shared`.
  All sessions invalidated once, as planned.
- **3b done via API, not UI**: found a non-expiring admin API token path
  (`ak shell` mint on prod-01) and provisioned everything headlessly — groups
  (seolith-prod-admins + 4 per-app admin groups), providers+applications for
  ceo-guide, tax-manager, pto-admin, email-manager (bearer), money-app (confidential,
  redirect monetization.amtocsoft.com), app-showcase-spa (PUBLIC PKCE client).
  All 9 issuer discovery endpoints verified 200. akadmin added to seolith-prod-admins.
- **walk-in cut over**: DNS flipped walkin.seolith.com → prod-01. Surfaced a dead
  CF_DNS_API_TOKEN in prod-01 traefik (/opt/seolith/ssi/.env, CLOUDFLARE_API_TOKEN)
  that had blocked ALL new cert issuance on the box for days (403/9109 + CF auth
  lockouts); replaced with the working zone token, traefik recreated, cert issued,
  https://walkin.seolith.com 200 verified. The legacy box 34.239.73.154 is now
  out of the request path — retirement is an owner decision.
- **money-app live on Authentik**: #81 fixed the staging deploy (NU1301 401s — the
  workflow never passed PACKAGES_READ_TOKEN to the host build; org secret granted to
  the repo and injected at deploy time like pto-admin). Redeployed with the auth
  wiring + client secret; verified: /health 200, /api/auth/providers authentik:true,
  /api/auth/authentik 302 → auth.seolith.com with client_id=money-app.
- **apps-showcase SPA SSO live**: #117 fixed the frontend authority to
  application/o/app-showcase-spa/ (the public client's per-provider issuer; the
  merged #116 pointed at the confidential provider, which would have failed
  issuer/client validation). Prod CD green; live bundle verified carrying the new
  issuer. Interactive browser sign-in test remains with the owner.
- **eventkeep prod cutover**: Deploy Production dispatched post-registration; green.
  Verified: home 200, /health 200, protected route 401 with no/garbage token.
- Smoke sweep after registrations: tax-manager invoices.seolith.com /healthz 200 +
  garbage bearer → 401; pto-admin pto.seolith.com /health 200 + garbage → 401;
  email-manager mail.seolith.com 401 wall + garbage → 401; ceo-guide ready 200.
- Corrected an OWNER_ACTIONS assumption: only portal/eventkeep/app-showcase were
  actually registered before today — ceo-guide/tax-manager/pto-admin were "verify"
  items that turned out not to exist.
- **main-site pipeline unblocked**: the `production` environment pointed at the OLD
  AWS account (bucket 478087977376, dead instance id); Telegram was never the blocker
  (that step already skips gracefully). Created role `github-ssm-deploy-main-site`,
  rewired bucket/instance/DEPLOY_PATH to prod-01, pinned the compose project
  (seolith-main-site#52) so the pipeline adopts the live stack. Dispatch is the
  owner's deliberate click (the live site runs the June 3 build).
- **Backup gap closed**: audit found only omnifield had daily DB dumps; the other
  ~22 postgres containers on prod-01 (and everything on staging/platform-prod) had
  none. seolith-shared#100 added scripts/pg-backup-all.sh (auto-discovers
  postgres/postgis containers, pg_dumpall/pg_dump streamed to
  s3://seolith-prod-backups-819168518599/db-backups/host/<container>/, 30-day
  retention, cron 03:23 UTC); #101 added the non-superuser fallback
  (alexlopezva-db). Installed and verified on all three boxes: prod-01 23/23,
  staging 19/19, platform-prod 4/4.
- Also fixed on prod-01 during the walk-in cutover: dead CLOUDFLARE_API_TOKEN in
  traefik env (no certs issued for days), and the ssi stack's containers split
  across compose projects `ssi`/`shared` causing name-conflict recreate failures —
  unified under `shared`; seolith-shared#99 env-gated the localhost host rules that
  spammed ACME 400s.
- Issuer-coverage sweep: probed every `application/o/<slug>` the estate's code
  expects. `twbb` was missing (twbb#83's frontend uses public client `twbb-web`,
  redirect <origin>/login) — registered it on the live instance; `twbb-staging`
  already existed on staging-auth.seolith.com. All expected issuers now serve 200.

## Tester v1 adoption

Added 2026-09-08 as a separate adoption track; the earlier audit and auth/mail
waves above retain their dated scope. [Tester v1](TESTER_V1_STANDARD.md) defines
the portable protocol, [manifest schema](tester-manifest.schema.json), host
boundary and consumer acceptance matrix. It does not change the current
conformance runner or enable the feature across the fleet.

| Layer | Foundation evidence | Remaining adoption work |
|---|---|---|
| Omnifield reference | Implementation at `fe346a6b34d6534764448d23b1265a460c423146`, landed through [PR #392](https://github.com/seolith-llc/seolith-omnifield/pull/392), merge `bc3020a` | Record actual staging and production serving release, access grants, acceptance and restore evidence in the app's operating docs; this source row is not live-health evidence |
| Shared SDK | Private, unpublished `@seolith-llc/tester-core` `0.1.0`, source `1e83c44e8905efbf140e67becef18462878f5938`; [PR #38](https://github.com/seolith-llc/seolith-sdk/pull/38) merged as `c855e21c8c1d4e059b0e04dc91eefe1a98a77405` | Choose an approved distribution mechanism and complete each consumer's host integration; no automatic registry publishing |
| Other applications | No adoption or deployment established by this change | Inventory each host, implement UI/auth/tenant/transport/server/offline adapters and catalog, then pass TV1 checks and stage/activate separately |

For each consumer, record repo + immutable implementation/package versions,
owner, environment/public origin, auth/permission mapping, schema/storage and
backup/restore coverage, TV1 check links, staging acceptance, production release
and rollback instructions. Keep `planned`, `implemented`, `staging accepted` and
`production verified` distinct. Existing identity convergence is not a prerequisite
to adopting Tester; preserve the host's current identity and tenant contracts.

## Verification

- Every touched repo: PR with green CI (gates + build/test), merged to main.
- Wave 1+: after deploy, health endpoints respond on the standard paths and Seq shows the service's events.
- This document updates as waves land; per-repo status lives in DEPLOYMENT_INVENTORY.md.
