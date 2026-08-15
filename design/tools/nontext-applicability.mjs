// F2-NT · NAR ETT KONTROLLGRAFISKT OBJEKT OMFATTAS AV ICKE-TEXTKRAVET.
//
// FELET MODULEN STANGER
// Matningen hade en genvag: bar kontrollen synlig text sa ar dess fyllning och
// ram SUPPLEMENTAL, punkt. Den regeln ar for bred. Synlig text ar EVIDENS for
// att kontrollen gar att identifiera — den ar inte automatiskt ett slutligt
// applicability-svar. Ett textord kan ligga i ett omrade som utan sin ram inte
// gar att skilja fran vanlig statisk text, och da bar ramen identiteten.
//
// LIKA VIKTIGT: den motsatta genvagen ar ocksa fel. "Namntext racker,
// statustext racker inte" ar INTE metodnyckeln. "Ledig" ar statustext men kan
// tillsammans med veckodagen, instruktionen och layouten gora den interaktiva
// platsen fullt begriplig. Requiredness avgors ur den FULLA visuella
// kontexten i den faktiska forekomsten.
//
// NORMATIV FRAGA, per forekomst:
//   Om just denna border/fill/form inte gick att urskilja — finns det anda
//   tillrackligt med annan VISUELL information for att anvandaren ska kunna
//   identifiera
//     A  att kontrollen finns
//     B  hur den kan anvandas
//     C  relevant tillstand, nar tillstandet beror pa grafiken?
//
// Annan visuell information kan komma fran synlig text, ikon, position,
// textstil, omgivande instruktion eller etablerad layout. INGEN av dem far
// ensam automatiskt ge PASS.
//
// KVOTEN AVGOR ALDRIG. En del under 3.0 blir inte kravd av att den ar svag,
// och en del over 3.0 blir inte valfri av att den ar stark.

export const TILLAMPLIGHET = Object.freeze({
  TEXT_OR_CONTEXT_SUFFICIENT: 'TEXT_OR_CONTEXT_SUFFICIENT',
  NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL: 'NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL',
  NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE: 'NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE',
  SUPPLEMENTAL_NON_TEXT_VISUAL: 'SUPPLEMENTAL_NON_TEXT_VISUAL',
  UNKNOWN_APPLICABILITY: 'UNKNOWN_APPLICABILITY' });

/* Iakttagelsen "objektet bar synlig text" ar en OBSERVATION, aldrig en klass. */
export const OBSERVATION = Object.freeze({
  VISIBLE_TEXT_PRESENT: 'VISIBLE_TEXT_PRESENT' });

/* Sjalvstandiga visuella ledtradar. Var och en far RAKNAS, ingen far AVGORA. */
export const LEDTRAD = Object.freeze({
  GLYPH_PRESENT: 'GLYPH_PRESENT',
  TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT: 'TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT',
  OTHER_PAINTED_DIFFERENTIATOR_ON_SAME_CONTROL: 'OTHER_PAINTED_DIFFERENTIATOR_ON_SAME_CONTROL',
  AUTHORED_INSTRUCTION_IN_CONTEXT: 'AUTHORED_INSTRUCTION_IN_CONTEXT' });

/* Minst tva OBEROENDE ledtradar kravs for att skarma av som tillracklig.
 * En ensam ledtrad ar aldrig nog — det ar hela poangen med korrigeringen. */
export const MINST_ANTAL_LEDTRADAR = 2;

/**
 * Skarmningsprov, per forekomst. Returnerar ALDRIG ett konformansutfall —
 * bara vilken tillamplighetsklass forekomsten hamnar i, och varfor.
 *
 * f = {
 *   harSynligText            bool   OBSERVATION, aldrig avgorande
 *   ledtradar                [LEDTRAD]
 *   ensamMaladDifferentiator bool   ar DENNA del det enda malade som skiljer
 *                                   kontrollen fran omgivningen?
 *   typografiskSkild         bool
 *   harGlyf                  bool
 *   tillstandBerorGrafiken   bool
 *   manskligBedomning        'REQUIRED' | 'SUFFICIENT' | null
 * }
 */
export function tillamplighet(f) {
  const ledtradar = Array.isArray(f.ledtradar) ? [...new Set(f.ledtradar)] : [];

  /* En manskligt levererad bedomning gar fore skarmningen — men bara nar den
   * faktiskt ar levererad. Den raknas aldrig fram ur kvoten. */
  if (f.manskligBedomning === 'REQUIRED')
    return { klass: f.tillstandBerorGrafiken
        ? TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE
        : TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL,
      ledtradar, skal: 'levererad bedomning: grafiken kravs' };
  if (f.manskligBedomning === 'SUFFICIENT')
    return { klass: TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT, ledtradar,
      skal: 'levererad bedomning: ovrig visuell information racker' };

  /* POSITIV EVIDENS FOR KRAV: delen ar det enda malade som skiljer kontrollen
   * fran sin omgivning, kontrollen har ingen glyf, och dess text ar
   * typografiskt oskiljbar fran texten omkring. Da forsvinner kontrollen in i
   * den statiska texten om delen inte gar att urskilja. */
  if (f.ensamMaladDifferentiator === true && f.harGlyf === false &&
      f.typografiskSkild === false)
    return { klass: f.tillstandBerorGrafiken
        ? TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE
        : TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL,
      ledtradar,
      skal: 'delen ar den enda malade avgransningen, kontrollen saknar glyf och dess text ar ' +
        'typografiskt oskiljbar fran texten omkring — utan delen finns ingen kvarvarande ' +
        'visuell markor for att en kontroll finns' };

  /* POSITIV EVIDENS FOR TILLRACKLIGHET: minst tva oberoende ledtradar OCH
   * delen ar inte den enda malade avgransningen. */
  if (ledtradar.length >= MINST_ANTAL_LEDTRADAR && f.ensamMaladDifferentiator === false)
    return { klass: TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT, ledtradar,
      skal: ledtradar.length + ' oberoende visuella ledtradar och delen ar inte den enda ' +
        'malade avgransningen: ' + ledtradar.join(', ') };

  /* Allt annat faller stangt. Synlig text ensam racker aldrig hit. */
  return { klass: TILLAMPLIGHET.UNKNOWN_APPLICABILITY, ledtradar,
    skal: 'evidensen avgor inte om delen behovs for att identifiera kontrollen' +
      (f.harSynligText ? ' — synlig text ar noterad som observation, inte som svar' : '') };
}

/** Kvoten far aldrig rora tillampligheten. Provas explicit av GP-13 och GP-14. */
export function tillamplighetOberoendeAvKvot(f, kvot) {
  void kvot;
  return tillamplighet(f);
}

/* ── KONFORMANSUTFALL, FORST EFTER TILLAMPLIGHET ────────────────────── */
export const UTFALL = Object.freeze({
  FINDING: 'FINDING',
  PASS: 'PASS',
  NOT_APPLICABLE: 'NOT_APPLICABLE',
  APPLICABILITY_REVIEW_REQUIRED: 'APPLICABILITY_REVIEW_REQUIRED' });

/**
 * klass  ur TILLAMPLIGHET
 * kvot   uppmatt kontrast mot faktiskt malad angransande farg, eller null
 * krav   troskelvardet, levereras av anroparen (graphic-part-requirement)
 */
export function konformansutfall(klass, kvot, krav) {
  if (klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY)
    return { utfall: UTFALL.APPLICABILITY_REVIEW_REQUIRED, kvot,
      skal: 'tillampligheten ar inte avgjord — ingen konformansslutsats far dras' };
  if (klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT ||
      klass === TILLAMPLIGHET.SUPPLEMENTAL_NON_TEXT_VISUAL)
    return { utfall: UTFALL.NOT_APPLICABLE, kvot,
      skal: 'delen kravs inte for att identifiera kontrollen eller dess tillstand' };
  if (kvot === null || kvot === undefined)
    return { utfall: UTFALL.APPLICABILITY_REVIEW_REQUIRED, kvot,
      skal: 'delen kravs men kvoten kunde inte matas' };
  return kvot >= krav
    ? { utfall: UTFALL.PASS, kvot, skal: 'kravd del nar troskeln' }
    : { utfall: UTFALL.FINDING, kvot, skal: 'kravd del nar inte troskeln' };
}
