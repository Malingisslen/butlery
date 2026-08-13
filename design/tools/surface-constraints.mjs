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
  EXACT_CARRIER_COLLAPSE: 'EXACT_CARRIER_COLLAPSE',
  TEXT_CONSTRAINT_FAIL: 'TEXT_CONSTRAINT_FAIL',
  NON_TEXT_CONSTRAINT_FAIL: 'NON_TEXT_CONSTRAINT_FAIL',
  SEMANTIC_ROLE_FAIL: 'SEMANTIC_ROLE_FAIL',
  COMPOSITING_DEPENDENCY_FAIL: 'COMPOSITING_DEPENDENCY_FAIL' });

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
  beraknadYta, kvotFn }) {
  const skal = [], matt = [];
  if (beraknadYta === bakgrund) skal.push(AVVISNING.EXACT_CARRIER_COLLAPSE);
  for (const k of krav) {
    if (k.typ === 'ICKE_TEXT') { const v = kvotFn(beraknadYta, bakgrund);
      matt.push({ krav: k.kalla, kvot: v, minsta: k.minsta });
      if (!skal.includes(AVVISNING.EXACT_CARRIER_COLLAPSE) && v < k.minsta)
        skal.push(AVVISNING.NON_TEXT_CONSTRAINT_FAIL); }
    if (k.typ === 'TEXT') { const v = kvotFn(textfarg, beraknadYta);
      matt.push({ krav: k.kalla, kvot: v, minsta: k.minsta });
      if (v < k.minsta) skal.push(AVVISNING.TEXT_CONSTRAINT_FAIL); } }
  if (genomskinlig) skal.push(AVVISNING.COMPOSITING_DEPENDENCY_FAIL);
  return { kandidat, bakgrund, beraknadYta, matt,
    passerar: skal.length === 0, avvisningsklasser: skal }; }
