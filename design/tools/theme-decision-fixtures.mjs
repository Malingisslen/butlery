#!/usr/bin/env node
// F2-R04 · PROV FOR TOKENIDENTITET OCH BESLUTSLIVSCYKEL.
//
// Felklassen som ar belagd i skarpt lage: tokennamn genererades ur
// listordningen. Nar ett beslut ersattes forskots numreringen och nasta batch
// fick ett namn som redan stod i ritningarna for en annan farg.

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { tilldelaTokennamn, tokenkarta, beslutFor, ersatt, arAktiv, beslutsIdAv, postIdAv } from './theme-decisions.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (OUT) { const o = resolve(OUT);
  if (o.startsWith(resolve('.') + '\\') || o.startsWith(resolve('.') + '/')) {
    console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
  mkdirSync(o, { recursive: true }); }

const bas = () => ({ beslut: [
  { beslutsId: 'CAND-yta-upphojd-#aaa', kandidatId: 'CAND-yta-upphojd-#aaa', omfattning: 'WHOLE_CANDIDATE',
    roll: 'yta-upphojd', ljusvarde: '#aaa', morkvarde: '#111' },
  { beslutsId: 'CAND-yta-upphojd-#bbb ‖ ug-1', kandidatId: 'CAND-yta-upphojd-#bbb', omfattning: 'SUBGROUP',
    semantiskUndergrupp: 'ug-1', roll: 'yta-upphojd', ljusvarde: '#bbb', morkvarde: '#222' },
  { beslutsId: 'CAND-text-kontroll-#ccc', kandidatId: 'CAND-text-kontroll-#ccc', omfattning: 'WHOLE_CANDIDATE',
    roll: 'text-kontroll', ljusvarde: '#ccc', morkvarde: '#333' } ] });
// Nyckeln ar POSTens identitet, inte scopets — annars skuggar ersattaren
// sin egen historik i jamforelsen.
const namnkarta = r => Object.fromEntries(r.beslut.map(b => [postIdAv(b), b.tokenNamn]));

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

/* ── A · supersede rorer inga befintliga namn ───────────────────────────── */
{ const r = bas(); tilldelaTokennamn(r);
  const fore = namnkarta(r);
  const sv = ersatt(r, 'CAND-yta-upphojd-#bbb ‖ ug-1',
    { morkvarde: '#999' }, 'FAILED_DARK_TEXT_CONTRAST');
  const efter = namnkarta(r);
  const oforandrade = Object.entries(fore).every(([k, v]) => efter[k] === v);
  const ersattFinns = r.beslut.some(b => b.status === 'SUPERSEDED' && b.tokenNamn === fore['CAND-yta-upphojd-#bbb ‖ ug-1 @r1']);
  prov('TI-01', 'supersede av ett beslut andrar 0 befintliga tokennamn',
    sv.ok && oforandrade && ersattFinns && sv.nyttNamn !== sv.gammaltNamn,
    'gammalt ' + sv.gammaltNamn + ' · nytt ' + sv.nyttNamn + ' · oforandrade ' + oforandrade); }

/* ── B · insattning fore ett befintligt beslut ──────────────────────────── */
{ const r = bas(); tilldelaTokennamn(r);
  const fore = namnkarta(r);
  r.beslut.unshift({ beslutsId: 'CAND-ram-kontroll-#ddd', kandidatId: 'CAND-ram-kontroll-#ddd',
    omfattning: 'WHOLE_CANDIDATE', roll: 'ram-kontroll', ljusvarde: '#ddd', morkvarde: '#444' });
  tilldelaTokennamn(r);
  const efter = namnkarta(r);
  const oforandrade = Object.entries(fore).every(([k, v]) => efter[k] === v);
  prov('TI-02', 'insattning FORE ett befintligt beslut andrar 0 befintliga tokennamn',
    oforandrade && !!efter['CAND-ram-kontroll-#ddd @r1'],
    'nytt ' + efter['CAND-ram-kontroll-#ddd @r1'] + ' · oforandrade ' + oforandrade); }

/* ── C · omsortering ────────────────────────────────────────────────────── */
{ const r = bas(); tilldelaTokennamn(r);
  const fore = namnkarta(r);
  r.beslut.reverse(); r.beslut.push(r.beslut.shift());
  tilldelaTokennamn(r);
  const efter = namnkarta(r);
  const oforandrade = Object.entries(fore).every(([k, v]) => efter[k] === v);
  prov('TI-03', 'omsortering av registret andrar 0 befintliga tokennamn',
    oforandrade, JSON.stringify(fore) + ' -> ' + JSON.stringify(efter)); }

/* ── D · ersatt beslut ignoreras men behaller sin identitet ─────────────── */
{ const r = bas(); tilldelaTokennamn(r);
  ersatt(r, 'CAND-yta-upphojd-#aaa', { morkvarde: '#000' }, 'FAILED_DARK_TEXT_CONTRAST');
  const gammal = r.beslut.find(b => b.status === 'SUPERSEDED');
  const karta = tokenkarta(r);
  const aktivt = beslutFor(r, 'CAND-yta-upphojd-#aaa', null);
  const ersattIKartan = [...karta.values()].some(t => t.mork === '#111');
  prov('TI-04', 'ersatt beslut ignoreras av uppslagningen men behaller sitt historiska tokennamn',
    !!gammal.tokenNamn && !arAktiv(gammal) && !ersattIKartan &&
    !!aktivt && aktivt.morkvarde === '#000',
    'historiskt namn ' + gammal.tokenNamn + ' · i aktiv karta ' + ersattIKartan +
    ' · aktivt morkvarde ' + (aktivt ? aktivt.morkvarde : '-')); }

/* ── E · ersattaren far ett eget namn, aldrig nagon annans ──────────────── */
{ const r = bas(); tilldelaTokennamn(r);
  const fore = namnkarta(r);
  const alla = new Set(Object.values(fore));
  const sv = ersatt(r, 'CAND-yta-upphojd-#aaa', { morkvarde: '#000' }, 'FAILED_DARK_TEXT_CONTRAST');
  const namn = r.beslut.filter(b => b.tokenNamn).map(b => b.tokenNamn);
  const unika = new Set(namn).size === namn.length;
  prov('TI-05', 'ersattaren far ett eget registrerat namn och ateranvander aldrig ett annat tokens namn',
    unika && !alla.has(sv.nyttNamn) && sv.nyttNamn !== sv.gammaltNamn,
    'nytt ' + sv.nyttNamn + ' · alla unika ' + unika + ' · fanns sedan tidigare ' + alla.has(sv.nyttNamn)); }

/* ── F · uppslagning sker pa identitet, inte pa listindex ───────────────── */
{ const r = bas(); tilldelaTokennamn(r);
  const fore = beslutFor(r, 'CAND-yta-upphojd-#bbb', 'ug-1');
  r.beslut.sort((a, b) => beslutsIdAv(b).localeCompare(beslutsIdAv(a)));
  const efter = beslutFor(r, 'CAND-yta-upphojd-#bbb', 'ug-1');
  const syskon = beslutFor(r, 'CAND-yta-upphojd-#bbb', 'ug-2');
  prov('TI-06', 'uppslagning sker pa beslutsidentitet och overlever omsortering; ett syskon traffas aldrig',
    !!fore && !!efter && fore.tokenNamn === efter.tokenNamn && syskon === null,
    'fore ' + (fore && fore.tokenNamn) + ' · efter ' + (efter && efter.tokenNamn) + ' · syskon ' + syskon); }

const ANTAL = 6;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('TOKENIDENTITETSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(resolve(OUT), 'tokenidentitetsprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
