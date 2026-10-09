-- ============================================================================
-- 004_storage_policies.sql — Storage bucket + object policies for
-- Bharat Tech Pulse media. Replaces the old 003_storage.sql.
--
-- SECURITY: the service_role key is never used from the client. Secrets exist
-- only in Supabase server-side environment variables (edge functions / Vault).
-- Client uploads go through these policies with the user's JWT only.
--
-- DEPENDS ON 002_auth_and_roles.sql: public.is_site_editor(site uuid),
-- public.is_site_member(site uuid) and public.is_super_admin() (stable
-- security definer). Storage policies are
-- evaluated as the calling role (anon/authenticated) against storage.objects;
-- 002 grants EXECUTE on the helpers to anon, authenticated, service_role,
-- which is what these policies rely on (invariant 7 in 003).
--
-- MODEL: one shared public bucket `media`; every object lives under a
-- top-level folder named after its site's slug ("<site_slug>/..."), so
-- sibling sites can share the bucket without crossing. Writes require the
-- caller to be editor+ OF THE SITE THAT OWNS THE FOLDER — looked up from the
-- folder name via sites.slug, never a hardcoded UUID. On this deployment the
-- only folder is 'india_tech' (lib/app/config/site_config.dart + the Flutter
-- upload path '${SiteConfig.siteId}/<uuid>-<file>'), which is also what
-- SupabaseMediaRepository.uploadMedia produces.
--
-- Size/MIME enforcement is a BUCKET property (file_size_limit 10 MB,
-- allowed_mime_types below) — not a policy predicate; storage validates both
-- before policies run. The DO block below re-applies them on every run so a
-- drifted bucket cannot silently loosen the limits.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Bucket: public read, 10 MB cap, image MIME allowlist. Idempotent.
-- ---------------------------------------------------------------------------
do $$
begin
  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values (
    'media',
    'media',
    true,
    10485760, -- 10 MB
    '{image/jpeg,image/png,image/webp,image/svg+xml,image/gif}'
  );
exception when unique_violation then
  update storage.buckets
     set public = true,
         file_size_limit = 10485760,
         allowed_mime_types = '{image/jpeg,image/png,image/webp,image/svg+xml,image/gif}'
   where id = 'media';
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Policies — drop-then-create so re-running this migration is safe.
-- ---------------------------------------------------------------------------
drop policy if exists "media_staff_list"             on storage.objects;
drop policy if exists "media_public_read"            on storage.objects;
drop policy if exists "media_site_editor_insert"     on storage.objects;
drop policy if exists "media_site_editor_update"     on storage.objects;
drop policy if exists "media_site_editor_delete"     on storage.objects;

-- Listing/storage-metadata reads are staff-only, and staff of THIS site only.
--
-- This used to be `media_public_read ... for select to anon, authenticated
-- using (bucket_id = 'media')`, which the Supabase Advisor flagged: a broad
-- SELECT on a public bucket lets any caller enumerate every object key. It is
-- not needed for delivery — the bucket is public, so `/object/public/<path>`
-- is served from the bucket flag and bypasses RLS entirely. Anonymous visitors
-- therefore keep working images while no longer being able to list the bucket,
-- and a signed-in reader with no site role sees zero rows. Cross-site
-- enumeration is blocked by the foldername predicate, mirroring the write gates.
create policy "media_staff_list"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'india_tech'
    and public.is_site_member(
      (select s.id from public.sites s
        where s.slug = 'india_tech' and s.is_active)
    )
  );

-- Upload: editor+ of the site owning the top-level folder, india_tech only
-- on this deployment. foldername(name)[1] pins the site folder so a member
-- of one site can never write into a sibling site's prefix.
create policy "media_site_editor_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'india_tech'
    and public.is_site_editor(
      (select s.id from public.sites s
        where s.slug = 'india_tech' and s.is_active)
    )
  );

-- Replace/upsert inside the same folder: same site-editor gate. USING checks
-- the existing object, WITH CHECK the new one — both must sit under
-- india_tech/, so an object can never be "moved" across site prefixes.
create policy "media_site_editor_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'india_tech'
    and public.is_site_editor(
      (select s.id from public.sites s
        where s.slug = 'india_tech' and s.is_active)
    )
  )
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'india_tech'
    and public.is_site_editor(
      (select s.id from public.sites s
        where s.slug = 'india_tech' and s.is_active)
    )
  );

-- Delete: matches SupabaseMediaRepository.deleteMedia, which removes the DB
-- row first and then the storage object with the same JWT.
create policy "media_site_editor_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'india_tech'
    and public.is_site_editor(
      (select s.id from public.sites s
        where s.slug = 'india_tech' and s.is_active)
    )
  );

-- End of 004_storage_policies.sql
