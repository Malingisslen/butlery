#!/usr/bin/env node
// F2-NT · PROV FOR TEXTHEURISTIKENS BLAST RADIUS.  BR-01 … BR-12
//
// Kör: node tools/blast-radius-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN PROVEN FINNS FOR
// Nar en regel som gissat i tio manader tas bort racker det inte att visa att
// den ar borta ur koden. Allt den producerade maste ocksa granskas: matningar
// som hoppades over, domar som vilade pa den, och nedstroms constraints som
// arvde den. Proven laser den granskningens slutsatser mot den maskinella
// rapporten i fas2/blast-radius.json, sa att en framtida andring inte tyst kan
// gora rapporten osann.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { relation, konformans, TILLAMPLIGHET, KONFORMANS, TEKNISKT, EVIDENSKALLA }
  from './part-relation.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });

const A = JSON.parse(readFileSync(resolve('fas2/blast-radius.json'), 'utf8'));
const rader = A.K_rader;
const bas = { PART_DETECTED: true, PART_IDENTITY: 'ram', PAINT_SOURCE: 'border-color',
  OUTSIDE_ADJACENT_SURFACE: 'rgb(245, 244, 237)' };

/* BR-01 · en tidigare textgrindad del ar nu matbar men far ingen automatisk dom */
{ const skippade = A.A_partition.PREVIOUSLY_SKIPPED_NOW_MEASURED;
  const medText = A.A_partition.tidigareSkipOrsaker['supplemental / kontroll MED text'] || 0;
  const utanDom = rader.filter(x => x.APPLICABILITY_VERDICT === 'UNKNOWN' &&
    x.MEASURED_RATIO !== null).length;
  prov('BR-01', 'en del som tidigare hoppades over pa grund av synlig text ar nu matbar ' +
    'men far ingen automatisk tillamplighetsdom',
    skippade === 1155 && medText === 1087 && utanDom > 0,
    skippade + ' tidigare overhoppade, varav ' + medText + ' pa kontroller med text · ' +
    utanDom + ' matta delar star som UNKNOWN'); }

/* BR-02 · en REQUIRED som bara kom ur textfranvaro ateroppnas */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'br02|1', MEASURED_RATIO: 2.0,
    VISIBLE_TEXT_PRESENT: false,
    tillamplighet: { verdikt: TILLAMPLIGHET.REQUIRED, evidenskalla: 'INGEN_TEXT',
      motivering: 'kontrollen saknar text' } });
  prov('BR-02', 'en REQUIRED vars enda grund ar textfranvaro ateroppnas till UNKNOWN',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    r.CONFORMANCE_VERDICT === KONFORMANS.UNKNOWN,
    r.APPLICABILITY_VERDICT + ' — ' + r.APPLICABILITY_REASON); }

/* BR-03 · en REQUIRED med separat positiv evidens overlever */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'br03|1', MEASURED_RATIO: 2.0,
    VISIBLE_TEXT_PRESENT: false,
    tillamplighet: { verdikt: TILLAMPLIGHET.REQUIRED,
      evidenskalla: EVIDENSKALLA.COUNTERFACTUAL_SCENE_REVIEW,
      motivering: 'utan gransen ar objektet oskiljbart fran scenens statusglyfer' } });
  const iRapporten = A.C_korstab.LT3_REQUIRED;
  prov('BR-03', 'en REQUIRED med separat positiv scenevidens overlever borttagningen',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.REQUIRED &&
    r.CONFORMANCE_VERDICT === KONFORMANS.REQUIRED_FAIL && iRapporten === 15,
    r.APPLICABILITY_VERDICT + '/' + r.CONFORMANCE_VERDICT + ' · LT3_REQUIRED i rapporten ' +
    iRapporten); }

/* BR-04 · en SUPPLEMENTAL med explicit manskligt beslut overlever */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'placera|17', MEASURED_RATIO: 1.414,
    VISIBLE_TEXT_PRESENT: true,
    tillamplighet: { verdikt: TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED,
      evidenskalla: EVIDENSKALLA.HUMAN_OCCURRENCE_DECISION,
      motivering: 'DAY_SLOT_BORDER_APPLICABILITY' } });
  const dagsrutor = rader.filter(x => x.EVIDENCE_ID &&
    /DAY_SLOT_BORDER_APPLICABILITY/.test(x.EVIDENCE_ID)).length;
  prov('BR-04', 'en SUPPLEMENTAL med explicit manskligt beslut overlever borttagningen',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED &&
    r.CONFORMANCE_VERDICT === KONFORMANS.NOT_APPLICABLE && dagsrutor === 15,
    r.CONFORMANCE_VERDICT + ' · ' + dagsrutor + ' dagsrutor bar beslutet i rapporten'); }

/* BR-05 · kvot under 3 skapar aldrig REQUIRED */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'br05|1', MEASURED_RATIO: 1.1 });
  const felaktiga = rader.filter(x => x.band === 'LT_3' &&
    x.APPLICABILITY_VERDICT === 'REQUIRED' && !x.EVIDENCE_ID).length;
  prov('BR-05', 'en kvot under 3.0 skapar aldrig REQUIRED, varken i modellen eller i datan',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN && felaktiga === 0,
    r.APPLICABILITY_VERDICT + ' · ' + felaktiga + ' REQUIRED utan evidens bland LT_3'); }

/* BR-06 · kvot over 3 skapar varken REQUIRED eller PASS */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'br06|1', MEASURED_RATIO: 9.1 });
  const ge3utan = rader.filter(x => x.band === 'GE_3' &&
    x.APPLICABILITY_VERDICT === 'UNKNOWN' && x.CONFORMANCE_VERDICT !== 'UNKNOWN').length;
  prov('BR-06', 'en kvot over 3.0 ger varken REQUIRED eller PASS utan tillamplighet',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    r.CONFORMANCE_VERDICT === KONFORMANS.UNKNOWN &&
    r.TECHNICAL_MEASUREMENT_STATUS === TEKNISKT.TECHNICALLY_PASSES_IF_REQUIRED &&
    ge3utan === 0,
    r.TECHNICAL_MEASUREMENT_STATUS + ' · ' + ge3utan + ' GE_3 med UNKNOWN som anda fatt utfall'); }

/* BR-07 · korstabben summerar exakt till populationen */
{ const k = A.C_korstab;
  const summa = k.LT3_REQUIRED + k.LT3_SUPPLEMENTAL + k.LT3_UNKNOWN +
    k.GE3_REQUIRED + k.GE3_SUPPLEMENTAL + k.GE3_UNKNOWN + k.OMATT;
  prov('BR-07', 'korstabben summerar exakt till den aktuella matpopulationen',
    summa === 1806 && rader.length === 1806 && k.$slutenhet === true,
    summa + ' celler, ' + rader.length + ' rader'); }

/* BR-08 · varje LT3_REQUIRED ar REQUIRED_FAIL */
{ const lt3req = rader.filter(x => x.band === 'LT_3' && x.APPLICABILITY_VERDICT === 'REQUIRED');
  const fail = lt3req.filter(x => x.CONFORMANCE_VERDICT === 'REQUIRED_FAIL');
  prov('BR-08', 'varje relation i LT3_REQUIRED ar REQUIRED_FAIL',
    lt3req.length === fail.length && lt3req.length === A.C_korstab.LT3_REQUIRED,
    fail.length + ' av ' + lt3req.length); }

/* BR-09 · LT3_UNKNOWN ar inte produktfel */
{ const lt3unk = rader.filter(x => x.band === 'LT_3' && x.APPLICABILITY_VERDICT === 'UNKNOWN');
  const somFel = lt3unk.filter(x => x.CONFORMANCE_VERDICT === 'REQUIRED_FAIL');
  prov('BR-09', 'LT3_UNKNOWN raknas aldrig som produktfel',
    somFel.length === 0 && lt3unk.length === A.C_korstab.LT3_UNKNOWN && lt3unk.length > 0,
    lt3unk.length + ' okanda under 3.0, varav ' + somFel.length + ' klassade som fel'); }

/* BR-10 · bararsubstitution kraver att ersattarens egen relation kontrolleras */
{ const F = A.F_plusknappen;
  const fillKontrollerad = !!F.direktmatning &&
    typeof F.direktmatning.FILL_TO_EXTERNAL_RATIO === 'number' &&
    F.direktmatning.FILL_APPLICABILITY === 'REQUIRED' &&
    /REQUIRED_(PASS|FAIL)/.test(F.direktmatning.FILL_CONFORMANCE);
  prov('BR-10', 'en supplemental grans med en required ersattare kraver att ersattarens ' +
    'egen relation ar matt och domd',
    fillKontrollerad,
    'fyllning ' + (F.direktmatning ? F.direktmatning.FILL_TO_EXTERNAL_RATIO + ' -> ' +
      F.direktmatning.FILL_CONFORMANCE : 'saknas')); }

/* BR-11 · ingen dubblerad relation nar ersattaren redan finns som del */
{ const perId = rader.reduce((a,x) => { a[x.PART_ID] = (a[x.PART_ID]||0)+1; return a; }, {});
  const dubbletter = Object.values(perId).filter(n => n > 1).length;
  prov('BR-11', 'ingen dubblerad grafisk relation skapas',
    dubbletter === 0 && Object.keys(perId).length === rader.length,
    dubbletter + ' dubbletter bland ' + rader.length + ' delidentiteter'); }

/* BR-12 · ingen R-04-constraint overlever pa enbart textheuristiken */
{ const G = A.G_downstream;
  prov('BR-12', 'ingen R-04-constraint har den borttagna textheuristiken som enda proveniens',
    G.R04posterMedEnbartTextskal === 0 &&
    G.DECISION_PROVENANCE_REVIEW_REQUIRED.length === 0,
    G.R04artefakterMedTextskal + ' R-04-artefakter namner regeln, ' +
    G.R04posterMedEnbartTextskal + ' poster vilar pa den, ' +
    G.DECISION_PROVENANCE_REVIEW_REQUIRED.length + ' beslut kraver granskning'); }

const ANTAL = 12;
for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(7) + r.vad);
  console.log('     ' + r.diag); }
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'blastradiusprov.json'), JSON.stringify({
  $schema: 'butlery-blastradiusprov/1', kontroll: 'CHK-BR-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('BLASTRADIUSPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
