// Kor: node tools/block287/gruppexpansion.mjs --index=<idx.json> --population=<pop.json>
//      --snapshot=<snap.json> --overlay=<overlay.json> --mork=<mork.json> --ut=<fil.json>
// F-N · Expanderar varje grupprad till exakta kallelement.
// WRITE_OWNER_ID (vem ager skrivningen) och TARGET_SOURCE_ELEMENT (var deklarationen star)
// halls isar: ett grafiskt barn i en deklarerad kontroll ags av kontrollen men bar sin egen
// deklaration.
import { readFileSync, writeFileSync } from 'node:fs';
import { skrivnyckel, ramIndex, ankratObjekt, slug, stabilNamn, kortFil } from '../bl01-skrivnyckel.mjs';
import { HANDLINGAR, styrandeRegel, handoffNyckel, POLICY } from '../semantic-owner-identity.mjs';
import { startTags } from '../bl01-kallskanner.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const j = f => JSON.parse(readFileSync(f, 'utf8'));
const IDX = j(arg('index')), POP = j(arg('population')), SNAP = j(arg('snapshot'));
const O = j(arg('overlay')), MORK = j(arg('mork'));
const BYGGE = arg('bygge') ? j(arg('bygge')) : null;
const TOK = j(arg('tokens') || 'tokens.json');
const ROT = arg('root');
const RAM = ramIndex(IDX);
const el = (art, ord) => RAM.get(art + '#' + ord);
const byAnchor = new Map(IDX.filter(e => e.occ).map(e => [e.occ, e]));

/* ── agaruppslag: alla nyckelformer som nagon enhet kan bara ────────────── */
const agarEl = new Map();
const reg = (k, e) => { if (k && !agarEl.has(k)) agarEl.set(k, e); };
for (const e of IDX) {
  const a = e.art;
  if (e.occ) { reg('OWNER::' + a + '::objekt::' + e.occ, e); reg('OWNER::' + a + '::occ::' + e.occ, e); }
  if (e.elId) reg('OWNER::' + a + '::id::' + slug(e.elId), e);
  if (e.hit && /^target:/.test(e.hit)) reg('OWNER::' + a + '::hit-target::' + slug(e.hit.slice(7)), e);
  if (e.comp) reg('OWNER::' + a + '::komponent::' + slug(e.comp), e);
  if (e.icon) reg('OWNER::' + a + '::glyf::' + slug(e.icon), e);
  if (e.name) {
    reg('OWNER::' + a + '::namn::' + stabilNamn(e.name), e);
    reg('OWNER::' + a + '::grupp::' + stabilNamn(e.name), e);
    const h = HANDLINGAR[String(e.name).trim()];
    if (h) reg('OWNER::' + a + '::handling::' + h, e);
    reg('RV284::' + a + '::' + slug(e.name), e);
    reg('RV284::' + a + '::' + stabilNamn(e.name), e);
    // handoffmonstrets handling ar en namnoberoende nyckelform som aldre enheter kan bara
    try { const k = { art: a, namn: e.name, roll: e.role, glyf: e.icon, text: String(e.own || ''), iLista: false, ramEtikett: '' };
      if (styrandeRegel(k)) { const h = handoffNyckel(k); if (h && h.nyckel) reg('OWNER::' + h.nyckel, e); } } catch {}
    const fore = String(e.name).split(/[,:]/)[0].trim();
    if (fore !== e.name) { reg('RV284::' + a + '::' + slug(fore), e); reg('OWNER::' + a + '::namn::' + stabilNamn(fore), e); }
  }
  if (e.own && stabilNamn(e.own)) reg('OWNER::' + a + '::text::' + stabilNamn(e.own), e);
}
for (const p of Object.entries(O.forekomst)) {
  if (p[1].klass !== 'KNOWN_CONTROL' || !p[1].agare) continue;
  const m = /::([a-z0-9-]+)::(\d+)$/.exec(p[0]) || null;
  const bits = p[0].split('::'); const art = bits[2], ord = Number(bits[3]);
  const e = el(art, ord); if (e) reg(p[1].agare, e);
}
// AGARSTEG: varje ombyggd enhet bar ankaret till sitt agande element
const enhetAnkare = new Map();
if (BYGGE && BYGGE.AGARSTEG) for (const r of BYGGE.AGARSTEG.rader) if (r.ANKARE) enhetAnkare.set(r.TO, r.ANKARE);
const agarUppslag = (id, enhetId) => {
  if (enhetId && enhetAnkare.has(enhetId)) { const a = byAnchor.get(enhetAnkare.get(enhetId)); if (a) return a; }
  if (!id) return null;
  const rent = String(id);
  if (agarEl.has(rent)) return agarEl.get(rent);
  if (agarEl.has('OWNER::' + rent)) return agarEl.get('OWNER::' + rent);
  const m = rent.match(/occ-[a-z]{12}/);
  if (m && byAnchor.has(m[0])) return byAnchor.get(m[0]);
  return null;
};

/* ── geometrireglerna ur tokens (samma kontrakt som tools/lint-controls.mjs) ── */
const C = TOK.controls;
const RADIER = new Set(Object.values(TOK.space.radius));
const ROLLSTORLEKAR = new Set(Object.values(TOK.typography.roles).map(r => r.size));
const dec = st => { const o = {}; for (const d of String(st || '').split(';')) { const i = d.indexOf(':'); if (i < 0) continue; o[d.slice(0, i).trim().toLowerCase()] = d.slice(i + 1).trim().replace(/\s+/g, ' '); } return o; };
const px = (o, k) => { const m = /([\d.]+)px/.exec(o[k] || ''); return m ? parseFloat(m[1]) : null; };
function geometrifynd(e) {
  const ut = [];
  const st = e.style; if (!st) return ut;
  if (/data-lint-exempt/.test(String(st))) return ut;
  const o = dec(st);
  const w = px(o, 'width'), h = px(o, 'height'), r = px(o, 'border-radius');
  const fs = px(o, 'font-size'), fw = parseInt(o['font-weight'] || '0', 10);
  // avatarregeln maste se beraknad farg: efter R-04-migreringen ar color en var()-referens
  const arAvatar = w !== null && w === h && (r === 999 || /50%/.test(o['border-radius'] || '')) &&
    !!(o.background || o['background-color']) && !!(o.color || e.fgC) && fs !== null;
  if (arAvatar && !C.avatarScale.includes(w)) ut.push({ REGEL: 'AVATAR_SCALE', VARDE: String(w) });
  const arCheckbox = e.comp === 'checkbox';
  if (r !== null && !RADIER.has(r) && !arAvatar && !(r === C.checkbox.radius && arCheckbox)) ut.push({ REGEL: 'RADIUS', VARDE: String(r) });
  const pad = /padding:\s*([\d.]+)px\s+([\d.]+)px/.exec(st);
  if (fs === 10.5 && fw === 700 && pad) {
    const y = Number(pad[1]), x = Number(pad[2]);
    const okPill = y === C.statusPill.paddingY && x === C.statusPill.paddingX;
    const okBadge = y === C.badge.paddingY && x === C.badge.paddingX;
    if (!okPill && !okBadge) ut.push({ REGEL: 'PILL_BADGE_PADDING', VARDE: y + 'x' + x });
  }
  if (e.comp === 'chip' && pad) {
    const y = Number(pad[1]), x = Number(pad[2]);
    const okFull = y === C.chip.paddingY && x === C.chip.paddingX;
    const okKompakt = y === C.chipCompactInField.paddingY && x === C.chipCompactInField.paddingX;
    if (!okFull && !okKompakt) ut.push({ REGEL: 'CHIP_PADDING', VARDE: y + 'x' + x });
  }
  if (fs !== null && !ROLLSTORLEKAR.has(fs)) ut.push({ REGEL: 'TYPE_SCALE', VARDE: String(fs) });
  if (fs !== null && fs < 12 && (!fw || fw < 600)) ut.push({ REGEL: 'WEIGHT_UNDER_12', VARDE: fs + 'px/' + (fw || 400) });
  return ut;
}
const geoPerRamRegel = new Map();
{
  // Kanonisk evidens: lintens egna fynd i ogonblicksbilden, mappade till element via kallskannern.
  const perFil = {};
  for (const f of [...new Set(IDX.map(e => e.fil))]) {
    const src = readFileSync(ROT + '/' + f, 'utf8');
    const tags = startTags(src);
    const rader = src.split(String.fromCharCode(10)); const radStart = []; let p = 0;
    for (const l of rader) { radStart.push(p); p += l.length + 1; }
    const perRad = {};
    for (let i = 0; i < tags.length; i++) { const t = tags[i];
      let lo = 0, hi = radStart.length - 1, rad = 0;
      while (lo <= hi) { const m = (lo + hi) >> 1; if (radStart[m] <= t.start) { rad = m; lo = m + 1; } else hi = m - 1; }
      (perRad[rad + 1] = perRad[rad + 1] || []).push(i); }
    perFil[f] = { perRad, tags };
  }
  const tplEl = new Map(IDX.map(e => [e.fil + '|' + e.tpl, e]));
  const REGEL = t => /^textstorlek/.test(t) ? 'TYPE_SCALE' : /^radie/.test(t) ? 'RADIUS' : /vikt/.test(t) ? 'WEIGHT_UNDER_12'
    : /^pill/.test(t) ? 'PILL_BADGE_PADDING' : /^avatar/.test(t) ? 'AVATAR_SCALE' : /^chip/.test(t) ? 'CHIP_PADDING' : null;
  const anvand = new Set();
  for (const fynd of SNAP.geo) {
    const regel = REGEL(fynd.text); if (!regel) continue;
    const F = perFil[fynd.fil]; if (!F) continue;
    const kand = (F.perRad[fynd.rad] || []).map(i => tplEl.get(fynd.fil + '|' + i)).filter(x => x && x.art === fynd.ram);
    const varde = (/[d.]+( × [d.]+)?/.exec(fynd.text) || [''])[0].replace(/ × /, 'x');
    let vald = kand.find(x => !anvand.has(x.art + '#' + x.ordProd) && geometrifynd(x).some(y => y.REGEL === regel));
    if (!vald) vald = kand.find(x => !anvand.has(x.art + '#' + x.ordProd));
    if (!vald) continue;
    anvand.add(vald.art + '#' + vald.ordProd);
    const k = regel + '::' + fynd.ram; (geoPerRamRegel.get(k) || geoPerRamRegel.set(k, []).get(k)).push({ e: vald, VARDE: varde, LINT: fynd.text });
  }
}

/* ── morka sekundartexter (M1) ──────────────────────────────────────────── */
const morkBarn = MORK.map(x => el(x.art, x.ordProd)).filter(Boolean);

/* ── expansion per familj ───────────────────────────────────────────────── */
const skrivnyckelFor = e => {
  const nk = skrivnyckel(e, RAM);
  if (nk.NIVA !== 0) return { id: nk.WRITE_OWNER_ID, grund: nk.GRUND, agare: e };
  let p = null; for (const o of e.anc || []) { const q = el(e.art, o); if (q && q.role) { p = q; break; } }
  if (!p) return { id: null, grund: nk.GRUND, agare: null };
  const pk = skrivnyckel(p, RAM);
  return { id: pk.WRITE_OWNER_ID, grund: 'agande kontroll: ' + pk.GRUND, agare: p };
};
const målrad = (e, extra) => {
  const w = skrivnyckelFor(e);
  return Object.assign({
    SOURCE_FILE: kortFil(e.fil), FRAME: e.art,
    SOURCE_LOCATOR: w.id || ('OLOST: ' + w.grund),
    ELEMENT_SIGNATURE: '<' + e.tag + '>' + (e.role ? ' roll=' + e.role : '') + (e.name ? ' namn="' + e.name + '"' : '') + ' "' + String(e.own || e.text || '').slice(0, 40) + '"',
    SEMANTIC_OWNER: w.agare ? (w.agare === e ? 'sig sjalv' : w.agare.art + ' <' + w.agare.tag + '> "' + (w.agare.name || '') + '"') : null,
    WRITE_OWNER_ID: w.id,
    TARGET_SOURCE_ELEMENT: 'EL::' + kortFil(e.fil) + '::' + (e.occ ? 'occ::' + e.occ : e.art + '::del::' + (e.icon ? 'glyf-' + slug(e.icon) : stabilNamn(e.own) ? 'etikett-' + stabilNamn(e.own) : 'ruta')),
    DEBUG_FRAME_ORD: e.art + '#' + e.ordProd, DEBUG_DC_TPL: e.tpl
  }, extra || {});
};

const grupper = [];
const olosta = [];
const ejExpanderade = [];
for (const u of POP) {
  if (u.CATEGORY !== 'PRODUCT_REMEDIATION_REQUIRED') continue;
  const fam = String(u.id).split('::')[1];
  const forvantat = u.OCCURRENCES || 1;
  let mal = [], kalla = null;

  if (fam === 'GEOMETRY') {
    const m = /^RP::GEOMETRY::([A-Z_0-9]+)::(.+)$/.exec(u.id);
    const lista = m ? (geoPerRamRegel.get(m[1] + '::' + m[2]) || []) : [];
    kalla = 'tokens.json controls/typography via tools/block287/gruppexpansion.mjs';
    mal = lista.map(x => målrad(x.e, { CURRENT_VALUE: x.VARDE, REGEL: m[1] }));
  } else if (fam === 'DARK_BORDER') {
    kalla = 'fas2/matning/kanter.json via enhetens evidens';
    const delar = [...String(u.CURRENT_EVIDENCE).matchAll(/([a-z0-9]+)#(\d+)/g)].map(x => el(x[1], Number(x[2]))).filter(Boolean);
    mal = delar.map(e => målrad(e, { REQUIRED_VALUE: u.BORDER_TOKEN || null }));
  } else if (fam === 'DARK_MODE') {
    if (/yta-kontroll::sekundartext$/.test(u.id)) {
      kalla = 'pastvingad mork matning (tools/bl01-morkprob.mjs)';
      mal = morkBarn.map(e => målrad(e, { CURRENT_VALUE: 'rgb(147,164,141) pa rgb(74,92,67)', REQUIRED_VALUE: 'text.bodyMuted #C9D3C4' }));
    } else {
      kalla = 'fas2/matning/r04-kandidat.json via enhetens rotter';
      const rot = /rotter:\s*(.+)$/s.exec(String(u.CURRENT_EVIDENCE));
      const delar = rot ? [...rot[1].matchAll(/([a-z0-9]+)#(\d+)/g)].map(x => el(x[1], Number(x[2]))).filter(Boolean) : [];
      mal = delar.map(e => målrad(e, {}));
    }
  } else if (fam === 'COMPONENT_BINDING') {
    kalla = 'enhetens ramlista + komponentens kontroll per ram';
    const ramar = (/ramar ([a-z0-9, ]+);/.exec(String(u.CURRENT_EVIDENCE)) || [, ''])[1].split(',').map(s => s.trim()).filter(Boolean);
    mal = ramar.map(a => IDX.find(e => e.art === a && e.role && /skicka|send/i.test(String(e.name) + ' ' + String(e.icon)))).filter(Boolean).map(e => målrad(e, {}));
  } else if (fam === 'STATE_GROUP') {
    kalla = 'kallans data-state-group';
    const g = (/([a-z0-9-]+) \(REJECTED\)/.exec(String(u.CURRENT_EVIDENCE)) || [])[1];
    mal = IDX.filter(e => e.art === u.OWNER_ID && String(e.style || '').includes(g)).map(e => målrad(e, {}));
    if (!mal.length) mal = IDX.filter(x => x.stateGroup === g).map(x => målrad(x, {}));
  } else if (fam === 'STATE_WITHOUT_ROLE') {
    kalla = 'ogonblicksbildens A11Y-01-fynd';
    const a = (SNAP.a11y01 || []).filter(x => x.ram === String(u.OWNER_ID).split('::')[0]);
    mal = a.map(x => IDX.find(e => e.art === x.ram && stabilNamn(e.own) === stabilNamn(x.text))).filter(Boolean).map(e => målrad(e, {}));
  } else {
    const e = agarUppslag(u.OWNER_ID, u.id) || agarUppslag(u.id, u.id);
    kalla = 'agaruppslag mot kallans nyckelformer';
    if (e) mal = [målrad(e, {})];
  }
  const rad = { GROUP_REQUIREMENT_ID: u.id, GROUP_FAMILY: fam, FRAME: String(u.OWNER_ID || '').split('::')[0] || null,
    SOURCE_EVIDENCE_FILE: kalla, EXPECTED_MEMBER_COUNT: forvantat, RESOLVED_MEMBER_COUNT: mal.length,
    FACET: u.REMEDIATION_FACET || null, TARGET_ELEMENTS: mal };
  grupper.push(rad);
  if (!mal.length) olosta.push(rad);
  else if (mal.length !== forvantat) ejExpanderade.push({ id: u.id, forvantat, loste: mal.length });
}
const allaMal = grupper.flatMap(g => g.TARGET_ELEMENTS);
const dubbletter = allaMal.length - new Set(allaMal.map(m => m.DEBUG_FRAME_ORD + '|' + m.WRITE_OWNER_ID)).size;
const utanNyckel = allaMal.filter(m => !m.WRITE_OWNER_ID).length;
const ut = {
  $om: 'F-N · gruppexpansion till exakta kallelement',
  GROUP_REQUIREMENTS: grupper.length,
  UNRESOLVED_GROUP_REQUIREMENTS: olosta.length,
  CARDINALITY_MISMATCH: ejExpanderade.length,
  MISSING_MEMBERS: ejExpanderade.filter(x => x.loste < x.forvantat).reduce((s, x) => s + (x.forvantat - x.loste), 0),
  EXTRA_MEMBERS: ejExpanderade.filter(x => x.loste > x.forvantat).reduce((s, x) => s + (x.loste - x.forvantat), 0),
  DUPLICATE_MEMBERS: dubbletter,
  EXPANDED_TARGET_OCCURRENCES: allaMal.length,
  MISSING_TARGET_SOURCE_ELEMENTS: utanNyckel,
  perFamilj: grupper.reduce((o, g) => (o[g.GROUP_FAMILY] = (o[g.GROUP_FAMILY] || 0) + 1, o), {}),
  MISMATCH: ejExpanderade, OLOSTA: olosta.map(g => ({ id: g.GROUP_REQUIREMENT_ID, familj: g.GROUP_FAMILY, forvantat: g.EXPECTED_MEMBER_COUNT })),
  grupper
};
writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + '\n');
const { grupper: _g, ...kort } = ut;
console.log(JSON.stringify(kort, null, 1).slice(0, 2600));
