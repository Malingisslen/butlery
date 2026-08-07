#!/usr/bin/env node
// F2-E01 · Bygger effektrapporten ur den committade triagen.
//
// Kör: node tools/effect-report.mjs [--out=<fil>]
//
// Läser fas2/residual-r03-triage.json och fas2/source-root-cause-map.json och
// skriver ett adjudicerat effektlager. Legacy-lagret rörs aldrig.

import { readFileSync, writeFileSync } from 'node:fs';
import { adjudicera } from './effect-adjudication.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');

const triage = JSON.parse(readFileSync('fas2/residual-r03-triage.json', 'utf8'));
const karta = JSON.parse(readFileSync('fas2/source-root-cause-map.json', 'utf8'));
const registry = JSON.parse(readFileSync('fas2/effect-registry.json', 'utf8'));
const r = adjudicera(triage, karta, registry);

if (OUT) writeFileSync(OUT, JSON.stringify(r, null, 1));

console.log('EFFEKTRAPPORT' +
  ' detectedLegacyInstances=' + r.detectedLegacyInstances_st +
  ' adjudicatedEffects=' + r.adjudicatedEffects_st +
  ' productErrors=' + r.productErrors_st +
  ' intentionalEffects=' + r.intentionalEffects_st +
  ' undecidedEffects=' + r.undecidedEffects_st +
  ' designRuntimeDeviations=' + r.designRuntimeDeviations_st +
  ' status=' + r.failClosed.status);
for (const e of r.effects)
  console.log('  ' + e.effectId.padEnd(26) + e.adjudicationStatus.padEnd(12) +
    e.sourceRootCauseId + '  legacy=' + e.legacyInstansIds.length +
    (e.sammanslagen ? ' (sammanslagen)' : '') +
    (e.designRuntimeDeviation ? ' [runtime-avvikelse]' : ''));
for (const f of r.failClosed.fel) console.log('  ✖ ' + f);
process.exit(r.failClosed.fel.length ? 1 : 0);
