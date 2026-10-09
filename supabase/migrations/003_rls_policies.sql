-- ============================================================================
-- 003_rls_policies.sql — Row Level Security for Bharat Tech Pulse
-- (multi-site model: global roles + per-site roles through profile_sites)
--
-- Depends on:
--   001_initial_schema.sql  — all 14 tables incl. public.profile_sites
--   002_auth_and_roles.sql  — helper functions (SA1-owned, contract below)
--
-- HELPER CONTRACT used here (all `stable security definer
-- set search_path = public`, defined in 002_auth_and_roles.sql):
--   is_super_admin()                 global profiles.role = 'super_admin'
--   site_role(site uuid)             caller's app_role for that site via
--                                    profile_sites (active rows only), else NULL
--   is_site_member(site uuid)        any active profile_sites membership
--                                    (author/admin/editor) OR super_admin
--   is_site_editor(site uuid)        super_admin OR site role admin/editor
--   is_site_admin(site uuid)         super_admin OR site role admin
--   is_staff()                       super_admin OR any active membership
--   current_profile()                the caller's profiles row
--   is_linked_author(author uuid)    authors.id belongs to auth.uid()
--   can_edit_post(post uuid)         is_site_editor of the POST's site, or the
--                                    caller's linked author owns the post
--
-- ROLE MODEL (binding):
--   profiles.role keeps only GLOBAL meaning: 'super_admin' is global; every
--   other value is inert by itself — powers come from profile_sites rows.
--   Signup default stays 'author', which grants NOTHING until an operator
--   adds a profile_sites membership. That is why no policy below equates
--   "profile author role" with site access.
--
-- ----------------------------------------------------------------------------
-- ACCESS MATRIX (accurate to the policies below; S=super_admin, A=site admin,
-- E=site editor, N=site author-role member with a LINKED byline,
-- O=other authenticated (no membership), X=anon).
-- Tables without a site_id column are scoped through their post/site FK.
--
--  TABLE           READ                                     INSERT
--  sites           active row: X+E(any)                     none via API (service/operator)
--  profiles        own row: E+A+S; all rows: S              none via API (SQL only)
--  profile_sites   own rows: E+A+S; all rows: S             none via API (SQL only)
--  authors         active: X+E; all: E+A+S                  E+A+S (is_site_admin) of the row's site
--  categories      active: X+E; all: E+A+S                  E+A+S of the row's site
--  tags            all: X+E                                 any active member E+A+S+N of site
--                                                        (N-branch = author save-flow auto-create)
--  post_tags       all: X+E                                 can_edit_post(post): E or own byline N
--  posts           published/due-scheduled: X+E; drafts,
--                  archived, future: E of row's site, or
--                  own byline N (member of that site)     E of site; N only status='draft'
--                                                        own-byline, site active
--  media           all metadata: X+E                        E+A+S of site, storage_path set
--  post_revisions  can_edit_post(post): E or N              can_edit_post(post): E or N
--                  (immutable: no UPDATE/DELETE)            (immutable: no UPDATE/DELETE)
--  redirects       all: X+E (public 301 map)                any active member E+A+S+N of site
--                                                        (slug-change save flow)
--  site_settings   rows of active sites: X+E (NO SECRETS)   E+A+S (is_site_admin) of site
--  subscribers     emails hidden from X+N+O; E+A+S of site  X+E (subscribe form, constrained)
--  analytics_events rows hidden from X+N+O; E+A+S of site   X+E (page_view/article_view only,
--                                                        site must be active)
--
--  TABLE           UPDATE                                   DELETE
--  sites           none via API                             none via API
--  profiles        none via API (prevents self-promotion)   none via API
--  profile_sites   none via API (SQL-only assignment)       none via API
--  authors         E+A+S (is_site_admin) of site            E+A+S (is_site_admin) of site
--  categories      E+A+S of site                            E+A+S (is_site_admin) of site
--  tags            E+A+S of site                            E+A+S (is_site_admin) of site
--  post_tags       can_edit_post(post) (E or N)             can_edit_post(post) (E or N)
--  posts           E+A+S of site; N own-byline (member)    E+A+S (is_site_admin) of site
--  media           E+A+S of site                            E+A+S of site
--  post_revisions  —                                        —
--  redirects       E+A+S (is_site_admin) of site            E+A+S (is_site_admin) of site
--  site_settings   E+A+S (is_site_admin) of site            E+A+S (is_site_admin) of site
--  subscribers     E+A+S of site (verify/unsubscribe)       E+A+S (is_site_admin) of site
--  analytics_events — (append-only)                         — (append-only)
--
-- WHO RUNS THE MULTI-STATEMENT ARTICLE SAVE (supabase_article_repository):
--   createArticle: posts INSERT (E, or N with status='draft' + linked byline)
--                  + post_tags DELETE+INSERT, tags INSERT (auto-create) — same actor.
--   updateArticle: redirects INSERT (old slug 301) — any member tier that can
--                  edit the post (E, or N editing own byline);
--                  post_revisions SELECT (revision_number) + INSERT — can_edit_post;
--                  posts UPDATE (E of site, or N own-byline);
--                  post_tags DELETE+INSERT + tags INSERT — can_edit_post / member.
--   deleteArticle: posts DELETE — admins only (is_site_admin of the row's site).
--   Category/tag/author CRUD screens: categories+tags write = is_site_editor /
--   is_site_admin of the row's site; authors write = is_site_admin.
--   Media library: media read = public, writes = is_site_editor of the site;
--   storage object writes require the same via 004_storage_policies.sql.
--   Public site pages (X): feeds, article pages, 301 lookups, tag/category
--   resolution, subscribe form, analytics beacons.
--
-- ----------------------------------------------------------------------------
-- HARD-WON INVARIANTS (do not regress):
--   1. JWT ROLE: a PostgREST request carrying a valid JWT runs as role
--      `authenticated`, NEVER `anon`. Every public-read policy is declared
--      `to anon, authenticated`; an `to anon` policy silently returns ZERO
--      rows for signed-in staff and breaks the whole site for them. Same for
--      the public INSERT policies (a signed-in reader may subscribe and emit
--      events too).
--   2. DRAFTS ARE NOT STAFF-READABLE: signup defaults profiles.role to
--      'author', and any registrant therefore passes a naive is_staff() read.
--      Sensitive rows are only visible through SITE-SPECIFIC membership
--      (profile_sites), never through the bare signup role.
--   3. SITE ISOLATION: every staff policy on a site-owned table tests the
--      ROW's site_id through is_site_*(site_id) — never an unscoped global
--      check — so a member of one site cannot read or touch a sibling site's
--      rows. Never hardcode the site UUID; scope by row.
--   4. NO WRITE POLICY uses an unrestricted USING (true)/WITH CHECK (true);
--      anonymous writes are limited to subscribers INSERT and analytics_events
--      INSERT, both value-constrained.
--   5. NO SELF-PROMOTION VIA API: profiles and profile_sites have SELECT-only
--      policies. Role/assignment changes are executed in SQL by an operator
--      (see supabase/README.md bootstrap).
--   6. RECURSION SAFETY: policies on profiles/profile_sites call
--      is_super_admin(), which reads profiles. That is safe ONLY because the
--      helpers are SECURITY DEFINER: they query profiles as the function
--      owner, bypassing the caller's RLS, so a policy predicate never
--      re-enters the policy it belongs to. Same reasoning for the membership
--      helpers used by policies on posts/profiles. Do not convert the helper
--      bodies to SECURITY INVOKER.
--   7. HELPER EXECUTE: policy predicates evaluate as the calling role, so
--      every role a policy runs for must hold EXECUTE on the helpers it
--      calls. 002_auth_and_roles.sql revokes EXECUTE from PUBLIC and grants
--      it explicitly to anon, authenticated, service_role — that grant model
--      is what makes this migration work and must be preserved (a missing
--      grant makes guarded queries ERROR, not silently deny).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Enable RLS on all 14 tables (profile_sites is the new 14th table)
-- ---------------------------------------------------------------------------
alter table public.sites            enable row level security;
alter table public.profiles         enable row level security;
alter table public.profile_sites    enable row level security;
alter table public.authors          enable row level security;
alter table public.categories       enable row level security;
alter table public.tags             enable row level security;
alter table public.posts            enable row level security;
alter table public.post_tags        enable row level security;
alter table public.media            enable row level security;
alter table public.post_revisions   enable row level security;
alter table public.redirects        enable row level security;
alter table public.site_settings    enable row level security;
alter table public.subscribers      enable row level security;
alter table public.analytics_events enable row level security;

-- Idempotency for dev re-runs: drop-then-create every policy below.
drop policy if exists sites_select_public              on public.sites;
drop policy if exists profiles_select_own              on public.profiles;
drop policy if exists profiles_select_super_admin      on public.profiles;
drop policy if exists profile_sites_select_own         on public.profile_sites;
drop policy if exists profile_sites_select_super_admin on public.profile_sites;
drop policy if exists authors_select_public            on public.authors;
drop policy if exists authors_select_site_editor       on public.authors;
drop policy if exists authors_insert_site_admin        on public.authors;
drop policy if exists authors_update_site_admin        on public.authors;
drop policy if exists authors_delete_site_admin        on public.authors;
drop policy if exists categories_select_public         on public.categories;
drop policy if exists categories_select_site_editor    on public.categories;
drop policy if exists categories_insert_site_editor    on public.categories;
drop policy if exists categories_update_site_editor    on public.categories;
drop policy if exists categories_delete_site_admin     on public.categories;
drop policy if exists tags_select_public               on public.tags;
drop policy if exists tags_insert_site_member          on public.tags;
drop policy if exists tags_update_site_editor          on public.tags;
drop policy if exists tags_delete_site_admin           on public.tags;
drop policy if exists posts_select_public              on public.posts;
drop policy if exists posts_select_staff               on public.posts;
drop policy if exists posts_insert_staff               on public.posts;
drop policy if exists posts_update_site_editor         on public.posts;
drop policy if exists posts_update_own_author          on public.posts;
drop policy if exists posts_delete_site_admin          on public.posts;
drop policy if exists post_tags_select_public          on public.post_tags;
drop policy if exists post_tags_insert_can_edit        on public.post_tags;
drop policy if exists post_tags_update_can_edit        on public.post_tags;
drop policy if exists post_tags_delete_can_edit        on public.post_tags;
drop policy if exists media_select_public             on public.media;
drop policy if exists media_select_site_member        on public.media;
drop policy if exists media_insert_site_editor         on public.media;
drop policy if exists media_update_site_editor         on public.media;
drop policy if exists media_delete_site_editor         on public.media;
drop policy if exists post_revisions_select_can_edit   on public.post_revisions;
drop policy if exists post_revisions_insert_can_edit   on public.post_revisions;
drop policy if exists redirects_select_public          on public.redirects;
drop policy if exists redirects_insert_site_member     on public.redirects;
drop policy if exists redirects_update_site_admin      on public.redirects;
drop policy if exists redirects_delete_site_admin      on public.redirects;
drop policy if exists site_settings_select_public      on public.site_settings;
drop policy if exists site_settings_insert_site_admin  on public.site_settings;
drop policy if exists site_settings_update_site_admin  on public.site_settings;
drop policy if exists site_settings_delete_site_admin  on public.site_settings;
drop policy if exists subscribers_insert_public        on public.subscribers;
drop policy if exists subscribers_select_site_editor   on public.subscribers;
drop policy if exists subscribers_update_site_editor   on public.subscribers;
drop policy if exists subscribers_delete_site_admin    on public.subscribers;
drop policy if exists analytics_events_insert_public   on public.analytics_events;
drop policy if exists analytics_events_select_site_editor on public.analytics_events;

-- ---------------------------------------------------------------------------
-- 1. sites — the active site row is publicly readable (SiteContext resolves
-- the site id by slug from the client, anon or signed-in). Writes have NO
-- policies: sites are provisioned by operators/service-role only.
-- ---------------------------------------------------------------------------
create policy sites_select_public on public.sites
  for select to anon, authenticated
  using (is_active = true);

-- ---------------------------------------------------------------------------
-- 2. profiles — own row readable; super_admin reads all.
-- NO UPDATE/DELETE POLICIES ON PURPOSE: global role changes and account
-- deactivation happen in SQL by an operator, which makes self-promotion to
-- super_admin impossible through PostgREST. is_super_admin() is security
-- definer, so this SELECT policy reading profiles via the helper does not
-- recurse (invariant 6).
-- ---------------------------------------------------------------------------
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid());

create policy profiles_select_super_admin on public.profiles
  for select to authenticated
  using (public.is_super_admin());

-- ---------------------------------------------------------------------------
-- 3. profile_sites — site-scoped role assignments (the heart of multi-site).
-- Own rows readable (the CMS needs "which sites am I on, in what role"),
-- super_admin reads all. NO INSERT/UPDATE/DELETE POLICIES: memberships are
-- granted in SQL by an operator — nobody, not even an existing admin, can
-- mint or escalate a membership through the API.
-- ---------------------------------------------------------------------------
create policy profile_sites_select_own on public.profile_sites
  for select to authenticated
  using (profile_id = auth.uid());

create policy profile_sites_select_super_admin on public.profile_sites
  for select to authenticated
  using (public.is_super_admin());

-- ---------------------------------------------------------------------------
-- 4. authors — public identity records: active rows public, all rows for the
-- site's editors+; writes are admin+ OF THE ROW'S SITE (parity with 002,
-- now site-scoped).
-- ---------------------------------------------------------------------------
create policy authors_select_public on public.authors
  for select to anon, authenticated
  using (is_active = true);

create policy authors_select_site_editor on public.authors
  for select to authenticated
  using (public.is_site_editor(site_id));

create policy authors_insert_site_admin on public.authors
  for insert to authenticated
  with check (
    public.is_site_admin(site_id)
    and site_id in (select id from public.sites where is_active)
  );

create policy authors_update_site_admin on public.authors
  for update to authenticated
  using (public.is_site_admin(site_id))
  with check (public.is_site_admin(site_id));

create policy authors_delete_site_admin on public.authors
  for delete to authenticated
  using (public.is_site_admin(site_id));

-- ---------------------------------------------------------------------------
-- 5. categories — active rows public; site editors+ also see inactive rows.
-- Inserts require the target site to be active. Delete stays admin+.
-- ---------------------------------------------------------------------------
create policy categories_select_public on public.categories
  for select to anon, authenticated
  using (is_active = true);

create policy categories_select_site_editor on public.categories
  for select to authenticated
  using (public.is_site_editor(site_id));

create policy categories_insert_site_editor on public.categories
  for insert to authenticated
  with check (
    public.is_site_editor(site_id)
    and site_id in (select id from public.sites where is_active)
  );

create policy categories_update_site_editor on public.categories
  for update to authenticated
  using (public.is_site_editor(site_id))
  with check (public.is_site_editor(site_id));

create policy categories_delete_site_admin on public.categories
  for delete to authenticated
  using (public.is_site_admin(site_id));

-- ---------------------------------------------------------------------------
-- 6. tags — vocabulary is public. INSERT is deliberately open to EVERY
-- active site member (including the author role): the article-save flow
-- (_syncTags in supabase_article_repository) auto-creates missing tags for
-- ANY tier that can save a post, so locking it to editors would abort an
-- author's save halfway. Editing/removing the shared vocabulary stays
-- privileged. Signup-default 'author' users pass this only after an operator
-- adds a profile_sites row, and only for that site.
-- ---------------------------------------------------------------------------
create policy tags_select_public on public.tags
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.sites s
      where s.id = tags.site_id and s.is_active
    )
  );

create policy tags_insert_site_member on public.tags
  for insert to authenticated
  with check (
    public.is_site_member(site_id)
    and site_id in (select id from public.sites where is_active)
  );

create policy tags_update_site_editor on public.tags
  for update to authenticated
  using (public.is_site_editor(site_id))
  with check (public.is_site_editor(site_id));

create policy tags_delete_site_admin on public.tags
  for delete to authenticated
  using (public.is_site_admin(site_id));

-- ---------------------------------------------------------------------------
-- 7. posts — the core table.
-- Public feed: published + scheduled rows whose time has passed, for anon
-- AND authenticated alike (invariant 1).
-- Staff read: editors+ OF THE ROW'S SITE see everything (drafts, archived,
-- future-scheduled); an author-tier member additionally sees only posts
-- carrying their own linked byline — never another site's or another
-- author's drafts (invariants 2 + 3).
-- ---------------------------------------------------------------------------
create policy posts_select_public on public.posts
  for select to anon, authenticated
  using (
    status = 'published'
    or (status = 'scheduled' and scheduled_for is not null and scheduled_for <= now())
  );

create policy posts_select_staff on public.posts
  for select to authenticated
  using (
    public.is_site_editor(site_id)
    or (public.is_linked_author(author_id) and public.is_site_member(site_id))
  );

-- INSERT: site editors+ file any post for their site; an author-tier member
-- may only file a DRAFT under their own linked byline (publishing is an
-- editorial decision, matching RolePermissions.canPublish in the app).
create policy posts_insert_staff on public.posts
  for insert to authenticated
  with check (
    site_id in (select id from public.sites where is_active)
    and (
      public.is_site_editor(site_id)
      or (
        public.is_site_member(site_id)
        and public.is_linked_author(author_id)
        and status = 'draft'
      )
    )
  );

-- UPDATE: editors+ of the row's site manage everything.
create policy posts_update_site_editor on public.posts
  for update to authenticated
  using (public.is_site_editor(site_id))
  with check (public.is_site_editor(site_id));

-- UPDATE (author tier): own byline only, and the caller must be a member of
-- that post's site — is_linked_author alone does not prove site membership,
-- because posts.author_id is not schema-constrained to the same site.
-- Note: like the old policy, an author moving their own published post stays
-- allowed (WITH CHECK cannot compare old vs new status in one permissive
-- policy); UI gating (canPublish) remains the publish control for authors.
create policy posts_update_own_author on public.posts
  for update to authenticated
  using (
    public.is_linked_author(author_id)
    and public.is_site_member(site_id)
  )
  with check (
    public.is_linked_author(author_id)
    and public.is_site_member(site_id)
  );

-- DELETE: admins only, scoped to the row's site.
create policy posts_delete_site_admin on public.posts
  for delete to authenticated
  using (public.is_site_admin(site_id));

-- ---------------------------------------------------------------------------
-- 8. post_tags — junction rows are readable for publicly visible posts only,
-- so draft/archived byline+tag combinations never leak. Writes follow
-- can_edit_post(post_id): editors+ of the post's site or the linked author of
-- that post — so an author saving an article never aborts halfway through tag
-- syncing (delete-then-insert in _syncTags).
-- ---------------------------------------------------------------------------
create policy post_tags_select_public on public.post_tags
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.posts p
      where p.id = post_tags.post_id
        and (
          p.status = 'published'
          or (p.status = 'scheduled' and p.scheduled_for is not null and p.scheduled_for <= now())
        )
    )
    or public.can_edit_post(post_tags.post_id)
  );

create policy post_tags_insert_can_edit on public.post_tags
  for insert to authenticated
  with check (public.can_edit_post(post_id));

create policy post_tags_update_can_edit on public.post_tags
  for update to authenticated
  using (public.can_edit_post(post_id))
  with check (public.can_edit_post(post_id));

create policy post_tags_delete_can_edit on public.post_tags
  for delete to authenticated
  using (public.can_edit_post(post_id));

-- ---------------------------------------------------------------------------
-- 9. media — the registry is STAFF-ONLY. Delivering images to visitors never
-- touches this table: public pages render the `public_url` text already stored
-- on the post/author rows, and the bucket itself is public, so `/object/public/
-- <path>` is served from the bucket flag and bypasses RLS. A `using (true)`
-- read here therefore added nothing for visitors while letting any anon caller
-- enumerate every object key (including assets attached only to drafts), which
-- is exactly the bucket-listing exposure the tightened storage policy in 004
-- closes — it would have re-opened the hole one layer up. Writes are editor+
-- OF THE ROW'S SITE. storage_path guard kept from 002. The matching Storage
-- object policies live in 004_storage_policies.sql (same is_site_editor gate,
-- folder = site slug).
-- ---------------------------------------------------------------------------
create policy media_select_site_member on public.media
  for select to authenticated
  using (public.is_site_member(site_id));

create policy media_insert_site_editor on public.media
  for insert to authenticated
  with check (
    public.is_site_editor(site_id)
    and storage_path is not null
    and site_id in (select id from public.sites where is_active)
  );

create policy media_update_site_editor on public.media
  for update to authenticated
  using (public.is_site_editor(site_id))
  with check (public.is_site_editor(site_id));

create policy media_delete_site_editor on public.media
  for delete to authenticated
  using (public.is_site_editor(site_id));

-- ---------------------------------------------------------------------------
-- 10. post_revisions — immutable history (no UPDATE/DELETE policies).
-- Read/write gate is can_edit_post(post_id): site editors+ or the post's
-- linked author. Anon, other-authenticated and non-member authors see
-- nothing (revision content can contain unpublished drafts). The revision
-- save flow's `select revision_number` in updateArticle is covered by the
-- same SELECT policy.
-- ---------------------------------------------------------------------------
create policy post_revisions_select_can_edit on public.post_revisions
  for select to authenticated
  using (public.can_edit_post(post_id));

create policy post_revisions_insert_can_edit on public.post_revisions
  for insert to authenticated
  with check (public.can_edit_post(post_id));

-- ---------------------------------------------------------------------------
-- 11. redirects — the public 301 map (anon must resolve indexed legacy URLs).
-- INSERT open to every active site member: BOTH editor and author save paths
-- register the 301 produced by a slug change (updateArticle). Admin+ manages
-- (update/delete) the map.
-- ---------------------------------------------------------------------------
create policy redirects_select_public on public.redirects
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.sites s
      where s.id = redirects.site_id and s.is_active
    )
  );

create policy redirects_insert_site_member on public.redirects
  for insert to authenticated
  with check (
    public.is_site_member(site_id)
    and site_id in (select id from public.sites where is_active)
  );

create policy redirects_update_site_admin on public.redirects
  for update to authenticated
  using (public.is_site_admin(site_id))
  with check (public.is_site_admin(site_id));

create policy redirects_delete_site_admin on public.redirects
  for delete to authenticated
  using (public.is_site_admin(site_id));

-- ---------------------------------------------------------------------------
-- 12. site_settings — public read (mirrors what the site already renders in
-- HTML), restricted to rows of ACTIVE sites so a deactivated site's settings
-- disappear. Writes are admin+ OF THE ROW'S SITE.
-- SECURITY NOTE: this table is publicly readable and MUST NEVER contain
-- secrets (no API keys, tokens, passwords). Secrets live only in Supabase
-- server-side env vars / Vault, never here.
-- ---------------------------------------------------------------------------
create policy site_settings_select_public on public.site_settings
  for select to anon, authenticated
  using (site_id in (select id from public.sites where is_active = true));

create policy site_settings_insert_site_admin on public.site_settings
  for insert to authenticated
  with check (
    public.is_site_admin(site_id)
    and site_id in (select id from public.sites where is_active)
  );

create policy site_settings_update_site_admin on public.site_settings
  for update to authenticated
  using (public.is_site_admin(site_id))
  with check (public.is_site_admin(site_id));

create policy site_settings_delete_site_admin on public.site_settings
  for delete to authenticated
  using (public.is_site_admin(site_id));

-- ---------------------------------------------------------------------------
-- 13. subscribers — emails are private: NO anonymous SELECT/UPDATE/DELETE.
-- The subscribe form works for anon AND signed-in readers (invariant 1) and
-- is value-constrained: a fresh signup cannot self-verify, deactivate, or
-- smuggle an unsubscribe timestamp through the API.
-- Management is editor+ OF THE ROW'S SITE (newsletter admin is content
-- ops); deletion is admin+ so subscriber lists cannot be wiped by editors.
-- ---------------------------------------------------------------------------
create policy subscribers_insert_public on public.subscribers
  for insert to anon, authenticated
  with check (
    email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    and is_verified = false
    and is_active = true
    and unsubscribed_at is null
  );

create policy subscribers_select_site_editor on public.subscribers
  for select to authenticated
  using (public.is_site_editor(site_id));

create policy subscribers_update_site_editor on public.subscribers
  for update to authenticated
  using (public.is_site_editor(site_id))
  with check (public.is_site_editor(site_id));

create policy subscribers_delete_site_admin on public.subscribers
  for delete to authenticated
  using (public.is_site_admin(site_id));

-- ---------------------------------------------------------------------------
-- 14. analytics_events — append-only. Anonymous beacons may ONLY emit the
-- whitelisted public event types against an ACTIVE site; nothing else is
-- writable by anon, and there is no anonymous SELECT. Reporting read is
-- editor+ OF THE ROW'S SITE.
-- ---------------------------------------------------------------------------
create policy analytics_events_insert_public on public.analytics_events
  for insert to anon, authenticated
  with check (
    event_type in ('page_view','article_view')
    and site_id in (select id from public.sites where is_active)
  );

create policy analytics_events_select_site_editor on public.analytics_events
  for select to authenticated
  using (public.is_site_editor(site_id));

-- End of 003_rls_policies.sql
