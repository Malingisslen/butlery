#!/usr/bin/env node
// F2-NT · PROV FOR ROW-OWNED SWITCH OCH ANGRANSANDE YTA.
//
// Kör: node tools/nontext-surface-fixtures.mjs --out=<katalog utanfor repot>
//
// Tva metodklasser som adjudiceringen av de 167 avslojade:
//
//   SW-R  rollen switch sitter pa hela listraden. Textkolumnen far aldrig bli
//         track, knopp eller barare bara for att den ligger under agaren.
//
//   AC    en barare inuti en kontroll mats mot den yta som FAKTISKT ar malad
//         direkt bakom den, enligt malnings- och innehallsstrukturen.
//
// SW-R02 och AC-02 ar anti-cirkularitetsproven: kontrasten far aldrig avgora
// klassificeringen, och kvoten ska folja den yta bararen ligger pa.

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

const IKON = (namn, farg) => '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="' +
  farg + '" stroke-width="2" data-icon="' + namn + '"><path d="M6 12h12"/></svg>';
const TRACK = farg => 'display:inline-flex;align-items:center;justify-content:flex-end;width:44px;height:26px;border-radius:999px;background:' + farg + ';padding:0 3px';
const KNOPP = 'width:20px;height:20px;border-radius:999px;background:#F5F4ED';
// Listraden: avdelarlinje under sig, textkolumn till vanster, reglage till hoger.
const RAD = 'display:flex;align-items:center;gap:12px;min-height:48px;padding:10px 0;border-bottom:1px solid #ccd1c2;box-sizing:border-box';
const TEXTKOL = 'flex:1 1 0%';

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{padding:10px;background:#fff}
</style>

<!-- SW-R01 · rollen pa hela raden. Textkolumn plus entydig track/knopp. -->
<div class="sc-item" id="swr01-rad-med-reglage">
  <div data-a11y-role="switch" data-a11y-name="Notiser fran Butlery" data-a11y-state="checked"
    data-hit="self" data-state-group="swrprov-notisreglage" style="${RAD}">
    <span style="${TEXTKOL}">Notiser fran Butlery</span>
    <span style="${TRACK('#3f6b4f')}"><span style="${KNOPP}"></span></span>
  </div>
</div>

<!-- SW-R02 · samma struktur, mycket svag track. Klassificeringen far inte
     andras av kontrasten; tracken forblir barare och blir fynd. -->
<div class="sc-item" id="swr02-svag-track">
  <div data-a11y-role="switch" data-a11y-name="Svag bana" data-a11y-state="checked"
    data-hit="self" data-state-group="swrprov-svag" style="${RAD}">
    <span style="${TEXTKOL}">Svag bana</span>
    <span style="${TRACK('#fdfdfd')}"><span style="${KNOPP}"></span></span>
  </div>
</div>

<!-- SW-R03 · tva plausibla reglagestrukturer i samma rad. -->
<div class="sc-item" id="swr03-tva-strukturer">
  <div data-a11y-role="switch" data-a11y-name="Tvetydig rad" data-a11y-state="checked"
    data-hit="self" data-state-group="swrprov-tvetydig" style="${RAD}">
    <span style="${TEXTKOL}">Tvetydig rad</span>
    <span style="${TRACK('#3f6b4f')}"><span style="${KNOPP}"></span></span>
    <span style="${TRACK('#8a6a12')}"><span style="${KNOPP}"></span></span>
  </div>
</div>

<!-- SW-R04 · vanligt reglage, rollen direkt pa boxen. Oforandrat beteende. -->
<div class="sc-item" id="swr04-roll-pa-boxen">
  <span data-a11y-role="switch" data-a11y-name="Direkt" data-a11y-state="on" data-hit="self"
    data-state-group="swrprov-direkt" style="${TRACK('#3f6b4f')}"><span style="${KNOPP}"></span></span>
</div>

<!-- SW-R05 · raden innehaller text, en dekorativ ikon och reglaget. -->
<div class="sc-item" id="swr05-rad-med-dekorikon">
  <div data-a11y-role="switch" data-a11y-name="Med dekor" data-a11y-state="checked"
    data-hit="self" data-state-group="swrprov-dekor" style="${RAD}">
    ${IKON('sparkle', '#c9c9c9')}
    <span style="${TEXTKOL}">Med dekor</span>
    <span style="${TRACK('#3f6b4f')}"><span style="${KNOPP}"></span></span>
  </div>
</div>

<!-- SW-R06 · rad med kryssruta OCH avatarcirkel. Tva avgransade syskon, men
     ritningen deklarerar vilken som ar komponenten. -->
<div class="sc-item" id="swr06-deklarerad-form">
  <div data-a11y-role="checkbox" data-a11y-name="Maja at" data-a11y-state="checked"
    data-hit="self" data-state-group="swrprov-vem-at" style="${RAD}">
    <span data-component="checkbox" style="width:24px;height:24px;border-radius:6px;background:#24382c;flex:none"></span>
    <span style="width:40px;height:40px;border-radius:50%;background:#4a5c43;flex:none"></span>
    <span style="${TEXTKOL}">Maja</span>
  </div>
</div>

<!-- SW-R07 · samma sak men BADA ar deklarerade. Deklarationen ar inte
     entydig, alltsa unknown. -->
<div class="sc-item" id="swr07-tva-deklarerade">
  <div data-a11y-role="checkbox" data-a11y-name="Tva deklarerade" data-a11y-state="checked"
    data-hit="self" data-state-group="swrprov-tva-dekl" style="${RAD}">
    <span data-component="checkbox" style="width:24px;height:24px;border-radius:6px;background:#24382c;flex:none"></span>
    <span data-component="chip" style="width:40px;height:40px;border-radius:50%;background:#4a5c43;flex:none"></span>
    <span style="${TEXTKOL}">Tva deklarerade</span>
  </div>
</div>

<!-- AC-01 · ikon pa massiv knappfyllning. Mats mot fyllningen. -->
<div class="sc-item" id="ac01-ikon-pa-fyllning">
  <span data-a11y-role="button" data-a11y-name="Lagg till" data-hit="self"
    style="display:inline-flex;align-items:center;justify-content:center;width:56px;height:56px;border-radius:999px;background:#ce7c1e">${IKON('plus', '#17251d')}</span>
</div>

<!-- AC-02 · samma ikonfarg, annan fyllning. Kvoten ska folja fyllningen. -->
<div class="sc-item" id="ac02-annan-fyllning">
  <span data-a11y-role="button" data-a11y-name="Lagg till morkt" data-hit="self"
    style="display:inline-flex;align-items:center;justify-content:center;width:56px;height:56px;border-radius:999px;background:#24382c">${IKON('plus', '#17251d')}</span>
</div>

<!-- AC-03 · genomskinlig knapp utan egen fyllning. Mats mot den verkliga
     underliggande ytan, inte mot en pahittad. -->
<div class="sc-item" id="ac03-transparent-knapp">
  <div style="background:#e6ead9;padding:8px;display:inline-block">
    <span data-a11y-role="button" data-a11y-name="Utan fyllning" data-hit="self"
      style="display:inline-flex;align-items:center;justify-content:center;width:48px;height:48px">${IKON('x', '#24382c')}</span>
  </div>
</div>

<!-- AC-04 · fyllning med alfa. Komposition fore kvot. -->
<div class="sc-item" id="ac04-alfafyllning">
  <div style="background:#24382c;padding:8px;display:inline-block">
    <span data-a11y-role="button" data-a11y-name="Halvgenomskinlig" data-hit="self"
      style="display:inline-flex;align-items:center;justify-content:center;width:48px;height:48px;background:rgba(245,244,237,0.5)">${IKON('x', '#24382c')}</span>
  </div>
</div>

<!-- AC-05 · nastlad fyllning. Den INRE ytan ar den angransande. -->
<div class="sc-item" id="ac05-nastlad-fyllning">
  <span data-a11y-role="button" data-a11y-name="Nastlad" data-hit="self"
    style="display:inline-flex;align-items:center;justify-content:center;padding:10px;background:#24382c"><span style="display:inline-flex;align-items:center;justify-content:center;width:32px;height:32px;background:#ce7c1e">${IKON('x', '#17251d')}</span></span>
</div>

<!-- AC-06 · barare som ar en RAM utan fyllning. Ingen pahittad inre yta. -->
<div class="sc-item" id="ac06-ram-utan-fyllning">
  <div style="background:#e6ead9;padding:8px;display:inline-block">
    <span data-a11y-role="checkbox" data-a11y-name="Bara ram" data-a11y-state="unchecked" data-hit="self"
      data-state-group="acprov-ram" style="display:inline-block;width:24px;height:24px;border:2px solid #7d897c"></span>
  </div>
</div>`;

const fixturPath = join(outAbs, 'ytprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9900 + (process.pid % 90);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-ytprov'), 'about:blank'],
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
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 1400, deviceScaleFactor: 1, mobile: false });
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
  console.log('YTPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const k = a => data.find(x => x.art === a);
const del = (a, f) => { const c = k(a); return c ? c.delar.find(f) : null; };
const id = a => del(a, d => d.carrier === 'componentIdentityCarrier');
const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });

{ const c = k('swr01-rad-med-reglage');
  const bar = c && c.delar.find(d => d.carrier === 'componentIdentityCarrier');
  const knopp = c && c.delar.find(d => d.typ === 'thumb');
  const fabricerad = c && c.delar.some(d => d.status === 'matt' && d.kvot === 1);
  prov('SW-R01', 'rollen pa hela raden: track och knopp identifieras, textkolumnen ignoreras',
    !!bar && !!knopp && bar.descent === true && bar.status === 'matt' && bar.kvot > 3 &&
    knopp.carrier === 'stateCarrier' && knopp.status === 'matt' && !fabricerad,
    bar && knopp ? 'track ' + bar.kvot + ' · knopp ' + knopp.kvot : 'delar saknas'); }

{ const bar = id('swr02-svag-track');
  prov('SW-R02', 'svag track forblir barare — kontrasten far inte andra klassificeringen',
    !!bar && bar.descent === true && bar.status === 'matt' && bar.kvot < 3,
    bar ? bar.carrier + ' · kvot ' + bar.kvot : 'ingen barare'); }

{ const c = k('swr03-tva-strukturer');
  const u = c && c.delar.find(d => d.carrier === 'unknown');
  prov('SW-R03', 'tva plausibla reglagestrukturer ger unknown',
    !!u && !id('swr03-tva-strukturer') && /flera plausibla|syskon/.test(u.motivering || ''),
    u ? u.motivering.slice(0, 80) : 'ingen unknown — modellen gissade'); }

{ const c = k('swr04-roll-pa-boxen');
  const bar = c && c.delar.find(d => d.carrier === 'componentIdentityCarrier');
  const knopp = c && c.delar.find(d => d.typ === 'thumb');
  prov('SW-R04', 'rollen direkt pa reglaget: oforandrat beteende',
    !!bar && bar.descent === false && !!knopp && knopp.carrier === 'stateCarrier' &&
    knopp.motYta === 'kontrollens inre yta',
    bar && knopp ? 'bana ' + bar.kvot + ' · knopp ' + knopp.kvot : 'delar saknas'); }

{ const c = k('swr05-rad-med-dekorikon');
  const bar = c && c.delar.find(d => d.carrier === 'componentIdentityCarrier');
  const dekor = c && c.delar.find(d => d.ikon === 'sparkle');
  prov('SW-R05', 'dekorativ ikon i raden blir aldrig reglagets barare',
    !!bar && bar.typ !== 'ikon' && bar.descent === true &&
    (!dekor || dekor.carrier === 'supplemental'),
    bar ? 'barare ' + bar.typ + ' · dekorikon ' + (dekor ? dekor.carrier : 'ej rapporterad') : 'ingen barare'); }

{ const bar = id('swr06-deklarerad-form');
  prov('SW-R06', 'deklarerad data-component avgor nar tva avgransade syskon finns',
    !!bar && bar.descent === true && bar.status === 'matt' &&
    /deklarera(d|t) med data-component/.test(bar.motivering || ''),
    bar ? bar.typ + ' · kvot ' + bar.kvot : 'ingen barare'); }

{ const c = k('swr07-tva-deklarerade');
  const u = c && c.delar.find(d => d.carrier === 'unknown');
  prov('SW-R07', 'tva deklarerade komponenter i samma rad ger unknown',
    !!u && !id('swr07-tva-deklarerade'),
    u ? u.motivering.slice(0, 80) : 'ingen unknown — modellen valde en av dem'); }

{ const d = del('ac01-ikon-pa-fyllning', x => x.typ === 'ikon');
  prov('AC-01', 'ikon pa massiv knappfyllning mats mot fyllningen',
    !!d && d.status === 'matt' && d.angransande === 'rgb(206, 124, 30)' && d.kvot > 3,
    d ? 'kvot ' + d.kvot + ' mot ' + d.angransande : 'delen saknas'); }

{ const a = del('ac01-ikon-pa-fyllning', x => x.typ === 'ikon');
  const b = del('ac02-annan-fyllning', x => x.typ === 'ikon');
  prov('AC-02', 'samma ikonfarg pa annan fyllning ger annan kvot — den foljer fyllningen',
    !!a && !!b && a.farg === b.farg && a.angransande !== b.angransande && a.kvot !== b.kvot &&
    b.angransande === 'rgb(36, 56, 44)',
    a && b ? a.kvot + ' mot ' + a.angransande + '  ·  ' + b.kvot + ' mot ' + b.angransande : 'delar saknas'); }

{ const d = del('ac03-transparent-knapp', x => x.typ === 'ikon');
  prov('AC-03', 'knapp utan egen fyllning mats mot den verkliga underliggande ytan',
    !!d && d.status === 'matt' && d.angransande === 'rgb(230, 234, 217)',
    d ? 'kvot ' + d.kvot + ' mot ' + d.angransande : 'delen saknas'); }

{ const d = del('ac04-alfafyllning', x => x.typ === 'ikon');
  // rgba(245,244,237,.5) over #24382c ger rgb(141,150,141)
  prov('AC-04', 'fyllning med alfa komponeras fore kvoten',
    !!d && d.status === 'matt' && d.angransande === 'rgb(141, 150, 141)',
    d ? 'kvot ' + d.kvot + ' mot ' + d.angransande : 'delen saknas'); }

{ const d = del('ac05-nastlad-fyllning', x => x.typ === 'ikon');
  prov('AC-05', 'nastlad fyllning: den inre ytan ar den angransande',
    !!d && d.status === 'matt' && d.angransande === 'rgb(206, 124, 30)',
    d ? 'kvot ' + d.kvot + ' mot ' + d.angransande : 'delen saknas'); }

{ const d = del('ac06-ram-utan-fyllning', x => x.typ === 'ram');
  prov('AC-06', 'ram utan fyllning mats mot ytan utanfor, ingen pahittad inre yta',
    !!d && d.status === 'matt' && d.angransande === 'rgb(230, 234, 217)',
    d ? 'kvot ' + d.kvot + ' mot ' + d.angransande : 'delen saknas'); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('YTPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'ytprov.json'), JSON.stringify({ resultat, data }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
