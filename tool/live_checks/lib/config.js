'use strict';
/**
 * tool/live_checks/lib/config.js
 *
 * Credential/secret handling for the live Supabase verification toolkit.
 *
 * HARD RULES enforced here:
 *   * NO service-role key, secret key, DB password or privileged credential is
 *     ever stored in this repository. Secrets come from the environment at
 *     runtime (or from a git-ignored tool/live_checks/.env).
 *   * The publishable/anon key and project URL are read from the EXISTING
 *     centralized Flutter config (lib/app/config/environment_config.dart) by
 *     parsing it — the value is never duplicated into this source tree.
 *   * Every value that looks like a credential is redacted from all output and
 *     from error messages; identities are printed only as `sha256:<first8>`.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const CHECKS_DIR = __dirname.replace(/[\\/]lib$/, '');
const REPO_ROOT = path.resolve(CHECKS_DIR, '..', '..');
const LOCAL_ENV_FILE = path.join(CHECKS_DIR, '.env');
const DART_CONFIG_FILE = path.join(
  REPO_ROOT,
  'lib',
  'app',
  'config',
  'environment_config.dart'
);

/** Environment variable slots understood by the toolkit. */
const ENV_SLOTS = {
  url: ['SUPABASE_URL', 'SUPABASE_PROJECT_URL'],
  anonKey: ['SUPABASE_ANON_KEY', 'SUPABABLE_ANON_KEY', 'SUPABASE_PUBLISHABLE_KEY'],
  /** Access token of an account that holds a staff role (super_admin or
   *  site admin/editor of india_tech). Provided by the operator at run time. */
  adminToken: ['SUPABASE_ADMIN_TOKEN', 'RLS_ADMIN_ACCESS_TOKEN'],
  /** Access token of a freshly signed-up account with NO profile_sites row. */
  readerToken: ['SUPABASE_READER_TOKEN', 'RLS_READER_ACCESS_TOKEN'],
  /** Optional: token of an account that is admin/editor of india_tech ONLY
   *  (never super_admin) — used for the strict cross-site isolation test. */
  siteAdminToken: ['SUPABASE_SITE_ADMIN_TOKEN', 'RLS_SITE_ADMIN_TOKEN'],
  /** Slug of a SECOND, operator-created temporary site used to prove
   *  cross-site isolation. Must match /^zzz-check/. */
  secondSiteSlug: ['CHECK_SECOND_SITE_SLUG', 'SECOND_SITE_SLUG'],
  /** Slug of a site whose admin token legitimately owns it. */
  adminSiteSlug: ['CHECK_ADMIN_SITE_SLUG'],
  /** '0' disables the throwaway-signup fallback for the reader plane. */
  allowSignup: ['ALLOW_THROWAWAY_SIGNUP'],
};

function firstEnv(slots) {
  for (const name of slots) {
    const v = process.env[name];
    if (v && v.trim()) return { name, value: v.trim() };
  }
  return null;
}

/** Minimal KEY=VALUE parser for the git-ignored local env file. */
function parseDotEnv(text) {
  const out = {};
  for (const rawLine of String(text).split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq < 1) continue;
    const key = line.slice(0, eq).trim();
    let val = line.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    out[key] = val;
  }
  return out;
}

function localEnv() {
  try {
    return parseDotEnv(fs.readFileSync(LOCAL_ENV_FILE, 'utf8'));
  } catch {
    return {};
  }
}

/**
 * Parse the centralized Dart config for the defaultValue of the two
 * --dart-define slots. Placeholder defaults (shipped in the repo) are treated
 * as "not configured" so the toolkit never talks to a bogus host.
 */
function readDartConfig() {
  const res = { url: null, anonKey: null, note: '' };
  let text;
  try {
    text = fs.readFileSync(DART_CONFIG_FILE, 'utf8');
  } catch {
    res.note = `central config not found at ${DART_CONFIG_FILE}`;
    return res;
  }
  const grab = (varName) => {
    // static const String <varName> = String.fromEnvironment( '<X>', defaultValue: '<v>' );
    const re = new RegExp(
      `${varName}\\s*=\\s*String\\.fromEnvironment\\s*\\([\\s\\S]*?defaultValue:\\s*'([^']*)'`,
      'm'
    );
    const m = text.match(re);
    return m ? m[1] : null;
  };
  const url = grab('supabaseUrl');
  const key = grab('supabaseAnonKey');
  if (url && !url.includes('placeholder')) res.url = url;
  if (key && !key.includes('placeholder')) res.anonKey = key;
  if (!res.url || !res.anonKey) {
    res.note =
      'lib/app/config/environment_config.dart still carries placeholder ' +
      'defaults (the real key is injected with --dart-define at build time, ' +
      'never committed)';
  }
  return res;
}

/** Resolve one logical slot: real env > local .env > dart config default. */
function resolveSlot(slot) {
  const fromEnv = firstEnv(ENV_SLOTS[slot]);
  if (fromEnv) return { value: fromEnv.value, source: `env:${fromEnv.name}` };
  const file = localEnv();
  for (const name of ENV_SLOTS[slot]) {
    if (file[name]) return { value: file[name], source: `file:${name}` };
  }
  const dart = readDartConfig();
  if (slot === 'url' && dart.url) return { value: dart.url, source: 'dart:supabaseUrl' };
  if (slot === 'anonKey' && dart.anonKey)
    return { value: dart.anonKey, source: 'dart:supabaseAnonKey' };
  return { value: null, source: null };
}

/** ---- secret hygiene helpers (used by every script and by run_all) ---- */

const JWT_RE = /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{4,}/g;

function fingerprint(value) {
  if (!value) return 'sha256:00000000';
  return 'sha256:' + crypto.createHash('sha256').update(String(value)).digest('hex').slice(0, 8);
}

/** Replace any credential-looking substring with a fingerprint. */
function redact(text, secrets = []) {
  let out = String(text == null ? '' : text);
  out = out.replace(JWT_RE, (m) => `[jwt ${fingerprint(m)}]`);
  for (const s of secrets) {
    if (s && s.length >= 12) out = out.split(s).join(`[secret ${fingerprint(s)}]`);
  }
  return out;
}

/** Never let a response body leak a credential into the console. */
function redactObject(obj, secrets) {
  try {
    return JSON.parse(redact(JSON.stringify(obj), secrets));
  } catch {
    return redact(String(obj), secrets);
  }
}

function load({ required = true } = {}) {
  const url = resolveSlot('url');
  const anonKey = resolveSlot('anonKey');
  const missing = [];
  if (!url.value) missing.push(...ENV_SLOTS.url);
  if (!anonKey.value) missing.push(...ENV_SLOTS.anonKey);

  if (!url.value || !anonKey.value) {
    const dart = readDartConfig();
    const msg =
      'SUPABASE_URL / SUPABASE_ANON_KEY are not available to the toolkit.\n' +
      `  (tried env ${ENV_SLOTS.url.join('|')} / ${ENV_SLOTS.anonKey.join('|')}, ` +
      `${path.relative(REPO_ROOT, LOCAL_ENV_FILE)}, ${path.relative(REPO_ROOT, DART_CONFIG_FILE)})\n` +
      `  reason: ${dart.note || 'no value found'}\n` +
      '  fix: export SUPABASE_URL and SUPABASE_ANON_KEY (the PUBLISHABLE/anon key only),\n' +
      '  or create a git-ignored tool/live_checks/.env with those two lines.\n' +
      '  NEVER put a service_role/secret key or a database password here.';
    if (required) {
      process.stderr.write(msg + '\n');
      process.exit(2);
    }
  }

  const cfg = {
    repoRoot: REPO_ROOT,
    checksDir: CHECKS_DIR,
    url: (url.value || '').replace(/\/+$/, ''),
    urlSource: url.source,
    anonKey: anonKey.value,
    anonKeySource: anonKey.source,
    adminToken: resolveSlot('adminToken').value,
    adminTokenSource: resolveSlot('adminToken').source,
    readerToken: resolveSlot('readerToken').value,
    siteAdminToken: resolveSlot('siteAdminToken').value,
    secondSiteSlug: resolveSlot('secondSiteSlug').value,
    adminSiteSlug: resolveSlot('adminSiteSlug').value,
    allowThrowawaySignup: (resolveSlot('allowSignup').value || '1') !== '0',
    dartConfigFile: DART_CONFIG_FILE,
    secrets: [],
  };
  // Values that must never reach the console: our own slots plus any env var
  // whose NAME looks credential-ish (service_role/secret/password are never
  // read by this toolkit, but if one is present in the shell we redact it).
  const credLikeEnv = Object.entries(process.env)
    .filter(([name, value]) =>
      /(^|_)(KEY|TOKEN|SECRET|PASSWORD|PWD|SERVICE_ROLE)(_|$)/i.test(name) &&
      value &&
      value.length >= 12
    )
    .map(([, value]) => value);
  cfg.secrets = [cfg.anonKey, cfg.adminToken, cfg.readerToken, cfg.siteAdminToken]
    .filter(Boolean)
    .concat(credLikeEnv);
  return cfg;
}

/** Which key/identity is in play — printed as fingerprints only. */
function identitySummary(cfg) {
  const line = (label, value) =>
    `${label.padEnd(14)} ${value ? fingerprint(value) : 'NOT PROVIDED'}`;
  return [
    `project url      ${cfg.url || 'NOT CONFIGURED'}`,
    line('anon key', cfg.anonKey),
    line('admin token', cfg.adminToken),
    line('reader token', cfg.readerToken),
    line('site-admin tok', cfg.siteAdminToken),
  ].join('\n');
}

/* ------------------------------------------------------------------ *
 * SAFETY GUARD: which sites may this toolkit ever WRITE into?
 *   - india_tech (throwaway `zzz-check-` fixtures only, always deleted)
 *   - a temporary site whose slug itself starts with `zzz-check`
 * Anything else (sibling production sites such as the travel site) is
 * hard-blocked: the write helper throws before issuing the request.
 * ------------------------------------------------------------------ */
const WRITE_ALLOWED_BASE_SLUG = 'india_tech';
const WRITE_ALLOWED_SLUG_RE = /^zzz-check[a-z0-9_-]*$/i;

function isWritableSiteSlug(slug) {
  if (!slug) return false;
  return slug === WRITE_ALLOWED_BASE_SLUG || WRITE_ALLOWED_SLUG_RE.test(slug);
}

/** True only for a THROWAWAY second site (never the base india_tech site).
 *  Used by the cross-site isolation probe, which must target a different site. */
function isTempCheckSiteSlug(slug) {
  return !!slug && slug !== WRITE_ALLOWED_BASE_SLUG && WRITE_ALLOWED_SLUG_RE.test(slug);
}

function assertWritableSiteSlug(slug, what) {
  if (!isWritableSiteSlug(slug)) {
    throw new Error(
      `SAFETY BLOCK: refusing to write ${what} into site slug '${slug}'. ` +
        `Allowed: '${WRITE_ALLOWED_BASE_SLUG}' and temporary sites matching ` +
        `'${WRITE_ALLOWED_SLUG_RE}'. Seeded/production rows are never touched.`
    );
  }
}

const TABLES = [
  'sites',
  'profiles',
  'profile_sites',
  'authors',
  'categories',
  'tags',
  'posts',
  'post_tags',
  'media',
  'post_revisions',
  'redirects',
  'site_settings',
  'subscribers',
  'analytics_events',
];

/** Tables the RLS design says anon must NOT be able to read. */
const ANON_DENIED_READ = [
  'subscribers',
  'post_revisions',
  'analytics_events',
  'profiles',
  'profile_sites',
];

/** Known non-public seed rows (ground truth read from 006_seed_data.sql).
 *  Used as the "verify a known draft slug is absent" evidence. */
const KNOWN_SEED_FIXTURES = {
  publishedSlug: 'choose-right-ai-tool-honest-framework',
  draftSlugs: [
    'budget-vs-premium-phone-features-worth-it',
    'weekend-app-audit-indian-families',
    'new-phone-first-week-checklist',
    'passwords-passkeys-parents-transition-guide',
  ],
  archivedSlugs: [
    'offline-first-apps-worth-installing',
    'festival-gadget-shopping-old-habits',
  ],
  futureScheduledSlugs: [
    'home-study-ai-routine-indian-families',
    'why-chip-news-matters-semiconductors-daily-life',
    'prepaid-vs-postpaid-how-to-choose',
  ],
};

const PREFIX = 'zzz-check-';
function fixtureTag() {
  return `${PREFIX}${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;
}

module.exports = {
  CHECKS_DIR,
  REPO_ROOT,
  LOCAL_ENV_FILE,
  DART_CONFIG_FILE,
  ENV_SLOTS,
  TABLES,
  ANON_DENIED_READ,
  KNOWN_SEED_FIXTURES,
  WRITE_ALLOWED_BASE_SLUG,
  PREFIX,
  load,
  readDartConfig,
  resolveSlot,
  redact,
  redactObject,
  fingerprint,
  identitySummary,
  isWritableSiteSlug,
  isTempCheckSiteSlug,
  assertWritableSiteSlug,
  fixtureTag,
};
