#!/usr/bin/env node
// F2-NT · BESTANDIGA PROV FOR COLOR-ONLY-PARBILDNINGEN.
//
// Kör: node tools/colour-only-fixtures.mjs --out=<katalog utanfor repot>
//
// CO-05 och CO-06 ar de tva prov som halIer modellen arlig:
//   CO-05  samma accessible name far ALDRIG para ihop tva komponenter
//   CO-06  olika accessible name far ALDRIG hindra ett par
// Utan dem ar "strukturell identitet" bara ett pastaende.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { parbilda } from './colour-only.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

const BOCK = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#F5F4ED" stroke-width="3" data-icon="check"><path d="M4 12l6 6 10-12"/></svg>';
const BANA = (farg, lage) => 'display:inline-flex;align-items:center;justify-content:' + lage +
  ';width:44px;height:26px;border-radius:999px;background:' + farg + ';padding:0 3px';
const KNOPP = 'width:20px;height:20px;border-radius:999px;background:#F5F4ED';
const RUTA = 'display:inline-flex;align-items:center;justify-content:center;width:24px;height:24px;border-radius:6px;box-sizing:border-box;';
const AGARE = 'display:inline-flex;align-items:center;justify-content:center;width:48px;height:48px';

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{padding:10px;background:#fff}
</style>

<!-- CO-01 · samma deklarerade komponent, tva tillstand, ENBART bantans farg skiljer -->
<div class="sc-item" id="co01a">
  <span data-a11y-role="switch" data-a11y-name="Paminnelser" data-a11y-state="on" data-hit="self"
    style="${AGARE}"><span data-component="co-toggle" style="${BANA('#3f6b4f', 'flex-end')}"><span style="${KNOPP}"></span></span></span>
</div>
<div class="sc-item" id="co01b">
  <span data-a11y-role="switch" data-a11y-name="Paminnelser" data-a11y-state="off" data-hit="self"
    style="${AGARE}"><span data-component="co-toggle" style="${BANA('#ccd1c2', 'flex-end')}"><span style="${KNOPP}"></span></span></span>
</div>

<!-- CO-02 · samma komponent, men knoppens lage skiljer ocksa -->
<div class="sc-item" id="co02a">
  <span data-a11y-role="switch" data-a11y-name="Ljud" data-a11y-state="on" data-hit="self"
    style="${AGARE}"><span data-component="co-toggle-lage" style="${BANA('#3f6b4f', 'flex-end')}"><span style="${KNOPP}"></span></span></span>
</div>
<div class="sc-item" id="co02b">
  <span data-a11y-role="switch" data-a11y-name="Ljud" data-a11y-state="off" data-hit="self"
    style="${AGARE}"><span data-component="co-toggle-lage" style="${BANA('#ccd1c2', 'flex-start')}"><span style="${KNOPP}"></span></span></span>
</div>

<!-- CO-03 · kryssruta: bocken tillkommer, alltsa inte color-only -->
<div class="sc-item" id="co03a">
  <span data-a11y-role="checkbox" data-a11y-name="Mjolk" data-a11y-state="checked" data-hit="self"
    style="${AGARE}"><span data-component="co-ruta" style="${RUTA}background:#24382c">${BOCK}</span></span>
</div>
<div class="sc-item" id="co03b">
  <span data-a11y-role="checkbox" data-a11y-name="Mjolk" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}"><span data-component="co-ruta" style="${RUTA}border:1px solid #7d897c"></span></span>
</div>

<!-- CO-04 · tillstand men ingen deklarerad komponent: pairingUnknown -->
<div class="sc-item" id="co04a">
  <span data-a11y-role="checkbox" data-a11y-name="Odeklarerad" data-a11y-state="checked" data-hit="self"
    style="${AGARE}"><span style="${RUTA}background:#24382c"></span></span>
</div>
<div class="sc-item" id="co04b">
  <span data-a11y-role="checkbox" data-a11y-name="Odeklarerad" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}"><span style="${RUTA}border:1px solid #7d897c"></span></span>
</div>

<!-- CO-05 · SAMMA namn, OLIKA deklarerad komponent: far inte paras -->
<div class="sc-item" id="co05a">
  <span data-a11y-role="checkbox" data-a11y-name="Aktiv" data-a11y-state="checked" data-hit="self"
    style="${AGARE}"><span data-component="co-namnfalla-ett" style="${RUTA}background:#24382c"></span></span>
</div>
<div class="sc-item" id="co05b">
  <span data-a11y-role="checkbox" data-a11y-name="Aktiv" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}"><span data-component="co-namnfalla-tva" style="${RUTA}border:1px solid #7d897c"></span></span>
</div>

<!-- CO-06 · OLIKA namn, SAMMA deklarerade komponent: maste paras anda -->
<div class="sc-item" id="co06a">
  <span data-a11y-role="switch" data-a11y-name="Vegetariskt" data-a11y-state="on" data-hit="self"
    style="${AGARE}"><span data-component="co-olika-namn" style="${BANA('#3f6b4f', 'flex-end')}"><span style="${KNOPP}"></span></span></span>
</div>
<div class="sc-item" id="co06b">
  <span data-a11y-role="switch" data-a11y-name="Glutenfritt" data-a11y-state="off" data-hit="self"
    style="${AGARE}"><span data-component="co-olika-namn" style="${BANA('#ccd1c2', 'flex-end')}"><span style="${KNOPP}"></span></span></span>
</div>

<!-- CO-07 · tva olika deklarerade komponenter i samma kontroll: pairingUnknown -->
<div class="sc-item" id="co07a">
  <span data-a11y-role="checkbox" data-a11y-name="Dubbel" data-a11y-state="checked" data-hit="self"
    style="${AGARE}"><span data-component="co-dubbel-ett" style="${RUTA}background:#24382c"></span><span data-component="co-dubbel-tva" style="${RUTA}border:1px solid #7d897c"></span></span>
</div>

<!-- CO-08 · deklarationen ligger i en ANNAN semantisk kontroll: raknas inte -->
<div class="sc-item" id="co08a">
  <span data-a11y-role="checkbox" data-a11y-name="Yttre ruta" data-a11y-state="checked" data-hit="self"
    style="${AGARE}"><span data-a11y-role="button" data-a11y-name="Inre knapp" data-hit="self"
      ><span data-component="co-innanfor" style="${RUTA}background:#24382c"></span></span></span>
</div>`;

const fixturPath = join(outAbs, 'coprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9820 + (process.pid % 120);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-coprov'), 'about:blank'],
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
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 1200, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  const r = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
  if (r.exceptionDetails) throw new Error('matskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 300));
  data = r.result.value;
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 8;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('COLORONLYPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const r = parbilda(data);
const parAv = f => r.par.filter(p => p.familj.startsWith(f + ' '));
const okand = namn => r.pairingUnknown.filter(x => x.namn === namn);
const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });

{ const p = parAv('co-toggle')[0];
  prov('CO-01', 'samma komponent, bara bantans farg skiljer: color-only',
    !!p && p.colorOnly === true && p.ickeFargSignaler.length === 0,
    p ? 'par ' + p.stateA + '/' + p.stateB + ' · signaler ' + p.ickeFargSignaler.length : 'inget par bildades'); }

{ const p = parAv('co-toggle-lage')[0];
  prov('CO-02', 'knoppens lage skiljer: inte color-only',
    !!p && p.colorOnly === false && p.ickeFargSignaler.some(s => s.nyckel === 'thumbLage'),
    p ? p.ickeFargSignaler.map(s => s.nyckel).join(', ') : 'inget par bildades'); }

{ const p = parAv('co-ruta')[0];
  prov('CO-03', 'bocken tillkommer: inte color-only',
    !!p && p.colorOnly === false && p.ickeFargSignaler.some(s => s.nyckel === 'bock'),
    p ? p.ickeFargSignaler.map(s => s.nyckel).join(', ') : 'inget par bildades'); }

{ const u = okand('Odeklarerad');
  prov('CO-04', 'tillstand utan deklarerad komponent blir pairingUnknown, aldrig "ingen skillnad"',
    u.length === 2 && r.par.every(p => p.namnA !== 'Odeklarerad'),
    u.length ? u.length + ' pairingUnknown · ' + u[0].varfor.slice(0, 60) : 'ingen pairingUnknown'); }

{ const parade = r.par.filter(p => p.namnA === 'Aktiv' || p.namnB === 'Aktiv');
  prov('CO-05', 'samma accessible name parar INTE ihop tva olika komponenter',
    parade.length === 0 && r.familjer_st >= 2,
    parade.length ? 'FEL: ' + parade.length + ' par bildades pa namnet' : '0 par pa namnet'); }

{ const p = parAv('co-olika-namn')[0];
  prov('CO-06', 'olika accessible name hindrar INTE ett par inom samma komponent',
    !!p && p.namnA !== p.namnB && p.colorOnly === true,
    p ? p.namnA + ' / ' + p.namnB + ' · color-only ' + p.colorOnly : 'inget par bildades'); }

{ const u = okand('Dubbel');
  prov('CO-07', 'tva deklarerade komponenter i samma kontroll ger pairingUnknown',
    u.length === 1 && /2 olika data-component/.test(u[0].varfor),
    u.length ? u[0].varfor.slice(0, 70) : 'ingen pairingUnknown'); }

{ const u = okand('Yttre ruta');
  const inre = r.pairingUnknown.concat(r.par).length;
  prov('CO-08', 'deklaration inne i en annan semantisk kontroll raknas inte',
    u.length === 1 && /ingen deklarerad data-component/.test(u[0].varfor),
    u.length ? u[0].varfor.slice(0, 70) : 'kontrollen tog den inre deklarationen'); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('familjer ' + r.familjer_st + ' · par ' + r.par_st + ' · color-only ' + r.colorOnly_st +
  ' · pairingUnknown ' + r.pairingUnknown_st);
console.log('COLORONLYPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'coprov.json'), JSON.stringify({ resultat, r }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
