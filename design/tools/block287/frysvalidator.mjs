// Kor: node tools/block287/frysvalidator.mjs --root=<kallrot> --bygge=<byggkatalog>
//      [--manifest=<frysning.json>] [--ut=<fil>]
//
// O/P · Den starka frysvalidatorn. Den binder inte bara antal, utan varje
// mangd den pastar nagot om. Ett tal som star stilla medan en medlem byts ut
// ska falla - det var precis sa baslinjegrinden gick att passera.
//
// Validatorn ar ren: den laser artefakterna och kallan och raknar om varje
// hash. Den litar aldrig pa ett varde som nagon annan har skrivit in.
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
export const h = x => createHash('sha256').update(typeof x === 'string' ? x : JSON.stringify(x)).digest('hex');

/** Kallans ankare och delnycklar, lasta direkt ur filerna. */
export function kallbindning(rot) {
  const filer = readdirSync(rot).filter(f => /^Butlery .*\.dc\.html$/.test(f)).sort();
  const ankare = [], delar = [];
  let bytes = 0;
  for (const f of filer) {
    const s = readFileSync(join(rot, f), 'utf8');
    bytes += s.length;
    for (const m of s.matchAll(/data-occurrence="(occ-[a-z]{12})"/g)) ankare.push(f + '|' + m[1]);
    for (const m of s.matchAll(/data-part-occurrence="([^"]+)"/g)) delar.push(f + '|' + m[1]);
  }
  return {
    SOURCE_BASELINE_HASH: h(filer.map(f => f + ':' + h(readFileSync(join(rot, f), 'utf8'))).join('\n')),
    CANONICAL_SEMANTIC_ANCHOR_MAP_HASH: h(ankare.slice().sort()),
    SOURCE_TARGET_METADATA_HASH: h(delar.slice().sort()),
    ANCHOR_COUNT: ankare.length,
    ANCHOR_UNIQUE: new Set(ankare.map(x => x.split('|')[1])).size,
    PART_KEY_COUNT: delar.length,
    SOURCE_BYTES: bytes
  };
}

/** Artefaktmangderna, var och en hashad over sina medlemmar. */
export function artefaktbindning(bygge) {
  const j = f => JSON.parse(readFileSync(join(bygge, f), 'utf8'));
  const pop = j('frys/block287k-population.json');
  const disc = j('disc-A.json');
  const grupper = j('grupper.json');
  const plan = j('skrivplan.json');
  const medl = existsSync(join(bygge, 'medlemmar.json')) ? j('medlemmar.json') : null;
  return {
    POPULATION_HASH: h(pop.map(u => u.id).slice().sort()),
    STATUS_HASH: h(pop.map(u => u.id + '|' + u.CATEGORY + '|' + (u.CURRENT_STATUS || '')).slice().sort()),
    DISCOVERY_OCCURRENCE_HASH: h((disc.forekomster || []).map(f => f.id || f.OCCURRENCE_ID || JSON.stringify(f)).slice().sort()),
    GROUP_EXPANSION_HASH: h(grupper.grupper.map(g =>
      g.GROUP_REQUIREMENT_ID + '|' + g.TARGET_ELEMENTS.map(t => t.TARGET_SOURCE_KEY || '-').slice().sort().join(',')).slice().sort()),
    WRITE_PLAN_HASH: h(plan.rader.map(r => r.TARGET_SOURCE_KEY + '|' + r.WRITE_OWNER_ID + '|'
      + r.REQUIREMENT_IDS.slice().sort().join(',')).slice().sort()),
    LC_MEMBER_SET_HASH: medl ? medl.MEDLEMSMANGDER.LC_MEMBER_SET_HASH : null,
    T08_MEMBER_SET_HASH: medl ? medl.MEDLEMSMANGDER.T08_MEMBER_SET_HASH : null,
    RECONCILIATION_MEMBER_SET_HASH: medl ? medl.MEDLEMSMANGDER.RECONCILIATION_MEMBER_SET_HASH : null,
    POPULATION_COUNT: pop.length,
    DISCOVERY_OCCURRENCE_COUNT: (disc.forekomster || []).length
  };
}

export const KONTRAKT = { WRITE_KEY_CONTRACT_VERSION: 1, TARGET_KEY_CONTRACT_VERSION: 1 };

export function bind(rot, bygge) {
  return { ...kallbindning(rot), ...artefaktbindning(bygge), ...KONTRAKT };
}

/** Jamfor en bindning mot ett fryst manifest. Varje nyckel i manifestet provas. */
export function validera(bindning, manifest) {
  const avvik = [];
  for (const k of Object.keys(manifest)) {
    if (k.startsWith('$') || !(k in bindning)) continue;
    if (String(bindning[k]) !== String(manifest[k])) avvik.push({ NYCKEL: k, FRYST: manifest[k], NU: bindning[k] });
  }
  return { PASS: avvik.length === 0, AVVIKELSER: avvik };
}

const isMain = !!process.argv[1] && process.argv[1].endsWith('frysvalidator.mjs');
if (isMain) {
  const b = bind(arg('root') || '.', arg('bygge'));
  if (arg('manifest')) {
    const m = JSON.parse(readFileSync(arg('manifest'), 'utf8'));
    const r = validera(b, m);
    console.log(JSON.stringify({ VALIDATOR: r.PASS ? 'PASS' : 'FAIL', ...r }, null, 1));
    process.exit(r.PASS ? 0 : 1);
  }
  console.log(JSON.stringify(b, null, 1));
}
