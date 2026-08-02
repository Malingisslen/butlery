#!/usr/bin/env node
// Butlery · manifestkontroll. Reporot = paketroten (fas0/..).
// Kontrollerar tre saker, och alla tre fäller:
//   1 hash per listad post   2 SET-LIKHET mot en kanoniskt genererad fillista
//   3 manifestets egen integritet (deklarerat antal, dubbletter, tom parsning)
// Kör: node fas0/check-manifest.mjs
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { createHash } from 'node:crypto';
// GEMENSAM parser och sökvägsupplösning — samma som verifieraren och grinden
// använder för fingeravtrycket. Fas 0.15: tre implementationer kunde glida isär.
import { manifestEntries, resolveEntry } from '../tools/report-logic.mjs';
import { join, relative } from 'node:path';

// LÄGE: repo = fristående checkout (leveransytan får saknas) · delivery = uppackad
// ZIP (varje zip:/-post är obligatorisk). Auto: delivery om NÅGON leveransfil
// finns. Utan detta godkändes en ZIP där support.js — som alla tre HTML-dokument
// laddar — hade tagits bort. Fas 0.9.
const argMode = (process.argv.find(a => a.startsWith('--mode=')) || '').split('=')[1];
let MODE = argMode || process.env.BUTLERY_MANIFEST_MODE || 'auto';
// EXAKT läge. '--mode=deliveri' accepterades tidigare och godkände en leverans
// där support.js saknades. Fas 0.10: allt utanför listan är ett hårt fel.
if (!['auto', 'repo', 'delivery'].includes(MODE)) {
  console.error('✖ okänt manifestläge "' + MODE + '" — tillåtna: auto, repo, delivery');
  process.exit(2);
}
const MD = 'fas0/andrade-filer.md';
if (!existsSync(MD)) { console.error('✖ manifest saknas: ' + MD); process.exit(1); }
const md = readFileSync(MD, 'utf8');

// Kanonisk fillista: varje text- och kodartefakt i reporoten. Binärer och
// genererade rapporter undantas uttryckligen och namngivet.
// SVG i reporotens topp (appikoner) räknas som artefakter; SVG i assets/ och
// exports/ är binärlika leveranser och undantas med katalogregeln nedan.
const TEXT = /\.(md|json|mjs|js|jsx|dart|css|txt|ya?ml|dc\.html|html|svg)$/i;
const SKIP_DIRS = new Set(['node_modules', '.git', 'assets', 'exports', 'Butlery-lockup-family-L4-3']);
// Genererade artefakter. Fas 0.11: manifestet SA att ci-evidence.json var
// undantagen men checkern undantog den inte, så CI-körningen fällde set-likheten.
const SKIP_FILES = new Set(['fas0/verify.log', 'fas0/manifest.log', 'fas0/verify-report.json',
  'fas0/kontrollstatus.md', 'fas0/andrade-filer.md', 'fas0/ci-evidence.json', 'fas0/verify-exit', '.thumbnail']);
const walk = (dir, acc = []) => {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    const rel = relative('.', p);
    if (statSync(p).isDirectory()) { if (!SKIP_DIRS.has(e)) walk(p, acc); continue; }
    if (!TEXT.test(e) || SKIP_FILES.has(rel)) continue;
    acc.push(rel);
  }
  return acc;
};
const onDisk = new Set(walk('.').map(p => p.split('\\').join('/')));

const expected = Number((md.match(/<!--manifest:files=(\d+)-->/) || [])[1] || 0);
let parsed = 0, ok = 0, bad = 0, missing = 0, dup = 0, outside = 0, outsideFound = 0;
const seen = new Set(), listed = new Set();
// GEMENSAM parser. Fas 0.15: tre implementationer läste manifestet — checkern,
// verifieraren och grinden — och kunde glida isär. Nu används manifestEntries()
// och resolveEntry() ur tools/report-logic.mjs överallt.
for (const e of manifestEntries(md)) {
  const path = e.key, want = e.sha256;
  parsed++;
  if (seen.has(path)) { console.error('✖ dubbel manifestpost: ' + path); dup++; continue; }
  seen.add(path);
  if (e.outside) {
    const p = resolveEntry(e);
    if (!existsSync(p)) { console.log('· utanför reporoten, ej närvarande: ' + path); outside++; continue; }
    outsideFound++;
    const got = createHash('sha256').update(readFileSync(p)).digest('hex');
    if (got === want) ok++; else { console.error('✖ hash (utanför repot): ' + path); bad++; }
    continue;
  }
  listed.add(path);
  if (!existsSync(path)) { console.error('✖ saknas: ' + path); missing++; continue; }
  const got = createHash('sha256').update(readFileSync(path)).digest('hex');
  if (got === want) ok++;
  else { console.error('✖ hash: ' + path + '\n    manifest: ' + want + '\n    fil:      ' + got); bad++; }
}

// SET-LIKHET: en fil som finns men inte är listad är lika allvarlig som en
// listad fil som saknas. Utan detta kan en utelämnad fil döljas genom att
// sänka det deklarerade antalet.
const unlisted = [...onDisk].filter(p => !listed.has(p)).sort();
for (const p of unlisted) console.error('✖ olistad artefakt i reporoten: ' + p);

// Auto-läge: finns någon leveransfil är detta en uppackad ZIP, och då krävs alla.
// LEVERANSMARKÖR. Fas 0.11: auto valde repo när ALLA sex zip:/-filer saknades,
// så en tömd leverans gav exit 0. Nu avgör en markörfil i ZIP-roten, inte hur
// många filer som råkar finnas.
if (MODE === 'auto') {
  const marker = ['../../../fas0/DELIVERY', '../../../fas0/LAS-MIG.md'].find(p => existsSync(p));
  MODE = marker ? 'delivery' : (outsideFound > 0 ? 'delivery' : 'repo');
  if (marker) console.log('· leveransmarkör funnen (' + marker.replace(/^(\.\.\/)+/, 'zip:/') + ') → delivery-läge');
}
console.log('MANIFEST-MODE ' + MODE + ' (leveransfiler funna: ' + outsideFound + ' av ' + (outsideFound + outside) + ')');
console.log('MANIFEST-SUMMARY mode=' + MODE + ' expected=' + expected + ' parsed=' + parsed + ' ok=' + ok + ' bad=' + bad + ' missing=' + missing +
  ' duplicates=' + dup + ' unlisted=' + unlisted.length + ' outside_absent=' + outside + ' expected=' + expected + ' ondisk=' + onDisk.size);

let fail = 0;
if (!expected) { console.error('✖ manifestet saknar <!--manifest:files=N--> — antalet kan inte kontrolleras'); fail = 1; }
if (parsed === 0) { console.error('✖ manifestet parsade noll rader'); fail = 1; }
if (expected && parsed !== expected) { console.error('✖ deklarerat ' + expected + ' poster, läste ' + parsed); fail = 1; }
if (bad || missing || dup || unlisted.length) fail = 1;
if (MODE === 'delivery' && outside) {
  console.error('✖ delivery-läge: ' + outside + ' obligatorisk leveransfil saknas — i en uppackad ZIP är varje zip:/-post krävd');
  fail = 1;
}
if (ok + outside !== parsed) { console.error('✖ verified ' + ok + ' + outsideAbsent ' + outside + ' ≠ parsed ' + parsed); fail = 1; }
// Rapportspråk: 'parsed' är inte 'verified'.
console.log(fail
  ? '✖ manifestkontroll underkänd · parsed=' + parsed + ' verified=' + ok + ' bad=' + bad + ' missing=' + missing + ' duplicates=' + dup + ' unlisted=' + unlisted.length + ' outsideAbsent=' + outside
  : '✔ manifest: ' + ok + ' av ' + parsed + ' poster verifierade · set-likhet mot ' + onDisk.size + ' artefakter');
process.exit(fail);
