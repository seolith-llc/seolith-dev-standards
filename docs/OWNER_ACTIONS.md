# Owner Actions Required

Things the automation cannot do for you — each item has the exact steps. Ordered by
customer impact. Delete items as you complete them (or ask for a status refresh).
Last updated: 2026-09-05 (evening).

Completed 2026-09-05 and removed from this list: secret rotation (#0 — both Authentik
instances), eventkeep prod cutover (#3), the Authentik registration session (#3b —
done headlessly via the Authentik API), and the walk-in DNS cutover (#4 — see the
legacy-box retirement question below).

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
Better long-term: a dedicated Authentik service account so the token stops
expiring — say the word and I'll create one (I can mint it via the Authentik API
now, no UI session needed).

## 3. Browser smoke: apps.seolith.com SSO button

The app-showcase-spa public client is registered and the frontend fix (#117) is
deployed — the SSO button is live and pointing at the right issuer. One interactive
check remains: open https://apps.seolith.com, click SSO, sign in as akadmin, confirm
you land back signed in. While there: mint the first `cpk_…` API key at
/admin/apps → Keys so I can e2e-test `POST https://api-apps.seolith.com/cp/v1/feedback`.

## 4. Group membership for the other admins

I created the groups and put akadmin in `seolith-prod-admins`. In
https://auth.seolith.com/if/admin/ → Directory → Groups, add the people who need
admin in each app:
- `seolith-prod-admins` — estate operators (Admin in eventkeep, money-app,
  apps-showcase; SuperAdmin in pto-admin/twbb by design)
- `seolith-prod-pto-admin-admins`, `seolith-prod-email-manager-admins`,
  `seolith-prod-ceo-guide-admins`, `seolith-prod-tax-manager-admins` — per-app admins
Eventkeep admins specifically need to be in `seolith-prod-admins` before they can
manage eventkeep.pro (the old committed-password login is gone).

## 5. walk-in legacy box: identify and retire

walkin.seolith.com now serves from prod-01 (verified 200 with a valid cert). The
legacy box at 34.239.73.154 is out of the request path but still running somewhere
OUTSIDE the AWS account. Identify whose it is and shut it down — it's unmanaged
and was the reliability risk we just removed.

## 6. Rotate the twbb Keycloak superadmin password

`Twwb@202405` sat in seolith-twbb git history (Keycloak era, now purged via #83).
If that password was reused anywhere, rotate it.

## 7. Smaller items

- **Seq UI spot-check**: log into https://seq.seolith.com and confirm events flow
  from the 13 telemetry-enabled services (ingestion is verified working; the query
  API is auth-protected, which is correct).
- **bos_api**: an orphaned container from a June experiment was removed during the
  portal incident and has no surviving definition or image. If "bos" was something
  you cared about, it needs a redeploy from source; otherwise nothing to do.
- **admin.therewillbebugs.com**: no DNS record exists (traefik labels reference it;
  admin works via twbb.seolith.com/admin). Add the record in the therewillbebugs.com
  Cloudflare zone or let me clean up the stale labels.
- **eyezen.app deploys via Vercel git integration** (not our CI). The serwist
  migration merged 2026-09-05; the Vercel build for that commit sat "queued" for
  25+ minutes and `/sw.js` still serves the old redirect fallback. If it stays
  stuck, check the project in the Vercel dashboard (or hand me a Vercel token).
- **main-site pipeline — ready, one click**: the blocker wasn't Telegram (that step
  already skips gracefully); the `production` GitHub Environment pointed at the OLD
  AWS account (bucket 478087977376, dead instance). Rewired 2026-09-05: new role
  `github-ssm-deploy-main-site`, bucket/instance/DEPLOY_PATH now target prod-01, and
  seolith-main-site#52 pinned the compose project so the pipeline adopts the live
  stack. To deploy current main (the live site runs the June 3 build): Actions →
  Deploy production → Run workflow.
- **money-app productionalizing** (decision, not urgent): monetization.amtocsoft.com
  is confirmed to run on the staging host with a manual deploy pipeline. Move it to
  prod-01 with a real pipeline, or formally accept staging-host hosting.
- **prod-01 traefik localhost rules** (cosmetic, I can fix): several routers in the
  ssi compose request certs for `*.localhost` names alongside real domains, causing
  perpetual Let's Encrypt 400s in the logs. Removing the localhost hostnames from
  those rules stops the noise and the rate-limit risk.

## Delegation offer

Any item above that you hand me credentials or a go-ahead for, I will execute and
verify end-to-end. The Cloudflare seolith.com zone token and AWS SSO profile are
already on file and working.
