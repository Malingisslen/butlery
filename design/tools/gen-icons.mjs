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
const before = readFileSync('icons.json', 'utf8');
// REPRODUCERBARHET (Fas 1, andra vändan): generatorn skrev counts med andra
// nyckelnamn än filen bar (ui_glyphs i stället för ui), tappade lint.note och
// stämplade dagens datum. Varje körning ändrade alltså icons.json, vilket gav
// manifestdrift på FÖRSTA körningen av en nyuppackad leverans och skilda utdata
// på andra. Nu uppdateras befintliga nycklar PÅ PLATS, datumet kommer ur
// tokens.json (samma källa som generatorernas headrar, och fältet heter numera
// source_date — det påstod tidigare en klocktid det inte hade) och filen skrivs bara om
// innehållet faktiskt ändrats.
const DATE = JSON.parse(readFileSync('tokens.json', 'utf8')).date;
const used = new Map();
for (const doc of DOCS) {
  if (!existsSync(doc)) continue;
  for (const m of readFileSync(doc, 'utf8').matchAll(/data-icon="([a-z0-9-]+)"/g))
    used.set(m[1], (used.get(m[1]) ?? 0) + 1);
}
const known = new Set();
for (const fam of ['ui_family', 'nav_family'])
  for (const g of icons[fam]) { g.usages = used.get(g.name) ?? 0; known.add(g.name); }

const usedGlyphs = [...known].filter(n => (used.get(n) ?? 0) > 0).length;
icons.counts.ui = icons.ui_family.length;
icons.counts.nav = icons.nav_family.length;
icons.counts.total = icons.ui_family.length + icons.nav_family.length;
icons.counts.used = usedGlyphs;
icons.counts.source_date = DATE;
icons.lint.unknown_icon_names = [...used.keys()].filter(n => !known.has(n)).sort();
icons.lint.source_date = DATE;

const after = JSON.stringify(icons, null, 2) + '\n';
const changed = after !== before;
if (changed) writeFileSync('icons.json', after);
console.log(`usages uppdaterade för ${known.size} glyfer · okända: ${icons.lint.unknown_icon_names.join(', ') || 'inga'} · icons.json ${changed ? 'skriven (innehållet ändrades)' : 'oförändrad — byteidentisk'}`);
