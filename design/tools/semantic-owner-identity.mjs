// PERSISTENT SEMANTISK AGARIDENTITET for remedieringsagare (Block 287).
//
// Tre identiteter halls isar (se discovery-identity.mjs): forekomst-id ar ett positionellt
// handtag, granskningsfamiljen grupperar, och agar-id:t har ar semantiskt. Id:t laser ALDRIG
// klass, verdikt, status, roll, position, ordinal, syskon, geometri, farg eller filordning.
//
// Nyckelformer (utan prefixet OWNER::):
//   <ram>::handling::<handling>[::objekt::<ankare>]   handoffstyrd kontroll: regelns semantiska
//                                                     handling, aldrig nuvarande eller kravt namn
//   <ram>::falt::<falt>                               handoffstyrt falt med fast faltnyckel
//   <ram>::objekt::<ankare>                           kontrollen ar sjalv det ankrade objektet (rad,
//                                                     alternativ, post, chip, plats, installning)
//   <ram>::objekt::<ankare>::handling::<handling>     kontroll i ett ankrat objekt med kallbelagd
//                                                     lokal handling (LOKALA_HANDLINGAR) — aldrig
//                                                     "ensam kontroll i objektet"
//   <ram>::objekt::<ankare>::namn::<rest>             kontroll i ett ankrat objekt; resten ar namnet
//                                                     utan objektets eget innehall
//   <ram>::handling|grupp|namn::<nyckel>              ovriga: dokumenterad handling, grupp eller
//                                                     stabilt namn utan flyktiga tal och utan kant
//                                                     lage (LAGESFRASER; semantik, inte skiljetecken)
//
// Innehall, lage och valt varde (person, ratt, vara, tagg, grupp, notistext, "Svenska", "På",
// "avstängd …") ar aldrig identitet.
//
// Beslut (Block 287): HANDOFF_GOVERNED_OWNER_ID_POLICY = SEMANTIC_PATTERN_KEY, inget aliaslager.
// Upprepade objekt bar ett opakt, kallforfattat data-occurrence ("occ-" + 12 bokstaver) pa det
// minsta agande semantiska objektet (rad, alternativ, post, chip, betygsgrupp, omrade).
//
// FAIL CLOSED: saknas ett kravt ankare, ar ankaret en innehallsbaserad legacy-skuld, eller kan
// tva agare inte sarskiljas, far ingen av dem ett id. Visningsnamnet ar aldrig reserv for en
// agare vars namn bar objektinnehall.
const fold = s => String(s == null ? '' : s).normalize('NFD').replace(/[̀-ͯ]/g, '');
export const slug = s => fold(s).toLowerCase().replace(/&amp;/g, '&').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
export const stabilNamn = s => slug(String(s == null ? '' : s).replace(/\d+(?:[.,:]\d+)*/g, ' '));

// Dokumenterade navigeringshandlingar. Portionsvaljaren: handoffen "Färre/Fler portioner".
export const HANDLINGAR = { 'Tillbaka': 'back', 'Föregående steg': 'previous-step',
  'Tillbaka till konversationer': 'back-to-conversations', 'Nästa steg': 'next-step',
  'Ta bort bilden': 'remove-image',
  'Färre portioner': 'decrement-portioner', 'Minska portioner': 'decrement-portioner',
  'Fler portioner': 'increment-portioner', 'Öka portioner': 'increment-portioner' };

/** Etikett for en kontroll vars namn bar sitt valda varde ("Enhet, deciliter"): fore forsta komma/kolon. */
export const stabilEtikett = (namn, harVarde) => { const n = String(namn == null ? '' : namn); return harVarde ? n.split(/[,:]/)[0].trim() : n; };

/** Grundnyckel for en agare utan handoffregel och utan innehallsobjekt. null = ingen stabil grund. */
export function agarNyckel(f) {
  if (f.kallAnkare) return 'OWNER::' + f.kallAnkare;
  if (!f.art) return null;
  const handling = f.handling || HANDLINGAR[f.namn];
  if (handling) return 'OWNER::' + f.art + '::handling::' + handling;
  const n = stabilNamn(f.namn);
  if (!n) return null;
  return 'OWNER::' + f.art + '::' + (f.grupp ? 'grupp' : 'namn') + '::' + n;
}

/** Normaliserar ett namnsegment i ett enhets-id: tal bort, utom bevisade varden. */
export function stabilSegment(namnSlug, tillatTal) { return tillatTal ? namnSlug : stabilNamn(String(namnSlug).replace(/-/g, ' ')); }

/* ── Handoffens komponenttabell ─────────────────────────────────────────── */

/** Matrisen ur tillganglighetshandoffen (49 rader). */
export function handoffMatris(html) {
  return [...html.matchAll(/\{\s*name:'([^']*)',\s*role:'([^']*)',\s*label:'([^']*)',\s*state:'([^']*)',\s*note:'([^']*)'\s*\}/g)]
    .map((m, i) => ({ HANDOFF_RULE_ID: 'H' + String(i + 1).padStart(2, '0'), CONTROL_PATTERN: m[1], REQUIRED_ROLE: m[2], ACCESSIBLE_NAME_TEMPLATE: m[3], STATE_REQUIREMENTS: m[4], NOTE: m[5] }));
}

// Agarpolicy per regel (CONTROL_PATTERN). Varje regel ar klassad; ingen faller tillbaka pa namnet.
export const POLICY = {
  'Bottennavigation': { policy: 'STABLE_OPTION_VALUE', nyckel: null, tillatenSlot: 'uppraknad etikett (Hem · Meny · Inköp · Mer) + "Lägg till"', grupp: 'bottom-navigation' },
  'Bakåt': { policy: 'SEMANTIC_ACTION', nyckel: 'back', forbjudna: ['föregående vy'] },
  'Stäng (X)': { policy: 'SEMANTIC_ACTION', nyckel: 'close', forbjudna: ['vyns namn'] },
  'Kebab': { policy: 'SEMANTIC_ACTION', nyckel: 'more-actions', forbjudna: ['objekt'], ankareVidUpprepning: true },
  'Sidtitel': { policy: 'NO_CONTROL_OWNER' },
  'Textstorlek (A+)': { policy: 'SEMANTIC_ACTION', nyckel: 'increase-text-size' },
  'Favorit': { policy: 'SEMANTIC_ACTION', nyckel: 'favorite-toggle', forbjudna: ['lage'], ankareVidUpprepning: true },
  'Ladda ned': { policy: 'SEMANTIC_ACTION', nyckel: 'download-offline' },
  'Portionsväljare': { policy: 'GROUP_OWNER', nyckel: null, tillatenSlot: 'fast etikett "Portioner" (grupp namn::portioner); − och + = decrement-/increment-portioner' },
  'Flikar Ingredienser / Gör så här': { policy: 'STABLE_OPTION_VALUE', tillatenSlot: 'uppraknad flik (Ingredienser · Gör så här)', grupp: 'recipe-tabs' },
  'Skafferistatus per rad': { policy: 'NO_CONTROL_OWNER' },
  'Lägg N varor i inköpslistan': { policy: 'SEMANTIC_ACTION', nyckel: 'add-to-shopping-list', forbjudna: ['antal'] },
  'Steg framåt / bakåt': { policy: 'SEMANTIC_ACTION', nyckel: null, tillatenSlot: 'uppraknad handling next-step · previous-step' },
  'Timerchip': { policy: 'SEMANTIC_ACTION', nyckel: 'start-timer', forbjudna: ['tid'], ankareVidUpprepning: true },
  'Ingrediensbyte': { policy: 'SEMANTIC_ACTION_PLUS_OBJECT_KEY', nyckel: 'substitute-ingredient', forbjudna: ['ingrediens'] },
  'Kryssruta i lista': { policy: 'SEMANTIC_ACTION_PLUS_OBJECT_KEY', nyckel: 'check-item', forbjudna: ['radens text'] },
  'Krysslista allergener': { policy: 'GROUP_OWNER', nyckel: 'allergens', tillatenSlot: 'gruppens fasta etikett' },
  'Chip / filter': { policy: 'STABLE_OPTION_VALUE', nyckel: 'filter', forbjudna: ['visningsnamn'], kraverOptionsnyckel: true },
  'Segment (Kan redigera / Endast läsa)': { policy: 'STABLE_OPTION_VALUE', grupp: 'permission', tillatenSlot: 'uppraknat varde (Kan redigera · Endast läsa)' },
  'Toggle': { policy: 'STABLE_CONTROL_FIELD', tillatenSlot: 'radens fasta produktetikett (statisk kopia, inte innehall)' },
  'Stepper (mängd)': { policy: 'SEMANTIC_ACTION_PLUS_OBJECT_KEY', nyckel: 'quantity', forbjudna: ['vara'] },
  'Textfält': { policy: 'STABLE_CONTROL_FIELD', tillatenSlot: 'faltets fasta etikett' },
  'Lösenordsfält': { policy: 'STABLE_CONTROL_FIELD', nyckel: 'password' },
  'Visa/dölj lösenord': { policy: 'SEMANTIC_ACTION', nyckel: 'toggle-password-visibility', forbjudna: ['lage'], ankareVidUpprepning: true },
  'OTP-kod': { policy: 'STABLE_CONTROL_FIELD', nyckel: 'verification-code' },
  'Stjärnbetyg (inmatning)': { policy: 'SEMANTIC_ACTION_PLUS_OBJECT_KEY', nyckel: 'rating', forbjudna: ['person'], tillatenSlot: 'betygsvarde 1–5 inom gruppen' },
  'Sortering': { policy: 'SEMANTIC_ACTION', nyckel: 'sort', forbjudna: ['aktuell ordning'] },
  'Draghandtag (ingrediens, steg, bildsida)': { policy: 'SEMANTIC_ACTION_PLUS_OBJECT_KEY', nyckel: 'move', forbjudna: ['rad'] },
  'Radens åtgärdsmeny': { policy: 'SEMANTIC_ACTION_PLUS_OBJECT_KEY', nyckel: 'row-actions', forbjudna: ['rad'] },
  'Flytta upp / ned': { policy: 'SEMANTIC_ACTION_PLUS_OBJECT_KEY', nyckel: null, tillatenSlot: 'move-up · move-down', forbjudna: ['rad'] },
  'Bottom sheet': { policy: 'NO_CONTROL_OWNER' }, 'Dialog': { policy: 'NO_CONTROL_OWNER' },
  'Kontextmeny': { policy: 'GROUP_OWNER', nyckel: 'context-menu', forbjudna: ['objekt'] },
  'Snackbar': { policy: 'NO_CONTROL_OWNER', tillatenSlot: 'atgarden ags av sin handling (Ångra, Försök igen)' },
  'Scrim': { policy: 'NO_CONTROL_OWNER' }, 'Sparat-status': { policy: 'NO_CONTROL_OWNER' }, 'Offlinebanner': { policy: 'NO_CONTROL_OWNER' },
  'Importsteg': { policy: 'NO_CONTROL_OWNER' }, 'Tallrikslinje-progress': { policy: 'NO_CONTROL_OWNER' }, 'Skelettrader': { policy: 'NO_CONTROL_OWNER' },
  'Nedräkning (Skicka igen 42 s)': { policy: 'SEMANTIC_ACTION', nyckel: 'resend-code', forbjudna: ['sekunder'] },
  'Tomläge': { policy: 'NO_CONTROL_OWNER' }, 'Avatar med namn intill': { policy: 'NO_CONTROL_OWNER' },
  'Avatar utan namn': { policy: 'NO_CONTROL_OWNER', forbjudna: ['personens namn'] },
  'Receptbild': { policy: 'NO_CONTROL_OWNER' }, 'Bild kunde inte laddas': { policy: 'NO_CONTROL_OWNER' },
  'Fotograferad receptsida': { policy: 'SEMANTIC_ACTION_PLUS_OBJECT_KEY', nyckel: 'recipe-page', tillatenSlot: 'sidnummer n (dokumentets sidordning)', forbjudna: ['vald'] },
  'Kamera / ladda upp': { policy: 'SEMANTIC_ACTION', nyckel: null, tillatenSlot: 'take-photo · choose-from-library' },
  'Logotyp och cloche': { policy: 'NO_CONTROL_OWNER' } };

// Igenkanning: vilken regel styr en kontroll? Mall med valfria slottar och dokumenterade nuvarande
// avvikelser (bevis for igenkanning, aldrig identitet).
export const IGENKANNING = [
  ['Bakåt', k => /^Tillbaka( till .+)?$/.test(k.namn) && (!k.glyf || /^(arrow-left|chevron-left)$/.test(k.glyf))],
  ['Stäng (X)', k => /^Stäng( .+)?$/.test(k.namn) && (!k.glyf || k.glyf === 'x')],
  ['Kebab', k => /^Fler åtgärder( för .+)?$/.test(k.namn)],
  ['Textstorlek (A+)', k => /^(Öka textstorlek|Textstorlek)$/.test(k.namn) || k.text === 'A+'],
  ['Favorit', k => /^(Spara som favorit|Ta bort från favoriter)$/.test(k.namn)],
  ['Ladda ned', k => /^Spara receptet offline$/.test(k.namn)],
  ['Lägg N varor i inköpslistan', k => /^Lägg \d+ varor i inköpslistan$/.test(k.namn)],
  ['Steg framåt / bakåt', k => /^(Nästa steg|Föregående steg)$/.test(k.namn)],
  ['Timerchip', k => /^Starta timer\b/.test(k.namn)],
  // handoffen: "i receptdetaljen"; veckomenyns "Byt ut {rätt}" ar inte H15 (se VECKOMENY_BYTE)
  ['Ingrediensbyte', k => /^Byt ut .+/.test(k.namn) && !/^Veckomeny/.test(k.ramEtikett || '')],
  ['Chip / filter', k => /^Filtrera på .+/.test(k.namn)],
  ['Visa/dölj lösenord', k => /^(Visa|Dölj)( nuvarande)? lösenord(et)?$/.test(k.namn)],
  ['OTP-kod', k => /^(Verifieringskod, sex siffror|Sexsiffrig kod)$/.test(k.namn)],
  ['Stjärnbetyg (inmatning)', k => (k.roll === 'radiogroup' && /^Betyg för .+/.test(k.namn)) || (k.roll === 'radio' && /^\d av 5 för .+/.test(k.namn))],
  ['Sortering', k => /^Sortera\b/.test(k.namn)],
  ['Flytta upp / ned', k => /^Flytta .+ (upp|ned)$/.test(k.namn)],
  ['Draghandtag (ingrediens, steg, bildsida)', k => (k.glyf === 'drag' || /^Flytta rad$/.test(k.namn)) && /^Flytta( .+)?$/.test(k.namn) && !/ (upp|ned)$/.test(k.namn)],
  ['Radens åtgärdsmeny', k => /^(Åtgärder för .+|Radens åtgärder)/.test(k.namn)],
  ['Nedräkning (Skicka igen 42 s)', k => /^Skicka koden igen/.test(k.namn)],
  ['Kamera / ladda upp', k => /^(Fota receptet|Välj bild från biblioteket)$/.test(k.namn)],
  ['Stepper (mängd)', k => /^(Minska|Öka) mängden$/.test(k.namn)],
  ['Fotograferad receptsida', k => /^(Förstora )?[Ss]ida \d+ av /.test(k.namn)],
  ['Kryssruta i lista', k => k.roll === 'checkbox' && k.iLista === true]];
export const styrandeRegel = k => (IGENKANNING.find(([, f]) => f(k)) || [null])[0];
export const kraverObjektankare = monster => { const p = POLICY[monster]; return !!p && (p.policy === 'SEMANTIC_ACTION_PLUS_OBJECT_KEY' || !!p.kraverOptionsnyckel); };

/** Nyckel for en handoffstyrd kontroll: { monster, nyckel } | { monster, olost, skal } | null (ej styrd). */
export function handoffNyckel(k) {
  const monster = styrandeRegel(k); if (!monster) return null;
  const p = POLICY[monster];
  const ankare = k.ankare ? '::objekt::' + slug(k.ankare) : '';
  let handling = p.nyckel;
  if (monster === 'Steg framåt / bakåt') handling = /^Nästa/.test(k.namn) ? 'next-step' : 'previous-step';
  if (monster === 'Flytta upp / ned') handling = / upp$/.test(k.namn) ? 'move-up' : 'move-down';
  if (monster === 'Kamera / ladda upp') handling = /^Fota/.test(k.namn) ? 'take-photo' : 'choose-from-library';
  if (kraverObjektankare(monster)) {
    if (!k.ankare) return { monster, olost: true, skal: 'upprepat monster "' + monster + '" utan kallforfattat objekt-/optionsankare' };
    if (monster === 'Stjärnbetyg (inmatning)' && k.roll === 'radio') return { monster, nyckel: k.art + '::handling::rating' + ankare + '::varde::' + (k.namn.match(/^(\d)/) || [])[1] };
    return { monster, nyckel: k.art + '::handling::' + handling + ankare };
  }
  if (p.policy === 'STABLE_CONTROL_FIELD' && p.nyckel) return { monster, nyckel: k.art + '::falt::' + p.nyckel + ankare };
  return { monster, nyckel: k.art + '::handling::' + handling + ankare };
}

/* ── Objektankare ───────────────────────────────────────────────────────── */

// DEFERRED_LEGACY_IDENTITY_DEBT: tio aldre data-occurrence vars varde ar hartlett ur innehall
// (person, vara, listnamn, lage). De andras inte har, men far inte bli grund for en ny persistent
// agare utan uttrycklig granskning.
export const LEGACY_IDENTITY_DEBT = Object.freeze([
  'forfragningar-erik-sandell-acceptera', 'forfragningar-hanna-vik-acceptera',
  'rcbofullstandigt-smor-mangd', 'rcbofullstandigt-kanel-mangd',
  'delatinkorg-helgens-inkop', 'delatinkorg-fredagstacos',
  'delatmindel-gul-lok-anna-tar', 'delatmindel-potatis-anna-tar', 'delatmindel-smor-tar-jag', 'delatmindel-vitlok-tar-jag']);

/**
 * Narmaste kallforfattade objektankare for en kontroll. kedja = [kontrollens element, forfader, ...]
 * inom ramen, varje led { occ, innehall: [textsegment utanfor kontrollens eget undertrad] }.
 * Returnerar { ankare, agerSjalv, innehall } | { skuld } | null.
 */
export function narmasteAnkare(kedja) {
  for (let i = 0; i < kedja.length; i++) {
    const led = kedja[i]; if (!led || !led.occ) continue;
    if (LEGACY_IDENTITY_DEBT.includes(led.occ)) return { skuld: led.occ, agerSjalv: i === 0 };
    return { ankare: led.occ, agerSjalv: i === 0, innehall: led.innehall || [] };
  }
  return null;
}

/** Namnet utan objektets eget innehall (hela segment, skiftlage ignoreras), som stabil nyckel. */
export function utanObjektinnehall(namn, innehall) {
  let n = ' ' + fold(namn).toLowerCase() + ' ';
  const seg = [...new Set((innehall || []).map(s => fold(s).toLowerCase().trim()).filter(s => /\p{L}/u.test(s) && s.replace(/[^\p{L}]/gu, '').length >= 2))].sort((a, b) => b.length - a.length);
  for (const s of seg) { const e = s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); n = n.replace(new RegExp('(^|[^\\p{L}\\p{N}])' + e + '(?=$|[^\\p{L}\\p{N}])', 'gu'), '$1 '); }
  return stabilNamn(n);
}

// Innehallsmallar som alltid bar objektinnehall i namnet. Utan objektankare faller de stangt.
export const INNEHALLSMALLAR = [
  ['VECKOMENY_BYTE', k => /^Byt ut .+/.test(k.namn) && /^Veckomeny/.test(k.ramEtikett || ''), 'replace-dish'],
  ['ROSTNING', k => /^Rösta på .+/.test(k.namn), null],
  ['VINNARVAL', k => /^Välj .+ som vinnare/.test(k.namn), null],
  ['NOTIS', k => /^(Läst|Oläst): .+/.test(k.namn), null]];
export const innehallsmall = k => (INNEHALLSMALLAR.find(([, f]) => f(k)) || [null, null, null]);

// TILLSTAND OCH VARDE ar aldrig identitet. Kanda lagesfraser med sin semantik (inte skiljetecken):
// frasen ar ett efterstallt lage till kontrollens fasta semantik, oavsett vilket tecken som skiljer dem.
export const LAGESFRASER = [
  ['DISABLED_UNTIL_COMPLETE', /avstängd till dess .+/i],
  ['UNAVAILABLE_OFFLINE', /ej tillgänglig offline/i],
  ['NOT_YET_AVAILABLE', /finns inte ännu/i],
  ['PLACEHOLDER_NO_VALUE', /välj ett år/i],
  ['SWITCH_STATE', /(avstängd|påslagen|på|av)/i, 'switch']];   // bara reglage: lagesordet ar reglagets varde
/** { stabil, tillstand } nar namnet ar fast semantik + ett kant lage, annars null. */
export function lagesSemantik(namn, roll) {
  const n = String(namn == null ? '' : namn).trim();
  for (const [tillstand, fras, bara] of LAGESFRASER) {
    if (bara && roll !== bara) continue;
    const m = n.match(new RegExp('^(.*?[\\p{L}\\p{N}])[\\s,;:–—·(]+(' + fras.source + ')\\)?\\s*$', 'iu'));
    if (m && stabilNamn(m[1])) return { stabil: m[1].trim(), tillstand };
  }
  return null;
}
// Valt varde som visas som egen kontroll i ett ankrat installningsobjekt ("Svenska", "På").
export const VARDEN = /^(svenska|english|engelska|suomi|finska|norsk|norska|dansk|danska|på|av)$/i;
// Lokala handlingar i ett redan ankrat objekt, med kallbevis. Id = objektankare + handling;
// en ny kontroll i samma objekt andrar inte detta id.
export const LOKALA_HANDLINGAR = [
  ['rule-active', k => k.roll === 'switch' && ['taggdetalj', 'taggregel'].includes(k.art), 'taggregel: reglaget heter "Regeln är aktiv" — det slar regeln pa/av'],
  ['current-value', k => VARDEN.test(String(k.namn).trim()), 'installningens valda varde (sprak, på/av) — vardet ar lage, inte identitet']];
export const lokalHandling = k => (LOKALA_HANDLINGAR.find(([, f]) => f(k)) || [null])[0];

// KALLBUNDNA HANDOFFMONSTER (R12). Ett kallankare som bevisats instansiera ett handoffmonster binds har
// uttryckligen: ankare → regel + handling. Beviset (glyf, tvilling, sammanhang) anvandes EN gang vid
// avgorandet och lases aldrig igen — namn, glyf, lage och tvillingar kan andras utan att agaren andras.
// bunden: SJALV = det ankrade elementet ar kontrollen; annars rollen hos den kontroll i objektet som bindningen
// avser (en tvetydig traff faller stangt via tilldela). Ingen visuell heuristik ("kryssglyf => close").
// epostverif: handoffens H41 (nedrakning/skicka igen) men vyn skickar en LANK — handlingen ar
// resend-verification-link; namnkravet "Skicka koden igen" ar ett separat, olost normkonflikt.
export const MONSTERBINDNINGAR = Object.freeze({
  'occ-sqwgjvtaefne': { art: 'allergener', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-onayqntglegj': { art: 'allergener', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-iiomdcbgckdf': { art: 'allergener', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-kajlctktzblm': { art: 'cooksnapgalleri', regel: 'H04', handling: 'more-actions', bunden: 'button' },
  'occ-eforxhockavf': { art: 'cooksnapgalleri', regel: 'H04', handling: 'more-actions', bunden: 'button' },
  'occ-felravaojrkb': { art: 'epostverif', regel: 'H41', handling: 'resend-verification-link', bunden: 'SJALV' },
  'occ-yqothacnvnhd': { art: 'hemtom', regel: 'H48', handling: 'take-photo', bunden: 'SJALV' },
  'occ-eowhvihfuelh': { art: 'installningar', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-uqcmuermtfbl': { art: 'lagaliggande', regel: 'H03', handling: 'close', bunden: 'SJALV' },
  'occ-imaflvduaqco': { art: 'lagamorkt', regel: 'H03', handling: 'close', bunden: 'SJALV' },
  'occ-jekixzlgfkan': { art: 'lagastaende', regel: 'H03', handling: 'close', bunden: 'SJALV' },
  'occ-rjuqllmkiouu': { art: 'lagastaende320', regel: 'H03', handling: 'close', bunden: 'SJALV' },
  'occ-aukacbsbrdew': { art: 'notisinstallningar', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-irtjvpvvevly': { art: 'notisinstallningar', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-zaqxkctxeiqv': { art: 'notisinstallningar', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-durbkqquvyzz': { art: 'notisinstallningar', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-ynqewhlxcxvv': { art: 'notisinstallningar', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-dxtzbgmkzywa': { art: 'notisinstallningar', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-esunrbxqhghe': { art: 'notisinstallningar', regel: 'H20', handling: 'toggle-setting', bunden: 'switch' },
  'occ-xnjjfrzeodza': { art: 'onbimport', regel: 'H48', handling: 'take-photo', bunden: 'SJALV' },
  'occ-xvuwbgpxqzoz': { art: 'storsttext', regel: 'H04', handling: 'more-actions', bunden: 'SJALV' },
  'occ-obfjmqzimeic': { art: 'vanprofildelning', regel: 'H04', handling: 'more-actions', bunden: 'SJALV' },
});
/** Bindning for en kontroll vars narmaste ankare ar bundet, annars null. */
export function monsterBindning(k) {
  const o = k.objekt; if (!o || !o.ankare) return null; const b = MONSTERBINDNINGAR[o.ankare]; if (!b || b.art !== k.art) return null;
  return (o.agerSjalv ? b.bunden === 'SJALV' : b.bunden !== 'SJALV' && k.roll === b.bunden) ? b : null;
}

/**
 * Agarnyckel ur semantiska fakta, i prioritetsordning:
 *   1 kallforfattat ankare ur upptackten (kallAnkare) — ororat
 *   1b kallbundet handoffmonster (MONSTERBINDNINGAR): <ram>::objekt::<ankare>::handling::<handling>
 *   2 handoffregel → SEMANTIC_PATTERN_KEY (objektankare nar regeln kraver det eller vid upprepning)
 *   3 innehallsburen agare → objektankaret; namnet bara utan objektets innehall
 *   4 dokumenterad handling, grupp eller stabilt namn
 * k: { art, namn, roll, glyf, text, iLista, ramEtikett, grupp, handling, kallAnkare,
 *      objekt: narmasteAnkare(...), anvandAnkare: bool (satts av tilldela vid upprepning) }
 * Returnerar { nyckel, regel } | { olost, skal, regel }.
 */
export function semantiskAgare(k0) {
  if (k0.kallAnkare) return { nyckel: 'OWNER::' + k0.kallAnkare, regel: 'KALLANKARE' };
  const lage = lagesSemantik(k0.namn, k0.roll);
  const k = lage ? { ...k0, namn: lage.stabil, lage: lage.tillstand } : k0;
  const o = k.objekt || null;
  const b = monsterBindning(k);
  if (b) return { nyckel: 'OWNER::' + k.art + '::objekt::' + slug(o.ankare) + '::handling::' + b.handling, regel: 'BINDNING', monster: b.regel };
  const monster = styrandeRegel(k);
  if (monster) {
    const behover = kraverObjektankare(monster) || k.anvandAnkare;
    if (behover && o && o.skuld) return { olost: true, regel: 'HANDOFF', monster, skal: 'LEGACY_IDENTITY_DEBT: ankaret ' + o.skuld + ' ar innehallsbaserat och far inte bli agargrund utan granskning' };
    const h = handoffNyckel({ ...k, ankare: behover && o ? o.ankare : null });
    return h.olost ? { olost: true, regel: 'HANDOFF', monster, skal: h.skal } : { nyckel: 'OWNER::' + h.nyckel, regel: 'HANDOFF', monster };
  }
  const [mall, , mallHandling] = innehallsmall(k);
  const lokal = o && !o.agerSjalv ? lokalHandling(k) : null;
  if (!o && VARDEN.test(String(k.namn).trim())) return { olost: true, regel: 'VARDE', skal: 'namnet ar bara ett valt varde och kontrollen saknar ankrat installningsobjekt' };
  if (o && (o.agerSjalv || mall || lokal || utanObjektinnehall(k.namn, o.innehall) !== stabilNamn(k.namn))) {
    if (o.skuld) return { olost: true, regel: 'OBJEKT', skal: 'LEGACY_IDENTITY_DEBT: ankaret ' + o.skuld + ' ar innehallsbaserat och far inte bli agargrund utan granskning' };
    const bas = k.art + '::objekt::' + slug(o.ankare);
    if (o.agerSjalv) return { nyckel: 'OWNER::' + bas, regel: 'OBJEKT' };
    if (mallHandling) return { nyckel: 'OWNER::' + bas + '::handling::' + mallHandling, regel: 'OBJEKT' };
    if (lokal) return { nyckel: 'OWNER::' + bas + '::handling::' + lokal, regel: 'OBJEKT' };
    const rest = utanObjektinnehall(k.namn, o.innehall);
    return { nyckel: 'OWNER::' + bas + (rest ? '::namn::' + rest : ''), regel: 'OBJEKT' };
  }
  if (mall) return { olost: true, regel: 'INNEHALLSMALL', skal: mall + ': namnet bar objektinnehall och kontrollen saknar kallforfattat objektankare' };
  const g = agarNyckel(k);
  return g ? { nyckel: g, regel: lage ? 'LAGE_UTESLUTET' : 'NAMN', lage: lage && lage.tillstand } : { olost: true, regel: 'NAMN', skal: 'ingen stabil semantisk grund' };
}

/**
 * Tilldelar id till en mangd fakta. Handoffstyrda kontroller vars handling upprepas i ramen far
 * sitt objektankare (ankareVidUpprepning); aterstar en kollision far ingen av dem ett id, utom nar
 * alla kolliderande ar alternativ i samma grupp som skiljer sig bara pa sitt varde (OPTION_VALUE).
 */
export function tilldela(fakta) {
  const rakna = xs => { const m = new Map(); for (const x of xs) if (x.r.nyckel) m.set(x.r.nyckel, (m.get(x.r.nyckel) || 0) + 1); return m; };
  let bas = fakta.map(f => ({ f, r: semantiskAgare(f) }));
  let antal = rakna(bas);
  bas = bas.map(b => (b.r.regel === 'HANDOFF' && b.r.nyckel && antal.get(b.r.nyckel) > 1 && b.f.objekt && !b.f.anvandAnkare)
    ? { f: { ...b.f, anvandAnkare: true }, r: semantiskAgare({ ...b.f, anvandAnkare: true }) } : b);
  antal = rakna(bas);
  return bas.map(({ f, r }) => {
    if (!r.nyckel) return { f, id: null, status: 'OWNER_IDENTITY_UNRESOLVED', regel: r.regel, skal: r.skal };
    if (antal.get(r.nyckel) === 1) return { f, id: r.nyckel, status: 'RESOLVED', regel: r.regel, monster: r.monster };
    const krock = bas.filter(b => b.r.nyckel === r.nyckel);
    const fulla = new Set(krock.map(b => slug(b.f.namn)));
    if (r.regel === 'NAMN' && krock.every(b => b.f.alternativ && b.f.alternativ === f.alternativ) && fulla.size === krock.length)
      return { f, id: 'OWNER::' + f.art + '::namn::' + slug(f.namn), status: 'RESOLVED', regel: r.regel, undantag: 'OPTION_VALUE' };
    return { f, id: null, status: 'OWNER_IDENTITY_UNRESOLVED', regel: r.regel, skal: krock.length + ' agare delar ' + r.nyckel + ' — kan inte sarskiljas' };
  });
}

/** Dubblettrevision: ett data-occurrence-varde far forekomma exakt en gang i en designfil. */
export function ankarRevision(html) {
  const c = new Map(); for (const m of String(html).matchAll(/data-occurrence="([^"]*)"/g)) c.set(m[1], (c.get(m[1]) || 0) + 1);
  return [...c].filter(([, n]) => n > 1).map(([v]) => v);
}
