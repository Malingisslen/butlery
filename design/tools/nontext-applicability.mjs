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

/* Visuella ledtradar. De redovisas DIAGNOSTISKT. Antalet avgor ingenting.
 *
 * FELET SOM RATTADES 2026-08-16
 * En tidigare version krayde "minst tva oberoende ledtradar" for att skarma
 * av en del som tillracklig. Det ar ingen giltig normativ regel. SC 1.4.11
 * vilar pa TILLRACKLIGHET i den faktiska scenen, inte pa ett minsta antal
 * signaler. EN stark signal kan racka. TRE svaga kan vara otillrackliga. */
export const LEDTRAD = Object.freeze({
  GLYPH_PRESENT: 'GLYPH_PRESENT',
  TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT: 'TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT',
  OTHER_PAINTED_DIFFERENTIATOR_ON_SAME_CONTROL: 'OTHER_PAINTED_DIFFERENTIATOR_ON_SAME_CONTROL',
  AUTHORED_INSTRUCTION_IN_CONTEXT: 'AUTHORED_INSTRUCTION_IN_CONTEXT',
  ESTABLISHED_POSITION_IN_LAYOUT: 'ESTABLISHED_POSITION_IN_LAYOUT',
  CONTROL_CONTENT_ITSELF: 'CONTROL_CONTENT_ITSELF' });

/* STYRKAN ar en bedomning per forekomst, inte en summa. En ledtrad ar STARK
 * bara nar den i DEN HAR scenen ensam identifierar att kontrollen finns och
 * hur den anvands. Allt annat ar SVAGT och kan aldrig, i nagot antal, bli
 * tillrackligt. */
export const STYRKA = Object.freeze({ STARK: 'STARK', SVAG: 'SVAG' });

/* Den enda vagen till tillracklighet: minst en ledtrad som ar bedomd STARK.
 * Det ar ingen rakning — en STARK ar en bedomning om att just den signalen
 * identifierar kontrollen. Hundra SVAGA ger fortfarande ingenting. */
function harStark(bedomda) {
  return (Array.isArray(bedomda) ? bedomda : []).some(b => b && b.styrka === STYRKA.STARK);
}

/**
 * Tillamplighetsprovet, per forekomst. Returnerar ALDRIG ett konformansutfall.
 *
 * DEN NORMATIVA FRAGAN — counterfactual i den faktiska scenen:
 *   Om den undersokta icke-textdelen inte kunde urskiljas, finns det anda
 *   TILLRACKLIG visuell information for att identifiera att kontrollen finns,
 *   hur den anvands, och relevant tillstand nar tillstandet ar fragan?
 *
 * f = {
 *   harSynligText            bool  OBSERVATION, aldrig avgorande
 *   bedomdaLedtradar         [{ ledtrad, styrka, skal }]  styrkan ar bedomd,
 *                                  aldrig raknad
 *   ingenAlternativIdentifiering  bool  positiv evidens for att INGEN annan
 *                                  visuell identifiering finns i scenen
 *   tillstandBerorGrafiken   bool
 *   manskligBedomning        'REQUIRED' | 'SUFFICIENT' | null
 * }
 */
export function tillamplighet(f) {
  const bedomda = Array.isArray(f.bedomdaLedtradar) ? f.bedomdaLedtradar : [];
  const ledtradar = bedomda.map(b => b.ledtrad);
  const starka = bedomda.filter(b => b.styrka === STYRKA.STARK).map(b => b.ledtrad);
  const svaga = bedomda.filter(b => b.styrka !== STYRKA.STARK).map(b => b.ledtrad);
  const diagnostik = { ledtradar, starka, svaga, antalLedtradar: ledtradar.length,
    $not: 'Antalet redovisas diagnostiskt och avgor ingenting.' };

  /* En levererad bedomning gar fore. Den raknas aldrig fram ur kvoten. */
  if (f.manskligBedomning === 'REQUIRED')
    return { klass: f.tillstandBerorGrafiken
        ? TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE
        : TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL,
      diagnostik, skal: 'levererad bedomning: grafiken kravs i den faktiska scenen' };
  if (f.manskligBedomning === 'SUFFICIENT')
    return { klass: TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT, diagnostik,
      skal: 'levererad bedomning: ovrig visuell information identifierar kontrollen' };

  /* TILLRACKLIGHET: minst en ledtrad ar bedomd STARK i denna forekomst. */
  if (harStark(bedomda))
    return { klass: TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT, diagnostik,
      skal: 'minst en ledtrad ar bedomd STARK i den faktiska scenen: ' + starka.join(', ') +
        '. Bedomningen galler den signalens identifierande kraft, inte antalet signaler.' };

  /* KRAV: positiv evidens for att ingen annan visuell identifiering finns. */
  if (f.ingenAlternativIdentifiering === true)
    return { klass: f.tillstandBerorGrafiken
        ? TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE
        : TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL,
      diagnostik,
      skal: 'ingen alternativ visuell identifiering finns i scenen — utan delen aterstar ' +
        'ingen markor for att en kontroll finns' };

  /* Allt annat faller stangt. Svaga ledtradar summerar aldrig till nagot. */
  return { klass: TILLAMPLIGHET.UNKNOWN_APPLICABILITY, diagnostik,
    skal: 'tillrackligheten ar inte bedomd' +
      (svaga.length ? ' — ' + svaga.length + ' svaga ledtradar finns men svaga signaler ' +
        'summerar aldrig till tillracklighet' : '') +
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
