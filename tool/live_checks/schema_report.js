#!/usr/bin/env node
'use strict';
/**
 * tool/live_checks/schema_report.js
 *
 * Presence + RLS smoke matrix over all 14 tables, using ONLY PostgREST with
 * the publishable/anon key. For each table it reports:
 *   exists?          — 404/PGRST205 means the table is not in the schema cache
 *   rows visible to anon — exact count via Content-Range (Prefer: count=exact)
 *   RLS verdict      — how the table behaves for an anonymous caller
 *
 * The database is currently expected to be EMPTY. When migrations are not
 * applied yet this script prints a clear "NOT APPLIED YET" report and exits 0
 * (use --strict to turn that into a non-zero exit) so it can be run at any
 * point before, during or after the dashboard apply.
 *
 * Usage:
 *   node tool/live_checks/schema_report.js [--strict] [--json]
 * Env: SUPABASE_URL, SUPABASE_ANON_KEY (see lib/config.js resolution order).
 */

const config = require('./lib/config');
const api = require('./lib/api');

/** What an anonymous caller is *allowed* to see per the 003 policy set. */
const ANON_EXPECTS_ROWS = new Set([
  'sites',
  'categories',
  'authors',
  'tags',
  'posts',
  'post_tags',
  'media',
  'redirects',
  'site_settings',
]);

async function main() {
  const args = process.argv.slice(2);
  const strict = args.includes('--strict');
  const cfg = config.load();
  const anon = new api.Api(cfg);

  process.stdout.write('schema_report.js — Bharat Tech Pulse live Supabase check\n');
  process.stdout.write(config.identitySummary(cfg) + '\n');

  const probe = await api.probeSchema(cfg);
  if (probe.applied !== true) {
    process.stdout.write(api.notAppliedBanner('any table', probe));
    process.stdout.write(`  probe result: ${probe.reason} — ${probe.detail}\n`);
    process.stdout.write('\nTable matrix (remote database state):\n');
    const stateText =
      probe.reason === 'auth'
        ? 'NOT PROBED — request rejected by the project (bad/absent publishable key)'
        : probe.reason === 'network'
        ? 'NOT PROBED — project unreachable from this machine'
        : 'ABSENT (0 tables — migrations 001..006 not applied)';
    for (const t of config.TABLES) {
      process.stdout.write(`${t.padEnd(18)} | ${stateText}\n`);
    }
    process.stdout.write(
      '\nNothing verified. Re-run after the dashboard apply of 001 -> 006 + seed.\n'
    );
    process.stdout.write(
      `SUMMARY schema_report.js matrix: PASS=0 FAIL=0 SKIP=${config.TABLES.length}\n`
    );
    process.exitCode = strict ? 1 : 0;
    return;
  }

  const rows = [];
  for (const table of config.TABLES) {
    const r = await anon.count(table, 'select=*');
    const exists = !(r.status === 404 || (r.error && String(r.error.code) === 'PGRST205'));
    let visible = null;
    let verdict;
    if (!exists) {
      verdict = 'MISSING from schema cache';
    } else if (r.status === 401 || r.status === 403) {
      visible = 0;
      verdict = `RLS/GRANT hard block (HTTP ${r.status}${r.error && r.error.code ? ' ' + r.error.code : ''})`;
    } else if (r.ok) {
      visible = r.total === null ? (r.rows ? r.rows.length : 0) : r.total;
      if (config.ANON_DENIED_READ.includes(table)) {
        verdict =
          visible === 0
            ? 'RLS ACTIVE — anon SELECT returns 0 rows (no anon policy)'
            : `LEAK — anon sees ${visible} rows of a staff-only table`;
      } else if (ANON_EXPECTS_ROWS.has(table)) {
        verdict =
          visible > 0
            ? 'anon-readable (public policy working)'
            : '0 rows to anon — empty table, or RLS filters every row';
      } else {
        verdict = 'anon SELECT allowed by policy — 0 rows expected (see 003)';
      }
    } else {
      verdict = `unexpected HTTP ${r.status}: ${(r.error && r.error.message) || r.raw}`.slice(0, 90);
    }
    rows.push({ table, exists, visible, verdict, status: r.status });
  }

  // RLS evidence that does not require any write: if a staff access token is
  // supplied, the same table is counted again as `authenticated`. anon=0 /
  // staff>0 is a positive proof that RLS is filtering, not that the table is
  // empty. Without a token the script says so instead of guessing.
  const staff = cfg.adminToken ? new api.Api(cfg, cfg.adminToken) : null;
  const staffCounts = {};
  if (staff) {
    for (const table of config.TABLES) {
      const r = await staff.count(table, 'select=*');
      staffCounts[table] = r.ok
        ? (r.total === null ? (r.rows ? r.rows.length : 0) : r.total)
        : `HTTP ${r.status}`;
    }
  }

  const w = Math.max(...rows.map((r) => r.table.length), 'table'.length);
  process.stdout.write('\nTABLE PRESENCE + ANON VISIBILITY MATRIX\n');
  const header =
    `${'table'.padEnd(w)} | exists | anon rows | HTTP |` +
    `${staff ? ' staff rows |' : ''} RLS verdict\n`;
  process.stdout.write(header);
  process.stdout.write(`${'-'.repeat(w + 44)}\n`);
  for (const r of rows) {
    const staffCell = staff ? ` ${String(staffCounts[r.table]).padStart(9)} |` : '';
    process.stdout.write(
      `${r.table.padEnd(w)} | ${(r.exists ? 'yes' : 'NO').padEnd(6)} | ` +
        `${String(r.visible === null ? '-' : r.visible).padStart(9)} | ` +
        `${String(r.status).padStart(4)} |${staffCell} ${r.verdict}\n`
    );
  }

  if (staff) {
    process.stdout.write('\nANON vs STAFF DIVERGENCE (proof that RLS is active, not just empty)\n');
    for (const r of rows) {
      if (!r.exists) continue;
      const s = staffCounts[r.table];
      if (typeof s === 'number' && r.visible !== null && s !== r.visible) {
        process.stdout.write(
          `${r.table.padEnd(w)} | anon=${String(r.visible).padStart(5)} staff=${String(s).padStart(5)} ` +
            `-> RLS FILTERS for anon\n`
        );
      } else if (typeof s === 'number' && r.visible === s && config.ANON_DENIED_READ.includes(r.table)) {
        process.stdout.write(
          `${r.table.padEnd(w)} | anon=${s} staff=${s} -> SUSPICIOUS (identical visibility of a staff-only table)\n`
        );
      }
    }
  } else {
    process.stdout.write(
      '\nNo staff token (SUPABASE_ADMIN_TOKEN) supplied: anon-vs-staff divergence not measured.\n' +
        '   Row-level enforcement itself is asserted by rls_matrix.js.\n'
    );
  }

  process.stdout.write(
    `\nSUMMARY schema_report: ${rows.length} tables probed, ` +
      `${rows.filter((r) => !r.exists).length} missing, ` +
      `${rows.filter((r) => /LEAK/.test(r.verdict)).length} anon-visibility leaks, ` +
      `${rows.filter((r) => /RLS ACTIVE/.test(r.verdict)).length} tables confirmed ` +
      `hidden from anon, ${rows.filter((r) => /anon-readable/.test(r.verdict)).length} ` +
      `tables confirmed anon-readable.\n`
  );
  // Report-shaped tally so run_all can aggregate this matrix suite too.
  const leakCount = rows.filter((r) => /LEAK/.test(r.verdict)).length;
  const missingCount = rows.filter((r) => !r.exists).length;
  const ambiguous = rows.filter((r) =>
    /empty table, or RLS filters|unexpected HTTP|0 rows expected \(see 003\)/.test(r.verdict)
  ).length;
  const passCount = rows.length - leakCount - missingCount - ambiguous;
  process.stdout.write(
    `SUMMARY schema_report.js matrix: PASS=${Math.max(passCount, 0)} FAIL=${leakCount + missingCount} SKIP=${ambiguous}\n`
  );
  if (args.includes('--json')) {
    process.stdout.write(
      JSON.stringify({ rows, staffCounts: staff ? staffCounts : null }, null, 2) + '\n'
    );
  }
  // An applied schema with a leak or a missing table is a real FAIL: exit 1
  // in both strict and default mode (same convention as seed_counts/rls_matrix
  // and what run_all's aggregate expects). --strict only changes the meaning
  // of the earlier "NOT APPLIED YET" path.
  process.exitCode = leakCount + missingCount > 0 ? 1 : 0;
}

main().catch((e) => {
  process.stderr.write('schema_report.js crashed: ' + config.redact(e.stack || e.message, []) + '\n');
  process.exitCode = 2;
});
