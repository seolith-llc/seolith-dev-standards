# Common Services Standard

SEOlith apps should not each invent authentication, audit logging, telemetry, email, configuration, tenancy, health checks, CORS, rate limiting, error handling, document handling, or referral plumbing.

The canonical backend packages live in `seolith-platform`:

| Capability | Canonical package | Required usage |
| --- | --- | --- |
| Authentication and authorization | `Seolith.Platform.Auth` | OIDC/JWT validation, role and group mapping, auth policies |
| Audit trail | `Seolith.Platform.Audit` | Security-relevant events, admin changes, user-visible workflow changes |
| Telemetry | `Seolith.Platform.Telemetry` | OpenTelemetry traces, metrics, structured logs, correlation IDs |
| Email | `Seolith.Platform.Mail` | Transactional email sending, templates, provider configuration |
| Configuration | `Seolith.Platform.Configuration` | Validated options, required secret checks, environment naming |
| Tenancy | `Seolith.Platform.Tenancy` | Tenant resolution, tenant-aware data access, tenant claims |
| Health checks | `Seolith.Platform.HealthChecks` | `/health/live`, `/health/ready`, dependency checks |
| CORS | `Seolith.Platform.Cors` | Environment-specific allowed origins |
| Rate limiting | `Seolith.Platform.RateLimiting` | IP/user/tenant rate policies on public APIs |
| Error handling | `Seolith.Platform.ErrorHandling` | Consistent problem details, exception mapping |
| Documents | `Seolith.Platform.Documents` | Upload validation, document storage contracts |
| Referrals | `Seolith.Platform.Referrals` | Referral tokens, attribution, partner links |

## Required App Baseline

Every production .NET API must:

- Reference the common package for each capability it uses instead of custom local implementations.
- Expose `GET /health/live` and `GET /health/ready`.
- Include correlation IDs in logs and responses.
- Emit structured logs in JSON in production.
- Use OIDC/JWT validation from `Seolith.Platform.Auth`.
- Use `Seolith.Platform.Mail` for transactional email.
- Emit audit events for login, logout, permission failure, admin settings changes, data export, destructive writes, and secret/configuration changes.
- Load configuration through validated options with fail-fast startup checks.
- Apply CORS and rate-limit policies from common packages.

Every frontend or PWA must:

- Use OIDC Authorization Code with PKCE for user login where user identity is required.
- Treat access tokens as short-lived credentials; do not store long-lived credentials in local storage.
- Send the common correlation header when calling APIs.
- Provide an admin-visible app version/build identifier.
- Report client errors to the chosen telemetry target when configured.

Every Cloudflare Worker app must:

- Keep secrets in Cloudflare Worker secrets or bindings, never in source.
- Log request metadata without sensitive prompt, token, or response bodies unless the admin feature explicitly masks and protects it.
- Use D1/R2/KV bindings through named environment bindings.
- Add an admin API token or OIDC gate before exposing usage data.
- Publish retention behavior for request logs and purges.

## Standard Environment Variables

Use these names unless a host requires a different prefix:

| Variable | Purpose |
| --- | --- |
| `SEOLITH_ENVIRONMENT` | `local`, `staging`, or `production` |
| `SEOLITH_SERVICE_NAME` | Stable service name used in logs and traces |
| `SEOLITH_PUBLIC_BASE_URL` | Public URL for links, redirects, callbacks |
| `SEOLITH_OIDC_ISSUER` | OIDC issuer URL |
| `SEOLITH_OIDC_CLIENT_ID` | OIDC client ID |
| `SEOLITH_OIDC_CLIENT_SECRET` | OIDC secret for confidential clients |
| `SEOLITH_OIDC_SCOPES` | Space-delimited scopes |
| `SEOLITH_ALLOWED_ORIGINS` | Comma-delimited CORS origins |
| `SEOLITH_OTEL_ENDPOINT` | OTLP endpoint |
| `SEOLITH_OTEL_HEADERS` | OTLP auth headers |
| `SEOLITH_MAIL_PROVIDER` | `smtp`, `resend`, `sendgrid`, or provider adapter |
| `SEOLITH_MAIL_FROM` | Default sender |
| `SEOLITH_MAIL_REPLY_TO` | Default reply-to |
| `SEOLITH_TENANT_MODE` | `single`, `host`, `path`, or `claim` |

## Migration Order

1. Add health checks, configuration validation, structured logs, and correlation IDs.
2. Replace local auth with `Seolith.Platform.Auth`.
3. Replace direct email provider calls with `Seolith.Platform.Mail`.
4. Add audit events for admin and security operations.
5. Add tenancy only where the product needs tenant isolation.
6. Add rate limits and CORS through the common packages.
7. Add dashboards and alert rules after the signals are consistent.

## Definition of Done

An app is common-services ready when:

- CI passes on the self-hosted Windows runner or an approved GitHub-hosted fallback.
- `scripts/audit-common-services.ps1` reports no blocking gaps for its stack.
- The deployment inventory lists URL, hosting target, secrets, health check, rollback, and owner.
- Production can answer who used the app, what changed, which requests failed, and which email notifications were sent.
