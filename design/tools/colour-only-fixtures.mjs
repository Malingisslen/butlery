#!/usr/bin/env node
// F2-NT · BESTANDIGA PROV FOR COLOR-ONLY-PARBILDNINGEN.
//
// Kör: node tools/colour-only-fixtures.mjs --out=<katalog utanfor repot>
//
// Identiteten ar authored: data-state-group pa kontrollen sjalv.
//
// Fyra prov finns for att halIa modellen arlig:
//   CO-05  samma accessible name parar ALDRIG ihop tva grupper
//   CO-06  olika accessible name hindrar ALDRIG ett par
//   CO-09  data-component racker inte — komponenttyp ar inte identitet
//   CO-11  en grupp med bara ett tillstand blir aldrig godkand

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { parbilda, parseGrupp } from './colour-only.mjs';

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

const reglage = (namn, state, grupp, farg, lage, extraAttr = '') =>
  `<span data-a11y-role="switch" data-a11y-name="${namn}" data-a11y-state="${state}" data-hit="self" ${
    grupp === null ? '' : 'data-state-group="' + grupp + '"'} ${extraAttr}
    style="${AGARE}"><span style="${BANA(farg, lage)}"><span style="${KNOPP}"></span></span></span>`;
const ruta = (namn, state, grupp, stil, inne = '', extraAttr = '') =>
  `<span data-a11y-role="checkbox" data-a11y-name="${namn}" data-a11y-state="${state}" data-hit="self" ${
    grupp === null ? '' : 'data-state-group="' + grupp + '"'} ${extraAttr}
    style="${AGARE}"><span style="${RUTA}${stil}">${inne}</span></span>`;

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{padding:10px;background:#fff}
</style>

<!-- CO-01 · samma grupp, tva tillstand, ENBART bantans farg skiljer -->
<div class="sc-item" id="co01a">${reglage('Paminnelser', 'on', 'coprov-paminnelser', '#3f6b4f', 'flex-end')}</div>
<div class="sc-item" id="co01b">${reglage('Paminnelser', 'off', 'coprov-paminnelser', '#ccd1c2', 'flex-end')}</div>

<!-- CO-02 · samma grupp, men knoppens lage skiljer ocksa -->
<div class="sc-item" id="co02a">${reglage('Ljud', 'on', 'coprov-ljud', '#3f6b4f', 'flex-end')}</div>
<div class="sc-item" id="co02b">${reglage('Ljud', 'off', 'coprov-ljud', '#ccd1c2', 'flex-start')}</div>

<!-- CO-03 · bocken tillkommer, alltsa inte color-only -->
<div class="sc-item" id="co03a">${ruta('Mjolk', 'checked', 'coprov-varurad', 'background:#24382c', BOCK)}</div>
<div class="sc-item" id="co03b">${ruta('Mjolk', 'unchecked', 'coprov-varurad', 'border:1px solid #7d897c')}</div>

<!-- CO-04 · tillstand men ingen grupp alls: pairingUnknown -->
<div class="sc-item" id="co04a">${ruta('Odeklarerad', 'checked', null, 'background:#24382c')}</div>
<div class="sc-item" id="co04b">${ruta('Odeklarerad', 'unchecked', null, 'border:1px solid #7d897c')}</div>

<!-- CO-05 · SAMMA namn, OLIKA grupp: far inte paras -->
<div class="sc-item" id="co05a">${ruta('Aktiv', 'checked', 'coprov-namnfalla-ett', 'background:#24382c')}</div>
<div class="sc-item" id="co05b">${ruta('Aktiv', 'unchecked', 'coprov-namnfalla-tva', 'border:1px solid #7d897c')}</div>

<!-- CO-06 · OLIKA namn, SAMMA grupp: maste paras anda -->
<div class="sc-item" id="co06a">${reglage('Vegetariskt', 'on', 'coprov-olika-namn', '#3f6b4f', 'flex-end')}</div>
<div class="sc-item" id="co06b">${reglage('Glutenfritt', 'off', 'coprov-olika-namn', '#ccd1c2', 'flex-end')}</div>

<!-- CO-07 · ogiltig gruppnyckel: pairingUnknown, aldrig tyst accepterad -->
<div class="sc-item" id="co07a">${ruta('Ogiltig', 'checked', 'CoProv Fel', 'background:#24382c')}</div>

<!-- CO-08 · gruppen spanner over tva artefakter, samma konceptuella kontroll -->
<div class="sc-item" id="co08a">${ruta('Visa allt', 'checked', 'coprov-over-artefakter', 'background:#24382c', BOCK)}</div>
<div class="sc-item" id="co08b">${ruta('Visa allt', 'unchecked', 'coprov-over-artefakter', 'border:1px solid #7d897c')}</div>

<!-- CO-09 · data-component finns men ingen grupp: komponenttyp racker inte -->
<div class="sc-item" id="co09a">
  <span data-a11y-role="switch" data-a11y-name="Typmarkt" data-a11y-state="on" data-hit="self"
    style="${AGARE}"><span data-component="toggle" style="${BANA('#3f6b4f', 'flex-end')}"><span style="${KNOPP}"></span></span></span>
</div>
<div class="sc-item" id="co09b">
  <span data-a11y-role="switch" data-a11y-name="Typmarkt" data-a11y-state="off" data-hit="self"
    style="${AGARE}"><span data-component="toggle" style="${BANA('#ccd1c2', 'flex-end')}"><span style="${KNOPP}"></span></span></span>
</div>

<!-- CO-10 · tva instanser i SAMMA tillstand som ser olika ut: tvetydig -->
<div class="sc-item" id="co10a">${ruta('Rad ett', 'checked', 'coprov-tvetydig', 'background:#24382c', BOCK)}</div>
<div class="sc-item" id="co10b">${ruta('Rad tva', 'checked', 'coprov-tvetydig', 'background:#24382c')}</div>
<div class="sc-item" id="co10c">${ruta('Rad tre', 'unchecked', 'coprov-tvetydig', 'border:1px solid #7d897c')}</div>

<!-- CO-11 · grupp med bara ETT tillstand: single-state, aldrig godkand -->
<div class="sc-item" id="co11a">${ruta('Ensam ett', 'checked', 'coprov-singel', 'background:#24382c', BOCK)}</div>
<div class="sc-item" id="co11b">${ruta('Ensam tva', 'checked', 'coprov-singel', 'background:#24382c', BOCK)}</div>

<!-- CO-13 · samma tillstand, olika lang etikett: bredden skiljer men
     tillstandet ar detsamma. Far INTE bli tvetydig. -->
<div class="sc-item" id="co13a"><span style="display:inline-flex;align-items:center;gap:8px">${ruta('Kort', 'checked', 'coprov-bredd', 'background:#24382c', BOCK)}<span>Ris</span></span></div>
<div class="sc-item" id="co13b"><span style="display:inline-flex;align-items:center;gap:8px">${ruta('Lang', 'checked', 'coprov-bredd', 'background:#24382c', BOCK)}<span>Krossade tomater med basilika och vitlok</span></span></div>
<div class="sc-item" id="co13c">${ruta('Obockad', 'unchecked', 'coprov-bredd', 'border:1px solid #7d897c')}</div>

<!-- CO-12 · flera instanser per tillstand som ser LIKADANA ut: paras anda -->
<div class="sc-item" id="co12a">${ruta('Vara ett', 'unchecked', 'coprov-lista', 'border:1px solid #7d897c')}</div>
<div class="sc-item" id="co12b">${ruta('Vara tva', 'unchecked', 'coprov-lista', 'border:1px solid #7d897c')}</div>
<div class="sc-item" id="co12c">${ruta('Vara tre', 'checked', 'coprov-lista', 'background:#24382c')}</div>`;

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
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 1600, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  const r = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
  if (r.exceptionDetails) throw new Error('matskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 300));
  data = r.result.value;
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 13;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('COLORONLYPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const r = parbilda(data);
const par = g => r.par.filter(p => p.familj === g);
const okand = namn => r.pairingUnknown.filter(x => x.namn === namn);
const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });

{ const p = par('coprov-paminnelser')[0];
  prov('CO-01', 'samma grupp, bara bantans farg skiljer: color-only',
    !!p && p.colorOnly === true && p.ickeFargSignaler.length === 0,
    p ? 'par ' + p.stateA + '/' + p.stateB + ' · signaler ' + p.ickeFargSignaler.length : 'inget par bildades'); }

{ const p = par('coprov-ljud')[0];
  prov('CO-02', 'knoppens lage skiljer: inte color-only',
    !!p && p.colorOnly === false && p.ickeFargSignaler.some(s => s.nyckel === 'thumbLage'),
    p ? p.ickeFargSignaler.map(s => s.nyckel).join(', ') : 'inget par bildades'); }

{ const p = par('coprov-varurad')[0];
  prov('CO-03', 'bocken tillkommer: inte color-only',
    !!p && p.colorOnly === false && p.ickeFargSignaler.some(s => s.nyckel === 'bock'),
    p ? p.ickeFargSignaler.map(s => s.nyckel).join(', ') : 'inget par bildades'); }

{ const u = okand('Odeklarerad');
  prov('CO-04', 'tillstand utan grupp blir pairingUnknown, aldrig "ingen skillnad"',
    u.length === 2 && /ingen data-state-group/.test(u[0].varfor) &&
    r.par.every(p => p.namnA !== 'Odeklarerad'),
    u.length ? u.length + ' pairingUnknown · ' + u[0].varfor.slice(0, 50) : 'ingen pairingUnknown'); }

{ const parade = r.par.filter(p => p.namnA === 'Aktiv' || p.namnB === 'Aktiv');
  prov('CO-05', 'samma accessible name parar INTE ihop tva grupper',
    parade.length === 0 && r.grupper_st >= 2,
    parade.length ? 'FEL: ' + parade.length + ' par bildades pa namnet' : '0 par pa namnet'); }

{ const p = par('coprov-olika-namn')[0];
  prov('CO-06', 'olika accessible name hindrar INTE ett par inom samma grupp',
    !!p && p.namnA !== p.namnB && p.colorOnly === true,
    p ? p.namnA + ' / ' + p.namnB + ' · color-only ' + p.colorOnly : 'inget par bildades'); }

{ const u = okand('Ogiltig');
  prov('CO-07', 'ogiltig gruppnyckel blir pairingUnknown, aldrig tyst accepterad',
    u.length === 1 && /foljer inte formen/.test(u[0].varfor) &&
    parseGrupp('CoProv Fel').form === 'ogiltig',
    u.length ? u[0].varfor.slice(0, 70) : 'nyckeln accepterades'); }

{ const p = par('coprov-over-artefakter')[0];
  prov('CO-08', 'en grupp far spanna over tva artefakter',
    !!p && p.artA !== p.artB && p.colorOnly === false,
    p ? p.artA + ' mot ' + p.artB : 'inget par bildades'); }

{ const p = par('toggle') .concat(r.par.filter(p => p.namnA === 'Typmarkt'));
  const u = okand('Typmarkt');
  prov('CO-09', 'data-component racker inte — komponenttyp ar inte identitet',
    p.length === 0 && u.length === 2,
    p.length ? 'FEL: ' + p.length + ' par bildades pa komponenttypen' : u.length + ' pairingUnknown'); }

{ const t = r.tvetydiga.filter(x => x.familj === 'coprov-tvetydig');
  prov('CO-10', 'tva instanser i samma tillstand som ser olika ut upptacks',
    t.length === 1 && t[0].state === 'checked' && t[0].instanser === 2 && par('coprov-tvetydig').length === 0,
    t.length ? t[0].varfor.slice(0, 80) : 'tvetydigheten upptacktes inte'); }

{ const s = r.singelState.filter(x => x.familj === 'coprov-singel');
  prov('CO-11', 'grupp med bara ett tillstand blir single-state, aldrig godkand',
    s.length === 1 && s[0].instanser === 2 && par('coprov-singel').length === 0,
    s.length ? s[0].varfor.slice(0, 80) : 'gruppen behandlades inte som single-state'); }

{ const p = par('coprov-lista')[0];
  prov('CO-12', 'flera likadana instanser per tillstand paras anda',
    !!p && p.colorOnly === false && r.tvetydiga.every(x => x.familj !== 'coprov-lista'),
    p ? 'par ' + p.stateA + '/' + p.stateB + ' · ' + p.ickeFargSignaler.map(s => s.nyckel).join(', ') : 'inget par bildades'); }

{ const p = par('coprov-bredd')[0];
  const t = r.tvetydiga.filter(x => x.familj === 'coprov-bredd');
  prov('CO-13', 'olika lang etikett gor inte representanten tvetydig',
    !!p && t.length === 0,
    t.length ? 'FEL: blev tvetydig pa bredden' : (p ? 'par ' + p.stateA + '/' + p.stateB : 'inget par bildades')); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('grupper ' + r.grupper_st + ' · par ' + r.par_st + ' · color-only ' + r.colorOnly_st +
  ' · single-state ' + r.grupper_singelState_st + ' · tvetydiga ' + r.grupper_tvetydiga_st +
  ' · pairingUnknown ' + r.pairingUnknown_kontroller_st + ' · invariant ' + (r.invariant_ok ? 'ok' : 'BRUTEN'));
console.log('COLORONLYPROV status=' + (ok === ANTAL && r.invariant_ok ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'coprov.json'), JSON.stringify({ resultat, r }, null, 1) + '\n');
process.exit(ok === ANTAL && r.invariant_ok ? 0 : 1);
