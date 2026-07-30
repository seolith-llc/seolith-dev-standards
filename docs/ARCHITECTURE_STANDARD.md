# SEOlith Architecture Standard

The decision framework above the operating docs. Where [CI_CD_STANDARD](CI_CD_STANDARD.md),
[COMMON_SERVICES_STANDARD](COMMON_SERVICES_STANDARD.md) and
[OBSERVABILITY_STANDARD](OBSERVABILITY_STANDARD.md) say *how*, this document says
*what gets built, kept, split, merged, hardened, or archived — and why*.

**Relationship to the SEOlith Engineering Standard v2.0**
(`seolith-ops-control/docs/estate-engineering-standard.md`): that document owns
the per-repo conformance rules (M1–M10, SWEEP, HOST, SHOULD) with their
incident histories; this one owns estate-level decisions (tiering, topology,
cost, AI-enablement). Where they touch, **v2.0's rules win** — in particular
its S20 reasoning that blanket `uses:` SHA-pinning is a SHOULD, scoped to
non-`actions/`-namespace publishers if ever promoted. Known defect, recorded
here until fixed: v2.0 declares its home as `seolith-dev-standards/STANDARD.md`
enforced by `scripts/seolith-conformance.sh`, and **neither file exists in any
repo** — the enforcement layer was specified (465-finding baseline measured
2026-07-28) but never committed. Building it is a standing hardening
deliverable.

Effective 2026-07-30. Owner: CTO. Changes via PR to this file; every material
architecture decision gets a dated entry in the Decision Log at the bottom.

---

## 1. Estate tiering

Every repo carries exactly one tier. The tier decides how much rigor it gets.
Tier assignments live in `seolith-ops-control/docs/estate-map.md`.

| Tier | Definition | Bar |
|---|---|---|
| **platform** | Shared libraries, standards, ops tooling other repos depend on | Highest: green CI, real tests, pinned deps, versioned releases |
| **product** | Has plausible paying users; monetization candidate | Green CI, staging deploy, vuln SLO, runbook |
| **client-work** | Built for a named client (PCI, LKS, J&J, …) | Green CI + whatever the engagement contract requires |
| **app-or-game** | Consumer PWA/app kept alive for portfolio value | Green CI; hardening is best-effort |
| **tool / infra** | Internal utilities, IaC | Green CI; secrets hygiene non-negotiable |
| **experiment** | Prototype; may graduate or die | CI optional, secret scan mandatory |
| **dead** | Superseded/abandoned | **Archive it.** Read-only costs nothing and reverses in one click |

**Rule: a repo that would embarrass us if an AI agent read it and took it as an
example of our standards is either fixed or archived — never left ambiguous.**

## 2. Security baseline (all tiers)

1. **No secrets in git.** The gitleaks gate (`secret-scan.yml`) is a required
   check everywhere. A found secret is rotated, not just deleted — history
   remembers.
2. **Vulnerability SLO by tier.** platform/product: zero critical, highs
   within 30 days. client-work: contract-driven, default same as product.
   app-or-game/tool: no criticals older than 90 days. experiment: triaged at
   graduation, not before. (Estate baseline on 2026-07-30: **2,897 open
   alerts** — the SLO applies to the burn-down, not as an instant bar.)
3. **Supply chain.** Third-party tools executed in CI (e.g. `ecc-agentshield`)
   pinned to exact versions and listed in the Supply-Chain Register (§8);
   `npx --yes` of an unpinned package in a workflow is a defect (v2.0 M5).
   `uses:` SHA-pinning follows v2.0 S20: SHOULD, prioritized for
   non-`actions/`-namespace publishers — not a blanket merge gate.
4. **Dependency confusion.** Private packages (`Seolith.Platform.*`) resolve
   only from the GitHub feed via `packageSourceMapping`; everything else only
   from the public registry. (And: **no `--` inside XML comments** — NuGet
   rejects the whole config file.)
5. **Workflow permissions.** Top-level `permissions: contents: read`; jobs
   escalate individually (`packages: read/write`) and reusable-workflow callers
   must grant explicitly. `pull_request_target` is banned without CTO sign-off.
6. **CI runs on our hardware.** Self-hosted runners mean workflow code executes
   on SEOlith machines: fork PRs never trigger runners, and no repo grants
   outside collaborators write access without moving its CI off the shared pool.

## 3. Performance & cost

- **Budgets are per-product, set at productization** (first paying customer or
  first public launch, whichever comes first): page-weight and TTI for web,
  container image size for services, build wall-clock ≤ 10 min on the shared
  pool for everything.
- **The estate cost ceiling stands: no new fixed-cost services while customer
  count is zero.** Pay-per-use (Stripe, SES) is acceptable; monthly-fee SaaS is
  not. Revisit-trigger: first paying customer buys nightly backups and a
  failover conversation — recorded here so it isn't relitigated each time.
- Shared CI capacity (7 runners on 2 machines) is a commons: caches are shared
  (`DOTNET_INSTALL_DIR`, npm cache), and a workflow that re-downloads SDKs per
  run is a defect, not a preference.

## 4. Quality gates

Merged via PR, enforced by required checks; never merged red:

| Gate | platform | product | client-work | app/tool | experiment |
|---|---|---|---|---|---|
| Build green from clean clone | ✔ | ✔ | ✔ | ✔ | — |
| Secret scan | ✔ | ✔ | ✔ | ✔ | ✔ |
| Tests exist and run | real suite | real suite | contract | smoke | — |
| Lint/format configured | ✔ | ✔ | ✔ | best-effort | — |
| Branch protection | ✔ | ✔ | ✔ | ✔ | ✔ |

"Green from clean clone" is literal: no sibling-checkout `ProjectReference`, no
machine-specific paths, no implicit local feeds. That defect cost this estate a
seven-week red streak in three repos; it does not come back.

## 5. Repo topology: split & consolidate criteria

Default is **one deployable per repo, shared code in versioned packages**. Act
only on evidence:

**Split a repo when** two deployables in it ship on different cadences, or a
consumer needs a library inside it without the app around it (→ extract to
`seolith-platform` / an npm package in `seolith-sdk`).

**Consolidate repos when** two repos deploy together to serve one product, or
they are near-duplicates (several `seolith-app-*` generations, two debug-dojo
variants): keep the winner, archive the loser — merging histories is rarely
worth it.

**Never** split for org-chart or aesthetic reasons; every extra repo costs CI
wiring, secret-scan coverage, vuln triage, and AI-agent context.

## 6. Operations

- Every **product** and **client-work** repo has a `docs/RUNBOOK.md`: how to
  deploy, roll back, where it runs, who is paged (today: Raghu, always).
- Deploy order and datastore coupling live in
  `seolith-ops-control/docs/production-deployment-order.md` — new coupling
  between apps (shared Redis, shared DB) requires a PR to that doc first.
- Known single points of failure are recorded, owned, and priced: Traefik on
  the single staging host, this desktop as the Windows CI pool, one human
  operator. Fixing them is tied to the first-customer revisit-trigger, not to
  discomfort.

## 7. AI-enablement standard

The estate is being prepared for AI agents as first-class engineers. Contract:

1. **Every active repo carries a `CLAUDE.md`** (agent-agnostic content,
   canonical name): what the repo is, how to build/test, what NOT to touch,
   links here and to the estate map. Schema in
   [AI_AGENT_HANDOVER](AI_AGENT_HANDOVER.md).
2. **Agents work through PRs only.** Required checks are the harness: an agent
   that can't merge red can't hurt main. No agent holds long-lived cloud
   credentials; deploys happen from merged main via OIDC, never from an agent's
   hands.
3. **Agent-written code meets the same gates as human code** — no separate
   lane, no rubber-stamp merges of agent PRs.
4. **Processes get AI-enabled through the same door**: a process is automatable
   when its inputs are readable from the estate (repos, issues, logs) and its
   output is a PR, an issue, or a report. Processes requiring production
   credentials stay human-executed until §2's constraint is deliberately
   revisited.

## 8. Supply-Chain Register

Third-party code executed by CI on our machines, beyond pinned marketplace
actions. Additions require a PR touching this table.

| Tool | Version | Where | Purpose | Reviewed |
|---|---|---|---|---|
| `ecc-agentshield` | 1.4.0 (pinned) | dotnet/node/angular shared workflows | AI-config security audit | pinned 2026-07 (PR #41); code audit pending |
| `gitleaks` | 8.30.1 (SHA-verified) | secret-scan.yml | secret detection | 2026-07 (PR #43) |

## Decision Log

- **2026-07-30** — Standard created. Estate baseline: 78 repos, 2,897 open
  Dependabot alerts, 7 self-hosted runners on 2 machines. Tiering model and
  first-customer revisit-triggers adopted.
- **2026-07-30** — CTO decisions (interactive review): 10-repo archive slate
  **approved and executed** (−576 alerts, −22 criticals); flagships designated
  **seolith-omnifield, seolith-tax-manager, SCL + second-chance-leads**;
  AI-platform choice deferred until after stabilization (handover docs stay
  platform-neutral); hardening waves 0–4 approved as proposed.
- **2026-07-30** — GitHub Packages is the only path for shared .NET code;
  sibling-checkout `ProjectReference` across repos is banned (root cause of the
  June–July red streak in ortho/sportmed/domain-suite).
