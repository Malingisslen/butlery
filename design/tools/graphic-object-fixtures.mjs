#!/usr/bin/env node
// F2-NT · BESTANDIGA PROV FOR GRAFIK UTANFOR KONTROLLER.
//
// Kör: node tools/graphic-object-fixtures.mjs --out=<katalog utanfor repot>
//
// GO-03 ar anti-cirkularitetsprovet: ett deklarerat informativt objekt med
// kontrast 1,00 forblir barare och blir ett fynd. GO-04 ar fail closed: ett
// odeklarerat objekt blir aldrig tyst dekorativt.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { GRAPHIC_OBJECTS } from './graphic-objects.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

const SVG = (attr, farg, extra = '') => '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="' +
  farg + '" stroke-width="2" ' + attr + '>' + extra + '<path d="M12 3l9 16H3z"/></svg>';

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{padding:10px;background:#fff}
</style>

<div class="sc-item" id="go01-deklarerat-dekorativ">
  ${SVG('data-icon="sparkle" aria-hidden="true"', '#eeeeee')}
  <span>Texten sager allt som behovs</span>
</div>

<div class="sc-item" id="go02-deklarerat-informativ">
  ${SVG('data-icon="triangle-alert" role="img" aria-label="Varning"', '#8f3324')}
</div>

<div class="sc-item" id="go03-informativ-utan-kontrast">
  <!-- Deklarerat informativ men malad vitt mot vitt: kvot 1,00.
       Ska forbli barare och bli ett fynd, inte omklassificeras. -->
  ${SVG('data-icon="triangle-alert" role="img" aria-label="Varning"', '#ffffff')}
</div>

<div class="sc-item" id="go04-odeklarerad">
  <!-- Bara data-icon. Formen ar namngiven, funktionen ar det inte. -->
  ${SVG('data-icon="info"', '#c9c9c9')}
</div>

<div class="sc-item" id="go05-i-en-kontroll">
  <!-- Grafik inne i en kontroll hor till kontrollpopulationen och far
       aldrig dyka upp har. -->
  <span data-a11y-role="button" data-a11y-name="Stang" data-hit="self"
    style="display:inline-flex;width:48px;height:48px;align-items:center;justify-content:center">${SVG('data-icon="x"', '#24382c')}</span>
</div>

<div class="sc-item" id="go06-titel-i-svg">
  ${SVG('data-icon="lock"', '#24382c', '<title>Last</title>')}
</div>`;

const fixturPath = join(outAbs, 'goprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9860 + (process.pid % 120);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-goprov'), 'about:blank'],
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
  const r = await s('Runtime.evaluate', { expression: GRAPHIC_OBJECTS, returnByValue: true });
  if (r.exceptionDetails) throw new Error('matskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 300));
  data = r.result.value;
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 6;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('GRAFIKOBJEKTPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const o = a => data.find(x => x.art === a);
const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });

{ const d = o('go01-deklarerat-dekorativ');
  prov('GO-01', 'deklarerat dekorativt objekt mats inte',
    !!d && d.carrier === 'decorative' && d.status === 'ejKravd' && d.kvot === null,
    d ? d.carrier + ' · ' + d.motivering : 'objektet saknas'); }

{ const d = o('go02-deklarerat-informativ');
  prov('GO-02', 'deklarerat informativt objekt mats mot sin angransande yta',
    !!d && d.carrier === 'graphicalObjectCarrier' && d.status === 'matt' && d.kvot >= 3,
    d ? d.carrier + ' · kvot ' + d.kvot + ' mot ' + d.angransande : 'objektet saknas'); }

{ const d = o('go03-informativ-utan-kontrast');
  prov('GO-03', 'kvot 1,00 omklassificerar aldrig ett deklarerat informativt objekt',
    !!d && d.carrier === 'graphicalObjectCarrier' && d.status === 'matt' && d.kvot === 1,
    d ? d.carrier + ' · kvot ' + d.kvot : 'objektet saknas'); }

{ const d = o('go04-odeklarerad');
  prov('GO-04', 'odeklarerat objekt blir unknown, aldrig tyst dekorativt',
    !!d && d.carrier === 'unknown' && d.status === 'unknown' && d.kvot === null &&
    /data-icon namnger formen/.test(d.motivering || ''),
    d ? d.carrier + ' · ' + d.motivering.slice(0, 70) : 'objektet saknas'); }

{ const d = o('go05-i-en-kontroll');
  prov('GO-05', 'grafik inne i en kontroll ingar aldrig i denna population',
    !d, d ? 'FEL: dok upp som ' + d.carrier : 'inte med — hor till kontrollmodellen'); }

{ const d = o('go06-titel-i-svg');
  prov('GO-06', '<title> i svg raknas som deklaration att objektet bar information',
    !!d && d.carrier === 'graphicalObjectCarrier' && /title/.test(d.motivering || '') && d.status === 'matt',
    d ? d.carrier + ' · ' + d.motivering : 'objektet saknas'); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('GRAFIKOBJEKTPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'goprov.json'), JSON.stringify({ resultat, data }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
