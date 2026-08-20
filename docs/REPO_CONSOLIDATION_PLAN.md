# Repo Consolidation Plan

Goal: one repo per product, one generation per product, no empty stubs. Archiving on
GitHub is free and fully reversible — it sets the repo read-only, it does not delete it.

Commands use: `gh repo archive seolith-llc/<repo> --yes`
Undo with:        `gh repo unarchive seolith-llc/<repo> --yes`

## Tier 1 — Safe to archive now (empty stubs or clearly superseded)

| Repo | Reason |
|---|---|
| `virosa-backend` | README-only stub |
| `seolith-system-side` | README-only stub |
| `SEOlithAI` | Superseded by `SEOlithAI4PCI` (byte-identical README; 4PCI is the client fork that lives on) |
| `debug-dojo-academy` | Superseded by `seolith-debug-dojo` (Lovable-template copy) |
| `plumbing-care-inc-content` | Content merged into the PCI site repos |

## Tier 2 — Archive after owner confirms the successor is complete

| Archive | Keep | Why |
|---|---|---|
| `SCL` | `second-chance-leads` | Two generations of one product; SCL is the older frontend-only generation |
| `PTO` | `pto-admin` | Same product, two repos |
| `pci-hvac` | `beta-pcihvac.seolith.com` | WordPress export vs the Angular SSR rebuild — confirm the rebuild shipped |
| `seolith-next-gen-site`, `seolith-solutions-llc` | `seolith-main-site` | Four "company site" repos; keep one |
| `jjglassworks`, `seolith-jjgw` | `agent-jjgw-2006` | Same J&J Glassworks client across three repos — confirm which is live |
| `seolith-app-creator` | `seolith-app-builder` | PromptArchitect duplicates app-builder's prompt module; merge any unique code first |

## Tier 3 — Decision required (same concept, multiple backends — do NOT archive yet)

- **Omnifield cluster**: `omnifield-ai` (ControlTower), `seolith-omnifield` (LeadsReporter),
  `seolith-omnifield-ai` (BusinessOS). Three backends for one business-OS concept.
  Pick the canonical codebase, migrate unique features, archive the other two.
- **Virosa cluster**: `virosa` (React Native app), `virosa-frontend` (React 19 web +
  a stale nested `frontend/` React 18 copy to delete), `virosa-backend` (stub, Tier 1).
  If Virosa is the next generation of Omnifield, fold it into that decision.
- **`seolith-app-factory`**: generic `@org/*` branding, Keycloak-based (estate standard is
  Authentik), zero consumers. Either rebrand/integrate as the template home or archive.
- **`seolith-saas-template`**: 34-file shell. Archive once the golden template
  (see docs/ONBOARDING.md) exists.
- **`seolith-ui-2026`**: 7,110-file dump — README for a different project, three parallel
  frontends, committed logs, a vendor zip, tracked `FE-cruxz/.env.local`. Quarantine:
  archive it, extract anything worth keeping into a fresh repo.

## Dedup without archiving

- **Lovable/shadcn family** (`seolith-hindi-buddy`, `seolith-learn-tamil-letters`,
  `gs-apsis-app`, `critter-path-adventures`): each carries its own diverging copy of the
  ~50-file shadcn `src/components/ui/` tree. Extract to a published `@seolith/ui` package
  (pattern already proven in `seolith-reference-sites/packages/ui`) and delete the copies.
- **Cookie-cutter .NET verticals** (~15 repos sharing the same slnx + Angular skeleton):
  formalize that skeleton as THE golden template; new apps scaffold from it instead of
  copy-pasting the nearest sibling.
- **`seolith-sdk`**: unpublishable skeleton with committed `node_modules`. Fold its real
  TS modules (identity/logging/theming) into the `@seolith/*` packages and archive,
  or rebuild it properly as the JS SDK home. Do not let it linger as-is.

## Execution checklist per archive

1. Confirm no active deployment pulls from the repo (check the EC2 deploy workflows).
2. `gh repo archive seolith-llc/<repo> --yes`
3. Add a one-line pointer in the successor repo's README ("history of X lives in archived repo Y").
4. Log the archive in `docs/fleet-modernization` (date, repo, successor).
