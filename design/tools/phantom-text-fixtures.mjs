#!/usr/bin/env node
// F2-R01 · PROV FOR FANTOMTEXTRELATIONEN.  PT-01 … PT-06
//
// Kör: node tools/phantom-text-fixtures.mjs --out=<katalog utanfor repot>
//
// PT-01 till PT-04 provar regeln. PT-05 och PT-06 provar den mot verkligheten:
// de sex saffransikonknapparna i produktkallan och hela den aktuella
// R-01-populationen. En regel som bara provas mot sin egen fixtur bevisar
// ingenting om korpusen.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { TEXT_POPULATION } from './text-population.mjs';
import { textrelation, farBliSkrivplan, glyfensForgrundArArvd,
  TEXTRELATION, GLYFMALNING } from './phantom-text.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });

/* De sex kanda ikonknapparna: artefakt och kontrollens produktordinal. */
const SEX = [
  { art: 'tangentbord',       ordinal: 19, fil: 'Butlery Skarmar v12 del 3 sok och skalbevis.dc.html' },
  { art: 'chattredigerat',    ordinal: 42, fil: 'Butlery Skarmar v12 del 4 morkt lage och etapp 0-1.dc.html' },
  { art: 'chattmeny',         ordinal: 27, fil: 'Butlery Skarmar v12 del 4 morkt lage och etapp 0-1.dc.html' },
  { art: 'receptkommentarer', ordinal: 46, fil: 'Butlery Skarmar v12 del 4 morkt lage och etapp 0-1.dc.html' },
  { art: 'bredlandskap',      ordinal: 28, fil: 'Butlery Skarmar v12 etapp 10 bred layout.dc.html' },
  { art: 'globinstallera',    ordinal: 38, fil: 'Butlery Skarmar v12 etapp 9 globala tillstand och flerval.dc.html' } ];
const filer = [...new Set(SEX.map(x => x.fil))];

/* ── PT-01 · beraknad color utan renderad text ar ingen relation ────────── */
{ const r = textrelation({ renderadeTextnoder: 0, glyfmalning: GLYFMALNING.EGEN_FARG,
    beraknadFarg: 'rgb(36, 56, 44)', fargkallaFinns: false });
  prov('PT-01', 'en kontroll utan renderad text far ingen textkontrastrelation bara for ' +
    'att en beraknad color finns',
    r.klass === TEXTRELATION.PHANTOM_TEXT_RELATION && r.skrivbar === false, r.skal); }

/* ── PT-02 · ikonens egen farg gor foralderns color irrelevant ──────────── */
{ const egen = glyfensForgrundArArvd(GLYFMALNING.EGEN_FARG);
  const cc = glyfensForgrundArArvd(GLYFMALNING.CURRENTCOLOR);
  const r = textrelation({ renderadeTextnoder: 0, glyfmalning: GLYFMALNING.EGEN_FARG,
    beraknadFarg: 'rgb(36, 56, 44)' });
  prov('PT-02', 'en ikon med egen malande farg tar aldrig foralderns color som forgrund',
    egen === false && cc === true && r.klass === TEXTRELATION.PHANTOM_TEXT_RELATION,
    'egen farg -> arvd forgrund ' + egen + ' · currentColor -> arvd forgrund ' + cc); }

/* ── PT-03 · verklig text som arver color ger fortfarande en relation ───── */
{ const r = textrelation({ renderadeTextnoder: 3, glyfmalning: GLYFMALNING.INGEN_GLYF,
    beraknadFarg: 'rgb(36, 56, 44)', fargkallaFinns: false });
  prov('PT-03', 'finns verklig text som faktiskt arver color skapas relationen anda',
    r.klass === TEXTRELATION.TEXTRELATION_FINNS && r.skrivbar === true &&
    farBliSkrivplan(r) === true, r.skal); }

/* ── PT-04 · en icke-malande arvd farg far inte bli plan, kandidat, fynd ── */
{ const fantom = textrelation({ renderadeTextnoder: 0, glyfmalning: GLYFMALNING.CURRENTCOLOR,
    beraknadFarg: 'rgb(36, 56, 44)' });
  const okand = textrelation({ glyfmalning: GLYFMALNING.INGEN_GLYF });
  prov('PT-04', 'en icke-malande arvd farg genererar varken skrivplan, ' +
    'remedieringskandidat eller preview-fynd — och okant underlag gor det inte heller',
    farBliSkrivplan(fantom) === false &&
    okand.klass === TEXTRELATION.UNKNOWN_TEXTRELATION && farBliSkrivplan(okand) === false,
    'fantom: ' + fantom.klass + ' · okant: ' + okand.klass); }

/* ── Korpusmatning for PT-05 och PT-06 ──────────────────────────────────── */
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9840 + (process.pid % 120);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(outAbs, 'chrome-ptprov'), 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });

let text = [], verktygsfel = null;
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
    setTimeout(() => { if (pend.has(i)) { pend.delete(i); rej(new Error(method + ' svarade inte')); } }, 60000); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable'); await s('Runtime.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: false });
  for (const f of filer) {
    await s('Page.navigate', { url: pathToFileURL(resolve(f)).href });
    for (let i = 0; i < 80; i++) { await sleep(150);
      const klar = await s('Runtime.evaluate', { expression:
        'document.readyState === "complete" && !!document.querySelector(".sc-item[id]")',
        returnByValue: true });
      if (klar.result.value) break; }
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    const r = await s('Runtime.evaluate', { expression: TEXT_POPULATION, returnByValue: true });
    if (r.exceptionDetails) throw new Error('textmotorn kastade: ' +
      JSON.stringify(r.exceptionDetails).slice(0, 300));
    const v = r.result.value;
    text.push(...(Array.isArray(v) ? v : (v.poster || v.runs || [])));
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 6;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('FANTOMTEXTPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2); }

/* ── PT-05 · de sex ger exakt noll textrelationer ───────────────────────── */
{ const rader = SEX.map(x => { const n = text.filter(t => t.art === x.art &&
    t.agare && t.agare.ordinal === x.ordinal).length;
  return { id: x.art + '|' + x.ordinal, n, rel: textrelation({ renderadeTextnoder: n,
    glyfmalning: GLYFMALNING.EGEN_FARG }) }; });
  const ok = rader.every(r => r.n === 0 &&
    r.rel.klass === TEXTRELATION.PHANTOM_TEXT_RELATION && !farBliSkrivplan(r.rel));
  prov('PT-05', 'de sex kanda saffransikonknapparna ger exakt 0 textrelationer och ' +
    'exakt 0 textskrivningar',
    ok, rader.map(r => r.id + ':' + r.n).join('  ') + '  ·  skrivbara ' +
      rader.filter(r => farBliSkrivplan(r.rel)).length); }

/* ── PT-06 · R-01-populationen ar oforandrad av metodfixen ──────────────── */
{ const under = text.filter(t => t.underThreshold);
  const utanText = text.filter(t => !String(t.text || '').trim());
  prov('PT-06', 'R-01-populationen ar oberord av metodfixen och har fortfarande ' +
    '0 underkanda textkorningar',
    under.length === 0 && utanText.length === 0 && text.length > 0,
    text.length + ' textkorningar i de fyra filerna · ' + under.length +
    ' under troskeln · ' + utanText.length + ' utan renderad text'); }

for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(7) + r.vad);
  console.log('     ' + r.diag); }
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'fantomtextprov.json'), JSON.stringify({
  $schema: 'butlery-fantomtextprov/1', kontroll: 'CHK-PT-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('FANTOMTEXTPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
