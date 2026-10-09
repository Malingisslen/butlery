// Butlery · GEMENSAM header för genererade filer.
// Fas 1: huvudena bar tokenversion, datum och generatorns sökväg, men saknade
// generatorversion och ett reproducerbart fingeravtryck över indata. Utan det
// går det inte att avgöra VILKEN källa en fil faktiskt genererades ur.
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

export const SYSTEM_VERSION = '2.1';

// Den GEMENSAMMA headerkoden ingår alltid i fingeravtrycket. Fas 1 (andra
// vändan): fingeravtrycket täckte bara datafilerna, så generatorns egen
// implementation — och den här filen — kunde skrivas om utan att någon
// genererad fil ändrades. Beteendet var alltså inte bundet till beviset.
export const SHARED_SOURCES = ['tools/gen-header.mjs', 'tools/gen-check.mjs'];
// Bakåtkompatibelt namn.
export const SHARED_SOURCE = SHARED_SOURCES[0];

// Fingeravtryck över SAMTLIGA faktiska indata, i deterministisk ordning.
export function inputFingerprint(files) {
  const h = createHash('sha256');
  const rows = [];
  for (const f of [...files].sort()) {
    let sha = 'MISSING';
    try { sha = createHash('sha256').update(readFileSync(f)).digest('hex'); } catch {}
    rows.push(f + ':' + sha);
  }
  h.update(rows.join('\n') + '\n');
  return { sha256: h.digest('hex'), files: rows.length };
}

// comment: '//' för Dart/JS, '*' för CSS-block.
export function header({ generator, generatorVersion, tokenVersion, inputs, comment = '//', date }) {
  // Indata = datafilerna PLUS generatorns källa och den delade headerkoden.
  const all = [...inputs, generator, ...SHARED_SOURCES].filter((f, i, a) => a.indexOf(f) === i);
  const fp = inputFingerprint(all);
  const c = comment === '*' ? '  ' : comment + ' ';
  const lines = [
    'GENERERAD FIL — ändra källan, inte den här.',
    'system ' + SYSTEM_VERSION + ' · tokens ' + tokenVersion,
    'generator ' + generator + ' v' + generatorVersion,
    'källfingeravtryck sha256:' + fp.sha256 + ' (' + fp.files + ' indatafiler, generatorns källa inräknad)',
    'genererad ur källdatum ' + (date || 'okänt') + ' (tokens.date — reproducerbart, inte klockan)'
  ];
  return { lines: lines.map(l => c + l), fingerprint: fp };
}
