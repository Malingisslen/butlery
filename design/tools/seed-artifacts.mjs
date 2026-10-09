#!/usr/bin/env node
// Butlery · SÅR artifacts.json med identitet och observationer.
// Kör: node tools/seed-artifacts.mjs [--dry]
//
// F2-A01 · Verktyget LÄGGER TILL saknade poster och UPPDATERAR observationer.
// Det rör ALDRIG ett beslutat fält. En post som redan bär ett mänskligt beslut
// lämnas orörd i allt utom `observed`, och en post vars beslut skulle skrivas
// över avbryter körningen.
//
// Det är skillnaden mot Fas 1:s generatorer: de renderar en fil ur en källa.
// Det här verktyget renderar ingenting — det förbereder ett underlag som en
// människa sedan fyller i.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { SCREEN_FILES } from './screen-files.mjs';
import { observeArtifacts } from './artifact-contract.mjs';

const DRY = process.argv.includes('--dry');
const P = 'artifacts.json';

// Fälten en människa äger. Verktyget skriver dem bara när posten är HELT ny,
// och då till sitt uttryckliga övergångsvärde.
const DECIDED = ['screenId', 'stateId', 'variantId', 'selectors', 'artifactKind',
  'viewportClass', 'viewportProfile', 'profileDeviation', 'authorityState',
  'classificationState', 'activationBlockers', 'supersededBy', 'classificationBasis', 'note'];

const fresh = () => ({
  screenId: null,
  stateId: null,
  variantId: null,
  selectors: {},
  artifactKind: 'unclassified',
  viewportClass: 'unclassified',
  viewportProfile: null,
  profileDeviation: null,
  // F2-A03 · Auktoritet och arbetsläge är skilda dimensioner. En ny post har
  // ingen auktoritet (`planned`) och inget avslutat beslut (`unclassified`).
  authorityState: 'planned',
  classificationState: 'unclassified',
  activationBlockers: [],
  supersededBy: null,
  classificationBasis: 'undecided',
  note: ''
});

const existing = existsSync(P) ? JSON.parse(readFileSync(P, 'utf8')) : null;
const byId = new Map((existing?.artifacts || []).map(a => [a.artifactId, a]));

const observedAll = [];
for (const f of SCREEN_FILES) {
  if (!existsSync(f)) continue;
  observedAll.push(...observeArtifacts(f, readFileSync(f, 'utf8')));
}

const problems = [];
for (const o of observedAll)
  if (!o.sourceElementId) problems.push('en sc-item i ' + o.sourceFile + ' saknar id — artefakten kan inte identifieras');
const ids = observedAll.map(o => o.artifactId);
for (const d of [...new Set(ids.filter((v, i) => ids.indexOf(v) !== i))])
  problems.push('artifactId "' + d + '" observeras flera gånger — identiteten är inte unik');
if (problems.length) {
  for (const p of problems) console.error('✖ ' + p);
  process.exit(1);
}

let added = 0, updated = 0, kept = 0;
const out = [];
for (const o of observedAll) {
  const prev = byId.get(o.artifactId);
  if (!prev) { out.push({ ...o, ...fresh() }); added++; continue; }
  // Beslutade fält bevaras EXAKT. Bara observationen skrivs om.
  const merged = { ...prev, sourceFile: o.sourceFile, sourceElementId: o.sourceElementId,
    artifactId: o.artifactId, lineageFrom: o.lineageFrom, observed: o.observed };
  for (const k of DECIDED) if (!(k in merged)) merged[k] = fresh()[k];
  if (JSON.stringify(prev.observed) !== JSON.stringify(o.observed)) updated++; else kept++;
  out.push(merged);
}

// En post i registret som inte längre observeras tas INTE bort automatiskt —
// den kan bära ett beslut någon fattat. Den rapporteras och lämnas kvar för
// kontrollen att fälla.
const observedIds = new Set(ids);
const orphans = (existing?.artifacts || []).filter(a => !observedIds.has(a.artifactId));
for (const a of orphans) out.push(a);

// Okända toppnycklar (viewportProfiles, $breakpointNote …) är BESLUT och
// bevaras. Seed-verktyget äger bara `artifacts[].observed`.
const carry = {};
for (const [k, v] of Object.entries(existing || {}))
  if (!['$schema', '$note', 'version', 'date', 'artifacts'].includes(k)) carry[k] = v;

const doc = {
  $schema: 'artifacts.schema.json',
  $note: 'BESLUTSREGISTER för artefaktklassificeringen (Fas 2, § 5.1). Fältet `observed` skrivs av tools/seed-artifacts.mjs ur skärmfilerna. Alla övriga fält är MÄNSKLIGA BESLUT och skrivs aldrig av ett verktyg. CHK-T-21 jämför registret mot observationen och redovisar registerfel, datafel och obeslutade poster som tre skilda felklasser.',
  version: existing?.version || '1.0',
  date: existing?.date || new Date().toISOString().slice(0, 10),
  ...carry,
  artifacts: out.sort((a, b) => a.artifactId.localeCompare(b.artifactId))
};

const undecided = out.filter(a => a.classificationState !== 'decided').length;
console.log('SEED-SUMMARY observed=' + observedAll.length + ' added=' + added +
  ' observation_updated=' + updated + ' unchanged=' + kept + ' orphans=' + orphans.length +
  ' undecided=' + undecided);
for (const a of orphans) console.error('◐ posten ' + a.artifactId + ' observeras inte längre — behålls, CHK-T-21 fäller den');

if (DRY) { console.log('(--dry: ingenting skrevs)'); process.exit(0); }
writeFileSync(P, JSON.stringify(doc, null, 2) + '\n');
console.log('skrivet: ' + P);
