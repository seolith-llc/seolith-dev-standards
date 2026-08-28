# Control Plane Plan — one hosted service for shared app functionality

Status: proposed
Date: 2026-08-28
Supersedes: nothing; builds on `COMMON_SERVICES_STANDARD.md` and `REPO_CONSOLIDATION_PLAN.md`

## Problem

An estate-wide survey (2026-08-28, all ~97 repos) found every common
application concern re-implemented per app:

| Concern | Repos with own implementation | Central facility today |
| --- | --- | --- |
| Authentication / authorization | ~17 hand-rolled JWT issuers + users tables | Authentik at `auth.seolith.com` (5 consumers) |
| Email / notifications | ~15 (SES v1, SES v2, SMTP/MailKit, nodemailer) | none |
| Logging bootstrap | ~12 hand-wired Serilog+Seq setups | Seq at `logs.seolith.com`; `Seolith.Platform.Telemetry` (2 consumers) |
| Billing (Stripe) | ~10, each with own webhook handler | none |
| Feedback collection | 7 near-identical widget + EF table builds | none |
| Invites | 5 independent flows | none (Authentik has no cross-app invite) |
| Feature flags | 4 | `Seolith.Platform.Configuration` (2 consumers) |

The standard and the packages already exist; adoption is what is missing.
Two concerns (email, feedback) have no central facility at all.

## Decision

Build one hosted control plane:

- **Where:** extend `seolith-apps-showcase` (`apps.seolith.com`). It already
  has production-shaped invites, feedback (reviews), push notifications, an
  app catalog (becomes the tenancy registry), super-admin UI, and Authentik
  integration. It is the product-facing control plane; `seolith-ops-control`
  stays the operator-facing console and will *consume* the control plane.
- **Substrate:** the `seolith-shared` host (Traefik edge, Authentik, Seq,
  Mailpit). Nothing new to host; the control plane deploys beside them.
- **Distribution:** new `Seolith.Platform.ControlPlane` NuGet and
  `@seolith-llc/control-plane` npm package, following the proven
  `Seolith.Platform.*` / `@seolith-llc/*` pattern.
- **Do not buy** Clerk/Auth0/etc. — duplicates Authentik, adds recurring
  cost, contradicts the hosting-consolidation goals.
- **Do not build on** `seolith-app-factory` / `seolith-app-creator`
  (zero consumers, archive candidates per `REPO_CONSOLIDATION_PLAN.md`).

## Architecture

### Control-plane API (new endpoints in apps-showcase)

Tenancy model: each registered app gets an `AppId` + API key (hashed at
rest, scoped, rotatable). All endpoints are app-scoped; per-app data
isolation enforced by the key, not by user tenancy.

- `POST /cp/v1/notify` — templated email / web-push / in-app message.
  The control plane is the **only** estate component holding SES SMTP
  credentials; per-app email credentials are retired. (This also collapses
  the SES cutover: one credential swap, once, forever.)
- `POST /cp/v1/feedback` — app-scoped feedback ingestion; one ops inbox
  across all apps, with triage/status workflow (omnifield's ticket-queue
  evolution is the model).
- `POST /cp/v1/invites` / `GET /cp/v1/invites/{token}` — cross-app invite
  minting and acceptance metadata; identity itself stays in Authentik.
- `GET /cp/v1/flags` — per-app feature flag evaluation, seeded from the
  `Seolith.Platform.Configuration` flag model.
- Rate limits and audit events (via `Seolith.Platform.Audit`) on all of
  the above; `/health/live` + `/health/ready` per the standard.

### Client SDKs

- `Seolith.Platform.ControlPlane` (.NET): typed clients for the endpoints
  above, Polly retry + circuit breaker, correlation-ID propagation.
- `@seolith-llc/control-plane` (TS): same surface for Node/Next apps.
- Angular feedback widget extracted to `@seolith-llc/ui-angular` (replace
  the 7 copy-pasted widgets with `<seolith-feedback appId="...">`).

### What stays per-app

- Billing: Stripe webhook semantics are app-specific. Ship a shared
  `Seolith.Platform.Billing` **library** (webhook verification, common
  subscription states), not a hosted service.
- User profile/role data with app semantics (per-tenant roles in
  tax-manager, per-domain roles in email-manager): keep per-app tables
  keyed by the OIDC `sub`; Authentik groups carry only cross-app roles.

## Phases

### Phase 0 — Adopt what exists (no new code, ~2 weeks part-time)

1. Standardize logging bootstrap: every .NET API moves to
   `Seolith.Platform.Telemetry` (12 apps, each a small PR).
2. Migrate remaining custom-JWT apps to Authentik. For the .NET fleet this
   is config-sized: swap `IssuerSigningKey` for
   `Authority=https://auth.seolith.com/application/o/{slug}/` (proven by
   seolith-twbb, sportmed, ortho). Order:
   a. ASP.NET Identity apps first (amtocsoft-quotzo, lumi-education-portal,
      seolith-refrilog, seolith-reference-sites) — trivial.
   b. Custom-JWT .NET apps (apps-showcase, alex-lopez-va, lks-site-and-portal,
      memorize-world, email-manager, second-chance-leads, omnifield,
      crop-fight, pto-admin, app-builder, clinical-trial, aegis).
   c. Magic-link apps (money-app, ceo-guide) last — UX depends on owning
      the token; evaluate Authentik passwordless first.
   d. JS outliers (virosa Firebase, debug-dojo Supabase, NextAuth trio) —
      per-stack adapters, case by case.
3. New apps: `seolith-saas-template` is mandatory — it is pre-wired for all
   of the above.

### Phase 1 — Control plane MVP (notify + feedback)

1. App registry + API keys in apps-showcase (admin UI exists; add keys).
2. `POST /cp/v1/notify` backed by the seolith-prod SES SMTP user; migrate
   tax-manager, ceo-guide, email-manager, money-app email sending to it.
3. `POST /cp/v1/feedback` + shared Angular widget; migrate the 7 copies.
4. SDKs published to GitHub Packages (pattern from seolith-sdk).

### Phase 2 — Invites + flags

1. `POST /cp/v1/invites`; extract showcase's invitation flow; migrate
   eventkeep, pci-autobot, crop-fight, lks referral flow.
2. `GET /cp/v1/flags`; converge the 4 flag systems on the platform model.

### Phase 3 — Billing library + cleanup

1. `Seolith.Platform.Billing` NuGet from the most complete implementation
   (amtocsoft-quotzo); migrate the other 9.
2. Archive seolith-app-factory, seolith-app-creator; merge unique code.
3. Update `COMMON_SERVICES_STANDARD.md` to mark control-plane usage as
   required for the four concerns; add a conformance check to the reusable
   CI workflows.

## Effort estimate (single senior dev, part-time)

| Phase | Size |
| --- | --- |
| 0a logging | 12 small PRs, ~1 day total |
| 0b auth migration | 2-4 h per .NET app; ~2-3 weeks for the fleet |
| 1 control-plane MVP | 2-3 weeks (API + keys + SDKs + widget) |
| 2 invites/flags | 1-2 weeks |
| 3 billing lib + archives | 1 week |

## Risks

- **Single point of failure:** the control plane going down must not take
  apps down. SDKs fail open for flags/feedback, queue-and-retry for notify;
  health probes wired into ops-control's existing `/api/health-probes`.
- **SES dependency:** notify requires SES production access in seolith-prod
  (case 178768928700465 in re-review as of 2026-08-28). Phase 1 ordering
  assumes it lands; if it drags, build feedback first.
- **Data migration:** users tables stay per-app keyed by `sub`; no bulk
  password migration needed since Authentik adoption uses each app's
  existing password reset / magic-link path for first login.
- **Adoption drift:** the estate's history is "standard written, adoption
  skipped" (`Seolith.Platform.Telemetry`: 2 consumers). Mitigation: CI
  conformance gate (Phase 3.3) and mandatory template for new apps.

## Success criteria

- Any new app gets auth, logging, email, feedback, invites, flags by
  reference, not by writing code.
- Exactly one SES credential set in the estate (control plane only).
- One feedback inbox, one invite flow, one flag UI for all apps.
- `grep -r "SymmetricSecurityKey" --include=Program.cs` trends to zero.
