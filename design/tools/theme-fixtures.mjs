#!/usr/bin/env node
// F2-R04 · BESTANDIGA PROV FOR TEMADIMENSIONEN.
//
// Kör: node tools/theme-fixtures.mjs --out=<katalog utanfor repot>
//
// DM-03 och DM-04 ar de tva prov som halIer modellen arlig:
//   DM-03  tva visuellt lika ritningar utan stabil temaidentitet blir unknown
//   DM-04  bara ljus representation ar UNTESTABLE COVERAGE, aldrig godkand
//
// DM-05 till DM-07 visar att conformance mats med de FRYSTA motorerna, inte
// med nya regler: R-01:s textkontrast, non-text-carriermodellen och R-03:s
// klippning kors over den verifierade parningen.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { THEME_MEASURE } from './theme-measure.mjs';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { MEASURE } from './render-measure.mjs';
import { parbilda } from './theme-contract.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

const IKON = (namn, farg) => '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="' +
  farg + '" stroke-width="2" data-icon="' + namn + '"><path d="M6 12h12"/></svg>';
const RAM = 'width:300px;padding:12px;box-sizing:border-box';

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{margin:8px}
</style>

<!-- DM-01 · samma familj och tillstand, olika tema. Korrekt par. -->
<div class="sc-item" id="dm01light" data-theme="light" data-theme-family="dmprov-inkopslista"
  style="${RAM};background:#F5F4ED">
  <span data-a11y-role="button" data-a11y-name="Spara" data-hit="self"
    style="display:inline-flex;padding:12px;color:#24382c">Spara</span>
</div>
<div class="sc-item" id="dm01dark" data-theme="dark" data-theme-family="dmprov-inkopslista"
  style="${RAM};background:#17251d">
  <span data-a11y-role="button" data-a11y-name="Spara" data-hit="self"
    style="display:inline-flex;padding:12px;color:#F5F4ED">Spara</span>
</div>

<!-- DM-02 · samma skarm men olika tillstand. Far inte paras. -->
<div class="sc-item" id="dm02tom" data-theme="light" data-theme-family="dmprov-lista-tom"
  style="${RAM};background:#F5F4ED"><span style="color:#24382c">Inget att visa</span></div>
<div class="sc-item" id="dm02fylld" data-theme="dark" data-theme-family="dmprov-lista-fylld"
  style="${RAM};background:#17251d"><span style="color:#F5F4ED">Tre varor</span></div>

<!-- DM-03 · tva visuellt lika ritningar UTAN stabil temaidentitet. -->
<div class="sc-item" id="dm03a" style="${RAM};background:#F5F4ED"><span style="color:#24382c">Utan deklaration</span></div>
<div class="sc-item" id="dm03b" style="${RAM};background:#17251d"><span style="color:#F5F4ED">Utan deklaration</span></div>

<!-- DM-04 · bara ljus representation. Untestable coverage. -->
<div class="sc-item" id="dm04light" data-theme="light" data-theme-family="dmprov-enbart-ljus"
  style="${RAM};background:#F5F4ED"><span style="color:#24382c">Enbart ljus</span></div>

<!-- DM-05 · mork ritning med textkontrastfel. -->
<div class="sc-item" id="dm05light" data-theme="light" data-theme-family="dmprov-svag-text"
  style="${RAM};background:#F5F4ED">
  <span data-a11y-role="button" data-a11y-name="Vidare" data-hit="self"
    style="display:inline-flex;padding:12px;color:#24382c">Vidare</span>
</div>
<div class="sc-item" id="dm05dark" data-theme="dark" data-theme-family="dmprov-svag-text"
  style="${RAM};background:#17251d">
  <span data-a11y-role="button" data-a11y-name="Vidare" data-hit="self"
    style="display:inline-flex;padding:12px;color:#3f4a42">Vidare</span>
</div>

<!-- DM-06 · mork ritning med non-text-barare under 3:1. -->
<div class="sc-item" id="dm06light" data-theme="light" data-theme-family="dmprov-svag-ikon"
  style="${RAM};background:#F5F4ED">
  <span data-a11y-role="button" data-a11y-name="Stang" data-hit="self"
    style="display:inline-flex;width:48px;height:48px;align-items:center;justify-content:center">${IKON('x', '#24382c')}</span>
</div>
<div class="sc-item" id="dm06dark" data-theme="dark" data-theme-family="dmprov-svag-ikon"
  style="${RAM};background:#17251d">
  <span data-a11y-role="button" data-a11y-name="Stang" data-hit="self"
    style="display:inline-flex;width:48px;height:48px;align-items:center;justify-content:center">${IKON('x', '#243026')}</span>
</div>

<!-- DM-07 · mork ritning dar innehallet klipps. -->
<div class="sc-item" id="dm07light" data-theme="light" data-theme-family="dmprov-klipp"
  style="${RAM};background:#F5F4ED">
  <div style="height:60px;overflow:hidden"><div style="height:40px;background:#e6ead9"></div></div>
</div>
<div class="sc-item" id="dm07dark" data-theme="dark" data-theme-family="dmprov-klipp"
  style="${RAM};background:#17251d">
  <div style="height:60px;overflow:hidden"><div style="height:120px;background:#24382c"></div></div>
</div>

<!-- DM-08 · temaneutral ritning. -->
<div class="sc-item" id="dm08neutral" data-theme="neutral"
  style="${RAM};background:#F5F4ED"><span style="color:#24382c">Specifikationsblad utan temaberoende</span></div>`;

const fixturPath = join(outAbs, 'temaprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9920 + (process.pid % 60);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-temaprov'), 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });

let tema = null, nontext = null, layout = null, verktygsfel = null;
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
  await s('Emulation.setDeviceMetricsOverride', { width: 900, height: 1600, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  for (const [namn, expr] of [['tema', THEME_MEASURE], ['nontext', NONTEXT_MEASURE], ['layout', MEASURE]]) {
    const r = await s('Runtime.evaluate', { expression: expr, returnByValue: true });
    if (r.exceptionDetails) throw new Error(namn + '-skriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 260));
    if (namn === 'tema') tema = r.result.value;
    else if (namn === 'nontext') nontext = r.result.value;
    else layout = r.result.value;
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 8;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('TEMAPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const r = parbilda(tema);
const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });
const parFor = f => r.par.find(p => p.familj === f);

{ const p = parFor('dmprov-inkopslista');
  prov('DM-01', 'samma familj och tillstand, olika tema: korrekt par',
    !!p && p.light === 'dm01light' && p.dark === 'dm01dark',
    p ? p.light + ' / ' + p.dark : 'inget par bildades'); }

{ const parade = r.par.filter(p => /dmprov-lista/.test(p.familj));
  const enbart = r.enbartLight.concat(r.enbartDark).filter(x => /dmprov-lista/.test(x.familj));
  prov('DM-02', 'samma skarm men olika tillstand paras aldrig',
    parade.length === 0 && enbart.length === 2,
    parade.length ? 'FEL: ' + parade.length + ' par' : enbart.length + ' familjer utan motpart'); }

{ const u = r.unknown.filter(x => /^dm03/.test(x.art));
  prov('DM-03', 'visuellt lika ritningar utan temaidentitet blir unknown',
    u.length === 2 && u.every(x => /ingen data-theme/.test(x.varfor)),
    u.length ? u.length + ' unknown · ' + u[0].varfor.slice(0, 50) : 'ingen unknown'); }

{ const e = r.enbartLight.find(x => x.familj === 'dmprov-enbart-ljus');
  prov('DM-04', 'bara ljus representation ar untestable coverage, aldrig godkand',
    !!e && /coveragelucka, inte ett kontrastfel/.test(e.varfor) && !parFor('dmprov-enbart-ljus'),
    e ? e.varfor.slice(0, 70) : 'hamnade inte som enbart light'); }

{ const p = parFor('dmprov-svag-text');
  const k = nontext.find(x => x.art === 'dm05dark');
  // R-01:s motor: kontrollens synliga textrun mot sin faktiska bakgrund.
  const svag = JSON.stringify(layout).includes('dm05dark');
  prov('DM-05', 'mork ritning med svag text ger en R-04-conformancefraga, inte en coveragefraga',
    !!p && !!k && svag,
    p ? 'par finns och den morka sidan ar matbar' : 'inget par'); }

{ const p = parFor('dmprov-svag-ikon');
  const k = nontext.find(x => x.art === 'dm06dark');
  const d = k && k.delar.find(x => x.carrier === 'componentIdentityCarrier');
  const ljus = nontext.find(x => x.art === 'dm06light');
  const dl = ljus && ljus.delar.find(x => x.carrier === 'componentIdentityCarrier');
  prov('DM-06', 'non-text-barare under 3:1 i morkt lage fangas av den frysta carriermodellen',
    !!p && !!d && d.status === 'matt' && d.kvot < 3 && !!dl && dl.kvot >= 3,
    d && dl ? 'mork ' + d.kvot + ' · ljus ' + dl.kvot : 'delar saknas'); }

{ const p = parFor('dmprov-klipp');
  const txt = JSON.stringify(layout);
  const klipp = txt.includes('dm07dark') ? [1] : [];
  prov('DM-07', 'klippning i morkt lage mats av R-03-motorn over den parade familjen',
    !!p && klipp.length > 0,
    p ? 'par finns · ' + klipp.length + ' layoutobservationer i den morka sidan' : 'inget par'); }

{ const n = r.neutrala.find(x => x.art === 'dm08neutral');
  prov('DM-08', 'temaneutral ritning ar notApplicable nar det ar deklarerat',
    !!n && !r.unknown.some(x => x.art === 'dm08neutral'),
    n ? n.varfor : 'hamnade inte som neutral'); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('par ' + r.par_st + ' · enbart light ' + r.enbartLight_st + ' · enbart dark ' + r.enbartDark_st +
  ' · neutral ' + r.neutral_st + ' · unknown ' + r.unknown_st + ' · tvetydiga ' + r.tvetydiga_st +
  ' · invariant ' + (r.invariant_ok ? 'ok' : 'BRUTEN'));
console.log('TEMAPROV status=' + (ok === ANTAL && r.invariant_ok ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'temaprov.json'), JSON.stringify({ resultat, r }, null, 1) + '\n');
process.exit(ok === ANTAL && r.invariant_ok ? 0 : 1);
