# live_checks — live Supabase verification harness

Offline self-test (no credentials, 127.0.0.1 mock only): `node selftest_mock.js` — must exit 0.

## Environment variables
Required (either source; resolution order: real env → `.env` → Dart config defaults):
- `SUPABASE_URL`         project URL, e.g. `https://<ref>.supabase.co`
- `SUPABASE_ANON_KEY`    the PUBLISHABLE/anon key ONLY (never service_role)

Optional (checks degrade to SKIP, never crash, without them):
- `SUPABASE_ADMIN_TOKEN`      access token of a staff account (super_admin or site admin/editor of india_tech)
- `SUPABASE_READER_TOKEN`     access token of an account with NO `profile_sites` row (else throwaway signup is attempted)
- `SUPABASE_SITE_ADMIN_TOKEN` token of an india_tech-only admin/editor (strict cross-site isolation probe)
- `CHECK_SECOND_SITE_SLUG`    a throwaway second site; must match `zzz-check*` (anything else is rejected)
- `ALLOW_THROWAWAY_SIGNUP=0`  disable the ephemeral reader-signup fallback

## Credentials file
Create a git-ignored `tool/live_checks/.env` (already covered by `.gitignore`):
```
SUPABASE_URL=https://<ref>.supabase.co
SUPABASE_ANON_KEY=<publishable key>
SUPABASE_ADMIN_TOKEN=<optional>
```
Keys are only ever printed as `sha256:<first8>` fingerprints.

## Commands
```
node schema_report.js     # 14-table presence + anon visibility matrix
node rls_matrix.js        # negative/positive security suite (planes A–G)
node run_all.js           # orchestrates schema + seed_counts + rls (also --strict, --only schema|seed|rls)
```
Exit 0 = nothing failed; unapplied/empty DB reports `NOT APPLIED YET` and exits 0 (use `--strict` in CI).

## What each plane proves (rls_matrix)
- A anon reads: published/due-scheduled posts + public taxonomy only.
- B anon blocked from staff-only tables (subscribers, revisions, analytics, profiles, profile_sites).
- C anon INSERT/UPDATE/DELETE are rejected (403/42501 or 0 rows, never silent success).
- D the two constrained public writes (subscribers, analytics_events) work; WITH-CHECK smuggling (is_verified, bad email, unsubscribed_at, is_active=false, bogus event_type) is rejected.
- E authenticated plain reader: sees own profile only, gains nothing (drafts/writes/storage all denied), self-promotion and role minting blocked; public-form rights survive sign-in.
- F staff plane (needs `SUPABASE_ADMIN_TOKEN`): editor+ reads drafts/archived/scheduled, throwaway CRUD on `zzz-check-` fixtures, `sites`/`profiles.role`/`profile_sites` closed to the API, cross-site isolation via a `zzz-check*` second site.
- G storage plane: public read works; anon and non-editor uploads rejected; editor upload only under `india_tech/`, signed URLs, throwaway object deleted.

## What stays SKIPped without real authenticated tokens
Without `SUPABASE_ADMIN_TOKEN`: staff counts in seed_counts, planes D1/F1–F13/G3–G6, cleanup of accepted throwaways.
Without `SUPABASE_READER_TOKEN` (and signup disabled/failed): plane E.
Without `SUPABASE_SITE_ADMIN_TOKEN`/`CHECK_SECOND_SITE_SLUG`: strict cross-site F13.

## Admin/bootstrap prerequisite for the staff planes
The token account must already exist in `auth.users` with a `public.profiles` row (role super_admin) AND a `public.profile_sites` row (admin/editor on india_tech, is_active) — these are SQL-operator-created (no API write path by design). Until then F-plane checks SKIP or fail on membership.

## Safety rails (tested by selftest_mock)
Writes only to `india_tech` throwaways (`zzz-check-` prefix) or `zzz-check*` sites; travel/production siblings hard-blocked; every DELETE requires exact-row `=eq.` filters; all fixtures removed via the cleanup registry (runs even on crash).
