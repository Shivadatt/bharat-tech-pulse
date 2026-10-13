-- ============================================================================
-- 009_rls_hardening.sql — Bharat Tech Pulse (site india_tech)
-- Forward-only RLS hardening over 001..008.
--
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ STATUS: DRAFT — WRITTEN 2026-10-13, NOT APPLIED TO ANY ENVIRONMENT.   │
-- │ Nothing in this file has been executed. The live project              │
-- │ (ylzwuwfhlqomjqcdrpxk) still runs 001..008 exactly as verified.       │
-- └────────────────────────────────────────────────────────────────────────┘
--
-- WHAT THIS FILE CHANGES (the 4 accepted exposures + 5 further defects found by
-- reading 001..008 and the Flutter repository layer):
--   1. public reads did not prove sites.is_active      (posts, authors,
--      categories — tags/redirects/site_settings already did)
--   2. analytics_events INSERT had no post_id proof, no value caps, no quota
--   3. site_settings anon SELECT exposed EVERY column (column-level exposure
--      is not expressible in RLS -> moved to a view, see section 4 for why)
--   4. redirects INSERT let the author tier plant a 301 for ANY path
--   5. subscribers INSERT had NO site predicate at all
--   6. post_tags INSERT/UPDATE never checked that the tag belongs to the
--      post's site
--   7. posts INSERT never checked that category_id / author_id belong to the
--      post's site
--   8. media INSERT/UPDATE accepted a storage_path outside the owner site's
--      folder
--   9. Storage object keys accepted '..' segments that still satisfied
--      foldername(name)[1] = 'india_tech'
--
-- GATE — DO NOT APPLY BEFORE BOTH ARE TRUE:
--   (a) The Flutter agent has landed the `site_settings_public` read for the
--       public surface. Today `lib/main.dart:67` ->
--       `SupabaseSiteSettingsRepository.getSettings()` reads the
--       `site_settings` TABLE, which after section 4 returns 0 rows for
--       visitors, so the DB-held GA4 id would silently stop loading
--       (fail-soft: the call is wrapped in try/catch, nothing crashes).
--       Admin screens keep working: they pass the new
--       `site_settings_select_site_member` policy.
--   (b) The owner has pasted the read-only queries from
--       supabase/operator/020_security_verification.sql and section 6 of that
--       file reports no blocker (analytics_events duplicate-beacon minutes,
--       Postgres version for `nulls not distinct`, live policy inventory).
--
-- IDEMPOTENCY: every statement is drop-then-create / create-if-not-exists /
-- create-or-replace and every guard is value-based, so re-running either
-- changes 0 rows or re-derives the identical object. The final `do $$` block
-- compares the resulting pg_policies inventory against an explicit expectation
-- list and RAISEs unless they match, so a partial apply cannot go unnoticed:
-- the whole file is one transaction and aborts itself.
--
── HELPER EXECUTE (invariant 7 of 003): section 2 adds a NEW security-definer
-- helper called from a policy, so it carries the same explicit
-- revoke-from-PUBLIC / grant-to-anon,authenticated,service_role pattern.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Public reads must prove the ROW'S SITE is active.
--    posts_select_public leaked a deactivated site's published posts;
--    authors_select_public / categories_select_public leaked them for every
--    site unconditionally. Deprocessing a site is the documented off switch
--    (supabase/operator/010_bootstrap_first_admin.sql footer), so it has to
--    actually work.
--    RLS note: the subquery on public.sites is itself policy-filtered
--    (sites_select_public -> is_active), so it narrows to exactly the same
--    rows it asks about. No recursion: sites references no other table.
-- ---------------------------------------------------------------------------
drop policy if exists posts_select_public on public.posts;
create policy posts_select_public on public.posts
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.sites s
      where s.id = posts.site_id and s.is_active
    )
    and (
      status = 'published'
      or (status = 'scheduled' and scheduled_for is not null and scheduled_for <= now())
    )
  );

drop policy if exists authors_select_public on public.authors;
create policy authors_select_public on public.authors
  for select to anon, authenticated
  using (
    is_active = true
    and exists (
      select 1 from public.sites s
      where s.id = authors.site_id and s.is_active
    )
  );

drop policy if exists categories_select_public on public.categories;
create policy categories_select_public on public.categories
  for select to anon, authenticated
  using (
    is_active = true
    and exists (
      select 1 from public.sites s
      where s.id = categories.site_id and s.is_active
    )
  );

-- ---------------------------------------------------------------------------
-- 2. analytics_events — the append-only public beacon.
--
--    The old WITH CHECK constrained only event_type and an active site, so an
--    anonymous caller could write a row for an arbitrary post_id (any draft,
--    archived or sibling-site post; the FK made a *nonexistent* id fail with
--    23503, which is itself an existence oracle), with unlimited path/session/
--    referrer sizes and a client-supplied created_at (history forgery +
--    retention evasion). Nothing bounded the row count, so the table was an
--    unbounded growth vector on a metered plan.
--
--    Closure here:
--      * post_id must be a publicly visible post OF THE SAME SITE — exactly
--        the set posts_select_public serves, so a beacon can never reference
--        content the caller cannot read.
--      * value caps on session_id / path / referrer + a non-null session key.
--      * created_at must be "now" (defaults fill it; only a hand-crafted
--        request sends it, and that request is now rejected).
--      * a per-session per-minute budget, enforced by the definer helper
--        below (a plain subquery in the policy cannot count rows: anon has no
--        SELECT policy on this table, so it would always see zero).
--      * a unique dedupe index (section 2c) and a retention pruner
--        (section 2d) for the growth cost itself.
--    RLS cannot rate-limit by IP and there is no IP column; the budget is
--    per session key, which an attacker can rotate. That limit is stated
--    honestly in the report, not hidden here.
-- ---------------------------------------------------------------------------

-- 2a. Budget helper. SECURITY DEFINER is load-bearing (it must count rows the
--     caller may not select), search_path pinned, returns only a boolean.
--     RESIDUAL, stated honestly: anon needs EXECUTE here (003 invariant 7), so
--     PostgREST also exposes /rpc/beacon_budget_ok. It leaks at most one boolean
--     per call about a session key ("that session crossed 60 beacons this
--     minute"), which is not a row, not a count, and not another site's data.
--     If even that is unwanted, move the helper into a non-exposed schema
--     (create schema beacon; ... set search_path = beacon, public) — a policy can
--     call it with EXECUTE granted to the client roles, while PostgREST stops
--     offering it as an RPC. Not done here: one new schema in a shared database
--     is a bigger change than the residual it removes.
create or replace function public.beacon_budget_ok(p_site uuid, p_session text)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select (
    select count(*)
    from public.analytics_events e
    where e.site_id    = p_site
      and e.session_id = p_session
      and e.created_at > now() - interval '1 minute'
  ) < 60;
$fn$;

revoke execute on function public.beacon_budget_ok(uuid, text) from public;
grant  execute on function public.beacon_budget_ok(uuid, text)
  to anon, authenticated, service_role;

-- 2b. The tightened insert policy.
drop policy if exists analytics_events_insert_public on public.analytics_events;
create policy analytics_events_insert_public on public.analytics_events
  for insert to anon, authenticated
  with check (
    event_type in ('page_view','article_view')
    and site_id in (select id from public.sites where is_active)
    and session_id is not null
    and session_id <> ''
    and char_length(session_id) <= 64
    and (path     is null or char_length(path)     <= 2048)
    and (referrer is null or char_length(referrer) <= 2048)
    and created_at >= now() - interval '1 minute'
    and created_at <= now() + interval '1 minute'
    and public.beacon_budget_ok(site_id, session_id)
    and (
      post_id is null
      or exists (
        select 1 from public.posts p
        where p.id      = analytics_events.post_id
          and p.site_id = analytics_events.site_id
          and (
            p.status = 'published'
            or (p.status = 'scheduled'
                and p.scheduled_for is not null
                and p.scheduled_for <= now())
          )
      )
    )
  );

-- analytics_events keeps its staff-only SELECT policy unchanged; there is
-- still no anon/authenticated read and no UPDATE/DELETE (append-only).

-- 2c. Dedupe + budget-supporting indexes. The unique index collapses
--     identical beacons (same site/session/event/path/minute) to one row; the
--     second index makes the budget helper's range scan cheap.
--     The duplicate pre-flight is required: CREATE UNIQUE INDEX aborts the
--     transaction if legacy rows already collide, and the owner must not lose
--     the rest of the hardening over demo analytics. The self-check in
--     section 6 accepts the index being absent ONLY when collisions exist.
create index if not exists analytics_events_beacon_window_idx
  on public.analytics_events (site_id, session_id, created_at);

do $guard$
begin
  if exists (
    select 1
    from public.analytics_events
    group by site_id, session_id, event_type, path, date_trunc('minute', created_at)
    having count(*) > 1
  ) then
    raise notice '009: analytics_events already contains duplicate beacon minutes - dedupe index SKIPPED. Prune or accept, then re-run 009 (idempotent).';
  else
    create unique index if not exists analytics_events_beacon_dedupe_idx
      on public.analytics_events (
        site_id, session_id, event_type, path,
        (date_trunc('minute', created_at))
      ) nulls not distinct;   -- requires PostgreSQL 15 (see operator/020 section 1)
    raise notice '009: analytics_events_beacon_dedupe_idx created.';
  end if;
end
$guard$;

-- 2d. Retention pruner. NOT scheduled by this file: a cron job is an ops
--     decision with a cost/accuracy trade-off, so the schedule statement is
--     provided in supabase/operator/020_security_verification.sql for the
--     owner to run deliberately. Locked down like the other definer helpers.
create or replace function public.prune_analytics_events(p_keep interval default '180 days')
returns integer
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v integer;
begin
  if p_keep < interval '7 days' then
    raise exception 'prune_analytics_events: refuse to keep less than 7 days of history';
  end if;
  delete from public.analytics_events
   where created_at < now() - p_keep;
  get diagnostics v = row_count;
  return v;
end;
$fn$;

revoke execute on function public.prune_analytics_events(interval) from public;
revoke execute on function public.prune_analytics_events(interval)
  from anon, authenticated, service_role;
grant execute on function public.prune_analytics_events(interval) to postgres;

-- ---------------------------------------------------------------------------
-- 3. redirects — writes to editor+, with the author tier kept alive only for
--    the save flow that actually needs it.
--
--    redirects_insert_site_member let ANY active member, including the signup
--    default tier, insert a 301 for an arbitrary path: an author-tier member
--    could point /article/<someone else's slug> or /contact-us at any target,
--    i.e. poison a sibling author's published URL. The legitimate need is
--    narrower and provable: updateArticle registers the 301 of the slug the
--    caller just edited, and it inserts the redirect BEFORE the posts UPDATE,
--    so old_path is still the caller's own post slug at that moment.
--    Therefore: editor+ freely; author tier only for a path that resolves to
--    a post of THIS site whose byline is linked to the caller.
--    posts_select_staff makes that post visible to exactly that caller, so
--    the EXISTS below is evaluated with RLS on and still succeeds.
--    Value guards: leading slash, length cap, no self-redirect, real codes.
--    The client validator (SupabaseRedirectRepository._pathPattern = ^/[^\s]*$)
--    is deliberately NOT copied in full: the article save flow builds old_path
--    straight from the stored slug (supabase_article_repository.dart:571 with
--    _publicArticlePath at :349) WITHOUT running that validator, and the admin
--    form passes a hand-typed slug through verbatim
--    (admin_article_controller.dart:185-187), so a slug containing a space is
--    reachable. A no-whitespace guard here would then reject the redirect insert
--    and abort the whole article save (the repository re-throws any non-23505
--    PostgrestException) — a policy that breaks a legitimate save is a
--    regression, not a hardening. Whitespace in a path is a hygiene problem for
--    the client-side validator to fix, not a security boundary.
-- ---------------------------------------------------------------------------
drop policy if exists redirects_insert_site_member on public.redirects;
drop policy if exists redirects_insert_content_editor on public.redirects;
create policy redirects_insert_content_editor on public.redirects
  for insert to authenticated
  with check (
    site_id in (select id from public.sites where is_active)
    and char_length(old_path) <= 2048
    and char_length(new_path) <= 2048
    and old_path like '/%'
    and new_path like '/%'
    and old_path <> new_path
    and status_code in (301, 302, 307, 308)
    and (
      public.is_site_editor(site_id)
      or (
        public.is_site_member(site_id)
        and exists (
          select 1 from public.posts p
          where p.site_id   = redirects.site_id
            and '/article/' || p.slug = redirects.old_path
            and public.is_linked_author(p.author_id)
        )
      )
    )
  );

-- redirects UPDATE/DELETE stay is_site_admin (unchanged) and
-- redirects_select_public already requires an active site.

-- ---------------------------------------------------------------------------
-- 4. site_settings — column-level exposure.
--
--    RLS is ROW-granular: a policy cannot hide one column, and column-level
--    GRANTs make a `select *` (what the client sends) ERROR rather than mask
--    the column. So the right mechanism is a VIEW that simply does not project
--    the private column, plus removing the anon read on the table itself.
--
--    Load-bearing property: a non-security_invoker view queries its base
--    table AS THE VIEW OWNER. The owner here is the migration role that also
--    owns site_settings, and site_settings has relforcerowsecurity = false,
--    so RLS is bypassed inside the view -> the view's own WHERE is the ONLY
--    thing that scopes what anon sees. That is why:
--      * the join to sites with s.is_active is mandatory (it replaces the
--        predicate the dropped policy used to apply), and
--      * section 6 aborts unless the view owner IS the table owner (a view
--        owned by a different role would return zero rows, silently).
--    Only contact_email is withheld: every other column is already rendered in
--    public HTML (footer / meta / JSON-LD), and google_analytics_id must stay
--    readable because lib/main.dart:_applyDatabaseGaId() feeds it to GA4.
--    A GA4 property id is public by construction; a staff mailbox is not.
-- ---------------------------------------------------------------------------
drop view if exists public.site_settings_public;
create view public.site_settings_public
  with (security_invoker = false)
as
select ss.id,
       ss.site_id,
       ss.site_name,
       ss.tagline,
       ss.logo_url,
       ss.favicon_url,
       ss.default_meta_title,
       ss.default_meta_description,
       ss.social_links,
       ss.footer_text,
       ss.copyright_text,
       ss.google_analytics_id,
       ss.created_at,
       ss.updated_at
  from public.site_settings ss
  join public.sites s on s.id = ss.site_id and s.is_active;

revoke all on public.site_settings_public from anon, authenticated, service_role;
grant select on public.site_settings_public to anon, authenticated, service_role;

drop policy if exists site_settings_select_public on public.site_settings;
drop policy if exists site_settings_select_site_member on public.site_settings;
create policy site_settings_select_site_member on public.site_settings
  for select to authenticated
  using (public.is_site_member(site_id));
-- The table is now staff-read only (full row, contact_email included, for the
-- settings/SEO screens); visitors get the view.

-- ---------------------------------------------------------------------------
-- 5. Referential-integrity defects that weaken site isolation.
--    Each predicate below is satisfied by every payload the current client
--    sends (verified against the repository insert maps) and rejects only
--    hand-crafted cross-site writes.
-- ---------------------------------------------------------------------------

-- 5a. subscribers INSERT had NO site predicate: an anonymous caller could
--     seed a newsletter row into ANY site (including a sibling site the
--     request has nothing to do with) with an unbounded email/name payload.
drop policy if exists subscribers_insert_public on public.subscribers;
create policy subscribers_insert_public on public.subscribers
  for insert to anon, authenticated
  with check (
    email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    and char_length(email) <= 320
    and (name is null or char_length(name) <= 200)
    and is_verified = false
    and is_active = true
    and unsubscribed_at is null
    and subscribed_at >= now() - interval '1 minute'
    and subscribed_at <= now() + interval '1 minute'
    and site_id in (select id from public.sites where is_active)
  );

-- 5b. post_tags: tag_id was never checked against the post's site, so a
--     member could attach a sibling site's tag (tags are publicly readable,
--     so the ids are harvestable) to their own post.
drop policy if exists post_tags_insert_can_edit on public.post_tags;
create policy post_tags_insert_can_edit on public.post_tags
  for insert to authenticated
  with check (
    public.can_edit_post(post_id)
    and exists (
      select 1
      from public.posts p, public.tags t
      where p.id = post_tags.post_id
        and t.id = post_tags.tag_id
        and t.site_id = p.site_id
    )
  );

drop policy if exists post_tags_update_can_edit on public.post_tags;
create policy post_tags_update_can_edit on public.post_tags
  for update to authenticated
  using (
    public.can_edit_post(post_id)
    and exists (
      select 1
      from public.posts p, public.tags t
      where p.id = post_tags.post_id
        and t.id = post_tags.tag_id
        and t.site_id = p.site_id
    )
  )
  with check (
    public.can_edit_post(post_id)
    and exists (
      select 1
      from public.posts p, public.tags t
      where p.id = post_tags.post_id
        and t.id = post_tags.tag_id
        and t.site_id = p.site_id
    )
  );
-- DELIBERATELY NOT tightened: post_tags_delete_can_edit. A junction row that
-- already violates tag-site consistency must stay deletable, or the defect
-- becomes unrepairable by the very role that can edit the post.

-- 5c. posts INSERT: category_id / author_id were unconstrained relative to
--     site_id. Enforced on INSERT only. On UPDATE it is deliberately NOT
--     enforced: posts_update_* re-checks the NEW row, so a post whose category
--     was later deactivated (invisible to an author-tier member under
--     categories_select_public) would become permanently uneditable with a
--     confusing 403. That drift is an editorial-integrity concern, not a
--     security boundary; the security boundary is that a row can never be
--     BORN cross-site.
drop policy if exists posts_insert_staff on public.posts;
create policy posts_insert_staff on public.posts
  for insert to authenticated
  with check (
    site_id in (select id from public.sites where is_active)
    and (
      author_id is null
      or exists (
        select 1 from public.authors a
        where a.id = posts.author_id and a.site_id = posts.site_id
      )
    )
    and (
      category_id is null
      or exists (
        select 1 from public.categories c
        where c.id = posts.category_id and c.site_id = posts.site_id
      )
    )
    and (
      public.is_site_editor(site_id)
      or (
        public.is_site_member(site_id)
        and public.is_linked_author(author_id)
        and status = 'draft'
      )
    )
  );

-- 5d. media.storage_path: only `is not null` was required, so an editor could
--     register a row pointing at another site's folder or at a foreign key
--     inside the shared bucket. The object-level gate in 004 pins the folder;
--     the registry row must pin it identically (sites.slug == first path
--     segment, which is exactly what SupabaseMediaRepository builds).
drop policy if exists media_insert_site_editor on public.media;
create policy media_insert_site_editor on public.media
  for insert to authenticated
  with check (
    public.is_site_editor(site_id)
    and storage_path is not null
    and char_length(storage_path) <= 1024
    and storage_path not like '/%'
    and storage_path not like '%/..%'
    and storage_path not like '../%'
    and storage_path not like '%/..'
    and split_part(storage_path, '/', 1) =
        (select s.slug from public.sites s where s.id = media.site_id)
    and site_id in (select id from public.sites where is_active)
  );

drop policy if exists media_update_site_editor on public.media;
create policy media_update_site_editor on public.media
  for update to authenticated
  using (public.is_site_editor(site_id))
  with check (
    public.is_site_editor(site_id)
    and storage_path is not null
    and char_length(storage_path) <= 1024
    and storage_path not like '/%'
    and storage_path not like '%/..%'
    and storage_path not like '../%'
    and storage_path not like '%/..'
    and split_part(storage_path, '/', 1) =
        (select s.slug from public.sites s where s.id = media.site_id)
  );

-- 5e. Storage object keys: foldername(name)[1] = 'india_tech' is satisfied by
--     'india_tech/../../<other>/x.png'. The key is stored verbatim, so whether
--     such a key can actually be served or listed is a storage-service
--     behaviour this audit cannot prove from here (operator/020 section 7
--     measures it read-only); the policy must not depend on that answer.
--     Same traversal set added to INSERT and to BOTH sides of UPDATE, so an
--     object can never be moved across the site prefix either.
drop policy if exists "media_site_editor_insert" on storage.objects;
create policy "media_site_editor_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'india_tech'
    and name not like '%/..%'
    and name not like '../%'
    and name not like '%/..'
    and public.is_site_editor(
      (select s.id from public.sites s
        where s.slug = 'india_tech' and s.is_active)
    )
  );

drop policy if exists "media_site_editor_update" on storage.objects;
create policy "media_site_editor_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'india_tech'
    and name not like '%/..%'
    and name not like '../%'
    and name not like '%/..'
    and public.is_site_editor(
      (select s.id from public.sites s
        where s.slug = 'india_tech' and s.is_active)
    )
  )
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'india_tech'
    and name not like '%/..%'
    and name not like '../%'
    and name not like '%/..'
    and public.is_site_editor(
      (select s.id from public.sites s
        where s.slug = 'india_tech' and s.is_active)
    )
  );

-- ============================================================================
-- MULTI-SITE FOLLOW-UP — COMMENTED ON PURPOSE, NOT PART OF THIS APPLY.
-- 004 and section 5e pin the top-level folder to the literal 'india_tech'.
-- That is the correct, tighter state while exactly one site exists, and it is
-- also the blocker for site #2: no member of any other site can upload.
-- When the second site is provisioned, replace the folder predicates with the
-- owning site derived FROM THE FOLDER (still one shared bucket, still one
-- site-scoped editor check, still no cross-folder write):
--   and (storage.foldername(name))[1] in (
--         select s.slug from public.sites s
--          where s.is_active
--            and public.is_site_editor(s.id))
-- Do NOT apply this edit while sites has one row only: it changes the meaning
-- of "cannot escape the seeded prefix" from a literal to a derived check and
-- must land with the second-site provisioning + a live isolation probe.
--
-- SAME SHAPE OF LIMITATION, PUBLIC WRITES (be honest about what 009 does NOT
-- fix): analytics_events_insert_public and subscribers_insert_public constrain
-- site_id to "ANY ACTIVE SITE", not to "the site this request belongs to",
-- because a PostgREST request carries no site identity — anon cannot prove
-- which site it came from. Today (one site) that is a no-op difference. With
-- site #2 live, an anonymous caller on site A's origin can attribute beacons or
-- newsletter signups to site B. The fix is identity, not a predicate:
--   * derive the site from the Origin/Host the client sends and pin it in a
--     request GUC (or put site_id in the JWT claim / in a per-site Edge
--     Function that forwards beacons), then
--   * replace `site_id in (select id from public.sites where is_active)` with
--     `site_id = public.current_site_id()` in both INSERT policies.
-- Neither is possible while the client sends a bare site_id, so 009 leaves the
-- predicate as it is and records the follow-up here.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 6. SELF-CHECK. Aborts the whole transaction unless the resulting policy
--    inventory is exactly what this file intended. Three independent layers:
--      6.1 exact set equality of (policyname, table, command, anon-allowed)
--          for every policy in the public schema;
--      6.2 required predicate fragments present on the hardened policies;
--      6.3 structural invariants: no USING(true)/WITH CHECK(true), every
--          SELECT policy carries a USING clause, anon appears in exactly the
--          9 sanctioned policies, RLS enabled, view owner == table owner and
--          the view does not project contact_email.
--    Read-only verification queries the owner runs BEFORE and AFTER applying
--    live in supabase/operator/020_security_verification.sql.
-- ---------------------------------------------------------------------------
do $selfcheck$
declare
  v          int;
  r          record;
  expr       text;
  v_expected constant int := 49;   -- 003 declares 49; 009 renames 2, adds 0 net
  v_defs     text;
begin
  -- ---- 6.1 exact inventory ----------------------------------------------
  with expected(policyname, tablename, cmd, anon_allowed) as (
    values
      ('sites_select_public','sites','SELECT', true),
      ('profiles_select_own','profiles','SELECT', false),
      ('profiles_select_super_admin','profiles','SELECT', false),
      ('profile_sites_select_own','profile_sites','SELECT', false),
      ('profile_sites_select_super_admin','profile_sites','SELECT', false),
      ('authors_select_public','authors','SELECT', true),
      ('authors_select_site_editor','authors','SELECT', false),
      ('authors_insert_site_admin','authors','INSERT', false),
      ('authors_update_site_admin','authors','UPDATE', false),
      ('authors_delete_site_admin','authors','DELETE', false),
      ('categories_select_public','categories','SELECT', true),
      ('categories_select_site_editor','categories','SELECT', false),
      ('categories_insert_site_editor','categories','INSERT', false),
      ('categories_update_site_editor','categories','UPDATE', false),
      ('categories_delete_site_admin','categories','DELETE', false),
      ('tags_select_public','tags','SELECT', true),
      ('tags_insert_site_member','tags','INSERT', false),
      ('tags_update_site_editor','tags','UPDATE', false),
      ('tags_delete_site_admin','tags','DELETE', false),
      ('posts_select_public','posts','SELECT', true),
      ('posts_select_staff','posts','SELECT', false),
      ('posts_insert_staff','posts','INSERT', false),
      ('posts_update_site_editor','posts','UPDATE', false),
      ('posts_update_own_author','posts','UPDATE', false),
      ('posts_delete_site_admin','posts','DELETE', false),
      ('post_tags_select_public','post_tags','SELECT', true),
      ('post_tags_insert_can_edit','post_tags','INSERT', false),
      ('post_tags_update_can_edit','post_tags','UPDATE', false),
      ('post_tags_delete_can_edit','post_tags','DELETE', false),
      ('media_select_site_member','media','SELECT', false),
      ('media_insert_site_editor','media','INSERT', false),
      ('media_update_site_editor','media','UPDATE', false),
      ('media_delete_site_editor','media','DELETE', false),
      ('post_revisions_select_can_edit','post_revisions','SELECT', false),
      ('post_revisions_insert_can_edit','post_revisions','INSERT', false),
      ('redirects_select_public','redirects','SELECT', true),
      ('redirects_insert_content_editor','redirects','INSERT', false),
      ('redirects_update_site_admin','redirects','UPDATE', false),
      ('redirects_delete_site_admin','redirects','DELETE', false),
      ('site_settings_select_site_member','site_settings','SELECT', false),
      ('site_settings_insert_site_admin','site_settings','INSERT', false),
      ('site_settings_update_site_admin','site_settings','UPDATE', false),
      ('site_settings_delete_site_admin','site_settings','DELETE', false),
      ('subscribers_select_site_editor','subscribers','SELECT', false),
      ('subscribers_insert_public','subscribers','INSERT', true),
      ('subscribers_update_site_editor','subscribers','UPDATE', false),
      ('subscribers_delete_site_admin','subscribers','DELETE', false),
      ('analytics_events_select_site_editor','analytics_events','SELECT', false),
      ('analytics_events_insert_public','analytics_events','INSERT', true)
  ), actual as (
    -- pg_policies.tablename/policyname are `name`; cast explicitly so EXCEPT
    -- cannot fall back to a cross-type operator the parser would reject.
    select policyname::text  as policyname,
           tablename::text   as tablename,
           cmd::text         as cmd,
           ('anon' = any (roles)) as anon_allowed
      from pg_policies
     where schemaname = 'public'
  ), diff as (
    select 'missing: ' || d.policyname || ' (' || d.tablename || ' ' || d.cmd || ')' as what
      from (select policyname, tablename, cmd, anon_allowed from expected
            except
            select policyname, tablename, cmd, anon_allowed from actual) d
    union all
    select 'unexpected: ' || u.policyname || ' (' || u.tablename || ' ' || u.cmd || ')'
      from (select policyname, tablename, cmd, anon_allowed from actual
            except
            select policyname, tablename, cmd, anon_allowed from expected) u
  )
  -- one CTE feeds exactly one statement, so the row count and the readable
  -- description of the symmetric difference are collected in the same SELECT.
  select count(*), string_agg(what, ' | ') into v, v_defs from diff;
  if v <> 0 then
    raise exception '009 self-check: policy inventory differs from expectation (% differing row(s)): %',
      v, coalesce(v_defs, 'n/a');
  end if;

  if (select count(*) from pg_policies where schemaname = 'public') <> v_expected then
    raise exception '009 self-check: expected % public policies, found %',
      v_expected, (select count(*) from pg_policies where schemaname = 'public');
  end if;

  -- ---- 6.2 hardened predicates carry their guards ------------------------
  for r in
    select p.policyname, p.fragment, p.slot
    from (values
      ('posts_select_public',               'public.sites',  'qual'),
      ('authors_select_public',             'public.sites',  'qual'),
      ('categories_select_public',          'public.sites',  'qual'),
      ('analytics_events_insert_public',    'public.posts',  'check'),
      ('analytics_events_insert_public',    'beacon_budget_ok', 'check'),
      ('analytics_events_insert_public',    'public.sites',  'check'),
      ('analytics_events_insert_public',    '2048',          'check'),
      ('redirects_insert_content_editor',   'is_site_editor','check'),
      ('redirects_insert_content_editor',   'is_linked_author', 'check'),
      ('redirects_insert_content_editor',   'public.posts',  'check'),
      ('site_settings_select_site_member',  'is_site_member','qual'),
      ('subscribers_insert_public',         'public.sites',  'check'),
      ('subscribers_insert_public',         '320',           'check'),
      ('post_tags_insert_can_edit',         'public.tags',   'check'),
      ('post_tags_update_can_edit',         'public.tags',   'check'),
      ('posts_insert_staff',                'public.authors','check'),
      ('posts_insert_staff',                'public.categories', 'check'),
      ('media_insert_site_editor',          'split_part',    'check'),
      ('media_update_site_editor',          'split_part',    'check')
    ) p(policyname, fragment, slot)
  loop
    select case when r.slot = 'qual' then coalesce(qual, '') else coalesce(with_check, '') end
      into expr
      from pg_policies
      where schemaname = 'public' and policyname = r.policyname;
    if expr is null or position(r.fragment in expr) = 0 then
      raise exception '009 self-check: policy % is missing guard fragment % in its % clause (found: %)',
        r.policyname, r.fragment, r.slot, left(coalesce(expr, '<policy absent>'), 200);
    end if;
  end loop;

  -- storage: the traversal guard must be on the object INSERT and on BOTH
  -- sides of the object UPDATE.
  for r in
    select p.policyname, p.slot
    from (values
      ('media_site_editor_insert', 'check'),
      ('media_site_editor_update', 'qual'),
      ('media_site_editor_update', 'check')
    ) p(policyname, slot)
  loop
    select case when r.slot = 'qual' then coalesce(qual, '') else coalesce(with_check, '') end
      into expr
      from pg_policies
      where schemaname = 'storage' and policyname = r.policyname;
    if expr is null or position('..' in expr) = 0 then
      raise exception '009 self-check: storage policy % (%) lacks the path-traversal guard',
        r.policyname, r.slot;
    end if;
  end loop;

  -- Exactly the four sanctioned storage policies may exist on objects: 004
  -- dropped media_public_read (a public bucket is gated by the bucket flag,
  -- not by RLS) and 009 only re-declares two of the remaining four.
  select count(*) into v from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname in ('media_staff_list','media_site_editor_insert',
                        'media_site_editor_update','media_site_editor_delete');
  if v <> 4 then
    raise exception '009 self-check: expected the 4 storage policies (004), matched %', v;
  end if;

  -- ---- 6.3 structural invariants ----------------------------------------
  if exists (
    select 1 from pg_policies
    where schemaname in ('public','storage')
      and (qual = 'true' or with_check = 'true')
  ) then
    raise exception '009 self-check: a policy with an unrestricted USING(true)/WITH CHECK(true) exists';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and cmd = 'SELECT' and qual is null
  ) then
    raise exception '009 self-check: a public SELECT policy has no USING clause';
  end if;

  select count(*) into v from pg_policies
   where schemaname = 'public' and ('anon' = any (roles));
  if v <> 9 then
    raise exception '009 self-check: anon may reach % policies, expected 9 (7 public reads + subscribers INSERT + analytics INSERT)', v;
  end if;

  -- PostgREST runs every token-bearing request as `authenticated`, so a
  -- policy that omits it is invisible to the whole app; a policy that names
  -- `service_role` would silently widen the surface, because that role holds
  -- BYPASSRLS anyway and must never be a policy target.
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and not ('authenticated' = any (roles))
  ) then
    raise exception '009 self-check: a public policy does not grant authenticated';
  end if;
  if exists (
    select 1 from pg_policies
    where schemaname in ('public','storage') and ('service_role' = any (roles))
  ) then
    raise exception '009 self-check: a policy grants service_role';
  end if;

  -- site_settings must no longer be readable by anon on the TABLE.
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'site_settings'
      and cmd = 'SELECT' and ('anon' = any (roles))
  ) then
    raise exception '009 self-check: site_settings is still anon-selectable';
  end if;

  -- The view is the security boundary, so its owner must be the table owner
  -- (otherwise the definer path silently returns zero rows) and it must not
  -- project the withheld column while still filtering on the active site.
  select count(*) into v
    from pg_class vc
    join pg_namespace n on n.oid = vc.relnamespace
    join pg_class tc on tc.relname = 'site_settings' and tc.relnamespace = n.oid
   where n.nspname = 'public'
     and vc.relname = 'site_settings_public'
     and vc.relkind = 'v'
     and vc.relowner = tc.relowner;
  if v <> 1 then
    raise exception '009 self-check: site_settings_public missing, or its owner is not the site_settings table owner (the definer view would not resolve rows)';
  end if;

  expr := pg_get_viewdef('public.site_settings_public'::regclass, true);
  if position('contact_email' in expr) > 0 then
    raise exception '009 self-check: site_settings_public still projects contact_email';
  end if;
  if position('is_active' in expr) = 0 then
    raise exception '009 self-check: site_settings_public no longer filters on sites.is_active';
  end if;
  if not has_table_privilege('anon', 'public.site_settings_public', 'select') then
    raise exception '009 self-check: anon cannot select site_settings_public (public pages would 401)';
  end if;

  -- The new policy helper must be callable by the roles the policy runs for
  -- (003 invariant 7): a missing grant makes guarded INSERTs ERROR, not deny.
  if not (has_function_privilege('anon', 'public.beacon_budget_ok(uuid, text)', 'execute')
          and has_function_privilege('authenticated', 'public.beacon_budget_ok(uuid, text)', 'execute')) then
    raise exception '009 self-check: beacon_budget_ok is not executable by anon/authenticated';
  end if;
  if not (select prosecdef from pg_proc where oid = 'public.beacon_budget_ok(uuid, text)'::regprocedure) then
    raise exception '009 self-check: beacon_budget_ok must be SECURITY DEFINER (anon cannot count its own rows)';
  end if;
  if has_function_privilege('anon', 'public.prune_analytics_events(interval)', 'execute') then
    raise exception '009 self-check: prune_analytics_events must not be callable by client roles';
  end if;

  -- Dedupe index: absent is acceptable ONLY because legacy collisions made it
  -- un-creatable (section 2c), and that case is recorded as a NOTICE.
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'analytics_events_beacon_dedupe_idx'
  ) and not exists (
    select 1 from public.analytics_events
    group by site_id, session_id, event_type, path, date_trunc('minute', created_at)
    having count(*) > 1
  ) then
    raise exception '009 self-check: dedupe index missing although no duplicate beacon minutes exist';
  end if;

  -- RLS posture (informational; FORCE stays off on purpose — see the note in
  -- the report: forcing would break the SQL-operator path that has no INSERT
  -- policy at all, i.e. operator/010_bootstrap_first_admin.sql).
  -- Scoped to the 14 application tables on purpose: the public schema can
  -- legitimately hold other relations (extensions, views, helper tables) and
  -- an unscoped assertion would abort 009 on someone else's table.
  select count(*) into v from pg_class
   where relnamespace = 'public'::regnamespace
     and relkind = 'r'
     and relname in ('sites','profiles','profile_sites','authors','categories','tags',
                     'posts','post_tags','media','post_revisions','redirects',
                     'site_settings','subscribers','analytics_events')
     and relrowsecurity = false;
  if v > 0 then
    raise exception '009 self-check: % application table(s) now have RLS disabled', v;
  end if;
  select count(*) into v from pg_class
   where relnamespace = 'public'::regnamespace
     and relkind = 'r'
     and relname in ('sites','profiles','profile_sites','authors','categories','tags',
                     'posts','post_tags','media','post_revisions','redirects',
                     'site_settings','subscribers','analytics_events')
     and relrowsecurity = true
     and relforcerowsecurity = true;
  if v > 0 then
    raise notice '009 note: % table(s) have FORCE ROW LEVEL SECURITY — operator SQL paths (010 bootstrap) must be re-tested.', v;
  end if;

  raise notice '009 self-check OK: % public policies (9 anon-reachable) + 4 storage policies, site_settings_public view in place, beacon budget/caps, editor-only redirects, is_active on every public read.',
    v_expected;
end
$selfcheck$;

commit;

-- ============================================================================
-- ROLLBACK / FORWARD-NOTE
--   This file is forward-only. To return to the 003/004 behaviour, re-apply
--   the affected statements from 003_rls_policies.sql and
--   004_storage_policies.sql verbatim (both are drop-then-create) and
--   `drop view if exists public.site_settings_public;` plus
--   `drop function if exists public.beacon_budget_ok(uuid, text);`
--   `drop function if exists public.prune_analytics_events(interval);`
--   No data is modified by this file at any point; only policies, one view,
--   two functions, two indexes and one unique index guard.
-- ============================================================================
