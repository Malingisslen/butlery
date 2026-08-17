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

/* ═══ PILOT 2 REGISTRERAD + PILOT 3 VALD · ACR-26 … ACR-35 ════════════════
 * Har laser proven den nya bokforingen: att granskad-utan-dom ar skilt fran
 * ogranskad, att de granskade inte atercirkulerar, och att preview-isolering
 * ar en villkorlig optimering med negativ sentinel — inte en verifierad metod. */
const PI = await import('file://' + resolve('tools/preview-isolation.mjs').replace(/\\/g,'/'));
const R2 = JSON.parse(readFileSync(resolve('fas2/lagkontrast-register-pilot2.json'), 'utf8'));
const P3 = JSON.parse(readFileSync(resolve('fas2/lagkontrast-pilot-3.json'), 'utf8'));
const SUP2 = R2.B_supplemental.records, RU = R2.C_reviewedUnknown.records;

/* ── ACR-26 ─────────────────────────────────────────────────────────────── */
{ const r = R2.A_registrering;
  prov('ACR-26', 'pilot 2 registrerad som exakt 43 supplemental och 12 reviewed unknown',
    r.REGISTERED_OCCURRENCES === 55 && r.NEW_SUPPLEMENTAL === 43 &&
    r.NEW_REVIEWED_UNKNOWN === 12 && r.DUPLICATES === 0 && r.OMITTED === 0 &&
    r.OUT_OF_SCOPE === 0 && SUP2.length === 43 && RU.length === 12 &&
    new Set([...SUP2, ...RU].map(x => x.RELATION_ID)).size === 55 &&
    SUP2.every(x => x.APPLICABILITY_VERDICT === 'SUPPLEMENTAL_NOT_REQUIRED' &&
      x.VERDICT_SCOPE === 'TARGET_PART_ONLY' &&
      x.VERDICT_BASIS === 'TARGET_OWN_VISUAL_STATUS' &&
      x.EVIDENCE.VISUAL_DIFFERENCE === 'NONE') &&
    R2.E_grindar.every(g => g.ok),
    r.NEW_SUPPLEMENTAL + ' supplemental + ' + r.NEW_REVIEWED_UNKNOWN +
    ' reviewed unknown = ' + r.REGISTERED_OCCURRENCES + ', ' + R2.E_grindar.length +
    ' grindar passerade'); }

/* ── ACR-27 ─────────────────────────────────────────────────────────────── */
{ const klasser = Object.values(AP.BLOCKERKLASS);
  prov('ACR-27', 'de 12 ar varken REQUIRED eller SUPPLEMENTAL utan granskade utan dom',
    RU.every(x => x.APPLICABILITY_VERDICT === 'UNKNOWN' &&
      x.REVIEW_STATUS === AP.REVIEW_STATUS.REVIEWED_UNKNOWN &&
      klasser.includes(x.BLOCKER) && Array.isArray(x.BLOCKING_CARRIERS) &&
      x.BLOCKING_CARRIERS.length > 0 &&
      x.EVIDENCE.VISUAL_DIFFERENCE === 'PRESENT' &&
      x.TARGET_FILL_CONTRIBUTES_DISTINGUISHABLE_VISUAL_INFORMATION === 'YES' &&
      x.R04_CREDIT === 0) &&
    !RU.some(x => /REQUIRED|SUPPLEMENTAL/.test(x.APPLICABILITY_VERDICT)) &&
    Object.keys(R2.C_reviewedUnknown.blockerfordelning).every(k => klasser.includes(k)),
    RU.length + ' poster, blockerfordelning ' +
    JSON.stringify(R2.C_reviewedUnknown.blockerfordelning)); }

/* ── ACR-28 ─────────────────────────────────────────────────────────────── */
{ const rec = { REVIEW_STATUS: AP.REVIEW_STATUS.REVIEWED_UNKNOWN,
    APPLICABILITY_VERDICT: 'UNKNOWN',
    BLOCKING_CARRIERS: [{ PART_ID: 'a|1#ram#0' }, { PART_ID: 'a|1#ikon#0' }] };
  const utan = AP.farAterOppnas(rec, null);
  const fel = AP.farAterOppnas(rec, { SKAL: 'RATIO_STILL_LOW' });
  const felBarare = AP.farAterOppnas(rec,
    { SKAL: 'BLOCKING_CARRIER_ADJUDICATED', ADJUDICERADE: ['b|9#ram#0'] });
  const rattBarare = AP.farAterOppnas(rec,
    { SKAL: 'BLOCKING_CARRIER_ADJUDICATED', ADJUDICERADE: ['a|1#ram#0'] });
  const alla = AP.ATEROPPNINGSSKAL.map(s => AP.farAterOppnas(rec,
    { SKAL: s, ADJUDICERADE: ['a|1#ram#0'] }).tillatet);
  const ogranskad = AP.farIngaIMekaniskPilot(
    { APPLICABILITY_VERDICT: 'UNKNOWN', REVIEW_STATUS: AP.REVIEW_STATUS.UNREVIEWED_UNKNOWN });
  prov('ACR-28', 'REVIEWED_UNKNOWN ar skilt fran UNREVIEWED_UNKNOWN och atercirkulerar inte',
    AP.REVIEW_STATUS.REVIEWED_UNKNOWN !== AP.REVIEW_STATUS.UNREVIEWED_UNKNOWN &&
    !utan.tillatet && !fel.tillatet && !felBarare.tillatet && rattBarare.tillatet &&
    alla.every(Boolean) && AP.ATEROPPNINGSSKAL.length === 4 &&
    AP.farIngaIMekaniskPilot(rec) === false && ogranskad === true &&
    RU.every(x => x.ELIGIBLE_FOR_MECHANICAL_PILOT === false &&
      x.REOPEN_REQUIRES_ANY_OF.length === 4),
    'utan skal ' + utan.tillatet + ', fel skal ' + fel.tillatet + ', fel barare ' +
    felBarare.tillatet + ', ratt barare ' + rattBarare.tillatet +
    '; ogranskad far ingaa: ' + ogranskad); }

/* ── ACR-29 ─────────────────────────────────────────────────────────────── */
{ const a = P3.A_rekonciliation;
  prov('ACR-29', 'rekonciliationen efter pilot 2 gar exakt jamnt ut',
    a.BEFORE.LT3_UNKNOWN === 467 && a.AFTER.LT3_UNKNOWN === 424 &&
    a.BEFORE.GE3_UNKNOWN === 1218 && a.AFTER.GE3_UNKNOWN === 1218 &&
    a.BEFORE.TOTAL_UNKNOWN === 1685 && a.AFTER.TOTAL_UNKNOWN === 1642 &&
    a.AFTER.KNOWN_REQUIRED_FAIL === 0 && a.DELTA.KNOWN_REQUIRED_FAIL === 0 &&
    a.NEW_SUPPLEMENTAL === 43 && a.NEW_REVIEWED_UNKNOWN === 12 &&
    a.LT3_TOTAL === 424 && a.LT3_REVIEWED_UNKNOWN === 12 &&
    a.UNREVIEWED_LT3_QUEUE === 412 &&
    a.LT3_TOTAL === a.LT3_REVIEWED_UNKNOWN + a.UNREVIEWED_LT3_QUEUE &&
    a.ANDRADE_UTANFOR_REGISTRERINGEN.length === 0 &&
    a.STATUSANDRINGAR_UTANFOR.length === 0 && a.KORSTAB_SLUTEN === true &&
    a.RECONCILED === true,
    'LT3 ' + a.BEFORE.LT3_UNKNOWN + '->' + a.AFTER.LT3_UNKNOWN + ', totalt ' +
    a.BEFORE.TOTAL_UNKNOWN + '->' + a.AFTER.TOTAL_UNKNOWN + '; ' + a.LT3_TOTAL +
    ' = ' + a.LT3_REVIEWED_UNKNOWN + ' + ' + a.UNREVIEWED_LT3_QUEUE); }

/* ── ACR-30 ─────────────────────────────────────────────────────────────── */
{ const h = P3.B_reviewedUnknown;
  const ruIds = new Set(RU.map(x => x.RELATION_ID));
  const iPilot = P3.G_pilot3.poster.filter(x => ruIds.has(x.RELATION_ID));
  prov('ACR-30', 'de 12 granskade atercirkulerar inte till nasta pilot',
    h.REVIEWED_UNKNOWN === 12 && h.I_KANDIDATPOOLEN === 0 && h.I_PILOT_3 === 0 &&
    iPilot.length === 0 && h.farAterOppnasUtanSkal === false &&
    P3.G_pilot3.REVIEWED_UNKNOWN_I_PILOTEN === 0 &&
    P3.G_pilot3.KANDIDATPOOL === 'UNREVIEWED_LT3_UNKNOWN' &&
    P3.G_pilot3.KANDIDATPOOL_STORLEK === P3.A_rekonciliation.UNREVIEWED_LT3_QUEUE,
    h.REVIEWED_UNKNOWN + ' granskade, ' + h.I_KANDIDATPOOLEN + ' i poolen, ' +
    h.I_PILOT_3 + ' i pilot 3; poolen ar ' + P3.G_pilot3.KANDIDATPOOL + ' = ' +
    P3.G_pilot3.KANDIDATPOOL_STORLEK); }

/* ── ACR-31 ─────────────────────────────────────────────────────────────── */
{ const rent = { geometry: 0, paint: 0, clipping: 0, content_state: 0 };
  const omatt = { geometry: 0, paint: 0, clipping: 0 };
  const flertagg = { geometry: 2, paint: 0, clipping: 0, content_state: 0 };
  const g1 = PI.isolationSafe(rent), g2 = PI.isolationSafe(omatt), g3 = PI.isolationSafe(flertagg);
  const D = P3.D_isoleringsgrind;
  const blandat = PI.farBlandas({ ISOLERING_ANVAND: true }, { ISOLERING_ANVAND: false });
  prov('ACR-31', 'isoleringsgrinden ar fail closed i fyra dimensioner med negativ sentinel',
    PI.ISOLATION_DIMENSIONS.length === 4 &&
    g1.ISOLATION_SAFE === true && g2.ISOLATION_SAFE === false &&
    g2.omatta.includes('content_state') && g3.ISOLATION_SAFE === false &&
    PI.evidensbeslut(flertagg).BESLUT === PI.EVIDENSBESLUT.DISCARD_AND_RERENDER_WITHOUT_ISOLATION &&
    PI.isolationSafe(null).ISOLATION_SAFE === false &&
    !blandat.tillatet && PI.matningAnvanderIsolering() === false &&
    D.SENTINEL.SENTINEL_HALLER === true && D.SENTINEL.UTFALL === false &&
    D.UNDERKANDA >= 1 && D.ALLA_UNDERKANDA_OMRENDERADE === true &&
    D.MATNINGEN_ANVANDER_ISOLERING === false,
    'ren ' + g1.ISOLATION_SAFE + ', omatt dimension ' + g2.ISOLATION_SAFE +
    ', flertagg ' + g3.ISOLATION_SAFE + '; sentinel haller ' + D.SENTINEL.SENTINEL_HALLER +
    '; ' + D.UNDERKANDA + ' underkanda, alla omrenderade ' + D.ALLA_UNDERKANDA_OMRENDERADE); }

/* ── ACR-32 ─────────────────────────────────────────────────────────────── */
{ const g = P3.G_pilot3;
  const registrerade = new Set([...REC, ...SUP2, ...RU].map(x => x.RELATION_ID));
  prov('ACR-32', 'pilot 3 ar byggt ur den ogranskade kon med samma lasta regel',
    g.KANDIDATPOOL === 'UNREVIEWED_LT3_UNKNOWN' && g.SAMMA_REGEL_SOM_TIDIGARE === true &&
    g.INOM_GRANS === true && g.PILOT_OCCURRENCES >= 50 && g.PILOT_OCCURRENCES <= 80 &&
    g.OVERLAPP_MED_TIDIGARE_REGISTRERADE === 0 && g.STATE_OUT_OF_SCOPE === 0 &&
    g.poster.every(x => x.CURRENT_APPLICABILITY === 'UNKNOWN' &&
      x.REVIEW_STATUS === 'UNREVIEWED_UNKNOWN' && x.APPLICABILITY_RECORD_WRITTEN === false) &&
    g.poster.filter(x => registrerade.has(x.RELATION_ID)).length === 0 &&
    g.REGISTRERADE_DOMAR === 0,
    g.PILOT_OCCURRENCES + ' i ' + g.PILOT_GROUPS + ' grupper ur en pool om ' +
    g.KANDIDATPOOL_STORLEK + ', kvot ' + g.MIN_RATIO + '-' + g.MAX_RATIO +
    ', overlapp ' + g.OVERLAPP_MED_TIDIGARE_REGISTRERADE); }

/* ── ACR-33 ─────────────────────────────────────────────────────────────── */
{ const d = R2.D_reviewGroups;
  prov('ACR-33', 'pilot 2:s grupper bar fortfarande ingen dom',
    d.GRUPPER_MED_DOM === 0 && d.AUTOMATIC_EQUIVALENCE === 0 &&
    d.VERDICT_PROPAGATION === 0 && d.PERSISTENT_SEMANTIC_DECISION_IDENTITY_SKAPAD === 0 &&
    d.HUMAN_EQUIVALENCE_GATE === 'NOT_PASSED' &&
    d.grupper.every(g => g.GROUP_VERDICT === null && g.HUMAN_EQUIVALENCE_GATE === 'NOT_PASSED') &&
    [...SUP2, ...RU].every(x => x.GROUP_VERDICT === null &&
      x.REVIEW_GROUP_ROLE === 'PRESENTATION_ONLY' &&
      x.PERSISTENT_SEMANTIC_DECISION_IDENTITY === null) &&
    P3.C_reviewGroups.GRUPPER_MED_VERDICT === 0,
    d.ANTAL + ' grupper, ' + d.GRUPPER_MED_DOM + ' med dom, ' + d.VERDICT_PROPAGATION +
    ' propagering'); }

/* ── ACR-34 ─────────────────────────────────────────────────────────────── */
{ const sex = RU.filter(x => x.FAMILY === 'flermeny');
  const alltTargetScope = [...SUP2, ...RU].every(x =>
    !x.VERDICT_SCOPE || x.VERDICT_SCOPE === 'TARGET_PART_ONLY');
  const barare = sex.flatMap(x => x.OTHER_CARRIERS_UNCHANGED);
  prov('ACR-34', 'ingen generell princip skapas for de sex dagrutorna',
    sex.length === 6 &&
    sex.every(x => x.REVIEW_STATUS === AP.REVIEW_STATUS.REVIEWED_UNKNOWN &&
      x.APPLICABILITY_VERDICT === 'UNKNOWN' &&
      x.BLOCKER === AP.BLOCKERKLASS.STATE_SIGNAL_REDUNDANCY_NOT_ADJUDICATED) &&
    barare.every(c => c.APPLICABILITY === 'UNKNOWN' && !c.CHANGED_BY_THIS_RECORD) &&
    alltTargetScope && typeof R2.C_reviewedUnknown.$sexDagrutor === 'string',
    sex.length + ' dagrutor, alla REVIEWED_UNKNOWN med blockeraren ' +
    AP.BLOCKERKLASS.STATE_SIGNAL_REDUNDANCY_NOT_ADJUDICATED + '; ' + barare.length +
    ' barare oforandrade; allt target-scope: ' + alltTargetScope); }

/* ── ACR-35 ─────────────────────────────────────────────────────────────── */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status','--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  const L = P3.L_regression;
  prov('ACR-35', 'baselinet ar bitidentiskt efter registreringen av pilot 2',
    !fel && produkt.length === 0 && L.PRODUKTBASELINE_BITIDENTISK === true &&
    L.R02_PASS === 1375 && L.R02_MEASURED === 1375 && L.GRAPHICAL_PARTS === 1879 &&
    L.BOUNDARIES === 689 && L.PAINTED_CONTROL_SURFACES === 420 &&
    L.STANDALONE_GRAPHICS === 32 && L.R01_FINDINGS === 0 && L.KNOWN_REQUIRED_FAIL === 0 &&
    L.GEOMETRY_DELTA === 0 && L.CLIPPING_DELTA === 0 && L.PRODUCT_WRITES === 0 &&
    L.COLOR_WRITES === 0 && L.R04_WRITES === 0 && L.R04_CREDIT === 0 &&
    R2.$produktfilerOrorda === true,
    (fel || produkt.length + ' andrade produktfiler') + '; ' + L.HIT_TARGETS +
    ', ' + L.GRAPHICAL_PARTS + ' delar, ' + L.BOUNDARIES + ' kanter, ' +
    L.PAINTED_CONTROL_SURFACES + ' malade ytor, R-01 ' + L.R01_FINDINGS); }

/* ═══ BLOCKING-CARRIER PILOT · ACR-36 … ACR-45 ════════════════════════════
 * Proven nedan laser bararfrontiern: att den ar exakt fryst, att sonden ar
 * lika ren for ikoner som for kanter, att konformans hålls skild fran
 * tillamplighet, att en bararedom aldrig avgor en beroende fyllning, och —
 * viktigast — att ingen extrapolerar de 66:s rackvidd till hela kon. */
const R3 = JSON.parse(readFileSync(resolve('fas2/lagkontrast-register-pilot3.json'), 'utf8'));
const C66 = JSON.parse(readFileSync(resolve('fas2/lagkontrast-barare-66.json'), 'utf8'));
const CAR = C66.M_humanReviewPackage.poster;
const CENSUS = C66.N_census;

/* ── ACR-36 ─────────────────────────────────────────────────────────────── */
{ const r = R3.A_registrering, rec = R3.D_records;
  prov('ACR-36', 'de 50 fyllningarna i pilot 3 ar registrerade som granskade utan dom',
    r.REGISTERED_OCCURRENCES === 50 && r.NEW_REVIEWED_UNKNOWN === 50 &&
    r.NEW_REQUIRED === 0 && r.NEW_SUPPLEMENTAL === 0 && r.DUPLICATES === 0 &&
    r.OMITTED === 0 && r.OUT_OF_SCOPE === 0 && rec.length === 50 &&
    rec.every(x => x.APPLICABILITY_VERDICT === 'UNKNOWN' &&
      x.REVIEW_STATUS === AP.REVIEW_STATUS.REVIEWED_UNKNOWN &&
      Array.isArray(x.BLOCKER_RELATION_IDS) && x.BLOCKER_RELATION_IDS.length > 0 &&
      x.ELIGIBLE_FOR_MECHANICAL_PILOT === false &&
      x.TARGET_FILL_CONTRIBUTES_DISTINGUISHABLE_VISUAL_INFORMATION === 'YES') &&
    R3.C_grindar.every(g => g.ok),
    r.REGISTERED_OCCURRENCES + ' registrerade, ' + r.UNIKA_BLOCKER_RELATIONER +
    ' unika blockerare, ' + R3.C_grindar.length + ' grindar'); }

/* ── ACR-37 ─────────────────────────────────────────────────────────────── */
{ const q = C66.Q_status, P_ = C66.P_regression;
  prov('ACR-37', 'LT3 delas exakt i granskade och ogranskade',
    q.LT3_UNKNOWN === 424 && q.REVIEWED_UNKNOWN_LT3 === 62 &&
    q.UNREVIEWED_UNKNOWN_LT3 === 362 &&
    q.LT3_UNKNOWN === q.REVIEWED_UNKNOWN_LT3 + q.UNREVIEWED_UNKNOWN_LT3 &&
    q.GE3_UNKNOWN === 1218 && q.UNKNOWN_APPLICABILITY === 1642 &&
    q.UNKNOWN_APPLICABILITY === q.LT3_UNKNOWN + q.GE3_UNKNOWN &&
    q.KNOWN_REQUIRED_FAIL === 0 && P_.REVIEWED_UNKNOWN === 62 && P_.UNREVIEWED_UNKNOWN === 362,
    q.LT3_UNKNOWN + ' = ' + q.REVIEWED_UNKNOWN_LT3 + ' + ' + q.UNREVIEWED_UNKNOWN_LT3 +
    ', totalt ' + q.UNKNOWN_APPLICABILITY + ', KNOWN_REQUIRED_FAIL ' + q.KNOWN_REQUIRED_FAIL); }

/* ── ACR-38 ─────────────────────────────────────────────────────────────── */
{ const b = C66.B_frontier, d = C66.D_inventering;
  const fills = new Set(R3.D_records.map(x => x.RELATION_ID));
  const allaLankar = CAR.every(x => x.DEPENDENT_FILL_COUNT > 0 &&
    x.DEPENDENT_FILL_RELATIONS.every(id => fills.has(id)));
  prov('ACR-38', 'bararfrontiern ar exakt 66 och fordelningen sluter',
    b.BLOCKING_CARRIER_RELATIONS === 66 && b.ICONS === 55 && b.BOUNDARIES === 11 &&
    b.ICON_GE3 === 22 && b.ICON_LT3 === 33 && b.BOUNDARY_GE3 === 5 && b.BOUNDARY_LT3 === 6 &&
    b.LT3_BLOCKERS === 39 && b.GE3_BLOCKERS === 27 && b.SUMMERAR === true &&
    b.DUPLICATES === 0 && b.UNRESOLVED_IDENTITY === 0 && b.MISSING_BLOCKER_LINK === 0 &&
    b.ALLA_UNKNOWN === true && b.TACKTA_FILLS === 50 &&
    d.ANTAL === 66 && d.DUPLICATES === 0 && d.UNRESOLVED_IDENTITY === 0 &&
    d.MISSING_BLOCKER_LINK === 0 && allaLankar,
    b.BLOCKING_CARRIER_RELATIONS + ' = ' + b.ICONS + ' ikoner + ' + b.BOUNDARIES +
    ' kanter; ' + b.LT3_BLOCKERS + ' LT3 / ' + b.GE3_BLOCKERS + ' GE3; alla lankar tillbaka: ' +
    allaLankar); }

/* ── ACR-39 ─────────────────────────────────────────────────────────────── */
{ const c = C66.C_scope, n = CENSUS;
  const partition = Object.values(n.EXKLUSIV_PARTITION).reduce((a,b)=>a+b,0);
  prov('ACR-39', 'de 66:s rackvidd extrapoleras aldrig till hela kon',
    c.BEVISAT_SCOPE.includes('50 fills i pilot 3') &&
    typeof c.EJ_PASTATT === 'string' && c.UNREVIEWED_LT3_UTANFOR_PILOT_3 === 362 &&
    n.UNREVIEWED_LT3 === 362 && partition === 362 && n.PARTITION_SUMMERAR === true &&
    n.OVERLAPPANDE_KATEGORIER.DEPENDENT_ON_EXISTING_66 < 362 &&
    n.NYA_BLOCKERARE_UNIKA > 0 &&
    typeof n.OVERLAPPANDE_KATEGORIER.MEASUREMENT_GAP === 'number' &&
    typeof n.OVERLAPPANDE_KATEGORIER.MULTIPLE_BLOCKERS === 'number' &&
    typeof n.OVERLAPPANDE_KATEGORIER.$overlapp === 'string',
    'bevisat scope ' + c.BEVISAT_SCOPE + '; av ' + n.UNREVIEWED_LT3 + ' kvarvarande beror ' +
    n.OVERLAPPANDE_KATEGORIER.DEPENDENT_ON_EXISTING_66 + ' pa de 66, ' +
    n.NYA_BLOCKERARE_UNIKA + ' nya blockerare finns'); }

/* ── ACR-40 ─────────────────────────────────────────────────────────────── */
{ const g = C66.E_G_sond;
  const rena = CAR.filter(x => x.COUNTERFACTUAL.GEOMETRY_DELTA === 0 &&
    x.COUNTERFACTUAL.CONTENT_STATE_DELTA === 0 &&
    x.COUNTERFACTUAL.UNRELATED_PAINT_DELTA === 0 &&
    x.COUNTERFACTUAL.RESTORATION_DELTA === 0 &&
    x.COUNTERFACTUAL.GEOMETRIEGENSKAPER_BEVARADE === true &&
    x.COUNTERFACTUAL.NEUTRALISERAD === true);
  const ingenArv = CAR.every(x => x.ARV.anvanderCurrentColor === false);
  const utanDom = CAR.filter(x => x.SOURCE_PROBE_STATUS === 'PROBE_UNSAFE' &&
    x.PROPOSED_VERDICT !== AP.FORSLAG.PROPOSED_UNKNOWN);
  prov('ACR-40', 'kontrafaktisk sond for alla 66 ar ren och lokal',
    g.PROBES === 66 && g.PROBE_CLEAN === 66 && g.PROBE_UNSAFE === 0 &&
    g.GEOMETRY_DELTA_TOTALT === 0 && g.CONTENT_STATE_DELTA_TOTALT === 0 &&
    g.UNRELATED_PAINT_DELTA_TOTALT === 0 && g.RESTORATION_DELTA_TOTALT === 0 &&
    g.SOURCE_BIT_IDENTICAL === true && g.PERMANENT_WRITES === 0 &&
    rena.length === 66 && ingenArv && utanDom.length === 0 &&
    CAR.every(x => /NEUTRALIZED/.test(x.COUNTERFACTUAL.OPERATION)),
    g.PROBES + ' sonder, ' + g.PROBE_CLEAN + ' rena, ' + g.PROBE_UNSAFE +
    ' unsafe; geometri ' + g.GEOMETRY_DELTA_TOTALT + ', innehall/tillstand ' +
    g.CONTENT_STATE_DELTA_TOTALT + ', ovrig malning ' + g.UNRELATED_PAINT_DELTA_TOTALT); }

/* ── ACR-41 ─────────────────────────────────────────────────────────────── */
{ const h = C66.H_konformitetsutfall;
  const suppBadaBand = new Set(CAR.filter(x => x.PROPOSED_VERDICT ===
    AP.FORSLAG.PROPOSED_SUPPLEMENTAL_NOT_REQUIRED).map(x => x.band));
  const reqBand = new Set(CAR.filter(x => x.PROPOSED_VERDICT ===
    AP.FORSLAG.PROPOSED_REQUIRED).map(x => x.band));
  const tabell = CAR.every(x => x.KONFORMITETSUTFALL.OM_REQUIRED ===
      (x.CURRENT_RATIO < 3 ? 'REQUIRED_FAIL' : 'REQUIRED_PASS') &&
    x.KONFORMITETSUTFALL.OM_UNKNOWN === 'fortsatt UNKNOWN');
  prov('ACR-41', 'konformans hålls skilt fran tillamplighet och kvoten domer aldrig',
    h.LT3_OM_REQUIRED === 'REQUIRED_FAIL' && h.GE3_OM_REQUIRED === 'REQUIRED_PASS' &&
    h.OM_UNKNOWN === 'fortsatt UNKNOWN' && tabell &&
    suppBadaBand.has('LT_3') && suppBadaBand.has('GE_3') &&
    reqBand.size === 1 && CAR.every(x => x.APPLICABILITY_RECORD_WRITTEN === false),
    'supplemental forekommer i band ' + [...suppBadaBand].join('+') +
    ', required i ' + [...reqBand].join('+') + '; utfallstabellen stammer for alla ' +
    CAR.length); }

/* ── ACR-42 ─────────────────────────────────────────────────────────────── */
{ const i = C66.I_alternativaSignaler;
  const supp = CAR.filter(x => x.PROPOSED_VERDICT === AP.FORSLAG.PROPOSED_SUPPLEMENTAL_NOT_REQUIRED);
  const utpekade = supp.every(x => x.ALTERNATIVE_SIGNALS_IF_SUPPLEMENTAL &&
    x.ALTERNATIVE_SIGNALS_IF_SUPPLEMENTAL.grafiskaBarare.length > 0 &&
    x.ALTERNATIVE_SIGNALS_IF_SUPPLEMENTAL.grafiskaBarare.every(y => y.KANONISK_RELATION) &&
    typeof x.ALTERNATIVE_SIGNALS_IF_SUPPLEMENTAL.$ejUteslutning === 'string');
  const forbjuden = /darfor att den andra bararen ar required|because the other carrier is required/i;
  const smitta = CAR.filter(x => forbjuden.test(x.PROPOSAL_SKAL));
  prov('ACR-42', 'alternativa signaler pekas ut exakt och ingen dom harleds genom uteslutning',
    i.MED_UTPEKADE_SIGNALER === supp.length && i.ALLA_SIGNALER_KANONISKA === true &&
    utpekade && smitta.length === 0 && i.JOINT_CONSTRAINTS > 0 &&
    typeof i.$ejUteslutning === 'string' &&
    CAR.filter(x => x.JOINT_CONSTRAINT).every(x => /minst en av/.test(x.JOINT_CONSTRAINT)),
    supp.length + ' supplemental-forslag, alla med utpekade kanoniska signaler: ' + utpekade +
    '; ' + i.JOINT_CONSTRAINTS + ' joint constraints; ' + smitta.length +
    ' uteslutningsformuleringar'); }

/* ── ACR-43 ─────────────────────────────────────────────────────────────── */
{ const j = C66.J_dependencyEffekt;
  const rec = R3.D_records;
  prov('ACR-43', 'en bararedom avgor aldrig automatiskt nagon beroende fyllning',
    j.PAVERKAR_BEROENDE_FILLS_AUTOMATISKT === false &&
    j.SKAPAR_ENDAST === 'BLOCKING_CARRIER_ADJUDICATED' &&
    j.FORBJUDNA_REGLER.length === 4 &&
    j.FORBJUDNA_REGLER.includes('BOUNDARY_REQUIRED -> FILL_SUPPLEMENTAL') &&
    j.FORBJUDNA_REGLER.includes('ICON_SUPPLEMENTAL -> FILL_REQUIRED') &&
    j.BEROENDE_FILLS === 50 &&
    CAR.every(x => x.DEPENDENCY_EFFEKT.PAVERKAR_BEROENDE_FILLS_AUTOMATISKT === false) &&
    rec.every(x => x.APPLICABILITY_VERDICT === 'UNKNOWN') &&
    AP.farArvaDom() === false &&
    AP.harleddDom('BOUNDARY_REQUIRED','FILL_SUPPLEMENTAL').tillatet === false,
    j.BEROENDE_FILLS + ' beroende fyllningar, alla fortfarande UNKNOWN; ' +
    j.FORBJUDNA_REGLER.length + ' forbjudna regler listade'); }

/* ── ACR-44 ─────────────────────────────────────────────────────────────── */
{ const k = C66.K_grupper;
  prov('ACR-44', 'bararpilotens presentationsgrupper bar ingen dom',
    k.GRUPPER_MED_DOM === 0 && k.HUMAN_EQUIVALENCE_GATE === 'NOT_PASSED' &&
    k.grupper.every(g => g.GROUP_VERDICT === null &&
      g.HUMAN_EQUIVALENCE_GATE === 'NOT_PASSED') &&
    k.grupper.reduce((a,g) => a + g.OCCURRENCES, 0) === 66 &&
    k.TILLATNA_FAKTA.length === 6,
    k.ANTAL + ' grupper over ' + k.grupper.reduce((a,g)=>a+g.OCCURRENCES,0) +
    ' forekomster, ' + k.GRUPPER_MED_DOM + ' med dom'); }

/* ── ACR-45 ─────────────────────────────────────────────────────────────── */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status','--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  const L = C66.P_regression, m = C66.M_humanReviewPackage;
  prov('ACR-45', 'inget carrier verdict registrerat och baselinet ar bitidentiskt',
    !fel && produkt.length === 0 && m.REGISTRERADE_CARRIER_VERDICTS === 0 &&
    m.SUMMERAR === true && CAR.length === 66 &&
    CAR.every(x => x.APPLICABILITY_RECORD_WRITTEN === false &&
      x.CURRENT_APPLICABILITY === 'UNKNOWN' && x.R04_CREDIT === 0) &&
    L.PRODUKTBASELINE_BITIDENTISK === true && L.R02_PASS === 1375 &&
    L.GRAPHICAL_PARTS === 1879 && L.BOUNDARIES === 689 &&
    L.PAINTED_CONTROL_SURFACES === 420 && L.STANDALONE_GRAPHICS === 32 &&
    L.R01_FINDINGS === 0 && L.KNOWN_REQUIRED_FAIL === 0 && L.PRODUCT_WRITES === 0 &&
    L.COLOR_WRITES === 0 && L.R04_WRITES === 0 && L.R04_CREDIT === 0 &&
    C66.$produktfilerOrorda === true,
    (fel || produkt.length + ' andrade produktfiler') + '; ' + m.PROPOSED_REQUIRED_GE3 +
    ' required + ' + m.PROPOSED_SUPPLEMENTAL + ' supplemental + ' + m.PROPOSED_UNKNOWN +
    ' unknown = ' + CAR.length + ' forslag, ' + m.REGISTRERADE_CARRIER_VERDICTS +
    ' registrerade'); }

/* ═══ BARARDOMARNA REGISTRERADE · ACR-46 … ACR-57 ═════════════════════════
 * Den farligaste genvagen i det har steget ar summering: tva korrekta
 * enskilda SUPPLEMENTAL-domar far aldrig laggas ihop till "bada far tas
 * bort". Proven laser den invarianten maskinellt, inte i prosa. */
const RS = await import('file://' + resolve('tools/redundancy-set.mjs').replace(/\\/g,'/'));
const R4 = JSON.parse(readFileSync(resolve('fas2/lagkontrast-register-barare66.json'), 'utf8'));
const RR = JSON.parse(readFileSync(resolve('fas2/lagkontrast-rereview-50.json'), 'utf8'));
const REQ = R4.A_required.records, SUP = R4.B_supplemental.records;
const SETS = R4.C_redundansset.set;

/* ── ACR-46 ─────────────────────────────────────────────────────────────── */
prov('ACR-46', 'exakt 6 REQUIRED och 60 SUPPLEMENTAL_NOT_REQUIRED registrerade',
  REQ.length === 6 && SUP.length === 60 && R4.F_records.length === 66 &&
  new Set(R4.F_records.map(x => x.RELATION_ID)).size === 66 &&
  R4.F_records.filter(x => x.APPLICABILITY_VERDICT === 'UNKNOWN').length === 0 &&
  R4.F_records.every(x => x.VERDICT_SCOPE === 'TARGET_PART_ONLY' &&
    x.VERDICT_PROVENANCE === 'HUMAN_OCCURRENCE_ADJUDICATION') &&
  R4.E_grindar.every(g => g.ok),
  REQ.length + ' + ' + SUP.length + ' = ' + R4.F_records.length + ', ' +
  R4.E_grindar.length + ' grindar');

/* ── ACR-47 ─────────────────────────────────────────────────────────────── */
prov('ACR-47', 'de sex REQUIRED ligger samtliga pa eller over 3.0 och passerar',
  REQ.every(x => x.CURRENT_RATIO >= 3 && x.CURRENT_OUTCOME === 'REQUIRED_PASS') &&
  R4.A_required.REQUIRED_PASS === 6 && R4.A_required.REQUIRED_FAIL === 0 &&
  REQ.every(x => x.CARRIER_CLASS === 'DRAG_HANDLE') &&
  REQ.every(x => x.DOES_NOT_IMPLY.includes('PROPAGATION_TO_OTHER_DRAG_ICONS')) &&
  RR.E_rekonciliation.EFTER.KNOWN_REQUIRED_FAIL === 0,
  'kvoter ' + [...new Set(REQ.map(x => x.CURRENT_RATIO))].join(',') + ', REQUIRED_PASS ' +
  R4.A_required.REQUIRED_PASS + ', REQUIRED_FAIL ' + R4.A_required.REQUIRED_FAIL);

/* ── ACR-48 ─────────────────────────────────────────────────────────────── */
{ const suppBadaBand = new Set(SUP.map(x => x.CURRENT_RATIO < 3 ? 'LT_3' : 'GE_3'));
  const kastar1 = kastar(() => AP.forslag({ COUNTERFACTUAL_KORD: true, MEASURED_RATIO: 9 }));
  prov('ACR-48', 'kvoten skapar aldrig en applicability-dom',
    kastar1 && suppBadaBand.size === 2 &&
    REQ.every(x => x.CURRENT_RATIO >= 3) &&
    SUP.some(x => x.CURRENT_RATIO >= 3) && SUP.some(x => x.CURRENT_RATIO < 3) &&
    R4.F_records.every(x => x.VERDICT_PROVENANCE === 'HUMAN_OCCURRENCE_ADJUDICATION'),
    'supplemental forekommer i ' + [...suppBadaBand].join('+') +
    '; forslagsfunktionen kastar pa kvot: ' + kastar1); }

/* ── ACR-49 ─────────────────────────────────────────────────────────────── */
{ const smitta = R4.F_records.filter(x => x.OTHER_CARRIERS_UNCHANGED
    .some(c => c.CHANGED_BY_THIS_RECORD || c.APPLICABILITY_BEFORE !== c.APPLICABILITY_AFTER));
  prov('ACR-49', 'en supplemental-dom skapar aldrig requiredness pa en syskonbarare',
    smitta.length === 0 &&
    SUP.every(x => x.DOES_NOT_IMPLY.includes('OTHER_CARRIER_REQUIRED') &&
      x.DOES_NOT_IMPLY.includes('OTHER_CARRIER_SUPPLEMENTAL') &&
      x.DOES_NOT_IMPLY.includes('CONTROL_CONFORMING')) &&
    RS.harledMedlemsdom().tillatet === false && AP.farArvaDom() === false,
    smitta.length + ' record som andrat en syskonbarare; alla ' + SUP.length +
    ' bar DOES_NOT_IMPLY'); }

/* ── ACR-50 ─────────────────────────────────────────────────────────────── */
{ const s = SETS[0];
  const bada = RS.redundancyGate(s, Object.fromEntries(s.MEMBERS.map(m => [m, false])));
  const en = RS.redundancyGate(s, Object.fromEntries(s.MEMBERS.map((m,i) => [m, i === 0])));
  const omatt = RS.redundancyGate(s, {});
  prov('ACR-50', 'ett redundansset kraver minst en urskiljbar member',
    SETS.length >= 1 && SETS.every(x => x.MIN_DISTINGUISHABLE_MEMBERS === 1 &&
      x.MEMBERS.length >= 2 &&
      x.PROVENANCE === RS.PROVENANS.HUMAN_OCCURRENCE_ADJUDICATION) &&
    !bada.HALLER && en.HALLER && !omatt.HALLER &&
    kastar(() => RS.redundancySet({ REDUNDANCY_SET_ID: 'X', MEMBERS: ['a'],
      PROVENANCE: RS.PROVENANS.HUMAN_OCCURRENCE_ADJUDICATION })) &&
    kastar(() => RS.redundancySet({ REDUNDANCY_SET_ID: 'X', MEMBERS: ['a','b'],
      PROVENANCE: 'GROUPING_ALGORITHM' })),
    SETS.length + ' set; bada neutraliserade ' + bada.HALLER + ', en kvar ' + en.HALLER +
    ', omatt ' + omatt.HALLER); }

/* ── ACR-51 ─────────────────────────────────────────────────────────────── */
{ const alla = SETS.map(s => RS.farNeutraliseraSamtidigt(s,
    Object.fromEntries(s.MEMBERS.map(m => [m, 'SUPPLEMENTAL_NOT_REQUIRED']))));
  const domar = new Map(R4.F_records.map(x => [x.RELATION_ID, x.APPLICABILITY_VERDICT]));
  const badaSupp = SETS.filter(s => s.MEMBERS.filter(m =>
    domar.get(m) === 'SUPPLEMENTAL_NOT_REQUIRED').length >= 1);
  prov('ACR-51', 'tva supplemental-domar gor inte samtidigt forsvinnande giltigt',
    alla.every(x => x.tillatet === false) &&
    alla.every(x => x.grind.HALLER === false) &&
    alla.some(x => x.allaSupplemental === true || x.allaSupplemental === false) &&
    badaSupp.length > 0 &&
    SETS.every(s => s.IMPLIES_MEMBER_REQUIRED === false && s.GROUP_VERDICT === null),
    'alla ' + SETS.length + ' set nekar samtidig neutralisering; grinden faller i samtliga'); }

/* ── ACR-52 ─────────────────────────────────────────────────────────────── */
{ const svaga = R4.F_records.filter(x => x.ALL_REMAINING_SIGNALS_BELOW_FLOOR);
  prov('ACR-52', 'svaga kvarvarande signaler ger ingen control-level closure',
    R4.D_svagaSignaler.ANTAL === svaga.length && svaga.length === 50 &&
    R4.D_svagaSignaler.CONTROL_LEVEL_CLOSURE === false &&
    R4.F_records.every(x => x.CONTROL_LEVEL_CLOSURE === false) &&
    RS.gerControlLevelClosure() === false &&
    svaga.every(x => x.OTHER_CARRIERS_UNCHANGED.every(c =>
      c.APPLICABILITY_BEFORE === c.APPLICABILITY_AFTER)),
    svaga.length + ' med svaga kvarvarande signaler, ' +
    R4.F_records.filter(x => x.CONTROL_LEVEL_CLOSURE).length + ' control-level closure'); }

/* ── ACR-53 ─────────────────────────────────────────────────────────────── */
{ const f = RR.F_de50, g = RR.G_rereview;
  prov('ACR-53', 'en upplast blockerare skapar bara RE_REVIEW_ELIGIBLE',
    f.ALL_REFERENCED_BLOCKERS_RESOLVED === 50 && f.RE_REVIEW_ELIGIBLE === 50 &&
    f.KVARSTAENDE_BLOCKERADE.length === 0 && f.ALLA_FORTFARANDE_UNKNOWN === true &&
    f.AUTOMATISKA_DOMAR === 0 && g.ALLA_FORTFARANDE_UNKNOWN === true &&
    g.REGISTRERADE_DOMAR === 0 &&
    g.poster.every(x => x.ATEROPPNINGSSKAL === 'BLOCKING_CARRIER_ADJUDICATED' &&
      x.CURRENT_APPLICABILITY === 'UNKNOWN'),
    f.RE_REVIEW_ELIGIBLE + ' av 50 upplasta, ' + f.AUTOMATISKA_DOMAR + ' automatiska domar'); }

/* ── ACR-54 ─────────────────────────────────────────────────────────────── */
{ const g = RR.G_rereview;
  prov('ACR-54', 'ett bararedomslut propagerar aldrig till en fyllningsdom',
    g.DEPENDENCY_PROPAGATION === 0 &&
    g.poster.every(x => x.DEPENDENCY_PROPAGATION === false &&
      x.FORBJUDNA_HARLEDNINGAR.length === 4 &&
      x.FORBJUDNA_HARLEDNINGAR.includes('BOUNDARY_SUPPLEMENTAL -> FILL_REQUIRED') &&
      x.FORBJUDNA_HARLEDNINGAR.includes('ICON_REQUIRED -> FILL_SUPPLEMENTAL') &&
      x.APPLICABILITY_RECORD_WRITTEN === false) &&
    AP.harleddDom('ICON_SUPPLEMENTAL','FILL_REQUIRED').tillatet === false &&
    g.FORESLAGNA_NYA_SET > 0 && g.REGISTRERADE_DOMAR === 0 &&
    RR.C_redundansset.foreslagna.every(s => s.PROVENANCE === null &&
      s.GROUP_VERDICT === null && /FORESLAGET/.test(s.STATUS)) &&
    RR.C_redundansset.foreslagna.length === g.FORESLAGNA_NYA_SET,
    g.DEPENDENCY_PROPAGATION + ' propageringar; ' + g.FORESLAGNA_NYA_SET +
    ' nya redundansset foreslagna, inga skapade'); }

/* ── ACR-55 ─────────────────────────────────────────────────────────────── */
{ const h = RR.H_census, e = RR.E_rekonciliation;
  const partition = Object.values(h.EXKLUSIV_PARTITION).reduce((a,b)=>a+b,0);
  prov('ACR-55', 'no-blocker-frontiern ar omraknad, inte aterbrukad',
    h.UNREVIEWED_UNKNOWN === 323 && h.UNREVIEWED_UNKNOWN !== 362 &&
    partition === h.UNREVIEWED_UNKNOWN && h.PARTITION_SUMMERAR === true &&
    h.LT3_UNKNOWN === 385 && h.REVIEWED_UNKNOWN === 62 &&
    h.LT3_UNKNOWN === h.REVIEWED_UNKNOWN + h.UNREVIEWED_UNKNOWN &&
    typeof h.GAMLA_147_FAR_EJ_ANVANDAS === 'string' &&
    typeof h.$gamla147 === 'string' && h.MEASUREMENT_GAP === 0 &&
    e.EFTER.LT3_UNKNOWN === h.LT3_UNKNOWN,
    'population ' + h.UNREVIEWED_UNKNOWN + ' (var 362), partition ' + partition +
    ', LT3 ' + h.LT3_UNKNOWN + ' = ' + h.REVIEWED_UNKNOWN + ' + ' + h.UNREVIEWED_UNKNOWN); }

/* ── ACR-56 ─────────────────────────────────────────────────────────────── */
{ const i = RR.I_typrakning;
  const summa = Object.values(i.TYPE_COUNTS).reduce((a,b)=>a+b,0);
  prov('ACR-56', 'typrakningen for de 362 summerar exakt',
    summa === 362 && i.TOTAL === 362 && i.UNCLASSIFIED === 0 &&
    i.SAKNADE_TRE.length === 3 &&
    i.SAKNADE_TRE.every(x => x.kanoniskTyp === 'thumb') &&
    Object.keys(i.TYPE_COUNTS).length === 4 && i.SUMMERAR === true &&
    i.RAPPORTERAT_I_PROSA.fyllning + i.RAPPORTERAT_I_PROSA.ram +
      i.RAPPORTERAT_I_PROSA.ikon === 359,
    JSON.stringify(i.TYPE_COUNTS) + ' = ' + summa + '; de tre saknade ar ' +
    i.SAKNADE_TRE.map(x => x.kanoniskTyp).join(',')); }

/* ── ACR-57 ─────────────────────────────────────────────────────────────── */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status','--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  const K = RR.K_regression, e2 = RR.E_rekonciliation;
  prov('ACR-57', 'inga produkt-, farg- eller R-04-skrivningar och exakt rekonciliation',
    !fel && produkt.length === 0 && K.PRODUCT_WRITES === 0 && K.COLOR_WRITES === 0 &&
    K.R04_WRITES === 0 && K.R04_CREDIT === 0 && K.PRODUKTBASELINE_BITIDENTISK === true &&
    K.R02_PASS === 1375 && K.GRAPHICAL_PARTS === 1879 && K.BOUNDARIES === 689 &&
    K.PAINTED_CONTROL_SURFACES === 420 && K.STANDALONE_GRAPHICS === 32 &&
    K.R01_FINDINGS === 0 && K.KNOWN_REQUIRED_FAIL === 0 &&
    e2.FORE.UNKNOWN_APPLICABILITY === 1642 && e2.EFTER.UNKNOWN_APPLICABILITY === 1576 &&
    e2.FORE.LT3_UNKNOWN === 424 && e2.EFTER.LT3_UNKNOWN === 385 &&
    e2.FORE.GE3_UNKNOWN === 1218 && e2.EFTER.GE3_UNKNOWN === 1191 &&
    e2.NEW_REQUIRED_PASS === 6 && e2.NEW_SUPPLEMENTAL_NOT_REQUIRED === 60 &&
    e2.ANDRADE_UTANFOR_REGISTRERINGEN.length === 0 && e2.SLUTER === true &&
    RR.M_status.REGISTRERADE_FILL_VERDICTS_I_DETTA_BLOCK === 0,
    (fel || produkt.length + ' andrade produktfiler') + '; ' +
    e2.FORE.UNKNOWN_APPLICABILITY + ' -> ' + e2.EFTER.UNKNOWN_APPLICABILITY +
    ', LT3 ' + e2.FORE.LT3_UNKNOWN + ' -> ' + e2.EFTER.LT3_UNKNOWN +
    ', GE3 ' + e2.FORE.GE3_UNKNOWN + ' -> ' + e2.EFTER.GE3_UNKNOWN); }

/* ═══ ATOMISK REGISTRERING + DIRECT FRONTIER · ACR-58 … ACR-71 ════════════
 * Har laser proven det farligaste steget hittills: att en fyllning aldrig far
 * bli SUPPLEMENTAL utan att dess redundansskydd finns i samma transaktion. */
const R5 = JSON.parse(readFileSync(resolve('fas2/lagkontrast-register-rereview50.json'), 'utf8'));
const DF = JSON.parse(readFileSync(resolve('fas2/lagkontrast-direct-147.json'), 'utf8'));
const R5REC = R5.F_records, RSETS = R5.D_redundansset.set, DISP = R5.C_safeguardDisposition.poster;

/* ── ACR-58 ─────────────────────────────────────────────────────────────── */
prov('ACR-58', 'exakt 50 supplemental-domar pa 50 target-identiteter',
  R5.A_registrering.REGISTERED === 50 && R5REC.length === 50 &&
  new Set(R5REC.map(x => x.RELATION_ID)).size === 50 &&
  R5.A_registrering.DUPLICATES === 0 && R5.A_registrering.OMITTED === 0 &&
  R5.A_registrering.OUT_OF_SCOPE === 0 &&
  R5REC.every(x => x.APPLICABILITY_VERDICT === 'SUPPLEMENTAL_NOT_REQUIRED' &&
    x.VERDICT_SCOPE === 'TARGET_PART_ONLY' && x.TARGET === 'FILL_RELATION' &&
    x.GRAPHICAL_PART_TYPE === 'fyllning') &&
  R5.E_grindar.every(g => g.ok),
  R5REC.length + ' record, ' + new Set(R5REC.map(x => x.RELATION_ID)).size +
  ' unika, ' + R5.E_grindar.length + ' grindar');

/* ── ACR-59 ─────────────────────────────────────────────────────────────── */
prov('ACR-59', 'ingen dom propagerade fran en barare',
  R5.A_registrering.PROPAGATED_VERDICTS === 0 &&
  R5REC.every(x => x.PROPAGATED_FROM_CARRIER === false &&
    x.DEPENDENCY_PROPAGATION === false && x.DEPENDENCY_EVIDENCE_ANVAND === true &&
    x.DOES_NOT_IMPLY.includes('SIBLING_REQUIRED') &&
    x.DOES_NOT_IMPLY.includes('SIBLING_SUPPLEMENTAL') &&
    x.DOES_NOT_IMPLY.includes('CONTROL_CONFORMING') &&
    x.OTHER_CARRIERS_UNCHANGED.every(c => !c.CHANGED_BY_THIS_RECORD)) &&
  AP.harleddDom('SIBLING_SUPPLEMENTAL','TARGET_REQUIRED').tillatet === false,
  R5.A_registrering.PROPAGATED_VERDICTS + ' propagerade; alla ' + R5REC.length +
  ' bar DOES_NOT_IMPLY med ' + R5.A_registrering.OMFATTAR_INTE.length + ' poster');

/* ── ACR-60 ─────────────────────────────────────────────────────────────── */
{ const idn = new Set(RSETS.map(s => s.REDUNDANCY_SET_ID));
  const utanSkydd = R5REC.filter(x => x.SAFEGUARD_DISPOSITION !== 'NO_RSET_REQUIRED' &&
    (!x.REDUNDANCY_SET_ID || !idn.has(x.REDUNDANCY_SET_ID) ||
     !RSETS.find(s => s.REDUNDANCY_SET_ID === x.REDUNDANCY_SET_ID)
       .MEMBER_RELATION_IDS.includes(x.RELATION_ID)));
  prov('ACR-60', 'dom och redundansset registreras atomiskt utan mellanstatus',
    utanSkydd.length === 0 && typeof R5.$atomicitet === 'string' &&
    R5.D_redundansset.NYA_I_DENNA_TRANSAKTION > 0 &&
    R5.D_redundansset.AKTIVA_TOTALT === R5.D_redundansset.BEFINTLIGA +
      R5.D_redundansset.NYA_I_DENNA_TRANSAKTION &&
    RSETS.filter(s => s.NY_I_DENNA_TRANSAKTION).every(s =>
      Array.isArray(s.SKAPAT_TILLSAMMANS_MED) && s.SKAPAT_TILLSAMMANS_MED.length > 0),
    utanSkydd.length + ' domar utan aktivt skydd; ' + R5.D_redundansset.AKTIVA_TOTALT +
    ' aktiva set varav ' + R5.D_redundansset.NYA_I_DENNA_TRANSAKTION + ' nya'); }

/* ── ACR-61 ─────────────────────────────────────────────────────────────── */
{ const p2 = R5.C_safeguardDisposition.PARTITION;
  const summa = Object.values(p2).reduce((a,b)=>a+b,0);
  prov('ACR-61', 'varje forekomst har exakt en safeguard-disposition',
    DISP.length === 50 && new Set(DISP.map(d => d.RELATION_ID)).size === 50 &&
    summa === 50 && !p2.OKANT &&
    DISP.every(d => ['EXISTING_RSET','NEW_RSET_REQUIRED','NO_RSET_REQUIRED']
      .includes(d.SAFEGUARD_DISPOSITION)) &&
    R5REC.every(x => DISP.some(d => d.RELATION_ID === x.RELATION_ID &&
      d.SAFEGUARD_DISPOSITION === x.SAFEGUARD_DISPOSITION)),
    JSON.stringify(p2) + ' = ' + summa); }

/* ── ACR-62 ─────────────────────────────────────────────────────────────── */
prov('ACR-62', 'varje redundansset ar maskinlasbart och stodjer tre members',
  RSETS.every(s => typeof s.REDUNDANCY_SET_ID === 'string' &&
    Array.isArray(s.MEMBER_RELATION_IDS) && s.MEMBER_RELATION_IDS.length >= 2 &&
    Number.isInteger(s.MIN_DISTINGUISHABLE_MEMBERS) &&
    s.PROVENANCE === RS.PROVENANS.HUMAN_OCCURRENCE_ADJUDICATION &&
    ['HOLDS','VIOLATED'].includes(s.CURRENT_VALIDITY) &&
    s.GROUP_VERDICT === null && s.IMPLIES_MEMBER_REQUIRED === false) &&
  RSETS.some(s => s.MEMBER_RELATION_IDS.length === 3) &&
  R5.D_redundansset.MED_TRE_MEMBERS > 0 &&
  R5.D_redundansset.falt.length === 5 &&
  R5.D_redundansset.AR_INTE.length === 5,
  RSETS.length + ' set, ' + R5.D_redundansset.MED_TRE_MEMBERS + ' med tre members');

/* ── ACR-63 ─────────────────────────────────────────────────────────────── */
{ const treSet = RSETS.find(s => s.MEMBER_RELATION_IDS.length === 3);
  const alla = RSETS.map(s => RS.redundancyGate(
    { MEMBERS: s.MEMBER_RELATION_IDS, MIN_DISTINGUISHABLE_MEMBERS: s.MIN_DISTINGUISHABLE_MEMBERS },
    Object.fromEntries(s.MEMBER_RELATION_IDS.map(m => [m, false]))));
  const en = RSETS.map(s => RS.redundancyGate(
    { MEMBERS: s.MEMBER_RELATION_IDS, MIN_DISTINGUISHABLE_MEMBERS: s.MIN_DISTINGUISHABLE_MEMBERS },
    Object.fromEntries(s.MEMBER_RELATION_IDS.map((m,i) => [m, i === 0]))));
  const treUtanTva = treSet ? RS.redundancyGate(
    { MEMBERS: treSet.MEMBER_RELATION_IDS, MIN_DISTINGUISHABLE_MEMBERS: 1 },
    Object.fromEntries(treSet.MEMBER_RELATION_IDS.map((m,i) => [m, i === 2]))) : null;
  prov('ACR-63', 'MIN_DISTINGUISHABLE_MEMBERS upprätthålls i alla aktiva set',
    RSETS.every(s => s.MIN_DISTINGUISHABLE_MEMBERS >= 1) &&
    R5.D_redundansset.ALLA_HOLDS === true &&
    RSETS.every(s => s.CURRENT_VALIDITY === 'HOLDS') &&
    alla.every(g => g.HALLER === false) && en.every(g => g.HALLER === true) &&
    !!treSet && treUtanTva.HALLER === true,
    RSETS.length + ' set: alla neutraliserade faller, en kvar haller, ' +
    'tremedlemsset med bara en kvar haller ' + (treUtanTva ? treUtanTva.HALLER : '-')); }

/* ── ACR-64 ─────────────────────────────────────────────────────────────── */
{ const domar = new Map([...R5REC, ...R4.F_records].map(x => [x.RELATION_ID, x.APPLICABILITY_VERDICT]));
  const badaSupp = RSETS.filter(s => s.MEMBER_RELATION_IDS
    .every(m => domar.get(m) === 'SUPPLEMENTAL_NOT_REQUIRED'));
  const nekas = RSETS.map(s => RS.farNeutraliseraSamtidigt(
    { MEMBERS: s.MEMBER_RELATION_IDS, MIN_DISTINGUISHABLE_MEMBERS: s.MIN_DISTINGUISHABLE_MEMBERS },
    Object.fromEntries(s.MEMBER_RELATION_IDS.map(m => [m, 'SUPPLEMENTAL_NOT_REQUIRED']))));
  prov('ACR-64', 'individuellt frivilliga delar far aldrig tas bort tillsammans',
    badaSupp.length > 0 && nekas.every(x => x.tillatet === false) &&
    nekas.every(x => x.grind.HALLER === false) &&
    nekas.filter(x => x.allaSupplemental).length === badaSupp.length,
    badaSupp.length + ' set dar samtliga members ar supplemental; alla ' + nekas.length +
    ' nekar samtidig neutralisering'); }

/* ── ACR-65 ─────────────────────────────────────────────────────────────── */
{ const utan = DISP.filter(d => d.SAFEGUARD_DISPOSITION === 'NO_RSET_REQUIRED');
  prov('ACR-65', 'NO_RSET_REQUIRED kraver en positiv occurrence-orsak',
    utan.length > 0 &&
    utan.every(d => /POSITIV ORSAK/.test(d.REASON) && d.REQUIRED_SYSKON.length > 0 &&
      d.OMSESIDIGT_MOTIVERADE_BARARE.length === 0) &&
    !utan.some(d => /^inget set behovs\.?$/i.test(d.REASON.trim())) &&
    R5REC.filter(x => x.SAFEGUARD_DISPOSITION === 'NO_RSET_REQUIRED')
      .every(x => x.REDUNDANCY_SET_ID === null && /POSITIV ORSAK/.test(x.SAFEGUARD_REASON)),
    utan.length + ' med NO_RSET_REQUIRED, alla med namngivet REQUIRED-syskon'); }

/* ── ACR-66 ─────────────────────────────────────────────────────────────── */
{ const e3 = DF.E_rekonciliation;
  prov('ACR-66', 'UNKNOWN och REVIEWED_UNKNOWN rekoncilierar exakt',
    e3.FORE.UNKNOWN_APPLICABILITY === 1576 && e3.EFTER.UNKNOWN_APPLICABILITY === 1526 &&
    e3.FORE.LT3_UNKNOWN === 385 && e3.EFTER.LT3_UNKNOWN === 335 &&
    e3.FORE.REVIEWED_UNKNOWN_LT3 === 62 && e3.EFTER.REVIEWED_UNKNOWN_LT3 === 12 &&
    e3.FORE.UNREVIEWED_UNKNOWN_LT3 === 323 && e3.EFTER.UNREVIEWED_UNKNOWN_LT3 === 323 &&
    e3.FORE.GE3_UNKNOWN === 1191 && e3.EFTER.GE3_UNKNOWN === 1191 &&
    e3.EFTER.KNOWN_REQUIRED_FAIL === 0 && e3.DELTA.KNOWN_REQUIRED_FAIL === 0 &&
    e3.NEW_SUPPLEMENTAL_NOT_REQUIRED === 50 &&
    e3.ANDRADE_UTANFOR_REGISTRERINGEN.length === 0 && e3.SLUTER === true &&
    e3.EFTER.LT3_UNKNOWN === e3.EFTER.REVIEWED_UNKNOWN_LT3 + e3.EFTER.UNREVIEWED_UNKNOWN_LT3,
    e3.FORE.UNKNOWN_APPLICABILITY + ' -> ' + e3.EFTER.UNKNOWN_APPLICABILITY +
    ', REVIEWED ' + e3.FORE.REVIEWED_UNKNOWN_LT3 + ' -> ' + e3.EFTER.REVIEWED_UNKNOWN_LT3 +
    ', UNREVIEWED ' + e3.EFTER.UNREVIEWED_UNKNOWN_LT3); }

/* ── ACR-67 ─────────────────────────────────────────────────────────────── */
{ const f3 = DF.F_frontier;
  const summa = Object.values(f3.DEPENDENCY_PARTITION).reduce((a,b)=>a+b,0);
  prov('ACR-67', 'frontiern ar omraknad ur aktuell population',
    f3.TOTAL_UNREVIEWED_LT3 === 323 && summa === 323 && f3.PARTITION_SUMMERAR === true &&
    f3.DIRECTLY_REVIEWABLE === f3.DEPENDENCY_PARTITION.NO_OTHER_PART +
      f3.DEPENDENCY_PARTITION.RESOLVED_PARTS_ONLY &&
    f3.BLOCKED === f3.DEPENDENCY_PARTITION.ONE_UNRESOLVED_BLOCKER +
      f3.DEPENDENCY_PARTITION.MULTIPLE_UNRESOLVED_BLOCKERS &&
    f3.DIRECTLY_REVIEWABLE + f3.BLOCKED === 323 &&
    DF.G_frontier.ANTAL === f3.DIRECTLY_REVIEWABLE &&
    DF.G_frontier.poster.length === f3.DIRECTLY_REVIEWABLE,
    f3.DIRECTLY_REVIEWABLE + ' direkt + ' + f3.BLOCKED + ' blockerade = ' +
    f3.TOTAL_UNREVIEWED_LT3); }

/* ── ACR-68 ─────────────────────────────────────────────────────────────── */
{ const f3 = DF.F_frontier, d3 = f3.DIRECT_TYPE_CENSUS, u3 = f3.UNREVIEWED_TYPE_CENSUS;
  const sum = c => c.FILL + c.BOUNDARY + c.ICON + c.THUMB + c.OTHER;
  prov('ACR-68', 'bada typcensusarna summerar exakt och den felaktiga raden ar rattad',
    sum(d3) === d3.TOTAL && d3.TOTAL === f3.DIRECTLY_REVIEWABLE && d3.UNCLASSIFIED === 0 &&
    sum(u3) === u3.TOTAL && u3.TOTAL === 323 && u3.UNCLASSIFIED === 0 &&
    f3.DIRECT_SUMMERAR === true && f3.UNREVIEWED_SUMMERAR === true &&
    typeof f3.$rattelse === 'string' &&
    !(d3.FILL === u3.FILL && d3.BOUNDARY === u3.BOUNDARY),
    'direkt ' + JSON.stringify(d3) + '; ogranskade ' + JSON.stringify(u3)); }

/* ── ACR-69 ─────────────────────────────────────────────────────────────── */
{ const k3 = DF.K_grupper;
  prov('ACR-69', 'presentationsgrupperna skapar inga domar',
    k3.GRUPPER_MED_DOM === 0 && k3.HUMAN_EQUIVALENCE_GATE === 'NOT_PASSED' &&
    k3.grupper.every(g => g.GROUP_VERDICT === null &&
      g.HUMAN_EQUIVALENCE_GATE === 'NOT_PASSED') &&
    k3.grupper.reduce((a,g) => a + g.OCCURRENCES, 0) === DF.G_frontier.ANTAL &&
    DF.G_frontier.poster.every(x => x.GROUP_ID && x.PROPOSED_VERDICT),
    k3.ANTAL + ' grupper over ' + k3.grupper.reduce((a,g)=>a+g.OCCURRENCES,0) +
    ' forekomster, ' + k3.GRUPPER_MED_DOM + ' med dom');

/* ── ACR-70 ─────────────────────────────────────────────────────────────── */
  const g3 = DF.G_frontier;
  prov('ACR-70', 'granskningen av frontiern registrerar inga slutliga domar',
    g3.REGISTRERADE_DOMAR === 0 &&
    g3.poster.every(x => x.APPLICABILITY_RECORD_WRITTEN === false &&
      x.CURRENT_APPLICABILITY === 'UNKNOWN' &&
      x.CURRENT_REVIEW_STATUS === 'UNREVIEWED_UNKNOWN' &&
      ['PROPOSED_REQUIRED','PROPOSED_SUPPLEMENTAL_NOT_REQUIRED','PROPOSED_UNKNOWN']
        .includes(x.PROPOSED_VERDICT) &&
      x.R04_CREDIT === 0) &&
    DF.J_prospektiva.SKAPADE === 0 &&
    DF.J_prospektiva.foreslagna.every(s => s.STATUS && /FORESLAGET/.test(s.STATUS)) &&
    DF.L_blockerade.ANTAL === 176 && DF.L_blockerade.BEDOMDA === 0,
    g3.ANTAL + ' granskade, ' + g3.REGISTRERADE_DOMAR + ' registrerade, ' +
    DF.J_prospektiva.foreslagna.length + ' prospektiva set foreslagna, ' +
    DF.J_prospektiva.SKAPADE + ' skapade'); }

/* ── ACR-71 ─────────────────────────────────────────────────────────────── */
{ let d = '', fel = null;
  try { d = execFileSync('git', ['status','--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  const M2 = DF.M_regression;
  prov('ACR-71', 'inga produkt-, farg- eller R-04-skrivningar och bitidentiskt baseline',
    !fel && produkt.length === 0 && M2.PRODUCT_WRITES === 0 && M2.COLOR_WRITES === 0 &&
    M2.R04_WRITES === 0 && M2.R04_CREDIT === 0 && M2.PRODUKTBASELINE_BITIDENTISK === true &&
    M2.R02_PASS === 1375 && M2.GRAPHICAL_PARTS === 1879 && M2.BOUNDARIES === 689 &&
    M2.PAINTED_CONTROL_SURFACES === 420 && M2.STANDALONE_GRAPHICS === 32 &&
    M2.R01_FINDINGS === 0 && M2.KNOWN_REQUIRED_FAIL === 0 &&
    R5.$produktfilerOrorda === true && DF.$produktfilerOrorda === true,
    (fel || produkt.length + ' andrade produktfiler') + '; ' + M2.HIT_TARGETS + ', ' +
    M2.GRAPHICAL_PARTS + ' delar, KNOWN_REQUIRED_FAIL ' + M2.KNOWN_REQUIRED_FAIL); }

/* ═══ DIRECT-147 REGISTRERAD · ACR-72 … ACR-86 ════════════════════════════
 * De forsta verkliga bristerna namnges har. Proven laser att de kommer ur
 * scenfragan och inte ur kvoten, att den strukturella klassen aldrig blir en
 * automatisk regel, och att state-deferred inte atercirkulerar. */
const R6 = JSON.parse(readFileSync(resolve('fas2/lagkontrast-register-direct147.json'), 'utf8'));
const PL = JSON.parse(readFileSync(resolve('fas2/lagkontrast-planerare-190.json'), 'utf8'));
const R6REC = R6.I_records, R6REQ = R6.A_required.records, R6SUP = R6.D_supplemental.records,
      R6DEF = R6.F_deferred.records;

prov('ACR-72', '147 = 87 REQUIRED + 58 SUPPLEMENTAL + 2 DEFERRED',
  R6REC.length === 147 && R6REQ.length === 87 && R6SUP.length === 58 && R6DEF.length === 2 &&
  new Set(R6REC.map(x => x.RELATION_ID)).size === 147 &&
  R6.G_rubrikrattelse.NORMATIV_TOTAL.SUMMA === 147 && R6.H_grindar.every(g => g.ok),
  R6REQ.length + ' + ' + R6SUP.length + ' + ' + R6DEF.length + ' = ' + R6REC.length);

prov('ACR-73', 'REQUIRED bestar av 12 ytor och 75 fyrsidiga rutor',
  R6.A_required.YTA_SOM_ENDA_SYNLIGA_GRAFIK === 12 &&
  R6.A_required.FYRSIDIG_RUTA_SOM_ENDA_SYNLIGA_GRAFIK === 75 &&
  R6REQ.filter(x => x.STRUKTURELL_KLASS === 'SOLE_FILL').length === 12 &&
  R6REQ.filter(x => x.STRUKTURELL_KLASS === 'SOLE_BOX').length === 75,
  '12 + 75 = ' + R6REQ.length);

prov('ACR-74', 'SUPPLEMENTAL bestar av 53 ytor och 5 ensidiga avskiljare',
  R6.D_supplemental.YTA_MED_KVARVARANDE_KONTROLLRUTA === 53 &&
  R6.D_supplemental.ENSIDIG_RADAVSKILJARE === 5 &&
  R6SUP.filter(x => x.STRUKTURELL_KLASS === 'FILL_WITH_VISIBLE_BOX').length === 53 &&
  R6SUP.filter(x => x.STRUKTURELL_KLASS === 'ROW_SEPARATOR').length === 5,
  '53 + 5 = ' + R6SUP.length);

prov('ACR-75', 'de tva state-fallen ar UNKNOWN och uppskjutna, inte ogranskade',
  R6DEF.every(x => x.APPLICABILITY_VERDICT === 'UNKNOWN' &&
    x.REVIEW_STATUS === AP.REVIEW_STATUS.DEFERRED_STATE_OUT_OF_SCOPE &&
    x.CURRENT_OUTCOME === 'UNKNOWN' && x.PASS_FAIL_CREDIT === 0 &&
    x.STATE_SCOPE === AP.STATE_SCOPE.INACTIVE &&
    typeof x.STATE_PROVENANS === 'string' && typeof x.$ejOgranskad === 'string') &&
  R6.F_deferred.STATE_SCOPE.length === 1 &&
  R6.F_deferred.STATE_SCOPE[0] === AP.STATE_SCOPE.INACTIVE &&
  typeof R6.F_deferred.$rattelse === 'string',
  'bada ar ' + R6.F_deferred.STATE_SCOPE.join(',') + ' — ingen ar ett nedtryckt lage');

prov('ACR-76', 'kvoten skapar aldrig requiredness',
  R6REQ.every(x => x.REQUIREDNESS_PROVENANCE.startsWith('COUNTERFACTUAL_ACTUAL_SCENE_REVIEW') &&
    /FORST efter domen/.test(x.RATIO_ROLE)) &&
  R6.B_provenians.RATIO_SKAPAR_ALDRIG_REQUIRED === true &&
  R6.B_provenians.SVAR_FOR_DE_87 === 'NO' &&
  kastar(() => AP.forslag({ COUNTERFACTUAL_KORD: true, MEASURED_RATIO: 1.41 })) &&
  R6SUP.some(x => x.CURRENT_RATIO < 3),
  'alla 87 har scen-proveniens; supplemental finns ocksa under 3.0');

prov('ACR-77', 'den strukturella klassen ar aldrig en automatisk verdict-regel',
  R6.C_strukturellKlass.AR_INTE_VERDICT_REGEL === true &&
  R6.C_strukturellKlass.FORBJUDNA_REGLER.includes('FOUR_SIDED_BOUNDARY => REQUIRED') &&
  R6.C_strukturellKlass.FORBJUDNA_REGLER.includes('ONE_SIDED_DIVIDER => SUPPLEMENTAL') &&
  R6REC.every(x => x.DOES_NOT_IMPLY.includes('STRUCTURAL_CLASS_RULE') &&
    typeof x.STRUKTURELL_KLASS_AR_INTE_REGEL === 'string'),
  'alla ' + R6REC.length + ' record avvisar klassregeln');

prov('ACR-78', 'REQUIRED under kravet ger exakt 87 REQUIRED_FAIL',
  R6.A_required.REQUIRED_FAIL === 87 && R6.A_required.REQUIRED_PASS === 0 &&
  R6REQ.every(x => x.CURRENT_RATIO < 3 && x.CURRENT_OUTCOME === 'REQUIRED_FAIL') &&
  R6.A_required.KNOWN_REQUIRED_FAIL_FORE === 0 &&
  R6.A_required.KNOWN_REQUIRED_FAIL_EFTER === 87 &&
  PL.H_rekonciliation.EFTER.KNOWN_REQUIRED_FAIL === 87,
  '87 REQUIRED_FAIL, hogsta kvot ' + Math.max(...R6REQ.map(x => x.CURRENT_RATIO)));

prov('ACR-79', 'en supplemental-dom skapar ingen requiredness pa ett syskon',
  R6SUP.every(x => x.DOES_NOT_IMPLY.includes('SIBLING_REQUIRED') &&
    x.DOES_NOT_IMPLY.includes('CONTROL_CONFORMING') &&
    x.OTHER_CARRIERS_UNCHANGED.every(c => !c.CHANGED_BY_THIS_RECORD &&
      c.APPLICABILITY_BEFORE === c.APPLICABILITY_AFTER)) &&
  typeof R6.D_supplemental.$ejFranSyskon === 'string' &&
  AP.harleddDom('SIBLING_REQUIRED','TARGET_SUPPLEMENTAL').tillatet === false,
  'alla ' + R6SUP.length + ' lamnar syskonen oforandrade');

prov('ACR-80', 'inga nya redundansset behovdes och alla 44 haller',
  R6.E_redundansset.NEW_REDUNDANCY_SETS === 0 &&
  R6.E_redundansset.NYA_BEROENDEN_UPPTACKTA === 0 &&
  R6.E_redundansset.AKTIVA === 44 && R6.E_redundansset.ALLA_HOLLER === true &&
  R6.E_redundansset.set.every(s => s.CURRENT_VALIDITY === 'HOLDS' &&
    s.JOINTLY_REMOVABLE === false),
  R6.E_redundansset.AKTIVA + ' aktiva set, alla HOLDS, ' +
  R6.E_redundansset.NEW_REDUNDANCY_SETS + ' nya');

prov('ACR-81', 'UNKNOWN rekoncilierar exakt och kon delas i tre spar',
  PL.H_rekonciliation.FORE.UNKNOWN_APPLICABILITY === 1526 &&
  PL.H_rekonciliation.EFTER.UNKNOWN_APPLICABILITY === 1381 &&
  PL.H_rekonciliation.FORE.LT3_UNKNOWN === 335 &&
  PL.H_rekonciliation.EFTER.LT3_UNKNOWN === 190 &&
  PL.H_rekonciliation.EFTER.GE3_UNKNOWN === 1191 &&
  PL.H_rekonciliation.EFTER.REVIEWED_UNKNOWN === 12 &&
  PL.H_rekonciliation.EFTER.DEFERRED_STATE_OUT_OF_SCOPE === 2 &&
  PL.H_rekonciliation.EFTER.UNREVIEWED === 176 &&
  PL.H_rekonciliation.ANDRADE_UTANFOR.length === 0 &&
  PL.H_rekonciliation.SLUTER === true,
  '1526 -> 1381, LT3 335 -> 190 = 12 + 2 + 176');

prov('ACR-82', 'kon ar omraknad och state-deferred halls utanfor',
  PL.L_planner.LT3_UNKNOWN === 190 && PL.L_planner.SPAR_SUMMERAR === true &&
  PL.L_planner.SPAR.DEFERRED_STATE_OUT_OF_SCOPE === 2 &&
  PL.L_planner.STATISKA_I_KON === 188 &&
  PL.L_planner.PARTITION_SUMMERAR === true &&
  PL.L_planner.rader.filter(x => x.SPAR === 'DEFERRED_STATE_OUT_OF_SCOPE')
    .every(x => !PL.M_frontier.poster.some(f => f.BLOCKERAR.includes(x.TARGET_RELATION_ID))) &&
  AP.farIngaIStatiskKo({ APPLICABILITY_VERDICT: 'UNKNOWN',
    REVIEW_STATUS: AP.REVIEW_STATUS.DEFERRED_STATE_OUT_OF_SCOPE }) === false &&
  AP.STATE_ATEROPPNINGSSKAL.length === 2,
  PL.L_planner.STATISKA_I_KON + ' statiska av ' + PL.L_planner.LT3_UNKNOWN);

prov('ACR-83', 'blocker-frontiern ar harledd pa nytt utan extrapolering',
  PL.M_frontier.UNIQUE_BLOCKERS > 0 &&
  PL.M_frontier.LT3_BLOCKERS + PL.M_frontier.GE3_BLOCKERS === PL.M_frontier.UNIQUE_BLOCKERS &&
  PL.M_frontier.NEW_BLOCKERS + PL.M_frontier.ATERKOMMANDE_FRAN_DE_66 === PL.M_frontier.UNIQUE_BLOCKERS &&
  PL.M_frontier.poster.every(f => f.UNLOCK_COUNT === f.BLOCKERAR.length &&
    f.APPLICABILITY === 'UNKNOWN') &&
  typeof PL.M_frontier.$ingenDom === 'string',
  PL.M_frontier.UNIQUE_BLOCKERS + ' unika, ' + PL.M_frontier.LT3_BLOCKERS + ' LT3 / ' +
  PL.M_frontier.GE3_BLOCKERS + ' GE3');

prov('ACR-84', 'nasta batch ar presentation utan domar',
  PL.N_nastaBatch.GROUP_VERDICT === 0 && PL.N_nastaBatch.AUTOMATIC_EQUIVALENCE === 0 &&
  PL.N_nastaBatch.VERDICT_PROPAGATION === 0 &&
  PL.N_nastaBatch.ROLL === 'PRESENTATION_OCH_REVIEW' &&
  PL.N_nastaBatch.poster.every(x => x.APPLICABILITY === 'UNKNOWN') &&
  typeof PL.N_nastaBatch.$gemensamma === 'string' &&
  PL.N_nastaBatch.MULTIPLE_BLOCKER_TARGETS >= PL.N_nastaBatch.MULTIPLE_BLOCKER_TARGETS_HELT_I_BATCHEN,
  PL.N_nastaBatch.BATCH_STORLEK + ' blockerare tacker ' + PL.N_nastaBatch.TACKTA_TARGETS +
  ' targets');

prov('ACR-85', 'censusen for de 87 ar read-only utan remedieringsidentitet',
  PL.O_census.ANTAL === 87 && PL.O_census.TYP === 'READ_ONLY_CENSUS' &&
  PL.O_census.INGA_REMEDIATION_DECISION_UNITS === true &&
  PL.O_census.INGA_FARGFORSLAG === true && PL.O_census.INGA_PREVIEWS === true &&
  PL.O_census.INGA_PRODUKTWRITES === true &&
  typeof PL.O_census.$regel === 'string' &&
  PL.O_census.poster.length === 87 &&
  PL.O_census.poster.every(x => x.RAW_PAINT && x.ADJACENT_SURFACE && x.SOURCE_ANCHOR) &&
  PL.K_ingenRemediering.STOPPAD === true &&
  PL.K_ingenRemediering.DE_87_AR.includes('LAST FAILURE INVENTORY'),
  PL.O_census.ANTAL + ' poster, ' + PL.O_census.DELADE_KALLDEKLARATIONER +
  ' delade kalldeklarationer');

{ let d = '', fel = null;
  try { d = execFileSync('git', ['status','--porcelain'], { cwd: resolve('.'), encoding: 'utf8' }); }
  catch (e) { fel = e.message; }
  const produkt = d.split('\n').map(x => x.slice(3).replace(/^"|"$/g,''))
    .filter(f => f.endsWith('.dc.html'));
  const J2 = PL.J_regression;
  prov('ACR-86', 'produkten ar bitidentisk och inga skrivningar har skett',
    !fel && produkt.length === 0 && J2.PRODUCT_WRITES === 0 && J2.COLOR_WRITES === 0 &&
    J2.R04_WRITES === 0 && J2.R04_CREDIT === 0 && J2.PRODUKTBASELINE_BITIDENTISK === true &&
    J2.R02_PASS === 1375 && J2.GRAPHICAL_PARTS === 1879 && J2.BOUNDARIES === 689 &&
    J2.PAINTED_CONTROL_SURFACES === 420 && J2.STANDALONE_GRAPHICS === 32 &&
    J2.R01_FINDINGS === 0 && J2.KNOWN_REQUIRED_FAIL === 87 &&
    J2.CURRENT_NON_TEXT_CONTRAST === 'OPEN · KNOWN FAILURES PRESENT' &&
    R6.$produktfilerOrorda === true && PL.$produktfilerOrorda === true,
    (fel || produkt.length + ' andrade produktfiler') + '; ' + J2.HIT_TARGETS +
    ', KNOWN_REQUIRED_FAIL ' + J2.KNOWN_REQUIRED_FAIL); }

const ANTAL = 86;
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
