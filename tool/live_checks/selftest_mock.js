#!/usr/bin/env node
'use strict';
/**
 * tool/live_checks/selftest_mock.js  (LOCAL ONLY — 127.0.0.1, fake data)
 *
 * A miniature PostgREST + GoTrue + Storage emulator used to self-test the live
 * check scripts on a machine that has no Supabase credentials (the remote
 * project is still empty). It proves two things that a report reader cannot
 * take on trust:
 *   1. the suites degrade gracefully and say "NOT APPLIED YET" when there are
 *      0 tables (MOCK_MODE=empty)
 *   2. the suites actually FAIL when a policy is broken (MOCK_MODE=leaky),
 *      i.e. the PASS results in MOCK_MODE=clean are not vacuous.
 *
 * The tokens here are literal placeholder strings, not credentials. Nothing
 * talks to the internet in this mode.
 *
 * Usage:
 *   MOCK_MODE=empty|clean|leaky PORT=54321 node tool/live_checks/selftest_mock.js
 */

const http = require('http');

const MODE = process.env.MOCK_MODE || 'clean';
const PORT = Number(process.env.PORT || 54321);
const SITE = '00000000-0000-4000-8000-000000000001';
const SITE2 = '00000000-0000-4000-8000-000000000002';
const SITE3 = '00000000-0000-4000-8000-000000000003';
const FUTURE = new Date(Date.now() + 30 * 864e5).toISOString();
const PAST = new Date(Date.now() - 864e5).toISOString();

const db = {
  sites: [
    { id: SITE, slug: 'india_tech', name: 'Bharat Tech Pulse', is_active: true },
    { id: SITE2, slug: 'zzz-check-temp-site', name: 'zzz-check temp', is_active: false },
    { id: SITE3, slug: 'go-travel-pulse', name: 'Travel sibling', is_active: true },
  ],
  site_settings: [{ id: '00000000-0000-4000-8000-000000000060', site_id: SITE, site_name: 'Bharat Tech Pulse' }],
  categories: Array.from({ length: 8 }, (_, i) => ({
    id: `00000000-0000-4000-8000-0000000001${String(i + 1).padStart(2, '0')}`,
    site_id: SITE, slug: ['ai', 'smartphones', 'how-to', 'apps', 'cyber-safety', 'gaming', 'reviews', 'internet'][i],
    name: `cat ${i}`, is_active: true,
  })).concat([
    {
      id: '00000000-0000-4000-8000-000000000109',
      site_id: SITE, slug: 'retired-category', name: 'retired', is_active: false,
    },
  ]),
  authors: Array.from({ length: 4 }, (_, i) => ({
    id: `00000000-0000-4000-8000-0000000002${String(i + 1).padStart(2, '0')}`,
    site_id: SITE, slug: `author-${i}`, name: `Author ${i}`, is_active: true,
  })),
  tags: Array.from({ length: 24 }, (_, i) => ({
    id: `00000000-0000-4000-8000-0000000003${String(i + 1).padStart(2, '0')}`,
    site_id: SITE, slug: `tag-${i}`, name: `Tag ${i}`,
  })),
  posts: [
    { id: 'p1', site_id: SITE, slug: 'choose-right-ai-tool-honest-framework', status: 'published', category_id: null, author_id: null, scheduled_for: null, published_at: PAST, title: 'pub 1' },
    { id: 'p2', site_id: SITE, slug: 'second-published', status: 'published', category_id: null, author_id: null, scheduled_for: null, published_at: PAST, title: 'pub 2' },
    ...Array.from({ length: 12 }, (_, i) => ({
      id: `p${i + 3}`, site_id: SITE, slug: `published-${i + 3}`, status: 'published',
      category_id: `00000000-0000-4000-8000-000000000101`, author_id: `00000000-0000-4000-8000-000000000201`,
      scheduled_for: null, published_at: PAST, title: `pub ${i + 3}`,
    })),
    { id: 'd1', site_id: SITE, slug: 'budget-vs-premium-phone-features-worth-it', status: 'draft', scheduled_for: null, published_at: null, title: 'draft 1' },
    { id: 'd2', site_id: SITE, slug: 'weekend-app-audit-indian-families', status: 'draft', scheduled_for: null, published_at: null, title: 'draft 2' },
    { id: 'd3', site_id: SITE, slug: 'new-phone-first-week-checklist', status: 'draft', scheduled_for: null, published_at: null, title: 'draft 3' },
    { id: 'd4', site_id: SITE, slug: 'passwords-passkeys-parents-transition-guide', status: 'draft', scheduled_for: null, published_at: null, title: 'draft 4' },
    { id: 'a1', site_id: SITE, slug: 'offline-first-apps-worth-installing', status: 'archived', scheduled_for: null, published_at: PAST, title: 'arch 1' },
    { id: 'a2', site_id: SITE, slug: 'festival-gadget-shopping-old-habits', status: 'archived', scheduled_for: null, published_at: PAST, title: 'arch 2' },
    { id: 's1', site_id: SITE, slug: 'home-study-ai-routine-indian-families', status: 'scheduled', scheduled_for: FUTURE, published_at: null, title: 'sch 1' },
    { id: 's2', site_id: SITE, slug: 'why-chip-news-matters-semiconductors-daily-life', status: 'scheduled', scheduled_for: FUTURE, published_at: null, title: 'sch 2' },
    { id: 's3', site_id: SITE, slug: 'prepaid-vs-postpaid-how-to-choose', status: 'scheduled', scheduled_for: FUTURE, published_at: null, title: 'sch 3' },
    { id: 's4', site_id: SITE, slug: 'already-due-scheduled', status: 'scheduled', scheduled_for: PAST, published_at: null, title: 'due 1' },
  ],
  post_tags: (() => {
    const published = ['p1', 'p2', ...Array.from({ length: 12 }, (_, i) => `p${i + 3}`)];
    const out = [];
    published.forEach((pid, i) => {
      out.push({ post_id: pid, tag_id: `00000000-0000-4000-8000-0000000003${String((i % 24) + 1).padStart(2, '0')}` });
      out.push({ post_id: pid, tag_id: `00000000-0000-4000-8000-0000000003${String(((i + 7) % 24) + 1).padStart(2, '0')}` });
    });
    out.push({ post_id: 'd1', tag_id: '00000000-0000-4000-8000-000000000301' }); // draft-only link
    return out;
  })(),
  media: Array.from({ length: 6 }, (_, i) => ({
    id: `00000000-0000-4000-8000-0000000005${String(i + 1).padStart(2, '0')}`,
    site_id: SITE, file_name: `m${i}.png`, storage_path: `india_tech/m${i}.png`,
  })),
  post_revisions: Array.from({ length: 5 }, (_, i) => ({
    id: `00000000-0000-4000-8000-0000000006${String(i + 1).padStart(2, '0')}`,
    post_id: 'p1', revision_number: i + 1,
  })),
  redirects: Array.from({ length: 3 }, (_, i) => ({
    id: `00000000-0000-4000-8000-0000000007${String(i + 1).padStart(2, '0')}`,
    site_id: SITE, old_path: `/old-${i}`, new_path: `/new-${i}`, status_code: 301,
  })),
  subscribers: Array.from({ length: 6 }, (_, i) => ({
    id: `00000000-0000-4000-8000-0000000008${String(i + 1).padStart(2, '0')}`,
    site_id: SITE, email: `reader${i}@example.com`, is_verified: false, is_active: true, unsubscribed_at: null,
  })),
  analytics_events: Array.from({ length: 40 }, (_, i) => ({
    id: `00000000-0000-4000-8000-0000000009${String(i + 1).padStart(2, '0')}`,
    site_id: SITE, event_type: i % 3 === 0 ? 'page_view' : 'article_view', session_id: `seed-${i}`, post_id: 'p1',
  })),
  profiles: [
    { id: 'admin-profile-id', role: 'super_admin', email: 'owner@example.com' },
    { id: 'reader-profile-id', role: 'author', email: 'zzz-check-reader@example.com' },
    { id: 'siteadmin-profile-id', role: 'author', email: 'site-admin@example.com' },
  ],
  profile_sites: [
    { profile_id: 'admin-profile-id', site_id: SITE, role: 'admin', is_active: true },
    { profile_id: 'siteadmin-profile-id', site_id: SITE, role: 'admin', is_active: true },
  ],
};

db.posts.push(
  { id: 't1', site_id: SITE2, slug: 'temp-site-draft', status: 'draft', scheduled_for: null, published_at: null, title: 'temp site draft' },
  { id: 't2', site_id: SITE2, slug: 'temp-site-published', status: 'published', scheduled_for: null, published_at: PAST, title: 'temp site published' },
  { id: 'g1', site_id: SITE3, slug: 'travel-site-post', status: 'published', scheduled_for: null, published_at: PAST, title: 'travel sibling post (never a write target)' }
);
db.post_tags.push(
  { post_id: 't2', tag_id: '00000000-0000-4000-8000-000000000301' },
  { post_id: 'g1', tag_id: '00000000-0000-4000-8000-000000000302' }
);

const storage = new Map();
const ADMIN_T = 'mock-admin-token';
const READER_T = 'mock-reader-token';
const SITE_ADMIN_T = 'mock-site-admin-token';

function roleOf(req) {
  const a = String(req.headers.authorization || '');
  if (a.includes(ADMIN_T)) return 'admin';
  if (a.includes(SITE_ADMIN_T)) return 'siteadmin';
  if (a.includes(READER_T)) return 'reader';
  return 'anon';
}
const pubVisible = (p) => p.status === 'published' || (p.status === 'scheduled' && p.scheduled_for && new Date(p.scheduled_for) <= new Date());
const publicPostIds = () => new Set(db.posts.filter(pubVisible).map((p) => p.id));

function select(table, role) {
  const rows = db[table] || [];
  const LEAK = MODE === 'leaky';
  const staffOfSite1 = (r) => r.site_id === SITE;
  switch (table) {
    case 'posts':
      if (role === 'admin') return rows;
      if (role === 'siteadmin') return rows.filter(staffOfSite1);
      return LEAK && role === 'reader' ? rows : rows.filter((p) => pubVisible(p) || (LEAK && p.status === 'draft' && role === 'anon'));
    case 'categories':
    case 'authors':
      return role === 'admin' || role === 'siteadmin' ? rows : rows.filter((r) => r.is_active);
    case 'post_tags': {
      const ok = publicPostIds();
      return rows.filter((r) => ok.has(r.post_id) || (LEAK && role !== 'admin' && r.post_id === 'd1'));
    }
    case 'profiles':
      if (role === 'admin') return rows;
      if (role === 'reader') return [rows.find((p) => p.id === 'reader-profile-id')].filter(Boolean);
      if (role === 'siteadmin') return [rows.find((p) => p.id === 'siteadmin-profile-id')].filter(Boolean);
      return LEAK ? rows : [];
    case 'profile_sites':
      if (role === 'admin') return rows;
      return role === 'siteadmin' ? rows.filter((r) => r.profile_id === 'siteadmin-profile-id') : [];
    case 'subscribers':
    case 'post_revisions':
    case 'analytics_events':
      return role === 'admin' || role === 'siteadmin' ? rows : [];
    case 'sites':
      return rows.filter((s) => s.is_active || role === 'admin' || role === 'siteadmin');
    default:
      return rows;
  }
}

const WRITE_ALLOWED_FOR_ANON = new Set(['subscribers', 'analytics_events']);

function checkWith(table, body, role) {
  if (role === 'anon' && !WRITE_ALLOWED_FOR_ANON.has(table)) return 'no anon insert policy';
  if ((table === 'profiles' || table === 'profile_sites' || table === 'sites') && role !== 'anon') return `${table} has no INSERT policy (operator SQL only)`;
  if (table === 'subscribers') {
    if (!/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(String(body.email || ''))) return 'email regex WITH CHECK';
    if (body.is_verified === true) return 'is_verified must stay false';
    if (body.is_active === false) return 'is_active must stay true';
    if (body.unsubscribed_at) return 'unsubscribed_at must stay null';
    return null;
  }
  if (table === 'analytics_events') {
    if (!['page_view', 'article_view'].includes(body.event_type)) return 'event_type whitelist';
    return null;
  }
  if (role === 'reader') return 'reader has no membership -> no write policy matches';
  if (table === 'posts' && role === 'admin') return null;
  // site-scoped staff: editor of india_tech ONLY (cross-site writes denied)
  if (table === 'posts' && role === 'siteadmin') {
    return body.site_id === SITE ? null : `is_site_editor(${body.site_id}) is false for this profile`;
  }
  if (role !== 'admin') return 'no policy matches';
  return null;
}

function send(res, status, body, headers = {}) {
  const h = { 'Content-Type': 'application/json', ...headers };
  res.writeHead(status, h);
  res.end(body === undefined ? '' : typeof body === 'string' ? body : JSON.stringify(body));
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const role = roleOf(req);
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const raw = Buffer.concat(chunks);
  let body = {};
  try {
    body = raw.length ? JSON.parse(raw.toString()) : {};
  } catch {
    body = raw.length ? { _bytes: raw.length } : {};
  }

  if (url.pathname.startsWith('/rest/v1/')) {
    const table = url.pathname.slice('/rest/v1/'.length).split('?')[0];
    if (MODE === 'empty') {
      return send(res, 404, {
        message: `Could not find the table public.${table} in the schema cache`,
        code: 'PGRST205',
        hint: null,
      });
    }
    if (!db[table]) return send(res, 404, { message: `relation public.${table} does not exist`, code: '42P01' });

    const q = url.searchParams;
    const filters = [];
    for (const [k, v] of q.entries()) if (!['select', 'limit', 'offset', 'order'].includes(k)) filters.push([k, v]);
    const match = (row) =>
      filters.every(([k, v]) => {
        const [op, val] = [v.slice(0, 2), v.slice(3)];
        if (op === 'eq') return String(row[k]) === val;
        if (op === 'gt') return new Date(row[k]) > new Date(val);
        if (op === 'neq') return String(row[k]) !== val;
        if (v.startsWith('in.')) {
          const list = v.slice(4, -1).split(',');
          return list.includes(String(row[k]));
        }
        return true;
      });

    if (req.method === 'GET' || req.method === 'HEAD') {
      let rows = select(table, role).filter(match);
      const total = rows.length;
      const lim = Number(q.get('limit') || 1000);
      rows = rows.slice(0, Number.isNaN(lim) ? 1000 : lim);
      const cr = total === 0 ? '*/0' : `0-${Math.min(rows.length, total) - 1}/${total}`;
      return send(res, 200, rows, { 'content-range': cr });
    }

    if (req.method === 'POST') {
      const reject = checkWith(table, body, role);
      if (MODE === 'leaky' && table === 'posts' && role === 'anon') {
        db.posts.push({ ...body, id: 'leak-post' });
        return send(res, 201, [{ id: 'leak-post' }]);
      }
      if (reject) {
        return send(res, 403, { code: '42501', message: `new row violates row-level security policy for table "${table}" (${reject})`, details: null, hint: null });
      }
      const id = `${table}-new-${db[table].length + 1}`;
      const row = { id, ...(Array.isArray(body) ? body[0] : body) };
      db[table].push(row);
      return send(res, 201, [row], { 'content-range': `0-0/1` });
    }

    if (req.method === 'PATCH') {
      if (table === 'profiles' || table === 'profile_sites') {
        return send(res, 403, { code: '42501', message: `permission denied (no UPDATE policy on ${table})` });
      }
      if (role === 'anon' || (role === 'reader' && !(MODE === 'leaky' && table === 'posts'))) {
        return send(res, 403, { code: '42501', message: 'permission denied for update' });
      }
      const hits = db[table].filter(match).map((r) => Object.assign(r, body));
      return send(res, 200, hits, { 'content-range': `0-${Math.max(hits.length, 1) - 1}/${hits.length}` });
    }

    if (req.method === 'DELETE') {
      if (role === 'anon' || role === 'reader') {
        return send(res, 204, undefined, { 'content-range': '*/0' });
      }
      const keep = db[table].filter((r) => !match(r));
      const removed = db[table].length - keep.length;
      db[table] = keep;
      return send(res, 204, undefined, { 'content-range': `0-${Math.max(removed, 1) - 1}/${removed}` });
    }
    return send(res, 405, { message: 'method not allowed' });
  }

  /* ---- storage (real Supabase layout: /object/{public|sign}/{bucket}/{path}) ---- */
  if (url.pathname.startsWith('/storage/v1/object/sign/')) {
    const rest = url.pathname.slice('/storage/v1/object/sign/'.length); // media/<path>
    const path = decodeURIComponent(rest.replace(/^media\//, '').split('?')[0]);
    if (req.method === 'POST') {
      if (role !== 'admin') return send(res, 400, { message: 'invalid token' });
      return send(res, 200, { signedURL: `/object/sign/media/${path}?token=sig-${role}` });
    }
    const token = url.searchParams.get('token');
    if (!token) return send(res, 400, { message: 'invalid token' });
    if (storage.has(path)) {
      const buf = storage.get(path);
      res.writeHead(200, { 'Content-Type': 'image/png', 'Content-Length': buf.length });
      return res.end(buf);
    }
    return send(res, 404, { error: 'Not Found' });
  }
  if (url.pathname.startsWith('/storage/v1/object/public/')) {
    const path = decodeURIComponent(url.pathname.slice('/storage/v1/object/public/media/'.length));
    const seeded = /^india_tech\/m\d\.png$/.test(path);
    if (storage.has(path) || seeded) {
      const buf = storage.get(path) || Buffer.from('fake-seeded-png-bytes');
      res.writeHead(200, { 'Content-Type': 'image/png', 'Content-Length': buf.length });
      return res.end(buf);
    }
    return send(res, 400, { error: 'Object Not Found' });
  }
  if (url.pathname.startsWith('/storage/v1/object/')) {
    const rest = url.pathname.slice('/storage/v1/object/'.length);
    const idx = rest.indexOf('/');
    const path = decodeURIComponent(rest.slice(idx + 1));
    if (req.method === 'POST') {
      const folder = path.split('/')[0];
      if (role === 'anon') return send(res, 400, { statusCode: '401', message: 'Unauthorized: invalid key or no policy' });
      if (role === 'reader') return send(res, 400, { statusCode: '403', message: 'The resource is already not exists (policy: media_site_editor_insert)' });
      if (folder !== 'india_tech') return send(res, 400, { statusCode: '403', message: 'new row violates row-level security policy' });
      storage.set(path, raw);
      return send(res, 200, { Key: path, Id: 'obj-' + path });
    }
    if (req.method === 'DELETE') {
      if (role !== 'admin') return send(res, 400, { statusCode: '403', message: 'policy violation' });
      storage.delete(path);
      return send(res, 200, [{ Name: path.split('/').pop() }]);
    }
  }

  /* ---- auth ---- */
  if (url.pathname === '/auth/v1/signup' && req.method === 'POST') {
    if (MODE === 'leaky') return send(res, 200, { id: 'reader-profile-id', access_token: READER_T });
    return send(res, 422, { error_description: 'Signups not allowed for this project' });
  }
  if (url.pathname === '/auth/v1/token' && req.method === 'POST') {
    return send(res, 400, { error_description: 'Invalid Login Credentials' });
  }

  return send(res, 404, { message: 'not found' });
});

/* ============================ mode dispatcher ============================
 *  `node selftest_mock.js`            -> self-verifying test; EXITS 0 or 1.
 *  `node selftest_mock.js --serve`    -> legacy behaviour: keep a mock server
 *                                         alive for manual suite runs.
 *  (the dispatcher itself sits at the bottom of this file, after every const) */

/* ---------------------------- self-test harness ------------------------- */

const path = require('path');
const { spawn, spawnSync } = require('child_process');
const configMod = require('./lib/config');
const apiMod = require('./lib/api');

const tally = { pass: 0, fail: 0 };
function assertTrue(cond, label) {
  if (cond) {
    tally.pass++;
    process.stdout.write('  ok   ' + label + '\n');
  } else {
    tally.fail++;
    process.stdout.write('  FAIL ' + label + '\n');
  }
}

async function expectThrow(promiseFactory, label) {
  try {
    await promiseFactory();
    assertTrue(false, label + ' (did NOT throw)');
  } catch (e) {
    assertTrue(/SAFETY BLOCK/.test(e.message), label + ` — '${e.message.slice(0, 40)}...'`);
  }
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

async function withMock(mode, fn) {
  const child = spawn(process.execPath, [__filename, '--serve'], {
    env: { ...process.env, MOCK_MODE: mode, PORT: '0' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let killed = false;
  const stop = () => {
    if (!killed) {
      killed = true;
      try { child.kill(); } catch {}
    }
  };
  try {
    const base = await new Promise((resolve, reject) => {
      let buf = '';
      const timer = setTimeout(() => reject(new Error(`mock(${mode}) did not start within 30s: ${buf}`)), 30000);
      child.stdout.on('data', (d) => {
        buf += String(d);
        const m = buf.match(/listening on (http:\/\/127\.0\.0\.1:\d+)/);
        if (m) {
          clearTimeout(timer);
          resolve(m[1]);
        }
      });
      child.on('exit', (code) => {
        clearTimeout(timer);
        reject(new Error(`mock(${mode}) exited early code=${code}: ${buf}`));
      });
    });
    return await fn(base);
  } finally {
    stop();
  }
}

function runScript(script, base, tokens) {
  const env = { ...process.env };
  for (const k of [
    'SUPABASE_URL', 'SUPABASE_PROJECT_URL', 'SUPABASE_ANON_KEY', 'SUPABABLE_ANON_KEY',
    'SUPABASE_PUBLISHABLE_KEY', 'SUPABASE_ADMIN_TOKEN', 'RLS_ADMIN_ACCESS_TOKEN',
    'SUPABASE_READER_TOKEN', 'RLS_READER_ACCESS_TOKEN', 'SUPABASE_SITE_ADMIN_TOKEN',
    'RLS_SITE_ADMIN_TOKEN', 'CHECK_SECOND_SITE_SLUG', 'SECOND_SITE_SLUG',
    'CHECK_ADMIN_SITE_SLUG', 'MOCK_MODE', 'PORT', 'ALLOW_THROWAWAY_SIGNUP',
  ]) delete env[k];
  env.SUPABASE_URL = base;
  env.SUPABASE_ANON_KEY = 'mock-anon-key';
  if (tokens) {
    env.SUPABASE_ADMIN_TOKEN = ADMIN_T;
    env.SUPABASE_READER_TOKEN = READER_T;
  }
  const r = spawnSync(process.execPath, [path.join(__dirname, script)], {
    env,
    encoding: 'utf8',
    timeout: 120000,
  });
  return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}

async function runSelfTest() {
  process.stdout.write('selftest_mock.js — offline self-verification (127.0.0.1 mock only)\n');

  /* [1] in-process guard + reporter unit tests: zero network of any kind. */
  process.stdout.write('\n[1] guard rails + reporter masking (no server, no network)\n');
  let threw = false;
  try {
    configMod.assertWritableSiteSlug('india_travel', 'unit probe');
  } catch {
    threw = true;
  }
  assertTrue(threw, "assertWritableSiteSlug('india_travel') throws (travel site hard-blocked)");
  assertTrue(
    configMod.isWritableSiteSlug('india_tech') &&
      configMod.isWritableSiteSlug('zzz-check-temp') &&
      !configMod.isWritableSiteSlug('india_travel') &&
      !configMod.isWritableSiteSlug('India_Tech') &&
      !configMod.isTempCheckSiteSlug('india_tech') &&
      configMod.isTempCheckSiteSlug('zzz-check-temp') &&
      !configMod.isTempCheckSiteSlug('go-travel-pulse'),
    'slug allow/block matrix (india_tech ok, zzz-check* ok, travel + case variants blocked)'
  );
  const fakeCfg = { url: 'http://127.0.0.1:1', anonKey: 'unit-anon-key-0123456789', secrets: [] };
  const cli = new apiMod.Api(fakeCfg);
  await expectThrow(
    () => cli.rest('posts', { method: 'DELETE', query: 'status=eq.draft' }),
    'DELETE with a non-exact filter is blocked before any request'
  );
  await expectThrow(
    () => cli.rest('posts', { method: 'DELETE', query: '' }),
    'DELETE with no filter at all is blocked before any request'
  );
  const netless = await cli.rest('posts', { method: 'DELETE', query: 'id=eq.p1' });
  assertTrue(
    netless.status === 0 && netless.networkError === true,
    'DELETE with id=eq.<x> passes the rail and degrades to a caught network error (no crash)'
  );
  let ctorThrew = false;
  try {
    new apiMod.Api({ url: '', anonKey: null });
  } catch {
    ctorThrew = true;
  }
  assertTrue(ctorThrew, 'Api refuses to build when URL/anon key are unresolved (no Bearer undefined)');
  const secret = 'unitsecretvalue123456789';
  const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.dummy-signature-abcdef';
  const printed = capturePrint(() => {
    const r2 = new apiMod.Report('unit report', [secret]);
    r2.fail('leaky row', `token ${secret} and ${jwt}`);
    r2.print();
  });
  assertTrue(
    !printed.includes(secret) && !printed.includes(jwt) && /\[secret sha256:|sha256:/.test(printed),
    'Report.print() masks raw secrets and JWTs as sha256 fingerprints'
  );
  const ident = configMod.identitySummary({ url: 'http://x', anonKey: secret, adminToken: jwt, readerToken: null, siteAdminToken: null });
  assertTrue(!ident.includes(secret) && !ident.includes(jwt) && ident.includes('sha256:'), 'identitySummary prints fingerprints only');
  assertTrue(/^sha256:[0-9a-f]{8}$/.test(configMod.fingerprint('anything')), 'fingerprint format sha256:<first8>');

  /* [2] MOCK_MODE=empty — suites must say NOT APPLIED YET and exit 0. */
  process.stdout.write('\n[2] MOCK_MODE=empty (0 tables): honest NOT APPLIED YET, exit 0\n');
  await withMock('empty', async (base) => {
    for (const s of ['schema_report.js', 'seed_counts.js', 'rls_matrix.js']) {
      const r = runScript(s, base, false);
      assertTrue(r.code === 0, `${s}: exit 0 on unapplied database (code=${r.code})`);
      assertTrue(/NOT APPLIED YET/.test(r.out), `${s}: prints the NOT APPLIED YET banner`);
    }
  });

  /* [3] MOCK_MODE=clean with ONLY the two required vars — runs, SKIPs auth/staff planes. */
  process.stdout.write('\n[3] MOCK_MODE=clean, ONLY SUPABASE_URL+SUPABASE_ANON_KEY: run + SKIP, never crash\n');
  await withMock('clean', async (base) => {
    for (const s of ['schema_report.js', 'seed_counts.js', 'rls_matrix.js']) {
      const r = runScript(s, base, false);
      assertTrue(r.code === 0, `${s}: exit 0 with required vars only (code=${r.code})`);
      assertTrue(!/crashed/.test(r.out), `${s}: no crash output`);
      assertTrue(!/undefined/.test(r.out.replace(/NOT [A-Z ]*undefined/g, '')), `${s}: no literal 'undefined' leaking into the report`);
      const sm = r.out.match(/SUMMARY [^\n]*?:\s*PASS=(\d+) FAIL=(\d+) SKIP=(\d+)/);
      assertTrue(!!sm && Number(sm[2]) === 0, `${s}: SUMMARY reports FAIL=0 on a clean mock`);
      if (s === 'rls_matrix.js') {
        assertTrue(/SKIP\s*\|\s*F plane staff checks|SUPABASE_ADMIN_TOKEN not provided/.test(r.out), 'rls_matrix: staff plane SKIPped without a token');
        assertTrue(/E0 authenticated reader plane/.test(r.out) || /E0 reader identity/.test(r.out), 'rls_matrix: reader plane handled (SKIP or token) without crashing');
      }
    }
  });

  /* [4] MOCK_MODE=clean with staff+reader tokens — the positive security path. */
  process.stdout.write('\n[4] MOCK_MODE=clean + admin/reader tokens: planes A–G execute and PASS\n');
  await withMock('clean', async (base) => {
    const r = runScript('rls_matrix.js', base, true);
    const sm = r.out.match(/SUMMARY [^\n]*?:\s*PASS=(\d+) FAIL=(\d+) SKIP=(\d+)/);
    assertTrue(r.code === 0, `rls_matrix: exit 0 (code=${r.code})`);
    assertTrue(!!sm && Number(sm[1]) >= 30 && Number(sm[2]) === 0, `rls_matrix: PASS>=30 and FAIL=0 (${sm && sm[0]})`);
    assertTrue(/F1 editor\+ reads drafts/.test(r.out) && /G3 editor upload/.test(r.out), 'rls_matrix: F/G planes actually executed with the token');
    assertTrue(!r.out.includes('mock-admin-token') && !r.out.includes(READER_T), 'rls_matrix: access-token VALUES never echoed in output');
    const s2 = runScript('seed_counts.js', base, true);
    assertTrue(s2.code === 0, `seed_counts: exit 0 with staff token (code=${s2.code})`);
  });

  /* [5] MOCK_MODE=leaky — the suite MUST fail, proving PASS is not vacuous. */
  process.stdout.write('\n[5] MOCK_MODE=leaky (broken RLS): FAIL rows + non-zero exit\n');
  await withMock('leaky', async (base) => {
    const r = runScript('rls_matrix.js', base, true);
    assertTrue(r.code === 1, `rls_matrix: exit 1 when policies leak (code=${r.code})`);
    assertTrue(/LEAK|<- SILENT SUCCESS/.test(r.out), 'rls_matrix: leak evidence present');
    const s = runScript('schema_report.js', base, false);
    assertTrue(s.code === 1 && /LEAK/.test(s.out), `schema_report: flags the profiles leak (exit=${s.code})`);
  });

  process.stdout.write(
    `\nSELFTEST SUMMARY: ${tally.pass} assertions passed, ${tally.fail} failed.\n` +
      (tally.fail ? 'SELFTEST RESULT: FAIL\n' : 'SELFTEST RESULT: PASS (exit 0)\n')
  );
  process.exitCode = tally.fail ? 1 : 0;
}

/* ---------------------------- dispatcher (runs last) --------------------- */
if (process.argv.includes('--serve')) {
  server.listen(PORT, '127.0.0.1', () => {
    const port = server.address().port;
    process.stdout.write(
      `mock supabase (${MODE}) listening on http://127.0.0.1:${port}\n` +
        `use: export SUPABASE_URL=http://127.0.0.1:${port} SUPABASE_ANON_KEY=mock-anon-key\n` +
        `     export SUPABASE_ADMIN_TOKEN=${ADMIN_T} SUPABASE_READER_TOKEN=${READER_T}\n`
    );
  });
} else {
  runSelfTest().catch((e) => {
    process.stderr.write('selftest crashed: ' + ((e && (e.stack || e.message)) || e) + '\n');
    process.exitCode = 1;
  });
}
