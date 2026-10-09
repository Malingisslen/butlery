#!/usr/bin/env node
// Regressionsprov: contrast-baseline:s status i morkt ska folja tillampligheten.
// Kor: node tools/contrast-baseline-applicability-fixtures.mjs --out=<katalog utanfor repot> [--original=<gammal contrast-baseline.mjs>]
//
// FELKLASSEN: morkt mats korrekt bara pa ramar med data-theme-support ~ dark (64),
// men verktyget jamforde med hela produktpopulationen (319) och gav FALLD —
// ett metodstatusfel, inget kontrastfynd.
//   CBA-01  alla tillampliga morka ramar matta → godkand, EXPECTED_DARK_FRAME_COUNT = tillampliga
//   CBA-02  en tillamplig mork ram saknas → FALLD
//   CBA-03  morkt utan darkIds → FALLD (tillampligheten kan inte bevisas)
//   CBA-04  ram utan morkt stod mats som mork → FALLD
//   CBA-05  NOT_APPLICABLE redovisas explicit
//   CBA-06  textfynden ar identiska med originalverktyget
//   CBA-07  ljus baslinje: utdata byte-identisk med originalverktyget
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = arg('out'); if (!OUT) { console.error('✖ ange --out=<katalog utanfor repot>'); process.exit(2); }
mkdirSync(OUT, { recursive: true });
const NY = join(ROT, 'tools', 'contrast-baseline.mjs'), GAMMAL = arg('original') ? resolve(arg('original')) : null;

const kontroll = (namn, kvot) => ({ role: 'button', name: namn, contrastApplicability: 'applicable', contrastStatus: 'measured',
  contrast: kvot, contrastThreshold: 4.5, underThreshold: kvot < 4.5, textRuns_st: 1,
  textRuns: [{ text: namn, tag: 'span', malareArKontrollen: false, color: 'rgb(1,1,1)', bakgrund: 'rgb(2,2,2)', fontSize: 14,
    fontWeight: 400, large: false, threshold: 4.5, ratio: kvot, status: 'measured', underThreshold: kvot < 4.5 }] });
const raw = (ramar, extra = {}) => ({ colorScheme: 'authored-dark', results: [{ profile: { id: 'compact-390' }, probe: null,
  artifacts: ramar.map(id => ({ id, controls: [kontroll('Spara ' + id, id === 'b' ? 2.73 : 7.1)] })) }], ...extra });
const kor = (verktyg, namn, d) => { const f = join(OUT, namn + '.raw.json'), u = join(OUT, namn + '.' + (verktyg === NY ? 'ny' : 'gammal') + '.json');
  writeFileSync(f, JSON.stringify(d)); let kod = 0;
  try { execFileSync(process.execPath, [verktyg, '--raw=' + f, '--out=' + u], { stdio: 'ignore' }); } catch (e) { kod = e.status; }
  return { kod, r: JSON.parse(readFileSync(u, 'utf8')), text: readFileSync(u, 'utf8').replace(/"källa": "[^"]*"/, '') }; };

const res = []; const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag).slice(0, 200) });
const NA = [{ sourceElementId: 'c', skal: 'NOT_APPLICABLE_NO_DARK_SUPPORT' }];
const r1 = kor(NY, 'cba01', raw(['a', 'b'], { darkIds: ['a', 'b'], notApplicable: NA }));
prov('CBA-01', 'alla tillampliga morka ramar → godkand', r1.r.failClosed.status === 'godkänd' && (r1.r.populationer.morkt || {}).EXPECTED_DARK_FRAME_COUNT === 2, JSON.stringify(r1.r.failClosed));
const r2 = kor(NY, 'cba02', raw(['a', 'b'], { darkIds: ['a', 'b', 'x'], notApplicable: NA }));
prov('CBA-02', 'saknad tillamplig mork ram → FALLD', r2.r.failClosed.status === 'FÄLLD' && /saknas: x/.test(r2.r.failClosed.fel.join()), JSON.stringify(r2.r.failClosed));
const r3 = kor(NY, 'cba03', raw(['a', 'b']));
prov('CBA-03', 'morkt utan darkIds → FALLD', r3.r.failClosed.status === 'FÄLLD' && /darkIds/.test(r3.r.failClosed.fel.join()), JSON.stringify(r3.r.failClosed));
const r4 = kor(NY, 'cba04', raw(['a', 'b', 'c'], { darkIds: ['a', 'b'], notApplicable: NA }));
prov('CBA-04', 'ram utan morkt stod matt som mork → FALLD', r4.r.failClosed.status === 'FÄLLD' && /utan morkt stod/.test(r4.r.failClosed.fel.join()), JSON.stringify(r4.r.failClosed));
prov('CBA-05', 'NOT_APPLICABLE redovisas', (r1.r.populationer.morkt || {}).NOT_APPLICABLE_st === 1, JSON.stringify(r1.r.populationer.morkt));
if (GAMMAL) {
  const g1 = kor(GAMMAL, 'cba01', raw(['a', 'b'], { darkIds: ['a', 'b'], notApplicable: NA }));
  prov('CBA-06', 'textfynden identiska med originalet', JSON.stringify(g1.r.fynd) === JSON.stringify(r1.r.fynd) && r1.r.fynd.length === 1, r1.r.fynd.length + ' fynd');
  const ljus = { results: [{ profile: { id: 'compact-390' }, probe: null, artifacts: [{ id: 'a', controls: [kontroll('Spara', 3.2)] }] }] };
  const gl = kor(GAMMAL, 'cba07', ljus), nl = kor(NY, 'cba07', ljus);
  prov('CBA-07', 'ljus baslinje byte-identisk med originalet', gl.text === nl.text && gl.kod === nl.kod, 'kod ' + gl.kod + '/' + nl.kod);
}
for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  → ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
