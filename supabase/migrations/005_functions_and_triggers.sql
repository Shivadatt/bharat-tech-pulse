-- ============================================================================
-- 005_functions_and_triggers.sql
-- Bharat Tech Pulse (site slug: india_tech) — operational functions & triggers.
-- Owned by SUB-AGENT 1 (database architecture). Supersedes the old
-- 005_functions.sql; the reusable set_updated_at() function and all of its
-- BEFORE-UPDATE triggers were moved here from 001 so that 001 is pure DDL.
-- Must run AFTER 001 (tables) and 002 (auth helpers). Seed (006) runs after
-- this so demo UPDATEs already refresh updated_at.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Reusable updated_at trigger function.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Triggers are declared with DROP IF EXISTS + CREATE so this file re-runs
-- cleanly. Tables carrying an updated_at column:
DROP TRIGGER IF EXISTS set_sites_updated_at          ON public.sites;
CREATE TRIGGER set_sites_updated_at          BEFORE UPDATE ON public.sites          FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS set_profiles_updated_at       ON public.profiles;
CREATE TRIGGER set_profiles_updated_at       BEFORE UPDATE ON public.profiles       FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS set_profile_sites_updated_at  ON public.profile_sites;
CREATE TRIGGER set_profile_sites_updated_at  BEFORE UPDATE ON public.profile_sites  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS set_authors_updated_at        ON public.authors;
CREATE TRIGGER set_authors_updated_at        BEFORE UPDATE ON public.authors        FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS set_categories_updated_at     ON public.categories;
CREATE TRIGGER set_categories_updated_at     BEFORE UPDATE ON public.categories     FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS set_tags_updated_at           ON public.tags;
CREATE TRIGGER set_tags_updated_at           BEFORE UPDATE ON public.tags           FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS set_posts_updated_at          ON public.posts;
CREATE TRIGGER set_posts_updated_at          BEFORE UPDATE ON public.posts          FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS set_media_updated_at          ON public.media;
CREATE TRIGGER set_media_updated_at          BEFORE UPDATE ON public.media          FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS set_site_settings_updated_at  ON public.site_settings;
CREATE TRIGGER set_site_settings_updated_at  BEFORE UPDATE ON public.site_settings  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- NOTE: post_revisions, redirects, subscribers and analytics_events have no
-- updated_at column (append-only / immutable audit data) and get no trigger.

-- ----------------------------------------------------------------------------
-- publish_scheduled_posts(): flips due scheduled posts to published.
-- Runs as security definer so pg_cron / edge functions can call it without a
-- user JWT. search_path pinned to public to avoid search-path hijacking.
-- Posts seeded 'scheduled' whose scheduled_for has already passed when the
-- migration set is applied are picked up on the first run of this function —
-- that is by design, not a seed bug.
--
-- Scheduling (owner runs manually once, after enabling the pg_cron extension
-- in the Supabase SQL editor):
--   select cron.schedule(
--     'publish-due-posts',
--     '* * * * *',
--     $$select public.publish_scheduled_posts()$$
--   );
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.publish_scheduled_posts()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  affected integer;
BEGIN
  UPDATE public.posts
  SET status = 'published',
      published_at = COALESCE(published_at, now())
  WHERE status = 'scheduled'
    AND scheduled_for IS NOT NULL
    AND scheduled_for <= now();

  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;

-- Lock down: callable only by the service role (edge functions) and postgres
-- (pg_cron runs as postgres). Not callable by anon/authenticated.
REVOKE EXECUTE ON FUNCTION public.publish_scheduled_posts() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.publish_scheduled_posts() TO service_role, postgres;

-- ----------------------------------------------------------------------------
-- normalize_slug(base): slugify helper for future RPCs (post create/update).
-- Lowercases, strips non-[a-z0-9] runs into '-', trims edge dashes.
-- Returns NULL when nothing usable remains, so callers can raise an error
-- instead of storing an empty slug. (unaccent is not assumed to exist.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalize_slug(base text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT NULLIF(
    BTRIM(
      REGEXP_REPLACE(LOWER(COALESCE(base, '')), '[^a-z0-9]+', '-', 'g'),
      '-'
    ),
    ''
  );
$$;

REVOKE EXECUTE ON FUNCTION public.normalize_slug(text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.normalize_slug(text) TO service_role, postgres;

-- ----------------------------------------------------------------------------
-- Revision-numbering rule (documentation only — no DB trigger).
-- post_revisions.revision_number is computed by the CLIENT (see
-- lib/data/repositories/supabase_article_repository.dart): next = COALESCE(
-- MAX(revision_number) for the post, 0) + 1, enforced unique by the
-- (post_id, revision_number) constraint. 006_seed_data.sql follows the same
-- max+1 monotonic rule for its demo rows. Do not add a DB trigger that
-- auto-creates revisions; the Flutter editor intentionally snapshots only on
-- editorial changes.
-- ----------------------------------------------------------------------------

-- End of 005_functions_and_triggers.sql
