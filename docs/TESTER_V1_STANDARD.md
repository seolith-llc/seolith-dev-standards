# Seolith Tester v1 standard

Version 1, 2026-09-08. This is the canonical estate contract and adoption checklist
for a private `/tester` catalog, manual results, history, and screenshot evidence.
It does not enable a runtime feature or add a required CI gate. Record each app's
implementation, staging acceptance, and production activation separately in the
[convergence plan](CONVERGENCE_PLAN.md#tester-v1-adoption).

The reference is Omnifield commit `fe346a6b34d6534764448d23b1265a460c423146`:
[protocol](https://github.com/seolith-llc/seolith-omnifield/blob/fe346a6b34d6534764448d23b1265a460c423146/docs/standards/tester-v1.md),
[wire types](https://github.com/seolith-llc/seolith-omnifield/blob/fe346a6b34d6534764448d23b1265a460c423146/frontend/src/lib/tester/contracts.ts),
and [operator guide](https://github.com/seolith-llc/seolith-omnifield/blob/fe346a6b34d6534764448d23b1265a460c423146/docs/handbook/TESTER-PORTAL.md).
This provenance establishes implemented behavior, not the current serving release.

## Ownership and package boundary

Each host serves `/tester` and `/api/tester` with its existing login and durable
storage. There is no new shared identity service or cross-app evidence database.
A manual result records an observation; Tester does not execute case steps,
arbitrary JavaScript, or provider requests, or infer a pass from an image.

The [seolith-sdk repository](https://github.com/seolith-llc/seolith-sdk) owns
[`packages/tester-core`](https://github.com/seolith-llc/seolith-sdk/blob/1e83c44e8905efbf140e67becef18462878f5938/packages/tester-core/README.md),
named `@seolith-llc/tester-core`. Its foundation commit
`1e83c44e8905efbf140e67becef18462878f5938` landed through
[SDK PR #38](https://github.com/seolith-llc/seolith-sdk/pull/38). Package `0.1.0` is
**private, UNLICENSED, and unpublished**. Do not assume registry installation or
change its publishing policy as part of app adoption. Package SemVer and wire
`schemaVersion: 1` are separate. Its `PROVENANCE.json` records the copied reference
files; the extraction preserves storage identity and behavior, normalizing source
imports for ESM. The original Omnifield source package was named `@seolith/tester-core`.

| Shared browser core owns | Host application owns |
|---|---|
| Wire types, IndexedDB store and partition key | Trusted context, login, live permission checks, account lifecycle |
| Drafts, outbox, attachment bytes, explicit conflict/recovery operations | Editor UI, identity-bound async callbacks, save/error states and export UI |
| `TesterSync` and `TesterTransport` contract | Authenticated transport, attachment downloads and before/after request identity guards |
| Sequence cursor and local evidence retention | Transactional server, immutable history, authorization and durable evidence |
| Browser primitives without framework dependencies | Routing, noindex, service worker, sync scheduling and deployment verification |

The package requires browser IndexedDB, `structuredClone`, `Blob`, and
`crypto.randomUUID` in a secure context. Importing from an SSR build is supported;
storage and sync run only in the browser. It adds no Angular or React dependency.

## Identity and access

The server derives `appId`, `environment`, release, actor ID/name and home tenant
from trusted host configuration and the live authenticated account. Require a
dedicated tester permission on every endpoint, including attachment retrieval;
reject impersonation. Omnifield uses `tester.access` independently of its legacy
RBAC switch: SuperAdmin's wildcard and AdminSupport's seeded grant qualify.
Other apps must map an equivalent explicit permission through their existing roles.

The workspace is the app/environment and actor's authorized home tenant. Actors
in that tenant may collaborate through server records; a global operator receives
no implicit access to another tenant's tester history. Product roles listed in a
case describe the test actors and grant no portal permission.

Every queued operation includes `expectedActorId` and `expectedTenantId` from its
verified context. On every submission the server compares both to the current
account and live home tenant; a move after preflight returns 403 `tenant_mismatch`.
These fields bind the operation, never select server scope. Do not rewrite them
to submit old evidence under a different identity. Tokens never enter the outbox.

Before and after **every awaited HTTP request**, the host transport must verify
the captured login generation, actor, tenant, app and environment. Guard editors
and async save/recovery callbacks the same way; invalidate the editor on a scope
change, including another actor in the same tenant. The core's initial preflight
and tenant-bound response checks cannot replace these host guards.

An observed 401/403 invalidates cached authorization and locks the workspace while
retaining local evidence. Cached context alone is not a login. Offline reopening
requires a matching unexpired host session plus previously verified context;
logout, expiry, impersonation or identity changes lock it. Online access must be
rechecked; disconnected clients cannot discover a newly revoked permission.

Keep `/tester` out of public navigation and sitemaps. Serve `X-Robots-Tag: noindex,
nofollow, nosnippet, noarchive`; tester APIs and attachment responses use
`Cache-Control: private, no-store`. These directives supplement authorization.
They neither hide a public endpoint from direct access nor encrypt local storage.

## Manifest and definitions

Validate catalogs against [tester-manifest.schema.json](tester-manifest.schema.json),
then separately check unique case IDs and matching host `appId`; JSON Schema alone
does not enforce uniqueness by ID. A portable seed looks like:

```json
{
  "schemaVersion": 1,
  "appId": "example-app",
  "manifestVersion": "1.0.0",
  "cases": [{
    "id": "EXAMPLE-T01",
    "title": "Sign in, reload, and sign out",
    "category": "Identity",
    "route": "/login",
    "roles": ["Tester"],
    "prerequisites": "Effects: session changes only. Use a disposable test account; sign out afterward.",
    "steps": ["Sign in.", "Reload a protected page.", "Sign out and revisit that page."],
    "expected": "Reload preserves access; signing out requires login on the protected page.",
    "status": "active"
  }]
}
```

IDs are stable within an app and never recycled. Seed import inserts missing IDs
only; it never overwrites authored edits, archival or history. Runtime cases add
integer revision, created/updated timestamps, and verified author snapshots.
Catalog authorship is `Repository catalog`, observed release
`catalog:<manifestVersion>`, rather than the first visitor's identity. Updating
shipped text does not migrate existing revisions: edit explicitly or use a new ID
for a different scenario. Case status is `active` or `archived`.

Prerequisites state fixtures, permissions, environment restrictions, side effects
and cleanup. Do not embed customer records or secrets. Unconfigured integrations
need explicit empty/disconnected/unsupported outcomes, not fabricated live results.

## HTTP and wire contract

JSON uses camelCase; schema version is the integer `1`. UUID operation IDs are
generated once and retained across retries. UTC ISO timestamps supplied by a
client are observations; server acceptance and sequence establish ordering.

| Endpoint | Contract |
|---|---|
| `GET /api/tester/context` | `TesterContext`: schema, app/environment/release, actor `{id,name,tenantId}`, screenshot limits |
| `GET /api/tester/cases` | `TesterCase[]`, active and archived; import missing seeds idempotently |
| `GET /api/tester/events?afterSequence=0&limit=100` | `{events,nextSequence,hasMore}`; nonnegative cursor, page size 1–200, default 100 |
| `POST /api/tester/operations` | Committed `TesterReceipt`: `{operationId,event,case}` |
| `GET /api/tester/attachments/{id}` | Authorized tenant-scoped raster bytes, never a public asset URL |

A result of an existing revision can be submitted as:

```json
{
  "schemaVersion": 1,
  "operationId": "f3e5b096-c56b-4eac-b646-503c494135fa",
  "appId": "example-app",
  "environment": "staging",
  "expectedActorId": "verified-actor-id",
  "expectedTenantId": "verified-home-tenant-id",
  "caseId": "EXAMPLE-T01",
  "kind": "run.recorded",
  "baseRevision": 1,
  "occurredAt": "2026-09-08T12:00:00Z",
  "observedRelease": "example-release",
  "result": {"status": "passed", "notes": "Reload and logout matched the expected outcome.", "reproductionSteps": []},
  "screenshots": []
}
```

Replace example identities with verified context, never user-entered labels.
Operation kinds are `case.created`, `case.updated`, and `run.recorded`.
Creates/updates require a complete `definition`; creation uses a new case ID and
base revision zero. Runs require `result` with status `passed`, `failed`, `blocked`
or `skipped`, notes and ordered reproduction steps. A run may supply its pinned
`definition`; the server compares it to the referenced retained revision and
returns a revision conflict on mismatch. It always retains the canonical snapshot.

Events contain ID (equal to operation ID), workspace sequence, case ID/revision,
kind, verified actor, observation/acceptance times and releases, complete definition,
optional result and screenshot metadata. A run of a historical revision retains
that definition even after a later edit. The exact types remain in the pinned
reference above and SDK exports; adapters must not fork field names or enums.

## Transactions, retries and recovery

1. Persist each operation, optimistic case and screenshots atomically before
   showing **Saved locally**. Persist unfinished drafts separately. Give each
   editor a unique draft ID so one tab cannot remove another tab's draft.
2. Commit revision/event, immutable receipt, evidence and ordered feed position
   together on the server. Serialize workspace sequence allocation through commit
   so a reader cannot skip an earlier in-flight event. Pull by sequence, not time.
3. Exact replay returns the original receipt, including its original case snapshot
   even after subsequent edits. Altered reuse of an operation ID is a conflict.
   Remove a queued operation only after accepting its matching receipt; timeouts
   and unknown/proxy errors preserve the operation and evidence. Replay lookup
   precedes revision comparison. A receipt never advances the pull cursor: doing
   so could skip earlier unseen events. Advance it only through validated feed pages.
4. Stale edit revisions return 409 with `currentCase`. Preserve local and server
   versions and request an explicit choice. A conflict blocks that case's dependent
   chain while independent cases can progress. Rebase run mappings use both the
   old revision and complete normalized definition; unrelated historic runs stay put.
5. Correcting a permanently rejected operation atomically archives the originals
   and creates visible saved drafts for every active operation in its case chain.
   Open the selected draft; retain followers for individual review. Corrected and
   rebased operations use fresh operation and screenshot IDs while retaining
   original bytes/IDs in export. Never silently drop followers or overwrite accepted history.

Web Locks can coordinate same-origin tabs, but server idempotency is mandatory.
The host schedules sync on open, reconnect, foreground polling and explicit Sync;
a closed browser is not a background-upload guarantee. Show pending, synced,
conflict and error distinctly. A network failure never becomes a test pass.

## Evidence, storage and limits

| Field | v1 bound |
|---|---|
| Case ID | 160 characters, `^[A-Za-z0-9][A-Za-z0-9._:-]*$` |
| Title / category | 200 / 100 characters |
| Route | 2,048 characters; starts `/`, no `//` prefix or backslash |
| Roles | At most 20 strings, each 100 characters |
| Prerequisites / expected | 8,000 characters each |
| Definition steps | 1–100 nonblank strings, each 4,000 characters |
| Notes / reproduction steps | 16,000 characters / up to 100 nonblank strings of 4,000 characters |
| Screenshots | Optional; at most 3 per operation, each at most 2 MiB (2,097,152 bytes) |
| Screenshot type / filename | PNG, JPEG or WebP / 120 characters, no path or control characters |
| Full operation request | 10 MiB including base64 JSON overhead |
| Local pending work | 100 non-superseded operations; pending operations plus drafts serialize to at most 40 MiB |

Required text is nonblank; text rejects NUL. Screenshot input is
`{id,name,contentType,base64}` with raw base64, no data-URL prefix. Validate MIME
against raster signatures and retain byte size and SHA-256 in attachment metadata.
Size every proxy for the complete envelope. Capture synthetic/redacted evidence;
there is no automatic image redaction.

Use IndexedDB transactions, never screenshot base64 in Web Storage. Partition by
origin, app, environment, home tenant and actor; **exclude release**. Preserve the
reference IndexedDB name/version and partition format when changing package imports.
Upgrades at the same origin preserve drafts, queue, history and evidence. Identity changes
create different partitions; never relabel stored work. Request persistent storage
where available, report quota/transaction failures without claiming a save, and
keep the editor available for correction or export.

Archived originals and cached accepted screenshots remain exportable; they do not
consume the pending-work limit but still consume browser quota. Validate final
replacement capacity atomically with archiving. Keep bytes after acknowledgement
and cache authenticated downloads. Unseen remote screenshots require their first
online fetch. Offline shell/assets require a previously loaded built app/service
worker; development-server success does not prove offline reopening.

Offer a local export containing the current partition's drafts, operations, history
and retained bytes without credentials. Preserve a volatile editor separately from
committed state: Omnifield uses `exportedAt`, `unsavedEditor: {context,draft} | null`
and optional `storageReadError`. If reading IndexedDB fails, context/editor/error
may be the only exported fields; do not label that a full backup. Export is not
server sync, and v1 promises no import UI. Clearing browser data can erase unsynced
work; another origin, browser or device does not share that local store.

Accepted events/evidence are immutable and survive releases and user deletion.
Archive cases through new revisions. The reference stores screenshot bytes in
PostgreSQL `bytea` with event writes in one transaction and database guards against
history updates/deletes. Other durable storage is allowed only with equivalent
commit, access and retention semantics; ephemeral container files are insufficient.
There is no automatic history deletion in v1. Document capacity, encrypted backup,
key recovery, retention and tested restore coverage before activation; distinguish
a release restore point from ongoing scheduled backups and off-host recovery.

## Errors

The HTTP error body is `{code,message,currentCase?}`. The SDK transport must reject
with `{status, error: {code, message, currentCase?}}`, preserving the HTTP status and
nested body; flattening the body prevents its revision-conflict recognition.
`currentCase` accompanies applicable revision conflicts. Proxy responses
may lack JSON; retain local work on unknown/network errors.

| HTTP | Portable codes / behavior |
|---|---|
| 400 | `validation_error`, `unsupported_schema`: retain and correct |
| 401 | `unauthenticated`: invalidate cached access; recover through host login |
| 403 | `access_denied`, `actor_mismatch`, `tenant_mismatch`, `scope_mismatch`, `impersonation_forbidden`: lock access; never relabel and retry |
| 404 | `not_found`: attachment unavailable in authorized workspace |
| 409 | `revision_conflict`, `idempotency_conflict`, `attachment_conflict`: preserve evidence for explicit resolution |
| 413 | `screenshot_too_large`, `request_too_large`: retain editor for evidence correction |
| 503 | `catalog_unavailable` or temporary service failure: report and retain work |

## Adoption sequence

1. Select an app and inventory its actual serving origin, environment/release,
   identity/tenant model, router, proxy limits, datastore and backup coverage.
   Preserve its existing auth contracts; Tester adoption is not an auth migration.
2. Review the private SDK package at an immutable commit, build/test and inspect
   its local tarball. Integrate through an approved dependency available inside a
   clean consumer build context; never require a sibling checkout or silently
   publish the package. Record the package source/version in the consumer lockfile
   and provenance. Until approved distribution exists, record that dependency as
   pending rather than claiming a registry install works.
3. Implement the full host boundary above: guarded transport/editor lifecycle,
   permission mapping, all five server endpoints, durable schema, and a versioned
   app catalog. Preserve pending/browser records and server history through upgrades.
4. Add private routes, tenant-prefix/reserved-path handling, offline assets, noindex,
   evidence UI/export and limits at every proxy. Add operator activation/grant,
   recovery and backup instructions to that app's handbook.
5. Pass the conformance matrix below, then perform authorized staging acceptance
   against the actual public route. Record identity/permission setup, release,
   evidence/history persistence across deployment and rollback prerequisites.
6. Activate production through that app's existing approved workflow and verify
   its serving release. Record the result per app/environment. Package extraction,
   a documentation link or a green mocked browser test is not fleet deployment.

## Conformance evidence

These are consumer acceptance criteria, not new checks in the estate's existing
M1–M10 conformance runner. Each adopter supplies test/run links and pass/fail/not-run
results; a shared-core pass covers only the core. Use disposable fixtures and
explicitly authorize any checks that send messages or mutate live provider data.

| Check | Required evidence |
|---|---|
| TV1-01 Catalog | Schema + duplicate-ID/app binding checks; seed replay preserves edited/archived cases and authored history |
| TV1-02 Access | Anonymous, denied, expired and impersonated requests fail on every endpoint including images; home-tenant isolation and live permission revocation |
| TV1-03 Identity races | Actor switch (including same tenant), home-tenant move and logout during requests/editor callbacks cannot read, queue or sync into another partition; 403 `tenant_mismatch` on moved-tenant write |
| TV1-04 Offline durability | Built app loaded online, then offline create/edit/result with optional image, reload and reconnect; acknowledged and downloaded bytes retained; unseen images explained |
| TV1-05 Failure recovery | Quota/transaction/IndexedDB-read failures keep volatile editor exportable without claiming a save; known 401/403 locks cached access without deleting evidence |
| TV1-06 Replay | Lost acknowledgement and cross-tab duplicate delivery create one event/evidence set; exact replay returns original receipt; altered reuse conflicts |
| TV1-07 Revision chains | Stale edit requires explicit choice; all rejected-chain followers recover as visible drafts with original evidence preserved; fresh screenshot IDs and exact revision/definition mapping |
| TV1-08 History ordering | Concurrent accepted operations plus sequence paging neither skip nor duplicate accepted events; historical runs retain the referenced definition |
| TV1-09 Evidence validation | Empty evidence accepted; malformed/MIME-mismatched/oversize/excess files rejected; 10 MiB proxy envelope supported; cross-tenant retrieval denied |
| TV1-10 Lifecycle | New release/container and user removal retain server history; old browser drafts survive upgrade; immutable storage guards and an isolated restore are exercised |
| TV1-11 Routes and operations | Direct load, refresh, tenant-prefixed route, noindex and private/no-store; no public sitemap link; exact activation/grant and rollback/backup instructions |

SDK verification from its own checkout uses Node 24 and the pinned pnpm:

```sh
corepack pnpm install --frozen-lockfile
corepack pnpm --filter @seolith-llc/tester-core build
corepack pnpm --filter @seolith-llc/tester-core test
```

Run `npm pack --dry-run --ignore-scripts` from `packages/tester-core` after building
to inspect contents without publishing. The SDK covers storage/sync regressions,
native ESM and emitted declaration consumption. It does not establish host auth,
database isolation, browser quota or service-worker behavior. Omnifield's
[browser fixture guide](https://github.com/seolith-llc/seolith-omnifield/blob/fe346a6b34d6534764448d23b1265a460c423146/frontend/e2e/README.md)
documents disposable local tests and separates them from backend/live acceptance.

Changing required fields, enum values, partition identity or storage format needs
an explicit compatibility/migration design for existing drafts and outbox entries.
Do not bump package version as a substitute for a wire/storage migration plan.

Browser references: [IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API),
[persistent storage](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist),
and [Web Locks](https://developer.mozilla.org/en-US/docs/Web/API/Web_Locks_API).
Proxy reference: [nginx request-body limits](https://nginx.org/en/docs/http/ngx_http_core_module.html#client_max_body_size).
