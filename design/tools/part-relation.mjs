// F2-NT · RELATIONSPOSTEN FOR EN GRAFISK DEL.
//
// VAD DEN FINNS FOR
// Fram till 2026-08-16 lag matning och normativ dom i samma falt. En del som
// hamnat i den tekniska hinken 'supplemental' fick kvot null och status
// ejKravd, och hinken sattes bland annat av regeln "kontrollen har egen synlig
// text". Effekten var att ett ord bredvid en malad grans gjorde gransen
// omatt och darmed i praktiken ej kravd.
//
// Den har modulen haller isar fyra saker som aldrig far blandas:
//
//   1  VAD SOM FAKTISKT MALAS      · delens identitet och malande kalla
//   2  UPPMATT KONTRAST            · ett tal, ingenting mer
//   3  NORMATIV TILLAMPLIGHET      · kravs delen for att kontrollen ska ga
//                                     att identifiera eller dess tillstand
//                                     uppfattas?
//   4  KONFORMANSDOM               · foljden av 2 och 3 tillsammans
//
// Ingen av niva 1 eller 2 far avgora niva 3. Det galler sarskilt:
//
//   · synlig text ar en OBSERVATION, aldrig en dom
//   · franvaro av synlig text ar ocksa en observation, aldrig en dom
//   · accessible name ar INTE visuell evidens for SC 1.4.11
//   · en ikon ar varken automatiskt tillracklig eller otillracklig
//   · kvoten far aldrig avgora om delen kravs
//   · samma kontrollroll, samma fargpar och samma kvot far aldrig
//     propagera en dom mellan forekomster
//
// UNKNOWN ar ett legitimt svar och ar default. Fail closed.

export const TILLAMPLIGHET = Object.freeze({
  REQUIRED: 'REQUIRED',
  SUPPLEMENTAL_NOT_REQUIRED: 'SUPPLEMENTAL_NOT_REQUIRED',
  UNKNOWN: 'UNKNOWN' });

export const KONFORMANS = Object.freeze({
  REQUIRED_PASS: 'REQUIRED_PASS',
  REQUIRED_FAIL: 'REQUIRED_FAIL',
  NOT_APPLICABLE: 'NOT_APPLICABLE',
  UNKNOWN: 'UNKNOWN' });

/* Teknisk beskrivning av matvardet nar tillampligheten annu ar okand. Den ar
 * INTE en dom och far aldrig redovisas som pass eller fail. */
export const TEKNISKT = Object.freeze({
  TECHNICALLY_PASSES_IF_REQUIRED: 'TECHNICALLY_PASSES_IF_REQUIRED',
  TECHNICALLY_FAILS_IF_REQUIRED: 'TECHNICALLY_FAILS_IF_REQUIRED',
  NOT_MEASURED: 'NOT_MEASURED' });

/* Evidenskallor som FAR bara en tillamplighetsdom. Alla ar occurrence-specifika. */
export const EVIDENSKALLA = Object.freeze({
  HUMAN_OCCURRENCE_DECISION: 'HUMAN_OCCURRENCE_DECISION',
  AUTHORED_DECLARATION: 'AUTHORED_DECLARATION',
  COUNTERFACTUAL_SCENE_REVIEW: 'COUNTERFACTUAL_SCENE_REVIEW' });

/* Iakttagelser. RAPPORTERANDE ENDAST. Ingen av dem ar en dom. */
export const OBSERVATION = Object.freeze({
  VISIBLE_TEXT_PRESENT: 'VISIBLE_TEXT_PRESENT',
  VISIBLE_TEXT_ABSENT: 'VISIBLE_TEXT_ABSENT',
  VISIBLE_ICON_PRESENT: 'VISIBLE_ICON_PRESENT',
  VISIBLE_ICON_ABSENT: 'VISIBLE_ICON_ABSENT',
  ACCESSIBLE_NAME_PRESENT: 'ACCESSIBLE_NAME_PRESENT',
  OTHER_VISUAL_CUES: 'OTHER_VISUAL_CUES',
  STATE_RELEVANCE: 'STATE_RELEVANCE' });

/**
 * Bygger en fullstandig relationspost. Alla falt ar separata och ingen
 * harleds ur nagon annan.
 *
 * m = {
 *   PART_DETECTED, PART_IDENTITY, CONTROL_IDENTITY, PAINT_SOURCE,
 *   OUTSIDE_ADJACENT_SURFACE, MEASURED_RATIO,
 *   VISIBLE_TEXT_PRESENT, VISIBLE_ICON_PRESENT, ACCESSIBLE_NAME,
 *   OTHER_VISUAL_CUES, STATE_RELEVANCE, CONTEXT_DESCRIPTION,
 *   tillamplighet: { verdikt, evidenskalla, motivering } | null
 * }
 */
export function relation(m, krav = 3) {
  const t = m && m.tillamplighet;
  const verdikt = t && Object.values(TILLAMPLIGHET).includes(t.verdikt) &&
    Object.values(EVIDENSKALLA).includes(t.evidenskalla)
      ? t.verdikt : TILLAMPLIGHET.UNKNOWN;
  const skal = verdikt === TILLAMPLIGHET.UNKNOWN
    ? (t && t.verdikt && !Object.values(EVIDENSKALLA).includes(t.evidenskalla)
        ? 'domen saknar giltig occurrence-specifik evidenskalla och faller stangt'
        : 'ingen occurrence-specifik evidens finns')
    : (t.motivering || '');
  const kvot = typeof m.MEASURED_RATIO === 'number' ? m.MEASURED_RATIO : null;
  const teknisk = kvot === null ? TEKNISKT.NOT_MEASURED
    : (kvot >= krav ? TEKNISKT.TECHNICALLY_PASSES_IF_REQUIRED
                    : TEKNISKT.TECHNICALLY_FAILS_IF_REQUIRED);
  return {
    PART_DETECTED: !!m.PART_DETECTED,
    PART_IDENTITY: m.PART_IDENTITY || null,
    CONTROL_IDENTITY: m.CONTROL_IDENTITY || null,
    PAINT_SOURCE: m.PAINT_SOURCE || null,
    OUTSIDE_ADJACENT_SURFACE: m.OUTSIDE_ADJACENT_SURFACE || null,
    MEASURED_RATIO: kvot,
    VISIBLE_TEXT_PRESENT: !!m.VISIBLE_TEXT_PRESENT,
    VISIBLE_ICON_PRESENT: !!m.VISIBLE_ICON_PRESENT,
    ACCESSIBLE_NAME: m.ACCESSIBLE_NAME || null,
    OTHER_VISUAL_CUES: m.OTHER_VISUAL_CUES || [],
    STATE_RELEVANCE: m.STATE_RELEVANCE || null,
    CONTEXT_DESCRIPTION: m.CONTEXT_DESCRIPTION || null,
    APPLICABILITY_VERDICT: verdikt,
    APPLICABILITY_EVIDENCE: verdikt === TILLAMPLIGHET.UNKNOWN ? null : t.evidenskalla,
    APPLICABILITY_REASON: skal,
    TECHNICAL_MEASUREMENT_STATUS: teknisk,
    CONFORMANCE_VERDICT: konformans(verdikt, kvot, krav),
    $regler: {
      textArObservation: 'VISIBLE_TEXT_PRESENT och VISIBLE_TEXT_ABSENT ar fakta, inte domar',
      accessibleName: 'ACCESSIBLE_NAME ar inte visuell evidens for SC 1.4.11',
      kvotenAvgorInte: 'MEASURED_RATIO paverkar aldrig APPLICABILITY_VERDICT',
      ingenPropagering: 'roll, fargpar och kvot far aldrig propagera en dom' } };
}

/** Konformansdomen. Enda stallet dar kvot och tillamplighet mots. */
export function konformans(verdikt, kvot, krav = 3) {
  if (verdikt === TILLAMPLIGHET.SUPPLEMENTAL_NOT_REQUIRED) return KONFORMANS.NOT_APPLICABLE;
  if (verdikt !== TILLAMPLIGHET.REQUIRED) return KONFORMANS.UNKNOWN;
  if (typeof kvot !== 'number') return KONFORMANS.UNKNOWN;
  return kvot >= krav ? KONFORMANS.REQUIRED_PASS : KONFORMANS.REQUIRED_FAIL;
}

/** En dom far bara aterbrukas pa EXAKT samma forekomstidentitet. */
export function farAterbruka(evidens, forekomstId) {
  return !!evidens && evidens.forekomstId === forekomstId;
}

/**
 * Sammanslagning efter occurrence-review. Tillaten bara nar allt nedan ar
 * bevisat lika. Samma kvot, samma farg, samma knappstil eller samma tema
 * racker aldrig.
 */
export const SAMMANSLAGNINGSKRAV = Object.freeze([
  'kontrollfunktion', 'tillstandsfunktion', 'typAvVisuellaCues',
  'scenhierarki', 'kontrafaktisktUtfall']);
export function farSlasSamman(a, b) {
  if (!a || !b) return { ok: false, skal: 'underlag saknas' };
  for (const k of SAMMANSLAGNINGSKRAV)
    if (JSON.stringify(a[k]) !== JSON.stringify(b[k]))
      return { ok: false, skal: k + ' skiljer sig' };
  if (a.occurrenceSpecifikEvidensForOlikaKrav || b.occurrenceSpecifikEvidensForOlikaKrav)
    return { ok: false, skal: 'occurrence-specifik evidens for olika requiredness finns' };
  return { ok: true, skal: 'samtliga ' + SAMMANSLAGNINGSKRAV.length +
    ' likhetskrav ar bevisade' };
}
