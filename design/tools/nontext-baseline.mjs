#!/usr/bin/env node
// F2-NT · BASLINJE FOR ICKE-TEXTUELL KONTRAST OCH ANVANDNING AV FARG.
//
// Kör: node tools/nontext-baseline.mjs [--out=<fil>]
//
// TRE SKILDA RAPPORTER. De slas aldrig ihop och summeras aldrig.
//
//   A  ICKE-TEXTUELL KONTRAST I UI-KOMPONENTER   1.4.11, troskel 3:1
//   B  ANVANDNING AV FARG                        1.4.1, parvis per komponent
//   C  GRAFISKA OBJEKT UTANFOR KONTROLLER        1.4.11, egen modell
//
// VARJE TAL BAR SIN ENHET. Fyra olika enheter forekommer och far aldrig
// laggas ihop:
//   kontroller        element med data-a11y-role
//   grafiska delar    barare/supplement inuti dessa kontroller
//   tillstandspar     tva tillstand av samma deklarerade komponent
//   grafiska objekt   grafik utanfor alla kontroller
//
// Kontrastvardet avgor aldrig nagon roll. Det lases forst i steg 2.

import { spawn } from 'node:child_process';
import { readdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { GRAPHIC_OBJECTS } from './graphic-objects.mjs';
import { parbilda } from './colour-only.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9580 + (process.pid % 100);

const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(process.env.TEMP || '.', 'butlery-nt'), 'about:blank'], { stdio: 'ignore' });
let K = [], G = [], verktygsfel = null;
try {
  let ws = null;
  for (let k = 0; k < 60 && !ws; k++) { await sleep(250);
    try { ws = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!ws) throw new Error('Chrome startade aldrig');
  const sock = new WebSocket(ws);
  await new Promise(r => { sock.onopen = r; });
  let id = 0; const p = new Map();
  sock.onmessage = m => { const j = JSON.parse(m.data); if (j.id && p.has(j.id)) { const res = p.get(j.id); p.delete(j.id); res(j.result); } };
  const call = (m, pr = {}, s) => new Promise(res => { const n = ++id; p.set(n, res); sock.send(JSON.stringify({ id: n, method: m, params: pr, ...(s ? { sessionId: s } : {}) })); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, pp) => call(m, pp, sessionId);
  await s('Page.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: false });
  for (const f of filer) {
    await s('Page.navigate', { url: pathToFileURL(resolve(f)).href });
    await sleep(400);
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    await sleep(650);
    const a = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
    if (a.exceptionDetails) throw new Error('kontrollmatningen kastade i ' + f);
    K.push(...(a.result.value || []).map(x => ({ ...x, fil: f })));
    const b = await s('Runtime.evaluate', { expression: GRAPHIC_OBJECTS, returnByValue: true });
    if (b.exceptionDetails) throw new Error('objektmatningen kastade i ' + f);
    G.push(...(b.result.value || []).map(x => ({ ...x, fil: f })));
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('NT-BASLINJE status=VERKTYGSFEL'); process.exit(2);
}

/* ── A · ICKE-TEXTUELL KONTRAST I UI-KOMPONENTER ────────────────────────── */
const delar = K.flatMap(x => x.delar.map(d => ({ ...d, art: x.art, fil: x.fil, roll: x.roll,
  namn: x.namn, state: x.state, disabled: x.disabled })));
const perRoll = {}; for (const d of delar) perRoll[d.carrier] = (perRoll[d.carrier] || 0) + 1;
const carriers = delar.filter(d => d.carrier === 'componentIdentityCarrier' || d.carrier === 'stateCarrier');
const okandaDelar = delar.filter(d => d.carrier === 'unknown');
const matta = carriers.filter(d => d.status === 'matt');
const ejMatta = carriers.filter(d => d.status !== 'matt');
const undantagna = matta.filter(d => d.disabled);
const bedomda = matta.filter(d => !d.disabled);
const fynd = bedomda.filter(d => d.kvot < 3).sort((a, b) => a.kvot - b.kvot);
const fyndPerBararroll = {}; for (const d of fynd) fyndPerBararroll[d.carrier] = (fyndPerBararroll[d.carrier] || 0) + 1;
const fyndPerTyp = {}; for (const d of fynd) fyndPerTyp[d.typ] = (fyndPerTyp[d.typ] || 0) + 1;

/* ── B · ANVANDNING AV FARG ─────────────────────────────────────────────── */
const co = parbilda(K);

/* ── C · GRAFISKA OBJEKT UTANFOR KONTROLLER ─────────────────────────────── */
const objPerRoll = {}; for (const g of G) objPerRoll[g.carrier] = (objPerRoll[g.carrier] || 0) + 1;
const objRequired = G.filter(g => g.carrier === 'required');
const objRedundant = G.filter(g => g.carrier === 'redundant');
const objDecorative = G.filter(g => g.carrier === 'decorative');
const objMatta = objRequired.filter(g => g.status === 'matt');
const objFynd = objMatta.filter(g => g.kvot < 3).sort((a, b) => a.kvot - b.kvot);
const objRollOkand = G.filter(g => g.carrier === 'unknown');
const objEjMatbara = objRequired.filter(g => g.status === 'unknown');

const artefakter = new Set(K.map(x => x.art));
const doc = {
  $schema: 'butlery-nt-baslinje/2', kontroll: 'CHK-NT-01',
  $regel: 'Rollen avgors ur strukturen, aldrig ur kontrastvardet. A, B och C ar tre skilda rapporter och slas aldrig ihop.',
  $enheter: {
    kontroller: 'element med data-a11y-role',
    grafiskaDelar: 'barare eller supplement inuti en kontroll — flera per kontroll',
    tillstandspar: 'tva tillstand av samma deklarerade komponent',
    grafiskaObjekt: 'grafik utanfor alla kontroller',
    artefakter: 'sc-item, en skarmbild',
  },
  matpunkt: { viewport: '390x844', deviceScaleFactor: 2, filer_st: filer.length },
  population: { artefakter_st: artefakter.size, kontroller_st: K.length,
    grafiskaDelar_st: delar.length, grafiskaObjekt_st: G.length },

  A_ickeTextuellKontrastIKomponenter: {
    $enhet: 'grafiska delar',
    grafiskaDelar_st: delar.length,
    perBararroll_grafiskaDelar: perRoll,
    unknown_grafiskaDelar_st: okandaDelar.length,
    barare_grafiskaDelar_st: carriers.length,
    matta_grafiskaDelar_st: matta.length,
    ejMatta_grafiskaDelar_st: ejMatta.length,
    undantagna_disabled_grafiskaDelar_st: undantagna.length,
    bedomda_grafiskaDelar_st: bedomda.length,
    fynd_under_3_grafiskaDelar_st: fynd.length,
    fynd_perBararroll_grafiskaDelar: fyndPerBararroll,
    fynd_perTyp_grafiskaDelar: fyndPerTyp,
    berorda_kontroller_st: new Set(fynd.map(d => d.art + '|' + d.roll + '|' + d.namn)).size,
    berorda_artefakter_st: new Set(fynd.map(d => d.art)).size,
    $not: 'fynd_perBararroll summerar till fynd_under_3 i enheten grafiska delar. Beror kontroller och artefakter ar ANDRA enheter och far aldrig laggas till.',
    fynd: fynd.slice(0, 80),
    unknown: okandaDelar.slice(0, 30),
  },

  B_anvandningAvFarg: {
    $enhet: 'tillstandspar',
    kontrollerMedTillstand_st: co.kontroller_med_tillstand_st,
    kontrollerIGrupp_st: co.kontroller_i_grupp_st,
    pairingUnknown_kontroller_st: co.pairingUnknown_kontroller_st,
    tackning_procent: co.kontroller_med_tillstand_st
      ? +(100 * co.kontroller_i_grupp_st / co.kontroller_med_tillstand_st).toFixed(1) : 0,
    stateGroups_st: co.grupper_st,
    stateGroups_singelState_st: co.grupper_singelState_st,
    stateGroups_tvetydiga_st: co.grupper_tvetydiga_st,
    tillstandspar_st: co.par_st,
    par_medIckefargSignal_st: co.par_med_ickefargSignal_st,
    colorOnly_tillstandspar_st: co.colorOnly_st,
    tackningsinvariant_ok: co.invariant_ok,
    $not: 'Identiteten ar authored data-state-group pa kontrollen sjalv. data-component anvands aldrig som reservidentitet: komponenttyp ar inte identitet. Accessible name, geometri, DOM-position och textmatchning ar otillatna. Utan giltig grupp blir kontrollen pairingUnknown — aldrig "ingen skillnad". En grupp med bara ett representerat tillstand ar single-state, aldrig godkand.',
    colorOnly: co.colorOnly,
    par: co.par,
    singelState: co.singelState,
    tvetydiga: co.tvetydiga,
    pairingUnknown: co.pairingUnknown,
  },

  C_grafiskaObjektUtanforKontroller: {
    $enhet: 'grafiska objekt',
    grafiskaObjekt_st: G.length,
    artefakter_st: new Set(G.map(g => g.art)).size,
    perRoll_grafiskaObjekt: objPerRoll,
    required_st: objRequired.length,
    redundant_st: objRedundant.length,
    decorative_st: objDecorative.length,
    unknown_st: objRollOkand.length,
    summa_kontroll: objRequired.length + objRedundant.length + objDecorative.length + objRollOkand.length,
    populationsinvariant_ok: objRequired.length + objRedundant.length + objDecorative.length + objRollOkand.length === G.length,
    required_matta_st: objMatta.length,
    required_ejMatbara_st: objEjMatbara.length,
    $notMatning: 'unknown_st ar objekt UTAN giltig roll. required_ejMatbara_st ar required-objekt vars farg inte kunde losas — tva skilda saker som aldrig slas ihop.',
    ejMatbara: objEjMatbara.slice(0, 20),
    fynd_under_3_grafiskaObjekt_st: objFynd.length,
    berorda_artefakter_st: new Set(objFynd.map(g => g.art)).size,
    $not: 'Rollen kravs som deklaration, precis som data-hit i R-02. data-icon namnger formen, inte funktionen, och raknas darfor inte. required + redundant + decorative + unknown motsvarar exakt populationen.',
    fynd: objFynd.slice(0, 40),
    unknown_exempel: objRollOkand.slice(0, 20),
  },
};
doc.status = (okandaDelar.length + fynd.length + co.pairingUnknown_kontroller_st +
  co.grupper_tvetydiga_st + co.colorOnly_st + objRollOkand.length + objEjMatbara.length +
  objFynd.length) ? 'FÄLLD' : 'godkänd';
doc.$avgransning = 'WCAG 1.4.11 kan inte kallas stangd sa lange nagon population har unknown.';
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

const rad = (etikett, tal, enhet) =>
  console.log('  ' + etikett.padEnd(34) + String(tal).padStart(6) + '  ' + enhet);

console.log('MATPUNKT  390x844 · dsf 2 · ' + filer.length + ' filer · ' + artefakter.size + ' artefakter');
console.log('');
console.log('A · ICKE-TEXTUELL KONTRAST I UI-KOMPONENTER');
rad('kontroller', K.length, 'kontroller');
rad('grafiska delar', delar.length, 'grafiska delar');
rad('  varav barare', carriers.length, 'grafiska delar');
rad('  varav unknown', okandaDelar.length, 'grafiska delar');
rad('matta', matta.length, 'grafiska delar');
rad('undantagna disabled', undantagna.length, 'grafiska delar');
rad('bedomda', bedomda.length, 'grafiska delar');
rad('fynd under 3:1', fynd.length, 'grafiska delar');
console.log('    per bararroll: ' + JSON.stringify(fyndPerBararroll));
console.log('    per typ:       ' + JSON.stringify(fyndPerTyp));
rad('beror', new Set(fynd.map(d => d.art + '|' + d.roll + '|' + d.namn)).size, 'kontroller');
rad('beror', new Set(fynd.map(d => d.art)).size, 'artefakter');
console.log('');
console.log('B · ANVANDNING AV FARG');
rad('kontroller med tillstand', co.kontroller_med_tillstand_st, 'kontroller');
rad('  med giltig state-group', co.kontroller_i_grupp_st, 'kontroller');
rad('  pairingUnknown', co.pairingUnknown_kontroller_st, 'kontroller');
console.log('    tackning: ' + doc.B_anvandningAvFarg.tackning_procent + ' %' +
  (co.invariant_ok ? '  ✔ invariant' : '  ✖ INVARIANT BRUTEN'));
rad('state-groups', co.grupper_st, 'grupper');
rad('  single-state / unpaired', co.grupper_singelState_st, 'grupper');
rad('  tvetydig representant', co.grupper_tvetydiga_st, 'grupper');
rad('jamforda par', co.par_st, 'tillstandspar');
rad('  klarar via ickefarg-signal', co.par_med_ickefargSignal_st, 'tillstandspar');
rad('  color-only', co.colorOnly_st, 'tillstandspar');
console.log('');
console.log('C · GRAFISKA OBJEKT UTANFOR KONTROLLER');
rad('grafiska objekt', G.length, 'grafiska objekt');
rad('  required', objRequired.length, 'grafiska objekt');
rad('  redundant', objRedundant.length, 'grafiska objekt');
rad('  decorative', objDecorative.length, 'grafiska objekt');
rad('  unknown roll', objRollOkand.length, 'grafiska objekt');
console.log('    summa ' + doc.C_grafiskaObjektUtanforKontroller.summa_kontroll +
  (doc.C_grafiskaObjektUtanforKontroller.populationsinvariant_ok ? '  ✔ invariant' : '  ✖ INVARIANT BRUTEN'));
rad('required matta', objMatta.length, 'grafiska objekt');
rad('required ej matbara', objEjMatbara.length, 'grafiska objekt');
rad('fynd under 3:1', objFynd.length, 'grafiska objekt');
rad('beror', new Set(objFynd.map(g => g.art)).size, 'artefakter');
console.log('');
console.log('NT-BASLINJE status=' + doc.status);
process.exit(doc.status === 'godkänd' ? 0 : 1);
