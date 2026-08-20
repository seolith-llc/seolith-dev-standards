# Secret Rotation & Hygiene Runbook

Status of known exposures as of 2026-08-19 audit. **Rotation can only be completed in the provider consoles (AWS, OpenAI, Supabase, Firebase) by an account admin** — deleting from git is not rotation.

## P0 — Rotate immediately

### 1. AWS + OpenAI keys in `seolith-vault/scrub-secrets.txt`

`seolith-vault/scrub-secrets.txt` is a plaintext "scrub mapping table" that itself contains
the live values: an AWS access key pair (`AKIA…`, referenced against SEOlithAI) and an
OpenAI `sk-proj-…` key. It is tracked in git and cloned to every developer machine.

1. AWS console → IAM → deactivate + delete access key `AKIAW6UC…` (see file for full value), issue replacement, update consumers.
2. OpenAI platform → API keys → revoke the `sk-proj-…` key, issue replacement.
3. Remove the file from git and purge history (commands below).
4. Going forward, scrub tables must record **fingerprints** (first 8 chars + hash), never full values.

### 2. Unrotated history credentials (two repos, incl. seolith-goptr)

`seolith-goptr/.github/workflows/secret-scan.yml` documents credentials committed for
months in two repos, rotation **declined by CTO 2026-08-01**, with `scan-history: false`
set so the finding is permanently ungated. With a new team onboarding and every repo
cloned to new machines, revisit this decision:

1. Identify the two repos and the specific credentials (recorded in the PR that introduced the secret-scan files).
2. Rotate them, then purge history.
3. Flip `scan-history` back to `true` in the reusable `secret-scan.yml` in this repo (dev-standards) — all 55 consumers inherit it.

## P2 — Hygiene (public-by-design, low risk)

These files are tracked in git but contain **client-side values that are inlined into the
shipped JS bundle anyway** (Supabase publishable key, Firebase web config, VAPID public
key, telemetry ingest URL). They are not secrets. Decide once, document, move on:

- `debug-dojo-academy/.env` — Supabase publishable key/URL. Now covered by a `.gitignore`; untrack with `git rm --cached .env`.
- `seolith-debug-dojo/.env` — Firebase web config + Sentry DSN. `.gitignore` updated to cover `.env`; untrack with `git rm --cached .env`.
- `seolith-fishbowl/apps/app/.env.production` — intentionally tracked and documented as public. **Leave as-is.**

Recommended estate rule: track `.env.example` (placeholder values), never `.env`;
exceptions like fishbowl's must carry an in-file justification comment.

## Standard rotation procedure (any credential)

1. **Rotate first** at the provider — assume any committed value is compromised.
2. Update the real source of truth (runner secrets / GitHub Actions secrets / EC2 SSM).
3. Remove from the working tree (`git rm --cached`), verify `.gitignore` covers it.
4. Purge history (see below) — deletion without purge leaves it in every clone.
5. Record the incident + rotation date in the repo's SECURITY.md.

## History purge commands (destructive — run with owner sign-off)

```bash
# Prereq: install git-filter-repo (pip install git-filter-repo)
# Example: seolith-vault
cd seolith-vault
git rm --cached scrub-secrets.txt migrate-secrets.js   # keep local copies OUTSIDE git if still needed
git commit -m "chore: untrack secret material"
git filter-repo --path scrub-secrets.txt --path migrate-secrets.js --invert-paths --force
git push origin --force --all
git push origin --force --tags
# Every clone must re-clone or: git fetch origin && git reset --hard origin/main
```

Note: force-push rewrites shared history. Coordinate with the team; GitHub may retain
cached views of the old commits — rotation (step 1) is the only true fix.

## Prevention (already available in this repo)

- `secret-scan.yml` reusable workflow gates HEAD on every PR for 55 repos — keep it mandatory.
- After rotations complete, set `scan-history: true` once, fleet-wide, to certify clean.
- Add `.env`, `.env.*` (with `!.env.example`) to every repo `.gitignore` — enforced via `scripts/seolith-conformance.sh` MUST-tier checks.
