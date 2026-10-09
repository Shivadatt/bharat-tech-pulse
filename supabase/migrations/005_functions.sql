-- ============================================================================
-- 005_functions.sql — Server-side helpers for Bharat Tech Pulse
-- ============================================================================

-- ---------------------------------------------------------------------------
-- publish_scheduled_posts(): flips due scheduled posts to published.
-- Runs as security definer so pg_cron / edge functions can call it without a
-- user JWT. search_path pinned to public to avoid search-path hijacking.
--
-- Scheduling (owner runs manually once, after enabling the pg_cron extension
-- in the Supabase SQL editor):
--   select cron.schedule(
--     'publish-due-posts',
--     '* * * * *',
--     $$select public.publish_scheduled_posts()$$
--   );
-- ---------------------------------------------------------------------------
create or replace function public.publish_scheduled_posts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer;
begin
  update public.posts
  set status = 'published',
      published_at = coalesce(published_at, now())
  where status = 'scheduled'
    and scheduled_for is not null
    and scheduled_for <= now();

  get diagnostics affected = row_count;
  return affected;
end;
$$;

-- Lock down: callable only by the service role (edge functions) and postgres
-- (pg_cron runs as postgres). Not callable by anon/authenticated.
revoke execute on function public.publish_scheduled_posts() from public, anon, authenticated;
grant execute on function public.publish_scheduled_posts() to service_role, postgres;

-- ---------------------------------------------------------------------------
-- normalize_slug(base): slugify helper for future RPCs (post create/update).
-- Lowercases, strips non-[a-z0-9] runs into '-', trims edge dashes.
-- Returns NULL when nothing usable remains, so callers can raise an error
-- instead of storing an empty slug. (unaccent is not assumed to exist.)
-- ---------------------------------------------------------------------------
create or replace function public.normalize_slug(base text)
returns text
language sql
immutable
set search_path = public
as $$
  select nullif(
    btrim(
      regexp_replace(lower(coalesce(base, '')), '[^a-z0-9]+', '-', 'g'),
      '-'
    ),
    ''
  );
$$;

revoke execute on function public.normalize_slug(text) from public, anon, authenticated;
grant execute on function public.normalize_slug(text) to service_role, postgres;
