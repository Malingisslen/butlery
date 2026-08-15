#!/usr/bin/env node
// F2 · BESTANDIGA PROV FOR ADJUDIKERINGSMETODEN.
//
// Kör: node tools/adjudication-pilot-fixtures.mjs --out=<katalog utanfor repot>
//
// FELKLASSEN DESSA PROV FINNS FOR
// Nar kandidater granskas familjevis uppstar frestelsen att lata familjen
// svara at forekomsterna. Da blir klustringen en osynlig klassificerare: ett
// verdikt fran en comparator eller fran majoriteten sprider sig till hundra
// objekt utan att nagon evidens om DEM lagts fram. Proven laser att
// granskningsgruppen ORGANISERAR utredningen men aldrig BEVISAR svaret.
//
//   ADJ-01  samma granskningspartition innebar inte samma verdikt
//   ADJ-02  comparatorroll ensam kan inte avgora ett verdikt
//   ADJ-03  majoritetsverdikt kan inte avgora en olost forekomst
//   ADJ-04  en delad utsaga far tillampas bara dar dess scope bevisligen tacker
//   ADJ-05  motevidens bedoms per forekomst
//   ADJ-06  UNKNOWN overlever nar forekomstspecifik evidens inte racker
//   ADJ-07  blandade verdikt skriver inte om strukturklustrets identitet
//   ADJ-08  en partition kan flaggas heterogen utan att medlemskap andras
//   ADJ-09  ett avgjort verdikt tar inte bort kandidaten ur den ra upptackten
//   ADJ-10  prospektiv konformitet paverkar inte det semantiska verdiktet
//   ADJ-11  upprepning eller identiska syskon far aldrig ensamt ge DECORATIVE
//   ADJ-12  textbakgrundsagarskap ensamt kan inte etablera grafiskt krav
//   ADJ-13  andrad barntext andrar inte forald erns carrier-krav

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { bortfallsprov, carrierstabilitet, grundarKrav, DELKLASS, EVIDENSGRUND,
  ICKE_GRUNDANDE_ENSAMT } from './graphic-part-requirement.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });
const rot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const A = JSON.parse(readFileSync(join(rot, 'fas2', 'adjudikeringspilot.json'), 'utf8'));
const KLU = JSON.parse(readFileSync(join(rot, 'fas2', 'kandidatklustring.json'), 'utf8'));
const F = A.E_F_G_perForekomst;

/* ── ADJ-01 ─────────────────────────────────────────────────────────*/
{ const klasser = [...new Set(F.map(x => x.verdikt))];
  prov('ADJ-01', 'samma granskningspartition innebar inte samma verdikt',
    klasser.length > 1 && A.H_utfallsklass.klass.startsWith('MIXED'),
    'en och samma partition gav ' + klasser.length + ' olika verdikt: ' + klasser.join(', ')); }

/* ── ADJ-02 ─────────────────────────────────────────────────────────*/
{ // Comparatorprofilen var button. Om rollen hade avgjort skulle alla 143 blivit
  // kontroller. De blev 5.
  const kontroller = F.filter(x => x.verdikt === 'INTERACTIVE_CONTROL').length;
  const roll = A.D_comparatorprofil.roller.join(',');
  prov('ADJ-02', 'comparatorroll ensam kan inte avgora ett verdikt',
    roll === 'button' && kontroller < F.length && kontroller === 5 &&
    /aldrig att dessa 143 ar knappar|aldrig "dessa 143 ar knappar"|aldrig/.test(
      A.C_deladEvidens.motevidens),
    'comparatorrollen var ' + roll + ' for hela partitionen; ' + kontroller + ' av ' +
      F.length + ' blev kontroller'); }

/* ── ADJ-03 ─────────────────────────────────────────────────────────*/
{ // Majoriteten var NON_INTERACTIVE_STATE_GRAPHIC. Om majoriteten hade avgjort
  // skulle inga UNKNOWN och inga kontroller finnas kvar.
  const per = {};
  for (const x of F) per[x.verdikt] = (per[x.verdikt] || 0) + 1;
  const majoritet = Object.entries(per).sort((a, b) => b[1] - a[1])[0];
  prov('ADJ-03', 'majoritetsverdikt kan inte avgora en olost forekomst',
    per.UNKNOWN > 0 && per.INTERACTIVE_CONTROL > 0 && majoritet[1] < F.length,
    'majoriteten var ' + majoritet[0] + ' med ' + majoritet[1] + ' av ' + F.length +
      '; anda star ' + per.UNKNOWN + ' som UNKNOWN och ' + per.INTERACTIVE_CONTROL +
      ' som kontroll'); }

/* ── ADJ-04 ─────────────────────────────────────────────────────────*/
{ // Varje familj med ett verdikt maste ange sitt scope, och forekomsterna maste
  // ligga inom det. Provet kontrollerar att varje avgjord forekomst har minst
  // en positiv evidenspunkt OCH en redovisad scopekontroll mot sin egen skarm.
  const avgjorda = F.filter(x => x.verdikt !== 'UNKNOWN');
  const allaHarScope = avgjorda.every(x => x.positivEvidens.length > 0 &&
    x.scopekontroll && x.scopekontroll.skarm);
  const scopeNamns = avgjorda.some(x => x.positivEvidens.some(e => /SCOPE/.test(e)));
  prov('ADJ-04', 'en delad utsaga far tillampas bara dar dess scope bevisligen tacker',
    allaHarScope && scopeNamns,
    avgjorda.length + ' avgjorda forekomster, alla med positiv evidens och egen ' +
      'scopekontroll mot sin skarm'); }

/* ── ADJ-05 ─────────────────────────────────────────────────────────*/
{ const avgjorda = F.filter(x => x.verdikt !== 'UNKNOWN');
  const allaHarMot = avgjorda.every(x => Array.isArray(x.motevidens) && x.motevidens.length > 0);
  prov('ADJ-05', 'motevidens bedoms och redovisas per forekomst',
    allaHarMot,
    'samtliga ' + avgjorda.length + ' avgjorda forekomster bar redovisad motevidens'); }

/* ── ADJ-06 ─────────────────────────────────────────────────────────*/
{ const okanda = F.filter(x => x.verdikt === 'UNKNOWN');
  const allaHarFraga = okanda.every(x => typeof x.olostFraga === 'string' &&
    x.olostFraga.length > 40 && !/otydlig|oklart/i.test(x.olostFraga));
  prov('ADJ-06', 'UNKNOWN overlever nar forekomstspecifik evidens inte racker',
    okanda.length > 0 && allaHarFraga,
    okanda.length + ' forekomster star kvar som UNKNOWN, alla med en konkret olost fraga'); }

/* ── ADJ-07 ─────────────────────────────────────────────────────────*/
{ prov('ADJ-07', 'blandade verdikt skriver inte om strukturklustrets identitet',
    A.B_medlemskap.signaturhash === KLU.W_klusterkvalitet
      .find(k => k.id === A.A_urval.vald).signaturhash &&
    KLU.C_niva1.antal === 416 && KLU.D_partitioner.antal === 559,
    'signaturhashen oforandrad; 416 strukturkluster och 559 partitioner star kvar'); }

/* ── ADJ-08 ─────────────────────────────────────────────────────────*/
{ const s = A.I_foreslagenSplit;
  prov('ADJ-08', 'en partition kan flaggas heterogen utan att medlemskap andras',
    A.H_utfallsklass.klass.startsWith('MIXED') &&
    A.B_medlemskap.antal === 143 &&
    // Den foreslagna egenskapen maste vara MATT FORE adjudikeringen och far
    // inte vara ett verdikt, en roll eller ett namn.
    /fore all adjudikering|pre-verdict/i.test(s.varforPreVerdict) &&
    /Ingen av dem ar ett verdikt/.test(s.varforPreVerdict) &&
    /andras INTE retroaktivt/.test(s.$forbud),
    'utfallet ar ' + A.H_utfallsklass.klass + ' och medlemskapet star kvar pa ' +
      A.B_medlemskap.antal); }

/* ── ADJ-09 ─────────────────────────────────────────────────────────*/
{ const k = A.K_avstamning;
  prov('ADJ-09', 'ett avgjort verdikt tar inte bort kandidaten ur den ra upptackten',
    k.rawOforandrad === 2700 && k.unresolvedFore - k.lostaHar === k.unresolvedEfter &&
    /lamnar den ra upptackten/.test(k.$regel),
    'ra population ' + k.rawOforandrad + ' oforandrad; unresolved ' + k.unresolvedFore +
      ' − ' + k.lostaHar + ' = ' + k.unresolvedEfter); }

/* ── ADJ-10 ─────────────────────────────────────────────────────────*/
{ const nya = A.N_prospektivt;
  const alla = nya.every(x => x.prospektivR02 === 'UNKNOWN' &&
    x.raknasIDeklarerade1351 === false && /KONFORMITETSFEL att rapportera/.test(x.r02Skal));
  prov('ADJ-10', 'prospektiv konformitet paverkar inte det semantiska verdiktet',
    nya.length > 0 && alla && A.O_frysta.deklarerade === 1351,
    nya.length + ' nya kontroller: prospektiv R-02 UNKNOWN, 30x30 skulle ge ett R-02-fel, ' +
      'och verdiktet star anda'); }

/* ── ADJ-11 · repetition ar inte dekorationsbevis ───────────────────
 *
 * FELET DETTA PROV FINNS FOR
 * Piloten forklarade fjorton listmarkorer DECORATIVE med skalet att markoren
 * ar identisk fore varje rad. Det ar STRUKTURELL UPPREPNINGSEVIDENS: den
 * bevisar bara att markoren inte kodar ett VARIERANDE attribut. En identisk
 * aterkommande markor kan fortfarande bara liststruktur, listmedlemskap eller
 * gruppering. SEMANTISK DEKORATIONSEVIDENS kraver dessutom att objektet inte
 * behovs for att forsta innehall, struktur eller tillstand — och den lades
 * aldrig fram. De fjorton ar ateroppnade som UNKNOWN.
 */
{ const V = JSON.parse(readFileSync(join(rot, 'fas2', 'klustring-v2.json'), 'utf8'));
  const k = V.B_korrigeradPilot;
  const STRUCTURAL_REPETITION_EVIDENCE =
    'identisk markor fore varje rad utan variation — bevisar att objektet inte kodar ett ' +
    'varierande attribut';
  const SEMANTIC_DECORATIVE_EVIDENCE =
    'objektet behovs inte for att forsta innehall, struktur eller tillstand — kraver egen ' +
    'positiv evidens';
  const skiljerBegreppen = k.ateroppnade.every(x =>
    /bevisar bara att den inte kodar ett VARIERANDE attribut|VARIERANDE/.test(x.skal) &&
    /kraver separat positiv evidens/.test(x.skal));
  prov('ADJ-11', 'upprepning eller identiska syskon far aldrig ensamt etablera DECORATIVE',
    k.totalerEfter.DECORATIVE_GRAPHIC === 0 && k.ateroppnade.length === 14 &&
    k.ateroppnade.every(x => x.nyttVerdikt === 'UNKNOWN' && x.olostFraga.length > 40) &&
    skiljerBegreppen &&
    STRUCTURAL_REPETITION_EVIDENCE !== SEMANTIC_DECORATIVE_EVIDENCE,
    k.ateroppnade.length + ' ateroppnade som UNKNOWN; ' +
      k.totalerEfter.DECORATIVE_GRAPHIC + ' dekorativa kvar; skalet skiljer uttryckligen ' +
      'strukturell upprepningsevidens fran semantisk dekorationsevidens'); }

/* ── ADJ-12 · textagarskap ar ingen grafisk carrier-evidens ─────────
 *
 * FELET DETTA PROV FINNS FOR
 * Batch 2 forklarade 31 skarmhuvuden INFORMATION_BEARING. Tre av fyra
 * evidenspunkter var utsagor om TEXT: raden ager titeln, raden ager
 * sekundarvardet, sekundarvardet varierar. Att en malad yta ar den narmaste
 * malade agaren till ett barns text gor den till textens MATBAKGRUND. Det ar
 * en matningsrelation i textsparet och sager ingenting om huruvida ytans egen
 * malning bar information eller struktur.
 *
 * SCENARIOT SOM PROVAS
 * En foralder malar en bakgrund. Ett barn bar sjalvstandig text. Foraldern ar
 * textens background owner. Ingen separat strukturell eller informationsbarande
 * funktion hos foralderns egen malning ar bevisad.
 *   FORVANTAT: textagarskapet far finnas — men graphical carrier requiredness
 *   far inte uppsta automatiskt. Faller stangt till UNKNOWN.
 */
{ const ENDAST_TEXT = [EVIDENSGRUND.TEXT_BACKGROUND_OWNER,
    EVIDENSGRUND.OWNS_VISIBLE_TEXT, EVIDENSGRUND.CHILD_TEXT_VARIES];
  const utanGrafisk = bortfallsprov({ id: 'foralderns_fyllning' }, false,
    'barnets text vore olasbar utan fyllningen', ENDAST_TEXT);
  /* Positiv kontroll: laggs EN utsaga om malningen sjalv till, far kravet uppsta. */
  const medGrafisk = bortfallsprov({ id: 'foralderns_fyllning' }, false,
    'fyllningen ar den enda avgransningen mot omgivningen',
    [...ENDAST_TEXT, EVIDENSGRUND.GRAPHICAL_DELIMITATION]);
  const g = grundarKrav(ENDAST_TEXT);

  const C = JSON.parse(readFileSync(join(rot, 'fas2', 'carrier-adjudikering-a2.json'), 'utf8'));
  const textgrunder = ICKE_GRUNDANDE_ENSAMT;
  const ingenBarareViladPaText = C.E_perForekomst.every(x =>
    Object.values(x.barare).every(bar => bar.klass !== DELKLASS.REQUIRED_FOR_UNDERSTANDING ||
      (bar.grunder || []).some(gr => !textgrunder.includes(gr))));
  const textrelationenKvarITextsparet = C.E_perForekomst.every(x =>
    /TEXTSPARET/.test(x.textrelation.$regel));
  const batch2Aterkallat = C.G_aterkalladeVerdikt.efter.UNKNOWN === 31 &&
    /utsagor om text/i.test(C.G_aterkalladeVerdikt.$skal);

  prov('ADJ-12', 'TEXT_BACKGROUND_OWNER ensamt kan inte etablera INFORMATION_BEARING eller ' +
    'REQUIRED_GRAPHICAL_CARRIER',
    utanGrafisk.klass === DELKLASS.UNKNOWN && utanGrafisk.krav === null &&
    medGrafisk.klass === DELKLASS.REQUIRED_FOR_UNDERSTANDING &&
    g.grundar === false && g.ickeGrundande.length === 3 &&
    ingenBarareViladPaText && textrelationenKvarITextsparet && batch2Aterkallat,
    'enbart textgrunder ger ' + utanGrafisk.klass + '; med en grafisk grund ger samma ' +
      'scenario ' + medGrafisk.klass + '; i korpusen vilar ingen kravd barare pa textgrunder ' +
      'och de 31 objektverdikten ar aterkallade'); }

/* ── ADJ-13 · barntexten far inte vagga fram ett carrier-krav ───────
 *
 * FELET DETTA PROV FINNS FOR
 * Om textagarskapet forst rakas in som carrier-evidens blir foljden att man
 * kan andra en grafisk barares status genom att skriva om, flytta eller byta
 * agare pa barnets text — utan att en enda pixel av malningen andrats. Sa
 * lange den grafiska och strukturella evidensen ar oforandrad ska
 * carrier-verdiktet vara oforandrat.
 */
{ const GRAFISK = [EVIDENSGRUND.GRAPHICAL_DELIMITATION];
  const fore = { grunder: [...GRAFISK, EVIDENSGRUND.OWNS_VISIBLE_TEXT,
      EVIDENSGRUND.TEXT_BACKGROUND_OWNER], begripligUtan: false };
  const efter = { grunder: [...GRAFISK], begripligUtan: false };   // texten borttagen
  const s1 = carrierstabilitet(fore, efter);

  const foreT = { grunder: [EVIDENSGRUND.TEXT_BACKGROUND_OWNER], begripligUtan: false };
  const efterT = { grunder: [EVIDENSGRUND.OWNS_VISIBLE_TEXT, EVIDENSGRUND.CHILD_TEXT_VARIES],
    begripligUtan: false };
  const s2 = carrierstabilitet(foreT, efterT);   // bara textgrunder — bada UNKNOWN

  /* Kontroll at andra hallet: andras den GRAFISKA evidensen far verdiktet skilja sig. */
  const s3 = carrierstabilitet({ grunder: GRAFISK, begripligUtan: false },
    { grunder: [], begripligUtan: false });

  prov('ADJ-13', 'andrad barntext eller andrat textagarskap andrar inte foralderns ' +
    'carrier-krav nar den grafiska evidensen ar oforandrad',
    s1.grafiskEvidensLika && s1.stabil && s1.fore === s1.efter &&
    s1.fore === DELKLASS.REQUIRED_FOR_UNDERSTANDING &&
    s2.grafiskEvidensLika && s2.stabil && s2.fore === DELKLASS.UNKNOWN &&
    s3.grafiskEvidensLika === false,
    'med grafisk grund: ' + s1.fore + ' → ' + s1.efter + ' (stabil); utan grafisk grund: ' +
      s2.fore + ' → ' + s2.efter + ' (stabil); nar den grafiska grunden faller bort ' +
      'redovisas evidensen som olik och verdiktet far skilja sig'); }

for (const x of resultat)
  console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('ADJUDIKERINGSPROV status=' + (ok === resultat.length ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + resultat.length);
writeFileSync(join(outAbs, 'adjprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === resultat.length ? 0 : 1);
