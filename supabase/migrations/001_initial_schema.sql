-- ============================================================================
-- 001_initial_schema.sql
-- Bharat Tech Pulse (site slug: india_tech) — initial database schema.
-- Target: PostgreSQL 15 on Supabase.
-- Owned by SUB-AGENT 1 (database architecture + migrations).
--
-- Contains: extensions, enums, 14 tables, indexes. PURE DDL — no functions,
-- no triggers.
--   * set_updated_at() + all BEFORE-UPDATE triggers and the scheduled-publish /
--     slug helpers live in 005_functions_and_triggers.sql.
--   * handle_new_user() + the auth.users trigger + every site-scoped
--     authorization helper live in 002_auth_and_roles.sql.
-- RLS policies and storage buckets live in migrations owned by the RLS agent,
-- and the demo seed is 006_seed_data.sql. Run all migrations in numeric order.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Extensions
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- provides gen_random_uuid()

-- ----------------------------------------------------------------------------
-- Enum types (plain CREATE — migrations run once)
-- ----------------------------------------------------------------------------
CREATE TYPE public.app_role AS ENUM ('super_admin', 'admin', 'editor', 'author');

CREATE TYPE public.post_status AS ENUM ('draft', 'published', 'scheduled', 'archived');

-- ----------------------------------------------------------------------------
-- 1. sites — one row per website in the multi-site workspace
-- ----------------------------------------------------------------------------
CREATE TABLE public.sites (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    slug        TEXT NOT NULL UNIQUE,
    domain      TEXT,
    description TEXT,
    logo_url    TEXT,
    favicon_url TEXT,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 2. profiles — 1:1 extension of auth.users
-- ----------------------------------------------------------------------------
CREATE TABLE public.profiles (
    id         UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    full_name  TEXT,
    email      TEXT,
    avatar_url TEXT,
    -- GLOBAL tier only: 'super_admin' is the sole meaningful value here.
    -- The signup default 'author' grants nothing by itself once site roles are
    -- assigned through profile_sites (see 002_auth_and_roles.sql helpers).
    role       public.app_role NOT NULL DEFAULT 'author',
    is_active  BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 3. authors — public-facing editorial bylines per site
--    user_id links a byline to an auth account so authors can own/edit their
--    own articles under RLS (policies in migration 002).
-- ----------------------------------------------------------------------------
CREATE TABLE public.authors (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id      UUID NOT NULL REFERENCES public.sites (id) ON DELETE CASCADE,
    user_id      UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    name         TEXT NOT NULL,
    slug         TEXT NOT NULL,
    bio          TEXT,
    avatar_url   TEXT,
    designation  TEXT,
    social_links JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active    BOOLEAN NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (site_id, slug)
);

-- ----------------------------------------------------------------------------
-- 4. categories
-- ----------------------------------------------------------------------------
CREATE TABLE public.categories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id         UUID NOT NULL REFERENCES public.sites (id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    slug            TEXT NOT NULL,
    description     TEXT,
    image_url       TEXT,
    icon_code       TEXT NOT NULL DEFAULT 'folder',
    subcategories   TEXT[] NOT NULL DEFAULT '{}',
    sort_order      INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    seo_title       TEXT,
    seo_description TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (site_id, slug)
);

-- ----------------------------------------------------------------------------
-- 5. tags
-- ----------------------------------------------------------------------------
CREATE TABLE public.tags (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id    UUID NOT NULL REFERENCES public.sites (id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    slug       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (site_id, slug)
);

-- ----------------------------------------------------------------------------
-- 6. posts — articles. Includes EXTRA columns required by the Flutter
--    ArticleModel (lib/data/models/article_model.dart):
--    subcategory, is_popular, key_takeaways, faqs, toc.
-- ----------------------------------------------------------------------------
CREATE TABLE public.posts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id         UUID NOT NULL REFERENCES public.sites (id) ON DELETE CASCADE,
    author_id       UUID REFERENCES public.authors (id) ON DELETE SET NULL,
    category_id     UUID REFERENCES public.categories (id) ON DELETE SET NULL,
    title           TEXT NOT NULL,
    slug            TEXT NOT NULL,
    excerpt         TEXT,
    content         TEXT NOT NULL,
    featured_image  TEXT,
    thumbnail_image TEXT,
    status          public.post_status NOT NULL DEFAULT 'draft',
    published_at    TIMESTAMPTZ,
    scheduled_for   TIMESTAMPTZ,
    reading_time    INTEGER,
    seo_title       TEXT,
    seo_description TEXT,
    canonical_url   TEXT,
    og_title        TEXT,
    og_description  TEXT,
    og_image        TEXT,
    is_featured     BOOLEAN NOT NULL DEFAULT false,
    is_trending     BOOLEAN NOT NULL DEFAULT false,
    view_count      BIGINT NOT NULL DEFAULT 0,
    -- Flutter-model extras
    subcategory     TEXT NOT NULL DEFAULT '',
    is_popular      BOOLEAN NOT NULL DEFAULT false,
    key_takeaways   JSONB NOT NULL DEFAULT '[]'::jsonb,
    faqs            JSONB NOT NULL DEFAULT '[]'::jsonb,
    toc             JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- timestamps (UTC)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (site_id, slug)
);

-- ----------------------------------------------------------------------------
-- 7. post_tags — many-to-many join between posts and tags
-- ----------------------------------------------------------------------------
CREATE TABLE public.post_tags (
    post_id UUID NOT NULL REFERENCES public.posts (id) ON DELETE CASCADE,
    tag_id  UUID NOT NULL REFERENCES public.tags (id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);

-- ----------------------------------------------------------------------------
-- 8. media — registry of files stored in the Supabase Storage 'media' bucket
-- ----------------------------------------------------------------------------
CREATE TABLE public.media (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id      UUID NOT NULL REFERENCES public.sites (id) ON DELETE CASCADE,
    uploaded_by  UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    file_name    TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    public_url   TEXT,
    mime_type    TEXT,
    file_size    BIGINT,
    width        INTEGER,
    height       INTEGER,
    alt_text     TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 9. post_revisions — content history for the editor
-- ----------------------------------------------------------------------------
CREATE TABLE public.post_revisions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id         UUID NOT NULL REFERENCES public.posts (id) ON DELETE CASCADE,
    edited_by       UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    title           TEXT,
    content         TEXT,
    excerpt         TEXT,
    revision_number INTEGER NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (post_id, revision_number)
);

-- ----------------------------------------------------------------------------
-- 10. redirects — legacy path forwarding per site
-- ----------------------------------------------------------------------------
CREATE TABLE public.redirects (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id     UUID NOT NULL REFERENCES public.sites (id) ON DELETE CASCADE,
    old_path    TEXT NOT NULL,
    new_path    TEXT NOT NULL,
    status_code INTEGER NOT NULL DEFAULT 301,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (site_id, old_path)
);

-- ----------------------------------------------------------------------------
-- 11. site_settings — 1:1 per-site configuration row
-- ----------------------------------------------------------------------------
CREATE TABLE public.site_settings (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id                  UUID NOT NULL UNIQUE REFERENCES public.sites (id) ON DELETE CASCADE,
    site_name                TEXT,
    tagline                  TEXT,
    logo_url                 TEXT,
    favicon_url              TEXT,
    default_meta_title       TEXT,
    default_meta_description TEXT,
    contact_email            TEXT,
    social_links             JSONB NOT NULL DEFAULT '{}'::jsonb,
    footer_text              TEXT,
    copyright_text           TEXT,
    google_analytics_id      TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 12. subscribers — newsletter subscribers per site
-- ----------------------------------------------------------------------------
CREATE TABLE public.subscribers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id         UUID NOT NULL REFERENCES public.sites (id) ON DELETE CASCADE,
    email           TEXT NOT NULL,
    name            TEXT,
    is_verified     BOOLEAN NOT NULL DEFAULT false,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    subscribed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    unsubscribed_at TIMESTAMPTZ,
    UNIQUE (site_id, email)
);

-- ----------------------------------------------------------------------------
-- 13. analytics_events — lightweight event stream for views/engagement
-- ----------------------------------------------------------------------------
CREATE TABLE public.analytics_events (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id    UUID NOT NULL REFERENCES public.sites (id) ON DELETE CASCADE,
    post_id    UUID REFERENCES public.posts (id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    session_id TEXT,
    path       TEXT,
    referrer   TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 14. profile_sites — site-scoped role assignments (the authorization core).
--     Every non-global role is granted THROUGH this table: one row per
--     (profile, site) with the role that profile holds on that site.
--     super_admin is GLOBAL-only (profiles.role) and is deliberately excluded
--     here via CHECK. Writes to this table are super_admin-only under RLS,
--     so a site admin can never promote themselves or escalate — see the
--     role-model comment block in 002_auth_and_roles.sql.
-- ----------------------------------------------------------------------------
CREATE TABLE public.profile_sites (
    profile_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    site_id    UUID NOT NULL REFERENCES public.sites (id) ON DELETE CASCADE,
    role       public.app_role NOT NULL CHECK (role <> 'super_admin'),
    is_active  BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (profile_id, site_id)
);

-- ----------------------------------------------------------------------------
-- Indexes (idempotent)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS posts_site_id_idx              ON public.posts (site_id);
CREATE INDEX IF NOT EXISTS posts_category_id_idx          ON public.posts (category_id);
CREATE INDEX IF NOT EXISTS posts_author_id_idx            ON public.posts (author_id);
CREATE INDEX IF NOT EXISTS posts_status_idx               ON public.posts (status);
CREATE INDEX IF NOT EXISTS posts_published_at_idx         ON public.posts (published_at);
CREATE INDEX IF NOT EXISTS posts_scheduled_for_idx        ON public.posts (scheduled_for);
CREATE INDEX IF NOT EXISTS posts_is_featured_idx          ON public.posts (is_featured);
CREATE INDEX IF NOT EXISTS posts_is_trending_idx          ON public.posts (is_trending);
CREATE INDEX IF NOT EXISTS posts_is_popular_idx           ON public.posts (is_popular);
CREATE INDEX IF NOT EXISTS categories_site_id_idx         ON public.categories (site_id);
CREATE INDEX IF NOT EXISTS tags_site_id_idx               ON public.tags (site_id);
CREATE INDEX IF NOT EXISTS authors_site_id_idx            ON public.authors (site_id);
CREATE INDEX IF NOT EXISTS media_site_id_idx              ON public.media (site_id);
CREATE INDEX IF NOT EXISTS post_revisions_post_id_idx     ON public.post_revisions (post_id);
CREATE INDEX IF NOT EXISTS redirects_site_id_idx          ON public.redirects (site_id);
CREATE INDEX IF NOT EXISTS subscribers_site_id_idx        ON public.subscribers (site_id);
CREATE INDEX IF NOT EXISTS analytics_events_site_id_idx   ON public.analytics_events (site_id);
CREATE INDEX IF NOT EXISTS analytics_events_created_at_idx ON public.analytics_events (created_at);
CREATE INDEX IF NOT EXISTS profile_sites_site_role_idx    ON public.profile_sites (site_id, role);
-- Composite indexes for the hot public-feed queries
CREATE INDEX IF NOT EXISTS posts_site_status_published_idx  ON public.posts (site_id, status, published_at);
CREATE INDEX IF NOT EXISTS posts_site_category_status_idx   ON public.posts (site_id, category_id, status);

-- ----------------------------------------------------------------------------
-- Functions & triggers intentionally NOT here:
--   * set_updated_at() + per-table BEFORE UPDATE triggers + scheduled-publish
--     + slug helpers  -> 005_functions_and_triggers.sql
--   * handle_new_user() + auth.users trigger + all authorization helpers
--     -> 002_auth_and_roles.sql
-- ----------------------------------------------------------------------------

-- End of 001_initial_schema.sql
