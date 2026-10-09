-- ============================================================================
-- 002_auth_and_roles.sql
-- Bharat Tech Pulse (site slug: india_tech) — auth bootstrap + authorization
-- helper functions. Owned by SUB-AGENT 1 (database architecture).
-- Must run AFTER 001_initial_schema.sql (and BEFORE the RLS policy migration,
-- which calls these helpers verbatim from policy expressions).
--
-- ─── ROLE MODEL ─────────────────────────────────────────────────────────────
-- * `super_admin` is GLOBAL. It is the ONLY role stored in profiles.role that
--   grants any privilege. A super_admin passes every helper below and can see
--   and edit every site.
-- * Every other role (admin / editor / author) is SITE-SCOPED and lives in
--   public.profile_sites (one row per profile+site, CHECK-excludes
--   'super_admin'). profiles.role defaults to 'author' at signup, which grants
--   NOTHING by itself — an account with the default and no profile_sites row
--   is a regular reader with no write access anywhere.
-- * SELF-PROMOTION IS IMPOSSIBLE: profile_sites writes are restricted to
--   super_admin by the RLS policies (migration owned by the RLS agent), so a
--   site admin/editor can never mint roles for themselves or others. Role
--   changes always require an existing super_admin.
-- * Helper precedence: an inactive profile (profiles.is_active = false) or an
--   inactive assignment (profile_sites.is_active = false) counts as NOTHING,
--   including for super_admin. Deactivation is instant.
--
-- BINDING CONTRACT consumed by the RLS agent — exact signatures defined here:
--   is_super_admin()                       -> boolean
--   site_role(site uuid)                   -> public.app_role (or NULL)
--   is_site_member(site uuid)              -> boolean
--   is_site_editor(site uuid)              -> boolean   (admin or editor)
--   is_site_admin(site uuid)               -> boolean
--   is_staff()                             -> boolean   (any site role)
--   is_editor_up()                         -> boolean   (admin/editor anywhere)
--   is_admin_up()                          -> boolean   (admin anywhere)
--   current_profile()                      -> public.profiles (0..1 row)
--   is_linked_author(author uuid)          -> boolean
--   can_edit_post(post uuid)               -> boolean
-- All are `language sql`, `stable`, `security definer`, `set search_path`.
-- ────────────────────────────────────────────────────────────────────────────
--
-- SECURITY NOTES
-- * Every function pins search_path = public to prevent hijacking.
-- * They are SECURITY DEFINER (owned by the superuser migration role) so RLS
--   on profiles / profile_sites / authors never recurses when a policy on one
--   of those tables calls a helper that reads them.
-- * EXECUTE is revoked from PUBLIC and granted to anon, authenticated,
--   service_role. These functions leak nothing: the boolean checks return only
--   true/false (for anon, auth.uid() IS NULL so they are always false), and
--   current_profile() returns zero rows for anon. This grant model is
--   deliberate: RLS policy expressions execute AS the querying role, so every
--   role a policy can run for must be able to CALL the helper (a missing
--   grant would make guarded queries error, not silently deny).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Profile auto-creation on signup (moved here from 001).
-- SECURITY DEFINER so inserts into public.profiles succeed even before any
-- RLS policy exists. Role defaults to 'author'; promotion is manual only —
-- this function NEVER auto-promotes anyone and NEVER writes profile_sites.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', '')
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
-- Trigger executes it as the definer; only the migration/DDL owner needs to
-- replace it. No client role calls it directly.

-- ----------------------------------------------------------------------------
-- current_profile(): the caller's active-or-inactive profile row (0..1 rows;
-- profiles.id is the PK). anon (auth.uid() IS NULL) matches zero rows.
-- Helpers below check is_active themselves; do NOT assume a returned row means
-- an authorized user.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_profile()
RETURNS public.profiles
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT p.*
    FROM public.profiles p
    WHERE p.id = auth.uid();
$$;

-- ----------------------------------------------------------------------------
-- is_super_admin(): global tier check — active profile with role super_admin.
-- (Inactive super_admin profiles are treated as nothing, per the model above.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = auth.uid()
          AND p.role = 'super_admin'
          AND p.is_active
    );
$$;

-- ----------------------------------------------------------------------------
-- site_role(site): the caller's active site-scoped role for one site, else
-- NULL. super_admin short-circuits to 'super_admin' even with no profile_sites
-- row (global tier implies every site).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.site_role(site uuid)
RETURNS public.app_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT CASE
        WHEN public.is_super_admin() THEN 'super_admin'::public.app_role
        ELSE (
            SELECT ps.role
            FROM public.profile_sites ps
            WHERE ps.profile_id = auth.uid()
              AND ps.site_id    = site
              AND ps.is_active
            LIMIT 1
        )
    END;
$$;

-- ----------------------------------------------------------------------------
-- is_site_member(site): may READ drafts/unlisted content on that site.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_site_member(site uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.profile_sites ps
            WHERE ps.profile_id = auth.uid()
              AND ps.site_id    = site
              AND ps.is_active
        );
$$;

-- ----------------------------------------------------------------------------
-- is_site_editor(site): admin OR editor on that site (can edit content).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_site_editor(site uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.profile_sites ps
            WHERE ps.profile_id = auth.uid()
              AND ps.site_id    = site
              AND ps.is_active
              AND ps.role IN ('admin', 'editor')
        );
$$;

-- ----------------------------------------------------------------------------
-- is_site_admin(site): admin on that site (site settings, members, deletes).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_site_admin(site uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.profile_sites ps
            WHERE ps.profile_id = auth.uid()
              AND ps.site_id    = site
              AND ps.is_active
              AND ps.role = 'admin'
        );
$$;

-- ----------------------------------------------------------------------------
-- is_staff(): holds ANY active site role (or global super_admin). Use for
-- coarse "CMS user vs reader" gates on shared admin surfaces.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.profile_sites ps
            WHERE ps.profile_id = auth.uid()
              AND ps.is_active
        );
$$;

-- ----------------------------------------------------------------------------
-- is_editor_up(): admin or editor on ANY site.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_editor_up()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.profile_sites ps
            WHERE ps.profile_id = auth.uid()
              AND ps.is_active
              AND ps.role IN ('admin', 'editor')
        );
$$;

-- ----------------------------------------------------------------------------
-- is_admin_up(): admin on ANY site.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin_up()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.profile_sites ps
            WHERE ps.profile_id = auth.uid()
              AND ps.is_active
              AND ps.role = 'admin'
        );
$$;

-- ----------------------------------------------------------------------------
-- is_linked_author(author): the given public.authors byline row is linked to
-- the caller's auth account (authors.user_id = auth.uid()). Linking itself is
-- an admin action under RLS; this only tests the existing link. anon never
-- matches (auth.uid() IS NULL).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_linked_author(author uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.authors a
        WHERE a.id      = author
          AND a.user_id = auth.uid()
    );
$$;

-- ----------------------------------------------------------------------------
-- can_edit_post(post): site editor/admin (via is_site_editor on the post's
-- site) OR the caller's linked byline owns the post. Posts with an unknown id
-- (or NULL) return false, never errors. The author-ownership path deliberately
-- does NOT require site membership: a linked author edits their own posts even
-- if their site role was demoted, until an admin unpublishes/deletes them.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.can_edit_post(post uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.posts p
        WHERE p.id = post
          AND (
              public.is_site_editor(p.site_id)
              OR EXISTS (
                  SELECT 1
                  FROM public.authors a
                  WHERE a.id      = p.author_id
                    AND a.user_id = auth.uid()
              )
          )
    );
$$;

-- ----------------------------------------------------------------------------
-- Execute grants (see SECURITY NOTES at the top for the rationale).
-- ----------------------------------------------------------------------------
DO $$
DECLARE fn text;
BEGIN
    FOREACH fn IN ARRAY ARRAY[
        'public.current_profile()',
        'public.is_super_admin()',
        'public.site_role(uuid)',
        'public.is_site_member(uuid)',
        'public.is_site_editor(uuid)',
        'public.is_site_admin(uuid)',
        'public.is_staff()',
        'public.is_editor_up()',
        'public.is_admin_up()',
        'public.is_linked_author(uuid)',
        'public.can_edit_post(uuid)'
    ]
    LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', fn);
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon, authenticated, service_role', fn);
    END LOOP;
END;
$$;

-- End of 002_auth_and_roles.sql
