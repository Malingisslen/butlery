#!/usr/bin/env node
// Butlery · reproducerbarhet för SAMTLIGA generatorutdata.
//
// F1-U11: CI:s reproducerbarhetsbevis täckte inte registret. `GENERATED_OUTPUTS`
// innehåller elva filer; Fas 1-jobbet jämförde sju och `content-baseline` bara
// fem — och det senare jobbet fick dessutom vara rött. Fyra skrivmål kunde alltså
// drifta mellan två körningar utan att någon obligatorisk kontroll märkte det.
//
// Listan härleds nu DIREKT ur tools/gen-targets.mjs. En ny generatorutdata
// hamnar automatiskt i beviset; en YAML-lista hade fortsatt att glida.
//
// Kör:
//   node tools/repro-check.mjs --snapshot=<fil>   före andra körningen
//   node tools/repro-check.mjs --compare=<fil>    efter andra körningen
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { GENERATED_OUTPUTS } from './gen-targets.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const SNAP = arg('snapshot'), CMP = arg('compare');
if (!SNAP && !CMP) {
  console.error('✖ ange --snapshot=<fil> eller --compare=<fil>');
  process.exit(2);
}

const sha = f => createHash('sha256').update(readFileSync(f)).digest('hex');

function take() {
  const out = {};
  const missing = [];
  for (const f of GENERATED_OUTPUTS) {
    if (!existsSync(f)) { missing.push(f); continue; }
    out[f] = sha(f);
  }
  return { out, missing };
}

if (SNAP) {
  const { out, missing } = take();
  if (missing.length) {
    // Ett saknat skrivmål är ett fel, inte något att hoppa över: då mäter
    // jämförelsen bara de filer som råkade finnas.
    for (const f of missing) console.error('✖ generatormålet ' + f + ' finns inte — kan inte snapshotas');
    process.exitCode = 1;
  }
  writeFileSync(SNAP, JSON.stringify(out, null, 2) + '\n');
  console.log('REPRO-SNAPSHOT files=' + Object.keys(out).length + '/' + GENERATED_OUTPUTS.length + ' missing=' + missing.length);
} else {
  if (!existsSync(CMP)) { console.error('✖ ögonblicksbilden ' + CMP + ' saknas'); process.exit(1); }
  const before = JSON.parse(readFileSync(CMP, 'utf8'));
  const { out, missing } = take();
  const problems = [];
  for (const f of missing) problems.push(f + ' finns inte efter andra körningen');
  for (const f of GENERATED_OUTPUTS) {
    if (!(f in before)) { problems.push(f + ' saknades i ögonblicksbilden'); continue; }
    if (!(f in out)) continue;                       // redan rapporterad
    if (before[f] !== out[f]) problems.push(f + ' skiljer sig mellan körning 1 och 2');
  }
  for (const p of problems) console.error('✖ ' + p);
  console.log('REPRO-SUMMARY declared=' + GENERATED_OUTPUTS.length + ' compared=' + Object.keys(out).length +
    ' identical=' + (Object.keys(out).length - problems.length) + ' problems=' + problems.length);
  if (problems.length) process.exitCode = 1;
  else console.log('✔ samtliga ' + GENERATED_OUTPUTS.length + ' generatorutdata byteidentiska över två körningar');
}
