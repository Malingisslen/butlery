#!/usr/bin/env node
// F2-NT · BESTANDIGA PROV FOR CARRIER-MODELLEN.
//
// Kör: node tools/nontext-fixtures.mjs --out=<katalog utanfor repot>
//
// Det viktigaste provet ar NT-04: en ram med kontrast 1,00 far INTE
// omklassificeras som dekorativ pa grund av kvoten. Utan det provet ar
// modellen ett cirkelresonemang.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { knoppLage, LAGE_OKANT } from './colour-only.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

const SVG = (icon, farg) => '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="' +
  farg + '" stroke-width="2" data-icon="' + icon + '"><path d="M6 12h12"/></svg>';

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{padding:10px;background:#fff}
</style>

<div class="sc-item" id="nt01-textknapp-svag-fyllning">
  <span data-a11y-role="button" data-a11y-name="Spara" data-hit="self"
    style="display:inline-flex;align-items:center;padding:12px 16px;background:#fdfdfd">Spara</span>
</div>

<div class="sc-item" id="nt02-ikonknapp">
  <span data-a11y-role="button" data-a11y-name="Stang" data-hit="self"
    style="display:inline-flex;align-items:center;justify-content:center;width:48px;height:48px">${SVG('x', '#24382c')}</span>
</div>

<div class="sc-item" id="nt03-ram-identifierar">
  <span data-a11y-role="checkbox" data-a11y-name="Med" data-a11y-state="unchecked" data-hit="self"
    style="display:inline-block;width:24px;height:24px;border:2px solid #24382c"></span>
  <span>Med i listan</span>
</div>

<div class="sc-item" id="nt04-ram-utan-kontrast">
  <!-- Ramen ar VIT mot vit bakgrund: kvot 1,00. Den ar anda det enda som
       identifierar kryssrutan, och far darfor inte bli dekorativ. -->
  <span data-a11y-role="checkbox" data-a11y-name="Utan" data-a11y-state="unchecked" data-hit="self"
    style="display:inline-block;width:24px;height:24px;border:2px solid #ffffff"></span>
  <span>Utan kontrast</span>
</div>

<div class="sc-item" id="nt05-ikryssad">
  <span data-a11y-role="checkbox" data-a11y-name="Klar" data-a11y-state="checked" data-hit="self"
    style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:24px;border:2px solid #24382c;background:#24382c">${SVG('check', '#F5F4ED')}</span>
  <span>Klar</span>
</div>

<div class="sc-item" id="nt06-text-med-svag-ikon">
  <span data-a11y-role="button" data-a11y-name="Dela receptet" data-hit="self"
    style="display:inline-flex;align-items:center;gap:8px;padding:12px">${SVG('share', '#fafafa')}<span>Dela receptet</span></span>
</div>

<div class="sc-item" id="nt07-text-med-state-ikon">
  <span data-a11y-role="button" data-a11y-name="Visa mer" data-a11y-state="expanded" data-hit="self"
    style="display:inline-flex;align-items:center;gap:8px;padding:12px">${SVG('chevron-down', '#24382c')}<span>Visa mer</span></span>
</div>

<div class="sc-item" id="nt08-reglage-pa">
  <span data-a11y-role="switch" data-a11y-name="Reglage" data-a11y-state="on" data-hit="self"
    style="display:inline-flex;align-items:center;justify-content:flex-end;width:48px;height:28px;border-radius:999px;background:#3f6b4f;padding:0 3px"><span style="width:22px;height:22px;border-radius:999px;background:#F5F4ED"></span></span>
</div>

<div class="sc-item" id="nt09-reglage-av">
  <span data-a11y-role="switch" data-a11y-name="Reglage" data-a11y-state="off" data-hit="self"
    style="display:inline-flex;align-items:center;justify-content:flex-start;width:48px;height:28px;border-radius:999px;background:#ccd1c2;padding:0 3px"><span style="width:22px;height:22px;border-radius:999px;background:#F5F4ED"></span></span>
</div>

<div class="sc-item" id="nt10-oreducerbar-bakgrund">
  <div style="background:linear-gradient(90deg,#000,#fff);padding:8px">
    <span data-a11y-role="button" data-a11y-name="Pa gradient" data-hit="self"
      style="display:inline-flex;width:48px;height:48px;align-items:center;justify-content:center">${SVG('x', '#888888')}</span>
  </div>
</div>

<div class="sc-item" id="nt11-avstangd">
  <span data-a11y-role="button" data-a11y-name="Nasta" data-a11y-state="disabled" data-hit="self"
    style="display:inline-flex;width:48px;height:48px;align-items:center;justify-content:center">${SVG('arrow-right', '#dcdcdc')}</span>
</div>`;

const fixturPath = join(outAbs, 'nontextprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9560 + (process.pid % 120);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-nontextprov'), 'about:blank'],
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
  const r = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
  if (r.exceptionDetails) throw new Error('matskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 300));
  data = r.result.value;
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 11;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('NONTEXTPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const k = a => data.find(x => x.art === a);
const del = (a, typ) => { const c = k(a); return c ? c.delar.find(d => d.typ === typ) : null; };
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

{ const d = del('nt01-textknapp-svag-fyllning', 'fyllning');
  prov('NT-01', 'textknapp med svag fyllning: fyllningen ar supplemental',
    !!d && d.carrier === 'supplemental' && d.kvot === null,
    d ? d.carrier + ' · kvot ' + d.kvot : 'delen saknas'); }

{ const d = del('nt02-ikonknapp', 'ikon');
  prov('NT-02', 'ikonknapp: glyfen ar componentIdentityCarrier och mats',
    !!d && d.carrier === 'componentIdentityCarrier' && d.status === 'matt' && d.kvot > 3,
    d ? d.carrier + ' · kvot ' + d.kvot : 'delen saknas'); }

{ const d = del('nt03-ram-identifierar', 'ram');
  prov('NT-03', 'ramen identifierar kryssrutan och maste klara 3:1',
    !!d && d.carrier === 'componentIdentityCarrier' && d.status === 'matt' && d.kvot >= 3,
    d ? d.carrier + ' · kvot ' + d.kvot : 'delen saknas'); }

{ const d = del('nt04-ram-utan-kontrast', 'ram');
  prov('NT-04', 'ram med kvot 1,00 forblir carrier — kvoten far inte omklassificera den',
    !!d && d.carrier === 'componentIdentityCarrier' && d.status === 'matt' && d.kvot === 1,
    d ? d.carrier + ' · kvot ' + d.kvot : 'delen saknas'); }

{ const c = k('nt05-ikryssad');
  const ram = c && c.delar.find(x => x.typ === 'ram');
  const bock = c && c.delar.find(x => x.typ === 'bock');
  prov('NT-05', 'ikryssad ruta: ramen bar identiteten, bocken bar tillstandet',
    !!ram && !!bock && ram.carrier === 'componentIdentityCarrier' &&
    bock.carrier === 'stateCarrier' && ram.status === 'matt' && bock.status === 'matt' &&
    ram.motYta !== bock.motYta,
    ram && bock ? 'ram ' + ram.kvot + ' mot ' + ram.motYta + ' · bock ' + bock.kvot + ' mot ' + bock.motYta : 'delar saknas'); }

{ const d = del('nt06-text-med-svag-ikon', 'ikon');
  prov('NT-06', 'textmarkt kontroll med ikon utan egen funktion: supplemental',
    !!d && d.carrier === 'supplemental' && d.kvot === null,
    d ? d.carrier + ' · kvot ' + d.kvot : 'delen saknas'); }

{ const d = del('nt07-text-med-state-ikon', 'ikon');
  prov('NT-07', 'chevron som bar oppet/stangt ar stateCarrier trots att kontrollen har text',
    !!d && d.carrier === 'stateCarrier' && d.status === 'matt',
    d ? d.carrier + ' · kvot ' + d.kvot : 'delen saknas'); }

{ const pa = k('nt08-reglage-pa'), av = k('nt09-reglage-av');
  // Lagesignalen lases ur FAKTISK RENDERAD GEOMETRI sedan 2026-08-15. Den
  // gamla modellen laste justify-content och var blind for allt utom flex.
  const la = pa && knoppLage(pa.signaler.knoppGeometri);
  const lb = av && knoppLage(av.signaler.knoppGeometri);
  const skiljer = !!la && !!lb && la.klass !== LAGE_OKANT && lb.klass !== LAGE_OKANT &&
    la.klass !== lb.klass;
  prov('NT-08', 'reglagets knopplage skiljer on fran off — icke-fargbaserad signal',
    skiljer, la && lb ? la.klass + ' (nX ' + la.nX + ') mot ' + lb.klass + ' (nX ' + lb.nX + ')'
      : 'kontroller saknas'); }

{ const pa = k('nt08-reglage-pa'), av = k('nt09-reglage-av');
  const t = pa && pa.delar.find(x => x.typ === 'thumb');
  prov('NT-09', 'reglagets knopp ar stateCarrier och mats mot banan',
    !!t && t.carrier === 'stateCarrier' && t.status === 'matt' && t.motYta === 'kontrollens inre yta',
    t ? t.carrier + ' · kvot ' + t.kvot + ' mot ' + t.motYta : 'delen saknas'); }

{ const d = del('nt10-oreducerbar-bakgrund', 'ikon');
  prov('NT-10', 'oreducerbar angransande farg ger unknown, aldrig ett fabricerat tal',
    !!d && d.status === 'unknown' && d.kvot === null && /oreducerbar/.test(d.varfor || ''),
    d ? d.status + ' · ' + (d.varfor || '') : 'delen saknas'); }

{ const c = k('nt11-avstangd');
  const d = c && c.delar.find(x => x.typ === 'ikon');
  prov('NT-11', 'avstangd kontroll: matvardet bevaras och disabled redovisas',
    !!c && c.disabled === true && !!d && d.status === 'matt' && d.kvot !== null,
    c ? 'disabled ' + c.disabled + ' · kvot ' + (d ? d.kvot : null) : 'kontrollen saknas'); }

for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(7) + r.vad);
  console.log('     ' + r.diag);
}
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'nontextprov.json'), JSON.stringify({
  $schema: 'butlery-nontextprov/1', kontroll: 'CHK-NT-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('NONTEXTPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
