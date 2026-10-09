// Kor: node tools/block287/gruppexpansionsprov.mjs --root=<kallrot> --bygge=<byggkatalog>
//
// GE-01..GE-04 · gruppexpansionen maste falla stangt pa obligatorisk indata.
// Felet var att den tyst hoppade over den kanoniska agarharledningen nar
// skorden saknades: farre rader loste sig, och ett samre resultat sag ut som
// ett resultat.
import { writeFileSync, readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root'), BYGGE = arg('bygge');
const VERKTYG = join(dirname(fileURLToPath(import.meta.url)), 'gruppexpansion.mjs');
const tmp = mkdtempSync(join(tmpdir(), 'ge-'));
const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });

const b = f => join(BYGGE, f);
function kor(extra) {
  const utfil = join(tmp, 'ut-' + res.length + '.json');
  const argv = [VERKTYG, '--root=' + ROT, '--index=' + b('bl01/idx-full.json'),
    '--population=' + b('frys/block287k-population.json'), '--snapshot=' + b('snap.json'),
    '--overlay=' + b('overlay.json'), '--bygge=' + b('ut.json'), '--mork=' + b('mork.json'),
    '--tokens=' + join(ROT, 'tokens.json'), '--ut=' + utfil, ...extra];
  try { execFileSync(process.execPath, argv, { encoding: 'utf8', maxBuffer: 1 << 26 }); return { kod: 0, utfil }; }
  catch (e) { return { kod: e.status === undefined ? -1 : e.status, utfil, fel: String(e.stderr || '') }; }
}

{ const r = kor(['--skord=' + b('skord.json')]);
  let j = {}; if (r.kod === 0 && existsSync(r.utfil)) { try { j = JSON.parse(readFileSync(r.utfil, 'utf8')); } catch {} }
  prov('GE-01', 'kanoniskt anrop med skord => gar igenom',
    r.kod === 0 && j.GROUP_REQUIREMENTS > 0 && j.UNRESOLVED_GROUP_REQUIREMENTS === 30,
    'kod=' + r.kod + ' krav=' + (j.GROUP_REQUIREMENTS || 0) + ' olosta=' + j.UNRESOLVED_GROUP_REQUIREMENTS); }

{ const r = kor([]);
  prov('GE-02', 'skorden saknas => faller stangt, inget kanoniskt utfall',
    r.kod !== 0 && /FAIL CLOSED/.test(r.fel || ''), 'kod=' + r.kod + ' ' + String(r.fel || '').split('\n')[0]); }

{ const r = kor(['--skord=' + join(tmp, 'finns-inte.json')]);
  prov('GE-03', 'skorden pekar pa en fil som inte finns => faller stangt',
    r.kod !== 0 && /FAIL CLOSED/.test(r.fel || ''), 'kod=' + r.kod + ' ' + String(r.fel || '').split('\n')[0]); }

{ const trasig = join(tmp, 'trasig-skord.json');
  writeFileSync(trasig, JSON.stringify({ inte: 'en lista' }));
  const r = kor(['--skord=' + trasig]);
  prov('GE-04', 'skorden har fel form => faller stangt',
    r.kod !== 0 && /FAIL CLOSED/.test(r.fel || ''), 'kod=' + r.kod + ' ' + String(r.fel || '').split('\n')[0]); }

rmSync(tmp, { recursive: true, force: true });
for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + '  -> ' + r.diag);
console.log('\nGE ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
