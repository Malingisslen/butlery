#!/usr/bin/env node
// Block 285 — revisionsproveniens for registreringen av de manskliga besluten.
//
// ROLL I ARKITEKTUREN
// -------------------
// Det har skriptet ar INTE ett byggsteg och INTE ett runtime-beroende.
// Den kanoniska kallan fas2/role-state-applicability.json bar redan besluten,
// och Block 285 reproduceras enbart ur den. Skriptet finns for att visa HUR
// besluten en gang registrerades, sa att registreringen gar att granska i
// efterhand i stallet for att behova tros pa.
//
// Kor det darfor ALDRIG i den normala reproduktionskedjan. Det kraver ett
// kallage FORE besluten och faller stangt mot en redan beslutad kalla.
//
// Kor (endast for revision, mot en pre-decision-kopia):
//   node tools/role-state-applicability-beslut.mjs <pre-decision-kalla.json>

import { readFileSync, writeFileSync } from 'node:fs';

const FIL = process.argv[2];
if (!FIL) {
  console.error('anvand: node role-state-applicability-beslut.mjs <pre-decision-kalla.json>');
  console.error('OBS: skriptet ar revisionsproveniens, inte ett byggsteg.');
  process.exit(2);
}
const K = JSON.parse(readFileSync(FIL, 'utf8'));
const fail = m => { throw new Error('FAIL CLOSED: ' + m); };
const rad = id => K.rollstate.find(r => r.ROW_ID === id) || fail('raden saknas: ' + id);

/* ── forvantat lage FORE besluten ─────────────────────────────────────── */
const FORE = {
  FORDELNING: { REQUIRED: 3, UNSPECIFIED: 21 },
  SEARCHBOX_SPEC_GAP: 'YES',
  STATUS_FINGERPRINT: '0b76ffd18858971b'
};
/* ── forvantat lage EFTER besluten ────────────────────────────────────── */
const EFTER = {
  FORDELNING: { REQUIRED: 5, NOT_REQUIRED: 4, UNSPECIFIED: 15 },
  SEARCHBOX_SPEC_GAP: 'NO',
  STATUS_FINGERPRINT: '8128ade072cb6f98'
};

const rakna = () => K.rollstate.reduce((o, r) => (o[r.PROPOSED_STATUS] = (o[r.PROPOSED_STATUS] || 0) + 1, o), {});
const lika = (a, b) => JSON.stringify(Object.fromEntries(Object.entries(a).sort())) ===
  JSON.stringify(Object.fromEntries(Object.entries(b).sort()));

// Precondition: kallan MASTE vara obeslutad. En redan beslutad kalla ska
// aldrig muteras igen — det ar hela poangen med att besluten bor i JSON:en.
if (lika(rakna(), EFTER.FORDELNING))
  fail('kallan ar redan beslutad. Det har skriptet ar revisionsproveniens och ' +
    'far inte koras i reproduktionskedjan — Block 285 byggs direkt ur den kanoniska kallan.');
if (!lika(rakna(), FORE.FORDELNING))
  fail('kallan ar varken fore- eller efterlaget: ' + JSON.stringify(rakna()) +
    ', vantade ' + JSON.stringify(FORE.FORDELNING));
if (K.produktbeslut_i_kraft.SEARCHBOX_SPEC_GAP !== FORE.SEARCHBOX_SPEC_GAP)
  fail('SEARCHBOX_SPEC_GAP ar ' + K.produktbeslut_i_kraft.SEARCHBOX_SPEC_GAP +
    ', preconditionen kraver ' + FORE.SEARCHBOX_SPEC_GAP);

/* ── A, B, C, F, G · de sex applicability-besluten ────────────────────── */
const BESLUT = [
 {
  id: 'CSR::ROLE::link::FOCUSED', fran: 'UNSPECIFIED', till: 'REQUIRED', beslut: 'HA285-A',
  basis: 'HUMAN_APPROVED 2026-09-17 (A): Butlery ska krava synligt tangentbordsfokus aven for lankar. ' +
   'Block 285 visade korrekt att ingen befintlig kalla namner link i den rollspecificerade fokusregeln — ' +
   'detta ar darfor ett nytt uttryckligt produkt- och designbeslut, inte en kalltolkning.'
 },
 {
  id: 'CSR::ROLE::menuitem::DISABLED', fran: 'UNSPECIFIED', till: 'NOT_REQUIRED', beslut: 'HA285-B',
  basis: 'HUMAN_APPROVED 2026-09-17 (B): en menyatgard som inte ar tillganglig for anvandarens behorighet ' +
   'ska utelamnas ur menyn, inte visas som en inaktiv menuitem (UNAVAILABLE_MENU_ACTION_POLICY = OMIT). ' +
   'Det gor strecken i behorighetstabellen entydiga framat. Beslutet generaliseras inte till andra kontrolltyper.'
 },
 {
  id: 'CSR::ROLE::menuitem::EXPANDED', fran: 'UNSPECIFIED', till: 'NOT_REQUIRED', beslut: 'HA285-C',
  basis: 'HUMAN_APPROVED 2026-09-17 (C): oppet/stangt tillhor kontrollen som oppnar menyn eller menybehallaren ' +
   '(MENUITEM_EXPANSION_OWNER = OPENER_OR_MENU_CONTAINER). Den enskilda menyposten ska inte bara ett eget expanderat lage.'
 },
 {
  id: 'CSR::ROLE::menuitem::COLLAPSED', fran: 'UNSPECIFIED', till: 'NOT_REQUIRED', beslut: 'HA285-C',
  basis: 'HUMAN_APPROVED 2026-09-17 (C): samma semantiska beslut som for EXPANDED — agarskapet ligger hos ' +
   'oppnaren eller behallaren, inte hos menyposten.'
 },
 {
  id: 'CSR::ROLE::combobox::EXPANDED', fran: 'UNSPECIFIED', till: 'REQUIRED', beslut: 'HA285-F',
  basis: 'HUMAN_APPROVED 2026-09-17 (F): adminwebbens combobox ska exponera sitt oppet/stangt-lage maskinlasbart ' +
   'som ett booleskt expanded state (COMBOBOX_EXPANSION_MODEL = EXPANDED_BOOLEAN). Telefonens arkregel ' +
   'generaliseras fortfarande INTE till adminwebben.'
 },
 {
  id: 'CSR::ROLE::combobox::COLLAPSED', fran: 'UNSPECIFIED', till: 'NOT_REQUIRED', beslut: 'HA285-G',
  basis: 'HUMAN_APPROVED 2026-09-17 (G): stangt lage uttrycks som expanded = false, inte som ett separat ' +
   'COLLAPSED state (COMBOBOX_COLLAPSED_SEPARATE_STATE = NO).'
 }
];

for (const b of BESLUT) {
  const r = rad(b.id);
  if (r.PROPOSED_STATUS !== b.fran)
    fail(b.id + ' star i ' + r.PROPOSED_STATUS + ', preconditionen kraver ' + b.fran);
  r.PROPOSED_STATUS = b.till;
  r.PROVENANCE = 'HUMAN_APPROVED';
  r.HUMAN_DECISION_ID = b.beslut;
  r.DECISION_BASIS = b.basis;
  r.CONFIDENCE = 'HOG';
  r.KRAVER_BESLUT = null;
}

/* ── D · sokfaltets krav star kvar pa kallgrund och lases ─────────────── */
for (const id of ['CSR::ROLE::searchbox::FOCUSED', 'CSR::ROLE::searchbox::DISABLED']) {
  const r = rad(id);
  if (r.PROVENANCE !== 'SOURCE_GROUNDED') fail(id + ' har tappat sin kallgrund');
  if (r.PROPOSED_STATUS !== 'REQUIRED') fail(id + ' star inte som REQUIRED');
  if (r.HUMAN_DECISION_ID) fail(id + ' har fatt en beslutsreferens och skulle da kunna relabelas');
  r.KRAVER_BESLUT = null;
}
K.lasta_kallbelagda = [
  'CSR::ROLE::menuitem::FOCUSED',
  'CSR::ROLE::searchbox::FOCUSED',
  'CSR::ROLE::searchbox::DISABLED'
];

/* ── E · faktakorrigering av Block 284:s premiss, med bevarad historik ── */
K.flagghistorik = K.flagghistorik || {};
K.flagghistorik.SEARCHBOX_SPEC_GAP = {
  previous_value: 'YES',
  new_value: 'NO',
  reason: 'Block 285 verified that component-sheet section 07 exists',
  $sv: 'Faktakorrigering av Block 284:s premiss, inte ett nytt designbeslut. Avsnitt 07 Sokfalt ' +
   'finns och ritar Vila, "Fokus + text", Tokeniserad och "Inaktiverad (tomt bibliotek)" pa rad 261-283. ' +
   'Block 284:s kanoniska fil ar historiskt oforandrad; Block 285 bar det effektiva nedstromsvardet.',
  datum: '2026-09-17'
};
const PB = K.produktbeslut_i_kraft;
PB.SEARCHBOX_SPEC_GAP = 'NO';

/* ── B, C, F, G, H, I · registrerade principer och scope-fynd ─────────── */
PB.UNAVAILABLE_MENU_ACTION_POLICY = 'OMIT';
PB.MENUITEM_EXPANSION_OWNER = 'OPENER_OR_MENU_CONTAINER';
PB.COMBOBOX_EXPANSION_MODEL = 'EXPANDED_BOOLEAN';
PB.COMBOBOX_COLLAPSED_SEPARATE_STATE = 'NO';
PB.SEARCHBOX_VILA_MAPS_TO_DEFAULT = 'YES';
PB.SEARCHBOX_VILA_PROVENANCE = 'HUMAN_APPROVED';
PB.SEARCHBOX_TOKENIZED_STATE_MODEL_GAP = 'YES';

K.modellbeslut = {
  SEARCHBOX_VILA_MAPS_TO_DEFAULT: {
    varde: 'YES', PROVENANCE: 'HUMAN_APPROVED', beslut: 'HA285-H',
    $om: 'Taxonomiskt beslut: "Vila" ar den visuella benamningen pa den befintliga searchbox::DEFAULT-raden, ' +
     'inte ett eget tillstand. Det ar uttryckligen INTE kallbelagt — det undviker en redundant ny state-rad. ' +
     'Block 283:s population ar oforandrad.'
  },
  SEARCHBOX_TOKENIZED_STATE_MODEL_GAP: {
    varde: 'YES', PROVENANCE: 'HUMAN_APPROVED', beslut: 'HA285-I',
    $om: 'Komponentarkets lage "Tokeniserad" motsvarar varken DEFAULT, PRESSED, FOCUSED, SELECTED, DISABLED, ' +
     'EXPANDED eller COLLAPSED. Ingen ny rad laggs till i Block 285 och 70-radersmatrisen utokas inte. ' +
     'Scope-fynd att losa separat innan den definitiva remedieringspopulationen fryses.'
  }
};

/* ── postcondition ────────────────────────────────────────────────────── */
if (!lika(rakna(), EFTER.FORDELNING))
  fail('efterlaget blev ' + JSON.stringify(rakna()) + ', vantade ' + JSON.stringify(EFTER.FORDELNING));
if (PB.SEARCHBOX_SPEC_GAP !== EFTER.SEARCHBOX_SPEC_GAP) fail('flaggan hamnade fel');
if (K.rollstate.some(r => r.KRAVER_BESLUT)) fail('en oppen fraga star kvar efter besluten');

writeFileSync(FIL, JSON.stringify(K, null, 1) + '\n');
console.log('beslut registrerade: ' + BESLUT.length);
console.log('fordelning fore: ' + JSON.stringify(FORE.FORDELNING));
console.log('fordelning efter: ' + JSON.stringify(rakna()));
console.log('statusfingerprint vantas ga ' + FORE.STATUS_FINGERPRINT + ' -> ' + EFTER.STATUS_FINGERPRINT);
console.log('OBS: kor aldrig detta skript i reproduktionskedjan.');
