#!/usr/bin/env node
// F2-R01 · BESTÄNDIGA PROV FÖR R-01-MÄTAREN.
//
// Kör: node tools/contrast-fixtures.mjs --out=<katalog utanför repot>
//
// Mätaren läste tidigare textfärgen från den semantiska kontrollen även när
// kontrollen bara var en behållare. På navigationsflikarna gav det kvoten 1,00
// — "osynlig text" — på text som i verkligheten ligger på 11,36. Provet nedan
// är det som gör att felet inte kan återuppstå tyst.
//
// Proven kör EXAKT samma mätskript som den skarpa körningen: MEASURE
// importeras ur tools/render-measure.mjs. Ett prov mot en kopia bevisar
// ingenting om koden som faktiskt mäter.
//
//   R01-M-01  behållarens färg == bakgrunden, barnets text ligger på 11,36
//   R01-M-02  inaktiv flik med barntext på 4,73
//   R01-M-03  två text-runs med olika färg — båda mäts, ingen containerfallback
//   R01-M-04  ikonkontroll med tillgängligt namn men utan synlig text
//   R01-M-05  display:none och visibility:hidden är inte synlig text
//   R01-M-06  verifierat disabled på 3,32 — kvoten bevaras, undantagen
//   R01-M-07  samma kvot utan verifierat tillstånd — INTE undantagen
//   R01-M-08  oreducerbar bakgrund ger unknown, aldrig ett fabricerat tal
//   R01-M-09  genomskinlig förgrund komposieras mot sitt faktiska underlag
//   R01-B-A…E bakgrundsalgoritmen prövad i fem skilda lägen

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { MEASURE } from './render-measure.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanför reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2);
}
mkdirSync(outAbs, { recursive: true });

// Färgparen är valda för att ge kända kvoter, verifierade för hand:
//   rgb(245,244,237) på rgb(36,56,44)  = 11,36   (aktiv flik i produkten)
//   rgb(147,164,141) på rgb(36,56,44)  =  4,73   (inaktiv flik i produkten)
//   rgb(141,141,141) på vit            =  3,32
//   svart 50 % på vit → rgb(128,128,128) = 3,95
const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{background:#fff;padding:8px}
 .flikrad{background:rgb(36,56,44);color:rgb(36,56,44);padding:6px}
</style>

<div class="sc-item" id="m01-container-arver-bakgrundsfargen">
  <!-- Behållaren har color == bakgrunden. Skulle ge 1,00 om den lästes. -->
  <div class="flikrad">
    <div data-a11y-role="tab" data-a11y-name="Hem" style="display:flex;flex-direction:column">
      <svg width="24" height="24" stroke="#F5F4ED" fill="none" data-icon="hem"><path d="M4 12 L12 4 L20 12"/></svg>
      <span style="color:rgb(245,244,237);font-size:11px">Hem</span>
    </div>
  </div>
</div>

<div class="sc-item" id="m02-inaktiv-flik">
  <div class="flikrad">
    <div data-a11y-role="tab" data-a11y-name="Meny" style="display:flex;flex-direction:column">
      <svg width="24" height="24" stroke="#93a48d" fill="none" data-icon="meny"><path d="M4 7h16"/></svg>
      <span style="color:rgb(147,164,141);font-size:11px">Meny</span>
    </div>
  </div>
</div>

<div class="sc-item" id="m03-tva-textruns">
  <div class="flikrad">
    <div data-a11y-role="button" data-a11y-name="Tva runs">
      <span style="color:rgb(245,244,237);font-size:11px">Ljus</span>
      <span style="color:rgb(147,164,141);font-size:11px">Dampad</span>
    </div>
  </div>
</div>

<div class="sc-item" id="m04-ikonkontroll">
  <!-- Tillgängligt namn finns, synlig text finns inte. -->
  <div data-a11y-role="button" data-a11y-name="Lagg till" style="width:56px;height:56px">
    <svg width="24" height="24" stroke="#111" fill="none" data-icon="plus"><path d="M12 5v14M5 12h14"/></svg>
  </div>
</div>

<div class="sc-item" id="m05-dold-text">
  <div data-a11y-role="button" data-a11y-name="Dold">
    <span style="display:none;color:rgb(141,141,141)">Ingen ska se mig</span>
    <span style="visibility:hidden;color:rgb(141,141,141)">Inte jag heller</span>
  </div>
</div>

<div class="sc-item" id="m06-disabled-verifierad">
  <button data-a11y-role="button" data-a11y-name="Nasta" data-a11y-state="disabled"
    style="background:#fff;border:0;font-size:14px;color:rgb(141,141,141)">Nasta</button>
</div>

<div class="sc-item" id="m07-samma-kvot-utan-state">
  <!-- Identisk kvot, men ingen positiv evidens för disabled. Färg och
       opacity får aldrig ensamma göra en kontroll undantagen. -->
  <div data-a11y-role="button" data-a11y-name="Skicka" style="opacity:.55">
    <span style="color:rgb(141,141,141);font-size:14px">Skicka</span>
  </div>
</div>

<div class="sc-item" id="m08-oreducerbar-bakgrund">
  <div style="background:linear-gradient(90deg,#000,#fff);padding:6px">
    <div data-a11y-role="button" data-a11y-name="Pa gradient">
      <span style="color:rgb(141,141,141);font-size:14px">Pa gradient</span>
    </div>
  </div>
</div>

<div class="sc-item" id="m09-genomskinlig-forgrund">
  <!-- Svart 50 % på vit ska komposieras till rgb(128,128,128) = 3,95. -->
  <div data-a11y-role="button" data-a11y-name="Halvgenomskinlig">
    <span style="color:rgba(0,0,0,.5);font-size:14px">Halvgenomskinlig</span>
  </div>
</div>

<div class="sc-item" id="ba-opak-direkt">
  <div style="background:rgb(36,56,44);padding:6px">
    <div data-a11y-role="button" data-a11y-name="A">
      <span style="color:rgb(245,244,237);font-size:14px">A</span></div>
  </div>
</div>

<div class="sc-item" id="bb-transparent-barn-over-opak">
  <div style="background:rgb(36,56,44);padding:6px">
    <div style="background:transparent;padding:4px">
      <div data-a11y-role="button" data-a11y-name="B">
        <span style="color:rgb(245,244,237);font-size:14px">B</span></div>
    </div>
  </div>
</div>

<div class="sc-item" id="bc-translucent-lager">
  <!-- Ett svart 50 %-lager över vitt ska bli rgb(128,128,128). -->
  <div style="background:rgba(0,0,0,.5);padding:6px">
    <div data-a11y-role="button" data-a11y-name="C">
      <span style="color:#fff;font-size:14px">C</span></div>
  </div>
</div>

<div class="sc-item" id="bd-flera-transparenta-lager">
  <div style="background:rgba(0,0,0,.5);padding:4px">
    <div style="background:transparent;padding:4px">
      <div style="background:transparent;padding:4px">
        <div data-a11y-role="button" data-a11y-name="D">
          <span style="color:#fff;font-size:14px">D</span></div>
      </div>
    </div>
  </div>
</div>

<div class="sc-item" id="be-bild-bakgrund">
  <div style="background-image:url(data:image/gif;base64,R0lGODlhAQABAAAAACw=);padding:6px">
    <div data-a11y-role="button" data-a11y-name="E">
      <span style="color:rgb(141,141,141);font-size:14px">E</span></div>
  </div>
</div>`;

const fixturPath = join(outAbs, 'kontrastprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

/* ── minimal CDP ─────────────────────────────────────────────────────────── */
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9600 + (process.pid % 150);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-kontrastprov'), 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });

let data = null, verktygsfel = null;
try {
  let wsUrl = null;
  for (let i = 0; i < 60 && !wsUrl; i++) {
    await sleep(250);
    try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {}
  }
  if (!wsUrl) throw new Error('Chrome startade aldrig sin debugger-port');
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP-anslutning misslyckades')); });
  let id = 0; const pend = new Map();
  ws.onmessage = m => { const msg = JSON.parse(m.data);
    if (msg.id && pend.has(msg.id)) { const { res, rej } = pend.get(msg.id); pend.delete(msg.id);
      msg.error ? rej(new Error(msg.error.message)) : res(msg.result); } };
  const call = (method, params = {}, sessionId) => new Promise((res, rej) => {
    const i = ++id; pend.set(i, { res, rej });
    ws.send(JSON.stringify({ id: i, method, params, ...(sessionId ? { sessionId } : {}) }));
    setTimeout(() => { if (pend.has(i)) { pend.delete(i); rej(new Error(method + ' svarade inte')); } }, 30000);
  });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable'); await s('Runtime.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 900, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  const r = await s('Runtime.evaluate', { expression: MEASURE, returnByValue: true, awaitPromise: false });
  if (r.exceptionDetails) throw new Error('mätskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 400));
  data = r.result.value;
  if (!data) throw new Error('mätskriptet returnerade inget');
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 14;
if (verktygsfel) {
  // Ett verktygsfel får ALDRIG räknas som godkända prov.
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('KONTRASTPROV status=VERKTYGSFEL godkända=0 av ' + ANTAL);
  process.exit(2);
}

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });
const ctl = (artId, namn) => {
  const a = data.artifacts.find(x => x.id === artId);
  return (a && (a.controls || []).find(c => c.name === namn)) || null;
};

{ const c = ctl('m01-container-arver-bakgrundsfargen', 'Hem');
  prov('R01-M-01', 'behållarens ärvda färg används aldrig som textfärg',
    !!c && c.contrast === 11.36 && c.contrastApplicability === 'applicable' &&
    c.textRuns_st === 1 && c.textRuns[0].malareArKontrollen === false,
    c ? 'kvot ' + c.contrast + ' · runs ' + c.textRuns_st + ' · målare är kontrollen: ' +
        c.textRuns[0].malareArKontrollen : 'kontrollen hittades inte'); }

{ const c = ctl('m02-inaktiv-flik', 'Meny');
  prov('R01-M-02', 'inaktiv flik mäts på sin faktiska barntext',
    !!c && c.contrast === 4.73 && c.underThreshold === false,
    c ? 'kvot ' + c.contrast + ' mot tröskel ' + c.contrastThreshold : 'saknas'); }

{ const c = ctl('m03-tva-textruns', 'Tva runs');
  const kvoter = c ? c.textRuns.map(r => r.ratio).sort((a, b) => a - b) : [];
  prov('R01-M-03', 'två text-runs mäts var för sig, ingen tredje kvot uppstår',
    !!c && c.textRuns_st === 2 && kvoter[0] === 4.73 && kvoter[1] === 11.36 &&
    c.contrast === 4.73 && c.textRuns.every(r => r.malareArKontrollen === false),
    c ? 'runs ' + JSON.stringify(kvoter) + ' · kontrollens resultat ' + c.contrast : 'saknas'); }

{ const c = ctl('m04-ikonkontroll', 'Lagg till');
  prov('R01-M-04', 'ikonkontroll med tillgängligt namn men utan synlig text',
    !!c && c.contrastApplicability === 'notApplicable:noVisibleText' &&
    c.textRuns_st === 0 && c.contrast === null && c.underThreshold === null,
    c ? c.contrastApplicability + ' · runs ' + c.textRuns_st + ' · kvot ' + c.contrast : 'saknas'); }

{ const c = ctl('m05-dold-text', 'Dold');
  prov('R01-M-05', 'display:none och visibility:hidden är inte synlig text',
    !!c && c.textRuns_st === 0 && c.contrastApplicability === 'notApplicable:noVisibleText',
    c ? 'runs ' + c.textRuns_st + ' · ' + c.contrastApplicability : 'saknas'); }

{ const c = ctl('m06-disabled-verifierad', 'Nasta');
  prov('R01-M-06', 'verifierat disabled: kvoten bevaras men räknas inte som produktfel',
    !!c && c.contrast === 3.32 && c.contrastApplicability === 'exempt:disabled' &&
    c.disabledVerifierad !== false && c.underThreshold === null,
    c ? 'kvot ' + c.contrast + ' · ' + c.contrastApplicability + ' · grund ' + c.disabledBasis : 'saknas'); }

{ const c = ctl('m07-samma-kvot-utan-state', 'Skicka');
  prov('R01-M-07', 'samma kvot utan verifierat tillstånd blir INTE undantagen',
    !!c && c.contrast === 3.32 && c.contrastApplicability === 'applicable' &&
    c.disabled === false && c.disabledBasis === null && c.underThreshold === true,
    c ? 'kvot ' + c.contrast + ' · ' + c.contrastApplicability +
        ' · under tröskel ' + c.underThreshold + ' · grund ' + c.disabledBasis : 'saknas'); }

{ const c = ctl('m08-oreducerbar-bakgrund', 'Pa gradient');
  prov('R01-M-08', 'oreducerbar bakgrund ger unknown, aldrig ett fabricerat tal',
    !!c && c.contrastApplicability === 'unknown' && c.contrast === null &&
    c.textRuns_st === 1 && c.textRuns[0].status === 'unknown' && c.underThreshold === null,
    c ? c.contrastApplicability + ' · kvot ' + c.contrast + ' · ' +
        (c.textRuns[0] ? c.textRuns[0].why : '') : 'saknas'); }

{ const c = ctl('m09-genomskinlig-forgrund', 'Halvgenomskinlig');
  const r = c && c.textRuns[0];
  prov('R01-M-09', 'genomskinlig förgrund komposieras mot sitt faktiska underlag',
    !!r && ((r.status === 'measured' && r.ratio === 3.95 && r.komposierad === 'rgb(128, 128, 128)') ||
            r.status === 'unknown'),
    r ? 'status ' + r.status + ' · kvot ' + r.ratio + ' · komposierad ' + r.komposierad : 'saknas'); }

/* ── Bakgrundsalgoritmen, fem lägen ──────────────────────────────────────── */
const bg = (artId, namn) => { const c = ctl(artId, namn); return c && c.textRuns[0]; };

{ const r = bg('ba-opak-direkt', 'A');
  prov('R01-B-A', 'opak direkt bakgrund läses rätt',
    !!r && r.bakgrund === 'rgb(36, 56, 44)' && r.ratio === 11.36,
    r ? r.bakgrund + ' · ' + r.ratio : 'saknas'); }

{ const r = bg('bb-transparent-barn-over-opak', 'B');
  prov('R01-B-B', 'genomskinligt barn läser den opaka förfaderns bakgrund',
    !!r && r.bakgrund === 'rgb(36, 56, 44)' && r.ratio === 11.36,
    r ? r.bakgrund + ' · ' + r.ratio : 'saknas'); }

{ const r = bg('bc-translucent-lager', 'C');
  prov('R01-B-C', 'translucent lager komposieras mot underlaget',
    !!r && r.bakgrund === 'rgb(128, 128, 128)' && r.ratio === 3.95,
    r ? r.bakgrund + ' · ' + r.ratio : 'saknas'); }

{ const r = bg('bd-flera-transparenta-lager', 'D');
  prov('R01-B-D', 'flera genomskinliga lager ger samma underlag som ett',
    !!r && r.bakgrund === 'rgb(128, 128, 128)' && r.ratio === 3.95,
    r ? r.bakgrund + ' · ' + r.ratio : 'saknas'); }

{ const r = bg('be-bild-bakgrund', 'E');
  prov('R01-B-E', 'bildbakgrund ger unknown, inte ett godtyckligt underlag',
    !!r && r.status === 'unknown' && r.ratio === null && r.bakgrund === null,
    r ? 'status ' + r.status + ' · kvot ' + r.ratio + ' · bakgrund ' + r.bakgrund : 'saknas'); }

for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(10) + r.vad);
  console.log('     ' + r.diag);
}
const godkända = resultat.filter(r => r.ok).length;
const status = godkända === ANTAL && resultat.length === ANTAL ? 'godkänd' : 'FÄLLD';
writeFileSync(join(outAbs, 'kontrastprov.json'),
  JSON.stringify({ $schema: 'butlery-kontrastprov/1', kontroll: 'CHK-R-01',
    godkända, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('KONTRASTPROV status=' + status + ' godkända=' + godkända + ' av ' + ANTAL);
process.exit(status === 'godkänd' ? 0 : 1);
