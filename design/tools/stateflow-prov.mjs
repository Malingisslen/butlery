#!/usr/bin/env node
// BUTLERY · BLOCK 282 · METODPROV för state/flow-populationen.  SF-01 … SF-09
//
// Provar att populationen är reproducerbar och att identiteten är stabil.
// Arbetar UTESLUTANDE på en kopia utanför reporoten — produkten rörs aldrig.
//
// Kör: node tools/stateflow-prov.mjs --out=<katalog utanför reporoten>
//
// SF-01  två bygg från samma källa ger byteidentisk utdata
// SF-02  källans förväntade värden stämmer med det byggda
// SF-03  omkastad filordning ändrar ingenting
// SF-04  omkastad syskonordning ändrar ingenting
// SF-05  ett relevant tillstånd TILLAGT flyttar exakt en kravrad
// SF-06  ett relevant tillstånd BORTTAGET flyttar exakt en kravrad
// SF-07  ändrad representation lämnar kravidentiteten orörd
// SF-08  ett omnumrerat regel-id faller stängt
// SF-09  ett beslut på en regel maskinen kallar DIREKT faller stängt

import { readFileSync, writeFileSync, cpSync, rmSync, existsSync, mkdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, resolve } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanför reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out måste ligga utanför reporoten'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });

const BYGGARE = resolve('tools/stateflow-population.mjs');
const KALLA = 'fas2/stateflow-mappning.json';
const K = JSON.parse(readFileSync(KALLA, 'utf8'));
const SKARMFILER = readFileSync('tools/screen-files.mjs', 'utf8')
  .split('export const SCREEN_FILES')[1].split('];')[0]
  .split('\n').map(l => (/'([^']+\.dc\.html)'/.exec(l) || [])[1]).filter(Boolean);
const BEROENDE = [...SKARMFILER, 'tools/screen-files.mjs', 'tools/lint-core.mjs',
  'testmatris.md', 'flows-roles-budget.md', 'fas2/nt-baslinje.json', KALLA];

const resultat = [];
const prov = (id, vad, ok, detalj) => {
  resultat.push({ id, vad, godkand: !!ok, detalj });
  console.log((ok ? '✔' : '✖') + ' ' + id + '  ' + vad + (detalj ? '\n     ' + detalj : ''));
};
function kor(root) {
  return JSON.parse(execFileSync(process.execPath, [BYGGARE, '--root=' + root],
    { encoding: 'utf8', maxBuffer: 1 << 26 }));
}
function korRatt(root) {
  try { execFileSync(process.execPath, [BYGGARE, '--root=' + root],
    { encoding: 'utf8', stdio: 'pipe', maxBuffer: 1 << 26 }); return null; }
  catch (e) { return String(e.stderr || e.message); }
}
function kopia(namn) {
  const d = join(outAbs, 'work-' + namn);
  if (existsSync(d)) rmSync(d, { recursive: true, force: true });
  for (const f of BEROENDE) {
    const mal = join(d, f);
    mkdirSync(join(mal, '..'), { recursive: true });
    cpSync(f, mal);
  }
  return d;
}

const PRISTINE = kopia('pristine');
const BAS = kor(PRISTINE);
const B = BAS.MAPPNINGSREVISION;

/* SF-01 */
{
  const a = execFileSync(process.execPath, [BYGGARE, '--root=' + PRISTINE], { encoding: 'utf8', maxBuffer: 1 << 26 });
  const b = execFileSync(process.execPath, [BYGGARE, '--root=' + PRISTINE], { encoding: 'utf8', maxBuffer: 1 << 26 });
  prov('SF-01', 'två bygg ger byteidentisk utdata', a === b, a.length + ' tecken');
}

/* SF-02 */
{
  const f = K.forvantat, fel = [];
  for (const [k, v] of Object.entries(f)) {
    const har = k in B ? B[k] : BAS[k];
    if (JSON.stringify(har) !== JSON.stringify(v)) fel.push(k + ': ' + JSON.stringify(har) + ' ≠ ' + JSON.stringify(v));
  }
  prov('SF-02', 'källans förväntade värden stämmer', fel.length === 0,
    fel.length ? fel.join(' · ') : Object.keys(f).length + ' värden prövade');
}

/* SF-03 */
{
  const d = kopia('sf03');
  const p = join(d, 'tools/screen-files.mjs');
  let t = readFileSync(p, 'utf8');
  const block = t.split('export const SCREEN_FILES')[1].split('];')[0];
  const rader = block.split('\n').filter(l => /\.dc\.html'/.test(l));
  const omkast = rader.slice().reverse().map((l, i, a) =>
    i === a.length - 1 ? l.replace(/,\s*$/, '') : (l.trim().endsWith(',') ? l : l + ','));
  writeFileSync(p, t.replace(block, '\n' + omkast.join('\n') + '\n'));
  const r = kor(d);
  prov('SF-03', 'omkastad filordning ändrar ingenting',
    r.POPULATION_FINGERPRINT === BAS.POPULATION_FINGERPRINT &&
    r.MAPPNINGSREVISION.MAPPING_FINGERPRINT === B.MAPPING_FINGERPRINT,
    'fp ' + r.POPULATION_FINGERPRINT);
}

/* SF-04 */
{
  const d = kopia('sf04');
  const f = join(d, SKARMFILER[0]);
  let t = readFileSync(f, 'utf8');
  const idx = [...t.matchAll(/<div class="sc-item" id="([^"]+)"/g)];
  const a0 = idx[0].index, a1 = idx[1].index, a2 = idx[2].index;
  writeFileSync(f, t.slice(0, a0) + t.slice(a1, a2) + t.slice(a0, a1) + t.slice(a2));
  const r = kor(d);
  prov('SF-04', 'omkastad syskonordning ändrar ingenting',
    r.POPULATION_FINGERPRINT === BAS.POPULATION_FINGERPRINT, 'fp ' + r.POPULATION_FINGERPRINT);
}

/* SF-05 */
{
  const d = kopia('sf05');
  let gjord = false;
  for (const fil of SKARMFILER) {
    const p = join(d, fil), t = readFileSync(p, 'utf8');
    const m = /<([a-z]+)([^>]*data-a11y-role="textbox"[^>]*)>/.exec(t);
    if (!m) continue;
    writeFileSync(p, t.replace(m[0], '<' + m[1] + m[2] + ' data-a11y-state="pressed">'));
    gjord = true; break;
  }
  const r = kor(d);
  const dr = r.COMPONENT_STATE_REQUIREMENTS.REQUIRED - BAS.COMPONENT_STATE_REQUIREMENTS.REQUIRED;
  const du = r.COMPONENT_STATE_REQUIREMENTS.UNKNOWN - BAS.COMPONENT_STATE_REQUIREMENTS.UNKNOWN;
  prov('SF-05', 'relevant tillstånd tillagt flyttar exakt en rad',
    gjord && dr === 1 && du === -1 && r.IDENTITY_FINGERPRINT === BAS.IDENTITY_FINGERPRINT,
    'REQUIRED ' + dr + ' · UNKNOWN ' + du + ' · identitet ' +
    (r.IDENTITY_FINGERPRINT === BAS.IDENTITY_FINGERPRINT ? 'stabil' : 'DREV'));
}

/* SF-06 */
{
  const d = kopia('sf06');
  let traff = 0;
  for (const fil of SKARMFILER) {
    const p = join(d, fil), t = readFileSync(p, 'utf8');
    const ut = t.replace(/(<[a-z]+[^>]*data-a11y-role="button"[^>]*?)\s*data-a11y-state="collapsed"/g,
      (_, pre) => { traff++; return pre; });
    if (ut !== t) writeFileSync(p, ut);
  }
  const r = kor(d);
  const dr = r.COMPONENT_STATE_REQUIREMENTS.REQUIRED - BAS.COMPONENT_STATE_REQUIREMENTS.REQUIRED;
  const du = r.COMPONENT_STATE_REQUIREMENTS.UNKNOWN - BAS.COMPONENT_STATE_REQUIREMENTS.UNKNOWN;
  prov('SF-06', 'relevant tillstånd borttaget flyttar exakt en rad',
    traff > 0 && dr === -1 && du === 1 && r.IDENTITY_FINGERPRINT === BAS.IDENTITY_FINGERPRINT,
    traff + ' förekomster · REQUIRED ' + dr + ' · UNKNOWN +' + du);
}

/* SF-07 */
{
  const d = kopia('sf07');
  const f = join(d, SKARMFILER.find(x => readFileSync(x, 'utf8').includes('id="hemladdar"')));
  let t = readFileSync(f, 'utf8');
  const i = t.indexOf('id="hemladdar"');
  const j = t.indexOf('class="sc-item"', i + 10);
  const slut = j < 0 ? t.length : j;
  const blk = t.slice(i, slut);
  const ny = blk.replace('data-screen-label="Hem · laddar"', 'data-screen-label="Hem · variant"')
    .replace(/sc-skeleton/g, 'sc-platta').replace(/sc-loader/g, 'sc-platta');
  writeFileSync(f, t.slice(0, i) + ny + t.slice(slut));
  const r = kor(d);
  prov('SF-07', 'ändrad representation lämnar kravidentiteten orörd',
    r.IDENTITY_FINGERPRINT === BAS.IDENTITY_FINGERPRINT &&
    r.POPULATION_FINGERPRINT !== BAS.POPULATION_FINGERPRINT &&
    r.FLOW_REPRESENTATION.PRESENT === BAS.FLOW_REPRESENTATION.PRESENT - 1,
    'PRESENT ' + BAS.FLOW_REPRESENTATION.PRESENT + ' -> ' + r.FLOW_REPRESENTATION.PRESENT +
    ' · identitet ' + (r.IDENTITY_FINGERPRINT === BAS.IDENTITY_FINGERPRINT ? 'stabil' : 'DREV'));
}

/* SF-08 · omnumrering ska falla stängt */
{
  const d = kopia('sf08');
  const p = join(d, KALLA);
  const k = JSON.parse(readFileSync(p, 'utf8'));
  k.regler.splice(3, 1);                       // ta bort en regel -> alla efter den omnumreras
  writeFileSync(p, JSON.stringify(k, null, 1));
  const fel = korRatt(d);
  prov('SF-08', 'omnumrerad källa faller stängt', !!fel && /omnumrerats/.test(fel),
    fel ? fel.split('\n').find(l => /FAIL CLOSED/.test(l)) : 'byggde utan att klaga');
}

/* SF-09 · beslut på en DIREKT-regel ska falla stängt */
{
  const d = kopia('sf09');
  const p = join(d, KALLA);
  const k = JSON.parse(readFileSync(p, 'utf8'));
  k.regler[0].beslut = 'HUMAN_APPROVED';       // MAP::001 är maskinellt DIREKT
  writeFileSync(p, JSON.stringify(k, null, 1));
  const fel = korRatt(d);
  prov('SF-09', 'beslut på en maskinellt DIREKT regel faller stängt',
    !!fel && /behöver inget beslut/.test(fel),
    fel ? fel.split('\n').find(l => /FAIL CLOSED/.test(l)) : 'byggde utan att klaga');
}

const godkanda = resultat.filter(r => r.godkand).length;
writeFileSync(join(outAbs, 'stateflow-prov.json'),
  JSON.stringify({ $schema: 'butlery-stateflow-prov/1', godkanda, av: resultat.length, resultat }, null, 1) + '\n');
console.log('\nSTATEFLOW-PROV status=' + (godkanda === resultat.length ? 'godkänd' : 'UNDERKÄND') +
  ' godkända=' + godkanda + ' av ' + resultat.length);
process.exit(godkanda === resultat.length ? 0 : 1);
