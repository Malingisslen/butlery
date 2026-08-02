#!/usr/bin/env node
// Butlery · PREFLIGHT — körs FÖRE generatorerna. Kör: node tools/preflight.mjs
//
// Rollfördelning (Fas 0.9):
//   preflight (GEN-02) · är de INCHECKADE genererade filerna aktuella?
//   T-15               · stämmer den GENERERADE outputens header med indexet?
//   GEN-01             · ändrade körningen någon incheckad fil?
// T-15 kunde inte se 1.3/1.4-headerarna eftersom den körs efter generatorerna —
// då är de redan omskrivna. Den driften hör hit.
import { readFileSync, existsSync } from 'node:fs';

const tokens = JSON.parse(readFileSync('tokens.json', 'utf8'));
const want = tokens.version;
const FILES = ['assets/generated/tokens.css', 'lib/theme/butlery_tokens.dart'];
let fail = 0, checked = 0;

for (const f of FILES) {
  if (!existsSync(f)) { console.error('✖ GEN-02  ' + f + ' finns inte'); fail++; continue; }
  const head = readFileSync(f, 'utf8').split('\n').slice(0, 12).join('\n');
  const got = (head.match(/^[^\n]*\btokens\s+v?(\d+\.\d+(?:\.\d+)?)/im) || [])[1] || null;
  checked++;
  if (!got) { console.error('✖ GEN-02  ' + f + ': headern saknar en läsbar "tokens <version>"-rad'); fail++; continue; }
  if (got !== want) { console.error('✖ GEN-02  ' + f + ' är genererad ur tokens ' + got + ' men tokens.json är ' + want + ' — den incheckade filen är stale'); fail++; }
  else console.log('✔ GEN-02  ' + f + ' · tokens ' + got);
}

console.log('PREFLIGHT-SUMMARY checked=' + checked + ' stale=' + fail + ' tokens=' + want);
process.exit(fail ? 1 : 0);
