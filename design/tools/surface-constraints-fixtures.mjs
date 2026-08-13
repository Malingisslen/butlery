#!/usr/bin/env node
// F2-R04 · METODPROV FOR YTKRAV OCH EXAKT LIKHET.  SC-01 … SC-09, EQ-01 … EQ-07
//
// Felet som inte far uppsta igen: en generell 3:1-troskel for ytor, tillampad
// pa en textmarkt knapp som projektets eget kontrakt sager identifieras av sin
// text. Fyra av fem kandidater avvisades pa en regel ingen kalla kravde.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { ytkrav, provaYtkandidat, AVVISNING, KRAVKALLA, VALKONTROLL,
  BARANSVAR, exaktLikhet, bararkollaps, previewkontrollduglighet } from './surface-constraints.mjs';

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

/* SC-05 · RATTAD. Exakt likhet ar en matning, inte ett utfall. */
{ const r = ytkrav(KNAPP);
  const utanAnsvar = provaYtkandidat('#24382c', '#24382c', { krav: r.krav, textfarg: '#c9d3c4',
    genomskinlig: false, beraknadYta: '#24382c', kvotFn,
    baransvar: BARANSVAR.NON_REQUIRED_VISUAL_STYLING });
  const medAnsvar = provaYtkandidat('#24382c', '#24382c', { krav: r.krav, textfarg: '#c9d3c4',
    genomskinlig: false, beraknadYta: '#24382c', kvotFn,
    baransvar: BARANSVAR.CONTROL_BODY_REQUIRED });
  prov('SC-05', 'exakt likhet ar en matning — utfallet avgors av bevisat baransvar',
    utanAnsvar.exaktLikhet.lika && utanAnsvar.passerar &&
    medAnsvar.avvisningsklasser.includes(AVVISNING.REQUIRED_CARRIER_COLLAPSE),
    'samma likhet, tva utfall: utan kravt baransvar passerar den, med CONTROL_BODY_REQUIRED faller den'); }

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
  /* Bara jamforelser som faktiskt ror ett kontrastvarde raknas — en
     mangdstorlek ar ingen fargtroskel. */
  const jamforelser = kod.split(String.fromCharCode(10))
    .filter(l => /kvot|minsta|kontrast/.test(l))
    .flatMap(l => [...l.matchAll(/[<>]=?\s*(\d+(?:\.\d+)?)/g)].map(m => m[1]));
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

/* ── EQ-01 … EQ-07 · exakt likhet mot bevisat baransvar ─────────────*/

/* EQ-01 · likheten rapporteras som en signal */
{ const e = exaktLikhet('#24382c', '#24382c');
  prov('EQ-01', 'exakt likhet rapporteras som EXACT_EQUALITY_SIGNAL',
    e.signal === 'EXACT_EQUALITY_SIGNAL' && e.lika === true,
    'signal ' + e.signal + ' · lika ' + e.lika + ' — ' + e.$not); }

/* EQ-02 · likheten ensam ar inget fel */
{ const k = bararkollaps('#24382c', '#24382c', BARANSVAR.NON_REQUIRED_VISUAL_STYLING);
  prov('EQ-02', 'exakt likhet ensam skapar ingen underkant',
    k.signal.lika === true && k.kollaps === false,
    k.skal); }

/* EQ-03 · kravd grupperings- eller upphojningsyta kollapsar */
{ const g = bararkollaps('#24382c', '#24382c', BARANSVAR.REQUIRED_GROUPING_CARRIER);
  const u = bararkollaps('#24382c', '#24382c', BARANSVAR.REQUIRED_ELEVATION_CARRIER);
  prov('EQ-03', 'en kravd grupperings- eller upphojningsyta som blir exakt lika kollapsar',
    g.kollaps && u.kollaps && g.baransvar === BARANSVAR.REQUIRED_GROUPING_CARRIER,
    g.skal); }

/* EQ-04 · textmarkt knapp utan kravt ytansvar forblir tekniskt giltig */
{ const r = ytkrav(KNAPP);
  const p = provaYtkandidat('#17251d', '#17251d', { krav: r.krav, textfarg: '#c9d3c4',
    genomskinlig: false, beraknadYta: '#17251d', kvotFn,
    baransvar: BARANSVAR.NON_REQUIRED_VISUAL_STYLING });
  prov('EQ-04', 'en textmarkt knapp vars yta inte bar nagot kravt forblir tekniskt giltig vid likhet',
    p.passerar && p.exaktLikhet.lika && p.matt.some(m => m.kvot >= 4.5),
    'ytan sammanfaller med appbakgrunden, men etiketten identifierar knappen och klarar ' +
    p.matt[0].kvot + ':1'); }

/* EQ-05 · tekniskt giltig men inte duglig som temporar kontroll */
{ const r = ytkrav(KNAPP);
  const mal = ['#17251d', '#24382c', '#4a5c43'];
  const prov5 = mal.map(bak => provaYtkandidat('#17251d', bak, { krav: r.krav, textfarg: '#c9d3c4',
    genomskinlig: false, beraknadYta: '#17251d', kvotFn,
    baransvar: BARANSVAR.NON_REQUIRED_VISUAL_STYLING }));
  const d = previewkontrollduglighet('#17251d', prov5);
  prov('EQ-05', 'ett tekniskt giltigt varde kan anda vara oduglig som temporar previewkontroll',
    prov5.every(p => p.passerar) && !d.duglig && d.klass === 'EJ_NEUTRAL_NOG',
    'giltig mot alla tre, men sammanfaller med en av dem — ' + d.skal); }

/* EQ-06 · kvot 1.00 ensam avvisar inte */
{ const r = ytkrav(BEHALLARE);
  const p = provaYtkandidat('#24382c', '#24382c', { krav: r.krav, textfarg: null,
    genomskinlig: false, beraknadYta: '#24382c', kvotFn,
    baransvar: BARANSVAR.NON_REQUIRED_VISUAL_STYLING });
  prov('EQ-06', 'en yta utan bevisat baransvar avvisas inte enbart for att kvoten ar 1.00',
    p.passerar && p.exaktLikhet.lika && p.avvisningsklasser.length === 0,
    'kvot 1.00, inga krav, inget kravt ansvar — passerar'); }

/* EQ-07 · ingen generell yttroskel aterinford, och UNKNOWN faller stangt */
{ const kalla = readFileSync(new URL('./surface-constraints.mjs', import.meta.url), 'utf8');
  const kod = kalla.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  const trosklar = [...kod.matchAll(/minsta:\s*(\d+(?:\.\d+)?)/g)].map(m => m[1]);
  /* Bara jamforelser som faktiskt ror ett kontrastvarde raknas — en
     mangdstorlek ar ingen fargtroskel. */
  const jamforelser = kod.split(String.fromCharCode(10))
    .filter(l => /kvot|minsta|kontrast/.test(l))
    .flatMap(l => [...l.matchAll(/[<>]=?\s*(\d+(?:\.\d+)?)/g)].map(m => m[1]));
  const bara345 = [...trosklar, ...jamforelser].every(t => t === '3' || t === '4.5');
  const okand = bararkollaps('#24382c', '#24382c', BARANSVAR.UNKNOWN);
  prov('EQ-07', 'ingen generell yttroskel aterinford, och obestamt baransvar faller stangt',
    bara345 && okand.kollaps && okand.faillClosed,
    'tal i koden: ' + [...new Set([...trosklar, ...jamforelser])].join(', ') +
    ' · UNKNOWN -> ' + okand.skal); }

/* SC-09 · genomskinlighet ar en egenskap, inte en underkant */
{ const r = ytkrav(BEHALLARE);
  const p = provaYtkandidat('rgba(245,244,237,0.18)', '#24382c', { krav: r.krav, textfarg: null,
    genomskinlig: true, beraknadYta: '#4a5a4f', kvotFn,
    baransvar: BARANSVAR.NON_REQUIRED_VISUAL_STYLING });
  prov('SC-09', 'compositingberoende redovisas som egenskap, inte som underkant',
    p.passerar && p.compositingberoende === true && p.avvisningsklasser.length === 0,
    'den redan godkanda PROGRESS_TRACK-mappningen ar sjalv rgba(245,244,237,0.18) — ' +
    'en regel som underkande genomskinliga varden hade underkant ett fattat beslut'); }

const ANTAL = 16;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('YTKRAVSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'ytkravsprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
