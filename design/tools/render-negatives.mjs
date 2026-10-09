#!/usr/bin/env node
// F2-R06 · BESTÄNDIGA NEGATIVA PROV.
//
// Ett grönt resultat är värdelöst om kontrollen inte kan bli röd. Varje prov här
// beskriver ett FEL som måste fällas, eller en LEGITIM form som inte får fällas.
// De körs mot samma kod som den skarpa körningen: mätskriptet importeras ur
// tools/render-measure.mjs och analysen ur tools/render-analyze.mjs.
//
//   N-01  R-03c utan faktisk klippning får INTE bli verifierat fel
//   N-02  faktisk klippning under overflow hidden/clip MÅSTE fällas
//   N-03  saknad och dubblerad mörk motpart
//   N-04  mörk motpart som inte går att koppla entydigt
//   N-05  viewportartefakt utan renderingsprofil
//   N-06  gridkonsument som avviker från sin deklarerade policy vid 1920
//   N-07  avsiktligt scrollområde får INTE bli verifierat fel
//   N-08  deklarerad line-clamp utan faktisk trunkering får INTE bli fel
//   N-09  samma klippning sedd av flera metoder ska DEDUPLICERAS
//   N-10  felaktig enhet, totalsumma eller nivåordning ska FÄLLA valideringen
//   N-11  förfader och barn med samma rotfel blir EN felinstans
//   N-12  två självständiga fel på förälder och barn slås INTE ihop
//   N-13  ett orelaterat inskjutet syskon ändrar inte fyndidentiteten
//   N-14  mätmetoden ligger i evidens, aldrig i findingId

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { MEASURE } from './render-measure.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanför manifestytan>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2);
}
mkdirSync(outAbs, { recursive: true });

const resultat = [];
const prov = (id, vad, ok, diag) => { resultat.push({ id, vad, ok: !!ok, diag }); };

/* ═══ Del A · prov som kräver en layoutmotor ═════════════════════════════ */
// Fixturen ligger UTANFÖR repot. Den är inte en designartefakt och ska aldrig
// hamna på manifestytan.
const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#fff;color:#111;font:14px/1.4 system-ui}
 .sc-item{background:#fff}
 .box{width:200px;height:60px;background:#eee}
</style>
<div class="sc-item" id="n01-ingen-klippning">
  <!-- overflow:hidden DEKLARERAD, innehållet ryms. Observation, inte fel. -->
  <div class="box" style="overflow:hidden"><div style="width:120px;height:30px"></div></div>
</div>
<div class="sc-item" id="n02-faktisk-klippning">
  <!-- overflow:hidden och ett barn som är 140 px bredare. Ska fällas. -->
  <div class="box" style="overflow:hidden"><div style="width:340px;height:30px"></div></div>
</div>
<div class="sc-item" id="n07-avsiktlig-scroll">
  <!-- overflow:auto = deklarerat scrollbar. Överskott är avsett. -->
  <div class="box" style="overflow:auto"><div style="width:600px;height:30px"></div></div>
</div>
<div class="sc-item" id="n08-clamp-utan-trunkering">
  <!-- line-clamp 3 men bara en rad text. Ska inte fällas. -->
  <div class="box" style="display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden">Kort</div>
</div>
<div class="sc-item" id="n08b-clamp-med-trunkering">
  <!-- line-clamp 1 och fyra rader text. Ska fällas. -->
  <div style="width:120px;height:20px;display:-webkit-box;-webkit-line-clamp:1;-webkit-box-orient:vertical;overflow:hidden">Detta ar en mycket lang text som garanterat inte ryms pa en enda rad i en box som ar hundratjugo pixlar bred</div>
</div>
<div class="sc-item" id="n11-forfader-och-barn">
  <!-- Förfadern klipper och barnet är just det som sticker ut. Ömsesidig
       referens: en felinstans, två elementfynd. -->
  <div class="box" style="overflow:hidden"><div style="width:400px;height:30px"></div></div>
</div>
<div class="sc-item" id="n12-tva-oberoende-fel">
  <!-- Förälder klipper VERTIKALT av eget innehåll. Barnet trunkerar text
       HORISONTELLT. Två självständiga fel — får aldrig slås ihop. -->
  <div style="width:200px;height:40px;overflow:hidden">
    <div style="width:120px;height:18px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">Denna text ryms garanterat inte pa en enda rad i en box som ar bara hundratjugo pixlar bred</div>
    <div style="height:60px"></div>
  </div>
</div>
<div class="sc-item" id="n13-utan-syskon">
  <div class="box" style="overflow:hidden"><div style="width:340px;height:30px"></div></div>
</div>
<div class="sc-item" id="n13b-med-inskjutet-syskon">
  <!-- Identisk med n13, men med ett orelaterat syskon inskjutet FÖRE.
       DOM-indexet flyttas; den stabila elementnyckeln får inte göra det. -->
  <p style="margin:0">orelaterat syskon</p>
  <div class="box" style="overflow:hidden"><div style="width:340px;height:30px"></div></div>
</div>
<div class="sc-item" id="n09-flera-metoder">
  <!-- Ett element, flera metoder: overflow-y hidden med överskott (R-03a),
       hidden-deklaration med utstickande barn (R-03c) och en klippt ellips
       (R-03d). Efter deduplicering ska det vara ETT fel. -->
  <div style="width:120px;height:18px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">Ett mycket langt textinnehall som varken ryms i bredd eller hojd i den har lilla boxen</div>
</div>`;

const fixturPath = join(outAbs, 'negativa-prov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

/* ── minimal CDP ─────────────────────────────────────────────────────────── */
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9800 + (process.pid % 150);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-negativ'), 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });

let data = null, verktygsfel = null;
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
  ws.onmessage = m => { const msg = JSON.parse(m.data);
    if (msg.id && pend.has(msg.id)) { const { res, rej } = pend.get(msg.id); pend.delete(msg.id);
      msg.error ? rej(new Error(msg.error.message)) : res(msg.result); } };
  const call = (method, params = {}, sessionId) => new Promise((res, rej) => {
    const i = ++id; pend.set(i, { res, rej });
    ws.send(JSON.stringify({ id: i, method, params, ...(sessionId ? { sessionId } : {}) }));
    setTimeout(() => { if (pend.has(i)) { pend.delete(i); rej(new Error(method + ' svarade inte')); } }, 30000);
  });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => call(m, p, sessionId);
  await s('Page.enable'); await s('Runtime.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 900, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(900);
  const r = await s('Runtime.evaluate', { expression: MEASURE, returnByValue: true, awaitPromise: false });
  if (r.exceptionDetails) throw new Error('mätskriptet kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 300));
  data = r.result.value;
  if (!data) throw new Error('mätskriptet returnerade inget');
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

if (verktygsfel) {
  // Ett verktygsfel får ALDRIG räknas som godkända prov.
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('NEGATIVA-PROV status=VERKTYGSFEL godkända=0 av 10');
  process.exit(2);
}

const art = id => data.artifacts.find(a => a.id === id);
const kl = (a, m) => (a && a[m + 'Klass']) || { verifierad: -1, avsiktlig: -1, observation: -1, verktygsfel: -1 };

{ const a = art('n01-ingen-klippning');
  prov('N-01', 'R-03c utan faktisk klippning blir observation, inte fel',
    kl(a, 'r03c').verifierad === 0 && kl(a, 'r03c').observation >= 1,
    'r03c ' + JSON.stringify(kl(a, 'r03c'))); }

{ const a = art('n02-faktisk-klippning');
  prov('N-02', 'faktisk klippning under overflow:hidden fälls',
    kl(a, 'r03c').verifierad >= 1,
    'r03c ' + JSON.stringify(kl(a, 'r03c')) + ' · ' + ((a.r03c.find(x => x.klass === 'verifierad') || {}).why || '')); }

{ const a = art('n07-avsiktlig-scroll');
  prov('N-07', 'avsiktligt scrollområde (overflow:auto) blir inte verifierat fel',
    kl(a, 'r03a').verifierad === 0 && kl(a, 'r03a').avsiktlig >= 1 && kl(a, 'r03c').verifierad === 0,
    'r03a ' + JSON.stringify(kl(a, 'r03a')) + ' r03c ' + JSON.stringify(kl(a, 'r03c'))); }

{ const a = art('n08-clamp-utan-trunkering'), b = art('n08b-clamp-med-trunkering');
  prov('N-08', 'line-clamp utan trunkering passerar, line-clamp med trunkering fälls',
    kl(a, 'r03d').verifierad === 0 && kl(a, 'r03d').observation >= 1 && kl(b, 'r03d').verifierad >= 1,
    'utan: ' + JSON.stringify(kl(a, 'r03d')) + ' · med: ' + JSON.stringify(kl(b, 'r03d'))); }

/* N-09, N-11…N-14 · identitet och nivåer — kör den RIKTIGA analyslogiken. */
const { detektionerAv, elementfynd, felinstanser } = await import('./render-analyze-lib.mjs');
const nivåer = id => {
  const a = art(id);
  const det = detektionerAv(a, { viewport: 'prov-800', fall: 'prov' });
  const fynd = elementfynd(det, 'verifierad');
  return { a, det, fynd, inst: felinstanser(fynd) };
};

{ const { a, det, fynd } = nivåer('n09-flera-metoder');
  const metoder = ['r03a', 'r03b', 'r03c', 'r03d']
    .filter(m => (a[m] || []).some(x => x.klass === 'verifierad'));
  const råa = det.filter(d => d.klass === 'verifierad').length;
  const flerMetoders = fynd.filter(f => f.evidens.metoder.length > 1);
  prov('N-09', 'samma fel sett av flera metoder får SAMMA findingId',
    metoder.length >= 2 && flerMetoders.length >= 1 && fynd.length < råa,
    'metoder: ' + metoder.join('+') + ' · råa detektioner: ' + råa + ' · elementfynd: ' + fynd.length +
    ' · flermetodsfynd: ' + JSON.stringify(flerMetoders.map(f => f.evidens.metoder.join('+')))); }

{ const { fynd, inst } = nivåer('n11-forfader-och-barn');
  const hop = inst.filter(i => i.hopslagen);
  prov('N-11', 'förfader och barn med samma geometriska rotfel blir EN felinstans',
    fynd.length >= 2 && inst.length === 1 && hop.length === 1,
    'elementfynd: ' + fynd.length + ' · felinstanser: ' + inst.length +
    ' · grund: ' + (hop[0] ? hop[0].hopslagningsgrund : 'ingen hopslagning')); }

{ const { fynd, inst } = nivåer('n12-tva-oberoende-fel');
  // Klippningen sitter på föräldern, trunkeringen på barnet. De har olika
  // subtypfamilj och saknar ömsesidig referens — får aldrig slås ihop.
  const familjer = new Set(inst.map(i => i.subtype));
  prov('N-12', 'två självständiga fel på förälder och barn slås INTE ihop',
    fynd.length >= 2 && inst.length >= 2 && familjer.size >= 2,
    'elementfynd: ' + fynd.length + ' · felinstanser: ' + inst.length +
    ' · subtyper: ' + [...familjer].join(', ')); }

{ const utan = nivåer('n13-utan-syskon'), med = nivåer('n13b-med-inskjutet-syskon');
  // Identiskt innehåll, men n13b har ett orelaterat <p> inskjutet före. Den
  // stabila nyckeln ska vara densamma; DOM-sökvägen ska ha ändrats.
  const nUtan = utan.fynd.map(f => f.elementKey).sort();
  const nMed = med.fynd.map(f => f.elementKey).sort();
  const pUtan = utan.fynd.map(f => f.path).sort();
  const pMed = med.fynd.map(f => f.path).sort();
  const idUtan = utan.fynd.map(f => f.findingId.split(' · ').slice(2).join(' · ')).sort();
  const idMed = med.fynd.map(f => f.findingId.split(' · ').slice(2).join(' · ')).sort();
  prov('N-13', 'ett orelaterat inskjutet syskon ändrar inte fyndidentiteten',
    nUtan.length > 0 && JSON.stringify(nUtan) === JSON.stringify(nMed) &&
    JSON.stringify(idUtan) === JSON.stringify(idMed) &&
    JSON.stringify(pUtan) !== JSON.stringify(pMed),
    'elementnyckel lika: ' + (JSON.stringify(nUtan) === JSON.stringify(nMed)) +
    ' · id-svans lika: ' + (JSON.stringify(idUtan) === JSON.stringify(idMed)) +
    ' · DOM-sökväg ändrad: ' + (JSON.stringify(pUtan) !== JSON.stringify(pMed)) +
    ' · nyckel: ' + nUtan[0]); }

{ // Mätmetoden får ALDRIG ingå i findingId. Om den gjorde det skulle samma
  // element ge ett id per metod, och nivå 2 vore meningslös.
  const { fynd } = nivåer('n09-flera-metoder');
  const metodINamn = fynd.some(f => /r03[abcd]/.test(f.findingId));
  prov('N-14', 'mätmetoden ligger i evidens, aldrig i findingId',
    !metodINamn && fynd.every(f => f.evidens.metoder.length >= 1),
    'findingId: ' + (fynd[0] ? fynd[0].findingId : '(inget)') +
    ' · evidens.metoder: ' + JSON.stringify(fynd.map(f => f.evidens.metoder))); }

/* ═══ Del B · prov utan layoutmotor ══════════════════════════════════════ */
const { readFileSync } = await import('node:fs');
const K = JSON.parse(readFileSync('layout-contract.json', 'utf8'));
const A = JSON.parse(readFileSync('artifacts.json', 'utf8'));

/* N-03 · saknad och dubblerad mörk motpart */
{
  const { parning } = await import('./theme-pairing-lib.mjs');
  const ljus = { id: 'l1', viewportClass: 'phone', buildTarget: null, layoutläge: 'compact',
    selectors: {}, fRoller: 'aaa', rollantal: 3, fSkelett: 'sss', luminansklass: 'ljus', luminans: 0.9 };
  const mörkUtan = { ...ljus, id: 'm-utan', luminansklass: 'mörk', luminans: 0.02, fRoller: 'zzz', fSkelett: 'zzz' };
  const mörkDubbel = { ...ljus, id: 'm-dubbel', luminansklass: 'mörk', luminans: 0.02 };
  const ljus2 = { ...ljus, id: 'l2' };
  const r1 = parning([ljus, mörkUtan]);
  const r2 = parning([ljus, ljus2, mörkDubbel]);
  prov('N-03', 'mörk artefakt utan motpart hamnar i utanMotpart; två identiska ljusa ger dubblett',
    r1.utanMotpart.length === 1 && r1.entydiga.length === 0 &&
    r2.flertydiga.length === 1 && r2.flertydiga[0].kandidater.length === 2,
    'utan motpart: ' + r1.utanMotpart.length + ' · dubbletter: ' +
    (r2.flertydiga[0] ? r2.flertydiga[0].kandidater.length : 0));
}

/* N-04 · mörk motpart som inte går att koppla entydigt */
{
  const { parning } = await import('./theme-pairing-lib.mjs');
  const bas = { viewportClass: 'phone', buildTarget: null, layoutläge: 'compact', selectors: {},
    fRoller: 'aaa', rollantal: 4, luminansklass: 'ljus', luminans: 0.9 };
  const r = parning([
    { ...bas, id: 'ljusA', fSkelett: 's1' },
    { ...bas, id: 'ljusB', fSkelett: 's2' },
    { ...bas, id: 'mork', luminansklass: 'mörk', luminans: 0.02, fSkelett: 's3' }
  ]);
  prov('N-04', 'flera möjliga motparter rapporteras som flertydig, aldrig som ett par',
    r.entydiga.length === 0 && r.flertydiga.length === 1 && r.flertydiga[0].kandidater.length === 2,
    'entydiga: ' + r.entydiga.length + ' · flertydiga: ' + r.flertydiga.length +
    ' · kandidater: ' + (r.flertydiga[0] || { kandidater: [] }).kandidater.length);
}

/* N-05 · viewportartefakt utan renderingsprofil */
{
  const utan = A.artifacts.filter(a => a.artifactKind === 'viewport' && !a.viewportProfile);
  const syntetisk = { artifactKind: 'viewport', viewportClass: 'phone', viewportProfile: null };
  const regel = a => !(a.artifactKind === 'viewport' && a.viewportClass !== 'none' && !a.viewportProfile);
  prov('N-05', 'viewportartefakt utan renderingsprofil fälls av regeln, och registret är rent',
    regel(syntetisk) === false && utan.filter(a => a.viewportClass !== 'none').length === 0,
    'syntetisk fälls: ' + (regel(syntetisk) === false) +
    ' · verkliga utan profil: ' + utan.filter(a => a.viewportClass !== 'none').length);
}

/* N-06 · gridkonsument som avviker från sin deklarerade policy vid 1920 */
{
  // Mätningen från flutter test, som deklarerade tal. Ett prov som läser sina
  // egna förväntningar ur samma källa som svaret bevisar ingenting — därför
  // står den förväntade trappan i layoutkontraktet och mätningen bredvid.
  const mätt = {
    standardrutnat: { 1180: 2, 1919: 3, 1920: 4, 2048: 4 },
    kortrutnat: { 1180: 2, 1919: 2, 1920: 3, 2048: 3 }
  };
  const policy = Object.fromEntries((K.gridPolicies || []).map(p => [p.id, p]));
  // Trappan står som steps: [{fromWidth, columns}] i layout-contract.json.
  const kolumnerVid = (p, w) => {
    if (!p || !Array.isArray(p.steps) || !p.steps.length) return null;
    let v = null;
    for (const s of [...p.steps].sort((a, b) => a.fromWidth - b.fromWidth))
      if (w >= s.fromWidth) v = s.columns;
    return v;
  };
  const kontroll = [];
  for (const [namn, m] of Object.entries(mätt)) {
    const p = policy[namn];
    for (const w of [1180, 1919, 1920, 2048]) {
      const förväntat = p ? kolumnerVid(p, w) : null;
      if (förväntat === null) continue;
      kontroll.push({ namn, w, mätt: m[w], förväntat, ok: m[w] === förväntat });
    }
  }
  // Provet bevisar att kontrollen KAN fälla. En påhittad avvikelse vid 1920
  // måste fällas, och en korrekt mätpunkt får inte fällas.
  //
  // De verkliga avvikelserna vid 1180 (deklarerat 3, uppmätt 2) är INTE ett
  // provfel. De är en registrerad, obesluten avvikelse mellan kontraktet och
  // implementationen — se layout-contract.json#gridPolicyAvvikelse. Provet får
  // därför inte kräva att alla mätpunkter stämmer; det skulle tvinga fram ett
  // normativt beslut som ingen fattat.
  const p = policy.standardrutnat;
  const förväntat1920 = p ? kolumnerVid(p, 1920) : null;
  const fällerFalskt = förväntat1920 !== null && 2 !== förväntat1920;
  const släpperRätt = förväntat1920 !== null && mätt.standardrutnat[1920] === förväntat1920;
  const verkligaAvvikelser = kontroll.filter(k => !k.ok);
  prov('N-06', 'avvikelse i kolumnantal vid 1920 fälls mot den deklarerade policyn',
    fällerFalskt === true && släpperRätt === true,
    förväntat1920 === null
      ? 'layout-contract.json saknar en trappa för standardrutnat — provet kan inte avgöra något'
      : 'deklarerat vid 1920: ' + förväntat1920 + ' · uppmätt: ' + mätt.standardrutnat[1920] +
        ' · påhittad avvikelse (2) fälls: ' + fällerFalskt + ' · korrekt värde släpps: ' + släpperRätt +
        ' · registrerade obeslutade avvikelser: ' +
        (verkligaAvvikelser.map(k => k.namn + '@' + k.w + ' dekl ' + k.förväntat + ' obs ' + k.mätt).join(', ') || 'inga'));
}

/* N-10 · felaktig enhet eller totalsumma fäller rapportvalideringen */
{
  const { validera } = await import('./render-analyze-lib.mjs');
  const bra = {
    populationer: { registrerade_produktartefakter_st: 309, probeartefakter_st: 3,
                    totalt_exekverade_artefakter_st: 312 },
    nivåer: { raa_detektioner_st: 35, elementfynd_st: 35, felinstanser_st: 17 },
    raa_detektioner_per_metod: { r03c: { detektioner_st: 10, verifierad_detektioner_st: 2,
      avsiktlig_detektioner_st: 0, observation_detektioner_st: 8, verktygsfel_detektioner_st: 0,
      verifierad_produktartefakter_st: 2, avsiktlig_produktartefakter_st: 0,
      observation_produktartefakter_st: 8, verktygsfel_produktartefakter_st: 0 } }
  };
  const felSumma = JSON.parse(JSON.stringify(bra));
  felSumma.raa_detektioner_per_metod.r03c.observation_detektioner_st = 7; // 2+0+7+0 ≠ 10
  const felEnhet = JSON.parse(JSON.stringify(bra));
  felEnhet.raa_detektioner_per_metod.r03c.observation_produktartefakter_st = 310; // > 309
  const felNamn = JSON.parse(JSON.stringify(bra));
  felNamn.raa_detektioner_per_metod.r03c.observation = 8; // tal utan enhetssuffix
  const felNivå = JSON.parse(JSON.stringify(bra));
  felNivå.nivåer.felinstanser_st = 40; // fler felinstanser än elementfynd

  const a = validera(bra), b = validera(felSumma), c = validera(felEnhet),
        d = validera(felNamn), e = validera(felNivå);
  prov('N-10', 'fel totalsumma, fel enhet, tal utan enhetssuffix och omöjlig nivåordning fäller valideringen',
    a.length === 0 && b.length > 0 && c.length > 0 && d.length > 0 && e.length > 0,
    'korrekt: ' + a.length + ' · summafel: ' + b.length + ' · enhetsfel: ' + c.length +
    ' · namnfel: ' + d.length + ' · nivåfel: ' + e.length +
    ' → ' + [b[0], c[0], e[0]].filter(Boolean).join(' | ').slice(0, 170));
}

/* ═══ Redovisning ════════════════════════════════════════════════════════ */
resultat.sort((a, b) => a.id.localeCompare(b.id));
for (const r of resultat)
  console.log((r.ok ? '✔ ' : '✖ ') + r.id + '  ' + r.vad + '\n     ' + r.diag);
const gröna = resultat.filter(r => r.ok).length;
console.log('NEGATIVA-PROV status=' + (gröna === resultat.length ? 'godkänd' : 'FÄLLD') +
  ' godkända=' + gröna + ' av ' + resultat.length);
writeFileSync(join(outAbs, 'negativa-prov.json'), JSON.stringify({ prov: resultat, gröna, av: resultat.length }, null, 1));
try { rmSync(join(outAbs, 'chrome-negativ'), { recursive: true, force: true }); } catch {}
process.exit(gröna === resultat.length ? 0 : 1);
