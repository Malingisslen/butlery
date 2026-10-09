#!/usr/bin/env node
// Butlery · sync-icon-paths.mjs — skriver om varje inline-glyf i dokumenten så att
// dess bana kommer UR masterfilen i assets/icons/. Kör: node tools/sync-icon-paths.mjs
//
// Varför den finns: granskningen 2026-07-27 hittade glyfer som var ritade ur
// minnet — `users` visade två personer där mastern har tre, `message-square` en
// kantig bubbla utan punkter där mastern har en rundad med tre. Namnet stämde,
// alltså rapporterade gen-icons "noll okända ikonnamn", men ritningen visade en
// annan ikon än inventeringen. `icons.json` är normativ enligt manualen; då måste
// banan komma från mastern och inte från en hjälpfunktion i ett skript.
//
// Öppningstaggen lämnas orörd (storlek, stroke-färg, stroke-bredd — täta ytor får
// 2,2 enligt ikonregeln). Bara innehållet byts.
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { DOCS } from './lint-core.mjs';

const MASTER_DIR = 'assets/icons';

const master = {};
for (const file of readdirSync(MASTER_DIR)) {
  if (!file.endsWith('.svg')) continue;
  const src = readFileSync(`${MASTER_DIR}/${file}`, 'utf8');
  master[file.replace('.svg', '')] = src
    .replace(/<svg[^>]*>/, '')
    .replace(/<\/svg>\s*$/, '')
    .replace(/<title>[\s\S]*?<\/title>/, '')
    .replace(/\s+/g, ' ')
    .trim();
}

const missing = new Set();
let total = 0;
let synced = 0;

for (const doc of DOCS) {
  if (!existsSync(doc)) continue;
  const before = readFileSync(doc, 'utf8');
  let n = 0;
  const after = before.replace(
    /(<svg\b[^>]*data-icon="([a-z0-9-]+)"[^>]*>)([\s\S]*?)(<\/svg>)/g,
    (m, open, name, inner, close) => {
      total++;
      if (!(name in master)) { missing.add(name); return m; }
      if (inner.replace(/\s+/g, ' ').trim() === master[name]) return m;
      n++; synced++;
      return open + master[name] + close;
    },
  );
  if (n) writeFileSync(doc, after);
  console.log(`${doc}: ${n} glyf(er) synkade`);
}

console.log(`\n${synced} av ${total} inline-glyfer skrivna om ur master.`);
if (missing.size) {
  console.error('✖ glyfnamn utan master i ' + MASTER_DIR + ': ' + [...missing].join(', '));
  console.error('  Rita mastern först — en glyf utan master går inte att verifiera.');
  process.exit(1);
}
