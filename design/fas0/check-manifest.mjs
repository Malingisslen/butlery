#!/usr/bin/env node
// Butlery · manifestkontroll. Reporot = paketroten (fas0/..).
// Kontrollerar tre saker, och alla tre fäller:
//   1 hash per listad post   2 SET-LIKHET mot en kanoniskt genererad fillista
//   3 manifestets egen integritet (deklarerat antal, dubbletter, tom parsning)
// Kör: node fas0/check-manifest.mjs
import { readFileSync, existsSync, readdirSync, statSync, lstatSync, realpathSync } from 'node:fs';
import { createHash } from 'node:crypto';
// GEMENSAM parser och sökvägsupplösning — samma som verifieraren och grinden
// använder för fingeravtrycket. Fas 0.15: tre implementationer kunde glida isär.
import { manifestEntries, resolveEntry } from '../tools/report-logic.mjs';
// F1-H08/H09: EN enumerator och EN undantagslista för båda ytorna.
import { enumerateSurface, RUNTIME_EXEMPT, MANIFEST_PATH } from '../tools/manifest-contract.mjs';
import { join, relative, resolve, parse, sep } from 'node:path';

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

// KANONISK FILLISTA — hela reporotsytan, ingen allowlist.
//
// Fas 0.11: manifestet SA att ci-evidence.json var undantagen men checkern
// undantog den inte, så CI-körningen fällde set-likheten.
// F1-H08: den gamla walkern jämförde `relative('.', p)` — som på Windows ger
// `fas0\andrade-filer.md` — mot undantag skrivna med snedstreck. INGET
// fas0/-undantag matchade därför på Windows, och manifestet rapporterade sig
// självt som olistat. Normaliseringen låg en rad för sent.
// F1-H09: TEXT-allowlisten och katalogundantagen (`assets`, `exports`,
// lockup-katalogen) gjorde 125 filer osynliga för set-likheten.
const repoSurface = enumerateSurface('.', { mode: 'repo' });
const onDisk = new Set(repoSurface.files);
for (const p of repoSurface.problems) console.error('✖ reporotsytan: ' + p);

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
  const marker = existsSync(join(resolve('../../..'), 'fas0/DELIVERY')) ? '../../../fas0/DELIVERY' : null;
  // Fas 1 (fjärde vändan): auto valde delivery så snart NÅGON extern fil fanns,
  // även när leveransroten var ogiltig. Nu krävs markören i en validerad rot.
  MODE = marker ? 'delivery' : 'repo';
  if (marker) console.log('· leveransmarkör funnen (' + marker.replace(/^(\.\.\/)+/, 'zip:/') + ') → delivery-läge');
}
// LEVERANSROTEN valideras INNAN något traverseras. Fas 1 (fjärde vändan):
// M-07:s fixtur låg så grunt att '../../..' blev "/", och med ett ärvt
// BUTLERY_MANIFEST_MODE=delivery började kontrollen traversera hela
// filsystemet — kedjan hängde på 100 % CPU och skrev aldrig sin summering.
// Regler: leveransroten måste ligga exakt tre nivåer över reporoten, får inte
// vara filsystemets rot, måste bära leveransmarkören, och traverseringen är
// djupbegränsad.
const ZIP_ROOT = resolve('../../..');
const zipRootProblems = () => {
  const p = [];
  const rel = relative(ZIP_ROOT, process.cwd()).split('\\').join('/');
  if (ZIP_ROOT === resolve('/') || parse(ZIP_ROOT).root === ZIP_ROOT)
    p.push('leveransroten skulle bli filsystemets rot (' + ZIP_ROOT + ') — reporoten ligger inte i en uppackad ZIP');
  if (rel.split('/').filter(Boolean).length !== 3)
    p.push('reporoten ligger ' + rel.split('/').filter(Boolean).length + ' nivåer under leveransroten, förväntat 3 ("' + rel + '")');
  if (!existsSync(join(ZIP_ROOT, 'fas0/DELIVERY')))
    p.push('leveransmarkören zip:/fas0/DELIVERY saknas — det här är ingen uppackad leverans');
  return p;
};

// SET-LIKHET ÄVEN UTANFÖR REPOROTEN — SAMMA enumerator som reporotsytan.
//
// Fas 1 (tredje vändan): set-likheten mättes bara inom reporoten.
// Fas 1 (fjärde vändan): undantaget var ett namn-wildcard och därmed fail-open.
// Fas 1 (femte vändan): kontrollen räknade bara filer som matchade en
// TEXT-allowlist och hoppade över breda kataloger.
// F1-H08: de två ytorna räknades av två olika walkers med olika
// säkerhetsegenskaper. Nu delar de enumeratorn i tools/manifest-contract.mjs,
// så en härdning av den ena gäller automatiskt den andra.
let deliveryUnlisted = [];
if (MODE === 'delivery') {
  const probs = zipRootProblems();
  if (probs.length) {
    for (const p of probs) console.error('✖ delivery-läge: ' + p);
    console.error('✖ delivery-läge kan inte bedömas — kör --mode=repo för en fristående checkout');
    process.exit(2);
  }
  const declared = new Set(manifestEntries(md).filter(e => e.outside).map(e => e.rel));
  // Den inbäddade reporoten mäts av sin egen yta — stopAt hindrar dubbelräkning.
  const zipSurface = enumerateSurface(ZIP_ROOT, { mode: 'delivery', stopAt: [process.cwd()] });
  deliveryUnlisted = zipSurface.files.filter(p => !declared.has(p)).sort();
  for (const p of deliveryUnlisted) console.error('✖ olistad artefakt i leveransytan: zip:/' + p);
  for (const p of zipSurface.problems) console.error('✖ leveransytan: ' + p);
  if (zipSurface.truncated) console.error('✖ leveransytan är djupare än traverseringsgränsen på ' + zipSurface.truncated + ' ställen');
  console.log('DELIVERY-SURFACE files=' + zipSurface.files.length + ' declared=' + declared.size +
    ' unlisted=' + deliveryUnlisted.length + ' rejected=' + zipSurface.problems.length +
    ' rejected_dirs=' + zipSurface.rejectedDirs.length + ' truncated=' + zipSurface.truncated + ' root=' + ZIP_ROOT);
  if (zipSurface.truncated || zipSurface.problems.length)
    deliveryUnlisted = [...deliveryUnlisted, ...zipSurface.problems, ...(zipSurface.truncated ? ['(djupbegränsning nådd)'] : [])];
}

console.log('MANIFEST-MODE ' + MODE + ' (leveransfiler funna: ' + outsideFound + ' av ' + (outsideFound + outside) + ')');
console.log('MANIFEST-SUMMARY mode=' + MODE + ' expected=' + expected + ' parsed=' + parsed + ' ok=' + ok + ' bad=' + bad + ' missing=' + missing +
  ' duplicates=' + dup + ' unlisted=' + (unlisted.length + deliveryUnlisted.length) + ' unlisted_repo=' + unlisted.length + ' unlisted_delivery=' + deliveryUnlisted.length + ' outside_absent=' + outside + ' expected=' + expected + ' ondisk=' + onDisk.size);

let fail = 0;
if (!expected) { console.error('✖ manifestet saknar <!--manifest:files=N--> — antalet kan inte kontrolleras'); fail = 1; }
if (parsed === 0) { console.error('✖ manifestet parsade noll rader'); fail = 1; }
if (expected && parsed !== expected) { console.error('✖ deklarerat ' + expected + ' poster, läste ' + parsed); fail = 1; }
if (repoSurface.problems.length) fail = 1;
if (bad || missing || dup || unlisted.length || deliveryUnlisted.length) fail = 1;
// F1-H09: undantagen är centralt definierade. Registret måste förteckna samma
// mängd — annars kan de två glida isär och en körartefakt bli osynlig i det
// ena men obligatorisk i det andra.
if (existsSync('source-authority.json')) {
  try {
    const ra = JSON.parse(readFileSync('source-authority.json', 'utf8')).runtimeArtifacts || [];
    const a = [...ra].sort().join('|'), b = [...RUNTIME_EXEMPT].sort().join('|');
    if (a !== b) {
      console.error('✖ source-authority.runtimeArtifacts [' + ra.join(', ') + '] skiljer sig från undantagen i tools/manifest-contract.mjs [' + RUNTIME_EXEMPT.join(', ') + ']');
      fail = 1;
    }
  } catch { /* T-20 fäller en otolkbar fil */ }
}
if (MODE === 'delivery' && outside) {
  console.error('✖ delivery-läge: ' + outside + ' obligatorisk leveransfil saknas — i en uppackad ZIP är varje zip:/-post krävd');
  fail = 1;
}
if (ok + outside !== parsed) { console.error('✖ verified ' + ok + ' + outsideAbsent ' + outside + ' ≠ parsed ' + parsed); fail = 1; }
// Rapportspråk: 'parsed' är inte 'verified'.
console.log(fail
  ? '✖ manifestkontroll underkänd · parsed=' + parsed + ' verified=' + ok + ' bad=' + bad + ' missing=' + missing + ' duplicates=' + dup + ' unlisted=' + (unlisted.length + deliveryUnlisted.length) + ' outsideAbsent=' + outside
  : '✔ manifest: ' + ok + ' av ' + parsed + ' poster verifierade · set-likhet mot ' + onDisk.size + ' artefakter');
process.exit(fail);
