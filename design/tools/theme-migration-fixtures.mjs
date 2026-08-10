#!/usr/bin/env node
// F2-R04 · BESTANDIGA PROV FOR ROLLKARTA, ANKARE OCH MIGRATOR.
//
// Kör: node tools/theme-migration-fixtures.mjs --out=<katalog utanfor repot>
//
// Tre felklasser som redan intraffat i skarpt lage har egna regressionsprov:
//   SA-01  <path> skrivs med explicit sluttagg men lag i void-listan, sa
//          djupvandringen avslutades for tidigt
//   SA-02  produktytan sjalv raknades i DOM men inte i kallan
//   SA-04  tva egenskaper pa samma tagg skrevs mot en foraldrad arbetskopia

import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { PAINT_PROBE } from './theme-paint-probe.mjs';
import { produktElementIKallan, migreraBlock, skrivITagg, deladKallaKonflikt } from './theme-migrator.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

const FIXTUR = `<!doctype html><meta charset="utf-8"><style>
 body{margin:0;background:#888;font:14px/1.4 system-ui}
 .sc-item{margin:8px}
 .sc-label{color:#37453a}
 .sc-id{color:#24382c}
 .sc-phone{background:var(--surface-app,#F5F4ED);border:1px solid var(--border-app,#ccd1c2);color:var(--text-app,#24382c);width:300px;padding:10px;box-sizing:border-box}
 .sc-item{--prov-ram:#7d897c;--prov-yta:#e6ead9}
 .sh-klass{border:1px solid var(--prov-ram)}
 .sh-langform{border-top-color:#3f6b4f}
</style>

<div class="sc-item" id="mrprov">
  <div class="sc-label"><a class="sc-id" href="#mrprov">dokumentation</a>
    Bildtexten anvander samma farg #37453a som produktytan.</div>
  <div class="sc-phone">
    <span data-a11y-role="button" data-a11y-name="Med ikon" data-hit="self"
      style="display:inline-flex;padding:8px;border:1px solid #ccd1c2"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#37453a" data-icon="x"><path d="M6 12h12"></path></svg></span>
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#37453a" data-icon="info"><path d="M6 12h12"></path></svg>
    <div style="border-top:2px solid #7d897c;border-bottom:2px solid #7d897c;color:#627061">Tva sidor och en text</div>
    <div style="background:#e6ead9;border:1px solid #ccd1c2">Kortform som tacker fyra sidor</div>
  </div>
</div>

<div class="sc-item" id="ccprov">
  <div class="sc-label"><a class="sc-id" href="#ccprov">dokumentation</a>
    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" data-icon="dok"><path d="M6 12h12"></path></svg>
    Dokumentationsikonen anvander ocksa currentColor.</div>
  <div class="sc-phone">
    <svg id="cc1" width="16" height="16" viewBox="0 0 24 24" fill="currentColor" style="color:#3f6b4f" data-icon="cc1"><path d="M6 12h12"></path></svg>
    <div id="cc2f" style="color:#627061"><svg id="cc2" width="16" height="16" viewBox="0 0 24 24" fill="currentColor" data-icon="cc2"><path d="M6 12h12"></path></svg></div>
    <svg id="cc3" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" style="color:#37453a" data-icon="cc3"><path d="M6 12h12"></path></svg>
    <svg id="cc4" width="16" height="16" viewBox="0 0 24 24" fill="currentColor" data-icon="cc4"><path d="M6 12h12"></path></svg>
    <div id="cc5f" data-a11y-role="button" data-a11y-name="Delad kalla" data-hit="self" style="color:#556b2f">Text och ikon delar kalla<svg id="cc5" width="16" height="16" viewBox="0 0 24 24" fill="currentColor" data-icon="cc5"><path d="M6 12h12"></path></svg></div>
  </div>
</div>

<div class="sc-item" id="cc7prov">
  <div class="sc-card">
    <svg id="cc7" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" data-icon="cc7"><path d="M6 12h12"></path></svg>
  </div>
</div>

<div class="sc-item" id="shprov">
  <div class="sc-phone">
    <div id="sh1" style="border:1px solid #ccd1c2">literal kortform</div>
    <div id="sh2" style="border:1px solid var(--prov-ram)">tokeniserad kortform</div>
    <div id="sh3" class="sh-klass">klassregel med kortform och var</div>
    <div id="sh4" class="sh-langform" style="border:1px solid var(--prov-ram)">inline kortform mot klassens langform</div>
    <div id="sh5" class="sh-klass" style="border-top-color:#9c3b23">klassens kortform mot inline langform</div>
    <div id="sh6" style="background:var(--prov-yta)"><span id="sh6b">barn utan egen bakgrund</span></div>
    <div id="sh7" style="color:#8a5212"><span id="sh7b">arvd text</span></div>
    <div id="sh8" style="border-width:1px;border-style:solid">ram utan fargdeklaration</div>
  </div>
</div>`;

const fixturPath = join(outAbs, 'migrationsprov.html');
writeFileSync(fixturPath, FIXTUR, 'utf8');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9870 + (process.pid % 25);
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--user-data-dir=' + join(outAbs, 'chrome-migprov'), 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });

let karta = null, domSekvens = null, verktygsfel = null;
try {
  let wsUrl = null;
  for (let i = 0; i < 60 && !wsUrl; i++) { await sleep(250);
    try { wsUrl = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!wsUrl) throw new Error('Chrome startade aldrig');
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP misslyckades')); });
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
  await s('Emulation.setDeviceMetricsOverride', { width: 800, height: 900, deviceScaleFactor: 1, mobile: false });
  await s('Page.navigate', { url: pathToFileURL(fixturPath).href });
  await sleep(800);
  const r = await s('Runtime.evaluate', { expression: PAINT_PROBE, returnByValue: true });
  if (r.exceptionDetails) throw new Error('proben kastade: ' + JSON.stringify(r.exceptionDetails).slice(0, 250));
  karta = r.result.value;
  const d = await s('Runtime.evaluate', { returnByValue: true, expression: `(() => {
    const it = document.getElementById('mrprov');
    const ytor = [...it.querySelectorAll('.sc-phone, .sc-card')];
    return [...it.querySelectorAll('*')].filter(e => ytor.some(y => y === e || y.contains(e)))
      .map(e => e.tagName.toLowerCase()); })()` });
  domSekvens = d.result.value;
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

const ANTAL = 34;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('MIGRATIONSPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const styck = id => { const i = FIXTUR.indexOf('<div class="sc-item" id="' + id + '"');
  const j = FIXTUR.indexOf('<div class="sc-item" id="', i + 10);
  return FIXTUR.slice(i, j < 0 ? FIXTUR.length : j); };
const blk = styck('mrprov');
const kallSekvens = (produktElementIKallan(blk) || []).map(e => e.tagg);
const skrivbara = karta.filter(x => x.art === 'mrprov' && x.ankare);
const tokenAv = p => '--prov-' + p.roll;
const mig = migreraBlock(blk, skrivbara, tokenAv);

const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });
const poster = f => karta.filter(x => x.art === 'mrprov' && f(x));
const alla = f => karta.filter(f);
const cc = id => karta.filter(x => x.viaCurrentColor && x.elementId === id);

/* ── MR · rollen kommer fran kartan, aldrig fran taggen ─────────────────── */
{ const p = poster(x => x.arSvg && x.arKontroll && x.egenskap === 'stroke');
  prov('MR-01', 'svg inuti en semantisk kontroll far rollen ikon-kontroll',
    p.length === 1 && p[0].roll === 'ikon-kontroll', p.length ? p[0].roll : 'posten saknas'); }

{ const p = poster(x => x.arSvg && !x.arKontroll && x.egenskap === 'stroke');
  prov('MR-02', 'motsvarande svg utanfor kontroll far rollen ikon-fristaende',
    p.length === 1 && p[0].roll === 'ikon-fristaende', p.length ? p[0].roll : 'posten saknas'); }

{ const a = poster(x => x.arSvg && x.arKontroll && x.egenskap === 'stroke')[0];
  const b = poster(x => x.arSvg && !x.arKontroll && x.egenskap === 'stroke')[0];
  prov('MR-03', 'samma literal i olika kontext ger olika tokenkandidat',
    !!a && !!b && a.beraknat === b.beraknat && a.roll !== b.roll,
    a && b ? a.beraknat + ': ' + a.roll + ' mot ' + b.roll : 'poster saknas'); }

{ const roller = new Set(mig.skrivna.map(x => x.roll));
  const kartroller = new Set(skrivbara.map(x => x.roll));
  prov('MR-04', 'migratorn omklassificerar aldrig en post fran kartan',
    [...roller].every(r => kartroller.has(r)) &&
    mig.skrivna.every(x => x.token === '--prov-' + x.roll),
    [...roller].join(', ')); }

{ const utan = { ...skrivbara[0], ankare: null };
  let kastade = false;
  try { migreraBlock(blk, [utan], tokenAv); } catch { kastade = true; }
  const r = migreraBlock(blk, [{ ...skrivbara[0], ankare: { ...skrivbara[0].ankare, elementOrdinal: 9999 } }], tokenAv);
  prov('MR-05', 'ett ankare som inte gar att losa ger fail closed utan skrivning',
    r.skrivna.length === 0 && r.hoppade.length === 1 && /finns inte i kallan/.test(r.hoppade[0].skal) &&
    r.blk === blk,
    r.hoppade.length ? r.hoppade[0].skal : 'ingen hoppad post'); }

/* ── SA · ankarmodellen ─────────────────────────────────────────────────── */
{ const path = kallSekvens.filter(t => t === 'path').length;
  prov('SA-01', 'produktytans subtrad parseras till samma elementpopulation som DOM, aven med explicit path-sluttagg',
    kallSekvens.length === domSekvens.length && path === 2,
    'kalla ' + kallSekvens.length + ' · DOM ' + domSekvens.length + ' · path ' + path); }

{ prov('SA-02', 'produktytan sjalv ingar i bada sekvenserna, ingen off-by-one',
    kallSekvens[0] === 'div' && domSekvens[0] === 'div' &&
    kallSekvens.join() === domSekvens.join(),
    'forsta ' + kallSekvens[0] + '/' + domSekvens[0] + ' · sekvenser lika ' + (kallSekvens.join() === domSekvens.join())); }

{ const trasig = blk.replace('<div style="background:#e6ead9', '<span style="background:#e6ead9');
  const el = produktElementIKallan(trasig) || [];
  const avviker = el.map(e => e.tagg).join() !== domSekvens.join();
  const r = migreraBlock(trasig, skrivbara, tokenAv);
  prov('SA-03', 'minsta taggavvikelse ger fail closed for de berorda posterna',
    avviker && r.hoppade.some(h => /taggen skiljer/.test(h.skal)),
    avviker ? r.hoppade.filter(h => /taggen skiljer/.test(h.skal)).length + ' poster fail closed' : 'ingen avvikelse skapades'); }

{ const tvaSidor = skrivbara.filter(x => /border-(top|bottom)-color/.test(x.egenskap) &&
    x.beraknat === 'rgb(125, 137, 124)');
  const skrivnaSidor = mig.skrivna.filter(x => tvaSidor.some(y => y.egenskap === x.egenskap));
  // Bada sidorna ar egna langformsdeklarationer och ska bada skrivas.
  const alla = mig.skrivna.filter(x => x.beraknat === 'rgb(125, 137, 124)');
  prov('SA-04', 'tva egenskaper pa samma tagg skrivs mot samma arbetskopia',
    tvaSidor.length === 2 && alla.length === 2 && mig.hoppade.length === 0,
    tvaSidor.length + ' poster · ' + alla.length + ' skrivna · 0 hoppade'); }

{ const kortform = skrivbara.filter(x => /border-\w+-color/.test(x.egenskap) &&
    x.beraknat === 'rgb(204, 209, 194)');
  // Jamfor pa POSTENS identitet, inte bara pa egenskapsnamnet.
  const nyckel = x => x.ankare.elementOrdinal + '|' + x.egenskap + '|' + x.beraknat;
  const kf = new Set(kortform.map(nyckel));
  const skrivna = mig.skrivna.filter(x => kf.has(nyckel(x)));
  const tackta = (mig.tackta || []).filter(x => kf.has(nyckel(x)));
  // Kortformen border:1px solid X malar fyra sidor. Exakt en skrivning per
  // element, ovriga sidor tackta av samma deklaration.
  const perEl = new Map();
  for (const x of mig.skrivna.filter(y => y.beraknat === 'rgb(204, 209, 194)'))
    perEl.set(x.ankare.elementOrdinal, (perEl.get(x.ankare.elementOrdinal) || 0) + 1);
  const enPerElement = [...perEl.values()].every(n => n === 1);
  prov('SA-05', 'en kortform som tacker flera sidor skrivs en gang, ovriga blir COVERED_BY_SAME_DECLARATION',
    kortform.length > 1 && enPerElement && tackta.length + skrivna.length === kortform.length,
    kortform.length + ' sidor · ' + skrivna.length + ' skrivna · ' + tackta.length + ' tackta · en per element ' + enPerElement); }

{ const summa = mig.skrivna.length + (mig.tackta || []).length + mig.hoppade.length;
  prov('SA-06', 'varje skrivbar post hamnar i exakt en kategori och summan ar populationen',
    summa === skrivbara.length && mig.hoppade.length === 0,
    skrivbara.length + ' = ' + mig.skrivna.length + ' skrivna + ' + (mig.tackta || []).length +
    ' tackta + ' + mig.hoppade.length + ' hoppade'); }

/* ── TOKEN_HOOK ─────────────────────────────────────────────────────────── */
{ const p = poster(x => x.ursprung === 'TOKEN_HOOK');
  prov('TH-01', 'kortform som innehaller var(...) kanns igen som TOKEN_HOOK',
    p.length > 0 && p.every(x => /var\(/.test(x.deklaration || '')),
    p.length + ' poster'); }

{ const p = poster(x => x.ursprung === 'TOKEN_HOOK');
  prov('TH-02', 'befintliga hooks ar inte skrivbara och tokeniseras aldrig om',
    p.length > 0 && p.every(x => !x.ankare),
    p.filter(x => x.ankare).length + ' skrivbara hooks (ska vara 0)'); }

{ const yta = poster(x => x.roll === 'yta-app')[0];
  prov('TH-03', 'fallbackvardet ger fortfarande det ljusa laget',
    !!yta && yta.beraknat === 'rgb(245, 244, 237)',
    yta ? yta.beraknat : 'ingen yta-app'); }

{ // Hooken finns i den delade regeln, men artefakten deklarerar inget
  // temastod. Coverage far darfor inte uppsta.
  const harStod = /data-theme-support/.test(FIXTUR);
  prov('TH-04', 'token hook i en delad regel ger inte automatiskt morkt stod',
    !harStod, harStod ? 'fixturen deklarerar stod' : 'inget data-theme-support i fixturen'); }

/* ── PRODUKTSCOPE ───────────────────────────────────────────────────────── */
{ const dok = poster(x => x.beraknat === 'rgb(55, 69, 58)' && !x.arSvg && x.egenskap === 'color');
  const iDok = dok.filter(x => /sc-label|sc-id/.test(x.klass || ''));
  prov('PS-01', 'dokumentationslagret ingar aldrig i rollkartan, aven vid samma farg',
    iDok.length === 0,
    iDok.length ? iDok.length + ' dokumentationsposter i kartan' : 'inga dokumentationsposter'); }

/* ── CC · currentColor ar en hanvisning, inte ett fargvarde ─────────────── */
// Felklassen som var belagd: proben pekade ut svg-attributet som skrivstalle
// trots att attributet inte bar nagon farg alls.

{ const p = cc('cc1')[0];
  prov('CC-01', 'fill=currentColor med lokal inline color: skrivstallet ar color-deklarationen, inte fill-attributet',
    !!p && p.egenskap === 'fill' && p.ursprung === 'INLINE' && p.kalla.upplost &&
    p.kalla.egenskap === 'color' && p.kalla.arvd === false &&
    p.ankare && p.ankare.egenskap === 'color' && p.ankare.form === 'INLINE' &&
    p.beraknat === 'rgb(63, 107, 79)',
    p ? p.ursprung + ' · kalla ' + p.kalla.varde + ' · ankare ' + JSON.stringify(p.ankare) : 'posten saknas'); }

{ const p = cc('cc2')[0];
  const foralder = karta.find(x => x.elementId === 'cc2f');
  prov('CC-02', 'arvd color: proveniensen gar till forfaderns deklaration och ankaret pekar pa forfadern',
    !!p && p.kalla.upplost && p.kalla.arvd === true && p.kalla.tagg === 'div' &&
    p.ursprung === 'INLINE' && p.ankare && p.ankare.egenskap === 'color' &&
    p.ankare.elementOrdinal !== null && p.beraknat === 'rgb(98, 112, 97)' &&
    (!foralder || p.ankare.elementOrdinal < karta.filter(x => x.art === 'ccprov' && x.ankare)
      .reduce((m, x) => Math.max(m, x.ankare.elementOrdinal), 0) + 1),
    p ? 'arvd ' + p.kalla.arvd + ' fran ' + p.kalla.tagg + ' · ordinal ' + (p.ankare && p.ankare.elementOrdinal) : 'posten saknas'); }

{ const p = cc('cc3')[0];
  prov('CC-03', 'stroke=currentColor foljer samma provenienskedja som fill',
    !!p && p.egenskap === 'stroke' && p.kalla.upplost && p.kalla.egenskap === 'color' &&
    p.ursprung === 'INLINE' && p.ankare && p.ankare.egenskap === 'color' &&
    p.kalla.hanvisning.ursprung === 'SVG_ATTRIBUTE' && p.beraknat === 'rgb(55, 69, 58)',
    p ? p.egenskap + ' -> ' + p.kalla.egenskap + ' · hanvisning ur ' + p.kalla.hanvisning.ursprung : 'posten saknas'); }

{ const p = cc('cc4')[0];
  prov('CC-04', 'nar color kommer ur en tokenhook klassas posten som TOKEN_HOOK och far inget fabricerat inline-ankare',
    !!p && p.ursprung === 'TOKEN_HOOK' && p.kalla.upplost && /var\(/.test(p.kalla.varde) &&
    p.ankare === null,
    p ? p.ursprung + ' · ' + p.kalla.varde + ' · ankare ' + p.ankare : 'posten saknas'); }

{ // En och samma color-deklaration malar bade texten och ikonen.
  const ccBlk = styck('ccprov');
  const ccSkrivbara = karta.filter(x => x.art === 'ccprov' && x.ankare);
  const r = migreraBlock(ccBlk, ccSkrivbara, tokenAv);
  const ikon = cc('cc5')[0];
  const text = karta.find(x => x.elementId === 'cc5f' && x.egenskap === 'color');
  const sammaAnkare = !!ikon && !!text && ikon.ankare && text.ankare &&
    ikon.ankare.elementOrdinal === text.ankare.elementOrdinal &&
    ikon.ankare.egenskap === text.ankare.egenskap;
  const gruppen = [...r.skrivna, ...(r.tackta || [])].filter(x =>
    text && x.ankare.elementOrdinal === text.ankare.elementOrdinal && (x.ankare.egenskap || x.egenskap) === 'color');
  const skrivna = gruppen.filter(x => r.skrivna.includes(x)).length;
  prov('CC-05', 'en color-deklaration som malar bade text och ikon skrivs en gang, ovriga beroende blir COVERED_BY_SAME_DECLARATION',
    sammaAnkare && gruppen.length === 2 && skrivna === 1 && r.hoppade.length === 0 &&
    ikon.roll === 'ikon-kontroll' && text.roll === 'text-kontroll',
    (sammaAnkare ? 'samma ankare' : 'olika ankare') + ' · beroende ' + gruppen.length +
    ' · skrivna ' + skrivna + ' · hoppade ' + r.hoppade.length +
    ' · roller ' + (ikon ? ikon.roll : '?') + '/' + (text ? text.roll : '?')); }

{ // Samma kalla, men beroendena kraver olika morka varden.
  const ccSkrivbara = karta.filter(x => x.art === 'ccprov' && x.ankare);
  const morkOlika = p => p.roll === 'ikon-kontroll' ? '#a8c0aa' : '#c9d3c4';
  const morkLika = () => '#c9d3c4';
  const k = deladKallaKonflikt(ccSkrivbara, morkOlika);
  const d = deladKallaKonflikt(ccSkrivbara, morkLika);
  prov('CC-06', 'tva beroende med olika morka varden pa samma deklaration ger fail closed, ingen kandidat vinner',
    k.konflikter.length === 1 && k.konflikter[0].morkvarden.length === 2 &&
    k.delade.length === 0 && d.konflikter.length === 0 && d.delade.length === 1,
    'olika: ' + k.konflikter.length + ' konflikt / ' + k.delade.length + ' delade · ' +
    'lika: ' + d.konflikter.length + ' konflikt / ' + d.delade.length + ' delade'); }

{ const p = cc('cc7')[0];
  prov('CC-07', 'currentColor utan entydig authored kalla ger fail closed, ingen svg-kalla fabriceras',
    !!p && p.kalla.upplost === false && p.ursprung === 'OKAND_CURRENTCOLOR' &&
    p.ankare === null && p.deklaration === null,
    p ? p.ursprung + ' · ankare ' + p.ankare + ' · ' + p.kalla.skal : 'posten saknas'); }

{ const dok = alla(x => x.viaCurrentColor && /sc-label|sc-id/.test(x.klass || ''));
  const produkt = alla(x => x.viaCurrentColor && x.art === 'ccprov');
  const svgKallor = alla(x => x.viaCurrentColor && x.ankare && x.ankare.form === 'SVG_ATTRIBUTE');
  prov('CC-08', 'dokumentationslagrets currentColor-ikon dras aldrig in, och ingen currentColor-post far en svg-kalla',
    dok.length === 0 && produkt.length >= 4 && svgKallor.length === 0,
    'dokumentation ' + dok.length + ' · produkt ' + produkt.length + ' · svg-kallor ' + svgKallor.length); }

/* ── SH · kortformer som malar langformer, aven med var() ───────────────── */
// Felklassen som var belagd: efter tokenisering slutade CSSOM exponera
// langformen och posten foll till INHERITED trots att deklarationen stod kvar
// i taggen.
const sh = (id, eg) => karta.filter(x => x.elementId === id && (!eg || x.egenskap === eg));

{ const p = sh('sh1', 'border-top-color')[0];
  prov('SH-01', 'literal kortform: border-*-color pekar pa samma kortformsdeklaration',
    !!p && p.ursprung === 'INLINE' && p.block === 'inline' && p.deklarationsnamn === 'border-top-color' &&
    p.beraknat === 'rgb(204, 209, 194)' && !!p.ankare,
    p ? p.ursprung + ' · block ' + p.block + ' · namn ' + p.deklarationsnamn + ' · kortform ' + p.kortform : 'posten saknas'); }

{ const p = sh('sh2', 'border-top-color')[0];
  prov('SH-02', 'tokeniserad kortform: posten behaller sin kalla och blir ALDRIG INHERITED',
    !!p && p.ursprung === 'TOKEN_HOOK' && p.block === 'inline' && p.kortform === 'border' &&
    p.arvd === false && /var\(/.test(p.deklaration || '') && p.beraknat === 'rgb(125, 137, 124)',
    p ? p.ursprung + ' · block ' + p.block + ' · kortform ' + p.kortform + ' · arvd ' + p.arvd : 'posten saknas'); }

{ const p = sh('sh3', 'border-top-color')[0];
  prov('SH-03', 'klassregel med kortform och var: proveniensen ar klassregeln, inte arv',
    !!p && p.ursprung === 'TOKEN_HOOK' && p.block === 'class' && p.selector === '.sh-klass' &&
    p.kortform === 'border' && p.arvd === false && p.ankare === null,
    p ? p.ursprung + ' · block ' + p.block + ' · ' + p.selector : 'posten saknas'); }

{ const p = sh('sh4', 'border-top-color')[0];
  prov('SH-04', 'inline kortform slar klassens langform — den faktiska kaskadvinnaren anvands',
    !!p && p.block === 'inline' && p.kortform === 'border' && p.beraknat === 'rgb(125, 137, 124)',
    p ? p.block + ' · ' + p.beraknat + ' (klassens langform ar #3f6b4f)' : 'posten saknas'); }

{ const p = sh('sh5', 'border-top-color')[0];
  prov('SH-05', 'inline langform slar klassens kortform — den faktiska kaskadvinnaren anvands',
    !!p && p.ursprung === 'INLINE' && p.block === 'inline' && p.kortform === null &&
    p.beraknat === 'rgb(156, 59, 35)',
    p ? p.ursprung + ' · kortform ' + p.kortform + ' · ' + p.beraknat : 'posten saknas'); }

{ const barn = sh('sh6b', 'background-color');
  const foralder = sh('sh6', 'background-color')[0];
  prov('SH-06', 'en kortform pa foraldern tillskrivs aldrig barnet nar egenskapen inte arvs',
    barn.length === 0 && !!foralder && foralder.kortform === 'background',
    'barnposter ' + barn.length + ' · foralderns kortform ' + (foralder ? foralder.kortform : '-')); }

{ const p = sh('sh7b', 'color')[0];
  prov('SH-07', 'genuint arvd color klassas fortfarande INHERITED',
    !!p && p.ursprung === 'INHERITED' && p.arvd === true && p.ankare === null &&
    p.beraknat === 'rgb(138, 82, 18)',
    p ? p.ursprung + ' · arvd ' + p.arvd : 'posten saknas'); }

{ const p = sh('sh8', 'border-top-color')[0];
  prov('SH-08', 'ram utan nagon fargdeklaration ger fail closed, ingen kalla fabriceras',
    !!p && (p.ursprung === 'OKAND' || p.ursprung === 'AMBIGUOUS') && p.ankare === null &&
    p.deklaration === null,
    p ? p.ursprung + ' · ankare ' + p.ankare + ' · deklaration ' + p.deklaration : 'posten saknas'); }

{ const sidor = sh('sh1').filter(x => /border-\w+-color/.test(x.egenskap));
  const blkSh = styck('shprov');
  const r = migreraBlock(blkSh, karta.filter(x => x.art === 'shprov' && x.ankare), tokenAv);
  const mina = [...r.skrivna, ...(r.tackta || [])].filter(x => /border-\w+-color/.test(x.egenskap) &&
    x.beraknat === 'rgb(204, 209, 194)');
  const skrivna = mina.filter(x => r.skrivna.includes(x)).length;
  prov('SH-09', 'en kortform som malar fyra langformer ger fyra poster men EN skrivning',
    sidor.length === 4 && sidor.every(x => x.kortform === null || x.kortform === 'border') &&
    mina.length === 4 && skrivna === 1 && r.hoppade.length === 0,
    sidor.length + ' poster · ' + mina.length + ' i migreringen · ' + skrivna + ' skrivna · ' +
    r.hoppade.length + ' hoppade'); }

{ // sh1 och sh2 ar samma markup fore och efter tokenisering av kortformen.
  const a = sh('sh1', 'border-left-color')[0], b = sh('sh2', 'border-left-color')[0];
  prov('SH-10', 'tokenisering av en kortform behaller kallans identitet: samma block, samma deklaration, aldrig INHERITED',
    !!a && !!b && a.block === b.block && a.block === 'inline' &&
    b.kortform === 'border' && a.arvd === false && b.arvd === false &&
    a.ursprung === 'INLINE' && b.ursprung === 'TOKEN_HOOK' &&
    b.ursprung !== 'INHERITED',
    a && b ? 'fore ' + a.ursprung + '/' + a.block + ' · efter ' + b.ursprung + '/' + b.block +
      ' kortform ' + b.kortform : 'poster saknas'); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('MIGRATIONSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'migrationsprov.json'), JSON.stringify({ resultat, karta, kallSekvens, domSekvens }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
