# Security, Credential, Privacy, Asset and Cost Audit — Bharat Tech Pulse

**Agent:** security-cost (five-agent final release audit)
**Scope:** `D:\personal blog websites\india_tech_web`
**Method:** local, read-only inspection (grep / git / filesystem measurement). No builds, no
`flutter`/`fvm` invocation, no git mutations, no network calls, no price browsing.
**Access I do not have:** a browser, the live Supabase project, the Cloudflare account, a DNS
registrar, or any billing page. Anything requiring those is tagged `BLOCKED` or `UNVERIFIED`,
never `PASS — LIVE VERIFIED`. That tag belongs to the `auth-live` teammate only.

---

## 0. Headline

**This product is not deployable today, and no credential has ever been leaked — those are two
different facts and only the first is a blocker.**

**One caution on all of the above: the working tree — including `build/web` — moved repeatedly
during this audit.** Between my first listing and my last, a teammate added `web/_headers`,
`web/_redirects`, `docs/DEPLOYMENT.md`, `tool/deploy_cloudflare.ps1`, `tool/generate_prerender.dart`,
`tool/live_checks/.env.example`, `supabase/operator/010_bootstrap_first_admin.sql` and the GA4
files, and **`build/web` was rebuilt three times while I watched it** (the 12,927,991 B debug mock
artifact at `mtime 11:26` was deleted at 12:04 and replaced by a 3,442,939 B release Supabase-wired
bundle, which was itself deleted at 12:20 and rebuilt at 12:21 as 3,443,121 B). §6.7 records every
snapshot with its own timestamp so no number is quoted without its provenance, and nothing below is
asserted from a stale snapshot. **Consequence for §6 as a whole: there is no stable shipping
artifact to audit yet**, so the bundle findings are `PASS — LOCAL VERIFIED` *per snapshot* and
`UNVERIFIED` for whatever actually gets deployed.

| | |
| :--- | :--- |
| Secret leakage | **CLEAN.** Zero real credentials in the repo, in git history-tracked files, or in `build/web`. No `service_role` key exists anywhere. |
| Deployability | **BLOCKED (P0)** — but the reason changed mid-audit and is narrower than it looked. The build pipeline **does** now produce a real release, Supabase-wired bundle (§6.7: mock fixtures tree-shaken, `post_revisions`/`analytics_events` present). What is missing is a **real config**: `tool/live_checks/.env` is still absent, and the bundles built so far were dry-runs against a deliberately fake host (`https://zzz-not-live.supabase.co`), so every API call would fail in the browser. Neither `build_production.ps1` nor the `deploy_cloudflare.ps1` bundle gate can detect that (§1.5, finding 32) — a dummy-config bundle passes every check and *looks* releasable. Also still absent: the registered domain, the first admin (`auth.users = 0`), and any live Cloudflare Pages state. |
| Edge routing + cache policy | **NOW PRESENT — locally verified, not live-verified.** `web/_headers` (36 rules) and `web/_redirects` (9 rules) were authored mid-audit and are well-reasoned; they resolve what was a P2 gap. See §6.5 and §12. |
| Cost | **~US$300/yr + 2 domain renewals (domains UNKNOWN).** The binding constraint is Supabase *egress*, not storage or database size — and it is self-inflicted by serving images from Supabase Storage instead of Cloudflare. |

---

## 1. Credential and secret hygiene — PASS — LOCAL VERIFIED

### 1.1 What was searched

Whole repo (excluding `build/`, `.dart_tool/`, `.fvm/` for the source sweep, then `build/web`
separately) for: `service_role`, `service-key`/`servicekey`, `eyJ`-prefixed JWTs, `secret`,
`password`, `token`, `supabaseurl`/`SUPABASE_URL`, anon-key-shaped strings, PEM blocks, `.env`
files, and high-entropy (35+ char base64url) runs.

### 1.2 Every hit, with verdict (values masked)

| Location | Match | Verdict |
| :--- | :--- | :--- |
| `lib/app/config/environment_config.dart:24,106` | `service_role` in prose/comment + a user-facing error string | **FALSE POSITIVE** — warning text, no key material |
| `README.md:265`, `supabase/README.md:126`, `tool/build_production.ps1:14,94,111`, `tool/live_checks/lib/config.js:8,186,215` | `service_role` | **FALSE POSITIVE** — the *policy* that forbids it |
| `supabase/migrations/002:46,343`, `003:124,202`, `004:5,13`, `005:88,112` | `service_role` | **PUBLIC CONFIG** — Postgres role *names* in `GRANT` statements. A role name is not a key. |
| `supabase/functions/generate-sitemap/index.ts:19`, `scheduled-publishing/index.ts:16` | `Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")` | **FALSE POSITIVE / CORRECT** — reads the server-side secret at runtime; nothing hardcoded. Line 2 of both files states secrets come only from Supabase env vars. |
| `tool/live_checks/selftest_mock.js:505` | `eyJ…`-prefixed strings (`eyJhbGciOiJIUzI1NiJ9`, `eyJyb2xlIjoiYW5vbiJ9`) | **FALSE POSITIVE** — a mock self-test fixture: an unsecured `alg:none`-style HS256 header and a decoded `{"role":"anon"}` claim. No signature, no privileges, not accepted by any real server. |
| `lib/**` (`auth_service.dart`, `admin_auth_*`) | `password` | **FALSE POSITIVE** — form field names and the `signInWithPassword` API call; no stored value |
| `supabase/migrations/006_seed_data.sql` (many lines), `lib/data/services/mock_data_source.dart` | `password`, `secret`, `token` | **FALSE POSITIVE** — inside published editorial article prose (passkeys/scam-safety guides) |
| `lib/app/config/environment_config.dart:42,47` | `https://placeholder-project.supabase.co`, `placeholder-anon-key-public-only` | **PUBLIC CONFIG / PLACEHOLDER** — deliberately inert defaults; `supabaseConfigured` (line 57-59) rejects any value containing `placeholder` |
| `supabase/config.toml:2`, `supabase/README.md:4,35,37,141`, `supabase/migrations/006,007,008`, `tool/live_checks/run_all.js:58`, `test/production_data_source_test.dart:19`, `README.md:293` | the project ref `ylzwuwfhlqomjqcdrpxk` | **PUBLIC CONFIG** — see §1.3 |
| `.dart_tool/flutter_build/*/app.dill` | `BEGIN PRIVATE KEY`, `BEGIN RSA/EC PRIVATE KEY`, `service.key` | **FALSE POSITIVE** — see §1.4 |

### 1.3 Is the project ref / anon key treated as public client config? — PASS — LOCAL VERIFIED

**Yes, unambiguously.** The ref is *committed to git* in `supabase/README.md:4` and embedded in
the seed migrations, which is only defensible if it is public. It enters the app exclusively
through a compile-time slot, never a source literal:

- `lib/app/config/environment_config.dart:40-48` — `String.fromEnvironment('SUPABASE_URL'…)` and
  `SUPABASE_ANON_KEY`, both with placeholder defaults.
- `lib/core/supabase/supabase_service.dart:19-27` — the anon value is passed as
  `publishableKey:` (the supabase_flutter 2.18 rename of `anonKey`), with `autoRefreshToken: true`.
- `lib/app/config/site_config.dart:29-34` — a comment makes the policy explicit: the ref "only
  ever enters the build via `--dart-define`".
- `README.md:263-266` — the anon/publishable key "is public by design: a Flutter Web bundle is
  readable by every visitor."

`lib/` contains **zero** occurrences of the ref (verified by `grep -rl`), which is the project's
own invariant, and it holds.

**One consequence worth stating plainly:** the ref *will* appear in the deployed HTML, because
seeded image URLs are absolute `…ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/…`
and the new prerender shells bake them in — measured: `build/web/article/choose-right-ai-tool-honest-framework/index.html`
contains 3 occurrences. That is **PUBLIC CONFIG, not a leak** (the same URL ships in every
production bundle anyway), but it means README §9's `ylzwuwfhlqomjqcdrpxk → 0` marker is only a
statement about `main.dart.js`, not about the artifact. **P3 documentation precision.**

### 1.4 Does any service-role key exist in the repo or build output? — NO (PASS — LOCAL VERIFIED)

Decisive evidence:

1. `tool/live_checks/.env` **does not exist**. The only `*.env*` files anywhere are
   `ios/Flutter/ephemeral/flutter_native_integration.env` and the macOS twin — generated Flutter
   build files containing no credentials.
2. `build/web/main.dart.js` — **0** matches for `eyJ[A-Za-z0-9_-]{6,}` (no JWT of any kind),
   **0** matches for the project ref, **0** `.supabase.co` URLs, **0** PEM markers.
   The single `service_role` occurrence is the literal prose of an error message.
3. All 15 largest-entropy runs in the bundle are dart2js mangled identifiers
   (`GetPage…`, `_Modified…`, `GoogleFonts…`, `MaterialIcons…`) — **FALSE POSITIVES**.
4. The `app.dill` PEM hits are a **regex artifact and a compiler artifact**: `service.key` matched
   through an unescaped `.` in my own pattern (confirmed — `canvaskit.wasm` scores 0 on each
   literal alternative), and `BEGIN PRIVATE KEY` strings are PEM-boundary constants compiled in
   from a transitive dependency. They exist only in `.dart_tool/` (gitignored, never shipped) and
   are tree-shaken out of `main.dart.js` (0 matches).

**Verdict: no private key, no service-role key, no database password, no Cloudflare token exists
in this working tree or in git-tracked content.** Nothing needs rotation.

### 1.5 Guard quality (informational, positive)

The tooling is better than average:

- `tool/build_production.ps1:78-96` prints `SUPABASE_URL` in full (public) and the key only as
  `present (length N, source …)`; refuses to build on placeholder values and refuses outright if
  the value matches `service_role`.
- `tool/live_checks/lib/config.js:144-166` maintains a JWT regex and redacts every credential-like
  substring to `sha256:<first8>` fingerprints; `:211-217` scrubs credential-named env vars from
  output even if they were never read.
- `tool/deploy_cloudflare.ps1:87,123-124` — "Presence only — a credential value is never echoed,
  only its length"; `:130` explicitly refuses a value that is a `eyJ…` JWT containing
  `service_role` (i.e. a mis-pasted Supabase secret in the Cloudflare token slot).

**Gap in those guards (P2):** the Supabase-side check is `--dart-define` value `-match 'service_role'`
(`build_production.ps1:94`). That catches a *legacy anon/service JWT* (whose payload carries
`"role":"service_role"`) but **not** a modern `sb_secret_…` key, which is opaque and contains no
such substring. `grep` confirms `sb_secret` appears nowhere in the repo as a guard, only
`sb_publishable` in prose (`README.md:263`) and a test fixture
(`test/production_data_source_test.dart:20`). A copy-paste of the wrong dashboard field would
therefore be bundled silently. Recommend adding a reject on the `sb_secret_` prefix alongside the
existing check. (Suggestion only — I changed nothing.)

---

## 2. `.gitignore` and tracked-file verification — PASS — LOCAL VERIFIED (with a P2 gap)

`git check-ignore -v` evidence (each path resolves to a real, specific rule):

| Path tested | Matching rule |
| :--- | :--- |
| `tool/live_checks/.env` | `tool/live_checks/.gitignore:5:*.env` |
| `.seed_media/` | `.gitignore:52:.seed_media/` |
| `build/` | `.gitignore:31:/build/` |
| `.env` | `.gitignore:34:.env` |
| `.env.local` | `.gitignore:35:.env.*` |
| `supabase/.env` | `.gitignore:34:.env` |
| **`tool/live_checks/.env.example`** (added mid-audit) | `tool/live_checks/.gitignore:15:!.env.example` — correctly **re-included** so the template is trackable while `.env` stays ignored |

`tool/live_checks/.gitignore` is tighter than the root file and additionally covers `.env.local`,
`.tokens`, `tokens.json`, `secrets*.json`, `*.token`, `.cache/`. Its new negation is deliberate and
documented in-file ("the repo-root `.gitignore` has a broad `.env.*` rule; this negation
re-includes only the example file"), and `tool/live_checks/.env.example` itself carries an explicit
anti-`service_role` briefing — it explains that a service-role key would make every
`rls_matrix.js` assertion "pass while proving nothing". Good security documentation.

**Also re-verified:** the file still does **not** exist (`ls tool/live_checks/.env` → No such file,
checked again at 11:53), so the `.env.example` template has not been copied. The credential
blocker is unchanged.

**Positive, added mid-audit:** `supabase/operator/010_bootstrap_first_admin.sql` (the first-admin
path) contains **no** literal password, key, JWT or token — `grep -niE 'password|secret|eyJ|token|
api_key'` matches only prose at `:27`, `:38` ("No secrets, passwords or API keys appear in this
file") and `:129`. It also independently corroborates §4's authorization reasoning by recording the
live policy state: `profiles` has only `profiles_select_own` + `profiles_select_super_admin`, and
`profile_sites` only `profiles_select_own` + `profiles_select_super_admin` — i.e. **no write policy
at all, so self-promotion through the API is impossible** (`:7-14`).

**Tracked-file verification:** `git ls-files` returns 314 files; filtering for
`\.env`, `env\.(local|production|dev)`, `secret`, `credential`, `service.?account`, `\.pem`,
`\.p12`, `\.key` yields **NONE tracked**. Working-tree evidence that the ignore rules are doing
real work: `.seed_media/` (624 KB, 17 jpg) and `.seed_media_stage/` (392 KB) are present on disk
and appear nowhere in `git ls-files`; `build/` likewise.

**P2 GAP (re-confirmed against the current tree) — the root `.gitignore` has no general
key-material rules.** Re-ran `git check-ignore -v` at the end of the audit; each of these is still
**NOT IGNORED**: `secrets.json`, `service-account.json`, `x.pem`, `x.key`, `y.p12`,
`google-services.json`. There are no rules for `*.jks` or `*.kdbx` either. Today this is harmless
(no such file exists, and the one new credential-shaped artifact — `.env.example` — is a template),
but the protection is currently concentrated in one subdirectory's private gitignore. Suggested
additions (non-binding; I edited nothing outside my own report):

```gitignore
*.pem
*.key
*.p12
*.jks
secrets*.json
service-account*.json
google-services.json
```

---

## 3. Cross-site isolation — client-side complement — PASS — LOCAL VERIFIED, one P1 latent hole

### 3.1 How scoping works

`SiteContext` (`lib/core/supabase/site_context.dart:20-47`) resolves the numeric site PK **once**
per app run by `sites.select('id').eq('slug', SiteConfig.siteId)` with a 10-second bound
(line 13) and a hard `NotFoundException` if the site row is missing (line 39-43). `SiteConfig.siteId`
is the compile-time constant `'india_tech'` (`lib/app/config/site_config.dart:4`). Every repository
then awaits `_site.siteId` and applies it.

### 3.2 Measured coverage

I enumerated **every** `.from('<table>')` call site in all 9 Supabase repositories and tested each
query chain for a site predicate. Results:

**Correctly scoped with `.eq('site_id', siteId)` — 60 call sites**, including all the dangerous
ones:

- reads: `supabase_article_repository.dart:267-275` (`_publicQuery`, the single choke point for
  all public post reads), `:521-523`, `supabase_category_repository.dart:100-188`,
  `supabase_media_repository.dart:28-30`, `supabase_redirect_repository.dart:44-46`,
  `supabase_site_settings_repository.dart:42-44`, `supabase_subscriber_repository.dart:49-51`,
  `supabase_post_admin_repository.dart:76-78,92-94,114-116,131-133`
- writes: `supabase_article_repository.dart:636-639` (update) and `:648-652` (delete)
- inserts carry `'site_id': siteId` explicitly:
  `supabase_article_repository.dart:337,570,540`, `supabase_category_repository.dart:194,247,287`,
  `supabase_media_repository.dart:58`, `supabase_redirect_repository.dart:27`,
  `supabase_site_settings_repository.dart:64`, `supabase_subscriber_repository.dart:32`,
  `supabase_analytics_repository.dart:47`

**Writes that must not move a row between sites** — `site_id` is deliberately stripped from update
payloads, which is right: `supabase_article_repository.dart:223` (`map.remove('site_id')`),
`supabase_category_repository.dart:299`, `supabase_site_settings_repository.dart:19` (comment),
`supabase_post_admin_repository.dart:16`.

**Self-only access is correctly keyed on `auth.uid()`:**
`supabase_profile_repository.dart:30-36` (`profiles.select().eq('id', user.id)`) and
`:43-47` (`profile_sites… .eq('profile_id', user.id).eq('site_id', siteId)`) — a user can read
their own membership and nothing else.

**Storage isolation:** `supabase_media_repository.dart:46` builds every object key as
`'${SiteConfig.siteId}/${uuid}-$sanitized'` — the site slug prefix is a compile-time constant, not
user input, so a client cannot craft a path into another site's folder. `_sanitizeFileName`
(`:112-122`) replaces everything outside `[a-z0-9._-]` with `-` and rejects `''`, `.` and `..`,
so `/` and `\` cannot survive: **no path traversal**. `deleteMedia` (`:87-109`) resolves the path
only *after* a site-scoped `SELECT` and returns `false` when that read finds nothing, so it cannot
be pointed at another site's object.

**No `.rpc()` anywhere in `lib/`** (verified) — `publish_scheduled_posts()` is reachable only from
pg_cron/server, which removes an entire class of client-side privilege questions.

### 3.3 The ten exceptions, and the one real hole

Queries **without** a `site_id` predicate fall into three groups:

| Group | Sites | Judgment |
| :--- | :--- | :--- |
| `profiles` by own uid | `supabase_profile_repository.dart:33` | **CORRECT** — self-scope is the right key here |
| `post_tags` / `post_revisions` by `post_id`, reached only from a site-proven path | `supabase_article_repository.dart:311,342,590,598` | **SAFE BY CONSTRUCTION**, and this is load-bearing: `updateArticle` performs a site-scoped read-back at `:553-560` (`.eq('site_id', siteId).eq('id', article.id)` → `if (existing == null) return false;`) **before** touching revisions or tags, and `createArticle` uses the id returned by its own `site_id`-carrying insert (`:537-547`). `deleteArticle` is likewise site-scoped (`:648-652`). Both tables have no `site_id` column (`supabase_post_admin_repository.dart:56` says so). |
| `post_revisions` by raw `postId`, no site proof | `supabase_post_admin_repository.dart:176-232` — `revisions(postId)`, `nextRevisionNumber(postId)`, `createRevision(revision)` | **P1 LATENT HOLE** |

**The hole, concretely:** `PostAdminRepository.revisions(String postId)`
(`supabase_post_admin_repository.dart:178-186`) issues
`post_revisions.select().eq('post_id', postId).range(0,49)` with no site resolution at all. The
admin editor route is `/admin/articles/edit/:id` (`lib/app/routes/app_routes.dart:36`), so a
`postId` is exactly the kind of value that arrives from a URL. A site-A editor calling it with a
site-B post UUID would receive site-B revision history — full article bodies — **if and only if
the RLS policy on `post_revisions` is not itself site-scoped**. The client offers no second layer.

**Mitigating fact (why this is P1-latent, not P0-live):** `grep` over `lib/` and `test/` proves
these three methods have **no caller in the application** — they exist only in the interface
(`lib/data/repositories/post_admin_repository.dart:41,47,51`) and its two implementations. Nothing
in any controller or view reads revision history yet. The hole is a missing guard on an unwired
road, so today no request can traverse it.

**Recommendation** (for whoever wires revisions next): make `revisions()`/`createRevision()`
resolve `_site.siteId` and join through the site-scoped `posts` row (or select `posts` by
`id` + `site_id` first, exactly as `updateArticle:553-560` already does) so the client and the
policy enforce the same thing twice.

**Answer to the task question:** *can a request read another site's rows because the app omits a
`site_id` filter?* For every path the app can currently execute — **no**. The omissions are confined
to `post_tags`/`post_revisions` (no `site_id` column exists on those tables) and each reachable one
is guarded by a site-scoped read-back; the single genuinely unguarded call site is dormant. This is
the client-side complement to the DB review: **the DB-side policy on `post_revisions` is
load-bearing and must be confirmed site-scoped before revisions are surfaced in the UI.**
`supabase/README.md` ("Everything else the client already sends … revision insert … is covered by
003/004 policies") asserts this is already handled — I cannot verify that from here; it needs live
SQL (`auth-live` teammate).

---

## 4. Client-side auth / authz — 2 P1 findings

### 4.1 Admin access control is client-side only? — NO for *authentication*, YES for *authorization* — P1

`AdminAuthMiddleware` (`lib/app/middleware/admin_auth_middleware.dart:15-27`) tests exactly two
things: `auth.isLoggedIn.value` (line 17) and `profile.isActive` (line 23). It never consults role.

All **14** protected admin routes carry it (`lib/app/routes/app_pages.dart:225,236,241,246,251,260,
269,278,287,296,305,314,323,332` — verified one-to-one against the 14 admin `GetPage`s; only
`/admin/login` at `:228` is unguarded, which is correct). So *authentication* gating is complete:
there is no admin screen reachable without a session. **That part is PASS — LOCAL VERIFIED.**

The **authorization** gap is real and measurable. The capability matrix exists and is
well-written — `lib/core/supabase/role_permissions.dart:32-50` defines `canManageContent`,
`canManageSettings`, `canPublish`, `canDeleteRecords`, `canViewReports`, and `:59-73` defines
`resolveEffective()`/`hasSiteAccess()` — but `grep -rn 'RolePermissions' lib/` finds **exactly one**
production consumer: `lib/data/repositories/supabase_analytics_repository.dart:110`
(`canViewReports`). A second grep for `canManageSettings|canDeleteRecords|canManageContent|canPublish|
effectiveRole|hasSiteAccess` across `lib/features/` and `lib/app/` returns **nothing**.

Consequences, stated precisely:

1. An authenticated account with a `profiles` row and **no** `profile_sites` membership passes the
   middleware (`hasSiteAccess` is never checked) and reaches the CMS shell.
   `supabase/README.md` is explicit that signup "always creates `'author'`, which grants nothing by
   itself", and `is_staff()` (`supabase/migrations/002_auth_and_roles.sql:215-229`) requires an
   active `profile_sites` row — so every *data* read is denied by RLS and the intruder sees an
   empty admin with zeros, not other people's content. **This is a defense-in-depth failure, not a
   privilege escalation, conditional on RLS being right.**
2. An `author` can open `/admin/settings`, `/admin/authors`, `/admin/trending` and press delete /
   publish / save-settings buttons. Each attempt makes a doomed network round-trip and surfaces a
   mapped PostgREST error instead of a clean "your role can't do this" state. Functionally
   acceptable, but it means **the app's only authorization layer is the database**, and any single
   policy mistake becomes a full breach with no client-side brake.
3. `AdminAuthController.role` (`lib/features/admin/auth/controllers/admin_auth_controller.dart:32`)
   defaults to `AdminRole.author` when no profile is loaded, which is the safe direction.

**Severity P1** *if* self-service signup is reachable on the live project; **P2** if it is not.
Whether GoTrue public sign-up is enabled, and whether an SMTP/allowlist gate exists, is
**UNVERIFIED** — it requires the dashboard Authentication → Providers page. Today
`auth.users = 0` and the client has no signup code (verified: `grep 'signUp|createUser|register'`
over `lib/` matches only an unrelated error string at `initial_binding.dart:93`), so nobody can
self-register *through the app* — the exposure would have to come from direct API access
(`POST /auth/v1/signup` with the anon key), which is exactly why the DB-side check matters.
`README.md:163-165` already documents the correct posture ("The GetX middleware is client-side UX
gating only; real authorization is enforced server-side").

### 4.2 Session restore — P3

`restoreSession()` (`admin_auth_controller.dart:121-130`) sets `isLoggedIn = true` from the
persisted session **synchronously, before** awaiting `_loadProfile()` (line 128 then 129), and
`InitialBinding` fires it `unawaited` (`lib/app/bindings/initial_binding.dart:125`). The comment at
`:116-120` explains why: the router evaluates the middleware synchronously, so waiting would bounce
a valid cold-boot deep link to login. The window is real but bounded and self-correcting —
`_loadProfile()` revokes the flag (`:171-179`) and force-signs-out a missing or deactivated account
(`:161-166`). Any admin query issued inside the window is still RLS-gated, so the worst case is a
few-hundred-millisecond render of an empty CMS. **Judgment: an accepted, documented trade-off, not
a defect. P3.**

### 4.3 Logout — P1

`admin_auth_controller.dart:103-111`:

```dart
Future<void> logout() async {
  try { await _auth?.signOut(); }
  catch (_) { /* Local reset proceeds even when the network sign-out fails. */ }
  _reset();
  await Get.offAllNamed('/admin/login');
}
```

`_reset()` (`:182-186`) clears only the three in-memory `Rx` fields. It does **not** touch the
persisted gotrue session. `AuthService.signOut()` (`lib/core/supabase/auth_service.dart:34-42`)
has no local-storage cleanup either — it relies on the SDK's own success path. Therefore, when the
network sign-out call fails (offline, 5xx, DNS, abort-on-navigation), the UI *shows* "signed out",
the user believes they logged out, but `currentSession` is still in browser storage and the very
next cold boot re-sets `isLoggedIn = true` at `:128`. **On a shared/public computer this is a real
account-exposure defect: logout is not atomic and its failure is silent.** Fix: on `signOut()`
failure, clear the persisted session locally (`SupabaseService.client.auth.signOut()` retry, or
drop the stored `sb-…-auth-token` key) and surface a warning rather than completing the redirect.
`_onAuthStateChanged` (`:136-149`) handles `signedOut` correctly for server-originated events;
that path is fine.

### 4.4 Token handling — P2 (inherent, partially mitigated by design)

- The gotrue access/refresh token pair lives in browser `localStorage` (supabase_flutter default),
  readable by any XSS and by any browser extension. Not fixable in a SPA with a public anon key;
  the mitigation is that RLS caps what a stolen token can do. Flagging as an accepted,
  should-be-documented risk — **no `docs/` file currently records it** (see §9).
- `autoRefreshToken: true` (`supabase_service.dart:25`) — correct.
- Errors are sanitized before reaching the UI: `_mapAuthError` (`auth_service.dart:59-79`) maps
  credential/email-confirm/throttle cases and `_safeAuthMessage` (`:82-88`) strips any gotrue
  internals. Good: no token or provider detail is echoed.
- No CSRF surface: the app uses bearer JWTs, not cookies, so cookie-based CSRF does not apply;
  PostgREST inserts are not ambient-authorized. **PASS — LOCAL VERIFIED.**
- No client-side login throttle (`login()` at `:71-101` has none) — brute force is left entirely to
  gotrue rate limiting, which is the right layer, but the `too_many_requests` mapping at `:73-77`
  is the only visible consequence. **P3.**

### 4.5 `unknownRoute` — PASS — LOCAL VERIFIED

`lib/app/app.dart:25-35` binds `unknownRoute` to a `/404` `GetPage` rendering `NotFoundView`
inside `PageSeoInit`. It carries **no** admin capability and is public-only. Because
`AdminAuthMiddleware` is attached per-route inside `getPages` and `unknownRoute` is a separate
`GetPage`, an unmatched URL cannot land in the CMS shell. The design note at `:27-29` (GetX skips
middleware on the initial deep link, hence `PageSeoInit` rather than a middleware) is a correct
rationale for the pattern. `lib/main.dart:15` documents the same boot subtlety.

---

## 5. Consent and analytics — NOT CONFIGURED today; P2 forward-looking

### 5.1 First-party beacons (live code)

`AnalyticsService` (`lib/core/analytics/analytics_service.dart`) is fired from
`lib/app/app.dart:43-47` (`routingCallback`, one `page_view` per navigation, `/admin*` deliberately
skipped so staff traffic does not pollute the public series).

**Exactly what leaves the browser** (`analytics_service.dart:63-98` →
`supabase_analytics_repository.dart:38-55`, `74-105`):

| Field | Value | Identifying? |
| :--- | :--- | :--- |
| `site_id` | resolved server-side site PK | no |
| `event_type` | `page_view` \| `article_view` only; `_allowedEvents` (`:22`) enforced client-side at `:79-81` before the request | no |
| `session_id` | `<ms-since-epoch base36>-<10 random digits>` (`analytics_service.dart:54-56`) | **pseudonymous run identifier** |
| `path` | the GetX route pattern, e.g. `/article/<slug>` | content, not person |
| `post_id` | UUID for `article_view` | content |
| `referrer` | in the interface (`analytics_repository.dart:8`) but **never supplied by any caller** → always `null` | — |

No name, no email, no coarse location, no screen size, no user-agent, no device fingerprint.
Deliberately **not persisted**: `:21-22` explains the session id is per app-run because persisting
it "would need a storage round-trip before the first beacon fires". So it cannot build a
cross-visit profile. Writes are fire-and-forget and every failure is swallowed
(`:108-123`, repository `:96-104`) so a beacon can never break a reader's page.

IP address is *not* sent by the app but is of course seen by Supabase's edge like any HTTPS
request; Supabase-side request logging retention is **UNVERIFIED** (dashboard/infra, out of my
access).

### 5.2 Google Analytics 4 — NOT CONFIGURED, and unwired

`GA_MEASUREMENT_ID` is read at `analytics_service.dart:22-23` with `defaultValue: ''`, so GA is
inert by default (`_gaActive`, `:29`). `site_settings.google_analytics_id` is **empty in the live
DB** (given state; corroborated by `lib/data/repositories/mock_site_settings_repository.dart:26,51`
defaulting it to `''` and by `supabase/migrations/001_initial_schema.sql:230` declaring the column
nullable).

Two paths, **both of which were still being wired while I audited this section** — I re-verified
each against the current tree rather than trusting my earlier read:

- **CLOSED mid-audit — build-time path.** `tool/live_checks/lib/config.js` now exposes
  `gaMeasurementId`/`googleSiteVerification` slots (`:56-57`), read by
  `build_production.ps1:62-63`; the script reports `GA_MEASUREMENT_ID : present | <absent: GA stays
  inert>` (`:84`), documents both keys (`:118-119`), and passes them **conditionally** as
  `--dart-define=GA_MEASUREMENT_ID=$gaId` (`:156-157`). Conditional-pass is the right design: an
  absent key leaves `defaultValue: ''` in force, so GA stays inert instead of being initialised
  with an empty id.
- **CLOSED mid-audit — DB runtime path.** `configureGa()` (`analytics_service.dart:45-52`) is
  called from `lib/main.dart:67` inside `_applyDatabaseGaId()` (`:64-71`), which `main()` fires as
  `unawaited(_applyDatabaseGaId())` at `:92-93` after `InitialBinding().dependencies()`. My first
  grep found zero callers because that wiring landed minutes later; **the admin SEO screen's GA
  field (`admin_seo_controller.dart:48,73`) therefore does have an effect**, and
  `site_settings.google_analytics_id` is a live control path. Build-time correctly wins over DB
  (`analytics_service.dart:36,48`). The design is sound: reading site_settings must not delay first
  paint, hence the unawaited fire-and-forget.
- **So GA is `NOT CONFIGURED`, not `BROKEN`.** Both switches work; neither has anything to switch
  on yet — `GA_MEASUREMENT_ID` is unset in every available build and
  `site_settings.google_analytics_id` is empty in the live DB.
- **P2 (the moment an ID is supplied) — no consent, and a third-party host.**
  `lib/core/analytics/ga4_dom_web.dart:20-31` injects an inline `gtag('config', …)` and then an
  async `<script src="https://www.googletagmanager.com/gtag/js?id=…">` into `document.head`.
  There is **no consent gate of any kind**: `grep -rniE 'consent|cookie' lib/` matches exactly one
  line, and it is the newsletter sentence at
  `lib/features/static_pages/views/privacy_policy_view.dart:54`. No banner, no preference centre,
  no `gtag('consent','update',…)`, no `allow_ad_personalization_signals:false`, no
  `anon_storage:true`, no DNT/GPC check, no region gate. The moment a real ID is supplied, every
  visitor's page paths and article reads are sent to Google and the visitor's IP is disclosed to
  `googletagmanager.com` — without notice. GA thereby becomes the product's only third-party
  *analytics* subresource (§6).
- **~~P3 — latent CSP conflict~~ → CLOSED, and closed twice.** My first read of `web/_headers` found
  no analytics origin in the CSP and its §4 note said *"no analytics tags exist in `web/index.html`
  … so no third-party analytics origin is allowed here"*. That reasoning was already superseded when
  I re-read the file at 11:54: the report-only policy now carries
  `script-src … https://www.googletagmanager.com`, `img-src … https://*.google-analytics.com
  https://*.googletagmanager.com` and `connect-src … https://*.google-analytics.com
  https://*.analytics.google.com https://*.googletagmanager.com`
  (`web/_headers:75`), with the rationale written out at `:287-301`. So a GA-enabled build will not
  be silently broken. I also re-verified `grep -iE 'gtag|googletagmanager' web/index.html` → **0**,
  i.e. the tag is still runtime-injected only, exactly as §6.3 records.
- **P3 (new, replaces the closed item) — GA's own loader is why the CSP needs `'unsafe-inline'`.**
  `ga4_dom_web.dart:20-27` emits an **inline** `window.dataLayer` / `gtag('config', …)` script, so
  `script-src` must carry `'unsafe-inline'` (`_headers:287-298` states this and calls removing it "an
  app-side change… before this policy is promoted to enforcing"). That matters beyond CSP hygiene,
  because it pairs with finding #18: with `'unsafe-inline'` present and the access token in
  `localStorage` (`supabase_service.dart:19-27`), a single injected-script XSS gets both the CSP-free
  path to run arbitrary code **and** the session. Nonce/hash-ising the GA tag is therefore a
  **security** prerequisite for enforcing CSP, not a cleanliness one. Suggested order: nonce support →
  consent UI → GA id → CSP promotion.

### 5.3 Disclosure accuracy — P2

`privacy_policy_view.dart:42-48` claims: *"We utilize anonymized telemetry to gauge story
popularity and device screen sizes (e.g. tablet vs mobile)…"*

- "device screen sizes" is **not collected** by anything in `lib/` — over-disclosure.
- "anonymized" is **overstated for GA4** if GA is ever enabled (GA4 re-identifies across sites and
  is neither anonymous nor consent-free) and is *roughly* fair for the first-party beacon
  (run-scoped random id), but the beacon id is a **pseudonymous identifier**, which is personal
  data under GDPR and "personal information" territory under India's DPDP Act 2023 — the very
  statute the page's own title invokes (`:21`).
- The page promises erasure/consent-revocation "at any time via
  **privacy@bharattechpulse.in**" (`:54`). That mailbox **cannot exist**: the domain is
  unregistered and no mail/DNS is configured. `SiteConfig` advertises two more
  (`lib/app/config/site_config.dart:16-17`: `contact@`, `editorial@`) and `web/index.html:75`
  bakes `contact@` into the Organization JSON-LD. So the published privacy rights and the contact
  routes are currently unreachable for any real reader. **P2, and it is a compliance-facing claim,
  not a cosmetic one.** Same for the `/contact` form if it points at mail.
- There is no cookie banner, which is defensible today (no cookies are set; `shared_preferences`
  on web uses `localStorage` for the theme toggle) but will not survive GA4 going live.
- **P3 (new, same root cause as #13) — four unprovisioned social identities are published as
  structured data.** `SiteConfig` declares `twitterHandle`/`youtubeChannel`/`telegramChannel`/
  `linkedinPage` (`lib/app/config/site_config.dart:20-23`) and `seo_schema.dart:22-25` emits them as
  the Organization `sameAs` array at runtime, while `web/index.html:78-81` bakes the same four URLs
  into the static JSON-LD. Whether any of those accounts exist is **UNVERIFIED** (no browser/network
  access, and out of my scope). If they do not, Google receives a machine-readable claim of four
  properties that 404, which is the same class of defect as the dead mailboxes and is the kind of
  thing that suppresses Organization schema rather than helping it. Either register them or drop the
  `sameAs` block until they exist.
- **Positive, verified:** the OG fallback image is first-party. `defaultOgImage` is
  `$domain/og-default.jpg` (`site_config.dart:35`, with the rationale in its comment at `:29-34`) and
  `web/og-default.jpg` really exists (**29,496 B**, measured). So no page's social card points at a
  third-party stock host, and the comment correctly notes this is also what keeps the project ref
  out of `lib/`.

**Bottom line for §5:** first-party analytics is genuinely light-touch and well-scoped
(**P3: no consent notice for a pseudonymous identifier**); GA4 is **NOT CONFIGURED** — no
measurement id exists in the live DB or in any available build, though both enable switches are now
verified wired (§5.2), so this is "nothing to turn on", not "cannot be turned on";
and the **P2** set is "no consent mechanism exists at all, the disclosure text is inaccurate, and
the contact address for exercising rights is dead."

---

## 6. Asset and bundle audit of `build/web` as it sits — FAIL (artifact is not releasable)

### 6.1 State drift — read this first

The brief described `build/web/main.dart.js` at **3,291,528 B**. It is now **12,927,991 B**
(`mtime 2026-10-13 11:26`), and **14 files appeared or changed while I audited**:
`tool/deploy_cloudflare.ps1` (11:43), `tool/generate_prerender.dart` (11:39), 15 prerendered
`build/web/article/*/index.html` shells, `web/_headers` + `web/_redirects`,
`tool/live_checks/.env.example`, `supabase/operator/010_bootstrap_first_admin.sql` (11:49),
`lib/core/analytics/ga4_dom.dart` + `_stub` + `_web`, `lib/core/seo/seo_schema.dart`,
`docs/DEPLOYMENT.md` (11:52, alongside my own file), plus edits to
`analytics_service.dart`, `seo_service.dart`, `web/index.html`, `initial_binding.dart`,
`environment_config.dart`, `README.md` and `supabase/README.md`. **The artifact changed under me;
everything below is a snapshot, and `main.dart.js` is now a *debug* build, not the release build the
brief measured.** I ran no builds. §12 records which findings I re-verified against the newer tree.

The single most consequential mid-audit change for this report: `analytics_service.dart` gained
**GA4 wiring** (`ga4_dom_web.dart` injecting a `googletagmanager.com` script) *after* my first read,
which is why §5 is framed as "inert today, P2 the moment it is switched on" rather than as a
purely hypothetical concern.

Corroborating markers (counts in `build/web/main.dart.js`):

| Marker | Count | Meaning |
| :--- | ---: | :--- |
| `Aravind Sharma` (mock fixture) | 1 | mock data is present → mock-mode build |
| `placeholder-project` | 2 | `SUPABASE_URL` never supplied |
| `images.unsplash.com` | 27 | third-party hotlinks baked in |
| `post_revisions` | 0 | Supabase repos tree-shaken away |
| `analytics_events` | 0 | Supabase repos tree-shaken away |
| `ylzwuwfhlqomjqcdrpxk` | 0 | **no live ref in the bundle** |
| `bharattechpulse.in` | 13 | own-origin URLs (fine) |
| `eyJ…` JWTs | 0 | **no credential** |

And `main.dart.js` has **257,324 lines** — unminified/pretty-printed. A dart2js `--release` output
is one line. Combined with the mock markers this is unambiguously the dev `--debug` artifact,
which is exactly what `README.md:289-296` predicts in its "dev `--debug` build (restored)" column
(12,927,991 B — matches my measurement byte-for-byte).

**Verdict: FAIL / NOT DEPLOYABLE.** Uploading `build/web` today would ship a debug bundle that
renders **fabricated** articles and hotlinks 27 Unsplash images. **P1.**

### 6.2 Size accounting (as measured, disk)

| Path | KB | Notes |
| :--- | ---: | :--- |
| `build/web` **total** | **53,758 KB (52.5 MB)** | 55 files |
| `canvaskit/` | 37,620 KB | 28.0 MB of `.wasm` + 8.2 MB of `.symbols` |
| `main.dart.js` | 12,625 KB (12,927,991 B) | debug build |
| `assets/` | 3,215 KB | `NOTICES` 1,358,071 B + `MaterialIcons-Regular.otf` 1,645,184 B + `CupertinoIcons.ttf` 257,628 B |
| `article/` (15 prerender shells) | 124 KB | ~5,455 B each |
| rest (html/js/png/xml/json) | ~80 KB | |

**Dead weight:** the `.js.symbols` files (8.2 MB) are stack-trace deobfuscation maps, never fetched
by a browser. Four renderer variants ship (`canvaskit`, `canvaskit/chromium`,
`canvaskit/experimental_webparagraph`, `skwasm`/`skwasm_heavy`/`wimp`) while
`flutter_bootstrap.js:36` declares **one** build — `{"compileTarget":"dart2js","renderer":"canvaskit"}`
— so **every skwasm/wimp payload (~14 MB raw) is unreachable** in this configuration. Since
`_headers`/`_redirects` do not exist (§6.5), an unused `canvaskit.wasm` is also not being served
by accident. This inflates the deploy/upload size but not the user's download.

### 6.3 Third-party hosts hotlinked — measured, with the big one

**`web/index.html` (source): clean.** The only URLs are `bharattechpulse.in` self-origin
(`:27,34,35,42`), own icons/manifest (`:48,51,53`), `flutter_bootstrap.js` (`:64`), and two
`developer.mozilla.org` / `docs.flutter.dev` links inside **comments** (`:12,62`). No `gtag`,
no Google Analytics, no CDN, no font `<link>`. `grep` for `googletagmanager|gtag` in
`web/index.html` → **0**. Verified `build/web/index.html` matches.

**From the bundle:** `images.unsplash.com` × 27 (`main.dart.js`) — mock fixtures; **must not be
deployed**, and the release/production build tree-shakes them (`README.md:295` reports 0 for the
production-wired artifact, and the mechanism is real: `EnvironmentConfig.mockDataAllowed` folds to
`false` at `environment_config.dart:67`, and `initial_binding.dart:91-95` throws before the mock
branch, so dart2js can drop the fixtures — `initial_binding.dart:85-90` documents exactly this).

**Runtime-injected, and this is the finding that matters — `fonts.gstatic.com` (via `google_fonts`)
and `www.gstatic.com` (via CanvasKit):**

1. **`google_fonts: ^8.2.1`** (`pubspec.yaml`, deps block) with **no bundled font assets** —
   `pubspec.yaml:60-95` shows the `assets:`/`fonts:` sections entirely commented out.
   `lib/app/theme/theme_text.dart` calls `GoogleFonts.interTextTheme()` at `:11` plus
   `GoogleFonts.outfit(...)` × 6 and `GoogleFonts.inter(...)` × 9 (`:14-107`). `google_fonts`
   fetches families **at runtime from `https://fonts.gstatic.com`**, caches them in
   `SharedPreferences`, and on failure falls back to the platform font. So every first visit issues
   cross-origin requests to Google, disclosing visitor IP + UA to a third party with no consent gate
   and no self-hosting. **P2 — privacy + render-blocking + third-party dependency for a site whose
   stated rule is "no third-party hotlinks".** Fix is to bundle Inter/Outfit as real font assets.
2. **CanvasKit is loaded from Google's CDN by default, not from the local folder.**
   `flutter_bootstrap.js` resolves the engine location as
   `E(i,e) = i.canvasKitBaseUrl ? … : (e.engineRevision && !e.useLocalCanvasKit) ? "https://www.gstatic.com/flutter-canvaskit" + engineRevision : "canvaskit"`
   (single line, minified; the `buildConfig` at `:36` supplies
   `engineRevision: 83675ed2…`, and the invocation at `:38-42` passes only
   `serviceWorkerSettings` — **no `useLocalCanvasKit`**). Therefore the browser fetches
   `canvaskit.js` + `canvaskit.wasm` from **`www.gstatic.com`**, and the 37.6 MB
   `build/web/canvaskit/` directory is never read. **P1-for-cost/P2-for-privacy: the heaviest
   download in the product comes from a third-party origin outside Cloudflare's unmetered
   bandwidth and outside our cache-control reach.** One line in a `flutter_bootstrap.js` template
   (`useLocalCanvasKit: true`) puts it on our own edge and makes the local directory useful.

Also (harmless): `schema.org`, `t.me`, `twitter.com`, `linkedin.com`, `youtube.com` appear as
*link targets* in the prerender shells' JSON-LD/share blocks — outgoing links, not subresource
loads. Not hotlinking.

### 6.4 `assetManifest.json` leak check — PASS — LOCAL VERIFIED

There is **no `AssetManifest.json`** (legacy format, no longer emitted). The manifests are
`assets/AssetManifest.bin` (117 B) and `assets/AssetManifest.bin.json` (158 B); decoded, the
content is a single entry pointing at
`packages/cupertino_icons/assets/CupertinoIcons.ttf`. `assets/FontManifest.json` (208 B) lists only
`MaterialIcons` and `packages/cupertino_icons/CupertinoIcons`. **Nothing meaningful is disclosed: no
article slugs, no upload paths, no Supabase URL, no ref, no keys.** `assets/NOTICES` (1,358,071 B)
is the standard open-source licence text — legally required, benign, and fetched only when the
licence page is opened. `version.json` (98 B) exposes only `india_tech_web / 1.0.0+1`. `web/index.html`
and the 15 prerender shells are intentionally public HTML.

### 6.5 Caching / cacheability — **corrected mid-audit: now PASS — LOCAL VERIFIED (live behaviour UNVERIFIED)**

**I originally reported this as a P2 failure, and that was overtaken by events.** When I first
listed `web/` there was no `_headers` and no `_redirects` (`ls web/_headers web/_redirects` →
"No such file"). A teammate then authored both (`web/_headers` ~10 KB, `web/_redirects` ~7 KB,
present in `git status` as `??` at the end of the audit). I read both files in full and they are
**correct, careful, and they close the gap**. Evidence:

- **`_redirects` fixes the SPA deep-link 404** — `/* /index.html 200` plus eight trailing-slash
  301s for the category routes. Its reasoning is sound and cites real code: `lib/main.dart` calls
  `usePathUrlStrategy()` (so deep links are `/article/<slug>`, not hash URLs) and the un-slashed
  `/ai` would otherwise soft-404 because `_isKnownRoute()` holds only the slashed form.
- **`_headers` sets a real cache policy**: `Cache-Control: no-cache` on `/`, `/index.html`,
  every route family and `/admin/*`; `public, max-age=0, must-revalidate` on
  `/main.dart.js`, `/flutter_bootstrap.js`, `/flutter.js`, `/version.json`, `/assets/*`,
  `/canvaskit/*`; and `max-age=3600`/`86400` on robots/sitemap/brand art.
- **Crucially, the author reached the same conclusion I did about the un-hashed artifacts, and
  refused to use `immutable`.** The comment block states that Flutter's web output is *not*
  content-addressed (zero hashed filenames across 42 files) and that `flutter_bootstrap.js` loads
  the literal URL `main.dart.js` with no `?v=` or fingerprint, so `max-age=31536000, immutable`
  "**would be WRONG** — the URL never changes but the bytes do". That is exactly right and is the
  subtlety that usually gets shipped wrong.
- **Security headers are present and sensible**: `X-Content-Type-Options: nosniff`,
  `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, a broad
  `Permissions-Policy` (camera/mic/geolocation/payment/usb all `()`),
  `Strict-Transport-Security: max-age=15552000`, and a `Content-Security-Policy-Report-Only`.
- Two judgement calls in it are notably good: HSTS ships **without** `includeSubDomains` because
  `lib/app/config/environment_config.dart:141` hard-codes a second host
  (`https://api.bharattechpulse.in`) that has no certificate yet — pinning subdomains now would
  brick it for 180 days; and COOP/COEP are omitted deliberately because `crossOriginIsolated` only
  buys multi-threaded skwasm while this build's renderer is `canvaskit`+`dart2js`, and
  `Cross-Origin-Opener-Policy: same-origin` would sever `window.opener` for any future Supabase
  OAuth popup.

Residual notes, all minor, all of which the file itself flags as not live-verified:

1. **The CSP is report-only, so it enforces nothing today.** It whitelists
   `https://www.gstatic.com` (CanvasKit), `https://fonts.googleapis.com` +
   `https://fonts.gstatic.com` (google_fonts) and `https://images.unsplash.com` (mock fixtures).
   Permitting those origins does not make them non-third-party: findings **#4 and #5 stand** —
   the fix is `useLocalCanvasKit: true` and bundling Inter/Outfit, after which the directives
   should be *narrowed*, and `images.unsplash.com` should be dropped from the CSP in the same
   release that ships a mock-free production bundle.
2. **My own read resolves a question `_headers` leaves open.** It says which CanvasKit source the
   browser fetches "is UNVERIFIED — hence both 'self' and gstatic are allowed rather than
   guessing." It can be settled statically from `build/web/flutter_bootstrap.js`: the resolver is
   `canvasKitBaseUrl ? it : (engineRevision && !useLocalCanvasKit ? "https://www.gstatic.com/
   flutter-canvaskit" + rev : "canvaskit")`, `buildConfig` supplies
   `engineRevision: 83675ed2…`, and the `load()` call passes only `serviceWorkerSettings`. So
   **gstatic wins** today, and the local `canvaskit/*` (~26 MB) is dead weight until
   `useLocalCanvasKit: true` is set. (P1 #4.)
3. `_headers` §4 remarks that "`web/sitemap.xml` currently advertises 15 of the 24 seeded posts"
   as if it were a shortcoming. **My measurement says it is correct, not deficient**: the seed has
   exactly 15 `'published'`, 4 draft, 3 scheduled, 2 archived (counted in
   `supabase/migrations/006_seed_data.sql`), and `web/sitemap.xml` has exactly 15
   `…/article/` `<loc>` entries — matching the 15 published posts, the 15 prerender shells, and
   the live verified state. Drafts and scheduled posts *should not* be in a sitemap. No action.
4. Everything in `_headers`/`_redirects` about actual Pages behaviour (comma-join, redirect
   priority over headers, static-asset-wins-over-rewrite, SPA 200-rewrite header matching) is
   **UNVERIFIED** until a preview exists; the file says so and defers to the curl checks in
   `docs/DEPLOYMENT.md` §7. Correct posture.

Still true and still a caveat:

- **Flutter web artifacts are not content-hashed** (`main.dart.js`, `flutter_bootstrap.js`,
  `index.html`, `canvaskit/*`, `assets/*` keep fixed URLs across builds; only
  `flutter_service_worker.js?v=<version>` varies) — which is precisely why `_headers` chose
  revalidation over `immutable`.
- **The service worker is a self-unregistering stub.** `flutter_service_worker.js` is 815 B whose
  whole body is `install → skipWaiting`, then `activate → registration.unregister()` and reload
  clients. **No precache, no offline capability.** The historical Flutter SW is deprecated (the
  comment at `flutter_bootstrap.js:40` says so), and `_headers` documents the same finding.
  So "second visit is free from the edge cache" holds only because of the new `Cache-Control`
  rules, not because of any service worker.
- `og-default.jpg` (29,496 B) is same-origin and correct as a share image
  (`site_config.dart:35` builds it from `$domain/og-default.jpg`) — good practice, no third-party.

### 6.6 Real first-visit download cost

Measured by gzipping the actual files on disk (Cloudflare Pages serves gzip or brotli, so
compressed figures are the honest ones; brotli would be ~10-20% smaller — labelled ASSUMPTION).

| Resource | Raw B | Wire (gz) B | Source | First visit? |
| :--- | ---: | ---: | :--- | :--- |
| `index.html` | 3,179 | 1,286 | our origin | yes |
| `flutter_bootstrap.js` | 9,975 | 3,853 | our origin | yes |
| `main.dart.js` — **current debug artifact** | 12,927,991 | **2,051,598** | our origin | yes (undeployable) |
| `main.dart.js` — production release, Supabase-wired | 3,436,722 (`README.md:296`) | **~1,050,000** | our origin | yes — **ASSUMPTION** (dart2js minified JS gzips to ≈30%; the file that produced this number no longer exists on disk) |
| `canvaskit.js` | 86,859 | 27,498 | **`www.gstatic.com`** | yes (Chromium variant: 86,496/27,458) |
| `canvaskit.wasm` | 7,229,467 | **2,909,284** | **`www.gstatic.com`** | yes |
| `assets/fonts/MaterialIcons-Regular.otf` | 1,645,184 | 563,183 | our origin | yes (icon glyphs) |
| `assets/…/CupertinoIcons.ttf` | 257,628 | 116,424 | our origin | conditional |
| Inter + Outfit | — | **~150,000–400,000** | **`fonts.gstatic.com`** | yes — **ASSUMPTION**, not in the bundle; varies by subset/weight and is fetched at runtime |
| `AssetManifest.bin`, `FontManifest.json`, `manifest.json`, `version.json` | 524 total | ~400 | our origin | yes |
| `assets/NOTICES` | 1,358,071 | 108,247 | our origin | only if the licences screen opens |

**Honest first-visit total (production release assumed):**

| Component | MB (compressed) |
| :--- | ---: |
| App shell: HTML + bootstrap + `main.dart.js` | ~1.05 |
| CanvasKit engine (`canvaskit.js` + `.wasm`) | ~2.94 |
| Bundled icon fonts (MaterialIcons, +Cupertino conditional) | ~0.56–0.68 |
| google_fonts Inter + Outfit | ~0.15–0.40 |
| Manifests + prerendered shell | ~0.01 |
| **TOTAL first cold visit** | **≈ 4.7 – 5.2 MB compressed** |
| Of which from **third-party origins** (gstatic CanvasKit + gstatic fonts) | **≈ 3.1 – 3.3 MB (~65%)** |
| Steady-state repeat visit **with the `_headers` policy now in place** | ~0.005–0.05 MB (revalidated HTML via 304 + PostgREST JSON + cached images) |
| Steady-state repeat visit **if `_headers` is not deployed / does not apply as written** | unbounded — up to the full ~5 MB per visit, because artifacts are un-hashed and the service worker unregisters itself (no precache layer). **UNVERIFIED** until a preview deploy answers the curl checks in `docs/DEPLOYMENT.md` §7. |
| First-visit images from Supabase (10 image-bearing cards on home) | ~0.43 MB — **billed Supabase egress, not Cloudflare** |

Two things a reader should take away: the download is **~5 MB, dominated by the rendering engine**,
and **roughly two-thirds of it currently comes from Google, not from Cloudflare** — which is both a
privacy issue and a caching/cost issue, and it is fixable with `useLocalCanvasKit: true` plus
self-hosted fonts. The `~4.7–5.2 MB` figure also means the "unmetered bandwidth" of Cloudflare
Pages is doing real work for us, while the small image bytes are the ones hitting a *metered*
provider (§7).

---

## 7. Cost model

### 7.1 Honest labelling of what I am allowed to claim

**I did not browse for pricing and will not.** Every figure below is tagged:

- **OFFICIAL PUBLISHED** — stated in the audit brief's own documented free-tier limits, or a
  no-cost product with no paid tier to confuse it with.
- **ASSUMPTION** — from my general knowledge of these vendors' list prices; plausible, dated, and
  **must be re-read off the vendor's pricing page before anyone relies on it**.
- **UNKNOWN** — I have no defensible number, or no access.

**Standing caveat, stated once and applying to every row: I cannot see any billing page.** The
actual plan of the live Supabase project `ylzwuwfhlqomjqcdrpxk` and of the Cloudflare account is
**UNVERIFIED**, so I do **not** claim either account is free. A project can sit on a paid plan while
a free plan exists. Only a `PASS — LIVE VERIFIED` from the billing page can settle it.

### 7.2 Line items

| Item | Documented free-tier limits | My annual figure | Label | Comment |
| :--- | :--- | :--- | :--- | :--- |
| **Supabase — Free tier** | 500 MB DB · 1 GB storage · **5 GB egress/mo** · 50k MAU · **project pauses after ~1 week of inactivity** | **$0 (if the account truly is on Free)** | ASSUMPTION (plan), OFFICIAL PUBLISHED (limits) | Headroom measured from this repo: **DB is a non-issue** (whole migration chain is 308 KB of SQL text, `006_seed_data.sql` = 217 KB → live content is a small fraction of 500 MB). **Storage is a non-issue** (17 media objects = **598,190 B = 584 KB of 1 GB**, per the registry in `006`+`007`). **MAU is a non-issue** (no end-user accounts exist; `auth.users = 0`). **Egress is the only binding limit** — §7.3. |
| **Supabase — Pro** | n/a | **~$300/yr** ($25/mo) | **ASSUMPTION** | Recollection of the published Pro price; unverified, and the plan in force is unverified. Included-then-metered egress allowance on Pro and the per-GB overage rate are **UNKNOWN to me** — do not plan against a number I cannot source. |
| **Cloudflare Pages** | 500 builds/mo · **unmetered bandwidth** | **$0** | OFFICIAL PUBLISHED (limits), ASSUMPTION (plan) | The whole app is ~55 files / 52.5 MB before trimming; comfortably inside one project. **500 builds/mo is not a constraint** for a blog — and note `deploy_cloudflare.ps1` uses `wrangler pages deploy` of a locally built directory (`:377-386`), which consumes **zero** Pages build minutes at all. |
| **Cloudflare Pages Pro** | unlimited builds, etc. | **~$240/yr** ($20/mo) — **NOT needed** | ASSUMPTION | Excluded from the total. Nothing in this project needs it. |
| **Cloudflare DNS + SSL** | Free tier DNS; Universal SSL for proxied hostnames at no charge | **$0** | OFFICIAL PUBLISHED / ASSUMPTION | A custom domain on Pages is served with a Cloudflare-managed certificate; no per-hostname fee. Advanced/Custom-SSL certificate products are a different, paid thing we don't need. **This only holds once the domain is actually on a Cloudflare-managed zone — UNVERIFIED.** |
| **Domain #1 — `bharattechpulse.in`** (the intended production domain, **not registered**) | — | **UNKNOWN** | **UNKNOWN** | I will not guess a registry/registrar price. `.in` is an India-registry TLD priced in INR through accredited registrars, and registration and renewal are often priced differently in the first year. **Must be read off a registrar checkout page.** Expect it to be a modest annual number, but that is my *impression*, not a figure — do not budget on it. |
| **Domain #2 — second intended domain** | — | **UNKNOWN** | **UNKNOWN** | The TLD was **never discovered** (per the brief) and I have no evidence for it in this repo. **Cannot be estimated at all.** A placeholder line, to be replaced when the owner names it. |
| **Static hosting / deploy path** (`build/web` → Pages via `wrangler`) | included in Pages Free | **$0** | ASSUMPTION | Build cost is local (a developer machine), so nothing is bought. No CDN fee, no per-request fee on Pages, no object storage required for the app shell. |
| **Google Search Console** | — | **$0** | OFFICIAL PUBLISHED | There is no paid tier to accidentally need. Verification is *unavailable* rather than *unpaid*: `web/index.html:58` carries `<meta name="google-site-verification" content="">` — intentionally empty — and `web/robots.txt:6` + `web/sitemap.xml` (30 `<loc>`, all `bharattechpulse.in`) already assert a domain that does not resolve. **Cost $0; status BLOCKED on the domain.** |
| **Google Analytics (GA4 standard)** | — | **$0** | OFFICIAL PUBLISHED (standard is free) / ASSUMPTION | GA4 "360" is the paid enterprise product; a blog of this size has no reason for it, so I do not price it. **Note the real GA cost is not money** — it is the consent obligation and the `googletagmanager.com` subresource (§5.2, §6.3). Today it is $0 *and* inactive: no measurement id exists in the live DB or in any available build, although both enable paths are now verified wired (§5.2; finding 16 closed). The only cost attached to GA is the consent obligation and the `'unsafe-inline'` CSP concession its loader forces. |
| **Email for `contact@` / `editorial@` / `privacy@bharattechpulse.in`** | — | **UNKNOWN — EXCLUDED** | UNKNOWN | Three addresses are published to readers (`site_config.dart:16-17`, `privacy_policy_view.dart:54`, `web/index.html:75`) and **none can receive mail today**. Options span no-cost (Cloudflare Email Routing — receive/forward only, cannot send *as* those addresses without an external SMTP relay; a free-tier mailbox product) to per-seat paid workspace mail. **Excluded from the headline; flagged in §8 because it is a P2 compliance item, not just a line item.** |
| **Taxes** | — | **+~$54/yr if 18% GST applies to the $300** | ASSUMPTION | Whether the bill carries GST depends on the billing address/country of the Supabase subscription, which I cannot see. Treated as a labelled exclusion. |
| **Overages** (egress, extra storage, build minutes beyond free) | — | **UNKNOWN** | UNKNOWN | Depends entirely on traffic; the egress mechanism is modelled in §7.3 so the *shape* is knowable even where the *rate* is not. |

### 7.3 Why Supabase egress, not storage or the database, is the real constraint

Seeded imagery is served from the Supabase **public** `media` bucket. Those bytes go from
Supabase's origin to the visitor **directly** (`…supabase.co/storage/…` is a cross-origin
subresource of our page; it does not traverse Cloudflare). So Cloudflare's **unmetered** bandwidth
cannot absorb them, while Supabase's free tier caps them at **5 GB/mo**.

Measured object sizes (`public.media` registry, from `006`+`007`, 17 rows):

- category heroes: 8 × ~40,000–48,121 B (1600×900)
- 1 pre-existing hero/OG object: 29,496 B (1200×630)
- author avatars: ~7,344–8,220 B (300×300)
- **total 598,190 B; average 34.4 KB**

Traffic model (ASSUMPTION on images-per-page, MEASURED on object sizes): the homepage renders
**10** image-bearing cards (`home_view.dart`: 7 `ArticleCard` + 1 each `FeaturedArticleCard`,
`PopularArticleCard`, `TrendingCard`) at ~43 KB per hero ⇒ **≈ 0.43 MB per first homepage view**;
an article page (~1 hero + 1 avatar + a few sidebar thumbs) ≈ **0.2 MB**. Adding PostgREST JSON
(a few tens of KB per navigation) keeps the order of magnitude.

| Free-tier ceiling (OFFICIAL PUBLISHED) | Implied monthly capacity (ASSUMPTION) |
| :--- | :--- |
| 5 GB egress ÷ 0.43 MB | **≈ 11,000 first-time homepage views/mo**, or ≈ 23,000 article views |
| 5 GB egress ÷ 34.4 KB per object | ≈ 145,000 image fetches, before browser caching |

So the free tier is genuinely usable for a small blog — **but the traffic ceiling is set by image
egress, not by the 500 MB database or the 1 GB storage**, and it is the number that will push a
successful launch onto Pro. Repeat visits are cheaper only if `Cache-Control` revalidates the
un-hashed artifacts — which `web/_headers` now does, at authoring level, but that behaviour is
**UNVERIFIED** until a preview deploy exists (§6.5). Supabase Storage's own CDN TTL is
**UNVERIFIED** in any case.

**The $0 recommendation:** move the 17 static seeded images out of Supabase Storage and into the
Cloudflare Pages deploy (or R2), and keep Supabase Storage only for genuine user uploads. Then those
bytes ride **unmetered Cloudflare bandwidth** (§7.2), the 5 GB Supabase ceiling stops being the
product's traffic ceiling, and the whole cost question collapses to "is Pro worth $25/mo for
backups and headroom". This is the single highest-leverage cost decision in the audit, and it
contradicts nothing in the security review — the objects are already public, so moving them neither
adds nor removes exposure.

### 7.4 Combined annual estimate

| Scenario | Infrastructure | Domains | **Combined annual** |
| :--- | :--- | :--- | :--- |
| **A — "everything free", accepted risk.** Supabase Free + Cloudflare Pages Free + CF DNS/SSL + GSC + GA4 | **$0** | 2 renewals (**UNKNOWN**) | **$0 + domain renewals.** Risks accepted: project **pauses after ~1 week inactivity** (an availability failure for anything but an actively-trafficked site), and a hard **~11k first-visit pageviews/mo** egress ceiling |
| **B — recommended.** Supabase **Pro** + Cloudflare Pages Free + DNS/SSL + GSC + GA4 | **~$300** | 2 renewals (**UNKNOWN**) | **≈ $300/yr + 2 domain renewals (UNKNOWN) ≈ $300–360/yr before domains**, or **≈ $354/yr** if 18% GST applies |
| **C — everything paid** (Pro + Pages Pro + email) | ~$540 | + 2 domains + email | **not recommended** — Pages Pro buys nothing here |

**Labelled exclusions from every row above:** domain registration/renewal for both domains
(prices UNKNOWN, one TLD unknown), **GST/taxes** if the billing jurisdiction applies them, **any
overage** (Supabase egress beyond the Pro allowance, additional storage, extra media objects),
**email** for the three published `bharattechpulse.in` mailboxes, and **all third-party tools**
(not used: no Sentry, no Plausible, no CI runner beyond Cloudflare's own builds, no image-resize
service, no Lighthouse/monitoring budget). Also excluded: developer time and the one-off cost of
self-hosting CanvasKit/fonts, which is measured in minutes, not money.

---

## 8. Consolidated findings register

| # | Finding | Where | Tag | Sev |
| :--- | :--- | :--- | :--- | :--- |
| 1 | No production artifact can be built: `tool/live_checks/.env` absent → anon key unobtainable; `build_production.ps1` refuses by design (`:76-96,100-103`). Re-verified at 11:53 — only the `.env.example` template exists, and it has not been copied. | `tool/live_checks/` (dir listing), `tool/build_production.ps1:76-103` | **BLOCKED** | **P0** |
| 2 | Intended production domain unregistered; Pages project/DNS/SSL unverifiable; GSC unverifiable; sitemap/robots/canonicals all point at a non-resolving origin. First admin also still absent (`auth.users = 0`) — the operator SQL now exists but has not been run. | `lib/app/config/site_config.dart:6`, `web/robots.txt:6`, `web/sitemap.xml` (30 locs), `supabase/operator/010_bootstrap_first_admin.sql` | **BLOCKED** | **P0** |
| 3 | The only bundle on disk is a **debug, unminified, mock** build: `main.dart.js` 12,927,991 B / 257,324 lines, `Aravind Sharma`=1, `placeholder-project`=2, 27 Unsplash URLs, 0 project ref. Not deployable. | `build/web/main.dart.js` (measured) | **FAIL** | **P1** |
| 4 | CanvasKit (~2.94 MB gz) loads from `https://www.gstatic.com/flutter-canvaskit/<rev>` because `useLocalCanvasKit` is never set; the local 37.6 MB `canvaskit/` is never read | `build/web/flutter_bootstrap.js` (`E()` logic; `:36` buildConfig; `:38-42` invocation) | **FAIL** | **P1** |
| 5 | `google_fonts` fetches Inter + Outfit at runtime from `fonts.gstatic.com`; no font assets are bundled | `pubspec.yaml` (google_fonts ^8.2.1, `assets:`/`fonts:` commented out at `:60-95`), `lib/app/theme/theme_text.dart:11,14-107` | **FAIL** | **P2** |
| 6 | Admin authorization is client-side absent: middleware checks only `isLoggedIn`+`isActive`; `canManageSettings`/`canDeleteRecords`/`canPublish`/`hasSiteAccess` have **zero** production callers; only `canViewReports` is used | `lib/app/middleware/admin_auth_middleware.dart:17-25`, `lib/core/supabase/role_permissions.dart:32-73`, `lib/data/repositories/supabase_analytics_repository.dart:110` | **PARTIAL** (mitigated by RLS, which is unverified) | **P1** |
| 7 | Logout is not atomic: a failed `signOut()` is swallowed, `_reset()` clears memory only, the persisted session survives and re-authenticates on next cold boot | `lib/features/admin/auth/controllers/admin_auth_controller.dart:103-111`, `:121-130`, `:182-186` | **FAIL** | **P1** |
| 8 | Dormant cross-site hole: `revisions()/nextRevisionNumber()/createRevision()` take a raw `postId` with no site proof; reachable only if a URL `:id` is passed straight through. Currently **no callers**. | `lib/data/repositories/supabase_post_admin_repository.dart:176-232`; interface `lib/data/repositories/post_admin_repository.dart:41,47,51` | **PARTIAL** | **P1 (latent)** |
| 9 | Key guard misses the modern secret format: rejects `service_role` substring but not the `sb_secret_` prefix → a mis-pasted secret key would be bundled | `tool/build_production.ps1:94-96`; `grep sb_secret` → 0 hits | **PARTIAL** | **P2** |
| 10 | Root `.gitignore` lacks general key-material rules: `secrets.json`, `service-account.json`, `*.pem`, `*.key`, `*.p12`, `*.jks` are **not ignored** at the repo root | `.gitignore` vs `git check-ignore -v` (empty results) | **PARTIAL** | **P2** |
| 11 | No consent mechanism of any kind before the third-party GA4 tag (`googletagmanager.com`) is injected | `lib/core/analytics/ga4_dom_web.dart:20-31`; `grep -rniE 'consent|cookie' lib/` → 1 unrelated hit | **NOT CONFIGURED** (GA inert) / **P2 when enabled** | **P2** |
| 12 | First-party beacon (run-scoped pseudonymous `session_id` + path + post_id) has no consent notice; the privacy page calls it "anonymized" and claims "device screen sizes" that are not collected | `lib/core/analytics/analytics_service.dart:54-56,63-98`, `lib/app/app.dart:43-47`, `lib/features/static_pages/views/privacy_policy_view.dart:42-48` | **PARTIAL** | **P2** |
| 13 | Three published `bharattechpulse.in` mailboxes are unreachable (domain unregistered, no mail configured), including the address for DPDP erasure requests | `lib/app/config/site_config.dart:16-17`, `privacy_policy_view.dart:54`, `web/index.html:75` | **BLOCKED** | **P2** |
| 14 | `web/_headers` and `web/_redirects` were missing at my first listing; **a teammate authored both mid-audit** and the cache/routing/security-header policy is now correct and well-reasoned (HSTS without `includeSubDomains`, no `immutable` on un-hashed artifacts, CSP report-only) | `web/_headers`, `web/_redirects` (read in full); `git status` shows them untracked (`??`) | **PASS — LOCAL VERIFIED**; live Pages behaviour **UNVERIFIED** | ~~P2~~ **closed** (residual: CSP enforces nothing yet — **P3**) |
| 15 | Unhashed artifacts + a service worker whose entire job is to unregister itself (`815 B`, `install→skipWaiting`, `activate→unregister`) → no precache, no offline. **Now mitigated by `_headers` revalidation, not by the SW.** | `build/web/flutter_service_worker.js`, `build/web/flutter_bootstrap.js:40`, `web/_headers` §3 | **PARTIAL** (documented and mitigated; deploy effect UNVERIFIED) | **P3** |
| 16 | GA looked unwired at my first read; **both enable switches were added mid-audit and I re-verified each against the current tree.** (a) build-time: `build_production.ps1` reads `gaMeasurementId` (`:62-63`), reports presence (`:84`), documents it (`:118-119`) and passes `--dart-define=GA_MEASUREMENT_ID` **conditionally** (`:156-157`); (b) DB runtime: `configureGa()` is called from `lib/main.dart:67` inside `_applyDatabaseGaId()` (`:64-71`), fired unawaited by `main()` at `:93`. So `site_settings.google_analytics_id` is a **live control path, not dead code**, and the admin SEO field (`admin_seo_controller.dart:48,73`) does have an effect. GA is `NOT CONFIGURED` (no id exists in DB or any build), **not broken** | `lib/core/analytics/analytics_service.dart:22-23,36,45-52,48`, `lib/main.dart:64-71,93`, `tool/build_production.ps1:62-63,84,156-157` | ~~**FAIL**~~ → **PASS — LOCAL VERIFIED** (wiring); **NOT CONFIGURED** (no id). My original "zero callers" grep was correct *at the time it ran*; the wiring landed minutes later | **P3 residual**: `ga4_dom_web.dart:20-27` emits an **inline** gtag script, which forces `script-src 'unsafe-inline'` (`_headers:75,287-298`) — a security prerequisite for CSP promotion, paired with #18 (§5.2) |
| 17 | Seeded live DB has `google_analytics_id` empty and no logo/favicon — correctly absent, not broken | live state (given); `supabase/migrations/001_initial_schema.sql:230` | **NOT CONFIGURED** | **P3** |
| 18 | localStorage JWT tokens are readable by XSS/extensions (inherent to SPA + public anon key); undocumented in any `docs/` | `lib/core/supabase/supabase_service.dart:19-27` | **PARTIAL** (bounded by RLS) | **P2** |
| 19 | Prerendered HTML bakes the live project ref into shipped files → contradicts README §9's `ref → 0` marker (which only ever measured `main.dart.js`) | `build/web/article/choose-right-ai-tool-honest-framework/index.html` (3 hits) | **PASS — LOCAL VERIFIED** (public config, not a secret) | **P3** |
| 20 | `AdminAuthController` rehydrates `isLoggedIn` synchronously before the profile round-trip; bounded, documented, self-correcting | `admin_auth_controller.dart:116-130`, `initial_binding.dart:125` | **PASS — LOCAL VERIFIED** (accepted trade-off) | **P3** |
| 21 | No client-side login throttle (left to gotrue rate limiting; `too_many_requests` is mapped) | `admin_auth_controller.dart:71-101`, `auth_service.dart:73-77` | **PASS** | **P3** |
| 22 | **Positive:** zero real credentials anywhere in repo, git-tracked files, or `build/web`; no `service_role` key exists; nothing needs rotation | §1 | **PASS — LOCAL VERIFIED** | — |
| 23 | **Positive:** all 14 admin routes guarded, exactly one deliberate exception (`/admin/login`); no signup path in the client | `app_pages.dart:225-332` | **PASS — LOCAL VERIFIED** | — |
| 24 | **Positive:** media storage keys derive the site prefix from a compile-time constant; filename sanitisation rejects `.`/`..` and strips `/` and `\` → no traversal | `supabase_media_repository.dart:46,112-122` | **PASS — LOCAL VERIFIED** | — |
| 25 | **Positive:** no `.rpc()` in `lib/`; `publish_scheduled_posts()` is server/pg_cron-only | `grep -rn '\.rpc(' lib/` → 0 | **PASS — LOCAL VERIFIED** | — |
| 26 | **Positive:** no `AssetManifest.json` leak; manifests expose only 2 font asset paths | §6.4 | **PASS — LOCAL VERIFIED** | — |
| 27 | **Positive:** credential tooling prints presence/length only and redacts JWTs to `sha256:` fingerprints | `build_production.ps1:78-96`, `live_checks/lib/config.js:144-166`, `deploy_cloudflare.ps1:87,123-124` | **PASS — LOCAL VERIFIED** | — |
| 28 | `india_travel_web` (read-only sibling) untouched: `git status --porcelain` → **0 lines**, `git stash list` → 0, HEAD `81e4bf9` | `git -C …/india_travel_web` | **PASS — LOCAL VERIFIED** | — |
| 29 | Documentation drift against reality in `README.md` (+1 minor contradiction in `003`) | §9 | **PARTIAL / FAIL** | **P3** |
| 30 | **Positive:** first-admin operator SQL carries no secret and confirms `profiles`/`profile_sites` have **no write policy at all** → self-promotion via the API is impossible, which is what makes finding #6 a defense-in-depth gap rather than an escalation | `supabase/operator/010_bootstrap_first_admin.sql:7-14,38`; `grep -niE 'password\|secret\|eyJ\|token\|api_key'` → prose only | **PASS — LOCAL VERIFIED** | — |
| 31 | **Positive:** `tool/live_checks/.env.example` is a template, not a credential, correctly un-ignored via `.gitignore:15:!.env.example`, and documents *why* a `service_role` key would void every RLS assertion | `tool/live_checks/.env.example`, `tool/live_checks/.gitignore:12-15` | **PASS — LOCAL VERIFIED** | — |

---

## 9. Documentation corrections — patch-ready (I did NOT edit `README.md`)

`README.md` is owned by a teammate. **Note first: the two defects named in my brief have already
been fixed while I worked** — §8 is now titled *"Data Source: Mock vs Supabase (Production Wiring)"*
(`README.md:228`, no longer "Future Supabase Integration (Phase 2 Preparation)"), §9 now claims
**62** tests (`:284-286`, no longer "13 / 13"), and the build command now points at
`tool\build_production.ps1` (`:44`, `:274`). I verified each of those against the tree rather than
re-reporting them.

Verified-correct, leave as-is:
- `README.md:284` "**62** tests (the 49 pre-existing … plus 13 new Phase 1 tests)" — **confirmed
  by counting**: `controllers_test 4 + models_test 3 + production_data_source_test 13 +
  repositories_test 4 + supabase_cms_mapping_test 22 + supabase_mapping_test 14 +
  widget_test 2 = 62`.
- `README.md:289-296` marker/size table — the 12,927,991 B dev-debug row matches my own measurement
  exactly; `placeholder-project` 1→2 and `images.unsplash.com` 28→27 differ slightly from my counts
  (they are line-count vs occurrence-count, and the file was regenerated mid-audit). Not a defect;
  re-derive the table after the final build.
- `README.md:263-266` (anon key is public; never `service_role`) and `:163-165` (middleware is UX
  gating only) — **both accurate and worth keeping verbatim.**
- `supabase/README.md` §"Secrets policy" and the migration table (001→008, forward-only) are
  **accurate against the tree**; `web/sitemap.xml` (15 article `<loc>`) matches the 15 published
  seed posts and the 15 prerender shells.

### Patches for `README.md`

**P1 — after `README.md:50` (the §3 blockquote), add an explicit non-deployability warning.**
`build/web` as it sits is a debug mock artifact, and §3's table otherwise invites someone to
upload it:

> **Do not deploy `build/web` as it currently sits.** The bundle on disk is a dev `--debug` build
> (12,927,991 B, unminified) carrying mock fixtures and 27 `images.unsplash.com` hotlinks. Only a
> `tool/build_production.ps1` output — `ENV=production` + `DATA_SOURCE=supabase` + a real
> publishable key — is deployable, and `tool/deploy_cloudflare.ps1` refuses anything else.

**P2 — `README.md:3`** (sub-heading). Currently:
> Built with **Flutter Web 3.44.6**, **FVM**, **GetX**, and **Material 3**. Engineered for …
> **ready for future Supabase multi-tenant scaling**.

Replace the last clause — "future" contradicts §8 and the applied-and-verified backend:
> … and **wired to a live Supabase multi-tenant backend (migrations 001–008 applied and verified on
> project `ylzwuwfhlqomjqcdrpxk`)**.

**P3 — `README.md:21`.** Currently: *"Managed strictly via FVM (`.fvm/fvm_config.json`)."* `.fvm/`
is gitignored (`.gitignore:49`), so a fresh clone has no `fvm_config.json`; the tracked source of
truth is `.fvmrc` (= `{"flutter":"3.44.6"}`). Change to:
> Managed strictly via **FVM**. The committed pin is `.fvmrc` (`"flutter": "3.44.6"`);
> `.fvm/fvm_config.json` is a generated, git-ignored local cache.

**P4 — `README.md:122-126` (§4 `test/` block).** It lists 4 of the 7 test files. Replace with:

```
├── test/
│   ├── models_test.dart                 # JSON serialization & entity tests (3)
│   ├── repositories_test.dart           # In-memory CRUD & filter tests (4)
│   ├── controllers_test.dart            # GetX controllers & theme toggle tests (4)
│   ├── widget_test.dart                 # App bootstrap & reactive theme tests (2)
│   ├── supabase_mapping_test.dart       # Row↔model mapping + RolePermissions matrix (14)
│   ├── supabase_cms_mapping_test.dart   # CMS/admin mapping + effective-role resolution (22)
│   └── production_data_source_test.dart # Production data-source guard (13)
```

**P5 — `README.md:56-128` (§4 tree).** The tree omits three tracked, load-bearing directories.
Insert after the `web/` block:

```
├── supabase/
│   ├── migrations/                      # 001 → 008, forward-only once applied
│   ├── functions/                       # Edge: generate-sitemap, scheduled-publishing
│   └── README.md                        # Backend layout, RLS matrix, secrets policy
├── tool/
│   ├── build_production.ps1             # Guarded production build (refuses mock)
│   ├── deploy_cloudflare.ps1            # Pages deploy plan/execute + bundle gate
│   ├── generate_prerender.dart          # Per-article/category HTML shells (run AFTER build)
│   ├── make_seed_media.py               # Generates the gitignored .seed_media/ artwork
│   └── live_checks/                     # Node RLS/schema/seed suite; reads gitignored .env
└── docs/
```

**P6 — `README.md:298-302` (§9 tail).** Add, so the ref rule is stated accurately:

> **Note on the project ref in shipped HTML.** `ylzwuwfhlqomjqcdrpxk → 0` above is a
> `main.dart.js`-only marker. The prerendered article/category shells deliberately embed absolute
> `…ylzwuwfhlqomjqcdrpxk.supabase.co/storage/…` image URLs, so the ref **does** appear in deployed
> HTML. That is expected and safe: the ref is public client configuration, and the same URL ships
> in every production bundle via `--dart-define`. The invariant is *"no service-role key, secret
> key or database password in the bundle"*, not *"no ref in the bundle"*. The `lib/` rule (zero
> occurrences of the ref in `lib/**`) still holds and is what keeps mock builds ref-free.

**P7 — `README.md:253-261` (§8 production command).** Add the two optional build-time keys, since
both are read via `String.fromEnvironment` and neither appears in any script today:

```
  --dart-define=GA_MEASUREMENT_ID=G-XXXXXXXXXX \
  --dart-define=GOOGLE_SITE_VERIFICATION=<token>
```
with one line each, and both now need correcting against §5.2: `GA_MEASUREMENT_ID` is the
**build-time** switch — `configureGa()` *is* called (`lib/main.dart:67`, fired unawaited at `:93`),
so `site_settings.google_analytics_id` is a second, runtime switch and the build-time value wins when
both are set (`analytics_service.dart:36,48`); and enabling GA4 **requires** a consent mechanism first
(finding 11) **plus** the CSP note below. If `README.md:253-261` already lists these two flags, verify
the accompanying prose does not describe `GA_MEASUREMENT_ID` as the only route.

**P8 — `README.md:155-177` (§5 Admin Routes).** The blockquote at `:159-165` is inserted between
`/admin/dashboard` and `/admin/articles`, which splits the bullet list into two lists in rendered
Markdown and detaches the 12 route entries from their heading. Move the blockquote to after `:177`.

**P9 — `README.md:94`.** `MockDataSource (21+ authentic Indian stories)` — the number is soft and
not worth a defect, but the tree's own §4 now enumerates test files precisely; consider
"(~24 mock articles; the live seed has 24 posts)" so mock and DB counts are not confused.

### One-line corrections outside `README.md`

| File | Line | Issue | Suggested fix |
| :--- | :--- | :--- | :--- |
| `supabase/migrations/003_rls_policies.sql` | `:100-102` | Comment asserts "signup defaults `profiles.role` to `'author'`, and **any registrant therefore passes a naive `is_staff()` read**". But `is_staff()` (`002:215-229`) requires an **active `profile_sites` row**, so a bare registrant does *not* pass it. The caveat overstates the risk and contradicts the function it cites. | "…a bare registrant passes `is_staff()` **only if** a `profile_sites` membership row exists; `profiles.role='author'` alone grants nothing." |
| `supabase/README.md` | `:37` | "the remote project is applied and verified by the **project owner only**" — accurate, but nothing states that 001–008 **are** applied, which the brief's verified state asserts. `:19-25` does say live-and-verified, so this is only a cross-reference gap. | Add "(001–008 are applied and verified remotely; this chain is forward-only)" to the "How to apply" heading. |
| `supabase/README.md` | `:31-35` | "If stale files (`004_seed_data.sql`, `005_functions.sql`) are still present …" — neither exists in the tree (`supabase/migrations/` holds exactly 001–008). Guard is harmless but reads as a live hazard. | "…are **no longer** present in this repo; the note is only for older clones." |
| `web/index.html` | `:54-56` | Comment offers deploy-time "Cloudflare Pages env/replacement" as an option for the site-verification token. **Cloudflare Pages does not substitute placeholders inside HTML at serve time**; that path will silently leave the meta empty. | Restrict the advice to the documented build-time dart-define route. |
| `docs/DEPLOYMENT.md` | — | **Does not exist** (there was no `docs/` directory at all before this audit). Any prior reference to it is stale, and the deployment runbook — Pages project, custom domain, `_headers`/`_redirects` content, DNS, plan/billing state — is **undocumented**. | Owed by the deploy/relaunch teammate; §6.5 and §7 of this file list what it must cover. |

---

## 10. Status tags by task

| Task | Status |
| :--- | :--- |
| 1. Credential & secret hygiene (repo + `build/web`) | **PASS — LOCAL VERIFIED** (no real credential; no `service_role` key exists; ref + anon key are public client config). One P2 guard gap (`sb_secret_` unrecognised). |
| 2. `.gitignore` / tracked-secrets | **PASS — LOCAL VERIFIED** for `.env`, `tool/live_checks/.env`, `.seed_media/`, `build/`; **PARTIAL** for general key-material patterns (P2). No secret-bearing file tracked. |
| 3. Cross-site isolation (code side) | **PASS — LOCAL VERIFIED** for every path the app can currently execute; **PARTIAL** for the dormant `post_revisions` APIs (P1 latent). DB-side confirmation **BLOCKED** (needs live SQL). |
| 4. Client auth/authz | **PARTIAL / FAIL** — authentication complete, **authorization client-side absent** (P1, conditional on live signup state = **UNVERIFIED**); **logout not atomic** (P1). Session-restore and `unknownRoute` are fine. |
| 5. Consent / analytics | **NOT CONFIGURED** (GA4 empty in DB **and** unwired) + **PARTIAL** (first-party beacon live, no consent gate) — P2 forward-looking, P3 today. |
| 6. Asset / bundle audit | **FAIL** — artifact is a debug mock build. Size, hosts, manifests and wire cost all measured; **P1** third-party CanvasKit origin, **P2** third-party fonts, missing `_headers`. |
| 7. Cost model | **ASSUMPTION-bound** — ≈ **$300/yr + 2 domain renewals (UNKNOWN)**. Live plan of both accounts **UNVERIFIED** (billing pages inaccessible). |
| 8. Documentation accuracy | **PARTIAL** — the two named defects were fixed before I reported; **9 README patches + 5 one-line corrections** in §9. `docs/DEPLOYMENT.md` does not exist. |
| Sibling repo | `india_travel_web` **PASS — LOCAL VERIFIED untouched** (`git status --porcelain` → 0 lines, 0 stashes, HEAD `81e4bf9`). |

---

## 11. What would unblock the remaining items

| Item | Access that resolves it | Who |
| :--- | :--- | :--- |
| P0 #1 — no production build | The owner pastes the **publishable/anon** key into `tool/live_checks/.env` (gitignored; deliberately kept out of chat transcripts), then runs `tool/build_production.ps1` | owner + build agent |
| P0 #2 — domain, Pages project, DNS/SSL | Registrar access (register `bharattechpulse.in`, discover/decide the **second domain's TLD**) + Cloudflare dashboard (zone, Pages project existence, certificate status) | owner + deploy agent |
| P1 #3, #4, #6, #7 — final bundle verification, live RLS backstop for admin routes, revision-API safety | A **fresh production build** plus a browser/live project to exercise `/admin` as a zero-membership account | build agent + `auth-live` |
| P1 #8 — `post_revisions` site isolation | `SELECT polname, pg_get_expr(polqual,…) FROM pg_policy WHERE polrelid='public.post_revisions'::regclass` against the live DB | `auth-live` (DB-side reviewer) |
| P2 #9 — whether unguarded `/admin` is actually reachable | Supabase dashboard → Authentication → Providers: is **public sign-up enabled**? any allowlist/SMTP gate? | owner / `auth-live` |
| P2 #18 — plan/billing, egress headroom, and whether "Free" is even the current plan | Supabase **Billing** page and Cloudflare **Billing/Subscription** page (both beyond my access) | owner |
| P2 #13 — dead mailboxes | Registrar/Cloudflare/ZoneMate access to create Email Routing or mailboxes, or remove the addresses from the published pages | owner |
| P3 #16 / §5.2 — GA go-live | A real `G-XXXXXXXXXX` measurement ID **plus** a decision on the consent UI, before any dart-define is set | owner |
| §7.2 — every **ASSUMPTION** price, and both domain **UNKNOWN**s | The vendors' pricing pages + a registrar checkout (browsing was out of bounds for me) | owner |
| §6.5, #14 — cacheability and SPA deep links | The content of `web/_headers` and `web/_redirects` (neither file exists yet) and a live `pages.dev` response-header check | deploy agent + `auth-live` |
