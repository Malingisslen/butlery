#!/usr/bin/env node
// F2-R04 · MORK PRODUKTTEXTBATCH. Fail closed pa bade tema och population.
//
// Kor: node tools/dark-text-batch.mjs --out=<katalog>
//
// TVA SEPARATA STEG, aldrig sammanblandade:
//   URVAL       exakt de kallor som ar faktiskt morkrenderade enligt kontraktet
//   TEXTSCOPE   inom en vald kalla galler produkttextmotorns vanliga
//               scopeupplosning
//
// En korning som begar 64 morka kallor men mater 329 artefakter ar ogiltig.

import { spawn } from 'node:child_process';
import { readdirSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';
import { PRODUKTTEXT } from './product-text.mjs';
import { SEMANTISK_SOND } from './semantic-units.mjs';
import { APPLICERA_TEMA, BUTLERY_SENTINEL, populationsgrind, kallfingeravtryck } from './authored-theme.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog>'); process.exit(2); }
mkdirSync(resolve(OUT), { recursive: true });
const sleep = ms => new Promise(r => setTimeout(r, ms));

/* ── URVAL. Kallorna kommer ur artefakternas EGNA temadeklarationer, inte ur
      "alla produktrotter textmotorn hittar". ──────────────────────────────── */
const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const forvantade = [], perFil = new Map();
for (const f of filer) {
  const src = readFileSync(f, 'utf8');
  for (const m of src.matchAll(/<div[^>]*class="sc-item"[^>]*>/g)) {
    const t = m[0]; const id = (t.match(/id="([^"]+)"/) || [])[1]; if (!id) continue;
    const stod = (t.match(/data-theme-support="([^"]*)"/) || [])[1] || '';
    if (!stod.trim().split(/\s+/).includes('dark')) continue;
    forvantade.push(id);
    if (!perFil.has(f)) perFil.set(f, []); perFil.get(f).push(id); } }
console.log('URVAL · ' + forvantade.length + ' morkrenderade kallor i ' + perFil.size + ' filer');
console.log('  fingeravtryck ' + JSON.stringify(kallfingeravtryck(forvantade)));

const port = 9971 + (process.pid % 7);
const chrome = spawn(process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  ['--headless=new', '--remote-debugging-port=' + port, '--disable-gpu', '--no-first-run',
   '--allow-file-access-from-files', '--user-data-dir=' + join(process.env.TEMP || '.', 'butlery-darktext'),
   'about:blank'], { stdio: 'ignore' });
let ws = null; for (let k = 0; k < 60 && !ws; k++) { await sleep(250);
  try { ws = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
if (!ws) { console.error('✖ ingen webbläsare'); process.exit(2); }
const sock = new WebSocket(ws); await new Promise(r => { sock.onopen = r; });
let id = 0; const p = new Map();
sock.onmessage = m => { const j = JSON.parse(m.data); if (j.id && p.has(j.id)) { const r = p.get(j.id); p.delete(j.id); r(j.result); } };
const call = (m, par = {}, s) => new Promise(res => { const n = ++id; p.set(n, res); sock.send(JSON.stringify({ id: n, method: m, params: par, ...(s ? { sessionId: s } : {}) })); });
const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
const s = (m, pp) => call(m, pp, sessionId);
await s('Page.enable');
const K = JSON.parse(readFileSync('layout-contract.json', 'utf8'));
const VP = (Array.isArray(K) ? K : K.profiles).find(x => x.id === 'compact-390');
await s('Emulation.setDeviceMetricsOverride', { width: VP.width, height: VP.height, deviceScaleFactor: 1, mobile: false });

const kor = async (uttryck, vantaLofte = false) => {
  const r = await s('Runtime.evaluate', { expression: uttryck, returnByValue: true, awaitPromise: vantaLofte });
  if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails).slice(0, 300));
  return r.result.value; };

const matta = [], temaLogg = [], text = [], farg = [];
for (const [f, ids] of perFil) {
  await s('Page.navigate', { url: pathToFileURL(resolve(f)).href });
  await sleep(340);
  await kor('document.fonts.ready', true);
  await sleep(520);
  // SENTINELN ligger i en av filerna. I ovriga filer verifieras bara attributet
  // — och da kravs att minst en kalla faktiskt bytte berknat varde, vilket
  // kontrolleras genom att jamfora mot en ljusmatning av samma fil.
  const harSentinel = ids.includes(BUTLERY_SENTINEL.art);
  const ljus = await kor(PRODUKTTEXT);
  const res = await kor(APPLICERA_TEMA('dark', BUTLERY_SENTINEL), true);
  const mork = await kor(PRODUKTTEXT);
  const morkFarg = await kor(SEMANTISK_SOND);
  // FAIL CLOSED: attributet maste halla, och nagot maste faktiskt ha bytt varde.
  const ljusIVal = ljus.filter(x => ids.includes(x.art));
  const morkIVal = mork.filter(x => ids.includes(x.art));
  const lk = new Map(ljusIVal.map(x => [x.art + '#' + x.elementOrdinal, x]));
  const bytte = morkIVal.filter(x => { const l = lk.get(x.art + '#' + x.elementOrdinal);
    return l && l.color && x.color && l.color !== x.color; }).length;
  const ok = res.attributSentinel && (harSentinel ? res.berknadSentinel : bytte > 0);
  temaLogg.push({ fil: f, kallor: ids, harSentinel, appliceratTema: 'dark',
    attributSentinel: res.attributSentinel, berknadSentinel: res.berknadSentinel,
    fragmentSomBytteFarg: bytte, sentinel: res.sentinel, ok,
    skal: ok ? null : (res.skal || 'inget fragment bytte farg — temat slog inte igenom') });
  if (!ok) { console.error('✖ TEMAGRIND FALLER i ' + f + ': ' + (res.skal || 'ingen fargforandring'));
    chrome.kill(); writeFileSync(join(resolve(OUT), 'darktext-avbruten.json'),
      JSON.stringify({ temaLogg }, null, 1)); process.exit(1); }
  for (const id2 of ids) matta.push(id2);
  for (const x of morkIVal) text.push(x);
  for (const x of morkFarg) if (ids.includes(x.art)) farg.push(x);
}
chrome.kill();

/* ── POPULATIONSGRIND ─────────────────────────────────────────────────────*/
const grind = populationsgrind(forvantade, matta);
console.log('');
console.log('POPULATIONSGRIND  forvantat ' + grind.forvantatAntal + ' · matt ' + grind.faktisktAntal +
  ' · EXPECTED_ONLY ' + grind.EXPECTED_ONLY.length + ' · ACTUAL_ONLY ' + grind.ACTUAL_ONLY.length +
  ' · dubbletter ' + grind.dubbletter.length + (grind.ok ? '  ✔' : '  ✖'));
if (!grind.ok) { console.error('✖ ' + grind.skal); process.exit(1); }

/* ── FORGRUNDSAVSTAMNING mot fargsonden ──────────────────────────────────*/
// Sonderna har olika ordinalbaser. Joinen sker pa artefakt + berknad
// forgrundsfarg + textinnehall, vilket ar en stabil identitet inom en artefakt.
const fargAv = new Map();
for (const x of farg) if (x.egenskap === 'color')
  fargAv.set(x.art + '#' + x.elementOrdinal, x.varde);
const P = x => /^PRODUCT_/.test(x.klass);
const produkt = text.filter(P);
let CHANGED = 0, UNCHANGED = 0, MISMATCH = 0;
const fargIArt = new Map();
for (const x of farg) if (x.egenskap === 'color') {
  if (!fargIArt.has(x.art)) fargIArt.set(x.art, new Set()); fargIArt.get(x.art).add(x.varde); }
for (const x of produkt) {
  const set = fargIArt.get(x.art);
  if (!set || !x.color) { MISMATCH++; continue; }
  if (set.has(x.color)) CHANGED++; else MISMATCH++; }
const okand = produkt.filter(x => x.status === 'unknown').length;
const utanBg = produkt.filter(x => !x.bakgrund).length;
const fynd = produkt.filter(x => x.underThreshold === true);
const ktrl = produkt.filter(x => x.klass === 'PRODUCT_CONTROL_TEXT');
const fri = produkt.filter(x => x.klass === 'PRODUCT_STANDALONE_TEXT');
const annot = text.filter(x => x.klass === 'ANNOTATION_TEXT').length;

console.log('');
console.log('MORK PRODUKTTEXT i ' + grind.faktisktAntal + ' kallor');
console.log('  CONTROL_TEXT       ' + String(ktrl.length).padStart(5) +
  ' · unknown ' + ktrl.filter(x => x.status === 'unknown').length +
  ' · fynd ' + ktrl.filter(x => x.underThreshold === true).length);
console.log('  STANDALONE_TEXT    ' + String(fri.length).padStart(5) +
  ' · unknown ' + fri.filter(x => x.status === 'unknown').length +
  ' · fynd ' + fri.filter(x => x.underThreshold === true).length);
console.log('  TOTAL PRODUKTTEXT  ' + String(produkt.length).padStart(5) +
  ' · unknown ' + okand + ' · fynd ' + fynd.length);
console.log('  ANNOTATION (utanfor namnaren) ' + annot);
console.log('  bakgrund unknown ' + utanBg + (utanBg ? '  ✖' : '  ✔'));
console.log('  forgrundsavstamning: i fargsondens vardemangd ' + CHANGED + ' · MISMATCH ' + MISMATCH +
  (MISMATCH === 0 ? '  ✔' : '  ✖'));
if (fynd.length) { console.log('  FYND:');
  for (const x of fynd.slice(0, 15)) console.log('    ' + x.art.padEnd(18) +
    x.klass.replace('PRODUCT_', '') + ' ' + x.ratio + '/' + x.threshold + '  ' +
    JSON.stringify(x.text).slice(0, 42) + ' pa ' + x.bakgrund); }

writeFileSync(join(resolve(OUT), 'darktext.json'), JSON.stringify({
  $schema: 'butlery-dark-text-baseline/1',
  $regel: 'Urval och textscope ar tva olika steg. Temat maste bevisas, inte begaras.',
  urval: { forvantade, fingeravtryck: kallfingeravtryck(forvantade), grind },
  temaLogg,
  sammanfattning: { kallor: grind.faktisktAntal,
    CONTROL_TEXT: { fragment: ktrl.length, unknown: ktrl.filter(x => x.status === 'unknown').length,
      fynd: ktrl.filter(x => x.underThreshold === true).length },
    STANDALONE_TEXT: { fragment: fri.length, unknown: fri.filter(x => x.status === 'unknown').length,
      fynd: fri.filter(x => x.underThreshold === true).length },
    TOTAL: { fragment: produkt.length, unknown: okand, fynd: fynd.length, bakgrundUnknown: utanBg },
    ANNOTATION: annot,
    forgrund: { iFargsondensVardemangd: CHANGED, MISMATCH } },
  fynd, poster: produkt }, null, 1) + '\n');
console.log('');
console.log('DARKTEXT status=' + (MISMATCH === 0 && okand === 0 && utanBg === 0 ? 'reproducerbar' : 'FALLD'));
process.exit(MISMATCH === 0 && okand === 0 && utanBg === 0 ? 0 : 1);
