#!/usr/bin/env node
// F2-R04 · METODPROV FOR TVATILLSTANDS-PREVIEW.  TS-01 … TS-07
//
// Felklassen: en ensam bildruta av ett animerat objekt beskrevs som preview
// trots att delar saknades. Proven kraver att paret ar jamforelseenheten, att
// bada tillstanden ar deterministiska, och att ett ofullstandigt par vagras.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { TILLSTAND, granskaTillstand, paketera, determinismgrind,
  FRYS, ATERSTALL_ANIMATION } from './two-state-preview.mjs';

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
const BANK = [3], MAT = [8, 9], ANGA = [5, 6], KUPA = [11, 12, 13];
const ALLA = [...BANK, ...ANGA, ...MAT, ...KUPA];
const T_TACKT = 1375, T_AVTACKT = 3475;
const VANTAT = {
  [TILLSTAND.TACKT]: { synliga: [...BANK, ...KUPA], dolda: [...MAT, ...ANGA], tid: T_TACKT },
  [TILLSTAND.AVTACKT]: { synliga: [...BANK, ...MAT, ...ANGA], dolda: KUPA, tid: T_AVTACKT } };
const FIL = readdirSync('.').filter(f => f.endsWith('.dc.html'))
  .find(f => readFileSync(f, 'utf8').includes('id="start"'));

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9799;
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-ts'), 'about:blank'], { stdio: 'ignore' });
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
    if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails).slice(0, 400));
    return r.result.value; };
  await s('Page.navigate', { url: pathToFileURL(resolve(FIL)).href });
  await sleep(420); await kor('document.fonts.ready'); await sleep(520);
  const frys = async t => JSON.parse(await kor(FRYS(SCEN, t, ALLA)));

  /* TS-01 · TACKT visar exakt sina delar */
  const a1 = await frys(T_TACKT);
  const g1 = granskaTillstand(a1, VANTAT[TILLSTAND.TACKT].synliga, VANTAT[TILLSTAND.TACKT].dolda);
  prov('TS-01', 'STATE_COVERED vid 1375 ms visar exakt kupa, handtag, knopp och banklinje',
    g1.ok, 'synliga ' + VANTAT[TILLSTAND.TACKT].synliga.join(',') + ' · dolda ' +
    VANTAT[TILLSTAND.TACKT].dolda.join(',') + ' · ' + (g1.ok ? 'exakt som vantat' : g1.skal));

  /* TS-02 · AVTACKT visar exakt sina delar */
  await kor(ATERSTALL_ANIMATION(SCEN), false); await sleep(120);
  const a2 = await frys(T_AVTACKT);
  const g2 = granskaTillstand(a2, VANTAT[TILLSTAND.AVTACKT].synliga, VANTAT[TILLSTAND.AVTACKT].dolda);
  prov('TS-02', 'STATE_REVEALED vid 3475 ms visar exakt mat, anga och banklinje',
    g2.ok, 'synliga ' + VANTAT[TILLSTAND.AVTACKT].synliga.join(',') + ' · dolda ' +
    VANTAT[TILLSTAND.AVTACKT].dolda.join(',') + ' · ' + (g2.ok ? 'exakt som vantat' : g2.skal));

  /* TS-03 · unionen tacker alla atta */
  { const union = new Set([...VANTAT[TILLSTAND.TACKT].synliga, ...VANTAT[TILLSTAND.AVTACKT].synliga]);
    prov('TS-03', 'de tva tillstanden tacker tillsammans alla atta beslutsdelar',
      ALLA.every(o => union.has(o)) && union.size === ALLA.length,
      union.size + ' av ' + ALLA.length + ' delar representerade i unionen'); }

  /* TS-04 · ett ofullstandigt par vagras */
  { const p = paketera({ id: 1, namn: 'prov' }, { [TILLSTAND.TACKT]: { granskning: g1, bild: 'a.png' } });
    prov('TS-04', 'ett ofullstandigt par vagras — en ensam bild ar aldrig en illustrationspreview',
      !p.ok && /ofullstandigt par/.test(p.skal), p.skal); }

  /* TS-05 · ett fullstandigt par godkanns och paret ar enheten */
  { const p = paketera({ id: 1, namn: 'prov' },
      { [TILLSTAND.TACKT]: { granskning: g1, bild: 'a.png' },
        [TILLSTAND.AVTACKT]: { granskning: g2, bild: 'b.png' } });
    prov('TS-05', 'ett fullstandigt par godkanns och redovisas som ETT alternativ',
      p.ok && p.par.length === 2 && p.par[0].frystTid === T_TACKT && p.par[1].frystTid === T_AVTACKT,
      'par: ' + p.par.map(x => x.tillstand + '@' + x.frystTid + 'ms').join(' + ')); }

  /* TS-06 · fel forvantan faller stangt */
  { const g = granskaTillstand(a1, ALLA, []);
    prov('TS-06', 'en forvantan om att alla atta syns samtidigt faller stangt',
      !g.ok && g.saknade.length === 4,
      'begarde alla atta synliga vid 1375 ms -> ' + g.saknade.length + ' saknas: ' + g.saknade.join(',')); }

  /* TS-07 · tva renderingar av samma tillstand ar matningsidentiska */
  { const las = `(() => { const it = document.getElementById('start');
      const prod = [...it.querySelectorAll('*')];
      return JSON.stringify(${JSON.stringify(ALLA)}.map(o => { const e = prod[o];
        const cs = e ? getComputedStyle(e) : null;
        return cs ? cs.fill + '|' + cs.stroke + '|' + cs.opacity : null; })); })()`;
    await kor(ATERSTALL_ANIMATION(SCEN), false); await sleep(150);
    await frys(T_AVTACKT); const x = await kor(las, false);
    await kor(ATERSTALL_ANIMATION(SCEN), false); await sleep(150);
    await frys(T_AVTACKT); const y = await kor(las, false);
    const d = determinismgrind(x, y);
    prov('TS-07', 'tva renderingar av samma tillstand ar matningsidentiska', d.ok,
      d.ok ? 'identiska berknade varden for alla atta delar' : d.skal); }

  await kor(ATERSTALL_ANIMATION(SCEN), false);
}
finally { try { chrome.kill(); } catch {} }
try { rmSync(join(outAbs, 'chrome-ts'), { recursive: true, force: true }); } catch {}

const ANTAL = 7;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('TVATILLSTANDSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(outAbs, 'tvatillstand.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
