'use strict';
/**
 * tool/live_checks/lib/api.js
 *
 * Thin REST gateway over Supabase's public HTTP surfaces (plain global fetch,
 * no dependencies):
 *   * PostgREST   /rest/v1/<table>
 *   * GoTrue      /auth/v1/<...>       (throwaway signup/sign-in only)
 *   * Storage     /storage/v1/object/...
 * Plus: a cleanup registry (throwaway fixtures removed in `finally`) and the
 * PASS/FAIL/SKIP reporter used by every script.
 *
 * READ-ONLY SAFETY: the only writes this layer will perform are calls made
 * through `client.rest(...)` with method POST/PATCH/DELETE. Callers must pass
 * fixture payloads built with config.fixtureTag() (prefix `zzz-check-`) and
 * must have run config.assertWritableSiteSlug() for the target site. Nothing
 * here ever truncates, drops or bulk-deletes: DELETE requests without a
 * narrow `id=eq.<uuid>` filter are refused outright.
 */

const config = require('./config');

const PG_BLOCKED = new Set(['42501', 'PGRST205', '42501 ']);

class Api {
  constructor(cfg, token = null) {
    // Fail fast instead of ever sending `Bearer undefined` / `apikey: undefined`
    // (which would produce misleading FAILs instead of clean SKIPs downstream).
    if (!cfg || !cfg.url || !cfg.anonKey) {
      throw new Error('Api: SUPABASE_URL and SUPABASE_ANON_KEY must be resolved before any request');
    }
    if (token !== null && token === undefined) {
      throw new Error('Api: token must be null (anon) or a string, got undefined');
    }
    this.cfg = cfg;
    this.token = token;
    this.cleanup = [];
    this.notes = [];
  }

  headers(extra = {}) {
    const h = {
      apikey: this.cfg.anonKey,
      Accept: 'application/json',
      ...extra,
    };
    // Supabase/PostgREST only parses `Authorization: Bearer <jwt>`; an anon-key
    // Bearer header is the canonical form used by every official client.
    h.Authorization = `Bearer ${this.token || this.cfg.anonKey}`;
    return h;
  }

  /* ---------------- PostgREST ---------------- */

  /**
   * Low-level REST call. Returns { status, ok, rows, total, error, body }.
   *  total = full row count reported by Content-Range when Prefer: count=exact.
   */
  async rest(table, { method = 'GET', query = '', body, headers = {}, token } = {}) {
    const url = `${this.cfg.url}/rest/v1/${table}${query ? '?' + query : ''}`;
    const hdrs = this.headers(headers);
    if (token !== undefined) {
      delete hdrs.Authorization;
      hdrs.Authorization = `Bearer ${token || this.cfg.anonKey}`;
    }
    if (body !== undefined) hdrs['Content-Type'] = 'application/json';

    // SAFETY: a DELETE must be pinned to exact rows by id/slug/path filters.
    if (method === 'DELETE') {
      const params = String(query || '')
        .replace(/^\?/, '')
        .split('&')
        .map((p) => p.trim())
        .filter((p) => p && !/^(select|order|limit|offset)=/.test(p));
      const SAFE = /^([a-z_]*id|slug|old_path|new_path|storage_path|email)=eq\.[^,]+$/;
      const bad = params.filter((p) => !SAFE.test(p));
      if (!params.length || bad.length) {
        throw new Error(
          `SAFETY BLOCK: DELETE on '${table}' needs only exact-row filters ` +
            `(<col>=eq.<single value> on id/slug/path/email). Offending filter(s): ` +
            `${JSON.stringify(bad)}. Bulk or range deletes are never issued here.`
        );
      }
    }

    let res;
    try {
      res = await fetch(url, {
        method,
        headers: hdrs,
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    } catch (e) {
      return {
        status: 0,
        ok: false,
        networkError: true,
        rows: null,
        total: null,
        error: { message: config.redact(e.message, this.cfg.secrets) },
        url: config.redact(url, this.cfg.secrets),
      };
    }

    let text = '';
    try {
      text = await res.text();
    } catch {
      text = '';
    }
    let parsed = null;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {
      parsed = null;
    }
    const rows = Array.isArray(parsed) ? parsed : null;
    const cr = res.headers.get('content-range');
    const total = cr && cr.includes('/') ? Number(cr.split('/')[1]) : null;

    const err =
      parsed && !Array.isArray(parsed) && (parsed.message || parsed.error_description)
        ? { code: parsed.code || parsed.error, message: config.redact(parsed.message || parsed.error_description, this.cfg.secrets) }
        : null;

    return {
      status: res.status,
      ok: res.ok,
      rows,
      total,
      error: err,
      headers: Object.fromEntries(res.headers.entries()),
      raw: config.redact(text, this.cfg.secrets).slice(0, 800),
      url,
    };
  }

  /** GET with an exact count; returns { status, rows, total, error }. */
  async list(table, query, opts = {}) {
    return this.rest(table, {
      ...opts,
      query: `${query}${query ? '&' : ''}limit=1000`,
      headers: { Prefer: 'count=exact', Range: '0-999', ...(opts.headers || {}) },
    });
  }

  /** Count rows matching a filter without transferring them. */
  async count(table, query = '', opts = {}) {
    return this.rest(table, {
      ...opts,
      query: `${query}${query ? '&' : ''}limit=0`,
      headers: { Prefer: 'count=exact', Range: '0-0', ...(opts.headers || {}) },
    });
  }

  async insert(table, values, opts = {}) {
    return this.rest(table, {
      method: 'POST',
      body: values,
      token: opts.token,
      headers: { Prefer: 'return=representation', ...(opts.headers || {}) },
    });
  }

  async update(table, patch, query, opts = {}) {
    return this.rest(table, {
      method: 'PATCH',
      query,
      body: patch,
      token: opts.token,
      headers: { Prefer: 'return=representation', ...(opts.headers || {}) },
    });
  }

  async remove(table, query, opts = {}) {
    return this.rest(table, {
      method: 'DELETE',
      query,
      token: opts.token,
      ...(opts || {}),
    });
  }

  /* ---------------- cleanup registry ---------------- */

  track(label, fn) {
    this.cleanup.push({ label, fn });
  }

  /** Run every registered cleanup; returns per-item outcome (never throws). */
  async runCleanup() {
    const out = [];
    for (const item of this.cleanup.reverse()) {
      try {
        const r = await item.fn();
        out.push({ label: item.label, ok: !!r || r === undefined, detail: r && r.error ? r.error.message : '' });
      } catch (e) {
        out.push({ label: item.label, ok: false, detail: config.redact(e.message, this.cfg.secrets) });
      }
    }
    this.cleanup = [];
    return out;
  }

  /* ---------------- GoTrue (throwaway accounts only) ---------------- */

  async signup(email, password, data = {}) {
    const { res, payload, networkError, message } = await netFetch(`${this.cfg.url}/auth/v1/signup`, {
      method: 'POST',
      headers: { apikey: this.cfg.anonKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, data }),
    }, this.cfg.secrets);
    if (networkError) return { status: 0, ok: false, json: null, networkError: true, message };
    return {
      status: res.status,
      ok: res.ok,
      json: safeJson(payload),
      message: config.redact(messageOf(payload), this.cfg.secrets),
    };
  }

  /**
   * Password grant. NOTE: named `signIn`, NOT `token` — the instance keeps a
   * `.token` property (the bearer string) which shadowed a method of the same
   * name and made anon.token() throw "is not a function" (original defect).
   */
  async signIn(email, password) {
    const { res, payload, networkError, message } = await netFetch(
      `${this.cfg.url}/auth/v1/token?grant_type=password`,
      {
        method: 'POST',
        headers: { apikey: this.cfg.anonKey, 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      },
      this.cfg.secrets
    );
    if (networkError) return { status: 0, ok: false, accessToken: null, networkError: true, message };
    const json = safeJson(payload);
    return {
      status: res.status,
      ok: res.ok,
      accessToken: json && json.access_token ? json.access_token : null,
      message: config.redact(messageOf(payload), this.cfg.secrets),
    };
  }
}

function safeJson(text) {
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return null;
  }
}

/** fetch + body reads that NEVER throw: a transport failure becomes
 *  { status: 0, networkError: true } so callers SKIP instead of crashing. */
async function netFetch(url, init, secrets, as = 'text') {
  try {
    const res = await fetch(url, init);
    const payload =
      as === 'buffer'
        ? res.ok
          ? await res.arrayBuffer()
          : await res.text()
        : await res.text();
    return { res, payload };
  } catch (e) {
    return { res: null, networkError: true, message: config.redact(e.message, secrets) };
  }
}

function messageOf(text) {
  const j = safeJson(text);
  if (!j) return String(text).slice(0, 200);
  return j.error_description || j.msg || j.message || JSON.stringify(j).slice(0, 200);
}

/* ---------------- storage (plain fetch, no SDK) ---------------- */

async function storageUpload(cfg, token, bucket, path, contentType, bytes) {
  const { res, payload, networkError, message } = await netFetch(`${cfg.url}/storage/v1/object/${bucket}/${path}`, {
    method: 'POST',
    headers: {
      apikey: cfg.anonKey,
      Authorization: `Bearer ${token || cfg.anonKey}`,
      'Content-Type': contentType,
      'x-upsert': 'false',
    },
    body: bytes,
  }, cfg.secrets);
  if (networkError) return { status: 0, ok: false, json: null, networkError: true, message };
  return {
    status: res.status,
    ok: res.ok,
    json: safeJson(payload),
    message: config.redact(messageOf(payload), cfg.secrets),
  };
}

async function storagePublicRead(cfg, bucket, path, token = null) {
  const { res, payload, networkError, message } = await netFetch(
    `${cfg.url}/storage/v1/object/public/${bucket}/${path}`,
    { method: 'GET', headers: token ? { Authorization: `Bearer ${token}`, apikey: cfg.anonKey } : {} },
    cfg.secrets,
    'buffer'
  );
  if (networkError) return { status: 0, ok: false, bytes: 0, networkError: true, message };
  const isBuf = payload instanceof ArrayBuffer;
  return {
    status: res.status,
    ok: res.ok,
    bytes: isBuf && payload ? payload.byteLength : 0,
    message: res.ok ? '' : config.redact(String(isBuf ? '' : payload || ''), cfg.secrets).slice(0, 200),
  };
}

async function storageSignedUrl(cfg, token, bucket, path, expiresIn = 60) {
  const { res, payload, networkError, message } = await netFetch(`${cfg.url}/storage/v1/object/sign/${bucket}/${path}`, {
    method: 'POST',
    headers: {
      apikey: cfg.anonKey,
      Authorization: `Bearer ${token || cfg.anonKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ expiresIn }),
  }, cfg.secrets);
  if (networkError) return { status: 0, ok: false, signedURL: null, networkError: true, message };
  const j = safeJson(payload);
  return {
    status: res.status,
    ok: res.ok,
    signedURL: j && j.signedURL ? j.signedURL : null,
    message: config.redact(messageOf(payload), cfg.secrets),
  };
}

/**
 * Read a signed URL. Supabase returns the signed path as
 * `/object/sign/<bucket>/<path>?token=...`, so the real request is
 * `<project>/storage/v1` + that path. Also accepts a bare `bucket/path?token=`.
 */
async function storageSignedRead(cfg, signedURL) {
  const p = String(signedURL || '');
  const target = p.startsWith('/object/')
    ? `${cfg.url}/storage/v1${p}`
    : p.includes('/object/sign/')
    ? p
    : `${cfg.url}/storage/v1/object/sign/${p.replace(/^\/?media\//, '')}`;
  const { res, payload, networkError, message } = await netFetch(target, { headers: { apikey: cfg.anonKey } }, cfg.secrets, 'buffer');
  if (networkError) return { status: 0, ok: false, bytes: 0, networkError: true, target: config.redact(target, cfg.secrets), message };
  const isBuf = payload instanceof ArrayBuffer;
  return {
    status: res.status,
    ok: res.ok,
    bytes: isBuf && payload ? payload.byteLength : 0,
    target: config.redact(target, cfg.secrets),
  };
}

async function storageDelete(cfg, token, bucket, path) {
  const { res, payload, networkError, message } = await netFetch(`${cfg.url}/storage/v1/object/${bucket}/${path}`, {
    method: 'DELETE',
    headers: {
      apikey: cfg.anonKey,
      Authorization: `Bearer ${token || cfg.anonKey}`,
    },
  }, cfg.secrets);
  if (networkError) return { status: 0, ok: false, networkError: true, message };
  return { status: res.status, ok: res.ok, message: config.redact(messageOf(payload), cfg.secrets) };
}

/** 1x1 transparent PNG, used as the throwaway upload fixture. */
function tinyPng() {
  return Uint8Array.from(
    Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      'base64'
    )
  );
}

/* ---------------- reporter ---------------- */

class Report {
  constructor(title, secrets = []) {
    this.title = title;
    this.secrets = secrets;
    this.rows = [];
    this.exitCode = 0;
  }

  add(status, name, evidence) {
    const s = ['PASS', 'FAIL', 'SKIP', 'INFO'].includes(status) ? status : 'INFO';
    this.rows.push({
      status: s,
      name: config.redact(name, this.secrets),
      evidence: config.redact(evidence, this.secrets),
    });
    if (s === 'FAIL') this.exitCode = 1;
    return this;
  }

  pass(name, ev) {
    return this.add('PASS', name, ev);
  }
  fail(name, ev) {
    return this.add('FAIL', name, ev);
  }
  skip(name, ev) {
    return this.add('SKIP', name, ev);
  }
  info(name, ev) {
    return this.add('INFO', name, ev);
  }

  /** assert helper: cond ? PASS : FAIL, with the evidence string always shown */
  check(cond, name, ev) {
    return cond ? this.pass(name, ev) : this.fail(name, ev);
  }

  print() {
    const nameW = Math.min(
      72,
      Math.max(...this.rows.map((r) => r.name.length), this.title.length, 12)
    );
    process.stdout.write(`\n${this.title}\n`);
    process.stdout.write(`${'='.repeat(nameW + 12)}\n`);
    for (const r of this.rows) {
      process.stdout.write(`${r.status.padEnd(5)} | ${r.name.padEnd(nameW)} | ${r.evidence}\n`);
    }
    const c = (s) => this.rows.filter((r) => r.status === s).length;
    process.stdout.write(
      `\nSUMMARY ${this.title}: PASS=${c('PASS')} FAIL=${c('FAIL')} SKIP=${c('SKIP')} INFO=${c('INFO')}\n`
    );
  }

  get failures() {
    return this.rows.filter((r) => r.status === 'FAIL');
  }
}

/**
 * Shared pre-flight: is the migration chain applied at all?
 * Returns { applied, detail }. When not applied every script degrades to a
 * clear "not applied yet" report instead of a misleading wall of failures.
 */
async function probeSchema(cfg) {
  const client = new Api(cfg);
  const r = await client.rest('sites', { query: 'limit=1' });
  if (r.networkError) return { applied: false, reason: 'network', detail: r.error.message };
  if (r.status === 404) {
    const code = (r.error && (r.error.code || r.error)) || '';
    if (String(code).includes('PGRST205') || /Could not find the table/.test(r.raw || '')) {
      return {
        applied: false,
        reason: 'empty-database',
        detail: 'relation public.sites is not in the PostgREST schema cache (0 tables) — migrations 001..006 have not been applied to the remote project yet.',
      };
    }
    return { applied: false, reason: 'missing', detail: `HTTP 404 on /rest/v1/sites: ${r.raw}` };
  }
  if (r.status === 401 || r.status === 403) {
    return {
      applied: 'unknown',
      reason: 'auth',
      detail: `HTTP ${r.status} using the anon key: ${r.error && r.error.message}`,
    };
  }
  if (r.ok) return { applied: true, detail: `HTTP ${r.status}, rows=${JSON.stringify(r.rows && r.rows.length)}` };
  return { applied: 'unknown', reason: 'other', detail: `HTTP ${r.status}: ${r.raw}` };
}

function notAppliedBanner(target, probe) {
  if (probe && probe.reason === 'auth') {
    return (
      `\n[CREDENTIALS REJECTED] The project answered the anon-key probe with a 401/403, so\n` +
      `nothing about ${target} can be read yet. Fix SUPABASE_ANON_KEY (the PUBLISHABLE key\n` +
      `only) or the project URL — this is not a schema state and not a security failure.\n` +
      `  probe: ${probe.detail}\n`
    );
  }
  if (probe && probe.reason === 'network') {
    return (
      `\n[UNREACHABLE] The project could not be contacted (${probe.detail}).\n` +
      `Nothing about ${target} was verified.\n`
    );
  }
  return (
    `\n[NOT APPLIED YET] The remote database does not expose ${target} — nothing can be\n` +
    'verified against it. This is the honest current state, not a test failure:\n' +
    'apply migrations 001 -> 006 (supabase/README.md), seed, then re-run.\n'
  );
}

/** One-line honest reason for why a case could not be executed. */
function stateSkipReason(probe) {
  switch (probe && probe.reason) {
    case 'auth':
      return 'publishable/anon key was rejected by the project (HTTP 401) — nothing was probed';
    case 'network':
      return 'project unreachable from this machine — nothing was probed';
    case 'empty-database':
      return 'remote database has 0 tables — migrations 001..006 not applied yet';
    default:
      return `schema not readable (${(probe && probe.reason) || 'unknown'})`;
  }
}

module.exports = {
  Api,
  Report,
  probeSchema,
  notAppliedBanner,
  stateSkipReason,
  storageUpload,
  storagePublicRead,
  storageSignedUrl,
  storageSignedRead,
  storageDelete,
  tinyPng,
  PG_BLOCKED,
};
