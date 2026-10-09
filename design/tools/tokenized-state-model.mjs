#!/usr/bin/env node
// Block 286 — searchbox tokenized state review.
//
// Byggaren avgor ingenting. Den laser den kanoniska analysallan, validerar
// fail-closed och aggregerar. Varje bedomning bor i JSON:en, aldrig har.
//
// Kor: node tools/tokenized-state-model.mjs [--root=.] [--detalj=alternativ]

import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const ROOT = resolve(arg('root') || '.');
const KALLA = arg('kalla') || join(ROOT, 'fas2/tokenized-state-model.json');

const h = x => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 16);
const fail = m => { throw new Error('FAIL CLOSED: ' + m); };

const K = JSON.parse(readFileSync(KALLA, 'utf8'));

/* ── 0 · read-only-grind mot Block 282-285 ────────────────────────────────
   Fyra stangda block. Byggaren kor deras egna committade verktyg, jamfor mot
   de frysta avtrycken och mot filernas faktiska innehall. */

const kor = rel => JSON.parse(execFileSync(process.execPath, [join(ROOT, rel), '--root=' + ROOT],
  { encoding: 'utf8', maxBuffer: 1 << 26 }));
const B282 = kor('tools/stateflow-population.mjs');
const B283 = kor('tools/stateflow-applicability.mjs');
const B284 = kor('tools/role-vocabulary-reconciliation.mjs');
const B285 = kor('tools/role-state-applicability.mjs');

const FRYST = K.fryst_baslinje;
const grind = {
  '282_POPULATION': B282.POPULATION_FINGERPRINT,
  '282_IDENTITY': B282.IDENTITY_FINGERPRINT,
  '282_MAPPING': B284.BLOCK_282_283_READONLY['282_MAPPING'],
  '283_IDENTITY': B283.IDENTITY_FINGERPRINT,
  '283_STATUS': B283.STATUS_FINGERPRINT,
  '284_OCCURRENCE_IDENTITY': B284.OCCURRENCE_IDENTITY_FINGERPRINT,
  '284_OCCURRENCE_STATUS': B284.OCCURRENCE_STATUS_FINGERPRINT,
  '285_IDENTITY': B285.IDENTITY_FINGERPRINT,
  '285_STATUS': B285.STATUS_FINGERPRINT
};
for (const [k, v] of Object.entries(grind))
  if (FRYST[k] !== v) fail('baslinjen har andrats: ' + k + ' ar ' + v + ', fryst ' + FRYST[k]);

const filhash = f => createHash('sha256').update(readFileSync(join(ROOT, f))).digest('hex').slice(0, 16);
for (const [f, vantat] of Object.entries(K.upstream_filhashar || {})) {
  const har = filhash(f);
  if (har !== vantat) fail('uppstromsfilen ' + f + ' har andrats: ' + har + ' != ' + vantat);
}
if (Object.keys(K.upstream_filhashar || {}).length < 4)
  fail('kallan deklarerar for fa uppstromshashar');

// Block 285 ska fortfarande bara gapet OPPET under hela analysen.
const G = readFileSync(join(ROOT, 'fas2/role-state-applicability.json'), 'utf8');
if (!/"SEARCHBOX_TOKENIZED_STATE_MODEL_GAP": "YES"/.test(G))
  fail('Block 285 bar inte langre gapet som oppet — det far inte andras i detta block');
if (B285.ROLE_STATE_ROWS !== 24) fail('Block 285:s population har andrats');
if (B283.CONTROL_STATE.ROWS !== 70) fail('Block 283:s population har andrats');
grind.grind = 'GRON';

/* ── 1 · identitet ────────────────────────────────────────────────────────
   Identiteten ar komponenten och det kallnamngivna laget. Aldrig utfallet. */

const F = K.modellfraga;
const vantatId = 'STATE_MODEL_GAP::' + F.KOMPONENT + '::' + F.LAGE_SLUG;
if (F.GAP_ID !== vantatId)
  fail('identiteten stammer inte med komponent och lage: ' + F.GAP_ID + ' != ' + vantatId);
for (const forbjudet of ['NEW_PERSISTENT_STATE', 'COMPOSITE', 'VARIANT', 'UNRESOLVED',
  'REQUIRED', 'SUPPORTED', 'FARG', 'INDEX'])
  if (F.GAP_ID.includes(forbjudet)) fail('identiteten bar ett utfall: ' + F.GAP_ID);
if (!F.KALLANKNYTNING || !F.KALLANKNYTNING.fil || !F.KALLANKNYTNING.rader)
  fail('identiteten saknar sin kallankytning — den maste harledas ur en source-authored plats');

// Identiteten bygger pa den SEMANTISKA anknytningen, inte pa den visuella
// etiketten. Doper komponentarket om "Tokeniserad" till nagot annat utan att
// andra vad laget ar, ska identiteten sta stilla (TKN286-03).
if (!F.LAGE_SLUG) fail('modellfragan saknar semantisk slug');
const IDENTITY_FINGERPRINT = h([F.GAP_ID, F.KOMPONENT, F.LAGE_SLUG, F.KALLANKNYTNING.fil]);

/* ── 2 · de fyra alternativen ─────────────────────────────────────────────
   Alla fyra ska provas uttryckligen. Ett alternativ utan bedomning ar en
   utebliven analys, inte ett tyst nej. */

const ALTERNATIV = ['NEW_PERSISTENT_STATE', 'COMPOSITE_VISUAL_MODE',
  'VARIANT_OR_CONTENT_MODE', 'UNRESOLVED'];
const BEDOMNINGAR = ['SUPPORTED', 'NOT_SUPPORTED', 'PARTIAL', 'UNRESOLVED'];
const kallnycklar = new Set(Object.keys(K.kallregister));

const A = K.alternativ;
for (const namn of ALTERNATIV) {
  const a = A[namn];
  if (!a) fail('alternativet ' + namn + ' ar inte provat');
  if (!BEDOMNINGAR.includes(a.BEDOMNING))
    fail(namn + ' har bedomningen ' + a.BEDOMNING + ' som inte ar tillaten');
  if (!a.GRUND || a.GRUND === '—') fail(namn + ' saknar motivering');
  for (const s of (a.SOURCE || []))
    if (!kallnycklar.has(s)) fail(namn + ' aberopar kallan ' + s + ' som inte star i kallregistret');
  if (a.BEDOMNING === 'SUPPORTED' && !(a.SOURCE || []).length)
    fail(namn + ' pastas ha stod men aberopar ingen kalla');
}
for (const namn of Object.keys(A))
  if (!ALTERNATIV.includes(namn)) fail('okant alternativ i kallan: ' + namn);

// Ett sammansatt lage forutsatter att delarna faktiskt finns ritade. Tas
// chippet bort ur exemplet ska analysen reagera pa RATT modellkomponent
// i stallet for att sta kvar och pasta att delarna beskriver laget (TKN286-04).
const KO = K.korpus || {};
for (const f of ['ritade_chip_i_sokfalt', 'chip_i_sokfalt_i_korpus',
  'sokfalt_i_korpus', 'sokfalt_med_maskinlasbart_state'])
  if (typeof KO[f] !== 'number') fail('korpusmatningen saknar talet ' + f);
if (A.COMPOSITE_VISUAL_MODE.BEDOMNING === 'SUPPORTED' && KO.ritade_chip_i_sokfalt < 1)
  fail('COMPOSITE_VISUAL_MODE pastas ha stod men inget chip ar ritat i sokfaltet — ' +
    'da finns ingen delkomponent som kan bara laget');

/* ── 2c · registrerade modellbeslut ──────────────────────────────────────
   Flaggorna ar en del av domen och provas darfor har, inte i prosan. */

const MB = K.modellbeslut || {};
const kravFlagga = (namn, vantat) => {
  if (MB[namn] !== vantat)
    fail('flaggan ' + namn + ' ar ' + JSON.stringify(MB[namn]) + ', vantade ' + JSON.stringify(vantat));
};
if (Object.keys(MB).length) {
  kravFlagga('TOKENIZED_MODEL_OUTCOME', 'COMPOSITE_VISUAL_MODE');
  kravFlagga('SEARCHBOX_TOKENIZED_IS_PERSISTENT_STATE', 'NO');
  kravFlagga('SEARCHBOX_TOKENIZED_STATE_ROW_CREATED', 'NO');
  kravFlagga('TOKENIZED_STATE_MODEL_GAP_RESOLVED', 'YES');
  kravFlagga('TOKENIZED_STATE_MODEL_GAP_RESOLUTION', 'COMPOSITE_VISUAL_MODE');
  kravFlagga('SEARCH_TOKEN_DOES_NOT_INHERIT_FILTER_CHIP_SEMANTICS', 'YES');
  kravFlagga('SEARCH_TOKEN_MODEL', 'CHILD_SEMANTICS');
  kravFlagga('REMOVABLE_SEARCH_TOKEN_ACTION_ROLE', 'button');
  kravFlagga('REMOVABLE_SEARCH_TOKEN_NEEDS_ACCESSIBLE_NAME', 'YES');
  kravFlagga('INGREDIENT_SELECTOR_AND_SEARCHBOX_SHARE_INTERACTION_PATTERN', 'NO');
  kravFlagga('INGREDIENT_SELECTOR_AND_SEARCHBOX_SHARE_PRIMARY_ACCESSIBILITY_ROLE', 'NO');
  kravFlagga('TOKEN_MULTISELECT_IS_ACCESSIBILITY_ROLE', 'NO');
  kravFlagga('INGREDIENT_SELECTOR_INTERACTION_PATTERN', 'TOKEN_MULTISELECT');
  kravFlagga('INGREDIENT_SELECTOR_PRIMARY_ACCESSIBILITY_ROLE', 'UNSPECIFIED');
  kravFlagga('SEARCH_PANEL_PRIMARY_ACCESSIBILITY_ROLE', 'searchbox');
  if ('INGREDIENT_SELECTOR_AND_SEARCHBOX_SHARE_PRIMARY_ROLE' in MB)
    fail('den tvetydiga flaggan INGREDIENT_SELECTOR_AND_SEARCHBOX_SHARE_PRIMARY_ROLE finns kvar');
  kravFlagga('TOKEN_COMPOSITION_MAY_BE_REUSED_ACROSS_CONTROL_TYPES', 'YES');
  kravFlagga('SEARCH_HISTORY_TOKENS_LOCATION', 'OUTSIDE_SEARCHBOX_VALUE');
  kravFlagga('SEARCH_HISTORY_IS_CURRENT_SEARCH_VALUE', 'NO');
  kravFlagga('CONTROL_STATE_CANDIDATE_LIST_KIND', 'REVIEW_MATRIX');
  kravFlagga('CONTROL_STATE_VOCABULARY_CLOSED', 'NO');

  // Gapets nedstromsresolution maste bara sin egen historia.
  const GH = K.gaphistorik;
  if (!GH || GH.previous_state !== 'OPEN' || GH.new_state !== 'RESOLVED' ||
    GH.resolved_by !== 'HUMAN_APPROVED_BLOCK_286')
    fail('gapets resolution saknar bevarad historik');

  // En oppen vokabular far inte i sig skapa en rad (TKN286-20).
  if (MB.SEARCHBOX_TOKENIZED_STATE_ROW_CREATED !== 'NO' ||
    K.population.tillstand !== 7 || TYPER_ROWS() !== 70)
    fail('en state-rad har skapats trots att resolutionen ar COMPOSITE_VISUAL_MODE');

  // Beslutet ar manskligt och maste bara sin referens.
  if (K.utfall.PROVENANCE !== 'HUMAN_APPROVED')
    fail('modellbesluten ar registrerade men utfallet bar proveniensen ' + K.utfall.PROVENANCE);
  if (!K.utfall.HUMAN_DECISION_ID)
    fail('modellbesluten ar registrerade men utfallet saknar beslutsreferens');

  // Den svenska ordalydelsen ar innehall, aldrig identitet (C).
  if (JSON.stringify(F).includes('Ta bort svamp'))
    fail('en tillganglig ordalydelse har hamnat i identitetsblocket');

  // J · uppdelningen kalla kontra beslut maste vara uttrycklig.
  const UD = K.uppdelning || {};
  if (!(UD.SOURCE_GROUNDED || []).length || !(UD.HUMAN_APPROVED || []).length)
    fail('kallan skiljer inte uttryckligen mellan det kallbelagda och det beslutade');

  // Utfallet och det registrerade beslutet maste saga samma sak.
  if (K.utfall.MODELL !== MB.TOKENIZED_MODEL_OUTCOME)
    fail('utfallet ' + K.utfall.MODELL + ' stammer inte med beslutet ' + MB.TOKENIZED_MODEL_OUTCOME);

  // B + C · kompositionens delar. Visuell chip-form ar aldrig semantik.
  const delar = (K.komposition && K.komposition.delar) || [];
  const del = n => delar.find(d => d.DEL === n) || fail('kompositionen saknar delen ' + n);
  const sok = del('searchbox'), tok = del('token'), bort = del('token_borttagning');
  del('fritext');
  if (sok.ROLL !== 'searchbox')
    fail('kompositionens falt ar inte searchbox utan ' + sok.ROLL);
  if (sok.EGET_TOKENIZED_STATE)
    fail('kompositionens searchbox har fatt ett eget tokeniserat tillstand');
  if (tok.ARVER_FRAN_FILTERCHIP !== false)
    fail('soktokenen arver filterchippets semantik');
  if (/vaxlingsknapp|pressed/i.test(JSON.stringify([tok.ROLL, tok.STATE])))
    fail('soktokenen har fatt filterchippets roll eller tillstand (' + tok.ROLL + ' / ' + tok.STATE + ')');
  if (tok.ROLL && tok.HARLEDD_UR !== 'INTERAKTION')
    fail('soktokenens roll ar harledd ur ' + tok.HARLEDD_UR + ', inte ur den faktiska interaktionen');
  if (bort.ROLL !== MB.REMOVABLE_SEARCH_TOKEN_ACTION_ROLE)
    fail('borttagningsatgarden har rollen ' + bort.ROLL + ', beslutet sager ' +
      MB.REMOVABLE_SEARCH_TOKEN_ACTION_ROLE);
  if (bort.KRAVER_TILLGANGLIGT_NAMN !== true)
    fail('borttagningsatgarden saknar krav pa tillgangligt namn');
  if (bort.NAMN_AR_IDENTITET !== false)
    fail('borttagningsatgardens ordalydelse har gjorts till identitet');

  // (D kors efter rollvokabular-grinden nedan, sa att ett monster i ett
  // rollfalt alltid fangas av grinden och inte av en senare kontroll.)
  const PM = K.primarmonster || {};
  const kontrolleraMonster = () => {
  const sp = PM['#sokpanel'], ing = PM['#ingredienssok'];
  if (!sp || typeof sp !== 'object' || !ing || typeof ing !== 'object')
    fail('primarmonstren skiljer inte roll fran interaktionsmonster');
  if (sp.PRIMARY_ACCESSIBILITY_ROLE !== MB.SEARCH_PANEL_PRIMARY_ACCESSIBILITY_ROLE)
    fail('sokpanelens roll ar ' + sp.PRIMARY_ACCESSIBILITY_ROLE + ', inte searchbox');
  if (sp.INTERACTION_PATTERN !== 'SEARCH') fail('sokpanelens monster ar ' + sp.INTERACTION_PATTERN);
  if (ing.PRIMARY_ACCESSIBILITY_ROLE === 'searchbox')
    fail('ingrediensvaljaren har relabelats searchbox genom Block 286');
  if (ing.PRIMARY_ACCESSIBILITY_ROLE !== MB.INGREDIENT_SELECTOR_PRIMARY_ACCESSIBILITY_ROLE)
    fail('ingrediensvaljarens roll ar ' + ing.PRIMARY_ACCESSIBILITY_ROLE + ', beslutet sager ' +
      MB.INGREDIENT_SELECTOR_PRIMARY_ACCESSIBILITY_ROLE);
  if (ing.INTERACTION_PATTERN !== MB.INGREDIENT_SELECTOR_INTERACTION_PATTERN)
    fail('ingrediensvaljarens monster ar ' + ing.INTERACTION_PATTERN);
  if (MB.INGREDIENT_SELECTOR_AND_SEARCHBOX_SHARE_INTERACTION_PATTERN === 'NO' &&
    ing.INTERACTION_PATTERN === sp.INTERACTION_PATTERN)
    fail('ingrediensvaljaren och sokpanelen delar monster trots beslutet');
  };

  // C · rollvokabular-grinden. Den stangda rollistan lases ur lint-core och
  // Block 284 — aldrig ur Block 286 sjalv. Ett rollfalt far bara bara en
  // erkand roll, UNSPECIFIED eller null. Ett interaktionsmonster far aldrig
  // smyga in som roll, och Block 286 far aldrig utvidga vokabularen.
  const lintRoller = (/const ROLES = new Set\(\[([^\]]+)\]\)/.exec(
    readFileSync(join(ROOT, 'tools/lint-core.mjs'), 'utf8')) || [])[1];
  if (!lintRoller) fail('lint-cores stangda rollvokabular kunde inte lasas');
  const STANGD = lintRoller.split(',').map(s => s.trim().replace(/'/g, ''));
  const ERKAND = B284.ERKAND_ROLLVOKABULAR || [];
  const KANDIDAT = (B284.PRODUKTBESLUT && B284.PRODUKTBESLUT.SLUTLIG_VOKABULAR_KANDIDAT) || [];
  if (JSON.stringify([...ERKAND].sort()) !== JSON.stringify([...STANGD].sort()))
    fail('Block 284:s erkanda vokabular och lint-cores stangda lista har glidit isar');
  if ([...ERKAND, ...KANDIDAT].includes('TOKEN_MULTISELECT'))
    fail('TOKEN_MULTISELECT har hamnat i Block 284:s rollvokabular');
  if ((K.rollvokabular_tillagg || []).length)
    fail('Block 286 forsoker utvidga rollvokabularen med ' + JSON.stringify(K.rollvokabular_tillagg));
  const TILLATNA = new Set([...STANGD, ...KANDIDAT, 'UNSPECIFIED']);
  if (!STANGD.includes(MB.REMOVABLE_SEARCH_TOKEN_ACTION_ROLE))
    fail('borttagningsatgardens roll ' + MB.REMOVABLE_SEARCH_TOKEN_ACTION_ROLE +
      ' ar inte en befintlig roll i den stangda vokabularen');
  const ROLLFALT = /^(ROLE|ROLL|ACCESSIBILITY_ROLE|PRIMARY_ACCESSIBILITY_ROLE|FINAL_ROLE|[A-Z_]+_(ACCESSIBILITY|ACTION|FINAL)_ROLE)$/;
  const gaIgenom = (o, stig) => {
    if (!o || typeof o !== 'object') return;
    for (const [k, v] of Object.entries(o)) {
      const s = stig + '.' + k;
      if (ROLLFALT.test(k) && !/SHARE|_IS_/.test(k) && v !== null && v !== undefined) {
        if (v === 'TOKEN_MULTISELECT' || /MULTISELECT|PATTERN/i.test(String(v)))
          fail('interaktionsmonstret ' + v + ' ligger i rollfaltet ' + s);
        if (!TILLATNA.has(v)) fail('rollfaltet ' + s + ' bar ' + v + ', som inte ar en erkand roll');
      }
      gaIgenom(v, s);
    }
  };
  gaIgenom(K, 'kalla');
  kontrolleraMonster();

  // E · sokhistorik ar inte faltets varde.
  const SH = K.sokhistorik || {};
  if (SH.RAKNAS_SOM_AKTUELLT_VARDE !== false || SH.EGET_SEARCHBOX_STATE)
    fail('sokhistoriken raknas som aktuellt searchbox-varde eller tillstand');
}
function TYPER_ROWS() { return B283.CONTROL_STATE.ROWS; }

/* ── 3 · utfallet ─────────────────────────────────────────────────────────
   TKN286-12: ett pastaende om ett nytt persistent state utan positivt
   normativt stod far aldrig passera. */

const U = K.utfall;
if (!ALTERNATIV.includes(U.MODELL))
  fail('utfallet ' + U.MODELL + ' ar inte ett av de fyra alternativen');
if (A[U.MODELL].BEDOMNING === 'NOT_SUPPORTED')
  fail('utfallet ' + U.MODELL + ' ar valt trots att alternativet bedomts NOT_SUPPORTED');

if (U.MODELL === 'NEW_PERSISTENT_STATE') {
  const a = A.NEW_PERSISTENT_STATE;
  if (a.BEDOMNING !== 'SUPPORTED')
    fail('NEW_PERSISTENT_STATE ar valt utan att alternativet bedomts SUPPORTED');
  if (!(a.SOURCE || []).length || !a.EVIDENCE || a.EVIDENCE === '—')
    fail('NEW_PERSISTENT_STATE ar valt utan positiv normativ grund med kalla och citat');
  if (!U.FORESLAGEN_STATE_ID) fail('ett nytt state saknar foreslagen persistent identitet');
}
const PROV = ['SOURCE_GROUNDED', 'HUMAN_APPROVED', 'UNRESOLVED_FROM_SOURCE_SILENCE',
  'UNVERIFIABLE_FROM_SOURCE'];
if (!PROV.includes(U.PROVENANCE)) fail('utfallets proveniens ' + U.PROVENANCE + ' ar inte tillaten');
if (U.PROVENANCE === 'HUMAN_APPROVED' && !U.HUMAN_DECISION_ID)
  fail('utfallet bar HUMAN_APPROVED utan beslutsreferens');
if (U.MODELL === 'UNRESOLVED' && !(K.kraver_beslut || []).length)
  fail('utfallet ar UNRESOLVED men ingen fraga ar formulerad at uppdragsgivaren');

// TKN286-14: under en sammansatt modell far ingen tokeniserad state-id foreslas.
if (U.MODELL !== 'NEW_PERSISTENT_STATE' && U.FORESLAGEN_STATE_ID)
  fail('en state-identitet ' + U.FORESLAGEN_STATE_ID + ' ar foreslagen trots att utfallet ar ' + U.MODELL);

// Nya state-rader raknas ur de faktiska populationerna, inte ur flaggan.
const K285 = JSON.parse(G);
const tokRader285 = K285.rollstate.filter(r => /TOKEN/i.test(r.STATE)).length;
const NEW_STATE_ROWS = (B283.CONTROL_STATE.ROWS - 70) + (B285.ROLE_STATE_ROWS - 24) + tokRader285;
const SEARCHBOX_TOKENIZED_STATE_ROW = tokRader285 ? 'PRESENT' : 'ABSENT';
if (U.MODELL === 'COMPOSITE_VISUAL_MODE' && NEW_STATE_ROWS !== 0)
  fail('resolutionen ar COMPOSITE_VISUAL_MODE men ' + NEW_STATE_ROWS + ' nya state-rader finns');

// Statusavtrycket bar utfallet och — nar beslutet ar registrerat — de
// normaliserade flaggorna och primarmonstren. Da kan ingen flagga vandas
// utan att avtrycket syns andras. Prosa ($-nycklar) ingar aldrig.
const statusDelar = [F.GAP_ID, U.MODELL, U.PROVENANCE];
const MB0 = K.modellbeslut || {};
if (Object.keys(MB0).length) {
  statusDelar.push(Object.fromEntries(Object.entries(MB0).filter(([k]) => !k.startsWith('$')).sort()));
  const P0 = K.primarmonster || {};
  statusDelar.push(['#sokpanel', '#ingredienssok'].map(k => P0[k] &&
    [k, P0[k].PRIMARY_ACCESSIBILITY_ROLE, P0[k].INTERACTION_PATTERN]));
}
const STATUS_FINGERPRINT = h(statusDelar);

/* ── 4 · populationskonsekvens ────────────────────────────────────────────
   Bada scenarierna redovisas oavsett utfall, och raknas — inte skrivs. */

const CS = B283.CONTROL_STATE;
const TYPER = K.population.kontrolltyper, TILLST = K.population.tillstand;
if (TYPER * TILLST !== CS.ROWS)
  fail('populationen ar inte den kryssprodukt kallan pastar: ' + TYPER + 'x' + TILLST +
    ' != ' + CS.ROWS);

const SCENARIO_A = {
  $om: 'Tokeniserad blir en egen persistent state-rad.',
  bara_searchbox: { rader: CS.ROWS + 1, kryssprodukt: false,
    $foljd: 'Matrisen upphor att vara en kryssprodukt: ' + TYPER + ' x ' + TILLST +
      ' = ' + CS.ROWS + ', men populationen skulle bli ' + (CS.ROWS + 1) + '.' },
  generaliserad: { rader: TYPER * (TILLST + 1), kryssprodukt: true,
    $foljd: 'Kryssprodukten bevaras men ' + (TYPER * (TILLST + 1) - CS.ROWS) +
      ' nya rader tillkommer, varav ' + (TYPER - 1) + ' for kontroller som aldrig tokeniseras.' },
  ny_identitet: U.FORESLAGEN_STATE_ID || 'CSR::ROLE::searchbox::TOKENIZED'
};
const SCENARIO_B = {
  $om: 'Tokeniserad blir inte en egen state-rad.',
  rader: CS.ROWS,
  kryssprodukt: true,
  var_informationen_bor: K.scenario_b_bor || '—'
};

/* ── 5 · sjalvkontroll ────────────────────────────────────────────────── */

const fv = K.forvantat, avvik = [];
let provade = 0;
const norm = v => (v && typeof v === 'object' && !Array.isArray(v))
  ? Object.fromEntries(Object.keys(v).sort().map(k => [k, norm(v[k])])) : v;
const jfr = (k, har) => {
  if (!(k in fv)) return;
  provade++;
  if (JSON.stringify(norm(har)) !== JSON.stringify(norm(fv[k])))
    avvik.push(k + ': ' + JSON.stringify(har) + ' != ' + JSON.stringify(fv[k]));
};
jfr('UTFALL', U.MODELL);
jfr('PROVENANCE', U.PROVENANCE);
jfr('BEDOMNINGAR', Object.fromEntries(ALTERNATIV.map(n => [n, A[n].BEDOMNING])));
jfr('IDENTITY_FINGERPRINT', IDENTITY_FINGERPRINT);
jfr('STATUS_FINGERPRINT', STATUS_FINGERPRINT);
jfr('KRAVER_BESLUT_ANTAL', (K.kraver_beslut || []).length);
jfr('SCENARIO_A_RADER', SCENARIO_A.bara_searchbox.rader);
jfr('SCENARIO_B_RADER', SCENARIO_B.rader);
jfr('KORPUS', K.korpus);
jfr('MATRIX_ROWS', B283.CONTROL_STATE.ROWS);
jfr('NEW_STATE_ROWS', NEW_STATE_ROWS);
jfr('SEARCHBOX_TOKENIZED_STATE_ROW', SEARCHBOX_TOKENIZED_STATE_ROW);
jfr('MODELLBESLUT_ANTAL', Object.keys(MB).length);
if (avvik.length) fail('kallans egna forvantningar stammer inte:\n  ' + avvik.join('\n  '));
if (provade === 0) fail('kallan deklarerar inga forvantningar att prova mot');

/* ── 6 · utdata ───────────────────────────────────────────────────────── */

if (arg('detalj') === 'alternativ') { console.log(JSON.stringify(A, null, 1)); process.exit(0); }

console.log(JSON.stringify({
  BLOCK: '286',
  INPUT_COMMIT: K.input_commit,
  BASELINE_READONLY: grind,
  MODELLFRAGA: { GAP_ID: F.GAP_ID, KOMPONENT: F.KOMPONENT, LAGE: F.LAGE,
    KALLANKNYTNING: F.KALLANKNYTNING },
  FRAGOR: K.fragor,
  ALTERNATIV: Object.fromEntries(ALTERNATIV.map(n => [n,
    { BEDOMNING: A[n].BEDOMNING, SOURCE: A[n].SOURCE || [] }])),
  UTFALL: U,
  KORPUS: K.korpus,
  SEXSTATE_SLUTSATS: K.sexstate_slutsats,
  POPULATION: { kontrolltyper: TYPER, tillstand: TILLST, rader: CS.ROWS },
  SCENARIO_A, SCENARIO_B,
  KRAVER_BESLUT: K.kraver_beslut || [],
  MODELLBESLUT: MB,
  GAPHISTORIK: K.gaphistorik || null,
  UPPDELNING: K.uppdelning || null,
  KOMPOSITION: K.komposition || null,
  PRIMARMONSTER: K.primarmonster || null,
  SOKHISTORIK: K.sokhistorik || null,
  BESVARADE_FRAGOR: K.besvarade_fragor || [],
  MATRIX_ROWS: B283.CONTROL_STATE.ROWS,
  NEW_STATE_ROWS,
  SEARCHBOX_TOKENIZED_STATE_ROW,
  IDENTITY_SCHEME: 'STATE_MODEL_GAP::<komponent>::<kallnamngivet lage>. Utan utfall, ' +
    'status, farg, geometri, index eller radnummer.',
  IDENTITY_FINGERPRINT,
  STATUS_FINGERPRINT,
  SJALVKONTROLL: { deklarerade_forvantningar: provade, avvikelser: avvik.length }
}, null, 1));
