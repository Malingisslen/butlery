#!/usr/bin/env node
// F2-I01 · IKONGEOMETRI — mäter varje inline-glyf mot sin egen viewBox.
//
// Kör: node tools/icon-geometry.mjs [--fix] [--fixtures] [--json=<fil>]
//
// VARFÖR DEN FINNS. nav-add ritades på ett 160×160-rutnät men bäddades in i en
// svg vars viewBox sa 0 0 24 24. Plustecknet låg på koordinaterna 43–117, alltså
// helt utanför fönstret, och eftersom webbläsare alltid klipper svg-innehåll var
// knappen "Lägg till" en TOM CIRKEL i åtta ritningar. Ingen kontroll såg det:
// ikonnamnet var rätt, banan var masterns, filen validerade. Det som saknades
// var en prövning av att grafiken faktiskt syns.
//
// MÄTNINGEN ÄR RIKTIG GEOMETRI, inte en regex över banans siffror. getBBox() ger
// den sanna omslutande rektangeln i användarkoordinater — samma system som
// viewBox — och klarar kurvor, bågar och relativa kommandon som en textmatchning
// aldrig kan. Ett försök med regex gav gränserna −8.5 och 18.2 för en glyf vars
// verkliga bbox ligger inom 0–24, eftersom kontrollpunkter och relativa steg
// räknades som koordinater.
//
// FYRA UTFALL, och bara ett av dem är godkänt:
//   ok          grafiken ligger helt inom viewBoxen
//   utanfor     grafiken ligger HELT utanför — ikonen är osynlig
//   klippt      grafiken skärs av viewBoxens kant
//   tom         inget renderas alls (nollstor bbox)
// En glyf med data-icon-clip="avsiktlig" undantas och redovisas separat.

import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { DOCS } from './lint-core.mjs';

const FIX = process.argv.includes('--fix');
const FIXTURES = process.argv.includes('--fixtures');
const JSONOUT = (process.argv.find(a => a.startsWith('--json=')) || '').split('=')[1];
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const sleep = ms => new Promise(r => setTimeout(r, ms));

/* ── Mätskriptet, kört I SIDAN ───────────────────────────────────────────── */
const MATA = `(() => {
  const ut = [];
  for (const svg of document.querySelectorAll('svg[data-icon]')) {
    const namn = svg.getAttribute('data-icon');
    const vbRaw = svg.getAttribute('viewBox');
    const avsikt = svg.getAttribute('data-icon-clip') || null;
    // getBBox() ger nollor för allt inuti display:none. En glyf som inte
    // renderas alls kan varken ha rätt eller fel geometri — den ligger UTANFÖR
    // mätningen och är inte ett fynd. Utan den skillnaden rapporterades 153
    // dolda glyfer som tomma ikoner.
    const renderad = svg.checkVisibility ? svg.checkVisibility() : svg.getClientRects().length > 0;
    let bbox = null, fel = null;
    try {
      const b = svg.getBBox();
      bbox = { x: +b.x.toFixed(3), y: +b.y.toFixed(3), w: +b.width.toFixed(3), h: +b.height.toFixed(3) };
    } catch (e) { fel = 'getBBox kastade: ' + e.message; }
    ut.push({ namn, viewBox: vbRaw, bbox, fel, avsikt, renderad,
      bredd: svg.getAttribute('width'), rect: (r => ({ w: +r.width.toFixed(2), h: +r.height.toFixed(2) }))(svg.getBoundingClientRect()) });
  }
  return ut;
})()`;

/* ── CDP ─────────────────────────────────────────────────────────────────── */
async function mät(filer) {
  const profil = mkdtempSync(join(tmpdir(), 'ikon-'));
  const port = 9880 + (process.pid % 60);
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
    await s('Emulation.setDeviceMetricsOverride', { width: 1400, height: 1000, deviceScaleFactor: 1, mobile: false });
    const alla = [];
    for (const f of filer) {
      if (!existsSync(f)) continue;
      await s('Page.navigate', { url: pathToFileURL(f).href });
      await sleep(1200);
      const r = await s('Runtime.evaluate', { expression: MATA, returnByValue: true });
      if (r.exceptionDetails || !r.result.value) throw new Error('mätningen misslyckades för ' + f);
      for (const g of r.result.value) alla.push({ ...g, fil: f });
    }
    return alla;
  } finally { try { chrome.kill(); } catch {} try { rmSync(profil, { recursive: true, force: true }); } catch {} }
}

/* ── Domslutet ───────────────────────────────────────────────────────────── */
export function bedomIkon(g) {
  if (g.fel) return { klass: 'verktygsfel', why: g.fel };
  if (g.renderad === false) return { klass: 'ej-renderad', why: 'glyfen renderas inte i dokumentet (dold yta) — geometrin gar inte att prova' };
  if (!g.viewBox) return { klass: 'verktygsfel', why: 'glyfen saknar viewBox' };
  const [vx, vy, vw, vh] = g.viewBox.trim().split(/[\s,]+/).map(Number);
  if (![vx, vy, vw, vh].every(Number.isFinite) || vw <= 0 || vh <= 0)
    return { klass: 'verktygsfel', why: 'oläsbar viewBox "' + g.viewBox + '"' };
  const b = g.bbox;
  // En rak linje har noll höjd eller bredd i bbox men är fullt mätbar för
  // inneslutning. Bara en helt nollstor rektangel saknar renderad geometri.
  if (!b || (b.w <= 0 && b.h <= 0))
    return { klass: 'tom', why: 'ingen renderad geometri — bbox ' + JSON.stringify(b) };
  const höger = vx + vw, botten = vy + vh;
  const utanförX = b.x >= höger || b.x + b.w <= vx;
  const utanförY = b.y >= botten || b.y + b.h <= vy;
  if (utanförX || utanförY)
    return { klass: 'utanfor',
      why: 'grafiken ligger helt utanför fönstret: bbox ' + b.x + '–' + (b.x + b.w) + ' × ' +
           b.y + '–' + (b.y + b.h) + ', viewBox ' + vx + '–' + höger + ' × ' + vy + '–' + botten };
  const över = [];
  if (b.x < vx - 0.01) över.push('vänster ' + (vx - b.x).toFixed(1));
  if (b.y < vy - 0.01) över.push('topp ' + (vy - b.y).toFixed(1));
  if (b.x + b.w > höger + 0.01) över.push('höger ' + (b.x + b.w - höger).toFixed(1));
  if (b.y + b.h > botten + 0.01) över.push('botten ' + (b.y + b.h - botten).toFixed(1));
  if (över.length)
    return { klass: 'klippt', why: 'grafiken skärs av fönstret: ' + över.join(', ') + ' användarenheter utanför' };
  return { klass: 'ok', why: null };
}

/* ── Fixturer ────────────────────────────────────────────────────────────── */
const FIXTUR = `<!doctype html><meta charset="utf-8"><title>ikonfixtur</title>
<!-- NEGATIV: 160-rutnätets geometri i en 24-viewBox. Exakt nav-add-felet. -->
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.2" data-icon="fixtur-negativ"><path d="M80 43v74M43 80h74"></path></svg>
<!-- POSITIV: samma geometri, rättat fönster. -->
<svg width="24" height="24" viewBox="22 22 116 116" fill="none" stroke="#000" stroke-width="7" data-icon="fixtur-positiv"><path d="M80 43v74M43 80h74"></path></svg>
<!-- KLIPPT: geometrin sticker ut åt ett håll. -->
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" data-icon="fixtur-klippt"><rect x="4" y="6" width="34" height="12"></rect></svg>
<!-- TOM: ingen geometri alls. -->
<svg width="24" height="24" viewBox="0 0 24 24" data-icon="fixtur-tom"></svg>`;

/* ── Körning ─────────────────────────────────────────────────────────────── */
const filer = [];
let fixturPath = null;
if (FIXTURES) {
  fixturPath = join(mkdtempSync(join(tmpdir(), 'ikonfix-')), 'fixtur.html');
  writeFileSync(fixturPath, FIXTUR, 'utf8');
  filer.push(fixturPath);
} else {
  filer.push(...DOCS.filter(existsSync));
}

let glyfer;
try { glyfer = await mät(filer); }
catch (e) {
  console.error('✖ VERKTYGSFEL: ' + e.message);
  console.log('ICON-GEOMETRY-SUMMARY status=verktygsfel');
  process.exit(2);
}

const rader = glyfer.map(g => ({ ...g, dom: bedomIkon(g) }));
const räkna = k => rader.filter(r => r.dom.klass === k).length;
const avsiktliga = rader.filter(r => r.avsikt && r.dom.klass !== 'ok');
const fel = rader.filter(r => !['ok', 'ej-renderad'].includes(r.dom.klass) && !r.avsikt);

if (FIXTURES) {
  const f = n => rader.find(r => r.namn === n);
  const prov = [
    ['I-01 · 160-geometri i 24-viewBox fälls som utanfor', f('fixtur-negativ')?.dom.klass === 'utanfor'],
    ['I-02 · samma geometri med rättat fönster passerar', f('fixtur-positiv')?.dom.klass === 'ok'],
    ['I-03 · geometri som skärs av fönstret fälls som klippt', f('fixtur-klippt')?.dom.klass === 'klippt'],
    ['I-04 · glyf utan renderad geometri fälls som tom', f('fixtur-tom')?.dom.klass === 'tom']
  ];
  for (const [namn, ok] of prov) console.log((ok ? '✔ ' : '✖ ') + namn);
  for (const r of rader) console.log('   ' + r.namn.padEnd(18) + r.dom.klass.padEnd(11) + (r.dom.why || '').slice(0, 80));
  const gröna = prov.filter(p => p[1]).length;
  console.log('IKONFIXTUR-SUMMARY godkända=' + gröna + ' av ' + prov.length);
  try { rmSync(join(fixturPath, '..'), { recursive: true, force: true }); } catch {}
  process.exit(gröna === prov.length ? 0 : 1);
}

for (const r of fel)
  console.log('✖ ' + r.namn + ' i ' + r.fil.replace(/^Butlery Skarmar v12 /, '') + ' [' + r.dom.klass + '] ' + r.dom.why);
for (const r of avsiktliga)
  console.log('· ' + r.namn + ' [avsiktlig beskärning: ' + r.avsikt + '] ' + r.dom.why);

const rapport = {
  $regel: 'Mätt med getBBox() i användarkoordinater, samma system som viewBox. Ingen regex över bandata.',
  glyfer_st: rader.length,
  ok_st: räkna('ok'),
  utanfor_st: fel.filter(r => r.dom.klass === 'utanfor').length,
  klippt_st: fel.filter(r => r.dom.klass === 'klippt').length,
  tom_st: fel.filter(r => r.dom.klass === 'tom').length,
  ej_renderade_st: räkna('ej-renderad'),
  verktygsfel_st: räkna('verktygsfel'),
  avsiktliga_st: avsiktliga.length,
  fel: fel.map(r => ({ namn: r.namn, fil: r.fil, klass: r.dom.klass, viewBox: r.viewBox, bbox: r.bbox, why: r.dom.why }))
};
if (JSONOUT) writeFileSync(JSONOUT, JSON.stringify(rapport, null, 1));

/* ── --fix · lagar FÖNSTRET, aldrig banan ────────────────────────────────── */
if (FIX && fel.length) {
  // Det nya fönstret härleds ur glyfens egen uppmätta bbox och ur det fönster
  // som glyfens familj redan använder — ingen hårdkodad regel för nav-add.
  const fungerande = new Map();
  for (const r of rader) if (r.dom.klass === 'ok' && r.viewBox) {
    const k = r.viewBox.trim();
    fungerande.set(k, (fungerande.get(k) || 0) + 1);
  }
  let lagade = 0;
  const perFil = {};
  for (const r of fel) {
    if (r.dom.klass !== 'utanfor' && r.dom.klass !== 'klippt') continue;
    // Välj det mest använda fungerande fönster som rymmer glyfens bbox.
    const kandidat = [...fungerande.entries()].sort((a, b) => b[1] - a[1]).find(([vb]) => {
      const [x, y, w, h] = vb.split(/[\s,]+/).map(Number);
      return r.bbox.x >= x - 0.01 && r.bbox.y >= y - 0.01 &&
             r.bbox.x + r.bbox.w <= x + w + 0.01 && r.bbox.y + r.bbox.h <= y + h + 0.01;
    });
    if (!kandidat) { console.log('  ⚠ inget fungerande fönster rymmer ' + r.namn); continue; }
    (perFil[r.fil] = perFil[r.fil] || []).push({ namn: r.namn, från: r.viewBox.trim(), till: kandidat[0], belägg: kandidat[1] });
  }
  for (const [fil, poster] of Object.entries(perFil)) {
    let t = readFileSync(fil, 'utf8');
    for (const p of poster) {
      const re = new RegExp('(<svg\\b[^>]*?)viewBox="' + p.från.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') +
        '"([^>]*data-icon="' + p.namn + '"[^>]*>)', 'g');
      const före = t;
      t = t.replace(re, '$1viewBox="' + p.till + '"$2');
      const n = (före.match(re) || []).length;
      lagade += n;
      console.log('  ✔ ' + p.namn + ' i ' + fil.replace(/^Butlery Skarmar v12 /, '') +
        ': viewBox ' + p.från + ' → ' + p.till + ' (' + n + ' förekomst(er), fönstret belagt av ' + p.belägg + ' fungerande glyfer)');
    }
    writeFileSync(fil, t);
  }
  console.log('ICON-FIX-SUMMARY lagade=' + lagade);
}

console.log('ICON-GEOMETRY-SUMMARY glyfer=' + rader.length +
  ' ok=' + räkna('ok') + ' utanfor=' + rapport.utanfor_st +
  ' klippt=' + rapport.klippt_st + ' tom=' + rapport.tom_st +
  ' ej_renderade=' + rapport.ej_renderade_st + ' verktygsfel=' + rapport.verktygsfel_st + ' avsiktliga=' + rapport.avsiktliga_st);
process.exit(räkna('verktygsfel') ? 2 : (fel.length && !FIX ? 1 : 0));
