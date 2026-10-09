// Kor: node tools/block287/extrakrav-r2.mjs --root=<kallrot> --index=<idx-full.json> --ut=<extra-krav14.json>
//
// Korrigeringsrunda 2 lade till fyra gruppbehallare som censusdetektorn aldrig
// sag: den valjer bara element med kontrollform, sa kallregeln for
// gruppbehallare kordes aldrig. De star itemiserade i censuskorrigeringen och
// harleds har, med ankaret last ur kallan - aldrig ur en aldre kopia.
import { readFileSync, writeFileSync } from 'node:fs';
import { ramIndex, skrivnyckel } from '../bl01-skrivnyckel.mjs';
const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root');
const IDX = JSON.parse(readFileSync(arg('index'), 'utf8'));
const BAS = JSON.parse(readFileSync(ROT + '/fas2/matning/extra-krav.json', 'utf8'));
const KOR = JSON.parse(readFileSync(ROT + '/fas2/block287-censuskorrigering.json', 'utf8'));

const RAM = ramIndex(IDX);
const ut = JSON.parse(JSON.stringify(BAS));
const nya = [];
for (const r of (KOR.M_SAKNADE_GRUPPROLLSAGARE.rader || [])) {
  const e = IDX.find(x => x.art === r.RAM && x.ordProd === r.ordProd);
  if (!e) throw new Error('gruppbehallaren saknas i kallan: ' + r.RAM + '#' + r.ordProd);
  if (!e.occ) throw new Error('gruppbehallaren saknar kallforfattat ankare: ' + r.RAM + '#' + r.ordProd);
  const agare = 'OWNER::' + r.RAM + '::objekt::' + e.occ;
  nya.push({
    id: 'RP::GROUP_ROLE::' + r.RAM + '::objekt::' + e.occ,
    OWNER_ID: agare,
    REQUIREMENT_ID: 'A11Y-01 (grupproll)',
    REQUIREMENT_SOURCE: 'kallans role="' + r.KALLROLL + '" + Block 287 korrigeringsrunda 1 (L2)',
    PROVENANCE: 'SOURCE_GROUNDED',
    CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED',
    CURRENT_STATUS: 'GROUP_ROLE_UNDECLARED',
    OCCURRENCES: 1,
    REQUIRED: 'deklarera grupprollen ' + r.KALLROLL + ' pa behallaren',
    CURRENT_EVIDENCE: 'kallan bar role="' + r.KALLROLL + '" men ingen data-a11y-role; behallaren omsluter '
      + r.DEKLARERADE_BARN + ' deklarerade flikar. ' + r.SKAL.charAt(0).toUpperCase() + r.SKAL.slice(1) + '.',
    REMEDIATION_FACET: 'DECLARE_GROUP_ROLE',
    WRITE_OWNER: skrivnyckel(e, RAM).WRITE_OWNER_ID,
    WRITE_READY: false
  });
}
// Korrigeringsrunda 1, avsnitt T: forutsattningar som saknade egen enhet.
// Ingen skrivagare far blockeras av nagot som inte sjalvt star i populationen.
const KR1 = JSON.parse(readFileSync(ROT + '/fas2/block287-korrigeringsrunda1.json', 'utf8'));
const T = KR1.T_FORUTSATTNINGAR;
for (const r of (T.SAKNADE_ENHETER || [])) nya.push({
  id: r.ENHET, OWNER_ID: r.ROLL,
  REQUIREMENT_ID: 'ROLE_VOCABULARY_POLICY',
  REQUIREMENT_SOURCE: 'BL-03 + handoffens rollkrav',
  PROVENANCE: 'SOURCE_GROUNDED',
  CATEGORY: 'SPEC_SYNC_REQUIRED',
  CURRENT_STATUS: 'SPEC_AND_LINT_LAG',
  SYNC_FACETS: ['SPEC_SYNC', 'LINT_SYNC'],
  CURRENT_EVIDENCE: r.KRAV
});
for (const r of (T.SAKNAD_HANDOFFENHET || [])) nya.push({
  id: r.ENHET, OWNER_ID: String(r.ENHET).split('::')[2].split('-')[0],
  REQUIREMENT_ID: 'HANDOFF_RULE_' + String(r.ENHET).split('::')[2].split('-')[0],
  REQUIREMENT_SOURCE: 'Butlery tillganglighetshandoff',
  PROVENANCE: 'SOURCE_GROUNDED',
  CATEGORY: 'SPEC_SYNC_REQUIRED',
  CURRENT_STATUS: 'SPEC_LAGS',
  CURRENT_EVIDENCE: r.KRAV
});

const fanns = new Set(ut.enheter.map(x => x.id));
for (const n of nya) if (!fanns.has(n.id)) ut.enheter.push(n);
writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + '\n');
console.log(JSON.stringify({
  $om: 'Korrigeringsrunda 2:s extrakrav, harledda ur repot',
  BASE_UNITS: BAS.enheter.length,
  DERIVED_UNITS_ADDED: nya.length,
  TOTAL_UNITS: ut.enheter.length
}, null, 1));
