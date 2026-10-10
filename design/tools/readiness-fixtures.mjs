#!/usr/bin/env node
// F2-R04 · METODPROV FOR DELADE BEREDSKAPSGRINDAR.  RT-01 … RT-07
//
// Tva fel ska inte kunna upprepas:
//   A  rutbaserad vantan gav upp efter cirka 1100 ms nar requestAnimationFrame
//      stryptes i headless — en falsk timeout.
//   B  utsnittet berknades fore fardig layout och gav tomma bilder pa 168 byte.
//
// RT-01 … RT-03 och RT-05 kors mot en simulerad klocka sa att strypningen kan
// aterskapas deterministiskt. RT-04, RT-06 och RT-07 kors mot en verklig scen.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { vantaPa, bildgrind, ANIMATIONSTILLSTAND, GEOMETRI, FRYS, ATERSTALL_ANIMATION,
  TILLSTAND, granskaTillstand } from './two-state-preview.mjs';

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

/* Simulerad klocka: beredskap intraffar forst efter en angiven fordrojning. */
const simulerad = (beredskapVidMs, svarNarEjKlar = { ok: false, skal: 'inte redo an' }) => {
  let t = 0;
  return { nu: () => t, sov: ms => { t += ms; return Promise.resolve(); },
    kor: async () => t >= beredskapVidMs ? { ok: true, antal: 3 } : svarNarEjKlar }; };

/* RT-01 · strypning ger ingen falsk timeout */
{ const s = simulerad(3000);
  const r = await vantaPa(s.kor, 'x', { maxMs: 8000, intervallMs: 120, nu: s.nu, sov: s.sov });
  prov('RT-01', 'strypt animationsstart ger ingen falsk timeout',
    r.ok && r.vantadeMs >= 3000 && r.vantadeMs < 8000,
    'beredskap efter 3000 ms simulerad tid · grinden vantade ' + r.vantadeMs + ' ms och lyckades. ' +
    'Den gamla rutraknande grinden gav upp vid cirka 1100 ms.'); }

/* RT-02 · utebliven initiering faller stangt */
{ const s = simulerad(Infinity, { ok: false, skal: 'inga animationer registrerade' });
  const r = await vantaPa(s.kor, 'x', { maxMs: 2000, intervallMs: 100, nu: s.nu, sov: s.sov });
  prov('RT-02', 'utebliven animationsinitiering faller stangt',
    !r.ok && /aldrig inom 2000 ms/.test(r.skal) && /inga animationer/.test(r.skal),
    r.skal); }

/* RT-03 · diagnostik andrar inget utfall */
{ const a = simulerad(2400), b = simulerad(2400);
  const ra = await vantaPa(a.kor, 'x', { maxMs: 8000, intervallMs: 120, nu: a.nu, sov: a.sov });
  let extra = 0;
  const medDiagnostik = async () => { extra++; return b.kor(); };
  const rb = await vantaPa(medDiagnostik, 'x', { maxMs: 8000, intervallMs: 120, nu: b.nu, sov: b.sov });
  prov('RT-03', 'diagnostik andrar inte beredskapens utfall',
    ra.ok === rb.ok && ra.vantadeMs === rb.vantadeMs && extra > 0,
    'utan diagnostik ' + ra.vantadeMs + ' ms · med diagnostik ' + rb.vantadeMs + ' ms · identiskt trots ' +
    extra + ' extra anrop'); }

/* RT-05 · tom rendering kan inte passera bildgrinden */
{ const tom = Buffer.alloc(168).toString('base64');
  const riktig = Buffer.alloc(70000).toString('base64');
  const a = bildgrind(tom), b = bildgrind(riktig);
  prov('RT-05', 'en tom rendering pa 168 byte kan inte passera bildgrinden',
    !a.ok && a.bytes === 168 && b.ok,
    '168 byte -> ' + a.skal + ' · 70000 byte -> passerar'); }

/* ── Verkliga scenprov ────────────────────────────────────────────*/
const SCEN = 'start';
const FIL = readdirSync('.').filter(f => f.endsWith('.dc.html'))
  .find(f => readFileSync(f, 'utf8').includes('id="start"'));
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9801;
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-rt'), 'about:blank'], { stdio: 'ignore' });
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
  const kor = async (e, l = true) => { const r = await s('Runtime.evaluate',
    { expression: e, returnByValue: true, awaitPromise: l });
    if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails).slice(0, 300));
    return r.result.value; };
  await s('Page.navigate', { url: pathToFileURL(resolve(FIL)).href });

  /* RT-04 · utsnittet fangas inte fore stabil layout */
  const g = await vantaPa(e => kor(e, false), GEOMETRI(SCEN, 0), { maxMs: 8000 });
  prov('RT-04', 'utsnittet fangas forst nar geometrin ar positivt upplost och icke-noll',
    g.ok && g.ruta.width > 0 && g.ruta.height > 0,
    'geometri ' + g.ruta.width + 'x' + g.ruta.height + ' efter ' + g.vantadeMs + ' ms vantan');

  /* RT-06 · samma tillstand ger identisk geometri */
  const a1 = await vantaPa(e => kor(e, false), GEOMETRI(SCEN, 0), { maxMs: 4000 });
  const a2 = await vantaPa(e => kor(e, false), GEOMETRI(SCEN, 0), { maxMs: 4000 });
  prov('RT-06', 'samma deterministiska tillstand ger identisk utsnittsgeometri',
    JSON.stringify(a1.ruta) === JSON.stringify(a2.ruta),
    JSON.stringify(a1.ruta));

  /* RT-07 · bada tillstanden behaller exakt avsedd fas efter delad grind */
  const anim = await vantaPa(e => kor(e), ANIMATIONSTILLSTAND(SCEN), { maxMs: 8000 });
  const ALLA = [3, 5, 6, 8, 9, 11, 12, 13];
  const V = { [TILLSTAND.TACKT]: { synliga: [3, 11, 12, 13], dolda: [5, 6, 8, 9], tid: 1375 },
    [TILLSTAND.AVTACKT]: { synliga: [3, 5, 6, 8, 9], dolda: [11, 12, 13], tid: 3475 } };
  const utfall = [];
  for (const namn of Object.values(TILLSTAND)) {
    await kor(ATERSTALL_ANIMATION(SCEN), false); await sleep(120);
    await vantaPa(e => kor(e), ANIMATIONSTILLSTAND(SCEN), { maxMs: 4000 });
    const fr = JSON.parse(await kor(FRYS(SCEN, V[namn].tid, ALLA)));
    utfall.push({ namn, fr, g: granskaTillstand(fr, V[namn].synliga, V[namn].dolda) }); }
  await kor(ATERSTALL_ANIMATION(SCEN), false);
  prov('RT-07', 'bada tillstanden behaller exakt avsedd fas efter den delade grinden',
    anim.ok && utfall.every(u => u.g.ok && u.fr.faktiskTid.every(t => Math.abs(t - V[u.namn].tid) < 0.5)),
    utfall.map(u => u.namn + '@' + V[u.namn].tid + ' ms ' + (u.g.ok ? 'ok' : u.g.skal)).join(' · '));
}
finally { try { chrome.kill(); } catch {} }
try { rmSync(join(outAbs, 'chrome-rt'), { recursive: true, force: true }); } catch {}

const ANTAL = 7;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('BEREDSKAPSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'beredskapsprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
