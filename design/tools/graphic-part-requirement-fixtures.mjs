#!/usr/bin/env node
// F2-NT · METODPROV FOR BORTFALLSPROVET.  GP-01 … GP-08

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { bortfallsprov, objektprov, buntprov, DELKLASS, KRAV_MOT_ANGRANSANDE }
  from './graphic-part-requirement.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

const rgb = h => { const m = /^#([0-9a-f]{6})$/i.exec(h); return m
  ? [0, 2, 4].map(i => parseInt(m[1].slice(i, i + 2), 16)) : null; };
const lum = c => { const f = c.map(v => { const s = v / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4); });
  return 0.2126 * f[0] + 0.7152 * f[1] + 0.0722 * f[2]; };
const kvotFn = (a, b) => { const A = lum(rgb(a)), Bq = lum(rgb(b));
  const h = Math.max(A, Bq), l = Math.min(A, Bq);
  return Math.round(((h + 0.05) / (l + 0.05)) * 100) / 100; };

const SKRIVINDIKATOR = { id: 'skrivindikator',
  delar: [{ id: 'punkt1' }, { id: 'punkt2' }, { id: 'punkt3' }] };
const ALLA_KRAVDA = { punkt1: { begripligUtan: false, motivering: 'en ensam kvarvarande punkt bevarar inte den igenkannbara treprickformen' },
  punkt2: { begripligUtan: false, motivering: 'samma skal' },
  punkt3: { begripligUtan: false, motivering: 'samma skal' } };

/* GP-01 · en del som objektet klarar sig utan ar supplemental */
{ const r = bortfallsprov({ id: 'skugga' }, true, 'objektet ar lika begripligt utan skuggan');
  prov('GP-01', 'en del objektet klarar sig utan ar SUPPLEMENTAL och far inget eget krav',
    r.klass === DELKLASS.SUPPLEMENTAL && r.krav === null, r.skal); }

/* GP-02 · en del objektet inte klarar sig utan ar kravd */
{ const r = bortfallsprov({ id: 'punkt2' }, false, 'formen upphor att vara igenkannbar');
  prov('GP-02', 'en del objektet inte klarar sig utan ar REQUIRED_FOR_UNDERSTANDING med krav 3.0',
    r.klass === DELKLASS.REQUIRED_FOR_UNDERSTANDING && r.krav.minsta === KRAV_MOT_ANGRANSANDE &&
    /angransande/.test(r.krav.mot), r.krav.kalla); }

/* GP-03 · obedomd del faller stangt */
{ const r = bortfallsprov({ id: 'x' }, null);
  prov('GP-03', 'en obedomd del faller stangt som UNKNOWN',
    r.klass === DELKLASS.UNKNOWN && r.krav === null, r.skal); }

/* GP-04 · skrivindikatorn: alla tre kravda */
{ const o = objektprov(SKRIVINDIKATOR, ALLA_KRAVDA);
  prov('GP-04', 'skrivindikatorns tre punkter ar alla kravda for forstaelsen',
    o.godkand && o.kravda.length === 3 && o.okanda.length === 0,
    'kravda: ' + o.kravda.join(', ')); }

/* GP-05 · kravet galler mot bakgrunden, aldrig mellan delarna */
{ const o = objektprov(SKRIVINDIKATOR, ALLA_KRAVDA);
  const bubbla = '#e6ead9';
  const b = buntprov(o, { punkt1: '#17251d', punkt2: '#24382c', punkt3: '#2f4437' },
    { punkt1: bubbla, punkt2: bubbla, punkt3: bubbla }, kvotFn);
  /* punkt1 mot punkt2 ar bara 1.27 — och det spelar ingen roll */
  const mellanDelar = kvotFn('#17251d', '#24382c');
  prov('GP-05', 'kravet mats mot angransande bakgrund, aldrig mellan delarna',
    b.ok && mellanDelar < 3,
    'alla tre mot bubblan ' + b.rader.map(r => r.kvot).join(' / ') +
    ' — godkant, trots att punkt1 mot punkt2 bara ar ' + mellanDelar); }

/* GP-06 · en kravd del under 3.0 faller */
{ const o = objektprov(SKRIVINDIKATOR, ALLA_KRAVDA);
  const bubbla = '#e6ead9';
  const b = buntprov(o, { punkt1: '#627061', punkt2: '#a9b2a0', punkt3: '#ccd1c2' },
    { punkt1: bubbla, punkt2: bubbla, punkt3: bubbla }, kvotFn);
  prov('GP-06', 'den nuvarande ljusa indikatorn faller pa tva av tre punkter',
    !b.ok && b.rader.filter(r => !r.ok).length === 2,
    b.rader.map(r => r.del + ' ' + r.kvot + (r.ok ? '' : ' ✖')).join(' · ')); }

/* GP-07 · ordningen avgor inte godkant */
{ const o = objektprov(SKRIVINDIKATOR, ALLA_KRAVDA);
  const bubbla = '#e6ead9';
  const fallande = buntprov(o, { punkt1: '#17251d', punkt2: '#24382c', punkt3: '#2f4437' },
    { punkt1: bubbla, punkt2: bubbla, punkt3: bubbla }, kvotFn);
  const stigande = buntprov(o, { punkt1: '#2f4437', punkt2: '#24382c', punkt3: '#17251d' },
    { punkt1: bubbla, punkt2: bubbla, punkt3: bubbla }, kvotFn);
  prov('GP-07', 'ordningen mellan delarna avgor inte konformans',
    fallande.ok && stigande.ok,
    'bade fallande och stigande serie ar godkanda — ordningen ar ett designdrag, inte kravets kalla'); }

/* GP-08 · ingen generell "varje del kraver 3:1" i kallan */
{ const kalla = readFileSync(new URL('./graphic-part-requirement.mjs', import.meta.url), 'utf8');
  const kod = kalla.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  const trosklar = [...kod.matchAll(/=\s*(\d+(?:\.\d+)?)\s*;/g)].map(m => m[1]);
  const villkorslos = /delar\.every\(.*3|alltid.*3\.0/.test(kod);
  const harBedomning = /begripligUtan/.test(kod);
  prov('GP-08', 'kallan kraver en bedomning per del och har ingen villkorslos treregel',
    !villkorslos && harBedomning && trosklar.every(t => t === '3.0'),
    'enda troskeln i koden ar ' + [...new Set(trosklar)].join(', ') +
    ' och den tillampas bara pa delar som bedomts kravda'); }

const ANTAL = 8;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('DELKRAVSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'delkravsprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
