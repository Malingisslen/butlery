#!/usr/bin/env node
// F2 · METODPROV FOR SORTERINGSNYCKEL MOT BESLUTSSCOPE.  KEY-01 … KEY-07
//
// KEY-01  samma nyckel + samma farg, annat screen scope: --yta-upphojd-d18 (start)
//         mot lagatimers BG-027  -> NO_MATCH / ZERO_CREDIT
// KEY-02  samma, mot lagatimers BG-028                   -> NO_MATCH / ZERO_CREDIT
// KEY-03  de tva lagatimers-besluten delar #d8b784 men forblir tva identiteter
// KEY-04  inget morkt varde arvs fran --yta-upphojd-d18 till lagatimers
// KEY-05  ingen R-04-kredit uppstar for lagatimers
// KEY-06  en legitim traff inom exakt registrerat scope fungerar fortfarande
// KEY-07  flera mojliga registerposter efter identitets- och scopeprov: fail
//         closed, aldrig "forsta traffen"
//
// KEY-01, KEY-02, KEY-04 och KEY-05 kors mot den VERKLIGA registerposten
// --yta-upphojd-d18 sa som den star i fas2/r04-designbeslut.json, och mot
// lagatimers-forekomsterna sa som matningen registrerade dem. Sentinellerna
// ger forekomsten SAMMA kandidatId, roll, undergrupp och ljusvarde som
// beslutet — annars skulle provet kunna bli gront av fel skal, pa
// identitetslagret, utan att scopelagret nagonsin provades.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { beslutstackning, tackerForekomst, beslutsomfattning, nyckelkollision,
  sorteringsnyckel, nyckelAvBeslut, OMFATTNINGSKLASS, TACKNING, NYCKELKONTRAKT }
  from './decision-scope-guard.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

const rot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const R04 = JSON.parse(readFileSync(join(rot, 'fas2', 'r04-designbeslut.json'), 'utf8'));
const NTR = JSON.parse(readFileSync(join(rot, 'fas2', 'nt-remediering-beslut.json'), 'utf8'));
const d18 = R04.beslut.find(b => b.tokenNamn === '--yta-upphojd-d18');
if (!d18) { console.error('✖ sentinellposten --yta-upphojd-d18 saknas'); process.exit(2); }
const UG = d18.semantiskUndergrupp;

// Forekomsterna sa som matningen registrerade dem, med det beslutade vardet.
const forekomst = (artefakt, ordinal) => ({
  kandidatId: d18.kandidatId, roll: d18.roll, undergrupp: UG, ljusvarde: '#d8b784',
  artefakt, kallidentitet: artefakt + '|' + ordinal + '|background-color' });
const BG027 = forekomst('lagatimers', 14);
const BG028 = forekomst('lagatimers', 23);

/* ── KEY-01 · annat screen scope, BG-027 ─────────────────────────────*/
{ const t = beslutstackning(R04, BG027);
  const k = nyckelkollision(R04, BG027);
  prov('KEY-01', 'samma nyckel och samma farg men annat screen scope ger NO_MATCH / ZERO_CREDIT (BG-027)',
    !t.ok && t.tackning === TACKNING.EJ_TACKT_ANNAN_KALLA && t.kredit === 0 &&
    t.mappningsevidens === false && t.morktVarde === null && t.tokenidentitet === null &&
    t.scopeUtokat === false && t.kopplarBeslut === false &&
    k.antalNyckeltraffar >= 1 && k.utfall === 'NYCKELTRAFF_UTAN_TACKNING' &&
    nyckelAvBeslut(d18) === sorteringsnyckel(BG027),
    'nyckeln ar identisk (' + k.nyckel + ') och ' + k.antalNyckeltraffar +
      ' registerpost traffar den, men ' + t.skal); }

/* ── KEY-02 · annat screen scope, BG-028 ─────────────────────────────*/
{ const t = beslutstackning(R04, BG028);
  const k = nyckelkollision(R04, BG028);
  prov('KEY-02', 'samma nyckel och samma farg men annat screen scope ger NO_MATCH / ZERO_CREDIT (BG-028)',
    !t.ok && t.tackning === TACKNING.EJ_TACKT_ANNAN_KALLA && t.kredit === 0 &&
    t.mappningsevidens === false && t.morktVarde === null && t.tokenidentitet === null &&
    k.utfall === 'NYCKELTRAFF_UTAN_TACKNING' &&
    nyckelAvBeslut(d18) === sorteringsnyckel(BG028),
    'samma nyckel som BG-027 och samma registerpost traffas, men ' + t.skal); }

/* ── KEY-03 · tva identiteter trots samma varde ──────────────────────*/
{ const a = NTR.beslut.find(b => b.beslutsId === 'NTR-BATCH04-LIGHT-PROGRESS-FILL-DU-01-A');
  const t = NTR.beslut.find(b => b.beslutsId === 'NTR-BATCH04-LIGHT-PROGRESS-FILL-TIMER-DU-02');
  const finns = !!a && !!t;
  prov('KEY-03', 'de tva lagatimers-besluten delar #d8b784 men forblir tva separata identiteter',
    finns && a.valtVarde === t.valtVarde && a.valtVarde === '#d8b784' &&
    a.beslutsId !== t.beslutsId && a.tokenidentitet !== t.tokenidentitet &&
    a.kallidentitet !== t.kallidentitet &&
    a.stabiltRelationsId !== t.stabiltRelationsId &&
    JSON.stringify(a.relationer) !== JSON.stringify(t.relationer) &&
    a.skrivplatser[0].offset !== t.skrivplatser[0].offset &&
    a.R04_COVERAGE_CREDIT === 0 && t.R04_COVERAGE_CREDIT === 0,
    finns ? 'samma varde ' + a.valtVarde + ', men skilda pa beslutsId, tokenidentitet, kallidentitet, relationsid, relation och skrivplats'
          : 'beslutsposterna saknas'); }

/* ── KEY-04 · inget morkt varde arvs ─────────────────────────────────*/
{ const a = beslutstackning(R04, BG027), t = beslutstackning(R04, BG028);
  prov('KEY-04', 'inget morkt varde arvs fran --yta-upphojd-d18 till nagot lagatimers-beslut',
    a.morktVarde === null && t.morktVarde === null &&
    d18.morkvarde === 'rgba(245,244,237,0.18)' &&
    !NTR.beslut.filter(b => (b.relationer || []).some(r => r === 'BG-027' || r === 'BG-028'))
      .some(b => 'morkvarde' in b || 'morktVarde' in b),
    'beslutet bar det morka vardet ' + d18.morkvarde +
      ', men uppslagningen ger null och ingen av de tva NTR-posterna har nagot morkt falt'); }

/* ── KEY-05 · ingen R-04-kredit ──────────────────────────────────────*/
{ const a = beslutstackning(R04, BG027), t = beslutstackning(R04, BG028);
  const ntr = NTR.beslut.filter(b => (b.relationer || []).some(r => r === 'BG-027' || r === 'BG-028'));
  prov('KEY-05', 'ingen R-04-coverage eller kredit uppstar for lagatimers',
    a.kredit === 0 && t.kredit === 0 &&
    a.mappningsevidens === false && t.mappningsevidens === false &&
    ntr.length === 2 && ntr.every(b => b.R04_COVERAGE_CREDIT === 0) &&
    !R04.beslut.some(b => (b.berordaArtefakter || []).includes('lagatimers')),
    'bada uppslagningarna ger kredit 0, bada NTR-posterna bar R04_COVERAGE_CREDIT 0 och ingen R-04-post har lagatimers i sitt scope'); }

/* ── KEY-06 · legitim traff inom exakt registrerat scope ─────────────*/
{ const inom = { kandidatId: d18.kandidatId, roll: d18.roll, undergrupp: UG,
    ljusvarde: d18.ljusvarde, artefakt: 'start', kallidentitet: d18.kallidentitet };
  const t = beslutstackning(R04, inom);
  const o = beslutsomfattning(d18);
  // Artefaktlistescope maste ocksa fungera.
  const listbeslut = { ...d18, kallidentitet: undefined, berordaArtefakter: ['start', 'globceremoni'] };
  delete listbeslut.kallidentitet;
  const lista = tackerForekomst(listbeslut, { artefakt: 'globceremoni',
    kallidentitet: 'globceremoni|7|background-color' });
  prov('KEY-06', 'en legitim traff inom exakt registrerat scope fungerar fortfarande',
    t.ok && t.tackning === TACKNING.TACKT && t.kredit === 1 &&
    t.mappningsevidens === true && t.morktVarde === d18.morkvarde &&
    t.tokenidentitet === '--yta-upphojd-d18' &&
    o.klass === OMFATTNINGSKLASS.KALLIDENTITET &&
    lista.tackt === true && beslutsomfattning(listbeslut).klass === OMFATTNINGSKLASS.ARTEFAKTLISTA,
    'kallraden ' + d18.kallidentitet + ' slar upp beslutet och far bade morkt varde och token; ett artefaktlistescope tacker ocksa sina egna artefakter'); }

/* ── KEY-07 · flera mojliga: fail closed, inte forsta traffen ────────*/
{ const dubblett = { ...d18, beslutsId: d18.beslutsId + ' @dubblett',
    tokenNamn: '--yta-upphojd-dublett', berordaArtefakter: ['start', 'lagatimers'] };
  const reg = { beslut: [...R04.beslut, dubblett] };
  const inom = { kandidatId: d18.kandidatId, roll: d18.roll, undergrupp: UG,
    ljusvarde: d18.ljusvarde, artefakt: 'start', kallidentitet: d18.kallidentitet };
  const t = beslutstackning(reg, inom);
  const lagat = beslutstackning(reg, BG027);
  prov('KEY-07', 'flera mojliga registerposter ger fail closed, aldrig forsta traffen',
    !t.ok && t.tackning === TACKNING.TVETYDIG && t.beslut === null && t.kredit === 0 &&
    t.tokenidentitet === null && t.morktVarde === null &&
    !lagat.ok && lagat.kredit === 0,
    'tva poster delar hela identiteten; uppslagningen faller stangt i stallet for att valja den forsta, och gor det aven for lagatimers-forekomsten'); }

const ANTAL = 7;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('NYCKELKONTRAKT');
for (const rad of NYCKELKONTRAKT) console.log('  · ' + rad);
console.log('');
console.log('SCOPEGUARD-PROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'scopeguardprov.json'),
  JSON.stringify({ resultat, kontrakt: NYCKELKONTRAKT }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
