# Owner Actions Required

Things the automation cannot do for you — each item has the exact steps. Ordered by
customer impact. Delete items as you complete them (or ask for a status refresh).
Last updated: 2026-09-19.

Completed 2026-09-05 and removed from this list: secret rotation (#0 — both Authentik
instances), eventkeep prod cutover (#3), the Authentik registration session (#3b —
done headlessly via the Authentik API), and the walk-in DNS cutover (#4 — see the
legacy-box retirement question below).

Completed 2026-09-06: **main-site pipeline** (was §7) — deploy run 34028227953 green,
`seolith.com`/`www.seolith.com` → 200, `api.seolith.com/api/site/leads` → 405 (POST-only,
correct). Two landmines fixed along the way, both now documented for any future
box-build repo:
- `gh secret set` with `echo` appends a trailing newline — the first deploy failed
  on a poisoned `DEPLOY_PATH`. Always `printf '%s' 'value' | gh secret set …`.
- Box builds that restore `Seolith.Platform.*` from GitHub Packages need
  `GITHUB_PACKAGES_TOKEN=<read:packages PAT>` in the host `.env` — compose passes it
  to BuildKit as the `gh_packages_token` secret. Now set on prod-01
  (`/opt/seolith/prod/seolith-main-site/.env`).

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

## 7. Provision the seolith-secret-sweep GitHub App (blocks the S4 org-wide secret sweep)

`.github/workflows/org-secret-scan.yml` (weekly org-wide gitleaks sweep, estate
backlog S4) is merged-ready but cannot enumerate or clone the org's 116 private
repos with GITHUB_TOKEN — that token is scoped to the workflow's own repo. The
sweep mints a token from a dedicated GitHub App instead (the seolith-ops-dispatch
precedent, not a PAT). Until the app exists, the sweep fails fast with a pointer
here — deliberately, so it can never silently scan only the 4 public repos.

Steps (org owner, ~10 min):

1. https://github.com/organizations/seolith-llc/settings/apps/new
   - Name: `seolith-secret-sweep`
   - Homepage URL: `https://github.com/seolith-llc/seolith-dev-standards`
   - Webhook: uncheck **Active** (the app receives nothing)
   - Repository permissions: **Contents: Read-only** (Metadata read-only is automatic; nothing else)
   - "Where can this GitHub App be installed?": **Only on this account**
2. After creating: note the **App ID**, then **Generate a private key** (downloads a `.pem`).
3. Install the app: https://github.com/organizations/seolith-llc/settings/apps/seolith-secret-sweep/installations
   → choose **All repositories** (new repos then inherit coverage automatically).
4. Add the two org secrets, visible to seolith-dev-standards ONLY
   (`printf`, not `echo` — echo's trailing newline poisons the value):
   ```
   gh secret set SWEEP_APP_ID --org seolith-llc --visibility selected --repos seolith-dev-standards --body "<app id>"
   gh secret set SWEEP_APP_PRIVATE_KEY --org seolith-llc --visibility selected --repos seolith-dev-standards < seolith-secret-sweep.*.private-key.pem
   ```
5. Trigger the first run: `gh workflow run org-secret-scan.yml -R seolith-llc/seolith-dev-standards`
   and check the `org-secret-sweep-report` artifact.

The app is read-only by construction; the workflow further narrows each minted
token to `contents: read`. Rotation: regenerate the private key and re-set
`SWEEP_APP_PRIVATE_KEY` (old keys are revocable from the app settings page).

## 8. Smaller items

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
