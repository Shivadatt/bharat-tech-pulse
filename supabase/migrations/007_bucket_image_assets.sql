-- =============================================================================
-- 007_bucket_image_assets.sql
--
-- Replaces the hotlinked third-party demo imagery left by 006_seed_data.sql
-- (Unsplash photo URLs) with first-party objects that live in this project's
-- own public 'media' Storage bucket, and registers those objects in
-- public.media with their real byte counts and pixel dimensions.
--
-- Rationale: the spec forbids seeded rows pointing at external URLs that only
-- look like working site assets. Every URL written here resolves to a bytes
-- object uploaded under bucket 'media'.
--
-- Idempotent and derived: image URLs are built from category/author slugs, so
-- re-running is a no-op once the seed already points at the bucket. The media
-- registry rows upsert on primary key.
--
-- Safe for a database that has already applied 006; also safe on a fresh
-- replay of 001..007.
-- =============================================================================

begin;

-- 1. author avatars -> media/india_tech/authors/<slug>-avatar.jpg ------------
update public.authors a
   set avatar_url = 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/' || a.slug || '-avatar.jpg'
  where a.slug in ('aravind-sharma', 'priya-nambiar', 'rohit-deshmukh', 'sneha-kulkarni');

-- 2. post hero / thumbnail / og -> media/india_tech/articles/category/<category-slug>-hero.jpg
update public.posts p
   set featured_image  = 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/' || c.slug || '-hero.jpg',
       thumbnail_image = 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/' || c.slug || '-hero.jpg',
       og_image        = 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/' || c.slug || '-hero.jpg'
  from public.categories c
 where p.category_id = c.id
   and c.slug in ('ai', 'smartphones', 'apps', 'how-to',
                  'tech-news', 'comparisons', 'cyber-safety', 'buying-guides');

-- 3. register the 11 new objects (8 category heroes + 3 author avatars) ------
INSERT INTO public.media
    (id, site_id, uploaded_by, file_name, storage_path, public_url,
     mime_type, file_size, width, height, alt_text)
VALUES
    ('00000000-0000-4000-8000-000000000507', '00000000-0000-4000-8000-000000000001', NULL,
     'ai-hero.jpg',
     'india_tech/articles/category/ai-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
     'image/jpeg', 39874, 1600, 900,
     'hero illustration for Artificial Intelligence articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000508', '00000000-0000-4000-8000-000000000001', NULL,
     'smartphones-hero.jpg',
     'india_tech/articles/category/smartphones-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
     'image/jpeg', 48121, 1600, 900,
     'hero illustration for Smartphone Reviews articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000509', '00000000-0000-4000-8000-000000000001', NULL,
     'apps-hero.jpg',
     'india_tech/articles/category/apps-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
     'image/jpeg', 43118, 1600, 900,
     'hero illustration for App & Software News articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000510', '00000000-0000-4000-8000-000000000001', NULL,
     'how-to-hero.jpg',
     'india_tech/articles/category/how-to-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
     'image/jpeg', 45842, 1600, 900,
     'hero illustration for How-To & Guides articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000511', '00000000-0000-4000-8000-000000000001', NULL,
     'tech-news-hero.jpg',
     'india_tech/articles/category/tech-news-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
     'image/jpeg', 43373, 1600, 900,
     'hero illustration for Latest Tech News 2026 articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000512', '00000000-0000-4000-8000-000000000001', NULL,
     'comparisons-hero.jpg',
     'india_tech/articles/category/comparisons-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
     'image/jpeg', 41033, 1600, 900,
     'hero illustration for Product Comparisons articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000513', '00000000-0000-4000-8000-000000000001', NULL,
     'cyber-safety-hero.jpg',
     'india_tech/articles/category/cyber-safety-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
     'image/jpeg', 46125, 1600, 900,
     'hero illustration for Cyber Safety & Security articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000514', '00000000-0000-4000-8000-000000000001', NULL,
     'buying-guides-hero.jpg',
     'india_tech/articles/category/buying-guides-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
     'image/jpeg', 44287, 1600, 900,
     'hero illustration for Buying Guides 2026 articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000515', '00000000-0000-4000-8000-000000000001', NULL,
     'priya-nambiar-avatar.jpg',
     'india_tech/authors/priya-nambiar-avatar.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/priya-nambiar-avatar.jpg',
     'image/jpeg', 8043, 300, 300,
     'Avatar for byline Priya Nambiar (demo asset)'),
    ('00000000-0000-4000-8000-000000000516', '00000000-0000-4000-8000-000000000001', NULL,
     'rohit-deshmukh-avatar.jpg',
     'india_tech/authors/rohit-deshmukh-avatar.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/rohit-deshmukh-avatar.jpg',
     'image/jpeg', 8220, 300, 300,
     'Avatar for byline Rohit Deshmukh (demo asset)'),
    ('00000000-0000-4000-8000-000000000517', '00000000-0000-4000-8000-000000000001', NULL,
     'sneha-kulkarni-avatar.jpg',
     'india_tech/authors/sneha-kulkarni-avatar.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/sneha-kulkarni-avatar.jpg',
     'image/jpeg', 7344, 300, 300,
     'Avatar for byline Sneha Kulkarni (demo asset)')
ON CONFLICT (id) DO UPDATE
SET file_name    = EXCLUDED.file_name,
    storage_path = EXCLUDED.storage_path,
    public_url   = EXCLUDED.public_url,
    mime_type    = EXCLUDED.mime_type,
    file_size    = EXCLUDED.file_size,
    width        = EXCLUDED.width,
    height       = EXCLUDED.height,
    alt_text     = EXCLUDED.alt_text;

commit;
