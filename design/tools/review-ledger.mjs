// F2 · GRANSKNINGSLIGGAREN.  UNRESOLVED AR INTE SAMMA SAK SOM UNREVIEWED.
//
// FELET MODULEN STANGER
// CLEANEST-FIRST-selectorn byggde sin valbara population som "alla kandidater
// minus de som har ett verdikt som inte ar UNKNOWN". En kandidat som HAR
// granskats och landat i UNKNOWN blev darmed exakt lika valbar som en som
// aldrig setts. Foljden ar en tyst slinga: samma svarbedomda objekt kan
// plockas om och om igen, varje gang med samma evidens, och varje omgang ser
// ut som nytt arbete.
//
// TRE TILLSTAND, ALDRIG TVA
//   UNREVIEWED         aldrig adjudicerad
//   REVIEWED_RESOLVED  adjudicerad med ett terminalt verdikt
//   REVIEWED_UNKNOWN   adjudicerad, och UNKNOWN var svaret
//
// REVIEWED_UNKNOWN ar ett RIKTIGT resultat. Det raknas fortsatt som
// unresolved — populationssiffran andras inte av den har modulen — men det far
// inte automatiskt aterkomma i en ny CLEANEST-FIRST-batch. Att plocka om det
// kraver ett angivet skal.
//
// VAD MODULEN INTE GOR
//   · Den rar inte klustringen. Medlemskap, signaturer och fingeravtryck ar
//     oforandrade.
//   · Den rar inte rankingmodellen. Havstang, vikter och tie-break ar
//     oforandrade. Grinden verkar EFTER ordningen, aldrig i den.
//   · Den andrar ingen historisk totalsiffra.

export const GRANSKNINGSSTATUS = Object.freeze({
  UNREVIEWED: 'UNREVIEWED',
  REVIEWED_RESOLVED: 'REVIEWED_RESOLVED',
  REVIEWED_UNKNOWN: 'REVIEWED_UNKNOWN' });

/** Sista verdiktet for en identitet -> granskningsstatus. null = aldrig granskad. */
export function granskningsstatus(sistaVerdikt) {
  if (sistaVerdikt === null || sistaVerdikt === undefined)
    return GRANSKNINGSSTATUS.UNREVIEWED;
  return sistaVerdikt === 'UNKNOWN'
    ? GRANSKNINGSSTATUS.REVIEWED_UNKNOWN
    : GRANSKNINGSSTATUS.REVIEWED_RESOLVED;
}

/** En REVIEWED_UNKNOWN raknas fortfarande som olost. Statusen ar ortogonal. */
export function arOlost(status) {
  return status === GRANSKNINGSSTATUS.UNREVIEWED ||
         status === GRANSKNINGSSTATUS.REVIEWED_UNKNOWN;
}

/* De enda skal som far ta upp en REVIEWED_UNKNOWN till ny adjudikering. */
export const OMPROVNINGSSKAL = Object.freeze({
  NY_EVIDENS: 'NY_EVIDENS',
  UPPLOST_BEROENDE: 'UPPLOST_BEROENDE',
  EXPLICIT_AUKTORISATION: 'EXPLICIT_AUKTORISATION' });

const GILTIGA = Object.freeze(Object.values(OMPROVNINGSSKAL));

/**
 * Far identiteten inga i en AUTOMATISK CLEANEST-FIRST-batch?
 *
 * status   ur GRANSKNINGSSTATUS
 * skal     null, eller { skal: OMPROVNINGSSKAL, vad: '<konkret beskrivning>' }
 */
export function automatisktValbar(status, skal = null) {
  if (status === GRANSKNINGSSTATUS.REVIEWED_RESOLVED)
    return { valbar: false, skal: 'redan avgjord med ett terminalt verdikt' };
  if (status === GRANSKNINGSSTATUS.UNREVIEWED)
    return { valbar: true, skal: 'aldrig granskad' };
  /* REVIEWED_UNKNOWN */
  if (!skal || !GILTIGA.includes(skal.skal))
    return { valbar: false,
      skal: 'REVIEWED_UNKNOWN kraver ny evidens, upplost beroende eller explicit ' +
        'omprovningsauktorisation — inget angivet' };
  if (typeof skal.vad !== 'string' || skal.vad.trim().length === 0)
    return { valbar: false,
      skal: 'omprovningsskalet ' + skal.skal + ' saknar konkret beskrivning — faller stangt' };
  return { valbar: true, skal: 'omprovning tillaten pa ' + skal.skal + ': ' + skal.vad };
}

/**
 * Delar en partitions medlemmar i det som far adjudiceras automatiskt och det
 * som ar sparrat. MEDLEMSKAPET ANDRAS INTE — bada listorna hor kvar till
 * partitionen, och olosta raknas som forut.
 */
export function batchomfattning(medlemmar, statusAv, skalAv = () => null) {
  const valbara = [], sparrade = [];
  for (const id of medlemmar) {
    const st = statusAv(id);
    const d = automatisktValbar(st, skalAv(id));
    (d.valbar ? valbara : sparrade).push({ identitet: id, status: st, skal: d.skal }); }
  return { valbara, sparrade,
    medlemmarOforandrade: valbara.length + sparrade.length === medlemmar.length,
    partitionValbar: valbara.length > 0,
    $regel: 'Medlemskap, klustring och ranking ar oforandrade. Grinden avgor bara vad en ' +
      'AUTOMATISK batch far adjudicera.' };
}
