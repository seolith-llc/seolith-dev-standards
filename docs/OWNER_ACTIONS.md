# Owner Actions Required

Things the automation cannot do for you — each item has the exact steps. Ordered by
customer impact. Delete items as you complete them (or ask for a status refresh).
Last updated: 2026-09-05.

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
- **main-site pipeline**: the stack on prod-01 currently runs the June 3 build.
  Deploying current main needs the deploy workflow's GitHub Environment configured
  (it wants a TELEGRAM_BOT_TOKEN/CHAT_ID for notifications — send me those, or I can
  strip the Telegram step and wire it without).

## Delegation offer

Any item above that you hand me credentials or a go-ahead for, I will execute and
verify end-to-end. The Cloudflare seolith.com zone token and AWS SSO profile are
already on file and working.
