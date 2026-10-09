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
import { findingId } from './render-analyze-lib.mjs';

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

/* ── IDENTITY-V2 · åtta prov till ────────────────────────────────────────── */
const v2 = R.identityV2.v2_per_nod;
const v2För = (id, tag) => v2.filter(x => x.artefakt === id && (!tag || x.identityDiagnostics.tag === tag));

{ const g = v2För('G-samma-dataicon', 'svg');
  prov('ID-G', 'två noder med SAMMA data-icon förblir tvetydiga',
    g.length === 2 && g.every(x => x.identityStatus === 'ambiguous' && x.identityKey === null),
    'noder: ' + g.length + ' · status: ' + g.map(x => x.identityStatus).join(',') +
    ' · nycklar: ' + JSON.stringify(g.map(x => x.identityKey))); }

{ const h = v2För('H-olika-dataicon', 'svg');
  prov('ID-H', 'två noder med olika unika data-icon blir stable',
    h.length === 2 && h.every(x => x.identityStatus === 'stable' && x.identityBasis === 'data-icon') &&
    new Set(h.map(x => x.identityKey)).size === 2,
    'status: ' + h.map(x => x.identityStatus + '/' + x.identityBasis).join(', ') +
    ' · distinkta nycklar: ' + new Set(h.map(x => x.identityKey)).size); }

{ const a = v2För('I-text-alfa').filter(x => x.identityDiagnostics.dataAttr['data-element-id'] === 'rutan');
  const b = v2För('I-text-beta').filter(x => x.identityDiagnostics.dataAttr['data-element-id'] === 'rutan');
  // Identiteten hänger på det explicita id:t, inte på texten. Att artefakt-id
  // skiljer är väntat — poängen är att GRUNDEN är explicit-element-id och att
  // texten aldrig blev identitetsbärande.
  const textIngårInte = [...a, ...b].every(x => x.identityBasis === 'explicit-element-id');
  prov('ID-I', 'ändrad text skapar inte automatiskt en ny kanonisk identitet',
    a.length === 1 && b.length === 1 && textIngårInte &&
    !a[0].identityKey.includes('Alfa') && !b[0].identityKey.includes('Beta'),
    'grund: ' + [...a, ...b].map(x => x.identityBasis).join(', ') +
    ' · texten ingår i nyckeln: ' + (a[0] && (a[0].identityKey.includes('Alfa'))) ); }

{ const e = v2För('J-ambigu-observation');
  const amb = e.filter(x => x.identityStatus === 'ambiguous');
  const obs = amb.filter(x => x.klasser.includes('observation') && !x.klasser.includes('verifierad'));
  prov('ID-J', 'tvetydiga observationer redovisas per nod, utan falsk deduplicering',
    obs.length >= 2 &&
    new Set(obs.map(x => x.identityDiagnostics.runtimeDomPath)).size === obs.length &&
    obs.every(x => x.identityKey === null),
    'tvetydiga observationsnoder: ' + obs.length + ' · distinkta sökvägar: ' +
    new Set(obs.map(x => x.identityDiagnostics.runtimeDomPath)).size +
    ' · alla utan identityKey: ' + obs.every(x => x.identityKey === null)); }

{ const k = v2För('K-ambiguost-verifierat');
  const verAmb = k.filter(x => x.identityStatus === 'ambiguous' && x.klasser.includes('verifierad'));
  const u = R.identityV2.failClosed;
  prov('ID-K', 'verifierat fynd i tvetydig grupp ger blocked och fäller fasgrinden',
    verAmb.length >= 1 && u.status === 'blocked' && u.fasgrind === 'faller' &&
    R.identityV2.kontrollresultat.verified_ambiguous_st >= 1,
    'verifierat tvetydiga: ' + verAmb.length + ' · failClosed: ' + u.status +
    ' · fasgrind: ' + (u.fasgrind || '—')); }

{ const utan = v2För('L-stabil-utan-syskon').filter(x => x.identityBasis === 'explicit-element-id');
  const med = v2För('L-stabil-med-syskon').filter(x => x.identityBasis === 'explicit-element-id');
  const nyckelUtanArtefakt = x => x.identityKey.split(' ‖ ').slice(1).join(' ‖ ');
  const pathFlyttad = utan.length && med.length &&
    utan[0].identityDiagnostics.runtimeDomPath !== med[0].identityDiagnostics.runtimeDomPath;
  prov('ID-L', 'inskjutet syskon flyttar runtime-sökvägen men inte identityKey',
    utan.length === 1 && med.length === 1 && pathFlyttad &&
    nyckelUtanArtefakt(utan[0]) === nyckelUtanArtefakt(med[0]),
    'sökväg: ' + (utan[0] || {}).identityDiagnostics?.runtimeDomPath + ' → ' +
    (med[0] || {}).identityDiagnostics?.runtimeDomPath +
    ' · nyckeldel lika: ' + (utan.length && med.length && nyckelUtanArtefakt(utan[0]) === nyckelUtanArtefakt(med[0]))); }

{ const utanKey = v2.filter(x => x.identityKey === null);
  // findingId får aldrig bära ett null. Vi prövar den RIKTIGA generatorn.
  const prov1 = utanKey.slice(0, 50).map(x => findingId(
    { artefakt: x.artefakt, elementKey: x.legacyElementKey, subtype: 'klippning', axis: 'x' },
    { viewport: x.viewport, theme: 'obeslutad', textScale: '1.0' }));
  const läcker = prov1.filter(f => /(^|·)s*(null|undefined|NaN)s*(·|$)/.test(f));
  prov('ID-M', 'identityKey null läcker aldrig in i findingId',
    utanKey.length > 0 && läcker.length === 0 &&
    R.identityV2.identityKey_osäkra_st === 0 &&
    utanKey.every(x => x.identityStatus !== 'stable'),
    'noder utan nyckel: ' + utanKey.length + ' · findingId med null-segment: ' + läcker.length +
    ' · osäkra identityKey: ' + R.identityV2.identityKey_osäkra_st); }

for (const r of resultat) console.log((r.ok ? '✔ ' : '✖ ') + r.id + '  ' + r.vad + '\n     ' + r.diag);
const gröna = resultat.filter(r => r.ok).length;
console.log('IDENTITETSPROV-SUMMARY status=' + (gröna === resultat.length ? 'godkänd' : 'FÄLLD') +
  ' godkända=' + gröna + ' av ' + resultat.length);
writeFileSync(join(outAbs, 'identitetsprov.json'), JSON.stringify({ prov: resultat, gröna, av: resultat.length, kollisioner: R.kollisioner }, null, 1));
process.exit(gröna === resultat.length ? 0 : 1);
