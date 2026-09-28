#!/usr/bin/env node
// F2-NT · PROV FOR GRANNDOMARNA.  NB-01 … NB-06
//
// Kör: node tools/neighbour-verdict-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN PROVEN FINNS FOR
// Nar ett enskilt beslut ar bekvamt vill det garna vaxa till en regel. Har
// avgjordes tva timerkontroller pa sin egen scen, och guldfargen noterades pa
// vagen. Proven laser att guldfargen ALDRIG blev en systemregel, att de tva
// forblev separata poster, och att en supplemental grans alltid har en utpekad
// barare som finns i den ordinarie matningen.

import { writeFileSync, mkdirSync, readFileSync, readdirSync } from 'node:fs';
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

const A = JSON.parse(readFileSync(resolve('fas2/grannar-7.json'), 'utf8'));
const P = A.D_domar.poster;
const TIMER = ['lagaliggande|11', 'lagatimers|30'];

/* NB-01 · populationen och domarna */
prov('NB-01', 'grannpopulationen ar exakt sju och domarna ar 4 / 3 / 0',
  P.length === 7 && A.D_domar.REQUIRED === 4 &&
  A.D_domar.SUPPLEMENTAL_NOT_REQUIRED === 3 && A.D_domar.UNKNOWN === 0 &&
  A.D_domar.konformans.REQUIRED_FAIL === 4,
  P.length + ' forekomster · ' + A.D_domar.REQUIRED + ' / ' +
  A.D_domar.SUPPLEMENTAL_NOT_REQUIRED + ' / ' + A.D_domar.UNKNOWN);

/* NB-02 · de tva timerkontrollerna ar separata poster */
{ const t = P.filter(x => TIMER.includes(x.CONTROL_ID));
  const idn = t.map(x => x.OCCURRENCE_RECORD_ID);
  prov('NB-02', 'de tva timerkontrollerna har var sin occurrence-post och ingen gemensam ' +
    'beslutsidentitet',
    t.length === 2 && idn.every(Boolean) && new Set(idn).size === 2 &&
    t.every(x => /Ingen gemensam beslutsidentitet/i.test(x['$separatIdentitet'] || '')),
    idn.join(' · '));
}

/* NB-03 · guldfargen ar observation, aldrig proveniens */
{ const t = P.filter(x => TIMER.includes(x.CONTROL_ID));
  const okProv = t.every(x => x.APPLICABILITY_PROVENANCE === 'HUMAN_OCCURRENCE_ADJUDICATION');
  const okObs = t.every(x => x.observeradStyling &&
    /OBSERVERAT STYLINGFAKTUM/.test(x.observeradStyling.$status));
  const ingenFargIEvidens = t.every(x => (x.EVIDENCE || [])
    .every(e => !/guld|accent|farg(?!ad etikett)/i.test(e)));
  const ejEvidens = t.every(x => (x.EJ_EVIDENCE || []).includes('global accent convention'));
  prov('NB-03', 'guldfargen ar registrerad som observation och ingar aldrig i domens proveniens',
    okProv && okObs && ingenFargIEvidens && ejEvidens,
    'proveniens ' + okProv + ' · observation ' + okObs + ' · fargfri evidens ' +
    ingenFargIEvidens + ' · uttrycklig ej-evidens ' + ejEvidens);
}

/* NB-04 · ingen global regel om accentfarg som kontrollsignal */
{ /* Provfilen sjalv namner regeln for att kunna leta efter den; den raknas
   * darfor inte som en forekomst. */
  const filer = readdirSync(resolve('tools')).filter(f => f.endsWith('.mjs') &&
    f !== 'neighbour-verdict-fixtures.mjs');
  const kod = filer.map(f => readFileSync(resolve('tools', f), 'utf8')).join('\n');
  const regelIKod = /CONTROL_SIGNAL|accentArKontroll|GOLD_RULE\s*=\s*true|accent.*=>.*REQUIRED/i.test(kod);
  const beslut = A.B2_guldregeln;
  prov('NB-04', 'ingen global regel om att accentfargad text betyder kontroll finns i koden ' +
    'eller i registret',
    !regelIKod && beslut && beslut.$beslut === 'NO_GLOBAL_GOLD_RULE' &&
    /INTE automatiskt REQUIRED_BOUNDARY/.test(beslut.$logik),
    'regel i kod: ' + regelIKod + ' · registrerat beslut: ' + (beslut ? beslut.$beslut : 'saknas'));
}

/* NB-05 · varje supplemental grans har en utpekad barare i den ordinarie matningen */
{ const supp = P.filter(x => x.APPLICABILITY_VERDICT === 'SUPPLEMENTAL_NOT_REQUIRED');
  const ok = supp.every(x => x.alternativCarrier &&
    x.alternativCarrier.finnsIKanoniskMatning === true &&
    typeof x.alternativCarrier.kvot === 'number');
  prov('NB-05', 'varje supplemental grans har en utpekad alternativ barare som finns i den ' +
    'ordinarie matmotorn',
    supp.length === 3 && ok,
    supp.map(x => x.CONTROL_ID + ':' + (x.alternativCarrier ?
      x.alternativCarrier.ikon + '@' + x.alternativCarrier.kvot : 'SAKNAS')).join(' · '));
}

/* NB-06 · inga produktfiler andrade, ingen R-04-credit */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status', '--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  prov('NB-06', 'inga produktfiler andras och ingen R-04-credit skapas',
    !fel && produkt.length === 0 && A.I_regression.produktskrivningar === 0 &&
    A.I_regression.R04credit === 0 && A.I_regression.R04skrivningar === 0,
    fel || produkt.length + ' produktfiler · R-04 credit ' + A.I_regression.R04credit);
}

const ANTAL = 6;
for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(7) + r.vad);
  console.log('     ' + r.diag); }
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'grannprov.json'), JSON.stringify({
  $schema: 'butlery-grannprov/1', kontroll: 'CHK-NB-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('GRANNPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
