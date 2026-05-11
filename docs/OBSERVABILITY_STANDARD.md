# Observability and Admin Dashboard Standard

## Minimum Telemetry

Every production app should capture:

- Request timestamp.
- Route or feature name.
- Authenticated user id or anonymous session id.
- Tenant id where applicable.
- Country/region from hosting edge metadata when available.
- User agent family.
- Status code and error code.
- Duration in milliseconds.
- AI provider, model, token count, and estimated cost when applicable.

Do not log secrets, raw access tokens, payment data, or PHI. For healthcare workflows, store only the minimum metadata needed for audit and operations.

## Admin Dashboard

Every admin console should show:

- Daily active sessions.
- Requests by route and status.
- Error trend.
- Top countries/regions.
- AI request count and estimated cost.
- Recent failed requests with redacted details.
- Retention/purge controls.
- Export for CSV/JSON when useful.

## Retention

- Default operational event retention: 30 days.
- Security audit retention: project-specific, usually longer.
- AI prompt/response retention: off by default unless the product explicitly requires it.
- Provide a purge job or scheduled retention task.

## Alerting

Start with simple thresholds:

- Error rate above 5% for 10 minutes.
- p95 latency above the product-specific SLO for 10 minutes.
- AI daily spend above budget.
- Authentication failures spike.
- Background retention job fails.

## Reference Implementation

`seolith-praiseit` has the current lightweight reference pattern:

- Cloudflare Worker request logging.
- D1 analytics table.
- Admin token gate.
- Usage/cost dashboard.
- Daily retention purge.
