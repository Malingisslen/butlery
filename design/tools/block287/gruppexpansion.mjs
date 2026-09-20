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
import { kontrollFakta } from './omnyckla.mjs';
import * as SEM from '../semantic-owner-identity.mjs';
import { malnyckel } from './malnyckel.mjs';

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
// Kanonisk agarharledning: samma vag som populationen bygger sina agare.
if (arg('skord')) {
  const skord = j(arg('skord'));
  const etik = {};
  for (const e of IDX) if (!(e.art in etik)) etik[e.art] = '';
  const { fakta } = kontrollFakta({ skord, overlay: O, etikett: etik });
  for (const f of fakta) { f.objekt = SEM.narmasteAnkare(f.kedja); const r = SEM.semantiskAgare(f);
    if (r.nyckel && f.el) { const e = RAM.get(f.art + '#' + f.el.ordProd); if (e) reg(r.nyckel, e); } }
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


/* ── GR2: sammansatt namnuppslag ────────────────────────────────────────────
   Ett krav som saknar tillgangligt namn kan bara namnges av sin egen synliga
   text. Vi matchar darfor kravets namn mot elementets samlade texttrad,
   separatoroberoende, och valjer den tataste behallaren. Flertydighet faller
   stangt - vi gissar aldrig. */
const bar = s => String(s || '').replace(/-/g, '');
const perRamLista = new Map();
for (const e of IDX) { if (!perRamLista.has(e.art)) perRamLista.set(e.art, []); perRamLista.get(e.art).push(e); }
const textFormer = new Map();
for (const [a, lista] of perRamLista) {
  lista.sort((x, y) => x.ordProd - y.ordProd);
  for (const e of lista) {
    const bitar = lista.filter(x => x.ordProd === e.ordProd || (x.anc || []).includes(e.ordProd))
      .map(x => String(x.own || '').trim()).filter(Boolean);
    textFormer.set(a + '#' + e.ordProd, new Set([bar(stabilNamn(bitar.join(' '))), bar(stabilNamn(e.own))].filter(Boolean)));
  }
}
function viaSamladText(id) {
  const m = /::([a-z0-9-]+)::(?:namn|grupp|text)::(.+)$/.exec(String(id || ''));
  if (!m) return null;
  const namn = bar(m[2]);
  let kand = (perRamLista.get(m[1]) || []).filter(e => textFormer.get(m[1] + '#' + e.ordProd).has(namn));
  if (!kand.length && m[2].length >= 45)
    // Bade kravnamnet och den skordade texten kapas, pa olika langd. Nar den ena ar
    // prefix till den andra och prefixet ar langt nog ar traffen entydig.
    kand = (perRamLista.get(m[1]) || []).filter(e => [...textFormer.get(m[1] + '#' + e.ordProd)]
      .some(t => t.length >= 30 && (t.startsWith(namn) || namn.startsWith(t))));
  if (kand.length > 1) { const d = Math.max(...kand.map(e => (e.anc || []).length)); kand = kand.filter(e => (e.anc || []).length === d); }
  return kand.length === 1 ? kand[0] : null;
}


/* -- GR3: kallburna attribut som elementindexet inte bar --------------------
   data-state-group star i kallan men foljer inte med renderingsindexet.
   Vi laser det dar det star, och binder det till elementet via startTags. */
const statgrupp = new Map();
const annotRad = new Map();
{
  for (const f of [...new Set(IDX.map(e => e.fil))]) {
    const src = readFileSync(ROT + '/' + f, 'utf8');
    const tags = startTags(src);
    const tplEl2 = new Map(IDX.filter(e => e.fil === f).map(e => [Number(e.tpl), e]));
    for (let i = 0; i < tags.length; i++) {
      const huvud = src.slice(tags[i].start, tags[i].tagEnd);
      const m = /data-state-group="([^"]+)"/.exec(huvud);
      if (!m) continue;
      const e = tplEl2.get(i);
      if (!statgrupp.has(m[1])) statgrupp.set(m[1], []);
      statgrupp.get(m[1]).push({ fil: f, tpl: i, e: e || null, huvud });
    }
    // radintervall som ligger inne i ett data-conformance-scope="annotation"
    const rader = src.split(String.fromCharCode(10));
    let djup = -1; const set = new Set();
    for (let r = 0; r < rader.length; r++) {
      const l = rader[r];
      if (djup >= 0) { set.add(r + 1); djup += (l.match(/<div/g) || []).length - (l.match(/<\/div>/g) || []).length; if (djup < 0) djup = -1; }
      else if (/data-conformance-scope="annotation"/.test(l)) { djup = (l.match(/<div/g) || []).length - (l.match(/<\/div>/g) || []).length; set.add(r + 1); if (djup <= 0) djup = -1; }
    }
    annotRad.set(f, set);
  }
}
const radCache = {};
const kallRad = (f, r) => (radCache[f] || (radCache[f] = readFileSync(ROT + '/' + f, 'utf8').split(String.fromCharCode(10))))[r - 1] || '';
const ramFinns = new Set(IDX.map(e => e.art));
const REGELAV = t => /^textstorlek/.test(t) ? 'TYPE_SCALE' : /^radie/.test(t) ? 'RADIUS' : /vikt/.test(t) ? 'WEIGHT_UNDER_12'
  : /^pill/.test(t) ? 'PILL_BADGE_PADDING' : /^avatar/.test(t) ? 'AVATAR_SCALE' : /^chip/.test(t) ? 'CHIP_PADDING' : null;
/** Varfor en geometrirad inte kan peka ut nagot produktelement. */
function geoOmfang(regel, ram) {
  if (!ramFinns.has(ram)) return 'FRAME_NOT_IN_PRODUCT_SCOPE';
  const fyndar = SNAP.geo.filter(x => x.ram === ram && REGELAV(x.text) === regel);
  if (!fyndar.length) return 'NO_LINT_FINDING';
  const utanfor = fyndar.every(f => (annotRad.get(f.fil) || new Set()).has(f.rad) || /class="sc-(label|item)"|width:\s*\d{3,}px/.test(kallRad(f.fil, f.rad)));
  return utanfor ? 'OUT_OF_PRODUCT_SCOPE_ANNOTATION' : null;
}
/** Avatarer i en ram med exakt den uppmatta bredden. Formen kommer ur kallan, inte ur linten. */
function avatarer(ram, bredd) {
  return IDX.filter(e => e.art === ram && /border-radius:\s*(999px|50%)/.test(String(e.style || ''))
    && /font-size/.test(String(e.style || ''))
    && Number((/width:\s*([\d.]+)px/.exec(String(e.style || '')) || [, NaN])[1]) === bredd);
}


/** GR4: kravets egen evidens namnger det deklarerade elementet. */
function viaDeklarerat(u) {
  const ram = String(u.WRITE_OWNER || u.OWNER_ID || '').split('::').filter(x => /^[a-z0-9-]+$/.test(x))[0]
    || String(u.OWNER_ID || '').split('::')[1];
  const m = /deklarerat "([^"]+)"/.exec(String(u.CURRENT_EVIDENCE || ''));
  if (!ram || !m) return null;
  const kand = IDX.filter(e => e.art === ram && stabilNamn(e.name) === stabilNamn(m[1]));
  return kand.length === 1 ? kand[0] : null;
}
/** GR5: en grupp ags av minsta gemensamma forfader till sina medlemmar. */
function viaGruppbehallare(id) {
  const m = /::([a-z0-9-]+)::(?:grupp|namn)::(.+)$/.exec(String(id || ''));
  if (!m) return null;
  const lista = (perRamLista.get(m[1]) || []);
  const namn = bar(m[2]);
  // etikettelementet: dess egen text ar namnet, eller namnet ar en del av den
  const etiketter = lista.filter(e => { const t = bar(stabilNamn(e.own));
    return t && (t === namn || (t.length >= 4 && (namn.includes(t) || t.includes(namn)))); });
  if (!etiketter.length) return null;
  const pang = e => { const t = bar(stabilNamn(e.own)); return t === namn ? 0 : Math.abs(t.length - namn.length); };
  const et = etiketter.slice().sort((a, b) => pang(a) - pang(b) || a.ordProd - b.ordProd)[0];
  // Etiketten sitter granne med gruppen, men ibland ett steg ner. Vi klattrar
  // uppat tills nivan faktiskt bar medlemmar, och stannar vid forsta traffen.
  const nivaer = [];
  for (const foralder of (et.anc || [])) {
    const syskon = lista.filter(e => (e.anc || [])[0] === foralder && e.ordProd !== et.ordProd && !(e.anc || []).includes(et.ordProd));
    nivaer.push([foralder, syskon]);
  }
  // Forst nivaer med deklarerade medlemmar, annars nivaer med egna behallare.
  for (const [pass, valj] of [[0, e => e.comp || e.role], [1, e => lista.some(x => (x.anc || []).includes(e.ordProd))]])
  for (const [foralder, syskon] of nivaer) {
    const medlem = syskon.filter(valj);
    if (!medlem.length) continue;
    if (medlem.length === 1) return medlem[0];
    const gem = (medlem[0].anc || []).filter(o => medlem.every(x => (x.anc || []).includes(o)));
    const nca = gem.length ? Math.max(...gem) : null;
    const e = lista.find(x => x.ordProd === nca);
    if (e) return e;
  }
  return null;
}

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
  // Ett element kan bryta mot flera regler samtidigt. Forbrukningen far darfor
  // bara galla inom en och samma regel, aldrig over regelgranser.
  const anvandPerRegel = new Map();
  for (const fynd of SNAP.geo) {
    const regel = REGEL(fynd.text); if (!regel) continue;
    const F = perFil[fynd.fil]; if (!F) continue;
    const kand = (F.perRad[fynd.rad] || []).map(i => tplEl.get(fynd.fil + '|' + i)).filter(x => x && x.art === fynd.ram);
    const varde = (/[d.]+( × [d.]+)?/.exec(fynd.text) || [''])[0].replace(/ × /, 'x');
    if (!anvandPerRegel.has(regel)) anvandPerRegel.set(regel, new Set());
    const anvand = anvandPerRegel.get(regel);
    let vald = kand.find(x => !anvand.has(x.art + '#' + x.ordProd) && geometrifynd(x).some(y => y.REGEL === regel));
    if (!vald) vald = kand.find(x => !anvand.has(x.art + '#' + x.ordProd));
    if (!vald) continue;
    anvand.add(vald.art + '#' + vald.ordProd);
    const k = regel + '::' + fynd.ram; (geoPerRamRegel.get(k) || geoPerRamRegel.set(k, []).get(k)).push({ e: vald, VARDE: varde, LINT: fynd.text, RAD: fynd.rad });
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
  const mk = malnyckel(e, RAM);
  return Object.assign({
    SOURCE_FILE: kortFil(e.fil), FRAME: e.art,
    SOURCE_LOCATOR: w.id || ('OLOST: ' + w.grund),
    ELEMENT_SIGNATURE: '<' + e.tag + '>' + (e.role ? ' roll=' + e.role : '') + (e.name ? ' namn="' + e.name + '"' : '') + ' "' + String(e.own || e.text || '').slice(0, 40) + '"',
    SEMANTIC_OWNER: w.agare ? (w.agare === e ? 'sig sjalv' : w.agare.art + ' <' + w.agare.tag + '> "' + (w.agare.name || '') + '"') : null,
    // malnyckeln kan ge en ram som strukturell agare dar den aldre skrivnyckeln faller stangt
    WRITE_OWNER_ID: w.id || mk.WRITE_OWNER_ID || null,
    PART_METADATA_REQUIRED: mk.PART_METADATA_REQUIRED ? (mk.SKAL || true) : undefined,
    TARGET_SOURCE_KEY: mk.TARGET_SOURCE_KEY || null,
    TARGET_KEY_GRUND: mk.GRUND || mk.SKAL || null,
    TARGET_SOURCE_ELEMENT: '<' + e.tag + '> i ' + e.art + (e.partOcc ? ' [del ' + e.partOcc + ']' : ''),
    DEBUG_FRAME_ORD: e.art + '#' + e.ordProd, DEBUG_DC_TPL: e.tpl
  }, extra || {});
};

const grupper = [], terminala = [];
const olosta = [];
const ejExpanderade = [];
for (const u of POP) {
  if (u.CATEGORY !== 'PRODUCT_REMEDIATION_REQUIRED') continue;
  const fam = String(u.id).split('::')[1];
  const forvantat = u.OCCURRENCES || 1;
  let mal = [], kalla = null, omfang = null, utanforMedlemmar = 0;

  if (fam === 'GEOMETRY') {
    const m = /^RP::GEOMETRY::([A-Z_0-9]+)::(.+)$/.exec(u.id);
    const lista = m ? (geoPerRamRegel.get(m[1] + '::' + m[2]) || []) : [];
    kalla = 'tokens.json controls/typography via tools/block287/gruppexpansion.mjs';
    mal = lista.map(x => målrad(x.e, { CURRENT_VALUE: x.VARDE, REGEL: m[1] }));
    if (!mal.length && m && m[1] === 'AVATAR_SCALE') {
      // Lintens ogonblicksbild missar avatarer vars bakgrund blivit en var()-referens
      // efter R-04. Formen (rund, malad, med initial) star kvar i kallan och racker.
      const b = Number((/uppmatta varden ([\d.]+)/.exec(String(u.CURRENT_EVIDENCE)) || [, NaN])[1]);
      kalla = 'kallans avatarform + kravets egen uppmatta bredd (linten saknar fyndet)';
      mal = avatarer(m[2], b).map(e => målrad(e, { CURRENT_VALUE: String(b), REGEL: 'AVATAR_SCALE' }));
    }
    if (!mal.length && m) omfang = geoOmfang(m[1], m[2]);
    // Delvis utanfor omfanget: linten raknar hela ramen, produktomfanget bara produktdelen.
    if (m && mal.length && mal.length < forvantat) {
      const fyndar = SNAP.geo.filter(x => x.ram === m[2] && REGELAV(x.text) === m[1]);
      const kartlagda = new Set(lista.map(x => x.RAD));
      // bara fynd som INTE gav nagot element raknas som utanfor omfanget
      utanforMedlemmar = fyndar.filter(f => !kartlagda.has(f.rad))
        .filter(f => (annotRad.get(f.fil) || new Set()).has(f.rad)
          || /class="sc-(label|item)"|width:\s*\d{3,}px/.test(kallRad(f.fil, f.rad))).length;
    }
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
      // Evidensen namnger ocksa rotter i formen "ram roll:roll|Namn" - aven de ar mal.
      if (rot) for (const x of rot[1].matchAll(/([a-z0-9]+) roll:([a-z]+)\|(.+?) [\d.]+:1/g)) {
        const e2 = IDX.find(y => y.art === x[1] && y.role === x[2] && stabilNamn(y.name) === stabilNamn(x[3]));
        if (e2 && !delar.some(d => d === e2)) delar.push(e2);
      }
      mal = delar.map(e => målrad(e, {}));
    }
  } else if (fam === 'COMPONENT_BINDING') {
    kalla = 'enhetens ramlista + komponentens kontroll per ram';
    const ramar = (/ramar ([a-z0-9, ]+);/.exec(String(u.CURRENT_EVIDENCE)) || [, ''])[1].split(',').map(s => s.trim()).filter(Boolean);
    const hittaSkicka = a => IDX.find(e => e.art === a && e.role && /skicka|send/i.test(String(e.name) + ' ' + String(e.icon)))
      || IDX.find(e => e.art === a && /^send$/i.test(String(e.icon || '')));
    mal = ramar.map(hittaSkicka).filter(Boolean).map(e => målrad(e, {}));
  } else if (fam === 'STATE_GROUP') {
    kalla = 'kallans data-state-group';
    const g = (/([a-z0-9-]+) \(REJECTED\)/.exec(String(u.CURRENT_EVIDENCE)) || [])[1];
    mal = IDX.filter(e => e.art === u.OWNER_ID && String(e.style || '').includes(g)).map(e => målrad(e, {}));
    if (!mal.length) mal = IDX.filter(x => x.stateGroup === g).map(x => målrad(x, {}));
    if (!mal.length && statgrupp.has(g)) {
      kalla = 'kallans data-state-group (tools/bl01-kallskanner.mjs)';
      mal = statgrupp.get(g).map(x => x.e ? målrad(x.e, {})
        : { WRITE_OWNER_ID: null, TARGET_SOURCE_KEY: null, TARGET_SOURCE_ELEMENT: 'data-state-group="' + g + '" i ' + kortFil(x.fil),
            DEBUG_LOCATOR: x.fil + '|tpl' + x.tpl, CURRENT_VALUE: g, REQUIRED_VALUE: 'profil-synlighetsval' });
    }
  } else if (fam === 'STATE_WITHOUT_ROLE') {
    kalla = 'ogonblicksbildens A11Y-01-fynd';
    const a = (SNAP.a11y01 || []).filter(x => x.ram === String(u.OWNER_ID).split('::')[0]);
    mal = a.map(x => IDX.find(e => e.art === x.ram && stabilNamn(e.own) === stabilNamn(x.text))).filter(Boolean).map(e => målrad(e, {}));
    if (!mal.length) { const d = String(u.OWNER_ID || '').split('::');
      const e = viaSamladText(u.id) || (d.length === 2 ? viaSamladText('::' + d[0] + '::namn::' + d[1]) : null);
      if (e) { kalla = 'samlad texttrad i kallan (GR2)'; mal = [målrad(e, {})]; } }
  } else {
    let e = agarUppslag(u.PERSISTENT_OWNER_ID, u.id) || agarUppslag(u.OWNER_ID, u.id) || agarUppslag(u.id, u.id);
    kalla = 'agaruppslag mot kallans nyckelformer';
    if (!e) { e = viaSamladText(u.id) || viaSamladText(u.OWNER_ID); if (e) kalla = 'samlad texttrad i kallan (GR2)'; }
    if (!e) { e = viaDeklarerat(u); if (e) kalla = 'kravets egen evidens: deklarerat namn (GR4)'; }
    if (!e) { e = viaGruppbehallare(u.id); if (e) kalla = 'gruppens minsta gemensamma forfader i kallan (GR5)'; }
    if (e) mal = [målrad(e, {})];
  }
  const rad = { GROUP_REQUIREMENT_ID: u.id, GROUP_FAMILY: fam, TERMINAL_CLASS: (!mal.length && omfang) || null,
    FRAME: String(u.OWNER_ID || '').split('::')[0] || null,
    SOURCE_EVIDENCE_FILE: kalla, EXPECTED_MEMBER_COUNT: forvantat, RESOLVED_MEMBER_COUNT: mal.length,
    OUT_OF_SCOPE_MEMBER_COUNT: utanforMedlemmar || 0,
    FACET: u.REMEDIATION_FACET || null, TARGET_ELEMENTS: mal };
  grupper.push(rad);
  if (!mal.length && !omfang && fam === 'STATE_WITHOUT_ROLE') {
    // Linten ser hela ramen; produktomfanget ser bara produktdelen. Ett fynd vars
    // text inte finns nagonstans i produktindexet ligger utanfor omfanget.
    const a = (SNAP.a11y01 || []).filter(x => x.ram === String(u.OWNER_ID).split('::')[0]);
    if (a.length && a.every(x => !IDX.some(e => stabilNamn(e.own) === stabilNamn(x.text)))) {
      omfang = 'TARGET_OUTSIDE_PRODUCT_ELEMENT_INDEX'; rad.TERMINAL_CLASS = omfang;
    }
  }
  if (!mal.length && omfang) terminala.push(rad);
  else if (!mal.length) olosta.push(rad);
  else if (mal.length + (utanforMedlemmar || 0) !== forvantat)
    ejExpanderade.push({ id: u.id, forvantat, loste: mal.length, utanforOmfang: utanforMedlemmar || 0 });
}
const allaMal = grupper.flatMap(g => g.TARGET_ELEMENTS);
const dubbletter = allaMal.length - new Set(allaMal.map(m => m.DEBUG_FRAME_ORD + '|' + m.WRITE_OWNER_ID)).size;
const utanNyckel = allaMal.filter(m => !m.WRITE_OWNER_ID).length;
const ut = {
  $om: 'F-N · gruppexpansion till exakta kallelement',
  GROUP_REQUIREMENTS: grupper.length,
  UNRESOLVED_GROUP_REQUIREMENTS: olosta.length,
  TERMINAL_OUT_OF_SCOPE_ROWS: terminala.length,
  TERMINAL_PER_CLASS: terminala.reduce((o, g) => (o[g.TERMINAL_CLASS] = (o[g.TERMINAL_CLASS] || 0) + 1, o), {}),
  CARDINALITY_MISMATCH: ejExpanderade.length,
  MISSING_MEMBERS: ejExpanderade.filter(x => x.loste < x.forvantat).reduce((s, x) => s + (x.forvantat - x.loste), 0),
  EXTRA_MEMBERS: ejExpanderade.filter(x => x.loste > x.forvantat).reduce((s, x) => s + (x.loste - x.forvantat), 0),
  DUPLICATE_MEMBERS: dubbletter,
  OUT_OF_SCOPE_MEMBERS: grupper.reduce((n, g) => n + (g.OUT_OF_SCOPE_MEMBER_COUNT || 0), 0),
  EXPANDED_TARGET_OCCURRENCES: allaMal.length,
  MISSING_TARGET_SOURCE_ELEMENTS: utanNyckel,
  perFamilj: grupper.reduce((o, g) => (o[g.GROUP_FAMILY] = (o[g.GROUP_FAMILY] || 0) + 1, o), {}),
  MISMATCH: ejExpanderade, TERMINALA: terminala.map(g => ({ id: g.GROUP_REQUIREMENT_ID, klass: g.TERMINAL_CLASS })), OLOSTA: olosta.map(g => ({ id: g.GROUP_REQUIREMENT_ID, familj: g.GROUP_FAMILY, forvantat: g.EXPECTED_MEMBER_COUNT })),
  grupper
};
writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + '\n');
const { grupper: _g, ...kort } = ut;
console.log(JSON.stringify(kort, null, 1).slice(0, 2600));
