#!/usr/bin/env node
// F2-ID01 · NEGATIVA PROV för identitetsrevisionen.
//
// Kör: node tools/identity-fixtures.mjs --out=<katalog utanför manifestytan>
//
// Proven renderas med SAMMA mätskript som den skarpa körningen och granskas av
// SAMMA revisionsfunktion. En kontroll som prövas mot en kopia av sin egen
// logik bevisar ingenting.
//
//   A  åtta syskon med identisk normaliserad selektor → åtta noder, EN kollision
//   B  samma DOM-nod sedd av R-03a och R-03c → aldrig identitetskollision
//   C  förälder och barn i samma klippfel, olika nycklar → ingen kollision
//   D  samma tagg och klass men olika data-icon → stabil diskriminator finns
//   E  två oskiljbara syskon → identitetsambiguitet, ingen diskriminator
//   F  ett orelaterat inskjutet syskon → tidigare identitet går att känna igen

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { tmpdir } from 'node:os';
import { MEASURE } from './render-measure.mjs';
import { revidera, FIXTUR_HTML } from './identity-audit-lib.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanför manifestytan>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2);
}
mkdirSync(outAbs, { recursive: true });

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const fixturPath = join(outAbs, 'identitetsfixtur.html');
writeFileSync(fixturPath, FIXTUR_HTML, 'utf8');

let data = null, verktygsfel = null;
const profil = mkdtempSync(join(tmpdir(), 'idfix-'));
const port = 9940 + (process.pid % 40);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + profil, 'about:blank'], { stdio: 'ignore' });
try {
  let wsUrl = null;
  for (let i = 0; i < 60 && !wsUrl; i++) {
    await sleep(250);
    try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {}
  }
  if (!wsUrl) throw new Error('Chrome startade aldrig sin debugger-port');
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP-anslutning misslyckades')); });
  let id = 0; const pend = new Map();
  ws.onmessage = m => { const j = JSON.parse(m.data);
    if (j.id && pend.has(j.id)) { const { res } = pend.get(j.id); pend.delete(j.id); res(j.result); } };
  const call = (m, p = {}, s) => new Promise(res => {
    const i = ++id; pend.set(i, { res });
    ws.send(JSON.stringify({ id: i, method: m, params: p, ...(s ? { sessionId: s } : {}) })); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 900, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(1000);
  const r = await s('Runtime.evaluate', { expression: MEASURE, returnByValue: true });
  if (r.exceptionDetails) throw new Error('mätskriptet kastade');
  data = r.result.value;
  if (!data) throw new Error('mätskriptet returnerade inget');
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} try { rmSync(profil, { recursive: true, force: true }); } catch {} }

if (verktygsfel) {
  // Ett verktygsfel är aldrig godkända prov.
  console.log('✖ VERKTYGSFEL: ' + verktygsfel);
  console.log('IDENTITETSPROV-SUMMARY status=VERKTYGSFEL godkända=0 av 6');
  process.exit(2);
}

// Bygg en render-raw-formad struktur så att revideraren körs oförändrad.
const D = { results: [{ profile: { id: 'fixtur-800' }, probe: null, artifacts: data.artifacts }] };
const R = revidera(D, 'identitetsfixtur');

const kollFör = id => R.kollisioner.filter(k => k.artefakt === id);
const flerFör = id => (R.matning.samma_nod_flera_metoder_st, R);

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

// Fixturen bär åtta svg-syskon INUTI åtta likadana omslag, så två nycklar
// kolliderar: omslaget och glyfen. Provet gäller GLYFEN, och kräver att den
// redovisas som åtta faktiska noder under EN nyckel — aldrig som ett element.
{ const alla = kollFör('A-atta-syskon');
  const svg = alla.filter(x => x.noder.every(n => n.tag === 'svg'));
  prov('ID-A', 'åtta syskon med samma selektor ger åtta noder under EN nyckel',
    svg.length === 1 && svg[0].domnoder_st === 8 &&
    new Set(svg[0].noder.map(n => n.path)).size === 8,
    'svg-nyckel: ' + (svg[0] ? svg[0].elementKey : '—') +
    ' · noder: ' + (svg[0] ? svg[0].domnoder_st : 0) +
    ' · distinkta sökvägar: ' + (svg[0] ? new Set(svg[0].noder.map(n => n.path)).size : 0) +
    ' · totalt kolliderande nycklar i fixturen: ' + alla.length +
    ' (omslaget kolliderar också, vilket är väntat)'); }

{ const k = kollFör('B-samma-nod-flera-metoder');
  // Samma nod, flera metoder — ska INTE vara en kollision.
  prov('ID-B', 'samma DOM-nod sedd av flera metoder är ingen identitetskollision',
    k.length === 0 && R.matning.samma_nod_flera_metoder_st >= 1,
    'kollisioner i B: ' + k.length + ' · registrerade flera-metoder-fall totalt: ' +
    R.matning.samma_nod_flera_metoder_st); }

{ const k = kollFör('C-foralder-och-barn');
  prov('ID-C', 'förälder och barn med olika nycklar är ingen nyckelkollision',
    k.length === 0,
    'kollisioner i C: ' + k.length + ' · förfader-barn-par under samma nyckel totalt: ' +
    R.matning.forfader_barn_par_st); }

// Även här kolliderar omslaget. Provet gäller glyfen: den bär olika data-icon
// och revisionen ska kunna VISA att en stabil diskriminator finns.
{ const alla = kollFör('D-samma-tagg-olika-dataicon');
  const svg = alla.filter(x => x.noder.every(n => n.tag === 'svg'));
  const omslag = alla.filter(x => x.noder.every(n => n.tag === 'div'));
  prov('ID-D', 'samma tagg och klass men olika data-icon — stabil diskriminator hittas',
    svg.length === 1 && svg[0].diskriminator === 'data-attribut' &&
    omslag.length === 1 && omslag[0].diskriminator === null,
    'glyfens diskriminator: ' + (svg[0] ? JSON.stringify(svg[0].diskriminator) : '—') +
    ' · omslagets: ' + (omslag[0] ? JSON.stringify(omslag[0].diskriminator) : '—') +
    ' · data-attribut: ' + (svg[0] ? JSON.stringify(svg[0].noder.map(n => n.dataAttr)) : '')); }

{ const k = kollFör('E-oskiljbara-syskon');
  prov('ID-E', 'oskiljbara syskon markeras som identitetsambiguitet utan diskriminator',
    k.length === 1 && k[0].diskriminator === null && k[0].domnoder_st === 2,
    'kollisioner: ' + k.length + ' · noder: ' + (k[0] ? k[0].domnoder_st : 0) +
    ' · diskriminator: ' + (k[0] ? JSON.stringify(k[0].diskriminator) : '—')); }

{ const e = kollFör('E-oskiljbara-syskon')[0], f = kollFör('F-inskjutet-syskon')[0];
  // Nyckeln ska vara densamma trots det inskjutna syskonet, och noderna ska
  // gå att känna igen på sin beskrivning — det är det underlaget en framtida
  // identitetsmodell ska bygga på.
  const sammaNyckel = e && f && e.elementKey === f.elementKey;
  const sammaBeskrivning = e && f &&
    JSON.stringify(e.noder.map(n => n.domBeskrivning)) === JSON.stringify(f.noder.map(n => n.domBeskrivning));
  const pathFlyttad = e && f && JSON.stringify(e.noder.map(n => n.path)) !== JSON.stringify(f.noder.map(n => n.path));
  prov('ID-F', 'ett inskjutet syskon flyttar DOM-sökvägen men inte den igenkännbara identiteten',
    sammaNyckel && sammaBeskrivning && pathFlyttad,
    'samma nyckel: ' + sammaNyckel + ' · samma beskrivning: ' + sammaBeskrivning +
    ' · sökväg flyttad: ' + pathFlyttad +
    ' · E-paths ' + JSON.stringify(e ? e.noder.map(n => n.path) : []) +
    ' F-paths ' + JSON.stringify(f ? f.noder.map(n => n.path) : [])); }

for (const r of resultat) console.log((r.ok ? '✔ ' : '✖ ') + r.id + '  ' + r.vad + '\n     ' + r.diag);
const gröna = resultat.filter(r => r.ok).length;
console.log('IDENTITETSPROV-SUMMARY status=' + (gröna === resultat.length ? 'godkänd' : 'FÄLLD') +
  ' godkända=' + gröna + ' av ' + resultat.length);
writeFileSync(join(outAbs, 'identitetsprov.json'), JSON.stringify({ prov: resultat, gröna, av: resultat.length, kollisioner: R.kollisioner }, null, 1));
process.exit(gröna === resultat.length ? 0 : 1);
