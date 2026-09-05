# Owner Actions Required

Things the automation cannot do for you — each item has the exact steps. Ordered by
customer impact. Delete items as you complete them (or ask for a status refresh).
Last updated: 2026-09-05.

## 0. URGENT: rotate two secrets that lived on seolith-platform main

`docs/notes.md` (deleted 2026-09-05 in seolith-platform#75) contained live
`POSTGRES_PASSWORD` and `AUTHENTIK_SECRET_KEY` values. Deleting the file does
NOT remove them from git history — both are compromised and must be rotated:
- Postgres password for the authentik stack database on platform-prod.
- Authentik `AUTHENTIK_SECRET_KEY` (rotating invalidates all Authentik sessions —
  everyone logs in again once; plan for that).
I can execute both rotations over SSM as soon as AWS SSO is re-authenticated
(`aws sso login --profile sso-seolith-prod`) — say go.

## 1. WordPress contact form on beta-pcihvac.seolith.com is dead (losing leads TODAY)

Evidence: the live WordPress MetForm endpoint
`https://plumbingcareinc.com/wp-json/metform/v1/entries/insert/3679` rejects every
submission with `401 Unauthorized submission` (no captcha involved).

Fix options (needs WordPress admin at plumbingcareinc.com):
- MetForm → the form with ID 3679 → check its settings/security plugin rules
  (Wordfence or similar is likely blocking REST writes), or
- Fastest permanent fix: the replacement Angular app's form is already wired to the
  estate leads API and verified working — finishing the Angular migration retires the
  WordPress site entirely.

Leads API is live regardless: `POST https://api.seolith.com/api/site/leads`
(verified 2026-09-05; three probe rows with "probe" in the message can be deleted in
the site-admin lead inbox).

## 2. Portal release verification needs an ops token (deploy evidence)

The portal deploy pipeline is fully fixed, but the final release-evidence step fails
because repo secret `PORTAL_OPS_ACCOUNTABILITY_TOKEN` (seolith-portal) is empty —
the daily portal-ops-verification has failed on the same gap for weeks.

Steps: log into https://portal.seolith.com as an admin, copy your session token
(browser dev tools → Application → cookies/local storage), then:
`gh secret set PORTAL_OPS_ACCOUNTABILITY_TOKEN -R seolith-llc/seolith-portal`
Better long-term: create a dedicated Authentik service account so the token stops
expiring — happy to set that up when you're at the Authentik UI.

## 3. Eventkeep production cutover (code merged, waiting on you)

seolith-eventkeep#534 killed the committed-password seeder and moved auth to
Authentik. Before I dispatch the production deploy:
- In https://auth.seolith.com admin UI: put the eventkeep admins into the
  `seolith-prod-admins` group (or an `Admin` group).
- The `eventkeep` Authentik application itself is confirmed registered and serving.
Then tell me to dispatch; deploy is a deliberate manual action.

## 3b. One Authentik admin session registers everything (W2 wave complete)

All W2 auth migrations are merged. Do this in one sitting at
https://auth.seolith.com (admin UI), then tell me to proceed with cutovers:

| App | Provider slug + client | Redirect URI | Group to create |
| --- | --- | --- | --- |
| money-app | `money-app` | `https://monetization.amtocsoft.com/api/auth/authentik/callback` | — (uses `seolith-prod-admins`) |
| pto-admin | `pto-admin` | (API bearer; confirm issuer URL serves) | `seolith-prod-pto-admin-admins` |
| email-manager | `email-manager` (NEW) | (API bearer; confirm issuer URL serves) | `seolith-prod-email-manager-admins` |
| ceo-guide | `ceo-guide` (verify exists) | (API bearer) | `seolith-prod-ceo-guide-admins` |
| tax-manager | `tax-manager` (verify exists) | (API bearer) | `seolith-prod-tax-manager-admins` |
| app-showcase SPA | `app-showcase-spa` (NEW, **public** client — the existing `app-showcase` client is confidential/backend-only) | `https://apps.seolith.com/auth/callback` (+ `http://localhost:4200/auth/callback` for dev; add post-logout URIs) | — (uses `seolith-prod-admins` + app groups) |

For every app: make sure the provider emits the `groups` claim in tokens (property
mapping). Estate operators belong in `seolith-prod-admins` (gets Admin everywhere;
SuperAdmin in pto-admin/twbb by design).
Already registered and confirmed: `eventkeep`, `portal`, `app-showcase`.
Also needed at cutover time: `Auth__ClientSecret` for money-app in the host `.env`
(only app that needs one — it's the cookie/PKCE flow).

Note: money-app currently has NO production deploy pipeline (only a manual
staging deploy); monetization.amtocsoft.com is CONFIRMED to run on the staging
host (its A record 18.190.201.241 is the staging box — same IP as all
staging-*.seolith.com records). Productionalizing it (move to prod-01 + real
pipeline, or formally accept staging-host hosting) is a separate decision.

## 4. walk-in: cut over from the mystery legacy box

`walkin.seolith.com` still resolves to `34.239.73.154` — an unmanaged box OUTSIDE
the AWS account that is alive and serving customers today. The replacement stack is
deployed and healthy on prod-01 (`/opt/walk-in`). Cutover needs:
- Traefik routing for walkin.seolith.com on prod-01 (I can do this), then
- DNS change in Cloudflare (I have the zone token — say the word).
Also decide: what is that legacy box, and can it be shut down after cutover?

## 5. Rotate the twbb Keycloak superadmin password

`Twwb@202405` sat in seolith-twbb git history (Keycloak era, now purged via #83).
If that password was reused anywhere, rotate it.

## 6. Smaller items

- **Seq UI spot-check**: log into https://seq.seolith.com and confirm events flow
  from the 13 telemetry-enabled services (ingestion is verified working; the query
  API is auth-protected, which is correct).
- **bos_api**: an orphaned container from a June experiment was removed during the
  portal incident and has no surviving definition or image. If "bos" was something
  you cared about, it needs a redeploy from source; otherwise nothing to do.
- **apps.seolith.com SSO smoke**: one sign-in through
  https://apps.seolith.com/login → SSO after the #115 deploy, plus mint the first
  `cpk_…` API key at /admin/apps → Keys so I can e2e-test `POST
  https://api-apps.seolith.com/cp/v1/feedback` (it currently 405s).
- **admin.therewillbebugs.com**: no DNS record exists (traefik labels reference it;
  admin works via twbb.seolith.com/admin). Add the record in the therewillbebugs.com
  Cloudflare zone or let me clean up the stale labels.
- **eyezen.app deploys via Vercel git integration** (not our CI). The serwist
  migration merged 2026-09-05; the Vercel build for that commit sat "queued" for
  25+ minutes and `/sw.js` still serves the old redirect fallback. If it stays
  stuck, check the project in the Vercel dashboard (or hand me a Vercel token).
- **main-site pipeline**: the stack on prod-01 currently runs the June 3 build.
  Deploying current main needs the deploy workflow's GitHub Environment configured
  (it wants a TELEGRAM_BOT_TOKEN/CHAT_ID for notifications — send me those, or I can
  strip the Telegram step and wire it without).

## Delegation offer

Any item above that you hand me credentials or a go-ahead for, I will execute and
verify end-to-end. The Cloudflare seolith.com zone token and AWS SSO profile are
already on file and working.
