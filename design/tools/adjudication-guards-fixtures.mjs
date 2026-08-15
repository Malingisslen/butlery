#!/usr/bin/env node
// F2 · BESTANDIGA PROV FOR ADJUDIKERINGENS BOKFORINGSREGLER.
//
// Kör: node tools/adjudication-guards-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN DESSA PROV FINNS FOR
// En adjudikering ar bara vard nagot om den inte kan smyga in en klassificering
// via en signal som aldrig var evidens, och om ett semantiskt svar inte kan
// forvaxlas med en uppmatt produktegenskap. Femton egenskaper lases har:
//
//   PR-01  grannkontroll ensam ger aldrig INTERACTIVE_CONTROL
//   PR-02  hog korpusfrekvens ensam ger aldrig INTERACTIVE_CONTROL
//   PR-03  komponenttypens namn ensamt ger aldrig INTERACTIVE_CONTROL
//   PR-04  saknad kontrollmetadata ger aldrig NON_INTERACTIVE_STATE_GRAPHIC
//   PR-05  saknad semantik ger aldrig DECORATIVE_GRAPHIC
//   PR-06  motstridig evidens overlever som UNKNOWN
//   PR-07  ett avgjort verdikt tar inte bort kallkandidaten ur detektorn
//   PR-08  semantiskt upptackta kontroller raknas inte som R-02-verifierade
//   PR-09  framtida agarskap muterar inte nuvarande icke-textpopulationer
//   PR-10  de utanfor omfanget far inga verdiktandringar
//   PR-11  populationen harleds ur persisterad kalla, inte ur en totalsiffra
//   PR-12  hojd prioritet fran en ny likadan comparator andrar inget verdikt
//   PR-13  en ny comparator starker evidens bara via redovisade matchningar
//   PR-14  prioritetsdelta muterar aldrig ra medlemskap eller verdikt
//   PR-15  en comparator ur en adjudicerad kontroll bootstrappar inte likande kandidater
//
// PR-01..PR-06 och PR-12..PR-15 provas mot detektorn sjalv, med syntetiska
// fall. PR-07..PR-11 provas mot adjudikeringens faktiska bokforing i
// fas2/prioriterade-kandidater.json, fas2/p0r-lineage.json och
// fas2/prioritetsdelta-adjudicering.json — de ar bokforingsregler, inte
// kodregler, och maste darfor lasas mot det som faktiskt redovisades.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { svep, VERDIKT } from './undeclared-components.mjs';

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
const A = JSON.parse(readFileSync(join(rot, 'fas2', 'prioriterade-kandidater.json'), 'utf8'));

/* Byggstenar. KRAV5 uppfyller samtliga fem evidenskrav; varje prov tar bort
 * exakt en sak, sa att det som provas ar just den saknade biten.            */
const KRAV5 = { komponent: 'kryss', etikett: 'Synlig etikett',
  signatur: 'div|flex|TEXT+KOMPONENT', tillstandsstruktur: { typ: 'FYLLD_MED_IKON' },
  sektion: 'Installningar' };
const deklarerad = (art, ordinal, roll, extra = {}) => ({ art, ordinal,
  ...KRAV5, ...extra, agare: { roll }, deklarerad: true });
const kandidat = (art, ordinal, extra = {}) => ({ art, ordinal,
  ...KRAV5, ...extra, deklarerad: false });

/* ── PR-01 · grannkontroll ensam ────────────────────────────────────*/
{ // Kandidaten har MAXIMAL grannsignal: tre syskonrader ar deklarerade
  // kontroller och samma typ ar deklarerad i skarmen. Men den saknar ett
  // evidenskrav. Den far inte bli kontroll, och grannskapet far inte namnas
  // som skal for verdiktet — bara som prioritering.
  const poster = [ deklarerad('N', 1, 'checkbox'), deklarerad('N', 2, 'checkbox'),
    deklarerad('N', 3, 'checkbox'),
    kandidat('N', 9, { sektion: null, syskonKontroller: 3, sammaTypDeklareradISkarmen: 3 }) ];
  const r = svep(poster);
  const k = r.kandidater[0];
  const grannskalIsolerat = k.skal.some(s => /hojer prioritet, avgor inte verdikt/.test(s));
  prov('PR-01', 'grannkontroll ensam ger aldrig INTERACTIVE_CONTROL',
    k.verdikt === VERDIKT.UNKNOWN && k.prioritet > 0 && grannskalIsolerat,
    'tre deklarerade syskon och typen deklarerad i skarmen → ' + k.verdikt +
      ', prioritet ' + k.prioritet + '; grannskapet redovisas uttryckligen som prioritering'); }

/* ── PR-02 · hog korpusfrekvens ensam ───────────────────────────────*/
{ const poster = [ ...Array.from({ length: 19 }, (_, i) => deklarerad('F', 10 + i, 'checkbox')),
    kandidat('F', 99, { sektion: null }) ];
  const r = svep(poster);
  const k = r.kandidater[0];
  const grad = r.konvention.find(c => c.komponent === 'kryss').grad;
  prov('PR-02', 'hog korpusfrekvens ensam ger aldrig INTERACTIVE_CONTROL',
    grad === 0.95 && k.verdikt === VERDIKT.UNKNOWN && !k.skal.some(s => /troskel/i.test(s)),
    'deklarationsgrad ' + grad + ' → ' + k.verdikt + '; ingen troskel i skalen'); }

/* ── PR-03 · komponenttypens namn ensamt ────────────────────────────*/
{ // Enda evidensen ar att elementet bar data-component="checkbox". Ingen
  // etikett, ingen radform, ingen sektion, inget deklarerat exempel.
  const r = svep([ kandidat('T', 5, { etikett: null, signatur: null,
    tillstandsstruktur: null, sektion: null }) ]);
  const k = r.kandidater[0];
  prov('PR-03', 'komponenttypens namn ensamt ger aldrig INTERACTIVE_CONTROL',
    k.verdikt === VERDIKT.UNKNOWN && k.uppfylldaKrav.length === 1 &&
    k.uppfylldaKrav[0] === 'AUTHORED_KOMPONENTTYP',
    'enda uppfyllda kravet ar ' + k.uppfylldaKrav.join(',') + ' → ' + k.verdikt); }

/* ── PR-04 · saknad kontrollmetadata ────────────────────────────────*/
{ // Kandidaten saknar all a11y-metadata. Det far inte i sig gora den till
  // icke-interaktiv tillstandsgrafik.
  const r = svep([ kandidat('M', 7, { sektion: null }) ]);
  const k = r.kandidater[0];
  prov('PR-04', 'saknad kontrollmetadata ger aldrig NON_INTERACTIVE_STATE_GRAPHIC',
    k.verdikt === VERDIKT.UNKNOWN && r.rakn[VERDIKT.NON_INTERACTIVE_STATE_GRAPHIC] === 0 &&
    k.skal.some(s => /ingen positiv evidens for icke-interaktiv/.test(s)),
    'ingen a11y-metadata → ' + k.verdikt + ', tillstandsgrafik ' +
      r.rakn[VERDIKT.NON_INTERACTIVE_STATE_GRAPHIC]); }

/* ── PR-05 · saknad semantik ────────────────────────────────────────*/
{ const r = svep([ kandidat('D', 3, { etikett: null, signatur: null,
    tillstandsstruktur: null, sektion: null }) ]);
  const k = r.kandidater[0];
  prov('PR-05', 'saknad semantik ger aldrig DECORATIVE_GRAPHIC',
    k.verdikt === VERDIKT.UNKNOWN && r.rakn[VERDIKT.DECORATIVE_GRAPHIC] === 0 &&
    k.skal.some(s => /eller dekoration/.test(s)),
    'ingen semantik alls → ' + k.verdikt + ', dekorativ ' + r.rakn[VERDIKT.DECORATIVE_GRAPHIC]); }

/* ── PR-06 · motstridig evidens ─────────────────────────────────────*/
{ // Kandidaten uppfyller allt UTOM att evidensen sager emot sig sjalv: samma
  // struktur ar deklarerad bade som checkbox och som switch i korpusen. Da
  // levererar exemplet ingen entydig roll. Kandidaten far inte doljas som
  // kontroll med en hopslagen roll, och inte heller doljas som tillstandsgrafik.
  const poster = [ deklarerad('C', 1, 'checkbox'), deklarerad('C', 2, 'switch'),
    kandidat('C', 8, { syskonKontroller: 2 }) ];
  const r = svep(poster);
  const k = r.kandidater.find(x => x.ordinal === 8);
  const enrollig = svep([ deklarerad('E', 1, 'checkbox'), deklarerad('E', 2, 'checkbox'),
    kandidat('E', 8) ]).kandidater[0];
  prov('PR-06', 'motstridig evidens overlever som UNKNOWN',
    !!k && k.verdikt === VERDIKT.UNKNOWN && k.kontrolltyp === undefined &&
    k.saknadeKrav.includes('DEKLARERAT_EXEMPEL') &&
    k.skal.some(s => /motstridig evidens/.test(s)) &&
    // Kontrollprov: med EN entydig roll blir exakt samma kandidat en kontroll.
    // Det ar alltsa rollmotstridigheten som bar utfallet, inget annat.
    enrollig.verdikt === VERDIKT.INTERACTIVE_CONTROL && enrollig.kontrolltyp === 'checkbox',
    k ? 'samma struktur deklarerad som checkbox OCH switch → ' + k.verdikt +
      '; med en entydig roll blir samma kandidat ' + enrollig.verdikt +
      ' (' + enrollig.kontrolltyp + ')' : 'kandidaten saknas'); }

/* ── PR-07 · avgjort verdikt tar inte bort kallkandidaten ───────────*/
{ const f = A.P6_avstamning;
  prov('PR-07', 'ett avgjort verdikt tar inte bort kallkandidaten ur detektorn',
    f.raInventeringFore === f.raInventeringEfter && f.raInventeringEfter === 108 &&
    f.produktskrivningar === 0,
    'ra inventering ' + f.raInventeringFore + ' → ' + f.raInventeringEfter +
      ' vid ' + f.produktskrivningar + ' produktskrivningar, trots ' +
      f.avgjorda + ' avgjorda verdikt'); }

/* ── PR-08 · semantiskt upptackta ar inte R-02-verifierade ──────────*/
{ const p = A.P3_populationer;
  prov('PR-08', 'semantiskt upptackta kontroller raknas inte som R-02-verifierade',
    p.deklareradeMatbara === 1346 && p.historisktVerifierade === 1344 &&
    p.semantisktUpptackta === 1346 + A.P2_verdikt.INTERACTIVE_CONTROL &&
    p.semantisktUpptackta !== p.deklareradeMatbara &&
    A.P4_prospektivR02.every(x => x.r02 === 'UNKNOWN'),
    'deklarerade ' + p.deklareradeMatbara + ' · historiska ' + p.historisktVerifierade +
      ' · semantiskt upptackta ' + p.semantisktUpptackta +
      ' · prospektiv R-02 for samtliga nya: ' +
      [...new Set(A.P4_prospektivR02.map(x => x.r02))].join(',')); }

/* ── PR-09 · framtida agarskap muterar inte nuvarande populationer ──*/
{ const b = A.R_frysta;
  prov('PR-09', 'framtida agarskap muterar inte nuvarande icke-textpopulationer',
    b.kontrollIckeTextFynd.fore === b.kontrollIckeTextFynd.efter &&
    b.grafiskaDelar.fore === b.grafiskaDelar.efter &&
    b.fristaendeRequired.fore === b.fristaendeRequired.efter &&
    A.P5_prospektivtAgarskap.every(x => x.agarskapFlyttat === false),
    'grafiska delar ' + b.grafiskaDelar.fore + ' → ' + b.grafiskaDelar.efter +
      ', kontrollfynd ' + b.kontrollIckeTextFynd.fore + ' → ' + b.kontrollIckeTextFynd.efter +
      ', flyttat agarskap i ' + A.P5_prospektivtAgarskap.filter(x => x.agarskapFlyttat).length +
      ' av ' + A.P5_prospektivtAgarskap.length + ' fall'); }

/* ── PR-10 · de utanfor omfanget ar ororda ──────────────────────────*/
{ const f = A.P6_avstamning;
  prov('PR-10', 'de utanfor omfanget far inga verdiktandringar',
    f.utanforOmfang === 87 && f.utanforOmfangVerdiktandringar === 0 &&
    f.adjudicerade === 21 && f.adjudicerade + f.utanforOmfang === f.raInventeringEfter,
    f.utanforOmfang + ' utanfor omfanget med ' + f.utanforOmfangVerdiktandringar +
      ' verdiktandringar; ' + f.adjudicerade + ' + ' + f.utanforOmfang + ' = ' +
      f.raInventeringEfter); }

/* ── PR-11 · populationen harleds ur kallan, aldrig ur en totalsiffra ──
 *
 * FELET DETTA PROV FINNS FOR
 * I cbee18d valdes predikatet for "prioriterad" genom att prova sex kandidater
 * och behalla den som gav 21. Att ett predikat rakar reproducera en forvantad
 * totalsiffra ar ingen harledning — det ar en efterhandsanpassning, och den
 * hade lika garna kunnat landa i fel population. Medlemskapet ska komma ur den
 * persisterade listan och predikatet ur koden vid samma commit.
 */
{ const L = JSON.parse(readFileSync(join(rot, 'fas2', 'p0r-lineage.json'), 'utf8'));
  const hist = L.B_historisktMedlemskap, nu = L.C_nuvarandeMedlemskap;
  const perId = L.D_rekonciliering.spar;
  prov('PR-11', 'populationen harleds ur persisterad kalla, inte ur en matchande totalsiffra',
    L.A_kalla.kategori.startsWith('A') && !!L.A_kalla.commit &&
    /prioritet > 0/.test(L.A_kalla.predikatSomGavMedlemskapet) &&
    hist.antal === nu.antal && hist.fingeravtryck === nu.fingeravtryck &&
    L.F_setjamforelse.identiska &&
    L.F_setjamforelse.baraHistoriska.length === 0 && L.F_setjamforelse.baraCbee18d.length === 0 &&
    perId.length === hist.antal && perId.every(s => s.gammalId && s.kategori),
    'kalla ' + L.A_kalla.commit + ' · ' + L.A_kalla.falt + ' · predikat "' +
      L.A_kalla.predikatSomGavMedlemskapet + '" · fingeravtryck ' + hist.fingeravtryck +
      ' = ' + nu.fingeravtryck + ' · ' + perId.length + ' av ' + hist.antal +
      ' med explicit gammal→ny-spar'); }

/* ── PR-12..PR-15 · ATERKOPPLINGSSLINGAN ───────────────────────────────
 *
 * FELKLASSEN DESSA PROV FINNS FOR
 * En produktdeklaration skapar en ny comparator, och den comparatorn hojer
 * detektorns prioritet for kandidater med samma struktur. Det ar legitimt som
 * upptackt och kolegi — men om det ocksa fick andra verdikt skulle metoden
 * validera sig sjalv: en enda adjudicerad kontroll kunde da rekursivt dra in
 * varje visuellt likande kandidat i kontrollpopulationen utan att nagon ny
 * evidens om DE forekomsterna nagonsin lades fram.
 *
 * Provet kor samma korpus tva ganger. Enda skillnaden ar att en tidigare
 * kandidat blivit deklarerad kontroll — precis det som hande i 9929749.
 */
{ const KAND = { komponent: 'kryss', etikett: 'Synlig etikett',
    signatur: 'div|flex|KOMPONENT+TEXT', tillstandsstruktur: { typ: 'TOM_RAM' },
    sektion: null };                       // sektion saknas → aldrig fem av fem
  const rad = (art, ordinal, extra = {}) => ({ art, ordinal, ...KAND, ...extra, deklarerad: false });
  // FORE: tva likadana kandidater, ingen deklarerad comparator finns.
  const fore = svep([ rad('Z', 1), rad('Z', 2) ]);
  // EFTER: den forsta ar nu deklarerad kontroll. Den andra ar ORORD.
  const efter = svep([ { ...rad('Z', 1), agare: { roll: 'checkbox' }, deklarerad: true },
    rad('Z', 2) ]);
  const kF = fore.kandidater.find(k => k.ordinal === 2);
  const kE = efter.kandidater.find(k => k.ordinal === 2);
  const comparatorTillkom = !kF.evidens.DEKLARERAT_EXEMPEL && kE.evidens.DEKLARERAT_EXEMPEL;
  const prioritetenOkade = kE.prioritet > kF.prioritet;

  prov('PR-12', 'hojd prioritet fran en ny likadan comparator andrar inget verdikt',
    comparatorTillkom && prioritetenOkade && kF.verdikt === kE.verdikt &&
    kE.verdikt === VERDIKT.UNKNOWN,
    'ny comparator ' + comparatorTillkom + ', prioritet ' + kF.prioritet + '→' + kE.prioritet +
      ', verdikt ' + kF.verdikt + '→' + kE.verdikt);

  prov('PR-13', 'en ny comparator starker evidens bara via redovisade matchningar',
    kE.evidens.DEKLARERAT_EXEMPEL === true && kE.evidens.exempelroll === 'checkbox' &&
    Array.isArray(kE.evidens.exempel) && kE.evidens.exempel.length > 0 &&
    kE.saknadeKrav.includes('INSTALLNINGSKONTEXT'),
    'exemplet redovisas med roll ' + kE.evidens.exempelroll + ' och forekomst ' +
      JSON.stringify(kE.evidens.exempel) + '; kvarvarande saknade krav ' +
      JSON.stringify(kE.saknadeKrav));

  prov('PR-14', 'prioritetsdelta muterar aldrig ra medlemskap eller verdikt',
    fore.kandidater.length === 2 && efter.kandidater.length === 1 &&
    // Den enda som lamnade listan ar den som faktiskt blev DEKLARERAD, inte den
    // vars prioritet andrades.
    !efter.kandidater.some(k => k.ordinal === 1) &&
    efter.kandidater.some(k => k.ordinal === 2) &&
    Object.values(efter.rakn).reduce((x, y) => x + y, 0) === efter.kandidater.length,
    'kandidater ' + fore.kandidater.length + ' → ' + efter.kandidater.length +
      '; den som lamnade ar den deklarerade, den med hojd prioritet ligger kvar som ' + kE.verdikt);

  // PR-15: hela poangen — en kedja av deklarationer far inte lyfta in fler.
  // Har deklareras ANNU en, sa att comparatorn har tva exempel. Kandidat 3 ar
  // fortfarande UNKNOWN, for den saknar fortfarande sin egen evidens.
  const kedja = svep([ { ...rad('Z', 1), agare: { roll: 'checkbox' }, deklarerad: true },
    { ...rad('Z', 2), agare: { roll: 'checkbox' }, deklarerad: true }, rad('Z', 3) ]);
  const k3 = kedja.kandidater.find(k => k.ordinal === 3);
  prov('PR-15', 'en comparator ur en adjudicerad kontroll bootstrappar inte likande kandidater',
    kedja.kandidater.length === 1 && k3.verdikt === VERDIKT.UNKNOWN &&
    k3.evidens.exempelantal === 2 && kedja.rakn[VERDIKT.INTERACTIVE_CONTROL] === 0,
    'tva deklarerade exempel med identisk struktur → kandidat 3 ar fortfarande ' + k3.verdikt +
      '; kontroller skapade av kedjan: ' + kedja.rakn[VERDIKT.INTERACTIVE_CONTROL]); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('ADJUDIKERINGSPROV status=' + (ok === resultat.length ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + resultat.length);
writeFileSync(join(outAbs, 'prprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === resultat.length ? 0 : 1);
