#!/usr/bin/env bash
#
# install-estate-waivers.sh -- deliver the STANDARD.md documented-exception
# waivers to the estate clones.
#
# The v2.0 standard's exceptions table (STANDARD.md "Documented exceptions")
# is honoured by seolith-conformance.sh via per-repo .seolith-waivers files.
# v1.0 shipped an exceptions table the script ignored; v2.0 shipped a script
# that reads exceptions from files nobody had written. The canonical files
# live in this repo under waivers/<repo>.seolith-waivers; this installer
# copies each into the matching clone under an estate root. Commit the file
# in each target repo -- an uncommitted waiver only helps local runs.
#
# USAGE:  install-estate-waivers.sh <estate-root>

set -u

ROOT="${1:-}"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "usage: install-estate-waivers.sh <estate-root>" >&2; exit 2; }
SRC="$(cd "$(dirname "$0")/.." && pwd)/waivers"
[ -d "$SRC" ] || { echo "waivers/ not found next to this script's repo root" >&2; exit 2; }

installed=0
for f in "$SRC"/*.seolith-waivers; do
  [ -f "$f" ] || continue
  repo="$(basename "$f" .seolith-waivers)"
  if [ -e "$ROOT/$repo/.git" ]; then
    cp "$f" "$ROOT/$repo/.seolith-waivers"
    echo "installed $repo/.seolith-waivers"
    installed=$((installed + 1))
  else
    echo "skip: $ROOT/$repo is not a git clone" >&2
  fi
done
echo "$installed waiver file(s) installed"
