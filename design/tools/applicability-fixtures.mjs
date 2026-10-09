#!/usr/bin/env node
// F2-NT · PROV FOR DEN TEXTOBEROENDE TILLAMPLIGHETSMODELLEN.  AP-01 … AP-12
//
// Kör: node tools/applicability-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN PROVEN FINNS FOR
// Modellen har tva ganger tidigare fatt en genvag inbyggd: forst "synlig text
// => supplemental", sedan "ingen text => required". Bada ar samma fel i olika
// riktning. Proven laser att INGEN av dem kan aterkomma, och att varken kvot,
// kontrollroll, fargpar eller accessible name kan avgora om nagot kravs.
//
// AP-12 provar dessutom att blocket inte ror produkten, R-04 eller nagot
// beslutsregister.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, join } from 'node:path';
import { relation, konformans, farSlasSamman, farAterbruka,
  TILLAMPLIGHET, KONFORMANS, TEKNISKT, EVIDENSKALLA } from './part-relation.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });

const bas = { PART_DETECTED: true, PART_IDENTITY: 'ram', PAINT_SOURCE: 'border-color',
  OUTSIDE_ADJACENT_SURFACE: 'rgb(245, 244, 237)' };

/* ── AP-01 · synlig text ger inte automatiskt SUPPLEMENTAL ──────────────── */
{ const utanDom = relation({ ...bas, CONTROL_IDENTITY: 'ap01|1', MEASURED_RATIO: 2.1,
    VISIBLE_TEXT_PRESENT: true,
    CONTEXT_DESCRIPTION: 'ordet ligger i ett falt som utan sin ram inte gar att ' +
      'skilja fran vanlig statisk text' });
  const medDom = relation({ ...bas, CONTROL_IDENTITY: 'ap01|1', MEASURED_RATIO: 2.1,
    VISIBLE_TEXT_PRESENT: true,
    tillamplighet: { verdikt: TILLAMPLIGHET.REQUIRED,
      evidenskalla: EVIDENSKALLA.COUNTERFACTUAL_SCENE_REVIEW,
      motivering: 'utan ramen laser scenen texten som brodtext, inte som kontroll' } });
  prov('AP-01', 'synlig text ger inte automatiskt SUPPLEMENTAL — och kan tvartom ' +
    'samexistera med REQUIRED',
    utanDom.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    utanDom.CONFORMANCE_VERDICT === KONFORMANS.UNKNOWN &&
    medDom.APPLICABILITY_VERDICT === TILLAMPLIGHET.REQUIRED &&
    medDom.CONFORMANCE_VERDICT === KONFORMANS.REQUIRED_FAIL,
    'utan dom: ' + utanDom.APPLICABILITY_VERDICT + '/' + utanDom.CONFORMANCE_VERDICT +
    ' · med scenbevisning: ' + medDom.APPLICABILITY_VERDICT + '/' + medDom.CONFORMANCE_VERDICT); }

/* ── AP-02 · SUPPLEMENTAL far komma ur scenbevisningen, aldrig ur texten ── */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'ap02|1', MEASURED_RATIO: 1.4,
    VISIBLE_TEXT_PRESENT: true, OTHER_VISUAL_CUES: ['knappform', 'placering i knapprad'],
    tillamplighet: { verdikt: TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED,
      evidenskalla: EVIDENSKALLA.COUNTERFACTUAL_SCENE_REVIEW,
      motivering: 'utan ramen ar kontrollen och dess operation anda tydliga i scenen' } });
  prov('AP-02', 'SUPPLEMENTAL_NOT_REQUIRED kan vara ratt, men bara pa scenbevisningen',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED &&
    r.APPLICABILITY_EVIDENCE === EVIDENSKALLA.COUNTERFACTUAL_SCENE_REVIEW &&
    r.CONFORMANCE_VERDICT === KONFORMANS.NOT_APPLICABLE,
    r.APPLICABILITY_VERDICT + ' · ' + r.CONFORMANCE_VERDICT + ' · kvot ' + r.MEASURED_RATIO); }

/* ── AP-03 · ikonknapp utan text ger inte automatiskt REQUIRED ──────────── */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'ap03|1', MEASURED_RATIO: 1.9,
    VISIBLE_TEXT_PRESENT: false, VISIBLE_ICON_PRESENT: true });
  prov('AP-03', 'franvaro av text ger inte automatiskt REQUIRED',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    r.CONFORMANCE_VERDICT === KONFORMANS.UNKNOWN &&
    r.TECHNICAL_MEASUREMENT_STATUS === TEKNISKT.TECHNICALLY_FAILS_IF_REQUIRED,
    r.APPLICABILITY_VERDICT + ' · ' + r.CONFORMANCE_VERDICT + ' · ' +
    r.TECHNICAL_MEASUREMENT_STATUS); }

/* ── AP-04 · ikon plus kontext kan gora gransen supplemental ────────────── */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'ap04|1', MEASURED_RATIO: 1.9,
    VISIBLE_TEXT_PRESENT: false, VISIBLE_ICON_PRESENT: true,
    OTHER_VISUAL_CUES: ['etablerad ikonografi', 'fast plats i verktygsraden'],
    tillamplighet: { verdikt: TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED,
      evidenskalla: EVIDENSKALLA.COUNTERFACTUAL_SCENE_REVIEW,
      motivering: 'ikonen och dess plats identifierar operationen aven utan gransen' } });
  prov('AP-04', 'en ikonknapp kan vara SUPPLEMENTAL nar ikon, form och kontext racker',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED &&
    r.CONFORMANCE_VERDICT === KONFORMANS.NOT_APPLICABLE,
    r.APPLICABILITY_VERDICT + ' · ' + r.CONFORMANCE_VERDICT); }

/* ── AP-05 · accessible name ar inte visuell evidens ────────────────────── */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'ap05|1', MEASURED_RATIO: 1.2,
    VISIBLE_TEXT_PRESENT: false, VISIBLE_ICON_PRESENT: false,
    ACCESSIBLE_NAME: 'Skicka' });
  const forsok = relation({ ...bas, CONTROL_IDENTITY: 'ap05|1', MEASURED_RATIO: 1.2,
    ACCESSIBLE_NAME: 'Skicka',
    tillamplighet: { verdikt: TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED,
      evidenskalla: 'ACCESSIBLE_NAME', motivering: 'namnet racker' } });
  prov('AP-05', 'accessible name ar varken visuell evidens eller giltig evidenskalla',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    forsok.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    /evidenskalla/.test(forsok.APPLICABILITY_REASON),
    'utan dom: ' + r.APPLICABILITY_VERDICT + ' · med namn som kalla: ' +
    forsok.APPLICABILITY_VERDICT + ' — ' + forsok.APPLICABILITY_REASON); }

/* ── AP-06 · ingen rollbaserad propagering ──────────────────────────────── */
{ const a = relation({ ...bas, CONTROL_IDENTITY: 'scenA|10', MEASURED_RATIO: 2.4,
    tillamplighet: { verdikt: TILLAMPLIGHET.REQUIRED,
      evidenskalla: EVIDENSKALLA.COUNTERFACTUAL_SCENE_REVIEW, motivering: 'scen A' } });
  const b = relation({ ...bas, CONTROL_IDENTITY: 'scenB|10', MEASURED_RATIO: 2.4 });
  const aterbruk = farAterbruka({ forekomstId: 'scenA|10' }, 'scenB|10');
  prov('AP-06', 'samma kontrolltyp i tva scener propagerar ingen dom',
    a.APPLICABILITY_VERDICT === TILLAMPLIGHET.REQUIRED &&
    b.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN && aterbruk === false,
    'scen A: ' + a.APPLICABILITY_VERDICT + ' · scen B: ' + b.APPLICABILITY_VERDICT +
    ' · aterbruk tillatet: ' + aterbruk); }

/* ── AP-07 · identiskt fargpar och identisk kvot propagerar inte ────────── */
{ const a = relation({ ...bas, CONTROL_IDENTITY: 'x|1', PAINT_SOURCE: 'rgb(204, 209, 194)',
    MEASURED_RATIO: 1.41,
    tillamplighet: { verdikt: TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED,
      evidenskalla: EVIDENSKALLA.HUMAN_OCCURRENCE_DECISION, motivering: 'beslut' } });
  const b = relation({ ...bas, CONTROL_IDENTITY: 'y|1', PAINT_SOURCE: 'rgb(204, 209, 194)',
    MEASURED_RATIO: 1.41 });
  const merge = farSlasSamman(
    { kontrollfunktion: 'valj dag', tillstandsfunktion: 'ledig', typAvVisuellaCues: ['ram'],
      scenhierarki: 'veckorutnat', kontrafaktisktUtfall: 'oskiljbar' },
    { kontrollfunktion: 'skicka', tillstandsfunktion: null, typAvVisuellaCues: ['ram'],
      scenhierarki: 'chattrad', kontrafaktisktUtfall: 'oskiljbar' });
  prov('AP-07', 'identiskt fargpar och identisk kvot ger ingen propagering och ingen merge',
    b.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN && merge.ok === false,
    'a: ' + a.APPLICABILITY_VERDICT + ' · b: ' + b.APPLICABILITY_VERDICT +
    ' · merge: ' + merge.skal); }

/* ── AP-08 · kvot under 3.0 skapar inte REQUIRED ────────────────────────── */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'ap08|1', MEASURED_RATIO: 1.27 });
  prov('AP-08', 'en kvot under 3.0 skapar aldrig REQUIRED',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    r.CONFORMANCE_VERDICT === KONFORMANS.UNKNOWN &&
    r.TECHNICAL_MEASUREMENT_STATUS === TEKNISKT.TECHNICALLY_FAILS_IF_REQUIRED,
    r.APPLICABILITY_VERDICT + ' · ' + r.TECHNICAL_MEASUREMENT_STATUS); }

/* ── AP-09 · kvot over 3.0 skapar inte REQUIRED och inte heller PASS ───── */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'ap09|1', MEASURED_RATIO: 7.7 });
  prov('AP-09', 'en kvot over 3.0 skapar varken REQUIRED eller REQUIRED_PASS',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    r.CONFORMANCE_VERDICT === KONFORMANS.UNKNOWN &&
    r.TECHNICAL_MEASUREMENT_STATUS === TEKNISKT.TECHNICALLY_PASSES_IF_REQUIRED,
    r.APPLICABILITY_VERDICT + ' · ' + r.CONFORMANCE_VERDICT + ' · ' +
    r.TECHNICAL_MEASUREMENT_STATUS); }

/* ── AP-10 · dagsrutorna behaller sin dom via BESLUTET, inte via text ───── */
{ const r = relation({ ...bas, CONTROL_IDENTITY: 'placera|17', PAINT_SOURCE: 'rgb(204, 209, 194)',
    MEASURED_RATIO: 1.41, VISIBLE_TEXT_PRESENT: true,
    tillamplighet: { verdikt: TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED,
      evidenskalla: EVIDENSKALLA.HUMAN_OCCURRENCE_DECISION,
      motivering: 'DAY_SLOT_BORDER_APPLICABILITY, manskligt beslut i e7346ae, ' +
        'baseline #ccd1c2 behalls, skrivscope 0' } });
  const utanBeslut = relation({ ...bas, CONTROL_IDENTITY: 'placera|17',
    MEASURED_RATIO: 1.41, VISIBLE_TEXT_PRESENT: true });
  prov('AP-10', 'dagsrutornas SUPPLEMENTAL kommer ur det manskliga beslutet, inte ur ' +
    'nagon textheuristik',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED &&
    r.APPLICABILITY_EVIDENCE === EVIDENSKALLA.HUMAN_OCCURRENCE_DECISION &&
    r.CONFORMANCE_VERDICT === KONFORMANS.NOT_APPLICABLE &&
    utanBeslut.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN,
    'med beslut: ' + r.APPLICABILITY_VERDICT + '/' + r.APPLICABILITY_EVIDENCE +
    ' · samma forekomst utan beslut: ' + utanBeslut.APPLICABILITY_VERDICT); }

/* ── AP-11 · ett befintligt UNKNOWN andras inte av kodandringar ─────────── */
{ const fore = relation({ ...bas, CONTROL_IDENTITY: 'gammal|9', MEASURED_RATIO: null });
  const efter = relation({ ...bas, CONTROL_IDENTITY: 'gammal|9', MEASURED_RATIO: 2.5,
    VISIBLE_TEXT_PRESENT: true, VISIBLE_ICON_PRESENT: true,
    OTHER_VISUAL_CUES: ['ny extraktion ser fler cues'] });
  prov('AP-11', 'ett befintligt UNKNOWN andras inte av att extraktionen eller ' +
    'bararkoden blir battre',
    fore.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    efter.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    efter.CONFORMANCE_VERDICT === KONFORMANS.UNKNOWN,
    'fore: ' + fore.APPLICABILITY_VERDICT + ' · efter battre matning: ' +
    efter.APPLICABILITY_VERDICT + '/' + efter.TECHNICAL_MEASUREMENT_STATUS); }

/* ── AP-12 · blocket ror varken produkt, R-04 eller beslutsregister ─────── */
{ let diff = '', fel = null;
  try { diff = execFileSync('git', ['status', '--porcelain'],
    { cwd: resolve('.'), encoding: 'utf8' }); } catch (e) { fel = e.message; }
  const rader = diff.split('\n').map(x => x.slice(3).replace(/^"|"$/g, '')).filter(Boolean);
  const produkt = rader.filter(f => f.endsWith('.dc.html'));
  const register = rader.filter(f => /theme-decisions|app-theme-map|authority|registry/i.test(f));
  prov('AP-12', 'inga produktfiler, inga R-04-registerfiler och inga beslutsregister ' +
    'ar andrade av blocket',
    !fel && produkt.length === 0 && register.length === 0,
    fel ? 'git: ' + fel : produkt.length + ' produktfiler · ' + register.length +
      ' registerfiler · andrade filer i arbetstradet: ' + rader.length); }

const ANTAL = 12;
for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(7) + r.vad);
  console.log('     ' + r.diag); }
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'tillamplighetsprov.json'), JSON.stringify({
  $schema: 'butlery-tillamplighetsprov/1', kontroll: 'CHK-AP-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('TILLAMPLIGHETSPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
