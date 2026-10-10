// Kor: node tools/block287/deltagranskning.mjs --gammal=<gammal fas2-katalog> --bygge=<byggkatalog> [--ut=<fil>]
//
// F/G · Riktad deltagranskning. Bara det som faktiskt andrats mellan den
// foregaende frysningen och nulaget provas - inte hela den semantiska
// granskningen om.
//
// Varje andrad enhet eller skrivning klassas, och integriteten i den nya
// populationen raknas om fran noll i stallet for att kopieras vidare.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const GAMMAL = arg('gammal'), BYGGE = arg('bygge');
const g = f => JSON.parse(readFileSync(join(GAMMAL, f), 'utf8'));
const n = f => JSON.parse(readFileSync(join(BYGGE, f), 'utf8'));

const gPop = g('block287k-population.json'), nPop = n('frys/block287k-population.json');
const gPlan = g('block287k-skrivplan.json'), nPlan = n('skrivplan.json');
const nGrp = n('grupper.json');
const OVL = n('overlay.json');
const DISC = n('disc-A.json');

/* ── F · vad andrades ────────────────────────────────────────────────────── */
const gId = new Map(gPop.map(u => [u.id, u]));
const nId = new Map(nPop.map(u => [u.id, u]));
const andrade = [];

for (const [id, u] of gId) if (!nId.has(id)) andrade.push({
  KLASS: 'REMOVED', OLD_ID: id, NEW_ID: null,
  REQUIREMENT_IDS: [id], OLD_TARGET: null, NEW_TARGET: null,
  SKAL: 'enheten finns inte langre i populationen',
  KALLEVIDENS: u.CURRENT_EVIDENCE || null,
  FORVANTAD_EFFEKT: 'ett krav farre; maste vara en dubblett eller en pensionerad identitet'
});
for (const [id, u] of nId) if (!gId.has(id)) andrade.push({
  KLASS: 'ADDED', OLD_ID: null, NEW_ID: id,
  REQUIREMENT_IDS: [id], OLD_TARGET: null, NEW_TARGET: null,
  SKAL: 'ny enhet i populationen', KALLEVIDENS: u.CURRENT_EVIDENCE || null,
  FORVANTAD_EFFEKT: 'ett krav mer'
});
for (const [id, u] of nId) {
  const o = gId.get(id); if (!o) continue;
  if (String(o.OWNER_ID) !== String(u.OWNER_ID)) andrade.push({
    KLASS: 'OWNER_CHANGED', OLD_ID: id, NEW_ID: id, REQUIREMENT_IDS: [id],
    OLD_TARGET: o.OWNER_ID, NEW_TARGET: u.OWNER_ID,
    SKAL: 'agarstrangen bytte varde', KALLEVIDENS: u.CURRENT_EVIDENCE || null,
    FORVANTAD_EFFEKT: 'samma krav, ny agaridentitet'
  });
}

// skrivningar: mal och facettbindning
const gRad = new Map(gPlan.rader.map(r => [r.TARGET_SOURCE_KEY, r]));
const nRad = new Map(nPlan.rader.map(r => [r.TARGET_SOURCE_KEY, r]));
const andradeSkrivningar = [];
const kravTillMal = (plan) => { const m = new Map(); for (const r of plan.rader) for (const k of r.REQUIREMENT_IDS) {
  const e = m.get(k) || []; e.push(r.TARGET_SOURCE_KEY); m.set(k, e); } return m; };
const gKrav = kravTillMal(gPlan), nKrav = kravTillMal(nPlan);
for (const [krav, nm] of nKrav) {
  const gm = gKrav.get(krav);
  if (!gm) { andradeSkrivningar.push({ KLASS: 'ADDED', REQUIREMENT_IDS: [krav], OLD_TARGET: null, NEW_TARGET: nm.join(','),
    SKAL: 'nytt krav i planen', FORVANTAD_EFFEKT: 'en skrivning mer' }); continue; }
  const a = gm.slice().sort().join(','), b2 = nm.slice().sort().join(',');
  if (a !== b2) andradeSkrivningar.push({ KLASS: 'TARGET_CHANGED', REQUIREMENT_IDS: [krav],
    OLD_TARGET: a, NEW_TARGET: b2, SKAL: 'kravet pekar pa ett annat fysiskt mal',
    FORVANTAD_EFFEKT: 'skrivningen flyttas' });
}
for (const [krav, gm] of gKrav) if (!nKrav.has(krav)) andradeSkrivningar.push({
  KLASS: 'REMOVED', REQUIREMENT_IDS: [krav], OLD_TARGET: gm.join(','), NEW_TARGET: null,
  SKAL: 'kravet finns inte langre', FORVANTAD_EFFEKT: 'en skrivning farre' });
// delade mal
for (const [k, gr] of gRad) {
  const nr = nRad.get(k);
  if (nr && nr.REQUIREMENT_IDS.length < gr.REQUIREMENT_IDS.length) andradeSkrivningar.push({
    KLASS: 'SPLIT_PHYSICAL_WRITE', REQUIREMENT_IDS: gr.REQUIREMENT_IDS,
    OLD_TARGET: k, NEW_TARGET: gr.REQUIREMENT_IDS.map(x => (nKrav.get(x) || []).join(',')).join(' + '),
    SKAL: 'malet bar farre krav an forut - de ovriga fick egna mal',
    FORVANTAD_EFFEKT: 'tva skilda kontroller skrivs var for sig' });
}
// facettbindning
const gHarChanges = gPlan.rader.some(r => Array.isArray(r.CHANGES));
if (!gHarChanges) andradeSkrivningar.push({ KLASS: 'FACET_BINDING_CHANGED', REQUIREMENT_IDS: ['(alla)'],
  OLD_TARGET: 'parallella listor FACETS/CURRENT_VALUE/REQUIRED_VALUE', NEW_TARGET: 'CHANGES[] per krav',
  SKAL: 'skrivplanens schema normaliserades', FORVANTAD_EFFEKT: 'varje varde hor till exakt ett krav och en facett' });

/* ── G · integriteten raknas om fran noll ────────────────────────────────── */
const produkt = nPop.filter(u => u.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED');
const kravIPlan = new Set(nPlan.rader.flatMap(r => r.REQUIREMENT_IDS));
const nyaRamar = new Set(nPlan.NYA_RAMAR.map(r => r.REQUIREMENT_ID));
const terminala = new Set(nPlan.TERMINALA.map(r => r.REQUIREMENT_ID));
const saknade = produkt.filter(u => !kravIPlan.has(u.id) && !nyaRamar.has(u.id) && !terminala.has(u.id));
const dubbla = nPop.length - new Set(nPop.map(u => u.id)).size;

// falska positiva: en produktenhet vars agare klassningen inte kallar kontroll
const perAgare = new Map();
for (const f of Object.values(OVL.forekomst)) { if (!f.agare) continue;
  const e = perAgare.get(f.agare) || { alla: 0, kontroller: 0 };
  e.alla++; if (f.klass === 'KNOWN_CONTROL') e.kontroller++; perAgare.set(f.agare, e); }
const falska = produkt.filter(u => { const e = perAgare.get(u.OWNER_ID); return e && e.alla > 0 && e.kontroller === 0; });

// motstridiga: samma mal, samma facett, olika kravt varde
const motstridiga = [];
for (const r of nPlan.rader) {
  const per = new Map();
  for (const c of (r.CHANGES || [])) { if (c.REQUIRED_VALUE == null) continue;
    const s = per.get(c.FACET) || new Set(); s.add(c.REQUIRED_VALUE); per.set(c.FACET, s); }
  for (const [f, s] of per) if (s.size > 1) motstridiga.push({ NYCKEL: r.TARGET_SOURCE_KEY, FACET: f, VARDEN: [...s] });
}

// dubbla identiteter: tva enheter som loser sig till samma element med samma facett
const perElement = new Map();
for (const g2 of nGrp.grupper) for (const t of g2.TARGET_ELEMENTS) {
  if (!t.TARGET_SOURCE_KEY) continue;
  const e = perElement.get(t.DEBUG_FRAME_ORD) || new Set();
  e.add(g2.GROUP_REQUIREMENT_ID); perElement.set(t.DEBUG_FRAME_ORD, e);
}
const dubblaIdentiteter = [];
for (const [el, krav] of perElement) {
  const rollkrav = [...krav].filter(k => /^RP::(ROLE_AND_NAME|ROLE)::/.test(k));
  if (rollkrav.length > 1) dubblaIdentiteter.push({ ELEMENT: el, KRAV: rollkrav });
}

const ut = {
  $om: 'F/G · riktad deltagranskning mot den foregaende frysningen',
  DELTA_AUDIT_CHANGED_UNITS: andrade.length,
  DELTA_AUDIT_CHANGED_WRITES: andradeSkrivningar.length,
  PER_KLASS_ENHETER: andrade.reduce((o, x) => (o[x.KLASS] = (o[x.KLASS] || 0) + 1, o), {}),
  PER_KLASS_SKRIVNINGAR: andradeSkrivningar.reduce((o, x) => (o[x.KLASS] = (o[x.KLASS] || 0) + 1, o), {}),
  MISSING_REMEDIATION_UNITS: saknade.length,
  FALSE_POSITIVE_REMEDIATION_UNITS: falska.length,
  DUPLICATE_REMEDIATION_UNITS: dubbla + dubblaIdentiteter.length,
  CONFLICTING_REMEDIATION_UNITS: motstridiga.length,
  POPULATION_COUNT: nPop.length,
  PRODUCT_REMEDIATION_COUNT: produkt.length,
  ANDRADE_ENHETER: andrade,
  ANDRADE_SKRIVNINGAR: andradeSkrivningar,
  DIAG: { SAKNADE: saknade.map(u => u.id), FALSKA: falska.map(u => u.id),
    MOTSTRIDIGA: motstridiga, DUBBLA_IDENTITETER: dubblaIdentiteter }
};
if (arg('ut')) writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + String.fromCharCode(10));
const { ANDRADE_ENHETER, ANDRADE_SKRIVNINGAR, DIAG, ...kort } = ut;
console.log(JSON.stringify(kort, null, 1));
console.log('\nandrade enheter:');
for (const a of andrade) console.log('  ' + a.KLASS.padEnd(16) + (a.OLD_ID || a.NEW_ID));
console.log('andrade skrivningar:');
for (const a of andradeSkrivningar.slice(0, 12)) console.log('  ' + a.KLASS.padEnd(22) + String(a.REQUIREMENT_IDS[0]).slice(0, 70));
process.exit(saknade.length || falska.length || motstridiga.length || dubbla || dubblaIdentiteter.length ? 1 : 0);
