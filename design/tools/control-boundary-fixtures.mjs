#!/usr/bin/env node
// F2-NT · PROV FOR KONTROLLGRANSEN SOM GRAFISK DEL.  IB-01 … IB-06
//
// Kör: node tools/control-boundary-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN PROVEN FINNS FOR
// Fram till 2026-08-16 enumererade nontext-measure kontrollens egen malade
// grans BARA i den textmarkta grenen. Exakt samma fysiska kant blev darfor en
// grafisk del pa en textknapp och foll bort pa en ikonknapp — inte for att
// kanten skilde sig, utan for att en textnod fanns eller saknades. Textnoder
// ar ingen egenskap hos en kant, och en tackningslucka som beror pa
// syskonelementets innehall ar inte en matning utan en slump.
//
// IB-05 och IB-06 provar mot de SEX verkliga saffransikonknapparna i
// produktkallan, med de varden den separata direktmatningen gav i f68becd.
// Ett prov som bara laser en syntetisk fixtur skulle inte visa att den
// ordinarie motorn nu duger som enda bevisvag.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
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
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });

const SVG = f => '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="' + f +
  '" stroke-width="1.75" data-icon="send"><path d="M20 4L4 11l6 3 3 6z"/></svg>';
const RAM = 'border:1.5px solid #3F5145;box-sizing:border-box';
const KNAPP = 'display:inline-flex;align-items:center;justify-content:center;' +
  'width:120px;height:48px;background:#CE7C1E;color:#17251D';

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#F5F4ED;color:#17251D;font:14px/1.4 system-ui}
 .sc-item{padding:12px;background:#F5F4ED}
</style>

<div class="sc-item" id="ib01-textknapp">
  <span data-a11y-role="button" data-a11y-name="Spara" data-hit="self"
    style="${KNAPP};${RAM}">Spara</span>
</div>

<div class="sc-item" id="ib02-ikonknapp">
  <span data-a11y-role="button" data-a11y-name="Skicka" data-hit="self"
    style="${KNAPP};${RAM}">${SVG('#17251d')}</span>
</div>

<div class="sc-item" id="ib03-text-och-ikon">
  <span data-a11y-role="button" data-a11y-name="Skicka nu" data-hit="self"
    style="${KNAPP};${RAM}">${SVG('#17251d')}<span>Skicka</span></span>
</div>

<div class="sc-item" id="ib04-ingen-kant">
  <span data-a11y-role="button" data-a11y-name="Naken" data-hit="self"
    style="${KNAPP}">${SVG('#17251d')}</span>
</div>
`;
const fixturPath = join(outAbs, 'ib-prov.html');
writeFileSync(fixturPath, FIXTUR);

/* De sex verkliga ikonknapparna och direktmatningens varden fran f68becd. */
const SEX = [
  { art: 'tangentbord',       fil: 'Butlery Skarmar v12 del 3 sok och skalbevis.dc.html' },
  { art: 'chattredigerat',    fil: 'Butlery Skarmar v12 del 4 morkt lage och etapp 0-1.dc.html' },
  { art: 'chattmeny',         fil: 'Butlery Skarmar v12 del 4 morkt lage och etapp 0-1.dc.html' },
  { art: 'receptkommentarer', fil: 'Butlery Skarmar v12 del 4 morkt lage och etapp 0-1.dc.html' },
  { art: 'bredlandskap',      fil: 'Butlery Skarmar v12 etapp 10 bred layout.dc.html' },
  { art: 'globinstallera',    fil: 'Butlery Skarmar v12 etapp 9 globala tillstand och flerval.dc.html' } ];
const DIREKT = { sidor: 4, bredd: '1.5px', farg: 'rgb(63, 81, 69)',
  angransande: 'rgb(245, 244, 237)', kvot: 7.698 };
const TOLERANS = 0.01;
const produktfiler = [...new Set(SEX.map(x => x.fil))];

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9700 + (process.pid % 120);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  /* Samma pixeltathet som den skarpa matningen. Utan den snappar Chrome en
   * 1.5 px kant till 1 px och provet skulle mata miljon, inte motorn. */
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(outAbs, 'chrome-ibprov'), 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });

let data = null, produkt = [], verktygsfel = null;
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
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  { const r = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
    if (r.exceptionDetails) throw new Error('matskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0,300));
    data = r.result.value; }
  for (const f of produktfiler) {
    await s('Page.navigate', { url: pathToFileURL(resolve(f)).href });
    for (let i = 0; i < 80; i++) { await sleep(150);
      const klar = await s('Runtime.evaluate', { expression:
        'document.readyState === "complete" && !!document.querySelector(".sc-item[id]")',
        returnByValue: true });
      if (klar.result.value) break; }
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    const r = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
    if (r.exceptionDetails) throw new Error('matskriptet kastade i produktfilen: ' +
      JSON.stringify(r.exceptionDetails).slice(0,300));
    produkt.push(...r.result.value);
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 6;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('GRANSPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2); }

const k = a => data.find(x => x.art === a);
const ramar = c => (c ? c.delar.filter(d => d.typ === 'ram') : []);

/* IB-01 · textknapp med relevant kant ger en gransdel */
{ const c = k('ib01-textknapp'); const r = ramar(c);
  prov('IB-01', 'textknapp med malad kant ger en boundary-part med matt kant',
    r.length === 1 && r[0].grans && r[0].grans.sidor === 4 &&
    r[0].grans.bredd === '1.5px' && r[0].grans.kvot > 0,
    r.length + ' ramdelar · ' + JSON.stringify(r[0] && r[0].grans)); }

/* IB-02 · ikonknapp med SAMMA kant ger ocksa en gransdel */
{ const c = k('ib02-ikonknapp'); const r = ramar(c);
  const t = ramar(k('ib01-textknapp'));
  prov('IB-02', 'ikonknapp med samma kant ger samma boundary-part — kanten beror inte pa text',
    r.length === 1 && r[0].grans && r[0].grans.sidor === 4 &&
    t.length === 1 && r[0].grans.kvot === t[0].grans.kvot &&
    r[0].grans.farg === t[0].grans.farg,
    r.length + ' ramdelar · ikon ' + JSON.stringify(r[0] && r[0].grans) +
    ' · text ' + JSON.stringify(t[0] && t[0].grans)); }

/* IB-03 · text OCH ikon ger inte tva delar for samma fysiska kant */
{ const c = k('ib03-text-och-ikon'); const r = ramar(c);
  prov('IB-03', 'text plus ikon ger exakt en boundary-part for samma fysiska kant',
    r.length === 1, r.length + ' ramdelar · ' +
    (c ? c.delar.map(d => d.typ).join(', ') : 'kontrollen saknas')); }

/* IB-04 · ingen malad kant ger ingen gransdel */
{ const c = k('ib04-ingen-kant'); const r = ramar(c);
  prov('IB-04', 'ingen malad kant ger ingen boundary-part',
    r.length === 0, r.length + ' ramdelar · ' +
    (c ? c.delar.map(d => d.typ).join(', ') : 'kontrollen saknas')); }

/* IB-05 · de sex verkliga ikonknapparna finns i den ordinarie dellistan */
{ const rader = SEX.map(x => { const c = produkt.find(p => p.art === x.art && !p.harEgenText &&
    p.delar.some(d => d.typ === 'ram' && d.grans && d.grans.farg === DIREKT.farg));
  const d = c ? c.delar.find(y => y.typ === 'ram' && y.grans && y.grans.farg === DIREKT.farg) : null;
  return { art: x.art, grans: d ? d.grans : null }; });
  const ok = rader.every(r => r.grans && r.grans.sidor === DIREKT.sidor &&
    r.grans.bredd === DIREKT.bredd && r.grans.farg === DIREKT.farg &&
    r.grans.angransande === DIREKT.angransande);
  prov('IB-05', 'alla sex saffransikonknappar finns nu i den ordinarie dellistan med fyra ' +
    'matta sidor, 1.5 px, #3F5145 och ratt yttre bakgrund',
    ok, rader.map(r => r.art + ':' + (r.grans ?
      r.grans.sidor + 'sid/' + r.grans.bredd + '/' + r.grans.farg + '/' + r.grans.angransande
      : 'SAKNAS')).join('  ')); }

/* IB-06 · ordinarie motor och direktmatning ger samma kvot */
{ const kvoter = SEX.map(x => { const c = produkt.find(p => p.art === x.art && !p.harEgenText &&
    p.delar.some(d => d.typ === 'ram' && d.grans && d.grans.farg === DIREKT.farg));
  const d = c ? c.delar.find(y => y.typ === 'ram' && y.grans && y.grans.farg === DIREKT.farg) : null;
  return { art: x.art, kvot: d && d.grans ? d.grans.kvot : null }; });
  const ok = kvoter.every(x => x.kvot !== null && Math.abs(x.kvot - DIREKT.kvot) <= TOLERANS);
  prov('IB-06', 'ordinarie motor och den separata direktmatningen ger samma kvot for de sex',
    ok, 'direkt ' + DIREKT.kvot + ' · motor ' +
      kvoter.map(x => x.art + ':' + x.kvot).join('  ')); }

for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(7) + r.vad);
  console.log('     ' + r.diag); }
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'gransprov.json'), JSON.stringify({
  $schema: 'butlery-gransprov/1', kontroll: 'CHK-IB-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('GRANSPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
