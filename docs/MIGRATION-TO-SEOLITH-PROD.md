# Migration: consolidate all hosting into the `seolith-prod` AWS account

Status: **Wave 1 complete** (last updated 2026-08-25).

## Wave log

- **Wave 1 (2026-08-25) — DONE.**
  - `amtocsoft-staging` (quotzo staging, staging.quotzo.com — note: no
    public DNS record exists; site was IP-only): amtocbot
    i-0eeb5c0669181d03d STOPPED → seolith-prod i-0055fc33af719303d
    (44.201.120.78, t4g.micro, us-east-1). AMI copy (unencrypted, shared
    AMI + snapshot), all 4 containers verified healthy. New SG restricts
    SSH to the admin IP (was 0.0.0.0/0).
  - `seolith-mail` (Stalwart mail + email-manager UI): amtocbot
    i-06b09a100510c354a STOPPED → seolith-prod i-05133115c203cdb87
    (t4g.micro, us-east-1). **EIP 3.214.251.135 transferred** cross-account
    (~2 min detachment, no DNS changes). Verified: ESMTP banner on :25,
    IMAP/submission ports listening, email-manager.seolith.com 200 via CF.
  - Sources: stop-before-terminate soak; terminate after ~1 quiet week,
    then deregister migration AMIs/snapshots and schedule the temporary
    CMK `alias/migration-cross-account` (076276bc-...-1a9598) for deletion.

### Lessons baked into the runbook (from Wave 1)

- Sharing an AMI is NOT enough — also `modify-snapshot-attribute` every
  underlying snapshot, else target `copy-image` fails with "You do not
  have permission to access the storage of this ami".
- If the source volume's CMK policy is locked (auto-ebs keys lack an
  enable-IAM statement — even admin gets PutKeyPolicy AccessDenied):
  create a temporary migration CMK (enable-IAM + target-account
  statement), `copy-snapshot --encrypted --kms-key-id <mig-key>`, then
  `register-image` from the copy (copy arch/root-device/boot-mode from
  the source AMI) and share that AMI + snapshot.
- EIP transfer: source `enable-address-transfer` → (disassociate first if
  attached — accept fails with InvalidTransfer.AddressAssociated) →
  target `accept-address-transfer` → `associate-address`.
- On Git Bash, `MSYS_NO_PATHCONV=1` or `/dev/sda1` gets mangled into a
  Windows path in register-image.

## Why

The estate is spread across three AWS accounts plus orphan resources.
Consolidate everything into one dedicated **workload** account
(`seolith-prod`), keep the management account nearly empty, and close the
rest. Decision record: user explicitly chose a dedicated member account
over running workloads in the org management account (2026-08-24).

## Account map

| Account | Id | Role | Workloads (as of 2026-08-24) |
|---|---|---|---|
| seolithllc | 875427248175 | org **management** — target: near-empty | `seolith-apps` i-0ae1f2f7ef448c698 (3.222.183.150: foxy, invoices), `seolith-platform-prod-app-host-01` i-0568fed3ba46ac6af (18.218.248.26: auth-new), S3: tfstate, cloudtrail, config, foxyinvoice, seolith-tax |
| **seolith-prod** | **819168518599** | **consolidation target** | empty (foundation done) |
| laakansolutions | 478087977376 | member — **empty + close** | prod-app-host-01 i-049e358ee9ea8118a (18.190.199.160), prod-app-host-02 i-03186641877827f53 (3.14.169.232), staging-app-host-01 i-072321eac21205fcf (18.190.201.241), orgqa-demo i-0b91d234c8b8ce97b us-east-1 (STOPPED 2026-08-24 — do not migrate; terminate after owner confirms), `seolith-prod-backups-478087977376` S3, SES identities us-east-1 |
| amtocbot | 137451611488 | member — **empty + close** | `amtocsoft-prod` (t4g.small 44.203.231.37), `amtocsoft-staging` (t4g.micro 18.215.63.23), `seolith-mail` (t4g.micro 3.214.251.135: email-manager.seolith.com), `seolith-apps` (t3.medium 34.239.73.154: 14 client sites — copperline, elowen, havenmark, ironpeak, lumessa, northvent, onyxhaus, smartfight, terravine, vitalume, voltari, walkin + `-admin` variants) |

AWS CLI profiles (all SSO, session `seolith`): `sso-mgmt` (875427248175),
`sso-seolith-prod` (819168518599), `sso-prod` (478087977376, legacy name —
this is laakansolutions), `sso-staging` (137451611488, legacy name — this
is amtocbot).

Unexplained DNS IPs (no live instance found in any account): 3.133.57.145
(ortho, platform-auth, platform-logs), 44.204.104.184 (admin-twbb).
Likely stopped instances or stale records — resolve during Wave 3/4.

## Foundation status (seolith-prod, done 2026-08-24)

- Account created via Organizations, root email `seolith-prod@seolith.com`,
  org role `OrganizationAccountAccessRole`.
- SSO: AdministratorAccess assigned to seolith.com@gmail.com; CLI profile
  `sso-seolith-prod` (region us-east-2).
- Default VPCs present in us-east-1 and us-east-2.
- S3 `seolith-prod-backups-819168518599` (us-east-2): versioning on, all
  public access blocked. Future home of host backups (currently they land
  in `seolith-prod-backups-478087977376`).
- Budget `seolith-prod-monthly` $200/mo: 80% actual + 100% forecast email
  alerts to seolith-prod@seolith.com.
- Org CloudTrail `seolith-org-trail` covers the account automatically.
- Quota increases requested 2026-08-24 (check before each wave):
  Standard vCPU 5 → 64 and EIP 5 → 20, both us-east-1 and us-east-2.

## Wave plan

Rehearsal first, stateful last. Every wave follows the per-instance
runbook below. Soak at least 48h before terminating the source instance.

| Wave | Instances | Notes |
|---|---|---|
| 1 | seolith-mail (amtocbot), amtocsoft-staging (amtocbot) | t4g = **ARM/Graviton** — AMIs only launch on ARM types |
| 2 | seolith-apps (mgmt, foxy/invoices), seolith-apps (amtocbot, 14 client sites) | client-site host needs extra verification per site |
| 3 | seolith-platform-prod-app-host-01 (mgmt), amtocsoft-prod (amtocbot) | amtocsoft-prod is t4g (ARM) |
| 4 | prod-app-host-02, staging-app-host-01, prod-app-host-01 (laakansolutions) | the big docker estates; see Wave 4 notes |
| tail | SES re-verify, S3 backups sync, close amtocbot + laakansolutions, remove SSO assignments, buy Savings Plan | see Tail section |

## Per-instance runbook

1. **Prep**
   - List every DNS record (all Cloudflare zones, not just seolith.com)
     pointing at the instance's EIP. Record them — you'll flip or re-point.
   - Verify backups are current (offen/docker-volume-backup → S3 on the
     docker hosts; manual dump for single-purpose boxes).
   - Note security group rules; recreate equivalent SG in seolith-prod.
2. **Image** — for single-purpose/small boxes a no-reboot AMI is fine;
   for DB-heavy hosts prefer a clean stop first:
   `aws ec2 create-image --no-reboot` (or stop → create-image → start).
3. **Encryption check** — snapshots encrypted with the AWS-managed
   `aws/ebs` key CANNOT be shared cross-account. If so: create a
   customer-managed CMK in the source account with a key policy granting
   seolith-prod (819168518599) `kms:*` on the key, `aws ec2 copy-snapshot`
   re-encrypting to that CMK, share the copy + CMK with seolith-prod.
4. **Share & launch** — share AMI (or snapshots) with 819168518599; in
   seolith-prod `aws ec2 copy-image` (re-encrypt with target-side CMK),
   then launch with the same instance type (respect ARM vs x86!) and the
   new SG.
5. **IP strategy** — preferred: Elastic IP transfer (source:
   modify/tranfer EIP to target account, accept in target) so DNS is
   untouched. Fallback: flip Cloudflare A/CNAME records to the new IP
   (trivial for proxied records; the one-off-workflow pattern in
   seolith-next-gen-site git history shows how).
6. **Verify** — app health checks, Traefik routers, HTTPS from outside,
   cron/backup jobs running, mail flow for seolith-mail.
7. **Soak 48h** → stop source instance → terminate after another quiet
   week. Do not skip the stop-before-terminate week on Wave 4.

## Wave 4 notes (the big docker hosts)

- Order: prod-app-host-02 (smallest) → staging-app-host-01 →
  prod-app-host-01 (largest, ~100 containers, live client traffic).
- Stop → create-image → start. Containers come back via
  `restart: unless-stopped`; verify with `docker ps` count against the
  pre-stop inventory (see HOSTING_CONSOLIDATION.md for the 2026-08-24
  baseline).
- DNS: dozens of records across zones point at these EIPs. Prefer EIP
  transfer; if any EIP can't transfer, flip records via the Cloudflare
  API before cutting over.
- After all three move: nothing stateful remains in laakansolutions.

## Tail

1. SES: re-verify sending domains/identities in seolith-prod us-east-1
   (DKIM CNAMEs are already in Cloudflare zones — reissue there), update
   SMTP creds on hosts (foxyinvoice, email-manager).
2. S3: sync `seolith-prod-backups-478087977376` →
   `seolith-prod-backups-819168518599`; repoint offen/docker-volume-backup
   configs on every host; keep the old bucket 90 days.
3. Close accounts: `aws organizations close-account` for amtocbot, then
   laakansolutions (90-day post-closure window; remove SSO assignments
   first). Keep seolithllc for management + billing only.
4. Buy a 1-year Compute Savings Plan in the org once the estate is stable
   (~28% off the EC2 baseline).
5. Update this file + HOSTING_CONSOLIDATION.md as waves complete.
