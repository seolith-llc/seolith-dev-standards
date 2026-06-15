# Deployment Inventory

This is the working production inventory. Fill unknowns before making deployment promises for that repo.

| Repository | Type | Production target | Health check | CI standard | Notes |
| --- | --- | --- | --- | --- | --- |
| `seolith-eventkeep` | Angular + .NET + PostgreSQL | EC2 Docker Compose, `https://eventkeep.pro/` and `https://www.eventkeep.pro/` | `https://eventkeep.pro/health`, `https://eventkeep.pro/api/health` | Local build and direct EC2 deploy | Production verified 2026-06-15. |
| `pto-admin` | Angular + .NET + PostgreSQL/MinIO/Redis | EC2 Docker Compose, `https://ptoadmin.org/` and `https://www.ptoadmin.org/` | `https://ptoadmin.org/health`, `https://ptoadmin.org/api/health` | Local build and direct EC2 deploy | Production verified 2026-06-15; superadmin route is auth-gated. |
| `seolith-omnifield-ai` | Angular + .NET + PostgreSQL/ClickHouse | EC2 Docker Compose, `https://omnifield.ai/`, `https://workportal.seolith.com/` | `https://api.omnifield.ai/health`, `https://api.workportal.seolith.com/health` | Direct EC2 deploy | Production aliases verified 2026-06-15. |
| `seolith-twbb` | Node/API + frontend + PostgreSQL/Redis/Keycloak | EC2 Docker Compose, `https://twbb.seolith.com/`, `https://admin.twbb.seolith.com/` | `https://twbb.seolith.com/health`, `https://admin.twbb.seolith.com/health` | Direct EC2 deploy | Admin subdomain Traefik route fixed and verified 2026-06-15. |
| `seolith-praiseit` | Vite PWA + Cloudflare Worker | Cloudflare Workers `hype-buddy` | Worker route plus admin console | Local workflow, should migrate to `node-pwa-build` | Has admin observability and D1 analytics. |
| `memorize-world` | PWA/mobile candidate | TBD | TBD | Self-hosted Windows CI merged | Android ready path; iOS needs macOS signing. |
| `critter-path-adventures` | Vite PWA | TBD | TBD | Self-hosted Windows CI merged | PWA launch assets done. |
| `sight-fix` | Next PWA + Capacitor config | TBD | TBD | Self-hosted Windows CI merged | PWA assets and service worker done. |
| `apsis` | Vite PWA | GitHub Pages / container path TBD | TBD | Self-hosted Windows CI merged | Docker aligned to Node/npm. |
| `vlog-learning` | Vite multi-page app | Container path TBD | TBD | Self-hosted Windows CI merged | Build fixed; lint/test scripts need later repair. |
| `seolith-platform` | .NET/Angular shared platform | Local/prod compose TBD | API health endpoint TBD | Reusable .NET and Angular workflows | Authentik groups mapped to roles. |
| `one-prompt-lab` | Next app + local infra | Existing local/docker deployment scripts | TBD | Needs deeper workflow cleanup | Ignore rules fixed; backend local output remains preserved. |
| `seolith-portal` | .NET + Next/Angular ecosystem | Docker compose / production TBD | TBD | Self-hosted fixes merged earlier | Needs .NET SDK/image alignment when targeting .NET 10. |

## Required Fields Per Repo

For each active repo, record:

- Production URL.
- Hosting provider.
- Deployment workflow name.
- Required GitHub environments.
- Secret names.
- Health check URL.
- Rollback command.
- Owner.
- Observability dashboard URL.

## Latest Fleet URL Sweep

Run from this repository:

```powershell
.\scripts\test-fleet-urls.ps1 -AllowProtected
```

Last verified on 2026-06-15 from the Apps Showcase catalog seed:

- `35` app URLs returned HTTP 200 with application titles.
- `10` URLs returned HTTP 200 but are still classified as placeholders.
- `3` URLs returned HTTP 200 behind an Authentik/protected page.
- `0` catalog URLs were broken.

Placeholder entries to convert into dedicated production apps or explicitly mark as placeholders in Portal/Fleet:

- `aimything.com`
- `quietsentinelshadow.com`
- `srvinvestmentsllc.com`
- `staging.aimything.com`
- `staging.hindibuddy.online`
- `staging.laakansolutions.com`
- `staging.quietsentinelshadow.com`
- `staging.srvinvestmentsllc.com`
- `staging-tamil-letters.seolith.com`
- `www.eyezen.app`

Protected entries that should be treated as auth-gated rather than down:

- `app-builder.seolith.com`
- `staging-app-builder.seolith.com`
- `staging.debugdojo.com`

## Next Fill-In Pass

Start with the public apps first: `seolith-praiseit`, `memorize-world`, `sight-fix`, `apsis`, `vlog-learning`, and `critter-path-adventures`.
