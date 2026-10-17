// Applies the colour changes copied out of design/mockup-kit/designlabb.html to tokens.json.
//
// The lab swaps a colour wherever the same hex is used, so the same swap is made here: every
// quoted value in tokens.json that equals a changed colour is replaced, in the palette and in
// both modes of the semantic layer. Prose that merely mentions a hex is left alone. Nothing
// but colours is applied; the rest of an export (type, radii, parts) is reported, not written.
//
// Run from design/:
//
//   node tools/apply-lab-export.mjs <export.json>    write tokens.json
//   node tools/apply-lab-export.mjs <export.json> --dry-run
//
// Then regenerate: dart run tools/design_theme.dart (from the repo root).

import { readFileSync, writeFileSync } from 'node:fs';

const [file, ...flags] = process.argv.slice(2);
if (!file) {
  console.error('usage: node tools/apply-lab-export.mjs <export.json> [--dry-run]');
  process.exit(2);
}
const dryRun = flags.includes('--dry-run');
const lab = JSON.parse(readFileSync(file, 'utf8'));
const HEX = /^#[0-9a-f]{6}$/i;

let tokens = readFileSync('tokens.json', 'utf8');
let swaps = 0;
for (const [names, { from, to }] of Object.entries(lab.colors ?? {})) {
  if (!HEX.test(from) || !HEX.test(to)) {
    console.error(`skipped ${names}: not a #rrggbb colour`);
    continue;
  }
  const value = new RegExp(`"${from}"`, 'gi');
  let hits = 0;
  tokens = tokens.replace(value, () => { hits++; return `"${to.toUpperCase()}"`; });
  swaps += hits;
  console.log(`${names}: ${from} -> ${to.toUpperCase()} (${hits} values)`);
}
if (!dryRun) writeFileSync('tokens.json', tokens);
console.log(`${swaps} colour values ${dryRun ? 'would change' : 'changed'}`);

const notApplied = Object.keys(lab).filter(k => k !== 'colors');
if (notApplied.length) console.log(`not applied (needs a decision or a component change): ${notApplied.join(', ')}`);
