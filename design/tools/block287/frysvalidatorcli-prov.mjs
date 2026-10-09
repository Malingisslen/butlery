// Kor: node tools/block287/frysvalidatorcli-prov.mjs --root=<kallrot> --bygge=<byggkatalog>
//
// CLI-FV01..CLI-FV08 · provar den ingang en manniska eller agent faktiskt kor.
// Enhetsprov av en intern hjalpfunktion duger inte: felet var att just
// kommandoradsvagen tog emot ett manifest med bindningen ett steg ned och
// darfor jamforde noll nycklar - och svarade PASS.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root'), BYGGE = arg('bygge');
const VALIDATOR = join(dirname(fileURLToPath(import.meta.url)), 'frysvalidator.mjs');
const tmp = mkdtempSync(join(tmpdir(), 'clifv-'));
const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });

/** Kor validatorn som ett riktigt kommando och las bade utdata och slutkod. */
function kor(manifestFil) {
  try {
    const ut = execFileSync(process.execPath,
      [VALIDATOR, '--root=' + ROT, '--bygge=' + BYGGE, '--manifest=' + manifestFil],
      { encoding: 'utf8', maxBuffer: 1 << 26 });
    return { kod: 0, ...JSON.parse(ut) };
  } catch (e) {
    let j = {};
    try { j = JSON.parse(String(e.stdout || '{}')); } catch {}
    return { kod: e.status === undefined ? -1 : e.status, ...j };
  }
}
const skriv = (namn, data) => { const f = join(tmp, namn); writeFileSync(f, JSON.stringify(data, null, 1)); return f; };

const KANONISK = join(ROT, 'fas2', 'block287k-frysning.json');
const OBSOLET = join(ROT, 'fas2', 'block287-frysning.json');
const kanonisk = JSON.parse(readFileSync(KANONISK, 'utf8'));

{ const r = kor(KANONISK);
  prov('CLI-FV01', 'kanoniskt manifest => PASS med jamforda nycklar',
    r.VALIDATOR === 'PASS' && r.kod === 0 && r.JAMFORDA_NYCKLAR > 0, r.VALIDATOR + ' kod=' + r.kod + ' nycklar=' + r.JAMFORDA_NYCKLAR); }

{ const r = kor(OBSOLET);
  prov('CLI-FV02', 'den ogiltiga frysningen => FAIL',
    r.VALIDATOR === 'FAIL' && r.kod !== 0, r.VALIDATOR + ' kod=' + r.kod + ' nycklar=' + r.JAMFORDA_NYCKLAR); }

{ const f = skriv('tom-bindning.json', { ...kanonisk, BINDNING: {} });
  const r = kor(f);
  prov('CLI-FV03', 'tom BINDNING => FAIL', r.VALIDATOR === 'FAIL' && r.kod !== 0,
    r.VALIDATOR + ' nycklar=' + r.JAMFORDA_NYCKLAR); }

{ const { BINDNING, ...utan } = kanonisk;
  const r = kor(skriv('utan-bindning.json', utan));
  prov('CLI-FV04', 'BINDNING saknas helt => FAIL', r.VALIDATOR === 'FAIL' && r.kod !== 0, r.VALIDATOR); }

{ const b = { ...kanonisk.BINDNING }; delete b.WRITE_PLAN_HASH;
  const r = kor(skriv('en-nyckel-borta.json', { ...kanonisk, BINDNING: b }));
  prov('CLI-FV05', 'en kanonisk bindningsnyckel borttagen => FAIL',
    r.VALIDATOR === 'FAIL' && (r.FEL || []).some(x => x.SLAG === 'SAKNAD_NYCKEL'), JSON.stringify((r.FEL || [])[0] || {})); }

{ const b = { ...kanonisk.BINDNING, PAHITTAD_NYCKEL: 'x' };
  const r = kor(skriv('extranyckel.json', { ...kanonisk, BINDNING: b }));
  prov('CLI-FV06', 'okand extranyckel => FAIL',
    r.VALIDATOR === 'FAIL' && (r.FEL || []).some(x => x.SLAG === 'OVANTAD_NYCKEL'), JSON.stringify((r.FEL || [])[0] || {})); }

{ const r = kor(skriv('fel-form.json', { ...kanonisk, BINDNING: [1, 2, 3] }));
  prov('CLI-FV07', 'BINDNING med fel form => FAIL', r.VALIDATOR === 'FAIL' && r.kod !== 0, r.VALIDATOR); }

{ // ett manifest som bara bar orelaterade nycklar far ALDRIG passera pa noll jamforelser
  const r = kor(skriv('orelaterat.json', { NAGOT: 1, ANNAT: 'tva' }));
  prov('CLI-FV08', 'noll jamforda nycklar => FAIL, aldrig PASS',
    r.VALIDATOR === 'FAIL' && r.JAMFORDA_NYCKLAR === 0, r.VALIDATOR + ' nycklar=' + r.JAMFORDA_NYCKLAR); }

{ // driftprov: ett andrat vardemaste falla
  const b = { ...kanonisk.BINDNING, POPULATION_COUNT: kanonisk.BINDNING.POPULATION_COUNT + 1 };
  const r = kor(skriv('drift.json', { ...kanonisk, BINDNING: b }));
  prov('CLI-FV09', 'ett andrat bindningsvarde => FAIL',
    r.VALIDATOR === 'FAIL' && (r.AVVIKELSER || []).length === 1, JSON.stringify((r.AVVIKELSER || [])[0] || {})); }

rmSync(tmp, { recursive: true, force: true });
for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + '  -> ' + r.diag);
console.log('\nCLI_FV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
