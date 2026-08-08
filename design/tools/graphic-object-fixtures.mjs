#!/usr/bin/env node
// F2-NT · BESTANDIGA PROV FOR GRAFIK UTANFOR KONTROLLER.
//
// Kör: node tools/graphic-object-fixtures.mjs --out=<katalog utanfor repot>
//
// Kontraktet ar data-graphic-role = required | redundant | decorative.
//
// GO-03 ar anti-cirkularitetsprovet: ett required-objekt med kontrast 1,00
// forblir required och blir ett fynd. GO-04 ar fail closed: ett omarkt objekt
// blir aldrig tyst dekorativt.

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

const SVG = (attr, farg) => '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="' +
  farg + '" stroke-width="2" ' + attr + '><path d="M12 3l9 16H3z"/></svg>';

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{padding:10px;background:#fff}
</style>

<div class="sc-item" id="go01-decorative">
  ${SVG('data-icon="sparkle" data-graphic-role="decorative"', '#eeeeee')}
  <span>Texten sager allt som behovs</span>
</div>

<div class="sc-item" id="go02-required">
  ${SVG('data-icon="triangle-alert" data-graphic-role="required"', '#8f3324')}
</div>

<div class="sc-item" id="go03-required-utan-kontrast">
  <!-- Markt required men malad vitt mot vitt: kvot 1,00.
       Ska forbli required och bli ett fynd, aldrig omklassificeras. -->
  ${SVG('data-icon="triangle-alert" data-graphic-role="required"', '#ffffff')}
</div>

<div class="sc-item" id="go04-omarkt">
  <!-- Bara data-icon. Formen ar namngiven, funktionen ar det inte. -->
  ${SVG('data-icon="info"', '#c9c9c9')}
</div>

<div class="sc-item" id="go05-i-en-kontroll">
  <!-- Grafik inne i en kontroll hor till kontrollpopulationen och far
       aldrig dyka upp har. -->
  <span data-a11y-role="button" data-a11y-name="Stang" data-hit="self"
    style="display:inline-flex;width:48px;height:48px;align-items:center;justify-content:center">${SVG('data-icon="x"', '#24382c')}</span>
</div>

<div class="sc-item" id="go06-redundant">
  <!-- Betydelsen finns fullstandigt i texten intill. Rapporteras, men ar
       inte required carrier. -->
  ${SVG('data-icon="triangle-alert" data-graphic-role="redundant"', '#f0f0f0')}
  <span>Varning: receptet innehaller notter</span>
</div>

<div class="sc-item" id="go07-ogiltigt-varde">
  ${SVG('data-icon="lock" data-graphic-role="supplemental"', '#24382c')}
</div>

<div class="sc-item" id="go09-currentcolor">
  <!-- stroke="currentColor" ar inget fargvarde. Motorn maste ga vidare till
       den beraknade stilen i stallet for att ge upp. -->
  <div style="color:#8f3324">${SVG('data-icon="triangle-alert" data-graphic-role="required"', 'currentColor')}</div>
</div>

<div class="sc-item" id="go08-tom-markning">
  ${SVG('data-icon="clock" data-graphic-role=""', '#24382c')}
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
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 1000, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  const r = await s('Runtime.evaluate', { expression: GRAPHIC_OBJECTS, returnByValue: true });
  if (r.exceptionDetails) throw new Error('matskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 300));
  data = r.result.value;
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 9;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('GRAFIKOBJEKTPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const o = a => data.find(x => x.art === a);
const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });

{ const d = o('go01-decorative');
  prov('GO-01', 'decorative mats inte',
    !!d && d.carrier === 'decorative' && d.status === 'ejKravd' && d.kvot === null,
    d ? d.carrier + ' · ' + d.motivering : 'objektet saknas'); }

{ const d = o('go02-required');
  prov('GO-02', 'required mats mot sin angransande yta',
    !!d && d.carrier === 'required' && d.status === 'matt' && d.kvot >= 3,
    d ? d.carrier + ' · kvot ' + d.kvot + ' mot ' + d.angransande : 'objektet saknas'); }

{ const d = o('go03-required-utan-kontrast');
  prov('GO-03', 'kvot 1,00 omklassificerar aldrig ett required-objekt',
    !!d && d.carrier === 'required' && d.status === 'matt' && d.kvot === 1,
    d ? d.carrier + ' · kvot ' + d.kvot : 'objektet saknas'); }

{ const d = o('go04-omarkt');
  prov('GO-04', 'omarkt objekt blir unknown, aldrig tyst dekorativt',
    !!d && d.carrier === 'unknown' && d.status === 'unknown' && d.kvot === null &&
    /data-icon namnger formen/.test(d.motivering || ''),
    d ? d.carrier + ' · ' + d.motivering.slice(0, 70) : 'objektet saknas'); }

{ const d = o('go05-i-en-kontroll');
  prov('GO-05', 'grafik inne i en kontroll ingar aldrig i denna population',
    !d, d ? 'FEL: dok upp som ' + d.carrier : 'inte med — hor till kontrollmodellen'); }

{ const d = o('go06-redundant');
  prov('GO-06', 'redundant rapporteras men mats inte mot 3:1',
    !!d && d.carrier === 'redundant' && d.status === 'ejKravd' && d.kvot === null,
    d ? d.carrier + ' · ' + d.motivering : 'objektet saknas'); }

{ const d = o('go07-ogiltigt-varde');
  prov('GO-07', 'ogiltigt varde blir unknown, aldrig tyst accepterat',
    !!d && d.carrier === 'unknown' && /ar inte required, redundant eller decorative/.test(d.motivering || ''),
    d ? d.carrier + ' · ' + d.motivering.slice(0, 70) : 'objektet saknas'); }

{ const d = o('go08-tom-markning');
  prov('GO-08', 'tom markning blir unknown',
    !!d && d.carrier === 'unknown' && d.status === 'unknown',
    d ? d.carrier + ' · ' + d.motivering.slice(0, 70) : 'objektet saknas'); }

{ const d = o('go09-currentcolor');
  prov('GO-09', 'stroke="currentColor" loses mot arvd color i stallet for unknown',
    !!d && d.carrier === 'required' && d.status === 'matt' && d.farg === 'rgb(143, 51, 36)',
    d ? d.status + ' · ' + (d.farg || d.varfor) : 'objektet saknas'); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('GRAFIKOBJEKTPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'goprov.json'), JSON.stringify({ resultat, data }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
