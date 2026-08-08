#!/usr/bin/env node
// F2-NT · KALLROTORSAKER FOR DE 167 SVAGA GRAFISKA DELARNA OCH OBJEKTEN.
//
// Kör: node tools/nontext-root-cause.mjs [--out=<fil>]
//
// INGEN FARG ANDRAS. Verktyget laser, grupperar och redovisar.
//
// TVA POPULATIONER, aldrig sammanblandade:
//   A  145 grafiska delar i kontroller  (componentIdentityCarrier / stateCarrier)
//   B   22 fristaende required-objekt
// En rotorsak far omfatta bada bara om EXAKT samma implementation producerar
// bada. Det provas mot kallan, inte mot utseendet.
//
// GRUPPERINGEN AR MEKANISK, INTE VISUELL. Tva fynd har samma rotorsak bara om
// samma implementation producerar den svaga kontrasten. Samma RGB pa olika
// bakgrunder ar INTE samma rotorsak. Samma synliga farg fran tva olika
// deklarationer ar det inte heller.
//
// Kontrastvardet anvands aldrig for att ompröva om en barare ar required.

import { spawn } from 'node:child_process';
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';
import { FARGMOTOR } from './colour-engine.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const CHROME = process.env.CHROME_BIN || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9760 + (process.pid % 60);

// Aterskapar carrier-modellen OCH bokfor varifran varje farg kom.
const KALLPROB = `(() => {
  ${FARGMOTOR}
  const oppningstagg = el => { const h = el.outerHTML; return h.slice(0, h.indexOf('>') + 1); };
  const stilrad = el => el.getAttribute('style') || '';
  // Vilken deklaration satte fargen? Attribut, inline-stil eller arv.
  function fgKalla(el, typ) {
    if (typ === 'ram') { const s = stilrad(el);
      const m = s.match(/border(?:-top)?\\s*:\\s*[^;]*/i) || s.match(/border-top-color\\s*:\\s*[^;]*/i);
      return { satt: m ? m[0].trim() : '(ingen inline border)', var: m ? 'inline style' : 'css-regel',
        varde: getComputedStyle(el).borderTopColor }; }
    if (typ === 'fyllning' || typ === 'thumb') { const s = stilrad(el);
      const m = s.match(/background(?:-color)?\\s*:\\s*[^;]*/i);
      return { satt: m ? m[0].trim() : '(ingen inline background)', var: m ? 'inline style' : 'css-regel',
        varde: getComputedStyle(el).backgroundColor }; }
    // glyf, ikon, bock
    const st = el.getAttribute('stroke'), fi = el.getAttribute('fill');
    const cs = getComputedStyle(el);
    if (st && st !== 'none' && parse(st)) return { satt: 'stroke="' + st + '"', var: 'svg-attribut', varde: st };
    if (fi && fi !== 'none' && parse(fi)) return { satt: 'fill="' + fi + '"', var: 'svg-attribut', varde: fi };
    // currentColor: fargen kommer fran narmaste color-deklaration.
    const arvad = st === 'currentColor' || fi === 'currentColor';
    let kalla = null;
    if (arvad) { let n = el;
      while (n && n !== document.documentElement) {
        const s = n.getAttribute && n.getAttribute('style');
        const m = s && s.match(/(^|;)\\s*color\\s*:\\s*[^;]*/i);
        if (m) { kalla = { tagg: oppningstagg(n).slice(0, 90), decl: m[0].replace(/^;/, '').trim() }; break; }
        n = n.parentElement; } }
    return { satt: arvad ? (st === 'currentColor' ? 'stroke="currentColor"' : 'fill="currentColor"') : '(beraknad)',
      var: arvad ? 'currentColor' : 'beraknad stil',
      arvsKalla: kalla, varde: cs.stroke && cs.stroke !== 'none' ? cs.stroke : cs.fill };
  }
  // Vilket element och vilken deklaration gav den angransande ytan?
  function bgKalla(el) {
    let n = el;
    while (n && n !== document.documentElement) {
      const c = parse(getComputedStyle(n).backgroundColor);
      if (c && c[3] > 0) { const s = n.getAttribute('style') || '';
        const m = s.match(/background(?:-color)?\\s*:\\s*[^;]*/i);
        return { el: oppningstagg(n).slice(0, 110), satt: m ? m[0].trim() : '(css-regel eller arv)',
          alfa: c[3], klass: n.getAttribute('class') || null }; }
      n = n.parentElement; }
    return { el: '(ingen malad yta)', satt: '(sidans grund)', alfa: 1, klass: null };
  }
  // ADJUDICERING · malar det har elementet nagot alls? Ett element utan egen
  // fyllning och utan ram far sin "farg" komponerad ur underlaget, och kvoten
  // blir da 1,00 av matematiska skal — inte for att designen ar svag. Det ar
  // samma felklass som containerfelet i R-01.
  function malarNagot(el, typ) {
    const cs = getComputedStyle(el);
    const bg = parse(cs.backgroundColor);
    const harFyll = !!bg && bg[3] > 0;
    const harKant = ['borderTopWidth','borderBottomWidth','borderLeftWidth','borderRightWidth']
      .some(k => parseFloat(cs[k]) > 0);
    if (typ === 'ram') return harKant;
    if (typ === 'fyllning' || typ === 'thumb') return harFyll;
    return true;   // glyfer far sin farg ur stroke/fill
  }
  // ADJUDICERING · ar den angransande ytan RATT? En glyf ligger pa den yta
  // som finns direkt bakom den. Mats den i stallet mot ytan utanfor hela
  // kontrollen blir vardet fabricerat: en mork ikon pa en orange platta
  // jamfors da med sidans bakgrund.
  function faktiskYta(el) {
    const bg = bakgrundBakom(el.parentElement || el);
    return bg.rgb ? fargRgb(bg.rgb) : null;
  }
  return { fgKalla, bgKalla, oppningstagg, stilrad, parse, malarNagot, faktiskYta };
})()`;

import { NONTEXT_MEASURE } from './nontext-measure.mjs';
import { GRAPHIC_OBJECTS } from './graphic-objects.mjs';

const KALLA_KONTROLL = `(() => {
  const H = ${KALLPROB};
  const svar = [];
  const M = ${NONTEXT_MEASURE};
  // Matskriptet ger inte elementreferenser tillbaka. Vi gar igenom samma
  // kontroller i samma ordning och tar reda pa kallan for de delar som blev
  // fynd. Ordningen ar dokumentordning i bada fallen.
  const kontroller = [...document.querySelectorAll('[data-a11y-role]')]
    .filter(c => c.closest('.sc-item'));
  for (let i = 0; i < M.length; i++) {
    const k = M[i], c = kontroller[i];
    if (!c) continue;
    for (const d of k.delar) {
      if (!(d.carrier === 'componentIdentityCarrier' || d.carrier === 'stateCarrier')) continue;
      if (d.status !== 'matt' || k.disabled || !(d.kvot < 3)) continue;
      // Elementet kommer fran matskriptet sjalvt, inte fran en gissning.
      const j = k.delar.indexOf(d);
      const el = (window.__NT_EL[i] || [])[j] || c;
      svar.push({ population: 'A', art: k.art, roll: k.roll, namn: k.namn, state: k.state,
        carrier: d.carrier, typ: d.typ, ikon: d.ikon || null, kvot: d.kvot,
        farg: d.farg, angransande: d.angransande, motYta: d.motYta, descent: !!d.descent,
        fg: H.fgKalla(el, d.typ), bg: H.bgKalla(d.motYta === 'kontrollens inre yta' ? el.parentElement || c : (el.parentElement || c)),
        malarNagot: H.malarNagot(el, d.typ),
        faktiskYta: H.faktiskYta(el),
        tagg: H.oppningstagg(el).slice(0, 160), stil: H.stilrad(el),
        klass: el.getAttribute('class') || null,
        kontrollTagg: H.oppningstagg(c).slice(0, 160) });
    }
  }
  return svar;
})()`;

const KALLA_OBJEKT = `(() => {
  const H = ${KALLPROB};
  const G = ${GRAPHIC_OBJECTS};
  const objekt = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    for (const g of it.querySelectorAll('svg, [data-icon], [data-illustration]')) {
      if (g.closest('[data-a11y-role]')) continue;
      if (g.parentElement && g.parentElement.closest('svg')) continue;
      const r = g.getBoundingClientRect();
      if (!(r.width > 0 && r.height > 0)) continue;
      objekt.push(g); }
  }
  const svar = [];
  for (let i = 0; i < G.length; i++) {
    const d = G[i], el = objekt[i];
    if (!el || d.carrier !== 'required' || d.status !== 'matt' || !(d.kvot < 3)) continue;
    svar.push({ population: 'B', art: d.art, roll: null, namn: null, state: null,
      carrier: 'graphicalObjectRequired', typ: 'objekt', ikon: d.ikon, kvot: d.kvot,
      farg: d.farg, angransande: d.angransande, motYta: 'ytan bakom objektet', descent: false,
      fg: H.fgKalla(el, 'glyf'), bg: H.bgKalla(el.parentElement || el), malarNagot: true, faktiskYta: H.faktiskYta(el),
      tagg: H.oppningstagg(el).slice(0, 160), stil: H.stilrad(el),
      klass: el.getAttribute('class') || null, kontrollTagg: null });
  }
  return svar;
})()`;

const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=' + port,
  '--disable-gpu', '--no-first-run', '--allow-file-access-from-files',
  '--force-device-scale-factor=2',
  '--user-data-dir=' + join(process.env.TEMP || '.', 'butlery-rc'), 'about:blank'], { stdio: 'ignore' });
let F = [], verktygsfel = null;
try {
  let ws = null;
  for (let k = 0; k < 60 && !ws; k++) { await sleep(250);
    try { ws = (await (await fetch('http://127.0.0.1:' + port + '/json/version')).json()).webSocketDebuggerUrl; } catch {} }
  if (!ws) throw new Error('Chrome startade aldrig');
  const sock = new WebSocket(ws);
  await new Promise(r => { sock.onopen = r; });
  let id = 0; const p = new Map();
  sock.onmessage = m => { const j = JSON.parse(m.data); if (j.id && p.has(j.id)) { const res = p.get(j.id); p.delete(j.id); res(j.result); } };
  const call = (m, pr = {}, s) => new Promise(res => { const n = ++id; p.set(n, res); sock.send(JSON.stringify({ id: n, method: m, params: pr, ...(s ? { sessionId: s } : {}) })); });
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, pp) => call(m, pp, sessionId);
  await s('Page.enable');
  await s('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: false });
  for (const f of filer) {
    await s('Page.navigate', { url: pathToFileURL(resolve(f)).href });
    await sleep(400);
    await s('Runtime.evaluate', { expression: 'document.fonts.ready', awaitPromise: true });
    await sleep(650);
    for (const [namn, expr] of [['A', KALLA_KONTROLL], ['B', KALLA_OBJEKT]]) {
      const r = await s('Runtime.evaluate', { expression: expr, returnByValue: true });
      if (r.exceptionDetails) throw new Error(namn + '-proben kastade i ' + f + ': ' +
        JSON.stringify(r.exceptionDetails).slice(0, 200));
      F.push(...(r.result.value || []).map(x => ({ ...x, fil: f })));
    }
  }
} catch (e) { verktygsfel = e.message; }
finally { try { chrome.kill(); } catch {} }

if (verktygsfel) {
  console.log('VERKTYGSFEL: ' + verktygsfel);
  console.log('NT-ROTORSAK status=VERKTYGSFEL'); process.exit(2);
}

/* ── MEKANISMNYCKEL ────────────────────────────────────────────────────────
   Vad som gor tva fynd till samma rotorsak:
     population + bararroll + hur forgrunden ar satt + exakt vilken
     deklaration + exakt vilken bakgrundsdeklaration.
   Ratio, skarm och RGB ingar INTE i nyckeln.                                */
// Var bakgrunden ar DEKLARERAD hor till write scope, inte till mekanismen.
// Samma forgrundsdeklaration mot samma losta yta ar samma rotorsak aven om
// ytan i ena fallet kommer fran en inline-stil och i andra fran en css-regel.
const GLYFTYP = new Set(['ikon', 'glyf', 'bock']);
const felYta = x => GLYFTYP.has(x.typ) && x.faktiskYta && x.faktiskYta !== x.angransande;
const artefakt = x => !x.malarNagot ? 'barare utan egen farg'
  : felYta(x) ? 'fel angransande yta' : null;
const nyckel = x => [x.population, x.carrier, x.typ, x.fg.var, x.fg.satt,
  x.angransande, artefakt(x) || 'giltigt'].join(' ‖ ');

const grupper = new Map();
for (const x of F) { const k = nyckel(x); if (!grupper.has(k)) grupper.set(k, []); grupper.get(k).push(x); }

// Ar implementationen DELAD eller bara UPPREPAD? Delad = exakt samma
// kallstrang forekommer flera ganger; upprepad = samma sak skriven pa nytt.
const kallor = new Map(filer.map(f => [f, readFileSync(f, 'utf8')]));
const forekomster = str => { if (!str || str.length < 8) return null;
  let n = 0; for (const s of kallor.values()) n += s.split(str).length - 1; return n; };

// WRITE SCOPE · rotorsakspopulationen ar fynden. Write scope ar samtliga
// stallen i kallan dar samma deklaration star. De ar tva olika tal och far
// aldrig blandas ihop: en gemensam normaliserad deklaration ar bevis for
// samma felmekanism, men den sager ingenting om hur manga stallen som ska
// skrivas om.
const tillHex = rgb => { const m = String(rgb).match(/(\d+),\s*(\d+),\s*(\d+)/);
  return m ? '#' + [1,2,3].map(i => (+m[i]).toString(16).padStart(2, '0')).join('') : null; };
function kallmonster(r) {
  const d = r.kalldeklaration_forgrund;
  let m = d.match(/^(stroke|fill)="(.+)"$/);
  if (m) return [m[0]];
  m = d.match(/^(border(?:-top)?|background(?:-color)?)\s*:\s*(.*)$/i);
  if (!m) return [];
  let varde = m[2].replace(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/g, (_, a, b, c) =>
    tillHex('rgb(' + a + ',' + b + ',' + c + ')'));
  // rgba behalIs men skrivs bade med och utan inledande nolla i decimaltalet.
  const rgbaVarianter = [varde, varde.replace(/,\s*0\.(\d+)\)/g, ',.$1)'),
    varde.replace(/,\s*\.(\d+)\)/g, ',0.$1)'), varde.replace(/,\s+/g, ',')];
  const egenskap = m[1].toLowerCase();
  const utan = varde.replace(/\s+/g, '');
  const alla = [];
  for (const v of [...new Set(rgbaVarianter)])
    alla.push(egenskap + ':' + v, egenskap + ': ' + v);
  // Kallan skriver rgba utan mellanslag och med inledande punkt: rgba(245,244,237,.18)
  const komprimerad = varde.replace(/,\s+/g, ',').replace(/,\s*0\.(\d+)\)/g, ',.$1)');
  alla.push(egenskap + ':' + komprimerad, egenskap + ': ' + komprimerad);
  return [...new Set(alla)];
}
const kallantal = r => { const monster = kallmonster(r);
  if (!monster.length) return null;
  let n = 0, sedda = new Set();
  for (const mo of monster) { if (sedda.has(mo)) continue; sedda.add(mo);
    const k = forekomster(mo); if (k) n += k; }
  return { monster: [...sedda], forekomster_i_kallan: n }; };

const rc = [...grupper.entries()]
  .sort((a, b) => b[1].length - a[1].length)
  .map(([k, v], i) => {
    const kvoter = v.map(x => x.kvot);
    const stilar = [...new Set(v.map(x => x.stil))];
    const delad = stilar.length === 1 && forekomster(stilar[0]) > 1;
    return {
      id: 'NRC-' + String(i + 1).padStart(2, '0'),
      population: v[0].population,
      bararroll: v[0].carrier,
      typ: v[0].typ,
      mekanism: v[0].fg.var + ': ' + v[0].fg.satt + '  mot  ' + v[0].angransande,
      kalldeklaration_forgrund: v[0].fg.satt,
      kalldeklaration_bakgrund: [...new Set(v.map(x => x.bg.satt))],
      matartefakt: !!artefakt(v[0]),
      artefaktklass: artefakt(v[0]),
      faktisk_angransande_yta: [...new Set(v.map(x => x.faktiskYta))],
      adjudicering: !artefakt(v[0]) ? 'giltigt fynd — bararen malar sin farg och mats mot ratt yta'
        : artefakt(v[0]) === 'barare utan egen farg'
          ? 'MATARTEFAKT: bararen malar ingenting. Kvoten kommer ur underlaget, inte ur designen.'
          : 'MATARTEFAKT: mats mot ytan utanfor kontrollen, men ligger pa kontrollens egen yta.',
      arvsKalla: v[0].fg.arvsKalla || null,
      klasser: [...new Set(v.map(x => x.klass).filter(Boolean))],
      kravd_kvot: 3.0,
      forgrund: [...new Set(v.map(x => x.farg))],
      bakgrund: [...new Set(v.map(x => x.angransande))],
      alfa_kompositering: v.some(x => x.bg.alfa < 1),
      antal_fynd: v.length,
      enhet: v[0].population === 'A' ? 'grafiska delar' : 'grafiska objekt',
      antal_kontroller: v[0].population === 'A'
        ? new Set(v.map(x => x.art + '|' + x.roll + '|' + x.namn)).size : null,
      antal_artefakter: new Set(v.map(x => x.art)).size,
      artefakter: [...new Set(v.map(x => x.art))],
      filer: [...new Set(v.map(x => x.fil))].length,
      kvot_min: Math.min(...kvoter), kvot_max: Math.max(...kvoter),
      states: [...new Set(v.map(x => x.state).filter(Boolean))],
      roller: [...new Set(v.map(x => x.roll).filter(Boolean))],
      ikoner: [...new Set(v.map(x => x.ikon).filter(Boolean))],
      implementation: delad ? 'delad kallstrang' : 'upprepad implementation',
      rotorsakspopulation_st: v.length,
      write_scope: null,
      distinkta_stilstrangar: stilar.length,
      exempel: v.slice(0, 3).map(x => ({ art: x.art, namn: x.namn, kvot: x.kvot,
        farg: x.farg, angransande: x.angransande, tagg: x.tagg.slice(0, 120) })),
      fynd: v.map(x => ({ art: x.art, fil: x.fil, namn: x.namn, state: x.state, kvot: x.kvot })),
    };
  });

for (const r of rc) { const w = kallantal(r);
  r.write_scope = (w && w.forekomster_i_kallan) ? { sokmonster: w.monster, forekomster_i_kallan_st: w.forekomster_i_kallan,
    utanfor_fynden_st: Math.max(0, w.forekomster_i_kallan - r.antal_fynd),
    $not: 'forekomster_i_kallan ar write scope. antal_fynd ar rotorsakspopulationen. De ar olika tal.' }
    : { sokmonster: [], forekomster_i_kallan_st: null, utanfor_fynden_st: null,
        $not: 'deklarationen kommer inte fran en inline-deklaration och gar inte att raka i kallan' }; }

const A = F.filter(x => x.population === 'A'), B = F.filter(x => x.population === 'B');
const doc = { $schema: 'butlery-nt-rotorsak/1',
  $regel: 'Grupperingen ar mekanisk. Samma RGB pa olika bakgrunder ar inte samma rotorsak. Rotorsakspopulation och write scope halIs isar.',
  population: {
    A_kontrollgrafik_grafiskaDelar_st: A.length,
    A_componentIdentityCarrier_st: A.filter(x => x.carrier === 'componentIdentityCarrier').length,
    A_stateCarrier_st: A.filter(x => x.carrier === 'stateCarrier').length,
    B_fristaende_grafiskaObjekt_st: B.length,
    totalt_raa_fynd_st: F.length },
  adjudicering: {
    giltiga_fynd_st: F.filter(x => !artefakt(x)).length,
    matartefakter_st: F.filter(x => !!artefakt(x)).length,
    artefakt_barare_utan_egen_farg_st: F.filter(x => artefakt(x) === 'barare utan egen farg').length,
    artefakt_fel_angransande_yta_st: F.filter(x => artefakt(x) === 'fel angransande yta').length,
    $not: 'Matartefakter ar bundna till en rotorsak som alla andra, men de ar inte designfel och ska inte fargrattas. De kraver ett metodbeslut.' },
  rotorsaker_st: rc.length,
  bundna_fynd_st: rc.reduce((n, r) => n + r.antal_fynd, 0),
  oforklarade_st: F.length - rc.reduce((n, r) => n + r.antal_fynd, 0),
  rotorsaker: rc };
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('POPULATION');
console.log('  A kontrollgrafik      ' + String(A.length).padStart(4) + '  grafiska delar');
console.log('      componentIdentity ' + String(doc.population.A_componentIdentityCarrier_st).padStart(4));
console.log('      stateCarrier      ' + String(doc.population.A_stateCarrier_st).padStart(4));
console.log('  B fristaende objekt   ' + String(B.length).padStart(4) + '  grafiska objekt');
console.log('  totalt raa fynd       ' + String(F.length).padStart(4));
console.log('');
console.log('ADJUDICERING  giltiga ' + doc.adjudicering.giltiga_fynd_st +
  '   matartefakter ' + doc.adjudicering.matartefakter_st);
console.log('   barare utan egen farg  ' + doc.adjudicering.artefakt_barare_utan_egen_farg_st);
console.log('   fel angransande yta    ' + doc.adjudicering.artefakt_fel_angransande_yta_st);
console.log('');
console.log('ROTORSAKER  ' + rc.length + '   bundna ' + doc.bundna_fynd_st +
  '   oforklarade ' + doc.oforklarade_st + (doc.oforklarade_st ? '  ✖' : '  ✔'));
console.log('');
for (const r of rc) {
  console.log(r.id + '  ' + String(r.antal_fynd).padStart(3) + ' ' + r.enhet +
    ' · ' + r.antal_artefakter + ' artefakter · kvot ' + r.kvot_min + '–' + r.kvot_max);
  console.log('      ' + r.bararroll + ' / ' + r.typ + ' · ' + r.implementation);
  console.log('      ' + r.mekanism.slice(0, 150));
}
console.log('');
console.log('NT-ROTORSAK status=' + (doc.oforklarade_st === 0 ? 'komplett' : 'OFORKLARADE FYND'));
process.exit(doc.oforklarade_st === 0 ? 0 : 1);
