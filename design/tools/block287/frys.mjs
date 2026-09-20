// Kor: node tools/block287/frys.mjs --root=<kallrot> --bygge=<ut.json> --overlay=<overlay.json>
//      --extra=<extra-krav.json> --index=<elementindex.json> --ut=<katalog>
// X · Korrigerad Block 287-frysning: population, status, forekomster, skrivplan och ankarkarta.
// Alla skrivagarnycklar foljer det stabila kontraktet i tools/bl01-skrivnyckel.mjs.
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { skrivnyckel, ramIndex, slug, kortFil } from '../bl01-skrivnyckel.mjs';
import { kontrollFakta } from './omnyckla.mjs';
import * as SEM from '../semantic-owner-identity.mjs';
import { skorda } from '../discovery-harvest.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root'), UT = arg('ut');
if (!ROT || !UT) throw new Error('FAIL CLOSED: ange --root och --ut');
const MAT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'fas2', 'matning');
const j = f => JSON.parse(readFileSync(f, 'utf8'));
const sha = x => createHash('sha256').update(JSON.stringify(x)).digest('hex');

const B = j(arg('bygge'));
const ENH = j(arg('enheter'));
const O = j(arg('overlay'));
const X = j(arg('extra'));
const IDX = j(arg('index'));
const H = j(join(MAT, 'handoff-underlag.json'));
const R1 = j(join(ROT, 'fas2', 'bl01-ankarrekonciliering.json'));
const RAM = ramIndex(IDX);
const occId = e => 'OCC::' + slug(e.fil) + '::' + e.art + '::' + e.ordProd;
const byOcc = new Map(IDX.map(e => [occId(e), e]));

/* ── population: bygget + handoffens nya enheter + extrakraven ──────────── */
const pfaMap = new Map(R1.PF_A_IDENTITY_MAPPING.map(m => [m.OLD_PF_A_ANCHOR, m.CANONICAL_BL01_ANCHOR]));
const byt = s => String(s).replace(/occ-[a-z]{12}/g, m => pfaMap.get(m) || m);
const handoffEnh = H.nyaEnheter.map(u => {
  const { forekomster, ...rest } = u;
  const k = { ...rest, FOREKOMSTER: forekomster };
  for (const f of ['id', 'OWNER_ID', 'WRITE_OWNER']) if (k[f]) k[f] = byt(k[f]);
  return k;
});
// Extrakraven bar samma sorts aldrade pf-a-ankare som handoffenheterna.
// Rekoncilieringen ar kanonisk for bada, annars hamnar tva id for samma objekt
// i populationen.
const extraEnh = X.enheter.map(u => {
  const k = { ...u };
  for (const f of ['id', 'OWNER_ID', 'WRITE_OWNER']) if (k[f]) k[f] = byt(k[f]);
  return k;
});
const pop = [...ENH, ...handoffEnh, ...extraEnh].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
const ids = pop.map(e => e.id);
if (ids.length !== new Set(ids).size) throw new Error('FAIL CLOSED: dubbla id i populationen');

/* ── skrivplan: en rad per fysisk skrivagare, stabil kallnyckel ─────────── */
const agarElement = new Map();      // OWNER:: -> element
for (const p of Object.entries(O.forekomst)) {
  if (p[1].klass !== 'KNOWN_CONTROL' || !p[1].agare) continue;
  const e = byOcc.get(p[0]); if (e) agarElement.set(p[1].agare, e);
}
for (const e of IDX) if (e.role && e.name) {
  const kanon = 'OWNER::' + e.art + '::namn::' + slug(String(e.name).replace(/\d+(?:[.,:]\d+)*/g, ' '));
  if (!agarElement.has(kanon)) agarElement.set(kanon, e);
}
// kanonisk semantisk agare for varje kontroll: det ar den nyckeln populationens enheter bar
const skord = JSON.parse(readFileSync(arg('skord'), 'utf8'));
const etikett = {};
for (const e of IDX) if (!(e.art in etikett)) etikett[e.art] = '';
{ const { fakta } = kontrollFakta({ skord, overlay: O, etikett });
  for (const f of fakta) { f.objekt = SEM.narmasteAnkare(f.kedja); const r = SEM.semantiskAgare(f);
    if (r.nyckel && f.el) { const e = RAM.get(f.art + '#' + f.el.ordProd); if (e && !agarElement.has(r.nyckel)) agarElement.set(r.nyckel, e); } } }
// elementuppslag via ankare, for enheter vars id bar ett occ
const byAnchor = new Map(IDX.filter(e => e.occ).map(e => [e.occ, e]));

const KATEGORIER_UTAN_SKRIVNING = new Set(['ALREADY_SATISFIED', 'NOT_REQUIRED', 'UNSPECIFIED_NO_ACTION',
  'HISTORICAL_OR_SUPERSEDED', 'FUTURE_PHASE_3_IMPLEMENTATION_CONTRACT', 'DOWNSTREAM_APP_IMPLEMENTATION_REQUIREMENTS',
  'SPEC_SYNC_REQUIRED', 'LINT_SYNC_REQUIRED', 'METHOD_TOOLING_REQUIRED', 'COMPONENT_COVERAGE_REQUIRED']);

function elementFor(u) {
  const m = String(u.id).match(/occ-[a-z]{12}/);
  if (m && byAnchor.has(m[0])) return byAnchor.get(m[0]);
  if (u.OWNER_ID && agarElement.has(u.OWNER_ID)) return agarElement.get(u.OWNER_ID);
  if (u.OWNER_ID) { const o = 'OWNER::' + String(u.OWNER_ID).replace(/^OWNER::/, ''); if (agarElement.has(o)) return agarElement.get(o); }
  return null;
}
const agare = new Map();
const utanMal = [];
for (const u of pop) {
  if (u.CATEGORY !== 'PRODUCT_REMEDIATION_REQUIRED') continue;
  if (/^RP::FLOW_STATE::/.test(u.id)) {       // nya ramar: ingen kallplats an
    const id = 'NEW_FRAME::' + String(u.OWNER_ID || u.id).replace(/^FSR::VIEW::/, '');
    const w = agare.get(id) || { WRITE_OWNER_ID: id, SOURCE_FILE: null, SOURCE_ELEMENT: null, STABLE_SOURCE_KEY: 'NEW_FRAME', REQUIREMENT_IDS: [], FACETS: [], BLOCKERS: ['NEW_FRAME_REQUIRED'], WRITE_KIND: 'NEW_FRAME_WRITE' };
    w.REQUIREMENT_IDS.push(u.id); if (u.REMEDIATION_FACET) w.FACETS.push(u.REMEDIATION_FACET);
    agare.set(id, w); continue;
  }
  const e = elementFor(u);
  if (!e) { utanMal.push({ id: u.id, OWNER_ID: u.OWNER_ID || null, FACET: u.REMEDIATION_FACET || null, KATEGORI: u.CATEGORY }); continue; }
  const nk = skrivnyckel(e, RAM);
  const id = nk.NIVA === 0
    ? (() => { let p = null; for (const o of e.anc || []) { const q = RAM.get(e.art + '#' + o); if (q && q.role) { p = q; break; } } return p ? skrivnyckel(p, RAM).WRITE_OWNER_ID : null; })()
    : nk.WRITE_OWNER_ID;
  if (!id) { utanMal.push({ id: u.id, OWNER_ID: u.OWNER_ID || null, FACET: u.REMEDIATION_FACET || null, KATEGORI: u.CATEGORY, SKAL: nk.GRUND }); continue; }
  const w = agare.get(id) || { WRITE_OWNER_ID: id, SOURCE_FILE: kortFil(e.fil), SOURCE_ELEMENT: e.art + ' <' + e.tag + '>' + (e.name ? ' "' + e.name + '"' : ''),
    STABLE_SOURCE_KEY: nk.GRUND, DEBUG_DC_TPL: e.tpl, REQUIREMENT_IDS: [], FACETS: [], BLOCKERS: [], WRITE_KIND: 'STATIC_PRODUCT_WRITE' };
  w.REQUIREMENT_IDS.push(u.id);
  if (u.REMEDIATION_FACET && !w.FACETS.includes(u.REMEDIATION_FACET)) w.FACETS.push(u.REMEDIATION_FACET);
  if (u.BLOCKING_REASON) for (const b of [].concat(u.BLOCKING_REASON)) if (!w.BLOCKERS.includes(b)) w.BLOCKERS.push(b);
  if (!e.role || !e.name) { const b = 'ROLE_OR_NAME_UNDECLARED'; if (!w.BLOCKERS.includes(b)) w.BLOCKERS.push(b); }
  agare.set(id, w);
}
const rader = [...agare.values()].sort((a, b) => (a.WRITE_OWNER_ID < b.WRITE_OWNER_ID ? -1 : 1))
  .map(w => ({ ...w, WRITE_READY: w.BLOCKERS.length === 0 }));
const positionella = rader.filter(r => /#tpl|::ord::|::index::/.test(r.WRITE_OWNER_ID)).length;
const dubbel = rader.length - new Set(rader.map(r => r.WRITE_OWNER_ID)).size;

/* ── ankarkarta ur kallan ───────────────────────────────────────────────── */
const ankare = IDX.filter(e => e.occ).map(e => ({ ANKARE: e.occ, FIL: kortFil(e.fil), RAM: e.art, TAGG: e.tag, TEXT: (e.own || e.text || '').slice(0, 70) }))
  .sort((a, b) => (a.ANKARE < b.ANKARE ? -1 : 1));
const kallFiler = readdirSync(ROT).filter(f => /^Butlery Skarmar.*\.dc\.html$/.test(f)).sort();
const kallHash = sha(kallFiler.map(f => [f, createHash('sha256').update(readFileSync(join(ROT, f))).digest('hex')]));

const manifest = {
  BLOCK: 287, STATUS: 'FROZEN', RUNDA: 'korrigeringsrunda 2',
  BASLINJE: { BL01_BASELINE_COMMIT: '06c1278', CORRECTION_ROUND_1_COMMIT: 'eecff3e', ANCHOR_CORRECTION_COMMIT: arg('ankarcommit') || null },
  BLOCK287_POPULATION_COUNT: pop.length,
  BLOCK287_POPULATION_HASH: sha(pop.map(e => e.id)),
  BLOCK287_STATUS_HASH: sha(pop.map(e => [e.id, e.CATEGORY, e.CURRENT_STATUS, (e.BLOCKERS || []).join(',')])),
  BLOCK287_OCCURRENCE_HASH: sha(pop.map(e => [e.id, e.OCCURRENCES || 1])),
  BLOCK287_WRITE_PLAN_HASH: sha(rader.map(r => [r.WRITE_OWNER_ID, r.REQUIREMENT_IDS.slice().sort(), r.BLOCKERS.slice().sort(), r.WRITE_READY])),
  BLOCK287_SOURCE_BASELINE_HASH: kallHash,
  BLOCK287_ANCHOR_MAP_HASH: sha(ankare),
  ANCHOR_COUNT: ankare.length,
  perKategori: pop.reduce((o, e) => (o[e.CATEGORY] = (o[e.CATEGORY] || 0) + 1, o), {}),
  PRODUCT_REMEDIATION_COUNT: pop.filter(e => e.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED').length,
  PRODUCT_OCCURRENCE_COUNT: pop.filter(e => e.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED').reduce((s, e) => s + (e.OCCURRENCES || 1), 0),
  CONTROL_COUNT: Object.values(O.forekomst).filter(v => v.klass === 'KNOWN_CONTROL').length,
  WRITE_OWNER_COUNT: rader.length,
  WRITE_READY_COUNT: rader.filter(r => r.WRITE_READY).length,
  WRITE_BLOCKED_COUNT: rader.filter(r => !r.WRITE_READY).length,
  WRITE_KINDS: rader.reduce((o, r) => (o[r.WRITE_KIND] = (o[r.WRITE_KIND] || 0) + 1, o), {}),
  HUMAN_DECISION_REQUIRED: pop.filter(e => e.CATEGORY === 'HUMAN_DECISION_REQUIRED').length,
  UNKNOWN_SEMANTICS: B.UPPTACKT.UNKNOWN_AFTER,
  OWNER_IDENTITY_UNRESOLVED: pop.filter(e => e.CATEGORY === 'OWNER_IDENTITY_UNRESOLVED').length,
  IDENTITY_COLLISIONS: ids.length - new Set(ids).size,
  WRITE_OWNER_COLLISIONS: dubbel,
  UNEXPLAINED_OCCURRENCES: B.grind.UNEXPLAINED_OCCURRENCES,
  POSITIONAL_WRITE_OWNER_IDS: positionella,
  STALE_SOURCE_REFERENCES: utanMal.length,
  BUILDER_FINGERPRINTS: B.fingeravtryck,
  UPPTACKT: B.UPPTACKT
};
mkdirSync(UT, { recursive: true });
const skriv = (f, x) => writeFileSync(join(UT, f), JSON.stringify(x, null, 1) + '\n');
skriv('block287k-population.json', pop);
skriv('block287k-skrivplan.json', { WRITE_OWNER_COUNT: rader.length, POSITIONAL_WRITE_OWNER_IDS: positionella, WRITE_OWNER_COLLISIONS: dubbel, PRODUKTENHETER_UTAN_SKRIVMAL: utanMal, rader });
skriv('block287k-ankarkarta.json', ankare);
skriv('block287k-avgoranden.json', { forekomst: O.forekomst, agare: O.agare });
skriv('block287k-frysning.json', manifest);
console.log(JSON.stringify(manifest, null, 1));
if (utanMal.length) console.log('\nPRODUKTENHETER UTAN SKRIVMAL (' + utanMal.length + '):\n' + utanMal.slice(0, 25).map(u => '  ' + u.id + '  ' + (u.SKAL || '')).join('\n'));
