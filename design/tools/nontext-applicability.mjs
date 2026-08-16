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

/* Omstandigheter i scenen. RAPPORTERANDE ENDAST. De beskrivs som fri text
 * och deltar ALDRIG i verdictlogiken — varken till antal eller till klass.
 *
 * TVA RATTNINGAR HAR GJORTS HAR
 *   1  "minst tva oberoende ledtradar" var en rakningsgrind. Borttagen.
 *   2  STARK/SVAG var en styrketaxonomi som producerade verdict. Borttagen.
 *
 * Bada var uppfunna grindar. SC 1.4.11 vilar pa TILLRACKLIGHET av visuell
 * identifiering i den faktiska scenen, betraktad SOM HELHET. Flera
 * omstandigheter som var for sig ar otillrackliga kan tillsammans racka, och
 * inget enskilt attribut och inget antal attribut far ge verdict.
 */

/**
 * Tillamplighetsprovet, per forekomst.
 *
 * DEN ENDA NORMATIVA FRAGAN — counterfactual i den faktiska scenen:
 *   Om den undersokta icke-textdelen inte kunde urskiljas, finns det anda
 *   tillracklig visuell information, betraktad som helhet, for att
 *   identifiera att kontrollen finns, hur den kan anvandas, och relevant
 *   tillstand nar tillstandet ar det som undersoks?
 *
 * f = {
 *   harSynligText           bool          OBSERVATION, aldrig avgorande
 *   evidens                 [string]      RAPPORTERANDE. Beskriver scenen.
 *                                         Paverkar aldrig returklassen.
 *   holistiskBedomning      'SUFFICIENT' | 'NOT_SUFFICIENT' | null
 *                                         Den enda normativa ingangen.
 *   bedomningsskal          string
 *   tillstandBerorGrafiken  bool
 * }
 */
export function tillamplighet(f) {
  const evidens = Array.isArray(f.evidens) ? f.evidens.slice() : [];
  const diagnostik = { evidens,
    $not: 'Rapporterande. Varken innehallet eller antalet paverkar klassen.' };

  if (f.holistiskBedomning === 'SUFFICIENT')
    return { klass: TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT, diagnostik,
      skal: f.bedomningsskal || 'holistisk bedomning: scenen identifierar kontrollen aven ' +
        'utan den undersokta delen' };

  if (f.holistiskBedomning === 'NOT_SUFFICIENT')
    return { klass: f.tillstandBerorGrafiken
        ? TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE
        : TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL,
      diagnostik,
      skal: f.bedomningsskal || 'holistisk bedomning: scenen identifierar INTE kontrollen ' +
        'utan den undersokta delen' };

  return { klass: TILLAMPLIGHET.UNKNOWN_APPLICABILITY, diagnostik,
    skal: 'den holistiska tillrackligheten ar inte bedomd for denna forekomst' +
      (f.harSynligText ? '. Synlig text ar noterad som observation, inte som svar.' : '') };
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
