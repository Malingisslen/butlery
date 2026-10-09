// Kor: node tools/block287-korrigering.mjs <scratchrot> <reporot>
// H-M · Samlad censuskorrigering mot BL-01.
// Manniskobesluten HD-UNMARKED-PRESENTATION och HD-UNDECLARED-AFFORDANCE star fast.
// Det som korrigeras ar MEDLEMSKAPET och de delgruppsregler Fable falsifierade.
import { readFileSync, writeFileSync } from 'node:fs';
const [, , SC, REPO] = process.argv;
const IDX = JSON.parse(readFileSync(SC + '/bl01/idx-full.json', 'utf8'));
const G = JSON.parse(readFileSync(SC + '/bl01/g-A.json', 'utf8'));
const A = JSON.parse(readFileSync(REPO + '/fas2/block287-avgoranden.json', 'utf8'));
const CR = JSON.parse(readFileSync(SC + '/bl01/census-reopen.json', 'utf8'));
const slug = s => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/&amp;/g, '&').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
const occId = e => 'OCC::' + slug(e.fil) + '::' + e.art + '::' + e.ordProd;
const byOcc = new Map(IDX.map(e => [occId(e), e]));
const disc = new Map(G.forekomster.map(f => [f.DISCOVERY_OCCURRENCE_ID, f]));
const find = (art, ord) => IDX.find(e => e.art === art && e.ordProd === ord);
const ref = (art, ord) => { const e = find(art, ord); return e ? occId(e) : null; };

// ── J · HD3 ACTION_TEXT: de nio med olost roll, omprovade mot BL-01
const J = [
  { RAM: 'lagamorkt', ord: 37, NY_KLASS: 'KNOWN_NON_CONTROL', ROLL: null, SKAL: 'instruktionstext 12,5/400 med uppdateringsglyf ovanfor ingredienslistan; hanvisar till andra kontroller, ar ingen egen handling' },
  { RAM: 'lagastaende', ord: 37, NY_KLASS: 'KNOWN_NON_CONTROL', ROLL: null, SKAL: 'samma instruktionstext som lagamorkt#37 i den staende varianten' },
  { RAM: 'kontosakerhet', ord: 12, NY_KLASS: 'KNOWN_CONTROL', ROLL: 'textbox', SKAL: 'identisk kallforfattad stil som syskonen #11 "Nytt losenord" och #16 "Ny e-postadress" i samma ram; rollen ar harledbar ur faltmonstret och var aldrig olost' },
  { RAM: 'veckoplacering', ord: 15, NY_KLASS: 'KNOWN_NON_CONTROL', ROLL: null, SKAL: 'upplysningsbanderoll 12,5/400 med vanster accentkant; en mening som hanvisar till andra kontroller' },
  { RAM: 'veckoplaceringvald', ord: 7, NY_KLASS: 'KNOWN_NON_CONTROL', ROLL: null, SKAL: 'samma upplysningsbanderoll med vald ratt inbakad' },
  { RAM: 'authmfa', ord: 7, NY_KLASS: 'DECORATIVE_OR_STRUCTURAL', ROLL: null, SKAL: 'rubrikrad: flexbehallare som bar skoldglyfen och sidrubriken "Skriv koden" 22/700; texten tillhor rubriken, inte behallaren' },
  { RAM: 'impfoto', ord: 33, NY_KLASS: 'KNOWN_NON_CONTROL', ROLL: null, SKAL: 'informerande brodtext 12/400 i en tonad ruta' },
  { RAM: 'kontosakerhetsvy', ord: 7, NY_KLASS: 'DECORATIVE_OR_STRUCTURAL', ROLL: null, SKAL: 'avsnittsrubrikrad: bar lasglyfen och rubriken "Byt losenord" 17/700; den deklarerade knappen med samma namn ligger separat pa #21' },
  { RAM: 'kontosakerhetsvy', ord: 23, NY_KLASS: 'DECORATIVE_OR_STRUCTURAL', ROLL: null, SKAL: 'avsnittsrubrikrad for "Byt e-post" 17/700; motsvarande deklarerad knapp finns separat' }
];

// ── K · de sex prototyplankarna, omprovade ur produktsemantiken
const K = [
  { RAM: 'rcbkommentar', ord: 34, NY_KLASS: 'KNOWN_CONTROL', ROLL: 'link', SKAL: 'kalldeklarerad tvilling: sokpanel#21 ar role=link med samma synliga text "Andra"; handlingen andrar vilka receptet delas med' },
  { RAM: 'rcbofullstandigt', ord: 9, NY_KLASS: 'KNOWN_CONTROL', ROLL: 'link', SKAL: 'ankarelement i lopande text med korpusens lankfarg #8A5212 och 12,5/600, samma som de deklarerade policylankarna; pekar pa det saknade faltet' },
  { RAM: 'rcbofullstandigt', ord: 10, NY_KLASS: 'KNOWN_CONTROL', ROLL: 'link', SKAL: 'samma monster som #9' },
  { RAM: 'rcbofullstandigt', ord: 11, NY_KLASS: 'KNOWN_CONTROL', ROLL: 'link', SKAL: 'samma monster som #9' },
  { RAM: 'kontojuridik', ord: 29, NY_KLASS: 'KNOWN_CONTROL', ROLL: 'link', SKAL: 'ankarelement med lankfargen i lopande text; korpusens ovriga sadana (jurriktlinjer#18-20, fbanmal#23, bredgrans#20) ar redan KNOWN_CONTROL. Malet ar obevisat och ar en nedstroms namnfraga, inte ett skal att ta elementet ur populationen' },
  { RAM: 'fbblockerade', ord: 19, NY_KLASS: 'KNOWN_CONTROL', ROLL: 'link', SKAL: 'lanktexten namnger en verklig produktvy ("Delat med mig", ramen delatmedmig)' }
];
const K_KVAR = [{ RAM: 'notiscentral', ord: 54, KLASS: 'OUT_OF_SCOPE', SKAL: 'den synliga texten ar ett ram-id ("notisrensa"), inte produktsprak: en designkorsreferens' }];

// ── L · undantag i de breda HD3-delgrupperna
const L = [
  { RAM: 'vmbgenererar', ord: 49, NUVARANDE: 'KNOWN_CONTROL button (CALENDAR_CELLS)', NY_KLASS: 'DECORATIVE_OR_STRUCTURAL', SKAL: 'cellen bar "lagger ut ..." och ar en laddplatshallare i genereringsvyn, inte en placerad maltid' },
  { RAM: 'betygsoversikt', ord: 13, NUVARANDE: 'KNOWN_CONTROL button (TAG_CHIPS)', NY_KLASS: 'KNOWN_NON_CONTROL', SKAL: 'chippet "Familj 4,3" ar ett betygssammandrag, inte ett filter; H18 galler filterchips' }
];

// ── M · grupprollsagare som upptackten aldrig ser
const M = [];
for (const [art, ord] of [['storsttext', 16], ['delatmindel', 11], ['delatnarvaro', 14], ['delatclaimkonflikt', 6]]) {
  const e = find(art, ord);
  M.push({
    RAM: art, ordProd: ord, OCCURRENCE_ID: e ? occId(e) : null,
    I_UPPTACKTEN: e ? disc.has(occId(e)) : false,
    KALLROLL: 'tablist', DEKLARERADE_BARN: e ? e.nDeclInside : null,
    TEXT: e ? e.text.slice(0, 60) : null,
    KRAV: 'GROUP_ROLE_OWNER: gruppbehallaren behover egen populationsenhet med grupprollen tablist; de deklarerade flikarna inuti kan inte bara gruppens roll',
    SKAL: 'detektorn valjer bara element med kontrollform; en omalad flexbehallare traffas aldrig, sa kallregeln for gruppbehallare kordes aldrig pa den'
  });
}

const rader = [];
const addJ = r => { const id = ref(r.RAM, r.ord); const v = id ? A.forekomst[id] : null; rader.push({ AVSNITT: 'J', OCCURRENCE_ID: id, RAM: r.RAM, ordProd: r.ord, TIDIGARE: v ? v.klass + ' / ' + (v.roll || '-') : '-', SUBGROUP: v ? v.sg : '-', NY_KLASS: r.NY_KLASS, ROLL: r.ROLL, SKAL: r.SKAL }); };
J.forEach(addJ);
const addK = r => { const id = ref(r.RAM, r.ord); const v = id ? A.forekomst[id] : null; rader.push({ AVSNITT: 'K', OCCURRENCE_ID: id, RAM: r.RAM, ordProd: r.ord, TIDIGARE: v ? v.klass : '-', SUBGROUP: v ? v.sg : '-', NY_KLASS: r.NY_KLASS, ROLL: r.ROLL, SKAL: r.SKAL }); };
K.forEach(addK);
const addL = r => { const id = ref(r.RAM, r.ord); const v = id ? A.forekomst[id] : null; rader.push({ AVSNITT: 'L', OCCURRENCE_ID: id, RAM: r.RAM, ordProd: r.ord, TIDIGARE: v ? v.klass + ' / ' + (v.roll || '-') : '-', SUBGROUP: v ? v.sg : '-', NY_KLASS: r.NY_KLASS, ROLL: null, SKAL: r.SKAL }); };
L.forEach(addL);

const ut = {
  $om: 'Block 287 · censuskorrigering mot BL-01 efter FINAL FABLE AUDIT. Manniskobesluten star fast; medlemskap och delgruppsregler ar omprovade.',
  BASLINJE: 'BL-01',
  H_I_ATERUPPTAGET_MEDLEMSKAP: {
    DELGRUPPER: ['HD4-BODY_OR_CONTENT_TEXT', 'HD4-CONTAINER_WITH_KNOWN_CONTROLS_AND_OWN_TEXT'],
    ATERUPPTAGNA: CR.ATERUPPTAGNA,
    OMKLASSADE_TILL_KONTROLL: CR.OMKLASSADE_TILL_KONTROLL,
    BEKRAFTADE_SOM_PRESENTATION: CR.KVAR_SOM_PRESENTATION,
    REGLER: CR.REGLER,
    KONTROLLER: CR.KONTROLLER
  },
  J_ACTION_TEXT_OMPROVAD: { ANTAL_I_DELGRUPPEN: Object.values(A.forekomst).filter(v => v.sg === 'HD3-ACTION_TEXT').length, KORRIGERADE: J.length, rader: rader.filter(r => r.AVSNITT === 'J') },
  K_PROTOTYPLANKAR: { ANTAL: 6, OMKLASSADE_TILL_KONTROLL: K.length, KVAR_OUT_OF_SCOPE: K_KVAR, rader: rader.filter(r => r.AVSNITT === 'K') },
  L_UNDANTAG_I_BREDA_DELGRUPPER: { rader: rader.filter(r => r.AVSNITT === 'L') },
  M_SAKNADE_GRUPPROLLSAGARE: { ANTAL: M.length, rader: M },
  SUMMERING: {
    NYA_KONTROLLER_UR_HD4: CR.OMKLASSADE_TILL_KONTROLL,
    HD3_KORRIGERADE: J.length,
    PROTOTYPLANKAR_TILL_KONTROLL: K.length,
    KONTROLLER_SOM_BLIR_PRESENTATION: L.length + J.filter(r => r.NY_KLASS !== 'KNOWN_CONTROL').length,
    NYA_POPULATIONSENHETER_GRUPPROLL: M.length
  }
};
writeFileSync(SC + '/bl01/block287-censuskorrigering.json', JSON.stringify(ut, null, 1) + '\n');
console.log('H/I omklassade:', CR.OMKLASSADE_TILL_KONTROLL, '| bekraftad presentation:', CR.KVAR_SOM_PRESENTATION);
console.log('J korrigerade:', J.length, '(varav till kontroll:', J.filter(r => r.NY_KLASS === 'KNOWN_CONTROL').length + ')');
console.log('K prototyplankar till kontroll:', K.length, '| kvar OUT_OF_SCOPE:', K_KVAR.length);
console.log('L undantag:', L.length, '| M grupprollsagare:', M.length);
console.log('rader utan OCCURRENCE_ID (fail closed-kontroll):', rader.filter(r => !r.OCCURRENCE_ID).length);
