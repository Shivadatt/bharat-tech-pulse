-- ============================================================================
--  supabase/operator/020_security_verification.sql
--
--  Bharat Tech Pulse — READ-ONLY security verification for the live project
--  (ref ylzwuwfhlqomjqcdrpxk). Companion to
--  supabase/migrations/009_rls_hardening.sql, which is DRAFT / NOT APPLIED.
--
--  ┌──────────────────────────────────────────────────────────────────────────┐
--  │ SECTIONS 1..13 CONTAIN SELECTs ONLY — no writes, no DDL, no GRANT, no     │
--  │ policy change. 13.6 opens a transaction solely to `set local role` and    │
--  │ then rolls it back. Every write/ops statement is in section 14 and is     │
--  │ COMMENTED OUT.                                                            │
--  │ Run sections 1..12 today; run 13.* only after 009 is applied (it refers   │
--  │ to objects 009 creates).                                                  │
--  └──────────────────────────────────────────────────────────────────────────┘
--
--  WHY THIS FILE EXISTS
--    * supabase-security (this round) had no live SQL access at all: the
--      session's permission layer refuses dashboard automation, so every
--      finding below is LOCAL/static (read from 001..008 + lib/) and had to be
--      labelled as such. Nothing here has been executed against the project.
--    * 009 aborts itself unless the resulting pg_policies inventory matches an
--      explicit expectation list. That expectation was written from the migration
--      files, not from the live database. Sections 2, 5 and 6 are what settles it.
--    * The owner runs these queries; no agent does.
--
--  ROLE ASSUMPTION
--    The SQL editor session runs as the project owner role (postgres/supabase_admin),
--    which holds BYPASSRLS and is the owner of every public.* table. So:
--      * counts here are COMPLETE (RLS is not forced: relforcerowsecurity = false);
--      * they are NOT what an anon/authenticated client would see — that is
--        exactly why 009's self-check asserts relforcerowsecurity stays false
--        (forcing it would break this operator path, which writes profiles /
--        profile_sites with no policies at all — see
--        supabase/operator/010_bootstrap_first_admin.sql).
--
--  SECRETS
--    No key, token or password appears in this file or in its output.
--    Note for context: tool/live_checks/.env does not exist in this repo, so the
--    anon/publishable key is not available to any agent either; live REST checks
--    (PostgREST responses as anon/authenticated) are BLOCKED this round and are
--    NOT reproducible with this file — this file answers "what does the catalog
--    say", not "what does HTTP say".
--
--  HOW TO READ THE OUTPUT
--    Section 6 is the roll-up. If every row of section 6 says OK/PASS, 009 can be
--    applied as-is. Any BLOCKER row is explained by the section it names.
--    Sections 1..12 run against TODAY's database (001..008). Sections 13.* refer to
--    objects 009 creates and will ERROR until 009 is applied — run them only after
--    the owner has applied it, and do not paste the whole file before that point.
-- ============================================================================


-- ============================================================================
-- 1. Environment & capability
-- ============================================================================

-- 1.1 Postgres version. `nulls not distinct` (used by 009's dedupe index) needs
--     15+. On 14 the CREATE UNIQUE INDEX in 009 section 2c is a syntax error, so
--     009 must be edited (drop the clause and accept that NULL-path beacons can
--     still duplicate) BEFORE applying.
select current_setting('server_version')                              as server_version,
       current_setting('server_version_num')::int >= 150000           as supports_nulls_not_distinct,
       version()                                                      as full_version;

-- 1.2 Session identity: confirms the BYPASSRLS assumption above and that this is
--     the intended project (the DB name differs per project).
select current_user                            as running_as,
       session_user                            as session_role,
       current_database()                      as database,
       (select rolbypassrls from pg_roles where rolname = current_user) as caller_bypasses_rls,
       (select rolsuper   from pg_roles where rolname = current_user)   as caller_is_superuser,
       pg_is_in_recovery()                     as on_read_replica;

-- 1.3 Extensions that the security story depends on.
select e.extname, n.nspname as schema, e.extversion
from pg_extension e
join pg_namespace n on n.oid = e.extnamespace
where e.extname in ('pg_cron','cron','postgis','pgcrypto','supabase_auth_admin','dblink')
order by 1;

-- 1.4 pg_cron must be reachable for the retention job discussion (section 5.7,
--     section 14). pg_cron normally lives in its own schema, not public.
select n.nspname, p.proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname in ('schedule','unschedule','job_run_log')
order by 1, 2;


-- ============================================================================
-- 2. Live policy inventory (the ground truth 009 was written against)
-- ============================================================================

-- 2.1 Counts. EXPECTED TODAY (pre-009, from 003 + 004): 49 public policies and
--     4 storage policies on storage.objects. If the live numbers differ, 009's
--     self-check WILL abort and the diff row list names the policies — that is
--     the intended behaviour, not a bug. Stop and reconcile before applying.
select schemaname,
       tablename,
       count(*)                                        as policies,
       bool_and(permissive = 'PERMISSIVE')             as all_permissive,
       count(*) filter (where 'anon' = any (roles))    as anon_reachable,
       count(*) filter (where not ('authenticated' = any (roles))) as missing_authenticated,
       count(*) filter (where 'service_role' = any (roles))        as grants_service_role,
       count(*) filter (where qual is null and cmd in ('SELECT','UPDATE')) as select_or_update_without_using
from pg_policies
where schemaname in ('public','storage')
group by 1, 2
order by 1, 2;

select count(*) filter (where schemaname = 'public')  as public_policies,
       count(*) filter (where schemaname = 'storage') as storage_policies
from pg_policies
where schemaname in ('public','storage');

-- 2.2 Full dump: the exact expression each policy enforces, which is the only
--     way to confirm the four accepted exposures and the seven defects are
--     really in the live database (not just in the migration files).
select schemaname,
       tablename,
       policyname,
       cmd,
       array_to_string(roles, ',') as roles,
       coalesce(qual,      '-')    as using_expr,
       coalesce(with_check,'-')    as with_check_expr
from pg_policies
where schemaname in ('public','storage')
order by schemaname, tablename, cmd, policyname;

-- 2.3 The four exposures 009 hardens, probed by name. Each row is a live answer
--     to "does the deployed policy really look like the file says it does".
select p.policyname,
       p.tablename,
       p.cmd,
       array_to_string(p.roles, ',') as roles,
       coalesce(p.with_check, p.qual) as expr,
       case
         when p.policyname = 'analytics_events_insert_public'
              then 'exposure 1: bounded? (expect NO 2048/64/beacon_budget_ok pre-009)'
         when p.policyname = 'site_settings_select_public'
              then 'exposure 2: anon can read ALL columns incl. contact_email (expect 1 row pre-009, 0 after)'
         when p.policyname = 'redirects_insert_site_member'
              then 'exposure 3: author tier may plant a 301 for any path (expect 1 row pre-009, 0 after)'
         when p.policyname = 'posts_select_public'
              then 'exposure 4: no sites.is_active proof (expect NO public.sites reference pre-009)'
       end as note
from pg_policies p
where p.schemaname = 'public'
  and p.policyname in ('analytics_events_insert_public','site_settings_select_public',
                       'redirects_insert_site_member','posts_select_public')
order by 1;

-- 2.4 The defects 009 found that were NOT on the accepted list. `guard_absent`
--     counts live policies of that name whose expression does NOT mention the
--     table the guard needs. EXPECT: 1 / 2 / 1 today (the defects exist), and
--     0 / 0 / 0 after 009. Bare table names are matched rather than
--     `public.sites` because pg_get_expr qualification is not contractually
--     fixed across versions.
select 'subscribers_insert_public / % sites predicate'::text as check_name,
       count(*) filter (where p.with_check not ilike '%sites%')  as guard_absent,
       count(*)                                                  as policies_found,
       coalesce(string_agg(p.with_check, ' /// '), '<no policy>') as live_expr
  from pg_policies p
 where p.schemaname = 'public' and p.policyname = 'subscribers_insert_public'
union all
select 'post_tags INSERT/UPDATE / tag-site check',
       count(*) filter (where p.with_check not ilike '%tags%'),
       count(*),
       coalesce(string_agg(p.with_check, ' /// '), '<no policy>')
  from pg_policies p
 where p.schemaname = 'public'
   and p.policyname in ('post_tags_insert_can_edit','post_tags_update_can_edit')
union all
select 'posts INSERT / category-site check',
       count(*) filter (where p.with_check not ilike '%categories%'),
       count(*),
       coalesce(string_agg(p.with_check, ' /// '), '<no policy>')
  from pg_policies p
 where p.schemaname = 'public' and p.policyname = 'posts_insert_staff';

-- 2.5 Any policy anywhere that is effectively unrestricted. EXPECT: 0 rows both
--     before and after 009 (media_public_read was already dropped by 004).
select schemaname, tablename, policyname, cmd, array_to_string(roles, ',') as roles,
       qual, with_check
from pg_policies
where schemaname in ('public','storage')
  and (qual = 'true' or with_check = 'true' or qual is null and cmd = 'SELECT');


-- ============================================================================
-- 3. RLS posture (row security enabled / forced / owned)
-- ============================================================================

-- 3.1 EXPECTED: relrowsecurity = true and relforcerowsecurity = false on all 14
--     application tables. relrowsecurity=false on a table named in 003 means the
--     policies exist but are INERT for non-owners — the single worst outcome.
--     009's self-check asserts RLS stays enabled on exactly these 14 names.
select n.nspname as schema,
       c.relname as table_name,
       c.relrowsecurity     as rls_enabled,
       c.relforcerowsecurity as rls_forced,
       pg_get_userbyid(c.relowner) as owner,
       (select count(*) from pg_policies p
         where p.schemaname = n.nspname and p.tablename = c.relname) as policies,
       c.reloptions::text   as reloptions
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relrowsecurity, c.relname;

-- 3.2 Storage-side posture, which is where a public bucket's real exposure
--     lives (see section 7).
select n.nspname as schema, c.relname as table_name,
       c.relrowsecurity, c.relforcerowsecurity,
       pg_get_userbyid(c.relowner) as owner,
       (select count(*) from pg_policies p
         where p.schemaname = n.nspname and p.tablename = c.relname) as policies
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'storage' and c.relkind = 'r'
order by c.relname;

-- 3.3 Is the table owner the same role that owns the future view? 009 aborts
--     unless public.site_settings_public.relowner == public.site_settings.relowner,
--     because a definer view owned by a different role would return zero rows to
--     anon instead of the intended column-subset. This query predicts that.
select c.relname, pg_get_userbyid(c.relowner) as owner, c.relkind
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('site_settings','sites','posts','authors','categories','media')
order by 1;


-- ============================================================================
-- 4. Function surface (SECURITY DEFINER, search_path pin, EXECUTE ACLs)
-- ============================================================================

-- 4.1 EXPECTED: 16 functions pre-009, 18 post-009 (beacon_budget_ok,
--     prune_analytics_events). Every policy helper must be prosecdef = true with
--     search_path pinned, exactly like 002/003 declare them; a helper that is not
--     definer is the recursion/privilege foot-gun 003 invariant 7 exists to avoid.
select p.proname,
       pg_get_function_arguments(p.oid)                     as args,
       p.prosecdef                                          as security_definer,
       coalesce(nullif(p.proconfig::text, '{}'),
                'NO SEARCH_PATH PIN')                        as proc_config,
       pg_get_userbyid(p.proowner)                          as owner,
       l.lanname                                            as language,
       p.provolatile                                        as volatility   -- 's'=stable 'i'=immutable 'v'=volatile
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
join pg_language    l on l.oid = p.prolang
where n.nspname = 'public'
order by p.proname;

-- 4.2 EXECUTE reachability per client role. This is the invariant that turns a
--     "policy denies you" into "query 42501 errors": a policy expression runs as
--     the CALLING role, so anon/authenticated need EXECUTE on every helper the
--     expression calls. Post-009 this MUST also show anon_ok = true and
--     auth_ok = true for beacon_budget_ok, and false for prune_analytics_events.
select p.proname,
       pg_get_function_arguments(p.oid) as args,
       has_function_privilege('anon',          p.oid::regprocedure, 'execute') as anon_ok,
       has_function_privilege('authenticated', p.oid::regprocedure, 'execute') as authenticated_ok,
       has_function_privilege('service_role',  p.oid::regprocedure, 'execute') as service_role_ok,
       has_function_privilege('postgres',      p.oid::regprocedure, 'execute') as postgres_ok
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.proname;

-- 4.3 Helpers referenced from a policy expression but NOT executable by the role
--     the policy is granted to — i.e. live 42501 landmines. EXPECT: 0 rows.
with policy_roles as (
  select p.policyname, p.schemaname, unnest(p.roles) as rolename,
         coalesce(p.qual,'') || ' ' || coalesce(p.with_check,'') as expr
    from pg_policies p
   where p.schemaname in ('public','storage')
), funcs as (
  select f.oid, f.proname, n.nspname
    from pg_proc f join pg_namespace n on n.oid = f.pronamespace
   where n.nspname = 'public'
)
select pr.schemaname, pr.policyname, pr.rolename::text, f.proname as missing_execute
from policy_roles pr
join funcs f on position(f.proname::text in pr.expr) > 0
where not has_function_privilege(pr.rolename::text, f.oid::regprocedure, 'execute')
order by 1, 2, 4;

-- 4.4 Column/table privileges that decide whether a public read works at all
--     after 009: anon needs SELECT on the VIEW (site_settings_public), not the
--     table. Owner privileges are implicit and do not appear in an ACL, so a
--     missing row for postgres is normal.
select c.relname,
       coalesce(pg_get_userbyid(a.grantee), 'PUBLIC') as grantee,
       string_agg(a.privilege_type, ',' order by a.privilege_type) as privileges,
       bool_or(a.is_grantable) as grantable
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join lateral aclexplode(c.relacl) a on true
where n.nspname = 'public'
  and c.relname in ('site_settings','site_settings_public','analytics_events','subscribers',
                    'posts','redirects','media','profiles','profile_sites','sites')
group by 1, 2
order by 1, 2;

-- 4.5 Does a relation named site_settings_public exist yet? EXPECT: no rows
--     pre-009 (009 is a draft), one row post-009 with relkind 'v'.
select c.relname, c.relkind, pg_get_userbyid(c.relowner) as owner, c.reloptions::text
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'site_settings_public';


-- ============================================================================
-- 5. analytics_events pre-flight (the highest-cost table and the widest door)
-- ============================================================================

-- 5.1 Size and growth. The live figure at the last read was 40 rows with pg_cron
--     job 1 firing every minute; the concern is unbounded growth, not today's
--     number. This measures the actual daily rate to pick a retention window.
select count(*)                                            as total_rows,
       min(created_at)                                     as oldest,
       max(created_at)                                     as newest,
       pg_size_pretty(pg_total_relation_size('public.analytics_events')) as total_size
from public.analytics_events;

select date_trunc('day', created_at) as day, count(*) as events,
       count(distinct session_id) as sessions,
       count(*) filter (where event_type = 'article_view') as article_views,
       count(*) filter (where event_type = 'page_view')    as page_views,
       count(*) filter (where post_id is not null)         as with_post_id
from public.analytics_events
group by 1
order by 1 desc
limit 31;

-- 5.2 DEDUPE BLOCKER PROBE. If this returns any row, 009 section 2c deliberately
--     skips the unique index (and says so in a NOTICE) rather than aborting the
--     migration; 009's self-check then accepts the missing index. Decide: prune
--     the collisions (section 14) and re-run 009, or live without dedupe.
select count(*)                                            as colliding_groups,
       coalesce(sum(c) - count(*), 0)                      as rows_that_would_merge,
       max(c)                                              as worst_group
from (
  select site_id, session_id, event_type, path,
         date_trunc('minute', created_at) as minute, count(*) as c
    from public.analytics_events
   group by 1, 2, 3, 4, 5
  having count(*) > 1
) t;

select site_id, session_id, event_type, path,
       date_trunc('minute', created_at) as minute, count(*) as c
from public.analytics_events
group by 1, 2, 3, 4, 5
having count(*) > 1
order by c desc
limit 20;

-- 5.3 Payload shape: the caps 009 adds (session_id 64, path 2048, referrer 2048)
--     must be far above what the real client sends, otherwise the app starts
--     silently losing beacons (SupabaseAnalyticsRepository.track() swallows
--     PostgrestException on purpose). EXPECT: every max well under the cap.
select count(distinct event_type)                as distinct_event_types,
       string_agg(distinct event_type, ',' order by event_type) as event_types_seen,
       max(char_length(coalesce(session_id,''))) as max_session_id_len,
       max(char_length(coalesce(path,'')))       as max_path_len,
       max(char_length(coalesce(referrer,'')))   as max_referrer_len,
       count(*) filter (where session_id is null or session_id = '') as null_or_empty_session,
       count(*) filter (where path is null)      as null_path,
       count(*) filter (where post_id is not null) as post_id_present
from public.analytics_events;

-- 5.4 created_at honesty: 009 requires |created_at - now| <= 1 minute at INSERT.
--     Existing rows are unaffected, but a large negative/positive skew here
--     means the client (or a bot) is stamping its own timestamps and would start
--     being rejected — that is the intended outcome, not a regression.
select count(*) filter (where created_at >  now() + interval '1 minute') as future_stamped,
       count(*) filter (where created_at <  now() - interval '1 minute') as past_only_gap
from public.analytics_events;

-- 5.5 post_id proof: 009 requires post_id (when sent) to be a post OF THE SAME
--     SITE that is publicly visible. These rows are what a client has already
--     managed to write through the current, looser policy — the concrete evidence
--     for the exposure, and the set the tightened WITH CHECK rejects going
--     forward. All three counts are expected to be 0 today; anything else is a
--     live demonstration that the old policy was exploitable.
select count(*) filter (
         where post_id is not null
           and not exists (select 1 from public.posts p
                            where p.id = e.post_id
                              and p.site_id = e.site_id)
       )                                                              as foreign_or_missing_post,
       count(*) filter (
         where post_id is not null
           and exists (select 1 from public.posts p
                        where p.id = e.post_id
                          and p.status not in ('published')
                          and p.status not in ('scheduled'))
       )                                                              as non_visible_post,
       count(*) filter (
         where post_id is not null
           and exists (select 1 from public.posts p
                        where p.id = e.post_id
                          and (p.status = 'draft' or p.status = 'archived'))
       )                                                              as draft_or_archived_ref,
       count(*) filter (
         where not exists (select 1 from public.sites s
                            where s.id = e.site_id and s.is_active)
       )                                                              as inactive_site,
       count(*)                                                       as total
from public.analytics_events e;

-- 5.6 Would the 009 budget (60 events per session per minute) have rejected
--     anything historically? EXPECT 0. If not 0, the threshold is too low for
--     real traffic and 009's literal must be raised before applying.
select count(*) as sessions_over_60_per_minute
from (
  select site_id, session_id, date_trunc('minute', created_at) as m, count(*) as c
    from public.analytics_events
   group by 1, 2, 3
  having count(*) >= 60
) t;

-- 5.7 The pg_cron side of the cost story (job 1 was observed at `* * * * *`
--     calling publish_scheduled_posts(), 5,656 runs, all succeeded). A per-minute
--     job is also why an idle project still bills compute — noted, not changed.
--     The column list deliberately omits the job's database column: pg_cron
--     renamed database/dbname between versions and a named list would then error.
select jobid, jobname, schedule, command, active
from cron.job
order by jobid;

select status, count(*) as runs,
       min(start_time) as first_run, max(start_time) as last_run
from cron.job_run_details
group by status
order by 2 desc;

select jobid, status, return_message, start_time, end_time
from cron.job_run_details
order by start_time desc
limit 10;


-- ============================================================================
-- 6. APPLY-BLOCKER SUMMARY (009 header section "GATE" refers to this query)
-- ============================================================================
-- Paste 6.1 alone after the sections above; every row must be OK/PASS before
-- 009 is applied. FAIL/BLOCKER rows name the section that explains them.
with checks as (
  select 1 as ord, 'postgres >= 15 (nulls not distinct)' as check_name,
         case when current_setting('server_version_num')::int >= 150000 then 'OK' else 'BLOCKER (section 1.1)' end as verdict
  union all
  select 2, 'public policy count == 49 (003)',
         case when (select count(*) from pg_policies where schemaname = 'public') = 49
              then 'OK' else 'BLOCKER (section 2.1) — reconcile before applying 009' end
  union all
  select 3, 'storage policy count == 4 (004)',
         case when (select count(*) from pg_policies where schemaname = 'storage') = 4
              then 'OK' else 'BLOCKER (section 2.1)' end
  union all
  select 4, 'no application table has RLS disabled',
         case when not exists (
                select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
                 where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity = false
                   and c.relname in ('sites','profiles','profile_sites','authors','categories','tags',
                                     'posts','post_tags','media','post_revisions','redirects',
                                     'site_settings','subscribers','analytics_events'))
              then 'OK' else 'BLOCKER (section 3.1)' end
  union all
  select 5, 'no unrestricted (true) policy',
         case when not exists (select 1 from pg_policies
                                where schemaname in ('public','storage')
                                  and (qual = 'true' or with_check = 'true'))
              then 'OK' else 'BLOCKER (section 2.5)' end
  union all
  select 6, 'analytics dedupe index creatable',
         case when not exists (
                select 1 from public.analytics_events
                group by site_id, session_id, event_type, path, date_trunc('minute', created_at)
                having count(*) > 1)
              then 'OK' else 'PARTIAL — 009 skips the index with a NOTICE (section 5.2)' end
  union all
  select 7, 'analytics payload within 009 caps',
         case when coalesce((select max(greatest(char_length(coalesce(session_id,'')),
                                                 char_length(coalesce(path,'')),
                                                 char_length(coalesce(referrer,''))))
                              from public.analytics_events), 0) <= 2048
               and coalesce((select max(char_length(coalesce(session_id,'')))
                              from public.analytics_events), 0) <= 64
              then 'OK' else 'REVIEW (section 5.3) — raise the caps or accept rejections' end
  union all
  select 8, 'no session exceeded the 60/min budget',
         case when not exists (
                select 1 from (select count(*) c from public.analytics_events
                                group by site_id, session_id, date_trunc('minute', created_at)
                                having count(*) >= 60) t)
              then 'OK' else 'REVIEW (section 5.6)' end
  union all
  select 9, 'no storage key contains a .. segment',
         case when not exists (select 1 from storage.objects
                                where bucket_id = 'media'
                                  and (name like '%/..%' or name like '../%' or name like '%/..'))
              then 'OK' else 'REVIEW (section 7.4) — tighten 004 first / clean the keys' end
  union all
  select 10, 'media.storage_path first segment == owning site slug',
         case when not exists (
                select 1 from public.media m join public.sites s on s.id = m.site_id
                 where split_part(m.storage_path, '/', 1) <> s.slug)
              then 'OK' else 'REVIEW (section 8.2) — 009 section 5d would reject those rows on UPDATE' end
  union all
  select 11, 'redirect paths satisfy the 009 guards',
         case when not exists (
                select 1 from public.redirects r
                 where r.old_path not like '/%' or r.new_path not like '/%'
                    or r.old_path = r.new_path
                    or char_length(r.old_path) > 2048 or char_length(r.new_path) > 2048
                    or r.status_code not in (301,302,307,308))
              then 'OK' else 'REVIEW (section 9)' end
  union all
  select 12, 'analytics post_id always same-site + visible',
         case when not exists (
                select 1 from public.analytics_events e
                 where e.post_id is not null
                   and not exists (select 1 from public.posts p
                                    where p.id = e.post_id and p.site_id = e.site_id
                                      and (p.status = 'published'
                                           or (p.status = 'scheduled'
                                               and p.scheduled_for is not null
                                               and p.scheduled_for <= now()))))
              then 'OK' else 'PARTIAL (section 5.5) — historical rows stay, new inserts rejected' end
  union all
  select 13, '009 objects absent (nothing half-applied)',
         case when (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                     where n.nspname = 'public'
                       and p.proname in ('beacon_budget_ok','prune_analytics_events')) = 0
               and (select count(*) from pg_indexes
                     where schemaname = 'public'
                       and indexname in ('analytics_events_beacon_window_idx',
                                         'analytics_events_beacon_dedupe_idx')) = 0
               and (select count(*) from pg_policies where schemaname = 'public'
                     and policyname in ('redirects_insert_content_editor',
                                        'site_settings_select_site_member')) = 0
              then 'OK — clean pre-009 state'
              else 'REVIEW — a previous partial 009 exists — 009 is idempotent, but read section 2.1 first' end
)
select ord, check_name, verdict from checks order by ord;


-- ============================================================================
-- 7. Storage: bucket flags, object keys, prefix containment
-- ============================================================================

-- 7.1 The bucket. public = true is the mechanism that serves images to visitors:
--     GET /storage/v1/object/public/<bucket>/<path> is authorised by the BUCKET
--     FLAG and does not consult storage.objects RLS at all. So the 004 SELECT
--     policies (media_staff_list) restrict only LISTING / metadata / signed-URL
--     paths — the leak surface of a broad SELECT policy is the key list and the
--     metadata JSON, not the bytes. EXPECT: id media, public true, 10485760-byte
--     limit, the 6 image MIME types, no video types.
select b.id, b.name, b.public, b.file_size_limit, b.allowed_mime_types,
       b.created_at, b.updated_at
from storage.buckets b
order by b.id;

-- 7.2 Objects per top-level folder. EXPECT (post 007/008): 18 objects, every one
--     under india_tech/ (authors 4 + articles/category 8 heroes + the remaining
--     seeded assets); 0 objects in any other top-level folder.
select (storage.foldername(o.name))[1]                       as top_folder,
       (storage.foldername(o.name))[1] || '/' ||
       coalesce((storage.foldername(o.name))[2],'')          as two_levels,
       count(*)                                              as objects,
       coalesce(sum(case when o.metadata ->> 'size' ~ '^[0-9]+$'
                         then (o.metadata ->> 'size')::bigint else 0 end), 0) as bytes,
       min(o.created_at)                                     as oldest,
       max(o.created_at)                                     as newest
from storage.objects o
where o.bucket_id = 'media'
group by 1, 2
order by 3 desc;

select count(*) as total_objects,
       count(*) filter (where (storage.foldername(name))[1] = 'india_tech') as under_india_tech,
       count(*) filter (where (storage.foldername(name))[1] <> 'india_tech') as outside_prefix,
       max(char_length(name))                                  as max_key_len,
       string_agg(distinct (metadata ->> 'mimetype'), ',')      as mimetypes_seen
from storage.objects
where bucket_id = 'media';

-- 7.3 Depth/segment breakdown — the shape the 004 foldername() predicate relies on.
select storage.foldername(name)                    as segments,
       array_length(storage.foldername(name), 1)   as depth,
       count(*)
from storage.objects
where bucket_id = 'media'
group by 1, 2
order by 2, 1;

-- 7.4 TRAVERSAL PROBE. 004 pins only foldername(name)[1] = 'india_tech', which a
--     key like 'india_tech/../../sibling/x.png' satisfies. Whether such a key can
--     actually be served or re-read across the prefix is storage-service behaviour
--     that no migration file can answer — this query measures it in the live
--     catalog. EXPECT 0 rows (then 009 section 5e stays a belt-and-braces guard
--     rather than a repair).
select o.name, o.bucket_id, o.owner, o.created_at
from storage.objects o
where o.bucket_id = 'media'
  and (o.name like '%/..%' or o.name like '../%' or o.name like '%/..' or o.name like '%//%')
order by o.name;

-- 7.5 Registry <-> object reconciliation (the integrity 007/008 exist for).
--     Rows: a media record with no object behind it (broken image) and an object
--     with no registry row (orphan, still publicly fetchable for ever).
select m.id, m.file_name, m.storage_path, m.public_url, m.mime_type, m.file_size
from public.media m
where not exists (select 1 from storage.objects o
                   where o.bucket_id = 'media' and o.name = m.storage_path);

select o.name
from storage.objects o
where o.bucket_id = 'media'
  and not exists (select 1 from public.media m where m.storage_path = o.name);

-- 7.6 Public URLs stored in content rows must all point at the public bucket of
--     THIS project. A stray http:// or a foreign ref leaks the project ref and
--     breaks on migration. `nonconforming` counts NOT NULL values that do not
--     start with the canonical public-media prefix for the india_tech folder.
select 'posts.featured_image' as col, count(*) as rows_total,
       count(*) filter (where featured_image is null) as nulls,
       count(*) filter (where featured_image is not null
                              and featured_image !~ '^https://[A-Za-z0-9-]+\.supabase\.co/storage/v1/object/public/media/india_tech/') as nonconforming
from public.posts
union all
select 'posts.thumbnail_image', count(*), count(*) filter (where thumbnail_image is null),
       count(*) filter (where thumbnail_image is not null
                              and thumbnail_image !~ '^https://[A-Za-z0-9-]+\.supabase\.co/storage/v1/object/public/media/india_tech/')
from public.posts
union all
select 'posts.og_image', count(*), count(*) filter (where og_image is null),
       count(*) filter (where og_image is not null
                              and og_image !~ '^https://[A-Za-z0-9-]+\.supabase\.co/storage/v1/object/public/media/india_tech/')
from public.posts
union all
select 'authors.avatar_url', count(*), count(*) filter (where avatar_url is null),
       count(*) filter (where avatar_url is not null
                              and avatar_url !~ '^https://[A-Za-z0-9-]+\.supabase\.co/storage/v1/object/public/media/india_tech/')
from public.authors;


-- ============================================================================
-- 8. Media registry consistency (the DB side of the asset story)
-- ============================================================================

-- 8.1 Counts by mime type / site. (media has no type column; the Flutter media
--     repository derives the type from mime_type / file_name.)
select m.mime_type, m.site_id, s.slug as site_slug,
       count(*) as rows_count,
       coalesce(sum(m.file_size), 0) as bytes,
       count(*) filter (where (storage.foldername(m.storage_path))[1] = s.slug) as in_own_folder
from public.media m
join public.sites s on s.id = m.site_id
group by 1, 2, 3
order by 4 desc;

-- 8.2 Does every storage_path start with its OWN site's slug? This is the exact
--     predicate 009 section 5d adds to media_insert/update_site_editor, so this
--     query is the pre-flight for "will 009 reject a legitimate admin write".
--     EXPECT 0 rows.
select m.id, m.file_name, m.site_id, s.slug as site_slug, m.storage_path
from public.media m
join public.sites s on s.id = m.site_id
where split_part(m.storage_path, '/', 1) <> s.slug
   or m.storage_path like '/%'
   or m.storage_path like '%..%'
   or char_length(m.storage_path) > 1024;

-- 8.3 media_select_site_member is `to authenticated` only while 003's access
--     matrix (header line ~50) says "all metadata: X+E". Documentation drift, not
--     a hole: anon genuinely cannot read the registry, and public image delivery
--     does not need it (section 7.1). Recorded so the matrix can be corrected.
select policyname, cmd, array_to_string(roles, ',') as roles, qual
from pg_policies
where schemaname = 'public' and tablename = 'media'
order by cmd;


-- ============================================================================
-- 9. Redirect map integrity (009 section 3 pre/post)
-- ============================================================================

-- 9.1 Every existing redirect measured against the guards 009 introduces. A row
--     failing here was writable under 003 and is NOT repaired by 009 (policies
--     only gate future writes) — the owner decides whether to fix the data.
--     The two *_has_whitespace columns are INFORMATIONAL ONLY: 009 deliberately
--     does not gate whitespace, because updateArticle builds old_path straight
--     from the stored slug with no client-side validator in that path
--     (supabase_article_repository.dart:571), so gating it would abort article
--     saves instead of stopping an attack.
select r.id, r.site_id, s.slug as site_slug, r.old_path, r.new_path, r.status_code,
       (r.old_path not like '/%')                    as old_missing_slash,
       (r.old_path ~ '\s')                           as old_has_whitespace,
       (r.new_path not like '/%')                    as new_missing_slash,
       (r.new_path ~ '\s')                           as new_has_whitespace,
       (r.old_path = r.new_path)                     as self_redirect,
       (char_length(r.old_path) > 2048 or char_length(r.new_path) > 2048) as over_long,
       (r.status_code not in (301,302,307,308))     as odd_status_code,
       -- would an AUTHOR-TIER member still be able to re-create this row?
       (not exists (select 1 from public.posts p
                     where p.site_id = r.site_id
                       and '/article/' || p.slug = r.old_path)) as not_an_article_slug
from public.redirects r
join public.sites s on s.id = r.site_id
order by r.old_path;

-- 9.2 Aggregate of the same, so a long list does not hide the verdict.
select count(*)                                              as redirects_total,
       count(*) filter (where old_path not like '/%' or new_path not like '/%') as bad_slash,
       count(*) filter (where old_path = new_path)           as self_redirects,
       count(*) filter (where status_code not in (301,302,307,308)) as bad_status,
       count(*) filter (where old_path ~ '\s' or new_path ~ '\s')   as whitespace_paths,
       count(*) filter (where not exists (select 1 from public.posts p
                                          where p.site_id = r.site_id
                                            and '/article/' || p.slug = r.old_path)) as unresolvable_old_path
from public.redirects r;

-- 9.3 Duplicate old_path per site (the client upserts by path; a duplicate would
--     make the 301 map ambiguous).
select site_id, old_path, count(*)
from public.redirects
group by 1, 2
having count(*) > 1;


-- ============================================================================
-- 10. What anon can actually read today (column-level exposure evidence)
-- ============================================================================

-- 10.1 The site_settings columns visible to a visitor through
--      site_settings_select_public. contact_email is the one that 009 removes
--      from the anon path; google_analytics_id MUST stay reachable (the app feeds
--      it to GA4 from lib/main.dart), which is why 009's view keeps it.
select c.column_name, c.data_type, c.is_nullable,
       case when c.column_name in ('contact_email') then 'WITHHELD by 009 view'
            when c.column_name = 'google_analytics_id' then 'KEPT (public by construction, needed by main.dart)'
            else 'kept' end as post_009_disposition
from information_schema.columns c
where c.table_schema = 'public' and c.table_name = 'site_settings'
order by c.ordinal_position;

select id, site_id, site_name, tagline,
       contact_email is not null as contact_email_present,
       google_analytics_id,
       (select count(*) from pg_policies p
         where p.schemaname = 'public' and p.tablename = 'site_settings'
           and p.cmd = 'SELECT' and 'anon' = any (p.roles)) as anon_select_policies
from public.site_settings;

-- 10.2 Cross-site rows in the tables an anonymous writer can reach. Both are the
--      evidence for "subscribers INSERT has NO site predicate": if a second site
--      ever exists, these counts show how a row can land on the wrong one.
select s.slug as site_slug, s.is_active,
       (select count(*) from public.subscribers x where x.site_id = s.id) as subscribers,
       (select count(*) from public.analytics_events x where x.site_id = s.id) as events,
       (select count(*) from public.posts x where x.site_id = s.id) as posts,
       (select count(*) from public.media x where x.site_id = s.id) as media_rows,
       (select count(*) from public.redirects x where x.site_id = s.id) as redirects
from public.sites s
order by 1;

-- 10.3 Subscriber payload shape vs the caps 009 adds (email 320 / name 200) and
--      the INSERT-time freshness rule. EXPECT: 0 over-long, and the state flags
--      exactly as the policy requires.
select count(*)                                              as subscribers_total,
       max(char_length(coalesce(email,'')))                  as max_email_len,
       max(char_length(coalesce(name,'')))                   as max_name_len,
       count(*) filter (where email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') as nonconforming_email,
       count(*) filter (where is_verified)                   as verified,
       count(*) filter (where not is_active)                 as inactive,
       count(*) filter (where unsubscribed_at is not null)   as unsubscribed,
       count(*) filter (where subscribed_at > now() + interval '1 minute') as future_stamped
from public.subscribers;

-- 10.4 Publicly visible content that should NOT be: rows belonging to an
--      inactive site (posts_select_public currently has no is_active proof, so
--      these ARE readable by anon today), and non-visible statuses leaking.
select p.id, p.slug, p.status, s.slug as site_slug, s.is_active
from public.posts p
join public.sites s on s.id = p.site_id
where not s.is_active
   or (p.status not in ('published')
       and p.status not in ('scheduled')
       and p.status <> 'draft' and p.status <> 'archived');

select a.slug, a.is_active, s.slug as site_slug, s.is_active as site_active
from public.authors a join public.sites s on s.id = a.site_id
where not a.is_active or not s.is_active;


-- ============================================================================
-- 11. Proof that re-running 008 now changes 0 rows
-- ============================================================================
-- 008 is `update ... where <slug set> AND <url not like '%/media/india_tech/...%'>`.
-- Its own WHERE clauses are therefore the no-op test: if the counts below are 0,
-- the UPDATEs match nothing and re-applying 008 changes 0 rows (it still stamps
-- nothing, because no row is written). 11.2 reproduces 008's transaction-internal
-- self-check read-only; both counts must be 0, i.e. every URL resolves to a
-- registered media row AND a real object.
select count(*) as authors_pending_008
from public.authors a
where a.slug in ('aravind-sharma','priya-nambiar','rohit-deshmukh','sneha-kulkarni')
  and a.avatar_url not like '%/media/india_tech/authors/%';

select count(*) as posts_pending_008
from public.posts p
join public.categories c on c.id = p.category_id
where c.slug in ('ai','smartphones','apps','how-to','tech-news','comparisons','cyber-safety','buying-guides')
  and (   p.featured_image  is null or p.featured_image  not like '%/media/india_tech/articles/category/%'
       or p.thumbnail_image is null or p.thumbnail_image not like '%/media/india_tech/articles/category/%'
       or p.og_image        is null or p.og_image        not like '%/media/india_tech/articles/category/%');

select count(*) as posts_not_resolving
from public.posts p
where not exists (select 1 from public.media m where m.public_url = p.featured_image)
   or not exists (select 1 from public.media m where m.public_url = p.thumbnail_image)
   or not exists (select 1 from public.media m where m.public_url = p.og_image)
   or not exists (select 1 from storage.objects o
                   where o.bucket_id = 'media'
                     and o.name = regexp_replace(p.featured_image, '^.*?/object/public/media/', ''));

select count(*) as authors_not_resolving
from public.authors a
where not exists (select 1 from public.media m where m.public_url = a.avatar_url)
   or not exists (select 1 from storage.objects o
                   where o.bucket_id = 'media'
                     and o.name = regexp_replace(a.avatar_url, '^.*?/object/public/media/', ''));

-- 11.2 007's media upserts use fixed ids 00000000-0000-4000-8000-0000000005xx, so
--      a re-run is ON CONFLICT (id) DO UPDATE: idempotent for content but it
--      rewrites updated_at. Listing them here documents that fact.
select m.id, m.file_name, m.storage_path, m.public_url, m.updated_at
from public.media m
where m.id::text like '00000000-0000-4000-8000-%'
order by m.id;


-- ============================================================================
-- 12. Auth / staff surface — including the admin@gmail.com question
-- ============================================================================

-- 12.1 Row counts of the identity tables. The last live read (2026-10-13) showed
--      auth.users = 0 and profiles = 0; if that is still true, NO account of any
--      kind exists yet and every staff-plane live check is unrunnable.
select (select count(*) from auth.users)                       as auth_users,
       (select count(*) from public.profiles)                  as profiles,
       (select count(*) from public.profile_sites)             as profile_sites,
       (select count(*) from public.profiles where role = 'super_admin') as super_admins,
       (select count(*) from public.authors)                   as authors,
       (select count(*) from public.posts)                     as posts,
       (select count(*) from public.posts where status = 'published') as published,
       (select count(*) from public.posts where status = 'scheduled'
                                              and scheduled_for > now()) as still_scheduled,
       (select count(*) from public.categories)                as categories,
       (select count(*) from public.tags)                      as tags,
       (select count(*) from public.media)                     as media,
       (select count(*) from public.post_revisions)            as revisions,
       (select count(*) from public.redirects)                 as redirects,
       (select count(*) from public.subscribers)               as subscribers,
       (select count(*) from public.analytics_events)          as events,
       (select count(*) from public.sites)                     as sites;

-- 12.2 THE admin@gmail.com QUESTION (UNVERIFIED from this side; this query
--      settles it). owner@bharat-tech-pulse / admin@gmail.com is the stated admin
--      email. Read carefully before drawing conclusions:
--        * 0 rows + auth_users > 0  -> the account does not exist under that
--          address; someone signed up with something else.
--        * 0 rows + auth_users = 0  -> no account exists at all yet, so the
--          statement about admin@gmail.com can be neither confirmed nor denied.
--        * a row with profile_missing = true -> signup happened but the
--          handle_new_user trigger did not create the profile (a real defect).
--        * a row with role = 'author' -> the account exists but has NO admin
--          rights: promotion is SQL-operator only (operator/010).
select (select count(*) from auth.users u2
         where lower(u2.email) = 'admin@gmail.com') as accounts_with_that_email,
       u.id,
       u.email,
       (u.email_confirmed_at is not null or u.confirmed_at is not null) as email_confirmed,
       u.banned_until,
       u.deleted_at,
       u.last_sign_in_at,
       u.aud,
       p.id  is not null                as profile_exists,
       p.role                           as global_role,
       p.is_active                      as profile_active,
       s.slug                           as site_slug,
       ps.role                          as site_role,
       ps.is_active                     as site_membership_active,
       (select count(*) from public.authors a
         where a.user_id = u.id)        as linked_author_profiles
from auth.users u
left join public.profiles      p  on p.id = u.id
left join public.profile_sites ps on ps.profile_id = u.id
left join public.sites         s  on s.id = ps.site_id
where lower(u.email) = 'admin@gmail.com';

-- 12.3 Every account that exists, and its privileges. (Read-only.)
select u.id, u.email,
       (u.email_confirmed_at is not null or u.confirmed_at is not null) as confirmed,
       p.role as global_role, p.is_active as profile_active,
       coalesce(string_agg(s.slug || ':' || ps.role::text, ', ' order by s.slug), '-') as site_roles
from auth.users u
left join public.profiles      p  on p.id = u.id
left join public.profile_sites ps on ps.profile_id = u.id
left join public.sites         s  on s.id = ps.site_id
group by u.id, u.email, confirmed, p.role, p.is_active
order by u.email;

-- 12.4 Orphans the write policies would strand: profiles with no auth user,
--      memberships pointing at a nonexistent profile/site, and authors whose
--      user_id no longer resolves. All must be 0.
select (select count(*) from public.profiles p where not exists
          (select 1 from auth.users u where u.id = p.id))                  as profiles_without_auth_user,
       (select count(*) from public.profile_sites ps where not exists
          (select 1 from public.profiles p where p.id = ps.profile_id))    as memberships_without_profile,
       (select count(*) from public.profile_sites ps where not exists
          (select 1 from public.sites s where s.id = ps.site_id))          as memberships_without_site,
       (select count(*) from public.authors a where a.user_id is not null and not exists
          (select 1 from public.profiles p where p.id = a.user_id))        as authors_without_profile,
       (select count(*) from public.posts p where p.author_id is not null and not exists
          (select 1 from public.authors a where a.id = p.author_id))       as posts_without_author,
       (select count(*) from public.posts p where p.category_id is not null and not exists
          (select 1 from public.categories c where c.id = p.category_id))  as posts_without_category;

-- 12.5 THE CROSS-SITE INTEGRITY QUESTION that 009 sections 5b/5c close, measured
--      on live data: a post whose byline or category belongs to another site, or
--      a tag link that crosses sites. Every count must be 0 for the current
--      single-site deployment to be provably clean; a non-zero count means the
--      loose INSERT policies already let a bad row in.
select (select count(*) from public.posts p
         join public.authors a on a.id = p.author_id
         where a.site_id <> p.site_id)                       as posts_foreign_author,
       (select count(*) from public.posts p
         join public.categories c on c.id = p.category_id
         where c.site_id <> p.site_id)                       as posts_foreign_category,
       (select count(*) from public.post_tags pt
         join public.posts p on p.id = pt.post_id
         join public.tags  t on t.id = pt.tag_id
         where t.site_id <> p.site_id)                       as cross_site_tag_links,
       (select count(*) from public.posts p
         join public.authors a on a.id = p.author_id
         join public.categories c on c.id = p.category_id
         where a.is_active is not true or c.is_active is not true) as posts_on_inactive_taxonomy;

-- 12.6 Self-promotion surface, i.e. the plane 003 relies on having NO write
--      policies: profiles / profile_sites must show SELECT-only. If an INSERT or
--      UPDATE policy ever appears here, a member could grant themselves a role.
select p.policyname, p.tablename, p.cmd, array_to_string(p.roles, ',') as roles,
       coalesce(p.qual,'') || ' | ' || coalesce(p.with_check,'') as expr
from pg_policies p
where p.schemaname = 'public' and p.tablename in ('profiles','profile_sites')
order by p.tablename, p.cmd;


-- ============================================================================
-- 13. POST-009 verification (run these only AFTER the owner applies 009)
-- ============================================================================

-- 13.1 The inventory must be exactly 49 public + 4 storage, with the two renamed
--      policies present and the two old names gone. 009's own self-check asserts
--      the same thing from inside the transaction; this is the external proof.
select count(*) filter (where schemaname = 'public')  as public_policies,
       count(*) filter (where schemaname = 'storage') as storage_policies,
       count(*) filter (where policyname = 'redirects_insert_content_editor')  as new_redirect_policy,
       count(*) filter (where policyname = 'site_settings_select_site_member') as new_settings_policy,
       count(*) filter (where policyname = 'redirects_insert_site_member')     as old_redirect_policy_should_be_0,
       count(*) filter (where policyname = 'site_settings_select_public')      as old_settings_policy_should_be_0,
       count(*) filter (where schemaname = 'public' and 'anon' = any (roles))  as anon_reachable_should_be_9
from pg_policies
where schemaname in ('public','storage');

-- 13.2 The hardened expressions, verbatim from the live catalog.
select policyname, cmd, array_to_string(roles, ',') as roles,
       coalesce(qual,'-') as using_expr, coalesce(with_check,'-') as with_check_expr
from pg_policies
where schemaname in ('public','storage')
  and policyname in ('posts_select_public','authors_select_public','categories_select_public',
                     'analytics_events_insert_public','redirects_insert_content_editor',
                     'site_settings_select_site_member','subscribers_insert_public',
                     'post_tags_insert_can_edit','post_tags_update_can_edit','posts_insert_staff',
                     'media_insert_site_editor','media_update_site_editor',
                     'media_site_editor_insert','media_site_editor_update')
order by schemaname, policyname;

-- 13.3 The view: exists, owned by the site_settings owner, filters on is_active,
--      does not project contact_email, is grantable to anon.
select c.relname, c.relkind, pg_get_userbyid(c.relowner) as view_owner,
       c.reloptions::text as reloptions,
       (select pg_get_userbyid(relowner) from pg_class
         where relname = 'site_settings'
           and relnamespace = 'public'::regnamespace) as table_owner,
       pg_get_viewdef(c.oid, true) as definition
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'site_settings_public';

-- 13.4 Indexes 009 adds. The dedupe index may legitimately be absent when legacy
--      collisions exist (section 5.2) — 009 prints a NOTICE in that case.
select indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and tablename in ('analytics_events','site_settings_public')
order by indexname;

-- 13.5 The two new functions with their ACLs.
select p.proname, p.prosecdef, p.proconfig::text,
       has_function_privilege('anon', p.oid::regprocedure, 'execute')          as anon_ok,
       has_function_privilege('authenticated', p.oid::regprocedure, 'execute') as auth_ok,
       has_function_privilege('service_role', p.oid::regprocedure, 'execute')  as svc_ok,
       has_function_privilege('postgres', p.oid::regprocedure, 'execute')      as postgres_ok,
       p.proacl::text as acl
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('beacon_budget_ok','prune_analytics_events');

-- 13.6 Functional proof of the site_settings fix — the closest this file gets to
--      behaving like a client. It SELECTs only, inside a transaction that always
--      ends in `rollback`, so nothing can persist. `set local role` works because
--      the SQL editor role is a member of anon/authenticated on Supabase; if the
--      project ever denies that membership the block errors out harmlessly.
--      EXPECT post-009: site_settings_rows_for_nonmember = 0 (the table is staff
--      only) and view_rows = 1 (the column-subset still reaches visitors).
--      Pre-009 the block cannot run at all (no view) — that is why it is here
--      rather than in sections 1..12.
--      If `set local request.jwt.claims` errors on this project's Postgres, keep
--      only the `set local role` line — the role switch is what applies RLS; the
--      claims line just makes auth.uid() resolve (and it resolves to a uuid with
--      no profile, which is the point: a caller with no site membership).
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"role":"authenticated","sub":"00000000-0000-0000-0000-000000000000"}';
  select 'table_should_be_0_rows' as probe, count(*) as site_settings_rows_for_nonmember
    from public.site_settings;
  select 'view_should_be_1_row'   as probe, count(*) as view_rows
    from public.site_settings_public;
rollback;

-- 13.7 Beacon dry-run as anon is NOT included as a live statement, because it
--      would write: see section 14.6, which is the same dry-run COMMENTED OUT
--      inside a `begin; ... rollback;` pair for the owner to run deliberately.


-- ============================================================================
-- 14. OPERATOR STATEMENTS — NOT READ-ONLY, COMMENTED OUT ON PURPOSE
-- ============================================================================
-- These are the write/ops statements 009 deliberately does NOT contain, so the
-- owner can decide each one separately. Un-comment ONE at a time, in the SQL
-- editor, only after reading what it does. None of them has been run.
--
-- 14.1 Retention (009 ships public.prune_analytics_events but schedules nothing).
--      Deleting analytics history is irreversible:
--   -- select public.prune_analytics_events(interval '180 days');
--   -- select cron.schedule('prune-analytics-events', '17 4 * * *',
--   --        $$select public.prune_analytics_events(interval '180 days')$$);
--   -- select cron.unschedule('prune-analytics-events');
--
-- 14.2 The per-minute publish job is a live cost (009 does not touch it). To
--      relax it after measuring (each run wakes compute):
--   -- select cron.unschedule(jobid) from cron.job where jobname = 'publish-scheduled-posts';
--      (confirm the jobname from section 5.7 first; re-schedule with
--       select cron.schedule('publish-scheduled-posts', '* * * * *',
--                            $$select public.publish_scheduled_posts()$$);
--       if it has to come back at all.)
--
-- 14.3 Dedupe cleanup, only if section 5.2 reported collisions and the owner
--      wants the unique index in a future 009 run. Review the SELECT first, then
--      run the DELETE in the same transaction only if the row list is acceptable:
--   -- select site_id, session_id, event_type, path,
--   --        date_trunc('minute', created_at) as minute, count(*), min(id) as keep_id
--   --   from public.analytics_events
--   --  group by 1,2,3,4,5 having count(*) > 1;
--   -- delete from public.analytics_events
--   --  where id in (select a.id from public.analytics_events a
--   --                 join (select site_id, session_id, event_type, path,
--   --                              date_trunc('minute', created_at) as minute, min(id) as keep_id
--   --                         from public.analytics_events
--   --                        group by 1,2,3,4,5 having count(*) > 1) d
--   --                   on  a.site_id = d.site_id
--   --                 and a.session_id is not distinct from d.session_id
--   --                 and a.event_type = d.event_type
--   --                 and a.path is not distinct from d.path
--   --                 and date_trunc('minute', a.created_at) = d.minute
--   --                and a.id <> d.keep_id);
--
-- 14.4 First admin (the answer to section 12.2 if the account is missing or
--      stuck on 'author'): create the user in Dashboard -> Authentication, then
--      follow supabase/operator/010_bootstrap_first_admin.sql with the real
--      email. Do not run it blindly: it has a REPLACE_ME placeholder.
--
-- 14.5 Applying 009 itself — supabase/migrations/009_rls_hardening.sql, once the
--      GATE in that file's header is cleared (the Flutter agent's
--      site_settings_public read must be on the deployed client first, or the
--      DB-held GA4 id silently stops loading for visitors). Verify with `13.*`.
--
-- 14.6 Beacon dry-run as anon: one LEGAL insert inside a transaction that is
--      rolled back, proving 009's WITH CHECK accepts exactly what
--      SupabaseAnalyticsRepository sends (site_id/event_type/session_id/path/
--      post_id, never created_at). Keep the `rollback` paired with the `begin`;
--      without it this is a real write to a metered table.
--   -- begin;
--   -- set local role anon;
--   -- set local request.jwt.claims = '{"role":"anon"}';
--   -- insert into public.analytics_events (site_id, event_type, session_id, path)
--   -- select s.id, 'page_view', '009-selfcheck-' || substr(md5(random()::text), 1, 10), '/selfcheck'
--   --   from public.sites s where s.is_active limit 1;
--   -- rollback;
--      Negative cases, each expected to be REJECTED (42501 / new-row violation)
--      rather than silently accepted — run them one at a time in their own
--      begin/rollback so a rejection does not abort the others:
--        * event_type = 'admin_ping'                     (whitelist)
--        * site_id = an inactive site's uuid             (active-site guard)
--        * post_id = a draft's or a foreign site's uuid  (visibility + same site)
--        * session_id = 200 chars                        (cap 64)
--        * 61 rows for one session_id in one minute      (beacon_budget_ok)
--
-- End of supabase/operator/020_security_verification.sql — sections 1..13 are
-- read-only (13.6 is a rolled-back transaction containing SELECTs only); every
-- write/ops statement lives in section 14 and is commented out.
