#!/usr/bin/env bash
#
# seolith-conformance.sh -- SEOlith Engineering Standard v2.0, MUST tier (M1-M10).
#
# The enforcement layer for seolith-dev-standards/STANDARD.md (v2.0, 2026-07-28).
# Scans a single repository, or an estate root containing many clones, for the
# ten MUST rules. SWEEP (SW1-SW2) and HOST (H1-H3) tiers are explicitly out of
# scope: they need org credentials or SSM, and this tool makes no network calls.
#
# USAGE
#   seolith-conformance.sh [PATH] [--write-baseline] [--new-only] [--skip a,b,c]
#
#   PATH               A git repo (scanned alone) or a directory of clones
#                      (every child that is a git repo is scanned). Default: .
#   --write-baseline   Freeze the current unwaived findings of each scanned repo
#                      into <repo>/.seolith-conformance-baseline. Exit 0.
#   --new-only         Fail (exit 1) only on findings absent from the committed
#                      baseline. Expired waivers still fail. This is the merge
#                      gate mode: new violations block, frozen debt does not.
#   --skip a,b,c       Estate mode only: directory names to skip (e.g. archived
#                      repos). Non-git directories are always skipped.
#
# OUTPUT
#   One line per finding:   RULE<TAB>repo<TAB>file:line<TAB>message
#   then a per-rule summary. Exit 1 on any reported finding, 0 when clean,
#   2 on usage error.
#
# WAIVERS  (<repo>/.seolith-waivers, tab-separated, '#' comments)
#   RULE<TAB>path[:line]<TAB>expiry(YYYY-MM-DD)<TAB>reason
#   `path` may be a glob and matches the finding's file (or file:line).
#   An EXPIRED waiver is itself a hard failure -- v1.0 shipped an exceptions
#   table the script ignored; exceptions now live where the tool reads them.
#
# BASELINE (<repo>/.seolith-conformance-baseline)
#   Normalised finding keys (RULE<TAB>file<TAB>message -- line numbers dropped,
#   so unrelated edits that shift lines do not un-freeze old debt). A key is
#   written once PER OCCURRENCE: --new-only lets a key absorb only as many
#   findings as were frozen, so adding a second :latest image to a file that
#   already has one frozen finding is NEW and blocks.
#
# PORTABILITY
#   bash + POSIX awk/grep/sed only. Runs under Git Bash on Windows and Linux.
#   No jq (absent estate-wide). No network. Uses `git ls-files` / `git grep`
#   rather than find over full trees: a 75-repo estate scans in minutes.
#
# FALSE-POSITIVE LESSONS ENCODED (each burned a previous scanner version):
#   M1  only live workflows; matrix-derived runs-on flagged as unresolvable.
#   M2  compares directory structure. Does NOT require <repo>/.github to exist
#       (the amtocsoft-quotzo relocation *removes* it) and does NOT compare
#       tracked-file counts to the workflows API total_count (Dependabot's
#       dynamic/ workflow makes that false-fail on every Dependabot repo).
#   M4  matches `secrets.<NAME>` references ONLY. A bare `AWS_ACCESS_KEY_ID=`
#       env assignment fed from assume-role-with-web-identity output is CORRECT
#       and must not fire. Comments never count (seolith-crop-fight's only
#       appleboy string is a comment explaining why SSH was abandoned).
#       Checked on plain lines AND inside run: | block bodies -- the first cut
#       of v2.0 only checked the non-block path and missed the M4 incident
#       class itself (ceo-guide writing secrets.EC2_SSH_KEY to disk inside a
#       run: | block), the mirror image of the v1.0 M6 run:-line bug.
#   M5  an unpinned `npx <bin>` is suppressed when `npm ci` runs earlier in
#       the same job AND the bin is a key in a committed package-lock.json:
#       npm ci installs the exact lockfile tree, so the bin is exact-version
#       pinned -- which is what M5 demands. The danger M5 targets is a package
#       declared in no package.json anywhere in the estate (ecc-agentshield).
#   M6  inspects run: single-line AND multi-line bodies (v1.0 skipped the run:
#       line itself and missed `run: ${{ inputs.build-command }}`); flags
#       caller-controlled runs-on (fromJSON(inputs...)); auto-suppresses
#       type: choice/boolean/number inputs resolved from the workflow file --
#       a choice input cannot carry an arbitrary value.
#   M7  searches compose files to depth 3, never a hardcoded root filename
#       list (which silently certified 11 repos whose deploy compose lives in
#       deploy/ or infrastructure/).
#   M9  detects test-failure discard across a run: block (a test command
#       followed by `exit 0` later in the same block, unless the exit code is
#       honoured in between), not a single-line regex. Calling
#       dotnet-build-test.yml is NOT proof of tests: it tests the first .sln
#       alphabetically and exits 0 having run nothing when that .sln has no
#       test project. echo/Write-Host lines never count as test execution.
#   M10 the -p parity class: rollback must construct the identical compose
#       invocation as deploy. The bug survived because no caller ever
#       triggered rollback.
#   ALL 'live workflow' means a file directly in .github/workflows/. Anything
#       under a subdirectory (legacy/ etc.) is inert by definition -- that IS
#       the M2 finding -- and is never counted for any other rule.

set -u
set -o pipefail

# ---------------------------------------------------------------------------
# args
# ---------------------------------------------------------------------------
ROOT="."
WRITE_BASELINE=0
NEW_ONLY=0
SKIP_LIST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --write-baseline) WRITE_BASELINE=1 ;;
    --new-only)       NEW_ONLY=1 ;;
    --skip)           shift; SKIP_LIST="${1:-}" ;;
    --skip=*)         SKIP_LIST="${1#--skip=}" ;;
    -h|--help)        sed -n '2,80p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)               echo "unknown option: $1" >&2; exit 2 ;;
    *)                ROOT="$1" ;;
  esac
  shift
done

if [ "$WRITE_BASELINE" = 1 ] && [ "$NEW_ONLY" = 1 ]; then
  echo "--write-baseline and --new-only are mutually exclusive" >&2; exit 2
fi
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }

TODAY="$(date +%Y-%m-%d)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/seolith-conf.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

REPORT="$WORK/report"       # final reported findings
: > "$REPORT"
CRASHES=0
WAIVED_TOTAL=0
BASELINED_TOTAL=0
REPOS_SCANNED=0

# ---------------------------------------------------------------------------
# the per-workflow-file analyser (M1 M3 M4 M5 M6 + M9 in-file + META facts).
# Two passes over the same file: pass 1 collects input names whose type is
# choice/boolean/number (cannot carry an arbitrary value -> M6 suppression),
# pass 2 flags. POSIX awk only -- no gawk extensions.
# Emits:  F<TAB>RULE<TAB>line<TAB>message   and   META<TAB>KEY
# ---------------------------------------------------------------------------
WF_AWK='
function ind(s,  t) { t = s; sub(/[^ ].*$/, "", t); return length(t) }
function F(rule, line, msg) { printf "F\t%s\t%s\t%s\n", rule, line, msg }
function flushstep() {
  if (coeline && (tolower(stepname) ~ /test|lint|audit|scan|typecheck/ || stephastest))
    F("M9", coeline, "continue-on-error swallows failures on step [" stepname "]")
  stepname = ""; stephastest = 0; coeline = 0
}
function istest(s) {
  if (s ~ /^[ ]*#/) return 0
  if (s ~ /^[ ]*(echo|Write-Host|Write-Error|Write-Output|print|printf|::)/) return 0
  if (s ~ /(npm|pnpm|yarn)([ ]+run)?[ ]+test([ :"&|;]|:[A-Za-z0-9_-]+|$)/) return 1
  if (s ~ /dotnet[ ]+test/) return 1
  if (s ~ /(^|[ ;&|(])pytest([ ]|$)/) return 1
  if (s ~ /python[0-9.]*[ ]+-m[ ]+(pytest|unittest)/) return 1
  if (s ~ /(^|[ ;&|(])go[ ]+test/) return 1
  if (s ~ /(^|[ ;&|(])cargo[ ]+test/) return 1
  if (s ~ /(^|[ ;&|(])ng[ ]+test/) return 1
  if (s ~ /(^|[ ;&|(])(vitest|jest|phpunit)([ "&|;]|$)/) return 1
  if (s ~ /Invoke-Pester/) return 1
  if (s ~ /node[ ]+--test/) return 1
  return 0
}
function m4check(s, n,  t, name) {
  # secrets.<NAME> refs only -- never bare env-var names (OIDC output is fine)
  if (s ~ /^[ ]*#/) return   # comments never count (the crop-fight lesson)
  t = s
  while (match(t, /secrets\.[A-Za-z0-9_]+/)) {
    name = substr(t, RSTART + 8, RLENGTH - 8)
    t = substr(t, RSTART + RLENGTH)
    if (name ~ /SSH/ && name ~ /KEY/) { F("M4", n, "long-lived credential secrets." name " (SSH key; hosts are SSM)"); continue }
    if (name ~ /^AWS_ACCESS_KEY_ID$|^AWS_SECRET_ACCESS_KEY$|^AWS_SESSION_TOKEN$/) { F("M4", n, "static AWS credential secrets." name " (AWS is OIDC)"); continue }
    if (name ~ /_PAT$|^PAT_|^GH_PAT/) { F("M4", n, "long-lived personal access token secrets." name); continue }
  }
}
function m5check(s, n,  t, pkg) {
  if (match(s, /(^|[ ;&|(])npx[ ]+/)) {
    t = substr(s, RSTART + RLENGTH)
    # strip leading flags; flags that consume a following value drop that too
    while (t ~ /^-/) {
      flag = t; sub(/[ ].*$/, "", flag)
      sub(/^[^ ]+/, "", t); sub(/^[ ]+/, "", t)
      if (flag ~ /^(--prefix|--package|-p|--loglevel|--registry|-w|--workspace|-c|--call)$/) {
        sub(/^[^ ]+/, "", t); sub(/^[ ]+/, "", t)
      }
    }
    pkg = t; sub(/[ ].*$/, "", pkg)
    if (pkg != "" && pkg !~ /@[0-9]+\.[0-9]+\.[0-9]+/) {
      if (sawnpmci)
        # npm ci ran earlier in this job: defer to the shell, which suppresses
        # the finding iff the bin is a key in a committed package-lock.json
        # (then it resolves to the exact-version local install, not the registry)
        printf "NPX\t%s\t%s\n", n, pkg
      else
        F("M5", n, "unpinned npx package [" pkg "] -- resolves to whatever npm calls latest at job start")
    }
  }
  if (s ~ /(curl|wget)[^|]*\|[ ]*(sudo[ ]+)?(ba|z)?sh([ ]|$|-)/)
    F("M5", n, "remote installer piped to shell (curl|sh)")
}
function m6check(s, n,  t, expr, name) {
  t = s
  while (match(t, /\$\{\{[^}]*\}\}/)) {
    expr = substr(t, RSTART, RLENGTH)
    t = substr(t, RSTART + RLENGTH)
    if (match(expr, /inputs\.[A-Za-z0-9_-]+/)) {
      name = substr(expr, RSTART + 7, RLENGTH - 7)
      if (!(name in safe))
        F("M6", n, "caller input [" name "] interpolated into run body -- command injection path")
    }
    if (expr ~ /github\.event\./)
      F("M6", n, "github.event.* interpolated into run body -- attacker-controlled payload")
    if (expr ~ /github\.(head_ref|ref_name)/)
      F("M6", n, "caller-controlled git ref interpolated into run body")
  }
}
function runline(s, n) {
  if (s ~ /^[ ]*#/) return    # commented-out shell lines never count (the
                              # crop-fight lesson: a comment is not a violation)
  if (s ~ /(^|[ ;&|(])npm[ ]+ci([ ]|$)/) sawnpmci = 1
  if (s ~ /[Gg]itleaks/) sawgitleaks = 1
  m5check(s, n)
  m6check(s, n)
  if (s ~ /Invoke-Expression[ ]*[($]/ || s ~ /(^|[^A-Za-z_.])eval[ ]+["$]/)
    F("M6", n, "Invoke-Expression / eval of a runtime string in a run body")
  if (istest(s)) {
    sawtest = 1; stephastest = 1
    if (s ~ /\|\|[ ]*(true|exit[ ]+0|:([ ]|$))/)
      F("M9", n, "test failure discarded on the test line itself (|| true / || exit 0)")
    if (inblock) { btest = 1; bhonor = bsete }
  }
  if (inblock) {
    if (s ~ /set[ ]+-e/) { bsete = 1; if (btest) bhonor = 1 }
    if (btest && s ~ /\$LASTEXITCODE|exit[ ]+\$|\$\?|throw/) bhonor = 1
    if (btest && !bhonor && s ~ /(^[ ]*|[;&][ ]*)exit[ ]+0([ ;]|$)/) {
      F("M9", n, "test failure discarded across run block: exit 0 after test without honouring its exit code")
      btest = 0
    }
  }
}
NR == FNR {
  sub(/\r$/, "")
  if ($0 ~ /^[ ]*#/) next
  if (match($0, /^[ ]*[A-Za-z0-9_.-]+:/)) {
    i = ind($0)
    key = $0; sub(/^[ ]*/, "", key); sub(/:.*/, "", key)
    if (key == "type" && $0 ~ /type:[ ]*.?(choice|boolean|number)/) {
      best = -1
      for (j in keyat) if (j + 0 < i && j + 0 > best) best = j + 0
      if (best >= 0) safe[keyat[best]] = 1
    }
    keyat[i] = key
    for (j in keyat) if (j + 0 > i) delete keyat[j]
  }
  next
}
{
  sub(/\r$/, "")
  line = $0; n = FNR; li = ind(line)
  if (inblock) {
    if (line ~ /^[ ]*$/) next
    if (li > blocki) { m4check(line, n); runline(line, n); next }
    inblock = 0; btest = 0; bhonor = 0; bsete = 0
  }
  if (line ~ /^[ ]*#/) next
  m4check(line, n)
  # job boundaries: an `npm ci` seen earlier in the SAME job is what makes a
  # later bare `npx <bin>` resolve to the local install (M5 suppression path)
  if (line ~ /^jobs:/) { injobs = 1; jobind = 0 }
  else if (injobs && li == 0 && line !~ /^[ ]*$/) injobs = 0
  if (injobs && match(line, /^[ ]+[A-Za-z0-9_.-]+:/)) {
    if (!jobind) jobind = li
    if (li == jobind) sawnpmci = 0
  }
  if (line ~ /^permissions:/) hasperm = 1
  if (line ~ /allow-no-tests:[ ]*.?true/) print "META\tALLOWNOTESTS"
  if (line ~ /^on:/ || onblock) {
    if (line ~ /^on:/) {
      onblock = 1
      if (line ~ /^on:.*(push|pull_request|schedule|workflow_dispatch)/) sawpush = 1
    } else if (li == 0 && line !~ /^[ ]*$/) onblock = 0
    if (onblock && line ~ /^[ ]+(push|pull_request|schedule|workflow_dispatch):?/) sawpush = 1
  }
  if (line ~ /^[ ]*-[ ]+(name|uses|run):/) {
    flushstep()
    if (match(line, /^[ ]*-[ ]+name:[ ]*/)) stepname = substr(line, RSTART + RLENGTH)
  }
  if (line ~ /continue-on-error:[ ]*.?true/) coeline = n
  if (match(line, /^[ ]*(-[ ]+)?runs-on:[ ]*/)) {
    val = tolower(substr(line, RSTART + RLENGTH))
    if (val ~ /\$\{\{[^}]*matrix\./)
      F("M1", n, "matrix-derived runs-on -- unresolvable to a static label set, therefore uncheckable")
    else if (val ~ /\$\{\{[^}]*inputs\./) {
      if (match(val, /inputs\.[a-z0-9_-]+/)) {
        name = substr(val, RSTART + 7, RLENGTH - 7)
        if (!(name in safe))
          F("M6", n, "caller-controlled runs-on [" name "] -- the caller picks the machine")
      }
    }
    else if (val ~ /(ubuntu|windows|macos)-(latest|[0-9]+)/)
      F("M1", n, "GitHub-hosted runner label -- org Actions minutes are spent and the spending limit is 0")
  }
  if (match(line, /^[ ]*(-[ ]+)?uses:[ ]*/)) {
    u = substr(line, RSTART + RLENGTH)
    if (u ~ /appleboy\//) F("M4", n, "appleboy SSH/SCP action -- long-lived host credential path (hosts are SSM)")
    if (u ~ /\/(node-build|node-pwa-build|angular-build-lint)\.ya?ml@/) print "META\tNODELANE"
    if (u ~ /\/dotnet-build-test\.ya?ml@/) print "META\tDOTNETLANE"
    if (u ~ /\/secret-scan\.ya?ml@/) sawgitleaks = 1
  }
  if (line ~ /[Gg]itleaks/ && line ~ /run:|uses:|download|\.tar\.gz|exec|scan/) sawgitleaks = 1
  if (match(line, /^[ ]*(-[ ]+)?run:[ ]*/)) {
    rest = substr(line, RSTART + RLENGTH)
    if (rest ~ /^[|>]/) { inblock = 1; blocki = li; btest = 0; bhonor = 0; bsete = 0 }
    else runline(rest, n)
  }
}
END {
  flushstep()
  if (!hasperm) print "META\tNOPERM"
  if (sawtest)  print "META\tHASTEST"
  if (sawgitleaks && sawpush) print "META\tGATE"
}
'

# ---------------------------------------------------------------------------
# M10 parity analyser: every FLAGS construction in a deploy/rollback file must
# agree on -p. Mixed presence = the rollback -p parity bug.
# ---------------------------------------------------------------------------
M10_AWK='
{ sub(/\r$/, "") }
/^[ \t]*#/ { next }   # a FLAGS construction quoted in a comment is not a construction
/FLAGS=""|FLAGS='"''"'/ {
  nc++; startline[nc] = FNR; hasp[nc] = 0; open = nc; window = 8
}
open && FNR <= startline[open] + 8 {
  if ($0 ~ /FLAGS="[^"]*-p |FLAGS=.*\$FLAGS.*-p |&& FLAGS="-p /) hasp[open] = 1
}
END {
  some = 0; all = 1
  for (i = 1; i <= nc; i++) { if (hasp[i]) some = 1; else all = 0 }
  if (nc >= 2 && some && !all)
    for (i = 1; i <= nc; i++) if (!hasp[i])
      printf "F\tM10\t%s\tcompose invocation built without -p while another path in this file sets it -- rollback would run under the directory-derived project name\n", startline[i]
}
'

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# is <bin> provided by a lockfile-pinned local dependency? `npm ci` installs
# the exact tree from a committed package-lock.json, and lockfile v2/v3
# entries list each package's bin names as keys ("cap" for @capacitor/cli,
# "ng" for @angular/cli); a dependency whose name equals the bin appears as a
# key too. Either way the bin is declared and exact-version pinned -- which is
# what M5 demands. The danger M5 targets is a package declared in no
# package.json anywhere in the estate.
npx_bin_is_pinned_local() {
  local bin="$1" lf
  case "$bin" in *[!A-Za-z0-9_.-]*|"") return 1 ;; esac
  while IFS= read -r lf; do
    [ -f "$lf" ] || continue
    if grep -qE "\"$bin\"[ ]*:" "$lf" 2>/dev/null; then return 0; fi
  done < <(git ls-files -- '*package-lock.json' 2>/dev/null \
           | grep -vE '(^|/)(node_modules|vendor|third_party|openclaw|_actions|\.runner-data)/' | head -25)
  return 1
}

# does any tracked package.json declare a real test script?
repo_has_pkg_test() {
  local p
  while IFS= read -r p; do
    [ -f "$p" ] || continue
    if grep -q '"test"[ ]*:' "$p" 2>/dev/null && ! grep -q 'no test specified' "$p" 2>/dev/null; then
      return 0
    fi
  done < <(git ls-files -- '*package.json' 2>/dev/null | grep -vE '(^|/)node_modules/' | awk -F/ 'NF<=3' | head -25)
  return 1
}

# ---------------------------------------------------------------------------
# scan one repo. cwd must be the repo root. Findings (RULE\tfile\tline\tmsg)
# on stdout.
# ---------------------------------------------------------------------------
scan_repo() {
  local f u meta live_wfs
  local has_gate=0 has_test=0 node_lane=0 dotnet_lane=0 allow_no_tests=0

  live_wfs="$(git ls-files -- '.github/workflows' 2>/dev/null \
              | grep -E '^\.github/workflows/[^/]+\.ya?ml$' || true)"

  # ---- M2: directory structure ------------------------------------------
  # (a) relocated .github -- compare structure; do NOT require ./.github to
  #     exist, the relocation removes it. Vendored trees (checked-in action
  #     checkouts, node_modules, openclaw) are third-party, not relocated CI.
  git ls-files 2>/dev/null | grep -E '.+/\.github/workflows/[^/]+\.ya?ml$' \
  | grep -vE '(^|/)(node_modules|vendor|third_party|openclaw|_actions|\.runner-data)/' \
  | while IFS= read -r f; do
      printf 'M2\t%s\t1\tworkflow under a relocated .github (not at repo root) -- GitHub reads only the root .github, so this CI is silently deregistered\n' "$f"
    done
  # (b) subdirectories below .github/workflows/ are inert by definition.
  git ls-files 2>/dev/null | grep -E '^\.github/workflows/[^/]+/.*\.ya?ml$' \
  | while IFS= read -r f; do
      printf 'M2\t%s\t1\tinert workflow in a subdirectory of .github/workflows/ -- reads as live capability but never executes; one git mv re-arms it\n' "$f"
    done

  # ---- per-live-workflow rules: M1 M3 M4 M5 M6 M9(file) ------------------
  for f in $live_wfs; do
    [ -f "$f" ] || continue
    while IFS=$'\t' read -r kind a b c; do
      case "$kind" in
        F)    printf '%s\t%s\t%s\t%s\n' "$a" "$f" "$b" "$c" ;;
        NPX)  # unpinned npx after an npm ci in the same job: only a finding
              # when the bin is NOT a committed-lockfile-pinned local dep
          if ! npx_bin_is_pinned_local "$b"; then
            printf 'M5\t%s\t%s\tunpinned npx package [%s] -- resolves to whatever npm calls latest at job start\n' "$f" "$a" "$b"
          fi ;;
        META)
          case "$a" in
            NOPERM)       printf 'M3\t%s\t1\tno top-level permissions: block -- one org toggle away from silent write access\n' "$f" ;;
            GATE)         has_gate=1 ;;
            HASTEST)      has_test=1 ;;
            NODELANE)     node_lane=1 ;;
            DOTNETLANE)   dotnet_lane=1 ;;
            ALLOWNOTESTS) allow_no_tests=1 ;;
          esac ;;
      esac
    done < <(awk "$WF_AWK" "$f" "$f" 2>/dev/null || printf 'META\tAWKFAIL\n')
  done

  # ---- M7: deploy compose files, searched to depth 3 ---------------------
  # Never a hardcoded root filename list: that silently certified 11 repos
  # whose deploy compose lives in deploy/, infrastructure/, docker/, backend/.
  local compose_all deploy_set
  compose_all="$(
    for f in *compose*.yml *compose*.yaml */*compose*.yml */*compose*.yaml */*/*compose*.yml */*/*compose*.yaml; do
      [ -f "$f" ] || continue
      case "$f" in *node_modules/*|*openclaw/*|*vendor/*|*_actions/*|.runner-data/*) continue ;; esac
      case "$(basename "$f")" in docker-compose*.yml|docker-compose*.yaml|compose*.yml|compose*.yaml) printf '%s\n' "$f" ;; esac
    done
  )"
  deploy_set="$(printf '%s\n' "$compose_all" | grep -iE '(^|/)[^/]*(prod|staging|release)[^/]*\.ya?ml$' || true)"
  for f in $deploy_set; do
    if grep -qE '^[ \t]*build:' "$f" 2>/dev/null; then
      line=$(grep -nE '^[ \t]*build:' "$f" | head -1 | cut -d: -f1)
      printf 'M7\t%s\t%s\tbuild: in a deploy compose file -- up -d without --build silently reuses whatever local image already carries the name; compose merge cannot delete the key\n' "$f" "$line"
    fi
    grep -nE '^[ \t]*image:.*:latest[ \t"'"'"']*$' "$f" 2>/dev/null \
    | while IFS=: read -r line _rest; do
        printf 'M7\t%s\t%s\t:latest image in a deploy compose file -- mutable tag; unreproducible\n' "$f" "$line"
      done
  done
  # tracked and unmodified applies to EVERY compose file to depth 3
  for f in $compose_all; do
    if ! git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
      printf 'M7\t%s\t1\tcompose file on disk but not tracked by git -- what runs must be reviewable\n' "$f"
    elif [ -n "$(git status --porcelain -- "$f" 2>/dev/null)" ]; then
      printf 'M7\t%s\t1\tcompose file differs from HEAD -- what runs must be what was reviewed\n' "$f"
    fi
  done

  # ---- M8: gitleaks gate + config + committed secrets --------------------
  if [ "$has_gate" = 0 ]; then
    printf 'M8\t.github/workflows\t0\tno gitleaks gate runs on push/PR (secret-scan.yml caller or equivalent)\n'
  fi
  if [ ! -f .gitleaks.toml ]; then
    printf 'M8\t.gitleaks.toml\t0\tno .gitleaks.toml -- copy the canonical config from seolith-dev-standards\n'
  fi
  # private keys in HEAD (placeholder blocks in .md files are excluded: they
  # made v1.0's revocation list unexecutable)
  git grep -I -n -E -e '-----BEGIN( RSA| OPENSSH| EC| DSA| PGP| ENCRYPTED)? PRIVATE KEY( BLOCK)?-----' \
      -- ':!*.md' ':!*.markdown' ':!*.txt' ':!*.rst' ':!.gitleaks.toml' ':!*.baseline' \
      ':!*pre-commit-config*' ':!*.test.*' ':!*.spec.*' ':!*.e2e.*' \
      ':!openclaw/' ':!vendor/' ':!third_party/' ':!__fixtures__/' ':!testdata/' ':!node_modules/' 2>/dev/null \
  | awk -F: '!seen[$1]++ { printf "M8\t%s\t%s\tprivate key committed in HEAD -- rotate at the source; deleting the file leaves it in history\n", $1, $2 }' \
  || true
  # real-shaped PATs (filter obvious placeholders: long same-char runs).
  # .md is NOT excluded here: the estate has held a real, reused PAT in
  # infrastructure docs; shape (not file type) separates real from placeholder.
  git grep -I -n -o -E -e 'gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{59}' \
      -- ':!.gitleaks.toml' ':!openclaw/' ':!vendor/' ':!third_party/' ':!node_modules/' 2>/dev/null \
  | awk -F: '
      {
        # awk EREs have no backreferences, so a same-char run must be counted
        # by hand: 8+ consecutive identical chars marks a doc placeholder
        tok = $3
        ph = 0
        run = 1
        for (c = 2; c <= length(tok); c++) {
          if (substr(tok, c, 1) == substr(tok, c - 1, 1)) {
            run++
            if (run >= 8) { ph = 1; break }
          } else run = 1
        }
        if (tolower(tok) ~ /xxxxxx|123456789/) ph = 1
        if (!ph && !seen[$1]++)
          printf "M8\t%s\t%s\treal-shaped GitHub PAT committed in HEAD -- revoke it; per-repo deletion is insufficient\n", $1, $2
      }' \
  || true
  # secret-bearing .env files in HEAD
  git ls-files 2>/dev/null \
  | grep -E '(^|/)\.env(\.[A-Za-z0-9_.-]+)?$|(^|/)[A-Za-z0-9_.-]+\.env$' \
  | grep -viE '(example|sample|template|dist|schema|spec|test|stub|vault|reference)' \
  | while IFS= read -r f; do
      [ -f "$f" ] || continue
      if grep -E -m1 '^[A-Za-z0-9_]*(SECRET|PASSWORD|PASSWD|PWD|TOKEN|API_KEY|ACCESS_KEY|PRIVATE_KEY|CONNECTION_STRING)[A-Za-z0-9_]*=[^ ]' "$f" 2>/dev/null \
         | grep -qviE '(change_?me|placeholder|example|your[-_]|<[^>]*>|\$\{|\$\(|dummy|xxxx+|redacted|to-?be-?set|fill-?in|^\s*[A-Za-z0-9_]+=\s*$)'; then
        printf 'M8\t%s\t1\tsecret-bearing .env file tracked in HEAD\n' "$f"
      fi
    done

  # ---- M9: repo-level -- CI executes a real test command -----------------
  if [ "$allow_no_tests" = 0 ]; then
    if [ -z "$live_wfs" ]; then
      printf 'M9\t.github/workflows\t0\tno live CI workflow -- tests (if any exist) never execute in CI\n'
    elif [ "$has_test" = 0 ]; then
      if [ "$node_lane" = 1 ] && repo_has_pkg_test; then
        : # node/angular lanes run npm test --if-present and a real test script exists
      elif [ "$dotnet_lane" = 1 ]; then
        printf 'M9\t.github/workflows\t0\tonly dotnet-build-test.yml is called -- NOT proof of tests: it tests the first .sln alphabetically and exits 0 having run nothing when no test project is referenced\n'
      else
        printf 'M9\t.github/workflows\t0\tCI never invokes a test command in any live workflow\n'
      fi
    fi
  fi
  # tests that cannot fail (the pto-admin scaffold pattern)
  git grep -n -E 'Assert\.True\(true[,)]' -- '*.cs' 2>/dev/null | head -5 \
  | while IFS=: read -r f line _rest; do
      printf 'M9\t%s\t%s\tAssert.True(true, ...) is a test that cannot fail -- scaffold assertions are not tests\n' "$f" "$line"
    done

  # ---- M10: rollback/deploy compose invocation parity --------------------
  {
    printf '%s\n' "$live_wfs"
    git ls-files 2>/dev/null | grep -E '\.(sh|ps1)$' | awk -F/ 'NF<=3' || true
  } | sort -u | while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    if grep -qi 'rollback' "$f" 2>/dev/null && grep -qE 'docker([ -])compose|COMPOSE_FILES' "$f" 2>/dev/null; then
      awk "$M10_AWK" "$f" | while IFS=$'\t' read -r kind rule line msg; do
        printf '%s\t%s\t%s\t%s\n' "$rule" "$f" "$line" "$msg"
      done
    fi
  done

  return 0
}

# ---------------------------------------------------------------------------
# post-process one repo's raw findings: waivers, baseline, reporting.
# ---------------------------------------------------------------------------
process_repo() {
  local repo_dir="$1" repo="$2" raw="$3"
  local wf="$repo_dir/.seolith-waivers"
  local bf="$repo_dir/.seolith-conformance-baseline"
  local active="$WORK/waivers.$$" expired="$WORK/expired.$$"
  : > "$active"; : > "$expired"

  # parse waivers
  if [ -f "$wf" ]; then
    awk -F'\t' -v today="$TODAY" '
      /^[ ]*#/ || /^[ ]*$/ { next }
      NF >= 3 {
        gsub(/\r/, "")
        if ($3 < today)
          printf "EXPIRED\t%s\t%s\t%s\t%s\n", $1, NR, $3, $2
        else
          printf "ACTIVE\t%s\t%s\n", $1, $2
      }
    ' "$wf" > "$WORK/wparse.$$" 2>/dev/null || true
    grep '^ACTIVE'  "$WORK/wparse.$$" | cut -f2- > "$active"  || true
    grep '^EXPIRED' "$WORK/wparse.$$" | cut -f2- > "$expired" || true
  fi

  # expired waivers are hard failures, always reported, never suppressible
  while IFS=$'\t' read -r rule lineno expiry path; do
    [ -n "$rule" ] || continue
    printf '%s\t%s\t.seolith-waivers:%s\tEXPIRED waiver for [%s] (expired %s) -- an expired waiver is itself a hard failure\n' \
      "$rule" "$repo" "$lineno" "$path" "$expiry" >> "$REPORT"
  done < "$expired"

  # baseline keys
  local basekeys="$WORK/base.$$"
  : > "$basekeys"
  if [ "$NEW_ONLY" = 1 ] && [ -f "$bf" ]; then
    grep -v '^#' "$bf" > "$basekeys" 2>/dev/null || true
  fi

  local newbase="$WORK/newbase.$$"
  : > "$newbase"

  local rule file line msg waived key avail used
  # each baseline key absorbs only as many findings as occurrences frozen in
  # it -- a key with no count would let a NEW second :latest in an already-
  # baselined file merge silently
  local -A baseused=()
  while IFS=$'\t' read -r rule file line msg; do
    [ -n "$rule" ] || continue
    # waiver match: rule + (file glob or file:line glob)
    waived=0
    while IFS=$'\t' read -r wrule wpath; do
      [ "$wrule" = "$rule" ] || continue
      case "$file" in $wpath) waived=1; break ;; esac
      case "$file:$line" in $wpath) waived=1; break ;; esac
    done < "$active"
    if [ "$waived" = 1 ]; then
      WAIVED_TOTAL=$((WAIVED_TOTAL + 1))
      continue
    fi
    printf '%s\t%s\t%s\n' "$rule" "$file" "$msg" >> "$newbase"
    if [ "$NEW_ONLY" = 1 ]; then
      key="$(printf '%s\t%s\t%s' "$rule" "$file" "$msg")"
      avail="$(grep -cxF "$key" "$basekeys" 2>/dev/null || true)"
      used="${baseused[$key]:-0}"
      if [ "${avail:-0}" -gt "$used" ]; then
        baseused[$key]=$((used + 1))
        BASELINED_TOTAL=$((BASELINED_TOTAL + 1))
        continue
      fi
    fi
    printf '%s\t%s\t%s:%s\t%s\n' "$rule" "$repo" "$file" "$line" "$msg" >> "$REPORT"
  done < "$raw"

  if [ "$WRITE_BASELINE" = 1 ]; then
    {
      printf '# seolith-conformance baseline -- frozen %s. This freezes today%s debt; it does not forgive it.\n' "$TODAY" "'s"
      printf '# key format: RULE<TAB>file<TAB>message (line numbers dropped so edits that shift lines do not un-freeze debt;\n'
      printf '# one line per occurrence, so a second identical violation in the same file is NEW and blocks)\n'
      sort "$newbase"
    } > "$bf"
  fi
  rm -f "$active" "$expired" "$basekeys" "$newbase" "$WORK/wparse.$$" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# main: single-repo or estate mode
# ---------------------------------------------------------------------------
scan_one() {
  local repo_dir="$1" repo="$2"
  local raw="$WORK/raw.$$"
  REPOS_SCANNED=$((REPOS_SCANNED + 1))
  if ! (cd "$repo_dir" && scan_repo) > "$raw" 2> "$WORK/err.$$"; then
    CRASHES=$((CRASHES + 1))
    printf 'CRASH scanning %s:\n' "$repo" >&2
    sed 's/^/  /' "$WORK/err.$$" >&2
  elif [ -s "$WORK/err.$$" ]; then
    # stderr noise without a failing exit still surfaces, once
    sed "s|^|warn($repo): |" "$WORK/err.$$" >&2
  fi
  process_repo "$repo_dir" "$repo" "$raw"
  rm -f "$raw" "$WORK/err.$$"
}

is_skipped() {
  local name="$1" s
  local IFS=', '
  for s in $SKIP_LIST; do [ "$s" = "$name" ] && return 0; done
  return 1
}

if [ -e "$ROOT/.git" ]; then
  scan_one "$ROOT" "$(basename "$(cd "$ROOT" && pwd)")"
else
  for d in "$ROOT"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    [ -e "$d/.git" ] || continue
    is_skipped "$name" && continue
    scan_one "$d" "$name"
  done
fi

# ---------------------------------------------------------------------------
# report
# ---------------------------------------------------------------------------
sort -t "$(printf '\t')" -k1,1 -k2,2 "$REPORT" > "$WORK/sorted"
cat "$WORK/sorted"

echo ""
echo "== seolith-conformance summary ($TODAY) =="
echo "repos scanned: $REPOS_SCANNED"
TOTAL=0
for r in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10; do
  c=$(awk -F'\t' -v r="$r" '$1==r' "$WORK/sorted" | wc -l | tr -d ' ')
  TOTAL=$((TOTAL + c))
  printf '  %-4s %s\n' "$r" "$c"
done
echo "total findings: $TOTAL (waived: $WAIVED_TOTAL, baselined: $BASELINED_TOTAL)"
[ "$CRASHES" -gt 0 ] && echo "CRASHES: $CRASHES" >&2

if [ "$WRITE_BASELINE" = 1 ]; then
  echo "baseline written; existing debt frozen, not forgiven."
  exit 0
fi
if [ "$TOTAL" -gt 0 ] || [ "$CRASHES" -gt 0 ]; then
  exit 1
fi
exit 0
