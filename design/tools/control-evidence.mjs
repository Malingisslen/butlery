// F2 · VAD SOM FAR ETABLERA ATT ETT OBJEKT AR EN KONTROLL — OCH VILKEN.
//
// TVA SKILDA FRAGOR, ALDRIG EN
//   1  AR objektet interaktivt?
//   2  VILKEN semantisk roll har det?
// Svaret pa 1 svarar aldrig pa 2. Ett objekt kan vara bevisat interaktivt
// medan rollen star oppen, och det ar ett korrekt resultat.
//
// FELET MODULEN STANGER
// Batch 3 forklarade tva objekt kontroller enbart darfor att hela deras
// innehall var en handlingsetikett — "+ Lägg till familjemedlem" och "Skapa
// konto". En handlingslik, imperativ eller navigerande etikett ar en utsaga om
// SPRAKET i objektet. Den ar inte forekomstspecifik positiv evidens for att
// objektet faktiskt gar att interagera med. Knapplik FORM racker inte heller:
// ram, radie och padding ar utseende, inte avsikt.
//
// Dessutom stamplades BUTTON pa allt som bedomdes interaktivt, aven dar
// skarmprosan talade om lankar. Rollen kraver egen evidens.

export const INTERAKTIONSGRUND = Object.freeze({
  /* Grundar INTE ensamma */
  IMPERATIVE_ACTION_LABEL: 'IMPERATIVE_ACTION_LABEL',
  NAVIGATIONAL_LABEL: 'NAVIGATIONAL_LABEL',
  BUTTON_LIKE_APPEARANCE: 'BUTTON_LIKE_APPEARANCE',
  /* Grundar */
  AUTHORED_SCREEN_PROSE_NAMES_CONTROL: 'AUTHORED_SCREEN_PROSE_NAMES_CONTROL',
  AUTHORED_SCREEN_PROSE_SUPPORTS_CAPABILITY: 'AUTHORED_SCREEN_PROSE_SUPPORTS_CAPABILITY',
  SELF_TEXT_INTERACTION_INSTRUCTION: 'SELF_TEXT_INTERACTION_INSTRUCTION',
  DECLARED_INTERACTION_RELATION: 'DECLARED_INTERACTION_RELATION',
  SPECIFIED_ACTION: 'SPECIFIED_ACTION' });

export const ICKE_GRUNDANDE_FOR_KONTROLL = Object.freeze([
  INTERAKTIONSGRUND.IMPERATIVE_ACTION_LABEL,
  INTERAKTIONSGRUND.NAVIGATIONAL_LABEL,
  INTERAKTIONSGRUND.BUTTON_LIKE_APPEARANCE ]);

export const KONTROLLKLASS = Object.freeze({
  INTERACTIVE_CONTROL: 'INTERACTIVE_CONTROL',
  UNKNOWN: 'UNKNOWN' });

/**
 * Racker de anforda grunderna for att etablera att objektet ar interaktivt?
 * Minst EN grund maste vara nagot annat an en utsaga om etiketten eller
 * utseendet. Annars faller det stangt.
 */
export function kontrollprov(grunder) {
  const g = Array.isArray(grunder) ? grunder : [];
  const barande = g.filter(x => !ICKE_GRUNDANDE_FOR_KONTROLL.includes(x));
  const svaga = g.filter(x => ICKE_GRUNDANDE_FOR_KONTROLL.includes(x));
  if (barande.length === 0)
    return { klass: KONTROLLKLASS.UNKNOWN, barande, svaga,
      skal: g.length === 0
        ? 'ingen grund anford — faller stangt'
        : 'samtliga anforda grunder ar utsagor om etiketten eller utseendet (' +
          svaga.join(', ') + ') — de kan inte ensamma etablera interaktivitet' };
  return { klass: KONTROLLKLASS.INTERACTIVE_CONTROL, barande, svaga,
    skal: 'minst en oberoende evidenspunkt for interaktionsavsikt: ' + barande.join(', ') };
}

/* ── ROLLEN AR EN EGEN FRAGA ────────────────────────────────────────── */

export const ROLL = Object.freeze({
  BUTTON: 'button', LINK: 'link', RADIO: 'radio', SWITCH: 'switch',
  CHECKBOX: 'checkbox', TEXTBOX: 'textbox', TAB: 'tab', UNKNOWN: 'UNKNOWN' });

export const ROLLGRUND = Object.freeze({
  AUTHORED_PROSE_STATES_ROLE: 'AUTHORED_PROSE_STATES_ROLE',
  OPERATION_ON_CURRENT_STATE: 'OPERATION_ON_CURRENT_STATE',
  NAVIGATES_TO_DESTINATION: 'NAVIGATES_TO_DESTINATION',
  ONE_OF_MUTUALLY_EXCLUSIVE_SET: 'ONE_OF_MUTUALLY_EXCLUSIVE_SET',
  DECLARED_STATE_FAMILY: 'DECLARED_STATE_FAMILY' });

/**
 * interaktivt   utfallet fran kontrollprov()
 * roll          den paastadda rollen, eller null
 * rollgrunder   lista ur ROLLGRUND
 *
 * Rollen kravs ALDRIG for att kontrollstatusen ska sta. En etablerad kontroll
 * med oppen roll ar ett giltigt resultat.
 */
export function rollprov(interaktivt, roll, rollgrunder) {
  if (interaktivt !== KONTROLLKLASS.INTERACTIVE_CONTROL)
    return { roll: ROLL.UNKNOWN, avgjord: false,
      skal: 'interaktivitet ar inte etablerad — rollfragan uppstar inte an' };
  const g = Array.isArray(rollgrunder) ? rollgrunder : [];
  if (g.length === 0 || !roll)
    return { roll: ROLL.UNKNOWN, avgjord: false,
      skal: 'interaktiviteten ar etablerad men ingen rollspecifik grund ar anford — rollen ' +
        'star oppen' };
  const motstridig = g.includes(ROLLGRUND.NAVIGATES_TO_DESTINATION) &&
    g.includes(ROLLGRUND.OPERATION_ON_CURRENT_STATE);
  if (motstridig)
    return { roll: ROLL.UNKNOWN, avgjord: false, grunder: g,
      skal: 'grunderna pekar at bade destination och operation — rollen star oppen' };
  if (g.includes(ROLLGRUND.ONE_OF_MUTUALLY_EXCLUSIVE_SET) &&
      !g.includes(ROLLGRUND.AUTHORED_PROSE_STATES_ROLE))
    return { roll: ROLL.UNKNOWN, avgjord: false, grunder: g,
      skal: 'objektet ar ett av flera omsesidigt uteslutande val — button och radio/option ar ' +
        'bada mojliga och prosan avgor inte' };
  return { roll, avgjord: true, grunder: g,
    skal: 'rollen vilar pa ' + g.join(', ') };
}
