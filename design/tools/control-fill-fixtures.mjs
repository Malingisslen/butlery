#!/usr/bin/env node
// F2-NT · PROV FOR KONTROLLFYLLNINGENS ENUMERERING.  FI-01 … FI-16
//
// Kör: node tools/control-fill-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN PROVEN FINNS FOR
// Samma fel som gransen hade, en niva ner: kontrollens egen malade fyllning
// enumererades bara i den textmarkta grenen. En knapp med orange fyllning blev
// en matbar del nar det stod ett ord i den och foll bort nar den bara bar en
// glyf. Proven laser att detektionen ar textoberoende, att samma malade yta
// aldrig registreras tva ganger, och att enumereringen aldrig i sig skapar en
// tillamplighetsdom.
//
// FI-11 till FI-14 provar mot den verkliga korpusen och mot den maskinella
// rapporten i fas2/fyllningsenumerering.json.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { relation, konformans, TILLAMPLIGHET, KONFORMANS, EVIDENSKALLA } from './part-relation.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });

const SVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#17251d" ' +
  'stroke-width="1.75" data-icon="send"><path d="M20 4L4 11l6 3 3 6z"/></svg>';
const KROPP = 'display:inline-flex;align-items:center;justify-content:center;width:120px;height:48px';
const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#F5F4ED;color:#17251D;font:14px/1.4 system-ui}
 .sc-item{padding:12px;background:#F5F4ED}
</style>
<div class="sc-item" id="fi01-textknapp">
  <span data-a11y-role="button" data-a11y-name="Spara" data-hit="self"
    style="${KROPP};background:#CE7C1E">Spara</span></div>
<div class="sc-item" id="fi02-ikonknapp">
  <span data-a11y-role="button" data-a11y-name="Skicka" data-hit="self"
    style="${KROPP};background:#CE7C1E">${SVG}</span></div>
<div class="sc-item" id="fi04-genomskinlig">
  <span data-a11y-role="button" data-a11y-name="Naken" data-hit="self"
    style="${KROPP};background:transparent">${SVG}</span></div>
<div class="sc-item" id="fi05-alfa">
  <span data-a11y-role="button" data-a11y-name="Halvton" data-hit="self"
    style="${KROPP};background:rgba(23,37,29,0.5)">${SVG}</span></div>
<div class="sc-item" id="fi06-fyll-och-ram">
  <span data-a11y-role="button" data-a11y-name="Bada" data-hit="self"
    style="${KROPP};background:#CE7C1E;border:1.5px solid #3F5145;box-sizing:border-box">Bada</span></div>
<div class="sc-item" id="fi08-barnkropp">
  <span data-a11y-role="button" data-a11y-name="Barnkropp" data-hit="self"
    style="display:inline-block"><span style="${KROPP};background:#CE7C1E">${SVG}</span></span></div>
`;
const fixturPath = join(outAbs, 'fi-prov.html');
writeFileSync(fixturPath, FIXTUR);

const RAPPORT = JSON.parse(readFileSync(resolve('fas2/fyllningsenumerering.json'), 'utf8'));

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9960 + (process.pid % 120);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(outAbs, 'chrome-fiprov'), 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });

let data = null, verktygsfel = null;
try {
  let wsUrl = null;
  for (let i = 0; i < 60 && !wsUrl; i++) { await sleep(250);
    try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!wsUrl) throw new Error('Chrome startade aldrig');
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP misslyckades')); });
  let id = 0; const pend = new Map();
  ws.onmessage = m => { const msg = JSON.parse(m.data);
    if (msg.id && pend.has(msg.id)) { const { res, rej } = pend.get(msg.id); pend.delete(msg.id);
      msg.error ? rej(new Error(msg.error.message)) : res(msg.result); } };
  const call = (method, params = {}, sessionId) => new Promise((res, rej) => {
    const i = ++id; pend.set(i, { res, rej });
    ws.send(JSON.stringify({ id: i, method, params, ...(sessionId ? { sessionId } : {}) }));
    setTimeout(() => { if (pend.has(i)) { pend.delete(i); rej(new Error(method + ' svarade inte')); } }, 40000); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable'); await s('Runtime.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  const r = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
  if (r.exceptionDetails) throw new Error('matskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0,300));
  data = r.result.value;
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 16;
if (verktygsfel) { console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('FYLLNINGSPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2); }

const k = a => data.find(x => x.art === a);
const fyll = a => { const c = k(a); return c ? c.delar.filter(d => d.typ === 'fyllning') : []; };

/* FI-01 */
{ const f = fyll('fi01-textknapp');
  prov('FI-01', 'textknapp med egen malad fyllning enumereras',
    f.length === 1 && f[0].kvot !== null, f.length + ' fyllningsdelar · kvot ' +
    (f[0] ? f[0].kvot : '-')); }
/* FI-02 */
{ const f = fyll('fi02-ikonknapp'), t = fyll('fi01-textknapp');
  prov('FI-02', 'ikonknapp utan text med identisk fyllningsmekanism enumereras likadant',
    f.length === 1 && t.length === 1 && f[0].kvot === t[0].kvot,
    'ikon ' + (f[0] ? f[0].kvot : '-') + ' · text ' + (t[0] ? t[0].kvot : '-')); }
/* FI-03 */
{ const f = fyll('fi02-ikonknapp'), t = fyll('fi01-textknapp');
  const cIkon = k('fi02-ikonknapp'), cText = k('fi01-textknapp');
  prov('FI-03', 'textnarvaro paverkar inte fyllningens detektion',
    f.length === t.length && cIkon.harEgenText === false && cText.harEgenText === true,
    'harEgenText ikon=' + cIkon.harEgenText + ' text=' + cText.harEgenText +
    ' · lika manga fyllningsdelar: ' + (f.length === t.length)); }
/* FI-04 */
{ const f = fyll('fi04-genomskinlig');
  prov('FI-04', 'genomskinlig bakgrund blir ingen fyllningsdel',
    f.length === 0, f.length + ' fyllningsdelar'); }
/* FI-05 */
{ const f = fyll('fi05-alfa');
  prov('FI-05', 'alfafyllning komposiras mot den faktiska underliggande ytan',
    f.length === 1 && f[0].kvot !== null && f[0].farg && !/[\d.]+\)/.test(f[0].farg.split(',')[3] || ''),
    f.length + ' del · komposierad farg ' + (f[0] ? f[0].farg : '-') + ' mot ' +
    (f[0] ? f[0].angransande : '-')); }
/* FI-06 */
{ const c = k('fi06-fyll-och-ram');
  const f = c.delar.filter(d => d.typ === 'fyllning'), r = c.delar.filter(d => d.typ === 'ram');
  prov('FI-06', 'fyllning och grans pa samma kontroll blir tva separata delar utan dubblett',
    f.length === 1 && r.length === 1, f.length + ' fyllning, ' + r.length + ' ram'); }
/* FI-07 */
{ const alla = data.flatMap(c => c.delar.filter(d => d.typ === 'fyllning')
    .map(d => c.art + '#' + d.farg + '#' + d.angransande));
  const unika = new Set(alla);
  prov('FI-07', 'samma malade yta funnen via agare och fallback blir exakt en del',
    alla.length === unika.size, alla.length + ' fyllningsdelar, ' + unika.size + ' unika'); }
/* FI-08 · MEDVETEN AVGRANSNING, last mot korpusen.
 * Steget enumererar agarens egen malning. En kontroll vars kropp malas av ett
 * BARN och som samtidigt bar en glyf nar ingen gren som gor child-descent, och
 * far darfor ingen fyllningsdel. En generell fallback provades och drog in 44
 * inre former som inte var kontrollkroppar — den forkastades. Luckan ar
 * medveten och matt: korpusen innehaller 0 sadana forekomster. Provet laser
 * bade beteendet och nollan, sa att en framtida ritning som infor fallet
 * omedelbart syns. */
{ const c = k('fi08-barnkropp');
  const f = c.delar.filter(d => d.typ === 'fyllning');
  const iKorpusen = RAPPORT.A_kodvag.barnmaladeKropparUtanFyllning;
  prov('FI-08', 'barnmalad kropp med glyf ar en MEDVETEN avgransning och forekommer inte ' +
    'i korpusen',
    f.length === 0 && iKorpusen === 0,
    'fixturen ger ' + f.length + ' fyllningsdelar · korpusen innehaller ' + iKorpusen +
    ' sadana forekomster'); }
/* FI-09 */
{ const r = relation({ PART_DETECTED: true, PART_IDENTITY: 'fyllning',
    CONTROL_IDENTITY: 'x|1', MEASURED_RATIO: 1.2 });
  prov('FI-09', 'kvot under 3 skapar inte REQUIRED for en fyllning',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN, r.APPLICABILITY_VERDICT); }
/* FI-10 */
{ const r = relation({ PART_DETECTED: true, PART_IDENTITY: 'fyllning',
    CONTROL_IDENTITY: 'x|1', MEASURED_RATIO: 8.4 });
  prov('FI-10', 'kvot over 3 skapar inte REQUIRED for en fyllning',
    r.APPLICABILITY_VERDICT === TILLAMPLIGHET.UNKNOWN &&
    r.CONFORMANCE_VERDICT === KONFORMANS.UNKNOWN, r.APPLICABILITY_VERDICT); }
/* FI-11 */
{ const I = RAPPORT.I_plusknappen;
  prov('FI-11', 'plusknappens kanoniska fyllningsrelation matchar den tidigare direktmatningen',
    I.inomTolerans === true && Math.abs(I.avvikelse) <= 0.01 && I.ytaStammer && I.fargStammer,
    'kanonisk ' + I.RATIO_CANONICAL + ' · direkt ' + I.RATIO_DIREKTMATNING +
    ' · avvikelse ' + I.avvikelse); }
/* FI-12 */
{ const I = RAPPORT.I_plusknappen;
  prov('FI-12', 'plusknappens grans kan vara supplemental samtidigt som fyllningen ar required',
    I.BOUNDARY_APPLICABILITY === 'SUPPLEMENTAL_NOT_REQUIRED' &&
    I.FILL_APPLICABILITY === 'REQUIRED' && I.FILL_CONFORMANCE === 'REQUIRED_PASS' &&
    I.dubbletter === 1,
    'grans ' + I.BOUNDARY_APPLICABILITY + ' · fyllning ' + I.FILL_APPLICABILITY + '/' +
    I.FILL_CONFORMANCE + ' · fyllningsdelar ' + I.dubbletter); }
/* FI-13 */
{ const J = RAPPORT.J_saffransfillarna;
  prov('FI-13', 'saffransfyllningarna aterfar inte gamla tillamplighetsdomar av fixen',
    J.allaUNKNOWN === true && J.allaUtanKonformansdom === true,
    J.hittade + ' saffransfyllningar, alla UNKNOWN: ' + J.allaUNKNOWN); }
/* FI-14 */
{ const D = RAPPORT.D_rekonciliation, K = RAPPORT.K_korstab;
  prov('FI-14', 'hela grafikpopulationen rekoncilerar exakt',
    D.PREVIOUS_ONLY_FILL === 0 && D.DUPLICATE_FILL === 0 &&
    D.UNRESOLVED_FILL_IDENTITY === 0 && K.SUMMA === RAPPORT.E_population.FAKTISKT,
    'korstab ' + K.SUMMA + ' = population ' + RAPPORT.E_population.FAKTISKT +
    ' · dubbletter ' + D.DUPLICATE_FILL + ' · olosta ' + D.UNRESOLVED_FILL_IDENTITY); }
/* FI-15 */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status', '--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,'')).filter(f => f.endsWith('.dc.html'));
  prov('FI-15', 'ingen produktfil andras av blocket',
    !fel && produkt.length === 0, fel || produkt.length + ' andrade produktfiler'); }
/* FI-16 */
{ const O = RAPPORT.O_systemrekonciliation;
  prov('FI-16', 'ingen R-04-credit och ingen registerskrivning skapas',
    O.R04.skrivningar === 0 && O.R04.nyCredit === 0 && O.registerskrivningar === 0,
    'R-04 skrivningar ' + O.R04.skrivningar + ', credit ' + O.R04.nyCredit +
    ', registerskrivningar ' + O.registerskrivningar); }

for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(7) + r.vad);
  console.log('     ' + r.diag); }
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'fyllningsprov.json'), JSON.stringify({
  $schema: 'butlery-fyllningsprov/1', kontroll: 'CHK-FI-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('FYLLNINGSPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
