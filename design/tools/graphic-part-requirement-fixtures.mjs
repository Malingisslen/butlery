#!/usr/bin/env node
// F2-NT · METODPROV FOR BORTFALLSPROVET OCH TILLAMPLIGHETEN.  GP-01 … GP-25

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { bortfallsprov, objektprov, buntprov, DELKLASS, KRAV_MOT_ANGRANSANDE }
  from './graphic-part-requirement.mjs';
import { TILLAMPLIGHET, LEDTRAD, STYRKA, UTFALL, tillamplighet,
  tillamplighetOberoendeAvKvot, konformansutfall } from './nontext-applicability.mjs';

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

/* ═══ TILLAMPLIGHET · GP-09 … GP-25 ═══════════════════════════════════
 *
 * FELET DESSA PROV FINNS FOR
 * Matningen hade en genvag: bar kontrollen synlig text sa var dess fyllning
 * och ram automatiskt supplemental, utan tillamplighetsfraga. Regeln ar for
 * bred. Den motsatta genvagen — "namntext racker, statustext racker inte" —
 * ar lika fel.
 *
 * OCH EN ANDRA RATTNING, 2026-08-16
 * Den forsta korrigeringen inforde "minst tva oberoende ledtradar" som grind.
 * Det ar heller ingen giltig normativ regel. SC 1.4.11 vilar pa TILLRACKLIGHET
 * i den faktiska scenen. EN stark signal kan racka; flera svaga kan vara
 * otillrackliga. GP-09 och GP-11 bar darfor omskrivna assertions — samma id,
 * samma avsikt, men styrka i stallet for antal. Den gamla lydelsen star kvar
 * i commit 485ca59.
 */
const bas = { harSynligText: true, bedomdaLedtradar: [],
  ingenAlternativIdentifiering: false, tillstandBerorGrafiken: false,
  manskligBedomning: null };
const stark = (l, skal) => ({ ledtrad: l, styrka: STYRKA.STARK, skal });
const svag = (l, skal) => ({ ledtrad: l, styrka: STYRKA.SVAG, skal });

/* GP-09 · A · synlig knapptext med en STARK kontextsignal => ramen far vara supplemental */
{ const r = tillamplighet({ ...bas,
    bedomdaLedtradar: [stark(LEDTRAD.AUTHORED_INSTRUCTION_IN_CONTEXT,
      'skarmens egen instruktion pekar ut interaktionen med just detta objekt')] });
  prov('GP-09', 'synlig knapptext med en stark kontextsignal far ge TEXT_OR_CONTEXT_SUFFICIENT',
    r.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT && r.diagnostik.starka.length === 1,
    r.skal); }

/* GP-10 · B · synlig text i ett annars oskiljbart omrade => texten far INTE tvinga supplemental */
{ const r = tillamplighet({ ...bas, ingenAlternativIdentifiering: true });
  const bara = tillamplighet({ ...bas });
  prov('GP-10', 'synlig text ensam kan inte tvinga fram supplemental',
    r.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    bara.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY,
    'oskiljbart omrade ger ' + r.klass + '; obeslutbart ger ' + bara.klass); }

/* GP-11 · C · tillstandslik text ar varken automatiskt kravande eller tillracklig */
{ const oklar = tillamplighet({ ...bas,
    bedomdaLedtradar: [svag(LEDTRAD.AUTHORED_INSTRUCTION_IN_CONTEXT, 'generell text i narheten')] });
  const nog = tillamplighet({ ...bas,
    bedomdaLedtradar: [stark(LEDTRAD.AUTHORED_INSTRUCTION_IN_CONTEXT,
      'instruktionen pekar ut just detta objekt')] });
  const kalla = readFileSync(new URL('./nontext-applicability.mjs', import.meta.url), 'utf8');
  const kod = kalla.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  prov('GP-11', 'tillstandslik text ger varken automatiskt krav eller automatisk tillracklighet',
    oklar.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    nog.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    !/statustext|namntext/i.test(kod),
    'samma tillstandslika text ger ' + oklar.klass + ' som svag signal och ' + nog.klass +
      ' som stark; koden bar ingen namn-mot-status-regel'); }

/* GP-12 · D · accessible-name-semantik avgor inte visuell requiredness */
{ const a = tillamplighet({ ...bas, ingenAlternativIdentifiering: true });
  const b = tillamplighet({ ...bas, ingenAlternativIdentifiering: true, harSynligText: false });
  prov('GP-12', 'tillgangligt namn eller dess semantik avgor inte den visuella requiredness',
    a.klass === b.klass,
    'med och utan synlig text ger samma klass ' + a.klass +
      ' nar de visuella dragen ar identiska'); }

/* GP-13 · E · kvot < 3 kan inte gora en valfri grafik kravd */
{ const f = { ...bas, bedomdaLedtradar: [stark(LEDTRAD.CONTROL_CONTENT_ITSELF,
    'ikonen ar sjalv kontrollen')] };
  const a = tillamplighetOberoendeAvKvot(f, 1.1);
  const b = tillamplighetOberoendeAvKvot(f, 9.9);
  const u = konformansutfall(a.klass, 1.1, KRAV_MOT_ANGRANSANDE);
  prov('GP-13', 'en kvot under troskeln kan inte gora en valfri grafik kravd',
    a.klass === b.klass && a.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    u.utfall === UTFALL.NOT_APPLICABLE,
    'kvot 1.1 och 9.9 ger samma klass ' + a.klass + ', och utfallet blir ' + u.utfall); }

/* GP-14 · F · kvot >= 3 kan inte gora en kravd grafik valfri */
{ const f = { ...bas, ingenAlternativIdentifiering: true };
  const a = tillamplighetOberoendeAvKvot(f, 9.9);
  const u = konformansutfall(a.klass, 9.9, KRAV_MOT_ANGRANSANDE);
  prov('GP-14', 'en kvot over troskeln kan inte gora en kravd grafik valfri',
    a.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    u.utfall === UTFALL.PASS,
    'klassen star kvar som ' + a.klass + ' och utfallet blir ' + u.utfall +
      ' — kravd men godkand, inte omklassad'); }

/* GP-15 · G · andrad text paverkar bara nar texten deltar i evidensen */
{ const deltar = { ...bas,
    bedomdaLedtradar: [stark(LEDTRAD.TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT,
      'texten ar satt som en handling och skiljer sig tydligt fran brodtexten')] };
  const deltarInte = { ...bas,
    bedomdaLedtradar: [stark(LEDTRAD.ESTABLISHED_POSITION_IN_LAYOUT,
      'objektet star i den etablerade atgardsraden langst ned')] };
  const a = tillamplighet(deltar), b = tillamplighet(deltarInte);
  const c = tillamplighet({ ...deltarInte, harSynligText: false });
  prov('GP-15', 'andrad text paverkar tillampligheten bara nar texten deltar i den visuella ' +
    'identifieringsevidensen',
    a.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    b.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT && c.klass === b.klass,
    'nar identifieringen vilar pa positionen andras ingenting av att texten tas bort: ' + c.klass); }

/* GP-16 · H · tillstandsgrafik bedoms sjalvstandigt nar den kravs */
{ const stat = tillamplighet({ ...bas, ingenAlternativIdentifiering: true,
    tillstandBerorGrafiken: true });
  const ident = tillamplighet({ ...bas, ingenAlternativIdentifiering: true });
  prov('GP-16', 'tillstandsgrafik far en egen kravklass och blandas inte ihop med identiteten',
    stat.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE &&
    ident.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    stat.klass !== ident.klass,
    'samma visuella drag ger ' + stat.klass + ' nar tillstandet beror pa grafiken och ' +
      ident.klass + ' nar det inte gor det'); }

/* ── ANDRA RATTNINGEN · GP-17 … GP-25 ────────────────────────────────*/

/* GP-17 · A · EN stark kontextsignal kan racka */
{ const r = tillamplighet({ ...bas,
    bedomdaLedtradar: [stark(LEDTRAD.AUTHORED_INSTRUCTION_IN_CONTEXT,
      'skarmen sager "tryck pa en ledig plats" och objektet ar en ledig plats')] });
  prov('GP-17', 'en ensam stark kontextsignal kan racka for tillracklighet',
    r.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT && r.diagnostik.antalLedtradar === 1,
    'en enda ledtrad, bedomd stark, ger ' + r.klass); }

/* GP-18 · B · EN stark positionssignal kan racka */
{ const r = tillamplighet({ ...bas,
    bedomdaLedtradar: [stark(LEDTRAD.ESTABLISHED_POSITION_IN_LAYOUT,
      'objektet star i skarmens etablerade atgardsrad')] });
  prov('GP-18', 'en ensam stark positionssignal kan racka for tillracklighet',
    r.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT && r.diagnostik.antalLedtradar === 1,
    'en enda positionsledtrad, bedomd stark, ger ' + r.klass); }

/* GP-19 · C · TVA SVAGA racker inte automatiskt */
{ const r = tillamplighet({ ...bas, bedomdaLedtradar: [
    svag(LEDTRAD.ESTABLISHED_POSITION_IN_LAYOUT, 'svag placering, inget etablerat monster'),
    svag(LEDTRAD.TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT, 'vanlig brodtext, knappt skild')] });
  const tre = tillamplighet({ ...bas, bedomdaLedtradar: [
    svag(LEDTRAD.ESTABLISHED_POSITION_IN_LAYOUT, 'svag'),
    svag(LEDTRAD.TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT, 'svag'),
    svag(LEDTRAD.GLYPH_PRESENT, 'svag')] });
  prov('GP-19', 'tva eller flera svaga ledtradar ger inte automatiskt tillracklighet',
    r.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    tre.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY,
    'tva svaga ger ' + r.klass + ' och tre svaga ger ' + tre.klass); }

/* GP-20 · D · ANTALET far aldrig avgora */
{ const enStark = tillamplighet({ ...bas,
    bedomdaLedtradar: [stark(LEDTRAD.CONTROL_CONTENT_ITSELF, 'innehallet ar sjalv kontrollen')] });
  const fyraSvaga = tillamplighet({ ...bas, bedomdaLedtradar: [
    svag(LEDTRAD.GLYPH_PRESENT, 's'), svag(LEDTRAD.ESTABLISHED_POSITION_IN_LAYOUT, 's'),
    svag(LEDTRAD.TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT, 's'),
    svag(LEDTRAD.OTHER_PAINTED_DIFFERENTIATOR_ON_SAME_CONTROL, 's')] });
  const kalla = readFileSync(new URL('./nontext-applicability.mjs', import.meta.url), 'utf8');
  const kod = kalla.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  const harRaknegrind = /MINST_ANTAL|length\s*>=\s*\d/.test(kod);
  prov('GP-20', 'antalet ledtradar kan aldrig avgora requiredness',
    enStark.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    fyraSvaga.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    fyraSvaga.diagnostik.antalLedtradar > enStark.diagnostik.antalLedtradar &&
    !harRaknegrind,
    '1 stark ger ' + enStark.klass + ' och 4 svaga ger ' + fyraSvaga.klass +
      '; ingen rakningsgrind finns kvar i kallan'); }

/* GP-21 · E · synlig text ar fortfarande inte avgorande */
{ const a = tillamplighet({ ...bas, harSynligText: true });
  const b = tillamplighet({ ...bas, harSynligText: false });
  prov('GP-21', 'synlig text ar fortfarande inte avgorande i nagon riktning',
    a.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY && a.klass === b.klass,
    'med och utan synlig text ger samma klass ' + a.klass); }

/* GP-22 · F · lag kontrast kan inte etablera krav */
{ const f = { ...bas, bedomdaLedtradar: [stark(LEDTRAD.AUTHORED_INSTRUCTION_IN_CONTEXT, 'stark')] };
  const r = tillamplighetOberoendeAvKvot(f, 1.0);
  prov('GP-22', 'lag kontrast kan inte etablera requiredness',
    r.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    konformansutfall(r.klass, 1.0, KRAV_MOT_ANGRANSANDE).utfall === UTFALL.NOT_APPLICABLE,
    'kvot 1.0 lamnar klassen ' + r.klass); }

/* GP-23 · G · hog kontrast kan inte etablera icke-krav */
{ const f = { ...bas, ingenAlternativIdentifiering: true };
  const r = tillamplighetOberoendeAvKvot(f, 21);
  prov('GP-23', 'hog kontrast kan inte etablera non-requiredness',
    r.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL,
    'kvot 21 lamnar klassen ' + r.klass); }

/* GP-24 · H · ett inmatningsfalt vars ram ar enda indikationen forblir KRAVD */
{ const r = tillamplighet({ ...bas, harSynligText: true, ingenAlternativIdentifiering: true,
    bedomdaLedtradar: [svag(LEDTRAD.TYPOGRAPHY_DISTINCT_FROM_NEIGHBOURING_TEXT,
      'faltets varde ar satt som vanlig text')] });
  const u = konformansutfall(r.klass, 1.414, KRAV_MOT_ANGRANSANDE);
  prov('GP-24', 'ett inmatningsfalt vars ram ar den enda visuella indikationen forblir kravd',
    r.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    u.utfall === UTFALL.FINDING,
    'faltet har synlig text och en svag ledtrad, men ingen alternativ identifiering: ' +
      r.klass + ' → ' + u.utfall); }

/* GP-25 · I · en knapp i stark kontext far vara supplemental utan kontrasterande ram */
{ const r = tillamplighet({ ...bas, harSynligText: true,
    bedomdaLedtradar: [stark(LEDTRAD.ESTABLISHED_POSITION_IN_LAYOUT,
      'skarmens etablerade primara atgardsplats, samma plats i hela flodet')] });
  const u = konformansutfall(r.klass, 1.2, KRAV_MOT_ANGRANSANDE);
  prov('GP-25', 'en knapp i stark etablerad kontext far vara supplemental aven utan ' +
    'kontrasterande ram',
    r.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT && u.utfall === UTFALL.NOT_APPLICABLE,
    'stark positionskontext ger ' + r.klass + ' och utfallet ' + u.utfall + ' trots kvot 1.2'); }

const ANTAL = 25;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('DELKRAVSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'delkravsprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
