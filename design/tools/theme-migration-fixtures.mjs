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
import { produktElementIKallan, migreraBlock, skrivITagg } from './theme-migrator.mjs';

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

const ANTAL = 16;
if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('MIGRATIONSPROV status=VERKTYGSFEL godkanda=0 av ' + ANTAL); process.exit(2);
}

const blk = FIXTUR.slice(FIXTUR.indexOf('<div class="sc-item" id="mrprov"'));
const kallSekvens = (produktElementIKallan(blk) || []).map(e => e.tagg);
const skrivbara = karta.filter(x => x.ankare);
const tokenAv = p => '--prov-' + p.roll;
const mig = migreraBlock(blk, skrivbara, tokenAv);

const resultat = [];
const prov = (n, vad, ok, diag) => resultat.push({ id: n, vad, ok: !!ok, diag });
const poster = f => karta.filter(f);

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

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('MIGRATIONSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'migrationsprov.json'), JSON.stringify({ resultat, karta, kallSekvens, domSekvens }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
