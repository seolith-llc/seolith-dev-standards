# Site Essentials Standard

Every public-facing web repo in the SEOlith estate must comply with the 20
items below. "Site" means anything served over HTTP(S) to end users:
marketing pages, SPAs, PWAs, and server-rendered apps.

Estate platform facts that shape this standard:

- **TLS is edge-terminated.** Production containers sit behind Traefik with a
  Let's Encrypt resolver (compose labels
  `traefik.http.routers.*.rule/tls/certresolver`), or on Cloudflare
  Pages/Workers where HTTPS is automatic. Apps must still set HSTS headers
  and must never hardcode `http://` asset URLs.
- **Analytics default is Cloudflare Web Analytics** — free and cookieless.
- **Spam protection default is Cloudflare Turnstile** on every public form.
- Audits run estate-wide from `seolith-ops-control` (`ops/site-essentials/`);
  see Rollout at the bottom.

Each item has three parts: **Requirement** (what "done" means),
**Implementation** (per stack: Next.js App Router, Angular, Vite/React SPA,
plain static/Cloudflare Pages, ASP.NET), and **Verification** (what the
automated audit checks vs. what needs manual review).

---

## 1. Privacy policy

**Requirement.** Every site ships a privacy policy page at a stable route
(e.g. `/privacy`), linked from the footer of every page. The page must be
part of the repo so it survives redeploys — never an ad-hoc file dropped on
a server. It must describe what data is collected (including analytics and
form submissions), where it is stored, and contact information.

**Implementation.**

- Next.js: `app/privacy/page.tsx` (static export-friendly).
- Angular: a `PrivacyComponent` routed at `/privacy`, footer link in the
  shell component.
- Vite/React SPA: a `/privacy` route in the router; footer link in the
  layout. If the SPA has no router, a `privacy.html` static page is
  acceptable.
- Static/Cloudflare Pages: `public/privacy.html` (or `/privacy/index.html`).
- ASP.NET: a Razor page `Pages/Privacy.cshtml` or a static file under
  `wwwroot`; link in `_Layout.cshtml` footer.

**Verification.** Automated: GET `/privacy` (and common alternates) returns
200 with non-trivial content; footer of the home page contains a link to it;
path exists in the repo. Manual: content accuracy and completeness.

## 2. Terms & conditions

**Requirement.** Every site ships a terms & conditions page at a stable
route (e.g. `/terms`), linked from the footer of every page, versioned in
the repo like the privacy policy.

**Implementation.** Same pattern as item 1, at `/terms` (or
`/terms-of-service`). Both pages may share a layout/template.

**Verification.** Automated: route returns 200, footer link present, file in
repo. Manual: legal content review.

## 3. No frontend secrets

**Requirement.** Nothing secret ever ships in a frontend bundle. Anything
prefixed `NEXT_PUBLIC_`, `VITE_`, or `REACT_APP_` is public by definition —
those values are inlined into client code. API keys, tokens, and credentials
live in server-side environment variables or a secret store and are only
used by server code (Route Handlers, API controllers, Workers). A committed
frontend secret is treated as compromised: rotate it, then delete it —
deletion alone is not remediation.

**Implementation.**

- Next.js: secrets in plain `process.env.*` read only from Route Handlers /
  Server Components; never add a secret to `NEXT_PUBLIC_*`.
- Angular: never put secrets in `environment*.ts` — those files are bundled.
  Call a backend endpoint instead.
- Vite/React: same rule for `import.meta.env.VITE_*`.
- Static/CF Pages: no secrets at all client-side; use a Pages Function /
  Worker for anything privileged.
- ASP.NET: secrets in user-secrets/Key Vault/env; never in `appsettings.json`
  shipped to the client or in `.cshtml`/JS served to the browser.

**Verification.** Automated: org secret-scan gate plus a build-artifact scan
of the emitted bundle for known secret patterns and for env-prefix leakage.
Manual: code review of any new `*_PUBLIC_*` variable.

## 4. Enforce HTTPS

**Requirement.** All traffic is HTTPS. Redirects to HTTPS happen at the edge
(Traefik/Cloudflare), but the app must still emit HSTS and must not hardcode
`http://` URLs for assets, API calls, canonical links, or sitemap entries.

**Implementation.**

- Traefik (compose): TLS via the standard labels; add HSTS via a middleware:

  ```yaml
  labels:
    - traefik.http.routers.myapp.rule=Host(`example.com`)
    - traefik.http.routers.myapp.tls=true
    - traefik.http.routers.myapp.tls.certresolver=letsencrypt
    - traefik.http.routers.myapp.middlewares=myapp-hsts
    - traefik.http.middlewares.myapp-hsts.headers.stsSeconds=31536000
    - traefik.http.middlewares.myapp-hsts.headers.stsIncludeSubdomains=true
  ```

- Cloudflare Pages/Workers: HTTPS is automatic; add HSTS via a `_headers`
  file:

  ```
  /*
    Strict-Transport-Security: max-age=31536000; includeSubDomains
  ```

- Next.js (self-hosted behind Traefik): `next.config.ts` headers:

  ```ts
  async headers() {
    return [{
      source: '/:path*',
      headers: [{ key: 'Strict-Transport-Security',
                  value: 'max-age=31536000; includeSubDomains' }],
    }];
  }
  ```

- ASP.NET: `app.UseHsts()` in production.
- All stacks: use protocol-relative or root-relative asset URLs; grep for
  `http://` in templates/config.

**Verification.** Automated: `http://` origin redirects to `https://`;
HSTS header present on the apex response; no `http://` literals in served
HTML/JS (excluding `xmlns` and schema URLs). Manual: none.

## 5. Cookie consent banner

**Requirement.** If the site sets non-essential cookies or uses analytics
that require consent (GA4, Meta pixel, etc.), a consent banner must gate
those scripts until the user opts in. **Exception:** a site that uses only
Cloudflare Web Analytics (cookieless) and sets no other non-essential
cookies does NOT need a consent banner — state this in the README compliance
table.

**Implementation.**

- Default: use Cloudflare Web Analytics only → no banner needed.
- If GA4 (or any consent-requiring tool) is used: load it only after
  consent, via Google Consent Mode v2 or a banner library (e.g.
  `vanilla-cookieconsent` works on all stacks):

  ```html
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('consent', 'default', { analytics_storage: 'denied' });
    // on accept: gtag('consent', 'update', { analytics_storage: 'granted' });
  </script>
  ```

**Verification.** Automated: inventory of cookies set on first paint (before
any interaction); if non-essential cookies exist, a consent UI element must
be present. Manual: banner blocks/allows correctly; rejection actually
prevents GA4 from loading.

## 6. Meta titles/descriptions

**Requirement.** Every public page has a unique, human-written `<title>`
(≤ 60 chars) and `<meta name="description">` (≤ 160 chars). SPAs must set
them per route, not once for the whole app.

**Implementation.**

- Next.js: per-page metadata export:

  ```ts
  export const metadata = { title: '…', description: '…' };
  ```

- Angular: `Title` and `Meta` services in each routed component
  (`this.title.setTitle(...)`, `this.meta.updateTag(...)`), or route data +
  a shell subscriber.
- Vite/React SPA: set `document.title` and the description tag in a route
  effect, or prerender with `vite-plugin-prerender` / react-helmet-async.
- Static: literal tags in each HTML file.
- ASP.NET: `ViewData["Title"]` + a description section in `_Layout.cshtml`.

**Verification.** Automated: crawl public pages; every page has non-empty,
non-duplicated title and description within length limits. Manual: copy
quality.

## 7. Social preview image (og:image / twitter card)

**Requirement.** Every public page carries Open Graph tags (`og:title`,
`og:description`, `og:image`, `og:url`) and a Twitter/X card
(`twitter:card` = `summary_large_image` when a large image exists). The
`og:image` must be an absolute HTTPS URL to a real image (≈1200×630) that
returns 200. Home/landing pages must have a branded image; interior pages
may fall back to the site default.

**Implementation.**

- Next.js: `openGraph` and `twitter` fields in the metadata export; set
  `metadataBase` in the root layout so relative image paths resolve.
- Angular: `Meta` service per route; ensure absolute image URLs (use an
  environment origin constant, not `http://localhost`).
- Vite/React SPA: static tags in `index.html` for the home page minimum;
  per-route updates via helmet or prerendering.
- Static: literal tags per page.
- ASP.NET: a meta section rendered in `_Layout.cshtml`.

**Verification.** Automated: fetch home + a sample of interior pages; all
four og tags present; `og:image` URL returns 200 with an image content type
and ≥ 600px width. Manual: paste the URL into a social preview validator
and eyeball the card.

## 8. Favicon

**Requirement.** Every site serves a favicon that renders in browser tabs —
at minimum `/favicon.ico` returning 200, plus a modern PNG/SVG and
`apple-touch-icon.png` linked from every page. The icon must be the product
or fleet brand, not the framework default (Next.js/Angular/React logos are
audit failures).

**Implementation.**

- Next.js: drop `icon.svg`/`icon.png` and `apple-icon.png` in `app/` —
  App Router serves them automatically.
- Angular: files in `public/` (or `src/assets` + `angular.json` assets) and
  `<link rel="icon" …>` in `index.html`.
- Vite/React: files in `public/`, links in `index.html`.
- Static/CF Pages: files at the site root.
- ASP.NET: files in `wwwroot`, links in `_Layout.cshtml`.

**Verification.** Automated: `/favicon.ico` and `/apple-touch-icon.png`
return 200; served icon bytes differ from known framework defaults. Manual:
visual check in a tab.

## 9. Sitemap and robots.txt

**Requirement.** Every public site serves `/robots.txt` and `/sitemap.xml`.
The sitemap lists all public canonical URLs with absolute HTTPS URLs.
**Indexing must not be blocked** except for explicitly non-public apps:
internal QA/tester/staging pages must send `noindex` (header or meta),
must be excluded from the sitemap, and may be disallowed in robots.txt.

**Implementation.**

Minimal `robots.txt`:

```
User-agent: *
Allow: /
Sitemap: https://example.com/sitemap.xml
```

Minimal `sitemap.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/</loc></url>
  <url><loc>https://example.com/pricing</loc></url>
</urlset>
```

- Next.js: `app/robots.ts` and `app/sitemap.ts` (MetadataRoute) generate
  both at build time.
- Angular: static files in `public/`, or generated in CI for large sites.
- Vite/React: static files in `public/`; for dynamic sites generate during
  the build from the route manifest.
- Static/CF Pages: literal files at the root.
- ASP.NET: static files in `wwwroot`, or an endpoint for dynamic catalogs.
- Non-public apps: add `X-Robots-Tag: noindex` via Traefik middleware or
  `_headers`, plus `Disallow: /` in robots.txt.

**Verification.** Automated: both files return 200; sitemap parses and every
URL returns 200 and is not noindexed; production robots.txt does not
`Disallow: /`. Manual: staging/QA instances correctly noindexed.

## 10. Image alt text

**Requirement.** Every `<img>` conveying content has meaningful `alt` text;
purely decorative images have `alt=""`. Icons-only buttons use
`aria-label`. Alt text describes the image's purpose, not "image" or the
filename.

**Implementation.**

- All stacks: lint catches most misses — `eslint-plugin-jsx-a11y`
  (`img-redundant-alt`, `alt-text`) for Next.js/Vite/React;
  `@angular-eslint/template/accessibility-alt-text` for Angular; plain-HTML
  sites are covered by the audit crawler.
- Next.js: always pass `alt` to `<Image>` (it is a required prop).

**Verification.** Automated: crawl served HTML; every `<img>` has an `alt`
attribute (empty allowed only when decorative). Manual: sample alt text for
meaningfulness.

## 11. Image compression

**Requirement.** Raster images are served compressed and sized for their
display dimensions: WebP/AVIF preferred, no multi-MB assets, no 4000px
source for a 400px slot. Large hero images ≤ ~200 KB after compression.

**Implementation.**

- Next.js: use `<Image>` from `next/image` — automatic WebP/AVIF, resizing,
  lazy loading.
- Angular: use `NgOptimizedImage` (`provideImgixLoader`-style loaders or the
  built-in defaults) where possible; otherwise compress at build time with
  `sharp`/`imagemin` in the asset pipeline.
- Vite/React: `vite-imagetools` or a pre-commit/CI `sharp` pass; serve from
  `public/` pre-compressed.
- Static/CF Pages: compress before commit (sharp CLI: `sharp -i in.jpg -o
  out.webp resize 1600`); consider Cloudflare Images/Polish for large
  catalogs.
- ASP.NET: compress at build/publish; serve via static files with cache
  headers.

**Verification.** Automated: fetch images referenced by crawled pages; flag
any raster image > 500 KB, any image whose intrinsic width is > 2× its
rendered width, and non-WebP/AVIF above 100 KB. Manual: hero art quality.

## 12. Page load speed budget

**Requirement.** Lighthouse (mobile, simulated throttling): performance
score **≥ 90 for marketing/landing pages**, **≥ 75 for app pages**; LCP
< 2.5s on both. Budget regressions block release for marketing pages.

**Implementation.** Common to all stacks:

- Defer non-critical JS; code-split routes (default in Next.js and Angular
  lazy routes; use `React.lazy`/dynamic `import()` in Vite SPAs).
- Preload the LCP image; `font-display: swap`; self-host fonts.
- Keep third-party scripts off the critical path (`async`/`defer`).
- ASP.NET: enable response compression and output caching for public pages.

**Verification.** Automated: CI/audit runs Lighthouse CI against the
deployed URL with the budgets above as assertions; LCP read from field or
lab data. Manual: investigate anything the score can't explain (real-device
feel, interaction latency).

## 13. Color contrast (WCAG AA)

**Requirement.** WCAG 2.1 AA: contrast ratio ≥ 4.5:1 for body text, ≥ 3:1
for large text (≥ 24px or ≥ 18.66px bold) and UI component boundaries/focus
indicators. This must hold in **every fleet theme** (see
`docs/THEMING_STANDARD.md`).

**Implementation.**

- Use the fleet semantic tokens (`--seolith-*`) rather than hard-coded
  colors; fix contrast at the token level so all consumers inherit it.
- Check pairs in CI: Storybook + axe, or `pa11y`/`axe-core` against built
  pages.
- All stacks: run `axe` (via Playwright/pa11y) on key routes in CI.

**Verification.** Automated: axe color-contrast rule on crawled pages in
default theme. Manual: sweep of the other fleet themes and of states
(hover/focus/disabled) that crawlers miss.

## 14. Mobile responsiveness

**Requirement.** Every page is fully usable at 360px width with no
horizontal scroll, no overlapping content, and tap targets ≥ 44×44px. The
viewport meta tag is present on every page. Layout adapts across mobile,
tablet, and desktop breakpoints.

**Implementation.**

Viewport meta (all stacks):

```html
<meta name="viewport" content="width=device-width, initial-scale=1" />
```

- Next.js App Router: emitted automatically; verify it isn't overridden.
- Angular: in `src/index.html`. Vite/React: in `index.html`. Static: each
  page. ASP.NET: `_Layout.cshtml` `<head>`.
- CSS: mobile-first flex/grid, `min()`/`clamp()` for fluid type, avoid
  fixed pixel widths on containers.

**Verification.** Automated: viewport meta present; render at 360×800 and
assert no horizontal scrollbar (Playwright). Manual: real-device pass on
the primary user flows.

## 15. Custom 404 page

**Requirement.** Unknown URLs render a branded 404 page (fleet look, link
home and to key sections) while returning an actual HTTP **404** status —
not a 200 soft-404. SPAs serve the app shell for unknown deep links but the
rendered route must show the not-found view; the apex fallback should still
404 for obviously bogus asset paths.

**Implementation.**

- Next.js: `app/not-found.tsx`; returns 404 automatically.
- Angular: a wildcard route `**` to a `NotFoundComponent`; for prerendered/
  static hosting, configure the host's 404 document.
- Vite/React SPA: a catch-all route rendering the 404 view; on Cloudflare
  Pages, add a `404.html` for true 404s on direct asset misses.
- Static/CF Pages: commit a `404.html` at the root — Pages serves it with a
  404 status automatically.
- ASP.NET: `app.UseStatusCodePagesWithReExecute("/404")` plus a 404
  Razor page.

**Verification.** Automated: GET a random bogus path; expect status 404 and
branded body content (not the host default). Manual: page is helpful
(nav links, search/home path).

## 16. Broken link checking

**Requirement.** No broken internal or external links on public pages.
Checking is automated in CI with **lychee** (the estate standard); broken
links fail the build for marketing sites and warn for app repos with
frequently changing external references.

**Implementation.**

CI step (any stack, run against the built/deployed site):

```yaml
- uses: lycheeverse/lychee-action@v2
  with:
    args: --base https://example.com --exclude-mail --retry 3
          'https://example.com'
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

For repo-content checks (README/docs), run lychee against `**/*.md`.
Exclude known-flaky hosts via a `.lycheeignore` in the repo.

**Verification.** Automated: the lychee CI job itself. Manual: quarterly
spot-check of excluded domains and redirect chains.

## 17. Form validation

**Requirement.** Every public form validates on both client and server.
Client-side validation gives immediate, field-level feedback (inline
messages, not alert boxes); server-side validation is authoritative and
returns actionable errors. Inputs are typed (`type="email"`, `required`,
`pattern`) and error messages are human-readable. Server never trusts
client validation.

**Implementation.**

- Next.js: client validation with the form library already in the repo
  (react-hook-form + zod recommended); re-validate with the same zod schema
  in the Route Handler.
- Angular: Reactive Forms with `Validators`; server re-validates in the API.
- Vite/React: react-hook-form/zod or native constraint validation +
  fetch-level error handling.
- Static/CF Pages: native HTML5 constraint validation client-side; a Pages
  Function validates on submit.
- ASP.NET: DataAnnotations on the model; tag-helper validation client-side,
  `ModelState` server-side.

**Verification.** Automated: submit invalid payloads directly to the form
endpoint and expect 4xx with structured errors (no 500s, no silent accepts);
check forms render inline error containers. Manual: UX of error states,
keyboard/screen-reader behavior.

## 18. Spam protection

**Requirement.** Every public form (contact, signup, comment, newsletter)
is protected with **Cloudflare Turnstile** — the estate default. Where
Turnstile cannot run (pure static hosts without a function endpoint,
embedded third-party forms), a honeypot field is the minimum fallback.
Unauthenticated endpoints that accept submissions must not be callable
without a valid token.

**Implementation.**

Client (any stack):

```html
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<div class="cf-turnstile" data-sitekey="<SITE_KEY>"></div>
```

Server-side verification (siteverify) from the form endpoint:

```ts
const res = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({ secret: process.env.TURNSTILE_SECRET!, response: token }),
});
const { success } = await res.json();
if (!success) return new Response('Invalid token', { status: 400 });
```

- Turnstile site key is public; the **secret stays server-side only** (see
  item 3).
- Honeypot fallback: a visually hidden input (e.g. `name="company_url"`)
  that real users leave empty; reject submissions where it is filled.
- ASP.NET: verify in the controller before model processing; Angular/Vite:
  verify in the backing API or Pages Function.

**Verification.** Automated: submit the form endpoint without a token and
expect rejection; detect the Turnstile script/container on form pages (or a
honeypot field where exempt). Manual: real submission passes; Turnstile
dashboard shows healthy solve rates.

## 19. Analytics setup

**Requirement.** Every public site records traffic with **Cloudflare Web
Analytics** — the estate default: free, cookieless, and (when used alone
with no other non-essential cookies) it does **not** require a cookie
consent banner. **GA4 is permitted only behind a consent banner** (item 5).
Analytics tokens/ids are public by nature but must be config values, not
scattered literals.

**Implementation.**

Cloudflare Web Analytics beacon (all stacks, in the layout/`index.html`
before `</body>`):

```html
<script defer src="https://static.cloudflareinsights.com/beacon.min.js"
        data-cf-beacon='{"token": "<TOKEN>"}'></script>
```

- Next.js: in `app/layout.tsx` via `<Script strategy="afterInteractive">`.
- Angular/Vite/static: in `index.html` / page footer partial.
- ASP.NET: in `_Layout.cshtml`.
- If the site is fronted by the Cloudflare zone, prefer automatic injection
  (no code change) and note it in the README.

**Verification.** Automated: beacon script present on every page (or zone
injection confirmed); if GA4 is detected, a consent mechanism must also be
detected. Manual: data flowing in the Cloudflare dashboard.

## 20. Single clear CTA (design review item)

**Requirement.** Every landing/marketing page has one primary call-to-action
that is visually dominant, above the fold on mobile and desktop, and
consistent with the page's goal (sign up, buy, contact — one, not three
competing primaries). Secondary actions are styled as secondary.

**Implementation.** This is a design/content item, not code: pick the single
conversion goal per page, style the primary button with the fleet accent
token, demote competing actions to links or ghost buttons. All stacks: it's
markup and CSS in the page component.

**Verification.** Not machine-checkable beyond heuristics. Automated: flag
pages with more than one primary-styled button above the fold. Manual
(design review): is the CTA obvious in 5 seconds, does it match the page
goal, does it survive each fleet theme.

---

## Compliance table (copy into each repo's README)

Paste this block into the repo README and keep it current:

```markdown
## Site Essentials Compliance

Audited against [seolith-dev-standards/docs/SITE_ESSENTIALS_STANDARD.md](https://github.com/seolith-llc/seolith-dev-standards/blob/main/docs/SITE_ESSENTIALS_STANDARD.md).

- [ ] 1. Privacy policy
- [ ] 2. Terms & conditions
- [ ] 3. No frontend secrets
- [ ] 4. Enforce HTTPS
- [ ] 5. Cookie consent banner (or N/A: Cloudflare Web Analytics only)
- [ ] 6. Meta titles/descriptions
- [ ] 7. Social preview image (og:image / twitter card)
- [ ] 8. Favicon
- [ ] 9. Sitemap and robots.txt
- [ ] 10. Image alt text
- [ ] 11. Image compression
- [ ] 12. Page load speed budget
- [ ] 13. Color contrast (WCAG AA)
- [ ] 14. Mobile responsiveness
- [ ] 15. Custom 404 page
- [ ] 16. Broken link checking
- [ ] 17. Form validation
- [ ] 18. Spam protection
- [ ] 19. Analytics setup
- [ ] 20. Single clear CTA
```

## Rollout

Audits run estate-wide from `seolith-ops-control` (`ops/site-essentials/`),
which crawls each deployed site and checks the automatable items above
against its repo. Each web repo in the org gets a tracking issue (and, where
fixes are mechanical, a PR) listing its gaps against the 20 items, plus the
README compliance table to adopt. Repos are expected to reach full
compliance in their next maintenance window; new repos must adopt this
standard before first public deploy.
