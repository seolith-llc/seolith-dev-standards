# AI Agent Handover Standard

How a SEOlith repo becomes safely workable by an AI agent (Claude Code, Copilot
agents, or any successor) with no human in the loop until PR review. Companion
to [ARCHITECTURE_STANDARD §7](ARCHITECTURE_STANDARD.md#7-ai-enablement-standard).

## The handover bar

A repo is **agent-ready** when all five hold:

1. CI is green on main from a clean clone, and required checks gate merges.
2. Secret scan is a required check, and no live credential exists in history
   that has not been rotated.
3. `CLAUDE.md` exists at repo root and follows the schema below.
4. The repo's tier is recorded in the estate map, so an agent knows how much
   rigor its changes must meet.
5. Deploys happen from merged main via OIDC — nothing an agent can run locally
   ships code to a host.

Repos below the bar get agents only in supervised sessions.

## CLAUDE.md schema

Keep it under ~80 lines; agents read it every session. Content is
agent-agnostic; the filename is canonical so every tool finds one file.

```markdown
# <repo-name>

<Two sentences: what this is, who uses it.>
Tier: <platform|product|client-work|app-or-game|tool|infra|experiment>  (see estate map)

## Build & test
<Exact commands that work from a clean clone, Windows and/or Linux.>

## Layout
<3-6 bullets: where the app, tests, deploy config live.>

## Do not touch
<Hard constraints: files owned by other systems, generated code,
 credentials-adjacent config, standing cost constraints that code
 must respect (no new paid services, no snapshots, ...).>

## Deploy
<How this ships: which workflow, which label pool, staging URL.
 Or "not deployed" / "parked".>

## Landmines
<The non-obvious: known-flaky tests, DNS records that look wrong but
 are production, sibling repos this one is often confused with.>
```

## Agent permission model

| Capability | Granted? | Mechanism |
|---|---|---|
| Read repo, open PRs | yes | repo-scoped token, `contents:write` on branches |
| Merge to main | no | branch protection + required checks; human merges |
| Run CI | yes, implicitly | PR triggers; runs on the shared self-hosted pool |
| Cloud credentials | no | deploys are OIDC-from-main only |
| Org/repo settings | no | admin stays human |
| Production data | no | staging only; prod access is a human act |

Rationale: the blast radius of a wrong agent action must be "a PR nobody
merges", never "a host nobody can recover".

## Working agreements for agents

- One concern per PR; describe what was verified, not just what changed.
- An agent that finds a live credential stops and reports it — no cleanup
  attempts that rewrite history mid-flight.
- Agent-authored workflow changes get human review line-by-line: workflows
  execute on SEOlith hardware.
- When CI disagrees with the agent's local run, CI wins until proven otherwise.
