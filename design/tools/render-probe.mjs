#!/usr/bin/env node
// Butlery · RENDERINGSHARNESS för R-01…R-04.
// Kör: node tools/render-probe.mjs --out=<katalog> [--only=<artefakt-id>]
//
// F2-R01 · Renderade fynd kan inte läsas ur markup. Kontrast mot faktisk
// bakgrund, effektiv träffyta, klippning och mörkt läge kräver en layoutmotor.
// Fas 0–1 mätte deklarationer; det här mäter resultat.
//
// TVÅ FELKLASSER, aldrig sammanblandade:
//   verktygsfel      harnesset kunde inte mäta — navigationsfel, timeout,
//                    saknat element, fontfel, noll körda fall. ALDRIG godkänt.
//   geometriavvikelse  harnesset mätte, och mätningen visar ett fynd.
//
// Harnesset har INGA egna breddtal. Profiler och prober läses ur
// layout-contract.json. Ändras kontraktet ändras mätningen — inte tvärtom.
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const ONLY = arg('only');
// R-04 · mörkt läge mäts genom att EMULERA prefers-color-scheme, inte genom att
// hoppas att dokumentet har en mörk variant.
const DARK = process.argv.includes('--dark');
// F2-R03 · --at=<bredd> kör samtliga profiltilldelade artefakter på EN bredd.
// Det är så en parvis jämförelse blir möjlig: samma artefakter, två bredder,
// allt annat lika.
const AT = arg('at') ? Number(arg('at')) : null;
if (!OUT) { console.error('✖ ange --out=<katalog utanför manifestytan>'); process.exit(2); }

const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten. Råloggar och renderingsartefakter ska ligga utanför manifestytan.');
  process.exit(2);
}
mkdirSync(outAbs, { recursive: true });

const LC = JSON.parse(readFileSync('layout-contract.json', 'utf8'));
const REG = JSON.parse(readFileSync('artifacts.json', 'utf8'));
const PROFILES = new Map(LC.profiles.map(p => [p.id, p]));
const DPR = LC.render.devicePixelRatio;
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

/* ── CDP-klient ─────────────────────────────────────────────────────────────
 * Node 22 har WebSocket inbyggt, så drivrutinen behöver inget beroende. Varje
 * fel här är ett VERKTYGSFEL. */
class CDP {
  constructor(ws) { this.ws = ws; this.id = 0; this.pending = new Map(); this.events = new Map(); }
  static async connect(url, timeoutMs = 15000) {
    const ws = new WebSocket(url);
    await new Promise((res, rej) => {
      const t = setTimeout(() => rej(new Error('CDP-anslutningen tog längre än ' + timeoutMs + ' ms')), timeoutMs);
      ws.onopen = () => { clearTimeout(t); res(); };
      ws.onerror = e => { clearTimeout(t); rej(new Error('CDP-anslutning misslyckades: ' + (e.message || 'okänt fel'))); };
    });
    const c = new CDP(ws);
    ws.onmessage = m => {
      const msg = JSON.parse(m.data);
      if (msg.id && c.pending.has(msg.id)) {
        const { res, rej } = c.pending.get(msg.id);
        c.pending.delete(msg.id);
        msg.error ? rej(new Error(msg.error.message)) : res(msg.result);
      } else if (msg.method) {
        (c.events.get(msg.method) || []).forEach(fn => fn(msg.params));
      }
    };
    return c;
  }
  on(method, fn) { if (!this.events.has(method)) this.events.set(method, []); this.events.get(method).push(fn); }
  send(method, params = {}, timeoutMs = 30000) {
    const id = ++this.id;
    return new Promise((res, rej) => {
      const t = setTimeout(() => { this.pending.delete(id); rej(new Error(method + ' svarade inte inom ' + timeoutMs + ' ms')); }, timeoutMs);
      this.pending.set(id, { res: v => { clearTimeout(t); res(v); }, rej: e => { clearTimeout(t); rej(e); } });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  close() { try { this.ws.close(); } catch {} }
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

/* ── Mätskriptet som körs I SIDAN ───────────────────────────────────────────
 * Returnerar rådata. All bedömning sker i Node, så tröskelvärden aldrig
 * hamnar i två versioner. */
import { MEASURE } from './render-measure.mjs';

/* ── Körning ────────────────────────────────────────────────────────────── */
const toolErrors = [];
const results = [];
let planned = 0, ranCases = 0, measured = 0, failed = 0;

// Vilka artefakter körs, och på vilken profil? Ur REGISTRET — bord och
// annoteringar får ingen viewportprofil och körs därför inte.
const cases = [];
for (const a of REG.artifacts) {
  if (!a.viewportProfile) continue;
  if (ONLY && a.sourceElementId !== ONLY) continue;
  const p = PROFILES.get(a.viewportProfile);
  if (!p) { toolErrors.push('profilen ' + a.viewportProfile + ' för ' + a.artifactId + ' finns inte i layoutkontraktet'); continue; }
  if (AT !== null) {
    cases.push({ a, profile: { id: 'at-' + AT, width: AT, height: p.height, mode: p.mode, synthetic: true } });
    continue;
  }
  cases.push({ a, profile: p });
  // Gridfall körs dessutom på ultrawide-profilen.
  const ultra = LC.profiles.find(x => x.id === 'expanded-ultrawide-2048');
  if (ultra && p.mode === 'expanded' && a.viewportClass === 'wide') cases.push({ a, profile: ultra });
}
planned = cases.length;

// Gruppera per fil och profil så varje sida laddas en gång per bredd.
const byKey = new Map();
for (const c of cases) {
  const k = c.a.sourceFile + '|' + c.profile.id;
  if (!byKey.has(k)) byKey.set(k, { file: c.a.sourceFile, profile: c.profile, ids: [] });
  byKey.get(k).ids.push(c.a.sourceElementId);
}
// Gränsproberna körs mot EN representativ fil per läge — de mäter gränsen,
// inte artefakten.
const probeFile = [...new Set(REG.artifacts.filter(a => a.viewportClass === 'wide').map(a => a.sourceFile))][0];
for (const pr of (AT === null ? LC.probes : [])) {
  if (!probeFile) break;
  byKey.set('PROB|' + pr.width, { file: probeFile, probe: pr,
    profile: { id: 'prob-' + pr.width, width: pr.width, height: 900, mode: pr.expectMode } });
}

const port = 9333 + (process.pid % 500);
const chrome = spawn(CHROME, [
  '--headless=new', '--remote-debugging-port=' + port, '--disable-gpu',
  '--no-first-run', '--no-default-browser-check', '--disable-extensions',
  '--allow-file-access-from-files', '--force-device-scale-factor=' + DPR,
  '--user-data-dir=' + join(outAbs, 'chrome-profil'), 'about:blank'
], { stdio: ['ignore', 'ignore', 'pipe'] });
let chromeErr = '';
chrome.stderr.on('data', d => { chromeErr += d.toString(); });

const finish = code => {
  try { chrome.kill(); } catch {}
  process.exitCode = code;
};

try {
  // Vänta på debugger-porten.
  let wsUrl = null;
  for (let i = 0; i < 60 && !wsUrl; i++) {
    await sleep(250);
    try {
      const r = await fetch('http://127.0.0.1:' + port + '/json/version');
      const j = await r.json();
      wsUrl = j.webSocketDebuggerUrl;
      console.log('CHROME ' + j.Browser + ' · protokoll ' + j['Protocol-Version']);
    } catch { /* inte uppe än */ }
  }
  if (!wsUrl) throw new Error('Chrome startade aldrig sin debugger-port. stderr: ' + chromeErr.slice(0, 300));

  const browser = await CDP.connect(wsUrl);
  const { targetId } = await browser.send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await browser.send('Target.attachToTarget', { targetId, flatten: true });
  const sess = (m, p) => browser.send(m, p, 45000).catch(e => { throw e; });
  // Flat session: lägg sessionId på varje anrop.
  const send = (method, params = {}) => new Promise((res, rej) => {
    const id = ++browser.id;
    const t = setTimeout(() => { browser.pending.delete(id); rej(new Error(method + ' timeout')); }, 45000);
    browser.pending.set(id, { res: v => { clearTimeout(t); res(v); }, rej: e => { clearTimeout(t); rej(e); } });
    browser.ws.send(JSON.stringify({ id, method, params, sessionId }));
  });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  const netFails = [];
  browser.on('Network.loadingFailed', p => netFails.push(p));

  for (const [key, job] of byKey) {
    const label = job.probe ? 'PROB ' + job.probe.width : job.profile.id;
    try {
      await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: DARK ? 'dark' : 'light' }] });
      await send('Emulation.setDeviceMetricsOverride', {
        width: job.profile.width, height: job.profile.height,
        deviceScaleFactor: DPR, mobile: false
      });
      const url = pathToFileURL(resolve(job.file)).href;
      netFails.length = 0;
      const nav = await send('Page.navigate', { url });
      if (nav.errorText) throw new Error('navigationsfel: ' + nav.errorText);

      // Vänta på dokument, typsnitt och bilder — var för sig, med egna fel.
      const ready = await send('Runtime.evaluate', {
        expression: `(async () => {
          if (document.readyState !== 'complete')
            await new Promise(r => addEventListener('load', r, { once: true }));
          const fonts = document.fonts ? await document.fonts.ready.then(() => 'ok').catch(e => 'FEL:' + e) : 'saknas';
          const imgs = [...document.images];
          const bad = [];
          await Promise.all(imgs.map(i => i.complete ? null : new Promise(r => {
            i.addEventListener('load', r, { once: true });
            i.addEventListener('error', () => { bad.push(i.currentSrc || i.src); r(); }, { once: true });
            setTimeout(r, 5000);
          })));
          // Stäng av animationer och övergångar EFTER laddning.
          const s = document.createElement('style');
          s.textContent = '*,*::before,*::after{animation:none!important;transition:none!important;' +
            'animation-duration:0s!important;transition-duration:0s!important;caret-color:transparent!important}';
          document.head.appendChild(s);
          return { readyState: document.readyState, fonts, images: imgs.length, brokenImages: bad.length,
                   items: document.querySelectorAll('.sc-item').length };
        })()`, awaitPromise: true, returnByValue: true, timeout: 40000
      });
      const r0 = ready.result && ready.result.value;
      if (!r0) throw new Error('mätuppstarten returnerade inget');
      if (String(r0.fonts).startsWith('FEL')) throw new Error('typsnitt kunde inte laddas: ' + r0.fonts);
      if (r0.fonts === 'saknas') throw new Error('document.fonts saknas — typsnittsstatus kan inte bevisas');
      if (r0.brokenImages) throw new Error(r0.brokenImages + ' bilder kunde inte laddas');
      if (!r0.items) throw new Error('noll .sc-item i dokumentet — inget att mäta');

      await sleep(120);   // en frame efter att animationer stängts av
      const m = await send('Runtime.evaluate', { expression: MEASURE, returnByValue: true, timeout: 40000 });
      if (!m.result || m.result.value === undefined) throw new Error('mätskriptet returnerade inget');
      const data = m.result.value;
      if (!data.artifacts.length) throw new Error('mätningen hittade noll artefakter');

      const wanted = job.ids ? new Set(job.ids) : null;
      const picked = wanted ? data.artifacts.filter(x => wanted.has(x.id)) : data.artifacts;
      if (wanted && picked.length !== job.ids.length) {
        const missing = job.ids.filter(id => !picked.some(x => x.id === id));
        throw new Error('saknade element i renderat DOM: ' + missing.join(', '));
      }
      results.push({ key, file: job.file, profile: job.profile, probe: job.probe || null,
        scheme: data.colorScheme, bodyBg: data.bodyBg, bodyColor: data.bodyColor,
        viewport: data.viewport, fontsReady: data.fontsReady, artifacts: picked,
        networkFailures: netFails.map(f => f.errorText).slice(0, 5) });
      ranCases++; measured += picked.length;
      console.log('✔ ' + label + ' · ' + job.file.replace(/^Butlery Skarmar v12 /, '').slice(0, 34) +
        ' · ' + picked.length + ' artefakter');
    } catch (e) {
      failed++;
      toolErrors.push(label + ' · ' + job.file + ' :: ' + e.message);
      console.error('✖ VERKTYGSFEL ' + label + ' · ' + job.file.slice(0, 40) + ' :: ' + e.message);
    }
  }
  browser.close();
} catch (e) {
  toolErrors.push('harnesset kunde inte starta: ' + e.message);
  console.error('✖ VERKTYGSFEL ' + e.message);
}

writeFileSync(join(outAbs, 'render-raw.json'), JSON.stringify({
  chrome: LC.render.chromeVersion, dpr: DPR, contractVersion: LC.version, colorScheme: DARK ? 'dark' : 'light',
  plannedCases: byKey.size, ranCases, measured, failedCases: failed, plannedArtifacts: planned, toolErrors, results
}, null, 1));

console.log('RENDER-SUMMARY planned_cases=' + byKey.size + ' ran_cases=' + ranCases +
  ' failed_cases=' + failed + ' artifacts_measured=' + measured +
  ' planned_artifacts=' + planned + ' tool_errors=' + toolErrors.length + ' out=' + outAbs);
if (!ranCases) { console.error('✖ NOLL körda fall — det är ett verktygsfel, aldrig ett godkänt utfall'); finish(1); }
else if (toolErrors.length) finish(1);
else finish(0);
