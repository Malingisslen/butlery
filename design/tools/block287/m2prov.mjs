// Kor: node tools/block287/m2prov.mjs --root=<kallrot> --overlay=<overlay.json>
//      --population=<pop.json> --index=<idx.json> [--ut=<fil>]
//
// E/G/H/I · M2-regressionen.
//
// HARD REGEL: ett kvarliggande roll- och namnkrav ar INGET bevis for att
// elementet ar en kontroll. Klassningen far bara ga
//
//     kallevidens -> semantisk klass -> krav
//
// aldrig tvartom. Provet faller om nagon av M2:s atta icke-kontroller ater
// dyker upp som produktremediering, och om nagot roll- och namnkrav nagonstans
// i populationen star pa ett element som klassningen sager inte ar en kontroll.
import { readFileSync, writeFileSync } from 'node:fs';
const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root');
const O = JSON.parse(readFileSync(arg('overlay'), 'utf8'));
const POP = JSON.parse(readFileSync(arg('population'), 'utf8'));
const IDX = JSON.parse(readFileSync(arg('index'), 'utf8'));
const KOR = JSON.parse(readFileSync(ROT + '/fas2/block287-censuskorrigering.json', 'utf8'));

const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });

/* ── H · reproducera M2:s nio ur klassningen ─────────────────────────────── */
const M2 = KOR.J_ACTION_TEXT_OMPROVAD.rader;
const KONTROLL = new Set(['KNOWN_CONTROL']);
const rader = M2.map(r => {
  const f = O.forekomst[r.OCCURRENCE_ID];
  const e = IDX.find(x => x.art === r.RAM && x.ordProd === r.ordProd);
  const klass = f ? f.klass : 'SAKNAS_I_OVERLAGGET';
  const krav = POP.filter(u => u.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED'
    && /^RP::ROLE_AND_NAME::/.test(u.id)
    && (u.OWNER_ID === (f && f.agare) || String(u.id).includes('::' + r.RAM + '::')));
  const egetKrav = krav.filter(u => u.OWNER_ID && f && u.OWNER_ID === f.agare);
  return {
    FRAME: r.RAM,
    SOURCE_ELEMENT: e ? '<' + e.tag + '> #' + r.ordProd : '(saknas i indexet)',
    CURRENT_TEXT: e ? String(e.own || '').trim().slice(0, 60) : null,
    CURRENT_CLASSIFICATION: klass,
    CURRENT_REQUIREMENT_ID: egetKrav.map(u => u.id),
    CURRENT_REQUIRED_ROLE: egetKrav.map(u => u.FINAL_ROLE || null),
    CURRENT_REQUIRED_NAME: e ? (e.name || null) : null,
    M2_CLASSIFICATION: r.NY_KLASS,
    M2_EVIDENCE: r.SKAL,
    SOURCE_OF_CURRENT_REQUIREMENT: egetKrav.length ? 'overlaggets agarkarta via build.mjs' : null,
    SOURCE_OF_M2_DECISION: 'fas2/block287-censuskorrigering.json · J_ACTION_TEXT_OMPROVAD',
    STALE_REQUIREMENT_RESURRECTED: (!KONTROLL.has(klass) && egetKrav.length > 0) ? 'YES' : 'NO',
    FINAL_ANCHOR_REQUIRED: (!KONTROLL.has(klass) && egetKrav.length === 0) ? 0 : (egetKrav.length ? 'AVGORS_AV_MALNYCKELN' : 0)
  };
});
const kontroller = rader.filter(r => KONTROLL.has(r.CURRENT_CLASSIFICATION));
const ickeKontroller = rader.filter(r => !KONTROLL.has(r.CURRENT_CLASSIFICATION) && r.CURRENT_CLASSIFICATION !== 'SAKNAS_I_OVERLAGGET');
const olosta = rader.filter(r => r.CURRENT_CLASSIFICATION === 'SAKNAS_I_OVERLAGGET');

prov('M2-01', 'M2 bestar av nio forekomster', rader.length === 9, rader.length);
prov('M2-02', 'exakt en av de nio ar en kontroll', kontroller.length === 1, kontroller.map(r => r.FRAME).join(','));
prov('M2-03', 'atta ar icke-kontroller', ickeKontroller.length === 8, ickeKontroller.length);
prov('M2-04', 'ingen ar olost', olosta.length === 0, olosta.map(r => r.FRAME).join(','));
prov('M2-05', 'klassningen stammer rad for rad med det registrerade beslutet',
  rader.every(r => r.CURRENT_CLASSIFICATION === r.M2_CLASSIFICATION),
  rader.filter(r => r.CURRENT_CLASSIFICATION !== r.M2_CLASSIFICATION).map(r => r.FRAME + ': ' + r.CURRENT_CLASSIFICATION + ' != ' + r.M2_CLASSIFICATION).join(' | '));
prov('M2-06', 'ingen icke-kontroll har ateruppstatt som produktremediering',
  rader.every(r => r.STALE_REQUIREMENT_RESURRECTED === 'NO'),
  rader.filter(r => r.STALE_REQUIREMENT_RESURRECTED === 'YES').map(r => r.FRAME).join(', '));

/* ── I · samma fel nagon annanstans? ─────────────────────────────────────── */
const klassPerAgare = new Map();
for (const f of Object.values(O.forekomst)) {
  if (!f.agare) continue;
  const e = klassPerAgare.get(f.agare) || { alla: 0, kontroller: 0 };
  e.alla++; if (f.klass === 'KNOWN_CONTROL') e.kontroller++;
  klassPerAgare.set(f.agare, e);
}
const paIckeKontroll = POP.filter(u => u.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED'
  && /^RP::ROLE_AND_NAME::/.test(u.id) && u.OWNER_ID)
  .filter(u => { const e = klassPerAgare.get(u.OWNER_ID); return e && e.alla > 0 && e.kontroller === 0; });
prov('M2-07', 'inget roll- och namnkrav star pa ett element klassningen kallar icke-kontroll',
  paIckeKontroll.length === 0, paIckeKontroll.map(u => u.id).slice(0, 6).join(', '));

const ut = {
  $om: 'E/G/H/I · M2-regressionen: kravet far aldrig vara beviset',
  M2_TOTAL: rader.length,
  M2_CONTROL: kontroller.length,
  M2_NON_CONTROL: ickeKontroller.length,
  M2_UNRESOLVED: olosta.length,
  ROLE_NAME_REQUIREMENT_ON_NONCONTROL_COUNT: paIckeKontroll.length,
  SIX_TARGET_RECONCILIATION: rader,
  prov: res
};
if (arg('ut')) writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + String.fromCharCode(10));
for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  -> ' + r.diag));
console.log('\nM2_TOTAL ' + ut.M2_TOTAL + ' | CONTROL ' + ut.M2_CONTROL + ' | NON_CONTROL ' + ut.M2_NON_CONTROL
  + ' | UNRESOLVED ' + ut.M2_UNRESOLVED + ' | ROLE_NAME_ON_NONCONTROL ' + ut.ROLE_NAME_REQUIREMENT_ON_NONCONTROL_COUNT);
console.log('PROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
