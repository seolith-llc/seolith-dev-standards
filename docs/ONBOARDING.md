# Developer Onboarding — SEOlith Estate

One page to read before your first commit. ~95 repos, but only a handful of patterns.

## The house stack

| Layer | Standard | Also in use (legacy/secondary) |
|---|---|---|
| Backend | **.NET 10 Web API** (`*.slnx`, Clean Architecture, `Directory.Packages.props`) | FastAPI (Python), Node/Express, Firebase Functions |
| Web frontend | **Angular 20–22** | React+Vite+shadcn (Lovable track), Next.js, Astro (marketing) |
| Mobile/desktop | **Capacitor** on the web app | React Native (virosa), Electron, Unity (games) |
| Infra runtime | **Docker on AWS EC2** (us-east-2), ECR registry, nginx/Traefik proxy, Cloudflare DNS | GHCR in a few repos |
| Identity | **Authentik** SSO (seolith-shared) | — |
| Observability | **Seq** (logs), **Dozzle** (containers), **Mailpit** (dev mail) — all in seolith-shared | OTEL/Sentry in some apps |

## Where shared code lives — import, never copy

| Need | Use | How |
|---|---|---|
| .NET: auth, tenancy, audit (CFR 21-11), mail, documents, telemetry | **`seolith-platform`** NuGet packages | GitHub Packages feed; see its README dependency table |
| Angular: auth | **`@seolith/auth`** (seolith-platform/angular) | GitHub Packages npm feed |
| JS: ui/theme/site-config | `@seolith/ui`, `@seolith/theme` (pattern: `seolith-reference-sites/packages`) | Being promoted to published packages — check first |
| SSO/logs/mail/monitoring | **`seolith-shared`** runtime services | Well-known URLs; see `docs/integrating-with-shared-services.md` there |
| CI workflows, lint, conformance | **this repo** (seolith-dev-standards) | `uses: seolith-llc/seolith-dev-standards/.github/workflows/...@<tag>` |

Copy-pasting a `components/ui` tree or an `auth.service.ts` from a sibling repo is a
review blocker. If the package doesn't have what you need, add it to the package.

## Starting a new app

1. Scaffold from the golden template (formalized from the shared .NET+Angular skeleton —
   see `docs/REPO_CONSOLIDATION_PLAN.md` until the template repo lands).
2. Your repo gets: `ci.yml` calling dev-standards reusable workflows (secret-scan +
   build/test), `SECURITY.md`, `.gitignore` incl. `.env` / `.env.*` (track only `.env.example`).
3. Register ports in seolith-app-factory `PORT_REGISTRY.md`; domains via the
   `seolith-domain-suite` multi-tenant host pattern for small sites.
4. Deploy: Docker → ECR → EC2 via the standard deploy workflow. Static/PWA frontends
   prefer Cloudflare Pages (near-free) over EC2.

## Reference implementations (copy the *patterns*, read these first)

- `seolith-platform` — packaging, publishing, Testcontainers tests
- `seolith-app-builder` — Clean Architecture .NET + Angular, xUnit + Playwright
- `seolith-shared` — infra compose stack, E2E tests, runbooks
- `seolith-domain-suite` — multi-domain single-runtime hosting
- `seolith-reference-sites` — pnpm monorepo with real shared JS packages

## Non-negotiables (enforced by `scripts/seolith-conformance.sh`, M1–M10)

- **No secrets in git.** Rotate-then-purge per `docs/SECRET_ROTATION.md`. `.env` is never committed.
- **Tests for changed code.** The estate historically has gates that are green by vacuity
  (test steps, zero test files) — new work must not add to that. Ratchet, don't big-bang.
- **CI caller pattern only** — don't fork workflow logic into repo-local copies.
- **Pin reusable workflows to a tag**, not `@main` (migration in progress).
- Small PRs, CODEOWNERS review where configured, conventional commits (see `skills/`).

## Your first week

1. Read `STANDARD.md` here + `estate-engineering-standard.md` in seolith-ops-control.
2. Stand up seolith-shared locally (`docker compose up`) — you get SSO, mail, logs.
3. Build and run `seolith-platform` tests (`build-packages.ps1`, Testcontainers needs Docker).
4. Pick a starter issue in a Tier-1 product repo; run `scripts/seolith-conformance.sh` on it.
5. Ship one small PR end-to-end through the CI caller pattern.

## Key docs map

- Standards: `STANDARD.md`, `docs/CI_CD_STANDARD.md`, `docs/ARCHITECTURE_STANDARD.md`, `docs/THEMING_STANDARD.md`
- Ops/estate: seolith-ops-control `docs/estate-map.md`, `docs/estate-engineering-standard.md`
- Secrets: `docs/SECRET_ROTATION.md` · Consolidation: `docs/REPO_CONSOLIDATION_PLAN.md`
- Runners: `SELF_HOSTED_RUNNER.md` · Agent handover: `AI_AGENT_HANDOVER.md`
