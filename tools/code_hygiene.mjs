#!/usr/bin/env node
// Measures copy-pasted blocks in lib/ and lib files that nothing reaches any more.
//
//   node tools/code_hygiene.mjs              print the report, write JSON to build/code_hygiene.json
//   node tools/code_hygiene.mjs --check      also exit 1 if either number rose above the baseline
//   node tools/code_hygiene.mjs --update-baseline   lower the baseline to today's numbers
//
// The baseline is a ratchet: --check fails on growth, never on the existing backlog, and
// --update-baseline refuses to raise it.

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, posix, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const BASELINE = join(ROOT, 'tools', 'code_hygiene_baseline.json');
const OUT_DIR = join(ROOT, 'build', 'code_hygiene');
// Pinned: a floating version would let a new upstream release change the counts the
// ratchet compares against.
const JSCPD = 'jscpd@5.3.3';
const PACKAGE = 'butlery';
const ENTRY_POINTS = ['lib/main.dart', 'lib/admin_main.dart'];
const GENERATED = /\.(g|freezed|mocks|gr|config)\.dart$|^lib\/l10n\//;
const SEARCH_ROOTS = ['lib', 'test', 'integration_test', 'tools', 'test_driver'];

const args = new Set(process.argv.slice(2));
const toPosix = (p) => p.split('\\').join('/');

function walk(dir) {
  const abs = join(ROOT, dir);
  if (!existsSync(abs)) return [];
  const out = [];
  for (const name of readdirSync(abs)) {
    const rel = posix.join(dir, name);
    const st = statSync(join(ROOT, rel));
    if (st.isDirectory()) out.push(...walk(rel));
    else if (name.endsWith('.dart')) out.push(rel);
  }
  return out;
}

// import / export / part directives, including every branch of a conditional import.
const DIRECTIVE = /^\s*(?:import|export|part)\s+((?:'[^']*'|"[^"]*"|[^;])*);/gm;
const URI = /'([^']*)'|"([^"]*)"/g;

function targetsOf(file, source) {
  const targets = [];
  for (const m of source.matchAll(DIRECTIVE)) {
    if (/^\s*part\s+of\b/.test(m[0])) continue;
    for (const u of m[1].matchAll(URI)) {
      const uri = u[1] ?? u[2];
      if (uri.startsWith(`package:${PACKAGE}/`)) {
        targets.push(`lib/${uri.slice(PACKAGE.length + 9)}`);
      } else if (!uri.includes(':')) {
        targets.push(posix.normalize(posix.join(posix.dirname(file), uri)));
      }
    }
  }
  return targets;
}

function deadCode() {
  const files = SEARCH_ROOTS.flatMap(walk);
  const edges = new Map();
  for (const f of files) edges.set(f, targetsOf(f, readFileSync(join(ROOT, f), 'utf8')));

  const reach = (starts) => {
    const seen = new Set();
    const stack = [...starts];
    while (stack.length) {
      const f = stack.pop();
      if (seen.has(f) || !edges.has(f)) continue;
      seen.add(f);
      stack.push(...edges.get(f));
    }
    return seen;
  };

  const fromApp = reach(ENTRY_POINTS);
  const fromAnything = reach(files.filter((f) => !f.startsWith('lib/')));
  const libFiles = files.filter((f) => f.startsWith('lib/') && !GENERATED.test(f));
  const unreachable = libFiles.filter((f) => !fromApp.has(f));
  return {
    // Nothing imports these at all — not the app, not a test, not a tool.
    orphans: unreachable.filter((f) => !fromAnything.has(f)).sort(),
    // Only tests or tools keep these alive; the shipped app never loads them.
    testOnly: unreachable.filter((f) => fromAnything.has(f)).sort(),
  };
}

function duplicates() {
  rmSync(OUT_DIR, { recursive: true, force: true });
  mkdirSync(OUT_DIR, { recursive: true });
  const npx = process.platform === 'win32' ? 'npx.cmd' : 'npx';
  execFileSync(npx, [
    '--yes', JSCPD, 'lib',
    '--format', 'dart',
    '--min-lines', '12',
    '--min-tokens', '80',
    '--ignore', '**/*.g.dart,**/*.freezed.dart,**/*.mocks.dart,**/l10n/**',
    '--reporters', 'json',
    '--output', OUT_DIR,
    '--silent',
  ], { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'], shell: process.platform === 'win32' });
  const report = JSON.parse(readFileSync(join(OUT_DIR, 'jscpd-report.json'), 'utf8'));
  const clones = report.duplicates
    .map((d) => ({
      lines: d.lines,
      a: `${posix.join('lib', toPosix(d.firstFile.name))}:${d.firstFile.start}`,
      b: `${posix.join('lib', toPosix(d.secondFile.name))}:${d.secondFile.start}`,
    }))
    .sort((x, y) => y.lines - x.lines);
  return { duplicatedLines: report.statistics.total.duplicatedLines, clones };
}

const dead = deadCode();
const dup = duplicates();
const measured = {
  duplicatedLines: dup.duplicatedLines,
  cloneCount: dup.clones.length,
  orphanFiles: dead.orphans.length,
  testOnlyFiles: dead.testOnly.length,
};

mkdirSync(join(ROOT, 'build'), { recursive: true });
writeFileSync(join(ROOT, 'build', 'code_hygiene.json'),
  JSON.stringify({ measured, orphans: dead.orphans, testOnly: dead.testOnly, clones: dup.clones }, null, 2));

console.log(`Duplicerade rader: ${measured.duplicatedLines} i ${measured.cloneCount} kopierade block`);
console.log(`Filer som inget importerar: ${measured.orphanFiles}`);
console.log(`Filer som bara tester/verktyg använder: ${measured.testOnlyFiles}`);
for (const c of dup.clones.slice(0, 5)) console.log(`  ${c.lines} rader  ${c.a}  ≈  ${c.b}`);
for (const f of dead.orphans.slice(0, 5)) console.log(`  oanvänd: ${f}`);

const baseline = existsSync(BASELINE) ? JSON.parse(readFileSync(BASELINE, 'utf8')) : null;

if (args.has('--update-baseline')) {
  const next = { ...measured };
  if (baseline) {
    for (const k of Object.keys(next)) next[k] = Math.min(next[k], baseline[k] ?? next[k]);
  }
  writeFileSync(BASELINE, `${JSON.stringify(next, null, 2)}\n`);
  console.log(`Baslinjen skriven: ${JSON.stringify(next)}`);
}

if (args.has('--check')) {
  if (!baseline) {
    console.error('Ingen baslinje — kör med --update-baseline först.');
    process.exit(1);
  }
  const grew = ['duplicatedLines', 'orphanFiles', 'testOnlyFiles'].filter((k) => measured[k] > baseline[k]);
  if (grew.length) {
    for (const k of grew) console.error(`ÖKADE: ${k} ${baseline[k]} → ${measured[k]}`);
    console.error('Återanvänd den befintliga koden i stället för att kopiera den, eller radera det som inte används. '
      + 'Detaljer: build/code_hygiene.json. Om ökningen är avsiktlig (t.ex. en ny fil som kopplas in i nästa commit), '
      + 'säg det i commit-meddelandet och höj inte baslinjen för hand.');
    process.exit(1);
  }
  console.log('Inga ökningar jämfört med baslinjen.');
}
