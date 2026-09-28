#!/usr/bin/env node
// Block 285 — role state specification.
//
// Byggaren avgor ingenting. Den laser den kanoniska kallan, validerar den
// fail-closed och aggregerar. Varje dom bor i JSON:en, aldrig har.
//
// Kor: node tools/role-state-applicability.mjs [--root=.] [--detalj=rader]

import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const ROOT = resolve(arg('root') || '.');
const KALLA = arg('kalla') || join(ROOT, 'fas2/role-state-applicability.json');

const h = x => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 16);
const fail = m => { throw new Error('FAIL CLOSED: ' + m); };

const K = JSON.parse(readFileSync(KALLA, 'utf8'));
const R = K.rollstate;

/* ── 0 · read-only-grind mot Block 282, 283 och 284 ───────────────────────
   Blocken ar stangda. Byggaren kor deras egna committade verktyg och
   jamfor mot de frysta avtrycken. Avviker nagot ar hela analysen ogiltig. */

const kor = rel => {
  const ut = execFileSync(process.execPath, [join(ROOT, rel), '--root=' + ROOT],
    { encoding: 'utf8', maxBuffer: 1 << 26 });
  return JSON.parse(ut);
};
const B282 = kor('tools/stateflow-population.mjs');
const B283 = kor('tools/stateflow-applicability.mjs');
const B284 = kor('tools/role-vocabulary-reconciliation.mjs');

const FRYST = K.fryst_baslinje;
const grind = {
  '282_POPULATION': B282.POPULATION_FINGERPRINT,
  '282_IDENTITY': B282.IDENTITY_FINGERPRINT,
  '283_IDENTITY': B283.IDENTITY_FINGERPRINT,
  '283_STATUS': B283.STATUS_FINGERPRINT,
  '284_OCCURRENCE_IDENTITY': B284.OCCURRENCE_IDENTITY_FINGERPRINT,
  '284_OCCURRENCE_STATUS': B284.OCCURRENCE_STATUS_FINGERPRINT
};
for (const [k, v] of Object.entries(grind))
  if (FRYST[k] !== v)
    fail('Block-baslinjen har andrats: ' + k + ' ar ' + v + ', fryst vardet ar ' + FRYST[k]);
if (B284.FINAL_ROLE_COUNT !== 26 || B284.FINAL_ROLE_NULL_COUNT !== 0)
  fail('Block 284:s FINAL_ROLE-tackning har andrats');
grind['282_MAPPING'] = B284.BLOCK_282_283_READONLY['282_MAPPING'];
if (FRYST['282_MAPPING'] !== grind['282_MAPPING'])
  fail('Block 282:s mappningsavtryck har andrats');

// Read-only i bokstavlig mening: uppstroms kanoniska filer ska vara byte for
// byte desamma. Ett andrat fingeravtryck fangar en andrad slutsats; det har
// fangar en andrad fil.
const filhash = f => createHash('sha256').update(readFileSync(join(ROOT, f))).digest('hex').slice(0, 16);
for (const [f, vantat] of Object.entries(K.upstream_filhashar || {})) {
  const har = filhash(f);
  if (har !== vantat) fail('uppstromsfilen ' + f + ' har andrats: ' + har + ' != ' + vantat);
}
if (!K.upstream_filhashar || Object.keys(K.upstream_filhashar).length < 3)
  fail('kallan deklarerar inga uppstromshashar att prova read-only mot');
grind.upstream_filer = Object.keys(K.upstream_filhashar).length + ' oforandrade';
grind.grind = 'GRON';

/* ── 1 · identitet ────────────────────────────────────────────────────────
   Identiteten ar roll + tillstand. Ingenting annat far ga in i den:
   inte status, inte FINAL_ROLE, inte representation, inte position. */

const ROLLER = ['link', 'menuitem', 'searchbox', 'combobox'];
const TILLSTAND = ['PRESSED', 'FOCUSED', 'SELECTED', 'DISABLED', 'EXPANDED', 'COLLAPSED'];
const STATUSAR = ['REQUIRED', 'NOT_REQUIRED', 'UNSPECIFIED', 'UNVERIFIABLE'];
const PROVENANS = ['SOURCE_GROUNDED', 'HUMAN_APPROVED',
  'UNSPECIFIED_FROM_SOURCE_SILENCE', 'UNVERIFIABLE_FROM_SOURCE'];
const REPR = ['PRESENT', 'ABSENT', 'UNVERIFIABLE', 'NOT_APPLICABLE'];

if (!Array.isArray(R)) fail('kallan saknar radlistan rollstate');

const sedda = new Set();
for (const r of R) {
  const vantat = 'CSR::ROLE::' + r.ROLE + '::' + r.STATE;
  if (r.ROW_ID !== vantat)
    fail(r.ROW_ID + ' stammer inte med sin egen roll och tillstand (' + vantat + ')');
  if (!ROLLER.includes(r.ROLE)) fail(r.ROW_ID + ' bar en roll utanfor blockets fyra: ' + r.ROLE);
  if (!TILLSTAND.includes(r.STATE)) fail(r.ROW_ID + ' bar ett tillstand utanfor de sex: ' + r.STATE);
  if (sedda.has(r.ROW_ID)) fail('identitetskollision: ' + r.ROW_ID);
  sedda.add(r.ROW_ID);

  // Identiteten far inte bara remedierbara egenskaper.
  for (const forbjudet of ['STATUS', 'FINAL_ROLE', 'FARG', 'GEOMETRI', 'INDEX', 'RADNUMMER'])
    if (r.ROW_ID.includes(forbjudet)) fail(r.ROW_ID + ' bar ' + forbjudet + ' i sin identitet');
}

const IDENTITY_FINGERPRINT = h([...sedda].sort());
const IDENTITY_COLLISIONS = R.length - sedda.size;

/* ── 2 · domarna ──────────────────────────────────────────────────────────
   UNKNOWN finns inte i detta block. Franvaro av krav ar UNSPECIFIED,
   aldrig NOT_REQUIRED. En REQUIRED-rad utan kalla faller bygget. */

const kallnycklar = new Set(Object.keys(K.kallregister));
for (const r of R) {
  if (r.PREVIOUS_STATUS !== 'UNSPECIFIED')
    fail(r.ROW_ID + ' pastar sig komma fran ' + r.PREVIOUS_STATUS +
      '; alla 24 var UNSPECIFIED efter Block 283');
  if (!STATUSAR.includes(r.PROPOSED_STATUS))
    fail(r.ROW_ID + ' har status ' + r.PROPOSED_STATUS + ' som inte ar tillaten');
  if (!PROVENANS.includes(r.PROVENANCE))
    fail(r.ROW_ID + ' har proveniens ' + r.PROVENANCE + ' som inte ar tillaten');
  if (!Array.isArray(r.SOURCE)) fail(r.ROW_ID + ' saknar kallista');
  for (const s of r.SOURCE)
    if (!kallnycklar.has(s)) fail(r.ROW_ID + ' aberopar kallan ' + s + ' som inte star i kallregistret');
  if (!r.DECISION_BASIS || r.DECISION_BASIS === '—')
    fail(r.ROW_ID + ' saknar motivering');

  const harKalla = r.SOURCE.length > 0 && r.SOURCE_LOCATION && r.SOURCE_LOCATION !== '—'
    && r.EVIDENCE && r.EVIDENCE !== '—';
  const harBeslut = !!(r.HUMAN_DECISION_ID && r.DECISION_BASIS && r.DECISION_BASIS !== '—');

  // En dom vilar antingen pa en kalla eller pa ett uttryckligt beslut.
  // De tva far aldrig byta plats med varandra.
  if (r.PROPOSED_STATUS === 'REQUIRED' || r.PROPOSED_STATUS === 'NOT_REQUIRED') {
    if (!['SOURCE_GROUNDED', 'HUMAN_APPROVED'].includes(r.PROVENANCE))
      fail(r.ROW_ID + ' ar ' + r.PROPOSED_STATUS + ' men har proveniensen ' + r.PROVENANCE +
        '; kalltystnad kan aldrig bli en dom');
    if (r.PROVENANCE === 'SOURCE_GROUNDED' && !harKalla)
      fail(r.ROW_ID + ' pastas ' + r.PROPOSED_STATUS +
        ' pa kallgrund men bar ingen kalla, plats och evidens');
    if (r.PROVENANCE === 'HUMAN_APPROVED' && !harBeslut)
      fail(r.ROW_ID + ' pastas ' + r.PROPOSED_STATUS +
        ' pa beslutsgrund men bar ingen beslutsreferens och motivering');
  }
  // Ett mansklig beslut far inte skriva om sig sjalvt till kallbelagt.
  if (r.HUMAN_DECISION_ID && r.PROVENANCE === 'SOURCE_GROUNDED')
    fail(r.ROW_ID + ' bar beslutsreferensen ' + r.HUMAN_DECISION_ID +
      ' men proveniensen SOURCE_GROUNDED — ett beslut far inte relabelas till kallbelagt');
  if (r.PROPOSED_STATUS === 'UNSPECIFIED' && r.PROVENANCE !== 'UNSPECIFIED_FROM_SOURCE_SILENCE')
    fail(r.ROW_ID + ' ar UNSPECIFIED men proveniensen sager ' + r.PROVENANCE);
  if (r.PROPOSED_STATUS === 'UNVERIFIABLE') {
    if (r.PROVENANCE !== 'UNVERIFIABLE_FROM_SOURCE')
      fail(r.ROW_ID + ' ar UNVERIFIABLE men proveniensen sager ' + r.PROVENANCE);
    if (!r.SOURCE.length)
      fail(r.ROW_ID + ' ar UNVERIFIABLE men namner ingen kalla som faktiskt finns');
  }
  if (r.PROVENANCE === 'HUMAN_APPROVED' && !r.HUMAN_DECISION_ID)
    fail(r.ROW_ID + ' bar HUMAN_APPROVED utan beslutsreferens');

  // Representation ar en separat axel och far aldrig styra applicability.
  if (!REPR.includes(r.REPRESENTATION))
    fail(r.ROW_ID + ' har representationen ' + r.REPRESENTATION + ' som inte ar tillaten');
  if (typeof r.REPRESENTATION_OCCURRENCES !== 'number')
    fail(r.ROW_ID + ' saknar matt representation');
  if (r.REPRESENTATION === 'PRESENT' && r.REPRESENTATION_OCCURRENCES === 0)
    fail(r.ROW_ID + ' sager PRESENT men ar matt till noll forekomster');
  if (r.REPRESENTATION === 'ABSENT' && r.REPRESENTATION_OCCURRENCES !== 0)
    fail(r.ROW_ID + ' sager ABSENT men ar matt till ' + r.REPRESENTATION_OCCURRENCES);
}

/* ── 2b · registrerade modellbeslut och faktakorrigeringar ───────────────
   Flaggorna ar en del av domen och provas darfor har, inte i prosan. */

const PB = K.produktbeslut_i_kraft || {};
const kravFlagga = (namn, vantat) => {
  if (PB[namn] !== vantat)
    fail('flaggan ' + namn + ' ar ' + JSON.stringify(PB[namn]) + ', vantade ' + JSON.stringify(vantat));
};
kravFlagga('SEARCHBOX_SPEC_GAP', 'NO');
kravFlagga('SEARCHBOX_VILA_MAPS_TO_DEFAULT', 'YES');
kravFlagga('SEARCHBOX_VILA_PROVENANCE', 'HUMAN_APPROVED');
kravFlagga('SEARCHBOX_TOKENIZED_STATE_MODEL_GAP', 'YES');
kravFlagga('PHONE_DROPDOWN_AS_SHEET_GENERALIZES_TO_ADMIN_WEB', 'NO');
kravFlagga('UNAVAILABLE_MENU_ACTION_POLICY', 'OMIT');
kravFlagga('MENUITEM_EXPANSION_OWNER', 'OPENER_OR_MENU_CONTAINER');
kravFlagga('COMBOBOX_EXPANSION_MODEL', 'EXPANDED_BOOLEAN');
kravFlagga('COMBOBOX_COLLAPSED_SEPARATE_STATE', 'NO');

// En faktakorrigering maste bara sin egen historia.
const H = K.flagghistorik && K.flagghistorik.SEARCHBOX_SPEC_GAP;
if (!H || H.previous_value !== 'YES' || H.new_value !== 'NO' || !H.reason)
  fail('SEARCHBOX_SPEC_GAP ar korrigerad men saknar bevarad andringshistorik');

// Vila -> DEFAULT far inte skapa en ny rad, och tokenized-gapet inte heller.
if (R.length !== 24)
  fail('Block 285 ska ha exakt 24 rader, har ' + R.length);
if (R.some(r => r.STATE === 'VILA' || r.STATE === 'DEFAULT' || r.STATE === 'TOKENISERAD'))
  fail('en taxonomisk benamning har blivit en egen state-rad i Block 285');
if (B283.CONTROL_STATE.ROWS !== 70)
  fail('Block 283:s population har andrats: ' + B283.CONTROL_STATE.ROWS + ' rader');

// Kallbelagda domar ar lasta: de far inte skrivas om till beslut.
for (const id of (K.lasta_kallbelagda || [])) {
  const r = R.find(x => x.ROW_ID === id);
  if (!r) fail('den lasta kallbelagda raden ' + id + ' saknas');
  if (r.PROVENANCE !== 'SOURCE_GROUNDED')
    fail(id + ' ar last som kallbelagd men bar proveniensen ' + r.PROVENANCE);
  if (!r.SOURCE.length || r.SOURCE_LOCATION === '—' || r.EVIDENCE === '—')
    fail(id + ' ar last som kallbelagd men har tappat sin kalla');
}

// Ar stangt lage modellerat som expanded=false far COLLAPSED inte krava en egen rad.
if (PB.COMBOBOX_COLLAPSED_SEPARATE_STATE === 'NO') {
  const c = R.find(x => x.ROW_ID === 'CSR::ROLE::combobox::COLLAPSED');
  if (c && c.PROPOSED_STATUS === 'REQUIRED')
    fail('combobox::COLLAPSED kravs som eget tillstand trots att modellen sager ' +
      'expanded=false (COMBOBOX_COLLAPSED_SEPARATE_STATE = NO)');
}

/* ── 3 · aggregat ─────────────────────────────────────────────────────────
   Statusavtrycket bar roll, tillstand och status — aldrig representation. */

const STATUS_FINGERPRINT = h(R.map(r => r.ROW_ID + '|' + r.PROPOSED_STATUS).sort());

const rakna = (xs, f) => xs.reduce((o, x) => (o[f(x)] = (o[f(x)] || 0) + 1, o), {});
const FORDELNING = rakna(R, r => r.PROPOSED_STATUS);
const PER_ROLL = {};
for (const roll of ROLLER) {
  const rader = R.filter(r => r.ROLE === roll);
  PER_ROLL[roll] = {
    rader: rader.length,
    ...rakna(rader, r => r.PROPOSED_STATUS),
    kallor: [...new Set(rader.flatMap(r => r.SOURCE))].sort()
  };
}
const PROVENIENS = rakna(R, r => r.PROVENANCE);

// Representation redovisas bara for REQUIRED-rader, och halls utanfor beslutet.
const req = R.filter(r => r.PROPOSED_STATUS === 'REQUIRED');
const REPRESENTATION = {
  REQUIRED_PRESENT: req.filter(r => r.REPRESENTATION === 'PRESENT').length,
  REQUIRED_ABSENT: req.filter(r => r.REPRESENTATION === 'ABSENT').length,
  REQUIRED_UNVERIFIABLE: req.filter(r => r.REPRESENTATION === 'UNVERIFIABLE').length,
  $regel: 'REQUIRED + ABSENT ar ett fynd, inte en order att andra produkten. ' +
    'UNSPECIFIED + ABSENT ar inte ett produktfel.'
};

/* ── 4 · effekt pa Block 283:s 70-radersmatris (hypotetisk) ───────────────
   Block 283:s kalla andras inte i detta block. */

const CS = B283.CONTROL_STATE;
const EFTER_285 = { ...CS.EFTER };
EFTER_285.UNSPECIFIED -= R.length;
for (const [st, n] of Object.entries(FORDELNING))
  EFTER_285[st] = (EFTER_285[st] || 0) + n;
const summa = Object.values(EFTER_285).reduce((a, b) => a + b, 0);
if (summa !== CS.ROWS)
  fail('70-radersmatrisen gar inte ihop efter Block 285: ' + summa + ' != ' + CS.ROWS);

const HYPOTETISK_MATRIS = {
  FORE_285: CS.EFTER,
  EFTER_285,
  TOTAL: summa,
  $anm: 'Hypotetisk. Block 283:s kanoniska fil ar ororad tills Block 285 godkants.'
};

/* ── 5 · vad som kraver ditt beslut ───────────────────────────────────── */

const KRAVER_BESLUT = R.filter(r => r.KRAVER_BESLUT)
  .map(r => ({ ROW_ID: r.ROW_ID, FRAGA: r.KRAVER_BESLUT, NULAGE: r.PROPOSED_STATUS }));

/* ── 6 · sjalvkontroll mot kallans egna forvantningar ─────────────────── */

const fv = K.forvantat, avvik = [];
let provade = 0;
// Nyckelordning ar inte data. Ett aggregat med samma antal ar samma aggregat.
const norm = v => (v && typeof v === 'object' && !Array.isArray(v))
  ? Object.fromEntries(Object.keys(v).sort().map(k => [k, norm(v[k])])) : v;
const jfr = (k, har) => {
  if (!(k in fv)) return;
  provade++;
  if (JSON.stringify(norm(har)) !== JSON.stringify(norm(fv[k])))
    avvik.push(k + ': ' + JSON.stringify(har) + ' != ' + JSON.stringify(fv[k]));
};
jfr('ROLE_STATE_ROWS', R.length);
jfr('FORDELNING', FORDELNING);
jfr('PROVENIENS', PROVENIENS);
jfr('IDENTITY_FINGERPRINT', IDENTITY_FINGERPRINT);
jfr('STATUS_FINGERPRINT', STATUS_FINGERPRINT);
jfr('IDENTITY_COLLISIONS', IDENTITY_COLLISIONS);
jfr('REPRESENTATION', { REQUIRED_PRESENT: REPRESENTATION.REQUIRED_PRESENT,
  REQUIRED_ABSENT: REPRESENTATION.REQUIRED_ABSENT,
  REQUIRED_UNVERIFIABLE: REPRESENTATION.REQUIRED_UNVERIFIABLE });
jfr('EFTER_285', EFTER_285);
jfr('KRAVER_BESLUT_ANTAL', KRAVER_BESLUT.length);
if (avvik.length) fail('kallans egna forvantningar stammer inte:\n  ' + avvik.join('\n  '));
if (provade === 0) fail('kallan deklarerar inga forvantningar att prova mot');

/* ── 7 · utdata ───────────────────────────────────────────────────────── */

if (arg('detalj') === 'rader') { console.log(JSON.stringify(R, null, 1)); process.exit(0); }

console.log(JSON.stringify({
  BLOCK: '285',
  INPUT_COMMIT: K.input_commit,
  BASELINE_READONLY: grind,
  ROLE_STATE_ROWS: R.length,
  ROLLER,
  TILLSTAND,
  FORDELNING,
  PER_ROLL,
  PROVENIENS,
  REPRESENTATION,
  HYPOTETISK_MATRIS,
  KRAVER_BESLUT,
  IDENTITY_SCHEME: 'CSR::ROLE::<roll>::<TILLSTAND>. Utan status, roll-beslut, ' +
    'representation, farg, geometri, index eller radnummer.',
  IDENTITY_COLLISIONS,
  IDENTITY_FINGERPRINT,
  STATUS_FINGERPRINT,
  SJALVKONTROLL: { deklarerade_forvantningar: provade, avvikelser: avvik.length }
}, null, 1));
