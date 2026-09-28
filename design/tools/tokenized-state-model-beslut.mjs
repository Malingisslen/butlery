#!/usr/bin/env node
// Block 286 — revisionsproveniens for registreringen av det manskliga
// modellbeslutet om "Tokeniserad".
//
// ROLL I ARKITEKTUREN
// Skriptet ar INTE ett byggsteg. Den kanoniska analysallan bar beslutet efter
// registreringen, och Block 286 byggs enbart ur den. Skriptet visar HUR
// beslutet en gang registrerades. Det kraver ett kallage FORE beslutet och
// faller stangt mot en redan beslutad kalla.
//
// Kor (endast for revision, mot en pre-decision-kopia):
//   node tools/tokenized-state-model-beslut.mjs <pre-decision-kalla.json>

import { readFileSync, writeFileSync } from 'node:fs';

const FIL = process.argv[2];
if (!FIL) {
  console.error('anvand: node tools/tokenized-state-model-beslut.mjs <pre-decision-kalla.json>');
  console.error('OBS: skriptet ar revisionsproveniens, inte ett byggsteg.');
  process.exit(2);
}
const K = JSON.parse(readFileSync(FIL, 'utf8'));
const fail = m => { throw new Error('FAIL CLOSED: ' + m); };

/* ── precondition ─────────────────────────────────────────────────────── */
if (K.modellbeslut && Object.keys(K.modellbeslut).length)
  fail('kallan ar redan beslutad. Skriptet ar revisionsproveniens och far inte ' +
    'koras i reproduktionskedjan — Block 286 byggs direkt ur den kanoniska kallan.');
if (K.utfall.MODELL !== 'COMPOSITE_VISUAL_MODE')
  fail('preconditionen kraver det foreslagna utfallet COMPOSITE_VISUAL_MODE, kallan sager ' + K.utfall.MODELL);
if (K.utfall.PROVENANCE !== 'SOURCE_GROUNDED')
  fail('preconditionen kraver ett foreslaget, inte beslutat, utfall');
if ((K.kraver_beslut || []).length !== 4)
  fail('preconditionen kraver fyra oppna fragor, kallan har ' + (K.kraver_beslut || []).length);

/* ── A · huvudbeslutet ────────────────────────────────────────────────── */
K.utfall.PROVENANCE = 'HUMAN_APPROVED';
K.utfall.HUMAN_DECISION_ID = 'HA286-A';
K.utfall.FORESLAGEN_STATE_ID = null;
K.utfall.$beslut = 'HUMAN_APPROVED 2026-09-17 (A): "Tokeniserad" ar inte ett state hos searchbox-kontrollen. ' +
  'Det ar ett sammansatt visuellt lage bestaende av (1) searchbox eller text-input i sitt befintliga tillstand, ' +
  '(2) noll eller flera token- eller chiplika barnobjekt, och (3) eventuell fortsatt fritext. ' +
  'searchbox::TOKENIZED skapas inte.';

K.modellbeslut = {
  TOKENIZED_MODEL_OUTCOME: 'COMPOSITE_VISUAL_MODE',
  SEARCHBOX_TOKENIZED_IS_PERSISTENT_STATE: 'NO',
  SEARCHBOX_TOKENIZED_STATE_ROW_CREATED: 'NO',
  TOKENIZED_STATE_MODEL_GAP_RESOLVED: 'YES',
  TOKENIZED_STATE_MODEL_GAP_RESOLUTION: 'COMPOSITE_VISUAL_MODE',
  SEARCH_TOKEN_DOES_NOT_INHERIT_FILTER_CHIP_SEMANTICS: 'YES',
  SEARCH_TOKEN_MODEL: 'CHILD_SEMANTICS',
  REMOVABLE_SEARCH_TOKEN_ACTION_ROLE: 'button',
  REMOVABLE_SEARCH_TOKEN_NEEDS_ACCESSIBLE_NAME: 'YES',
  INGREDIENT_SELECTOR_AND_SEARCHBOX_SHARE_INTERACTION_PATTERN: 'NO',
  INGREDIENT_SELECTOR_AND_SEARCHBOX_SHARE_PRIMARY_ACCESSIBILITY_ROLE: 'NO',
  TOKEN_MULTISELECT_IS_ACCESSIBILITY_ROLE: 'NO',
  INGREDIENT_SELECTOR_INTERACTION_PATTERN: 'TOKEN_MULTISELECT',
  INGREDIENT_SELECTOR_PRIMARY_ACCESSIBILITY_ROLE: 'UNSPECIFIED',
  SEARCH_PANEL_PRIMARY_ACCESSIBILITY_ROLE: 'searchbox',
  TOKEN_COMPOSITION_MAY_BE_REUSED_ACROSS_CONTROL_TYPES: 'YES',
  SEARCH_HISTORY_TOKENS_LOCATION: 'OUTSIDE_SEARCHBOX_VALUE',
  SEARCH_HISTORY_IS_CURRENT_SEARCH_VALUE: 'NO',
  CONTROL_STATE_CANDIDATE_LIST_KIND: 'REVIEW_MATRIX',
  CONTROL_STATE_VOCABULARY_CLOSED: 'NO',
  PROVENANCE: 'HUMAN_APPROVED',
  $monster_kontra_roll: 'INGREDIENT_SELECTOR_AND_SEARCHBOX_SHARE_INTERACTION_PATTERN = NO ar ett faktiskt ' +
    'modellbeslut. INGREDIENT_SELECTOR_AND_SEARCHBOX_SHARE_PRIMARY_ACCESSIBILITY_ROLE = NO betyder ENDAST att ' +
    'Block 286 inte har beslutat att ingrediensvaljaren ska bara rollen searchbox — det ar inget positivt stod ' +
    'for nagon alternativ ARIA-roll. TOKEN_MULTISELECT ar ett interaktionsmonster, aldrig en tillganglighetsroll, ' +
    'och utvidgar inte den stangda rollvokabularen.',
  $vokabular: 'CONTROL_STATE_VOCABULARY_CLOSED = NO betyder INTE att nya states far laggas till utan bevis. ' +
    'Ett nytt persistent state kraver fortfarande positiv normativ eller HUMAN_APPROVED grund. ' +
    'Tokeniserad uppfyller inte det kriteriet som searchbox-state.'
};

// Block 285:s historiska flagga lamnas orord i Block 285:s fil.
// Block 286 bar nedstromsresolutionen.
K.gaphistorik = {
  gap: 'SEARCHBOX_TOKENIZED_STATE_MODEL_GAP',
  upstream_fil: 'fas2/role-state-applicability.json',
  upstream_varde_orort: 'YES',
  previous_state: 'OPEN',
  new_state: 'RESOLVED',
  resolved_by: 'HUMAN_APPROVED_BLOCK_286',
  resolution: 'COMPOSITE_VISUAL_MODE',
  datum: '2026-09-17'
};

/* ── B + C · kompositionen och soktokenens semantik ───────────────────── */
K.komposition = {
  $om: 'Laget beskrivs med delar. Ingen del ar ett state hos searchboxen.',
  delar: [
    { DEL: 'searchbox', ROLL: 'searchbox', EGET_TOKENIZED_STATE: false,
      $om: 'Faltet i sitt befintliga tillstand. Tillstanden bor i Block 285:s searchbox-rader.' },
    { DEL: 'token', ROLL: null, STATE: null, ARVER_FRAN_FILTERCHIP: false, HARLEDD_UR: null,
      $om: 'Ett barnobjekt som presenterar ett valt sokord. Ar wrappern inte interaktiv far den ingen ' +
        'artificiell kontrollroll. Visuell chip-form ar inte persistent semantik: filterchippets ' +
        'vaxlingsknapp och pressed arvs inte fran data-component="chip". Semantik harleds ur den faktiska interaktionen.' },
    { DEL: 'token_borttagning', ROLL: 'button', KRAVER_TILLGANGLIGT_NAMN: true, NAMN_AR_IDENTITET: false,
      $om: 'Kan tokenen tas bort ar borttagningen en separat interaktiv kontroll vars roll motsvarar atgarden. ' +
        'Det tillgangliga namnet identifierar bade atgarden och tokenen, till exempel ett namn som anger att ' +
        'just det sokordet tas bort — men ordalydelsen ar innehall, inte identitet.' },
    { DEL: 'fritext', ROLL: null, $om: 'Eventuell fortsatt inmatning i samma falt.' }
  ]
};

/* ── D · primarmonster ────────────────────────────────────────────────── */
// Tva skilda begrepp: tillganglighetsroll och interaktionsmonster.
K.primarmonster = {
  '#sokpanel': { PRIMARY_ACCESSIBILITY_ROLE: 'searchbox', INTERACTION_PATTERN: 'SEARCH' },
  '#ingredienssok': { PRIMARY_ACCESSIBILITY_ROLE: 'UNSPECIFIED', INTERACTION_PATTERN: 'TOKEN_MULTISELECT' },
  $om: 'Ingrediensvaljaren tvingas inte till searchbox for att den innehaller tokens. Samma kompositionsprincip ' +
    'kan ateranvandas over kontrolltyper, men huvudkontrollens roll behover inte vara densamma. ' +
    'Ingen ny roll ar beslutad for ingrediensvaljaren; senare arbete far avgora dess faktiska ' +
    'tillganglighetssemantik om det behovs.'
};

/* ── E · sokhistorik ──────────────────────────────────────────────────── */
K.sokhistorik = {
  LAGE: 'OUTSIDE_SEARCHBOX_VALUE',
  RAKNAS_SOM_AKTUELLT_VARDE: false,
  EGET_SEARCHBOX_STATE: false,
  $om: 'Sokhistorik ar separata atgarder for att ateranvanda tidigare sokningar, intill eller under faltet. ' +
    'Aktiverar ett historikobjekt en tidigare sokning foljer dess roll den atgarden; kan det aven tas bort ' +
    'modelleras borttagningen separat.'
};

/* ── J · kalla kontra beslut ──────────────────────────────────────────── */
K.uppdelning = {
  SOURCE_GROUNDED: [
    'Inget normativt stod for searchbox::TOKENIZED.',
    'Det ritade laget bestar av chip-element plus fritext (komponentark rad 277).',
    'Korpusen har 0 tokeniserade searchbox-forekomster.',
    'Kandidatstate-listan ar en verktygsdriven granskningsmatris (tools/stateflow-population.mjs rad 269).',
    'Befintliga chip/filter-komponenter har egen semantik (handoff rad 152, komponentark rad 146).'
  ],
  HUMAN_APPROVED: [
    'Gapet stangs som COMPOSITE_VISUAL_MODE.',
    'Ingen searchbox::TOKENIZED skapas.',
    'Filterchip-semantik arvs inte automatiskt av soktokens.',
    'Ett borttagbart soktoken anvander en separat atgardskontroll med roll button och tillgangligt namn.',
    'Ingrediensvaljare och searchbox delar inte interaktionsmonster; ingrediensvaljarens tillganglighetsroll ar UNSPECIFIED och TOKEN_MULTISELECT ar ingen roll.',
    'Sokhistorik ligger utanfor aktuellt searchbox-varde.'
  ]
};

// Preciseringen fran uppdragsgivaren, bredvid det analysen sade.
K.fragor['6_har_chippet_egen_modellering'].$precisering =
  'Att filterchippet ar modellerat far INTE tolkas som att sokfaltets token arver dess roll vaxlingsknapp ' +
  'eller state pressed. Visuell chip-form ar inte persistent semantik.';

/* ── de fyra fragorna ar besvarade ────────────────────────────────────── */
const SVAR = ['HA286-A: gapet stangs som COMPOSITE_VISUAL_MODE, ingen ny state-rad.',
  'HA286-C: en icke-interaktiv tokenwrapper far ingen artificiell roll; en borttagning ar en separat button med tillgangligt namn.',
  'HA286-D: ingrediensvaljaren har interaktionsmonstret TOKEN_MULTISELECT och tillganglighetsrollen UNSPECIFIED; sokpanelen ar searchbox med monstret SEARCH. Kompositionsprincipen far ateranvandas.',
  'HA286-E: sokhistorik ligger utanfor searchbox-vardet som separata atgarder.'];
K.besvarade_fragor = K.kraver_beslut.map((f, i) => ({ FRAGA: f.FRAGA, SVAR: SVAR[i] }));
K.kraver_beslut = [];

/* ── forvantat efterlage ──────────────────────────────────────────────── */
K.forvantat.PROVENANCE = 'HUMAN_APPROVED';
K.forvantat.KRAVER_BESLUT_ANTAL = 0;
K.forvantat.MATRIX_ROWS = 70;
K.forvantat.NEW_STATE_ROWS = 0;
K.forvantat.SEARCHBOX_TOKENIZED_STATE_ROW = 'ABSENT';
K.forvantat.MODELLBESLUT_ANTAL = Object.keys(K.modellbeslut).length;
delete K.forvantat.STATUS_FINGERPRINT;
K.statusfingerprint_historik = {
  fore: 'd59323519551de18',
  $om: 'Statusavtrycket andras legitimt nar utfallet gar fran foreslaget (SOURCE_GROUNDED) till beslutat ' +
    '(HUMAN_APPROVED). Gap-identiteten ska sta stilla.'
};

/* ── postcondition ────────────────────────────────────────────────────── */
if (K.kraver_beslut.length) fail('en oppen fraga star kvar');
if (K.utfall.FORESLAGEN_STATE_ID) fail('en state-identitet ar foreslagen');

writeFileSync(FIL, JSON.stringify(K, null, 1) + '\n');
console.log('modellbeslut registrerat: ' + K.utfall.MODELL + ' (' + K.utfall.PROVENANCE + ')');
console.log('flaggor: ' + (Object.keys(K.modellbeslut).length - 2));
console.log('besvarade fragor: ' + K.besvarade_fragor.length + ' · oppna: ' + K.kraver_beslut.length);
console.log('OBS: kor aldrig detta skript i reproduktionskedjan.');
