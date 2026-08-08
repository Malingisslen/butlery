#!/usr/bin/env node
// F2-R02 · POPULATIONSRAPPORTEN FÖR TRÄFFYTOR.
//
// Kör: node tools/hit-population.mjs [--out=<fil>] [--fryst]
//
// Rapporterar den frusna populationsmodellen och faller på varje invariant som
// bryts. --fryst prövar dessutom talen mot den beslutade modellen, så att en
// tyst drift i ritningarna upptäcks som drift och inte som en ny sanning.
//
// Detta är INTE R-02:s mätbaslinje. Ingen migration av befintliga
// data-hit-deklarationer är gjord, och därför är nästan hela populationen
// ännu odömd. Baslinjen tas efter produktvändan.

import { spawn } from 'node:child_process';
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';
import { HIT_MEASURE } from './hit-measure.mjs';
import { population, klassificera, domslut } from './hit-contract.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const FRYST = process.argv.includes('--fryst');

// Den frusna modellen. Talen är beslutade, inte uppmätta i den här körningen —
// därför prövas de, aldrig skrivs de.
export const FRUSEN = {
  // Frusen ar bara det som INTE far rora sig. Antalet data-hit och antalet
  // odeklarerade VAXER respektive KRYMPER med varje migration — det ar hela
  // poangen med migrationen och far aldrig larmas som drift.
  sourceDeclarations: 1376, renderade: 1376, delta: 0,
  utanforArtefakt: 32, utanforPerFil: {
    'Butlery Skarmar v12 del 1 recept och veckomeny.dc.html': 28,
    'Butlery Skarmar v12 del 2 familj och socialt.dc.html': 4 }
};

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const TMP = join(process.env.TEMP || '.', 'butlery-hitpop');
const port = 9310 + (process.pid % 130);

const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
let kallDeklarationer = 0, kallDataHit = 0;
for (const f of filer) {
  const t = readFileSync(f, 'utf8');
  kallDeklarationer += (t.match(/data-a11y-role=/g) || []).length;
  kallDataHit += (t.match(/data-hit=/g) || []).length;
}

const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2', '--user-data-dir=' + TMP, 'about:blank'], { stdio: 'ignore' });

let poster = null, verktygsfel = null;
try {
  let wsUrl = null;
  for (let i = 0; i < 60 && !wsUrl; i++) { await sleep(250);
    try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
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
    setTimeout(() => { if (pend.has(i)) { pend.delete(i); rej(new Error(method + ' svarade inte')); } }, 30000); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable'); await s('Runtime.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: false });
  poster = [];
  for (const f of filer) {
    await s('Page.navigate', { url: pathToFileURL(resolve(f)).href });
    await sleep(400);
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    await sleep(700);
    const r = await s('Runtime.evaluate', { expression: HIT_MEASURE, returnByValue: true });
    if (r.exceptionDetails) throw new Error('mätskriptet kastade i ' + f);
    const v = r.result.value;
    if (!v) throw new Error('ingen mätning för ' + f);
    poster.push(...v.poster.map(p => ({ ...p, fil: f })));
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('TRÄFFYTEPOPULATION status=VERKTYGSFEL');
  process.exit(2);
}

const rap = population(poster, { kallDeklarationer, kallDataHit });

// Domsluten redovisas, men de är ännu inte en baslinje: utan migration är
// varje löptextdeklaration unknown, och det är avsikten.
const dom = poster.filter(p => p.roll && p.iRegistreradArtefakt).map(domslut);
const perStatus = {};
for (const d of dom) perStatus[d.status] = (perStatus[d.status] || 0) + 1;

const driftfel = [];
if (FRYST) {
  const p = (namn, faktisk, forvantat) => {
    if (faktisk !== forvantat) driftfel.push(namn + ' ' + faktisk + ' != fryst ' + forvantat); };
  p('SOURCE DECLARATIONS källtext', kallDeklarationer, FRUSEN.sourceDeclarations);
  p('SOURCE DECLARATIONS renderade', rap.sourceDeclarations.renderade, FRUSEN.renderade);
  p('delta', rap.sourceDeclarations.delta, FRUSEN.delta);
  p('OUTSIDE REGISTERED ARTIFACTS', rap.outsideRegisteredArtifacts.st, FRUSEN.utanforArtefakt);
  const perFil = {};
  for (const x of rap.outsideRegisteredArtifacts.poster) perFil[x.fil] = (perFil[x.fil] || 0) + 1;
  for (const [f, n] of Object.entries(FRUSEN.utanforPerFil)) p('utanför artefakt i ' + f, perFil[f] || 0, n);
}

const doc = { $schema: 'butlery-traffytepopulation/1', kontroll: 'CHK-R-02',
  $note: 'Populationsmodell och domslut. INTE R-02:s mätbaslinje — ingen migration av befintliga data-hit-deklarationer är gjord.',
  frusenModell: FRYST ? FRUSEN : null, driftfel,
  ...rap, domslutPerStatus: perStatus,
  status: rap.failClosed.fel.length + driftfel.length ? 'FÄLLD' : 'godkänd' };
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('SOURCE DECLARATIONS  källtext ' + kallDeklarationer +
  ' · renderade ' + rap.sourceDeclarations.renderade + ' · delta ' + rap.sourceDeclarations.delta);
console.log('DATA-HIT             totalt ' + rap.dataHit.totalt +
  ' = ' + rap.dataHit.pa_kontroller + ' på kontroller + ' + rap.dataHit.pa_element_utan_roll + ' utan roll');
console.log('UNDECLARED           ' + rap.undeclared.utan_data_hit + ' utan data-hit + ' +
  rap.undeclared.aktiverbara_utan_deklaration + ' aktiverbara = ' + rap.undeclared.summa);
console.log('OUTSIDE ARTIFACTS    ' + rap.outsideRegisteredArtifacts.st + '  (utanför produktnämnaren)');
console.log('CONTROL × VIEWPORT   annan mätenhet — ingår aldrig i summan ovan');
console.log('produktnämnare       ' + rap.produktnamnare_st);
console.log('klasser              ' + JSON.stringify(rap.klasser));
console.log('domslut              ' + JSON.stringify(perStatus));
for (const f of rap.failClosed.fel) console.log('  ✖ invariant: ' + f);
for (const f of driftfel) console.log('  ✖ drift: ' + f);
console.log('TRÄFFYTEPOPULATION status=' + doc.status);
process.exit(doc.status === 'godkänd' ? 0 : 1);
