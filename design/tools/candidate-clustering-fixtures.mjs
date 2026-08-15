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

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { struktursignatur, signaturnyckel, partitionsnyckel, havstang, hash,
  formklass, texttopologi, tillstandsbarare, FORBJUDNA_NYCKLAR }
  from './candidate-clustering.mjs';

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

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('KLUSTERPROV status=' + (ok === resultat.length ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + resultat.length);
writeFileSync(join(outAbs, 'clprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === resultat.length ? 0 : 1);
