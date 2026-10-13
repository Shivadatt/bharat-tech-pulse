# Deployment - Cloudflare Pages (Bharat Tech Pulse, site slug `india_tech`)

Owner-facing runbook for hosting this Flutter Web app on Cloudflare Pages.
Everything below is either read out of this repository or explicitly labelled.
Nothing in this document has been executed against a live service: **no Pages
project, deployment, domain, DNS record or TLS setting exists yet for this site.**

---

## 0. Status board (as of this round)

| Item | State | Why |
|---|---|---|
| SPA fallback for deep links | **PASS - LOCAL VERIFIED (copy mechanism), NOT DEPLOYED** | `web/_redirects` (9 rules) was copied verbatim into `build/web/_redirects` by the build that landed during this round - verified by listing and by the deploy helper counting it. Nothing has been served by Cloudflare yet, so the runtime 200/301 behaviour is still unverified |
| Cache + security headers | **PASS - LOCAL VERIFIED (copy mechanism), NOT DEPLOYED** | same: `build/web/_headers` exists with 44 rule blocks. Header application by Pages is unverified until a preview deploy |
| Real production bundle | **RESOLVED DURING THIS ROUND (not by me)** | `build/web/main.dart.js` is now 3,442,832 B with `placeholder-project` 0 hits and `post_revisions` 2 / `analytics_events` 4 hits, i.e. Supabase-backed. The `tool/live_checks/.env` blocker was cleared by the tooling agent; I did not run the build |
| Stale mock bundle concern | **SUPERSEDED** | earlier in this round `build/web` was a mock artifact (12,927,991 B, 2 `placeholder-project` hits) - the deploy helper's bundle gate correctly refused it. It is now the live bundle and the same gate says PASS |
| Prerendered crawler HTML in `build/web/` | **PRESENT, NOT DEPLOYED** | 15 `build/web/article/<slug>/index.html` shells + 8 category directories (verified by listing) |
| GA4 / Search Console ownership | **NOT CONFIGURED** | inert until the bundle is built with `--dart-define=GA_MEASUREMENT_ID=...` / `...=GOOGLE_SITE_VERIFICATION=...`; `web/index.html:59` still holds an empty verification meta |
| Cloudflare Pages project | **NOT CONFIGURED** | no `wrangler.toml`/`wrangler.jsonc` in the repo (verified) and no dashboard access this round |
| Custom domain `bharattechpulse.in` | **BLOCKED - not registered** | prior audit: RDAP + DoH both return no delegation. A second intended domain was never found; none is assumed here |
| SSL/TLS mode | **NOT CONFIGURED** | cannot be chosen in a dashboard that has no zone yet; decision rule in section 6 |
| Deploy helper | **PASS - LOCAL VERIFIED (dry run only)** | `tool/deploy_cloudflare.ps1` parses clean on Windows PowerShell 5.1 and its credential/bundle gates were exercised locally; the `-Execute` path was never run |

Hard truth to keep in view: `web/index.html`, `web/robots.txt`, `web/sitemap.xml`
and `lib/app/config/site_config.dart` all hard-code `https://bharattechpulse.in`
(canonical tag, `og:url`, `og:image`, `twitter:image`, sitemap `<loc>` list,
`SiteConfig.domain`, `defaultOgImage`). Until that zone exists, every share preview
and canonical URL points at a domain nobody controls. Do not submit the sitemap to
Google until section 5 is done.

---

## 1. Prerequisites (all four must be true before a first deploy)

1. **Supabase publishable credentials on the build machine.**
   Fill the git-ignored `tool/live_checks/.env` from the committed template
   `tool/live_checks/.env.example` (already covered by
   `tool/live_checks/.gitignore:3`) with exactly:
   ```
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_ANON_KEY=<publishable/anon key>
   ```
   `tool/build_production.ps1:56-64` loads them through the existing
   `tool/live_checks/lib/config.js` loader (real env vars win over the file); it
   rejects placeholders and refuses a `service_role` key (`:94-97`). **Only the
   publishable/anon key may ever be used** - a Flutter Web bundle is public by
   definition.
2. **A Cloudflare account + Pages project + API token** with `Account / Cloudflare
   Pages: Edit` scope, and the 32-character account id. Both go in the shell
   environment only.
3. **Node + wrangler** available to the operator machine (`npx` is on PATH here -
   verified; `wrangler` itself is NOT installed - verified). The helper falls back
   to `npx --yes wrangler`, which downloads the CLI at run time.
4. **Domain registration** for the intended hostname (section 5). Not required for
   the first `*.pages.dev` deployment, so it can be parallelised with 1-3.

---

## 2. Build

Run the wrapper, never a bare `flutter build web`, for anything that leaves this
machine:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_production.ps1
```

That is the equivalent of (verbatim from `lib/app/config/environment_config.dart:26-31`):

```
fvm flutter build web --release \
  --dart-define=ENV=production \
  --dart-define=DATA_SOURCE=supabase \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-anon-key>
```

Notes that matter for hosting:

* **No `--base-href` is needed or wanted.** Pages serves the app at the zone root,
  and the built shell already resolves to `<base href="/">`
  (verified at `build/web/index.html:17`). An absolute base is what makes a deep
  link like `/article/foo` load `/main.dart.js` instead of `/article/main.dart.js`.
* The build **copies `web/_redirects` and `web/_headers` verbatim into
  `build/web/`**. That is the whole deployment mechanism for routing and caching:
  no Cloudflare dashboard rule, no Pages Function, no `_headers` generator.
* The wrapper then runs the prerenderer (`tool/build_production.ps1:171-189` ->
  `fvm dart run tool/generate_prerender.dart`) and **fails the build if it produced
  no article shells**. It writes `build/web/article/<slug>/index.html` plus one shell
  per category directory, each with a real `<title>`, description, canonical,
  OG/Twitter tags and JSON-LD. Those are *real files*, so Cloudflare Pages serves
  them before the SPA fallback: a non-JavaScript crawler gets correct per-article
  metadata instead of the generic home `<head>`. (`build/web/article/` holds 15 shells
  and the 8 category directories exist in the bundle that landed during this round -
  verified by listing.)
* GA4 is opt-in at build time: the wrapper appends
  `--dart-define=GA_MEASUREMENT_ID=...` / `--dart-define=GOOGLE_SITE_VERIFICATION=...`
  only when the operator environment provides them; otherwise the tag never loads.
* Do not run two Flutter toolchains at once, and build from the `subst` drive the
  script sets up (`tool/build_production.ps1:129-143`) - the repo path contains a
  space, which breaks Windows native asset steps.
* The wrapper fails the build if Supabase repositories get tree-shaken out
  (`:198-209`), which is the reason a mock bundle can reach production only by
  someone deliberately bypassing it.

---

## 3. Routing: `web/_redirects`

The app is a client-rendered SPA with **clean path URLs** - `lib/main.dart:77`
calls `usePathUrlStrategy()` before `GetMaterialApp` (no `#/` anywhere). Cloudflare
Pages has no file at `/article/<slug>`, so without a fallback every deep link and
every F5 on a deep link is a 404. The file is one fallback rule plus eight
normalisation redirects:

```
/ai /ai/ 301                (and the other 7 category routes)
/* /index.html 200          (SPA fallback)
```

* The 301s exist because the category routes are declared **with** a trailing
  slash (`lib/app/routes/app_routes.dart:5-12`, and `web/sitemap.xml` advertises
  `/ai/`, `/smartphones/`, ...) while `lib/main.dart`'s `_exactRoutes` set only
  contains the slashed form. A cold load of `/ai` therefore falls through to the
  home route with "Page Not Found" metadata - a soft-404/duplicate-content shape.
* `200` is an invisible rewrite, so the browser keeps the deep URL that GetX
  routing and the SEO service need.
* Routes that resolve through the fallback: `/article/<slug>`, `/author/<slug>`,
  `/search`, `/about`, `/contact`, `/editorial-policy`, `/privacy-policy`,
  `/terms`, `/disclaimer`, `/404` and the whole `/admin/*` tree
  (`lib/app/routes/app_pages.dart:56-334`).
* Interaction with the prerendered shells (section 2): `/article/<slug>` and the
  category paths become **real files** after a correct build, and Pages serves a real
  file before applying the `200` rewrite. The fallback is therefore the safety net,
  not the normal path, for those URLs - and it stays essential for `/admin/*`,
  `/search`, the static pages, and any article published later through the CMS whose
  shell has not been regenerated. Both paths are covered by the same `no-cache`
  header rule in `web/_headers`, so crawler-visible HTML is never served stale.
* There is **no `/category/<slug>` route in this app** - `app_routes.dart` has no
  such constant and `app_pages.dart` registers none. Categories are the eight
  slashed top-level routes. Rules for `/category/*` were deliberately not added,
  because rewrites into a route the app cannot render only create dead links.
* Unknown paths intentionally reach the shell: `lib/main.dart` detects an unknown
  cold-boot path, stamps `Page Not Found` metadata and renders `NotFoundView`,
  which is the designed 404 experience.
* Deliberately omitted: `/index.html -> / 301` canonicalisation (the fallback's own
  destination is `/index.html`; the SEO gain is small and a wrong precedence
  assumption would white-gate every deep link).

Rule order follows the documented Cloudflare behaviour that "the top-most redirect
is applied" for the same source path; the catch-all is last, always.

---

## 4. Caching and security headers: `web/_headers`

Cloudflare Pages' `_headers` semantics forced the file's shape (docs, quoted in the
file itself): a request matching several rules **inherits all of them**, and the
same header twice is **comma-joined**. So `Cache-Control` is set by exactly one rule
per path and the catch-all `/*` carries only the five security headers plus the
report-only CSP.

### Why nothing is marked `immutable` - what I actually inspected

I listed every file of `build/web/` (42 files in the bundle I first inspected, 49 in
the live bundle that replaced it mid-round) and read the emitted loader, rather than
trusting the usual "Flutter assets are hashed" folklore:

| Evidence | Finding |
|---|---|
| Full `build/web` file listing | **No filename carries a content hash.** `main.dart.js`, `flutter_bootstrap.js`, `flutter.js`, `flutter_service_worker.js`, `version.json`, `assets/AssetManifest.bin`, `assets/FontManifest.json`, `assets/NOTICES`, `assets/fonts/MaterialIcons-Regular.otf`, `canvaskit/canvaskit.wasm`, `icons/Icon-*.png` are all stable names |
| Same listing | **There are no `*.part.js` split chunks** in this bundle - nothing to hash there either |
| `build/web/flutter_bootstrap.js` | loads the entrypoint as the literal URL `main.dart.js` (`builds:[{... "mainJsPath":"main.dart.js"}]`, `entrypointUrl:c("main.dart.js")`) - no `?v=`, no fingerprint |
| `build/web/flutter_bootstrap.js` | CanvasKit base resolves through `engineRevision && !useLocalCanvasKit`, and this build's `buildConfig` has `engineRevision` with **no `useLocalCanvasKit` key**, so the emitted artifact points at `https://www.gstatic.com/flutter-canvaskit/<engineRevision>` even though ~26 MB of local `canvaskit/` is also bundled. Which one the browser actually fetches is **UNVERIFIED** (no browser this round) |
| `build/web/flutter_service_worker.js` | **the current bundle does not emit this file at all** (verified: absent from the 49-file listing), while `flutter_bootstrap.js` still calls `loadServiceWorker` with a `serviceWorkerVersion`. Consequences: there is no service-worker cache layer, so HTTP caching is the only layer; and because the missing URL is answered by the `/* /index.html 200` rewrite, the registration attempt receives HTML and fails on MIME type. The loader wraps that call in `.catch(console.warn)` (verified in the minified source), so it is a console warning, not a broken app - P3 cosmetic. `_headers` keeps a `no-immutable` rule for the path anyway so an older Flutter output that *does* emit the stub is still handled correctly |
| same listing, twice | I re-ran every one of these checks against the **fresh live bundle** after the tooling agent rebuilt, and the conclusions are unchanged: `mainJsPath":"main.dart.js"`, `<base href="/">`, 0 `*.part.js`, 0 files with hash-like names |

Conclusion: name stable + bytes changing = `immutable, max-age=31536000` would pin
the previous release's Dart code next to the new `index.html`. So:

| Path | Cache-Control | Reasoning |
|---|---|---|
| `/`, `/index.html`, `/article/*`, `/author/*`, `/admin`, `/admin/*`, `/search`, static pages, `/404`, the 8 category paths | `no-cache` | shell HTML must revalidate, so a browser refresh after a deploy picks up the new build instead of the old shell |
| `/main.dart.js`, `/flutter_bootstrap.js`, `/flutter.js`, `/flutter_service_worker.js`, `/version.json`, `/assets/*`, `/canvaskit/*` | `public, max-age=0, must-revalidate` | unhashed names, so revalidate. Cheap here: each Pages deployment is an immutable snapshot, so revalidation either 304s from the edge or returns the new deployment's bytes |
| `/robots.txt`, `/sitemap.xml` | `public, max-age=3600, must-revalidate` | crawler-visible files that get fixed by hand; one hour of staleness is the bound |
| `/favicon.png`, `/manifest.json`, `/og-default.jpg`, `/icons/*` | `public, max-age=86400, must-revalidate` | brand art; a day of staleness is harmless and bounded |
| everything else | platform default | `/*` carries no `Cache-Control` on purpose; the unknown-path responses are 404 shells and fall back to whatever Pages defaults to (**UNVERIFIED** - confirm with the curl checks in section 7) |

Security headers shipped on `/*`: `X-Content-Type-Options: nosniff`,
`X-Frame-Options: DENY` (no iframe anywhere in `lib/` or `web/` - verified),
`Referrer-Policy: strict-origin-when-cross-origin`, a `Permissions-Policy` that
disables camera/mic/geolocation/payment/usb/accelerometer/gyroscope/magnetometer
(the app has no such feature; media upload uses a file input,
`lib/core/platform/file_selector_web.dart`), and
`Strict-Transport-Security: max-age=15552000` **without** `includeSubDomains` -
because `lib/app/config/environment_config.dart:141` already hard-codes a second,
unprovisioned host `https://api.bharattechpulse.in` (verified: zero references
outside that declaration). Pinning subdomains before it has a certificate would
brick it for 180 days.

**COOP/COEP are deliberately absent**: `crossOriginIsolated` only buys
multi-threaded skwasm and this build's renderer is `canvaskit` + `dart2js`; and
`Cross-Origin-Opener-Policy: same-origin` would sever `window.opener` for any future
Supabase OAuth popup (today it is password sign-in only,
`lib/core/supabase/auth_service.dart:22`).

**CSP: no enforcing `Content-Security-Policy` ships.** A
`Content-Security-Policy-Report-Only` with a fully source-derived policy is active
instead, because a wrong directive does not degrade a feature here - it white-screens
the site (Flutter boots by evaluating JS and streaming WebAssembly), and I had
neither a browser nor the Flutter toolchain this round. Each allowed source traces
to code: `'wasm-unsafe-eval'` + `blob:` + `https://www.gstatic.com` (the emitted
`flutter_bootstrap.js`), `style-src 'unsafe-inline'` (the app writes inline style
attributes itself, `file_selector_web.dart:21`), `https://fonts.googleapis.com` +
`https://fonts.gstatic.com` (`google_fonts ^8.2.1` in `pubspec.yaml`, used by
`lib/app/theme/theme_text.dart`), `https://*.supabase.co` (PostgREST + public
Storage URLs, `lib/data/repositories/supabase_media_repository.dart:53`), and
`https://images.unsplash.com` (mock data only).

Analytics: `lib/core/analytics/analytics_service.dart` still beacons pageviews to
Supabase, but GA4 was added during this round - `lib/core/analytics/ga4_dom_web.dart`
appends an **inline** `dataLayer`/`gtag` script and then an external
`https://www.googletagmanager.com/gtag/js` script, and GA4 beacons go to
`*.google-analytics.com` / `*.analytics.google.com`. That is why the report-only
policy above lists those three hosts and, regretfully, `script-src 'unsafe-inline'`:
the loader emits no nonce or hash, so an exact `'unsafe-inline'`-free policy cannot
describe this app as it stands. Removing `'unsafe-inline'` from `script-src` is an
app-side change (emit a nonce from `web/index.html`, or load gtag with a
`src`-only bootstrap), not something the hosting config can fix. GA4 is inert unless
the bundle is built with `--dart-define=GA_MEASUREMENT_ID=G-XXXXXXXXXX`
(`analytics_service.dart:23` defaults to `''` and `Ga4Dom.init` returns early), so on
a GA-less build none of these origins is contacted at all. `web/index.html` also now
carries an inline `<script type="application/ld+json">` block and a
`<meta name="google-site-verification">` placeholder (`:59`); the `ld+json` type is a
data block, which `script-src` neither executes nor blocks.

The CSP promotion procedure is step 6 of section 7. The header file has 44 rule
blocks (documented ceiling 100). Among them are eight `/<category>/index.html` rules
carrying the same `no-cache`: the prerenderer writes `build/web/ai/index.html` and
friends, and a request for `/ai/` may be header-matched as the request path *or* as
the resolved asset path, so both spellings are covered. Their values are identical, so
even if Cloudflare joined them the result is `no-cache, no-cache` - semantically
unchanged. No rule in the file can downgrade freshness, only preserve it.

---

## 5. Publishing

Preferred mode is **Direct Upload via wrangler**, built on the operator machine -
not git-integrated Pages builds. Reason: `SUPABASE_URL`/`SUPABASE_ANON_KEY` are
compile-time `--dart-define` inputs, Cloudflare's build image has no Flutter/fvm,
and this repo's Windows build needs the `subst` workaround.

```powershell
# 1. Inspect the plan, the gates and the expected dashboard settings (no build,
#    no upload, no network):
powershell -NoProfile -ExecutionPolicy Bypass -File tool\deploy_cloudflare.ps1 -ProjectName bharat-tech-pulse

# 2. Only once the gates say PASS:
$env:CLOUDFLARE_API_TOKEN  = '<paste, never store in a file>'
$env:CLOUDFLARE_ACCOUNT_ID = '<account id>'
powershell -NoProfile -ExecutionPolicy Bypass -File tool\deploy_cloudflare.ps1 -ProjectName bharat-tech-pulse -Execute
```

`tool/deploy_cloudflare.ps1` refuses without the token **and** the account id
(exit 1, verified locally), refuses a mock/placeholder bundle (exit 3, verified -
the bundle on disk right now fails that gate), never prints a secret (lengths
only), never puts the token in a command-line argument (wrangler reads it from the
environment), and runs `tool/build_production.ps1` before
`npx --yes wrangler pages deploy build/web --project-name=<project> --branch=main
--commit-dirty=true`. Add `-Branch <name>` for a preview deployment and `-SkipBuild`
to re-publish a bundle that already passed the gate.

### Exact Cloudflare Pages settings the owner must set (dashboard)

| Setting | Value |
|---|---|
| Project name | `bharat-tech-pulse` (matches the GitHub repo `Shivadatt/bharat-tech-pulse`, verified via `git remote -v`) or the owner's equivalent; it must equal `-ProjectName` |
| Source / build integration | **None / Direct Upload** (wrangler). If git integration is enabled anyway: Root directory = repository root, Build output directory = `build/web`, Build command = unusable without a Flutter image - keep this OFF |
| Production branch | `main` (verified: local default branch is `main` and `origin/main` exists) |
| Environment variables (dashboard) | **none required, none recommended** - see section 6 |
| Custom domains | `bharattechpulse.in` + `www.bharattechpulse.in` once the domain is registered (section 7) |
| "Encrypt my project's files with a password" / secret files | leave OFF - no runtime secret file exists, and everything in a Web bundle is public anyway |
| Assets | do NOT add a Pages cache rule that overrides the `_headers` values; if a Cache Rule is ever added, it must reproduce the no-`immutable` policy of section 4 |

Deployment URLs (doc-derived, unverified): production
`https://<project>.pages.dev`, preview `https://<deployment-hash>.<project>.pages.dev`.

---

## 6. Environment variables vs `--dart-define` (secret policy)

* **Never** put `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, a service key, a
  database password or any admin token into Pages environment variables - build-time
  or runtime. Pages build logs print substituted values, and build-time variables are
  readable by anything running in the build.
* **Never** add a Pages *runtime* variable expecting the app to read it: a deployed
  Flutter Web bundle is static files; there is no server to read `process.env`. The
  variables below are **compile-time only**, baked in by `--dart-define`:

  | Key | Where it enters | Public? |
  |---|---|---|
  | `ENV=production` | `environment_config.dart:33` | yes, and it is what activates the no-mock guard |
  | `DATA_SOURCE=supabase` | `:51` | yes |
  | `SUPABASE_URL` | `:40` | yes - it is the project host |
  | `SUPABASE_ANON_KEY` | `:45` | yes - publishable key only |
  | `GA_MEASUREMENT_ID` | `lib/core/analytics/analytics_service.dart:23` | yes; a GA4 id is public but is not a secret and still does not belong in a committed file. Absent => GA4 never loads |
  | `GOOGLE_SITE_VERIFICATION` | `lib/core/seo/seo_service.dart:15` | yes; needed to prove Search Console ownership. Absent => the `google-site-verification` meta stays empty and the site is unclaimed |
  | `DATA_SOURCE`/`ENV` omitted | defaults to `mock`/`development` | a release build with these defaults is refused by the startup guard (`:119-138`) |

* On the operator machine, `SUPABASE_URL` / `SUPABASE_ANON_KEY` live in the real
  environment or in `tool/live_checks/.env`, which is git-ignored twice over
  (`.gitignore` `# Environment / secrets` block and
  `tool/live_checks/.gitignore:3`). Keep it that way; nothing in this repo may
  contain a key or a ref-derived credential.
* A `service_role`/secret key passed anywhere near these scripts is rejected by
  `tool/build_production.ps1:94-97` and by the deploy helper's token sanity check.

---

## 7. Post-deploy verification (must be done by hand - I had no network or browser)

Against the real deployment URL, with the bundle rebuilt so `_redirects`/`_headers`
are inside it:

```bash
curl -sSI https://<url>/                       # 200 text/html,  Cache-Control: no-cache
curl -sSI https://<url>/article/<real-slug>    # 200 text/html,  no-cache  <- deep link works
curl -sS  https://<url>/article/<real-slug> | grep -o "<title>[^<]*"
                                               # must name THAT article, not the home page -> proves the
                                               # prerendered shell is being served before the SPA fallback
curl -sSI https://<url>/ai/                    # 200 text/html, no-cache (prerendered category shell)
curl -sSI https://<url>/admin                  # 200 text/html   (login via client route)
curl -sSI https://<url>/sitemap.xml            # 200 application/xml - NOT the index.html shell
curl -sSI https://<url>/robots.txt             # 200 text/plain
curl -sSI https://<url>/og-default.jpg         # 200 image/jpeg
curl -sSI https://<url>/ai                     # 301, Location: /ai/
curl -sSI https://<url>/main.dart.js           # 200; max-age=0, must-revalidate; NO immutable
curl -sSI https://<url>/definitely-not-a-page  # 200 shell + in-app "Page Not Found"
```

Then in a browser, on a **deep link** (not the root):
1. Load `/article/<slug>` in a fresh tab, then press F5 - it must render the
   article, not 404. (This is the `_redirects` fallback + `<base href="/">` pair.)
2. Confirm the app deploys cleanly twice: after a new upload, a refresh on an open
   deep link must show the new build (`no-cache` shell + revalidated
   `main.dart.js`).
3. DevTools > Network: `main.dart.js`, `flutter_bootstrap.js`, `assets/*` are
   200/304 with the Cache-Control above; confirm which CanvasKit host was requested
   (`www.gstatic.com` vs local `canvaskit/`) - that answers the UNVERIFIED item in
   section 4.
4. `manifest.json` installs as a PWA (`web/manifest.json`, `start_url: "/"`); the
   service worker should NOT persist (Flutter's emitted SW stub unregisters itself).
5. Confirm the admin login still works against live Supabase and that
   `/admin` stays out of the index (robots.txt `Disallow: /admin`, verified).
6. **CSP promotion**: read the console for `[Report Only] Refused ...` violations
   across a category page, an article, `/admin/login` and a refreshed deep link.
   Widen only the named directive (never add `script-src 'unsafe-inline'` as a
   shortcut). When clean, rename the header to `Content-Security-Policy`, redeploy,
   re-run 1-5.

**Rollback**: Pages keeps every deployment; roll back from
`Pages > <project> > Deployments > ... > Rollback`, or re-upload an older bundle
with `-SkipBuild`. Since artifact names are unhashed, rollback is only consistent as
a whole-directory upload - never mix files from two builds.

---

## 8. Custom domain procedure - and why it is blocked

`https://bharattechpulse.in` is **not registered** (prior audit: RDAP and DNS-over-HTTPS
both report no delegation), so no hostname, DNS, certificate or deploy target can be
completed today. There is no second intended domain in this repository, and none is
assumed here. Once the owner registers the domain:

1. Register at any registrar; set nameservers to a Cloudflare zone on the account
   that will host Pages.
2. In Cloudflare, add the site `bharattechpulse.in` (proxied/orange-cloud apex).
3. Pages > `<project>` > Custom domains > **Set up a custom domain** > add
   `bharattechpulse.in`. Cloudflare creates the apex `CNAME` (flattened) and
   provisions the certificate itself - the dashboard drives this; nothing in this
   repo does.
4. Add `www.bharattechpulse.in` the same way, or as a Redirect Rule to the apex.
5. Only after the certificate is issued and both hostnames resolve: re-check the
   hard-coded absolute URLs. `web/index.html:27,34,35,42` (canonical, `og:url`,
   `og:image`, `twitter:image`), `web/robots.txt` (Sitemap line), `web/sitemap.xml`
   (all 30 `<loc>` entries) and `lib/app/config/site_config.dart` `domain` all
   already say `https://bharattechpulse.in`, so they become correct automatically -
   but they are wrong until then, which is why a `*.pages.dev` deployment should not
   be submitted to search engines as canonical.
6. Keep `https://bharattechpulse.in/sitemap.xml` reachable (it is a real file in
   `build/web/`, and the fallback rule must not shadow it - verify step in section 7).
7. Consider `includeSubDomains`/`preload` on HSTS only when every planned
   subdomain - including the unused `api.bharattechpulse.in` - is HTTPS.

---

## 9. SSL/TLS mode decision

For the zone that will hold the domain (not yet creatable - no zone exists):

| Mode | What it means | Verdict for this site |
|---|---|---|
| **Flexible** | browser->Cloudflare HTTPS, Cloudflare->origin plain HTTP | **Do not use.** Combined with the `Strict-Transport-Security` header shipped in `web/_headers`, it produces a redirect loop, and it also allows mixed content. Also `SUPABASE_URL` is validated as `https://` only (`tool/build_production.ps1:86-88`, `environment_config.dart:100`), so a plain-HTTP leg buys nothing |
| **Full** | Cloudflare->origin HTTPS, certificate not validated | Acceptable transitional setting only |
| **Full (strict)** | Cloudflare->origin HTTPS with a validated certificate | **Target setting.** For a Pages custom domain the "origin" is Cloudflare's own edge and Universal SSL is what is issued, so strict validation is the normal, correct choice. Whether the Pages-managed hostname even exposes an SSL-mode toggle is **UNVERIFIED** (I could not inspect the dashboard with no browser); if the zone offers it, pick Full (strict) before enabling HSTS-backed behaviour |

Order of operations that matters: register domain -> zone on Cloudflare -> TLS mode
Full (strict) -> Pages custom domain -> certificate issued -> then (optionally) raise
HSTS to `max-age=31536000` with `includeSubDomains; preload`. The header file's
current 180-day value is a deliberate, reversible midpoint.

---

## 10. Known hosting gaps that are NOT configured (do not assume these work)

* **Prerendered metadata is seed-driven, not live-driven.**
  `tool/generate_prerender.dart` parses `supabase/migrations/006_seed_data.sql`
  ("NO network, NO database", per its own header) and emits shells for
  `published` posts only. Consequences to keep honest: anything an editor changes
  through the CMS after a build is not reflected in the crawler-visible HTML until a
  new build+prerender+upload; the shells cover `/article/<slug>` and the eight
  category paths only, so a `/author/<slug>` deep link still reaches a non-JS crawler
  as the generic shell (`_redirects` fallback + runtime `SeoDom`); and the prerendered
  canonical URLs are built from `SiteConfig.domain`, i.e. the unregistered host.
  `_redirects` fixes *availability* of deep links; this bullet is about *metadata*
  quality for crawlers that do not run JS.
* **`web/sitemap.xml` is hand-maintained with no generator.** Its 30 `<loc>` entries
  are `/`, the 8 categories, the 6 static pages and 15 articles. Counting the status
  literals in the seed gives 22 post rows - 15 `published`, 4 `draft`, 3 `scheduled` -
  so sitemap coverage matches the published set exactly, and the prerenderer produced
  exactly those same 15 shells (verified by listing `build/web/article`). The residual
  risks are maintenance, not coverage: a post published later through the CMS appears
  in neither the sitemap nor the prerender set until someone regenerates both.
  `supabase/migrations/008_repair_image_url_prefix.sql:6` quotes "24 posts", which does
  not reconcile with the 22 rows I counted - UNVERIFIED discrepancy, worth one query
  against the live database.
* **`/article/*` slugs in the sitemap are the mock-era list** - re-verify against
  live Supabase after the real build.
* **CSP is report-only** (section 4). No `report-to`/`report-uri` endpoint exists.
* **No `functions/` directory** (verified), so no Pages Functions and no edge
  rewrites beyond `_redirects`.
* **`build/` is gitignored** (`.gitignore` `/build/`), so the ~41 MB artifact on disk
  is not a deliverable anyone else can reproduce without section 1's prerequisites.
* **Nothing about `*.pages.dev` currently exists for this project.** This document
  describes the configuration to apply; none of it has been applied.

---

## 11. Owner action list, in order

1. Create `tool/live_checks/.env` with `SUPABASE_URL` + `SUPABASE_ANON_KEY`
   (publishable key only). *(unblocks the real build - P0)*
2. Optionally add the analytics/ownership ids to the same environment
   (`GA_MEASUREMENT_ID`, `GOOGLE_SITE_VERIFICATION`) if the owner wants GA4 and Search
   Console on the first deploy; both are inert if absent. *(P1)*
3. `powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_production.ps1`
   and confirm it prints the prerendered article-shell count (non-zero) and ends with
   `OK: Supabase-backed production bundle written`. This is the step that also copies
   `web/_redirects` and `web/_headers` into `build/web/`.
   *(P0 - a teammate owns the Flutter toolchain this round; do not run two at once)*
4. Run `tool\deploy_cloudflare.ps1 -ProjectName <project>` with **no** `-Execute`
   and read the gates: `_redirects`/`_headers` must show `present` and
   `article shells` must be non-zero (both are impossible until step 3 rebuilt the
   bundle - right now the helper correctly reports 4 problems for exactly that reason).
   *(P0)*
5. Create the Cloudflare Pages project (Direct Upload), set the production branch to
   `main`, create a Pages-Edit-scoped API token, export token + account id, then run
   the helper with `-Execute`. *(P0)*
6. Work through section 7's curl + browser checks, including the prerendered
   `<title>` check, the CanvasKit host question, and the CSP report-only console audit.
   *(P1)*
7. Register `bharattechpulse.in`, then section 8 + section 9. *(P0 for any public
   launch; it is the hard blocker today)*
8. Plan a rebuild cadence so CMS-published posts reach both `web/sitemap.xml` and the
   prerendered shells - neither is generated automatically today (section 10). *(P2)*
9. Only after the domain + Full (strict) + certificate are confirmed: consider
   `includeSubDomains; preload` on HSTS and promoting the CSP to enforcing - and remove
   `script-src 'unsafe-inline'` first, which needs the nonce change described in
   section 4. *(P3)*
