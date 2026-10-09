#!/usr/bin/env node
// F2-R04 · METODPROV FOR PREVIEWSIMULERING.  PV-01 … PV-08
//
// Proven kors mot en verklig renderad sentinelscen, inte mot syntetiska noder.
// De bevisar mekanismen: ratt ordinalbas, ratt mal, noll kollateral injektion,
// exakt aterstallning, och att alla tre grindarna faller STANGDA nar de ska.
//
// PV-08 ar den viktigaste: sentinelscenen har inget authored morkt lage, och
// temagrinden maste falla for det. Ett previewresultat fran en scen utan
// authored dark far aldrig redovisas som designunderlag.

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { SCENTILLSTAND, KALLGRIND, FORALDERGRIND, INJICERA, ATERSTALL, SCENTEMAGRIND,
  malfingeravtryck, malgrind, kollateralgrind, malidentitet } from './preview-simulation.mjs';
import { APPLICERA_TEMA, BUTLERY_SENTINEL } from './authored-theme.mjs';

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

/* ── Sentinelscenen valjs ur det frysta maskinpaketet ────────────────────*/
const KOR = JSON.parse(readFileSync(new URL('../fas2/r04-foralderkorpus.json', import.meta.url), 'utf8'));
const AUD = JSON.parse(readFileSync(new URL('../fas2/r04-granularitetsaudit.json', import.meta.url), 'utf8'));
const KK = JSON.parse(readFileSync(new URL('../fas2/r04-kandidatkontrakt.json', import.meta.url), 'utf8'));
const SCEN = 'soctomtingavanner';
const ENHET = AUD.K_foundation.top10Fria[0];
const enhetsdata = KK.enheter.find(u => u.uid === ENHET);
const mal = KOR.population.filter(p => p.enhet === ENHET && p.art === SCEN)
  .map(p => ({ art: p.art, ordinal: p.elementOrdinal, egenskap: p.egenskap,
    forvantat: p.varde, foralderOrdinal: p.underliggandeYta ? p.underliggandeYta.ordinal : null }));
const scenPoster = KOR.population.filter(p => p.art === SCEN);
const KANDIDAT = enhetsdata.overlevande[2] || enhetsdata.overlevande[0];

const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const FIL = filer.find(f => readFileSync(f, 'utf8').includes('id="' + SCEN + '"'));
const arterIFil = [...readFileSync(FIL, 'utf8').matchAll(/class="sc-item"[^>]*id="([^"]+)"|id="([^"]+)"[^>]*class="sc-item"/g)]
  .map(m => m[1] || m[2]);

/* ── minimal CDP ────────────────────────────────────────────────────────*/
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9793;
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-preview'), 'about:blank'], { stdio: 'ignore' });
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
  const K = JSON.parse(readFileSync('layout-contract.json', 'utf8'));
  const VP = (Array.isArray(K) ? K : K.profiles).find(x => x.id === 'compact-390');
  await s('Emulation.setDeviceMetricsOverride', { width: VP.width, height: VP.height,
    deviceScaleFactor: 1, mobile: false });
  const kor = async (e, l = false) => { const r = await s('Runtime.evaluate',
    { expression: e, returnByValue: true, awaitPromise: l });
    if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails).slice(0, 400));
    return r.result.value; };
  await s('Page.navigate', { url: pathToFileURL(resolve(FIL)).href });
  await sleep(400); await kor('document.fonts.ready', true); await sleep(600);

  /* ── PV-01 · produktordinalbasen ar densamma som matningens ───────────*/
  { // Bred bas: ALLA uppmatta poster i HELA filen, inte bara sentinelscenen.
    const iFil = new Set(arterIFil);
    const alla = [...KOR.population, ...KOR.element]
      .filter(p => iFil.has(p.art))
      .map(p => ({ art: p.art, ordinal: p.elementOrdinal, egenskap: p.egenskap, forvantat: p.varde }));
    const kontroll = await kor(KALLGRIND(alla));
    const fel = kontroll.rader.filter(r => !r.ok);
    prov('PV-01', 'previewns produktordinalbas ar exakt matningens',
      kontroll.ok && alla.length > 20 && arterIFil.length > 1,
      alla.length + ' uppmatta poster i ' + arterIFil.length + ' artefakter i filen · ' +
      (alla.length - fel.length) + ' traffar samma element och samma varde · ' + fel.length + ' avvikelser'); }

  /* ── PV-02 · kallgrinden faller stangd nar kallan drivit ──────────────*/
  { const bra = await kor(KALLGRIND(mal));
    const drivit = await kor(KALLGRIND(mal.map(m => ({ ...m, forvantat: 'rgb(1, 2, 3)' }))));
    prov('PV-02', 'kallgrinden godkanner ratt kalla och faller stangd vid drift',
      bra.ok && !drivit.ok && /kallan har drivit/.test(drivit.rader[0].skal),
      'ratt kalla ok · pahittad forvantan avvisas: ' + drivit.rader[0].skal); }

  /* ── PV-03 · foraldergrinden jamfor ordinal, aldrig farg ──────────────*/
  { const bra = await kor(FORALDERGRIND(mal));
    const fel = await kor(FORALDERGRIND(mal.map(m => ({ ...m, foralderOrdinal: 999 }))));
    prov('PV-03', 'foraldergrinden bekraftar upplost foralderelement och faller vid fel',
      bra.ok && !fel.ok,
      'malets faktiska foralder = upplost ordinal ' + mal[0].foralderOrdinal +
      ' · pahittad foralder 999 avvisas'); }

  /* ── PV-04 · injektionen traffar exakt malmangden ─────────────────────*/
  const fore = await kor(SCENTILLSTAND(arterIFil));
  const inj = await kor(INJICERA(mal, KANDIDAT));
  const efter = await kor(SCENTILLSTAND(arterIFil));
  { const g = malgrind(mal, inj.filter(x => x.ok));
    prov('PV-04', 'injektionen traffar exakt beslutsenhetens instanser i scenen',
      g.ok && inj.every(x => x.blevKandidaten) && inj.length === mal.length,
      inj.length + ' mal, alla blev ' + KANDIDAT + ' · fingeravtryck ' +
      g.fingeravtryck.faktiskt.fingeravtryck); }

  /* ── PV-05 · noll kollateral injektion ────────────────────────────────*/
  const koll = kollateralgrind(fore, efter, mal);
  { prov('PV-05', 'ingen annan enhet an malet andras av injektionen',
      koll.ok && koll.andrade === mal.length,
      koll.andrade + ' element andrade, varav ' + koll.kollateral.length + ' kollaterala'); }

  /* ── PV-06 · syskon med samma rafarg forblir oforandrade ──────────────*/
  { const syskon = await kor(`(() => {
      const V = ${JSON.stringify(mal[0].forvantat)};
      let n = 0; for (const it of document.querySelectorAll('.sc-item'))
        for (const e of it.querySelectorAll('*'))
          if (getComputedStyle(e).backgroundColor === V) n++;
      return n; })()`);
    prov('PV-06', 'syskon med samma rafarg pavekas inte — rafargen ar aldrig selector',
      koll.kollateral.length === 0,
      syskon + ' element i filen bar fortfarande rafargen ' + mal[0].forvantat +
      ' efter injektionen · 0 av dem andrades'); }

  /* ── PV-07 · aterstallningen ar exakt ─────────────────────────────────*/
  { const n = await kor(ATERSTALL);
    const ater = await kor(SCENTILLSTAND(arterIFil));
    prov('PV-07', 'aterstallningen lamnar inga rester',
      JSON.stringify(ater) === JSON.stringify(fore) && n === mal.length,
      n + ' injektioner aterstallda · scentillstandet identiskt med fore'); }

  /* ── PV-08 · temagrinden faller stangd i en scen utan authored dark ───*/
  { const g = await kor(SCENTEMAGRIND(SCEN, 'dark'), true);
    const fil = await kor(APPLICERA_TEMA('dark', BUTLERY_SENTINEL), true);
    prov('PV-08', 'temagrinden mater SCENEN, inte filen, och faller stangd utan authored morkt lage',
      g.ok === false && g.stodjerTemat === false && g.andradeAvTemat === 0 && fil.roradaAntal > 0,
      'scenen ' + SCEN + ': ' + g.skal + ' · 0 av ' + g.produktElement +
      ' produktelement andrades. Filen har ' + fil.roradaAntal + ' ANDRA artefakter med authored dark — ' +
      'de far inte rakna som stod for denna scen'); }
}
finally { try { chrome.kill(); } catch {} }
try { rmSync(join(outAbs, 'chrome-preview'), { recursive: true, force: true }); } catch {}

const ANTAL = 8;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('PREVIEWPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'previewprov.json'), JSON.stringify({ scen: SCEN, enhet: ENHET,
  kandidat: KANDIDAT, mal, resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
