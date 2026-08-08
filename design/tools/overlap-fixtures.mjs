#!/usr/bin/env node
// F2-R02 · BESTANDIGA PROV FOR OVERLAPP-AUDITEN.
//
// Kör: node tools/overlap-fixtures.mjs --out=<katalog utanfor repot>
//
//   O-A  explicit overlager, underlaget BELAGT suspenderat  → inget fynd
//   O-B  tva kontroller i samma aktiva lager                → fynd
//   O-C  egen yta med pointer-events:none                   → fynd
//   O-D  aldrig samtidigt synliga                           → inget fynd
//   O-E  kant mot kant, snitt = 0                           → inget par alls
//   O-F  ett enda pixels overlapp                           → fynd
//   O-G  glyf och dess egen agare                           → inget par alls
//
// Proven kor EXAKT samma auditskript som den skarpa korningen.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { OVERLAP_AUDIT } from './hit-overlap-audit.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{position:relative;margin:0 0 40px;padding:8px;width:400px;height:120px}
</style>

<div class="sc-item" id="oa-suspenderat-underlag">
  <!-- Underlaget bar UTTALAD suspenderingsmarkor. Det ar evidensen. -->
  <div data-a11y-role="button" data-a11y-name="Under" data-hit="self" inert
    style="position:absolute;left:10px;top:10px;width:200px;height:60px;background:#eee"></div>
  <div data-a11y-role="button" data-a11y-name="Over" data-hit="self"
    style="position:absolute;left:10px;top:10px;width:200px;height:60px;background:#ccd1c2"></div>
</div>

<div class="sc-item" id="ob-samma-lager">
  <!-- Inga lagermarkorer, men de ar bevisat samtidigt aktiva: bagge ar
       traffbara och ingen ar suspenderad. -->
  <div data-a11y-role="button" data-a11y-name="Vanster" data-hit="self"
    style="position:absolute;left:10px;top:10px;width:120px;height:60px;background:#eee"></div>
  <div data-a11y-role="button" data-a11y-name="Hoger" data-hit="self"
    style="position:absolute;left:100px;top:10px;width:120px;height:60px;background:#ddd"></div>
</div>

<div class="sc-item" id="oc-egen-yta-ej-traffbar">
  <div data-a11y-role="button" data-a11y-name="Under" data-hit="self"
    style="position:absolute;left:10px;top:10px;width:200px;height:60px;background:#eee"></div>
  <div data-a11y-role="button" data-a11y-name="Over" data-hit="self"
    style="position:absolute;left:10px;top:10px;width:200px;height:60px;background:rgba(0,0,0,.15);pointer-events:none"></div>
</div>

<div class="sc-item" id="od-olika-scrollage" style="height:520px">
  <div style="height:60px;overflow-y:auto;border:1px solid #ccc">
    <div style="height:400px"></div>
    <div data-a11y-role="button" data-a11y-name="Bortscrollad" data-hit="self"
      style="width:200px;height:60px;background:#eee"></div>
  </div>
  <div data-a11y-role="button" data-a11y-name="Utanfor" data-hit="self"
    style="position:absolute;left:10px;top:430px;width:200px;height:60px;background:#ddd"></div>
</div>

<div class="sc-item" id="oe-kant-mot-kant">
  <div data-a11y-role="button" data-a11y-name="Ett" data-hit="self"
    style="position:absolute;left:10px;top:10px;width:48px;height:48px;background:#eee"></div>
  <div data-a11y-role="button" data-a11y-name="Tva" data-hit="self"
    style="position:absolute;left:58px;top:10px;width:48px;height:48px;background:#ddd"></div>
</div>

<div class="sc-item" id="of-en-pixel">
  <div data-a11y-role="button" data-a11y-name="Ett" data-hit="self"
    style="position:absolute;left:10px;top:10px;width:48px;height:48px;background:#eee"></div>
  <div data-a11y-role="button" data-a11y-name="Tva" data-hit="self"
    style="position:absolute;left:57px;top:10px;width:48px;height:48px;background:#ddd"></div>
</div>

<div class="sc-item" id="og-glyf-i-sin-agare">
  <!-- Kontrollen pekar ut sin omslutande yta. Glyfen inuti ar inte en egen
       kontroll och ska inte jamforas som en andra yta. -->
  <div data-hit-target="og-yta" style="position:absolute;left:10px;top:10px;width:48px;height:48px;background:#eee">
    <span data-a11y-role="button" data-a11y-name="Glyf" data-hit="target:og-yta"
      style="display:block;width:24px;height:24px;background:#999"></span>
  </div>
</div>`;

const fixturPath = join(outAbs, 'overlappprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9130 + (process.pid % 120);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-overlappprov'), 'about:blank'],
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
    setTimeout(() => { if (pend.has(i)) { pend.delete(i); rej(new Error(method + ' svarade inte')); } }, 30000); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable'); await s('Runtime.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 900, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  const r = await s('Runtime.evaluate', { expression: OVERLAP_AUDIT, returnByValue: true });
  if (r.exceptionDetails) throw new Error('auditskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 300));
  data = r.result.value;
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 7;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('OVERLAPPPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const par = a => data.par.filter(x => x.art === a);
const ejTraff = a => data.ejTraffbara.filter(x => x.art === a);
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

{ const p = par('oa-suspenderat-underlag')[0];
  prov('O-A', 'belagt suspenderat underlag ger intentionalOverlay, inget fynd',
    !!p && p.geometricOverlap === true && p.relation === 'intentionalOverlay' && p.produktfynd === false,
    p ? p.relation + ' · ' + p.evidens.slice(0, 70) : 'paret saknas'); }

{ const p = par('ob-samma-lager')[0];
  prov('O-B', 'tva kontroller utan lagerevidens far INTE bli intentionalOverlay',
    !!p && p.geometricOverlap === true && p.relation !== 'intentionalOverlay' &&
    p.intersection.area > 0 && p.lostOwnHitArea.A > 0 && p.lostOwnHitArea.B > 0,
    p ? p.relation + ' · snitt ' + p.intersection.area + ' · forlorad andel A ' +
        p.lostOwnHitArea.A + ' B ' + p.lostOwnHitArea.B : 'paret saknas'); }

{ const e = ejTraff('oc-egen-yta-ej-traffbar');
  prov('O-C', 'egen yta med pointer-events:none ar ett eget fel',
    e.length === 1 && e[0].namn === 'Over',
    e.length ? e.map(x => x.namn).join(', ') : 'inget registrerat'); }

{ const p = par('od-olika-scrollage')[0];
  prov('O-D', 'olika scrollpositioner ger notSimultaneous, inget fynd',
    !!p && p.relation === 'notSimultaneous' && p.produktfynd === false,
    p ? p.relation : 'paret saknas'); }

{ const p = par('oe-kant-mot-kant');
  prov('O-E', 'kant mot kant ger inget par alls',
    p.length === 0, p.length + ' par'); }

{ const p = par('of-en-pixel')[0];
  prov('O-F', 'ett enda pixels overlapp registreras — ingen tolerans',
    !!p && p.intersection.area > 0 && p.intersection.w > 0 && p.intersection.w <= 1.5,
    p ? 'snitt ' + p.intersection.w + '×' + p.intersection.h + ' = ' + p.intersection.area : 'paret saknas'); }

{ const p = par('og-glyf-i-sin-agare');
  prov('O-G', 'glyf och dess egen agare jamfors inte som tva ytor',
    p.length === 0, p.length + ' par'); }

for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(6) + r.vad);
  console.log('     ' + r.diag);
}
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'overlappprov.json'), JSON.stringify({
  $schema: 'butlery-overlappprov/2', kontroll: 'CHK-R-02',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('OVERLAPPPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
