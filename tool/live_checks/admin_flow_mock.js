#!/usr/bin/env node
'use strict';
/**
 * tool/live_checks/admin_flow_mock.js   (LOCAL ONLY — 127.0.0.1 emulator)
 *
 * End-to-end ADMIN CMS flow against the mock Supabase from selftest_mock.js, so
 * the editorial path can be proven with NO live project and NO credentials:
 *
 *   sign-in (staff / site-admin / author / reader) -> session token ->
 *   profiles + profile_sites gate -> SiteContext site resolution ->
 *   post list incl. drafts -> create draft -> edit -> publish ->
 *   post_revisions -> author-tier denials -> plain-reader public-only reads.
 *
 * Three planes matter for honesty:
 *   MOCK_MODE=clean  the flow must PASS and leave nothing behind
 *   MOCK_MODE=empty  nothing exists yet -> every row SKIPs, exit 0 (NOT APPLIED)
 *   MOCK_MODE=leaky  the RLS guards are broken on purpose -> the flow MUST FAIL,
 *                    which is what makes the clean-mode PASS non-vacuous
 *
 * A STATIC plane re-reads the real Dart sources (lib/**) and asserts the shape
 * of the login path, so the file:line claims in the report are checked by code
 * instead of by prose.
 *
 * Usage:
 *   node tool/live_checks/admin_flow_mock.js
 *   node tool/live_checks/admin_flow_mock.js --mode=clean
 *
 * Exit code 0 only when clean passed, empty degraded honestly and leaky failed.
 * (leaky is a NEGATIVE CONTROL: its FAIL rows are the desired outcome, so a
 * `--mode=leaky` run exiting 0 means the control behaved, not that the CMS did.)
 * Nothing here ever talks to a non-loopback address: see assertLoopback().
 */

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { spawn } = require('child_process');

const config = require('./lib/config');
const api = require('./lib/api');

const REPO = config.REPO_ROOT;
const MOCK_SERVER = path.join(__dirname, 'selftest_mock.js');
const MODES = ['clean', 'empty', 'leaky'];

const D = (...p) => path.join(REPO, 'lib', ...p);
const SRC = {
  loginView: D('features', 'admin', 'auth', 'views', 'admin_login_view.dart'),
  authController: D('features', 'admin', 'auth', 'controllers', 'admin_auth_controller.dart'),
  authService: D('core', 'supabase', 'auth_service.dart'),
  middleware: D('app', 'middleware', 'admin_auth_middleware.dart'),
  siteContext: D('core', 'supabase', 'site_context.dart'),
  siteConfig: D('app', 'config', 'site_config.dart'),
  profileRepo: D('data', 'repositories', 'supabase_profile_repository.dart'),
  postAdminRepo: D('data', 'repositories', 'supabase_post_admin_repository.dart'),
  articleRepo: D('data', 'repositories', 'supabase_article_repository.dart'),
  scaffold: D('features', 'admin', 'layouts', 'admin_scaffold.dart'),
  articleEditorView: D('features', 'admin', 'articles', 'views', 'admin_article_editor_view.dart'),
  initialBinding: D('app', 'bindings', 'initial_binding.dart'),
  appPages: D('app', 'routes', 'app_pages.dart'),
  rolePermissions: D('core', 'supabase', 'role_permissions.dart'),
};
const read = (file) => {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return '';
  }
};

/** Every .dart file under lib/ (used to prove "no call site" claims by
 *  exhaustive grep instead of by eyeballing). */
function dartFiles(dir = path.join(REPO, 'lib'), out = []) {
  let entries = [];
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) dartFiles(full, out);
    else if (e.name.endsWith('.dart')) out.push(full);
  }
  return out;
}

/* ------------------------------------------------------------------ *
 * loopback rail
 * ------------------------------------------------------------------ */
function assertLoopback(base) {
  let u;
  try {
    u = new URL(base);
  } catch {
    throw new Error(`SAFETY BLOCK: '${base}' is not a URL — admin_flow_mock.js only speaks to the 127.0.0.1 emulator`);
  }
  const loopback = ['127.0.0.1', 'localhost', '[::1]'].includes(u.hostname);
  if (!loopback || u.protocol !== 'http:') {
    throw new Error(
      `SAFETY BLOCK: admin_flow_mock.js refuses to target ${u.protocol}//${u.host}. ` +
        'It drives the local emulator only; the live project is exercised by run_all.js ' +
        'with operator-supplied credentials.'
    );
  }
  return base;
}

/* ------------------------------------------------------------------ *
 * static mirror of the Dart client-side gate (admin_auth_controller.dart
 * `_loadProfile`, profile_model.dart `effectiveRole`/`hasSiteAccess`,
 * admin_auth_middleware.dart `redirect`). A model, labelled as such in the
 * report — Dart execution needs the Flutter toolchain, which is out of scope.
 * ------------------------------------------------------------------ */
function modelAdminGate(profileRow, membershipRow) {
  if (!profileRow) return { decision: 'DENY_AND_SIGNOUT', reason: 'no profiles row', hasSiteAccess: false, effectiveRole: null };
  if (profileRow.is_active !== true) {
    return { decision: 'DENY_AND_SIGNOUT', reason: 'profiles.is_active is not true', hasSiteAccess: false, effectiveRole: null };
  }
  const siteRole = membershipRow && membershipRow.is_active === true ? membershipRow.role : null;
  const globalRole = profileRow.role;
  return {
    decision: 'OPEN_CMS',
    reason: 'profile active',
    hasSiteAccess: globalRole === 'super_admin' || siteRole !== null,
    effectiveRole: globalRole === 'super_admin' ? 'super_admin' : siteRole || 'author',
  };
}

/* ------------------------------------------------------------------ *
 * mock server lifecycle (same contract selftest_mock.js uses)
 * ------------------------------------------------------------------ */
function startMock(mode) {
  const child = spawn(process.execPath, [MOCK_SERVER, '--serve'], {
    env: { ...process.env, MOCK_MODE: mode, PORT: '0' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  return new Promise((resolve, reject) => {
    let buf = '';
    const timer = setTimeout(() => reject(new Error(`mock(${mode}) never reported a listening port: ${buf}`)), 30000);
    child.stdout.on('data', (d) => {
      buf += String(d);
      const m = buf.match(/listening on (http:\/\/127\.0\.0\.1:\d+)/);
      if (m) {
        clearTimeout(timer);
        resolve({ base: assertLoopback(m[1]), child, mode });
      }
    });
    child.on('exit', (code) => {
      clearTimeout(timer);
      reject(new Error(`mock(${mode}) exited early code=${code}: ${buf}`));
    });
  });
}

function capturePrint(fn) {
  const real = process.stdout.write.bind(process.stdout);
  let buf = '';
  process.stdout.write = (chunk) => {
    buf += String(chunk);
    return true;
  };
  try {
    fn();
  } finally {
    process.stdout.write = real;
  }
  return buf;
}

const rowCount = (r) => (r && typeof r.total === 'number' ? r.total : r && r.rows ? r.rows.length : 0);
const isReject = (r) => !r || r.status === 403 || r.status === 401 || r.status === 406 || r.status === 409 || (r.error && /42501|row-level security|permission denied/i.test(r.error.message || ''));
const ev = (r) => `status=${r.status} rows=${rowCount(r)}${r.error ? ` msg="${String(r.error.message).slice(0, 90)}"` : ''}`;

/** posts_select_public predicate (003:342-346), transcribed for the negative
 *  cross-site probes: anything that is not published and not already-due is
 *  private and may never cross a site boundary. */
const isPublicRow = (p) =>
  p && (p.status === 'published' || (p.status === 'scheduled' && p.scheduled_for && new Date(p.scheduled_for) <= new Date()));

// Every bearer token and every ephemeral password this process ever handed to
// the emulator. Module scope on purpose: the crash handler at the bottom has to
// redact with the same list, and a stack trace captured mid sign-in is exactly
// where a raw value would surface.
const ISSUED_SECRETS = [];

/* ------------------------------------------------------------------ *
 * the flow
 * ------------------------------------------------------------------ */
async function runFlow(mode, base) {
  // The reporter is seeded with the (growing) ISSUED_SECRETS array so every row
  // is masked at add() time, not only at echo time.
  const rep = new api.Report(`admin_flow_mock.js [${mode}] — CMS flow against the emulator`, ISSUED_SECRETS);
  const identities = [];
  const issuedSecrets = ISSUED_SECRETS;

  const cfg = {
    url: base,
    anonKey: 'mock-anon-key',
    adminToken: null,
    readerToken: null,
    siteAdminToken: null,
    adminEmail: null,
    adminPassword: null,
    secrets: ['mock-anon-key', 'mock-admin-token', 'mock-reader-token', 'mock-site-admin-token', 'mock-author-token'],
  };
  const anon = new api.Api(cfg);
  const SITE_SLUG = 'india_tech';
  const TRAVEL_SLUG = 'go-travel-pulse';
  const TEMP_SLUG = 'zzz-check-temp-site';

  /* ---- pre-flight: does the schema exist at all? ---- */
  const probe = await api.probeSchema(cfg);
  if (probe.applied !== true) {
    process.stdout.write(config.redact(api.notAppliedBanner('the mock admin CMS flow', probe), ISSUED_SECRETS));
    rep.skip('CMS flow', `${mode}: ${api.stateSkipReason(probe)} — no assertion was attempted`);
    rep.skip('author tier denials', `${mode}: no tables`);
    rep.skip('reader public-only reads', `${mode}: no tables`);
    rep.skip('post_revisions', `${mode}: no tables`);
    rep.info('STATIC plane still runs', 'the Dart-source assertions below do not need a database at all');
    staticPlane(rep);
    return { rep, mode, issuedSecrets, applied: false };
  }
  rep.pass('P0 emulator schema probe', `${mode}: /rest/v1/sites reachable (${probe.detail})`);

  /* ---- discover the mock identities from the emulator (no duplication) ---- */
  let idRes = { ok: false, rows: null };
  try {
    idRes = await fetch(`${base}/mock/v1/identities`).then(async (r) => ({
      ok: r.ok,
      rows: await r.json(),
    }));
  } catch (e) {
    idRes = { ok: false, rows: null, err: e.message };
  }
  const rows = Array.isArray(idRes.rows) ? idRes.rows : [];
  rows.forEach((r) => identities.push(r.email));
  rep.check(rows.length >= 4, 'P1 four staff/reader tiers discoverable', `rows=${rows.length} (${rows.map((r) => r.tier).join(', ')})`);
  if (!rows.length) {
    rep.fail('P1 SECURITY: flow is vacuous', 'the emulator exposed no identities — nothing could be signed in');
    staticPlane(rep);
    return { rep, mode, issuedSecrets, applied: true };
  }

  /* ---- S. sign-in + session ---- */
  const byTier = {};
  for (const id of rows) byTier[id.tier] = id;
  const clientFor = (token) => {
    const c = new api.Api(cfg, token);
    issuedSecrets.push(token);
    return c;
  };
  const signIn = async (email) => {
    const password = crypto.randomBytes(9).toString('hex');
    cfg.secrets.push(password);
    issuedSecrets.push(password);
    const res = await anon.signIn(email, password);
    return res;
  };

  const adminIn = await signIn(byTier.super_admin.email);
  rep.check(adminIn.ok && !!adminIn.accessToken, 'S1 staff sign-in (password grant) yields a session token', `status=${adminIn.status} token=${config.fingerprint(adminIn.accessToken)}`);
  const badIn = await signIn('mock-nobody@btp.test');
  rep.check(!badIn.ok && !badIn.accessToken, 'S2 unknown account is denied a session', `status=${badIn.status} "${String(badIn.message).slice(0, 40)}"`);
  const emptyPw = await anon.signIn(byTier.super_admin.email, '');
  rep.check(!emptyPw.ok && !emptyPw.accessToken, 'S3 empty password denied (mirrors login() validation)', `status=${emptyPw.status}`);
  if (!adminIn.accessToken) {
    rep.fail('S1 SECURITY: sign-in produced no token', 'the rest of the flow cannot run');
    staticPlane(rep);
    return { rep, mode, issuedSecrets, applied: true };
  }
  const admin = clientFor(adminIn.accessToken);

  /* ---- CTX. SiteContext equivalent: the site id comes from the SERVER ---- */
  const siteLookup = await anon.list('sites', `select=id,slug,is_active&slug=eq.${SITE_SLUG}`);
  const siteId = siteLookup.rows && siteLookup.rows[0] ? siteLookup.rows[0].id : null;
  rep.check(!!siteId, 'CTX1 active site id resolved by slug from public.sites', `slug=${SITE_SLUG} id=${siteId ? config.fingerprint(siteId) : 'none'} (site_context.dart:27-44)`);
  const travel = await anon.list('sites', `select=id,slug&slug=eq.${TRAVEL_SLUG}`);
  const travelId = travel.rows && travel.rows[0] ? travel.rows[0].id : null;
  rep.check(!!siteId && siteId !== travelId, 'CTX2 the resolved site is never the sibling production site', `india_tech=${siteId ? 'ok' : 'missing'} travel=${travelId || 'unread'}`);
  const anonSites = await anon.list('sites', 'select=slug');
  const anonSlugs = (anonSites.rows || []).map((s) => s.slug);
  rep.check(!anonSlugs.includes('zzz-check-temp-site'), 'CTX3 inactive site hidden from anon (sites_select_public)', `visible=${anonSlugs.join('|')}`);

  /* ---- S4/S5. profile + membership, exactly as SupabaseProfileRepository ---- */
  const prof = await admin.list('profiles', 'select=id,role,email,is_active&limit=1');
  const profileRow = prof.rows && prof.rows[0] ? prof.rows[0] : null;
  rep.check(prof.ok && !!profileRow && profileRow.role === 'super_admin' && profileRow.is_active === true, 'S4 admin reads its own profiles row', `role=${profileRow && profileRow.role} active=${profileRow && profileRow.is_active}`);
  const memberships = await admin.list('profile_sites', `select=role,is_active,site_id&site_id=eq.${siteId}`);
  const memberRow = memberships.rows && memberships.rows[0] ? memberships.rows[0] : null;
  rep.check(memberships.ok && !!memberRow && memberRow.is_active === true, 'S5 admin membership readable for the resolved site', ev(memberships));
  const adminGate = modelAdminGate(profileRow, memberRow);
  rep.check(adminGate.decision === 'OPEN_CMS' && adminGate.hasSiteAccess === true, 'S6 gate model: staff membership opens the CMS', `decision=${adminGate.decision} effectiveRole=${adminGate.effectiveRole}`);

  /* ---- L. CMS list: staff sees drafts, the public feed does not ---- */
  const allPosts = await admin.list('posts', `select=id,slug,status,author_id&site_id=eq.${siteId}`);
  const byStatus = (rows2, s) => (rows2 || []).filter((p) => p.status === s);
  rep.check(allPosts.ok && byStatus(allPosts.rows, 'draft').length >= 4, 'L1 CMS list includes the seeded drafts', `${ev(allPosts)} drafts=${byStatus(allPosts.rows, 'draft').length}`);
  rep.check(byStatus(allPosts.rows, 'archived').length >= 2, 'L2 CMS list includes archived posts (staff-only)', `archived=${byStatus(allPosts.rows, 'archived').length}`);
  const publicList = await anon.list('posts', `select=id,slug,status&site_id=eq.${siteId}`);
  rep.check(publicList.ok && byStatus(publicList.rows, 'draft').length === 0, 'L3 anon/public feed has zero drafts', `${ev(publicList)}`);
  const stats = await admin.count('posts', `site_id=eq.${siteId}`);
  rep.check(stats.ok && rowCount(stats) >= 20, 'L4 dashboard counts come from the DB, not list length', `total=${rowCount(stats)} anonVisible=${rowCount(publicList)}`);

  /* ---- C. create -> edit -> revision -> publish (the admin's own session) ---- */
  let throwThrew = false;
  try {
    config.assertWritableSiteSlug(TRAVEL_SLUG, 'mock CMS fixture');
  } catch {
    throwThrew = true;
  }
  rep.check(throwThrew, 'C0 write rail blocks the sibling production site', 'assertWritableSiteSlug threw before any request');
  config.assertWritableSiteSlug(SITE_SLUG, 'mock CMS fixture');

  const tag = config.fixtureTag();
  const draftSlug = `${tag}-draft`;
  const created = await admin.insert('posts', {
    site_id: siteId,
    slug: draftSlug,
    title: 'zzz-check mock CMS draft',
    excerpt: 'mock-only fixture',
    content: 'body under revision',
    status: 'draft',
    category_id: null,
    author_id: null,
    scheduled_for: null,
    published_at: null,
  });
  const draftId = created.rows && created.rows[0] ? created.rows[0].id : null;
  rep.check(created.status === 201 && !!draftId, 'C1 admin creates a draft post', `${ev(created)} slug=${draftSlug}`);

  if (draftId) {
    admin.track('cleanup C1 draft', () => admin.remove('posts', `id=eq.${draftId}`));
    const anonSeesDraft = await anon.list('posts', `select=id&slug=eq.${draftSlug}`);
    rep.check(anonSeesDraft.ok && rowCount(anonSeesDraft) === 0, 'C2 the new draft is invisible to the public feed', ev(anonSeesDraft));

    const edited = await admin.update('posts', { title: 'zzz-check mock CMS draft (v2)', content: 'edited body' }, `id=eq.${draftId}&site_id=eq.${siteId}`);
    rep.check(edited.ok && rowCount(edited) === 1, 'C3 admin edits the draft (site-scoped update)', ev(edited));

    const nextRev = await admin.list('post_revisions', `select=revision_number&post_id=eq.${draftId}&order=revision_number.desc&limit=1`);
    const highest = nextRev.rows && nextRev.rows.length ? Number(nextRev.rows[0].revision_number || 0) : 0;
    rep.check(nextRev.ok && highest === 0, 'C4 revision numbering starts at 1 for a new post', `readback=${JSON.stringify(nextRev.rows)}`);

    const revision = await admin.insert('post_revisions', {
      post_id: draftId,
      title: 'zzz-check mock CMS draft',
      excerpt: 'mock-only fixture',
      content: 'body under revision',
      revision_number: highest + 1,
    });
    rep.check(revision.status === 201, 'C5 publish-before edit snapshots post_revisions', ev(revision));
    const revRead = await admin.list('post_revisions', `select=id,revision_number&post_id=eq.${draftId}`);
    rep.check(revRead.ok && rowCount(revRead) >= 1, 'C6 revision history readable back by the author of the edit', ev(revRead));
    const revEdit = await admin.update('post_revisions', { content: 'tampered history' }, `post_id=eq.${draftId}`);
    rep.check(
      isReject(revEdit) || (revEdit.ok && rowCount(revEdit) === 0),
      'C7 revision rows are immutable (no UPDATE policy in 003)',
      ev(revEdit)
    );

    const published = await admin.update('posts', { status: 'published', published_at: new Date().toISOString() }, `id=eq.${draftId}&site_id=eq.${siteId}`);
    rep.check(published.ok && rowCount(published) === 1, 'C8 admin publishes (status patch only, body untouched)', ev(published));
    const publicAfter = await anon.list('posts', `select=id&slug=eq.${draftSlug}`);
    rep.check(publicAfter.ok && rowCount(publicAfter) === 1, 'C9 published post is now in the public feed', ev(publicAfter));
    const adminAfter = await admin.list('posts', `select=id,status&slug=eq.${draftSlug}`);
    rep.check(
      adminAfter.ok && adminAfter.rows && adminAfter.rows[0] && adminAfter.rows[0].status === 'published',
      'C10 staff read-back confirms the lifecycle transition',
      `status=${adminAfter.rows && adminAfter.rows[0] && adminAfter.rows[0].status}`
    );

    const removed = await admin.remove('posts', `id=eq.${draftId}`);
    const afterDelete = await admin.list('posts', `select=id&slug=eq.${draftSlug}`);
    rep.check(removed.status === 204 && rowCount(afterDelete) === 0, 'C11 fixture removed again (no residue in the emulator)', `delete=${removed.status} remaining=${rowCount(afterDelete)}`);
  }

  /* ---- AU. author tier: the denials that must hold ---- */
  // The byline an author owns is resolved from the server (authors.user_id is
  // what is_linked_author()/can_edit_post() join on), never hardcoded.
  const bylines = await anon.list('authors', 'select=id,user_id,slug');
  const ownByline = (bylines.rows || []).find((a) => a.user_id) || null;
  const foreignByline = (bylines.rows || []).find((a) => !a.user_id) || null;
  rep.check(!!ownByline && !!foreignByline, 'AU0 linked vs unlinked byline resolvable', `own=${ownByline ? ownByline.slug : 'none'} foreign=${foreignByline ? foreignByline.slug : 'none'}`);

  const authorIn = await signIn(byTier.site_author.email);
  rep.check(authorIn.ok && !!authorIn.accessToken, 'AU1 author-tier sign-in yields its own session', `status=${authorIn.status}`);
  const author = authorIn.accessToken ? clientFor(authorIn.accessToken) : admin;
  const authorProf = await author.list('profiles', 'select=id,role,is_active&limit=1');
  const authorProfile = authorProf.rows && authorProf.rows[0] ? authorProf.rows[0] : null;
  const authorMember = await author.list('profile_sites', `select=role,is_active&site_id=eq.${siteId}`);
  const authorMembership = authorMember.rows && authorMember.rows[0] ? authorMember.rows[0] : null;
  rep.check(
    !!authorProfile && authorProfile.role === 'author' && !!authorMembership && authorMembership.role === 'author',
    'AU2 author tier: global role author + per-site role author',
    `global=${authorProfile && authorProfile.role} site=${authorMembership && authorMembership.role}`
  );
  const authorGate = modelAdminGate(authorProfile, authorMembership);
  rep.check(authorGate.effectiveRole === 'author' && authorGate.hasSiteAccess === true, 'AU3 gate model for an author member', `effective=${authorGate.effectiveRole}`);

  const authorPosts = await author.list('posts', `select=id,slug,status,author_id&site_id=eq.${siteId}`);
  const authorDrafts0 = byStatus(authorPosts.rows, 'draft');
  rep.check(
    authorPosts.ok && authorDrafts0.length === 0,
    'AU4 author sees NO unattributed or other-author drafts',
    `authorDrafts=${authorDrafts0.length} staffDrafts=${byStatus(allPosts.rows, 'draft').length} (posts_select_staff byline branch)`
  );
  rep.check(byStatus(authorPosts.rows, 'published').length > 0, 'AU5 author still reads the public feed', `published=${byStatus(authorPosts.rows, 'published').length}`);

  const pubByAuthor = await author.insert('posts', {
    site_id: siteId,
    slug: `${config.fixtureTag()}-author-publish`,
    title: 'zzz-check author files published',
    content: 'should be refused',
    status: 'published',
    author_id: ownByline ? ownByline.id : null,
  });
  rep.check(isReject(pubByAuthor), 'AU6 author CANNOT file a published post (draft-only INSERT)', ev(pubByAuthor));

  const otherByline = await author.insert('posts', {
    site_id: siteId,
    slug: `${config.fixtureTag()}-wrong-byline`,
    title: 'zzz-check author uses another byline',
    content: 'should be refused',
    status: 'draft',
    author_id: foreignByline ? foreignByline.id : null,
  });
  rep.check(isReject(otherByline), 'AU7 author CANNOT file under someone else\'s byline', ev(otherByline));

  const ownDraftSlug = `${config.fixtureTag()}-author-own`;
  const ownDraft = await author.insert('posts', {
    site_id: siteId,
    slug: ownDraftSlug,
    title: 'zzz-check author own draft',
    content: 'allowed as a draft',
    status: 'draft',
    author_id: ownByline ? ownByline.id : null,
  });
  const ownDraftId = ownDraft.rows && ownDraft.rows[0] ? ownDraft.rows[0].id : null;
  rep.check(ownDraft.status === 201 && !!ownDraftId, 'AU8 author CAN file a draft under its own linked byline', ev(ownDraft));
  if (ownDraftId) {
    admin.track('cleanup AU8 author draft', () => admin.remove('posts', `id=eq.${ownDraftId}`));
  }

  const foreignPost = (allPosts.rows || []).find((p) => p.status === 'draft' && !p.author_id);
  if (foreignPost) {
    const touchForeign = await author.update('posts', { title: 'zzz-check author tampering' }, `id=eq.${foreignPost.id}&site_id=eq.${siteId}`);
    rep.check(
      isReject(touchForeign) || (touchForeign.ok && rowCount(touchForeign) === 0),
      'AU9 author cannot edit an unattributed/other-author draft',
      `${ev(touchForeign)} target=${foreignPost.slug}`
    );
    const foreignRev = await author.insert('post_revisions', {
      post_id: foreignPost.id,
      title: 'zzz-check forged revision',
      content: 'nope',
      revision_number: 1,
    });
    rep.check(isReject(foreignRev), 'AU10 author cannot forge a revision on a foreign post', ev(foreignRev));
  } else {
    rep.fail('AU9 vacuous: no unattributed draft to probe', 'the seeded draft pool disappeared from the staff read');
  }

  if (ownDraftId) {
    const ownEdit = await author.update('posts', { content: 'author edits own draft' }, `id=eq.${ownDraftId}&site_id=eq.${siteId}`);
    rep.check(ownEdit.ok && rowCount(ownEdit) === 1, 'AU11 author CAN edit its own draft (posts_update_own_author)', ev(ownEdit));
    const ownRev = await author.insert('post_revisions', {
      post_id: ownDraftId,
      title: 'zzz-check author own draft',
      content: 'snapshot',
      revision_number: 1,
    });
    rep.check(ownRev.status === 201, 'AU12 author may snapshot its own post into post_revisions', ev(ownRev));
    const foreignRead = await author.list('post_revisions', 'select=id&post_id=eq.p1');
    rep.check(foreignRead.ok && rowCount(foreignRead) === 0, 'AU13 author sees no revisions of posts it does not own', ev(foreignRead));
    const del = await author.remove('posts', `id=eq.${ownDraftId}`);
    const survives = await admin.list('posts', `select=id&id=eq.${ownDraftId}`);
    rep.check(
      rowCount(survives) === 1 && (del.status === 204 || isReject(del)),
      'AU14 author-tier DELETE removes nothing (admins only)',
      `delete=${del.status} stillPresent=${rowCount(survives)}`
    );
  }

  if (ownDraftId) {
    // Read the draft pool BEFORE AU18 publishes it, otherwise the assertion
    // would be checking a state its own previous step changed.
    const authorReadAgain = await author.list('posts', `select=id,slug,status&status=eq.draft&site_id=eq.${siteId}`);
    const mineVisible = (authorReadAgain.rows || []).filter((p) => p.id === ownDraftId);
    const othersLeaked = (authorReadAgain.rows || []).filter((p) => p.id !== ownDraftId);
    rep.check(
      mineVisible.length === 1 && othersLeaked.length === 0,
      'AU16 author draft pool is exactly its own row',
      `mine=${mineVisible.length} others=${othersLeaked.length}`
    );
    const anonBefore = await anon.list('posts', `select=id&slug=eq.${ownDraftSlug}`);
    rep.check(anonBefore.ok && rowCount(anonBefore) === 0, 'AU17 the author draft is invisible to the public feed while it is a draft', ev(anonBefore));
  }

  if (ownDraftId) {
    const ownRevRead = await author.list('post_revisions', `select=id&post_id=eq.${ownDraftId}`);
    rep.check(ownRevRead.ok && rowCount(ownRevRead) >= 1, 'AU12b author reads back its own revision', ev(ownRevRead));
    const publishOwn = await author.update('posts', { status: 'published' }, `id=eq.${ownDraftId}&site_id=eq.${siteId}`);
    rep.check(
      publishOwn.ok && rowCount(publishOwn) === 1,
      'AU18 FINDING: author publish-by-update IS permitted by the database',
      `${ev(publishOwn)} — 003 posts_update_own_author (003:370-396) cannot compare old vs new status inside one ` +
        'permissive WITH CHECK, so only RolePermissions.canPublish (role_permissions.dart:42-45) stops an author ' +
        'publishing its own post. Defense-in-depth gap: the UI gate is load-bearing.'
    );
    const anonAfter = await anon.list('posts', `select=id&slug=eq.${ownDraftSlug}`);
    rep.check(anonAfter.ok && rowCount(anonAfter) === 1, 'AU19 and that transition is immediately public (the gap has a visible effect)', ev(anonAfter));
  }

  /* ---- R. plain reader: published/due only ---- */
  const readerIn = await signIn(byTier.reader_no_membership.email);
  rep.check(readerIn.ok && !!readerIn.accessToken, 'R1 reader sign-in yields a session', `status=${readerIn.status}`);
  const reader = readerIn.accessToken ? clientFor(readerIn.accessToken) : anon;
  const readerProf = await reader.list('profiles', 'select=id,role,is_active&limit=1');
  const readerProfile = readerProf.rows && readerProf.rows[0] ? readerProf.rows[0] : null;
  const readerMember = await reader.list('profile_sites', `select=role&site_id=eq.${siteId}`);
  rep.check(!!readerProfile && rowCount(readerMember) === 0, 'R2 reader has a profiles row and ZERO memberships', `role=${readerProfile && readerProfile.role} memberships=${rowCount(readerMember)}`);
  const readerGate = modelAdminGate(readerProfile, null);
  rep.check(
    readerGate.decision === 'OPEN_CMS' && readerGate.hasSiteAccess === false,
    'R3 gate model: no membership still opens the CMS shell (author tier, no site access)',
    `decision=${readerGate.decision} hasSiteAccess=${readerGate.hasSiteAccess} effective=${readerGate.effectiveRole} (middleware reads isLoggedIn only — see admin_auth_middleware.dart:17-25)`
  );
  const noProfileGate = modelAdminGate(null, null);
  rep.check(noProfileGate.decision === 'DENY_AND_SIGNOUT', 'R4 gate model: a missing profiles row is denied + force-signed-out', `admin_auth_controller.dart:161-166`);

  const readerPosts = await reader.list('posts', `select=id,status,scheduled_for&site_id=eq.${siteId}`);
  rep.check(readerPosts.ok && byStatus(readerPosts.rows, 'draft').length === 0, 'R5 reader sees NO drafts', ev(readerPosts));
  rep.check(byStatus(readerPosts.rows, 'archived').length === 0, 'R6 reader sees NO archived posts', `archived=${byStatus(readerPosts.rows, 'archived').length}`);
  const now = Date.now();
  const future = byStatus(readerPosts.rows, 'scheduled').filter((p) => p.scheduled_for && new Date(p.scheduled_for).getTime() > now);
  rep.check(future.length === 0, 'R7 reader sees NO not-yet-due scheduled posts', `future=${future.length}`);
  const dueScheduled = byStatus(readerPosts.rows, 'scheduled').filter((p) => p.scheduled_for && new Date(p.scheduled_for).getTime() <= now);
  rep.check(byStatus(readerPosts.rows, 'published').length > 0 && dueScheduled.length >= 1, 'R8 reader DOES see published + already-due scheduled', `published=${byStatus(readerPosts.rows, 'published').length} due=${dueScheduled.length}`);

  for (const table of ['subscribers', 'post_revisions', 'analytics_events', 'media']) {
    const r = await reader.list(table, 'select=id');
    rep.check(isReject(r) || (r.ok && rowCount(r) === 0), `R9 reader cannot enumerate ${table}`, ev(r));
  }
  const readerWrite = await reader.insert('posts', { site_id: siteId, slug: `${config.fixtureTag()}-reader`, title: 'zzz-check reader write', content: 'nope', status: 'published' });
  rep.check(isReject(readerWrite), 'R10 reader cannot write posts', ev(readerWrite));

  /* ---- X. cross-site: what a client-chosen site_id can actually buy ----
   * posts_select_public (003:342-346) carries NO site predicate, so published
   * rows of any site sharing a project are public by design. The boundary that
   * must hold is the PRIVATE one: a draft/archived/future-scheduled row of
   * another site may never reach another site's session. */
  const clientChosen = await author.list('posts', `select=id,slug,status,scheduled_for&site_id=eq.${travelId}`);
  const foreignPrivate = (clientChosen.rows || []).filter((p) => !isPublicRow(p));
  rep.check(
    clientChosen.ok && foreignPrivate.length === 0,
    'X1 a client-supplied foreign site_id can only ever return PUBLIC rows',
    `${ev(clientChosen)} private=${foreignPrivate.length} site=${TRAVEL_SLUG} (003:342 posts_select_public is not site-scoped; the app never sends a client-chosen id — see CTX/T rows)`
  );
  const tempLookup = await admin.list('sites', `select=id,slug&slug=eq.${TEMP_SLUG}`);
  const tempId = tempLookup.rows && tempLookup.rows[0] ? tempLookup.rows[0].id : null;
  rep.check(!!tempId, 'X1a the inactive sibling site is staff-visible (sites_select_public is is_active-only)', `slug=${TEMP_SLUG}`);
  if (tempId) {
    for (const [tier, client] of [['author', author], ['reader', reader], ['anon', anon]]) {
      const probe = await client.list('posts', `select=id,status,scheduled_for&site_id=eq.${tempId}`);
      const priv = (probe.rows || []).filter((p) => !isPublicRow(p));
      rep.check(probe.ok && priv.length === 0, `X1b.${tier} no private row of the other site is readable`, `${ev(probe)} private=${priv.length}`);
    }
    const staffForeign = await admin.list('posts', `select=id,status&site_id=eq.${tempId}&status=eq.draft`);
    rep.check(staffForeign.ok && rowCount(staffForeign) >= 1, 'X1c a super-admin session does see them (is_site_editor via the global role)', ev(staffForeign));
  }

  const editorIn = await signIn(byTier.site_admin.email);
  const editor = editorIn.accessToken ? clientFor(editorIn.accessToken) : admin;
  const editorPosts = await editor.list('posts', 'select=id,site_id');
  const foreignSeen = (editorPosts.rows || []).filter((p) => p.site_id !== siteId);
  rep.check(editorPosts.ok && foreignSeen.length === 0, 'X2 site-scoped staff reads ONLY its own site rows', `rows=${rowCount(editorPosts)} foreign=${foreignSeen.length}`);
  const crossWrite = await editor.insert('posts', { site_id: travelId, slug: `${config.fixtureTag()}-cross`, title: 'zzz-check cross-site write', content: 'nope', status: 'draft' });
  rep.check(isReject(crossWrite), 'X3 site-scoped staff cannot write into another site', ev(crossWrite));
  const crossReadDrafts = await editor.list('posts', `select=id&site_id=eq.${tempId}&status=eq.draft`);
  rep.check(crossReadDrafts.ok && rowCount(crossReadDrafts) === 0, 'X3b site-scoped staff cannot read another site\'s drafts either', ev(crossReadDrafts));
  const editorMediaUpload = await api.storageUpload(cfg, editorIn.accessToken || cfg.anonKey, 'media', `${SITE_SLUG}/zzz-check-editor.png`, 'image/png', api.tinyPng());
  rep.check(editorMediaUpload.ok, 'X4 staff media upload accepted by the storage policy', `status=${editorMediaUpload.status}`);
  const authorMediaUpload = await api.storageUpload(cfg, authorIn.accessToken || cfg.anonKey, 'media', `${SITE_SLUG}/zzz-check-author.png`, 'image/png', api.tinyPng());
  rep.check(!authorMediaUpload.ok, 'X5 author-tier media upload denied (is_site_editor gate, 003:449 + 004)', `status=${authorMediaUpload.status} "${String(authorMediaUpload.message).slice(0, 60)}"`);
  // Cleanup uses the super-admin session: 004 lets only a site editor/admin
  // delete an object, so the editor token above would leave the fixture behind.
  const objCleanup = await api.storageDelete(cfg, adminIn.accessToken, 'media', `${SITE_SLUG}/zzz-check-editor.png`);
  rep.check(objCleanup.ok, 'X6 throwaway media object deleted again', `status=${objCleanup.status} "${String(objCleanup.message).slice(0, 50)}"`);

  /* ---- cleanup registry: every tracked fixture row goes back out ---- */
  const cleaned = await admin.runCleanup();
  rep.check(
    cleaned.every((c) => c.ok) && cleaned.length >= 2,
    'H0 tracked fixtures are released',
    cleaned.map((c) => `${c.label}:${c.ok ? 'ok' : 'FAILED(' + String(c.detail).slice(0, 30) + ')'}`).join(' | ')
  );

  /* ---- H. fixture hygiene: no zzz-check residue in clean mode ---- */
  const residue = await admin.list('posts', 'select=id,slug');
  const left = (residue.rows || []).filter((p) => p.slug && p.slug.startsWith(config.PREFIX)).map((p) => p.slug);
  if (mode === 'leaky') {
    rep.info('H1 fixture residue', `left=${left.length} (expected: leaky denials do not fire, the emulator is discarded after the run)`);
  } else {
    rep.check(left.length === 0, 'H1 no zzz-check fixture survives the run', `left=${left.length} ${left.slice(0, 3).join(', ')}`);
  }

  staticPlane(rep);
  return { rep, mode, issuedSecrets, applied: true };
}

/* ------------------------------------------------------------------ *
 * STATIC plane: the login path proven against the real Dart sources
 * ------------------------------------------------------------------ */
function staticPlane(rep) {
  const loginView = read(SRC.loginView);
  const controller = read(SRC.authController);
  const authSvc = read(SRC.authService);
  const middleware = read(SRC.middleware);
  const siteContext = read(SRC.siteContext);
  const siteConfig = read(SRC.siteConfig);
  const profileRepo = read(SRC.profileRepo);
  const scaffold = read(SRC.scaffold);
  const pages = read(SRC.appPages);
  const binding = read(SRC.initialBinding);
  const rolePerms = read(SRC.rolePermissions);

  const check = (cond, name, evidence) => rep.check(cond, `T ${name}`, evidence);

  check(/onPressed:\s*controller\.isLoading\.value\s*\?\s*null\s*:\s*controller\.login/.test(loginView), 'AdminLoginView submits through controller.login', 'admin_login_view.dart:113');
  check(/await auth\.signIn\(email, password\)/.test(controller), 'controller.login calls AuthService.signIn', 'admin_auth_controller.dart:90');
  check(/await _client\.auth\.signInWithPassword/.test(authSvc), 'AuthService.signIn is the real password grant', 'auth_service.dart:22');
  check(/final loaded = await _loadProfile\(\);/.test(controller) && /Get\.offNamed\('\/admin\/dashboard'\)/.test(controller), 'dashboard route is entered only after the profile load', 'admin_auth_controller.dart:91-93');
  check(/if \(loaded == null \|\| !loaded\.isActive\)/.test(controller), 'missing/inactive profile forces sign-out', 'admin_auth_controller.dart:161');
  check(/from\('profiles'\)\s*\.select\(\)/.test(profileRepo) && /\.eq\('id', user\.id\)/.test(profileRepo), 'profile read is keyed to auth.uid() server-side', 'supabase_profile_repository.dart:32-36');
  check(/\.eq\('site_id', siteId\)/.test(profileRepo), 'membership read is scoped to the server-resolved site', 'supabase_profile_repository.dart:46-47');

  check(/if \(!auth\.isLoggedIn\.value\)/.test(middleware), 'middleware checks the session flag only', 'admin_auth_middleware.dart:17');
  check(!/hasSiteAccess/.test(middleware), 'FINDING: middleware never checks hasSiteAccess', 'admin_auth_middleware.dart has no hasSiteAccess reference — a member-less login still renders the CMS shell');
  check(/current != null && !current\.isActive/.test(middleware), 'middleware bounces a deactivated profile', 'admin_auth_middleware.dart:23');

  check(/\.eq\('slug', SiteConfig\.siteId\)/.test(siteContext), 'SiteContext resolves the site id from the server by slug', 'site_context.dart:30');
  check(/static const String siteId = 'india_tech';/.test(siteConfig), 'active site is a compile-time const (no URL/param override)', 'site_config.dart:4');
  check(!/Get\.parameters|Get\.arguments|queryParameters/.test(siteContext), 'no client state feeds the site resolution', 'site_context.dart carries no route-parameter reads');

  check(/Future<void> logout\(\)/.test(controller) && /await _auth\?\.signOut\(\)/.test(controller), 'logout() does call the network sign-out', 'admin_auth_controller.dart:103-110');
  const scaffoldLogsOut = /onTap:\s*\(\)\s*=>\s*controller\.logout|auth\.logout\(\)|controller\.logout\(\)/.test(scaffold);
  check(
    !scaffoldLogsOut && /onTap: \(\) => Get\.offAllNamed\('\/admin\/login'\)/.test(scaffold),
    'FINDING: the sidebar Logout only NAVIGATES (no signOut call)',
    'admin_scaffold.dart:235 — the persisted session survives "logout"; AdminAuthController.logout() has no call site in lib/'
  );
  check(/void _reset\(\)/.test(controller) && !/articles\.clear\(\)|SiteContext.*reset/.test(controller), 'FINDING: _reset() clears session flags only, not cached site/post state', 'admin_auth_controller.dart:182-186 — AdminArticleController.articles and SiteContext._siteId survive');

  const pageChunks = pages.split('GetPage(').slice(1);
  const adminChunks = pageChunks.filter((chunk) => /name:\s*AppRoutes\.admin(?!Login\b)/.test(chunk));
  const unguarded = adminChunks
    .filter((chunk) => !/middlewares:\s*\[[^\]]*AdminAuthMiddleware/.test(chunk))
    .map((chunk) => (chunk.match(/name:\s*AppRoutes\.(\w+)/) || [])[1] || 'unnamed-route');
  check(
    adminChunks.length >= 5 && unguarded.length === 0,
    'every admin route carries AdminAuthMiddleware',
    unguarded.length
      ? `UNGUARDED: ${unguarded.join(', ')}`
      : `${adminChunks.length} admin routes declared, all with AdminAuthMiddleware (app_pages.dart:221-…)`
  );

  check(/Get\.put<ProfileRepository>\(profiles, permanent: true\)/.test(binding), 'CMS uses SupabaseProfileRepository when the backend is live', 'initial_binding.dart:72-73');
  check(/Get\.put<PostAdminRepository>[\s\S]{0,80}SupabasePostAdminRepository/.test(binding), 'CMS uses SupabasePostAdminRepository', 'initial_binding.dart:74-75');
  check(/unawaited\(Get\.find<AdminAuthController>\(\)\.restoreSession\(\)\)/.test(binding), 'cold-boot restore runs unawaited (routing trusts the persisted session)', 'initial_binding.dart:125');
  check(/static bool canPublish\(AdminRole role\)/.test(rolePerms) && /role == AdminRole\.editor/.test(rolePerms), 'author tier cannot publish in the UI layer', 'role_permissions.dart:42-45');
}

/* ------------------------------------------------------------------ *
 * driver
 * ------------------------------------------------------------------ */
async function runMode(mode) {
  const started = await startMock(mode);
  try {
    const out = await runFlow(mode, started.base);

    // Hygiene plane: print once into a buffer, then scan that exact buffer for
    // any token/password this run issued. The scan runs BEFORE anything is
    // echoed, and the echoed text is redacted a second time as a backstop.
    const draft = capturePrint(() => out.rep.print());
    const leaks = issuedIn(draft);
    out.rep.check(leaks.length === 0, 'G1 no session token or password value reaches stdout', `scanned=${ISSUED_SECRETS.length} issued values, leaks=${leaks.length}`);
    const finalText = config.redact(capturePrint(() => out.rep.print()), ISSUED_SECRETS);
    process.stdout.write(finalText);

    const counts = countStatuses(finalText);
    const staticFail = out.rep.rows.filter((r) => r.status === 'FAIL' && r.name.startsWith('T ')).length;
    return {
      mode,
      counts,
      staticFail,
      dbFail: counts.FAIL - staticFail,
      leaked: leaks.length,
      rep: out.rep,
      applied: out.applied,
    };
  } finally {
    try {
      started.child.kill();
    } catch {}
  }
}

function issuedIn(text) {
  return ISSUED_SECRETS.filter((s) => s && String(s).length >= config.MIN_REDACT_LEN && String(text).includes(String(s)));
}

function countStatuses(text) {
  const out = { PASS: 0, FAIL: 0, SKIP: 0, INFO: 0 };
  for (const line of String(text).split(/\r?\n/)) {
    const m = line.match(/^(PASS|FAIL|SKIP|INFO)\s*\|/);
    if (m) out[m[1]]++;
  }
  return out;
}

async function main() {
  const args = process.argv.slice(2);
  const modeArgIdx = args.indexOf('--mode');
  const explicit = modeArgIdx >= 0 ? args[modeArgIdx + 1] : null;
  const single = args.find((a) => a.startsWith('--mode='));
  const requested = explicit || (single ? single.split('=')[1] : null);
  if (requested && !MODES.includes(requested)) {
    process.stderr.write(`unknown --mode '${requested}' (clean|empty|leaky)\n`);
    process.exitCode = 2;
    return;
  }
  const modes = requested ? [requested] : MODES;

  process.stdout.write('================================================================\n');
  process.stdout.write(' Bharat Tech Pulse — admin CMS flow against the MOCK Supabase\n');
  process.stdout.write(' (127.0.0.1 emulator, fake rows, ZERO live credentials required)\n');
  process.stdout.write('================================================================\n');
  process.stdout.write(
    `\nCredential intake status for THIS run:\n${config.credentialSummary(config.load({ required: false }))}\n` +
      `(presence/length/fingerprint only — no value is read from anywhere else,\n` +
      ' and none is needed: this flow runs entirely against the local emulator.)\n'
  );

  const results = [];
  for (const mode of modes) {
    process.stdout.write(`\n########## MOCK_MODE=${mode} ##########\n`);
    results.push(await runMode(mode));
  }

  let bad = 0;
  process.stdout.write('\n================ AGGREGATE (admin_flow_mock) ================\n');
  for (const r of results) {
    process.stdout.write(
      `MOCK_MODE=${r.mode.padEnd(6)} PASS=${String(r.counts.PASS).padEnd(4)} FAIL=${String(r.counts.FAIL).padEnd(4)} ` +
        `(DB=${r.dbFail} static=${r.staticFail}) SKIP=${String(r.counts.SKIP).padEnd(4)} INFO=${r.counts.INFO} ` +
        `secret-leaks=${r.leaked}\n`
    );
    if (r.leaked > 0) {
      process.stdout.write(`FAIL: ${r.mode} run echoed a token/password VALUE into its own report.\n`);
      bad++;
    }
  }
  for (const r of results) {
    if (r.mode === 'clean') {
      if (r.counts.FAIL > 0) {
        const which = r.rep.rows
          .filter((row) => row.status === 'FAIL')
          .map((row) => row.name)
          .slice(0, 6)
          .join('; ');
        process.stdout.write(`\nFAIL: clean mock run reported ${r.counts.FAIL} failed assertion(s): ${which}\n`);
        bad++;
      } else if (r.counts.PASS < 20) {
        process.stdout.write(`\nFAIL: clean run only asserted ${r.counts.PASS} conditions — too few to be meaningful.\n`);
        bad++;
      } else {
        process.stdout.write(`\nOK: clean mock run passes ${r.counts.PASS} assertions (real sign-in, real RLS semantics, no credentials).\n`);
      }
    }
    if (r.mode === 'empty') {
      // The static plane reads Dart sources, not the database, so its verdict is
      // independent of emulator state and must never be scored as "the empty
      // mock failed to degrade honestly".
      if (r.dbFail > 0) {
        process.stdout.write(`\nFAIL: empty mock must degrade to SKIP, got ${r.dbFail} DB FAIL rows.\n`);
        bad++;
      } else if (r.staticFail > 0) {
        process.stdout.write(`\nOK: empty mock degraded to NOT APPLIED YET (${r.staticFail} static finding(s) still FAIL — see the T rows).\n`);
      } else {
        process.stdout.write('\nOK: empty mock degrades to NOT APPLIED YET without inventing a pass.\n');
      }
    }
    if (r.mode === 'leaky') {
      if (r.dbFail === 0) {
        process.stdout.write('\nFAIL: leaky mock reported no DB failure — the clean-mode assertions are VACUOUS.\n');
        bad++;
      } else {
        process.stdout.write(`\nOK: leaky mock failed ${r.dbFail} DB assertion(s) — the clean-mode PASS is not vacuous.\n`);
      }
    }
  }
  process.stdout.write(
    '\nSCOPE NOTE — MOCK-VERIFIED: sign-in grant, the profiles/profile_sites gate,\n' +
      'SiteContext resolution, draft/visibility rules, the create->edit->revision->\n' +
      'publish lifecycle, author-tier denials and reader public-only reads, against a\n' +
      'local emulator whose rules were transcribed from 002/003. NOT verified here:\n' +
      'that admin@gmail.com exists, that its password is correct, that GoTrue accepts\n' +
      'it, real RLS on the live project, and any Dart widget execution — those stay\n' +
      'BLOCKED for the operator runbook (see the report from auth-admin-qa).\n'
  );
  process.exitCode = bad ? 1 : 0;
}

main().catch((e) => {
  process.stderr.write('admin_flow_mock.js crashed: ' + config.redact((e && (e.stack || e.message)) || String(e), ISSUED_SECRETS) + '\n');
  process.exitCode = 1;
});
