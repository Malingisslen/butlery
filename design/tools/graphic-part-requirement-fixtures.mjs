#!/usr/bin/env node
// F2-NT · METODPROV FOR BORTFALLSPROVET OCH TILLAMPLIGHETEN.  GP-01 … GP-35

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { bortfallsprov, objektprov, buntprov, DELKLASS, KRAV_MOT_ANGRANSANDE }
  from './graphic-part-requirement.mjs';
import { TILLAMPLIGHET, UTFALL, tillamplighet, tillamplighetOberoendeAvKvot,
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

/* ═══ TILLAMPLIGHET · GP-09 … GP-35 ═══════════════════════════════════
 *
 * TVA UPPFUNNA GRINDAR HAR TAGITS BORT, I TUR OCH ORDNING
 *   485ca59  "minst tva oberoende ledtradar"  — en RAKNING
 *   e7346ae  STARK / SVAG per ledtrad          — en STYRKETAXONOMI
 * Ingen av dem ar en giltig normativ regel. SC 1.4.11 vilar pa
 * TILLRACKLIGHET av visuell identifiering i den faktiska scenen, betraktad
 * SOM HELHET.
 *
 * TESTLINEAGE
 * Sex prov bar assertions som var utsagor OM de borttagna grindarna. De far
 * inte fortsatta bara nya pastaenden under samma id. De ar PENSIONERADE
 * nedan, med bada sina historiska lydelser bevarade, och de provar numera
 * bara att de ar pensionerade och att grindarna ar borta ur kallan.
 * Ovriga prov har oforandrad utsaga och ar bara omskrivna mot det nya
 * API:t — det ar en anpassning, inte en ny utsaga.
 */
const KALLA = readFileSync(new URL('./nontext-applicability.mjs', import.meta.url), 'utf8');
const KOD = KALLA.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');

/* Pensionerade id:n, med full lineage. */
const PENSIONERADE = {
  'GP-09': { v1: '485ca59 · "synlig knapptext med FLERA oberoende ledtradar far ge SUFFICIENT"',
    v2: 'e7346ae · "synlig knapptext med en STARK kontextsignal far ge SUFFICIENT"',
    varfor: 'bada lydelserna var utsagor om en uppfunnen grind — forst antal, sedan styrka' },
  'GP-11': { v1: '485ca59 · "tillstandslik text… en respektive tva ledtradar"',
    v2: 'e7346ae · "tillstandslik text… svag respektive stark signal"',
    varfor: 'samma sak: pastaendet vilade pa grinden, inte pa tillrackligheten' },
  'GP-17': { v1: 'e7346ae · "en ensam STARK kontextsignal kan racka"', v2: null,
    varfor: 'utsagan handlar om styrkeenumet, som ar borttaget' },
  'GP-18': { v1: 'e7346ae · "en ensam STARK positionssignal kan racka"', v2: null,
    varfor: 'samma' },
  'GP-19': { v1: 'e7346ae · "tva eller flera SVAGA racker inte"', v2: null,
    varfor: 'samma' },
  'GP-25': { v1: 'e7346ae · "en knapp i STARK etablerad kontext far vara supplemental"', v2: null,
    varfor: 'samma' } };
for (const [id, h] of Object.entries(PENSIONERADE))
  prov(id, 'PENSIONERAT — RETIRED_METHOD_INVALID: ' + h.varfor,
    !/STYRKA|STARK|SVAG|MINST_ANTAL|hasStrong|strongCount/.test(KOD),
    'lydelser bevarade: ' + [h.v1, h.v2].filter(Boolean).join('  ||  ') +
      '. Provet gor numera ingen utsaga om metoden och ersatts av nya id:n.');

/* Bas for de anpassade och de nya proven. */
const bas = { harSynligText: true, evidens: [], holistiskBedomning: null,
  bedomningsskal: null, tillstandBerorGrafiken: false };

/* GP-10 · ANPASSAT · synlig text ensam kan inte tvinga fram supplemental */
{ const bara = tillamplighet({ ...bas });
  const kravd = tillamplighet({ ...bas, holistiskBedomning: 'NOT_SUFFICIENT',
    bedomningsskal: 'utan ramen ar objektet oskiljbart fran den statiska texten' });
  prov('GP-10', 'synlig text ensam kan inte tvinga fram supplemental',
    bara.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    kravd.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL,
    'enbart synlig text ger ' + bara.klass + '; en holistisk bedomning ger ' + kravd.klass); }

/* GP-12 · ANPASSAT · accessible-name-semantik avgor inte visuell requiredness */
{ const a = tillamplighet({ ...bas, harSynligText: true });
  const b = tillamplighet({ ...bas, harSynligText: false });
  prov('GP-12', 'tillgangligt namn eller dess semantik avgor inte den visuella requiredness',
    a.klass === b.klass && a.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY,
    'med och utan synlig text ger samma klass ' + a.klass); }

/* GP-13 · ANPASSAT · kvot < 3 kan inte gora en valfri grafik kravd */
{ const f = { ...bas, holistiskBedomning: 'SUFFICIENT', bedomningsskal: 'scenen racker' };
  const a = tillamplighetOberoendeAvKvot(f, 1.1);
  const b = tillamplighetOberoendeAvKvot(f, 9.9);
  const u = konformansutfall(a.klass, 1.1, KRAV_MOT_ANGRANSANDE);
  prov('GP-13', 'en kvot under troskeln kan inte gora en valfri grafik kravd',
    a.klass === b.klass && a.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    u.utfall === UTFALL.NOT_APPLICABLE,
    'kvot 1.1 och 9.9 ger samma klass ' + a.klass + ', och utfallet blir ' + u.utfall); }

/* GP-14 · ANPASSAT · kvot >= 3 kan inte gora en kravd grafik valfri */
{ const f = { ...bas, holistiskBedomning: 'NOT_SUFFICIENT', bedomningsskal: 'scenen racker inte' };
  const a = tillamplighetOberoendeAvKvot(f, 9.9);
  const u = konformansutfall(a.klass, 9.9, KRAV_MOT_ANGRANSANDE);
  prov('GP-14', 'en kvot over troskeln kan inte gora en kravd grafik valfri',
    a.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    u.utfall === UTFALL.PASS,
    'klassen star kvar som ' + a.klass + ' och utfallet blir ' + u.utfall); }

/* GP-15 · ANPASSAT · andrad text paverkar bara nar texten deltar i evidensen */
{ const a = tillamplighet({ ...bas, holistiskBedomning: 'SUFFICIENT',
    evidens: ['positionen i den etablerade atgardsraden'], harSynligText: true });
  const b = tillamplighet({ ...bas, holistiskBedomning: 'SUFFICIENT',
    evidens: ['positionen i den etablerade atgardsraden'], harSynligText: false });
  prov('GP-15', 'andrad text paverkar tillampligheten bara nar texten deltar i den visuella ' +
    'identifieringsevidensen',
    a.klass === b.klass,
    'nar bedomningen vilar pa positionen andras ingenting av att texten tas bort: ' + b.klass); }

/* GP-16 · ANPASSAT · tillstandsgrafik far en egen kravklass */
{ const stat = tillamplighet({ ...bas, holistiskBedomning: 'NOT_SUFFICIENT',
    tillstandBerorGrafiken: true });
  const ident = tillamplighet({ ...bas, holistiskBedomning: 'NOT_SUFFICIENT' });
  prov('GP-16', 'tillstandsgrafik far en egen kravklass och blandas inte ihop med identiteten',
    stat.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_STATE &&
    ident.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    stat.klass !== ident.klass,
    'samma bedomning ger ' + stat.klass + ' respektive ' + ident.klass); }

/* GP-20 · ANPASSAT · antalet kan aldrig avgora */
{ const noll = tillamplighet({ ...bas, holistiskBedomning: 'SUFFICIENT', evidens: [] });
  const manga = tillamplighet({ ...bas, evidens: ['a', 'b', 'c', 'd', 'e'] });
  prov('GP-20', 'antalet omstandigheter kan aldrig avgora requiredness',
    noll.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    manga.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    manga.diagnostik.evidens.length > noll.diagnostik.evidens.length,
    'noll beskrivna omstandigheter med bedomning ger ' + noll.klass +
      '; fem utan bedomning ger ' + manga.klass); }

/* GP-21 · ANPASSAT · synlig text ar fortfarande inte avgorande */
{ const a = tillamplighet({ ...bas, harSynligText: true });
  const b = tillamplighet({ ...bas, harSynligText: false });
  prov('GP-21', 'synlig text ar fortfarande inte avgorande i nagon riktning',
    a.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY && a.klass === b.klass,
    'med och utan synlig text ger samma klass ' + a.klass); }

/* GP-22 · ANPASSAT · lag kontrast kan inte etablera krav */
{ const r = tillamplighetOberoendeAvKvot({ ...bas, holistiskBedomning: 'SUFFICIENT' }, 1.0);
  prov('GP-22', 'lag kontrast kan inte etablera requiredness',
    r.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    konformansutfall(r.klass, 1.0, KRAV_MOT_ANGRANSANDE).utfall === UTFALL.NOT_APPLICABLE,
    'kvot 1.0 lamnar klassen ' + r.klass); }

/* GP-23 · ANPASSAT · hog kontrast kan inte etablera icke-krav */
{ const r = tillamplighetOberoendeAvKvot({ ...bas, holistiskBedomning: 'NOT_SUFFICIENT' }, 21);
  prov('GP-23', 'hog kontrast kan inte etablera non-requiredness',
    r.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL,
    'kvot 21 lamnar klassen ' + r.klass); }

/* GP-24 · ANPASSAT · inmatningsfalt vars ram ar enda indikationen forblir KRAVD */
{ const r = tillamplighet({ ...bas, harSynligText: true, holistiskBedomning: 'NOT_SUFFICIENT',
    evidens: ['etiketten "Titel" ligger over faltet men samma monster anvands for de ' +
      'icke-redigerbara blocken pa skarmen', 'faltets varde ar satt som vanlig brodtext'],
    bedomningsskal: 'utan ramen ar faltet visuellt identiskt med skarmens lasrutor' });
  const u = konformansutfall(r.klass, 1.414, KRAV_MOT_ANGRANSANDE);
  prov('GP-24', 'ett inmatningsfalt vars ram ar den enda visuella indikationen forblir kravd',
    r.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    u.utfall === UTFALL.FINDING,
    'counterfactual komponentidentifiering ger ' + r.klass + ' → ' + u.utfall); }

/* ── TREDJE RATTNINGEN · GP-26 … GP-35 ───────────────────────────────*/

/* GP-26 · COLLECTIVE_CONTEXT_CAN_BE_SUFFICIENT */
{ const r = tillamplighet({ ...bas, holistiskBedomning: 'SUFFICIENT',
    evidens: ['position i sidnavigeringen', 'sekvensen 1 2 3', 'jamnstor grannruta',
      'aktuell sida ar markerad'],
    bedomningsskal: 'omstandigheterna lasta TILLSAMMANS identifierar sidvaljarna' });
  prov('GP-26', 'flera omstandigheter kan TILLSAMMANS vara tillrackliga',
    r.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    /TILLSAMMANS/.test(r.skal),
    'kollektiv bedomning ger ' + r.klass); }

/* GP-27 · MULTIPLE_INDIVIDUALLY_INCONCLUSIVE_CUES_MAY_COMBINE_TO_SUFFICIENCY */
{ const var1 = tillamplighet({ ...bas, evidens: ['position'] });
  const var2 = tillamplighet({ ...bas, evidens: ['sekvens'] });
  const bada = tillamplighet({ ...bas, evidens: ['position', 'sekvens'],
    holistiskBedomning: 'SUFFICIENT',
    bedomningsskal: 'var for sig avgor ingen av dem, tillsammans gor de det' });
  prov('GP-27', 'omstandigheter som var for sig ar otillrackliga kan kombineras till ' +
    'tillracklighet',
    var1.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    var2.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    bada.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT,
    'var for sig ' + var1.klass + ', tillsammans med bedomning ' + bada.klass); }

/* GP-28 · NO_CUE_STRENGTH_ENUM_CAN_DETERMINE_VERDICT */
{ const medEnum = tillamplighet({ ...bas, styrka: 'STARK', strongCue: true,
    evidens: ['nagot som nagon kallar starkt'] });
  prov('GP-28', 'inget styrkeenum kan avgora verdict',
    medEnum.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    !/STYRKA|STARK|SVAG|strongCue|weakCue|hasStrong|allWeak|strongCount/.test(KOD),
    'ett palagt styrkefalt ignoreras helt (' + medEnum.klass +
      ') och inget styrkebegrepp finns kvar i kallan'); }

/* GP-29 · NO_CUE_COUNT_CAN_DETERMINE_VERDICT */
{ const noll = tillamplighet({ ...bas, evidens: [] });
  const tio = tillamplighet({ ...bas, evidens: Array.from({ length: 10 }, (_, i) => 'omst' + i) });
  prov('GP-29', 'inget antal omstandigheter kan avgora verdict',
    noll.klass === tio.klass && noll.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    !/MINST_ANTAL|evidens\.length\s*[<>=]/.test(KOD),
    'noll och tio omstandigheter ger samma klass ' + noll.klass +
      '; ingen langdjamforelse finns i kallan'); }

/* GP-30 · ONE_CONTEXT_FEATURE_MAY_BE_SUFFICIENT */
{ const r = tillamplighet({ ...bas, holistiskBedomning: 'SUFFICIENT',
    evidens: ['skarmens egen instruktion pekar ut interaktionen'],
    bedomningsskal: 'instruktionen ensam identifierar mal och operation i denna scen' });
  prov('GP-30', 'en enda omstandighet kan vara tillracklig nar scenen stodjer det',
    r.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    r.diagnostik.evidens.length === 1,
    'en enda beskriven omstandighet, holistiskt bedomd, ger ' + r.klass); }

/* GP-31 · VISIBLE_TEXT_ALONE_IS_NON_DETERMINATIVE */
{ const a = tillamplighet({ ...bas, harSynligText: true, evidens: ['synlig etikett'] });
  prov('GP-31', 'synlig text ensam ar icke-avgorande',
    a.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY,
    'synlig etikett utan holistisk bedomning ger ' + a.klass); }

/* GP-32 · POSITION_ALONE_MAY_OR_MAY_NOT_BE_SUFFICIENT_DEPENDING_ON_SCENE */
{ const racker = tillamplighet({ ...bas, evidens: ['position'], holistiskBedomning: 'SUFFICIENT',
    bedomningsskal: 'etablerad atgardsplats i hela flodet' });
  const rackerInte = tillamplighet({ ...bas, evidens: ['position'],
    holistiskBedomning: 'NOT_SUFFICIENT', bedomningsskal: 'godtycklig plats i ett textstycke' });
  prov('GP-32', 'samma positionsomstandighet kan vara tillracklig i en scen och otillracklig ' +
    'i en annan',
    racker.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    rackerInte.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    JSON.stringify(racker.diagnostik.evidens) === JSON.stringify(rackerInte.diagnostik.evidens),
    'identisk omstandighetslista ger ' + racker.klass + ' respektive ' + rackerInte.klass +
      ' — scenen avgor, inte omstandigheten'); }

/* GP-33 · TEXT_INPUT_BOUNDARY_REQUIRED_WHEN_WITHOUT_IT_INPUT_IS_NOT_VISUALLY_IDENTIFIABLE */
{ const r = tillamplighet({ ...bas, harSynligText: true, holistiskBedomning: 'NOT_SUFFICIENT',
    evidens: ['ingen fyllning', 'ingen inset', 'ingen markor i den statiska ritningen',
      'samma etikett-over-varde-monster som skarmens lasrutor'],
    bedomningsskal: 'utan ramen finns ingen visuell komponentindikator for ett inmatningsfalt' });
  prov('GP-33', 'ett inmatningsfalts ram ar kravd nar faltet utan den inte gar att identifiera ' +
    'visuellt',
    r.klass === TILLAMPLIGHET.NON_TEXT_VISUAL_REQUIRED_TO_IDENTIFY_CONTROL &&
    konformansutfall(r.klass, 1.414, KRAV_MOT_ANGRANSANDE).utfall === UTFALL.FINDING,
    'counterfactual komponentidentifiering, inte styrka: ' + r.klass); }

/* GP-34 · PAGINATION_CONTEXT_MUST_BE_EVALUATED_AS_A_WHOLE */
{ const helhet = tillamplighet({ ...bas, holistiskBedomning: 'SUFFICIENT',
    evidens: ['tre jamnstora numrerade rutor i foljd', 'aktuell sida markerad med ram',
      'atgardsknapp i samma rad'],
    bedomningsskal: 'sidvaljaren lases som EN STRUKTUR' });
  const enskild = tillamplighet({ ...bas, evidens: ['en numrerad ruta'] });
  prov('GP-34', 'sidnavigering ska bedomas som en hel struktur, inte ruta for ruta',
    helhet.klass === TILLAMPLIGHET.TEXT_OR_CONTEXT_SUFFICIENT &&
    enskild.klass === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    /EN STRUKTUR/.test(helhet.skal),
    'helheten ger ' + helhet.klass + ', en losryckt ruta ger ' + enskild.klass); }

/* GP-35 · RATIO_CANNOT_DETERMINE_APPLICABILITY */
{ const f = { ...bas, evidens: ['nagot'] };
  const kvoter = [1.0, 1.414, 2.918, 3.0, 21];
  const klasser = [...new Set(kvoter.map(k => tillamplighetOberoendeAvKvot(f, k).klass))];
  prov('GP-35', 'kvoten kan aldrig avgora tillampligheten',
    klasser.length === 1 && klasser[0] === TILLAMPLIGHET.UNKNOWN_APPLICABILITY &&
    !/kvot/.test(KOD.slice(KOD.indexOf('export function tillamplighet(f)'),
      KOD.indexOf('export function tillamplighetOberoendeAvKvot'))),
    'fem olika kvoter ger samma klass ' + klasser[0] +
      '; tillamplighetsfunktionen ror aldrig kvoten'); }

const ANTAL = 35;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('DELKRAVSPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'delkravsprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
