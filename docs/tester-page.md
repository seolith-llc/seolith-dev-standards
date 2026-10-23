# /tester (not searchable)

Every shipped app exposes `/tester` for signed-in testers only.

- Tabs: Smoke, Functional, Regression, History
- Each case: how to test, expected result, result, notes, **version**
- Stored in `localStorage` keyed by app + tester email
- POSTed to `/api/tester/runs`; client flushes the queue at least once per 24h
- `X-Robots-Tag: noindex` and `robots.txt` Disallow `/tester`

Do not add `/tester` to sitemaps. Do not link it from public nav.
