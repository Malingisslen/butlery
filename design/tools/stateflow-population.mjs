#!/usr/bin/env node
// BUTLERY · BLOCK 282 · STATE/FLOW-POPULATIONEN.  READ-ONLY BYGGARE.
//
// Skriver ingenting i produkten. Ingen dom fälls. Ingen state skapas.
//
// KANONISK INDATA: fas2/stateflow-mappning.json — maskinläsbar.
// HTML-rapporter är ALDRIG indata. Beslut läses aldrig ur minnet.
//
// IDENTITETSKONTRAKT
//   MAP::nnn              regel. Numret är positionen i källans regler[] och
//                         får aldrig omnumreras. En splittrad regel behåller
//                         sin plats som icke-klassificerande platshållare.
//   MAP::nnn::<skärm-id>  barnregel: förälderns id + skärmens authored id.
//                         Aldrig position, målvy, färg eller geometri.
//   VIEW/FLOW/FSR/ROLE/CSR/TR/COF — authored id.
//
// Kollision, oväntad grund eller beslut som inte stämmer med källan
// => FAIL CLOSED (kastar).
//
// Kör:  node tools/stateflow-population.mjs [--root=.] [--detalj=map|fsr|csr|cof|tr|skarm]
//       node tools/stateflow-population.mjs --emit-kalla=<fil>   (skriver om källan)

import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const ROOT = arg('root') || '.';
const R = p => readFileSync(join(ROOT, p), 'utf8');
const KALLA = 'fas2/stateflow-mappning.json';
const K = JSON.parse(R(KALLA));
if (K.$schema !== 'butlery-stateflow-mappning/1')
  throw new Error('FAIL CLOSED: okänt schema i ' + KALLA + ': ' + K.$schema);

const SCREEN_FILES = R('tools/screen-files.mjs')
  .split('export const SCREEN_FILES')[1].split('];')[0]
  .split('\n').map(l => (/'([^']+\.dc\.html)'/.exec(l) || [])[1]).filter(Boolean);
if (SCREEN_FILES.length !== 14) throw new Error('FAIL CLOSED: väntade 14 skärmfiler, fick ' + SCREEN_FILES.length);

/* ── A · NORMATIVA VYER ur testmatris.md § 1 ────────────────────────────── */
const tmSec = R('testmatris.md').split(/^## /m).find(s => s.startsWith('1. Tillstånd per vy'));
if (!tmSec) throw new Error('FAIL CLOSED: testmatris.md § 1 hittades inte');
const tmRows = tmSec.split('\n').filter(l => /^\|/.test(l) && !/^\|\s*---/.test(l));
const STATES = tmRows[0].split('|').slice(2, -1).map(s => s.trim().toUpperCase());
const VIEWS = tmRows.slice(1).map(r => {
  const c = r.split('|').slice(1, -1).map(s => s.trim());
  const slug = c[0].toLowerCase().replace(/[^a-zåäö0-9]+/g, '-').replace(/^-|-$/g, '');
  const krav = {};
  STATES.forEach((st, i) => { krav[st] = c[i + 1] === '✔' ? 'REQUIRED' : c[i + 1] === '–' ? 'NOT_APPLICABLE' : 'UNKNOWN'; });
  return { id: 'VIEW::' + slug, slug, namn: c[0], krav };
});
if (new Set(VIEWS.map(v => v.id)).size !== VIEWS.length) throw new Error('FAIL CLOSED: vy-id-kollision');
const VY = Object.fromEntries(VIEWS.map(v => [v.slug, v.id]));

/* ── B · FLÖDEN OCH ÖVERGÅNGAR ─────────────────────────────────────────── */
const fr = R('flows-roles-budget.md');
const FLOWS = [], TRANSITIONS = [];
for (const s of fr.split(/^## /m).filter(s => /^\d\d · /.test(s))) {
  const rubrik = s.split('\n')[0], nr = rubrik.slice(0, 2);
  const rows = s.split('\n').filter(l => /^\|/.test(l) && !/^\|\s*---/.test(l));
  const head = rows.length ? rows[0].split('|').slice(1, -1).map(x => x.trim()) : [];
  const overgangstabell = head[0] === 'Från' && head[1] === 'Händelse' && head[2] === 'Till';
  FLOWS.push({ id: 'FLOW::' + nr, nr, namn: rubrik.slice(5).trim(),
    tabellrader: rows.slice(1).length, overgangstabell });
  if (!overgangstabell) continue;
  for (const r of rows.slice(1)) {
    const c = r.split('|').slice(1, -1).map(x => x.replace(/[`*]/g, '').trim());
    const sl = t => t.toLowerCase().replace(/[^a-zåäö0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 44);
    TRANSITIONS.push({ id: 'TR::FLOW::' + nr + '::' + sl(c[0]) + '::' + sl(c[1]),
      flow: 'FLOW::' + nr, fran: c[0], handelse: c[1], till: c[2],
      skarmref: [...(c[3] || c[2] || '').matchAll(/#([a-z0-9]+)/g)].map(m => m[1]) });
  }
}
{
  const ids = TRANSITIONS.map(t => t.id);
  const dup = ids.filter((v, i) => ids.indexOf(v) !== i);
  if (dup.length) throw new Error('FAIL CLOSED: övergångskollision ' + [...new Set(dup)].join(', '));
}

/* ── C · SKÄRMKORPUSEN ─────────────────────────────────────────────────── */
const SCREENS = [];
for (const f of SCREEN_FILES) {
  const s = R(f);
  const idx = [...s.matchAll(/<div class="sc-item" id="([^"]+)"([^>]*)>/g)];
  for (let i = 0; i < idx.length; i++) {
    const m = idx[i];
    const blk = s.slice(m.index, i + 1 < idx.length ? idx[i + 1].index : s.length);
    const lm = /data-screen-label="([^"]*)"/.exec(m[2]);
    if (!lm) throw new Error('FAIL CLOSED: ' + m[1] + ' saknar data-screen-label');
    const pm = /class="sc-label"[^>]*>([\s\S]{0,900}?)<\/div>/.exec(blk);
    SCREENS.push({ id: m[1], fil: f,
      etikett: lm[1].replace(/&amp;/g, '&'),
      prosa: (pm ? pm[1] : '').replace(/<[^>]*>/g, ' ').replace(/&amp;/g, '&').replace(/\s+/g, ' ').trim(),
      grupper: [...blk.matchAll(/data-state-group="([^"]+)"/g)].map(x => x[1]),
      skelett: /sc-skeleton/.test(blk), laddare: /sc-loader/.test(blk),
      retry: /Försök igen/.test(blk),
      offlinemarkor: /wifi-off|Ingen anslutning|[Oo]ffline|[Ff]rånkopplat/.test(blk) });
  }
}
{
  const ids = SCREENS.map(x => x.id);
  const dup = ids.filter((v, i) => ids.indexOf(v) !== i);
  if (dup.length) throw new Error('FAIL CLOSED: skärm-id-kollision ' + [...new Set(dup)].join(', '));
}

/* ── D · REGLERNA ur den kanoniska källan ──────────────────────────────── */
const ANKARE = K.ankarlexikon;
const norm = s => s.toLowerCase().replace(/[^a-zåäö0-9]/g, '');
const prefixAv = t => t.split(/\s+[—·]\s+/)[0].trim();
const vyNamnAv = mal => mal === 'RAM' ? '(ram, ingen vy)'
  : mal === 'SPLIT' ? '(splittrad, klassificerar inget)'
  : (VIEWS.find(v => v.slug === mal) || {}).namn;

const REGLER = K.regler.map((r, i) => {
  const vantat = 'MAP::' + String(i + 1).padStart(3, '0');
  if (r.id !== vantat)
    throw new Error('FAIL CLOSED: regel på position ' + (i + 1) + ' bär id ' + r.id +
      ' men positionen ger ' + vantat + ' — källan har omnumrerats');
  return { ...r, parent: null, matchning: 'PREFIX', skarmId: null,
    grundMaskinKalla: r.grundMaskin === undefined ? null : r.grundMaskin,
    vy: (r.mal === 'RAM' || r.mal === 'SPLIT') ? null : VY[r.mal],
    vyNamn: vyNamnAv(r.mal), splittrad: r.mal === 'SPLIT', skarmar: [] };
});
for (const b of K.barnregler) {
  const p = REGLER.find(r => r.id === b.parent);
  if (!p) throw new Error('FAIL CLOSED: barnregel utan förälder: ' + b.parent);
  if (!p.splittrad) throw new Error('FAIL CLOSED: ' + b.parent + ' är inte markerad SPLIT');
  if (b.id !== b.parent + '::' + b.skarmId)
    throw new Error('FAIL CLOSED: barn-id ' + b.id + ' följer inte kontraktet förälder::skärm-id');
  REGLER.push({ ...b, matchning: 'SKARM', prefix: p.prefix,
    grundMaskinKalla: b.grundMaskin === undefined ? null : b.grundMaskin,
    vy: b.mal === 'RAM' ? null : VY[b.mal], vyNamn: vyNamnAv(b.mal),
    splittrad: false, skarmar: [] });
}
for (const r of REGLER)
  if (r.mal !== 'RAM' && r.mal !== 'SPLIT' && !r.vy)
    throw new Error('FAIL CLOSED: okänd vy-slug ' + r.mal + ' i ' + r.id);
{
  const ids = REGLER.map(r => r.id);
  const dup = ids.filter((v, i) => ids.indexOf(v) !== i);
  if (dup.length) throw new Error('FAIL CLOSED: regel-id-kollision: ' + [...new Set(dup)].join(', '));
  const p = REGLER.filter(r => r.matchning === 'PREFIX' && !r.splittrad).map(r => r.prefix);
  const pd = p.filter((v, i) => p.indexOf(v) !== i);
  if (pd.length) throw new Error('FAIL CLOSED: två regler delar prefix: ' + [...new Set(pd)].join(', '));
  const sk = REGLER.filter(r => r.matchning === 'SKARM').map(r => r.skarmId);
  const sd = sk.filter((v, i) => sk.indexOf(v) !== i);
  if (sd.length) throw new Error('FAIL CLOSED: två barnregler delar skärm: ' + [...new Set(sd)].join(', '));
}
const regelAvId = new Map(REGLER.map(r => [r.id, r]));

/* Matchning. Splittrad förälder matchar aldrig. Skärm-id och prefix prövas
 * BÅDA, så att en dubbelträff upptäcks i stället för att tystas av precedens. */
for (const s of SCREENS) {
  s.prefix = prefixAv(s.etikett);
  const traffar = REGLER.filter(r =>
    !r.splittrad && (r.matchning === 'SKARM' ? r.skarmId === s.id : r.prefix === s.prefix));
  s.traffar = traffar.map(r => r.id);
  if (traffar.length > 1)
    throw new Error('FAIL CLOSED: ' + s.id + ' träffar flera regler: ' + s.traffar.join(', '));
  const r = traffar[0] || null;
  s.regel = r ? r.id : null;
  s.vy = r && r.mal !== 'RAM' ? r.vy : null;
  s.ram = !!(r && r.mal === 'RAM');
  if (r) r.skarmar.push(s.id);
}
const OMAPPADE = SCREENS.filter(s => !s.regel);

/* Varje splittrad förälders barn måste täcka exakt förälderns population. */
for (const p of REGLER.filter(r => r.splittrad)) {
  const barn = REGLER.filter(r => r.parent === p.id).flatMap(r => r.skarmar).sort();
  const viaPrefix = SCREENS.filter(s => s.prefix === p.prefix).map(s => s.id).sort();
  if (JSON.stringify(barn) !== JSON.stringify(viaPrefix))
    throw new Error('FAIL CLOSED: barnen till ' + p.id + ' täcker inte förälderns population');
}

/* Grund räknas ut ur källtexten — deklareras aldrig. */
for (const r of REGLER) {
  const skarmar = SCREENS.filter(x => x.regel === r.id);
  r.antal = skarmar.length;
  if (r.splittrad) { r.grundMaskin = 'SPLITTRAD'; r.ankare = []; }
  else if (r.mal === 'RAM') { r.grundMaskin = 'RAM_DEKLARERAD'; r.ankare = []; }
  else {
    const vn = norm(r.vyNamn), pn = norm(r.prefix);
    const direkt = r.matchning === 'PREFIX' && (vn.includes(pn) || pn.includes(vn));
    const lex = ANKARE[r.mal] || [];
    const txt = s => (s.etikett + ' ' + s.prosa).toLowerCase();
    r.ankare = [...new Set(skarmar.flatMap(s => lex.filter(w => txt(s).includes(w))))].sort();
    const allaAnkrade = skarmar.length > 0 && skarmar.every(s => lex.some(w => txt(s).includes(w)));
    r.grundMaskin = direkt ? 'DIREKT' : (allaAnkrade ? 'ANKRAD' : 'BEDOMNING');
  }
  r.grund = r.grundMaskin;
  r.annan_regel_kan_traffa = 'NEJ — prefixregler matchar exakt prefixlikhet, barnregler exakt skärm-id; båda mängderna är dubblettfria och prövas tillsammans';
}

/* Emittera källan om den ska skrivas om — innan besluten tillämpas. */
const emit = arg('emit-kalla');
if (emit) {
  const ut = { ...K,
    regler: REGLER.filter(r => !r.parent).map(r => ({ id: r.id, prefix: r.prefix, mal: r.mal,
      skal: r.skal, gammaltMal: r.gammaltMal || null, grundMaskin: r.grundMaskin, beslut: r.beslut || null })),
    barnregler: REGLER.filter(r => r.parent).map(r => ({ id: r.id, parent: r.parent,
      skarmId: r.skarmId, mal: r.mal, skal: r.skal, gammaltMal: r.gammaltMal || null,
      grundMaskin: r.grundMaskin, beslut: r.beslut || null })) };
  writeFileSync(emit, JSON.stringify(ut, null, 1) + '\n');
  console.log('källa skriven: ' + emit);
  process.exit(0);
}

/* Besluten. Varje beslut prövas mot verkligheten innan det gäller. */
for (const r of REGLER) {
  // Grunden som maskinen räknade fram MÅSTE stämma med den som källan säger
  // gällde när beslutet fattades. Annars har underlaget ändrats under beslutet.
  if (r.grundMaskin && r.grundMaskin !== undefined && K.regler.length && r.grundMaskinKalla !== undefined
      && r.grundMaskin !== r.grundMaskinKalla)
    throw new Error('FAIL CLOSED: ' + r.id + ' beräknas nu som ' + r.grundMaskin +
      ' men källan registrerade beslutet mot ' + r.grundMaskinKalla);
  if (!r.beslut) continue;
  if (r.beslut !== 'HUMAN_APPROVED')
    throw new Error('FAIL CLOSED: okänd beslutstyp ' + r.beslut + ' i ' + r.id);
  if (r.gammaltMal) {
    if (r.gammaltMal !== 'RAM' && !VY[r.gammaltMal])
      throw new Error('FAIL CLOSED: okänt tidigare mål ' + r.gammaltMal + ' i ' + r.id);
    if (r.gammaltMal === r.mal)
      throw new Error('FAIL CLOSED: ' + r.id + ' påstår en ommappning men målet är oförändrat');
  }
  if (r.grundMaskin === 'DIREKT')
    throw new Error('FAIL CLOSED: ' + r.id + ' är maskinellt DIREKT och behöver inget beslut');
  r.grund = 'HUMAN_APPROVED';
}
const AMBIGUOUS_SKARMAR = SCREENS.filter(s => (regelAvId.get(s.regel) || {}).grund === 'BEDOMNING').map(s => s.id);
const GODKANDA_SKARMAR = SCREENS.filter(s => (regelAvId.get(s.regel) || {}).grund === 'HUMAN_APPROVED').map(s => s.id);

/* ── E · TILLSTÅND PER SKÄRM · positiv identifiering ────────────────────── */
const REGLER_STATE = [
  ['LOADING', s => /laddar|genererar|hämtar|förbereder|pågår|förlopp|väntan/i.test(s.etikett) || s.skelett || s.laddare],
  ['EMPTY', s => /\btom(t|ma|)\b|inga öppna|inga vänner|tomt läge|tyst så här långt/i.test(s.etikett)],
  ['PARTIAL', s => /delvis|partiell|överfyllnad|ofullständig|flersidig/i.test(s.etikett)],
  ['ERROR', s => /\bfel\b|misslyckades|kunde inte|nekad|spärr|gräns|kvoten slut|inte behörig|gick inte|nås inte|avvisar/i.test(s.etikett) || s.retry],
  ['OFFLINE', s => /offline|frånkopplat|ingen anslutning/i.test(s.etikett) || s.offlinemarkor],
  ['CONFLICT', s => /konflikt|hann först|samtidig|kapplöpning/i.test(s.etikett)]
];
for (const s of SCREENS) {
  s.burnaStates = REGLER_STATE.filter(([, f]) => f(s)).map(([n]) => n);
  if (!s.burnaStates.length) s.burnaStates = ['DEFAULT'];
}

/* ── F · FLOW-STATE-KRAV × REPRESENTATION ──────────────────────────────── */
const FSR = [];
for (const v of VIEWS) {
  const skarmar = SCREENS.filter(s => s.vy === v.id);
  for (const st of STATES) {
    const relevans = v.krav[st];
    let rep = null, bevis = [];
    if (relevans === 'REQUIRED') {
      if (!skarmar.length) rep = 'UNVERIFIABLE';
      else { bevis = skarmar.filter(s => s.burnaStates.includes(st)).map(s => s.id);
        rep = bevis.length ? 'PRESENT' : 'ABSENT'; }
    }
    FSR.push({ id: 'FSR::' + v.id + '::' + st, vy: v.id, vyNamn: v.namn, state: st,
      relevans, representation: rep, bevis: bevis.sort(), skarmar_i_vyn: skarmar.length });
  }
}
if (new Set(FSR.map(x => x.id)).size !== FSR.length) throw new Error('FAIL CLOSED: FSR-kollision');

/* ── G · KOMPONENTROLLER × TILLSTÅND ───────────────────────────────────── */
const smatch = /const STATEFUL = \/\^\(([^)]+)\)\$\/i;/.exec(R('tools/lint-core.mjs'));
if (!smatch) throw new Error('FAIL CLOSED: A11Y-02:s STATEFUL-regel kunde inte läsas');
const STATEFUL = new Set(smatch[1].split('|'));
const KANDIDATSTATES = ['DEFAULT', 'PRESSED', 'FOCUSED', 'SELECTED', 'DISABLED', 'EXPANDED', 'COLLAPSED'];
const STATE_ALIAS = { selected: 'SELECTED', unselected: 'SELECTED', checked: 'SELECTED',
  unchecked: 'SELECTED', on: 'SELECTED', off: 'SELECTED', av: 'SELECTED', med: 'SELECTED',
  utan: 'SELECTED', disabled: 'DISABLED', expanded: 'EXPANDED', collapsed: 'COLLAPSED',
  pressed: 'PRESSED' };
const rollForekomst = new Map(), rollState = new Map();
for (const f of SCREEN_FILES) {
  for (const m of R(f).matchAll(/<[a-z]+[^>]*data-a11y-role="([^"]+)"[^>]*>/g)) {
    const roll = m[1];
    rollForekomst.set(roll, (rollForekomst.get(roll) || 0) + 1);
    if (!rollState.has(roll)) rollState.set(roll, new Map());
    const st = /data-a11y-state="([^"]+)"/.exec(m[0]);
    const k = st ? STATE_ALIAS[st[1]] : 'DEFAULT';
    if (k) rollState.get(roll).set(k, (rollState.get(roll).get(k) || 0) + 1);
  }
}
const ROLES = [...rollForekomst.keys()].sort();
const CSR = [];
for (const roll of ROLES) for (const st of KANDIDATSTATES) {
  const antal = rollState.get(roll).get(st) || 0;
  let relevans, rep = null;
  if (st === 'DEFAULT') { relevans = 'REQUIRED'; rep = antal ? 'PRESENT' : 'ABSENT'; }
  else if (antal > 0) { relevans = 'REQUIRED'; rep = 'PRESENT'; }
  else relevans = 'UNKNOWN';
  CSR.push({ id: 'CSR::ROLE::' + roll + '::' + st, roll: 'ROLE::' + roll, state: st,
    relevans, representation: rep, forekomster: antal, stateful_enligt_A11Y02: STATEFUL.has(roll) });
}
if (new Set(CSR.map(x => x.id)).size !== CSR.length) throw new Error('FAIL CLOSED: CSR-kollision');

/* ── H · COLOR-ONLY-FAMILJER ───────────────────────────────────────────── */
const grupper = new Map();
for (const f of SCREEN_FILES) {
  for (const m of R(f).matchAll(/<[a-z]+[^>]*data-state-group="([^"]+)"[^>]*>/g)) {
    const g = m[1];
    if (!grupper.has(g)) grupper.set(g, { states: new Set(), roller: new Set() });
    const st = /data-a11y-state="([^"]+)"/.exec(m[0]);
    const rl = /data-a11y-role="([^"]+)"/.exec(m[0]);
    if (st) grupper.get(g).states.add(st[1]);
    if (rl) grupper.get(g).roller.add(rl[1]);
  }
}
const skarmForGrupp = new Map();
for (const s of SCREENS) for (const g of new Set(s.grupper)) {
  if (!skarmForGrupp.has(g)) skarmForGrupp.set(g, new Set());
  skarmForGrupp.get(g).add(s.id);
}
const COF = [...grupper.entries()].map(([g, d]) => {
  const skarmar = [...(skarmForGrupp.get(g) || [])].sort();
  const vyer = [...new Set(skarmar.map(id => (SCREENS.find(s => s.id === id) || {}).vy).filter(Boolean))].sort();
  return { id: 'COF::' + g, familj: g, states: [...d.states].sort(), roller: [...d.roller].sort(),
    skarmar, vyer, testbar: d.states.size >= 2 ? 'TESTBAR' : 'OTESTBAR_SINGLE_STATE' };
}).sort((a, b) => a.id.localeCompare(b.id));
const HIST = (JSON.parse(R('fas2/nt-baslinje.json')).B_anvandningAvFarg.singelState || []).map(x => x.familj).sort();
const NU = COF.filter(c => c.testbar === 'OTESTBAR_SINGLE_STATE').map(c => c.familj).sort();
const MATCHED = NU.filter(f => HIST.includes(f));
const BORTTAGNA = HIST.filter(f => !NU.includes(f));
const TILLKOMNA = NU.filter(f => !HIST.includes(f));

/* ── I · ÖVERGÅNGARNAS REPRESENTATION ──────────────────────────────────── */
const skarmIds = new Set(SCREENS.map(s => s.id));
for (const t of TRANSITIONS)
  t.representation = t.skarmref.length
    ? (t.skarmref.every(r => skarmIds.has(r)) ? 'PRESENT' : 'ABSENT') : 'UNKNOWN';

/* ── J · RECONCILIATION ────────────────────────────────────────────────── */
const unikaVy = new Set(SCREENS.filter(s => s.vy).map(s => s.id));
const unikaRam = new Set(SCREENS.filter(s => s.ram).map(s => s.id));
const aktiva = REGLER.filter(r => !r.splittrad);
const RECON = {
  skarmar_i_korpus: SCREENS.length,
  VIEW_SCREENS: unikaVy.size, FRAME_SCREENS: unikaRam.size,
  TOTAL_SCREENS: unikaVy.size + unikaRam.size,
  OVERLAP: SCREENS.filter(s => s.vy && s.ram).length,
  UNMAPPED: OMAPPADE.length,
  skarmar_med_fler_an_en_regeltraff: SCREENS.filter(s => s.traffar.length > 1).length,
  summa_stammer: unikaVy.size + unikaRam.size === SCREENS.length,
  distinkta_vyer_traffade: new Set(SCREENS.filter(s => s.vy).map(s => s.vy)).size,
  regler_totalt: REGLER.length, regler_klassificerande: aktiva.length,
  regler_splittrade: REGLER.filter(r => r.splittrad).length,
  barnregler: REGLER.filter(r => r.parent).length,
  regler_utan_skarm: aktiva.filter(r => r.antal === 0).map(r => r.id + ' ' + r.prefix),
  HUMAN_APPROVED_RULES: REGLER.filter(r => r.grund === 'HUMAN_APPROVED').length,
  HUMAN_APPROVED_SCREENS: GODKANDA_SKARMAR.length,
  UNRESOLVED_RULES: REGLER.filter(r => r.grund === 'BEDOMNING').length,
  UNRESOLVED_SCREENS: AMBIGUOUS_SKARMAR.length
};

/* ── K · FINGERAVTRYCK ─────────────────────────────────────────────────── */
const kanon = {
  views: VIEWS.map(v => v.id).sort(), flows: FLOWS.map(f => f.id).sort(),
  fsr: FSR.map(x => [x.id, x.relevans, x.representation].join('|')).sort(),
  csr: CSR.map(x => [x.id, x.relevans, x.representation].join('|')).sort(),
  tr: TRANSITIONS.map(x => [x.id, x.representation].join('|')).sort(),
  cof: COF.map(x => [x.id, x.testbar].join('|')).sort()
};
const h = o => createHash('sha256').update(JSON.stringify(o)).digest('hex').slice(0, 16);
const FP = h(kanon);
const FP_IDENTITET = h({ v: kanon.views, f: kanon.flows, fsr: FSR.map(x => x.id).sort(),
  csr: CSR.map(x => x.id).sort(), tr: TRANSITIONS.map(x => x.id).sort(), cof: COF.map(x => x.id).sort() });
const FP_MAPPNING = h(REGLER.map(r =>
  [r.id, r.prefix, r.skarmId || '', r.mal, r.grund, r.skarmar.slice().sort().join(',')].join('|')).sort());
const FP_SKARM = h(SCREENS.map(s => s.id).sort());
const FP_REGEL = h(REGLER.map(r => r.id).sort());

/* ── L · UTMATNING ─────────────────────────────────────────────────────── */
const rakna = (a, f, v) => a.filter(x => f(x) === v).length;
const grundRakning = g => ({ regler: REGLER.filter(r => r.grund === g).length,
  skarmar: SCREENS.filter(s => (regelAvId.get(s.regel) || {}).grund === g).length });
const ut = {
  BASELINE: { skarmfiler: SCREEN_FILES.length, skarmar: SCREENS.length, kalla: KALLA },
  FUNCTIONAL_FLOWS_TOTAL: FLOWS.length, VIEWS_TOTAL: VIEWS.length, STATE_VOKABULAR: STATES,
  MAPPNINGSREVISION: { ...RECON,
    per_grund: Object.fromEntries(['DIREKT', 'ANKRAD', 'HUMAN_APPROVED', 'BEDOMNING',
      'RAM_DEKLARERAD', 'SPLITTRAD'].map(g => [g, grundRakning(g)])),
    godkanda_regler: REGLER.filter(r => r.grund === 'HUMAN_APPROVED')
      .map(r => r.id + ' ' + (r.skarmId || r.prefix) + ' -> ' + r.mal + ' (' + r.antal + ')'),
    olosta_skarmar: AMBIGUOUS_SKARMAR.slice().sort(),
    MAPPING_FINGERPRINT: FP_MAPPNING, SCREEN_IDENTITY_FINGERPRINT: FP_SKARM,
    RULE_IDENTITY_FINGERPRINT: FP_REGEL },
  SKARM_VY_MAPPNING: { mappade: unikaVy.size, icke_vy_ramar: unikaRam.size, OMAPPADE: OMAPPADE.length },
  FLOW_STATE_REQUIREMENTS: { TOTALT: FSR.length,
    REQUIRED: rakna(FSR, x => x.relevans, 'REQUIRED'),
    NOT_APPLICABLE: rakna(FSR, x => x.relevans, 'NOT_APPLICABLE'),
    UNKNOWN: rakna(FSR, x => x.relevans, 'UNKNOWN') },
  FLOW_REPRESENTATION: { PRESENT: rakna(FSR, x => x.representation, 'PRESENT'),
    ABSENT: rakna(FSR, x => x.representation, 'ABSENT'),
    AMBIGUOUS: rakna(FSR, x => x.representation, 'AMBIGUOUS'),
    UNVERIFIABLE: rakna(FSR, x => x.representation, 'UNVERIFIABLE') },
  COMPONENT_ROLES_TOTAL: ROLES.length,
  COMPONENT_STATE_REQUIREMENTS: { TOTALT: CSR.length,
    REQUIRED: rakna(CSR, x => x.relevans, 'REQUIRED'),
    NOT_APPLICABLE: rakna(CSR, x => x.relevans, 'NOT_APPLICABLE'),
    UNKNOWN: rakna(CSR, x => x.relevans, 'UNKNOWN') },
  COMPONENT_REPRESENTATION: { PRESENT: rakna(CSR, x => x.representation, 'PRESENT'),
    ABSENT: rakna(CSR, x => x.representation, 'ABSENT'),
    AMBIGUOUS: rakna(CSR, x => x.representation, 'AMBIGUOUS'),
    UNVERIFIABLE: rakna(CSR, x => x.representation, 'UNVERIFIABLE') },
  TRANSITIONS: { REQUIRED: TRANSITIONS.length,
    PRESENT: rakna(TRANSITIONS, x => x.representation, 'PRESENT'),
    ABSENT: rakna(TRANSITIONS, x => x.representation, 'ABSENT'),
    UNKNOWN: rakna(TRANSITIONS, x => x.representation, 'UNKNOWN') },
  COLOR_ONLY: { HISTORICAL_BASELINE: HIST.length, CURRENT_FAMILIES_TOTAL: COF.length,
    CURRENT_OTESTBARA: NU.length, CURRENT_TESTBARA: COF.length - NU.length,
    MATCHED: MATCHED.length, LEGITIMATELY_REMOVED: BORTTAGNA, LEGITIMATELY_ADDED: TILLKOMNA,
    UNACCOUNTED: HIST.length - MATCHED.length - BORTTAGNA.length,
    knutna_till_vy: COF.filter(c => c.vyer.length).length,
    knutna_till_roll: COF.filter(c => c.roller.length).length },
  SCOPE_FYND: K.scope_fynd,
  IDENTITY_SCHEME: 'VIEW/FLOW/FSR/ROLE/CSR/TR/COF/MAP — authored id. Barnregel = förälder-id + skärmens authored id.',
  IDENTITY_COLLISIONS: 0,
  POPULATION_COUNT: FSR.length + CSR.length + TRANSITIONS.length + COF.length,
  POPULATION_FINGERPRINT: FP, IDENTITY_FINGERPRINT: FP_IDENTITET
};

const d = arg('detalj');
if (d === 'fsr') console.log(JSON.stringify(FSR, null, 1));
else if (d === 'csr') console.log(JSON.stringify(CSR, null, 1));
else if (d === 'cof') console.log(JSON.stringify(COF, null, 1));
else if (d === 'tr') console.log(JSON.stringify(TRANSITIONS, null, 1));
else if (d === 'skarm') console.log(JSON.stringify(SCREENS.map(s => ({
  id: s.id, regel: s.regel, vy: s.vy, ram: s.ram, states: s.burnaStates })), null, 1));
else if (d === 'map') console.log(JSON.stringify({ RECON, STATES,
  VIEWS: VIEWS.map(v => ({ id: v.id, namn: v.namn })),
  REGLER: REGLER.map(r => ({ id: r.id, parent: r.parent, matchning: r.matchning, prefix: r.prefix,
    skarmId: r.skarmId, mal: r.mal, gammaltMal: r.gammaltMal || null, vy: r.vy, vyNamn: r.vyNamn,
    skal: r.skal, grund: r.grund, grundMaskin: r.grundMaskin, ankare: r.ankare, antal: r.antal,
    skarmar: r.skarmar.slice().sort(), splittrad: r.splittrad,
    annan_regel_kan_traffa: r.annan_regel_kan_traffa })),
  MAPPING_FINGERPRINT: FP_MAPPNING, SCREEN_IDENTITY_FINGERPRINT: FP_SKARM,
  RULE_IDENTITY_FINGERPRINT: FP_REGEL }, null, 1));
else console.log(JSON.stringify(ut, null, 1));
