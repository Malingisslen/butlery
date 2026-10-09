#!/usr/bin/env node
// F2-NT · BESTANDIGA PROV FOR CHILD-DESCENT.
//
// Kör: node tools/nontext-descent-fixtures.mjs --out=<katalog utanfor repot>
//
// Bakgrund: R-02 gjorde traffytan till ett genomskinligt 48x48-element och
// flyttade den synliga formen till ett barn. Semantisk agare och visuell
// barare ar darfor inte langre samma nod.
//
// Descent ar tillaten — men bara nar subtradet ger ETT entydigt svar. Regeln
// "forsta barnet med ram eller fyllning" anvands INTE; den skulle valja nagot
// aven nar ritningen inte pekar ut nagot.
//
// ND-04 ar provet som halIer modellen arlig: en glyf med kontrast 1,00 ska
// forbli barare. Kontrasten far aldrig avgora vem som ar barare.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

const STJARNA = farg => '<svg width="24" height="24" viewBox="0 0 24 24" fill="' + farg +
  '" data-icon="star"><path d="M12 2l3 7h7l-6 4 2 7-6-4-6 4 2-7-6-4h7z"/></svg>';
const IKON = (namn, farg) => '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="' +
  farg + '" stroke-width="2" data-icon="' + namn + '"><path d="M6 12h12"/></svg>';

// Traffyteagaren: genomskinlig, 48x48. Exakt det monster R-02 lamnade efter sig.
const AGARE = 'display:inline-flex;align-items:center;justify-content:center;width:48px;height:48px';

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{padding:10px;background:#fff}
</style>

<div class="sc-item" id="nd01-ruta-i-barn">
  <!-- Agaren malar ingenting. Exakt ETT barn ritar en avgransad form. -->
  <span data-a11y-role="checkbox" data-a11y-name="Med" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}"><span style="width:24px;height:24px;border:2px solid #24382c"></span></span>
  <span>Med i listan</span>
</div>

<div class="sc-item" id="nd02-reglage-i-barn">
  <!-- Bana och knopp: tva avgransade element, men i nastlad kedja. -->
  <span data-a11y-role="switch" data-a11y-name="Reglage" data-a11y-state="on" data-hit="self"
    style="${AGARE}"><span style="display:inline-flex;align-items:center;justify-content:flex-end;width:44px;height:26px;border-radius:999px;background:#3f6b4f;padding:0 3px"><span style="width:20px;height:20px;border-radius:999px;background:#F5F4ED"></span></span></span>
</div>

<div class="sc-item" id="nd03-stjarna-som-form">
  <!-- Ingen avgransad form alls. Kontrollen ar RITAD som en glyf. -->
  <span data-a11y-role="radio" data-a11y-name="Betyg 3" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}">${STJARNA('#24382c')}</span>
</div>

<div class="sc-item" id="nd04-stjarna-utan-kontrast">
  <!-- Samma struktur, men stjarnan ar VIT mot vitt: kvot 1,00.
       Den ska forbli barare och bli lagkontrastkandidat. -->
  <span data-a11y-role="radio" data-a11y-name="Betyg 4" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}">${STJARNA('#ffffff')}</span>
</div>

<div class="sc-item" id="nd05-ruta-plus-dekor">
  <!-- En avgransad form OCH en glyf. Formen vinner; glyfen ar inte identitet. -->
  <span data-a11y-role="checkbox" data-a11y-name="Med dekor" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}"><span style="width:24px;height:24px;border:2px solid #24382c"></span>${IKON('sparkle', '#c9c9c9')}</span>
</div>

<div class="sc-item" id="nd06-tva-syskonformer">
  <!-- Tva avgransade syskon. Vilken ar kontrollens ruta? Ingen aning. -->
  <span data-a11y-role="checkbox" data-a11y-name="Tvetydig" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}"><span style="width:20px;height:20px;border:2px solid #24382c"></span><span style="width:20px;height:20px;border:2px solid #8a6a12"></span></span>
</div>

<div class="sc-item" id="nd07-form-i-annan-kontroll">
  <!-- Den enda avgransade formen tillhor en ANNAN semantisk kontroll.
       Descent far aldrig hoppa in dit. -->
  <span data-a11y-role="checkbox" data-a11y-name="Yttre" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}"><span data-a11y-role="button" data-a11y-name="Inre" data-hit="self"
      style="width:24px;height:24px;border:2px solid #24382c"></span></span>
</div>

<div class="sc-item" id="nd08-egen-ram-vinner">
  <!-- Agaren har EGEN ram. Da sker ingen descent, aven om ett barn ocksa
       ritar en form. -->
  <span data-a11y-role="checkbox" data-a11y-name="Egen ram" data-a11y-state="unchecked" data-hit="self"
    style="display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;border:2px solid #24382c"><span style="width:10px;height:10px;border:1px solid #8a6a12"></span></span>
</div>

<div class="sc-item" id="nd09-tva-glyfer">
  <!-- Ingen avgransad form, men tva glyfer med olika funktion. -->
  <span data-a11y-role="checkbox" data-a11y-name="Tva glyfer" data-a11y-state="unchecked" data-hit="self"
    style="${AGARE}">${IKON('star', '#24382c')}${IKON('flag', '#8a6a12')}</span>
</div>`;

const fixturPath = join(outAbs, 'descentprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9700 + (process.pid % 120);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-descentprov'), 'about:blank'],
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

const ANTAL = 9;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('DESCENTPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const k = a => data.find(x => x.art === a && x.namn !== 'Inre');
const id = a => { const c = k(a); return c ? c.delar.find(d => d.carrier === 'componentIdentityCarrier') : null; };
const okand = a => { const c = k(a); return c ? c.delar.find(d => d.carrier === 'unknown') : null; };
const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });

{ const d = id('nd01-ruta-i-barn');
  prov('ND-01', 'ruta i barnet blir barare nar agaren inte malar nagot',
    !!d && d.descent === true && d.typ === 'ram' && d.status === 'matt' && d.kvot >= 3,
    d ? d.typ + ' · descent ' + d.descent + ' · kvot ' + d.kvot : 'ingen barare'); }

{ const c = k('nd02-reglage-i-barn');
  const bana = c && c.delar.find(x => x.carrier === 'componentIdentityCarrier');
  const knopp = c && c.delar.find(x => x.typ === 'thumb');
  prov('ND-02', 'bana och knopp i nastlad kedja: banan bar formen, knoppen tillstandet',
    !!bana && !!knopp && bana.descent === true && knopp.carrier === 'stateCarrier' &&
    bana.status === 'matt' && knopp.status === 'matt' && knopp.motYta === 'kontrollens inre yta' &&
    bana.angransande !== knopp.angransande,
    bana && knopp ? 'bana ' + bana.kvot + ' mot ' + bana.angransande + ' · knopp ' + knopp.kvot + ' mot ' + knopp.angransande : 'delar saknas'); }

{ const d = id('nd03-stjarna-som-form');
  prov('ND-03', 'kontroll ritad som en enda glyf: glyfen ar barare',
    !!d && d.descent === true && d.typ === 'glyf' && d.ikon === 'star' && d.status === 'matt' && d.kvot >= 3,
    d ? d.typ + ' · ' + d.ikon + ' · kvot ' + d.kvot : 'ingen barare'); }

{ const d = id('nd04-stjarna-utan-kontrast');
  prov('ND-04', 'glyf med kvot 1,00 forblir barare och blir lagkontrastkandidat',
    !!d && d.typ === 'glyf' && d.status === 'matt' && d.kvot === 1,
    d ? d.carrier + ' · kvot ' + d.kvot : 'ingen barare'); }

{ const c = k('nd05-ruta-plus-dekor');
  const d = id('nd05-ruta-plus-dekor');
  const glyf = c && c.delar.find(x => x.ikon === 'sparkle');
  prov('ND-05', 'avgransad form vinner over dekorativ glyf',
    !!d && d.typ === 'ram' && d.descent === true && !!glyf && glyf.carrier === 'supplemental',
    d ? d.typ + ' bar identiteten · glyfen ' + (glyf ? glyf.carrier : 'saknas') : 'ingen barare'); }

{ const u = okand('nd06-tva-syskonformer');
  prov('ND-06', 'tva avgransade syskon ger unknown, inte en gissning',
    !!u && !id('nd06-tva-syskonformer') && /syskon/.test(u.motivering || ''),
    u ? u.motivering.slice(0, 90) : 'ingen unknown — modellen gissade'); }

{ const u = okand('nd07-form-i-annan-kontroll');
  prov('ND-07', 'descent hoppar aldrig in i en annan semantisk kontroll',
    !!u && !id('nd07-form-i-annan-kontroll'),
    u ? u.motivering.slice(0, 90) : 'ingen unknown — modellen tog den inre kontrollens ram'); }

{ const d = id('nd08-egen-ram-vinner');
  prov('ND-08', 'agarens egen ram vinner; ingen descent sker',
    !!d && d.descent === false && d.typ === 'ram' &&
    /egen (omslutande )?boundary|agaren ar sjalv formen/.test(d.motivering || ''),
    d ? d.typ + ' · descent ' + d.descent : 'ingen barare'); }

{ const u = okand('nd09-tva-glyfer');
  prov('ND-09', 'tva glyfer med olika funktion ger unknown',
    !!u && !id('nd09-tva-glyfer') && /glyfer/.test(u.motivering || ''),
    u ? u.motivering.slice(0, 90) : 'ingen unknown — modellen valde en glyf'); }

for (const r of resultat)
  console.log((r.ok ? '✔ ' : '✖ ') + r.id + '  ' + r.vad + '\n     ' + r.diag);
const ok = resultat.filter(r => r.ok).length;
console.log('');
console.log('DESCENTPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(outAbs, 'descentprov.json'),
  JSON.stringify({ resultat, data }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
