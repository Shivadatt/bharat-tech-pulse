#!/usr/bin/env node
'use strict';
/**
 * tool/live_checks/run_all.js
 *
 * Orchestrates the live verification suite against the remote Supabase project:
 *   1. schema_report.js  — table presence + anon visibility matrix
 *   2. seed_counts.js    — 006 seed contract + referential integrity
 *   3. rls_matrix.js     — negative/positive security suite (incl. storage)
 *
 * Output is passed through a redaction filter, so NO key/token/secret value can
 * ever reach the console or a log, even if a child process tried to print one.
 * Credentials are matched by identity (sha256 fingerprint) only.
 *
 * Exit code: 0 when no case FAILED (an unapplied/empty database is reported as
 * "NOT APPLIED YET" and exits 0 by design — it is a state, not a security
 * failure). 1 when any suite reported failures. Use --strict to also turn the
 * unapplied/empty state into a non-zero exit (useful in CI after the apply).
 *
 * Usage:
 *   node tool/live_checks/run_all.js [--strict] [--only schema|seed|rls] [--verbose]
 */

const path = require('path');
const { spawnSync } = require('child_process');
const config = require('./lib/config');
const api = require('./lib/api');

const SUITES = [
  { key: 'schema', file: 'schema_report.js', desc: 'table presence + anon visibility matrix' },
  { key: 'seed', file: 'seed_counts.js', desc: '006 seed counts + referential integrity' },
  { key: 'rls', file: 'rls_matrix.js', desc: 'RLS/storage negative + positive security suite' },
];

async function main() {
  const args = process.argv.slice(2);
  const strict = args.includes('--strict');
  const verbose = args.includes('--verbose');
  const onlyIdx = args.indexOf('--only');
  const only = onlyIdx >= 0 ? args[onlyIdx + 1] : null;

  const cfg = config.load({ required: false });
  const secrets = cfg.secrets || [];

  process.stdout.write('================================================================\n');
  process.stdout.write(' Bharat Tech Pulse — live Supabase verification (run_all)\n');
  process.stdout.write('================================================================\n');
  process.stdout.write(config.identitySummary(cfg) + '\n');
  process.stdout.write(
    `\nNOTE: output is filtered — credentials are shown as sha256:<first8> only.\n` +
      `Credentials are resolved from env / git-ignored tool/live_checks/.env /\n` +
      `the centralized Dart config; nothing is hardcoded in this toolkit.\n`
  );

  if (!cfg.url || !cfg.anonKey) {
    process.stdout.write(
      '\nCREDENTIALS UNRESOLVED — cannot reach the project.\n' +
        '  export SUPABASE_URL=https://ylzwuwfhlqomjqcdrpxk.supabase.co\n' +
        '  export SUPABASE_ANON_KEY=<publishable/anon key ONLY>\n' +
        '  (optional) export SUPABASE_ADMIN_TOKEN=<access token of the operator admin account>\n' +
        '  (optional) export SUPABASE_READER_TOKEN=<access token of an account with no profile_sites row>\n'
    );
    process.exit(2);
  }

  const selected = only ? SUITES.filter((s) => s.key === only) : SUITES;
  if (!selected.length) {
    process.stderr.write(`unknown --only '${only}' (schema|seed|rls)\n`);
    process.exit(2);
  }

  /* ---------------- schema-applied state (reported up front) ---------------- */
  process.stdout.write('\nPre-flight: probing /rest/v1/sites with the anon key...\n');
  const state = await api.probeSchema(cfg);
  if (state.applied === true) {
    process.stdout.write(`  database state: APPLIED (${state.detail})\n`);
  } else {
    process.stdout.write(
      `  database state: NOT VERIFIABLE (reason: ${state.reason}) — ${state.detail}\n` +
        `  Every suite will report that state honestly and exit 0; nothing is being hidden.\n`
    );
  }

  const results = [];
  for (const suite of selected) {
    const target = path.join(config.CHECKS_DIR, suite.file);
    process.stdout.write(`\n\n######## ${suite.file} — ${suite.desc} ########\n`);
    const child = spawnSync(process.execPath, [target, ...(verbose ? ['--verbose'] : []), ...(strict ? ['--strict'] : [])], {
      encoding: 'utf8',
      env: process.env,
      cwd: config.REPO_ROOT,
      maxBuffer: 64 * 1024 * 1024,
    });
    const out = config.redact((child.stdout || '') + (child.stderr || ''), secrets);
    process.stdout.write(out.endsWith('\n') ? out : out + '\n');
    const statuses = countStatuses(out);
    results.push({
      suite: suite.file,
      code: child.status === null ? (child.error ? `spawn error: ${config.redact(child.error.message, secrets)}` : 'signal') : child.status,
      pass: statuses.PASS,
      fail: statuses.FAIL,
      skip: statuses.SKIP,
    });
  }

  /* ---------------- aggregate ---------------- */
  process.stdout.write('\n\n================ AGGREGATE ================\n');
  process.stdout.write(
    `database state: ${state.applied === true ? 'migrations applied' : api.stateSkipReason(state)}\n`
  );
  for (const r of results) {
    process.stdout.write(
      `${r.suite.padEnd(20)} exit=${String(r.code).padEnd(4)} PASS=${String(r.pass).padEnd(4)} ` +
        `FAIL=${String(r.fail).padEnd(4)} SKIP=${r.skip}\n`
    );
  }
  const totalFail = results.reduce((a, r) => a + (typeof r.fail === 'number' ? r.fail : 0), 0);
  const badExit = results.filter((r) => r.code !== 0);
  if (totalFail) {
    process.stdout.write(
      `\nOVERALL: ${totalFail} SECURITY/DATA ASSERTION(S) FAILED. Backend is not ready.\n`
    );
  } else if (badExit.length) {
    process.stdout.write(`\nOVERALL: suites crashed or exited non-zero: ${badExit.map((r) => `${r.suite}(${r.code})`).join(', ')}.\n`);
  } else if (state.applied !== true) {
    process.stdout.write(
      `\nOVERALL: NO ASSERTION COULD BE VERIFIED — ${api.stateSkipReason(state)}.\n` +
        `Exit 0 means "nothing failed", NOT "backend is secure".\n` +
        `Re-run once migrations 001 -> 006 are applied, seeded and the keys are exported.\n`
    );
  } else {
    process.stdout.write(
      `\nOVERALL: no assertion FAILED. Skipped assertions still need the missing\n` +
        `tokens (see the SKIP rows) — re-run with SUPABASE_ADMIN_TOKEN / SUPABASE_READER_TOKEN.\n`
    );
  }

  let code = totalFail ? 1 : badExit.length ? 1 : 0;
  if (strict && code === 0 && state.applied !== true) {
    process.stdout.write('--strict: unapplied/empty database treated as a failure.\n');
    code = 1;
  }
  if (strict && code === 0) {
    const skipped = results.reduce((a, r) => a + r.skip, 0);
    if (skipped) {
      process.stdout.write(`--strict: ${skipped} skipped assertion(s) treated as a failure.\n`);
      code = 1;
    }
  }
  process.exitCode = code;
}

function countStatuses(text) {
  const out = { PASS: 0, FAIL: 0, SKIP: 0, leakLines: 0, sawSummary: false };
  for (const line of String(text).split(/\r?\n/)) {
    const m = line.match(/^(PASS|FAIL|SKIP)\s*\|/);
    if (m) out[m[1]]++;
    if (/LEAK|SECURITY:|<- SILENT SUCCESS/.test(line)) out.leakLines++;
    const s = line.match(/SUMMARY .*?:\s*PASS=(\d+) FAIL=(\d+) SKIP=(\d+)/);
    if (s) {
      // trust the suite's own tally when it prints one (avoids double counting)
      out.PASS = Number(s[1]);
      out.FAIL = Number(s[2]);
      out.SKIP = Number(s[3]);
      out.sawSummary = true;
    }
  }
  // Suites that print a plain matrix instead of a Report (schema_report) get
  // their leak lines counted once, as failures.
  if (!out.sawSummary) out.FAIL += out.leakLines;
  return out;
}

main().catch((e) => {
  process.stderr.write('run_all.js crashed: ' + config.redact((e && (e.stack || e.message)) || String(e), []) + '\n');
  process.exitCode = 2;
});
