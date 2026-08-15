#!/usr/bin/env node
// F2 · BESTANDIGA PROV FOR UPPTACKTEN AV ODEKLARERADE KONTROLLER.
//
// Kör: node tools/control-shape-discovery-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN DESSA PROV FINNS FOR
// Den forsta upptackten var bunden till authored data-component och en enda
// hardkodad form; knappar kunde aldrig bli kandidater. Nar det rattades
// infordes tva NYA fel: 48x48 anvandes som upptacktsgrind, och regeln valdes
// pa declared/(declared+undeclared) som om oadjudicerade kandidater vore
// falska positiva. Bada kopplar ihop upptackt med konformitet, och bada ar
// lasta har.
//
//   UDC-01  ett verkligt odeklarerat knappobjekt upptacks
//   UDC-02  upptackten ar inte tom — den skiljer pa objekt med och utan form
//   UDC-03  upptackt ger kandidat, aldrig verdikt
//   UDC-04  ett redan deklarerat objekt ligger inte kvar i listan
//   UDC-05  radagare och visuellt barn dedupliceras
//   UDC-06  tvetydigt agarskap ger fail closed, ingen kandidat
//   UDC-07  befintliga stabila identiteter bevaras
//   UDC-08  dialogsparameny-kryssrutan forblir samma objekt, ingen dublett
//   UDC-09  en kand kryssruta i en dialog gor inte syskonen interaktiva
//   UDC-10  skarmkontext far utlosa granskning men aldrig verdikt
//   UDC-11  en kontroll under 48 px kan anda upptackas
//   UDC-12  traffytans PASS/FAIL paverkar inte medlemskapet
//   UDC-13  en deklarerad 42 px-struktur, virtuellt odeklarerad, ar upptackbar
//   UDC-14  recall mats utan att kontrollens semantiska verdikt anvands
//   UDC-15  en oadjudicerad kandidat raknas inte som falsk positiv
//   UDC-16  regelval far inte optimera pa declared/(declared+undeclared)
//   UDC-17  varje missad deklarerad kontroll far exakt en primar gap-orsak
//   UDC-18  unionen har inga tysta missar
//   UDC-19  kandidatens agare stams av mot samma semantiska agare
//   UDC-20  borttagna konformitetstrosklar andrar inte semantiska verdikt
//   UDC-21  nastlad malad form blockerar inte agarupptackt
//   UDC-22  nastlad malad form gor inte heller foraldern till kandidat automatiskt
//   UDC-23  en omalad atgardsagare upptacks utan krav pa centrering
//   UDC-24  en vanlig omalad innehallsrad blir inte automatiskt kandidat
//   UDC-25  fler kandidater kan aldrig sanka recall
//   UDC-26  Tier 1-medlemskap ar oberoende av prioriteringspoangen
//   UDC-27  varje deklarerad kontroll ar aterupptackt eller INFORMATION_LIMIT
//   UDC-28  tvetydiga agare ligger kvar i explicit bokforing
//   UDC-29  R-02-utfallet paverkar aldrig medlemskapet
//   UDC-30  semantisk UNKNOWN presenteras inte som antal kontroller

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { upptack, aterupptack, mekanismerFor, prioritet, arDeklarerad, PREDIKAT, UNION,
  MEKANISM, MATT, TRAFFYTA_MIN } from './control-shape-discovery.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });
const rot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const MOD = readFileSync(join(rot, 'tools', 'control-shape-discovery.mjs'), 'utf8');
const KOD = MOD.replace(/^\s*\/\/.*$/gm, '');   // kod utan kommentarer

/* Byggstenar. KROPP ar en malad textkropp; varje prov andrar exakt en sak. */
const KROPP = { harFyllning: true, helRam: false, malar: true, egenTextLangd: 6,
  inreMalande: 0, svgAntal: 0, display: 'flex', align: 'center', w: 155, h: 48,
  tagg: 'div', roll: null, forfaderRoll: null, iSvg: false, komponent: null,
  piller: false, harKnopp: false, fil: 'prov.html' };
const o = (art, ordinal, extra = {}) => ({ art, ordinal, ...KROPP, ...extra });

/* ── UDC-01 ─────────────────────────────────────────────────────────*/
{ const r = upptack([ o('D', 11, { harFyllning: false, helRam: true }), o('D', 12) ]);
  prov('UDC-01', 'ett verkligt odeklarerat knappobjekt upptacks',
    r.nya_st === 2, r.nya_st + ' kandidater: ' + r.nya.map(x => x.identitet).join(', ')); }

/* ── UDC-02 · upptackten ar inte tom ────────────────────────────────*/
{ // Ett objekt utan nagon av formerna: omalat, ingen text, ingen glyf, block.
  const tomt = o('P', 5, { malar: false, harFyllning: false, helRam: false,
    egenTextLangd: 0, display: 'block', align: 'normal' });
  const r = upptack([tomt, o('P', 6)]);
  prov('UDC-02', 'upptackten skiljer pa objekt med och utan kontrollform',
    mekanismerFor(tomt).length === 0 && r.nya_st === 1 && r.nya[0].identitet === 'P|6',
    'objektet utan form gav ' + mekanismerFor(tomt).length + ' mekanismer; kandidater: ' +
      r.nya.map(x => x.identitet).join(',')); }

/* ── UDC-03 ─────────────────────────────────────────────────────────*/
{ const r = upptack([ o('D', 12) ]); const k = r.nya[0];
  prov('UDC-03', 'upptackt ger kandidat, aldrig verdikt eller roll',
    k.verdikt === null && k.roll === null && Array.isArray(k.mekanismer),
    'verdikt ' + k.verdikt + ', roll ' + k.roll + ', mekanismer ' + JSON.stringify(k.mekanismer)); }

/* ── UDC-04 ─────────────────────────────────────────────────────────*/
{ const r = upptack([ o('D', 12, { roll: 'button' }), o('D', 13, { forfaderRoll: 'button' }),
    o('D', 14) ]);
  prov('UDC-04', 'ett redan deklarerat objekt ligger inte kvar i den odeklarerade listan',
    r.nya_st === 1 && r.nya[0].identitet === 'D|14' &&
    r.deklareradeMedKontrollform_st === 2,
    'kvar: ' + r.nya.map(x => x.identitet).join(',') + '; deklarerade med formen: ' +
      r.deklareradeMedKontrollform_st); }

/* ── UDC-05 ─────────────────────────────────────────────────────────*/
{ const r = upptack([ o('R', 20, { w: 364 }), o('R', 21, { w: 364 }) ], new Set(['R|20']));
  prov('UDC-05', 'radagare och visuellt barn med samma box ger inte tva kandidater',
    r.nya_st === 0 && r.redanKanda_st === 1 && r.tvetydigaAgare_st === 1 && r.invariant_ok,
    'tvetydiga: ' + JSON.stringify(r.tvetydigaAgare.map(x => x.identitet))); }

/* ── UDC-06 ─────────────────────────────────────────────────────────*/
{ const r = upptack([ o('A', 30, { w: 200, h: 60 }), o('A', 31, { w: 200, h: 60 }) ],
    new Set(['A|30']));
  prov('UDC-06', 'tvetydigt agarskap ger fail closed — ingen kandidat, en redovisad post',
    r.nya_st === 0 && r.tvetydigaAgare_st === 1 &&
    /gar inte att avgora/.test(r.tvetydigaAgare[0].skal) && r.invariant_ok,
    r.tvetydigaAgare[0].skal); }

/* ── UDC-07 ─────────────────────────────────────────────────────────*/
{ const bef = new Set(['X|1', 'X|2']);
  const r = upptack([ o('X', 1), o('X', 2, { w: 300, h: 70 }), o('X', 9, { w: 120, h: 90 }) ], bef);
  prov('UDC-07', 'befintliga stabila identiteter bevaras och aterupptacks aldrig som nya',
    r.redanKanda_st === 2 && r.nya_st === 1 && r.nya[0].identitet === 'X|9',
    'redan kanda ' + JSON.stringify(r.redanKanda) + ', nya X|9'); }

/* ── UDC-08 ─────────────────────────────────────────────────────────*/
{ const kryss = o('dialogsparameny', 8, { komponent: 'checkbox', harFyllning: false,
    helRam: true, malar: true, egenTextLangd: 0, display: 'block', align: 'normal',
    w: 24, h: 24 });
  const r = upptack([kryss, o('dialogsparameny', 11)], new Set(['dialogsparameny|8']));
  prov('UDC-08', 'dialogsparameny-kryssrutan forblir samma objekt, ingen dublett',
    r.redanKanda.includes('dialogsparameny|8') && r.nya_st === 1 &&
    r.nya[0].identitet === 'dialogsparameny|11',
    'redan kand: ' + JSON.stringify(r.redanKanda) + '; nya: ' +
      r.nya.map(x => x.identitet).join(',')); }

/* ── UDC-09 ─────────────────────────────────────────────────────────*/
{ const utan = upptack([ o('S', 11), o('S', 12) ]);
  const med = upptack([ o('S', 8, { roll: 'checkbox', komponent: 'checkbox', w: 24, h: 24 }),
    o('S', 11), o('S', 12) ]);
  const lika = JSON.stringify(utan.nya.map(x => [x.identitet, x.verdikt, x.roll])) ===
    JSON.stringify(med.nya.map(x => [x.identitet, x.verdikt, x.roll]));
  prov('UDC-09', 'en kand interaktiv kryssruta gor inte syskonen interaktiva',
    lika && med.nya.every(x => x.verdikt === null),
    'identiskt utfall med och utan deklarerad granne: ' + lika); }

/* ── UDC-10 ─────────────────────────────────────────────────────────*/
{ const a = upptack([ o('dialogsparameny', 12) ]), b = upptack([ o('nagonannan', 12) ]);
  const ingenSkarm = !/dialogsparameny|inkopmerge|kontovantan|delatlista/.test(KOD);
  prov('UDC-10', 'skarmkontext far utlosa granskning men aldrig verdikt',
    a.nya_st === b.nya_st && a.nya[0].verdikt === null && ingenSkarm,
    'samma utfall i bada artefakterna; ingen skarm-id i regelkoden: ' + ingenSkarm); }

/* ── UDC-11 · under 48 px kan anda upptackas ────────────────────────*/
{ const liten = o('K', 3, { w: 24, h: 24, egenTextLangd: 0, svgAntal: 0,
    display: 'block', align: 'normal' });      // malad naken kropp, 24x24
  const r = upptack([liten]);
  prov('UDC-11', 'en kontroll under 48 px kan anda upptackas som kandidat',
    r.nya_st === 1 && r.nya[0].w < TRAFFYTA_MIN && r.nya[0].h < TRAFFYTA_MIN &&
    r.nya[0].uppfyllerTraffytekontraktet === false,
    '24x24 blev kandidat; traffytekontraktet uppfyllt: ' +
      r.nya[0].uppfyllerTraffytekontraktet + ' — och det hindrade inte upptackten'); }

/* ── UDC-12 · traffytans utfall paverkar inte medlemskapet ──────────*/
{ // Samma struktur i tre storlekar. Alla tre ska bli kandidater.
  const r = upptack([ o('T', 1, { w: 155, h: 48 }), o('T', 2, { w: 155, h: 42 }),
    o('T', 3, { w: 30, h: 30 }) ]);
  const ingenTroskelIPredikat = !/\bw\s*>=\s*|\bh\s*>=\s*/.test(
    KOD.slice(KOD.indexOf('export const PREDIKAT'), KOD.indexOf('export const UNION')));
  prov('UDC-12', 'traffytans PASS eller FAIL paverkar inte medlemskapet',
    r.nya_st === 3 && ingenTroskelIPredikat &&
    JSON.stringify(r.nya.map(x => x.uppfyllerTraffytekontraktet)) === '[true,false,false]',
    '3 av 3 upptackta med traffyteutfall ' +
      JSON.stringify(r.nya.map(x => x.uppfyllerTraffytekontraktet)) +
      '; ingen storlekstroskel i predikaten: ' + ingenTroskelIPredikat); }

/* ── UDC-13 · deklarerad 42 px-struktur, virtuellt odeklarerad ──────*/
{ const kontroll = { art: 'F', roll: 'textbox', namn: 'Namn',
    agare: o('F', 6, { w: 314, h: 42, harFyllning: true, helRam: true, egenTextLangd: 17,
      display: 'flex', align: 'center' }),
    attkomlingar: [] };
  const r = aterupptack(kontroll);
  prov('UDC-13', 'en deklarerad 42 px-struktur ar upptackbar nar den virtuellt odeklareras',
    r.agarAvstambar && r.strikt && r.via === 'agaren',
    '42 px hog textfaltsstruktur aterupptacks via ' + r.mekanism + ' pa ' + r.via); }

/* ── UDC-14 · recall mats utan semantiskt verdikt ───────────────────*/
{ // aterupptack far bara se struktur. Samma agare med och utan roll/namn/state
  // ska ge identiskt resultat.
  const bas = { agare: o('G', 4), attkomlingar: [] };
  const medVerdikt = { roll: 'button', namn: 'Spara', state: 'x', verdikt: 'INTERACTIVE_CONTROL',
    agare: o('G', 4), attkomlingar: [] };
  const a = aterupptack(bas), b = aterupptack(medVerdikt);
  prov('UDC-14', 'recall mats utan att kontrollens semantiska verdikt anvands som evidens',
    JSON.stringify(a) === JSON.stringify(b) &&
    !/verdikt|INTERACTIVE_CONTROL|data-a11y/.test(
      KOD.slice(KOD.indexOf('export function aterupptack'), KOD.indexOf('export function upptack'))),
    'identiskt resultat med och utan verdikt, och aterupptack laser inget verdikt'); }

/* ── UDC-15 · oadjudicerad kandidat ar inte falsk positiv ───────────*/
{ const r = upptack([ o('H', 1), o('H', 2) ]);
  const ingaFalskaPositiva = !/falsk|precision|traffsakerhet/i.test(JSON.stringify(r));
  prov('UDC-15', 'en oadjudicerad kandidat raknas inte som falsk positiv',
    r.nya.every(x => x.verdikt === null) && ingaFalskaPositiva &&
    !Object.keys(r).some(k => /precision|falsk/i.test(k)),
    'kandidaterna saknar verdikt och rapporten innehaller inget precisionsbegrepp'); }

/* ── UDC-16 · regelval far inte optimera pa pseudo-precision ────────*/
{ const ingenPrecision = !/declared\s*\/\s*\(|precision|traffsakerhet/i.test(KOD);
  const namnerRecall = /recall/i.test(MOD);
  prov('UDC-16', 'regelval far inte optimera pa declared/(declared+undeclared)',
    ingenPrecision && namnerRecall,
    'ingen precisionskvot i koden: ' + ingenPrecision +
      '; modulen motiverar valet med recall: ' + namnerRecall); }

/* ── UDC-17 · varje miss far exakt en primar gap-orsak ──────────────*/
{ const A = JSON.parse(readFileSync(join(rot, 'fas2', 'upptacktsslutning.json'), 'utf8'));
  prov('UDC-17', 'varje missad deklarerad kontroll far exakt en primar gap-orsak',
    A.F_recall.missade === 0 && A.E_informationLimit.antal === 0 &&
    A.D_perKontroll.every(x => x.nuAterupptackt && typeof x.mekanism === 'string'),
    'noll kvarvarande missar; alla ' + A.D_perKontroll.length +
    ' tidigare missar har en namngiven mekanism'); }

/* ── UDC-18 · unionen har inga tysta missar ─────────────────────────*/
{ const A = JSON.parse(readFileSync(join(rot, 'fas2', 'upptacktsslutning.json'), 'utf8'));
  const t = A.F_recall;
  prov('UDC-18', 'detektorunionen har inga tysta missade deklarerade kontroller',
    t.deklarerade === t.aterupptackta + t.informationLimit && t.missade === 0,
    t.deklarerade + ' = ' + t.aterupptackta + ' aterupptackta + ' + t.informationLimit +
      ' informationsgranser'); }

/* ── UDC-19 · kandidatens agare stams av ────────────────────────────*/
{ // En traff pa ETT entydigt barn stams av till agaren. Tva likadana barn gor
  // agarvalet tvetydigt och far inte raknas som aterupptackt.
  const ettBarn = { agare: o('I', 1, { malar: false, harFyllning: false, helRam: false,
      egenTextLangd: 0, display: 'block', align: 'normal' }),
    attkomlingar: [ o('I', 2) ] };
  const tvaBarn = { agare: o('J', 1, { malar: false, harFyllning: false, helRam: false,
      egenTextLangd: 0, display: 'block', align: 'normal' }),
    attkomlingar: [ o('J', 2), o('J', 3) ] };
  const a = aterupptack(ettBarn), b = aterupptack(tvaBarn);
  prov('UDC-19', 'kandidatens agare maste stammas av mot samma semantiska agare',
    a.agarAvstambar && a.kandidatOrdinal === 2 && a.via === 'entydig attkomling' &&
    !b.agarAvstambar && b.kandidatOrdinal === null,
    'ett entydigt barn → avstambar via ordinal ' + a.kandidatOrdinal +
      '; tva likadana barn → avstambar ' + b.agarAvstambar); }

/* ── UDC-20 · borttagna trosklar andrar inte verdikt ────────────────*/
{ const A = JSON.parse(readFileSync(join(rot, 'fas2', 'upptacktsslutning.json'), 'utf8'));
  prov('UDC-20', 'borttagna konformitetstrosklar okar kandidater men andrar inga verdikt',
    A.L_raPopulation.nya > 0 && A.L_raPopulation.forloradeIdentiteter === 0 &&
    A.O_dialogsparameny.namnfalt.verdikt === 'UNKNOWN — OFORANDRAT',
    A.L_raPopulation.nya + ' nya kandidater, 0 tappade identiteter, namnfaltets verdikt ' +
      A.O_dialogsparameny.namnfalt.verdikt); }

/* -- UDC-21 - nastlad malad form blockerar inte agarupptackt --------*/
{ // Matkortet: malad kortyta, egen text, en nastlad bricka inuti.
  const kort = o('V', 22, { w: 126, h: 86, inreMalande: 1, svgAntal: 1, egenTextLangd: 9 });
  const m = mekanismerFor(kort);
  prov('UDC-21', 'nastlad malad form blockerar inte agarupptackt',
    m.includes('PAINTED_TEXT_BODY') && upptack([kort]).nya_st === 1,
    'malad agare med en nastlad form och egen text -> ' + JSON.stringify(m)); }

/* -- UDC-22 - nastlad form gor inte foraldern till kandidat ---------*/
{ // En sektionsbehallare: malar en yta, men all text ligger INUTI de nastlade
  // malade korten. Agaren har darfor ingen EGEN text och far inte bli kandidat.
  const sektion = o('V', 1, { w: 380, h: 400, inreMalande: 6, egenTextLangd: 0,
    svgAntal: 2, display: 'block', align: 'normal' });
  const m = mekanismerFor(sektion);
  prov('UDC-22', 'nastlad malad form gor inte foraldern till kandidat automatiskt',
    m.length === 0 && upptack([sektion]).nya_st === 0,
    'malad behallare utan egen text och med sex nastlade former -> ' +
      JSON.stringify(m) + ' mekanismer'); }

/* -- UDC-23 - omalad atgardsagare utan centrering -------------------*/
{ const rad = o('W', 28, { malar: false, harFyllning: false, helRam: false,
    w: 294, h: 56, align: 'normal', egenTextLangd: 32 });
  const ikon = o('W', 15, { malar: false, harFyllning: false, helRam: false,
    w: 412, h: 64, align: 'flex-start', egenTextLangd: 0, svgAntal: 1 });
  const r = upptack([rad, ikon]);
  prov('UDC-23', 'en omalad atgardsagare upptacks utan krav pa centrering',
    r.nya_st === 2 && mekanismerFor(rad).includes('CONTROL_SHELL') &&
    mekanismerFor(ikon).includes('CONTROL_SHELL'),
    'align normal och flex-start bada upptackta: ' + r.nya_st + ' av 2'); }

/* -- UDC-24 - vanlig omalad innehallsrad blir inte kandidat ---------*/
{ // En brodtextrad: blocklayout, ingen malning, ingen glyf. Inte en kandidat.
  const brodtext = o('W', 40, { malar: false, harFyllning: false, helRam: false,
    display: 'block', align: 'normal', egenTextLangd: 120, w: 364, h: 60 });
  // En flexrad vars innehall ar nastlade MALADE kort - inte heller kandidat.
  const kortrad = o('W', 41, { malar: false, harFyllning: false, helRam: false,
    display: 'flex', align: 'center', egenTextLangd: 0, svgAntal: 0,
    inreMalande: 3, w: 364, h: 120 });
  const r = upptack([brodtext, kortrad]);
  prov('UDC-24', 'en vanlig omalad innehallsrad blir inte automatiskt kandidat',
    r.nya_st === 0 && mekanismerFor(brodtext).length === 0 &&
    mekanismerFor(kortrad).length === 0,
    'brodtext ' + JSON.stringify(mekanismerFor(brodtext)) + ', kortrad ' +
      JSON.stringify(mekanismerFor(kortrad))); }

/* -- UDC-25 - fler kandidater kan aldrig sanka recall ---------------*/
{ // Unionen ar monoton: att lagga till en mekanism kan bara oka recall.
  const kontroller = [
    { agare: o('M', 1), attkomlingar: [] },
    { agare: o('M', 2, { malar: false, harFyllning: false, helRam: false,
        align: 'flex-start', egenTextLangd: 12 }), attkomlingar: [] },
    { agare: o('M', 3, { komponent: 'checkbox', display: 'block', align: 'normal',
        egenTextLangd: 0, malar: false, harFyllning: false }), attkomlingar: [] } ];
  const smal = ['AUTHORED_COMPONENT'];
  const bred = UNION;
  const rSmal = kontroller.filter(k => aterupptack(k, smal).agarAvstambar).length;
  const rBred = kontroller.filter(k => aterupptack(k, bred).agarAvstambar).length;
  const volSmal = upptack(kontroller.map(k => k.agare), new Set(), smal).nya_st;
  const volBred = upptack(kontroller.map(k => k.agare), new Set(), bred).nya_st;
  prov('UDC-25', 'fler kandidater kan aldrig sanka recall',
    rBred >= rSmal && volBred >= volSmal && rBred === 3 && rSmal === 1,
    'recall ' + rSmal + ' -> ' + rBred + ' nar volymen gick ' + volSmal + ' -> ' + volBred); }

/* -- UDC-26 - Tier 1 ar oberoende av prioriteringspoangen -----------*/
{ const lag = o('N', 1, { w: 20, h: 20, egenTextLangd: 0, malar: true, harFyllning: true,
    svgAntal: 0, inreMalande: 0 });
  const hog = o('N', 2, { w: 200, h: 60, komponent: 'checkbox', egenTextLangd: 10 });
  const pl = prioritet(lag), ph = prioritet(hog);
  const r = upptack([lag, hog]);
  prov('UDC-26', 'Tier 1-medlemskap ar oberoende av prioriteringspoangen',
    r.nya_st === 2 && pl.poang < ph.poang &&
    /paverkar inte Tier 1-medlemskap/.test(pl.$regel),
    'poang ' + pl.poang + ' och ' + ph.poang + ' - bada ar kandidater'); }

/* -- UDC-27 - aterupptackt eller INFORMATION_LIMIT ------------------*/
{ const A = JSON.parse(readFileSync(join(rot, 'fas2', 'upptacktsslutning.json'), 'utf8'));
  const t = A.F_recall;
  prov('UDC-27', 'varje deklarerad kontroll ar aterupptackt eller explicit INFORMATION_LIMIT',
    t.deklarerade === t.aterupptackta + t.informationLimit && t.missade === 0 &&
    Object.values(A.G_perRoll).every(r => r.missade === 0),
    t.deklarerade + ' = ' + t.aterupptackta + ' + ' + t.informationLimit +
      '; alla roller pa 100 %'); }

/* -- UDC-28 - tvetydiga agare ligger kvar i bokforingen -------------*/
{ const A = JSON.parse(readFileSync(join(rot, 'fas2', 'upptacktsslutning.json'), 'utf8'));
  const k = A.K_tvetydigaAgare;
  const r = upptack([ o('A', 30, { w: 200, h: 60 }), o('A', 31, { w: 200, h: 60 }) ],
    new Set(['A|30']));
  prov('UDC-28', 'tvetydiga agare ligger kvar i explicit bokforing',
    k.antal === A.M_N_matt.DISCOVERY_AMBIGUOUS_OWNER.efter && k.poster.length === k.antal &&
    k.poster.every(x => x.konkurrerandeAgare && x.behovs) &&
    r.tvetydigaAgare[0].behovs.length > 0,
    k.antal + ' tvetydiga, alla med konkurrerande agare och angivet saknat bevis'); }

/* -- UDC-29 - R-02-utfallet paverkar aldrig medlemskapet ------------*/
{ const A = JSON.parse(readFileSync(join(rot, 'fas2', 'upptacktsslutning.json'), 'utf8'));
  const i = A.I_konformitetsoberoende;
  prov('UDC-29', 'R-02-utfallet paverkar aldrig medlemskapet',
    i.sammaBeslutForAllaStorlekar && i.ingenStorlekIPredikaten &&
    new Set(i.storlekar.map(s => JSON.stringify(s.mekanismer))).size === 1 &&
    new Set(i.storlekar.map(s => s.uppfyllerTraffyta)).size === 2,
    'fyra storlekar med tva olika traffyteutfall gav ett och samma upptacktsbeslut'); }

/* -- UDC-30 - UNKNOWN presenteras inte som antal kontroller ---------*/
{ const A = JSON.parse(readFileSync(join(rot, 'fas2', 'upptacktsslutning.json'), 'utf8'));
  const m = A.M_N_matt;
  const tre = ['RAW_DISCOVERY_CANDIDATES', 'ADJUDICATION_UNRESOLVED', 'DISCOVERY_AMBIGUOUS_OWNER']
    .every(k => m[k] && typeof m[k].definition === 'string');
  prov('UDC-30', 'semantisk UNKNOWN presenteras inte som antal kontroller',
    tre && /aldrig|inte/.test(m.$varning) && /backlogtal/.test(m.$historik) &&
    // Varningen ska uttryckligen FORNEKA att talen ar ett antal kontroller.
    /uppskattning/.test(MATT.$varning) && /kontroller/.test(MATT.$varning),
    'tre atskilda matt med egna definitioner, plus explicit varning och historiknot'); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('UPPTACKTSPROV status=' + (ok === resultat.length ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + resultat.length);
writeFileSync(join(outAbs, 'udcprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === resultat.length ? 0 : 1);
