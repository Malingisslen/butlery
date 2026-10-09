#!/usr/bin/env node
// F2-R04 · DUAL RENDER OCH FORSTA MORKA BASLINJEN.
//
// Kör: node tools/theme-dual-render.mjs [--out=<fil>]
//
// Temat satts EXPLICIT pa de kallor som deklarerar stod for det, och bara pa
// dem. Ingen rendering fabriceras. Bara det som faktiskt renderats raknas.
//
// Conformance mats med de FRYSTA motorerna. R-04 infor inga egna regler.

import { spawn } from 'node:child_process';
import { readdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { MEASURE } from './render-measure.mjs';
import { tackning } from './theme-contract.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9990 + (process.pid % 9);

const SATT = tema => `(() => {
  const rorda = [];
  for (const it of document.querySelectorAll('.sc-item[data-theme-support]')) {
    const stod = (it.getAttribute('data-theme-support') || '').trim().split(/\\s+/);
    if (!stod.includes(${JSON.stringify(tema)})) continue;
    it.setAttribute('data-theme', ${JSON.stringify(tema)});
    rorda.push(it.id); }
  return rorda; })()`;

const INVENTERING = `(() => [...document.querySelectorAll('.sc-item')].map(it => ({
  art: it.id, tema: it.getAttribute('data-theme'),
  familj: it.getAttribute('data-theme-family'),
  stod: it.getAttribute('data-theme-support') })))()`;

const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(process.env.TEMP || '.', 'butlery-dual'), 'about:blank'], { stdio: 'ignore' });
let inv = [], perTema = { light: { renderade: [], nt: [], layout: [] }, dark: { renderade: [], nt: [], layout: [] } };
let verktygsfel = null;
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
    const i = await s('Runtime.evaluate', { expression: INVENTERING, returnByValue: true });
    inv.push(...(i.result.value || []));
    for (const tema of ['light', 'dark']) {
      const satt = await s('Runtime.evaluate', { expression: SATT(tema), returnByValue: true });
      await sleep(150);
      perTema[tema].renderade.push(...(satt.result.value || []));
      const nt = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
      if (nt.exceptionDetails) throw new Error('carriermodellen kastade i ' + f);
      perTema[tema].nt.push(...(nt.result.value || []));
      const ly = await s('Runtime.evaluate', { expression: MEASURE, returnByValue: true });
      if (ly.exceptionDetails) throw new Error('layoutmotorn kastade i ' + f);
      const v = ly.result.value;
      perTema[tema].layout.push(...(Array.isArray(v) ? v : (v && v.artifacts) || []));
    }
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('R04-DUAL status=VERKTYGSFEL'); process.exit(2);
}

const rend = new Map();
for (const t of ['light', 'dark']) for (const a of perTema[t].renderade) {
  if (!rend.has(a)) rend.set(a, []); rend.get(a).push(t); }
const artefakter = inv.map(x => ({ ...x, renderade: rend.get(x.art) || [] }));
const t = tackning(artefakter);

// Morka fynd, mätta med de frysta motorerna.
const morkaKallor = new Set([...rend.entries()].filter(([, v]) => v.includes('dark')).map(([k]) => k));
const ntMork = perTema.dark.nt.filter(x => morkaKallor.has(x.art));
const delar = ntMork.flatMap(x => x.delar.map(d => ({ ...d, art: x.art, namn: x.namn, disabled: x.disabled })));
const barare = delar.filter(d => d.carrier === 'componentIdentityCarrier' || d.carrier === 'stateCarrier');
const ickeTextFynd = barare.filter(d => d.status === 'matt' && !d.disabled && d.kvot < 3);
const okanda = delar.filter(d => d.carrier === 'unknown');

const doc = { $schema: 'butlery-r04-dual/1',
  $regel: 'Temat satts explicit pa de kallor som deklarerar stod. Ingen rendering fabriceras. Conformance mats med de frysta motorerna.',
  renderingar: { light_st: perTema.light.renderade.length, dark_st: perTema.dark.renderade.length,
    kallor: [...rend.entries()].map(([a, v]) => ({ art: a, renderade: v })) },
  tackning: { familjer_st: t.familjer_st, covered_st: t.covered_st,
    explicitPair_st: t.covered_explicitPair_st, dualThemeRender_st: t.covered_dualThemeRender_st,
    coverageGap_st: t.coverageGap_st, lightOnly_st: t.lightOnly_st, darkOnly_st: t.darkOnly_st,
    ambiguous_st: t.ambiguous_st, neutral_st: t.neutral_st,
    unknown_artefakter_st: t.unknown_artefakter_st,
    duala_familjer: t.familjer.filter(x => x.modell === 'dualThemeRender') },
  morkBaslinje: { kallor_st: morkaKallor.size, kontroller_st: ntMork.length,
    grafiskaDelar_st: delar.length, barare_st: barare.length,
    ickeText_fynd_st: ickeTextFynd.length, unknown_st: okanda.length,
    fynd: ickeTextFynd.sort((a, b) => a.kvot - b.kvot).slice(0, 40) },
  status: t.ambiguous_st === 0 ? 'reproducerbar' : 'TVETYDIGHETER FINNS' };
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('RENDERINGAR  light ' + perTema.light.renderade.length + ' · dark ' + perTema.dark.renderade.length);
console.log('');
console.log('TACKNING');
console.log('  familjer            ' + t.familjer_st);
console.log('  covered             ' + t.covered_st +
  '   explicitPair ' + t.covered_explicitPair_st + ' · dualThemeRender ' + t.covered_dualThemeRender_st);
console.log('  coverageGap         ' + t.coverageGap_st +
  '   lightOnly ' + t.lightOnly_st + ' · darkOnly ' + t.darkOnly_st);
console.log('  ambiguous           ' + t.ambiguous_st);
console.log('  neutral             ' + t.neutral_st);
console.log('');
console.log('FORSTA MORKA BASLINJEN, mätt med de frysta motorerna');
console.log('  morka kallor        ' + morkaKallor.size);
console.log('  kontroller          ' + ntMork.length);
console.log('  grafiska delar      ' + delar.length + '   barare ' + barare.length);
console.log('  non-text-fynd       ' + ickeTextFynd.length);
console.log('  unknown             ' + okanda.length);
for (const f of ickeTextFynd.sort((a, b) => a.kvot - b.kvot).slice(0, 12))
  console.log('    ' + String(f.kvot).padEnd(6) + f.art.padEnd(22) + f.typ.padEnd(10) +
    f.farg + ' mot ' + f.angransande);
console.log('');
console.log('R04-DUAL status=' + doc.status);
