#!/usr/bin/env node
// Butlery · räknar om icons.json → usages ur dokumentens data-icon-attribut.
// Kör: node tools/gen-icons.mjs   (usages redigeras aldrig för hand)
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { ICON_SOURCE_FILES } from './screen-files.mjs';

// Beslutsunderlag (Butlery beslut *.dc.html) räknas AVSIKTLIGT inte: de är
// mockar för att jämföra alternativ, inte spec. Det valda alternativet ritas om
// som riktiga ramar i skärmfilen och räknas då.
// Kanoniskt scope — delas med lint-core (T-06). Se tools/screen-files.mjs.
const DOCS = ICON_SOURCE_FILES;
const icons = JSON.parse(readFileSync('icons.json', 'utf8'));
const used = new Map();
for (const doc of DOCS) {
  if (!existsSync(doc)) continue;
  for (const m of readFileSync(doc, 'utf8').matchAll(/data-icon="([a-z0-9-]+)"/g))
    used.set(m[1], (used.get(m[1]) ?? 0) + 1);
}
const known = new Set();
for (const fam of ['ui_family', 'nav_family'])
  for (const g of icons[fam]) { g.usages = used.get(g.name) ?? 0; known.add(g.name); }
icons.counts = { ui_glyphs: icons.ui_family.length, nav_glyphs: icons.nav_family.length, diet_glyphs: 0 };
icons.lint = { unknown_icon_names: [...used.keys()].filter(n => !known.has(n)), generated: new Date().toISOString().slice(0, 10) };
writeFileSync('icons.json', JSON.stringify(icons, null, 2));
console.log(`usages uppdaterade för ${known.size} glyfer · okända: ${icons.lint.unknown_icon_names.join(', ') || 'inga'}`);
