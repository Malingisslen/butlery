#!/usr/bin/env node
// F2-R04 · REGRESSIONSPROV FOR DE TRE ANALYSMETODFELEN.
//
// Alla tre intraffade i skarpt lage under ythierarkianalysen och gav var for
// sig ett falskt resultat som sag giltigt ut.

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { tolkaFarg, kontrast, platta, forgrunderPaYtan, klassificera, bedomKandidat } from './surface-analysis.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (OUT) { const o = resolve(OUT);
  if (o.startsWith(resolve('.') + '\\') || o.startsWith(resolve('.') + '/')) {
    console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
  mkdirSync(o, { recursive: true }); }

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });
const nara = (a, b) => a !== null && Math.abs(a - b) < 0.02;

/* ── A · fargtolkning ───────────────────────────────────────────────────── */
{ const f = [['#24382c', 36, 56, 44], ['#17251d', 23, 37, 29], ['#FFF', 255, 255, 255],
    ['rgb(147, 164, 141)', 147, 164, 141], ['rgba(245,244,237,0.4)', 245, 244, 237]];
  const fel = f.filter(([v, r, g, b]) => { const c = tolkaFarg(v);
    return !c || c.r !== r || c.g !== g || c.b !== b; });
  prov('SA-A1', 'hex och rgb tolkas bada till korrekt RGB',
    fel.length === 0, fel.length ? 'fel pa ' + fel.map(x => x[0]).join(', ') : f.length + ' fargpar korrekta'); }

{ // Kanda par ur den verkliga analysen.
  const par = [['#93a48d', '#24382c', 4.73], ['#de9078', '#24382c', 4.99],
    ['#93a48d', '#17251d', 6.02], ['#f5f4ed', '#4a5c43', 6.56], ['#24382c', '#17251d', 1.27]];
  const fel = par.filter(([a, b, v]) => !nara(kontrast(a, b), v));
  prov('SA-A2', 'kontrastkvoten blir numerisk och stammer mot kanda hexpar',
    fel.length === 0, fel.length ? fel.map(x => x[0] + '/' + x[1] + ' gav ' + kontrast(x[0], x[1]) + ' vantat ' + x[2]).join(' · ')
      : par.map(x => x[2]).join(', ')); }

{ // Felklassen: null slank igenom som ett giltigt resultat.
  const dåliga = ['ingen-farg', '', null, undefined, 'var(--x)', 'transparent', '#12345'];
  const utfall = dåliga.map(v => kontrast(v, '#17251d'));
  const kNaN = kontrast('#24382c', 'sopor');
  prov('SA-A3', 'ett otolkbart varde ger null, aldrig NaN eller undefined som giltigt matresultat',
    utfall.every(x => x === null) && kNaN === null &&
    utfall.every(x => !Number.isNaN(x)),
    'otolkbara ' + utfall.length + ' -> ' + JSON.stringify(utfall) + ' · okand bakgrund -> ' + kNaN); }

{ const g = platta('rgba(245,244,237,0.4)', '#17251d');
  prov('SA-A4', 'genomskinlig forgrund plattas mot sin faktiska bakgrund fore matning',
    !!g && g.a === 1 && g.r === 112 && nara(kontrast('rgba(245,244,237,0.4)', '#17251d'), 3.5),
    g ? 'rgb(' + g.r + ', ' + g.g + ', ' + g.b + ') · kvot ' + kontrast('rgba(245,244,237,0.4)', '#17251d') : 'gick inte att platta'); }

/* ── B · forgrund mot sin FAKTISKA yta ──────────────────────────────────── */
{ // Tva ytor med IDENTISK farg. Forgrunden tillhor bara den ena.
  const ytor = [{ art: 'skarm', ordinal: 5 }];
  const element = [
    { art: 'skarm', ordinal: 6, namn: 'text pa ytan', underliggandeYta: { ordinal: 5, farg: 'rgb(36, 56, 44)' } },
    { art: 'skarm', ordinal: 9, namn: 'text pa den ANDRA ytan', underliggandeYta: { ordinal: 8, farg: 'rgb(36, 56, 44)' } },
    { art: 'annan', ordinal: 6, namn: 'text i en annan artefakt', underliggandeYta: { ordinal: 5, farg: 'rgb(36, 56, 44)' } }];
  const traff = forgrunderPaYtan(element, ytor);
  prov('SA-B1', 'forgrund kopplas till ytans IDENTITET; en yta med samma farg drar aldrig in fel forgrund',
    traff.length === 1 && traff[0].namn === 'text pa ytan',
    traff.length + ' traff: ' + traff.map(t => t.namn).join(', ')); }

{ // Utan ordinal gar identiteten inte att faststalla: posten slapps.
  const ytor = [{ art: 'skarm', ordinal: 5 }];
  const element = [{ art: 'skarm', ordinal: 6, underliggandeYta: { ordinal: null, farg: 'rgb(36, 56, 44)' } },
    { art: 'skarm', ordinal: 7, underliggandeYta: null }];
  prov('SA-B2', 'en forgrund utan faststallbar ytidentitet dras aldrig in — fail closed',
    forgrunderPaYtan(element, ytor).length === 0,
    forgrunderPaYtan(element, ytor).length + ' traff (ska vara 0)'); }

{ // Flera ytor i samma grupp: alla deras forgrunder ska med, men inga andra.
  const ytor = [{ art: 'a', ordinal: 3 }, { art: 'a', ordinal: 12 }, { art: 'b', ordinal: 3 }];
  const element = [
    { art: 'a', ordinal: 4, underliggandeYta: { ordinal: 3 } },
    { art: 'a', ordinal: 13, underliggandeYta: { ordinal: 12 } },
    { art: 'b', ordinal: 4, underliggandeYta: { ordinal: 3 } },
    { art: 'a', ordinal: 20, underliggandeYta: { ordinal: 19 } },
    { art: 'c', ordinal: 4, underliggandeYta: { ordinal: 3 } }];
  const t = forgrunderPaYtan(element, ytor);
  prov('SA-B3', 'flera ytor i en grupp samlar alla sina egna forgrunder och inga andras',
    t.length === 3 && !t.some(x => x.art === 'c') && !t.some(x => x.ordinal === 20),
    t.length + ' traff: ' + t.map(x => x.art + '#' + x.ordinal).join(', ')); }

/* ── C · klassificering av befintliga fel ───────────────────────────────── */
{ const fall = [
    { fore: 6.02, efter: 4.73, t: 4.5, vantat: 'PASS_TO_PASS' },
    { fore: 6.02, efter: 3.96, t: 4.5, vantat: 'PASS_TO_FAIL' },
    { fore: 2.50, efter: 3.10, t: 4.5, vantat: 'EXISTING_FAIL_IMPROVED' },
    { fore: 2.50, efter: 2.50, t: 4.5, vantat: 'EXISTING_FAIL_UNCHANGED' },
    { fore: 2.50, efter: 1.97, t: 4.5, vantat: 'EXISTING_FAIL_WORSENED' }];
  const fel = fall.filter(f => klassificera(f.fore, f.efter, f.t).utfall !== f.vantat);
  prov('SA-C1', 'alla fem utfallsklasser skiljs at korrekt',
    fel.length === 0, fel.length ? fel.map(f => f.fore + '->' + f.efter + ' gav ' + klassificera(f.fore, f.efter, f.t).utfall).join(' · ')
      : fall.map(f => f.vantat).join(', ')); }

{ // Det verkliga fallet: #8a5212 pa #17251d = 2.50, pa #24382c = 1.97.
  const k = klassificera(2.50, 1.97, 4.5);
  prov('SA-C2', 'en forsamring av ett befintligt fel markeras COUPLED_FIX_REQUIRED och doljs aldrig',
    k.utfall === 'EXISTING_FAIL_WORSENED' && k.kopplatFix === true && k.markning === 'COUPLED_FIX_REQUIRED',
    k.utfall + ' · kopplatFix ' + k.kopplatFix + ' · ' + k.markning); }

{ // En kandidat med bara befintliga fel ar fortfarande duglig.
  const rader = [klassificera(6.02, 4.73, 4.5), klassificera(2.50, 2.50, 4.5), klassificera(2.50, 3.10, 4.5)]
    .map((k, i) => ({ ...k, i }));
  const b = bedomKandidat(rader);
  prov('SA-C3', 'befintliga fel diskvalificerar aldrig en annars korrekt ytkandidat',
    b.duglig === true && b.nyaFel === 0 && b.kraverKopplatFix === false,
    'duglig ' + b.duglig + ' · nya fel ' + b.nyaFel + ' · ' + JSON.stringify(b.perUtfall)); }

{ // Ett enda nytt fel faller kandidaten.
  const b = bedomKandidat([klassificera(6.02, 3.96, 4.5), klassificera(6.02, 5.10, 4.5)]);
  prov('SA-C4', 'ett enda PASS_TO_FAIL faller kandidaten',
    b.duglig === false && b.nyaFel === 1,
    'duglig ' + b.duglig + ' · nya fel ' + b.nyaFel); }

{ // Duglig men kopplad. Far inte rapporteras som "inga nya fel" utan mer.
  const b = bedomKandidat([klassificera(6.02, 4.73, 4.5), klassificera(2.50, 1.97, 4.5)]);
  prov('SA-C5', 'en duglig kandidat som forsamrar ett befintligt fel flaggas som kopplad, inte som ren',
    b.duglig === true && b.nyaFel === 0 && b.kraverKopplatFix === true && b.kopplatFixKravs === 1,
    'duglig ' + b.duglig + ' · nya fel ' + b.nyaFel + ' · kopplade ' + b.kopplatFixKravs); }

{ // Ett omatbart varde far aldrig passera som duglig.
  const b = bedomKandidat([klassificera(null, 4.73, 4.5)]);
  prov('SA-C6', 'ett omatbart utfall gor kandidaten obedombar — aldrig duglig',
    b.duglig === false && b.perUtfall.UNKNOWN === 1,
    'duglig ' + b.duglig + ' · ' + JSON.stringify(b.perUtfall)); }

const ANTAL = 13;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('YTANALYSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(resolve(OUT), 'ytanalysprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
