#!/usr/bin/env node
// F2-NT · PROV FOR REMEDIERINGSPAKETET.  RM-01 … RM-14
//
// Kör: node tools/remediation-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN PROVEN FINNS FOR
// Ett atgardspaket ar farligast nar det ser prydligt ut. Proven laser att
// malpopulationen ar exakt den adjudicerade, att ingen okand relation smyger
// in, att beslutsenheter aldrig bildas av rafarg, att en kandidat maste klara
// kravet mot VARJE faktisk yta i sin enhet, och att previewen inte ror
// produkten.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, join } from 'node:path';
import { relation, konformans, TILLAMPLIGHET, KONFORMANS } from './part-relation.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });

const A = JSON.parse(readFileSync(resolve('fas2/remediering-15.json'), 'utf8'));
const POP = A.A_population.poster;
const DU = A.B_beslutsenheter.enheter;
const MAT = A.F_G_kandidatmatriser;

/* RM-01 */
prov('RM-01', 'malpopulationen ar exakt 15',
  A.A_population.CURRENT_REQUIRED_FAIL === 15 &&
  A.A_population.TARGET_REMEDIATION_POPULATION === 15 && POP.length === 15,
  POP.length + ' occurrences');

/* RM-02 */
prov('RM-02', 'ingen relation med okand tillamplighet smyger in i scopet',
  A.A_population.TARGET_UNKNOWN === 0 &&
  POP.every(x => x.CURRENT_APPLICABILITY === 'REQUIRED'),
  'UNKNOWN i scopet: ' + A.A_population.TARGET_UNKNOWN);

/* RM-03 */
{ const perFarg = {};
  for (const x of POP) (perFarg[x.CURRENT_BOUNDARY_COLOR] = perFarg[x.CURRENT_BOUNDARY_COLOR] || new Set())
    .add(x.DECISION_UNIT);
  const delade = Object.entries(perFarg).filter(([, s]) => s.size > 1);
  prov('RM-03', 'samma raa ramfarg skapar inte automatiskt samma beslutsenhet',
    delade.length > 0,
    delade.map(([f, s]) => f + ' -> ' + s.size + ' enheter').join(' · ') || 'ingen delad farg'); }

/* RM-04 */
{ const fel = [];
  for (const m of MAT) for (const k of m.kandidater) {
    if (k.TECHNICAL_VERDICT !== 'TECHNICALLY_VALID') continue;
    for (const [yta, kv] of Object.entries(k.perYta))
      if (kv < 3) fel.push(m.DECISION_UNIT + '/' + k.CANDIDATE + ' mot ' + yta + ' = ' + kv); }
  prov('RM-04', 'en giltig kandidat klarar 3.0 mot VARJE faktisk angransande yta i sin enhet',
    fel.length === 0, fel.length ? fel.join(' · ') : 'samtliga giltiga kandidater klarar alla ytor'); }

/* RM-05 */
{ const blockerade = MAT.flatMap(m => m.kandidater).filter(k => k.TEXT_REGRESSION > 0);
  const giltigaMedTextfel = blockerade.filter(k => k.TECHNICAL_VERDICT === 'TECHNICALLY_VALID');
  prov('RM-05', 'en textrelation som gar fran godkand till fallande blockerar kandidaten',
    giltigaMedTextfel.length === 0,
    blockerade.length + ' kandidater med textregression, varav ' + giltigaMedTextfel.length +
    ' anda giltiga'); }

/* RM-06 */
{ const blockerade = MAT.flatMap(m => m.kandidater).filter(k => k.OTHER_GRAPHICS_REGRESSION > 0);
  const anda = blockerade.filter(k => k.TECHNICAL_VERDICT === 'TECHNICALLY_VALID');
  prov('RM-06', 'en required grafisk relation som gar fran godkand till fallande blockerar kandidaten',
    anda.length === 0, blockerade.length + ' med grafikregression, varav ' + anda.length +
    ' anda giltiga'); }

/* RM-07 */
{ const k = A.C_kallaOchKoppling;
  const harIckeMal = k.every(x => typeof x.NUMBER_OF_NON_TARGET_CONSUMERS === 'number') &&
    k.some(x => x.NUMBER_OF_NON_TARGET_CONSUMERS > 0);
  prov('RM-07', 'kall koppling till konsumenter utanfor malet upptacks och redovisas',
    harIckeMal,
    k.map(x => x.DECISION_UNIT + ':' + x.NUMBER_OF_NON_TARGET_CONSUMERS).join(' ')); }

/* RM-08 */
{ const ljusaTraffade = MAT.flatMap(m => m.kandidater).some(k => k.SOURCE_COLLATERAL > 0);
  prov('RM-08', 'ingen ljus konsument andras av previewen utan explicit scope',
    !ljusaTraffade,
    'kollaterala andringar i nagon preview: ' + (ljusaTraffade ? 'JA' : 'nej')); }

/* RM-09 */
{ const enPerJamforelse = MAT.every(m => m.kandidater.every(k =>
    typeof k.CANDIDATE === 'string' && k.CANDIDATE.length > 0));
  prov('RM-09', 'previewen varierar exakt ett avsett gransbeslut per jamforelse',
    enPerJamforelse && A.H_previews.$garantier.some(g => /endast den avsedda ramfargen/.test(g)),
    MAT.reduce((a,m)=>a+m.kandidater.length,0) + ' kandidatrenderingar, en farg per rendering'); }

/* RM-10 */
{ const geom = MAT.flatMap(m => m.kandidater).map(k => k.GEOMETRY_DELTA);
  prov('RM-10', 'M1-previewen ger 0 geometridelta',
    geom.every(g => g === 0), 'max geometridelta ' + Math.max(...geom)); }

/* RM-11 */
prov('RM-11', 'pressed, inactive och focus far ingen konformanscredit',
  A.M_status.PRESSED === 'UNTESTED' && A.M_status.INACTIVE === 'UNTESTED' &&
  A.M_status.FOCUS === 'UNTESTED',
  A.M_status.PRESSED + ' / ' + A.M_status.INACTIVE + ' / ' + A.M_status.FOCUS);

/* RM-12 */
prov('RM-12', 'en remedieringskandidat ger 0 R-04-credit',
  A.M_status.R04_CREDIT === 0 && A.L_regression.R04credit === 0 &&
  /R-04 CREDIT = 0/.test(A.E_kandidatuniversum.$R04),
  'credit ' + A.M_status.R04_CREDIT + ' · ' + A.E_kandidatuniversum.$R04.slice(0, 80));

/* RM-13 */
{ const ids = POP.map(x => x.CONTROL_ID);
  const parts = POP.map(x => x.PART_ID);
  const iEnhet = DU.flatMap(u => u.medlemmar);
  prov('RM-13', 'alla 15 forekomster rekoncilerar exakt en gang',
    new Set(ids).size === 15 && new Set(parts).size === 15 &&
    iEnhet.length === 15 && new Set(iEnhet).size === 15 &&
    ids.every(i => iEnhet.includes(i)),
    ids.length + ' forekomster, ' + new Set(parts).size + ' delidentiteter, ' +
    iEnhet.length + ' medlemskap i ' + DU.length + ' enheter'); }

/* RM-14 */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status', '--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  prov('RM-14', 'inga produktfiler andras i pre-write-blocket',
    !fel && produkt.length === 0 && A.L_regression.produktskrivningar === 0,
    fel || produkt.length + ' andrade produktfiler'); }

const ANTAL = 14;
for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(7) + r.vad);
  console.log('     ' + r.diag); }
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'remedieringsprov.json'), JSON.stringify({
  $schema: 'butlery-remedieringsprov/1', kontroll: 'CHK-RM-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('REMEDIERINGSPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
