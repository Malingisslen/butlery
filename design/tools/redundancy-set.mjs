// Butlery · OMSESIDIG REDUNDANS SOM MASKINLASBAR INVARIANT.
//
// FELKLASSEN MODULEN FINNS FOR
// Tva grafiska delar kan vara utbytbara mot varandra: faltets kant och
// faltets fyllning gor var for sig faltet urskiljbart. Bada kan darfor
// enskilt domas SUPPLEMENTAL_NOT_REQUIRED — helt korrekt, var for sig.
// Men tva korrekta enskilda domar far INTE laggas ihop till "bada kan tas
// bort". Da forsvinner komponenten.
//
// Prosa i en rapport rader inte det. Invarianten maste vara lasbar for en
// maskin och provbar i regression.
//
// Setet ar INTE en gruppdom, INTE en gemensam tillamplighetsidentitet, INTE
// ett bevis att nagon member ar REQUIRED, INTE en design token och INTE ett
// R-04-beslut. Det uttrycker bara den observerade gemensamma villkoret.

export const PROVENANS = Object.freeze({
  HUMAN_OCCURRENCE_ADJUDICATION: 'HUMAN_OCCURRENCE_ADJUDICATION' });

export function redundancySet({ REDUNDANCY_SET_ID, MEMBERS, MIN_DISTINGUISHABLE_MEMBERS = 1,
    PROVENANCE, EVIDENCE_ID = null, SCENE = null }) {
  if (!REDUNDANCY_SET_ID) throw new Error('REDUNDANCY_SET_ID saknas');
  if (!Array.isArray(MEMBERS) || MEMBERS.length < 2)
    throw new Error('ett redundansset kraver minst tva members');
  if (new Set(MEMBERS).size !== MEMBERS.length)
    throw new Error('dubblett bland members');
  if (!Number.isInteger(MIN_DISTINGUISHABLE_MEMBERS) || MIN_DISTINGUISHABLE_MEMBERS < 1 ||
      MIN_DISTINGUISHABLE_MEMBERS > MEMBERS.length)
    throw new Error('MIN_DISTINGUISHABLE_MEMBERS ligger utanfor [1, antal members]');
  if (PROVENANCE !== PROVENANS.HUMAN_OCCURRENCE_ADJUDICATION)
    throw new Error('ett redundansset far bara skapas av occurrence-adjudicering');
  return Object.freeze({ REDUNDANCY_SET_ID, MEMBERS: Object.freeze([...MEMBERS]),
    MIN_DISTINGUISHABLE_MEMBERS, PROVENANCE, EVIDENCE_ID, SCENE,
    GROUP_VERDICT: null,
    SHARED_APPLICABILITY_IDENTITY: null,
    IMPLIES_MEMBER_REQUIRED: false,
    IS_DESIGN_TOKEN: false, IS_R04_DECISION: false, R04_CREDIT: 0,
    $betydelse: 'A far neutraliseras om B forblir visuellt urskiljbar. B far neutraliseras ' +
      'om A forblir visuellt urskiljbar. A och B far inte neutraliseras samtidigt.' });
}

/* Grinden. Tar det FAKTISKA urskiljbarhetslaget for varje member och svarar
 * om setet halls. Enskilda SUPPLEMENTAL-domar ingar med flit INTE i
 * berakningen: domen sager vad en del inte kravs for pa egen hand, inte att
 * den far tas bort tillsammans med sin partner. */
export function redundancyGate(set, urskiljbarhet) {
  const okanda = set.MEMBERS.filter(m => typeof urskiljbarhet[m] !== 'boolean');
  if (okanda.length) return { HALLER: false, skal: 'omatt urskiljbarhet', okanda };
  const kvar = set.MEMBERS.filter(m => urskiljbarhet[m] === true);
  const haller = kvar.length >= set.MIN_DISTINGUISHABLE_MEMBERS;
  return { HALLER: haller, URSKILJBARA: kvar.length,
    KRAVS: set.MIN_DISTINGUISHABLE_MEMBERS, kvarvarande: kvar,
    skal: haller ? 'minst ' + set.MIN_DISTINGUISHABLE_MEMBERS + ' member ar urskiljbar'
      : 'farre an ' + set.MIN_DISTINGUISHABLE_MEMBERS + ' member ar urskiljbar' };
}

/* Far bada members neutraliseras darfor att bada har domen
 * SUPPLEMENTAL_NOT_REQUIRED? Nej. Aldrig. */
export function farNeutraliseraSamtidigt(set, domar) {
  const alla = set.MEMBERS.every(m => domar[m] === 'SUPPLEMENTAL_NOT_REQUIRED');
  return { tillatet: false,
    allaSupplemental: alla,
    skal: 'tva enskilda SUPPLEMENTAL_NOT_REQUIRED-domar summerar aldrig till att bada far ' +
      'neutraliseras. Domen galler varje member for sig, med den andra kvar i scenen. ' +
      'Redundansgrinden kraver ' + set.MIN_DISTINGUISHABLE_MEMBERS + ' urskiljbar member.',
    grind: redundancyGate(set, Object.fromEntries(set.MEMBERS.map(m => [m, false]))) };
}

/* En member-dom skapar aldrig en dom om nagon annan member. */
export function harledMedlemsdom() {
  return { tillatet: false,
    skal: 'ett redundansset ar inte en gruppdom. Att A ar SUPPLEMENTAL innebar varken att B ' +
      'ar REQUIRED eller att B ar SUPPLEMENTAL.' };
}

/* Ett set stanger aldrig kontrollen. */
export function gerControlLevelClosure() { return false; }
