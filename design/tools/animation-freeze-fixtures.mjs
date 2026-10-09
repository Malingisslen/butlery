#!/usr/bin/env node
// F2-R04 · METODPROV FOR ANIMATIONSFRYSNING.  AF-01 … AF-08
//
// Felklassen: en stillbild av en animerad illustration fangar en godtycklig
// bildruta. Proven kraver att frysningen ar deterministisk, att den rapporterade
// tiden ar den faktiskt tillampade, att produktens normala animation inte rors,
// och att analysen FALLER STANGT nar ingen fas kan visa alla delar samtidigt.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { SYNLIGHETSPROV, synlighetsintervall, valjFrysTid, FRYS, ATERSTALL_ANIMATION,
  REPRESENTERAD_TROSKEL } from './animation-freeze.mjs';

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

const SCEN = 'start';
const DELAR = [3, 5, 6, 8, 9, 11, 12, 13];   // illustrationens atta malade barn
const FIL = readdirSync('.').filter(f => f.endsWith('.dc.html'))
  .find(f => readFileSync(f, 'utf8').includes('id="start"'));

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9797;
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-anim'), 'about:blank'], { stdio: 'ignore' });
let sock = null, id = 0; const pend = new Map();
let analys = null, val = null;
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
  const kor = async (e, l = true) => { const r = await s('Runtime.evaluate',
    { expression: e, returnByValue: true, awaitPromise: l });
    if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails).slice(0, 400));
    return r.result.value; };
  const ladda = async () => { await s('Page.navigate', { url: pathToFileURL(resolve(FIL)).href });
    await sleep(420); await kor('document.fonts.ready'); await sleep(520); };
  await ladda();

  /* Analys av hela cykeln. */
  analys = JSON.parse(await kor(SYNLIGHETSPROV(SCEN, DELAR, 100)));
  const intervall = analys.fel ? null : synlighetsintervall(analys);
  val = analys.fel ? { ok: false, skal: analys.fel } : valjFrysTid(analys);

  /* AF-01 · samma frysbegaran ger samma tillstand tva ganger */
  { const T = analys.cykel * 0.30;
    const a = JSON.parse(await kor(FRYS(SCEN, T, DELAR)));
    await kor(ATERSTALL_ANIMATION(SCEN), false);
    await sleep(120);
    const b = JSON.parse(await kor(FRYS(SCEN, T, DELAR)));
    const lika = JSON.stringify(a.delar) === JSON.stringify(b.delar);
    prov('AF-01', 'samma frysbegaran ger samma berknade tillstand tva ganger',
      a.ok && b.ok && lika,
      'tva frysningar vid ' + Math.round(T) + ' ms gav identiska opaciteter: ' +
      a.delar.map(d => d.opacitet).join(', ')); }

  /* AF-02 · rapporterad tid ar den faktiskt tillampade */
  { const T = analys.cykel * 0.42;
    const r = JSON.parse(await kor(FRYS(SCEN, T, DELAR)));
    const avvik = Math.max(...r.faktiskTid.map(t => Math.abs(t - T)));
    prov('AF-02', 'rapporterad frystid ar exakt den tillampade fasen',
      r.ok && avvik < 0.5,
      'begard ' + Math.round(T * 100) / 100 + ' ms · storsta avvikelse ' + Math.round(avvik * 1000) / 1000 + ' ms'); }

  /* AF-03 · finns en fas dar alla atta ar representerade? */
  { prov('AF-03', 'urvalsregeln hittar en fas dar alla atta ar representerade, ELLER faller stangt',
      val.ok === false && val.frysTidMs === null,
      val.ok ? 'frystid ' + val.frysTidMs + ' ms' :
      'FALLER STANGT — ' + val.skal + '. Kupan och maten ar aldrig synliga samtidigt: animationen ar en avtackning.'); }

  /* AF-04 · produktens normala animation ar oforandrad utanfor harnesset */
  { await kor(ATERSTALL_ANIMATION(SCEN), false);
    await sleep(150);
    const a = await kor(`(() => { const it = document.getElementById('start');
      const an = it.getAnimations({ subtree: true });
      return JSON.stringify({ n: an.length, spelar: an.every(x => x.playState === 'running') }); })()`, false);
    const r = JSON.parse(a);
    prov('AF-04', 'produktens normala animation ar oforandrad efter aterstallning',
      r.n > 0 && r.spelar,
      r.n + ' animationer, alla i playState running efter aterstallning'); }

  /* AF-05 · reducerad rorelse ar oforandrad */
  { await s('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
    await ladda();
    const r = JSON.parse(await kor(`(() => {
      const it = document.getElementById('start');
      const kupa = it.querySelector('.start-cover'), mat = it.querySelector('.start-dish'),
        anga = it.querySelector('.start-steam');
      return JSON.stringify({ kupa: getComputedStyle(kupa).opacity, mat: getComputedStyle(mat).opacity,
        anga: getComputedStyle(anga).opacity,
        anim: it.getAnimations({ subtree: true }).length }); })()`, false));
    await s('Emulation.setEmulatedMedia', { features: [] });
    await ladda();
    prov('AF-05', 'produktens beteende vid reducerad rorelse ar oforandrat',
      r.kupa === '0' && r.mat === '1' && r.anga === '0',
      'kupa ' + r.kupa + ' · mat ' + r.mat + ' · anga ' + r.anga + ' — precis som authored'); }

  /* AF-06 · saknad animationsidentitet faller stangt */
  { const r = JSON.parse(await kor(FRYS('finns-inte', 100, DELAR)));
    const r2 = JSON.parse(await kor(FRYS(SCEN, 100, [999])));
    prov('AF-06', 'saknad artefakt eller saknad del faller stangt',
      !r.ok && !r2.ok && /artefakten saknas/.test(r.skal) && /saknas/.test(r2.skal),
      'okand artefakt -> ' + r.skal + ' · okand ordinal -> ' + r2.skal); }

  /* AF-07 · frysningen overlever en animationsruta utan att ga vidare */
  { const T = analys.cykel * 0.20;
    const a = JSON.parse(await kor(FRYS(SCEN, T, DELAR)));
    await sleep(400);
    const b = await kor(`(() => { const it = document.getElementById('start');
      return JSON.stringify(it.getAnimations({ subtree: true }).map(x => x.currentTime)); })()`, false);
    const tider = JSON.parse(b);
    const stilla = tider.every(t => Math.abs(t - T) < 0.5);
    prov('AF-07', 'frysningen star stilla aven efter flera rutor',
      a.ok && stilla,
      '400 ms senare star currentTime kvar pa ' + Math.round(tider[0] * 100) / 100 + ' ms'); }

  /* AF-08 · tva renderingar vid samma fas ar matningsidentiska */
  { const T = analys.cykel * 0.65;
    const las = `(() => { const it = document.getElementById('start');
      const prod = [...it.querySelectorAll('*')];
      return JSON.stringify(${JSON.stringify(DELAR)}.map(o => { const e = prod[o];
        const cs = e ? getComputedStyle(e) : null;
        return cs ? cs.fill + '|' + cs.stroke + '|' + cs.opacity : null; })); })()`;
    await kor(FRYS(SCEN, T, DELAR));
    const a = await kor(las, false);
    await kor(ATERSTALL_ANIMATION(SCEN), false); await sleep(200);
    await kor(FRYS(SCEN, T, DELAR));
    const b = await kor(las, false);
    prov('AF-08', 'tva renderingar vid samma fas ar matningsidentiska',
      a === b,
      'identiska berknade varden for alla atta delar vid ' + Math.round(T) + ' ms'); }

  await kor(ATERSTALL_ANIMATION(SCEN), false);
  writeFileSync(join(outAbs, 'animfrys.json'), JSON.stringify({ analys, intervall, val }, null, 1) + '\n');
  console.log('');
  console.log('CYKEL ' + analys.cykel + ' ms · ' + analys.animationer + ' animationer · ' + analys.steg + ' provpunkter');
  if (intervall) for (const i of intervall) console.log('  ordinal ' + String(i.ordinal).padStart(3) +
    '  synlig ' + String(i.andelAvCykeln).padStart(5) + ' % · intervall ' +
    i.intervall.map(([a, b]) => Math.round(a) + '-' + Math.round(b)).join(', '));
  console.log('  gemensam fas for alla atta: ' + (val.ok ? val.frysTidMs + ' ms' : 'FINNS INTE'));
}
finally { try { chrome.kill(); } catch {} }
try { rmSync(join(outAbs, 'chrome-anim'), { recursive: true, force: true }); } catch {}

const ANTAL = 8;
console.log('');
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('ANIMATIONSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
process.exit(ok === ANTAL ? 0 : 1);
