#!/usr/bin/env node
// Butlery · SAMLAT FÖRSLAG för de artefakter som ännu är obeslutade.
// Kör: node tools/gen-artifact-proposal.mjs   ·   vaktas av GEN-01
//
// F2-A02: verktyget fattar INGA beslut. Det skriver aldrig artifacts.json.
// Det läser observationerna, föreslår en klassificering där evidensen är
// entydig, och lyfter ut varje post där den inte är det till en
// UNDANTAGSLISTA som måste bedömas för hand.
//
// En enhetsram är stark evidens för en viewport — men bara evidens. Därför är
// utdata ett förslag att godkänna, inte ett register att lita på.
import { readFileSync, existsSync } from 'node:fs';
import { emit } from './gen-check.mjs';
import { ARTIFACT_KINDS, ARTIFACT_STATES } from './artifact-contract.mjs';

const OUT = 'fas0/artefaktforslag.md';
const P = 'artifacts.json';
if (!existsSync(P)) { console.error('✖ ' + P + ' saknas'); process.exit(1); }
const R = JSON.parse(readFileSync(P, 'utf8'));

const short = f => f.replace(/^Butlery Skarmar v12 /, '').replace(/\.dc\.html$/, '');
const undecided = R.artifacts.filter(a => a.artifactKind === 'unclassified');

// Regler. Varje förslag bär sin grund; en post utan entydig grund blir undantag.
function propose(a) {
  const o = a.observed;
  if (o.deviceFrames > 1)
    return { exception: 'bär ' + o.deviceFrames + ' ramelement — flera ytor i en artefakt, måste granskas separat' };
  if (o.deviceFrames === 1 && o.hasExplicitDimensions)
    return { kind: 'viewport', viewportClass: 'phone', profile: null, basis: 'device-frame-evidence' };
  if (o.deviceFrames === 1 && !o.hasExplicitDimensions)
    return { exception: 'enhetsram utan explicita mått — ytan går inte att mäta' };
  if (!o.hasDeviceFrame && o.hasExplicitDimensions && o.controls > 0)
    return { kind: 'viewport', viewportClass: 'wide', profile: 'wide-1280', basis: 'explicit-dimensions' };
  if (!o.hasDeviceFrame && o.hasExplicitDimensions && o.controls === 0)
    return { exception: 'mått men noll kontroller — bord eller annotering, evidensen räcker inte' };
  return { exception: 'varken enhetsram eller mått' };
}

const byFile = new Map();
const exceptions = [];
for (const a of undecided) {
  const p = propose(a);
  if (p.exception) { exceptions.push({ a, why: p.exception }); continue; }
  const k = a.sourceFile;
  if (!byFile.has(k)) byFile.set(k, []);
  byFile.get(k).push({ a, p });
}

const L = [];
L.push('# Samlat förslag · artefaktklassificering');
L.push('');
L.push('**GENERERAD FIL — ett FÖRSLAG, inte ett beslut.** Skriven av `tools/propose-artifacts.mjs` ur observationerna i `artifacts.json`. Verktyget skriver aldrig registret. En rad blir ett beslut först när den förs in för hand med en `classificationBasis`.');
L.push('');
L.push('En enhetsram är stark evidens för en viewport, men aldrig ett auktoritetsbeslut. Posterna nedan är de där evidensen är **entydig**. Allt annat står i undantagslistan och måste bedömas individuellt.');
L.push('');
const total = [...byFile.values()].reduce((n, l) => n + l.length, 0);
L.push('| | Antal |');
L.push('|---|---|');
L.push('| Obeslutade i registret | ' + undecided.length + ' |');
L.push('| **Föreslagna för batchbeslut** | **' + total + '** |');
L.push('| Undantag — kräver individuell bedömning | ' + exceptions.length + ' |');
L.push('');

L.push('## Förslag per fil');
L.push('');
for (const [file, list] of [...byFile].sort((a, b) => b[1].length - a[1].length)) {
  const kinds = {};
  for (const { p } of list) kinds[p.kind + ' · ' + p.viewportClass] = (kinds[p.kind + ' · ' + p.viewportClass] || 0) + 1;
  L.push('### ' + short(file));
  L.push('');
  L.push('' + list.length + ' artefakter · ' + Object.entries(kinds).map(([k, n]) => n + ' × `' + k + '`').join(' · '));
  L.push('');
  L.push('| Element-id | Etikett | Kontroller | Föreslagen klass | Grund |');
  L.push('|---|---|---|---|---|');
  for (const { a, p } of list.sort((x, y) => x.a.sourceElementId.localeCompare(y.a.sourceElementId)))
    L.push('| `' + a.sourceElementId + '` | ' + (a.observed.label || '—').replace(/\|/g, '\\|') + ' | ' +
      a.observed.controls + ' | `' + p.kind + ' · ' + p.viewportClass + '` | `' + p.basis + '` |');
  L.push('');
}

L.push('## Undantagslista — bedöms individuellt');
L.push('');
if (!exceptions.length) L.push('_Inga undantag._');
else {
  L.push('| Fil | Element-id | Etikett | Kontroller | Varför den inte kan batchbeslutas |');
  L.push('|---|---|---|---|---|');
  for (const { a, why } of exceptions.sort((x, y) => x.a.artifactId.localeCompare(y.a.artifactId)))
    L.push('| ' + short(a.sourceFile) + ' | `' + a.sourceElementId + '` | ' +
      (a.observed.label || '—').replace(/\|/g, '\\|') + ' | ' + a.observed.controls + ' | ' + why + ' |');
}
L.push('');
L.push('## Vad ett batchbeslut betyder');
L.push('');
L.push('Att godkänna förslaget ovan är **ett dokumenterat beslut**, inte en automatisk import. Posterna får `classificationBasis: device-frame-evidence` eller `explicit-dimensions`, vilket säger exakt vad beslutet vilar på — och gör det granskningsbart i efterhand. `screenId` och `stateId` sätts inte av förslaget; de kräver egna beslut och håller posterna i `draft` tills de är satta.');
L.push('');

emit({ [OUT]: L.join('\n') }, { label: 'gen-artifact-proposal' });
console.log('PROPOSE-SUMMARY undecided=' + undecided.length + ' proposed=' + total +
  ' exceptions=' + exceptions.length + ' files=' + byFile.size + ' out=' + OUT);
for (const { a, why } of exceptions) console.log('  undantag: ' + a.sourceElementId + ' — ' + why);
