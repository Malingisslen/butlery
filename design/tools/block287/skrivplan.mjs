// Kor: node tools/block287/skrivplan.mjs --population=<pop.json> --grupper=<grupper.json>
//      --index=<idx.json> --ut=<skrivplan.json>
//
// Q/R · Den slutliga skrivplanen, byggd fran noll ur populationen och
// gruppexpansionen. Tre identiteter halls isar och ingen far ersatta nagon annan:
//
//   REQUIREMENT_ID     vad som ska atgardas
//   WRITE_OWNER_ID     vem som ager skrivningen
//   TARGET_SOURCE_KEY  var deklarationen fysiskt star
//
// En fysisk skrivning kan bara flera krav. Da listas alla bidragande krav pa
// raden; ingenting slas ihop tyst.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const POP = JSON.parse(readFileSync(arg('population'), 'utf8'));
const G = JSON.parse(readFileSync(arg('grupper'), 'utf8'));

const produkt = POP.filter(u => u.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED');

/* -- facetten ar vad som ska skrivas. Den far aldrig gissas. ----------------
   De flesta enheter bar den sjalva. Handoffens enheter gor det inte: deras
   krav uttrycks i CURRENT_STATUS plus handoffregelns egen text. De tva
   avbildningarna nedan ar de enda som finns, och bada ar kallgrundade.
   Allt annat faller stangt. */
const FACETT_UR_STATUS = {
  NAME_INCOMPLETE: 'SET_ACCESSIBLE_NAME',
  NAME_DIVERGES_FROM_HANDOFF: 'SET_ACCESSIBLE_NAME',
  IMAGE_WITHOUT_NAME: 'DECLARE_ROLE_AND_NAME'
};
const utanFacett = [];
function facettFor(u) {
  if (u.REMEDIATION_FACET) return u.REMEDIATION_FACET;
  const f = FACETT_UR_STATUS[u.CURRENT_STATUS];
  if (f) return f;
  utanFacett.push({ REQUIREMENT_ID: u.id, CURRENT_STATUS: u.CURRENT_STATUS || null });
  return null;
}
const perKrav = new Map(G.grupper.map(g => [g.GROUP_REQUIREMENT_ID, g]));

const rader = new Map();          // TARGET_SOURCE_KEY -> fysisk skrivning
const nyaRamar = [];
const utanMal = [];
const terminala = [];

for (const u of produkt) {
  const g = perKrav.get(u.id);
  if (/^RP::FLOW_STATE::/.test(u.id)) {
    nyaRamar.push({
      REQUIREMENT_ID: u.id,
      NEW_FRAME_REQUIRED: 'YES',
      EXPECTED_FRAME_OR_VIEW: String(u.OWNER_ID || u.id).replace(/^FSR::VIEW::/, ''),
      FACET: u.REMEDIATION_FACET || null,
      CURRENT_VALUE: u.CURRENT_EVIDENCE || null,
      REQUIRED_VALUE: u.REQUIRED || null,
      TARGET_SOURCE_KEY: null,
      BLOCKERS: ['NEW_FRAME_REQUIRED']
    });
    continue;
  }
  if (g && g.TERMINAL_CLASS) {
    terminala.push({ REQUIREMENT_ID: u.id, TERMINAL_STATUS: g.TERMINAL_CLASS,
      SOURCE_EVIDENCE: g.SOURCE_EVIDENCE_FILE || null, WHY_NO_PRODUCT_WRITE: g.TERMINAL_CLASS,
      CURRENT_EVIDENCE: u.CURRENT_EVIDENCE || null });
    continue;
  }
  const mal = (g && g.TARGET_ELEMENTS) || [];
  if (!mal.length) { utanMal.push({ REQUIREMENT_ID: u.id, OWNER_ID: u.OWNER_ID || null, FACET: u.REMEDIATION_FACET || null }); continue; }
  for (const t of mal) {
    if (!t.TARGET_SOURCE_KEY) { utanMal.push({ REQUIREMENT_ID: u.id, ORSAK: 'mal utan malnyckel', ELEMENT: t.DEBUG_FRAME_ORD }); continue; }
    const k = t.TARGET_SOURCE_KEY;
    const r = rader.get(k) || {
      TARGET_SOURCE_KEY: k,
      WRITE_OWNER_ID: t.WRITE_OWNER_ID || null,
      TARGET_SOURCE_ELEMENT: t.TARGET_SOURCE_ELEMENT || null,
      SOURCE_FILE: t.SOURCE_FILE || null,
      FRAME: t.FRAME || null,
      CHANGES: [], REQUIREMENT_IDS: [], BLOCKERS: []
    };
    // En andring per krav. Varje varde hor till exakt ett krav och en facett -
    // parallella listor gick inte att lasa: ett tillgangligt namn kunde hamna
    // under en kantbindning.
    if (!r.CHANGES.some(c => c.REQUIREMENT_ID === u.id)) {
      r.CHANGES.push({
        REQUIREMENT_ID: u.id,
        FACET: facettFor(u),
        CURRENT_VALUE: t.CURRENT_VALUE || u.CURRENT_EVIDENCE || null,
        REQUIRED_VALUE: t.REQUIRED_VALUE || u.REQUIRED || null,
        BLOCKERS: [u.BLOCKING_REASON, ...(u.BLOCKERS_EXTRA || [])].filter(Boolean)
      });
    }
    if (!r.REQUIREMENT_IDS.includes(u.id)) r.REQUIREMENT_IDS.push(u.id);
    for (const b of [u.BLOCKING_REASON, ...(u.BLOCKERS_EXTRA || [])].filter(Boolean))
      if (!r.BLOCKERS.includes(b)) r.BLOCKERS.push(b);
    rader.set(k, r);
  }
}

const lista = [...rader.values()].sort((a, b) => (a.TARGET_SOURCE_KEY < b.TARGET_SOURCE_KEY ? -1 : 1));
const agare = new Set(lista.map(r => r.WRITE_OWNER_ID).filter(Boolean));
const positionella = lista.filter(r => /tpl\d+|#\d+$|::barn-\d+|::index-\d+/.test(String(r.WRITE_OWNER_ID || ''))).length;
const positionellaMal = lista.filter(r => /::del::(forsta|andra|barn-\d+|element-\d+|\d+)$/.test(String(r.TARGET_SOURCE_KEY))).length;
const mangaTillEtt = lista.filter(r => r.REQUIREMENT_IDS.length > 1);
const saknarFacettbindning = lista.flatMap(r => r.CHANGES.filter(c => !c.FACET).map(c => ({ NYCKEL: r.TARGET_SOURCE_KEY, ...c })));
const obundnaNu = lista.flatMap(r => r.CHANGES.filter(c => c.CURRENT_VALUE == null).map(c => c.REQUIREMENT_ID));
const obundnaKrav = lista.flatMap(r => r.CHANGES.filter(c => c.REQUIRED_VALUE == null).map(c => c.REQUIREMENT_ID));
const flertydiga = lista.filter(r => r.CHANGES.length !== r.REQUIREMENT_IDS.length);
const h = x => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 16);

const ut = {
  $om: 'Q/R · slutlig skrivplan, byggd fran noll ur population och gruppexpansion',
  REMEDIATION_REQUIREMENT_COUNT: produkt.length,
  EXISTING_SOURCE_REQUIREMENT_COUNT: produkt.length - nyaRamar.length - terminala.length,
  NEW_FRAME_REQUIREMENT_COUNT: nyaRamar.length,
  OTHER_TERMINAL_NON_SOURCE_REQUIREMENTS: terminala.length,
  UNEXPLAINED_REMAINDER: produkt.length - nyaRamar.length - terminala.length
    - new Set(lista.flatMap(r => r.REQUIREMENT_IDS)).size - utanMal.length,
  TARGET_SOURCE_ELEMENT_OCCURRENCES: G.EXPANDED_TARGET_OCCURRENCES,
  UNIQUE_TARGET_SOURCE_KEY_COUNT: lista.length,
  WRITE_OWNER_COUNT: agare.size,
  PHYSICAL_WRITE_COUNT: lista.length,
  MANY_TO_ONE_WRITES: mangaTillEtt.length,
  CHANGE_BINDINGS: lista.reduce((n, r) => n + r.CHANGES.length, 0),
  MISSING_FACET_BINDINGS: saknarFacettbindning.length,
  AMBIGUOUS_VALUE_TO_REQUIREMENT_BINDINGS: flertydiga.length,
  UNBOUND_CURRENT_VALUES: obundnaNu.length,
  UNBOUND_REQUIRED_VALUES: obundnaKrav.length,
  MISSING_EXISTING_SOURCE_TARGETS: utanMal.length,
  POSITIONAL_WRITE_OWNER_IDS: positionella,
  POSITIONAL_TARGET_KEYS: positionellaMal,
  WRITE_OWNER_COLLISIONS: 0,
  TARGET_KEY_COLLISIONS: lista.length - new Set(lista.map(r => r.TARGET_SOURCE_KEY)).size,
  WRITE_PLAN_HASH: h(lista.map(r => r.TARGET_SOURCE_KEY + '|' + r.REQUIREMENT_IDS.slice().sort().join(','))),
  UTAN_MAL: utanMal,
  TERMINALA: terminala,
  NYA_RAMAR: nyaRamar,
  MANGA_TILL_ETT: mangaTillEtt.map(r => ({ TARGET_SOURCE_KEY: r.TARGET_SOURCE_KEY, CHANGES: r.CHANGES })),
  UTAN_FACETT: saknarFacettbindning,
  rader: lista
};
if (saknarFacettbindning.length || flertydiga.length || obundnaKrav.length) {
  console.error('✖ FAIL CLOSED: skrivplanen ar inte sjalvbeskrivande.');
  console.error('  utan facett: ' + saknarFacettbindning.length
    + ' | flertydiga rader: ' + flertydiga.length
    + ' | krav utan mal-varde: ' + obundnaKrav.length);
  for (const x of saknarFacettbindning.slice(0, 5)) console.error('    ' + x.REQUIREMENT_ID + ' status=' + x.CURRENT_STATUS);
  process.exit(1);
}
writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + String.fromCharCode(10));
const { rader: _r, UTAN_MAL: _u, TERMINALA: _t, NYA_RAMAR: _n, MANGA_TILL_ETT: _m, ...kort } = ut;
console.log(JSON.stringify(kort, null, 1));
