#!/usr/bin/env node
// F2-R02 · TÄCKNINGS- OCH CONFORMANCEBASLINJE FÖR TRÄFFYTOR.
//
// Kör: node tools/hit-baseline.mjs [--out=<fil>]
//
// Detta är en TÄCKNINGSBASLINJE. Den säger vad som är verifierat och vad som
// inte är det — den påstår inte att R-02 är färdigverifierad. Så länge den
// overifierade populationen är materiell är R-02 inte stängd.
//
// UNKNOWN RÄKNAS ALDRIG SOM PASS. Ett fynd redovisas alltid med sitt scope:
// "N verifierade fynd i den mätbara populationen; M kontroller har ännu inte
// verifierad hit ownership." Aldrig "R-02 har N fel".
//
// MÄTPUNKT: referensviewporten compact-390. Deklarationspopulationen är per
// KONTROLL, inte per kontroll och viewport. control × viewport är en egen
// mätenhet och blandas aldrig in — se hit-contract.mjs invariant 5.

import { spawn } from 'node:child_process';
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';
import { HIT_MEASURE } from './hit-measure.mjs';
import { population, klassificera, domslut, parseHit, KRAV_PX } from './hit-contract.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const TMP = join(process.env.TEMP || '.', 'butlery-hitbas');
const port = 9160 + (process.pid % 120);
const VIEWPORT = { id: 'compact-390', width: 390, height: 844, dpr: 2 };

const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
let kallDeklarationer = 0, kallDataHit = 0;
for (const f of filer) {
  const t = readFileSync(f, 'utf8');
  kallDeklarationer += (t.match(/data-a11y-role=/g) || []).length;
  kallDataHit += (t.match(/data-hit=/g) || []).length;
}

const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2', '--user-data-dir=' + TMP, 'about:blank'], { stdio: 'ignore' });

let poster = null, verktygsfel = null;
try {
  let wsUrl = null;
  for (let i = 0; i < 60 && !wsUrl; i++) { await sleep(250);
    try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!wsUrl) throw new Error('Chrome startade aldrig sin debugger-port');
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP-anslutning misslyckades')); });
  let id = 0; const pend = new Map();
  ws.onmessage = m => { const msg = JSON.parse(m.data);
    if (msg.id && pend.has(msg.id)) { const { res, rej } = pend.get(msg.id); pend.delete(msg.id);
      msg.error ? rej(new Error(msg.error.message)) : res(msg.result); } };
  const call = (method, params = {}, sessionId) => new Promise((res, rej) => {
    const i = ++id; pend.set(i, { res, rej });
    ws.send(JSON.stringify({ id: i, method, params, ...(sessionId ? { sessionId } : {}) }));
    setTimeout(() => { if (pend.has(i)) { pend.delete(i); rej(new Error(method + ' svarade inte')); } }, 30000); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable'); await s('Runtime.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: VIEWPORT.width, height: VIEWPORT.height,
    deviceScaleFactor: VIEWPORT.dpr, mobile: false });
  poster = [];
  for (const f of filer) {
    await s('Page.navigate', { url: pathToFileURL(resolve(f)).href });
    await sleep(400);
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    await sleep(700);
    const r = await s('Runtime.evaluate', { expression: HIT_MEASURE, returnByValue: true });
    if (r.exceptionDetails) throw new Error('mätskriptet kastade i ' + f);
    const v = r.result.value;
    if (!v) throw new Error('ingen mätning för ' + f);
    poster.push(...v.poster.map(p => ({ ...p, fil: f })));
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('R-02-BASLINJE status=VERKTYGSFEL'); process.exit(2);
}

const pop = population(poster, { kallDeklarationer, kallDataHit });

// Produktnämnaren: semantiska kontroller inom registrerad artefakt.
const iNamnare = poster.filter(p => p.roll && p.iRegistreradArtefakt);
const dom = iNamnare.map(p => ({ ...domslut(p), fil: p.fil, form: parseHit(p.dataHit).form }));

const räkna = f => dom.filter(f).length;
const mätta = dom.filter(d => d.status === 'measured');
const fail = mätta.filter(d => d.uppfyller === false);
const failW = fail.filter(d => d.matt.w < KRAV_PX);
const failH = fail.filter(d => d.matt.h < KRAV_PX);
const failB = fail.filter(d => d.matt.w < KRAV_PX && d.matt.h < KRAV_PX);
const okänd = dom.filter(d => d.status !== 'measured');
const pct = (a, b) => b ? +(100 * a / b).toFixed(1) : 0;

// FYND. Formuleringen bär alltid sitt scope — ett fynd utan scope är ett
// påstående om hela populationen, och det påståendet finns inte täckning för.
const fynd = fail.map(d => ({
  findingId: ['CHK-R-02', d.artifactId, 'roll:' + d.roll + '|' + (d.namn || '(namnlöst)'),
    'agare=' + d.basis, 'vp=' + VIEWPORT.id].join(' · '),
  artifactId: d.artifactId, roll: d.roll, namn: d.namn,
  agare: d.basis, matt: d.matt, krav: KRAV_PX,
  brist: { bredd: +(KRAV_PX - d.matt.w).toFixed(2) > 0 ? +(KRAV_PX - d.matt.w).toFixed(2) : 0,
           hojd: +(KRAV_PX - d.matt.h).toFixed(2) > 0 ? +(KRAV_PX - d.matt.h).toFixed(2) : 0 }
})).sort((a, b) => (b.brist.bredd + b.brist.hojd) - (a.brist.bredd + a.brist.hojd));

const fel = [];
if (dom.some(d => d.status !== 'measured' && d.uppfyller !== null))
  fel.push('en overifierad kontroll bär ett pass/fail-omdöme — unknown får aldrig räknas som pass');
if (mätta.some(d => !d.matt)) fel.push('en mätt kontroll saknar mått');
if (pop.failClosed.fel.length) fel.push(...pop.failClosed.fel);

const rapport = {
  $schema: 'butlery-r02-baslinje/1', kontroll: 'CHK-R-02',
  $typ: 'TÄCKNINGS- OCH CONFORMANCEBASLINJE',
  $regel: 'Unknown räknas aldrig som pass. Antalet fynd gäller den mätbara populationen och får aldrig citeras utan sitt scope. R-02 är inte stängd så länge den overifierade populationen är materiell.',
  matpunkt: VIEWPORT,
  $matenhet: 'En rad per KONTROLL. control × viewport (1441) är en annan mätenhet och ingår aldrig i talen nedan.',
  populationsmodell: pop,
  population: {
    total_metadatapopulation_st: poster.length,
    semantiska_kontroller_st: poster.filter(p => p.roll).length,
    produktnamnare_st: iNamnare.length,
    utanfor_produktpopulationen_st: pop.outsideRegisteredArtifacts.st,
    metadata_utan_roll_st: pop.klasser['metadata-utan-roll']
  },
  deklaration: {
    self_st: räkna(d => d.form === 'self'),
    target_st: räkna(d => d.form === 'target'),
    lopttext_ej_migrerad_st: räkna(d => d.form === 'legacy-prose'),
    odeklarerad_st: räkna(d => d.form === 'undeclared')
  },
  utfall: {
    measured_st: mätta.length,
    unknown_st: okänd.length,
    pass_st: mätta.filter(d => d.uppfyller === true).length,
    fail_st: fail.length,
    fail_bredd_st: failW.length,
    fail_hojd_st: failH.length,
    fail_bagge_st: failB.length,
    measured_coverage_pct: pct(mätta.length, iNamnare.length),
    unknown_coverage_pct: pct(okänd.length, iNamnare.length)
  },
  artefakter: {
    med_matt_kontroll_st: new Set(mätta.map(d => d.artifactId)).size,
    med_fynd_st: new Set(fail.map(d => d.artifactId)).size,
    med_overifierad_kontroll_st: new Set(okänd.map(d => d.artifactId)).size
  },
  utanfor_produktpopulationen: pop.outsideRegisteredArtifacts,
  control_times_viewport: { st: 1441,
    $regel: 'EGEN MÄTENHET. Redovisas här bara för att den inte ska förväxlas — den summeras aldrig med talen ovan.' },
  fynd,
  overifierade_skal: (() => {
    const o = {}; for (const d of okänd) { const k = d.why || d.form; o[k] = (o[k] || 0) + 1; } return o;
  })(),
  failClosed: { fel, status: fel.length ? 'FÄLLD' : 'godkänd' }
};
if (OUT) writeFileSync(OUT, JSON.stringify(rapport, null, 1) + '\n');

const u = rapport.utfall;
console.log('R-02 TÄCKNINGSBASLINJE · ' + VIEWPORT.id + ' · en rad per kontroll');
console.log('  produktnämnare            ' + String(iNamnare.length).padStart(5));
console.log('  self / target             ' + String(rapport.deklaration.self_st).padStart(5) +
  ' / ' + rapport.deklaration.target_st);
console.log('  measured                  ' + String(u.measured_st).padStart(5) + '   ' + u.measured_coverage_pct + ' %');
console.log('  unknown                   ' + String(u.unknown_st).padStart(5) + '   ' + u.unknown_coverage_pct + ' %');
console.log('  pass >= ' + KRAV_PX + '×' + KRAV_PX + '           ' + String(u.pass_st).padStart(5));
console.log('  fail                      ' + String(u.fail_st).padStart(5) +
  '   bredd ' + u.fail_bredd_st + ' · höjd ' + u.fail_hojd_st + ' · båda ' + u.fail_bagge_st);
console.log('  artefakter med fynd       ' + String(rapport.artefakter.med_fynd_st).padStart(5));
console.log('  artefakter med overifierad' + String(rapport.artefakter.med_overifierad_kontroll_st).padStart(5));
console.log('  utanför produktpopulation ' + String(rapport.population.utanfor_produktpopulationen_st).padStart(5) + '   (redovisas separat)');
console.log('');
console.log('  ' + u.fail_st + ' verifierade R-02-fynd i den mätbara populationen;');
console.log('  ' + u.unknown_st + ' kontroller har ännu inte verifierad hit ownership.');
for (const f of fel) console.log('  ✖ ' + f);
console.log('R-02-BASLINJE status=' + rapport.failClosed.status);
process.exit(fel.length ? 1 : 0);
