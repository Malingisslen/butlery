#!/usr/bin/env node
// Flags widget tests that pull one of OUR widgets back out of the tree and assert on its
// constructor props without ever asserting on anything that rendered.
//
//   node tools/check_prop_only_widget_tests.mjs            print the list
//   node tools/check_prop_only_widget_tests.mjs --check    exit 1 if a test joined the list
//   node tools/check_prop_only_widget_tests.mjs --update-baseline   forget tests that no longer match
//
// Why: BUT-1780 said allergen badges never appear on recipe cards. Three tests built a
// ContentCard, took the RecipeCard out of the tree and asserted `showAllergenBadges`; they
// stayed green while no badge was ever drawn, because the prop was set and nothing read it.
// The same test reads naturally for a framework widget (a Container's decoration IS what
// paints), so only widgets declared in lib/ count.
//
// A test that really is about a prop (a callback, a route) says so with a
// `// props-only: <why>` line in its body, 10+ characters. The existing backlog sits in
// tools/prop_only_widget_tests_baseline.json and may only shrink.
//
// It cannot see a test that renders something unrelated and also asserts a prop, or a
// helper that hides the read; both look fine.

import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const argv = process.argv.slice(2);
const flag = (name) => argv.includes(name);
const rootArg = argv.indexOf('--root');
const TOOLS = dirname(fileURLToPath(import.meta.url));
const ROOT = rootArg >= 0 ? resolve(argv[rootArg + 1]) : resolve(TOOLS, '..');
const baselineArg = argv.indexOf('--baseline');
const BASELINE = baselineArg >= 0
  ? resolve(argv[baselineArg + 1])
  : join(TOOLS, 'prop_only_widget_tests_baseline.json');

const WAIVER = /\/\/[ \t]*props-only:[ \t]*\S.{8,}/;
// Anything that asserts on what was drawn or announced.
const RENDER_ASSERTION = new RegExp([
  String.raw`expect\(\s*find\.`,
  String.raw`expect\(\s*tester\.getSemantics`,
  String.raw`expectLater\(`,
  String.raw`matchesGoldenFile`,
  String.raw`\bfinds(?:OneWidget|Widgets|NWidgets|Nothing|AtLeastNWidgets)\b`,
].join('|'));

function walk(dir, keep) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p, keep));
    else if (keep(name)) out.push(p);
  }
  return out;
}

const rel = (p) => p.slice(ROOT.length + 1).split('\\').join('/');

function ourWidgets() {
  const names = new Set();
  for (const f of walk(join(ROOT, 'lib'), (n) => n.endsWith('.dart'))) {
    const src = readFileSync(f, 'utf8');
    for (const m of src.matchAll(/^class\s+(\w+)\s+extends\s+(?:Stateless|Stateful|Consumer|Inherited)\w*Widget/gm)) {
      names.add(m[1]);
    }
  }
  return names;
}

function bodyAfter(src, from) {
  const open = src.indexOf('{', from);
  let depth = 0;
  for (let i = open; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}' && --depth === 0) return src.slice(open, i);
  }
  return src.slice(open);
}

function findings() {
  const widgets = ourWidgets();
  const found = [];
  for (const f of walk(join(ROOT, 'test'), (n) => n.endsWith('_test.dart'))) {
    const src = readFileSync(f, 'utf8');
    const header = /testWidgets\(\s*(['"])((?:\\.|(?!\1).)*)\1/g;
    for (let m; (m = header.exec(src));) {
      const body = bodyAfter(src, m.index + m[0].length);
      const readsOurs = [...body.matchAll(/\.(?:widget|firstWidget)<(\w+)>/g)].some((x) => widgets.has(x[1]));
      if (!readsOurs || RENDER_ASSERTION.test(body) || WAIVER.test(body)) continue;
      found.push(`${rel(f)} :: ${m[2]}`);
    }
  }
  return found.sort();
}

const current = findings();
const baseline = existsSync(BASELINE) ? JSON.parse(readFileSync(BASELINE, 'utf8')).tests : [];

// Multiset difference: two tests with one name in one file are two entries.
function minus(a, b) {
  const left = new Map();
  for (const k of b) left.set(k, (left.get(k) ?? 0) + 1);
  return a.filter((k) => {
    const n = left.get(k) ?? 0;
    if (n > 0) { left.set(k, n - 1); return false; }
    return true;
  });
}

console.log(`Widgettest som bara läser rekvisita ur våra egna widgets: ${current.length}`);
if (flag('--all')) for (const k of current) console.log(`  ${k}`);

if (flag('--update-baseline')) {
  const next = existsSync(BASELINE) ? minus(current, minus(current, baseline)) : current;
  writeFileSync(BASELINE, `${JSON.stringify({ tests: next }, null, 2)}\n`);
  console.log(`Baslinjen skriven: ${next.length} test`);
}

if (flag('--check')) {
  const fresh = minus(current, baseline);
  if (fresh.length) {
    console.error(`NYA widgettest som bara läser rekvisita (${fresh.length}):`);
    for (const k of fresh) console.error(`  ${k}`);
    console.error('Ett test som tar en av våra widgets ur trädet och kollar dess rekvisita visar att '
      + 'värdet sattes, inte att något ritades. Lägg till en assert på det som syns '
      + '(expect(find.…), tester.getSemantics eller en golden). Handlar testet på riktigt om '
      + 'rekvisitan (en callback, en rutt) skriv `// props-only: <varför>` i testet. '
      + 'Rör inte baslinjen för hand: den får bara krympa.');
    process.exit(1);
  }
  console.log('Inga nya prop-bara widgettest.');
}
