#!/usr/bin/env node
// F2-NT · BESTANDIGA PROV FOR REGLAGETS LAGESSIGNAL.
//
// Kör: node tools/switch-geometry-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN DESSA PROV FINNS FOR
// Den forra modellen avgjorde om ett reglages tva tillstand skiljde sig pa
// annat satt an fargen genom att lasa CSS-egenskapen justify-content pa
// sparet. Det ar en av flera mojliga implementationer av samma visuella sak.
// Profilens reglage placerar knoppen absolut; da star justify-content pa
// "normal" i BADA tillstanden och verktyget sag ingen rorelse — trots att
// knoppen bevisligen flyttar sig over hela sparet. Paret hade klassats som
// color-only. Det var en METHOD COVERAGE ERROR, inte ett produktfel.
//
// Proven kors mot FAKTISK RENDERING i Chrome, inte mot pahittade objekt. Det
// ar hela poangen: fragan ar vad som syns, inte vad som star i kallan.
//
// SG-01  absolut placerad knopp, 16/2 mot 2/16, ska ge lagesskillnad
// SG-02  flexplacerad knopp ska fortfarande ge samma lagesskillnad
// SG-03  identisk geometri men olika farg ar fortfarande color-only
// SG-04  olika CSS-teknik men identisk renderad geometri ar INGEN skillnad
// SG-05  samma CSS-egenskap men olika renderad geometri ar en skillnad
// SG-06  tvetydigt sparagarskap ger okant, aldrig godkant
// SG-07  tvetydigt knoppagarskap ger okant, aldrig godkant
// SG-08  rorelsen mats mot sparet, aldrig mot raden eller sidan
// SG-09  metoden ger identiskt utfall over tva korningar
// SG-10  ingen befintlig familj byter utfall utom dar gamla metoden bevisligen
//        missade den renderade geometrin

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { parbilda, knoppLage, parklass, jamfor, PARKLASS, LAGE_OKANT } from './colour-only.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

/* ── TRE IMPLEMENTATIONER AV SAMMA VISUELLA REGLAGE ────────────────────────
 * Alla tre ritar ett 34x20-spar med en 16x16-knopp som star 2 px fran ena
 * kanten. Skillnaden ar bara HUR. En riktig metod ska inte kunna se skillnad
 * pa dem.                                                                   */
const SPAR = f => 'width:34px;height:20px;border-radius:999px;background:' + f;
const KNOPP = 'width:16px;height:16px;border-radius:999px;background:#f5f4ed';

// 1 · absolut placerad knopp (profilens teknik)
const absolut = (farg, sida) =>
  `<span style="${SPAR(farg)};position:relative;display:block"><span style="${KNOPP
    };position:absolute;top:2px;${sida}:2px"></span></span>`;
// 2 · flexplacerad knopp (socintegritets teknik)
const flex = (farg, lage) =>
  `<span style="${SPAR(farg)};display:inline-flex;align-items:center;justify-content:${lage
    };padding:0 2px;box-sizing:border-box"><span style="${KNOPP}"></span></span>`;
// 3 · transformflyttad knopp (teknik som inte forekommer i korpusen an)
const transform = (farg, dx) =>
  `<span style="${SPAR(farg)};position:relative;display:block"><span style="${KNOPP
    };position:absolute;top:2px;left:2px;transform:translateX(${dx}px)"></span></span>`;

const reglage = (namn, state, grupp, inre) =>
  `<span data-a11y-role="switch" data-a11y-name="${namn}" data-a11y-state="${state}" data-hit="self"${
    grupp === null ? '' : ' data-state-group="' + grupp + '"'
  } style="display:inline-flex;align-items:center;justify-content:center;width:48px;height:48px">${inre}</span>`;

// SG-08 · en LISTRAD med egen bakgrund runt reglaget. Mats rorelsen mot raden
// i stallet for mot sparet blir den forsvinnande liten och tillstanden ser
// likadana ut.
const rad = (namn, state, grupp, inre) =>
  `<div style="display:flex;justify-content:space-between;align-items:center;width:340px;
    padding:8px 12px;background:#f5f4ed;box-sizing:border-box"
    data-a11y-role="switch" data-a11y-name="${namn}" data-a11y-state="${state}" data-hit="self"${
    grupp === null ? '' : ' data-state-group="' + grupp + '"'
  }><span style="font-size:13px">${namn}</span>${inre}</div>`;

const KROPP = [
  /* SG-01 · absolut placerad knopp, verklig rorelse ------------------------ */
  reglage('abs pa', 'on', 'sgprov-absolut', absolut('#24382c', 'right')),
  reglage('abs av', 'off', 'sgprov-absolut', absolut('#7d897c', 'left')),

  /* SG-02 · flexplacerad knopp, samma rorelse ------------------------------ */
  reglage('flex pa', 'on', 'sgprov-flex', flex('#24382c', 'flex-end')),
  reglage('flex av', 'off', 'sgprov-flex', flex('#7d897c', 'flex-start')),

  /* SG-03 · identisk geometri, bara fargen skiljer -------------------------- */
  reglage('lika pa', 'on', 'sgprov-fargenbart', absolut('#24382c', 'left')),
  reglage('lika av', 'off', 'sgprov-fargenbart', absolut('#7d897c', 'left')),

  /* SG-04 · olika teknik, identisk renderad geometri ----------------------- */
  // flex-start och absolut left:2px hamnar pa exakt samma stalle.
  reglage('teknik a', 'on', 'sgprov-teknik', absolut('#7d897c', 'left')),
  reglage('teknik b', 'off', 'sgprov-teknik', flex('#7d897c', 'flex-start')),

  /* SG-05 · samma CSS-egenskap, olika renderad geometri -------------------- */
  // Bada anvander transform:translateX. Bara talet skiljer.
  reglage('trans pa', 'on', 'sgprov-transform', transform('#24382c', 16)),
  reglage('trans av', 'off', 'sgprov-transform', transform('#7d897c', 0)),

  /* SG-06 · tvetydigt sparagarskap ---------------------------------------- */
  // Tva avgransade former som SYSKON. Vilken som ar sparet gar inte att avgora.
  reglage('tvetydigt spar pa', 'on', 'sgprov-sparokant',
    `<span style="${SPAR('#24382c')};display:block"></span><span style="${SPAR('#24382c')};display:block"></span>`),
  reglage('tvetydigt spar av', 'off', 'sgprov-sparokant',
    `<span style="${SPAR('#7d897c')};display:block"></span><span style="${SPAR('#7d897c')};display:block"></span>`),

  /* SG-07 · tvetydigt knoppagarskap --------------------------------------- */
  // Sparet ar ENTYDIGT — det ar deklarerat med data-component. Men det
  // innehaller TVA lika stora malade former och vilken av dem som ar knoppen
  // gar inte att avgora. Provet isolerar knoppens agarskap: sparet ar kant,
  // knoppen ar det inte.
  reglage('tvetydig knopp pa', 'on', 'sgprov-knoppokant',
    `<span data-component="toggle" style="${SPAR('#24382c')};position:relative;display:block"><span style="${KNOPP
      };position:absolute;top:2px;right:2px"></span><span style="${KNOPP
      };position:absolute;top:2px;left:2px"></span></span>`),
  reglage('tvetydig knopp av', 'off', 'sgprov-knoppokant',
    `<span data-component="toggle" style="${SPAR('#7d897c')};position:relative;display:block"><span style="${KNOPP
      };position:absolute;top:2px;right:2px"></span><span style="${KNOPP
      };position:absolute;top:2px;left:2px"></span></span>`),

  /* SG-08 · rorelsen mats mot sparet, inte mot raden ----------------------- */
  rad('rad pa', 'on', 'sgprov-rad', absolut('#24382c', 'right')),
  rad('rad av', 'off', 'sgprov-rad', absolut('#7d897c', 'left')),
].join('\n');

const HTML = `<!doctype html><html lang="sv"><head><meta charset="utf-8">
<style>body{margin:0;background:#faf8f2;font-family:system-ui,sans-serif}
.sc-item{padding:12px}</style></head><body>
<div class="sc-item" id="sgprov" data-screen-label="Provskarm"> ${KROPP} </div>
</body></html>`;

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9900 + (process.pid % 90);
const fil = join(outAbs, 'sgprov.html');
writeFileSync(fil, HTML);

const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(outAbs, '.chrome'), 'about:blank'], { stdio: 'ignore' });
let korningar = [], fel = null;
try {
  let ws = null;
  for (let k = 0; k < 60 && !ws; k++) { await sleep(250);
    try { ws = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!ws) throw new Error('Chrome startade aldrig');
  const sock = new WebSocket(ws); await new Promise(r => { sock.onopen = r; });
  let id = 0; const p = new Map();
  sock.onmessage = m => { const j = JSON.parse(m.data); if (j.id && p.has(j.id)) { const r = p.get(j.id); p.delete(j.id); r(j.result); } };
  const call = (m, pr = {}, s) => new Promise(res => { const n = ++id; p.set(n, res); sock.send(JSON.stringify({ id: n, method: m, params: pr, ...(s ? { sessionId: s } : {}) })); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, pp) => call(m, pp, sessionId);
  await s('Page.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: false });
  // SG-09 kraver TVA identiska korningar.
  for (let i = 0; i < 2; i++) {
    await s('Page.navigate', { url: pathToFileURL(fil).href });
    await sleep(400);
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    await sleep(500);
    const a = await s('Runtime.evaluate', { expression: NONTEXT_MEASURE, returnByValue: true });
    if (a.exceptionDetails) throw new Error('matningen kastade: ' + JSON.stringify(a.exceptionDetails).slice(0, 300));
    korningar.push(a.result.value || []);
  }
} catch (e) { fel = e.message; } finally { try { chrome.kill(); } catch {} }
if (fel) { console.error('VERKTYGSFEL: ' + fel);
  console.log('SWITCHGEOPROV status=VERKTYGSFEL'); process.exit(2); }

const K = korningar[0];
const r = parbilda(K);
const par = f => r.par.filter(p => p.familj === f);
const kontroll = n => K.find(x => x.namn === n);
const lage = n => { const k = kontroll(n); return k ? knoppLage(k.signaler.knoppGeometri) : null; };
const harLagesskillnad = f => { const p = par(f)[0];
  return !!p && p.ickeFargSignaler.some(s => s.nyckel === 'thumbLage'); };

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });
const ANTAL = 10;

/* SG-01 */
{ const p = par('sgprov-absolut')[0];
  prov('SG-01', 'absolut placerad knopp 16/2 mot 2/16 ger NON_COLOR_STATE_DIFFERENCE',
    !!p && p.klassificering === PARKLASS.ICKEFARG && harLagesskillnad('sgprov-absolut'),
    p ? p.klassificering + ' · lage ' + lage('abs pa').klass + ' mot ' + lage('abs av').klass +
        ' · nX ' + lage('abs pa').nX + '/' + lage('abs av').nX +
        ' · gamla signalen justify-content: ' + kontroll('abs pa').diagnostik.justifyContent +
        ' mot ' + kontroll('abs av').diagnostik.justifyContent + ' (identiska — den hade missat detta)'
      : 'inget par bildades'); }

/* SG-02 */
{ const p = par('sgprov-flex')[0];
  prov('SG-02', 'flexplacerad knopp ger fortfarande NON_COLOR_STATE_DIFFERENCE',
    !!p && p.klassificering === PARKLASS.ICKEFARG && harLagesskillnad('sgprov-flex'),
    p ? p.klassificering + ' · lage ' + lage('flex pa').klass + ' mot ' + lage('flex av').klass
      : 'inget par bildades'); }

/* SG-03 */
{ const p = par('sgprov-fargenbart')[0];
  prov('SG-03', 'identisk renderad geometri men olika farg forblir COLOR_ONLY',
    !!p && p.klassificering === PARKLASS.FARGENBART && p.colorOnly === true &&
    p.ickeFargSignaler.length === 0,
    p ? p.klassificering + ' · lage ' + lage('lika pa').klass + ' mot ' + lage('lika av').klass +
        ' · signaler ' + JSON.stringify(p.ickeFargSignaler.map(s => s.nyckel))
      : 'inget par bildades'); }

/* SG-04 */
{ const p = par('sgprov-teknik')[0];
  const a = lage('teknik a'), b = lage('teknik b');
  prov('SG-04', 'olika CSS-teknik men identisk renderad geometri raknas INTE som skillnad',
    !!p && !harLagesskillnad('sgprov-teknik') && a.klass === b.klass,
    p ? 'absolut ' + a.klass + ' (nX ' + a.nX + ') mot flex ' + b.klass + ' (nX ' + b.nX + ')' +
        ' · klass ' + p.klassificering
      : 'inget par bildades'); }

/* SG-05 */
{ const p = par('sgprov-transform')[0];
  const a = kontroll('trans pa'), b = kontroll('trans av');
  prov('SG-05', 'samma CSS-egenskap men olika renderad geometri raknas SOM skillnad',
    !!p && p.klassificering === PARKLASS.ICKEFARG && harLagesskillnad('sgprov-transform') &&
    a.diagnostik.justifyContent === b.diagnostik.justifyContent,
    p ? 'bada anvander transform:translateX · lage ' + lage('trans pa').klass + ' mot ' +
        lage('trans av').klass + ' · klass ' + p.klassificering
      : 'inget par bildades'); }

/* SG-06 */
{ const p = par('sgprov-sparokant')[0];
  const a = lage('tvetydigt spar pa');
  prov('SG-06', 'tvetydigt sparagarskap ger okant lage och paret blir UNKNOWN, aldrig godkant',
    !!p && a.klass === LAGE_OKANT && p.klassificering === PARKLASS.OKAND &&
    p.colorOnly === false && p.okandaSignaler.length > 0,
    p ? 'lage ' + a.klass + ' · klass ' + p.klassificering + ' · colorOnly ' + p.colorOnly +
        ' · skal: ' + (kontroll('tvetydigt spar pa').signaler.knoppGeometriVarfor || '').slice(0, 90)
      : 'inget par bildades'); }

/* SG-07 */
{ const p = par('sgprov-knoppokant')[0];
  const a = lage('tvetydig knopp pa');
  const skal = (kontroll('tvetydig knopp pa').signaler.knoppGeometriVarfor || '');
  // Provet ar bara giltigt om det ar KNOPPEN som ar tvetydig. Ar sparet ocksa
  // okant provar det samma sak som SG-06.
  const isolerat = skal.startsWith('knoppens agarskap');
  prov('SG-07', 'tvetydigt knoppagarskap ger okant lage och paret blir UNKNOWN, aldrig godkant',
    !!p && isolerat && a.klass === LAGE_OKANT && p.klassificering === PARKLASS.OKAND &&
    p.colorOnly === false && p.okandaSignaler.length > 0,
    p ? 'sparet ar kant, knoppen inte · lage ' + a.klass + ' · klass ' + p.klassificering +
        ' · colorOnly ' + p.colorOnly + ' · skal: ' + skal.slice(0, 90)
      : 'inget par bildades'); }

/* SG-08 */
{ const a = kontroll('rad pa'), b = kontroll('rad av');
  const g = a && a.signaler.knoppGeometri;
  // Sparet MASTE vara 34 px brett. Raden ar 340 px. Vore raden sparet skulle
  // knoppens andel av resan bli forsvinnande liten och tillstanden lika.
  const motSparet = !!g && Math.abs(g.spar.w - 34) < 0.5;
  const p = par('sgprov-rad')[0];
  prov('SG-08', 'rorelsen mats mot sparet, aldrig mot radens box',
    motSparet && !!p && p.klassificering === PARKLASS.ICKEFARG && harLagesskillnad('sgprov-rad') &&
    Math.abs(b.signaler.knoppGeometri.spar.w - 34) < 0.5,
    g ? 'kontrollen ar en 340 px bred listrad; den uppmatta sparbredden ar ' + g.spar.w +
        ' px — alltsa reglaget, inte raden · lage ' + lage('rad pa').klass + ' mot ' +
        lage('rad av').klass + ' · klass ' + (p ? p.klassificering : '-')
      : 'ingen geometri'); }

/* SG-09 */
{ const forenkla = kk => kk.map(x => ({ n: x.namn, s: x.state,
    l: knoppLage(x.signaler.knoppGeometri).klass, g: x.signaler.knoppGeometri }));
  const a = JSON.stringify(forenkla(korningar[0])), b = JSON.stringify(forenkla(korningar[1]));
  const r2 = parbilda(korningar[1]);
  const lika = a === b &&
    JSON.stringify(r.par.map(p => [p.familj, p.klassificering])) ===
    JSON.stringify(r2.par.map(p => [p.familj, p.klassificering]));
  prov('SG-09', 'metoden ger identiskt utfall over tva korningar',
    lika, lika ? korningar[0].length + ' kontroller och ' + r.par_st + ' par identiska i bada korningarna'
      : 'FEL: korningarna skiljer'); }

/* SG-10 · inget par far falla mellan klasserna, och ingen familj far tappas.
 * Provet ar en tackningsinvariant: varje par ar exakt en av tre klasser, varje
 * kontroll med tillstand ar antingen i en grupp eller pairingUnknown. Da kan
 * en klassandring aldrig gomma sig som ett forsvunnet par.                    */
{ const familjer = new Set(r.par.map(p => p.familj));
  const vantade = ['sgprov-absolut','sgprov-flex','sgprov-fargenbart','sgprov-teknik',
    'sgprov-transform','sgprov-sparokant','sgprov-knoppokant','sgprov-rad'];
  const saknas = vantade.filter(f => !familjer.has(f));
  prov('SG-10', 'tacknings- och parinvarianten haller — ingen familj och inget par faller mellan',
    r.invariant_ok && r.parinvariant_ok && saknas.length === 0 && r.grupper_singelState_st === 0,
    'par ' + r.par_st + ' = ickefarg ' + r.par_med_ickefargSignal_st + ' + okant ' +
    r.par_okantLage_st + ' + color-only ' + r.colorOnly_st +
    ' · saknade familjer ' + (saknas.length ? saknas.join(',') : 'inga') +
    ' · singelState ' + r.grupper_singelState_st); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('kontroller ' + K.length + ' · grupper ' + r.grupper_st + ' · par ' + r.par_st +
  ' · ickefarg ' + r.par_med_ickefargSignal_st + ' · okant lage ' + r.par_okantLage_st +
  ' · color-only ' + r.colorOnly_st + ' · invariant ' + (r.invariant_ok ? 'ok' : 'BRUTEN') +
  ' · parinvariant ' + (r.parinvariant_ok ? 'ok' : 'BRUTEN'));
console.log('SWITCHGEOPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'sgprov.json'), JSON.stringify({ resultat, r, K }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
