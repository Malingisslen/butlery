// F2 · UPPTACKT AV ODEKLARERADE KONTROLLER UR KORPUSENS EGEN KONTROLLFORM.
//
// FELKLASSEN DENNA MODUL FINNS FOR
// tools/undeclared-components.mjs slapper in en kandidat pa tva satt: elementet
// bar ett authored data-component, eller det ar ett pillerformat spar med ett
// absolut placerat runt barn. Bada ar authored- eller formbundna, och korpusen
// anvander data-component BARA for toggle, checkbox och chip. Knappar och
// textfalt bar det aldrig. Foljden ar att hela klassen knapp- och faltliknande
// kontroller var strukturellt osynlig for upptackten: i dialogsparameny fanns
// kryssrutan i kandidatlistan medan Avbryt och Spara inte gjorde det.
//
// ROTORSAK: KANDIDATPREDIKATET VAR FOR SMALT. Upptackten var bunden till en
// authored komponentvokabular som inte tacker hela kontrollvokabularen.
//
// REGELN AR HARLEDD, INTE UPPFUNNEN
// Formen kommer ur den DEKLARERADE populationen. Ett element som
//   1  sjalv malar en avgransad yta — fyllning eller hel ram
//   2  bar sin egen synliga text
//   3  inte innehaller nagon nastlad malad form
//   4  inte innehaller nagon glyf
//   5  ar en flexbehallare som centrerar sitt innehall i tvarled
//   6  och vars RENDERADE box uppfyller traffytekontraktet 48x48
// har exakt den kropp som 349 av korpusens deklarerade kontroller har —
// 284 knappar, 42 textfalt, 29 flikar, 24 kryssrutor, 20 radioknappar.
// INGEN av dessa 349 ar under 48x48. Troskeln ar alltsa korpusens egen grans,
// inte ett pahittat varde.
//
// INGEN SKARM, INGEN ETIKETT, INGET KLASSNAMN
// Regeln laser bara struktur och renderad geometri. Den namner ingen skarm-id,
// ingen textstrang och inget klassnamn, och den far inte gora det.
//
// UPPTACKT AR INTE VERDIKT
// Modulen producerar KANDIDATER. Rollen, semantiken och verdiktet avgors
// nagon annanstans, forekomst for forekomst. Att ett objekt har kontrollens
// kropp betyder att det ska granskas, aldrig att det ar en kontroll.

export const MEKANISM = Object.freeze({
  BUTTON_LIKE_OWNER_GAP: 'element med korpusens kontrollkropp som varken bar ' +
    'data-a11y-role sjalvt eller ligger inuti nagon deklarerad kontroll' });

export const KONTROLLKROPP = Object.freeze({
  MALAR_EGEN_YTA: 'fyllning eller hel ram',
  EGEN_SYNLIG_TEXT: 'elementets egen text, inte enbart nastlade komponenters',
  INGEN_NASTLAD_FORM: 'inget barn malar en egen avgransad form',
  INGEN_GLYF: 'ingen svg och inget data-icon i subtradet',
  CENTRERAT_INNEHALL: 'display:flex med align-items:center',
  TRAFFYTEKONTRAKT: 'renderad box minst 48x48' });

export const TRAFFYTA_MIN = 48;

/** Har objektet korpusens kontrollkropp? Rent strukturellt. */
export function harKontrollkropp(o) {
  if (!o) return { ja: false, skal: 'inget objekt' };
  const brist = [];
  if (!(o.harFyllning || o.helRam)) brist.push('MALAR_EGEN_YTA');
  if (!o.harEgenText) brist.push('EGEN_SYNLIG_TEXT');
  if (o.inreMalande > 0) brist.push('INGEN_NASTLAD_FORM');
  if (o.svgAntal > 0) brist.push('INGEN_GLYF');
  if (!(o.display === 'flex' && o.align === 'center')) brist.push('CENTRERAT_INNEHALL');
  if (!(o.w >= TRAFFYTA_MIN && o.h >= TRAFFYTA_MIN)) brist.push('TRAFFYTEKONTRAKT');
  return { ja: brist.length === 0, brist,
    skal: brist.length ? 'saknar ' + brist.join(', ') : 'har korpusens kontrollkropp' };
}

/** Ar objektet redan deklarerat, sjalvt eller via en forfader? */
export const arDeklarerad = o => !!(o && (o.roll || o.forfaderRoll));

/**
 * Svepet. `objekt` ar den renderade inventeringen av allt som malar en yta.
 * `befintliga` ar de stabila identiteterna som redan finns i den ra
 * kandidatlistan — de aterupptacks aldrig som nya.
 *
 * DEDUP AR FAIL CLOSED. Tvetydigt agarskap ger ingen kandidat, utan en post i
 * `tvetydigaAgare`. En rad och dess visuella barn far aldrig bli tva kandidater
 * for samma fysiska objekt.
 */
export function upptack(objekt, befintliga = new Set()) {
  const id = o => o.art + '|' + o.ordinal;
  const deklareradeMedKroppen = objekt.filter(o => arDeklarerad(o) && harKontrollkropp(o).ja);
  const traffar = objekt.filter(o => !arDeklarerad(o) && harKontrollkropp(o).ja);

  const redanKanda = [], nya = [], tvetydigaAgare = [];
  for (const o of traffar) {
    if (befintliga.has(id(o))) { redanKanda.push(id(o)); continue; }
    // Samma fysiska objekt som en befintlig kandidat? Kravet ar strikt: samma
    // artefakt OCH samma renderade box. Da ar det ett agarval, inte en ny
    // kandidat, och det avgors inte har.
    const krock = objekt.filter(x => x !== o && befintliga.has(id(x)) &&
      x.art === o.art && x.w === o.w && x.h === o.h);
    if (krock.length) { tvetydigaAgare.push({ identitet: id(o),
      krockarMed: krock.map(id), skal: 'samma artefakt och samma renderade box som en ' +
        'befintlig kandidat — agarvalet gar inte att avgora har' }); continue; }
    nya.push(o);
  }
  // Ett objekt kan vara deklarerat via en FORFADER och da sakna egen roll. Det
  // redovisas som sadant i stallet for som "null", sa att talet inte laser fel.
  const perRoll = {};
  for (const o of deklareradeMedKroppen) {
    const k = o.roll || 'inuti en deklarerad kontroll (' + o.forfaderRoll + ')';
    perRoll[k] = (perRoll[k] || 0) + 1; }
  return { mekanism: MEKANISM.BUTTON_LIKE_OWNER_GAP,
    objekt_st: objekt.length,
    deklareradeMedKontrollkropp_st: deklareradeMedKroppen.length, perRoll,
    traffar_st: traffar.length, redanKanda_st: redanKanda.length,
    nya_st: nya.length, tvetydigaAgare_st: tvetydigaAgare.length,
    nya: nya.map(o => ({ identitet: id(o), art: o.art, fil: o.fil, tagg: o.tagg,
      w: o.w, h: o.h, yta: (o.harFyllning ? 'fyllning' : '') +
        (o.helRam ? (o.harFyllning ? '+helram' : 'helram') : ''),
      egenText: o.egenText,
      // Ingen roll och inget verdikt. Upptackt ar inte bedomning.
      verdikt: null, roll: null })),
    redanKanda, tvetydigaAgare,
    // Invariant: varje traff ar exakt en av tre.
    invariant_ok: traffar.length === nya.length + redanKanda.length + tvetydigaAgare.length };
}
