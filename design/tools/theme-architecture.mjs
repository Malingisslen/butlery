#!/usr/bin/env node
// F2-R04 · UNDERLAG FOR ARKITEKTURBESLUTET OM MORKT LAGE.
//
// Kör: node tools/theme-architecture.mjs --raw=<render-raw.json> [--out=<fil>]
//
// INGEN ANDRING. Verktyget laser kallan, grupperar och redovisar.
// Ingen data-theme rors, ingen artefakt skapas, ingen farg andras.
//
// Fyra fragor, hallna isar:
//   1  vilka artefakter saknar matfall och varfor
//   2  hur manga FAKTISKA designmonster de 306 light-only representerar
//   3  finns ett systemiskt temakontrakt redan i kallan
//   4  vad skiljer de nio befintliga paren i kallan

import { readdirSync, readFileSync, writeFileSync } from 'node:fs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const RAW = arg('raw'), OUT = arg('out');
if (!RAW) { console.error('✖ ange --raw=<render-raw.json>'); process.exit(2); }

const tack = JSON.parse(readFileSync('fas2/r04-tackning.json', 'utf8'));
const D = JSON.parse(readFileSync(RAW, 'utf8'));
const filer = readdirSync('.').filter(f => f.endsWith('.dc.html'));
const kallor = new Map(filer.map(f => [f, readFileSync(f, 'utf8')]));

// Artefaktens egen kallblock, fran dess sc-item-tagg till nasta.
const block = new Map();
for (const [f, s] of kallor) {
  const pos = [...s.matchAll(/<div class="sc-item" id="([a-z0-9]+)"/g)];
  for (let i = 0; i < pos.length; i++)
    block.set(pos[i][1], { fil: f, text: s.slice(pos[i].index, i + 1 < pos.length ? pos[i + 1].index : s.length) });
}

/* ── 1 · MATFALLSTACKNING ─────────────────────────────────────────────── */
const iProdukt = new Set(), iProbe = new Set();
for (const r of D.results) for (const a of r.artifacts) (r.probe ? iProbe : iProdukt).add(a.id);
const alla = tack.alla_artefakter;
const utanFall = alla.filter(x => !iProdukt.has(x.art) && !iProbe.has(x.art));

// Vilka viewportbredder kor harnesset for produkten?
const bredder = [...new Set(D.results.filter(r => !r.probe).map(r => r.viewport || r.width))].filter(Boolean);

/* ── 2 · DESIGNMONSTER BLAND DE LIGHT-ONLY ────────────────────────────── */
// Ett monster ar en implementation, inte en verifieringsfamilj. Signaturen
// bygger pa vad artefakten FAKTISKT ritar: dess ytfarger, ramfarger och
// textfarger i kallan, plus formfaktorn. Tva artefakter med samma signatur
// tematiseras av samma andring.
const fargerI = txt => {
  const ut = { yta: new Set(), ram: new Set(), text: new Set() };
  for (const m of txt.matchAll(/background(?:-color)?\s*:\s*(#[0-9a-fA-F]{6}|rgba?\([^)]*\))/g)) ut.yta.add(m[1].toLowerCase());
  for (const m of txt.matchAll(/border[a-z-]*\s*:\s*[^;"']*?(#[0-9a-fA-F]{6}|rgba?\([^)]*\))/g)) ut.ram.add(m[1].toLowerCase());
  for (const m of txt.matchAll(/(?:^|[;"'\s])color\s*:\s*(#[0-9a-fA-F]{6}|rgba?\([^)]*\))/g)) ut.text.add(m[1].toLowerCase());
  return ut;
};
const parFamiljer = new Set(tack.A_tackning.par.map(p => p.familj));
const darkOnly = new Set(tack.A_tackning.enbartDark.map(x => x.familj));
const lightOnly = tack.A_tackning.enbartLight;

const monster = new Map();
for (const lo of lightOnly) {
  const b = block.get(lo.art);
  if (!b) continue;
  const f = fargerI(b.text);
  const inv = alla.find(x => x.art === lo.art);
  const formfaktor = inv && inv.diagnostik.ramBredder.length ? inv.diagnostik.ramBredder[0] : 'panel';
  // Signaturen ar den sorterade fargpaletten plus formfaktorn.
  const nyckel = formfaktor + ' ‖ ytor:' + [...f.yta].sort().join(',') +
    ' ‖ ramar:' + [...f.ram].sort().join(',') + ' ‖ text:' + [...f.text].sort().join(',');
  if (!monster.has(nyckel)) monster.set(nyckel, []);
  monster.get(nyckel).push(lo.art);
}
// Grovare gruppering: bara paletten, oberoende av formfaktor.
const palettMonster = new Map();
for (const lo of lightOnly) {
  const b = block.get(lo.art); if (!b) continue;
  const f = fargerI(b.text);
  const nyckel = 'ytor:' + [...f.yta].sort().join(',');
  if (!palettMonster.has(nyckel)) palettMonster.set(nyckel, []);
  palettMonster.get(nyckel).push(lo.art);
}

/* ── 3 · FINNS ETT SYSTEMISKT TEMAKONTRAKT REDAN? ─────────────────────── */
const heleKallan = [...kallor.values()].join('\n');
const customProps = (heleKallan.match(/--[a-z][a-z0-9-]*\s*:/g) || []).length;
const varAnvandning = (heleKallan.match(/var\(--[a-z0-9-]+\)/g) || []).length;
const inlineStilar = (heleKallan.match(/style="/g) || []).length;
const klassregler = (heleKallan.match(/\.[a-z][a-z0-9-]*\s*\{/g) || []).length;
const hexTotalt = (heleKallan.match(/#[0-9a-fA-F]{6}\b/g) || []).length;
const hexUnika = new Set((heleKallan.match(/#[0-9a-fA-F]{6}\b/g) || []).map(x => x.toLowerCase())).size;
// Hur koncentrerad ar paletten? Om fa farger bar merparten ar den tokeniserbar.
const hexRakning = {};
for (const m of heleKallan.matchAll(/#[0-9a-fA-F]{6}\b/g)) { const k = m[0].toLowerCase(); hexRakning[k] = (hexRakning[k] || 0) + 1; }
const topp = Object.entries(hexRakning).sort((a, b) => b[1] - a[1]);
const topp20andel = +(100 * topp.slice(0, 20).reduce((n, x) => n + x[1], 0) / hexTotalt).toFixed(1);

/* ── 4 · VAD SKILJER DE NIO PAREN? ────────────────────────────────────── */
const parAnalys = tack.A_tackning.par.map(p => {
  const l = block.get(p.light), d = block.get(p.dark);
  if (!l || !d) return { familj: p.familj, fel: 'kallblock saknas' };
  const fl = fargerI(l.text), fd = fargerI(d.text);
  const skillnad = (a, b) => ({
    borta: [...a].filter(x => !b.has(x)), tillkomna: [...b].filter(x => !a.has(x)),
    gemensamma: [...a].filter(x => b.has(x)).length });
  // Ar markupen densamma? Jamfor taggskelettet utan attributvarden.
  const skelett = t => (t.match(/<[a-z][a-z0-9-]*/g) || []).join('>');
  return {
    familj: p.familj, light: p.light, dark: p.dark,
    samma_markupskelett: skelett(l.text) === skelett(d.text),
    langd_light: l.text.length, langd_dark: d.text.length,
    ytor: skillnad(fl.yta, fd.yta),
    ramar: skillnad(fl.ram, fd.ram),
    text: skillnad(fl.text, fd.text),
    kontroller_light: (l.text.match(/data-a11y-role="/g) || []).length,
    kontroller_dark: (d.text.match(/data-a11y-role="/g) || []).length,
  };
});
// Aterkommande transformationer over de nio paren.
const transform = new Map();
for (const p of parAnalys) {
  if (p.fel) continue;
  for (const slag of ['ytor', 'ramar', 'text'])
    for (const b of p[slag].borta) for (const t of p[slag].tillkomna) {
      const k = slag + ': ' + b + ' -> ' + t;
      if (!transform.has(k)) transform.set(k, new Set());
      transform.get(k).add(p.familj); }
}
const aterkommande = [...transform.entries()]
  .map(([k, v]) => ({ transform: k, familjer_st: v.size, familjer: [...v] }))
  .filter(x => x.familjer_st >= 2).sort((a, b) => b.familjer_st - a.familjer_st);

const doc = { $schema: 'butlery-r04-arkitektur/1',
  $regel: 'Analys utan andring. Ingen data-theme rors, ingen artefakt skapas, ingen farg andras.',
  matfallsgap: {
    artefakter_st: utanFall.length,
    produktartefakter_i_matfall: iProdukt.size,
    probe_st: [...iProbe].filter(x => !iProdukt.has(x)).length,
    harnessets_bredder: bredder,
    artefakter: utanFall.map(x => ({ art: x.art, etikett: x.skarmetikett, tema: x.tema,
      familj: x.familj, ramBredder: x.diagnostik.ramBredder,
      kontroller_st: x.diagnostik.kontroller_st,
      fil: (block.get(x.art) || {}).fil })),
  },
  lightOnly_monster: {
    familjer_st: lightOnly.length,
    monster_med_formfaktor_st: monster.size,
    monster_enbart_palett_st: palettMonster.size,
    storsta_monster: [...palettMonster.entries()].sort((a, b) => b[1].length - a[1].length)
      .slice(0, 12).map(([k, v]) => ({ artefakter_st: v.length, signatur: k.slice(0, 160), exempel: v.slice(0, 6) })),
  },
  temakontrakt: {
    css_custom_properties_st: customProps,
    var_anvandningar_st: varAnvandning,
    inline_stilattribut_st: inlineStilar,
    klassregler_st: klassregler,
    hexfarger_totalt: hexTotalt, hexfarger_unika: hexUnika,
    topp20_andel_procent: topp20andel,
    topp10: topp.slice(0, 10).map(([h, n]) => ({ hex: h, forekomster: n })),
  },
  parjamforelse: { par: parAnalys, aterkommande_transformationer: aterkommande },
  darkOnly: tack.A_tackning.enbartDark,
};
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('1 · MATFALLSGAP');
console.log('  artefakter utan matfall  ' + utanFall.length);
for (const x of doc.matfallsgap.artefakter)
  console.log('    ' + x.art.padEnd(20) + String(x.tema).padEnd(8) + 'ram ' + JSON.stringify(x.ramBredder).padEnd(8) +
    'kontroller ' + String(x.kontroller_st).padStart(3) + '  ' + JSON.stringify(x.etikett).slice(0, 46));
console.log('');
console.log('2 · DESIGNMONSTER BLAND ' + lightOnly.length + ' LIGHT-ONLY');
console.log('  monster med formfaktor   ' + monster.size);
console.log('  monster enbart palett    ' + palettMonster.size);
for (const m of doc.lightOnly_monster.storsta_monster.slice(0, 8))
  console.log('    ' + String(m.artefakter_st).padStart(4) + '  ' + m.exempel.join(', ').slice(0, 70));
console.log('');
console.log('3 · TEMAKONTRAKT I KALLAN');
console.log('  css custom properties    ' + customProps);
console.log('  var()-anvandningar       ' + varAnvandning);
console.log('  inline stilattribut      ' + inlineStilar);
console.log('  klassregler              ' + klassregler);
console.log('  hexfarger                ' + hexTotalt + ' totalt, ' + hexUnika + ' unika');
console.log('  topp 20 farger bar       ' + topp20andel + ' % av alla forekomster');
console.log('');
console.log('4 · DE NIO PAREN');
for (const p of parAnalys) console.log('  ' + p.familj.padEnd(32) +
  (p.samma_markupskelett ? 'samma skelett' : 'OLIKA skelett').padEnd(15) +
  'kontroller ' + p.kontroller_light + '/' + p.kontroller_dark);
console.log('  aterkommande transformationer i minst tva par: ' + aterkommande.length);
for (const t of aterkommande.slice(0, 10))
  console.log('    ' + String(t.familjer_st).padStart(2) + ' par  ' + t.transform.slice(0, 78));
