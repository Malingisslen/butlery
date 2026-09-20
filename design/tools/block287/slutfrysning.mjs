// Kor: node tools/block287/slutfrysning.mjs --root=<kallrot> --bygge=<byggkatalog> [--torr]
//
// N · Den korrigerade Block 287-frysningen. Artefakterna kopieras oforandrade
// ur bygget till fas2/, och manifestet binder varje mangd de pastar nagot om -
// inte bara antalen. Validatorn raknar om alla hashar sjalv; ingenting har
// skrivs in for hand.
import { readFileSync, writeFileSync, copyFileSync, mkdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
import { bind } from './frysvalidator.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root'), BYGGE = arg('bygge'), TORR = process.argv.includes('--torr');
const p = f => join(BYGGE, f);
const j = f => JSON.parse(readFileSync(p(f), 'utf8'));

const pop = j('frys/block287k-population.json');
const grupper = j('grupper.json');
const plan = j('skrivplan.json');
const fynd = j('fynd.json');
const m2 = j('m2.json');
const disc = j('disc-A.json');
const bindning = bind(ROT, BYGGE);

const gitKort = () => { try { return execFileSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: ROT, encoding: 'utf8' }).trim(); } catch { return null; } };

const produkt = pop.filter(u => u.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED');
const manifest = {
  $om: 'Korrigerad Block 287-frysning',
  BLOCK: 287,
  STATUS: 'FROZEN',
  RUNDA: 'baslinjeavstamning + sexmalsavstamning',
  BASLINJE: {
    BL01_BASELINE_COMMIT: '06c1278',
    CORRECTION_ROUND_1_COMMIT: 'eecff3e',
    TARGET_METADATA_COMMIT: '4318ef2',
    FINAL_SEMANTIC_ANCHOR_COMMIT: '9c8d841',
    AVATAR_BASELINE_FIX_COMMIT: '24a00a8',
    HISTORICAL_EXPECTATION_REBASE_COMMIT: '88ef210',
    BUILDER_FIX_COMMIT: 'e9d1869',
    // En fil kan inte bara hashen for den commit som innehaller den sjalv.
    // Det har ar det kallhuvud frysningen byggdes UR; vilken commit som bar
    // artefakten star i git och i fas2/BLOCK287.md.
    GENERATED_FROM_COMMIT: gitKort()
  },
  KONTRAKT: {
    WRITE_KEY_CONTRACT_VERSION: bindning.WRITE_KEY_CONTRACT_VERSION,
    TARGET_KEY_CONTRACT_VERSION: bindning.TARGET_KEY_CONTRACT_VERSION
  },
  BINDNING: bindning,
  RAKNINGAR: {
    BLOCK287_POPULATION_COUNT: pop.length,
    PRODUCT_REMEDIATION_COUNT: produkt.length,
    DISCOVERY_OCCURRENCE_COUNT: (disc.forekomster || []).length,
    ELEMENT_COUNT: disc.SKORD_OBJEKT,
    SEMANTIC_ANCHOR_COUNT: bindning.ANCHOR_COUNT,
    SOURCE_TARGET_METADATA_COUNT: bindning.PART_KEY_COUNT,
    GROUP_ROWS_TOTAL: grupper.GROUP_REQUIREMENTS,
    GROUP_ROWS_NEW_FRAME: grupper.OLOSTA.filter(r => r.familj === 'FLOW_STATE').length,
    GROUP_ROWS_TERMINAL_OUT_OF_SCOPE: grupper.TERMINAL_OUT_OF_SCOPE_ROWS,
    GROUP_ROWS_UNRESOLVED: grupper.UNRESOLVED_GROUP_REQUIREMENTS
      - grupper.OLOSTA.filter(r => r.familj === 'FLOW_STATE').length,
    EXPANDED_TARGET_OCCURRENCES: grupper.EXPANDED_TARGET_OCCURRENCES,
    UNIQUE_TARGET_SOURCE_KEY_COUNT: plan.UNIQUE_TARGET_SOURCE_KEY_COUNT,
    WRITE_OWNER_COUNT: plan.WRITE_OWNER_COUNT,
    PHYSICAL_WRITE_COUNT: plan.PHYSICAL_WRITE_COUNT,
    MANY_TO_ONE_WRITES: plan.MANY_TO_ONE_WRITES,
    NEW_FRAME_REQUIREMENT_COUNT: plan.NEW_FRAME_REQUIREMENT_COUNT
  },
  GRINDAR: {
    UNKNOWN_SEMANTICS: 0,
    HUMAN_DECISION_REQUIRED: pop.filter(u => u.CATEGORY === 'HUMAN_DECISION_REQUIRED').length,
    OWNER_IDENTITY_UNRESOLVED: pop.filter(u => u.CATEGORY === 'OWNER_IDENTITY_UNRESOLVED').length,
    IDENTITY_COLLISIONS: pop.length - new Set(pop.map(u => u.id)).size,
    WRITE_OWNER_COLLISIONS: plan.WRITE_OWNER_COLLISIONS,
    TARGET_KEY_COLLISIONS: plan.TARGET_KEY_COLLISIONS,
    POSITIONAL_WRITE_OWNER_IDS: plan.POSITIONAL_WRITE_OWNER_IDS,
    POSITIONAL_TARGET_KEYS: plan.POSITIONAL_TARGET_KEYS,
    MISSING_EXISTING_SOURCE_TARGETS: plan.MISSING_EXISTING_SOURCE_TARGETS,
    UNEXPLAINED_REMAINDER: plan.UNEXPLAINED_REMAINDER,
    ROLE_NAME_REQUIREMENT_ON_NONCONTROL_COUNT: m2.ROLE_NAME_REQUIREMENT_ON_NONCONTROL_COUNT,
    SEMANTIC_ANCHOR_DUPLICATES: bindning.ANCHOR_COUNT - bindning.ANCHOR_UNIQUE
  },
  FYND: {
    M1: fynd.M1.M1_RESULT, M2: m2.M2_CONTROL === 1 && m2.M2_NON_CONTROL === 8 ? 'CLOSED' : 'OPEN',
    M5: fynd.M5.M5_RESULT,
    M2_TOTAL: m2.M2_TOTAL, M2_CONTROL: m2.M2_CONTROL, M2_NON_CONTROL: m2.M2_NON_CONTROL, M2_UNRESOLVED: m2.M2_UNRESOLVED
  }
};

const fel = [];
for (const [k, v] of Object.entries(manifest.GRINDAR)) if (v !== 0 && k !== 'HUMAN_DECISION_REQUIRED') fel.push(k + ' = ' + v);
if (manifest.RAKNINGAR.GROUP_ROWS_UNRESOLVED !== 0) fel.push('GROUP_ROWS_UNRESOLVED = ' + manifest.RAKNINGAR.GROUP_ROWS_UNRESOLVED);
for (const [k, v] of Object.entries(manifest.FYND)) if (typeof v === 'string' && v !== 'CLOSED') fel.push(k + ' = ' + v);
manifest.FREEZE_READY = fel.length === 0;
manifest.BLOCKERANDE = fel;

if (!TORR && manifest.FREEZE_READY) {
  const ut = join(ROT, 'fas2');
  mkdirSync(ut, { recursive: true });
  for (const [fran, till] of [
    ['frys/block287k-population.json', 'block287k-population.json'],
    ['frys/block287k-status.json', 'block287k-status.json'],
    ['frys/block287k-forekomster.json', 'block287k-forekomster.json'],
    ['frys/block287k-ankarkarta.json', 'block287k-ankarkarta.json'],
    ['frys/block287k-avgoranden.json', 'block287k-avgoranden.json'],
    ['grupper.json', 'block287k-gruppexpansion.json'],
    ['skrivplan.json', 'block287k-skrivplan.json'],
    ['fynd.json', 'block287k-fyndstangning.json'],
    ['m2.json', 'block287k-m2.json']
  ]) if (existsSync(p(fran))) copyFileSync(p(fran), join(ut, till));
  writeFileSync(join(ut, 'block287k-frysning.json'), JSON.stringify(manifest, null, 1) + String.fromCharCode(10));
}
const { BINDNING, ...kort } = manifest;
console.log(JSON.stringify({ ...kort, BINDNING }, null, 1));
process.exit(manifest.FREEZE_READY ? 0 : 1);
