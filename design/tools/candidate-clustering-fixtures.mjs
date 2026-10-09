#!/usr/bin/env node
// F2 · BESTANDIGA PROV FOR KANDIDATKLUSTRINGEN.
//
// Kör: node tools/candidate-clustering-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN DESSA PROV FINNS FOR
// En klustring som far rora vid semantiken slutar vara ett arbetsverktyg och
// blir en osynlig klassificerare: den kan sprida ett verdikt fran en comparator
// till hundra forekomster utan att nagon evidens om DEM lagts fram. Proven
// haller de tre lagren isar — struktur, granskningsgrupp och verdikt — och
// hindrar att klusteridentiteten byggs av nagot som redan ar ett svar.
//
//   CL-01  literal etikettext definierar inte klusteridentiteten
//   CL-02  absolut skarmposition definierar inte klusteridentiteten
//   CL-03  viewportbredd splittrar inte en annars identisk familj
//   CL-04  olika tillstandsbarare far splittra granskningspartitionen
//   CL-05  befintligt verdikt gar aldrig in i struktursignaturen
//   CL-06  prioritetspoang andrar aldrig medlemskap
//   CL-07  blandade kanda verdikt flaggas som heterogent
//   CL-08  flera comparatorroller bevaras som konflikt, aldrig majoritet
//   CL-09  varje olost kandidat ligger i exakt ett strukturkluster
//   CL-10  varje olost kandidat ligger i exakt en granskningspartition
//   CL-11  klusteridentiteten ar deterministisk over identiska korningar
//   CL-12  klustringen andrar noll semantiska verdikt
//   CL-13  samma indata och samma population ger bit-identisk klustring
//   CL-14  andrade semantiska verdikt ensamt kan inte andra medlemskap
//   CL-15  andrade comparatorroller ensamt kan inte andra medlemskap
//   CL-16  relativ ytklass bestams utan semantiska data
//   CL-17  syskonupprepningsklass bestams utan semantiska data
//   CL-18  historiska klusteridentiteter ar oforanderliga
//   CL-19  andrad medlemsmangd kraver en ny klusteridentitet
//   CL-20  shadowpopulationen stammer exakt 2684 = 2684
//   CL-21  den operativa populationen stammer exakt 2611 = 2611
//   CL-22  upprepning ensam kan inte innebara DECORATIVE
//   CL-23  de nya egenskaperna kan inte sprida ett semantiskt verdikt
//   CL-24  tva identiska fullkorningar ger identiskt medlemskap och ordning

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { struktursignatur, struktursignaturV2, signaturnyckel, partitionsnyckel,
  havstang, hash, formklass, texttopologi, tillstandsbarare, relativYtklass,
  syskonupprepningsklass, FORBJUDNA_NYCKLAR } from './candidate-clustering.mjs';

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
const MOD = readFileSync(join(rot, 'tools', 'candidate-clustering.mjs'), 'utf8');
const KOD = MOD.replace(/^\s*\/\/.*$/gm, '');
const A = JSON.parse(readFileSync(join(rot, 'fas2', 'kandidatklustring.json'), 'utf8'));

const BAS = { harFyllning: true, helRam: false, harOutline: false, malar: true,
  display: 'flex', align: 'center', flexRiktning: 'row', w: 364, h: 48,
  egenTextLangd: 12, textblock: 1, ikoner: [], inreMalande: 0, barnAntal: 1,
  komponent: null, piller: false, harKnopp: false, segmentgrupp: 0,
  maladeBarn: [], mekanismer: ['CONTROL_SHELL', 'PAINTED_TEXT_BODY'], art: 'A', ordinal: 1 };
const o = (extra = {}) => ({ ...BAS, ...extra });
const nyckel = x => signaturnyckel(struktursignatur(x));

/* ── CL-01 · literal etikettext ─────────────────────────────────────*/
{ // Tva objekt med olika etiketter men identisk struktur. Signaturen ar samma,
  // och ingen textstrang finns i den.
  const a = o({ egenText: 'Spara', etikett: 'Spara' });
  const b = o({ egenText: 'Ta bort allt for alltid', etikett: 'Ta bort allt for alltid' });
  // Signaturen far lasa OM det finns egen text — en boolean ur egenTextLangd —
  // men aldrig sjalva strangen. Provet letar darfor efter faktiska
  // textlasningar, inte efter faltnamnet.
  const sigKod = KOD.slice(KOD.indexOf('export function struktursignatur'),
    KOD.indexOf('export const signaturnyckel'));
  const ingenTextIKod = !/textContent|innerText|o\.egenText\b|o\.etikett|o\.namn/.test(sigKod);
  prov('CL-01', 'literal etikettext definierar inte klusteridentiteten',
    nyckel(a) === nyckel(b) && ingenTextIKod &&
    !/Spara|Ta bort/.test(nyckel(a)),
    'olika etiketter, samma signatur; signaturen innehaller ingen textstrang'); }

/* ── CL-02 · absolut position ───────────────────────────────────────*/
{ const a = o({ x: 0, y: 0, art: 'skarmA' });
  const b = o({ x: 812, y: 4300, art: 'skarmB' });
  prov('CL-02', 'absolut skarmposition definierar inte klusteridentiteten',
    nyckel(a) === nyckel(b) && !/x=|y=|skarm/.test(nyckel(a)),
    'olika lage och olika skarm, samma signatur'); }

/* ── CL-03 · viewportbredd ──────────────────────────────────────────*/
{ // Samma komponentfamilj i 320 och 364 px. Far inte bli tva familjer.
  const smal = o({ w: 320, h: 48 });
  const bred = o({ w: 364, h: 48 });
  prov('CL-03', 'viewportbredd splittrar inte en annars identisk familj',
    nyckel(smal) === nyckel(bred) && formklass(320, 48) === formklass(364, 48) &&
    !/w=|h=|364|320/.test(nyckel(smal)),
    '320 och 364 px ger samma formklass "' + formklass(364, 48) + '" och samma signatur'); }

/* ── CL-04 · tillstandsbarare far splittra partitionen ──────────────*/
{ // Samma agarform, men den ena har en bock och den andra en tom ruta.
  const medBock = o({ komponent: 'checkbox', ikoner: ['check'] });
  const tom = o({ komponent: 'checkbox', ikoner: [] });
  const p1 = partitionsnyckel(medBock), p2 = partitionsnyckel(tom);
  prov('CL-04', 'olika tillstandsbarare far splittra granskningspartitionen',
    p1 !== p2 && tillstandsbarare(medBock) === 'bock' && tillstandsbarare(tom) === 'tom-ruta',
    'bock mot tom ruta ger olika partition: ' + tillstandsbarare(medBock) + ' / ' +
      tillstandsbarare(tom)); }

/* ── CL-05 · verdikt gar aldrig in i signaturen ─────────────────────*/
{ const utan = o();
  const med = o({ verdikt: 'INTERACTIVE_CONTROL', roll: 'button', namn: 'Spara',
    prioritet: 9 });
  const sigKod = KOD.slice(KOD.indexOf('export function struktursignatur'),
    KOD.indexOf('export const signaturnyckel'));
  prov('CL-05', 'befintligt verdikt gar aldrig in i struktursignaturen',
    nyckel(utan) === nyckel(med) &&
    !/verdikt|roll|namn|prioritet/.test(sigKod),
    'identisk signatur med och utan verdikt, roll, namn och prioritet'); }

/* ── CL-06 · prioritet andrar aldrig medlemskap ─────────────────────*/
{ const liten = havstang({ olosta: 1, comparatorer: 0, comparatorRoller: 0,
    tillstandsformer: 1, texttopologier: 1, semantisktHeterogen: false });
  const stor = havstang({ olosta: 162, comparatorer: 5, comparatorRoller: 1,
    tillstandsformer: 1, texttopologier: 1, semantisktHeterogen: false });
  const sigKod = KOD.slice(KOD.indexOf('export function struktursignatur'),
    KOD.indexOf('export const signaturnyckel'));
  const partKod = KOD.slice(KOD.indexOf('export function partitionsnyckel'),
    KOD.indexOf('export function hash'));
  prov('CL-06', 'prioritetspoang andrar aldrig medlemskap i kluster eller partition',
    stor.poang > liten.poang && !/havstang|poang/.test(sigKod) && !/havstang|poang/.test(partKod) &&
    /aldrig andra medlemskap/.test(stor.$regel),
    'poang ' + liten.poang + ' och ' + stor.poang + '; varken signatur eller partition ' +
      'laser poangen'); }

/* ── CL-07 · blandade verdikt flaggas ───────────────────────────────*/
{ const het = A.G_heterogenitet.heterogenaKluster;
  const allaFlaggade = het.every(k => k.semantisktHeterogen === true &&
    k.sentinelVerdikt.length > 1);
  const ingenSpridning = A.P_verdiktandringar === 0;
  prov('CL-07', 'ett kluster med blandade kanda verdikt flaggas och sprider inget',
    allaFlaggade && ingenSpridning,
    het.length + ' heterogena kluster, alla flaggade; ' + A.P_verdiktandringar +
      ' verdikt andrade'); }

/* ── CL-08 · comparatorrollkonflikt bevaras ─────────────────────────*/
{ const konf = A.F_comparatorprofiler.medRollkonflikt;
  const bevarad = konf.every(k => k.comparatorRoller.length > 1 &&
    k.comparatorRollKonflikt === true);
  prov('CL-08', 'flera comparatorroller bevaras som konflikt, aldrig reducerade av majoritet',
    bevarad && konf.length > 0 &&
    !/majoritet|vanligast|flest/.test(KOD),
    konf.length + ' kluster med rollkonflikt, alla med full rollista bevarad'); }

/* ── CL-09 / CL-10 · tackning ───────────────────────────────────────*/
{ const r = A.E_avstamning;
  prov('CL-09', 'varje olost kandidat ligger i exakt ett strukturkluster',
    r.summaNiva1 === r.olosta && r.dubbletter === 0 && r.saknade === 0,
    r.summaNiva1 + ' av ' + r.olosta + ', ' + r.dubbletter + ' dubbletter, ' +
      r.saknade + ' saknade'); }
{ const r = A.E_avstamning;
  prov('CL-10', 'varje olost kandidat ligger i exakt en granskningspartition',
    r.summaPartitioner === r.olosta && r.dubbletter === 0 && r.saknade === 0,
    r.summaPartitioner + ' av ' + r.olosta); }

/* ── CL-11 · determinism ────────────────────────────────────────────*/
{ const d = A.I_determinism;
  // Plus ett direkt prov: samma indata ger samma hash.
  const h1 = hash(nyckel(o())), h2 = hash(nyckel(o()));
  prov('CL-11', 'klusteridentiteten ar deterministisk over identiska korningar',
    d.sammaMedlemskap && d.sammaHashar && d.sammaOrdning && h1 === h2,
    'tva korningar: medlemskap ' + d.sammaMedlemskap + ', hashar ' + d.sammaHashar +
      ', ordning ' + d.sammaOrdning); }

/* ── CL-12 · noll verdiktandringar ──────────────────────────────────*/
{ prov('CL-12', 'klustringen andrar noll semantiska verdikt',
    A.P_verdiktandringar === 0 && A.Q_deklarerade === 1351 &&
    A.R_recall === '1351/1351' && A.S_tvetydiga === 0 &&
    FORBJUDNA_NYCKLAR.length >= 12,
    '0 verdiktandringar, deklarerade ' + A.Q_deklarerade + ', recall ' + A.R_recall +
      ', tvetydiga ' + A.S_tvetydiga); }

/* ── CL-13 · bit-identisk klustring ─────────────────────────────────*/
{ const V = JSON.parse(readFileSync(join(rot, 'fas2', 'klustring-v2.json'), 'utf8'));
  const d = V.J_determinism;
  prov('CL-13', 'samma indata och samma population ger bit-identisk klustring',
    d.shadowIdentisk && d.operativIdentisk,
    'shadow ' + d.shadowIdentisk + ', operativ ' + d.operativIdentisk +
      '; fingeravtryck ' + d.shadowFp + ' / ' + d.operativFp); }

/* ── CL-14 · verdikt kan inte andra medlemskap ──────────────────────*/
{ const bas = o({ andelAvArtefaktyta: 0.01, identiskaSyskon: 1 });
  const med = { ...bas, verdikt: 'INTERACTIVE_CONTROL', tidigareVerdikt: 'DECORATIVE_GRAPHIC' };
  prov('CL-14', 'andrade semantiska verdikt ensamt kan inte andra medlemskap',
    signaturnyckel(struktursignaturV2(bas)) === signaturnyckel(struktursignaturV2(med)),
    'identisk v2-signatur med och utan verdiktfalt'); }

/* ── CL-15 · comparatorroll kan inte andra medlemskap ───────────────*/
{ const bas = o({ andelAvArtefaktyta: 0.01, identiskaSyskon: 1 });
  const med = { ...bas, comparatorRoll: 'button', roll: 'checkbox' };
  prov('CL-15', 'andrade comparatorroller ensamt kan inte andra medlemskap',
    signaturnyckel(struktursignaturV2(bas)) === signaturnyckel(struktursignaturV2(med)) &&
    !/comparator|roll/.test(signaturnyckel(struktursignaturV2(bas))),
    'identisk v2-signatur, och ingen rollterm i nyckeln'); }

/* ── CL-16 / CL-17 · rent matematiska egenskaper ────────────────────*/
{ const fn = relativYtklass.toString();
  prov('CL-16', 'relativ ytklass bestams utan semantiska data',
    relativYtklass(0.96) === 'A-1' && relativYtklass(0.00006) === 'A-5' &&
    relativYtklass(0.01) === 'A-2' &&
    !/verdikt|roll|namn|etikett|skarm/.test(fn) && /log10/.test(fn),
    '0,96 → A-1, 0,01 → A-2, 0,00006 → A-5; funktionen laser bara en ytkvot'); }
{ const fn = syskonupprepningsklass.toString();
  prov('CL-17', 'syskonupprepningsklass bestams utan semantiska data',
    syskonupprepningsklass(1) === 'R0' && syskonupprepningsklass(3) === 'R1' &&
    syskonupprepningsklass(4) === 'R2' && syskonupprepningsklass(16) === 'R4' &&
    !/verdikt|roll|namn|etikett|skarm/.test(fn) && /log2/.test(fn),
    '1 → R0, 3 → R1, 4 → R2, 16 → R4; funktionen laser bara ett antal'); }

/* ── CL-18 · historiska identiteter oforanderliga ───────────────────*/
{ const gammal = JSON.parse(readFileSync(join(rot, 'fas2', 'kandidatklustring.json'), 'utf8'));
  const V = JSON.parse(readFileSync(join(rot, 'fas2', 'klustring-v2.json'), 'utf8'));
  const gamlaId = new Set(gammal.W_klusterkvalitet.map(k => k.id));
  const nyaId = V.F_operativ.kluster.map(k => k.id);
  prov('CL-18', 'historiska klusteridentiteter ar oforanderliga',
    gammal.C_niva1.antal === 416 && gammal.D_partitioner.antal === 559 &&
    nyaId.every(id => !gamlaId.has(id)) && nyaId.every(id => id.startsWith('CL2-')),
    'de gamla 416/559 star kvar och ingen ny identitet ateranvander ett gammalt id'); }

/* ── CL-19 · andrad medlemsmangd kraver ny identitet ────────────────*/
{ const V = JSON.parse(readFileSync(join(rot, 'fas2', 'klustring-v2.json'), 'utf8'));
  const pilot = V.I_pilotgruppen;
  const nya = pilot.delning.map(x => x.nyPartition);
  prov('CL-19', 'andrad medlemsmangd kraver en ny kluster- eller partitionsidentitet',
    pilot.gammalId === 'CL-903533c5d5' && pilot.gammaltAntal === 143 &&
    pilot.nyaPartitioner > 1 && nya.every(id => id !== pilot.gammalId) &&
    new Set(nya).size === nya.length,
    '143 i ett gammalt id blev ' + pilot.nyaPartitioner + ' nya, alla med egna identiteter'); }

/* ── CL-20 / CL-21 · avstamning ─────────────────────────────────────*/
{ const V = JSON.parse(readFileSync(join(rot, 'fas2', 'klustring-v2.json'), 'utf8'));
  prov('CL-20', 'shadowpopulationen stammer exakt 2684 = 2684',
    V.E_shadow.population === 2684 && V.E_shadow.summa === 2684,
    V.E_shadow.population + ' = ' + V.E_shadow.summa); }
{ const V = JSON.parse(readFileSync(join(rot, 'fas2', 'klustring-v2.json'), 'utf8'));
  prov('CL-21', 'den operativa populationen stammer exakt 2611 = 2611',
    V.F_operativ.population === 2611 && V.F_operativ.summa === 2611 &&
    V.K_avstamning.raPopulation === 2700,
    V.F_operativ.population + ' = ' + V.F_operativ.summa + '; ra population oforandrad ' +
      V.K_avstamning.raPopulation); }

/* ── CL-22 · upprepning innebar inte DECORATIVE ─────────────────────*/
{ const V = JSON.parse(readFileSync(join(rot, 'fas2', 'klustring-v2.json'), 'utf8'));
  const hogUpprepning = syskonupprepningsklass(16);
  prov('CL-22', 'upprepning ensam kan inte innebara DECORATIVE',
    V.B_korrigeradPilot.totalerEfter.DECORATIVE_GRAPHIC === 0 &&
    V.B_korrigeradPilot.ateroppnade.length === 14 &&
    hogUpprepning === 'R4' &&
    // Klassen ar en gruppering, inte ett verdikt: den namner ingen verdiktklass.
    !/DECORATIVE|CONTROL|GRAPHIC/.test(hogUpprepning),
    'de 14 ar ateroppnade som UNKNOWN och upprepningsklassen bar ingen verdiktterm'); }

/* ── CL-23 · nya egenskaper sprider inget verdikt ───────────────────*/
{ const V = JSON.parse(readFileSync(join(rot, 'fas2', 'klustring-v2.json'), 'utf8'));
  const blandade = V.I_pilotgruppen.delning.filter(x => Object.keys(x.$postHoc).length > 1);
  prov('CL-23', 'de nya egenskaperna kan inte sprida ett semantiskt verdikt',
    V.I_pilotgruppen.delning.every(x => /post hoc|EFTER klustringen/i.test(x.$not)) &&
    blandade.length > 0,
    'verdiktfordelningen visas enbart som efterhandsdiagnostik, och ' + blandade.length +
      ' av de nya partitionerna ar fortfarande blandade — inget verdikt har spridits'); }

/* ── CL-24 · tva identiska fullkorningar ────────────────────────────*/
{ const V = JSON.parse(readFileSync(join(rot, 'fas2', 'klustring-v2.json'), 'utf8'));
  const h1 = hash(signaturnyckel(struktursignaturV2(o({ andelAvArtefaktyta: 0.02,
    identiskaSyskon: 4 }))));
  const h2 = hash(signaturnyckel(struktursignaturV2(o({ andelAvArtefaktyta: 0.02,
    identiskaSyskon: 4 }))));
  prov('CL-24', 'tva identiska fullkorningar ger identiskt medlemskap, hashar och ordning',
    V.J_determinism.shadowIdentisk && V.J_determinism.operativIdentisk && h1 === h2,
    'bada fullkorningarna identiska och samma indata ger samma hash ' + h1.slice(0, 12)); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('KLUSTERPROV status=' + (ok === resultat.length ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + resultat.length);
writeFileSync(join(outAbs, 'clprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === resultat.length ? 0 : 1);
