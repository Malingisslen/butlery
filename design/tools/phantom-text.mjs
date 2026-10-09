// F2-R01 · FANTOMTEXTRELATIONEN.
//
// FELET DEN HAR MODULEN FINNS FOR
// I forhandsvisningen av saffransremedieringen lastes `getComputedStyle(el).color`
// pa sex knappar och tolkades som knappens etikettfarg. Kvoten mot fyllningen
// blev 3.891 mot kravet 4.5, och sex "textfel" fordes in i beslutsunderlaget.
// Knapparna innehaller ingen text. Vardet var den ARVDA color-egenskapen, som
// inte malar nagonting nar det inte finns nagon textnod att mala, och ikonen
// ritas med sin egen stroke i stallet for currentColor.
//
// Felklassen ar generell och har ingenting med saffran att gora:
//
//   en beraknad fargegenskap ar inte en fargrelation.
//   En relation finns forst nar nagot FAKTISKT malas med fargen.
//
// Modulen ar avsiktligt strukturell. Den laser aldrig ett kontrastvarde och
// den vager aldrig hur nara ett varde ligger sin troskel. Den svarar bara pa
// fragan om det over huvud taget finns en relation att mata.

export const TEXTRELATION = Object.freeze({
  /* Text renderas och fargen malar den. En riktig relation. */
  TEXTRELATION_FINNS: 'TEXTRELATION_FINNS',
  /* Ingen renderad text. Den beraknade fargen malar ingenting. */
  PHANTOM_TEXT_RELATION: 'PHANTOM_TEXT_RELATION',
  /* Underlaget racker inte for att avgora. Fail closed: ingen relation skapas. */
  UNKNOWN_TEXTRELATION: 'UNKNOWN_TEXTRELATION' });

/* Vad som faktiskt malar en glyf. Arvd color galler BARA nar glyfen sjalv
 * hanvisar till den med currentColor. En svg med egen stroke eller fill malas
 * av sitt eget varde, och foralderns color ar da irrelevant for glyfen. */
export const GLYFMALNING = Object.freeze({
  EGEN_FARG: 'EGEN_FARG',
  CURRENTCOLOR: 'CURRENTCOLOR',
  INGEN_GLYF: 'INGEN_GLYF' });

/**
 * f = {
 *   renderadeTextnoder : antal FAKTISKT renderade textkorningar som elementet ager
 *   glyfmalning        : GLYFMALNING
 *   beraknadFarg       : den beraknade color-egenskapen (redovisas, avgor aldrig)
 *   fargkallaFinns     : om nagon i foraldrakedjan deklarerar color
 * }
 */
export function textrelation(f) {
  const n = f && typeof f.renderadeTextnoder === 'number' ? f.renderadeTextnoder : null;
  const dia = { renderadeTextnoder: n, glyfmalning: f && f.glyfmalning || null,
    beraknadFarg: f && f.beraknadFarg || null,
    $not: 'Rapporterande. Varken fargvardet eller dess avstand till troskeln ' +
      'paverkar om relationen finns.' };
  if (n === null)
    return { klass: TEXTRELATION.UNKNOWN_TEXTRELATION, skrivbar: false,
      skal: 'antalet renderade textkorningar ar okant', diagnostik: dia };
  if (n === 0)
    return { klass: TEXTRELATION.PHANTOM_TEXT_RELATION, skrivbar: false,
      skal: 'elementet renderar ingen text; den beraknade color-egenskapen malar ingenting',
      diagnostik: dia };
  return { klass: TEXTRELATION.TEXTRELATION_FINNS, skrivbar: true,
    skal: n + ' renderad' + (n === 1 ? ' textkorning' : 'e textkorningar') +
      ' malas med fargen', diagnostik: dia };
}

/** Ar foralderns color glyfens forgrund? Bara nar glyfen ber om det. */
export function glyfensForgrundArArvd(glyfmalning) {
  return glyfmalning === GLYFMALNING.CURRENTCOLOR;
}

/** Fail closed: bara en verklig textrelation far bli skrivplan, kandidat eller fynd. */
export function farBliSkrivplan(relation) {
  return !!relation && relation.klass === TEXTRELATION.TEXTRELATION_FINNS;
}
export const farBliRemedieringskandidat = farBliSkrivplan;
export const farBliPreviewFynd = farBliSkrivplan;
