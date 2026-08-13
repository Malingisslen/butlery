// F2-R04 · VILKA KRAV GALLER FAKTISKT FOR EN YTA?
//
// FELKLASSEN DENNA MODUL FINNS FOR
// En audit avvisade fyra av fem kandidater for en knappyta med motiveringen
// "otillracklig ytkontrast" och en 3:1-troskel som ingen kalla kravde.
// Projektets eget kontrakt i tools/nontext-measure.mjs sager motsatsen: for en
// kontroll med EGEN SYNLIG TEXT ar det texten som identifierar komponenten.
// Ytan ar da ingen componentIdentityCarrier och 1.4.11 galler den inte.
//
// FORBJUDET HAR
//   · generell ytkontrasttroskel
//   · ljusa lagets numeriska ytkvot som minimum i morkt lage
//   · godtyckligt minsta delta
//
// TILLATET HAR
//   · exakt 1:1 som forsvinnandesignal
//   · numerisk kontrast dar WCAG faktiskt galler:
//       1.4.3  text mot sin egen bakgrund
//       1.4.11 grafik som ar komponentens ENDA identifierande information
//
// Kraven harleds ur elementets uppmatta struktur, aldrig ur fargen.

export const KRAVKALLA = Object.freeze({
  WCAG_1_4_3: 'WCAG 1.4.3 · text 4.5:1 mot sin egen bakgrund',
  WCAG_1_4_11: 'WCAG 1.4.11 · 3:1 for grafik som ar komponentens enda identifierande information',
  FORSVINNANDE: 'exakt likhet — ytan upphor att existera visuellt' });

export const AVVISNING = Object.freeze({
  REQUIRED_CARRIER_COLLAPSE: 'REQUIRED_CARRIER_COLLAPSE',
  TEXT_CONSTRAINT_FAIL: 'TEXT_CONSTRAINT_FAIL',
  NON_TEXT_CONSTRAINT_FAIL: 'NON_TEXT_CONSTRAINT_FAIL',
  SEMANTIC_ROLE_FAIL: 'SEMANTIC_ROLE_FAIL',
  COMPOSITING_DEPENDENCY_FAIL: 'COMPOSITING_DEPENDENCY_FAIL' });

/* ── EXAKT LIKHET AR EN MATNING, INTE ETT UTFALL ─────────────────────
 *
 * Rattad 2026-08-13. Tidigare gav exakt likhet med foraldern alltid
 * underkant. Det var for brett: en yta som inte bar nagot kravt far
 * sammanfalla med sin foralder utan att nagot ar fel.
 *
 * Tva skilda begrepp:
 *
 *   EXACT_EQUALITY_SIGNAL      berknad yta === berknad foralder.
 *                              En ren matningsfakta. Inget utfall.
 *
 *   REQUIRED_CARRIER_COLLAPSE  Exakt likhet PLUS ett bevisat baransvar.
 *                              Bara da ar det ett fel.
 *
 * Baransvaret kommer fran semantisk roll eller godkand designprincip och
 * levereras av den anropande. Det far ALDRIG harledas ur kontrastvardet.
 */
export const BARANSVAR = Object.freeze({
  CONTROL_BODY_REQUIRED: 'CONTROL_BODY_REQUIRED',
  GROUPING_PLUS_STATE_REQUIRED: 'GROUPING_PLUS_STATE_REQUIRED',
  REQUIRED_GROUPING_CARRIER: 'REQUIRED_GROUPING_CARRIER',
  REQUIRED_ELEVATION_CARRIER: 'REQUIRED_ELEVATION_CARRIER',
  REQUIRED_INFORMATION_CARRIER: 'REQUIRED_INFORMATION_CARRIER',
  PURE_STATE_EMPHASIS: 'PURE_STATE_EMPHASIS',
  NON_REQUIRED_VISUAL_STYLING: 'NON_REQUIRED_VISUAL_STYLING',
  UNKNOWN: 'UNKNOWN' });

export const KRAVT_BARANSVAR = new Set([
  BARANSVAR.CONTROL_BODY_REQUIRED, BARANSVAR.GROUPING_PLUS_STATE_REQUIRED,
  BARANSVAR.REQUIRED_GROUPING_CARRIER, BARANSVAR.REQUIRED_ELEVATION_CARRIER,
  BARANSVAR.REQUIRED_INFORMATION_CARRIER]);

/** Ren matning. Ingen bedomning. */
export const exaktLikhet = (beraknadYta, foralder) =>
  ({ signal: 'EXACT_EQUALITY_SIGNAL', lika: beraknadYta === foralder,
    beraknadYta, foralder,
    $not: 'En matningsfakta. Den avgor ingenting i sig.' });

/**
 * Kollapsar en KRAVD barare? Fail closed pa UNKNOWN: ett obestamt baransvar
 * far aldrig tolkas som "inte kravt".
 */
export function bararkollaps(beraknadYta, foralder, baransvar) {
  const e = exaktLikhet(beraknadYta, foralder);
  if (!e.lika) return { kollaps: false, signal: e, baransvar, skal: null };
  if (baransvar === BARANSVAR.UNKNOWN)
    return { kollaps: true, signal: e, baransvar, faillClosed: true,
      skal: 'exakt likhet och obestamt baransvar — faller stangt tills ansvaret ar klassat' };
  if (KRAVT_BARANSVAR.has(baransvar))
    return { kollaps: true, signal: e, baransvar,
      skal: 'ytan bar ' + baransvar + ' och sammanfaller exakt med sin foralder' };
  return { kollaps: false, signal: e, baransvar,
    skal: 'exakt likhet, men ytan bar inget kravt ansvar — ingen underkant' }; }

/** Valkontroller identifieras alltid av sin egen ruta, aven med etikett. */
export const VALKONTROLL = new Set(['checkbox', 'radio', 'switch', 'toggle']);

/**
 * Vilka numeriska krav galler ytan pa DETTA element?
 * el: { kontrollroll, harEgenText, harRam, harSkugga, harBakgrundsbild, barText }
 * Returnerar en lista av krav. Tom lista betyder: inget matbart krav — och da
 * ar valet ett rent visuellt val, inte ett tekniskt.
 */
export function ytkrav(el) {
  const krav = [];
  const arKontroll = !!el.kontrollroll;
  const valkontroll = arKontroll && VALKONTROLL.has(el.kontrollroll);
  const ytanIdentifierar = arKontroll && (valkontroll || !el.harEgenText) &&
    !el.harRam && !el.harSkugga && !el.harBakgrundsbild;
  if (ytanIdentifierar) krav.push({ typ: 'ICKE_TEXT', minsta: 3, kalla: KRAVKALLA.WCAG_1_4_11,
    motpart: 'omgivande yta',
    skal: valkontroll ? 'valkontrollens egen ruta identifierar den'
      : 'kontrollen har ingen egen synlig text — ytan ar det enda som identifierar den' });
  if (el.barText) krav.push({ typ: 'TEXT', minsta: 4.5, kalla: KRAVKALLA.WCAG_1_4_3,
    motpart: 'texten pa ytan', skal: 'ytan ar bakgrund for text' });
  return { krav, ytanIdentifierar,
    $not: arKontroll && el.harEgenText && !valkontroll
      ? 'kontrollen har egen synlig text — texten identifierar komponenten och ytan ar ingen componentIdentityCarrier'
      : null }; }

/**
 * Provar en ytkandidat. kvotFn(a, b) levereras av anroparen — modulen raknar
 * inte farg sjalv och kanner ingen troskel utom de kraven bar med sig.
 */
export function provaYtkandidat(kandidat, bakgrund, { krav, textfarg, genomskinlig,
  beraknadYta, kvotFn, baransvar = BARANSVAR.UNKNOWN }) {
  const skal = [], matt = [];
  const kollaps = bararkollaps(beraknadYta, bakgrund, baransvar);
  if (kollaps.kollaps) skal.push(AVVISNING.REQUIRED_CARRIER_COLLAPSE);
  for (const k of krav) {
    if (k.typ === 'ICKE_TEXT') { const v = kvotFn(beraknadYta, bakgrund);
      matt.push({ krav: k.kalla, kvot: v, minsta: k.minsta });
      if (!kollaps.kollaps && v < k.minsta) skal.push(AVVISNING.NON_TEXT_CONSTRAINT_FAIL); }
    if (k.typ === 'TEXT') { const v = kvotFn(textfarg, beraknadYta);
      matt.push({ krav: k.kalla, kvot: v, minsta: k.minsta });
      if (v < k.minsta) skal.push(AVVISNING.TEXT_CONSTRAINT_FAIL); } }
  /* Genomskinlighet ar en EGENSKAP, inte en underkant. Den godkanda
     PROGRESS_TRACK-mappningen ar sjalv rgba(245,244,237,0.18). Det som ska
     redovisas ar att vardet inte ager sitt eget resultat — inte att det ar fel. */
  return { kandidat, bakgrund, beraknadYta, matt,
    exaktLikhet: kollaps.signal, baransvar, bararkollaps: kollaps,
    compositingberoende: !!genomskinlig,
    passerar: skal.length === 0, avvisningsklasser: skal }; }

/**
 * PREVIEWKONTROLLDUGLIGHET — en ANNAN dimension an teknisk giltighet.
 *
 * Ett varde kan vara tekniskt giltigt och anda vara olampligt som temporar
 * kontroll, om det beter sig OLIKA mellan malkandidaterna och darmed andrar
 * jamforelsen i sig. Utfallet ar aldrig "ogiltigt" — det ar "inte neutralt nog".
 */
export function previewkontrollduglighet(kandidat, provPerMal) {
  const giltiga = provPerMal.filter(p => p.passerar);
  const likhetsvariation = new Set(provPerMal.map(p => p.exaktLikhet.lika)).size > 1;
  if (giltiga.length !== provPerMal.length)
    return { kandidat, duglig: false, klass: 'EJ_GILTIG_MOT_ALLA_MAL',
      skal: 'tekniskt ogiltig mot ' + provPerMal.filter(p => !p.passerar)
        .map(p => p.bakgrund).join(', ') };
  if (likhetsvariation)
    return { kandidat, duglig: false, klass: 'EJ_NEUTRAL_NOG',
      skal: 'ytan sammanfaller med foraldern for vissa malkandidater men inte andra — ' +
        'den visuella prominensen skiljer sig mellan bilderna och jamforelsen blir ojamn' };
  return { kandidat, duglig: true, klass: 'NEUTRAL',
    skal: 'tekniskt giltig mot samtliga malkandidater och beter sig likadant mot alla' }; }
