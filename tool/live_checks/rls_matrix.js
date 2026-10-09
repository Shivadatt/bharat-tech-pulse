#!/usr/bin/env node
'use strict';
/**
 * tool/live_checks/rls_matrix.js
 *
 * Negative/positive security suite for the Bharat Tech Pulse Supabase backend.
 * Every assertion records the ACTUAL HTTP status and row counts as evidence.
 *
 * Planes exercised (see supabase/migrations/003_rls_policies.sql + 004_storage_policies.sql):
 *   A  anonymous (publishable key, no JWT)            — public reads + the two
 *                                                       value-constrained public INSERTs only
 *   R  authenticated plain reader (no profile_sites)  — signup grants NOTHING
 *                                                       incl. self-promotion attempts
 *   S  authenticated staff (SUPABASE_ADMIN_TOKEN)     — drafts + throwaway CRUD
 *                                                       + cross-site isolation
 *   D  storage: public read, anon/non-editor upload rejected, editor upload
 *      under india_tech/ only
 *
 * MUTATION POLICY: only `zzz-check-` prefixed throwaway fixtures are ever
 * written, only into sites allowed by config.assertWritableSiteSlug()
 * (india_tech + a temporary `zzz-check*` site), and every fixture is removed
 * in a `finally` block. Seeded/production rows and the travel site are never
 * touched. No credential is ever printed (lib/config.js redaction).
 *
 * Usage:
 *   node tool/live_checks/rls_matrix.js [--verbose]
 * Env: SUPABASE_URL, SUPABASE_ANON_KEY, and optionally
 *      SUPABASE_ADMIN_TOKEN (access token, operator-created staff account)
 *      SUPABASE_READER_TOKEN (access token, account with NO profile_sites)
 *      SUPABASE_SITE_ADMIN_TOKEN (admin/editor of india_tech only)
 *      CHECK_SECOND_SITE_SLUG (temporary zzz-check* site for isolation)
 */

const crypto = require('crypto');
const config = require('./lib/config');
const api = require('./lib/api');

const NOW_ISO = new Date().toISOString();
const VERBOSE = process.argv.includes('--verbose');

/* Registry the finalize step uses so cleanup runs even when main() throws
 * (a mid-run crash previously leaked zzz-check- fixtures). */
const RUNTIME = { rep: null, clients: [] };
let readerCleanupNote = '';

const isReject = (r) =>
  r.status === 401 || r.status === 403 || (r.error && String(r.error.code).startsWith('42501'));
const isAccept = (r) => r.status >= 200 && r.status < 300;
const rowCount = (r) => (r.total !== null ? r.total : r.rows ? r.rows.length : 0);
const evidence = (r, extra = '') =>
  `HTTP ${r.status}${r.error && r.error.code ? ' ' + r.error.code : ''}` +
  `${r.total !== null ? ` rows=${r.total}` : r.rows ? ` rows=${r.rows.length}` : ''}` +
  `${r.error ? ` msg="${String(r.error.message).slice(0, 90)}"` : ''}${extra ? ' ' + extra : ''}`;

async function main() {
  const cfg = config.load();
  const rep = new api.Report('rls_matrix.js — security suite', cfg.secrets);
  const anon = new api.Api(cfg);
  const admin = cfg.adminToken ? new api.Api(cfg, cfg.adminToken) : null;
  const siteAdmin = cfg.siteAdminToken ? new api.Api(cfg, cfg.siteAdminToken) : null;
  RUNTIME.rep = rep;
  RUNTIME.clients = [anon, admin, siteAdmin];

  process.stdout.write('rls_matrix.js — identity fingerprints only (no key values)\n');
  process.stdout.write(config.identitySummary(cfg) + '\n');

  /* ---------------- pre-flight: is the schema applied at all? ------------- */
  const probe = await api.probeSchema(cfg);
  if (probe.applied !== true) {
    process.stdout.write(api.notAppliedBanner('the blog tables', probe));
    process.stdout.write(`  probe: ${probe.reason} — ${probe.detail}\n`);
    for (const name of CASE_NAMES) rep.skip(name, api.stateSkipReason(probe));
    process.stdout.write(
      '\nRESULT: 0 assertions executed, 0 failures. Run again after the apply + seed.\n'
    );
    return 0;
  }

  /* ---------------- site resolution --------------------------------------- */
  const siteRes = await anon.list('sites', 'select=id,slug,is_active&slug=eq.india_tech');
  if (!siteRes.ok || !siteRes.rows || !siteRes.rows.length) {
    for (const name of CASE_NAMES) rep.skip(name, `india_tech site row not found (${evidence(siteRes)})`);
    process.stdout.write('\nRESULT: tables exist but seed (006) is not present yet.\n');
    return 0;
  }
  const SITE_ID = siteRes.rows[0].id;
  rep.info('site resolved', `india_tech -> ${SITE_ID}`);

  let reader = null;
  let readerId = null;
  // (readerCleanupNote is module-level so the finalize step can report it)

  /* =========================== A. ANONYMOUS READS ========================= */
  const pub = await anon.list('posts', 'select=id,slug,status,scheduled_for,published_at&order=published_at.desc');
  rep.check(
    pub.ok && rowCount(pub) > 0,
    'A1 anon lists published posts',
    `${evidence(pub)} firstSlug=${(pub.rows && pub.rows[0] && pub.rows[0].slug) || '-'}`
  );
  const nonPublicVisible = (pub.rows || []).filter(
    (p) =>
      !(
        p.status === 'published' ||
        (p.status === 'scheduled' && p.scheduled_for && new Date(p.scheduled_for) <= new Date(NOW_ISO))
      )
  );
  rep.check(
    nonPublicVisible.length === 0,
    'A2 anon result set is published/due-scheduled only',
    `violations=${nonPublicVisible.length ? JSON.stringify(nonPublicVisible.slice(0, 3)) : 0}`
  );

  for (const [label, filter, slugs] of [
    ['A3 anon cannot see drafts', 'status=eq.draft', config.KNOWN_SEED_FIXTURES.draftSlugs],
    ['A4 anon cannot see archived', 'status=eq.archived', config.KNOWN_SEED_FIXTURES.archivedSlugs],
    [
      'A5 anon cannot see future-scheduled',
      `status=eq.scheduled&scheduled_for=gt.${NOW_ISO}`,
      config.KNOWN_SEED_FIXTURES.futureScheduledSlugs,
    ],
  ]) {
    const c = await anon.count('posts', filter);
    rep.check(
      c.ok && rowCount(c) === 0,
      label,
      `${evidence(c)} (must be 0 — staff-only status)`
    );
    for (const slug of slugs) {
      const one = await anon.list('posts', `select=slug,status&slug=eq.${slug}`);
      rep.check(
        one.ok && rowCount(one) === 0,
        `${label} — known seed slug`,
        `${slug}: ${evidence(one)}`
      );
    }
  }

  const publicIds = new Set((pub.rows || []).map((p) => p.id));
  const pt = await anon.list('post_tags', 'select=post_id,tag_id');
  const orphanTags = (pt.rows || []).filter((r) => !publicIds.has(r.post_id));
  rep.check(
    pt.ok && orphanTags.length === 0,
    'A6 anon post_tags limited to publicly visible posts',
    `${evidence(pt)} leakRows=${orphanTags.length}`
  );

  for (const [table, label] of [
    ['sites', 'A7 anon reads active site row'],
    ['categories', 'A8 anon reads active categories'],
    ['authors', 'A9 anon reads active authors'],
    ['tags', 'A10 anon reads tags'],
    ['redirects', 'A11 anon reads redirects map'],
    ['site_settings', 'A12 anon reads site_settings (config only, no secrets)'],
    ['media', 'A13 anon reads media metadata'],
  ]) {
    const r = await anon.count(table, 'select=*');
    rep.check(r.ok && rowCount(r) > 0, label, `${evidence(r)}`);
  }

  /* ================== B. ANONYMOUS READS OF STAFF-ONLY TABLES ============= */
  for (const table of config.ANON_DENIED_READ) {
    const r = await anon.list(table, 'select=*');
    const blocked = isReject(r);
    const emptied = r.ok && rowCount(r) === 0;
    rep.check(
      blocked || emptied,
      `B anon cannot read ${table}`,
      `${evidence(r)} mechanism=${blocked ? 'PERMISSION BLOCK (401/403)' : emptied ? 'permissive-absent: SELECT filtered to 0 rows' : 'LEAK'}`
    );
  }

  /* ===================== C. ANONYMOUS WRITE ATTEMPTS ====================== */
  const tag = config.fixtureTag();
  const anonWritePayloads = {
    posts: {
      site_id: SITE_ID,
      title: `${tag} anon post write`,
      slug: `${tag}-anon-post`,
      content: 'must never be inserted',
      status: 'draft',
    },
    categories: { site_id: SITE_ID, name: `${tag} anon category`, slug: `${tag}-anon-cat` },
    authors: { site_id: SITE_ID, name: `${tag} anon author`, slug: `${tag}-anon-author` },
    site_settings: { site_id: SITE_ID, site_name: `${tag} anon settings` },
    media: {
      site_id: SITE_ID,
      file_name: `${tag}.png`,
      storage_path: `india_tech/${tag}-anon.png`,
    },
    redirects: { site_id: SITE_ID, old_path: `/${tag}-anon`, new_path: '/' },
  };
  for (const [table, payload] of Object.entries(anonWritePayloads)) {
    const r = await anon.insert(table, payload);
    const rejected = isReject(r);
    const silentOk = isAccept(r);
    // 409/23xxx = the request reached Postgres integrity checks, which means
    // RLS let the row through before the unique/FK error fired -> that is a LEAK.
    const reachedIntegrity =
      r.status === 409 || (r.error && ['23505', '23503', '23514'].includes(String(r.error.code)));
    let extra = '';
    if (silentOk && r.rows && r.rows[0] && r.rows[0].id) {
      extra = ` createdId=${r.rows[0].id}`;
      if (admin) admin.track(`cleanup anon-write leak in ${table}`, () => admin.remove(table, `id=eq.${r.rows[0].id}`));
      else rep.info(`C1 note ${table}`, 'anon write accepted and no staff token to remove the fixture — operator cleanup needed');
    }
    if (reachedIntegrity) extra = ' (integrity error AFTER the policy layer — treat as a policy leak)';
    rep.check(
      rejected,
      `C1 anon INSERT ${table} rejected`,
      `${evidence(r)}${silentOk ? ' <- SILENT SUCCESS (anon write accepted!)' : ''}${reachedIntegrity ? extra : ''}`
    );
  }

  const NONEXISTENT_UUID = '00000000-0000-4000-8000-00000000zzzz'.replace('zzzz', 'ffff');
  const anonPatch = await anon.update('posts', { title: `${tag} anon patch` }, `id=eq.${NONEXISTENT_UUID}`);
  rep.check(
    isReject(anonPatch) || (anonPatch.ok && rowCount(anonPatch) === 0),
    'C2 anon UPDATE affects nothing',
    `${evidence(anonPatch)} mechanism=${isReject(anonPatch) ? 'permission block' : '0 rows matched/RLS-filtered'} (target id deliberately nonexistent)`
  );
  const anonDel = await anon.remove('redirects', 'id=eq.00000000-0000-4000-8000-ffffffffffff');
  rep.check(
    isReject(anonDel) || (anonDel.ok && rowCount(anonDel) === 0),
    'C3 anon DELETE affects nothing',
    `${evidence(anonDel)} (target id deliberately nonexistent, no seeded row at risk)`
  );

  /* ============ D. THE TWO ALLOWED ANONYMOUS WRITES (constrained) ========== */
  const subEmail = `${tag}@example.com`;
  if (!admin) {
    // D1 is a POSITIVE write: if it succeeds there is no anon DELETE policy
    // to remove the row, and without a staff token the cleanup registry has
    // no way to remove it. Skip (never leave an untracked write behind).
    rep.skip(
      'D1 anon INSERT subscribers (well-formed @example.com) succeeds',
      'needs SUPABASE_ADMIN_TOKEN so the accepted throwaway row can be removed (anon has no DELETE policy)'
    );
  } else {
    const goodSub = await anon.insert('subscribers', { site_id: SITE_ID, email: subEmail });
    const subId = goodSub.rows && goodSub.rows[0] ? goodSub.rows[0].id : null;
    rep.check(
      isAccept(goodSub),
      'D1 anon INSERT subscribers (well-formed @example.com) succeeds',
      `${evidence(goodSub)} id=${subId || '-'}`
    );
    if (subId && admin) {
      admin.track(`cleanup subscriber ${subEmail}`, () => admin.remove('subscribers', `id=eq.${subId}`));
    } else if (subId) {
      rep.info('D1 note', `no staff token: throwaway subscriber ${subEmail} left behind (operator: delete from public.subscribers where id='${subId}')`);
    }
  }

  for (const [label, body] of [
    ['D2 is_verified=true rejected by WITH CHECK', { site_id: SITE_ID, email: `${tag}-v@example.com`, is_verified: true }],
    ['D3 malformed email rejected', { site_id: SITE_ID, email: `not-an-email-${tag}` }],
    ['D4 unsubscribed_at smuggle rejected', { site_id: SITE_ID, email: `${tag}-u@example.com`, unsubscribed_at: NOW_ISO }],
    ['D5 is_active=false rejected', { site_id: SITE_ID, email: `${tag}-i@example.com`, is_active: false }],
  ]) {
    const r = await anon.insert('subscribers', body);
    // ONLY a policy rejection (401/403/42501) passes. A 2xx or a 409/23505
    // integrity error means the WITH CHECK clause let the row through.
    rep.check(isReject(r), label, `${evidence(r)}${r.status === 409 ? ' <- WITH CHECK PASSED, unique index stopped it (LEAK)' : ''}`);
  }

  const goodEvent = await anon.insert('analytics_events', {
    site_id: SITE_ID,
    event_type: 'page_view',
    session_id: `${tag}-session`,
    path: '/zzz-check-page-view',
  });
  rep.check(isAccept(goodEvent), 'D6 anon INSERT analytics_events page_view succeeds', evidence(goodEvent));
  const goodEvent2 = await anon.insert('analytics_events', {
    site_id: SITE_ID,
    event_type: 'article_view',
    session_id: `${tag}-session`,
    path: '/zzz-check-article-view',
  });
  rep.check(isAccept(goodEvent2), 'D7 anon INSERT analytics_events article_view succeeds', evidence(goodEvent2));
  rep.info(
    'D6/D7 append-only note',
    `analytics_events has no DELETE policy by design (003). Traceable via session_id=${tag}-session; no seeded row modified.`
  );
  for (const bad of ['admin_login', 'click', '', 'DELETE']) {
    const r = await anon.insert('analytics_events', { site_id: SITE_ID, event_type: bad, session_id: `${tag}-session` });
    rep.check(isReject(r), `D8 anon INSERT analytics_events bogus event_type='${bad || '<empty>'}' rejected`, evidence(r));
  }

  /* ================= E. AUTHENTICATED PLAIN READER (no membership) ========= */
  if (cfg.readerToken) {
    reader = new api.Api(cfg, cfg.readerToken);
    RUNTIME.clients.push(reader);
    rep.info('E0 reader identity', `token supplied via env, fingerprint=${config.fingerprint(cfg.readerToken)}`);
  } else if (cfg.allowThrowawaySignup) {
    const email = `${config.fixtureTag()}-reader@example.com`;
    const password = crypto.randomBytes(18).toString('hex'); // ephemeral, never printed
    cfg.secrets.push(password); // redact even if the server echoes it back in an error body
    const su = await anon.signup(email, password, { full_name: 'zzz-check throwaway reader' });
    const direct =
      su.json && su.json.access_token
        ? su.json.access_token
        : su.json && su.json.session && su.json.session.access_token
        ? su.json.session.access_token
        : null;
    let token = direct;
    let tk = { status: direct ? su.status : 0 };
    if (!token) {
      const res = await anon.signIn(email, password);
      tk = res;
      token = res.accessToken;
    }
    if (token) {
      reader = new api.Api(cfg, token);
      RUNTIME.clients.push(reader);
      rep.pass(
        'E0 throwaway reader account created',
        `signup=${su.status} signin=${tk.status || 'implicit'} email=${email} token=${config.fingerprint(token)}`
      );
      readerCleanupNote = email;
    } else {
      rep.skip(
        'E0 authenticated reader plane',
        `no SUPABASE_READER_TOKEN and throwaway signup unavailable (signup=${su.status} signin=${tk ? tk.status : 'n/a'}: ${
          (tk && tk.message) || su.message || 'email confirmation required'
        }). Set SUPABASE_READER_TOKEN to an account with NO profile_sites row.`
      );
      if (su.json && su.json.id) readerCleanupNote = email;
    }
  } else {
    rep.skip('E0 authenticated reader plane', 'throwaway signup disabled (ALLOW_THROWAWAY_SIGNUP=0) and no SUPABASE_READER_TOKEN');
  }

  if (reader) {
    const ownProfile = await reader.list('profiles', 'select=id,role,email');
    readerId = ownProfile.rows && ownProfile.rows[0] ? ownProfile.rows[0].id : null;
    rep.check(
      ownProfile.ok && rowCount(ownProfile) === 1 && !!readerId,
      'E1 reader sees exactly its own profile row',
      `${evidence(ownProfile)} selfRole=${(ownProfile.rows && ownProfile.rows[0] && ownProfile.rows[0].role) || '-'}`
    );
    const memberships = await reader.list('profile_sites', 'select=site_id,role');
    rep.check(
      memberships.ok && rowCount(memberships) === 0,
      'E2 reader has zero profile_sites memberships (plain reader)',
      `${evidence(memberships)}`
    );
    const drafts = await reader.count('posts', 'status=eq.draft');
    rep.check(
      drafts.ok && rowCount(drafts) === 0,
      'E3 reader CANNOT read drafts (signup role grants nothing)',
      `${evidence(drafts)}`
    );
    const published = await reader.count('posts', 'status=eq.published');
    rep.check(
      published.ok && rowCount(published) > 0,
      'E4 reader CAN read published posts (invariant 1: to anon, authenticated)',
      `${evidence(published)}`
    );
    const arch = await reader.count('posts', 'status=eq.archived');
    rep.check(arch.ok && rowCount(arch) === 0, 'E5 reader cannot read archived posts', evidence(arch));

    for (const table of ['subscribers', 'post_revisions', 'analytics_events']) {
      const r = await reader.list(table, 'select=*');
      rep.check(
        isReject(r) || (r.ok && rowCount(r) === 0),
        `E6 reader cannot enumerate ${table}`,
        `${evidence(r)}`
      );
    }

    const writePost = await reader.insert('posts', {
      site_id: SITE_ID,
      title: `${tag} reader write`,
      slug: `${tag}-reader-post`,
      content: 'nope',
      status: 'published',
    });
    rep.check(isReject(writePost), 'E7 reader cannot write posts', evidence(writePost));
    if (isAccept(writePost) && admin && writePost.rows && writePost.rows[0]) {
      admin.track('cleanup E7 leak', () => admin.remove('posts', `id=eq.${writePost.rows[0].id}`));
    }

    /* -------- SELF-PROMOTION ATTEMPTS (must all fail) -------- */
    if (readerId) {
      const promote = await reader.update('profiles', { role: 'super_admin' }, `id=eq.${readerId}`);
      const afterPatch = await reader.list('profiles', `select=role&id=eq.${readerId}`);
      const stillAuthor =
        afterPatch.rows && afterPatch.rows[0] && afterPatch.rows[0].role !== 'super_admin';
      rep.check(
        (isReject(promote) || (promote.ok && rowCount(promote) === 0)) && stillAuthor,
        'E8 SELF-PROMOTION BLOCKED: PATCH own profiles.role=super_admin',
        `${evidence(promote)} roleAfter=${(afterPatch.rows && afterPatch.rows[0] && afterPatch.rows[0].role) || '?'}`
      );

      const insertProfile = await reader.insert('profiles', {
        id: readerId,
        role: 'super_admin',
        email: `${tag}-promote@example.com`,
      });
      rep.check(
        isReject(insertProfile),
        'E9 SELF-PROMOTION BLOCKED: INSERT profiles (own id, role=super_admin)',
        `${evidence(insertProfile)}${insertProfile.status === 409 ? ' <- 409 means the policy layer PASSED (duplicate key stopped it): LEAK' : ''}`
      );
      const recheck = await reader.list('profiles', `select=role&id=eq.${readerId}`);
      rep.check(
        recheck.rows && recheck.rows[0] && recheck.rows[0].role !== 'super_admin',
        'E9b role unchanged after INSERT attempt',
        `role=${(recheck.rows && recheck.rows[0] && recheck.rows[0].role) || '?'}`
      );

      const mint = await reader.insert('profile_sites', {
        profile_id: readerId,
        site_id: SITE_ID,
        role: 'admin',
      });
      rep.check(isReject(mint), 'E10 SELF-ASSIGNMENT BLOCKED: INSERT profile_sites admin', evidence(mint));
      const mint2 = await reader.insert('profile_sites', {
        profile_id: readerId,
        site_id: SITE_ID,
        role: 'editor',
      });
      rep.check(isReject(mint2), 'E10b SELF-ASSIGNMENT BLOCKED: INSERT profile_sites editor', evidence(mint2));
      const after = await reader.list('profile_sites', `select=role&profile_id=eq.${readerId}`);
      rep.check(after.ok && rowCount(after) === 0, 'E10c no membership created', evidence(after));

      const demoteGuard = await reader.update('profile_sites', { role: 'super_admin' }, `profile_id=eq.${readerId}`);
      rep.check(
        isReject(demoteGuard) || (demoteGuard.ok && rowCount(demoteGuard) === 0),
        'E11 reader cannot UPDATE profile_sites',
        evidence(demoteGuard)
      );
    }

    /* -------- public-form rights survive sign-in (invariant 1) -------- */
    const sub = await reader.insert('subscribers', { site_id: SITE_ID, email: `${tag}-reader@example.com` });
    rep.check(isAccept(sub), 'E12 signed-in reader may still subscribe', evidence(sub));
    if (sub.rows && sub.rows[0] && admin) {
      admin.track('cleanup E12 subscriber', () => admin.remove('subscribers', `id=eq.${sub.rows[0].id}`));
    } else if (sub.rows && sub.rows[0]) {
      rep.info('E12 note', `no staff token: throwaway subscriber ${tag}-reader@example.com left behind (id=${sub.rows[0].id}) — operator cleanup needed`);
    }
    const ev = await reader.insert('analytics_events', {
      site_id: SITE_ID,
      event_type: 'page_view',
      session_id: `${tag}-reader`,
    });
    rep.check(isAccept(ev), 'E13 signed-in reader may still emit page_view', evidence(ev));

    /* -------- storage: non-editor upload rejected -------- */
    const objPath = `india_tech/${tag}-reader-upload.png`;
    // MUST use the reader's own access token (reader.token); using
    // cfg.readerToken would silently fall back to anon when the reader was
    // created by throwaway signup, making E14 a vacuous pass.
    const up = await api.storageUpload(cfg, reader.token, 'media', objPath, 'image/png', api.tinyPng());
    rep.check(!up.ok, 'E14 reader storage upload REJECTED', `HTTP ${up.status} ${up.message}`);
    if (up.ok) {
      rep.fail('E14 SECURITY: non-editor storage upload accepted', objPath);
      admin && admin.track('cleanup E14 object', () => api.storageDelete(cfg, cfg.adminToken, 'media', objPath));
      reader.track && reader.track('cleanup E14 object (reader path)', () => api.storageDelete(cfg, reader.token, 'media', objPath));
    }
  }

  /* ============================ F. STAFF PLANE ============================ */
  if (!admin) {
    for (const n of [
      'F1 editor+ reads drafts (anon sees 0)',
      'F2 editor+ reads archived posts',
      'F3 editor+ reads future-scheduled posts',
      'F4 staff reads subscribers/post_revisions/analytics_events',
      'F5 admin creates throwaway draft post',
      'F6 admin updates own throwaway post',
      'F7 throwaway post readable by staff',
      'F8 throwaway draft invisible to anon',
      'F9 sites has NO API insert policy (even staff cannot mint a site)',
      'F11 staff cannot change profiles.role through the API',
      'F12 staff cannot mint a profile_sites membership',
      'F13 cross-site isolation (temporary second site)',
    ]) {
      rep.skip(n, 'SUPABASE_ADMIN_TOKEN not provided (access token of the operator-created admin account)');
    }
  } else {
    const drafts = await admin.count('posts', 'status=eq.draft');
    rep.check(
      drafts.ok && rowCount(drafts) > 0,
      'F1 editor+ reads drafts (anon sees 0)',
      `${evidence(drafts)} anonComparison=${await countFor(anon, 'posts', 'status=eq.draft')}`
    );
    const arch = await admin.count('posts', 'status=eq.archived');
    rep.check(arch.ok && rowCount(arch) > 0, 'F2 editor+ reads archived posts', evidence(arch));
    const fut = await admin.count('posts', `status=eq.scheduled&scheduled_for=gt.${NOW_ISO}`);
    rep.check(fut.ok && rowCount(fut) > 0, 'F3 editor+ reads future-scheduled posts', evidence(fut));

    for (const table of ['subscribers', 'post_revisions', 'analytics_events']) {
      const r = await admin.list(table, 'select=*');
      rep.check(r.ok && rowCount(r) > 0, `F4 staff reads ${table}`, evidence(r));
    }

    /* ---- throwaway post lifecycle on an ALLOWED site (india_tech) ---- */
    config.assertWritableSiteSlug('india_tech', 'throwaway post lifecycle');
    const throwSlug = `${config.fixtureTag()}-lifecycle`;
    const created = await admin.insert('posts', {
      site_id: SITE_ID,
      title: 'zzz-check lifecycle fixture',
      slug: throwSlug,
      content: 'throwaway',
      status: 'draft',
    });
    const createdId = created.rows && created.rows[0] ? created.rows[0].id : null;
    rep.check(isAccept(created) && !!createdId, 'F5 admin creates throwaway draft post', `${evidence(created)} slug=${throwSlug}`);
    if (createdId) {
      admin.track(`cleanup post ${throwSlug}`, () => admin.remove('posts', `id=eq.${createdId}`));
      const upd = await admin.update('posts', { title: 'zzz-check lifecycle fixture (updated)', reading_time: 1 }, `id=eq.${createdId}`);
      rep.check(isAccept(upd) && rowCount(upd) === 1, 'F6 admin updates own throwaway post', evidence(upd));
      const readBack = await admin.list('posts', `select=id,title&slug=eq.${throwSlug}`);
      rep.check(readBack.ok && rowCount(readBack) === 1, 'F7 throwaway post readable by staff', evidence(readBack));
      const anonRead = await anon.list('posts', `select=id&slug=eq.${throwSlug}`);
      rep.check(anonRead.ok && rowCount(anonRead) === 0, 'F8 throwaway draft invisible to anon', evidence(anonRead));
    }

    /* ---- operator-only tables stay closed even to staff ---- */
    const siteWrite = await admin.insert('sites', {
      name: 'zzz-check temp site',
      slug: `${config.fixtureTag()}-site`,
      is_active: false,
    });
    rep.check(
      isReject(siteWrite),
      'F9 sites has NO API insert policy (even staff cannot mint a site)',
      evidence(siteWrite)
    );
    if (isAccept(siteWrite) && siteWrite.rows && siteWrite.rows[0]) {
      rep.fail('F9 SECURITY: sites INSERT allowed through PostgREST', evidence(siteWrite));
      admin.track('cleanup rogue site row', () => admin.remove('sites', `id=eq.${siteWrite.rows[0].id}`));
    }

    const ownAdminProfile = await admin.list('profiles', 'select=id,role&limit=1');
    const adminProfileId = ownAdminProfile.rows && ownAdminProfile.rows[0] ? ownAdminProfile.rows[0].id : null;
    const adminRole = ownAdminProfile.rows && ownAdminProfile.rows[0] ? ownAdminProfile.rows[0].role : 'unknown';
    rep.info('F10 admin profile', `role=${adminRole} membershipsVisible=${await countFor(admin, 'profile_sites', 'select=role')}`);
    if (adminProfileId) {
      const selfRole = await admin.update('profiles', { role: 'super_admin' }, `id=eq.${adminProfileId}`);
      rep.check(
        isReject(selfRole) || (selfRole.ok && rowCount(selfRole) === 0),
        'F11 staff cannot change profiles.role through the API',
        `${evidence(selfRole)} (SQL-operator-only path, invariant 5)`
      );
      const selfAssign = await admin.insert('profile_sites', {
        profile_id: adminProfileId,
        site_id: SITE_ID,
        role: 'admin',
      });
      rep.check(
        isReject(selfAssign),
        'F12 staff cannot mint a profile_sites membership',
        `${evidence(selfAssign)}${selfAssign.status === 409 ? ' <- WITH CHECK/USING PASSED, pkey stopped it: LEAK' : ''}`
      );
      if (isAccept(selfAssign) && selfAssign.rows && selfAssign.rows[0]) {
        rep.fail('F12 SECURITY: profile_sites membership created through the API', JSON.stringify(selfAssign.rows[0]).slice(0, 120));
        admin.track('cleanup minted membership', () =>
          admin.remove('profile_sites', `profile_id=eq.${adminProfileId}&site_id=eq.${SITE_ID}`)
        );
      }
    }

    /* ---- CROSS-SITE ISOLATION ---- */
    const otherSites = await admin.list('sites', 'select=id,slug,is_active&slug=neq.india_tech');
    // An operator-supplied second-site slug is only accepted if it is itself a
    // throwaway zzz-check site — the travel/production siblings are never a
    // write target, whatever the environment says.
    if (cfg.secondSiteSlug && !config.isTempCheckSiteSlug(cfg.secondSiteSlug)) {
      rep.fail(
        'CHECK_SECOND_SITE_SLUG rejected',
        `'${cfg.secondSiteSlug}' is not a zzz-check* throwaway site; isolation probing refuses production siblings (travel site stays untouched)`
      );
    }
    const allowedSecond =
      cfg.secondSiteSlug && config.isTempCheckSiteSlug(cfg.secondSiteSlug) ? cfg.secondSiteSlug : null;
    const tempSite =
      (otherSites.rows || []).find((s) => allowedSecond && s.slug === allowedSecond) ||
      (otherSites.rows || []).find((s) => config.isTempCheckSiteSlug(s.slug)) ||
      null;
    const otherNonWritable = (otherSites.rows || []).find((s) => !config.isWritableSiteSlug(s.slug)) || null;
    if (otherNonWritable) {
      rep.info('cross-site safety', `sibling production site '${otherNonWritable.slug}' is on the write-BLOCKLIST — no request will target it`);
    }
    if (!tempSite) {
      rep.skip(
        'F13 cross-site isolation',
        'no temporary zzz-check* second site found. Operator SQL to create one for the test: ' +
          "insert into public.sites (name, slug, is_active) values ('zzz-check temp', 'zzz-check-temp-site', false) on conflict do nothing;"
      );
    } else {
      const isoClient = siteAdmin || admin;
      const isoLabel = siteAdmin ? 'site-scoped admin/editor token' : 'staff token (no site-scoped token supplied)';
      config.assertWritableSiteSlug(tempSite.slug, `cross-site isolation probe on '${tempSite.slug}'`);
      const cross = await isoClient.insert('posts', {
        site_id: tempSite.id,
        title: 'zzz-check cross-site probe',
        slug: `${config.fixtureTag()}-cross`,
        content: 'should be rejected unless assigned on this site',
        status: 'draft',
      });
      if (siteAdmin) {
        rep.check(
          isReject(cross),
          'F13 site-scoped staff BLOCKED writing another site rows',
          `${evidence(cross)} actor=${isoLabel} site=${tempSite.slug}`
        );
        if (isAccept(cross) && cross.rows && cross.rows[0]) {
          isoClient.track('cleanup cross-site leak', () => isoClient.remove('posts', `id=eq.${cross.rows[0].id}`));
        }
      } else {
        const isSuper = String(adminRole).toLowerCase() === 'super_admin';
        rep.check(
          isSuper ? isAccept(cross) : isReject(cross),
          'F13 cross-site write behaviour matches the token tier',
          `${evidence(cross)} actor=${isoLabel} adminRole=${adminRole} site=${tempSite.slug} ` +
            `(expected: super_admin allowed everywhere, site-scoped denied)`
        );
        if (isAccept(cross) && cross.rows && cross.rows[0]) {
          admin.track(`cleanup cross-site fixture ${tempSite.slug}`, () =>
            admin.remove('posts', `id=eq.${cross.rows[0].id}`)
          );
        }
      }
      const crossRead = await isoClient.count('posts', `site_id=eq.${tempSite.id}`);
      rep.info('F13b cross-site read visibility', `${tempSite.slug} posts visible to ${isoLabel}: ${evidence(crossRead)}`);
    }
  }

  /* ============================ G. STORAGE ================================= */
  const bucketCheck = await anon.list('media', 'select=id,file_name,storage_path,public_url');
  const seeded = (bucketCheck.rows || []).find(
    (m) => m.storage_path && String(m.storage_path).startsWith('india_tech/')
  );
  if (seeded) {
    const read = await api.storagePublicRead(cfg, 'media', seeded.storage_path);
    const objectMissing = read.status === 400 || read.status === 404 || read.status === 403;
    if (read.ok) {
      rep.pass('G1 public read of a seeded media object', `path=${seeded.storage_path} HTTP ${read.status} bytes=${read.bytes}`);
    } else if (objectMissing && !String(seeded.public_url || '').includes('/storage/v1/object/public/media/')) {
      rep.skip(
        'G1 public read of a seeded media object',
        `media row exists (storage_path=${seeded.storage_path}) but the object itself was never uploaded — ` +
          `006 seeds DB metadata only, public_url=${String(seeded.public_url || '').slice(0, 42)}. ` +
          `Public READ is still proven conclusively by G3b (upload -> public URL -> cleanup).`
      );
    } else {
      rep.fail('G1 public read of a seeded media object', `path=${seeded.storage_path} HTTP ${read.status} ${read.message}`);
    }
  } else {
    rep.skip('G1 public read of a seeded media object', 'no media row with an india_tech/ storage_path yet (seed section 8 pending)');
  }

  const anonUp = await api.storageUpload(cfg, null, 'media', `india_tech/${config.fixtureTag()}-anon.png`, 'image/png', api.tinyPng());
  rep.check(!anonUp.ok, 'G2 anon storage upload REJECTED', `HTTP ${anonUp.status} ${anonUp.message}`);
  if (anonUp.ok) rep.fail('G2 SECURITY: anon storage upload accepted', JSON.stringify(anonUp.json));

  const editorToken = cfg.adminToken;
  if (!editorToken) {
    rep.skip('G3 editor upload + public read-back', 'SUPABASE_ADMIN_TOKEN not provided');
    rep.skip('G4 upload blocked outside india_tech/ folder', 'SUPABASE_ADMIN_TOKEN not provided');
    rep.skip('G5 signed URL read', 'SUPABASE_ADMIN_TOKEN not provided');
  } else {
    const objPath = `india_tech/${config.fixtureTag()}-editor.png`;
    const up = await api.storageUpload(cfg, editorToken, 'media', objPath, 'image/png', api.tinyPng());
    rep.check(up.ok, 'G3 editor upload under india_tech/ succeeds', `HTTP ${up.status} ${up.message || objPath}`);
    if (up.ok) {
      const pubRead = await api.storagePublicRead(cfg, 'media', objPath);
      rep.check(pubRead.ok && pubRead.bytes > 0, 'G3b uploaded object readable through the public URL', `HTTP ${pubRead.status} bytes=${pubRead.bytes}`);
      const wrongPath = `zzz-other-folder/${config.fixtureTag()}.png`;
      const wrongFolder = await api.storageUpload(
        cfg, editorToken, 'media', wrongPath, 'image/png', api.tinyPng()
      );
      rep.check(!wrongFolder.ok, 'G4 upload blocked outside the india_tech/ top-level folder', `HTTP ${wrongFolder.status} ${wrongFolder.message}`);
      if (wrongFolder.ok) {
        rep.fail('G4 SECURITY: object written outside the site folder prefix', wrongPath);
        admin.track(`cleanup wrong-folder object ${wrongPath}`, () =>
          api.storageDelete(cfg, editorToken, 'media', wrongPath)
        );
      }
      const signed = await api.storageSignedUrl(cfg, editorToken, 'media', objPath, 60);
      if (signed.ok && signed.signedURL) {
        const got = await api.storageSignedRead(cfg, signed.signedURL);
        rep.check(
          got.ok,
          'G5 signed URL read of the object',
          `HTTP ${got.status} bytes=${got.bytes}${got.bytes > 0 ? ' (token-carrying path omitted from this line)' : ''}`
        );
      } else {
        rep.skip('G5 signed URL read', `signed-url call HTTP ${signed.status} ${signed.message}`);
      }
      // CLEANUP (also guaranteed by the finally block below)
      const del = await api.storageDelete(cfg, editorToken, 'media', objPath);
      rep.check(del.ok, 'G6 throwaway object deleted (cleanup)', `HTTP ${del.status} ${del.message}`);
    }
  }

  /* ---------------- report + cleanup happens in finalize() ----------------
   * (the normal path ends here; finalize is attached to main()'s promise so
   *  registered throwaway fixtures are removed even if main() throws)       */
}

/**
 * Always-run tail: run every client's cleanup registry, print the report.
 * `crashed` marks a mid-suite exception — cleanup still runs, exit code 2.
 */
async function finalize(crashed) {
  const rep = RUNTIME.rep;
  if (!rep) return crashed ? 2 : 0;
  const secrets = rep.secrets || [];
  const cleanup = [];
  for (const client of RUNTIME.clients.filter(Boolean)) {
    cleanup.push(...(await client.runCleanup()));
  }
  rep.print();
  process.stdout.write('\nTHROWAWAY FIXTURE CLEANUP (finalize — runs on pass, fail and crash paths)\n');
  if (!cleanup.length) process.stdout.write('  nothing to clean (no fixture was written)\n');
  for (const c of cleanup) {
    process.stdout.write(`${c.ok ? 'OK  ' : 'FAIL'} | ${config.redact(c.label, secrets)}${c.detail ? ' | ' + config.redact(c.detail, secrets) : ''}\n`);
  }
  if (cleanup.some((c) => !c.ok)) {
    process.stdout.write('WARNING: some throwaway fixtures could not be removed — see labels above.\n');
  }
  if (readerCleanupNote) {
    process.stdout.write(
      `\nThrowaway auth account left in auth.users (no API delete path without a service key — which this\n` +
        `toolkit never uses): ${readerCleanupNote}\n` +
        `   Remove it in Dashboard -> Authentication -> Users.\n`
    );
  }
  const fails = rep.failures;
  process.stdout.write(
    `\nRESULT rls_matrix: ${rep.rows.filter((r) => r.status === 'PASS').length} passed, ` +
      `${fails.length} FAILED, ${rep.rows.filter((r) => r.status === 'SKIP').length} skipped` +
      `${crashed ? ' (suite CRASHED — see stderr above; cleanup was still attempted)' : ''}.\n`
  );
  if (VERBOSE) {
    for (const f of fails) process.stdout.write(`  FAIL ${f.name} :: ${f.evidence}\n`);
  }
  return crashed ? 2 : fails.length ? 1 : 0;
}

async function countFor(client, table, filter) {
  const r = await client.count(table, filter);
  return r.ok ? rowCount(r) : `HTTP ${r.status}`;
}

const CASE_NAMES = [
  'A1 anon lists published posts',
  'A2 anon result set is published/due-scheduled only',
  'A3 anon cannot see drafts',
  'A4 anon cannot see archived',
  'A5 anon cannot see future-scheduled',
  'A6 anon post_tags limited to publicly visible posts',
  'B anon cannot read subscribers',
  'B anon cannot read post_revisions',
  'B anon cannot read analytics_events',
  'B anon cannot read profiles',
  'B anon cannot read profile_sites',
  'C1 anon INSERT posts rejected',
  'E plane reader checks',
  'F plane staff checks',
  'G storage checks',
];

main()
  .then(async () => {
    process.exitCode = await finalize(false);
  })
  .catch(async (e) => {
    process.stderr.write(
      'rls_matrix.js crashed: ' + config.redact((e && (e.stack || e.message)) || String(e), []) + '\n'
    );
    // finalize() runs every registered cleanup even on this crash path.
    process.stderr.write(
      'If throwaway fixtures may remain, re-run with the staff token — every fixture uses the\n' +
        'zzz-check- prefix and is removed by this script; operator SQL cleanup is documented in the report.\n'
    );
    process.exitCode = await finalize(true).catch(() => 2);
  });
