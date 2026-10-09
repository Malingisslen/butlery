#!/usr/bin/env node
// F2-R04 · BESTANDIGA PROV FOR HYBRIDMODELLEN.
//
// Kör: node tools/theme-hybrid-fixtures.mjs --out=<katalog utanfor repot>
//
// H-02 och H-06 ar de tva prov som halIer modellen arlig:
//   H-02  en kalla som bara stodjer light far ALDRIG ge en fabricerad
//         morkrendering
//   H-06  bade explicit mork artefakt och dual render for samma familj ar
//         tvetydigt tills agarskapet ar bestamt
//
// Tokenmodellen provas ocksa: kallan uttrycker fargroller, inte hexvarden,
// och temat byts genom att sattas pa artefakten.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { tackning, parseStod } from './theme-contract.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

// SEMANTISKA ROLLER, inte hexvarden. Samma hex kan bli flera roller.
const TOKENS = `
 .sc-item[data-theme="light"]{
   --yta-app:#F5F4ED; --yta-upphojd:#e6ead9;
   --text-primar:#24382c; --text-sekundar:#627061;
   --ram-kontroll:#7d897c; }
 .sc-item[data-theme="dark"]{
   --yta-app:#17251d; --yta-upphojd:#2f4437;
   --text-primar:#F5F4ED; --text-sekundar:#93a48d;
   --ram-kontroll:rgba(245,244,237,.4); }
`;
const KORT = 'background:var(--yta-upphojd);border:1px solid var(--ram-kontroll);padding:12px;box-sizing:border-box';

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#888;font:14px/1.4 system-ui}
 .sc-item{width:300px;margin:8px;padding:12px;box-sizing:border-box;background:var(--yta-app)}
 ${TOKENS}
</style>

<!-- H-01 · temakapabel kalla, renderas tva ganger -->
<div class="sc-item" id="h01" data-theme-support="light dark" data-theme-family="hprov-kort-412" data-theme="light">
  <span data-a11y-role="button" data-a11y-name="Spara" data-hit="self" style="${KORT};color:var(--text-primar)">Spara</span>
</div>

<!-- H-02 · kallan stodjer bara light -->
<div class="sc-item" id="h02" data-theme-support="light" data-theme-family="hprov-endast-ljus-412" data-theme="light">
  <span data-a11y-role="button" data-a11y-name="Bara ljus" data-hit="self" style="${KORT};color:var(--text-primar)">Bara ljus</span>
</div>

<!-- H-03 · samma familj, tva renderingar -->
<div class="sc-item" id="h03" data-theme-support="light dark" data-theme-family="hprov-lista-412" data-theme="light">
  <span data-a11y-role="button" data-a11y-name="Lista" data-hit="self"
    style="display:inline-flex;width:48px;height:48px;align-items:center;justify-content:center;${KORT}"></span>
</div>

<!-- H-04 · samma kalla men olika STATE: tva familjer -->
<div class="sc-item" id="h04tom" data-theme-support="light dark" data-theme-family="hprov-lista-tom-412" data-theme="light">
  <span style="color:var(--text-sekundar)">Inget att visa</span>
</div>
<div class="sc-item" id="h04fylld" data-theme-support="light dark" data-theme-family="hprov-lista-fylld-412" data-theme="light">
  <span style="color:var(--text-primar)">Tre varor</span>
</div>

<!-- H-05 · explicit par, som tidigare -->
<div class="sc-item" id="h05light" data-theme="light" data-theme-family="hprov-explicit-412">
  <span style="color:var(--text-primar)">Explicit ljus</span></div>
<div class="sc-item" id="h05dark" data-theme="dark" data-theme-family="hprov-explicit-412">
  <span style="color:var(--text-primar)">Explicit mork</span></div>

<!-- H-06 · bade explicit mork artefakt OCH temakapabel kalla i samma familj -->
<div class="sc-item" id="h06kalla" data-theme-support="light dark" data-theme-family="hprov-krock-412" data-theme="light">
  <span style="color:var(--text-primar)">Temakapabel</span></div>
<div class="sc-item" id="h06dark" data-theme="dark" data-theme-family="hprov-krock-412">
  <span style="color:var(--text-primar)">Explicit mork</span></div>

<!-- H-07 · morkrendering med for svag ikonbarare -->
<div class="sc-item" id="h07" data-theme-support="light dark" data-theme-family="hprov-svag-412" data-theme="light">
  <span data-a11y-role="button" data-a11y-name="Stang" data-hit="self"
    style="display:inline-flex;width:48px;height:48px;align-items:center;justify-content:center"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--yta-upphojd)" stroke-width="2" data-icon="x"><path d="M6 12h12"/></svg></span>
</div>`;

const fixturPath = join(outAbs, 'hybridprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9960 + (process.pid % 30);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-hybridprov'), 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });

let matning = {}, verktygsfel = null;
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
  // DUAL RENDER · temat sätts EXPLICIT pa de kallor som deklarerar stod for
  // det, och bara pa dem. Ingen rendering fabriceras.
  for (const tema of ['light', 'dark']) {
    const satt = await s('Runtime.evaluate', { returnByValue: true, expression: `(() => {
      const rorda = [];
      for (const it of document.querySelectorAll('.sc-item[data-theme-support]')) {
        const stod = (it.getAttribute('data-theme-support') || '').trim().split(/\\s+/);
        if (!stod.includes(${JSON.stringify(tema)})) continue;
        it.setAttribute('data-theme', ${JSON.stringify(tema)});
        rorda.push(it.id); }
      return rorda; })()` });
    await sleep(120);
    const r = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
    if (r.exceptionDetails) throw new Error('carriermodellen kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 200));
    matning[tema] = { renderade: satt.result.value, data: r.result.value };
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 7;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('HYBRIDPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

// Bygg tackningsunderlaget ur det som FAKTISKT renderades.
const renderadeAv = a => ['light', 'dark'].filter(t => matning[t].renderade.includes(a));
const artefakter = [
  { art: 'h01', stod: 'light dark', familj: 'hprov-kort-412', renderade: renderadeAv('h01') },
  { art: 'h02', stod: 'light', familj: 'hprov-endast-ljus-412', renderade: renderadeAv('h02') },
  { art: 'h03', stod: 'light dark', familj: 'hprov-lista-412', renderade: renderadeAv('h03') },
  { art: 'h04tom', stod: 'light dark', familj: 'hprov-lista-tom-412', renderade: renderadeAv('h04tom') },
  { art: 'h04fylld', stod: 'light dark', familj: 'hprov-lista-fylld-412', renderade: renderadeAv('h04fylld') },
  { art: 'h05light', tema: 'light', familj: 'hprov-explicit-412' },
  { art: 'h05dark', tema: 'dark', familj: 'hprov-explicit-412' },
  { art: 'h06kalla', stod: 'light dark', familj: 'hprov-krock-412', renderade: renderadeAv('h06kalla') },
  { art: 'h06dark', tema: 'dark', familj: 'hprov-krock-412' },
  { art: 'h07', stod: 'light dark', familj: 'hprov-svag-412', renderade: renderadeAv('h07') },
];
const t = tackning(artefakter);
const fam = f => t.familjer.find(x => x.familj === f);
const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });

{ const f = fam('hprov-kort-412');
  prov('H-01', 'temakapabel kalla renderad tva ganger ger ett verifierat par',
    !!f && f.status === 'covered' && f.modell === 'dualThemeRender' &&
    f.renderade.includes('light') && f.renderade.includes('dark'),
    f ? f.status + ' / ' + f.modell + ' · ' + JSON.stringify(f.renderade) : 'familjen saknas'); }

{ const f = fam('hprov-endast-ljus-412');
  const rendDark = matning.dark.renderade.includes('h02');
  // Ingen fabricerad morkrendering — och familjen ar darfor en coveragelucka,
  // aldrig covered.
  prov('H-02', 'kalla som bara stodjer light far ingen fabricerad morkrendering och blir en coveragelucka',
    !rendDark && !!f && f.status === 'coverageGap' && /renderad bara i light/.test(f.varfor || '') &&
    parseStod('light').teman.join() === 'light',
    'morkrenderad: ' + rendDark + ' · ' + (f ? f.status + ' · ' + (f.varfor || '') : '—')); }

{ const f = fam('hprov-lista-412');
  const l = matning.light.data.find(x => x.art === 'h03');
  const d = matning.dark.data.find(x => x.art === 'h03');
  const lb = l && l.delar.find(x => x.carrier === 'componentIdentityCarrier');
  const db = d && d.delar.find(x => x.carrier === 'componentIdentityCarrier');
  prov('H-03', 'dual render i samma familj och formfaktor ger korrekt par och tva skilda matningar',
    !!f && f.status === 'covered' && !!lb && !!db && lb.angransande !== db.angransande,
    lb && db ? 'ljus mot ' + lb.angransande + ' · mork mot ' + db.angransande : 'delar saknas'); }

{ const a = fam('hprov-lista-tom-412'), b = fam('hprov-lista-fylld-412');
  prov('H-04', 'samma kalla men olika state raknas aldrig som ett temapar',
    !!a && !!b && a.familj !== b.familj && a.status === 'covered' && b.status === 'covered',
    a && b ? 'tva skilda familjer, bada covered' : 'familjer saknas'); }

{ const f = fam('hprov-explicit-412');
  prov('H-05', 'explicit artefaktpar fungerar som tidigare',
    !!f && f.status === 'covered' && f.modell === 'explicitPair' &&
    f.light === 'h05light' && f.dark === 'h05dark',
    f ? f.modell + ' · ' + f.light + '/' + f.dark : 'familjen saknas'); }

{ const f = fam('hprov-krock-412');
  prov('H-06', 'bade explicit mork artefakt och dual render i samma familj ar tvetydigt',
    !!f && f.status === 'ambiguous' && /agarskapet/.test(f.varfor || ''),
    f ? f.status + ' · ' + (f.varfor || '').slice(0, 60) : 'familjen saknas'); }

{ const d = matning.dark.data.find(x => x.art === 'h07');
  const l = matning.light.data.find(x => x.art === 'h07');
  const db = d && d.delar.find(x => x.carrier === 'componentIdentityCarrier');
  const lb = l && l.delar.find(x => x.carrier === 'componentIdentityCarrier');
  prov('H-07', 'morkrendering med for svag barare ger ett R-04-fynd precis som en explicit artefakt',
    !!db && db.status === 'matt' && db.kvot < 3 && !!lb && lb.status === 'matt',
    db && lb ? 'mork ' + db.kvot + ' · ljus ' + lb.kvot : 'delar saknas'); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('familjer ' + t.familjer_st + ' · covered ' + t.covered_st +
  ' (explicitPair ' + t.covered_explicitPair_st + ', dualThemeRender ' + t.covered_dualThemeRender_st + ')' +
  ' · gap ' + t.coverageGap_st + ' · ambiguous ' + t.ambiguous_st);
console.log('HYBRIDPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'hybridprov.json'), JSON.stringify({ resultat, t }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
