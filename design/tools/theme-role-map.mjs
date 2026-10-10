#!/usr/bin/env node
// F2-R04 · SEMANTISK ROLLKARTA FOR PILOTPOPULATIONEN.
//
// Kör: node tools/theme-role-map.mjs --pilot=<fil med artefakt-id> [--out=<fil>]
//
// INGEN ANDRING. Verktyget laser kallan och foreslar roller.
//
// EN ROLL AR EN FUNKTION, INTE ETT HEXVARDE.
//   Samma hex far delas i flera roller.
//   Olika hex far bara foras ihop nar funktionen faktiskt ar densamma.
//   Ingen token skapas bara for att flera artefakter delar hexvarde.
//
// Rollen harleds ur DEKLARATIONENS EGENSKAP och elementets funktion i
// markupen — inte ur fargen. En #e6ead9 som background pa en kortyta och en
// #e6ead9 som border pa en avdelare ar tva olika roller.

import { readdirSync, readFileSync, writeFileSync } from 'node:fs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const PILOT = arg('pilot'), OUT = arg('out');
if (!PILOT) { console.error('✖ ange --pilot=<fil>'); process.exit(2); }
const pilot = new Set(JSON.parse(readFileSync(PILOT, 'utf8')));

// Artefaktens egen kallblock.
const block = new Map();
for (const f of readdirSync('.').filter(x => x.endsWith('.dc.html'))) {
  const s = readFileSync(f, 'utf8');
  const pos = [...s.matchAll(/<div class="sc-item" id="([a-z0-9]+)"/g)];
  for (let i = 0; i < pos.length; i++)
    block.set(pos[i][1], { fil: f, text: s.slice(pos[i].index, i + 1 < pos.length ? pos[i + 1].index : s.length) });
}

/* ── Rollhärledning ────────────────────────────────────────────────────────
   Signalerna ar strukturella: vilken css-egenskap det ar, vilket element den
   sitter pa, och vad elementet gor i markupen.                              */
const roll = (egenskap, taggen, varde) => {
  const arKontroll = /data-a11y-role="/.test(taggen);
  const arSvg = /^<svg/.test(taggen);
  const arRam = /^border/.test(egenskap);
  const enSida = /^border-(top|bottom|left|right)\b/.test(egenskap);
  const arText = egenskap === 'color';
  const arYta = /^background/.test(egenskap);
  const arSkelett = /sc-skeleton|sc-loader/.test(taggen);
  const telefonram = /class="sc-phone"/.test(taggen);

  if (arSvg) return arKontroll ? 'ikon-kontroll' : 'ikon-fristaende';
  if (arText) return arKontroll ? 'text-kontroll' : 'text-innehall';
  if (arYta) {
    if (telefonram) return 'yta-app';
    if (arSkelett) return 'yta-platshallare';
    if (arKontroll) return 'yta-kontroll';
    return 'yta-upphojd';
  }
  if (arRam) {
    if (enSida) return 'ram-avdelare';
    return arKontroll ? 'ram-kontroll' : 'ram-behallare';
  }
  return 'ospecificerad';
};

const poster = [];
for (const id of pilot) {
  const b = block.get(id);
  if (!b) { console.log('✖ ' + id + ' finns inte i kallan'); process.exit(1); }
  // Varje taggs stilattribut, en deklaration i taget.
  for (const m of b.text.matchAll(/<[a-z][a-z0-9-]*[^>]*>/g)) {
    const taggen = m[0];
    const st = taggen.match(/style="([^"]*)"/);
    if (st) for (const decl of st[1].split(';')) {
      const d = decl.trim(); if (!d) continue;
      const kv = d.match(/^([a-z-]+)\s*:\s*(.+)$/); if (!kv) continue;
      const [, egenskap, varde] = kv;
      const farg = varde.match(/#[0-9a-fA-F]{6}|rgba?\([^)]*\)/);
      if (!farg) continue;
      poster.push({ art: id, fil: b.fil, egenskap, varde: farg[0].toLowerCase(),
        roll: roll(egenskap, taggen, farg[0]),
        taggstart: taggen.slice(0, 60) });
    }
    // svg-attribut
    for (const a of ['stroke', 'fill']) {
      const av = taggen.match(new RegExp(a + '="(#[0-9a-fA-F]{6})"'));
      if (av && /^<svg/.test(taggen))
        poster.push({ art: id, fil: b.fil, egenskap: a, varde: av[1].toLowerCase(),
          roll: roll('svg', taggen, av[1]), taggstart: taggen.slice(0, 60) });
    }
  }
}

const perRoll = new Map();
for (const p of poster) {
  if (!perRoll.has(p.roll)) perRoll.set(p.roll, []);
  perRoll.get(p.roll).push(p);
}

const karta = [...perRoll.entries()].sort((a, b) => b[1].length - a[1].length).map(([r, v]) => {
  const varden = {}; for (const p of v) varden[p.varde] = (varden[p.varde] || 0) + 1;
  const egenskaper = {}; for (const p of v) egenskaper[p.egenskap] = (egenskaper[p.egenskap] || 0) + 1;
  return { roll: r, deklarationer_st: v.length,
    artefakter_st: new Set(v.map(p => p.art)).size,
    ljusa_varden: Object.entries(varden).sort((a, b) => b[1] - a[1]).map(([h, n]) => ({ varde: h, forekomster: n })),
    egenskaper, artefakter: [...new Set(v.map(p => p.art))] };
});

// Motexempel: samma hexvarde i FLERA roller. Da far det inte bli en token.
const perVarde = new Map();
for (const p of poster) {
  if (!perVarde.has(p.varde)) perVarde.set(p.varde, new Set());
  perVarde.get(p.varde).add(p.roll);
}
const blandade = [...perVarde.entries()].filter(([, r]) => r.size > 1)
  .map(([v, r]) => ({ varde: v, roller: [...r] })).sort((a, b) => b.roller.length - a.roller.length);

const doc = { $schema: 'butlery-r04-rollkarta/1',
  $regel: 'En roll ar en funktion, inte ett hexvarde. Samma hex far delas i flera roller. Ingen token skapas bara for att flera artefakter delar hexvarde.',
  pilot_artefakter: [...pilot],
  deklarationer_st: poster.length,
  roller_st: karta.length,
  roller: karta,
  hexvarden_i_flera_roller: blandade,
  poster };
if (OUT) writeFileSync(OUT, JSON.stringify(doc, null, 1) + '\n');

console.log('ROLLKARTA · ' + pilot.size + ' artefakter · ' + poster.length + ' fargdeklarationer · ' + karta.length + ' roller');
console.log('');
for (const r of karta)
  console.log('  ' + r.roll.padEnd(20) + String(r.deklarationer_st).padStart(4) + ' dekl · ' +
    String(r.artefakter_st).padStart(2) + ' art · ' +
    r.ljusa_varden.slice(0, 4).map(v => v.varde + '×' + v.forekomster).join('  '));
console.log('');
console.log('HEXVARDEN SOM BAR FLERA ROLLER — far inte bli en enda token:');
for (const b of blandade) console.log('  ' + b.varde + '   ' + b.roller.join(', '));
