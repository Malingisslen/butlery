#!/usr/bin/env node
// F2-R02 · BESTÄNDIGA PROV FÖR TRÄFFYTEKONTRAKTET.
//
// Kör: node tools/hit-fixtures.mjs --out=<katalog utanför repot>
//
//   A  self 48×48 mäts som 48×48
//   B  24 px ikon med explicit utpekad 48×48-target — targetens mått gäller
//   C  odeklarerad wrapper får INTE väljas heuristiskt
//   D  tvetydig referens (två noder med samma id) => unknown
//   E  target saknas i DOM:en => unknown
//   F  deklarerat 48×48 men renderat 44×48 => 44×48 och fynd
//   G  separata träffytor unioneras aldrig till en påhittad bounding box
//   H  kontroll utanför registrerad artefakt redovisas utanför produktnämnaren
//   I  data-hit på element utan roll hör till metadatauniversum, inte R-02
//   J  löptextdeklaration tolkas aldrig heuristiskt
//   P1…P5  populationsinvarianterna, prövade som kod
//
// Proven kör samma mätskript som en skarp körning: HIT_MEASURE importeras.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { HIT_MEASURE } from './hit-measure.mjs';
import { domslut, population, parseHit, klassificera, KRAV_PX } from './hit-contract.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanför reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{padding:6px}
 .k{display:flex;align-items:center;justify-content:center}
</style>

<div class="sc-item" id="a-self">
  <div class="k" data-a11y-role="button" data-a11y-name="A" data-hit="self"
    style="width:48px;height:48px">A</div>
</div>

<div class="sc-item" id="b-explicit-target">
  <!-- Wrappern är den deklarerade träffytan; ikonen är 24 px. -->
  <div class="k" data-hit-target="b-wrapper" style="width:48px;height:48px">
    <div data-a11y-role="button" data-a11y-name="B" data-hit="target:b-wrapper"
      style="width:24px;height:24px"></div>
  </div>
</div>

<div class="sc-item" id="c-odeklarerad-wrapper">
  <!-- Wrappern är 48×48 och ser ut som en träffyta, men INGET pekar ut den. -->
  <div class="k" style="width:48px;height:48px">
    <div data-a11y-role="button" data-a11y-name="C" style="width:24px;height:24px"></div>
  </div>
</div>

<div class="sc-item" id="d-tvetydig">
  <div data-hit-target="d-dubbel" style="width:48px;height:48px"></div>
  <div data-hit-target="d-dubbel" style="width:60px;height:60px"></div>
  <div data-a11y-role="button" data-a11y-name="D" data-hit="target:d-dubbel"
    style="width:24px;height:24px"></div>
</div>

<div class="sc-item" id="e-saknad-target">
  <div data-a11y-role="button" data-a11y-name="E" data-hit="target:e-finns-inte"
    style="width:24px;height:24px"></div>
</div>

<div class="sc-item" id="f-avsikt-mot-utfall">
  <!-- Löptexten säger 48×48. Renderingen säger 44×48. Renderingen vinner. -->
  <div class="k" data-hit-target="f-wrapper" style="width:44px;height:48px">
    <div data-a11y-role="button" data-a11y-name="F" data-hit="target:f-wrapper"
      style="width:24px;height:24px"></div>
  </div>
</div>

<div class="sc-item" id="g-tva-oar">
  <!-- Två skilda ytor bär samma id. Deras gemensamma bounding box vore
       120×48 — den ytan finns inte och får aldrig fabriceras. -->
  <div data-hit-target="g-o" style="width:48px;height:48px;position:absolute;left:0;top:0"></div>
  <div data-hit-target="g-o" style="width:48px;height:48px;position:absolute;left:72px;top:0"></div>
  <div data-a11y-role="button" data-a11y-name="G" data-hit="target:g-o"
    style="width:24px;height:24px"></div>
</div>

<div class="sc-item" id="i-metadata-utan-roll">
  <div data-hit="self" style="width:48px;height:48px"></div>
  <div data-a11y-role="button" data-a11y-name="I" data-hit="self"
    style="width:48px;height:48px"></div>
</div>

<!-- H · märkt kontroll UTANFÖR varje .sc-item -->
<div data-a11y-role="button" data-a11y-name="H" data-hit="self"
  style="width:48px;height:48px"></div>

<div class="sc-item" id="j-lopttext">
  <!-- Gammal löptextdeklaration. Tolkas aldrig heuristiskt. -->
  <div class="k" style="width:48px;height:48px">
    <div data-a11y-role="button" data-a11y-name="J" data-hit="raden 48 (rutan 24 är visuell)"
      style="width:24px;height:24px"></div>
  </div>
</div>`;

const fixturPath = join(outAbs, 'traffyteprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

/* ── minimal CDP ─────────────────────────────────────────────────────────── */
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9450 + (process.pid % 140);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-traffyteprov'), 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });

let data = null, verktygsfel = null;
try {
  let wsUrl = null;
  for (let i = 0; i < 60 && !wsUrl; i++) { await sleep(250);
    try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!wsUrl) throw new Error('Chrome startade aldrig sin debugger-port');
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP-anslutning misslyckades')); });
  let id = 0; const pend = new Map();
  ws.onmessage = m => { const msg = JSON.parse(m.data);
    if (msg.id && pend.has(msg.id)) { const { res, rej } = pend.get(msg.id); pend.delete(msg.id);
      msg.error ? rej(new Error(msg.error.message)) : res(msg.result); } };
  const call = (method, params = {}, sessionId) => new Promise((res, rej) => {
    const i = ++id; pend.set(i, { res, rej });
    ws.send(JSON.stringify({ id: i, method, params, ...(sessionId ? { sessionId } : {}) }));
    setTimeout(() => { if (pend.has(i)) { pend.delete(i); rej(new Error(method + ' svarade inte')); } }, 30000); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable'); await s('Runtime.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 900, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  const r = await s('Runtime.evaluate', { expression: HIT_MEASURE, returnByValue: true });
  if (r.exceptionDetails) throw new Error('mätskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 400));
  data = r.result.value;
  if (!data) throw new Error('mätskriptet returnerade inget');
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 15;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('TRÄFFYTEPROV status=VERKTYGSFEL godkända=0 av ' + ANTAL);
  process.exit(2);
}

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });
const p = namn => data.poster.find(x => x.namn === namn) || null;
const d = namn => { const x = p(namn); return x ? domslut(x) : null; };

{ const r = d('A');
  prov('A', 'self mäts som kontrollens eget renderade element',
    !!r && r.status === 'measured' && r.matt.w === 48 && r.matt.h === 48 &&
    r.basis === 'self' && r.uppfyller === true,
    r ? r.status + ' ' + JSON.stringify(r.matt) + ' basis ' + r.basis : 'saknas'); }

{ const r = d('B');
  prov('B', '24 px ikon med explicit utpekad target mäts på targeten',
    !!r && r.status === 'measured' && r.matt.w === 48 && r.matt.h === 48 &&
    r.basis === 'target:b-wrapper' && r.uppfyller === true,
    r ? r.status + ' ' + JSON.stringify(r.matt) + ' basis ' + r.basis : 'saknas'); }

{ const r = d('C');
  prov('C', 'odeklarerad wrapper väljs ALDRIG heuristiskt',
    !!r && r.status === 'unknown' && r.matt === null && r.uppfyller === null &&
    r.klass === 'ingen-deklaration',
    r ? r.status + ' · ' + r.why : 'saknas'); }

{ const r = d('D');
  prov('D', 'två noder med samma target-id ger unknown, inte ett val',
    !!r && r.status === 'unknown' && r.matt === null && /inte entydig/.test(r.why || ''),
    r ? r.status + ' · ' + r.why : 'saknas'); }

{ const r = d('E');
  prov('E', 'target som saknas i DOM:en ger unknown',
    !!r && r.status === 'unknown' && r.matt === null && /finns inte/.test(r.why || ''),
    r ? r.status + ' · ' + r.why : 'saknas'); }

{ const r = d('F');
  prov('F', 'renderade måttet vinner över den deklarerade avsikten',
    !!r && r.status === 'measured' && r.matt.w === 44 && r.matt.h === 48 && r.uppfyller === false,
    r ? JSON.stringify(r.matt) + ' uppfyller ' + KRAV_PX + ': ' + r.uppfyller : 'saknas'); }

{ const r = d('G'); const post = p('G');
  prov('G', 'separata träffytor unioneras aldrig till en påhittad bounding box',
    !!r && r.status === 'unknown' && r.matt === null && post.hitOar_st === 2,
    r ? r.status + ' · öar ' + post.hitOar_st + ' · ' + r.why : 'saknas'); }

{ const post = p('H');
  prov('H', 'kontroll utanför registrerad artefakt hamnar utanför produktnämnaren',
    !!post && klassificera(post) === 'utanfor-artefakt' && post.iRegistreradArtefakt === false,
    post ? klassificera(post) : 'saknas'); }

{ const utanRoll = data.poster.filter(x => !x.roll && x.dataHit !== null);
  prov('I', 'data-hit utan semantisk roll hör till metadatauniversum, inte R-02',
    utanRoll.length === 1 && klassificera(utanRoll[0]) === 'metadata-utan-roll',
    utanRoll.length + ' post(er) · klass ' + (utanRoll[0] ? klassificera(utanRoll[0]) : '—')); }

{ const r = d('J');
  prov('J', 'löptextdeklaration tolkas aldrig heuristiskt',
    !!r && r.status === 'unknown' && r.klass === 'deklaration-lopttext' &&
    r.deklareradAvsikt && r.deklareradAvsikt.bredd === 48 && r.matt === null,
    r ? r.status + ' · avsikt ' + JSON.stringify(r.deklareradAvsikt && r.deklareradAvsikt.bredd) +
        ' · mätvärde ' + r.matt : 'saknas'); }

/* ── Populationsinvarianterna, prövade som kod ───────────────────────────── */
const bas = data.poster;
const antalKontroller = bas.filter(x => x.roll).length;
const antalHit = bas.filter(x => x.dataHit !== null).length;
const rent = { kallDeklarationer: antalKontroller, kallDataHit: antalHit };

{ const r = population(bas, rent);
  prov('P1', 'ren population passerar alla invarianter och täcker exakt en gång',
    r.failClosed.status === 'godkänd' &&
    Object.values(r.klasser).reduce((a, b) => a + b, 0) === bas.length,
    r.failClosed.status + ' · klassumma ' +
    Object.values(r.klasser).reduce((a, b) => a + b, 0) + ' av ' + bas.length); }

{ const r = population(bas, { ...rent, kallDeklarationer: antalKontroller + 1 });
  prov('P2', 'källtext skild från rendering fäller rapporten',
    r.failClosed.status === 'FÄLLD' && /SOURCE DECLARATIONS/.test(r.failClosed.fel.join(' ')),
    r.failClosed.fel[0] || 'inget fel'); }

{ const r = population(bas, { ...rent, kallDataHit: antalHit + 3 });
  prov('P3', 'data-hit-bokföring som inte går ihop fäller rapporten',
    r.failClosed.status === 'FÄLLD' && /DATA-HIT/.test(r.failClosed.fel.join(' ')),
    r.failClosed.fel[0] || 'inget fel'); }

{ // Ett universum utan out-of-artifact-posten ska inte tyst tappa den.
  const utan = bas.filter(x => x.namn !== 'H');
  const r = population(utan, { kallDeklarationer: utan.filter(x => x.roll).length,
    kallDataHit: utan.filter(x => x.dataHit !== null).length });
  const medH = population(bas, rent);
  prov('P4', 'out-of-artifact-poster redovisas och ingår aldrig i produktnämnaren',
    medH.outsideRegisteredArtifacts.st === 1 &&
    medH.produktnamnare_st === bas.length - 1 - medH.klasser['metadata-utan-roll'] &&
    r.outsideRegisteredArtifacts.st === 0,
    'med H: ' + medH.outsideRegisteredArtifacts.st + ' utanför · nämnare ' +
    medH.produktnamnare_st + ' · utan H: ' + r.outsideRegisteredArtifacts.st); }

{ const r = population(bas, { ...rent, controlTimesViewport: antalKontroller });
  prov('P5', 'control×viewport får aldrig dela summeringsidentitet med metadata',
    r.failClosed.status === 'FÄLLD' && /skilda mätenheter/.test(r.failClosed.fel.join(' ')),
    r.failClosed.fel.find(f => /mätenheter/.test(f)) || 'inget fel'); }

for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(4) + r.vad);
  console.log('     ' + r.diag);
}
const godkända = resultat.filter(r => r.ok).length;
const status = godkända === ANTAL && resultat.length === ANTAL ? 'godkänd' : 'FÄLLD';
writeFileSync(join(outAbs, 'traffyteprov.json'), JSON.stringify({
  $schema: 'butlery-traffyteprov/1', kontroll: 'CHK-R-02',
  godkända, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('TRÄFFYTEPROV status=' + status + ' godkända=' + godkända + ' av ' + ANTAL);
process.exit(status === 'godkänd' ? 0 : 1);
