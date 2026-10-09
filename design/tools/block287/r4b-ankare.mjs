// KORRIGERINGSRUNDA 4b · ankare for de sista gruppmalen.
// De 21 malen ar semantiska objekt som remedieringen ska ge roll och namn.
// De ar inte dekor, sa de far det kanoniska ankaret - inte en fysisk delnyckel.
// Myntningen foljer exakt samma kontrakt som BL-01 (sha256 -> 12 bokstaver).
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { startTags } from '../bl01-kallskanner.mjs';
const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root'), TORR = process.argv.includes('--torr');
const G = JSON.parse(readFileSync(arg('grupper'), 'utf8'));
const IDX = JSON.parse(readFileSync(arg('index'), 'utf8'));

// B · frys den exakta malmangden innan nagon skrivning
const perMal = new Map();
for (const g of G.grupper) for (const t of g.TARGET_ELEMENTS) {
  if (t.TARGET_SOURCE_KEY) continue;
  const k = t.DEBUG_FRAME_ORD;
  if (!perMal.has(k)) perMal.set(k, { sign: t.ELEMENT_SIGNATURE, agare: t.SEMANTIC_OWNER, skal: t.TARGET_KEY_GRUND, krav: [] });
  if (!perMal.get(k).krav.includes(g.GROUP_REQUIREMENT_ID)) perMal.get(k).krav.push(g.GROUP_REQUIREMENT_ID);
}
const mal = [];
for (const [k, v] of perMal) {
  const [art, ord] = k.split('#');
  const traff = IDX.filter(x => x.art === art && String(x.ordProd) === ord);
  if (traff.length !== 1) throw new Error('flertydigt mal: ' + k + ' (' + traff.length + ' element)');
  mal.push({ e: traff[0], krav: v.krav, sign: v.sign, agare: v.agare, skal: v.skal });
}
if (new Set(mal.map(m => m.e.art + '#' + m.e.ordProd)).size !== mal.length) throw new Error('dubbletter i malmangden');

const filer = [...new Set(IDX.map(e => e.fil))];
const kalla = {};
const fanns = new Set();
for (const f of filer) {
  kalla[f] = readFileSync(ROT + '/' + f, 'utf8');
  for (const m of kalla[f].matchAll(/data-occurrence="(occ-[a-z]{12})"/g)) fanns.add(m[1]);
}
const BOK = 'abcdefghijklmnopqrstuvwxyz';
function mint(key) {
  for (let n = 0; n < 50; n++) {
    const h = createHash('sha256').update('BL01-ANCHOR|' + key + '|' + n).digest();
    let s = 'occ-'; for (let i = 0; i < 12; i++) s += BOK[h[i] % 26];
    if (!fanns.has(s)) { fanns.add(s); return s; }
  }
  throw new Error('kan inte mynta unikt ankare for ' + key);
}

const perFil = {};
const rader = [];
for (const m of mal) {
  const e = m.e;
  const nyckel = e.fil + '|' + e.art + '|' + e.tag + '|' + String(e.own || '').slice(0, 60);
  const ank = mint(nyckel);
  rader.push({ TARGET_ID: 'T4B::' + e.art + '#' + e.ordProd,
    SOURCE_FILE: e.fil, FRAME: e.art,
    SOURCE_ELEMENT: m.sign,
    SEMANTIC_OWNER: m.agare || 'sig sjalv',
    DEPENDENT_REQUIREMENT_IDS: m.krav,
    WHY_EXISTING_KEY_IS_INSUFFICIENT: m.skal || 'ingen semantisk agare i forfaderkedjan och ingen kallforfattad delnyckel',
    PROPOSED_DATA_OCCURRENCE: ank,
    DEBUG_DC_TPL: Number(e.tpl) });
  (perFil[e.fil] = perFil[e.fil] || []).push({ tpl: Number(e.tpl), ank });
}

let skrivna = 0;
for (const [f, lista] of Object.entries(perFil)) {
  const src = kalla[f];
  const tags = startTags(src);
  const punkter = lista.map(x => {
    const t = tags[x.tpl];
    if (!t) throw new Error('ingen starttagg for tpl ' + x.tpl + ' i ' + f);
    if (/data-occurrence=/.test(src.slice(t.start, t.tagEnd))) throw new Error('elementet bar redan ett ankare: ' + f + ' tpl ' + x.tpl);
    return { pos: t.nameEnd, text: ' data-occurrence="' + x.ank + '"' };
  }).sort((a, b) => b.pos - a.pos);
  let ut = src;
  for (const p of punkter) ut = ut.slice(0, p.pos) + p.text + ut.slice(p.pos);
  // Aterstallningsprov: tas de nya attributen bort ska filen bli byte for byte identisk.
  let ater = ut;
  for (const x of lista) ater = ater.replace(' data-occurrence="' + x.ank + '"', '');
  if (ater !== src) throw new Error('aterstallning ar inte byteidentisk for ' + f);
  if (TORR) { if (arg('utkast')) writeFileSync(arg('utkast') + '/' + f, ut); }
  else writeFileSync(ROT + '/' + f, ut);
  skrivna += punkter.length;
}
const ut = { $om: 'Korrigeringsrunda 4b · ankare for de sista gruppmalen',
  APPROVED_TARGET_COUNT: rader.length,
  AMBIGUOUS_TARGETS: 0,
  DUPLICATE_TARGETS: rader.length - new Set(rader.map(r => r.TARGET_ID)).size,
  DUPLICATE_ANCHOR_VALUES: rader.length - new Set(rader.map(r => r.PROPOSED_DATA_OCCURRENCE)).size,
  NEW_ANCHOR_COUNT: rader.length, FILES_TOUCHED: Object.keys(perFil).length,
  ANCHORS_WRITTEN: TORR ? 0 : skrivna, DRY_RUN: TORR,
  ANCHOR_VOCABULARY: 'data-occurrence (kanoniskt semantiskt objektankare)',
  MINT_CONTRACT: 'sha256("BL01-ANCHOR|" + fil|ram|tagg|text60 + "|" + n) -> occ- + 12 bokstaver',
  rader };
writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + '\n');
const { rader: _r, ...kort } = ut;
console.log(JSON.stringify(kort, null, 1));
