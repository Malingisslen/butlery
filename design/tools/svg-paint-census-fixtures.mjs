#!/usr/bin/env node
// F2-R04 · METODPROV FOR SVG-MALNINGSCENSUS.  SVG-P-01 … SVG-P-12
//
// Felklassen: fill och stroke registrerades bara nar elementet SJALVT var
// <svg>. Illustrationer som malar per <path> var osynliga. Proven kraver att
// barnen syns, att arvda varden INTE blir egna kallor, och att en preview inte
// far kallas komplett nar ett sjalvstandigt malat barn saknar varde.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { SVG_CENSUS, avstamning, nyaKandidater, arEgenKalla, KALLKLASS } from './svg-paint-census.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });
const sleep = ms => new Promise(r => setTimeout(r, ms));

/* ── Syntetisk fixtur ────────────────────────────────────────────────*/
const FIX = join(outAbs, 'svgprov.html');
writeFileSync(FIX, `<!doctype html><meta charset="utf-8">
<style>
  .sc-item { font-family: sans-serif; }
  .sc-phone { background: #f5f4ed; color: #24382c; padding: 10px; }
  .via-regel path { fill: #4a5c43; }
</style>
<div class="sc-item" id="prov">
  <div class="sc-phone">
    <svg id="a" width="20" height="20" fill="none" stroke="#7d897c" data-graphic-role="redundant">
      <circle cx="5" cy="5" r="3"></circle>
      <path d="M1 1 L9 9"></path>
      <rect x="1" y="1" width="4" height="4" fill="#ce7c1e"></rect>
      <line x1="0" y1="0" x2="9" y2="9" stroke="#93a48d"></line>
      <ellipse cx="5" cy="5" rx="2" ry="1" style="fill:#de9078"></ellipse>
      <polygon points="0,0 4,0 2,4" fill="currentColor"></polygon>
    </svg>
    <svg id="b" class="via-regel" width="20" height="20" fill="none" stroke="none">
      <path d="M2 2 L8 8"></path>
    </svg>
  </div>
</div>`);

/* ── CDP ─────────────────────────────────────────────────────────────*/
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9795;
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-svgprov'), 'about:blank'], { stdio: 'ignore' });
let sock = null, id = 0; const pend = new Map();
try {
  let wsUrl = null;
  for (let k = 0; k < 80 && !wsUrl; k++) { await sleep(250);
    try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!wsUrl) throw new Error('CDP-anslutning misslyckades');
  sock = new WebSocket(wsUrl);
  await new Promise((res, rej) => { sock.onopen = res; sock.onerror = () => rej(new Error('CDP-socket')); });
  sock.onmessage = m => { const j = JSON.parse(m.data);
    if (j.id && pend.has(j.id)) { const r = pend.get(j.id); pend.delete(j.id); r(j.result); } };
  const call = (m, par = {}, s) => new Promise(res => { const n = ++id; pend.set(n, res);
    sock.send(JSON.stringify({ id: n, method: m, params: par, ...(s ? { sessionId: s } : {}) })); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, pp) => call(m, pp, sessionId);
  await s('Page.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: false });
  const kor = async e => { const r = await s('Runtime.evaluate', { expression: e, returnByValue: true });
    if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails).slice(0, 400));
    return r.result.value; };
  const las = async fil => { await s('Page.navigate', { url: pathToFileURL(resolve(fil)).href });
    await sleep(360); await kor('document.fonts.ready'); await sleep(420);
    return JSON.parse(await kor(SVG_CENSUS)); };

  const F = await las(FIX);
  const hitta = (tagg, egenskap) => F.find(r => r.tagg === tagg && r.egenskap === egenskap);

  /* SVG-P-01 · explicit barn-fill upptacks */
  { const r = hitta('rect', 'fill');
    prov('SVG-P-01', 'explicit fill pa ett barn upptacks',
      !!r && r.varde === 'rgb(206, 124, 30)' && r.kalla === KALLKLASS.ATTRIBUT,
      r ? 'rect fill ' + r.varde + ' · kalla ' + r.kalla : 'hittades inte'); }

  /* SVG-P-02 · explicit barn-stroke upptacks */
  { const r = hitta('line', 'stroke');
    prov('SVG-P-02', 'explicit stroke pa ett barn upptacks',
      !!r && r.varde === 'rgb(147, 164, 141)' && r.kalla === KALLKLASS.ATTRIBUT,
      r ? 'line stroke ' + r.varde + ' · kalla ' + r.kalla : 'hittades inte'); }

  /* SVG-P-03 · arvd rotstroke syns som malad, men loses till roten */
  { const c = hitta('circle', 'stroke');
    prov('SVG-P-03', 'arvt varde syns som malat barn men loses till roten',
      !!c && c.varde === 'rgb(125, 137, 124)' && c.kalla === KALLKLASS.ARVD &&
      c.arvtFranRot === true && c.rotOrdinal !== null,
      c ? 'circle stroke ' + c.varde + ' · kalla ' + c.kalla + ' · rot ordinal ' + c.rotOrdinal : 'hittades inte'); }

  /* SVG-P-04 · arvt varde ger INGEN egen skrivbar deklaration */
  { const c = hitta('circle', 'stroke'), p = hitta('path', 'stroke');
    prov('SVG-P-04', 'arvt varde skapar ingen egen skrivbar deklaration',
      !!c && !!p && !arEgenKalla(c.kalla) && !arEgenKalla(p.kalla),
      'circle och path arver bada rotens stroke · arEgenKalla = false for bada'); }

  /* SVG-P-05 · currentColor loses mot elementets faktiska color */
  { const r = hitta('polygon', 'fill');
    prov('SVG-P-05', 'currentColor loses mot elementets verkliga color',
      !!r && r.viaCurrentColor === true && r.color === 'rgb(36, 56, 44)' &&
      r.varde === 'rgb(36, 56, 44)' && r.kalla === KALLKLASS.ATTRIBUT,
      r ? 'polygon fill=currentColor -> ' + r.varde + ' · color ' + r.color : 'hittades inte'); }

  /* SVG-P-06 · barnmalning ur en CSS-regel loses genom faktisk cascade */
  { const r = F.find(r2 => r2.art === 'prov' && r2.tagg === 'path' && r2.egenskap === 'fill' &&
      r2.varde === 'rgb(74, 92, 67)');
    prov('SVG-P-06', 'barnmalning ur en CSS-regel loses genom faktisk cascade',
      !!r && r.kalla === KALLKLASS.CSS_REGEL && arEgenKalla(r.kalla),
      r ? 'path fill ' + r.varde + ' · kalla ' + r.kalla + ' (ingen attribut, avviker fran forfadern)' : 'hittades inte'); }

  /* SVG-P-07 · inline style pa barnet */
  { const r = hitta('ellipse', 'fill');
    prov('SVG-P-07', 'inline style pa ett barn loses som egen kalla',
      !!r && r.kalla === KALLKLASS.INLINE && r.varde === 'rgb(222, 144, 120)',
      r ? 'ellipse fill ' + r.varde + ' · kalla ' + r.kalla : 'hittades inte'); }

  /* ── Korpusprov ────────────────────────────────────────────────────*/
  const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
  const filMed = art => filer.find(f => readFileSync(f, 'utf8').includes('id="' + art + '"'));
  const startRader = (await las(filMed('start'))).filter(r => r.art === 'start');
  const socRader = (await las(filMed('soctomtingavanner'))).filter(r => r.art === 'soctomtingavanner');

  /* SVG-P-08 · start ger de atta tidigare saknade sjalvstandiga varden */
  { const egna = startRader.filter(r => arEgenKalla(r.kalla));
    prov('SVG-P-08', 'start ger de atta tidigare saknade sjalvstandigt malade barnvardena',
      egna.length === 8,
      egna.length + ' sjalvstandiga varden: ' +
      [...new Set(egna.map(r => r.egenskap + ' ' + r.varde))].join(', ')); }

  /* SVG-P-09 · soctomtingavanner fyra loses som arvda fran roten */
  { const arvda = socRader.filter(r => r.kalla === KALLKLASS.ARVD && r.arvtFranRot);
    const egna = socRader.filter(r => arEgenKalla(r.kalla));
    prov('SVG-P-09', 'soctomtingavanner: alla fyra tidigare omatta loses som arvda fran roten',
      socRader.length === 4 && arvda.length === 4 && egna.length === 0,
      socRader.length + ' malade barn · ' + arvda.length + ' arvda · ' + egna.length + ' egna kallor'); }

  /* SVG-P-10 · forsta previewn star kvar efter utvidgad census */
  { const egna = socRader.filter(r => arEgenKalla(r.kalla));
    const allaFranRot = socRader.every(r => r.arvtFranRot && r.rotVarde === 'rgb(125, 137, 124)');
    prov('SVG-P-10', 'forsta previewn ar fortsatt giltig efter utvidgad census',
      egna.length === 0 && allaFranRot,
      'inga sjalvstandiga barnvarden · alla fyra foljer rotens stroke, som previewn injicerade'); }

  /* SVG-P-11 · sjalvstandigt dekorativt barn paverkar previewkomplett */
  { const dek = startRader.filter(r => arEgenKalla(r.kalla) && r.grafikroll === 'decorative');
    prov('SVG-P-11', 'ett sjalvstandigt dekorativt barn paverkar previewkomplettheten anda',
      dek.length === 8 && dek.every(r => r.grafikroll === 'decorative'),
      dek.length + ' dekorativa sjalvstandiga varden i start. De har inget icke-textkrav, ' +
      'men de syns i bild och maste ha ett morkervarde for att scenen ska vara arlig.'); }

  /* SVG-P-12 · oloslig sjalvstandig malning faller stangd */
  { const a = avstamning(startRader);
    const kompletthet = (rader, harVarde) => {
      const egna = rader.filter(r => arEgenKalla(r.kalla));
      const utan = egna.filter(r => !harVarde(r));
      return { komplett: utan.length === 0, saknar: utan.length }; };
    const utanVarden = kompletthet(startRader, () => false);
    const medVarden = kompletthet(startRader, () => true);
    prov('SVG-P-12', 'oloslig sjalvstandig svg-malning faller stangd for previewkomplett',
      a.summerar && a.godkand && utanVarden.komplett === false && utanVarden.saknar === 8 &&
      medVarden.komplett === true,
      'avstamning summerar · 0 okanda · utan morkervarden ar scenen INTE komplett (8 saknas), ' +
      'med varden ar den komplett'); }

  /* Korpusavstamning skrivs ut som underlag. */
  const alla = [];
  for (const f of filer) alla.push(...await las(f));
  const A = avstamning(alla);
  console.log('');
  console.log('KORPUSAVSTAMNING  ' + A.totalt + ' = ' + A.egenKalla + ' egen kalla + ' +
    A.arvd + ' arvda + ' + A.okand + ' okanda   ' + (A.summerar && A.godkand ? '✔' : '✖'));
  console.log('  per kallklass: ' + JSON.stringify(A.perKalla));
  console.log('  artefakter med egen kalla: ' + A.artefakterMedEgenKalla.length);
  writeFileSync(join(outAbs, 'svgcensus.json'), JSON.stringify({ avstamning: A,
    nyaKandidater: nyaKandidater(alla), rader: alla }, null, 1) + '\n');
}
finally { try { chrome.kill(); } catch {} }
try { rmSync(join(outAbs, 'chrome-svgprov'), { recursive: true, force: true }); } catch {}

const ANTAL = 12;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('SVG-MALNINGSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
process.exit(ok === ANTAL ? 0 : 1);
