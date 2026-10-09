# Supabase Backend — Bharat Tech Pulse

Production backend for the Bharat Tech Pulse Flutter app
(project ref: `ylzwuwfhlqomjqcdrpxk`, URL: `https://ylzwuwfhlqomjqcdrpxk.supabase.co`).
The workspace is multi-site: `india_tech` is site #1 and sibling sites share this
backend through the `sites` table and per-site role memberships.

## Migration layout — apply strictly in numeric order 001 → 006

| Order | File | Contents |
|-------|------|----------|
| 001 | `001_initial_schema.sql` | Extensions, enums, **14 tables** (incl. `profile_sites`), indexes, `set_updated_at()`, `handle_new_user()` profile auto-creation |
| 002 | `002_auth_and_roles.sql` | Role helper functions: `is_super_admin()`, `site_role(uuid)`, `is_site_member(uuid)`, `is_site_editor(uuid)`, `is_site_admin(uuid)`, `is_staff()`, `is_editor_up()`, `is_admin_up()`, `current_profile()`, `is_linked_author(uuid)`, `can_edit_post(uuid)` — all `stable security definer set search_path = public` |
| 003 | `003_rls_policies.sql` | RLS enable + all policies for the 14 tables. Top-of-file comment carries the authoritative table × role × operation access matrix |
| 004 | `004_storage_policies.sql` | `media` bucket (public read, 10 MB cap, image MIME allowlist) + storage object policies. Idempotent (drop-then-create) |
| 005 | `005_functions.sql` | Scheduled-publishing helper `publish_scheduled_posts()` and its lock-down |
| 006 | `006_seed_data.sql` | Site row `india_tech`, 8 categories, 4 unlinked author bylines. **Must run last** (needs tables + policies in place) |

> Numbering note: the seed was renumbered `004_seed_data.sql` → `006_seed_data.sql`
> during the Phase-2 rewrite. If stale files (`004_seed_data.sql`,
> `005_functions.sql`) are still present alongside the new set, do not apply
> them — apply exactly the chain above (001 → 006) and let the schema agent
> (SA1) remove superseded files. Never apply seed data before the policies
> (003/004) exist.

## How to apply

**Option A — Supabase CLI:** `supabase link --project-ref ylzwuwfhlqomjqcdrpxk` then `supabase db push`.

**Option B — Dashboard SQL editor** (`https://supabase.com/dashboard/project/ylzwuwfhlqomjqcdrpxk/sql/new`): paste each file in the order above. All files are written to tolerate re-runs in dev (drop-then-create guards); the remote project is applied and verified by the project owner only.

## The `authenticated` role gotcha (non-negotiable)

A request carrying a valid JWT runs as Postgres role `authenticated`, **not**
`anon`. Every public-read policy is therefore declared `to anon,
authenticated`; any policy limited to `to anon` silently returns **zero rows**
the moment a staff member signs in and breaks the whole site for them. Same
rule for public INSERTs (subscribe form, analytics beacons): a logged-in
reader must be able to submit them too.

## Role model

Two planes, deliberately separated:

- **Global role** — `profiles.role` (`app_role` enum). Only `'super_admin'`
  has meaning here: it is global, bypasses every site check, and sees all
  sites' data. `admin`/`editor`/`author` in `profiles.role` are inert defaults;
  **signup always creates `'author'`, which grants nothing by itself**.
- **Site-scoped role** — `profile_sites(profile_id, site_id, role)` with
  `CHECK (role <> 'super_admin')` and an `is_active` flag. Every staff policy
  in 003 tests the **row's** `site_id` through `is_site_member /
  is_site_editor / is_site_admin(site_id)` — an editor assigned to one site
  can neither read nor write another site's rows.

Tier capabilities within an assigned site:

| Tier | Grants |
|------|--------|
| author (member) | Read own-byline posts (incl. drafts); create **drafts only** under own linked byline; tag/redirect rows needed by the article-save flow; edit own-byline posts |
| editor | + all content management site-wide: posts read/write, categories, tags edit, media + storage writes, revisions, subscriber list, analytics read |
| admin | + deletes (posts/categories/tags/redirects), authors CRUD, `site_settings`, redirects update/delete, subscriber delete |
| super_admin | Everything, on every site |

Anti-privilege-escalation: `profiles` and `profile_sites` have **SELECT-only
policies** — role changes and site assignments are impossible through
PostgREST (including for super_admins); they are executed in SQL by an
operator. There is deliberately no `is_staff()`-style "any profile exists"
read path for drafts/subscribers, because every signup gets an `author`
profile.

## Creating the FIRST admin (bootstrap procedure)

1. Dashboard → **Authentication → Users → Add user** (email/password). The
   `on_auth_user_created` trigger creates a `profiles` row with default role
   `author` — which grants nothing yet.
2. Dashboard → **SQL Editor** — promote to global super_admin:

```sql
update public.profiles
   set role = 'super_admin'
 where email = 'owner@example.com';
```

3. Verify from the API surface: sign in, then
   `select * from public.profiles where id = auth.uid();` must return the row
   with `role = 'super_admin'`.

Super_admin needs no `profile_sites` row. To grant **site-level** roles
(operators only, in SQL):

```sql
insert into public.profile_sites (profile_id, site_id, role)
select p.id, s.id, 'editor'          -- or 'admin' / 'author'
  from public.profiles p
  join public.sites s on s.slug = 'india_tech'
 where p.email = 'editor@example.com'
on conflict (profile_id, site_id)
do update set role = excluded.role, is_active = true;
```

Revoking a membership: `update public.profile_sites set is_active = false
where ...` (never delete, to preserve history).

## Storage expectations

One shared bucket **`media`** (004): public read; 10 MB per-file cap; MIME
allowlist `image/jpeg, png, webp, svg+xml, gif`; enforced as bucket properties.
Object paths are `<site_slug>/<file>` — on this deployment `india_tech/...`,
matching the Flutter upload path in `SupabaseMediaRepository`. Writes/uploads
require `is_site_editor` of the site owning the folder (super_admin passes
automatically), with the top-level folder checked via
`storage.foldername(name)[1]`. `media` DB rows mirror the objects; the app
deletes the row first, then the object.

## Scheduled publishing

`posts.status = 'scheduled'` + `scheduled_for`. 005 provides
`publish_scheduled_posts()` (security definer, locked to `postgres`/service
roles). Schedule via pg_cron after enabling the extension:
`select cron.schedule('publish-due-posts', '* * * * *', $$select public.publish_scheduled_posts()$$);`
Public readers start seeing a scheduled post once `scheduled_for <= now()` —
the RLS public policy mirrors this exactly.

## Secrets policy (non-negotiable)

- `service_role` key, database passwords and JWT secrets live **only** in
  Supabase server-side env vars (Dashboard → Edge Functions → Secrets) or
  Vault. **Never committed to this repo, never shipped to the client.**
- `site_settings` is publicly readable and must **never** contain secrets —
  config-only columns.
- The Flutter app gets **only** the publishable/anon key via `--dart-define`:

```bash
flutter run --dart-define=SUPABASE_URL=https://ylzwuwfhlqomjqcdrpxk.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=<publishable-anon-key>
```

See `lib/app/config/environment_config.dart`.

## Notes for the Flutter client (SA3 / lib/**)

- Client-side `RolePermissions` gating is **UI only**; server RLS is the
  authority and is now site-scoped. The client must treat capabilities as
  per-site: read `profile_sites` (own rows are selectable) alongside the
  global `profiles.role` to decide what the CMS may show for a given site.
- Authors (site role `author`) can create **drafts with their own linked
  byline only**; publish transitions must be presented as editor+ actions.
- Everything else the client already sends (article save: redirects insert,
  revision insert, tag auto-create, post_tags delete+insert; media delete
  order) is covered by 003/004 policies — no payload changes required.
