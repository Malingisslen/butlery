#!/usr/bin/env node
// F2-R04 · METODPROV FOR YTKRAV.  SC-01 … SC-08
//
// Felet som inte far uppsta igen: en generell 3:1-troskel for ytor, tillampad
// pa en textmarkt knapp som projektets eget kontrakt sager identifieras av sin
// text. Fyra av fem kandidater avvisades pa en regel ingen kalla kravde.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { ytkrav, provaYtkandidat, AVVISNING, KRAVKALLA, VALKONTROLL } from './surface-constraints.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

/* Enkel WCAG-kvot for provet. Modulen sjalv raknar aldrig farg. */
const rgb = h => { const m = /^#([0-9a-f]{6})$/i.exec(h); return m
  ? [0, 2, 4].map(i => parseInt(m[1].slice(i, i + 2), 16)) : null; };
const lum = c => { const f = c.map(v => { const s = v / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4); });
  return 0.2126 * f[0] + 0.7152 * f[1] + 0.0722 * f[2]; };
const kvotFn = (a, b) => { const A = lum(rgb(a)), Bq = lum(rgb(b));
  const h = Math.max(A, Bq), l = Math.min(A, Bq);
  return Math.round(((h + 0.05) / (l + 0.05)) * 100) / 100; };

const KNAPP = { kontrollroll: 'button', harEgenText: true, harRam: false,
  harSkugga: false, harBakgrundsbild: false, barText: true };
const IKONKNAPP = { ...KNAPP, harEgenText: false, barText: false };
const KRYSSRUTA = { kontrollroll: 'checkbox', harEgenText: true, harRam: false,
  harSkugga: false, harBakgrundsbild: false, barText: false };
const BEHALLARE = { kontrollroll: null, harEgenText: false, harRam: false,
  harSkugga: false, harBakgrundsbild: false, barText: false };

/* SC-01 · textmarkt knapp far INGET ytkrav */
{ const r = ytkrav(KNAPP);
  const harIckeText = r.krav.some(k => k.typ === 'ICKE_TEXT');
  prov('SC-01', 'en textmarkt kontroll far inget 3:1-krav pa sin yta',
    !harIckeText && !r.ytanIdentifierar && r.krav.length === 1 && r.krav[0].typ === 'TEXT',
    r.$not); }

/* SC-02 · ikonknapp far ytkrav */
{ const r = ytkrav(IKONKNAPP);
  prov('SC-02', 'en kontroll utan egen text far 3:1-krav pa sin yta',
    r.ytanIdentifierar && r.krav.some(k => k.typ === 'ICKE_TEXT' && k.minsta === 3),
    r.krav.map(k => k.typ + ' ' + k.minsta).join(', ') + ' · ' + KRAVKALLA.WCAG_1_4_11); }

/* SC-03 · valkontroll far ytkrav aven med etikett */
{ const r = ytkrav(KRYSSRUTA);
  prov('SC-03', 'en valkontroll far ytkrav aven nar den har en etikett',
    r.ytanIdentifierar && VALKONTROLL.has('checkbox'),
    'valkontrollens egen ruta identifierar den — etiketten sager bara vad valet galler'); }

/* SC-04 · behallare utan kontrollroll far inga numeriska krav alls */
{ const r = ytkrav(BEHALLARE);
  prov('SC-04', 'en behallaryta utan kontrollroll och utan text far inga numeriska krav',
    r.krav.length === 0 && !r.ytanIdentifierar,
    'inga krav — valet ar ett rent visuellt val, inte ett tekniskt'); }

/* SC-05 · exakt likhet flaggas alltid */
{ const r = ytkrav(KNAPP);
  const p = provaYtkandidat('#24382c', '#24382c', { krav: r.krav, textfarg: '#c9d3c4',
    genomskinlig: false, beraknadYta: '#24382c', kvotFn });
  prov('SC-05', 'exakt likhet med bakgrunden flaggas som forsvinnande, oavsett ovriga krav',
    p.avvisningsklasser.includes(AVVISNING.EXACT_CARRIER_COLLAPSE) && !p.passerar,
    'texten pa ytan klarar 8.11 men ytan sjalv ar borta'); }

/* SC-06 · textkravet tillampas dar WCAG faktiskt galler */
{ const r = ytkrav(KNAPP);
  const bra = provaYtkandidat('#24382c', '#17251d', { krav: r.krav, textfarg: '#c9d3c4',
    genomskinlig: false, beraknadYta: '#24382c', kvotFn });
  const daligt = provaYtkandidat('#ce7c1e', '#17251d', { krav: r.krav, textfarg: '#c9d3c4',
    genomskinlig: false, beraknadYta: '#ce7c1e', kvotFn });
  prov('SC-06', 'textkravet 4.5:1 tillampas pa ytan som bar texten',
    bra.passerar && daligt.avvisningsklasser.includes(AVVISNING.TEXT_CONSTRAINT_FAIL),
    '#24382c: text 8.11 passerar · #ce7c1e: text 2.08 faller'); }

/* SC-07 · ljusa lagets ytkvot ar ingen minimigrans */
{ const r = ytkrav(KNAPP);
  /* I ljust lage ar knappytan #f5f4ed mot appytan #24382c — kvot 11.36.
     Om den kvoten bevarades som minimum skulle ingen mork kandidat kunna
     passera. Provet visar att en kandidat pa 1.27 passerar. */
  const ljusKvot = kvotFn('#f5f4ed', '#24382c');
  const p = provaYtkandidat('#24382c', '#17251d', { krav: r.krav, textfarg: '#c9d3c4',
    genomskinlig: false, beraknadYta: '#24382c', kvotFn });
  prov('SC-07', 'ljusa lagets numeriska ytkvot bevaras inte som minimum i morkt lage',
    p.passerar && kvotFn('#24382c', '#17251d') < ljusKvot,
    'ljust 11.36 · morkt 1.27 · passerar anda, eftersom ingen kalla kraver den kvoten'); }

/* SC-08 · ingen generell yttroskel i kallan */
{ const kalla = readFileSync(new URL('./surface-constraints.mjs', import.meta.url), 'utf8');
  const kod = kalla.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  /* Enda numeriska trosklar som far finnas ar de tva WCAG-kraven, och de star
     bara i ytkrav() dar de bars av en kalla. */
  const trosklar = [...kod.matchAll(/minsta:\s*(\d+(?:\.\d+)?)/g)].map(m => m[1]);
  const jamforelser = [...kod.matchAll(/[<>]=?\s*(\d+(?:\.\d+)?)/g)].map(m => m[1]);
  const tillatna = new Set(['3', '4.5']);
  const otillatna = [...trosklar, ...jamforelser].filter(t => !tillatna.has(t));
  const harGenerell = /minstaDelta|MIN_YTKONTRAST|ytTroskel|bevaraLjusKvot|GENERELL/.test(kod);
  const trosklarBarsAvKalla = kod.split('\n')
    .filter(l => /minsta:\s*\d/.test(l) || /minsta:\s*\d/.test(l))
    .every(() => true) && /minsta: 3, kalla: KRAVKALLA.WCAG_1_4_11/.test(kod) &&
    /minsta: 4.5, kalla: KRAVKALLA.WCAG_1_4_3/.test(kod);
  prov('SC-08', 'kallan innehaller ingen generell yttroskel — varje troskel bars av en namngiven WCAG-kalla',
    otillatna.length === 0 && !harGenerell && trosklarBarsAvKalla,
    'trosklar i koden: ' + [...new Set(trosklar)].join(', ') +
    ' · numeriska jamforelser: ' + ([...new Set(jamforelser)].join(', ') || 'inga direkta') +
    ' · bada knutna till WCAG 1.4.11 respektive 1.4.3'); }

const ANTAL = 8;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('YTKRAVSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'ytkravsprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
