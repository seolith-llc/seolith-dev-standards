# SEOlith Development Standards Runbook

## Ownership

- Service: `seolith-dev-standards`
- Owner: SEOlith LLC platform engineering
- Repository: `https://github.com/seolith-llc/seolith-dev-standards`
- Type: reusable GitHub Actions workflows and engineering standards
- Runtime: GitHub Actions on SEOlith self-hosted Windows runners
- Public endpoint: none; this repository is a shared build dependency, not a deployed application

## Consumers

Fleet repositories reference reusable workflows from `.github/workflows/`, including:

- `angular-build-lint.yml`
- `dotnet-build-test.yml`
- `node-build.yml`
- `node-pwa-build.yml`

Portal Fleet scans those references to measure standards adoption and runner usage.

## Operational checks

1. Verify both self-hosted runner smoke workflows complete successfully.
2. Validate each reusable workflow with a representative consumer before changing its default branch reference.
3. Confirm runner labels, Node version, .NET version, cache inputs, audit level, and artifact paths match the consumer contract.
4. Check recent consumer runs for regressions after a shared workflow change.
5. Keep `docs/DEPLOYMENT_INVENTORY.md` aligned with verified production targets and health checks.

## Change and release process

1. Create a scoped branch and document the compatibility impact.
2. Run the repository smoke workflows on the self-hosted runners.
3. Test the changed reusable workflow from at least one representative application PR.
4. Merge only after both the standards repository and consumer checks pass.
5. Prefer immutable release tags for broad fleet adoption; references to `@main` require careful compatibility review.
6. Update the affected standard document and Portal Fleet evidence in the same delivery batch.

## Rollback

1. Identify the last verified shared-workflow commit or release tag.
2. Revert the shared change or pin affected consumers to the last verified tag.
3. Re-run the runner smoke workflows and one representative consumer build.
4. Check that queued and in-progress workflows are not still executing the faulty revision.
5. Record affected repositories, failed runs, rollback commit, and follow-up work in Portal operations.

## Diagnostics

1. Check organization runner status, labels, availability, and working-directory disk space.
2. Inspect the reusable workflow run and the calling repository run; failures may originate in either layer.
3. Confirm the caller supplied every required input and secret without exposing secret values in logs.
4. Compare the failing consumer against a successful consumer using the same workflow revision.
5. For checkout, cache, or install failures, inspect runner state before modifying application code.

## Known risks

- Changes on `main` can affect many repositories that do not pin an immutable workflow tag.
- Self-hosted runners are shared capacity and can delay unrelated build and deployment jobs.
- Runner-local caches and stale workspaces can create environment-specific failures.
- Preview runtime versions can introduce fleet-wide incompatibilities if adopted before representative testing.
- This repository defines build standards but cannot prove an application's production health, rollback, accessibility, or security by itself.
