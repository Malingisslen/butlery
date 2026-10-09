#!/usr/bin/env node
// BUTLERY · BLOCK 284 · ROLE VOCABULARY RECONCILIATION.  READ-ONLY BYGGARE.
//
// Harleder de faktiska forekomsterna av de fyra oerkanda rollerna ur SAMMA
// lintpopulation som gav Block 283-fyndet: elementen i skarmkorpusen vars
// data-a11y-role ligger utanfor den stangda vokabularen i tools/lint-core.mjs.
//
// Klassificeringen bor i en SEPARAT kalla. Byggaren avgor ingenting.
//
// IDENTITETSKONTRAKT
//   OCCURRENCE_ID = RV284::<skarm-id>::<slug av authored a11y-name>
//   Bada leden ar authored. Identiteten innehaller ALDRIG nuvarande roll,
//   foreslagen roll, status, DOM-index, arrayposition, farg, geometri eller
//   radnummer. En roll som byts behaller darfor sin identitet.
//
// FAIL CLOSED
//   · identitetskollision avbryter
//   · Block 282:s och Block 283:s frysta fingeravtryck maste reproduceras
//   · varje forekomst maste tackas av klassificeringskallan, exakt en gang
//
// Kor: node tools/role-vocabulary-reconciliation.mjs [--root=.] [--detalj=occ|roll]

import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const ROOT = arg('root') || '.';
const R = p => readFileSync(join(ROOT, p), 'utf8');
const KALLA = arg('kalla') || join(ROOT, 'fas2/role-vocabulary-reconciliation.json');
const K = JSON.parse(readFileSync(KALLA, 'utf8'));
if (K.$schema !== 'butlery-role-vocabulary/1')
  throw new Error('FAIL CLOSED: okant schema: ' + K.$schema);

/* ── A · BLOCK 282/283 READ-ONLY-GRIND ─────────────────────────────────── */
const kor = (verktyg, d) => JSON.parse(execFileSync(process.execPath,
  [join(ROOT, verktyg), '--root=' + ROOT, ...(d ? ['--detalj=' + d] : [])],
  { encoding: 'utf8', maxBuffer: 1 << 26 }));
const P282 = kor('tools/stateflow-population.mjs');
const P283 = kor('tools/stateflow-applicability.mjs');
const grind = [
  ['282 POPULATION', P282.POPULATION_FINGERPRINT, '5ede5a7c9ab3dfef'],
  ['282 IDENTITY', P282.IDENTITY_FINGERPRINT, 'd0c7b88913b45f18'],
  ['282 MAPPING', P282.MAPPNINGSREVISION.MAPPING_FINGERPRINT, '639a14d6afb84664'],
  ['283 IDENTITY', P283.IDENTITY_FINGERPRINT, '2e7816936df8d602'],
  ['283 STATUS', P283.STATUS_FINGERPRINT, '48182cf827ccfb6b']
];
for (const [namn, har, vantat] of grind)
  if (har !== vantat) throw new Error('FAIL CLOSED: ' + namn + ' ar ' + har + ', fryst vardet ar ' + vantat);
if (P283.PRODUKTBESLUT.ROLE_VOCABULARY_CONFLICT_OPEN !== 'YES')
  throw new Error('FAIL CLOSED: rollkonflikten ar inte langre oppen i Block 283');

/* ── B · FOREKOMSTPOPULATIONEN ur samma lintpopulation ─────────────────── */
const lint = R('tools/lint-core.mjs');
const rm = /const ROLES = new Set\(\[([^\]]+)\]\);/.exec(lint);
if (!rm) throw new Error('FAIL CLOSED: T-08:s rollvokabular kunde inte lasas ur lint-core');
const ERKANDA = new Set(rm[1].split(',').map(s => s.trim().replace(/^'|'$/g, '')));

const SCREEN_FILES = R('tools/screen-files.mjs')
  .split('export const SCREEN_FILES')[1].split('];')[0]
  .split('\n').map(l => (/'([^']+\.dc\.html)'/.exec(l) || [])[1]).filter(Boolean);

const slug = s => s.toLowerCase().replace(/[^a-z0-9åäö]+/g, '-').replace(/^-|-$/g, '').slice(0, 52);
const FOREKOMSTER = [];
for (const f of SCREEN_FILES) {
  const s = R(f);
  const ramar = [...s.matchAll(/<div class="sc-item" id="([^"]+)"/g)];
  const ramVid = i => { let c = null; for (const m of ramar) { if (m.index <= i) c = m[1]; else break; } return c; };
  for (const m of s.matchAll(/<([a-z]+)([^>]*data-a11y-role="([^"]+)"[^>]*)>/g)) {
    const roll = m[3];
    if (ERKANDA.has(roll)) continue;
    const namn = (/data-a11y-name="([^"]*)"/.exec(m[2]) || [])[1];
    if (!namn) throw new Error('FAIL CLOSED: konfliktforekomst utan authored namn i ' + f);
    const artefakt = ramVid(m.index);
    if (!artefakt) throw new Error('FAIL CLOSED: forekomst utanfor varje ram i ' + f);
    FOREKOMSTER.push({
      OCCURRENCE_ID: 'RV284::' + artefakt + '::' + slug(namn),
      ARTIFACT_ID: artefakt, CONTROL_NAME: namn, CURRENT_ROLE: roll,
      TAG: m[1], HAS_HIT: /data-hit=/.test(m[2]),
      HREF: (/href="([^"]*)"/.exec(m[2]) || [])[1] || null,
      SOURCE_LOCATION: f + ' · ram ' + artefakt
    });
  }
}
{
  const ids = FOREKOMSTER.map(x => x.OCCURRENCE_ID);
  const dup = ids.filter((v, i) => ids.indexOf(v) !== i);
  if (dup.length) throw new Error('FAIL CLOSED: identitetskollision: ' + [...new Set(dup)].join(', '));
}

/* Tidigt lage: skriv ut den HARLEDDA forekomstlistan och sluta. Finns sa att
 * klassificeringskallan kan rattas mot EN harledning i stallet for mot en
 * handskriven gissning. Kors fore taeckningskontrollen med flit. */
if (arg('emit-forekomster') !== undefined && process.argv.some(a => a.startsWith('--emit-forekomster'))) {
  console.log(JSON.stringify(FOREKOMSTER, null, 1));
  process.exit(0);
}

/* ── C · KLASSIFICERINGEN ur den separata kallan ───────────────────────── */
const UTFALL = new Set(['CURRENT_ROLE_SUPPORTED', 'EXISTING_ROLE_SUPPORTED', 'SEMANTIC_ROLE_UNRESOLVED']);
const kallRader = new Map();
for (const r of K.forekomster) {
  if (kallRader.has(r.OCCURRENCE_ID)) throw new Error('FAIL CLOSED: dubblerad rad ' + r.OCCURRENCE_ID);
  if (!UTFALL.has(r.OUTCOME)) throw new Error('FAIL CLOSED: ogiltigt utfall ' + r.OUTCOME + ' i ' + r.OCCURRENCE_ID);
  if (r.OUTCOME === 'EXISTING_ROLE_SUPPORTED' && !ERKANDA.has(r.SUPPORTED_ROLE))
    throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' pekar pa en icke-erkand roll: ' + r.SUPPORTED_ROLE);
  if (r.OUTCOME !== 'SEMANTIC_ROLE_UNRESOLVED' && (!r.SOURCE || !r.SOURCE.length))
    throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' har utfall utan kalla');
  // Ett manskligt beslut bar sin proveniens explicit och far aldrig harledas.
  if (r.DECISION !== undefined && r.DECISION !== null && r.DECISION !== 'HUMAN_APPROVED')
    throw new Error('FAIL CLOSED: okand beslutstyp ' + r.DECISION + ' i ' + r.OCCURRENCE_ID);
  if (r.DECISION === 'HUMAN_APPROVED') {
    if (r.OUTCOME !== 'CURRENT_ROLE_SUPPORTED')
      throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' ar HUMAN_APPROVED men utfallet ar ' + r.OUTCOME);
    if (!r.NEW_ROLE) throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' ar HUMAN_APPROVED utan NEW_ROLE');
  }
  if (r.NEW_ROLE && r.DECISION !== 'HUMAN_APPROVED')
    throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' bar NEW_ROLE utan manskligt beslut');
  // FINAL_ROLE ar den explicita slutrollen. Den harleds ALDRIG tyst har — den
  // maste sta i kallan, och byggaren provar bara att den ar forenlig med utfallet.
  const kravFinal = r.OUTCOME !== 'SEMANTIC_ROLE_UNRESOLVED';
  if (kravFinal && (r.FINAL_ROLE === undefined || r.FINAL_ROLE === null))
    throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' har utfallet ' + r.OUTCOME +
      ' men saknar FINAL_ROLE');
  if (!kravFinal && r.FINAL_ROLE)
    throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' ar olost men bar FINAL_ROLE ' + r.FINAL_ROLE);
  if (r.FINAL_ROLE) {
    const vokab = (K.produktbeslut && K.produktbeslut.SLUTLIG_VOKABULAR_KANDIDAT) || [...ERKANDA];
    if (!vokab.includes(r.FINAL_ROLE))
      throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' har FINAL_ROLE ' + r.FINAL_ROLE +
        ' utanfor den beslutade slutliga vokabularkandidaten');
    if (r.OUTCOME === 'EXISTING_ROLE_SUPPORTED' && r.FINAL_ROLE !== r.SUPPORTED_ROLE)
      throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' FINAL_ROLE ' + r.FINAL_ROLE +
        ' stammer inte med SUPPORTED_ROLE ' + r.SUPPORTED_ROLE);
    if (r.DECISION === 'HUMAN_APPROVED' && r.FINAL_ROLE !== r.NEW_ROLE)
      throw new Error('FAIL CLOSED: ' + r.OCCURRENCE_ID + ' FINAL_ROLE ' + r.FINAL_ROLE +
        ' stammer inte med beslutet ' + r.NEW_ROLE);
  }
  for (const s of r.SOURCE || [])
    if (!K.kallregister[s]) throw new Error('FAIL CLOSED: okand kalla "' + s + '" i ' + r.OCCURRENCE_ID);
  kallRader.set(r.OCCURRENCE_ID, r);
}
const saknas = FOREKOMSTER.filter(x => !kallRader.has(x.OCCURRENCE_ID)).map(x => x.OCCURRENCE_ID);
const over = [...kallRader.keys()].filter(id => !FOREKOMSTER.some(x => x.OCCURRENCE_ID === id));
if (saknas.length) throw new Error('FAIL CLOSED: forekomster utan klassificering:\n  ' + saknas.join('\n  '));
if (over.length) throw new Error('FAIL CLOSED: klassificering av forekomster som inte finns:\n  ' + over.join('\n  '));

const OCC = FOREKOMSTER.map(x => ({ ...x, ...kallRader.get(x.OCCURRENCE_ID) }));

/* ── D · SUMMERING PER ROLL ────────────────────────────────────────────── */
const ROLLER = [...new Set(OCC.map(x => x.CURRENT_ROLE))].sort();
const perRoll = {};
for (const roll of ROLLER) {
  const rader = OCC.filter(x => x.CURRENT_ROLE === roll);
  const c = n => rader.filter(x => x.OUTCOME === n).length;
  const stod = c('CURRENT_ROLE_SUPPORTED'), remap = c('EXISTING_ROLE_SUPPORTED'), olost = c('SEMANTIC_ROLE_UNRESOLVED');
  let niva;
  if (olost > 0) niva = (stod === 0 && remap === 0) ? 'UNRESOLVED' : 'MIXED';
  else if (stod > 0 && remap > 0) niva = 'MIXED';
  else if (stod > 0) niva = 'VOCAB_EXTENSION_SUPPORTED';
  else niva = 'ALL_OCCURRENCES_REMAP_SUPPORTED';
  perRoll[roll] = { forekomster: rader.length, CURRENT_ROLE_SUPPORTED: stod,
    EXISTING_ROLE_SUPPORTED: remap, SEMANTIC_ROLE_UNRESOLVED: olost, ROLLNIVA: niva,
    foreslagna_roller: [...new Set(rader.filter(x => x.SUPPORTED_ROLE).map(x => x.SUPPORTED_ROLE))].sort() };
}

/* ── E · KONSEKVENSANALYS · endast hypotetisk ──────────────────────────── */
const CSR283 = kor('tools/stateflow-applicability.mjs', 'csr');
const konfliktRader = CSR283.filter(x => ROLLER.includes(x.CONTROL_TYPE) && x.NEW_STATUS === 'UNSPECIFIED');
const hypotetisk = {};
for (const roll of ROLLER) {
  const rader = konfliktRader.filter(x => x.CONTROL_TYPE === roll);
  const r = perRoll[roll];
  const erkand = r.CURRENT_ROLE_SUPPORTED > 0;
  const remappade = r.EXISTING_ROLE_SUPPORTED;
  hypotetisk[roll] = {
    unspecified_rader_i_block_283: rader.length,
    rader: rader.map(x => x.ROW_ID),
    rollniva: r.ROLLNIVA,
    forekomster_kvar_i_rollen: r.forekomster - remappade,
    forekomster_som_byter_roll: remappade,
    KRAVER_NORMATIVT_BESLUT: erkand ? rader.length : 0,
    foljd: erkand
      ? ('Rollen ar erkand av minst en forekomst. Dess ' + rader.length + ' state-rader kraver darfor ' +
         'ett NORMATIVT BESLUT — de blir varken REQUIRED eller NOT_REQUIRED av att rollen erkanns.' +
         (remappade ? ' De ' + remappade + ' forekomster som byter roll skapar inte langre applicability for ' +
          roll + '; de anvander malrollens redan avgjorda rader.' : ''))
      : ('Ingen forekomst behaller rollen. Rollens ' + rader.length + ' state-rader blir inte langre ' +
         'relevanta, och forekomsterna anvander malrollens redan avgjorda rader.')
  };
}
const kraverBeslutTotalt = Object.values(hypotetisk).reduce((s, h) => s + h.KRAVER_NORMATIVT_BESLUT, 0);
const lintEffekt = {
  T08_fynd_idag: OCC.length,
  $anm: 'Vokabularen och lint ar INTE andrade i detta block.',
  vid_erkand_vokabular: 'ROLES i tools/lint-core.mjs skulle utokas med ' +
    (K.produktbeslut && K.produktbeslut.VOCABULARY_EXTENSION_CANDIDATES
      ? K.produktbeslut.VOCABULARY_EXTENSION_CANDIDATES.join(', ') : '(inga kandidater)') +
    ', och T-08-fynden for de forekomster som behaller sin roll skulle falla bort.',
  vid_remap_av_de_sju: 'De ' + OCC.filter(x => x.OUTCOME === 'EXISTING_ROLE_SUPPORTED').length +
    ' forekomster som byter till en redan erkand roll skulle falla bort ur T-08 utan nagon vokabularandring.',
  kvarstaende_T08_fynd_om_bada_gors: 0
};

/* ── F · FINGERAVTRYCK ─────────────────────────────────────────────────── */
/* En rad som behaller sin roll maste ha FINAL_ROLE lika med den roll korpusen
 * faktiskt bar. Den kontrollen kraver den harledda rollen och kan darfor inte
 * goras forran har. */
for (const x of OCC) {
  if (x.OUTCOME === 'CURRENT_ROLE_SUPPORTED' && x.FINAL_ROLE !== x.CURRENT_ROLE)
    throw new Error('FAIL CLOSED: ' + x.OCCURRENCE_ID + ' behaller sin roll men FINAL_ROLE ' +
      x.FINAL_ROLE + ' skiljer sig fran CURRENT_ROLE ' + x.CURRENT_ROLE);
}
/* Slutfordelningen harleds ENBART ur FINAL_ROLE — ingen sarskild logik for
 * "behaller sin roll" behovs. */
const FINAL_FORDELNING = {};
for (const x of OCC) if (x.FINAL_ROLE) FINAL_FORDELNING[x.FINAL_ROLE] = (FINAL_FORDELNING[x.FINAL_ROLE] || 0) + 1;
const FINAL_ROLE_COUNT = OCC.filter(x => x.FINAL_ROLE).length;
const FINAL_ROLE_NULL_COUNT = OCC.length - FINAL_ROLE_COUNT;
{
  const summa = Object.values(FINAL_FORDELNING).reduce((a, b) => a + b, 0);
  if (summa + FINAL_ROLE_NULL_COUNT !== OCC.length)
    throw new Error('FAIL CLOSED: FINAL_ROLE-aggregatet summerar till ' + summa + ' + ' +
      FINAL_ROLE_NULL_COUNT + ', inte ' + OCC.length);
}

const h = o => createHash('sha256').update(JSON.stringify(o)).digest('hex').slice(0, 16);
const OCC_IDENT_FP = h(OCC.map(x => x.OCCURRENCE_ID).sort());
// Statusavtrycket omfattar den explicita slutrollen. Identiteten gor det aldrig.
const OCC_STATUS_FP = h(OCC.map(x =>
  x.OCCURRENCE_ID + '|' + x.OUTCOME + '|' + (x.SUPPORTED_ROLE || '-') + '|' + (x.FINAL_ROLE || '-')).sort());

const ut = {
  BLOCK_282_283_READONLY: {
    '282_POPULATION': P282.POPULATION_FINGERPRINT, '282_IDENTITY': P282.IDENTITY_FINGERPRINT,
    '282_MAPPING': P282.MAPPNINGSREVISION.MAPPING_FINGERPRINT,
    '283_IDENTITY': P283.IDENTITY_FINGERPRINT, '283_STATUS': P283.STATUS_FINGERPRINT,
    ROLE_VOCABULARY_CONFLICT_OPEN: P283.PRODUKTBESLUT.ROLE_VOCABULARY_CONFLICT_OPEN,
    grind: 'GRON' },
  ERKAND_ROLLVOKABULAR: [...ERKANDA].sort(),
  TOTAL_ROLE_CONFLICT_OCCURRENCES: OCC.length,
  PER_NUVARANDE_ROLL: Object.fromEntries(ROLLER.map(r => [r, perRoll[r].forekomster])),
  UTFALL: { CURRENT_ROLE_SUPPORTED: OCC.filter(x => x.OUTCOME === 'CURRENT_ROLE_SUPPORTED').length,
    EXISTING_ROLE_SUPPORTED: OCC.filter(x => x.OUTCOME === 'EXISTING_ROLE_SUPPORTED').length,
    SEMANTIC_ROLE_UNRESOLVED: OCC.filter(x => x.OUTCOME === 'SEMANTIC_ROLE_UNRESOLVED').length },
  ROLLNIVA: Object.fromEntries(ROLLER.map(r => [r, perRoll[r].ROLLNIVA])),
  PER_ROLL: perRoll,
  FINAL_ROLE_FORDELNING: Object.fromEntries(Object.entries(FINAL_FORDELNING).sort()),
  FINAL_ROLE_COUNT, FINAL_ROLE_NULL_COUNT,
  PRODUKTBESLUT: K.produktbeslut || null,
  HUMAN_APPROVED_BESLUT: OCC.filter(x => x.DECISION === 'HUMAN_APPROVED')
    .map(x => ({ id: x.OCCURRENCE_ID, current_role: x.CURRENT_ROLE, new_role: x.NEW_ROLE,
      identitet_oforandrad: true, basis: x.DECISION_BASIS })),
  HUMAN_APPROVED_ANTAL: OCC.filter(x => x.DECISION === 'HUMAN_APPROVED').length,
  BLOCK_283_IMPACT: { ...hypotetisk, TOTALT_KRAVER_NORMATIVT_BESLUT: kraverBeslutTotalt,
    $regel: 'Att en roll erkanns gor ALDRIG en state-rad REQUIRED eller NOT_REQUIRED. Den maste specificeras separat.' },
  LINT_EFFEKT: lintEffekt,
  KRAVER_HUMAN_APPROVED: OCC.filter(x => x.KRAVER_BESLUT).map(x => ({ id: x.OCCURRENCE_ID, fraga: x.KRAVER_BESLUT })),
  IDENTITY_SCHEME: 'RV284::<skarm-id>::<slug av authored a11y-name>. Utan roll, status, index, farg eller geometri.',
  IDENTITY_COLLISIONS: 0,
  OCCURRENCE_IDENTITY_FINGERPRINT: OCC_IDENT_FP,
  OCCURRENCE_STATUS_FINGERPRINT: OCC_STATUS_FP
};

/* Sjalvkontroll mot kallans deklarerade forvantningar. */
const fv = K.forvantat || {}, avvik = [];
let provade = 0;
const jfr = (k, har) => { if (!(k in fv)) return; provade++;
  if (JSON.stringify(har) !== JSON.stringify(fv[k])) avvik.push(k + ': ' + JSON.stringify(har) + ' != ' + JSON.stringify(fv[k])); };
jfr('TOTAL_ROLE_CONFLICT_OCCURRENCES', OCC.length);
jfr('PER_NUVARANDE_ROLL', ut.PER_NUVARANDE_ROLL);
jfr('UTFALL', ut.UTFALL);
jfr('ROLLNIVA', ut.ROLLNIVA);
jfr('OCCURRENCE_IDENTITY_FINGERPRINT', OCC_IDENT_FP);
jfr('OCCURRENCE_STATUS_FINGERPRINT', OCC_STATUS_FP);
jfr('HUMAN_APPROVED_DECISIONS', ut.HUMAN_APPROVED_ANTAL);
jfr('FINAL_ROLE_COUNT', FINAL_ROLE_COUNT);
jfr('FINAL_ROLE_NULL_COUNT', FINAL_ROLE_NULL_COUNT);
jfr('FINAL_ROLE_FORDELNING', ut.FINAL_ROLE_FORDELNING);
// Nyckelordningen maste folja kallans, eftersom jamforelsen ar pa serialiserad form.
jfr('BLOCK_282_283', {
  '282_POPULATION': ut.BLOCK_282_283_READONLY['282_POPULATION'],
  '282_IDENTITY': ut.BLOCK_282_283_READONLY['282_IDENTITY'],
  '282_MAPPING': ut.BLOCK_282_283_READONLY['282_MAPPING'],
  '283_IDENTITY': ut.BLOCK_282_283_READONLY['283_IDENTITY'],
  '283_STATUS': ut.BLOCK_282_283_READONLY['283_STATUS']
});
if (avvik.length) throw new Error('FAIL CLOSED: byggt resultat avviker fran kallans forvantade varden:\n  ' + avvik.join('\n  '));
ut.SJALVKONTROLL = { deklarerade_forvantningar: provade, avvikelser: 0 };

const d = arg('detalj');
if (d === 'occ') console.log(JSON.stringify(OCC, null, 1));
else if (d === 'roll') console.log(JSON.stringify(perRoll, null, 1));
else console.log(JSON.stringify(ut, null, 1));
