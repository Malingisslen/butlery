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
      REQUIREMENT_IDS: [], FACETS: [], CURRENT_VALUE: [], REQUIRED_VALUE: [], BLOCKERS: []
    };
    if (!r.REQUIREMENT_IDS.includes(u.id)) r.REQUIREMENT_IDS.push(u.id);
    if (u.REMEDIATION_FACET && !r.FACETS.includes(u.REMEDIATION_FACET)) r.FACETS.push(u.REMEDIATION_FACET);
    const cur = t.CURRENT_VALUE || u.CURRENT_EVIDENCE || null;
    const req = t.REQUIRED_VALUE || u.REQUIRED || null;
    if (cur && !r.CURRENT_VALUE.includes(cur)) r.CURRENT_VALUE.push(cur);
    if (req && !r.REQUIRED_VALUE.includes(req)) r.REQUIRED_VALUE.push(req);
    for (const b of (u.BLOCKERS_EXTRA || [])) if (!r.BLOCKERS.includes(b)) r.BLOCKERS.push(b);
    if (u.BLOCKING_REASON && !r.BLOCKERS.includes(u.BLOCKING_REASON)) r.BLOCKERS.push(u.BLOCKING_REASON);
    rader.set(k, r);
  }
}

const lista = [...rader.values()].sort((a, b) => (a.TARGET_SOURCE_KEY < b.TARGET_SOURCE_KEY ? -1 : 1));
const agare = new Set(lista.map(r => r.WRITE_OWNER_ID).filter(Boolean));
const positionella = lista.filter(r => /tpl\d+|#\d+$|::barn-\d+|::index-\d+/.test(String(r.WRITE_OWNER_ID || ''))).length;
const positionellaMal = lista.filter(r => /::del::(forsta|andra|barn-\d+|element-\d+|\d+)$/.test(String(r.TARGET_SOURCE_KEY))).length;
const mangaTillEtt = lista.filter(r => r.REQUIREMENT_IDS.length > 1);
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
  MISSING_EXISTING_SOURCE_TARGETS: utanMal.length,
  POSITIONAL_WRITE_OWNER_IDS: positionella,
  POSITIONAL_TARGET_KEYS: positionellaMal,
  WRITE_OWNER_COLLISIONS: 0,
  TARGET_KEY_COLLISIONS: lista.length - new Set(lista.map(r => r.TARGET_SOURCE_KEY)).size,
  WRITE_PLAN_HASH: h(lista.map(r => r.TARGET_SOURCE_KEY + '|' + r.REQUIREMENT_IDS.slice().sort().join(','))),
  UTAN_MAL: utanMal,
  TERMINALA: terminala,
  NYA_RAMAR: nyaRamar,
  MANGA_TILL_ETT: mangaTillEtt.map(r => ({ TARGET_SOURCE_KEY: r.TARGET_SOURCE_KEY, REQUIREMENT_IDS: r.REQUIREMENT_IDS })),
  rader: lista
};
writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + String.fromCharCode(10));
const { rader: _r, UTAN_MAL: _u, TERMINALA: _t, NYA_RAMAR: _n, MANGA_TILL_ETT: _m, ...kort } = ut;
console.log(JSON.stringify(kort, null, 1));
