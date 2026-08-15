// F2 · UPPTACKT AV ODEKLARERADE KONTROLLER UR KORPUSENS EGEN KONTROLLFORM.
//
// FELKLASSEN DENNA MODUL FINNS FOR
// tools/undeclared-components.mjs slapper in en kandidat pa tva satt: elementet
// bar ett authored data-component, eller det ar ett pillerformat spar med ett
// absolut placerat runt barn. Korpusen anvander data-component BARA for toggle,
// checkbox och chip. Knappar och falt bar det aldrig. Foljden var att hela
// klassen knapp- och faltliknande kontroller var strukturellt osynlig.
//
// ROTORSAK: KANDIDATPREDIKATET VAR FOR SMALT. Upptackten var bunden till en
// authored komponentvokabular som inte tacker kontrollvokabularen.
//
// TVA METODFEL I FORSTA VERSIONEN, RATTADE HAR
//
//   1  48x48 ANVANDES SOM UPPTACKTSGRIND. Det ar ett KONFORMITETSKRAV, och en
//      kontroll som INTE uppfyller det ar precis den som mest behover
//      upptackas. Ett konformitetsutfall far aldrig avgora vad som ens gar att
//      se. Storleken mats och redovisas fortfarande, och anvands senare for
//      prospektiv R-02 — men den avgor aldrig medlemskap.
//
//   2  REGELN VALDES PA "TRAFFSAKERHET" declared/(declared+undeclared).
//      Namnaren bestod av oadjudicerade kandidater, som saknar ground truth och
//      darfor INTE ar falska positiva. Mattet sager ingenting om metodens
//      kvalitet. Regeln valjs nu pa RECALL mot den kanda deklarerade
//      populationen, mott med en virtual-undeclare-audit.
//
// UPPTACKT ar "kan detta behova adjudiceras?"
// KONFORMITET ar "har denna kontroll ratt roll, namn, tillstand, traffyta?"
// De far aldrig kopplas ihop, och konformitet far aldrig ga forst.
//
// MEKANISMERNA AR HARLEDDA UR DEN DEKLARERADE POPULATIONEN
// Unionen aterupptacker 1305 av korpusens 1351 deklarerade kontroller nar
// deras deklaration virtuellt ignoreras — recall 96,6 %. De 46 kvarvarande
// ligger i uttryckligt dokumenterade gap-familjer, inte i en osynlig rest.
//
// INGEN SKARM, INGEN ETIKETT, INGET KLASSNAMN, INGEN KONFORMITET
// Varje mekanism laser bara struktur. Upptackt ger KANDIDAT, aldrig roll och
// aldrig verdikt.

export const MEKANISM = Object.freeze({
  AUTHORED_COMPONENT: 'elementet bar en authored data-component',
  PILL_KNOB: 'pillerformat spar med ett absolut placerat runt barn',
  CONTROL_SHELL: 'flexbehallare som centrerar sitt innehall i tvarled och vars ' +
    'eget innehall ar text, glyf eller bada, utan nastlad malad form',
  PAINTED_TEXT_BODY: 'malad yta med egen text och ingen nastlad malad form',
  PAINTED_BARE_BODY: 'malad yta utan egen text, utan glyf och utan nastlad form' });

export const GAPFAMILJER = Object.freeze({
  OWNER_WITH_NESTED_PAINTED_SHAPE: 'agaren innehaller nastlade malade former. Att slappa ' +
    'det kravet lyfter recall till 98,4 % men gor predikatet till "vilken behallare som ' +
    'helst" — mekanismen upphor da att vara en mekanism.',
  BORDERLESS_NOT_CROSS_CENTERED: 'omalad flexbehallare som inte centrerar i tvarled. Att ' +
    'slappa centreringen lyfter recall till 97,9 % men tar bort det enda som skiljer ' +
    'kontrollskalet fran en godtycklig rad.',
  INVISIBLE_OWNER_NO_CONTENT: 'agaren malar ingenting och bar varken text eller glyf. Det ' +
    'finns ingen struktur att upptacka.' });

// Storleken ar DIAGNOSTIK och prioriteringssignal. Aldrig medlemskap.
export const TRAFFYTA_MIN = 48;

const FLEXBEHALLARE = o => /^(inline-)?flex$/.test(o.display);

export const PREDIKAT = Object.freeze({
  AUTHORED_COMPONENT: o => !!o.komponent,
  PILL_KNOB: o => !!(o.piller && o.harKnopp),
  CONTROL_SHELL: o => FLEXBEHALLARE(o) && o.align === 'center' &&
    (o.egenTextLangd > 0 || o.svgAntal > 0) && o.inreMalande === 0,
  PAINTED_TEXT_BODY: o => !!o.malar && o.egenTextLangd > 0 && o.inreMalande === 0,
  PAINTED_BARE_BODY: o => !!o.malar && o.egenTextLangd === 0 && o.inreMalande === 0 &&
    o.svgAntal === 0 });

export const UNION = Object.freeze(Object.keys(PREDIKAT));

/** Vilka mekanismer traffar objektet? Ren struktur, ingen konformitet. */
export function mekanismerFor(o, union = UNION) {
  if (!o) return [];
  return union.filter(m => PREDIKAT[m](o));
}

/** Ar objektet redan deklarerat, sjalvt eller via en forfader? */
export const arDeklarerad = o => !!(o && (o.roll || o.forfaderRoll));

/**
 * RECALL-PROV. Behandlar en deklarerad kontroll som om den vore odeklarerad —
 * strukturen behalls orord, bara deklarationsflaggorna ignoreras — och avgor
 * om nagon mekanism skulle hitta SAMMA semantiska agare.
 *
 * En traff pa en attkomling raknas bara nar den ar ENTYDIG. Att nagot barn
 * eller nagon granne fangas racker inte: agaren maste ga att stamma av.
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
 * Svepet. `objekt` ar den renderade inventeringen av produktens element.
 * `befintliga` ar stabila identiteter som redan finns i den ra kandidatlistan.
 *
 * DEDUP AR FAIL CLOSED. Samma fysiska agare ger EN identitet. Tvetydigt
 * agarval ger ingen kandidat, utan en post i tvetydigaAgare.
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
    if (krock.length) { tvetydigaAgare.push({ identitet: id(o), krockarMed: krock.map(id),
      skal: 'samma artefakt och samma renderade box som en befintlig kandidat — ' +
        'agarvalet gar inte att avgora i upptackten' }); continue; }
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
      // Storleken redovisas som DIAGNOSTIK. Den paverkade inte medlemskapet.
      uppfyllerTraffytekontraktet: o.w >= TRAFFYTA_MIN && o.h >= TRAFFYTA_MIN,
      egenTextLangd: o.egenTextLangd,
      verdikt: null, roll: null })),
    redanKanda, tvetydigaAgare,
    invariant_ok: traffar.length === nya.length + redanKanda.length + tvetydigaAgare.length };
}
