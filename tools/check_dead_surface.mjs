#!/usr/bin/env node
// Finds surface that nothing uses any more: ARB strings and public methods.
// Unreferenced files are tools/code_hygiene.mjs's job.
//
//   node tools/check_dead_surface.mjs                 print both lists
//   node tools/check_dead_surface.mjs --check         exit 1 if a NEW ARB key is unused
//   node tools/check_dead_surface.mjs --update-baseline   forget keys that are used again
//   node tools/check_dead_surface.mjs --root <dir>    measure another checkout (e.g. a worktree)
//   node tools/check_dead_surface.mjs --all           list every finding, not the first 20 methods
//
// Only the ARB half can fail a build: a key is a unique string, so "no identifier of that
// name in lib/" is exact. The method half is a name match and reports only; it cannot see a
// method that is called solely from other dead code, which looks used until that code goes.
// A method that is used through a dynamic call, or kept for a future caller, goes in
// METHOD_ALLOW with the reason.

import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const argv = process.argv.slice(2);
const flag = (name) => argv.includes(name);
const rootArg = argv.indexOf('--root');
const ROOT = rootArg >= 0
  ? resolve(argv[rootArg + 1])
  : resolve(dirname(fileURLToPath(import.meta.url)), '..');
const baselineArg = argv.indexOf('--baseline');
const BASELINE = baselineArg >= 0
  ? resolve(argv[baselineArg + 1])
  : join(dirname(fileURLToPath(import.meta.url)), 'dead_surface_baseline.json');

const GENERATED = /\.(g|freezed|mocks|gr|config)\.dart$/;

// name -> why it is allowed to have no caller.
const METHOD_ALLOW = new Map([
  // Entry points the framework or a package calls by name.
  ['main', 'entry point'],
  ['build', 'Flutter framework'],
  ['dispose', 'Flutter framework'],
  ['createState', 'Flutter framework'],
  ['initState', 'Flutter framework'],
  ['didChangeDependencies', 'Flutter framework'],
  ['didUpdateWidget', 'Flutter framework'],
  ['toString', 'Dart core'],
  ['noSuchMethod', 'Dart core'],
  ['fromJson', 'json_serializable calls it from generated code'],
  ['toJson', 'json_serializable calls it from generated code'],
]);

function walk(dir, skip = () => false) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (skip(p)) continue;
    if (statSync(p).isDirectory()) out.push(...walk(p, skip));
    else if (name.endsWith('.dart')) out.push(p);
  }
  return out;
}

const rel = (p) => p.slice(ROOT.length + 1).split('\\').join('/');
const read = (p) => readFileSync(p, 'utf8');
const identifiers = (src) => src.match(/[A-Za-z_$][A-Za-z0-9_$]*/g) ?? [];

const libFiles = walk(join(ROOT, 'lib'), (p) => p.split('\\').join('/').endsWith('/lib/l10n'))
  .filter((p) => !GENERATED.test(p));
const sources = new Map(libFiles.map((f) => [f, read(f)]));

function unusedArbKeys() {
  const arb = JSON.parse(read(join(ROOT, 'lib', 'l10n', 'app_sv.arb')));
  const used = new Set();
  for (const src of sources.values()) for (const id of identifiers(src)) used.add(id);
  // "@key" metadata belongs to its key, so it never counts as a key of its own.
  return Object.keys(arb).filter((k) => !k.startsWith('@') && !used.has(k)).sort();
}

// A member declared at class indent: optional modifiers/return type, a lower-case name, "(".
// Constructors are capitalised, so they fall out; "_x" is private and already caught by the
// analyzer's unused_element.
const MEMBER = /^ {2}(?=\S)(?:static\s+)?([\w<>?,.]+\s+(?:[\w<>?,.]+\s+)*?)([a-z]\w*)\s*(?:<[^>(]*>)?\(/;
// A call statement at the same indent has no type in front of it, or a keyword.
const STATEMENT = /^(?:await|return|throw|yield|else|new|const|final|var|late|case)\s/;
const NOT_A_METHOD = /^(?:if|for|while|switch|return|await|else|catch|assert)$/;
const TYPE_HEADER = /^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+)*(?:class|mixin|extension(?:\s+type)?|enum)\s+(\w+)([^{;]*)/;

// Without type resolution a bare name match would clear `blockUser` because some service
// also has one. So a member counts as used only in a file that also names the type that
// declares it, or a subtype, mixin user or implementer of it.
function typeGraph() {
  const subtypes = new Map();
  for (const src of sources.values()) {
    for (const line of src.split('\n')) {
      const h = TYPE_HEADER.exec(line);
      if (!h) continue;
      const parents = (h[2].match(/\b[A-Z]\w*/g) ?? []).filter((n) => n !== h[1]);
      for (const parent of parents) {
        if (!subtypes.has(parent)) subtypes.set(parent, new Set());
        subtypes.get(parent).add(h[1]);
      }
    }
  }
  const closure = (type) => {
    const seen = new Set([type]);
    const stack = [type];
    while (stack.length) {
      for (const sub of subtypes.get(stack.pop()) ?? []) {
        if (!seen.has(sub)) { seen.add(sub); stack.push(sub); }
      }
    }
    return seen;
  };
  return closure;
}

function unreferencedMethods() {
  const closure = typeGraph();
  const idsByFile = new Map([...sources].map(([f, src]) => [f, identifiers(src)]));
  const sets = new Map([...idsByFile].map(([f, ids]) => [f, new Set(ids)]));
  const found = [];
  for (const [file, src] of sources) {
    const lines = src.split('\n');
    let owner = null;
    lines.forEach((line, i) => {
      const h = TYPE_HEADER.exec(line);
      if (h) owner = h[1];
      else if (/^[}\w]/.test(line) && !TYPE_HEADER.test(line)) owner = null;
      const m = MEMBER.exec(line);
      if (!m || !owner) return;
      const name = m[2];
      if (STATEMENT.test(m[1]) || NOT_A_METHOD.test(name) || METHOD_ALLOW.has(name)) return;
      if (/^\s*\/\//.test(line)) return;
      let prev = i - 1;
      while (prev >= 0 && /^\s*@/.test(lines[prev])) {
        if (/^\s*@override\b/.test(lines[prev])) return;
        prev--;
      }
      const types = closure(owner);
      const own = idsByFile.get(file).filter((id) => id === name).length;
      if (own > 1) return;
      for (const [other, set] of sets) {
        if (other === file || !set.has(name)) continue;
        for (const t of types) if (set.has(t)) return;
      }
      found.push(`${rel(file)}:${i + 1}  ${owner}.${name}`);
    });
  }
  return found.sort();
}

const arbKeys = unusedArbKeys();
const methods = unreferencedMethods();

console.log(`ARB-nycklar utan referens i lib/: ${arbKeys.length}`);
console.log(`Publika metoder utan anropare (rapport, fäller inte): ${methods.length}`);
if (flag('--all')) for (const k of arbKeys) console.log(`  arb: ${k}`);
for (const m of flag("--all") ? methods : methods.slice(0, 20)) console.log(`  ${m}`);

const baseline = existsSync(BASELINE) ? JSON.parse(readFileSync(BASELINE, 'utf8')) : { arbKeys: [] };
const known = new Set(baseline.arbKeys);

if (flag('--update-baseline')) {
  // Ratchet: the list may shrink, never grow, so a new dead key cannot be hidden here.
  const next = arbKeys.filter((k) => known.has(k) || !existsSync(BASELINE));
  writeFileSync(BASELINE, `${JSON.stringify({ arbKeys: next }, null, 2)}\n`);
  console.log(`Baslinjen skriven: ${next.length} nycklar`);
}

if (flag('--check')) {
  const fresh = arbKeys.filter((k) => !known.has(k));
  if (fresh.length) {
    console.error(`NYA oanvända ARB-nycklar (${fresh.length}):`);
    for (const k of fresh) console.error(`  ${k}`);
    console.error('Radera nyckeln ur app_sv.arb och app_en.arb, eller använd den. '
      + 'Rör inte baslinjen för hand: den får bara krympa.');
    process.exit(1);
  }
  const used = baseline.arbKeys.filter((k) => !arbKeys.includes(k));
  if (used.length) {
    console.log(`${used.length} nycklar i baslinjen används igen — kör --update-baseline.`);
  }
  console.log('Inga nya oanvända ARB-nycklar.');
}
