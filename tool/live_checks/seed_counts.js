#!/usr/bin/env node
'use strict';
/**
 * tool/live_checks/seed_counts.js
 *
 * Asserts the 006_seed_data.sql contract against the LIVE database and checks
 * referential integrity — entirely through PostgREST, read-only.
 *
 * Expected minimums (from the 006 seed plan):
 *   1 site | 8 categories | >=4 authors | >=20 tags | >=24 posts
 *   >=12 published | >=4 draft | >=3 future-scheduled | >=2 archived
 *   >=6 media | >=4 post_revisions | >=3 redirects | >=6 subscribers
 *   ~40 analytics_events | post_tags junction with no orphans
 *
 * Tables that staff-only policies hide from the anon key (drafts, archived,
 * future-scheduled posts, post_revisions, subscribers, analytics_events) are
 * measured with SUPABASE_ADMIN_TOKEN when it is provided; otherwise those
 * assertions are reported as SKIP (never as a false PASS).
 *
 * Usage: node tool/live_checks/seed_counts.js [--json]
 */

const config = require('./lib/config');
const api = require('./lib/api');

const NOW_ISO = new Date().toISOString();
const SITE_SLUG = 'india_tech';

/** Minimum row counts the seed must satisfy. `staff: true` = hidden from anon. */
const EXPECT = [
  { table: 'sites', filter: 'is_active=eq.true', min: 1, label: 'active site', staff: false },
  { table: 'categories', filter: 'is_active=eq.true', min: 8, label: 'active categories', staff: false },
  { table: 'authors', filter: 'is_active=eq.true', min: 4, label: 'active author bylines', staff: false },
  { table: 'tags', filter: 'select=*', min: 20, label: 'tags', staff: false },
  { table: 'posts', filter: 'status=eq.published', min: 12, label: 'published posts', staff: false },
  { table: 'posts', filter: 'status=eq.draft', min: 4, label: 'draft posts', staff: true },
  { table: 'posts', filter: `status=eq.scheduled&scheduled_for=gt.${NOW_ISO}`, min: 3, label: 'future-scheduled posts', staff: true },
  { table: 'posts', filter: 'status=eq.archived', min: 2, label: 'archived posts', staff: true },
  { table: 'posts', filter: 'select=*', min: 24, label: 'total posts', staff: true },
  { table: 'media', filter: 'select=*', min: 6, label: 'media rows', staff: false },
  { table: 'post_revisions', filter: 'select=*', min: 4, label: 'post revisions', staff: true },
  { table: 'redirects', filter: 'select=*', min: 3, label: 'redirects', staff: false },
  { table: 'subscribers', filter: 'select=*', min: 6, label: 'subscribers', staff: true },
  { table: 'analytics_events', filter: 'select=*', min: 30, label: 'analytics events (~40 expected)', staff: true },
  { table: 'post_tags', filter: 'select=*', min: 24, label: 'post_tags junction rows', staff: false },
  { table: 'site_settings', filter: 'select=*', min: 1, label: 'site_settings row', staff: false },
];

const total = (r) => (r.total !== null ? r.total : r.rows ? r.rows.length : 0);
const ev = (r) =>
  `HTTP ${r.status} count=${r.ok ? total(r) : '-'}` +
  `${r.error ? ` msg="${String(r.error.message).slice(0, 70)}"` : ''}`;

async function main() {
  const cfg = config.load();
  const rep = new api.Report('seed_counts.js — seed contract + integrity', cfg.secrets);
  const anon = new api.Api(cfg);
  const staff = cfg.adminToken ? new api.Api(cfg, cfg.adminToken) : null;

  process.stdout.write('seed_counts.js\n' + config.identitySummary(cfg) + '\n');

  const probe = await api.probeSchema(cfg);
  if (probe.applied !== true) {
    process.stdout.write(api.notAppliedBanner('the seeded data', probe));
    process.stdout.write(`  probe: ${probe.reason} — ${probe.detail}\n`);
    for (const e of EXPECT) rep.skip(`count ${e.label}`, api.stateSkipReason(probe));
    rep.skip('referential integrity', api.stateSkipReason(probe));
    rep.print();
    process.stdout.write('\nRESULT: seed not verifiable yet (0 tables). Not a failure to hide.\n');
    return 0;
  }

  /* ---------------- row counts ---------------- */
  const siteRes = await anon.list('sites', `select=id&slug=eq.${SITE_SLUG}`);
  if (!siteRes.ok || !total(siteRes)) {
    rep.fail(`site row '${SITE_SLUG}' exists`, ev(siteRes));
    rep.print();
    return 1;
  }
  const SITE_ID = siteRes.rows[0].id;
  rep.pass(`site '${SITE_SLUG}' present`, `id=${SITE_ID} ${ev(siteRes)}`);

  const fetched = {};
  for (const e of EXPECT) {
    if (e.staff && !staff) {
      const a = await anon.count(e.table, e.filter);
      rep.skip(
        `count ${e.label}`,
        `hidden from anon by the 003 policies (anon probe ${ev(a)}) — supply SUPABASE_ADMIN_TOKEN`
      );
      continue;
    }
    const client = e.staff ? staff : anon;
    const r = await client.count(e.table, e.filter);
    if (!r.ok) {
      rep.fail(`count ${e.label}`, ev(r));
      continue;
    }
    const n = total(r);
    if (n >= e.min) {
      rep.pass(`count ${e.label}`, `${n} >= ${e.min} ${ev(r)}`);
    } else {
      rep.fail(`count ${e.label}`, `${n} < expected minimum ${e.min} ${ev(r)}`);
    }
    fetched[`${e.table}:${e.filter}`] = n;
  }

  /* ---------------- integrity data sets ---------------- */
  const src = staff || anon;
  const postsR = await src.list('posts', 'select=id,site_id,slug,category_id,author_id,status');
  const catsR = await src.list('categories', 'select=id,site_id,slug,is_active');
  const authR = await src.list('authors', 'select=id,site_id,slug,is_active');
  const tagsR = await src.list('tags', 'select=id,site_id,slug');
  const ptR = await src.list('post_tags', 'select=post_id,tag_id');
  const sitesR = await src.list('sites', 'select=id,slug');
  const mediaR = await src.list('media', 'select=id,site_id,storage_path');
  const redR = await src.list('redirects', 'select=id,site_id,old_path');
  const subR = staff ? await staff.list('subscribers', 'select=id,site_id,email') : null;
  const evR = staff ? await staff.list('analytics_events', 'select=id,site_id,post_id,event_type') : null;
  const revR = staff ? await staff.list('post_revisions', 'select=id,post_id,revision_number') : null;

  const idSet = (r) => new Set((r && r.rows ? r.rows : []).map((x) => x.id));
  const siteSet = idSet(sitesR);
  const catIds = idSet(catsR);
  const authorIds = idSet(authR);
  const tagIds = idSet(tagsR);
  const postIds = idSet(postsR);

  rep.info(
    'fetched for integrity',
    `posts=${postsR.rows ? postsR.rows.length : '-'}(${postsR.total}) ` +
      `categories=${n(catsR)} authors=${n(authR)} tags=${n(tagsR)} post_tags=${n(ptR)} ` +
      `media=${n(mediaR)} redirects=${n(redR)} revisions=${revR ? n(revR) : 'no-token'} ` +
      `subscribers=${subR ? n(subR) : 'no-token'} events=${evR ? n(evR) : 'no-token'} ` +
      `scope=${staff ? 'staff (complete)' : 'anon (RLS-filtered subset — see note)'}`
  );
  if (!staff) {
    rep.info(
      'integrity scope caveat',
      'running as anon: inactive categories/authors and non-public posts are filtered by RLS, ' +
        'so an FK could be reported as an orphan when it points at a hidden-but-valid row. ' +
        'Provide SUPABASE_ADMIN_TOKEN for a conclusive integrity pass.'
    );
  }
  if ((postsR.total !== null && postsR.total > 1000)) {
    rep.info('paging', 'more than 1000 rows exist; integrity checks used the first page only');
  }

  /* ---------------- orphan checks ---------------- */
  const orphan = (rows, fk, allowed, label) => {
    const bad = (rows || []).filter((r) => r[fk] !== null && r[fk] !== undefined && !allowed.has(r[fk]));
    if (bad.length) {
      if (staff) {
        rep.fail(label, `${bad.length} orphan(s): ${JSON.stringify(bad.slice(0, 3))}`);
      } else {
        // Without a staff token the allowed-set only contains anon-VISIBLE
        // rows; a FK into a legitimately hidden row (inactive site/category,
        // draft post, zzz-check temp site) is indistinguishable from a real
        // orphan. Report SKIP, never a misleading FAIL.
        rep.skip(
          `${label} (conclusive verdict needs SUPABASE_ADMIN_TOKEN)`,
          `apparent orphan(s) visible-from-anon only=${bad.length}: ${JSON.stringify(bad.slice(0, 2))} — may be RLS-hidden-but-valid targets`
        );
      }
    } else {
      rep.pass(label, `0 orphans across ${(rows || []).length} row(s) checked`);
    }
    return bad;
  };

  orphan(postsR.rows, 'category_id', catIds, 'no orphan posts.category_id');
  orphan(postsR.rows, 'author_id', authorIds, 'no orphan posts.author_id');
  orphan(ptR.rows, 'post_id', postIds, 'no orphan post_tags.post_id');
  orphan(ptR.rows, 'tag_id', tagIds, 'no orphan post_tags.tag_id');
  for (const [name, r] of [
    ['posts.site_id', postsR],
    ['categories.site_id', catsR],
    ['authors.site_id', authR],
    ['tags.site_id', tagsR],
    ['media.site_id', mediaR],
    ['redirects.site_id', redR],
  ]) {
    orphan(r.rows, 'site_id', siteSet, `no orphan ${name}`);
  }
  if (evR) {
    orphan(evR.rows, 'site_id', siteSet, 'no orphan analytics_events.site_id');
    orphan(evR.rows, 'post_id', postIds, 'no orphan analytics_events.post_id');
    const badTypes = evR.rows.filter(
      (e) => !['page_view', 'article_view'].includes(e.event_type) && !/^zzz-check-/.test(String(e.session_id || ''))
    );
    rep.check(
      badTypes.length === 0,
      'analytics_events event_type values are within the public whitelist',
      `unexpected=${badTypes.length ? JSON.stringify(badTypes.slice(0, 3).map((b) => b.event_type)) : 0}` +
        ` (throwaway rows written by rls_matrix are excluded by session_id prefix)`
    );
    const types = {};
    for (const e of evR.rows) types[e.event_type] = (types[e.event_type] || 0) + 1;
    rep.info('event_type distribution', JSON.stringify(types));
  } else {
    rep.skip('analytics_events value check', 'hidden from anon — needs SUPABASE_ADMIN_TOKEN');
  }
  if (revR) {
    orphan(revR.rows, 'post_id', postIds, 'no orphan post_revisions.post_id');
    const dup = findDuplicates(revR.rows, (r) => `${r.post_id}#${r.revision_number}`);
    rep.check(dup.length === 0, 'post_revisions (post_id, revision_number) unique', `${revR.rows.length} rows, dup=${dup.length}`);
  } else {
    rep.skip('post_revisions integrity', 'hidden from anon — needs SUPABASE_ADMIN_TOKEN');
  }
  if (subR) {
    orphan(subR.rows, 'site_id', siteSet, 'no orphan subscribers.site_id');
    const dup = findDuplicates(subR.rows, (r) => `${r.site_id}#${String(r.email).toLowerCase()}`);
    rep.check(dup.length === 0, 'subscribers (site_id, email) unique', `${subR.rows.length} rows, dup=${dup.length}`);
    const seedEmails = (subR.rows || []).filter((s) => !/^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$/.test(String(s.email)));
    rep.check(seedEmails.length === 0, 'seeded subscriber emails are well-formed', `bad=${JSON.stringify(seedEmails.slice(0, 3))}`);
  } else {
    rep.skip('subscriber uniqueness/format', 'hidden from anon — needs SUPABASE_ADMIN_TOKEN');
  }

  /* ---------------- uniqueness constraints ---------------- */
  for (const [name, r, key] of [
    ['posts (site_id, slug)', postsR, (x) => `${x.site_id}#${x.slug}`],
    ['categories (site_id, slug)', catsR, (x) => `${x.site_id}#${x.slug}`],
    ['authors (site_id, slug)', authR, (x) => `${x.site_id}#${x.slug}`],
    ['tags (site_id, slug)', tagsR, (x) => `${x.site_id}#${x.slug}`],
    ['redirects (site_id, old_path)', redR, (x) => `${x.site_id}#${x.old_path}`],
  ]) {
    const dup = findDuplicates(r.rows, key);
    rep.check(dup.length === 0, `unique constraint holds for ${name}`, `${n(r)} rows, duplicates=${JSON.stringify(dup.slice(0, 3))}`);
  }

  /* ---------------- shape of the public feed ---------------- */
  const pubPosts = await anon.list('posts', 'select=id,slug,status,scheduled_for&status=in.(published,scheduled)');
  const leak = (pubPosts.rows || []).filter(
    (p) => p.status !== 'published' && !(p.status === 'scheduled' && p.scheduled_for && new Date(p.scheduled_for) <= new Date(NOW_ISO))
  );
  rep.check(
    pubPosts.ok && leak.length === 0,
    'public feed contains only published + due-scheduled',
    `${ev(pubPosts)} violations=${leak.length}`
  );
  const publishedIds = new Set((postsR.rows || []).filter((p) => p.status === 'published').map((p) => p.id));
  const withTags = new Set((ptR.rows || []).map((r) => r.post_id));
  const postsWithoutTags = [...publishedIds].filter((id) => !withTags.has(id));
  if (publishedIds.size === 0) {
    rep.skip('every published post carries at least one tag', 'no published posts visible to this credential');
  } else {
    rep.check(
      postsWithoutTags.length === 0,
      'every visible published post carries at least one tag',
      `published=${publishedIds.size} withoutTags=${postsWithoutTags.length}` +
        `${staff ? '' : ' (anon-visible subset only)'}`
    );
  }

  /* ---------------- status distribution ---------------- */
  const dist = {};
  for (const p of postsR.rows || []) dist[p.status] = (dist[p.status] || 0) + 1;
  rep.info('post status distribution (seed plan: 15 published | 4 draft | 3 scheduled | 2 archived)', JSON.stringify(dist));
  const storagePaths = new Set((mediaR.rows || []).map((m) => m.storage_path));
  const wrongPrefix = [...storagePaths].filter((p) => p && !String(p).startsWith(`${SITE_SLUG}/`));
  rep.check(
    wrongPrefix.length === 0,
    'media.storage_path values are all under the india_tech/ folder',
    `paths=${storagePaths.size} wrongPrefix=${JSON.stringify(wrongPrefix.slice(0, 3))}`
  );

  rep.print();
  const fails = rep.failures;
  process.stdout.write(
    `\nRESULT seed_counts: ${rep.rows.filter((r) => r.status === 'PASS').length} passed, ` +
      `${fails.length} FAILED, ${rep.rows.filter((r) => r.status === 'SKIP').length} skipped.\n`
  );
  if (process.argv.includes('--json')) {
    process.stdout.write(JSON.stringify({ rows: rep.rows }, null, 2) + '\n');
  }
  return fails.length ? 1 : 0;
}

function n(r) {
  return r && r.rows ? r.rows.length : '-';
}

function findDuplicates(rows, keyFn) {
  const seen = new Map();
  const dups = [];
  for (const row of rows || []) {
    const k = keyFn(row);
    seen.set(k, (seen.get(k) || 0) + 1);
    if (seen.get(k) === 2) dups.push(k);
  }
  return dups;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((e) => {
    process.stderr.write('seed_counts.js crashed: ' + config.redact((e && (e.stack || e.message)) || String(e), []) + '\n');
    process.exitCode = 2;
  });
