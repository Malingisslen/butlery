#!/usr/bin/env node
// Prov for funktionssignal utan kontrollform i upptackten (Block 287 omgang 9).
// Kor: node tools/discovery-coverage-fixtures.mjs
import { signalkandidater } from './discovery-population.mjs';

const BAS = { fil: 'prov.dc.html', art: 'prov', tagg: 'span', roll: null, forfaderRoll: null, rawRole: null, iSvg: false, komponent: null,
  attr: {}, hitTarget: null, egenDelar: [], text: '', display: 'block', malar: false, x: 0, y: 0, w: 20, h: 20 };
const o = (ordProd, foralder, x = {}) => ({ ...BAS, ordProd, foraldraProd: foralder == null ? [] : [foralder], ...x });
// Portioner [− 4 +] i en yttre rad: 1 = rad, 2 = etikett, 3 = grupp, 4/5/6 = − varde +
const stepper = (v = '4', extra = []) => [o(1, null, { tagg: 'div' }), o(2, 1, { egenDelar: ['Portioner'] }), o(3, 1, { tagg: 'div', malar: true }),
  o(4, 3, { egenDelar: ['−'] }), o(5, 3, { egenDelar: [v] }), o(6, 3, { egenDelar: ['+'] }), ...extra];
const res = []; const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag) });
const ids = xs => signalkandidater(xs, []).map(k => k.ordProd + ':' + k.signalmekanism).sort();

{ const r = ids(stepper()); prov('STEP-01', 'portionsvaljarens minus blir kandidat', r.includes('4:HANDOFF_STEPPER'), r); }
{ const r = ids(stepper()); prov('STEP-02', 'portionsvaljarens plus blir kandidat', r.includes('6:HANDOFF_STEPPER'), r); }
{ const ensam = [o(1, null, { tagg: 'div' }), o(2, 1, { egenDelar: ['+'] }), o(3, 1, { egenDelar: ['Lägg till rubrik'] })];
  const utanEtikett = [o(1, null, { tagg: 'div' }), o(3, 1, { tagg: 'div' }), o(4, 3, { egenDelar: ['−'] }), o(5, 3, { egenDelar: ['4'] }), o(6, 3, { egenDelar: ['+'] })];
  const utanVarde = [o(1, null), o(2, 1, { egenDelar: ['Portioner'] }), o(3, 1), o(4, 3, { egenDelar: ['−'] }), o(5, 3, { egenDelar: ['fyra'] }), o(6, 3, { egenDelar: ['+'] })];
  const r = [ids(ensam), ids(utanEtikett), ids(utanVarde)];
  prov('STEP-03', 'ensamt eller dekorativt −/+ (utan etikett, utan tal) blir inte kontroll', r.every(x => x.length === 0), JSON.stringify(r)); }
{ const d = stepper().map(x => x.ordProd === 4 || x.ordProd === 6 ? { ...x, forfaderRoll: 'button' } : x);
  const r = ids(d); prov('STEP-04', 'tecken inuti en deklarerad knapp ar grafikbarn, ingen ny kandidat', r.length === 0, r); }
{ const r = signalkandidater(stepper(), []); const a = r.find(k => k.ordProd === 4), b = r.find(k => k.ordProd === 6);
  prov('STEP-05', 'minus och plus ar tva skilda kandidater med skilda tecken', a && b && a !== b && a.egenDelar[0] !== b.egenDelar[0], r.length); }
{ const r1 = ids(stepper('4')), r2 = ids(stepper('12'));
  prov('STEP-06', 'visat antal 4 → 12 andrar inte vilka som tas med', JSON.stringify(r1) === JSON.stringify(r2), r1 + ' / ' + r2); }
{ const bas = stepper().map(x => x.ordProd === 1 ? x : x); const flyttad = [o(7, 1, { egenDelar: ['Tid 45 min'] }), ...stepper()];
  const t = xs => signalkandidater(xs, []).map(k => k.egenDelar[0]).sort();
  prov('STEP-07', 'infogat syskon andrar inte vilka stegknappar som hittas', JSON.stringify(t(bas)) === JSON.stringify(t(flyttad)), t(flyttad)); }
{ const a = ids(stepper()), b = ids([...stepper()].reverse());
  prov('STEP-08', 'filordning/objektordning andrar inte resultatet', JSON.stringify(a) === JSON.stringify(b), a + ' / ' + b); }
{ const r = ids([o(1, null, { tagg: 'div', hitTarget: 'prov-button-1' }), o(2, null, { tagg: 'a', egenDelar: ['våra riktlinjer'] }), o(3, null, { attr: { 'data-action': 'spara' } })]);
  prov('SIG-01', 'data-hit-target, <a> och binding tas med utan kontrollform', r.length === 3 && r.every(x => /FUNCTIONAL_SIGNAL/.test(x)), r); }
{ const r = ids([o(1, null, { tagg: 'div', rawRole: 'tablist', hitTarget: 'x' }), o(2, null, { tagg: 'a', roll: 'link' }), o(3, null, { tagg: 'a', iSvg: true }), o(4, null, { egenDelar: ['Rubrik'] })]);
  prov('SIG-02', 'kallforfattad roll, deklarerat, svg-inre och ren text tas inte med', r.length === 0, r); }
{ const redan = [{ art: 'prov', ordinal: 1 }]; const s = signalkandidater([o(1, null, { tagg: 'a' })], redan);
  prov('SIG-03', 'element som redan ar kandidat laggs inte till igen', s.length === 0, s.length); }

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  → ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
