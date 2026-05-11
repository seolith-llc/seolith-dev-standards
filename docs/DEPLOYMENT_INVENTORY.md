# Deployment Inventory

This is the working production inventory. Fill unknowns before making deployment promises for that repo.

| Repository | Type | Production target | Health check | CI standard | Notes |
| --- | --- | --- | --- | --- | --- |
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

## Next Fill-In Pass

Start with the public apps first: `seolith-praiseit`, `memorize-world`, `sight-fix`, `apsis`, `vlog-learning`, and `critter-path-adventures`.
