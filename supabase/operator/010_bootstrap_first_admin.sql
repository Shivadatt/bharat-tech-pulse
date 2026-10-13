-- ============================================================================
--  supabase/operator/010_bootstrap_first_admin.sql
--
--  Bharat Tech Pulse — grant the FIRST admin / super_admin to an existing Auth user.
--
--  WHY THIS FILE EXISTS
--    * profiles.role defaults to 'author' on signup (001_initial_schema.sql), and
--      NEITHER public.profiles NOR public.profile_sites has any INSERT/UPDATE/
--      DELETE policy (verified live in pg_policies: profiles has
--      profiles_select_own + profiles_select_super_admin only; profile_sites has
--      profile_sites_select_own + profile_sites_select_super_admin only).
--      That is deliberate — it makes self-promotion impossible through the API —
--      and it means the FIRST admin can only be created by a SQL operator.
--      This file is that operator path.
--    * It is intentionally NOT in supabase/migrations/: it is per-person,
--      per-environment operator SQL and must never run automatically on a deploy.
--
--  WHAT IT DOES
--    1. guards: the Auth user must already exist (it does NOT create one),
--       the site must exist, the roles must be legal for this model;
--    2. upserts public.profiles       (global tier, normally super_admin),
--    3. upserts public.profile_sites  (per-site tier: admin | editor | author),
--    4. prints a verification SELECT read back from the database.
--
--  HOW TO RUN
--    1. Dashboard -> Authentication -> Users -> "Add user": create the account
--       (email/password). Tick "auto confirm" only if that is what you want.
--       The on_auth_user_created trigger (public.handle_new_user()) creates the
--       public.profiles row with role='author' automatically.
--    2. Dashboard -> SQL Editor (as the project owner): edit ONLY the parameter
--       block inside the DO statement below, paste the WHOLE file, Run.
--       All statements execute in one session, which the file relies on to hand
--       the resolved user id to the verification query.
--    3. Read the verification table. It is idempotent: re-running with the same
--       values changes nothing and prints the same rows.
--
--  SAFETY
--    * No secrets, passwords or API keys appear in this file.
--    * It never touches auth.users credentials, never changes RLS/policies,
--      never deletes anything, and writes at most the two rows it grants.
--    * If a precondition is unmet it aborts with RAISE EXCEPTION and writes
--      nothing (the DO block and the grants are one atomic statement).
--    * To revoke later, use the commented block at the bottom.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1..3  GUARD + GRANT.  >>> EDIT ONLY THESE 5 PARAMETER LINES <<<
-- ---------------------------------------------------------------------------
do $$
declare
  -- the exact email of the Auth user from step 1 (matched case-insensitively)
  p_email        text        := 'REPLACE_ME_owner@example.com';
  -- display name; '' keeps whatever handle_new_user() already stored
  p_full_name    text        := '';
  -- seeded Bharat Tech Pulse site (slug 'india_tech'), verified live in public.sites
  p_site_id      uuid        := '00000000-0000-4000-8000-000000000001';
  -- per-site tier: 'admin' | 'editor' | 'author'   (NEVER 'super_admin')
  p_site_role    public.app_role := 'admin';
  -- global tier: 'super_admin' for the platform owner, else 'author'
  p_global_role  public.app_role := 'super_admin';

  v_uid   uuid;
  v_email text;
begin
  -- ---- 0. parameters actually filled in? -----------------------------------
  if p_email is null or btrim(p_email) = '' then
    raise exception 'ABORT: p_email is empty.';
  end if;
  if p_email = 'REPLACE_ME_owner@example.com' then
    raise exception 'ABORT: p_email is still the placeholder — edit the parameter block first.';
  end if;

  -- ---- 1. role values legal for this model? --------------------------------
  -- profile_sites_role_check forbids super_admin on the per-site row.
  if p_site_role = 'super_admin' then
    raise exception
      'ABORT: profile_sites.role cannot be super_admin (CHECK constraint '
      'profile_sites_role_check). Use admin / editor / author; super_admin is a '
      'GLOBAL tier that lives on profiles.role.';
  end if;

  -- ---- 2. the Auth user must already exist ---------------------------------
  select u.id, u.email into v_uid, v_email
  from auth.users u
  where lower(u.email) = lower(p_email)
    and u.deleted_at is null
  limit 1;

  if v_uid is null then
    raise exception
      'ABORT: no auth user matches that email (case-insensitive, soft-deleted '
      'users ignored). Create it first in Authentication -> Users -> "Add user"; '
      'this script never creates Auth users.';
  end if;

  -- ---- 3. the site must exist ----------------------------------------------
  if not exists (select 1 from public.sites s where s.id = p_site_id) then
    raise exception 'ABORT: site % is not present in public.sites.', p_site_id;
  end if;

  -- ---- 4. global tier: profiles (upsert; the trigger usually created it) ----
  insert into public.profiles as p
        (id, email, full_name, role, is_active, updated_at)
  values (
    v_uid,
    v_email,
    nullif(btrim(p_full_name), ''),
    p_global_role,
    true,
    now()
  )
  on conflict (id) do update
     set role            = excluded.role,
         is_active       = true,
         email           = coalesce(excluded.email, p.email),
         -- an empty p_full_name must not wipe a name the signup already set
         full_name       = coalesce(excluded.full_name, p.full_name),
         updated_at      = now();

  -- ---- 5. per-site membership: profile_sites (upsert) ----------------------
  insert into public.profile_sites as ps
        (profile_id, site_id, role, is_active, updated_at)
  values (v_uid, p_site_id, p_site_role, true, now())
  on conflict (profile_id, site_id) do update
     set role        = excluded.role,
         is_active   = true,
         updated_at  = now();

  -- hand the resolved id to the verification query (session setting, no secret)
  perform set_config('bootstrap.auth_uid', v_uid::text, false);

  raise notice 'BOOTSTRAP OK: uid=% global_role=% site=% site_role=%',
    v_uid, p_global_role, p_site_id, p_site_role;
end
$$;

-- ---------------------------------------------------------------------------
-- 4. VERIFICATION — read straight back from the database.
--    Shows the promoted account only; if the session setting above did not
--    survive, it falls back to listing every super_admin profile, so it can
--    never silently print "nothing to see".
-- ---------------------------------------------------------------------------
select
  u.id                                          as auth_user_id,
  (u.email is not null)                         as auth_email_present,
  (u.is_sso_user)                               as is_sso_user,
  (coalesce(u.banned_until is not null, false)) as banned,
  (u.deleted_at is not null)                    as soft_deleted,
  (u.email_confirmed_at is not null
   or u.confirmed_at is not null)               as email_confirmed,
  p.role                                        as global_role,
  p.is_active                                   as profile_active,
  p.full_name                                   as profile_full_name,
  s.slug                                        as site_slug,
  s.is_active                                   as site_active,
  ps.role                                       as site_role,
  ps.is_active                                  as site_membership_active,
  now()                                         as verified_at
from auth.users u
join public.profiles      p  on p.id = u.id
left join public.profile_sites ps on ps.profile_id = u.id
left join public.sites    s  on s.id = ps.site_id
where u.id = nullif(current_setting('bootstrap.auth_uid', true), '')::uuid
   or p.role = 'super_admin'
order by u.id, s.slug;

-- Every staff member currently in the system (spot-check the total):
select 'staff rows: profiles=' ||
        (select count(*) from public.profiles where role = 'super_admin')::text ||
       ' | memberships=' ||
        (select count(*) from public.profile_sites where is_active)::text ||
       ' | auth.users=' || (select count(*) from auth.users)::text
       as roster;

-- ---------------------------------------------------------------------------
-- 5. OPTIONAL (read-only) — prove the RLS helpers resolve for THAT account.
--    Runs entirely in one statement: auth.uid() reads the request.jwt.claims
--    GUC, so seeding it makes the helpers evaluate as the promoted user would.
--    Nothing is written; the claim is cleared in the same statement.
--    Replace <AUTH_USER_ID> with the id printed by the verification table.
--
-- select public.is_staff() as is_staff,
--        public.is_editor_up() as is_editor_up,
--        public.is_super_admin() as is_super_admin,
--        public.site_role('00000000-0000-4000-8000-000000000001'::uuid) as site_role,
--        auth.uid() as resolved_uid
-- from (select set_config('request.jwt.claims',
--        '{"sub":"<AUTH_USER_ID>","role":"authenticated"}', false)) as seed;
--
-- ALWAYS clear it afterwards in the same session (this is verified to work):
--   select set_config('request.jwt.claims', '', false);
--
-- Expected for the first admin: is_staff = true, is_editor_up = true,
-- is_super_admin = true, site_role = admin, resolved_uid = <AUTH_USER_ID>.
-- This is corroboration, not proof of the login path: the authoritative check
-- is a real sign-in plus tool/live_checks (needs the publishable key).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- REVOKE / DEMOTE (only when asked; uncomment to run)
--   -- take away the site membership (keeps the login usable for reading own profile)
--   update public.profile_sites set is_active = false, updated_at = now()
--    where profile_id = '<AUTH_USER_ID>'::uuid
--      and site_id    = '00000000-0000-4000-8000-000000000001'::uuid;
--   -- drop the global tier back to the inert default
--   update public.profiles set role = 'author', updated_at = now()
--    where id = '<AUTH_USER_ID>'::uuid;
-- Deactivating a site instead (hides its public surfaces):
--   update public.sites set is_active = false, updated_at = now() where slug = 'india_tech';
-- ---------------------------------------------------------------------------
