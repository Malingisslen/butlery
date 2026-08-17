// Butlery · PLANERINGSKARNAN for kvarvarande UNKNOWN_APPLICABILITY.
//
// FELKLASSEN MODULEN FINNS FOR
// Nar en population blir stor ar frestelsen att lata siffran avgora: "kvoten
// ar over 3, alltsa ar den godkand", "kvoten ar under 3, alltsa ar den ett
// fel", "de har samma farg, alltsa samma dom". Alla tre ar metodfel.
//
// Modulen halter isar tre saker som annars glider ihop:
//   1 TILLAMPLIGHET  — kravs delen for att forsta innehallet? Avgors bara av
//                      occurrence-evidens. Kvoten far aldrig rora den.
//   2 MATT UTFALL    — vad sager kvoten om exakt den nu matta scenen? Ett
//                      rent faktum, aldrig en dom.
//   3 GRUPPERING     — far flera forekomster granskas tillsammans? Bara pa
//                      positiva forhandsdomsfakta, och en grupp bar aldrig en
//                      dom av sig sjalv.

export const APPLICABILITY_STATUS = Object.freeze({
  APPLICABILITY_UNKNOWN: 'APPLICABILITY_UNKNOWN' });

export const RATIO_UTFALL = Object.freeze({
  POSSIBLE_FAIL_IF_REQUIRED: 'POSSIBLE_FAIL_IF_REQUIRED',
  NON_FAIL_IF_APPLICABLE: 'NON_FAIL_IF_APPLICABLE',
  UNMEASURED: 'UNMEASURED' });

export const FORSLAG = Object.freeze({
  PROPOSED_REQUIRED: 'PROPOSED_REQUIRED',
  PROPOSED_SUPPLEMENTAL_NOT_REQUIRED: 'PROPOSED_SUPPLEMENTAL_NOT_REQUIRED',
  PROPOSED_UNKNOWN: 'PROPOSED_UNKNOWN' });

export const SCENIDENTIFIERING = Object.freeze({
  SCENE_IDENTIFIES_WITHOUT_TARGET: 'SCENE_IDENTIFIES_WITHOUT_TARGET',
  SCENE_FAILS_WITHOUT_TARGET: 'SCENE_FAILS_WITHOUT_TARGET',
  UNDETERMINED: 'UNDETERMINED' });

/* ── 1 · BAND OCH MATT UTFALL ───────────────────────────────────────────── */
/* Bandet ar en ren avlasning av kvoten. Det ar INTE en dom och far inte
 * anvandas som en. */
export function band(kvot, krav = 3) {
  if (typeof kvot !== 'number' || Number.isNaN(kvot)) return 'OMATT';
  return kvot < krav ? 'LT_3' : 'GE_3';
}

export function ratioUtfall(kvot, krav = 3) {
  const b = band(kvot, krav);
  if (b === 'OMATT') return RATIO_UTFALL.UNMEASURED;
  return b === 'LT_3' ? RATIO_UTFALL.POSSIBLE_FAIL_IF_REQUIRED
    : RATIO_UTFALL.NON_FAIL_IF_APPLICABLE;
}

/* Statusseparationen. Fungerar BARA pa relationer vars tillamplighet ar
 * UNKNOWN — en relation med dom har ingen "risk", den har ett utfall. */
export function statusSeparation(relation, krav = 3) {
  if (relation.APPLICABILITY_VERDICT !== 'UNKNOWN')
    throw new Error('statusSeparation kraver APPLICABILITY_VERDICT = UNKNOWN, fick ' +
      relation.APPLICABILITY_VERDICT);
  return { APPLICABILITY_STATUS: APPLICABILITY_STATUS.APPLICABILITY_UNKNOWN,
    APPLICABILITY_VERDICT: 'UNKNOWN',
    CURRENT_RATIO_OUTCOME: ratioUtfall(relation.MEASURED_RATIO, krav),
    R04_CREDIT: 0,
    $galler: 'exakt den nu matta scenen och det nu matta tillstandet',
    $gallerInte: ['andra states', 'andra teman', 'andra viewportar',
      'tillamplighet', 'konformans'] };
}

/* ── 2 · GRUPPERING ─────────────────────────────────────────────────────── */
/* Fakta som FAR bilda en review group. Alla ar positiva forhandsdomsfakta. */
export const TILLATNA_GRUPPFAKTA = Object.freeze([
  'COMPONENT_SIGNATURE',            // bestaende komponent-/familjidentitet
  'PART_FUNCTION',                  // samma grafiska delfunktion + relation till kroppen
  'EXPLICIT_STATE',                 // samma explicit deklarerade tillstand
  'ADJACENT_SURFACE_CLASS',         // samma faktiska angransande yta
  'VISIBLE_ALTERNATIVE_CARRIERS',   // samma uppsattning synliga alternativa barare
  'COMPONENT_GEOMETRY_CLASS',       // samma komponentgeometri (skiljer verkliga viewportvarianter)
  'THEME',
  'DOCUMENTED_OPERATION' ]);        // bara dar operationen redan ar explicit kand

/* Fakta som ALDRIG racker for semantisk ekvivalens. */
export const OTILLATNA_GRUPPFAKTA = Object.freeze([
  'RAW_COLOUR', 'MEASURED_RATIO', 'CONTROL_ROLE_ALONE', 'CONTROL_TYPE_ALONE',
  'VISIBLE_TEXT_PRESENT', 'VISIBLE_TEXT_ABSENT', 'ICON_SHAPE',
  'PHYSICAL_PROXIMITY', 'SAME_SCREEN', 'SAME_BACKGROUND_ALONE',
  'MAJORITY_VERDICT', 'ACCESSIBLE_NAME' ]);

export function grupperingsnyckel(fakta) {
  const nycklar = Object.keys(fakta);
  const otillatna = nycklar.filter(k => OTILLATNA_GRUPPFAKTA.includes(k));
  if (otillatna.length)
    throw new Error('otillatet grupperingsfaktum: ' + otillatna.join(', '));
  const okanda = nycklar.filter(k => !TILLATNA_GRUPPFAKTA.includes(k));
  if (okanda.length) throw new Error('okant grupperingsfaktum: ' + okanda.join(', '));
  return TILLATNA_GRUPPFAKTA.filter(k => k in fakta).map(k => fakta[k]).join(' | ');
}

/* En review group bar ALDRIG en dom. */
export function gruppdom(grupp) {
  return { GROUP_ID: grupp.GROUP_ID, OCCURRENCES: grupp.OCCURRENCES,
    APPLICABILITY_VERDICT: null, GROUP_VERDICT: null,
    HUMAN_EQUIVALENCE_GATE: 'NOT_PASSED',
    $regel: 'Gruppering ar presentation. Den skapar ingen semantisk ekvivalens och ' +
      'ingen dom. Varje forekomst behaller egen identitet.' };
}

/* ── 3 · MANSKLIG EKVIVALENSGRIND ───────────────────────────────────────── */
export const EKVIVALENSKRAV = Object.freeze([
  'component function',
  'relevant operation/state',
  'carrier responsibility',
  'scene-level identification mechanism',
  'counterfactual consequence when the target part is removed' ]);

/* Grinden kan bara passeras av manskligt actual-scene-bevis, aldrig av
 * grupperingsalgoritmen. Saknas ett kriterium, eller skiljer sig en medlem,
 * ska gruppen splittras. */
export function farFaGemensamDom(grind) {
  if (!grind || grind.BESLUTSKALLA !== 'HUMAN_ACTUAL_SCENE_EVIDENCE')
    return { tillatet: false, skal: 'grinden far bara passeras av manskligt actual-scene-bevis' };
  const saknas = EKVIVALENSKRAV.filter(k => grind[k] !== true);
  if (saknas.length) return { tillatet: false, skal: 'ej styrkt: ' + saknas.join('; '),
    atgard: 'SPLIT_GROUP' };
  if (Array.isArray(grind.avvikandeMedlemmar) && grind.avvikandeMedlemmar.length)
    return { tillatet: false, skal: 'medlem skiljer sig: ' + grind.avvikandeMedlemmar.join(', '),
      atgard: 'SPLIT_GROUP' };
  return { tillatet: true, skal: 'alla fem kriterier styrkta ur faktisk scen' };
}

/* ── 4 · ALTERNATIVA BARARE ─────────────────────────────────────────────── */
/* En supplemental-dom far aldrig vila pa en osynlig eller omatt barare, och
 * heller inte pa text eller pa ett tillgangligt namn. */
export function provaCarrier(carrier) {
  if (!carrier) return { godkand: false, MEASUREMENT_GAP: true, skal: 'ingen barare angiven' };
  if (carrier.typ === 'TEXT' || carrier.typ === 'ACCESSIBLE_NAME')
    return { godkand: false, MEASUREMENT_GAP: false,
      skal: 'text och tillgangligt namn ar aldrig visuell barareevidens' };
  if (carrier.OMFATTAS_AV_1_4_11 && !(carrier.KANONISK_DEL && carrier.MATT))
    return { godkand: false, MEASUREMENT_GAP: true,
      skal: 'bararen omfattas av SC 1.4.11 men finns inte som kanonisk matt grafisk del' };
  if (!carrier.SYNLIG_I_SCENEN)
    return { godkand: false, MEASUREMENT_GAP: false, skal: 'bararen ar inte synlig i scenen' };
  return { godkand: true, MEASUREMENT_GAP: false, PART_ID: carrier.PART_ID };
}

/* ── 5 · FORSLAG PER FOREKOMST ──────────────────────────────────────────── */
/* Funktionen tar INTE emot malets kvot. Kvoten kan darmed inte pavercka
 * forslaget ens av misstag. Den holistiska fragan besvaras ur den
 * kontrafaktiska sonden mot faktisk scen. */
export function forslag(bevis) {
  const ut = { FORSLAG: FORSLAG.PROPOSED_UNKNOWN, MEASUREMENT_GAP: false,
    CARRIERS: [], skal: null, R04_CREDIT: 0,
    $ejRegisterdom: 'Ett forslag ar inte en applicability record och skrivs inte permanent.' };
  if ('MEASURED_RATIO' in bevis || 'CURRENT_RATIO' in bevis)
    throw new Error('forslag() far inte se malets kvot');
  if (bevis.STATE_UNDER_TEST === 'STATE_OUT_OF_SCOPE') {
    ut.skal = 'pressed / inactive / focus ar oprovade och far varken dom eller credit';
    return ut; }
  if (!bevis.COUNTERFACTUAL_KORD) {
    ut.skal = 'ingen kontrafaktisk sond mot faktisk scen'; return ut; }
  if (bevis.SCENIDENTIFIERING === SCENIDENTIFIERING.SCENE_FAILS_WITHOUT_TARGET) {
    ut.FORSLAG = FORSLAG.PROPOSED_REQUIRED;
    ut.skal = 'scenen identifierar inte langre komponenten eller dess relevanta ' +
      'operation/tillstand nar exakt denna del gors visuellt oskiljbar';
    return ut; }
  if (bevis.SCENIDENTIFIERING !== SCENIDENTIFIERING.SCENE_IDENTIFIES_WITHOUT_TARGET) {
    ut.skal = 'scenens identifiering utan malet gick inte att avgora'; return ut; }
  const provade = (bevis.ALTERNATIVE_CARRIERS || []).map(provaCarrier);
  ut.CARRIERS = provade.filter(x => x.godkand).map(x => x.PART_ID);
  if (provade.some(x => x.MEASUREMENT_GAP)) {
    ut.MEASUREMENT_GAP = true;
    ut.skal = 'en aberopad barare ar inte en kanonisk matt grafisk del — domen stoppas';
    return ut; }
  if (!ut.CARRIERS.length) {
    ut.skal = 'ingen godkand visuell alternativ barare kunde pekas ut'; return ut; }
  ut.FORSLAG = FORSLAG.PROPOSED_SUPPLEMENTAL_NOT_REQUIRED;
  ut.skal = 'scenen identifierar komponenten och dess relevanta operation/tillstand ' +
    'aven nar exakt denna del gors visuellt oskiljbar; identifieringen bars av ' +
    ut.CARRIERS.join(', ');
  return ut;
}

/* Ett forslag far aldrig skrivas som en applicability record i detta skede. */
export function farSkrivasSomRegisterdom() { return false; }
