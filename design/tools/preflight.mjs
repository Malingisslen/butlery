#!/usr/bin/env node
// Butlery · PREFLIGHT — körs FÖRE generatorerna. Kör: node tools/preflight.mjs
//
// Rollfördelning (Fas 0.9):
//   preflight (GEN-02) · är de INCHECKADE genererade filerna aktuella?
//   T-15               · stämmer den GENERERADE outputens header med indexet?
//   GEN-01             · ändrade körningen någon incheckad fil?
// T-15 kunde inte se 1.3/1.4-headerarna eftersom den körs efter generatorerna —
// då är de redan omskrivna. Den driften hör hit.
//
// TRE MÄTNINGAR per fil (Fas 1, tredje vändan). Tidigare räckte det att headern
// bar rätt tokenversion och rätt källfingeravtryck — och båda kan vara HELT
// korrekta medan filens kropp kommer ur en äldre körning. Två levererade filer
// var stale på precis det sättet och GEN-02 stod grön. Nu krävs:
//   1 rätt tokenversion i headern,
//   2 rätt GENERATOR i headern enligt det kanoniska registret, och ett
//     källfingeravtryck som stämmer med indata + generatorns egen källa,
//   3 att generatorn själv, i rent --check-läge, byte-jämför filen med sitt
//     aktuella resultat. Ingen skrivning sker.
import { readFileSync, existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { GENERATED_REGISTER } from './gen-targets.mjs';
import { inputFingerprint, SHARED_SOURCES } from './gen-header.mjs';

const tokens = JSON.parse(readFileSync('tokens.json', 'utf8'));
const want = tokens.version;
const FILES = Object.keys(GENERATED_REGISTER);
let fail = 0, checked = 0, driftFp = 0, driftBody = 0;

for (const f of FILES) {
  const reg = GENERATED_REGISTER[f];
  if (!existsSync(f)) { console.error('✖ GEN-02  ' + f + ' finns inte'); fail++; continue; }
  const head = readFileSync(f, 'utf8').split('\n').slice(0, 12).join('\n');
  checked++;
  const got = (head.match(/^[^\n]*\btokens\s+v?(\d+\.\d+(?:\.\d+)?)/im) || [])[1] || null;
  if (!got) { console.error('✖ GEN-02  ' + f + ': headern saknar en läsbar "tokens <version>"-rad'); fail++; continue; }
  if (got !== want) { console.error('✖ GEN-02  ' + f + ' är genererad ur tokens ' + got + ' men tokens.json är ' + want + ' — den incheckade filen är stale'); fail++; continue; }

  const declared = (head.match(/källfingeravtryck sha256:([0-9a-f]{64})/) || [])[1] || null;
  const generator = (head.match(/^[^\n]*\bgenerator\s+(\S+)\s+v[\d.]+/im) || [])[1] || null;
  if (!declared || !generator) { console.error('✖ GEN-02  ' + f + ': headern saknar källfingeravtryck eller generatorrad'); fail++; continue; }
  // RÄTT generator, enligt registret — inte vilken generator filen råkar påstå.
  if (generator !== reg.generator) {
    console.error('✖ GEN-02  ' + f + ': headern säger generator ' + generator + ' men registret säger ' + reg.generator);
    fail++; continue;
  }
  const now = inputFingerprint([...reg.inputs, generator, ...SHARED_SOURCES].filter((x, i, a) => a.indexOf(x) === i));
  if (now.sha256 !== declared) {
    console.error('✖ GEN-02  ' + f + ': källfingeravtrycket är ' + declared.slice(0, 12) + '… men indata ger nu ' + now.sha256.slice(0, 12) +
      '… (' + now.files + ' filer: ' + reg.inputs.join(', ') + ', ' + generator + ', ' + SHARED_SOURCES.join(', ') + ') — den incheckade filen är stale');
    fail++; driftFp++; continue;
  }
  console.log('✔ GEN-02  ' + f + ' · tokens ' + got + ' · generator ' + generator + ' · fingeravtryck ' + declared.slice(0, 12) + '… oförändrat');
}

// KROPPEN mot generatorn. En körning per generator, i rent läge.
const generators = [...new Set(FILES.map(f => GENERATED_REGISTER[f].generator))].sort();
for (const g of generators) {
  if (!existsSync(g)) { console.error('✖ GEN-02  generatorn ' + g + ' finns inte'); fail++; continue; }
  const p = spawnSync(process.execPath, [g, '--check'], { encoding: 'utf8' });
  const out = ((p.stdout || '') + (p.stderr || '')).trimEnd();
  if (p.status === 0) {
    console.log('✔ GEN-02  ' + g + ' --check · kroppen är byteidentisk med generatorns resultat');
    continue;
  }
  for (const l of out.split('\n')) if (l.trim()) console.error('  ' + l.replace(/^✖\s*/, '· '));
  console.error('✖ GEN-02  ' + g + ' --check gav exit ' + p.status + ' — den incheckade kroppen motsvarar inte generatorns aktuella resultat, trots att headern och fingeravtrycket stämmer');
  fail++; driftBody++;
}

console.log('PREFLIGHT-SUMMARY checked=' + checked + ' stale=' + fail + ' fingerprint_drift=' + driftFp +
  ' body_drift=' + driftBody + ' generators=' + generators.length + ' tokens=' + want);
process.exit(fail ? 1 : 0);
