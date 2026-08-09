#!/usr/bin/env node
// F2-NT · FIXMANIFEST FOR DE 29 KALLROTORSAKERNA.
//
// Kör: node tools/nontext-fix-manifest.mjs [--out=<fil>]
//
// INGEN FARG ANDRAS. Manifestet foreslar, mater och redovisar risk.
//
// TRE OLIKA TAL SOM ALDRIG BLANDAS IHOP:
//   rotorsakspopulation      antalet verifierade fynd i gruppen
//   source occurrence        antalet stallen i kallan dar deklarationen star
//   write scope              de stallen som FAKTISKT ska skrivas om
//
// NRC-01 har 36 fynd och 401 forekomster. Write scope ar 36, inte 401.
// Endast en bevisat DELAD implementation far andras gemensamt.
//
// FARGVAL, i prioritetsordning:
//   1  behall komponentens semantiska fargroll
//   2  foredra en farg som redan anvands i sviten for samma funktion och som
//      klarar 3:1 mot den faktiska angransande ytan
//   3  annars minsta rimliga justering av samma kulor som ger >= 3,0
//   4  andra bara komponentens egen sida av paret
// Ingen tolerans: 2,98 ar underkant. 2,92 ar underkant.

import { readFileSync, readdirSync, writeFileSync } from 'node:fs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
const KRAV = 3.0;

const rc = JSON.parse(readFileSync('fas2/nt-rotorsaker.json', 'utf8'));
const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const kallor = new Map(filer.map(f => [f, readFileSync(f, 'utf8')]));

/* ── Fargmatematik, samma som matmotorn ────────────────────────────────── */
const srgb = c => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
const lum = ([r, g, b]) => 0.2126 * srgb(r) + 0.7152 * srgb(g) + 0.0722 * srgb(b);
const parse = s => { if (!s) return null;
  const m = String(s).match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/);
  if (m) return [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]];
  const h = String(s).trim().match(/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/);
  if (!h) return null;
  const v = h[1].length === 3 ? h[1].split('').map(c => c + c).join('') : h[1];
  return [parseInt(v.slice(0, 2), 16), parseInt(v.slice(2, 4), 16), parseInt(v.slice(4, 6), 16), 1]; };
const kvot = (f, b) => { const L1 = lum(f), L2 = lum(b);
  return +(((Math.max(L1, L2) + 0.05) / (Math.min(L1, L2) + 0.05))).toFixed(2); };
const hex = c => '#' + c.slice(0, 3).map(x => Math.round(x).toString(16).padStart(2, '0')).join('');

// Kulor och mattnad i HSL, sa att ett forslag kan behalla kuloren och bara
// flytta ljusheten. Semantiken sitter i kuloren, inte i ljusheten.
function tillHsl([r, g, b]) {
  r /= 255; g /= 255; b /= 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let h = 0;
  if (d) { h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4; h *= 60;
    if (h < 0) h += 360; }
  const l = (mx + mn) / 2;
  const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1));
  return [h, s, l];
}
function franHsl([h, s, l]) {
  const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2;
  const t = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x]
    : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
  return t.map(v => Math.round((v + m) * 255));
}

/* ── Palett ur kallan: vilka farger anvander ritningarna redan? ─────────── */
const palett = new Map();
for (const s of kallor.values())
  for (const m of s.matchAll(/#[0-9a-fA-F]{6}\b/g)) {
    const k = m[0].toLowerCase();
    palett.set(k, (palett.get(k) || 0) + 1); }
const paletten = [...palett.entries()].filter(([, n]) => n >= 3)
  .map(([h, n]) => ({ hex: h, rgb: parse(h).slice(0, 3), antal: n }));

// Steg 2: finns en befintlig designfarg med SAMMA kulor som klarar kravet?
// Kuloren far avvika hogst 20 grader — da ar det samma fargroll, inte en ny.
function palettforslag(fg, bg) {
  const [h0] = tillHsl(fg);
  const kandidater = paletten
    .map(p => ({ ...p, kv: kvot(p.rgb, bg), dh: Math.min(Math.abs(tillHsl(p.rgb)[0] - h0),
      360 - Math.abs(tillHsl(p.rgb)[0] - h0)) }))
    .filter(p => p.kv >= KRAV && p.dh <= 20)
    .sort((a, b) => (b.antal - a.antal) || (a.kv - b.kv));
  return kandidater[0] || null;
}
// Steg 3: minsta rimliga justering — behall kulor och mattnad, flytta bara
// ljusheten at det hall som redan ar rätt (morkare mot ljus yta, tvartom).
function ljushetsforslag(fg, bg) {
  const [h, s, l] = tillHsl(fg);
  const mork = lum(bg) > lum(fg);
  for (let steg = 1; steg <= 100; steg++) {
    const nl = mork ? l - steg / 100 : l + steg / 100;
    if (nl < 0 || nl > 1) break;
    const rgb = franHsl([h, s, nl]);
    if (kvot(rgb, bg) >= KRAV) return { hex: hex(rgb), rgb, kv: kvot(rgb, bg), antal: 0 };
  }
  return null;
}

const DELADE = new Set(['.empty', '.sc-skeleton']);

const manifest = rc.rotorsaker.map(r => {
  const fg = parse(r.forgrund[0]), bg = parse(r.bakgrund[0]);
  const nuKvot = fg && bg ? kvot(fg.slice(0, 3), bg.slice(0, 3)) : null;
  // VILKEN SIDA AV PARET HOR TILL KOMPONENTEN?
  // For en knopp ar bada sidorna komponentens egna, och knoppen ar per design
  // den ljusa ytan. Da ar det BANAN som ska justeras, inte knoppen. For allt
  // annat justeras bararens egen farg och den angransande ytan lamnas.
  const justeraBanan = r.typ === 'thumb';
  const kalla = justeraBanan ? bg : fg, motpart = justeraBanan ? fg : bg;
  const p = kalla && motpart ? palettforslag(kalla.slice(0, 3), motpart.slice(0, 3)) : null;
  const j = !p && kalla && motpart ? ljushetsforslag(kalla.slice(0, 3), motpart.slice(0, 3)) : null;
  const forslag = p || j;
  const delad = r.klasser.some(k => k.split(/\s+/).some(x => DELADE.has('.' + x)));

  // Vilka ANDRA verifierade element traffas av exakt samma skrivning? Bara de
  // som delar implementation. Upprepade strangar ar separata skrivstallen.
  const skrivstallen = delad ? 1 : r.antal_fynd;

  return {
    id: r.id,
    verifierade_fynd_st: r.antal_fynd,
    enhet: r.enhet,
    artefakter_st: r.antal_artefakter,
    artefakter: r.artefakter,
    kontroller_st: r.antal_kontroller,
    bararroll: r.bararroll,
    typ: r.typ,
    nuvarande_forgrund: r.forgrund[0],
    faktisk_angransande_farg: r.bakgrund[0],
    nuvarande_kvot: nuKvot,
    kvot_min: r.kvot_min, kvot_max: r.kvot_max,
    kalldeklaration: r.kalldeklaration_forgrund,
    source_occurrence_population_st: r.write_scope.forekomster_i_kallan_st,
    write_scope_st: skrivstallen,
    write_scope_grund: delad
      ? 'bevisat delad implementation — en enda deklaration andras'
      : 'upprepad implementation — endast de verifierade fynden skrivs om, aldrig alla forekomster',
    shared_implementation: delad,
    klasser: r.klasser,
    andrad_sida: justeraBanan ? 'den angransande banan — knoppen ar per design den ljusa ytan'
      : 'bararens egen farg',
    foreslagen_farg: forslag ? forslag.hex : null,
    forslagets_ursprung: p ? 'befintlig designfarg, anvand ' + p.antal + ' ganger i sviten'
      : j ? 'minsta ljushetsjustering med bevarad kulor' : null,
    forvantad_kvot: forslag ? forslag.kv : null,
    klarar_kravet: forslag ? forslag.kv >= KRAV : false,
    paverkade_andra_verifierade_element:
      delad ? 'alla instanser som klassen traffar — maste efterverifieras' : 'inga, skrivningen ar riktad',
    risk_R01: /ikon|glyf|bock|objekt/.test(r.typ)
      ? 'ingen — svg-attribut och fyllningar pa grafik pavarkar inte textkontrast'
      : 'ingen — ram- och fyllningsfarger pa kontroller ar inte textfarger',
    risk_ovriga_nontext: delad
      ? 'klassen kan traffa element som i dag klarar kravet; efterverifiering kravs'
      : 'begransad till de listade fynden',
    fynd: r.fynd,
  };
});

const doc = { $schema: 'butlery-nt-fixmanifest/1',
  $regel: 'rotorsakspopulation, source occurrence population och write scope ar tre olika tal. Endast bevisat delad implementation andras gemensamt.',
  krav_kvot: KRAV,
  rotorsaker_st: manifest.length,
  verifierade_fynd_st: manifest.reduce((n, m) => n + m.verifierade_fynd_st, 0),
  source_occurrences_totalt: manifest.reduce((n, m) => n + (m.source_occurrence_population_st || 0), 0),
  write_scope_totalt: manifest.reduce((n, m) => n + m.write_scope_st, 0),
  shared_implementations_st: manifest.filter(m => m.shared_implementation).length,
  utan_forslag_st: manifest.filter(m => !m.foreslagen_farg).length,
  manifest };
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('FIXMANIFEST  ' + doc.rotorsaker_st + ' rotorsaker · ' +
  doc.verifierade_fynd_st + ' verifierade fynd');
console.log('  source occurrences totalt ' + doc.source_occurrences_totalt +
  '   write scope totalt ' + doc.write_scope_totalt);
console.log('  bevisat delade implementationer ' + doc.shared_implementations_st +
  '   utan fargforslag ' + doc.utan_forslag_st);
console.log('');
for (const m of manifest) {
  console.log(m.id + '  ' + String(m.verifierade_fynd_st).padStart(3) + ' fynd · ' +
    m.bararroll.replace('componentIdentityCarrier', 'identitet')
      .replace('stateCarrier', 'tillstand').replace('graphicalObjectRequired', 'objekt') +
    '/' + m.typ + ' · ' + m.artefakter_st + ' art');
  console.log('      ' + m.nuvarande_forgrund + ' mot ' + m.faktisk_angransande_farg +
    ' = ' + m.nuvarande_kvot + '   ->  ' + (m.foreslagen_farg || 'INGET FORSLAG') +
    (m.andrad_sida.startsWith('den angransande') ? ' (banan)' : '') +
    (m.forvantad_kvot ? ' = ' + m.forvantad_kvot : '') +
    (m.klarar_kravet ? '  ✔' : '  ✖'));
  console.log('      write scope ' + m.write_scope_st + ' (av ' +
    (m.source_occurrence_population_st || '—') + ' forekomster) · ' +
    (m.shared_implementation ? 'DELAD implementation ' + m.klasser.join(' ') : 'riktad skrivning'));
}
