# SEOlith Engineering Standard — v2.0

This is the declared home of the standard; the **canonical text lives at
[`seolith-ops-control/docs/estate-engineering-standard.md`](https://github.com/seolith-llc/seolith-ops-control/blob/main/docs/estate-engineering-standard.md)**
(v2.0, 2026-07-28) and is deliberately not duplicated here — two copies would
drift, and v2.0's own history shows what stale numbers cost.

Until 2026-07-30 this file and the enforcement script below **did not exist**,
despite v2.0 naming both — the standard's enforcement layer was specified
(465-finding baseline measured 2026-07-28) but never committed. It exists now.

## Enforcement

```bash
# Whole estate (from a directory containing the clones):
scripts/seolith-conformance.sh /path/to/clones --skip <archived,repos>

# One repo:
scripts/seolith-conformance.sh /path/to/repo

# Freeze existing debt, then gate only NEW violations in CI:
scripts/seolith-conformance.sh . --write-baseline
scripts/seolith-conformance.sh . --new-only
```

Covers the MUST tier (M1–M10) only. SWEEP and HOST tiers need org credentials
or SSM and are run separately (see v2.0). Waivers: `.seolith-waivers` per repo
(tab-separated, expiry-dated; an expired waiver is itself a failure). Canonical
per-repo waiver files for v2.0's documented-exceptions table live in
[`waivers/`](waivers/).

Measured runs: 465 findings (2026-07-28, 75 clones, the spec's baseline) →
**181 findings + 54 waived (2026-07-30, 65 active clones, this tool)** — the
delta is the archive slate leaving scope plus the hardening wave (secret-scan
rollout, permissions blocks, key removals, npx pinning), each verified during
the tool's adversarial review, not assumed.

Decision layer above this standard: [`docs/ARCHITECTURE_STANDARD.md`](docs/ARCHITECTURE_STANDARD.md).
