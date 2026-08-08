#!/usr/bin/env node
// F2-NT · BASLINJE FOR ICKE-TEXTUELL KONTRAST OCH COLOR-ONLY.
//
// Kör: node tools/nontext-baseline.mjs [--out=<fil>]
//
// Tva SKILDA rapporter som aldrig slas ihop:
//   NON-TEXT CONTRAST  carriers mot sin angransande yta, troskel 3:1
//   USE OF COLOR       skiljs tva tillstand enbart av farg?
//
// Scopet ar UI-komponenter. Meningsbarande grafik utanfor kontroller
// inventeras separat och ingar inte i kontrollpopulationen.

import { spawn } from 'node:child_process';
import { readdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9580 + (process.pid % 100);

// Meningsbarande grafik UTANFOR kontroller — separat population.
const UTANFOR = `(() => {
  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    for (const g of it.querySelectorAll('svg, [data-icon], [data-illustration]')) {
      if (g.closest('[data-a11y-role]')) continue;      // hor till en kontroll
      const r = g.getBoundingClientRect();
      if (!(r.width > 0 && r.height > 0)) continue;
      ut.push({ art: it.id, tag: g.tagName.toLowerCase(),
        ikon: g.getAttribute('data-icon') || g.getAttribute('data-illustration') || null,
        w: +r.width.toFixed(1), h: +r.height.toFixed(1) });
    }
  }
  return ut;
})()`;

const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(process.env.TEMP || '.', 'butlery-nt'), 'about:blank'], { stdio: 'ignore' });
let K = [], G = [], verktygsfel = null;
try {
  let ws = null;
  for (let k = 0; k < 60 && !ws; k++) { await sleep(250);
    try { ws = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!ws) throw new Error('Chrome startade aldrig');
  const sock = new WebSocket(ws);
  await new Promise(r => { sock.onopen = r; });
  let id = 0; const p = new Map();
  sock.onmessage = m => { const j = JSON.parse(m.data); if (j.id && p.has(j.id)) { const res = p.get(j.id); p.delete(j.id); res(j.result); } };
  const call = (m, pr = {}, s) => new Promise(res => { const n = ++id; p.set(n, res); sock.send(JSON.stringify({ id: n, method: m, params: pr, ...(s ? { sessionId: s } : {}) })); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, pp) => call(m, pp, sessionId);
  await s('Page.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: false });
  for (const f of filer) {
    await s('Page.navigate', { url: pathToFileURL(resolve(f)).href });
    await sleep(400);
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    await sleep(650);
    const a = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
    if (a.exceptionDetails) throw new Error('matskriptet kastade i ' + f);
    K.push(...(a.result.value || []).map(x => ({ ...x, fil: f })));
    const b = await s('Runtime.evaluate', { expression: UTANFOR, returnByValue: true });
    G.push(...(b.result.value || []).map(x => ({ ...x, fil: f })));
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('NT-BASLINJE status=VERKTYGSFEL'); process.exit(2);
}

const delar = K.flatMap(x => x.delar.map(d => ({ ...d, art: x.art, roll: x.roll, namn: x.namn,
  state: x.state, disabled: x.disabled })));
const per = {}; for (const d of delar) per[d.carrier] = (per[d.carrier] || 0) + 1;
const carriers = delar.filter(d => d.carrier === 'componentIdentityCarrier' || d.carrier === 'stateCarrier');
const matta = carriers.filter(d => d.status === 'matt');
const okanda = carriers.filter(d => d.status === 'unknown');
const undantagna = matta.filter(d => d.disabled);
const bedomda = matta.filter(d => !d.disabled);
const fynd = bedomda.filter(d => d.kvot < 3);

// COLOR-ONLY · parvis per komponentfamilj och tillstandspar.
const familj = new Map();
for (const x of K) { if (!x.state) continue;
  const k = x.roll + ' ‖ ' + (x.namn || '').replace(/\d+/g, '#');
  if (!familj.has(k)) familj.set(k, []); familj.get(k).push(x); }
const parbedomning = [];
for (const [k, v] of familj) {
  const states = [...new Set(v.map(x => x.state))];
  if (states.length < 2) continue;
  for (let i = 0; i < states.length; i++) for (let j = i + 1; j < states.length; j++) {
    const a = v.find(x => x.state === states[i]), b = v.find(x => x.state === states[j]);
    const skillnader = [];
    if (a.signaler.bock !== b.signaler.bock) skillnader.push('bock tillkommer eller forsvinner');
    if (a.signaler.chevron !== b.signaler.chevron) skillnader.push('chevron byts');
    if (a.signaler.glyfNamn !== b.signaler.glyfNamn) skillnader.push('glyfuppsattningen skiljer');
    if (a.signaler.thumbLage !== b.signaler.thumbLage) skillnader.push('knoppens lage skiljer');
    if (a.signaler.barnAntal !== b.signaler.barnAntal) skillnader.push('antal synliga delar skiljer');
    if (a.signaler.form !== b.signaler.form) skillnader.push('formen skiljer');
    if (a.text !== b.text) skillnader.push('texten skiljer');
    parbedomning.push({ familj: k, stateA: states[i], stateB: states[j],
      artA: a.art, artB: b.art, ickeFargSignaler: skillnader,
      colorOnly: skillnader.length === 0 });
  }
}
const colorOnly = parbedomning.filter(x => x.colorOnly);

const doc = { $schema: 'butlery-nt-baslinje/1', kontroll: 'CHK-NT-01',
  $regel: 'Rollen avgors ur strukturen, aldrig ur kontrastvardet. Icke-textuell kontrast och color-only ar skilda rapporter och slas aldrig ihop.',
  kontrollgrafik: { kontroller_st: K.length, grafiska_delar_st: delar.length, perRoll: per },
  ickeTextuellKontrast: { carriers_st: carriers.length, matta_st: matta.length,
    unknown_st: okanda.length, undantagna_disabled_st: undantagna.length,
    bedomda_st: bedomda.length, fynd_under_3_st: fynd.length,
    berorda_kontroller_st: new Set(fynd.map(d => d.art + '|' + d.namn)).size,
    berorda_artefakter_st: new Set(fynd.map(d => d.art)).size,
    fynd: fynd.sort((a, b) => a.kvot - b.kvot).slice(0, 60),
    unknown: okanda.slice(0, 30) },
  colorOnly: { familjer_st: familj.size, jamforda_par_st: parbedomning.length,
    med_ickefarg_signal_st: parbedomning.length - colorOnly.length,
    colorOnly_st: colorOnly.length, colorOnly, alla: parbedomning },
  grafikUtanforKontroller: { st: G.length, artefakter_st: new Set(G.map(x => x.art)).size,
    $not: 'Separat population. Ingar aldrig i kontrollpopulationen och ar annu inte matt — WCAG 1.4.11 kan darfor inte kallas stangd.',
    exempel: G.slice(0, 20) },
  status: (okanda.length + fynd.length) ? 'FÄLLD' : 'godkänd' };
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('KONTROLLGRAFIK  kontroller ' + K.length + ' · grafiska delar ' + delar.length);
console.log('  per roll: ' + JSON.stringify(per));
console.log('');
console.log('ICKE-TEXTUELL KONTRAST');
console.log('  carriers            ' + carriers.length);
console.log('  matta               ' + matta.length);
console.log('  unknown             ' + okanda.length);
console.log('  undantagna disabled ' + undantagna.length);
console.log('  bedomda             ' + bedomda.length);
console.log('  fynd under 3:1      ' + fynd.length + ' i ' + new Set(fynd.map(d => d.art)).size + ' artefakter');
console.log('');
console.log('COLOR-ONLY');
console.log('  familjer            ' + familj.size);
console.log('  jamforda par        ' + parbedomning.length);
console.log('  med ickefarg-signal ' + (parbedomning.length - colorOnly.length));
console.log('  color-only          ' + colorOnly.length);
console.log('');
console.log('GRAFIK UTANFOR KONTROLLER  ' + G.length + ' i ' + new Set(G.map(x => x.art)).size + ' artefakter (ej matt)');
console.log('NT-BASLINJE status=' + doc.status);
process.exit(doc.status === 'godkänd' ? 0 : 1);
