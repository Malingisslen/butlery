// F2 · UPPTACKT AV ODEKLARERADE KONTROLLER UR KORPUSENS EGEN KONTROLLFORM.
//
// FELKLASSEN DENNA MODUL FINNS FOR
// tools/undeclared-components.mjs slapper in en kandidat pa tva satt: elementet
// bar ett authored data-component, eller det ar ett pillerformat spar med ett
// absolut placerat runt barn. Korpusen anvander data-component BARA for toggle,
// checkbox och chip. Knappar och falt bar det aldrig. Recall for de tva
// mekanismerna ar 7,8 % mot den kanda kontrollpopulationen: nio av tio
// kontroller var strukturellt osynliga.
//
// TRE METODFEL HAR RATTATS PA VAGEN. Alla tre ar bevarade har som varning.
//
//   1  48x48 ANVANDES SOM UPPTACKTSGRIND. Ett KONFORMITETSKRAV som villkor for
//      att objektet ens skulle synas. En kontroll som inte uppfyller kravet ar
//      precis den som mest behover upptackas. Storleken mats och redovisas, men
//      avgor aldrig medlemskap.
//
//   2  REGELN VALDES PA declared/(declared+undeclared). Namnaren bestod av
//      oadjudicerade kandidater, som saknar ground truth och darfor inte ar
//      falska positiva. Regeln valjs pa RECALL.
//
//   3  KANDIDATVOLYM ANVANDES SOM SKAL ATT INTE SLAPPA KRAV. Volym ar
//      granskningsarbete, inte tackning. Den loses i TIER 2 med prioritering,
//      aldrig genom att gora kontroller osynliga i TIER 1.
//
// TVA STRUKTURPRIMITIV VAR OCKSA FEL, OCH DE GJORDE TVA KONTROLLER
// "OUPPTACKBARA" NAR DE I SJALVA VERKET BARA VAR OMATTA:
//
//   a  EN OUTLINE ar en malad avgransning precis som en ram. Den lastes inte.
//      MFA-koden ar en outline-inramad behallare runt sex siffercellar.
//   b  AGARENS EGNA TEXT ar all text i subtradet som INTE ligger inuti en
//      nastlad malad form. Den forra hjalparen laste bara direkta textnoder och
//      barnlosa barn, sa en etikett i en nastlad span raknades som ingen text.
//
// EFTER RATTNINGARNA: recall 1351 av 1351. Noll strukturella missar, noll
// DISCOVERY_INFORMATION_LIMIT.
//
// TVA SKIKT, STRIKT ATSKILDA
//   TIER 1  UPPTACKTSUNIVERSUM. Hog recall, far overinkludera, ger KANDIDAT.
//           Inget verdikt, ingen roll, ingen konformitetsgrind.
//   TIER 2  PRIORITERING. Rangordnar kandidater for granskning. Far ANVANDA
//           strukturell narhet och kontext. Far ALDRIG andra medlemskap i
//           Tier 1 och far aldrig satta verdikt.
//
// INGEN SKARM, INGEN ETIKETT, INGET KLASSNAMN, INGEN KONFORMITET.

/* ── PRIMITIVKONTRAKT ─────────────────────────────────────────────────────
 * Modulen konsumerar skordade objekt. Skorden MASTE leverera dessa falt med
 * exakt denna innebord, annars galler inte recall-siffran.                 */
export const PRIMITIVKONTRAKT = Object.freeze({
  malar: 'fyllning med alfa > 0, ELLER ram pa alla fyra sidor, ELLER en outline',
  egenTextLangd: 'langden pa all text i subtradet som INTE ligger inuti en nastlad malad form',
  inreMalande: 'antal element i subtradet som sjalva malar',
  svgAntal: 'antal svg eller data-icon i subtradet',
  segmentgrupp: 'storsta antal DIREKTA barn som malar och har identisk renderad geometri',
  display: 'computed display', align: 'computed align-items',
  w: 'renderad bredd', h: 'renderad hojd — DIAGNOSTIK, aldrig medlemskap' });

export const MEKANISM = Object.freeze({
  AUTHORED_COMPONENT: 'elementet bar en authored data-component',
  PILL_KNOB: 'pillerformat spar med ett absolut placerat runt barn',
  CONTROL_SHELL: 'flexbehallare vars EGNA innehall ar text, glyf eller bada, utan nastlad ' +
    'malad form. Tvarcentrering kravs INTE — 17 deklarerade kontroller centrerar inte.',
  PAINTED_TEXT_BODY: 'malad yta med egen text. Nastlade malade former hindrar INTE — 25 ' +
    'deklarerade kontroller bar en avatar eller bricka inuti sig.',
  PAINTED_BARE_BODY: 'malad yta utan egen text, utan glyf och utan nastlad form',
  SEGMENTED_FIELD: 'behallare utan egen text vars direkta barn innehaller minst tre malade ' +
    'syskon med identisk renderad geometri — den segmenterade faltformen' });

// Storleken ar DIAGNOSTIK och prioriteringssignal. Aldrig medlemskap.
export const TRAFFYTA_MIN = 48;
const FLEXBEHALLARE = o => /^(inline-)?flex$/.test(o.display);
const SEGMENT_MIN = 3;

export const PREDIKAT = Object.freeze({
  AUTHORED_COMPONENT: o => !!o.komponent,
  PILL_KNOB: o => !!(o.piller && o.harKnopp),
  CONTROL_SHELL: o => FLEXBEHALLARE(o) && (o.egenTextLangd > 0 || o.svgAntal > 0) &&
    o.inreMalande === 0,
  PAINTED_TEXT_BODY: o => !!o.malar && o.egenTextLangd > 0,
  PAINTED_BARE_BODY: o => !!o.malar && o.egenTextLangd === 0 && o.inreMalande === 0 &&
    o.svgAntal === 0,
  SEGMENTED_FIELD: o => o.segmentgrupp >= SEGMENT_MIN && o.egenTextLangd === 0 });

export const UNION = Object.freeze(Object.keys(PREDIKAT));

/** TIER 1. Vilka mekanismer traffar objektet? Ren struktur, ingen konformitet. */
export function mekanismerFor(o, union = UNION) {
  if (!o) return [];
  return union.filter(m => PREDIKAT[m](o));
}

export const arDeklarerad = o => !!(o && (o.roll || o.forfaderRoll));

/**
 * TIER 2. Prioritering for granskningskon. Rangordnar, aldrig mer.
 *
 * Poangen far ALDRIG lasas tillbaka in i medlemskapet. Den finns for att en
 * hog kandidatvolym ska losas med ordning, inte med osynlighet.
 */
export function prioritet(o, union = UNION) {
  const m = mekanismerFor(o, union);
  if (!m.length) return null;
  return { poang: m.length +
      (o.w >= TRAFFYTA_MIN && o.h >= TRAFFYTA_MIN ? 1 : 0) +
      (o.egenTextLangd > 0 ? 1 : 0) + (o.komponent ? 1 : 0),
    mekanismer: m,
    $regel: 'Prioritet ar en sorteringssignal. Den paverkar inte Tier 1-medlemskap och ' +
      'ar aldrig ett verdikt.' };
}

/**
 * RECALL-PROV. Behandlar en deklarerad kontroll som om den vore odeklarerad —
 * strukturen behalls orord, bara deklarationsflaggorna ignoreras — och avgor
 * om nagon mekanism skulle hitta SAMMA semantiska agare.
 *
 * En traff pa en attkomling raknas bara nar den ar ENTYDIG.
 */
export function aterupptack(kontroll, union = UNION) {
  const paAgaren = mekanismerFor(kontroll.agare, union);
  const viaBarn = [];
  for (const m of union) {
    if (PREDIKAT[m](kontroll.agare)) continue;
    const b = (kontroll.attkomlingar || []).filter(a => PREDIKAT[m](a));
    if (b.length === 1) viaBarn.push({ mekanism: m, ordinal: b[0].ordinal });
  }
  return { strikt: paAgaren.length > 0,
    agarAvstambar: paAgaren.length > 0 || viaBarn.length > 0,
    mekanism: paAgaren[0] || (viaBarn[0] || {}).mekanism || null,
    kandidatOrdinal: paAgaren.length ? kontroll.agare.ordinal
      : ((viaBarn[0] || {}).ordinal ?? null),
    via: paAgaren.length ? 'agaren' : (viaBarn.length ? 'entydig attkomling' : null) };
}

/**
 * Svepet. DEDUP AR FAIL CLOSED: samma fysiska agare ger EN identitet, och ett
 * tvetydigt agarval ger ingen kandidat utan en post i tvetydigaAgare.
 *
 * De tvetydiga FORSVINNER INTE ur bokforingen. De ar en egen oppen population,
 * DISCOVERY_AMBIGUOUS_OWNER, och raknas aldrig som vanliga kandidater.
 */
export function upptack(objekt, befintliga = new Set(), union = UNION) {
  const id = o => o.art + '|' + o.ordinal;
  const iScope = o => !o.iSvg;
  const deklareradeMedForm = objekt.filter(o => iScope(o) && arDeklarerad(o) &&
    mekanismerFor(o, union).length > 0);
  const traffar = objekt.filter(o => iScope(o) && !arDeklarerad(o) &&
    mekanismerFor(o, union).length > 0);

  const redanKanda = [], nya = [], tvetydigaAgare = [];
  for (const o of traffar) {
    if (befintliga.has(id(o))) { redanKanda.push(id(o)); continue; }
    const krock = objekt.filter(x => x !== o && befintliga.has(id(x)) &&
      x.art === o.art && x.w === o.w && x.h === o.h);
    if (krock.length) { tvetydigaAgare.push({ identitet: id(o), art: o.art, fil: o.fil,
      konkurrerandeAgare: krock.map(id), geometri: o.w + 'x' + o.h,
      skal: 'samma artefakt och samma renderade box som en befintlig kandidat — agarvalet ' +
        'gar inte att avgora ur strukturen',
      behovs: 'ett strukturellt bevis for vilken av boxarna som ar den semantiska agaren, ' +
        'till exempel en authored agarmarkering eller en entydig innehallsrelation' });
      continue; }
    nya.push(o);
  }
  const perRoll = {};
  for (const o of deklareradeMedForm) {
    const k = o.roll || 'inuti en deklarerad kontroll (' + o.forfaderRoll + ')';
    perRoll[k] = (perRoll[k] || 0) + 1; }
  return { union,
    objekt_st: objekt.length,
    deklareradeMedKontrollform_st: deklareradeMedForm.length, perRoll,
    traffar_st: traffar.length, redanKanda_st: redanKanda.length,
    nya_st: nya.length, tvetydigaAgare_st: tvetydigaAgare.length,
    nya: nya.map(o => ({ identitet: id(o), art: o.art, fil: o.fil, tagg: o.tagg,
      w: o.w, h: o.h, mekanismer: mekanismerFor(o, union),
      prioritet: prioritet(o, union).poang,
      uppfyllerTraffytekontraktet: o.w >= TRAFFYTA_MIN && o.h >= TRAFFYTA_MIN,
      egenTextLangd: o.egenTextLangd, verdikt: null, roll: null })),
    redanKanda, tvetydigaAgare,
    invariant_ok: traffar.length === nya.length + redanKanda.length + tvetydigaAgare.length };
}

/* ── TERMINOLOGI ──────────────────────────────────────────────────────────
 * Tre skilda tal. De far aldrig anvandas i varandras stalle, och inget av dem
 * ar "antalet okanda kontroller i appen".                                   */
export const MATT = Object.freeze({
  RAW_DISCOVERY_CANDIDATES: 'kandidatidentiteter som upptackten har ytat',
  ADJUDICATION_UNRESOLVED: 'kandidatidentiteter vars semantiska verdikt ar UNKNOWN eller ' +
    'som annu inte adjudicerats',
  DISCOVERY_AMBIGUOUS_OWNER: 'strukturellt ytade objekt vars semantiska agare annu inte ' +
    'gar att faststalla — oppet upptacktsarbete, inte kandidater',
  $varning: 'Inget av talen ar en uppskattning av hur manga kontroller appen har. De ar ' +
    'bokforing over vad metoden har ytat och vad som annu inte bedomts.' });
