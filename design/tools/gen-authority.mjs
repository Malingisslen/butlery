#!/usr/bin/env node
// Butlery · source-authority.json → fas0/kallauktoritetsregister.md
// Kör: node tools/gen-authority.mjs   ·   Verifieras av T-20 och GEN-01
//
// Fas 1 (femte vändan): registret var handskrivet och drev. icons.json stod som
// 1.6 och "ej regenererad" när den var 1.8 och regenererad; de fyra genererade
// filerna stod som tokens 1.3/1.4 ur 1.9 när alla var på 1.12; och två skilda
// kontrollstatusar (blocked, not run) låg ihopslagna på samma rad. Registret
// GENERERAS nu ur en maskinläsbar källa och får inte redigeras för hand.
//
// F1-H02: statusordboken låg i registret självt och var endimensionell
// ("gällande" / "fryst" / "historisk" / "ska skapas"), vilket blandade ihop
// NORMATIVITET med ÄNDRINGSPOLICY. Maskinvärdena är nu engelska och bor i
// tools/authority-contract.mjs; de svenska etiketterna sätts HÄR, i
// presentationslagret, och ingen annanstans.
//
// F1-H03: 00-spec-index.md underhöll samma versioner och statusar för hand,
// parallellt med registret — och drev därför isär (indexet sa 1.1 om
// källauktoriteten när filen sa 2.0). Generatorn äger nu de cellerna. En rad
// som ska följa registret bär en `auth:`-markör som säger vilken domän den
// hör till och vilka kolumner som är generatorägda. Rader utan markör är
// fortfarande handskrivna.
import { readFileSync, existsSync } from 'node:fs';
import { emit } from './gen-check.mjs';
import { AUTHORITY_STATES, CHANGE_POLICIES, stateLabel, policyLabel,
  INDEX_AUTHORITY_ROWS, INDEX_ROWS_EXEMPT, INDEX_MARKER_RE, INDEX_MARKER_RE_G,
  indexVersionCell, indexFileRef, indexStatusCell } from './authority-contract.mjs';

const A = JSON.parse(readFileSync('source-authority.json', 'utf8'));
const tokens = JSON.parse(readFileSync('tokens.json', 'utf8'));
const cell = v => String(v ?? '').replace(/\\/g, '\\\\').replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
const dash = v => (v === null || v === undefined || v === '' ? '—' : cell(v));

// Tokenversionen i en genererad fils header — läses, inte påstås.
function headerTokenVersion(file) {
  if (!existsSync(file)) return null;
  const head = readFileSync(file, 'utf8').split('\n').slice(0, 12).join('\n');
  return (head.match(/^[^\n]*\btokens\s+v?(\d+\.\d+(?:\.\d+)?)/im) || [])[1] || null;
}

const L = [];
L.push('# Källauktoritetsregister');
L.push('');
L.push('**GENERERAD FIL — ändra `source-authority.json`, inte den här.** Renderad av `tools/gen-authority.mjs` ur `source-authority.json` ' + A.version + ' (' + A.date + '). Valideras av T-20: exakt en aktiv auktoritet per domän, varje deklarerad fil finns, statusarna hör till ordboken, och `supersededBy` bildar ingen cykel.');
L.push('');
for (const s of A.sections.filter(s => s.heading === 'Precedens' || s.heading === 'Maskin-id')) {
  L.push('**' + s.heading + '.** ' + s.body);
  L.push('');
}
L.push('## Normativa källor');
L.push('');
L.push('**Två dimensioner, inte en.** `authorityState` säger vilken roll posten spelar för sin domän; `changePolicy` säger om källan får ändras. De är oberoende — `legacy-api-contract.json` är både **gällande** och **fryst**. Endast `active` är normativ, och endast `planned` får sakna fil.');
L.push('');
L.push('| Domän-id | Domän | Normativ källa | Version | Tillstånd | Ändringspolicy | Ägare | Anmärkning |');
L.push('|---|---|---|---|---|---|---|---|');
for (const a of A.authorities)
  L.push('| `' + cell(a.domainId) + '` | ' + cell(a.domain) + ' | ' + (a.file ? '`' + cell(a.file) + '`' : '*saknas*') + ' | ' + dash(a.version) +
    ' | ' + cell(stateLabel(a.authorityState)) + ' (`' + cell(a.authorityState) + '`) | ' + cell(policyLabel(a.changePolicy)) +
    ' | ' + cell(a.owner) + ' | ' + dash(a.note) + ' |');
L.push('');
L.push('## Dokumentruntime');
L.push('');
L.push('Två byggen av `support.js` finns i leveransen. De är **avsiktligt olika** och båda är manifestdeklarerade. Ingen av dem får skrivas över eller slås ihop utan att relationen omprövas.');
L.push('');
L.push('| Sökväg | Var | Manifeststatus | Konsumenter | Anmärkning |');
L.push('|---|---|---|---|---|');
for (const r of A.runtimeInstances)
  L.push('| `' + cell(r.path) + '` | ' + cell(r.where) + ' | ' + cell(r.manifestStatus) + ' | ' + cell(r.consumers) + ' | ' + cell(r.note) + ' |');
L.push('');
{
  const s = A.sections.find(x => x.heading.startsWith('Genererade'));
  L.push('## Genererade artefakter — ingen egen auktoritet');
  L.push('');
  if (s) { L.push(s.body); L.push(''); }
  L.push('| Fil | Generator | Tokenversion i headern | Aktuell mot `tokens.json` ' + tokens.version + ' |');
  L.push('|---|---|---|---|');
  for (const g of A.generatedArtifacts) {
    const v = headerTokenVersion(g.file);
    const state = v === null ? 'ingen tokenrad (renderas ur annan källa)' : (v === tokens.version ? '**ja**' : '**NEJ — ' + cell(v) + '**');
    L.push('| `' + cell(g.file) + '` | `' + cell(g.generator) + '` | ' + dash(v) + ' | ' + state + ' |');
  }
  L.push('');
}
L.push('## Superseded och frysta');
L.push('');
L.push('| Fil | Var | Tillstånd | Ändringspolicy | Ersatt av | Anmärkning |');
L.push('|---|---|---|---|---|---|');
for (const s of A.superseded)
  L.push('| `' + cell(s.file) + '` | ' + cell(s.where) + ' | ' + cell(stateLabel(s.authorityState)) + ' (`' + cell(s.authorityState) + '`) | ' +
    cell(policyLabel(s.changePolicy)) + ' | ' + (s.supersededBy ? '`' + cell(s.supersededBy) + '`' : '—') + ' | ' + dash(s.note) + ' |');
L.push('');
L.push('## Statusordbok för kontroller');
L.push('');
L.push('| Status | Betyder | Får uppfylla ett godkännandekriterium? |');
L.push('|---|---|---|');
for (const c of A.controlStatusVocabulary)
  L.push('| `' + cell(c.status) + '` | ' + cell(c.means) + ' | ' + (c.satisfies ? 'ja' : '**nej**') + ' |');
L.push('');
L.push('`not applicable` får aldrig användas för något som bara ännu inte körts. Samma ordbok gäller i styrdokumentets § 15, `tools/controls.mjs` och den genererade `fas0/kontrollstatus.md`.');
L.push('');
L.push('## Statusordbok för källor');
L.push('');
L.push('Maskinvärdena är engelska och definieras i `tools/authority-contract.mjs`. De svenska etiketterna sätts i presentationslagret — de finns inte i maskinfältet och får inte skrivas dit.');
L.push('');
L.push('| `authorityState` | Etikett | Normativ? | Aktuell auktoritet? | Kräver fil? |');
L.push('|---|---|---|---|---|');
for (const [k, v] of Object.entries(AUTHORITY_STATES))
  L.push('| `' + cell(k) + '` | ' + cell(v.label) + ' | ' + (v.normative ? '**ja**' : 'nej') + ' | ' +
    (v.current ? 'ja' : '**nej**') + ' | ' + (v.requiresFile ? 'ja' : 'nej') + ' |');
L.push('');
L.push('| `changePolicy` | Etikett | Betyder |');
L.push('|---|---|---|');
L.push('| `' + cell('maintained') + '` | ' + cell(CHANGE_POLICIES.maintained.label) + ' | källan får ändras inom sin domän |');
L.push('| `' + cell('frozen') + '` | ' + cell(CHANGE_POLICIES.frozen.label) + ' | låst — får inte ändras utan att kontraktet omförhandlas. Oberoende av `authorityState`: en källa kan vara `active` och `frozen` samtidigt |');
L.push('');
for (const s of A.sections.filter(s => !['Precedens', 'Maskin-id'].includes(s.heading) && !s.heading.startsWith('Genererade'))) {
  L.push('## ' + s.heading);
  L.push('');
  L.push(s.body);
  L.push('');
}
const out = L.join('\n');

/* ── F1-H03 · indexets auktoritets- och versionsceller ─────────────────────
 * 00-spec-index.md underhöll domän, version och status parallellt med
 * registret och drev därför isär. Generatorn äger nu exakt de cellerna.
 *
 * En rad som ska följa registret bär i sin FÖRSTA cell en markör:
 *     <!--auth:<domainId>:<kolumner>-->
 * där kolumnerna är `version`, `status` eller båda. Separatorn är kolon, inte
 * pipe — en pipe inne i markören hade delat tabellcellen. Rader utan markör är
 * handskrivna och rörs inte. Skärmraden äger bara `version`, eftersom dess
 * statuscell bär gen-counts räkneankare — två generatorer får aldrig skriva
 * i samma cell.
 */
const byDomain = new Map(A.authorities.map(a => [a.domainId, a]));
const idxPath = '00-spec-index.md';
let index = readFileSync(idxPath, 'utf8');
const idxLines = index.split('\n');

// F1-U02 · MÄNGDLIKHET FÖRST, cellskrivning sedan.
//
// Generatorn rörde tidigare bara de rader den råkade hitta. En struken rad var
// därför osynlig: inga markörer, inga celler att skriva, och ett "klart".
// Nu jämförs markörmängden mot den kanoniska listan i authority-contract.mjs
// INNAN något skrivs, och avviker den skriver generatorn ingenting alls.
const seenMarkers = [];
for (const line of idxLines) {
  for (const m of line.matchAll(INDEX_MARKER_RE_G)) seenMarkers.push(m[1]);
}
const idxProblems = [];
const dupMarkers = seenMarkers.filter((v, i) => seenMarkers.indexOf(v) !== i);
for (const d of [...new Set(dupMarkers)])
  idxProblems.push('markören auth:' + d + ' förekommer ' + seenMarkers.filter(x => x === d).length + ' gånger — en rad per domän');
const haveM = new Set(seenMarkers), wantM = new Set(INDEX_AUTHORITY_ROWS);
for (const d of [...wantM].filter(d => !haveM.has(d)))
  idxProblems.push('raden för domänen "' + d + '" saknas i versionstabellen — markören auth:' + d + ' finns inte');
for (const d of [...haveM].filter(d => !wantM.has(d))) {
  idxProblems.push(byDomain.has(d)
    ? 'domänen "' + d + '" har en auth:-markör men står inte i INDEX_AUTHORITY_ROWS' +
      (INDEX_ROWS_EXEMPT[d] ? ' (undantagen: ' + INDEX_ROWS_EXEMPT[d] + ')' : '')
    : 'okänd auth:-markör "' + d + '" — domänen finns inte i source-authority.json');
}
if (idxProblems.length) {
  for (const p of idxProblems) console.error('✖ 00-spec-index.md: ' + p);
  console.error('✖ gen-authority skriver ingenting — indexets auktoritetsrader måste vara exakt ' +
    INDEX_AUTHORITY_ROWS.length + ' stycken innan cellerna kan ägas');
  process.exit(1);
}

// Cellskrivning. Renderarna ligger i authority-contract.mjs och delas med
// linten, så generatorn och kontrollen aldrig kan mena olika saker om vad en
// cell ska innehålla.
let rewritten = 0;
for (let i = 0; i < idxLines.length; i++) {
  const m = idxLines[i].match(INDEX_MARKER_RE);
  if (!m) continue;
  const a = byDomain.get(m[1]);
  const own = new Set(m[2].split(',').filter(Boolean));
  const cells = idxLines[i].split('|');
  // cells[0] är tomt (raden börjar med |), cells[1] = Del, [2] = Version,
  // [3] = Fil, [4] = Status, [5] = Normativ för.
  if (own.has('version')) {
    const v = indexVersionCell(a);
    if (v !== null) cells[2] = ' ' + cell(v) + ' ';
  }
  // Filkolumnen: generatorn äger det FÖRSTA kodcitatet, resten är prosa.
  if (own.has('file')) {
    const ref = indexFileRef(a);
    cells[3] = /`[^`]+`/.test(cells[3])
      ? cells[3].replace(/`[^`]+`/, ref)
      : ' ' + ref + ' ';
  }
  if (own.has('status')) cells[4] = ' ' + cell(indexStatusCell(a)) + ' ';
  idxLines[i] = cells.join('|');
  rewritten++;
}

// Indexets huvudrad. F1-H03: indexet får inte kalla sig ensam källa för
// versioner och status, och dess datum får inte vara handskrivet.
const HEAD_START = '<!--auth:header:start-->', HEAD_END = '<!--auth:header:end-->';
const hs = idxLines.indexOf(HEAD_START), he = idxLines.indexOf(HEAD_END);
if (hs < 0 || he < 0 || he < hs) {
  console.error('✖ 00-spec-index.md saknar ' + HEAD_START + ' … ' + HEAD_END);
  process.exitCode = 1;
} else {
  const head = [
    '**Navigationskarta och versionsregister.** Den **maskinella källan** för domänägarskap, versioner, `authorityState` och `changePolicy` är `source-authority.json` ' + A.version + ' (' + A.date + ') — inte den här filen. Rader nedan med en `auth:`-markör genereras ur registret av `tools/gen-authority.mjs` och ska aldrig handredigeras; övriga rader är handskrivna. Vid konflikt mellan en genererad cell och en handskriven rad gäller registret, och avvikelsen fälls av T-15 och T-20.'
  ];
  idxLines.splice(hs + 1, he - hs - 1, ...head);
}

emit({ 'fas0/kallauktoritetsregister.md': out, [idxPath]: idxLines.join('\n') }, { label: 'gen-authority' });
console.log('kallauktoritetsregister.md skrivet · ' + A.authorities.length + ' domäner · ' +
  A.generatedArtifacts.length + ' genererade artefakter · ' + A.superseded.length + ' superseded · ' +
  rewritten + ' indexrader generatorägda');
