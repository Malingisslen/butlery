#!/usr/bin/env node
// F2-NT · PROV FOR LOW-CONTRAST UNKNOWN APPLICABILITY PLANNER.  ACR-01 … ACR-15
//
// Kör: node tools/low-contrast-planner-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN PROVEN FINNS FOR
// Nar 1736 relationer saknar dom ar frestelsen att lata maskinen doma at oss:
// lata kvoten avgora vad som kravs, lata en grupp arva en dom, lata samma
// farg eller samma roll smitta, eller lata en supplemental-dom vila pa en
// barare som ingen har matt. Proven laser varje sadan genvag.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });
const kastar = f => { try { f(); return false; } catch { return true; } };

const AP = await import('file://' + resolve('tools/applicability-planner.mjs').replace(/\\/g,'/'));
const A = JSON.parse(readFileSync(resolve('fas2/lagkontrast-planering.json'), 'utf8'));
const INV = A.C_riskpopulation.poster;
const GRP = A.D_reviewGroups.grupper;
const PIL = A.H_forslag.poster;
const PROBE = A.G_probe.resultat;

/* Ett komplett, giltigt bevis som proven varierar. Malets kvot saknas med flit. */
const barare = (pid, kvot) => ({ PART_ID: pid, typ: 'BOUNDARY', KANONISK_DEL: true,
  MATT: true, OMFATTAS_AV_1_4_11: true, SYNLIG_I_SCENEN: true, kvot });
const bevis = (over = {}) => ({ COUNTERFACTUAL_KORD: true,
  SCENIDENTIFIERING: AP.SCENIDENTIFIERING.SCENE_IDENTIFIES_WITHOUT_TARGET,
  ALTERNATIVE_CARRIERS: [barare('x|1#ram#0', 1.41)],
  STATE_UNDER_TEST: 'STATIC_DEFAULT', ...over });

/* ── ACR-01 ─────────────────────────────────────────────────────────────── */
{ const d = A.A_delning;
  const summaKorstab = Object.entries(d.KORSTAB).filter(([k]) => k !== 'SUMMA')
    .reduce((a,[,v]) => a + v, 0);
  prov('ACR-01', 'current UNKNOWN rekoncilierar exakt mot LT3 + GE3',
    d.LT3_UNKNOWN + d.GE3_UNKNOWN === d.CURRENT_UNKNOWN_APPLICABILITY &&
    d.RECONCILES === true && d.OMATT_UNKNOWN === 0 &&
    d.KORSTAB.LT3_UNKNOWN === d.LT3_UNKNOWN && d.KORSTAB.GE3_UNKNOWN === d.GE3_UNKNOWN &&
    summaKorstab === d.GRAPHICAL_PARTS && d.KORSTAB_SLUTEN === true &&
    A.A2_harkomst.RECONCILED === true && A.A2_harkomst.DELTA_SUMMA === 0 &&
    INV.length === d.LT3_UNKNOWN,
    d.LT3_UNKNOWN + ' + ' + d.GE3_UNKNOWN + ' = ' + d.CURRENT_UNKNOWN_APPLICABILITY +
    ', korstaben sluter pa ' + summaKorstab + ' av ' + d.GRAPHICAL_PARTS +
    ', harkomstdelta ' + A.A2_harkomst.DELTA_SUMMA + ', inventeringen ' + INV.length); }

/* ── ACR-02 ─────────────────────────────────────────────────────────────── */
{ const serKvot = kastar(() => AP.forslag(bevis({ MEASURED_RATIO: 2.9 })));
  const serKvot2 = kastar(() => AP.forslag(bevis({ CURRENT_RATIO: 9.9 })));
  const lag = AP.forslag(bevis({ ALTERNATIVE_CARRIERS: [barare('a|1#ram#0', 1.01)] }));
  const hog = AP.forslag(bevis({ ALTERNATIVE_CARRIERS: [barare('b|1#ram#0', 13.4)] }));
  const hogFaller = AP.forslag(bevis({ ALTERNATIVE_CARRIERS: [barare('c|1#ram#0', 13.4)],
    SCENIDENTIFIERING: AP.SCENIDENTIFIERING.SCENE_FAILS_WITHOUT_TARGET }));
  const statusVarden = [1.0, 2.99, 3.0, 21].map(k =>
    AP.statusSeparation({ APPLICABILITY_VERDICT: 'UNKNOWN', MEASURED_RATIO: k }));
  prov('ACR-02', 'ratio kan aldrig skapa REQUIRED eller SUPPLEMENTAL',
    serKvot && serKvot2 && lag.FORSLAG === hog.FORSLAG &&
    lag.FORSLAG === AP.FORSLAG.PROPOSED_SUPPLEMENTAL_NOT_REQUIRED &&
    hogFaller.FORSLAG === AP.FORSLAG.PROPOSED_REQUIRED &&
    statusVarden.every(s => s.APPLICABILITY_VERDICT === 'UNKNOWN') &&
    !PIL.some(x => x.COUNTERFACTUAL.KORD === false &&
      x.PROPOSED_VERDICT !== AP.FORSLAG.PROPOSED_UNKNOWN),
    'forslag() kastar pa kvot: ' + (serKvot && serKvot2) + '; barare 1.01 och 13.4 ger ' +
    lag.FORSLAG + ' / ' + hog.FORSLAG + '; hog kvot hindrar inte REQUIRED: ' +
    hogFaller.FORSLAG); }

/* ── ACR-03 ─────────────────────────────────────────────────────────────── */
{ const j = A.J_ge3;
  prov('ACR-03', 'GE3_UNKNOWN forblir applicability UNKNOWN',
    j.ALLA_APPLICABILITY_UNKNOWN === true && j.ALLA_KONFORMANS_UNKNOWN === true &&
    j.APPLICABILITY_STATUS === 'APPLICABILITY_UNKNOWN' &&
    j.ADJUDICERADE_I_DETTA_BLOCK === 0 &&
    j.GE3_UNKNOWN === A.A_delning.GE3_UNKNOWN && j.MIN_RATIO >= 3,
    j.GE3_UNKNOWN + ' relationer, alla UNKNOWN, lagsta kvot ' + j.MIN_RATIO +
    ', adjudicerade i blocket ' + j.ADJUDICERADE_I_DETTA_BLOCK); }

/* ── ACR-04 ─────────────────────────────────────────────────────────────── */
{ const s = AP.statusSeparation({ APPLICABILITY_VERDICT: 'UNKNOWN', MEASURED_RATIO: 3.0 });
  const varden = JSON.stringify(s);
  const kastarPaDom = kastar(() =>
    AP.statusSeparation({ APPLICABILITY_VERDICT: 'REQUIRED', MEASURED_RATIO: 9 }));
  prov('ACR-04', 'GE3_UNKNOWN kan bara fa matfaktumet NON_FAIL_IF_APPLICABLE',
    s.CURRENT_RATIO_OUTCOME === AP.RATIO_UTFALL.NON_FAIL_IF_APPLICABLE &&
    !/REQUIRED_PASS|SUPPLEMENTAL|NOT_APPLICABLE/.test(varden) && kastarPaDom &&
    A.J_ge3.ALLA_NON_FAIL_IF_APPLICABLE === true &&
    A.J_ge3.CURRENT_RATIO_OUTCOME === 'NON_FAIL_IF_APPLICABLE' && s.R04_CREDIT === 0,
    'utfall ' + s.CURRENT_RATIO_OUTCOME + '; inga domord i objektet; kastar pa dom: ' +
    kastarPaDom); }

/* ── ACR-05 ─────────────────────────────────────────────────────────────── */
{ const felmarkta = INV.filter(x => x.CURRENT_RATIO_OUTCOME !== 'POSSIBLE_FAIL_IF_REQUIRED' ||
    x.CURRENT_APPLICABILITY !== 'UNKNOWN' || x.APPLICABILITY_STATUS !== 'APPLICABILITY_UNKNOWN');
  const overGolvet = INV.filter(x => x.CURRENT_RATIO >= 3);
  prov('ACR-05', 'LT3_UNKNOWN markt enbart POSSIBLE_FAIL_IF_REQUIRED fore adjudicering',
    felmarkta.length === 0 && overGolvet.length === 0 &&
    A.B_statusseparation.LT3_CURRENT_RATIO_OUTCOME === 'POSSIBLE_FAIL_IF_REQUIRED' &&
    A.M_status.APPLICABILITY_RECORDS_WRITTEN === 0,
    INV.length + ' poster, felmarkta ' + felmarkta.length + ', over golvet ' +
    overGolvet.length + ', skrivna registerdomar ' + A.M_status.APPLICABILITY_RECORDS_WRITTEN); }

/* ── ACR-06 ─────────────────────────────────────────────────────────────── */
{ const avvisar = kastar(() => AP.grupperingsnyckel({ RAW_COLOUR: '#ccd1c2' }));
  const perFarg = new Map();
  for (const x of INV) { if (!perFarg.has(x.PART_PAINT)) perFarg.set(x.PART_PAINT, new Set());
    perFarg.get(x.PART_PAINT).add(x.GROUP_ID); }
  const fargSomSpannerFleraGrupper = [...perFarg.values()].filter(s => s.size > 1).length;
  const enfargadeGrupper = GRP.filter(g => g.RAW_COLOUR_UNIFORM);
  const IP = A.D_reviewGroups.GRUPPERINGSREGLER.ICKE_PROPAGERING;
  prov('ACR-06', 'samma rafarg kan inte propagera dom',
    avvisar && !AP.TILLATNA_GRUPPFAKTA.includes('RAW_COLOUR') &&
    fargSomSpannerFleraGrupper > 0 && IP.PER_RAW_COLOUR.medFleraDomar > 0 &&
    enfargadeGrupper.every(g => g.GROUP_VERDICT === null) &&
    !Object.keys(INV[0].GROUPING_FACTS).some(k => AP.OTILLATNA_GRUPPFAKTA.includes(k)),
    'nyckeln avvisar RAW_COLOUR: ' + avvisar + '; ' + fargSomSpannerFleraGrupper +
    ' rafarger spanner over flera grupper i LT3; ' + IP.PER_RAW_COLOUR.medFleraDomar +
    ' av ' + IP.PER_RAW_COLOUR.totalt + ' rafarger i hela populationen bar flera olika ' +
    'domar; ' + enfargadeGrupper.length + ' enfargade grupper, alla utan dom'); }

/* ── ACR-07 ─────────────────────────────────────────────────────────────── */
{ const avvisar = kastar(() => AP.grupperingsnyckel({ CONTROL_ROLE_ALONE: 'button' }));
  const avvisarTyp = kastar(() => AP.grupperingsnyckel({ CONTROL_TYPE_ALONE: 'checkbox' }));
  const perRoll = new Map();
  for (const x of INV) { if (!perRoll.has(x.CONTROL_ROLE)) perRoll.set(x.CONTROL_ROLE, new Set());
    perRoll.get(x.CONTROL_ROLE).add(x.GROUP_ID); }
  const rollSomSpanner = [...perRoll.values()].filter(s => s.size > 1).length;
  const IP = A.D_reviewGroups.GRUPPERINGSREGLER.ICKE_PROPAGERING;
  prov('ACR-07', 'samma control role eller control type kan inte propagera dom',
    avvisar && avvisarTyp && rollSomSpanner > 0 &&
    IP.PER_CONTROL_ROLE.medFleraDomar > 0 && IP.PER_PART_TYPE.medFleraDomar > 0 &&
    GRP.every(g => g.GROUP_VERDICT === null),
    'nyckeln avvisar roll och typ ensamma: ' + (avvisar && avvisarTyp) + '; ' +
    rollSomSpanner + ' roller spanner over flera grupper; ' +
    IP.PER_CONTROL_ROLE.medFleraDomar + ' av ' + IP.PER_CONTROL_ROLE.totalt +
    ' roller och ' + IP.PER_PART_TYPE.medFleraDomar + ' av ' + IP.PER_PART_TYPE.totalt +
    ' deltyper bar flera olika domar; alla ' + GRP.length + ' grupper utan dom'); }

/* ── ACR-08 ─────────────────────────────────────────────────────────────── */
{ const text = AP.provaCarrier({ typ: 'TEXT', SYNLIG_I_SCENEN: true, KANONISK_DEL: true, MATT: true });
  const namn = AP.provaCarrier({ typ: 'ACCESSIBLE_NAME', SYNLIG_I_SCENEN: true });
  const baraText = AP.forslag(bevis({ ALTERNATIVE_CARRIERS: [
    { typ: 'TEXT', SYNLIG_I_SCENEN: true, KANONISK_DEL: true, MATT: true }] }));
  const medText = PIL.filter(x => x.VISIBLE_TEXT_FACT === 'VISIBLE_TEXT_PRESENT');
  const textSomCarrier = PIL.flatMap(x => x.ANVANDA_CARRIERS)
    .filter(c => !/#(ram|ikon|bock|thumb|glyf|fyllning)#\d+$/.test(String(c)));
  prov('ACR-08', 'synlig text kan inte propagera en supplemental-dom',
    !text.godkand && !namn.godkand &&
    baraText.FORSLAG === AP.FORSLAG.PROPOSED_UNKNOWN &&
    medText.length > 0 && textSomCarrier.length === 0,
    'text avvisad: ' + !text.godkand + '; enbart text ger ' + baraText.FORSLAG + '; ' +
    medText.length + ' pilotposter har synlig text; ' + textSomCarrier.length +
    ' icke-delbarare i ANVANDA_CARRIERS'); }

/* ── ACR-09 ─────────────────────────────────────────────────────────────── */
{ const d = AP.gruppdom({ GROUP_ID: 'RG-prov', OCCURRENCES: 9 });
  prov('ACR-09', 'en review group skapar inga semantiska domar',
    d.APPLICABILITY_VERDICT === null && d.GROUP_VERDICT === null &&
    d.HUMAN_EQUIVALENCE_GATE === 'NOT_PASSED' &&
    GRP.every(g => g.GROUP_VERDICT === null && g.HUMAN_EQUIVALENCE_GATE === 'NOT_PASSED') &&
    A.D_reviewGroups.GRUPPER_MED_SEMANTISK_DOM === 0,
    GRP.length + ' grupper, ' + A.D_reviewGroups.GRUPPER_MED_SEMANTISK_DOM +
    ' med dom, ' + A.D_reviewGroups.SINGLETON_GROUPS + ' singletons'); }

/* ── ACR-10 ─────────────────────────────────────────────────────────────── */
{ const fullt = Object.fromEntries(AP.EKVIVALENSKRAV.map(k => [k, true]));
  const utanKalla = AP.farFaGemensamDom({ ...fullt });
  const maskinkalla = AP.farFaGemensamDom({ ...fullt, BESLUTSKALLA: 'GROUPING_ALGORITHM' });
  const ettSaknas = AP.farFaGemensamDom({ ...fullt, BESLUTSKALLA: 'HUMAN_ACTUAL_SCENE_EVIDENCE',
    'carrier responsibility': false });
  const avvikande = AP.farFaGemensamDom({ ...fullt, BESLUTSKALLA: 'HUMAN_ACTUAL_SCENE_EVIDENCE',
    avvikandeMedlemmar: ['x|3#ram#0'] });
  const ok = AP.farFaGemensamDom({ ...fullt, BESLUTSKALLA: 'HUMAN_ACTUAL_SCENE_EVIDENCE' });
  prov('ACR-10', 'ekvivalensgrinden kravs fore varje framtida gruppdom',
    !utanKalla.tillatet && !maskinkalla.tillatet &&
    !ettSaknas.tillatet && ettSaknas.atgard === 'SPLIT_GROUP' &&
    !avvikande.tillatet && avvikande.atgard === 'SPLIT_GROUP' && ok.tillatet &&
    A.E_ekvivalensgrind.GRUPPER_SOM_PASSERAT_GRINDEN === 0 &&
    A.E_ekvivalensgrind.AUTOMATISK_VERDICT_PROPAGATION === 'FORBJUDEN' &&
    A.E_ekvivalensgrind.KRAV.length === 5,
    'utan kalla ' + utanKalla.tillatet + ', maskinkalla ' + maskinkalla.tillatet +
    ', ett kriterium saknas ' + ettSaknas.tillatet + ', avvikande medlem ' +
    avvikande.tillatet + ', fullt bevis ' + ok.tillatet + '; passerade grupper ' +
    A.E_ekvivalensgrind.GRUPPER_SOM_PASSERAT_GRINDEN); }

/* ── ACR-11 ─────────────────────────────────────────────────────────────── */
{ const g = A.G_probe;
  const rorda = PROBE.filter(x => x.GEOMETRY_DELTA !== 0 || x.CLIPPING_DELTA !== 0);
  const iso = g.isoleringsbevis;
  prov('ACR-11', 'den kontrafaktiska sonden andrar 0 geometri',
    g.GEOMETRY_DELTA_TOTALT === 0 && g.CLIPPING_DELTA_TOTALT === 0 &&
    rorda.length === 0 && PROBE.length === A.F_pilot.PILOT_OCCURRENCES &&
    g.COLLATERAL_PAINT_DELTA_TOTALT === 0 &&
    iso.length > 0 && iso.every(x => x.ISOLERING_PAVERKAR_INTE_ARTEFAKTEN) &&
    PROBE.every(x => x.JAMFORDA_ELEMENT > 0),
    PROBE.length + ' sonder, geometri ' + g.GEOMETRY_DELTA_TOTALT + ', klipp ' +
    g.CLIPPING_DELTA_TOTALT + ', kollateral ' + g.COLLATERAL_PAINT_DELTA_TOTALT +
    ', isoleringsbevis ' + iso.length); }

/* ── ACR-12 ─────────────────────────────────────────────────────────────── */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status','--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  prov('ACR-12', 'sonden lamnar kallan bitidentisk',
    !fel && produkt.length === 0 && A.G_probe.SOURCE_BIT_IDENTICAL === true &&
    A.G_probe.PERMANENT_WRITES === 0 && A.G_probe.ALLA_ATERSTALLDA === true &&
    A.G_probe.RESTORATION_DELTA_TOTALT === 0,
    (fel || produkt.length + ' andrade produktfiler') + '; bitidentisk ' +
    A.G_probe.SOURCE_BIT_IDENTICAL + '; aterstallningsdelta ' +
    A.G_probe.RESTORATION_DELTA_TOTALT); }

/* ── ACR-13 ─────────────────────────────────────────────────────────────── */
{ const utanKanon = AP.provaCarrier({ typ: 'BOUNDARY', OMFATTAS_AV_1_4_11: true,
    KANONISK_DEL: false, MATT: false, SYNLIG_I_SCENEN: true });
  const f = AP.forslag(bevis({ ALTERNATIVE_CARRIERS: [{ typ: 'BOUNDARY',
    OMFATTAS_AV_1_4_11: true, KANONISK_DEL: false, MATT: false, SYNLIG_I_SCENEN: true }] }));
  const supplemental = PIL.filter(x => x.PROPOSED_VERDICT === AP.FORSLAG.PROPOSED_SUPPLEMENTAL_NOT_REQUIRED);
  const alltKanoniskt = supplemental.every(x => x.ANVANDA_CARRIERS.length > 0 &&
    x.ANVANDA_CARRIERS.every(pid => { const c = x.ALTERNATIVE_CARRIERS.find(y => y.PART_ID === pid);
      return c && c.KANONISK_DEL && c.MATT && c.SYNLIG_I_SCENEN; }));
  prov('ACR-13', 'alternativ barare maste finnas i den kanoniska matningen',
    utanKanon.MEASUREMENT_GAP === true && !utanKanon.godkand &&
    f.FORSLAG === AP.FORSLAG.PROPOSED_UNKNOWN && f.MEASUREMENT_GAP === true &&
    alltKanoniskt && A.I_carriers.ALLA_CARRIERS_KANONISKA === true &&
    A.H_forslag.MEASUREMENT_GAP_ANTAL === A.I_carriers.MEASUREMENT_GAP.length,
    'omatt barare ger MEASUREMENT_GAP och ' + f.FORSLAG + '; ' + supplemental.length +
    ' supplemental-forslag, alla med kanonisk matt barare: ' + alltKanoniskt); }

/* ── ACR-14 ─────────────────────────────────────────────────────────────── */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status','--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  const L = A.L_regression;
  prov('ACR-14', 'ingen produkt-, farg- eller R-04-skrivning sker',
    !fel && produkt.length === 0 && L.PRODUCT_WRITES === 0 && L.COLOR_WRITES === 0 &&
    L.R04_WRITES === 0 && L.R04_CREDIT === 0 && A.$produktfilerOrorda === true &&
    A.M_status.APPLICABILITY_RECORDS_WRITTEN === 0 &&
    PIL.every(x => x.APPLICABILITY_RECORD_WRITTEN === false && x.R04_CREDIT === 0) &&
    AP.farSkrivasSomRegisterdom() === false,
    (fel || produkt.length + ' andrade produktfiler') + '; produktskrivningar ' +
    L.PRODUCT_WRITES + ', fargskrivningar ' + L.COLOR_WRITES + ', R-04 ' + L.R04_WRITES +
    '/' + L.R04_CREDIT); }

/* ── ACR-15 ─────────────────────────────────────────────────────────────── */
{ const utanfor = AP.forslag(bevis({ STATE_UNDER_TEST: 'STATE_OUT_OF_SCOPE' }));
  const flaggade = INV.filter(x => x.STATE_UNDER_TEST === 'STATE_OUT_OF_SCOPE');
  const borde = INV.filter(x => x.STATE && /^(disabled|pressed|focus)/.test(x.STATE));
  prov('ACR-15', 'pressed, inactive och focus far ingen credit',
    utanfor.FORSLAG === AP.FORSLAG.PROPOSED_UNKNOWN && utanfor.R04_CREDIT === 0 &&
    flaggade.length === borde.length && borde.length > 0 &&
    A.F_pilot.STATE_OUT_OF_SCOPE === 0 &&
    !PIL.some(x => x.STATE && /^(disabled|pressed|focus)/.test(x.STATE)) &&
    A.M_status.PRESSED === 'UNTESTED' && A.M_status.INACTIVE === 'UNTESTED' &&
    A.M_status.FOCUS === 'UNTESTED',
    'utanfor scope ger ' + utanfor.FORSLAG + '; ' + flaggade.length +
    ' flaggade av ' + borde.length + ' i inventeringen; i piloten ' +
    A.F_pilot.STATE_OUT_OF_SCOPE); }

/* ═══ REGISTRERINGEN AV PILOT 1 · ACR-16 … ACR-25 ═════════════════════════
 * Proven ovanfor last planeringen. Proven nedan laser registreringen: att
 * exakt 51 skrevs, att domen vilar pa targetdelens egen status och inte pa
 * "kanten racker", att ingen annan barare arvde nagot, och att nasta pilot
 * valdes med samma mekaniska regel. */
const REG = JSON.parse(readFileSync(resolve('fas2/lagkontrast-register-51.json'), 'utf8'));
const P2 = JSON.parse(readFileSync(resolve('fas2/lagkontrast-pilot-2.json'), 'utf8'));
const REC = REG.F_records;

/* ── ACR-16 ─────────────────────────────────────────────────────────────── */
{ const r = REG.A_registrering;
  prov('ACR-16', 'exakt 51 occurrence-domar registrerade',
    r.REGISTERED_OCCURRENCES === 51 && r.DUPLICATES === 0 && r.OMITTED === 0 &&
    r.OUT_OF_SCOPE === 0 && REC.length === 51 &&
    new Set(REC.map(x => x.RELATION_ID)).size === 51 &&
    REC.every(x => x.APPLICABILITY_VERDICT === 'SUPPLEMENTAL_NOT_REQUIRED') &&
    REC.every(x => x.TARGET === 'FILL_RELATION' && x.GRAPHICAL_PART_TYPE === 'fyllning') &&
    REG.E_grindar.every(g => g.ok) &&
    PIL.every(x => REC.some(r2 => r2.RELATION_ID === x.RELATION_ID)),
    r.REGISTERED_OCCURRENCES + ' registrerade, ' + r.DUPLICATES + ' dubbletter, ' +
    r.OMITTED + ' utelamnade, ' + r.OUT_OF_SCOPE + ' utanfor scope, ' +
    REG.E_grindar.length + ' grindar passerade'); }

/* ── ACR-17 ─────────────────────────────────────────────────────────────── */
{ const forbjuden = /border[^.]{0,20}sufficient|kanten\s+racker|etiketten\s+racker|label is sufficient/i;
  const textIRecord = REC.map(x => (x.MOTIVERING || '') + ' ' + JSON.stringify(x.DOES_NOT_IMPLY));
  const bar = REC.every(x => x.VERDICT_BASIS === 'TARGET_OWN_VISUAL_STATUS' &&
    x.VERDICT_SCOPE === 'TARGET_PART_ONLY' &&
    x.TARGET_FILL_CONTRIBUTES_DISTINGUISHABLE_VISUAL_INFORMATION === 'NO');
  const okAntal = textIRecord.filter(t => forbjuden.test(t)).length;
  prov('ACR-17', 'domen vilar pa targetdelens egen status, inte pa "kanten racker"',
    bar && okAntal === 0 &&
    REG.B_verdictprecisering.EJ_MOTIVERING === 'border/label is sufficient' &&
    REG.B_verdictprecisering.VERDICT_BASIS === 'TARGET_OWN_VISUAL_STATUS' &&
    REC.every(x => x.EVIDENCE.CANONICAL_CURRENT_RATIO === 1 &&
      x.EVIDENCE.TARGET_PAINT === x.EVIDENCE.EFFECTIVE_SURROUNDING_PAINT),
    'alla ' + REC.length + ' har target-scope och target-basis: ' + bar +
    '; forbjuden motivering forekommer ' + okAntal + ' ganger'); }

/* ── ACR-18 ─────────────────────────────────────────────────────────────── */
{ const a = P2.A_rekonciliation;
  prov('ACR-18', 'registreringen andrar ingen annan applicability-record',
    a.ANDRADE_RELATIONER === 51 && a.ANDRADE_SOM_AR_REGISTRERADE === 51 &&
    a.ANDRADE_UTANFOR_REGISTRERINGEN.length === 0 &&
    REC.every(x => x.OTHER_CARRIERS_UNCHANGED.every(c =>
      c.APPLICABILITY_BEFORE === c.APPLICABILITY_AFTER && !c.CHANGED_BY_THIS_RECORD)) &&
    REG.A_registrering.ANDRADE_ANDRA_RECORDS === 0,
    a.ANDRADE_RELATIONER + ' andrade relationer, alla registrerade, ' +
    a.ANDRADE_UTANFOR_REGISTRERINGEN.length + ' utanfor'); }

/* ── ACR-19 ─────────────────────────────────────────────────────────────── */
{ const a = P2.A_rekonciliation;
  prov('ACR-19', 'rekonciliationen gar exakt jamnt ut',
    a.BEFORE.LT3_UNKNOWN - a.AFTER.LT3_UNKNOWN === 51 &&
    a.DELTA.GE3_UNKNOWN === 0 && a.DELTA.TOTAL_UNKNOWN === -51 &&
    a.DELTA.KNOWN_REQUIRED_FAIL === 0 && a.AFTER.KNOWN_REQUIRED_FAIL === 0 &&
    a.DELTA.LT3_SUPPLEMENTAL === 51 && a.KORSTAB_SLUTEN === true &&
    a.AFTER.KORSTAB.SUMMA === a.GRAPHICAL_PARTS && a.RECONCILED === true &&
    a.AFTER.LT3_UNKNOWN === P2.G_nastaPilot.LT3_UNKNOWN,
    'LT3 ' + a.BEFORE.LT3_UNKNOWN + '->' + a.AFTER.LT3_UNKNOWN + ', GE3 ' +
    a.BEFORE.GE3_UNKNOWN + '->' + a.AFTER.GE3_UNKNOWN + ', totalt ' +
    a.BEFORE.TOTAL_UNKNOWN + '->' + a.AFTER.TOTAL_UNKNOWN + ', korstab ' +
    a.AFTER.KORSTAB.SUMMA + ' av ' + a.GRAPHICAL_PARTS); }

/* ── ACR-20 ─────────────────────────────────────────────────────────────── */
{ const b = P2.B_kanter;
  prov('ACR-20', 'de olosta bararna arvde ingen requiredness',
    b.ALLA_OFORANDRADE === true && b.ALLA_KVAR_I_LT3_UNKNOWN === true &&
    b.ANTAL_SOM_BLEV_REQUIRED === 0 && b.ANTAL_MED_REGISTRERAD_FAILURE === 0 &&
    b.BEROENDE_FOREKOMSTER === 39 && b.VARAV_KANTER === 39 &&
    b.poster.every(x => x.APPLICABILITY_AFTER === 'UNKNOWN' &&
      x.CONFORMANCE_AFTER === 'UNKNOWN'),
    b.BEROENDE_FOREKOMSTER + ' beroende forekomster, ' + b.UNIKA_BARARRELATIONER +
    ' bararrelationer (' + b.VARAV_KANTER + ' kanter pa kvot ' +
    JSON.stringify(b.KANTKVOTER) + '), ' + b.ANTAL_SOM_BLEV_REQUIRED +
    ' blev REQUIRED, ' + b.ANTAL_MED_REGISTRERAD_FAILURE + ' fick failure'); }

/* ── ACR-21 ─────────────────────────────────────────────────────────────── */
{ const c = P2.C_reviewGroups;
  prov('ACR-21', 'review groups bar fortfarande ingen dom efter registreringen',
    c.GRUPPER_MED_VERDICT === 0 && c.ALLA_NOT_PASSED === true &&
    c.ALLA_UTAN_GRUPPDOM === true && c.VERDICT_PROPAGATION === 0 &&
    c.PERSISTENT_SEMANTIC_DECISION_IDENTITY === 0 &&
    c.ALLA_RECORDS_INDIVIDUELLA === true && c.ALLA_GRUPPER_I_PLANEN_UTAN_DOM === true &&
    REG.D_reviewGroups.HUMAN_EQUIVALENCE_GATE === 'NOT_PASSED' &&
    REC.every(x => x.REVIEW_GROUP_ROLE === 'PRESENTATION_ONLY' &&
      x.GROUP_VERDICT === null && x.PERSISTENT_SEMANTIC_DECISION_IDENTITY === null),
    c.PILOTGRUPPER + ' grupper, ' + c.GRUPPER_MED_VERDICT + ' med dom, alla NOT_PASSED: ' +
    c.ALLA_NOT_PASSED); }

/* ── ACR-22 ─────────────────────────────────────────────────────────────── */
{ const arv = AP.harleddDom('FILL_SUPPLEMENTAL', 'BOUNDARY_REQUIRED');
  prov('ACR-22', 'fill-supplemental ar aldrig evidens for boundary-required',
    AP.farArvaDom() === false && arv.tillatet === false &&
    AP.OMFATTAR_INTE.includes('BOUNDARY_REQUIRED') &&
    AP.OMFATTAR_INTE.includes('ICON_REQUIRED') &&
    AP.OMFATTAR_INTE.includes('TEXT_SUFFICIENT') &&
    AP.OMFATTAR_INTE.includes('CONTROL_CONFORMING') &&
    REC.every(x => Array.isArray(x.DOES_NOT_IMPLY) &&
      x.DOES_NOT_IMPLY.includes('BOUNDARY_REQUIRED')) &&
    P2.G_nastaPilot.FILL_SUPPLEMENTAL_SOM_EVIDENS === 0,
    'arv sparrat: ' + (!AP.farArvaDom() && !arv.tillatet) + '; alla ' + REC.length +
    ' record bar DOES_NOT_IMPLY med ' + AP.OMFATTAR_INTE.length + ' poster'); }

/* ── ACR-23 ─────────────────────────────────────────────────────────────── */
{ const T = AP.SONDOPERATION.TARGET_PAINT_NEUTRALIZED_TO_EFFECTIVE_SURROUNDING_PAINT;
  const borttag = /\btas bort\b|\bborttagen\b|\bremoved\b|\bdeleted\b/i;
  const text = REC.map(x => (x.MOTIVERING || '') + ' ' + JSON.stringify(x.EVIDENCE));
  prov('ACR-23', 'sonden beskrivs som neutralisering, inte som borttagning',
    REC.every(x => x.EVIDENCE.OPERATION === T) &&
    REG.C_terminologi.OPERATION === T &&
    text.filter(t => borttag.test(t)).length === 0 &&
    REC.every(x => x.EVIDENCE.VISUAL_DIFFERENCE === 'NONE' &&
      x.EVIDENCE.NEUTRALIZED_TO === x.EVIDENCE.EFFECTIVE_SURROUNDING_PAINT),
    'exakt maskinterm i alla ' + REC.length + ' record; ' +
    text.filter(t => borttag.test(t)).length + ' borttagningsformuleringar'); }

/* ── ACR-24 ─────────────────────────────────────────────────────────────── */
{ const g = P2.G_nastaPilot;
  const dubbel = g.poster.filter(x => REC.some(r => r.RELATION_ID === x.RELATION_ID));
  prov('ACR-24', 'nasta pilot ar valt med exakt samma lasta mekaniska regel',
    g.SAMMA_REGEL_SOM_PILOT_1 === true && g.INOM_GRANS === true &&
    g.PILOT_OCCURRENCES >= 50 && g.PILOT_OCCURRENCES <= 80 &&
    g.OVERLAPP_MED_PILOT_1 === 0 && dubbel.length === 0 &&
    g.REGISTRERADE_DOMAR === 0 &&
    g.poster.every(x => x.CURRENT_APPLICABILITY === 'UNKNOWN' &&
      x.APPLICABILITY_RECORD_WRITTEN === false),
    g.PILOT_OCCURRENCES + ' forekomster i ' + g.PILOT_GROUPS + ' grupper, kvot ' +
    g.MIN_RATIO + '-' + g.MAX_RATIO + ', overlapp med pilot 1: ' + g.OVERLAPP_MED_PILOT_1 +
    ', registrerade domar: ' + g.REGISTRERADE_DOMAR); }

/* ── ACR-25 ─────────────────────────────────────────────────────────────── */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status','--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  const L = P2.L_regression;
  prov('ACR-25', 'produktbaselinet ar bitidentiskt och inget skrevs',
    !fel && produkt.length === 0 && L.PRODUKTBASELINE_BITIDENTISK === true &&
    L.R02_PASS === 1375 && L.R02_MEASURED === 1375 && L.GRAPHICAL_PARTS === 1879 &&
    L.BOUNDARIES === 689 && L.PAINTED_CONTROL_SURFACES === 420 &&
    L.STANDALONE_GRAPHICS === 32 && L.R01_FINDINGS === 0 &&
    L.KNOWN_REQUIRED_FAIL === 0 && L.GEOMETRY_DELTA === 0 && L.CLIPPING_DELTA === 0 &&
    L.PRODUCT_WRITES === 0 && L.COLOR_WRITES === 0 && L.R04_WRITES === 0 &&
    L.R04_CREDIT === 0 && REG.$produktfilerOrorda === true,
    (fel || produkt.length + ' andrade produktfiler') + '; ' + L.HIT_TARGETS +
    ' hit targets, ' + L.GRAPHICAL_PARTS + ' delar, ' + L.BOUNDARIES + ' kanter, ' +
    L.PAINTED_CONTROL_SURFACES + ' malade ytor, ' + L.STANDALONE_GRAPHICS +
    ' fristaende, R-01 ' + L.R01_FINDINGS + ', KNOWN_REQUIRED_FAIL ' +
    L.KNOWN_REQUIRED_FAIL); }

const ANTAL = 25;
for (const r of resultat) {
  console.log((r.ok ? '✔ ' : '✖ ') + r.id.padEnd(9) + r.vad);
  console.log('     ' + r.diag); }
const godkanda = resultat.filter(r => r.ok).length;
const status = godkanda === ANTAL && resultat.length === ANTAL ? 'godkand' : 'FALLD';
writeFileSync(join(outAbs, 'lagkontrastprov.json'), JSON.stringify({
  $schema: 'butlery-lagkontrastprov/1', kontroll: 'CHK-ACR-01',
  godkanda, total: ANTAL, status, prov: resultat }, null, 1) + '\n');
console.log('LAGKONTRASTPROV status=' + status + ' godkanda=' + godkanda + ' av ' + ANTAL);
process.exit(status === 'godkand' ? 0 : 1);
