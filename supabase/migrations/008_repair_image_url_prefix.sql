-- =============================================================================
-- 008_repair_image_url_prefix.sql
--
-- Forward repair for the defect shipped in 007_bucket_image_assets.sql: its
-- derived URLs omitted the Storage folder prefix, so the already-applied
-- database points 24 posts and 4 authors at
--   .../object/public/media/<slug>-hero.jpg        (HTTP 400 not_found)
--   .../object/public/media/<slug>-avatar.jpg      (HTTP 400 not_found)
-- while the real objects live at
--   india_tech/articles/category/<slug>-hero.jpg
--   india_tech/authors/<slug>-avatar.jpg
--
-- 007's own derivation is corrected in place so a fresh 001..008 replay is
-- right the first time; this file repairs a database that already ran the
-- broken 007. Both are the same idempotent derived UPDATE, so running 008
-- twice - or after a corrected 007 - is a no-op.
--
-- Only rows that are missing the prefix are touched; correct rows are left
-- exactly as they are.
-- =============================================================================

begin;

-- 1. author avatars -----------------------------------------------------------
update public.authors a
   set avatar_url = 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/' || a.slug || '-avatar.jpg'
  where a.slug in ('aravind-sharma', 'priya-nambiar', 'rohit-deshmukh', 'sneha-kulkarni')
    and a.avatar_url not like '%/media/india_tech/authors/%';

-- 2. post hero / thumbnail / og ----------------------------------------------
update public.posts p
   set featured_image  = 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/' || c.slug || '-hero.jpg',
       thumbnail_image = 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/' || c.slug || '-hero.jpg',
       og_image        = 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/' || c.slug || '-hero.jpg'
  from public.categories c
 where p.category_id = c.id
   and c.slug in ('ai', 'smartphones', 'apps', 'how-to',
                  'tech-news', 'comparisons', 'cyber-safety', 'buying-guides')
   and (   p.featured_image  is null or p.featured_image  not like '%/media/india_tech/articles/category/%'
        or p.thumbnail_image is null or p.thumbnail_image not like '%/media/india_tech/articles/category/%'
        or p.og_image        is null or p.og_image        not like '%/media/india_tech/articles/category/%');

-- 3. self-check: every stored URL must be a registered media row AND a real
--    Storage object. Runs inside this transaction, so a disagreement aborts
--    the whole repair instead of leaving the database pointing at 404s.
do $$
declare
    bad_rows int;
begin
    select count(*) into bad_rows
      from public.posts p
     where not exists (select 1 from public.media m where m.public_url = p.featured_image)
        or not exists (select 1 from public.media m where m.public_url = p.thumbnail_image)
        or not exists (select 1 from public.media m where m.public_url = p.og_image)
        or not exists (select 1 from storage.objects o
                        where o.bucket_id = 'media'
                          and o.name = regexp_replace(p.featured_image, '^.*?/object/public/media/', ''));
    if bad_rows > 0 then
        raise exception '008 self-check: % posts do not resolve to a registered media row + real storage object', bad_rows;
    end if;

    select count(*) into bad_rows
      from public.authors a
     where not exists (select 1 from public.media m where m.public_url = a.avatar_url)
        or not exists (select 1 from storage.objects o
                       where o.bucket_id = 'media'
                         and o.name = regexp_replace(a.avatar_url, '^.*?/object/public/media/', ''));
    if bad_rows > 0 then
        raise exception '008 self-check: % authors do not resolve to a registered media row + real storage object', bad_rows;
    end if;
end $$;

commit;
