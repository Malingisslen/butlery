#!/usr/bin/env node
// F2-NT · METODPROV FOR BORTFALLSPROVET OCH TILLAMPLIGHETEN.  GP-01 … GP-16

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { bortfallsprov, objektprov, buntprov, DELKLASS, KRAV_MOT_ANGRANSANDE }
  from './graphic-part-requirement.mjs';
import { TILLAMPLIGHET, LEDTRAD, UTFALL, tillamplighet, tillamplighetOberoendeAvKvot,
  konformansutfall } from './nontext-applicability.mjs';

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

/* ═══ TILLAMPLIGHET · GP-09 … GP-16 ═══════════════════════════════════
 *
 * FELET DESSA PROV FINNS FOR
 * Matningen hade en genvag: bar kontrollen synlig text sa var dess fyllning
 * och ram automatiskt supplemental, utan tillamplighetsfraga. Regeln ar for
 * bred. Den motsatta genvagen — "namntext racker, statustext racker inte" —
 * ar lika fel. Requiredness avgors ur den fulla visuella kontexten i den
 * faktiska forekomsten, och kvoten far aldrig avgora den.
 */
const bas = { harSynligText: true, ledtradar: [], ensamMaladDifferentiator: false,
  typografiskSkild: null, harGlyf: false, tillstandBerorGrafiken: false,
  manskligBedomning: null };

/* GP-09 · A · synlig knapptext + tydlig position/kontext => ramen FAR vara supplemental */
{ const r = tillamplighet({ ...bas, harGlyf: true,
    ledtradar: [LEDTRAD.GLYPH_PRESENT, LEDTRAD.TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT],
    typografiskSkild: true, ensamMaladDifferentiator: false });
  prov('GP-09', 'synlig knapptext med flera oberoende visuella ledtradar far ge ' +
    'TEXT_OR_CONTEXT_SUFFICIENT',
    r.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT && r.ledtradar.length >= 2,
    r.skal); }

/* GP-10 · B · synlig text i ett annars oskiljbart omrade => texten far INTE tvinga supplemental */
{ const r = tillamplighet({ ...bas, ensamMaladDifferentiator: true, harGlyf: false,
    typografiskSkild: false });
  const bara = tillamplighet({ ...bas, ensamMaladDifferentiator: true, typografiskSkild: null });
  prov('GP-10', 'synlig text ensam kan inte tvinga fram supplemental',
    r.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    bara.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY,
    'oskiljbart omrade ger ' + r.klass + '; obeslutbart ger ' + bara.klass); }

/* GP-11 · C · tillstandslik text ar varken automatiskt kravande eller tillracklig */
{ const oklar = tillamplighet({ ...bas, ensamMaladDifferentiator: true, typografiskSkild: true,
    ledtradar: [LEDTRAD.AUTHORED_INSTRUCTION_IN_CONTEXT] });
  const nog = tillamplighet({ ...bas, ensamMaladDifferentiator: false, typografiskSkild: true,
    ledtradar: [LEDTRAD.AUTHORED_INSTRUCTION_IN_CONTEXT,
      LEDTRAD.TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT] });
  const kalla = readFileSync(new URL('./nontext-applicability.mjs', import.meta.url), 'utf8');
  prov('GP-11', 'tillstandslik text ger varken automatiskt krav eller automatisk tillracklighet',
    oklar.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    nog.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    !/statustext|namntext/i.test(kalla.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '')),
    'samma tillstandslika text ger ' + oklar.klass + ' i ett fall och ' + nog.klass +
      ' i ett annat; koden bar ingen namn-mot-status-regel'); }

/* GP-12 · D · accessible-name-semantik avgor inte visuell requiredness */
{ const a = tillamplighet({ ...bas, ensamMaladDifferentiator: true, harGlyf: false,
    typografiskSkild: false });
  const b = tillamplighet({ ...bas, ensamMaladDifferentiator: true, harGlyf: false,
    typografiskSkild: false, harSynligText: false });
  prov('GP-12', 'tillgangligt namn eller dess semantik avgor inte den visuella requiredness',
    a.klass === b.klass,
    'med och utan synlig text ger samma klass ' + a.klass +
      ' nar de visuella dragen ar identiska'); }

/* GP-13 · E · kvot < 3 kan inte gora en valfri grafik kravd */
{ const f = { ...bas, ledtradar: [LEDTRAD.GLYPH_PRESENT, LEDTRAD.AUTHORED_INSTRUCTION_IN_CONTEXT],
    harGlyf: true, ensamMaladDifferentiator: false };
  const a = tillamplighetOberoendeAvKvot(f, 1.1);
  const b = tillamplighetOberoendeAvKvot(f, 9.9);
  const u = konformansutfall(a.klass, 1.1, KRAV_MOT_ANGRANSANDE);
  prov('GP-13', 'en kvot under troskeln kan inte gora en valfri grafik kravd',
    a.klass === b.klass && a.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    u.utfall === UTFALL.NOT_APPLICABLE,
    'kvot 1.1 och 9.9 ger samma klass ' + a.klass + ', och utfallet blir ' + u.utfall); }

/* GP-14 · F · kvot >= 3 kan inte gora en kravd grafik valfri */
{ const f = { ...bas, ensamMaladDifferentiator: true, harGlyf: false, typografiskSkild: false };
  const a = tillamplighetOberoendeAvKvot(f, 9.9);
  const u = konformansutfall(a.klass, 9.9, KRAV_MOT_ANGRANSANDE);
  prov('GP-14', 'en kvot over troskeln kan inte gora en kravd grafik valfri',
    a.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    u.utfall === UTFALL.PASS,
    'klassen star kvar som ' + a.klass + ' och utfallet blir ' + u.utfall +
      ' — kravd men godkand, inte omklassad'); }

/* GP-15 · G · andrad synlig text far paverka tillampligheten BARA nar texten
 * faktiskt deltar i den visuella identifieringsevidensen */
{ const deltar = { ...bas, ensamMaladDifferentiator: false, typografiskSkild: true,
    ledtradar: [LEDTRAD.TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT, LEDTRAD.GLYPH_PRESENT],
    harGlyf: true };
  const deltarInte = { ...deltar, typografiskSkild: false,
    ledtradar: [LEDTRAD.GLYPH_PRESENT, LEDTRAD.OTHER_PAINTED_DIFFERENTIATOR_ON_SAME_CONTROL] };
  const a = tillamplighet(deltar), b = tillamplighet(deltarInte);
  /* Texten byts men ingen VISUELL ledtrad andras -> klassen star still */
  const c = tillamplighet({ ...deltarInte, harSynligText: false });
  prov('GP-15', 'andrad text paverkar tillampligheten bara nar texten deltar i den visuella ' +
    'identifieringsevidensen',
    a.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    b.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    c.klass === b.klass,
    'nar typografiledtraden faller bort star klassen kvar pa ovriga ledtradar; att ta bort ' +
      'texten utan att andra en enda visuell ledtrad ger ' + c.klass); }

/* GP-16 · H · tillstandsgrafik bedoms sjalvstandigt nar den kravs */
{ const stat = tillamplighet({ ...bas, ensamMaladDifferentiator: true, harGlyf: false,
    typografiskSkild: false, tillstandBerorGrafiken: true });
  const ident = tillamplighet({ ...bas, ensamMaladDifferentiator: true, harGlyf: false,
    typografiskSkild: false, tillstandBerorGrafiken: false });
  prov('GP-16', 'tillstandsgrafik far en egen kravklass och blandas inte ihop med identiteten',
    stat.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE &&
    ident.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    stat.klass !== ident.klass,
    'samma visuella drag ger ' + stat.klass + ' nar tillstandet beror pa grafiken och ' +
      ident.klass + ' nar det inte gor det'); }

const ANTAL = 16;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('DELKRAVSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'delkravsprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
