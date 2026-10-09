#!/usr/bin/env node
// F2-NT · PROV FOR ATGARDSPAKETET FOR DE FYRA.  R4N-01 … R4N-12
//
// Kör: node tools/four-remediation-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN PROVEN FINNS FOR
// Nar bara fyra fynd aterstar ar frestelsen att behandla dem som en klump.
// Proven laser att de tre A+ inte slas ihop pa operation eller rafarg, att
// viewportbredd ensam inte splittrar, att timerchippet inte drar med sig
// A+ utan positiv evidens, och att ett valt varde aldrig blir R-04-evidens.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });

const A = JSON.parse(readFileSync(resolve('fas2/remediering-4.json'), 'utf8'));
const POP = A.A_population.poster;
const DU = A.B_beslutsenheter.enheter;
const MAT = A.F_G_kandidatmatriser;
const APLUS = POP.filter(x => x.CONTROL_OPERATION === 'Textstorlek');

/* R4N-01 */
prov('R4N-01', 'malpopulationen ar exakt fyra',
  A.A_population.TARGET_OCCURRENCES === 4 && POP.length === 4 &&
  A.A_population.DUPLICATE === 0 && A.A_population.UNRESOLVED_IDENTITY === 0,
  POP.length + ' forekomster · dubbletter ' + A.A_population.DUPLICATE);

/* R4N-02 */
{ const enheterForAplus = new Set(APLUS.map(x => x.DECISION_UNIT_ID));
  const sammaFarg = new Set(APLUS.map(x => x.CURRENT_BOUNDARY_COLOR));
  prov('R4N-02', 'de tre A+ slas inte ihop enbart pa operation eller rafarg',
    APLUS.length === 3 && enheterForAplus.size === 2,
    APLUS.length + ' A+ i ' + enheterForAplus.size + ' enheter (' +
    [...enheterForAplus].join(', ') + ') trots samma operation och ' + sammaFarg.size +
    ' distinkta rafarger'); }

/* R4N-03 */
{ const bredd = APLUS.filter(x => /320/.test(x.CONTROL_ID));
  const standard = APLUS.filter(x => x.CONTROL_ID === 'lagastaende|3');
  const sammaEnhet = bredd.length === 1 && standard.length === 1 &&
    bredd[0].DECISION_UNIT_ID === standard[0].DECISION_UNIT_ID;
  prov('R4N-03', 'viewportvariant ensam skapar ingen split utan faktisk designorsak',
    sammaEnhet && /VIEWPORTBREDD ENSAM SKAPADE INGEN NY ENHET/.test(A.B_beslutsenheter.$viewport),
    'lagastaende|3 och lagastaende320|3 i samma enhet: ' + sammaEnhet); }

/* R4N-04 */
{ const fel = [];
  for (const m of MAT) for (const k of m.kandidater) {
    if (k.TECHNICAL_VERDICT !== 'TECHNICALLY_VALID') continue;
    for (const [yta, kv] of Object.entries(k.perYta))
      if (kv < 3) fel.push(m.DECISION_UNIT_ID + '/' + k.CANDIDATE + ' mot ' + yta + ' = ' + kv); }
  prov('R4N-04', 'en giltig kandidat klarar 3.0 i samtliga medlemmar av sin beslutsenhet',
    fel.length === 0, fel.length ? fel.join(' · ') : 'samtliga giltiga klarar alla ytor'); }

/* R4N-05 */
{ const delvis = MAT.flatMap(m => m.kandidater.filter(k =>
    Object.values(k.perYta).some(v => v < 3) && Object.values(k.perYta).some(v => v >= 3)));
  const anda = delvis.filter(k => k.TECHNICAL_VERDICT === 'TECHNICALLY_VALID');
  prov('R4N-05', 'en kandidat som bara fungerar i vissa medlemmar blir aldrig giltig',
    anda.length === 0,
    delvis.length + ' kandidater klarar bara delar av sin enhet, varav ' + anda.length +
    ' anda giltiga'); }

/* R4N-06 */
{ const timer = POP.filter(x => x.CONTROL_OPERATION !== 'Textstorlek');
  const delarEnhet = timer.some(t => APLUS.some(a => a.DECISION_UNIT_ID === t.DECISION_UNIT_ID));
  prov('R4N-06', 'timerchippet slas inte ihop med A+ utan positiv semantisk evidens',
    timer.length === 1 && !delarEnhet &&
    /Ingen positiv evidens for samma designfunktion/.test(A.B_beslutsenheter.$timerchip),
    'delad enhet: ' + delarEnhet + ' · ' + timer[0].DECISION_UNIT_ID); }

/* R4N-07 */
{ const k = A.C_kallaOchKoppling;
  prov('R4N-07', 'kall koppling till konsumenter utanfor malet upptacks och redovisas',
    k.every(x => typeof x.NON_TARGET_CONSUMERS === 'number') &&
    k.some(x => x.NON_TARGET_CONSUMERS > 0) &&
    k.every(x => x.occurrenceExakt === true),
    k.map(x => x.DECISION_UNIT_ID + ':' + x.NON_TARGET_CONSUMERS).join(' ')); }

/* R4N-08 */
{ const g = MAT.flatMap(m => m.kandidater).map(k => k.GEOMETRY_DELTA);
  prov('R4N-08', 'previewen ger 0 geometridelta', g.every(x => x === 0),
    'max ' + Math.max(...g)); }

/* R4N-09 */
{ const t = MAT.flatMap(m => m.kandidater).map(k => k.TEXT_REGRESSION);
  prov('R4N-09', '0 textregressioner', t.every(x => x === 0), 'max ' + Math.max(...t)); }

/* R4N-10 */
{ const g = MAT.flatMap(m => m.kandidater).map(k => k.OTHER_GRAPHICS_REGRESSION);
  prov('R4N-10', '0 regressioner i ovriga required-grafiska relationer',
    g.every(x => x === 0), 'max ' + Math.max(...g)); }

/* R4N-11 */
{ const J = A.J_R04separation;
  prov('R4N-11', 'remedieringen ger 0 R-04-credit och kan inte bli mappningsevidens',
    J.R04_CREDIT === 0 && J.R04_WRITES === 0 &&
    /NOT_DARK_MAPPING_EVIDENCE/.test(J.$provenanstagg) &&
    J.$regler.some(r => /mappningsproveniens/.test(r)),
    J.$provenanstagg); }

/* R4N-12 */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status', '--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  prov('R4N-12', 'inga produktfiler andras i detta block',
    !fel && produkt.length === 0 && A.L_regression.produktskrivningar === 0,
    fel || produkt.length + ' andrade produktfiler'); }

const ANTAL = 12;
for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(9) + r.vad);
  console.log('     ' + r.diag); }
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'fyraprov.json'), JSON.stringify({
  $schema: 'butlery-fyraprov/1', kontroll: 'CHK-R4N-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('FYRAPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
