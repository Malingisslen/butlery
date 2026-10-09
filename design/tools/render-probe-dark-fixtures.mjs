#!/usr/bin/env node
// Regressionsprov for authored-dark i tools/render-probe.mjs.
// Kor: node tools/render-probe-dark-fixtures.mjs --out=<katalog utanfor repot> [--probe=<annan render-probe.mjs>]
//
// FELKLASSEN: temat sattes innan dokumentet var laddat. I korpusen byggs ramarna
// medan sidan laddar, sa APPLICERA_TEMA hittade 0 ramar och varje morkt fall foll.
// Provet bygger en minimal korpus dar ramarna uppstar forst efter en fordrojning,
// plus en ram utan morkt stod, och kor verktyget mot den.
//   RPD-01  verktyget vantar in ramarna och mater den morka ramen (ran_cases = 1)
//   RPD-02  ramen utan morkt stod redovisas som NOT_APPLICABLE, inte som fel
//   RPD-03  breddproberna redovisas som NOT_APPLICABLE i morkt, inte som fel
//   RPD-04  varje uppmatt ram ar faktiskt mork (data-theme lases tillbaka)
//   RPD-05  kallordningen: laddningsvantan ligger fore APPLICERA_TEMA
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, cpSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = arg('out'); if (!OUT) { console.error('✖ ange --out=<katalog utanfor repot>'); process.exit(2); }
const PROBE = resolve(arg('probe') || join(ROT, 'tools', 'render-probe.mjs'));
const kat = resolve(OUT, 'korpus'); mkdirSync(join(kat, 'tools'), { recursive: true });
for (const f of ['render-probe.mjs', 'authored-theme.mjs', 'render-measure.mjs']) copyFileSync(f === 'render-probe.mjs' ? PROBE : join(ROT, 'tools', f), join(kat, 'tools', f));
for (const f of readFileSync(join(ROT, 'tools', 'render-measure.mjs'), 'utf8').matchAll(/from '\.\/([a-z-]+\.mjs)'/g)) copyFileSync(join(ROT, 'tools', f[1]), join(kat, 'tools', f[1]));
copyFileSync(join(ROT, 'layout-contract.json'), join(kat, 'layout-contract.json'));
const LC = JSON.parse(readFileSync(join(ROT, 'layout-contract.json'), 'utf8'));
const profil = LC.profiles.find(p => p.mode === 'compact') || LC.profiles[0];
const FIL = 'Butlery Skarmar prov.dc.html';
// Ramarna skapas av ett skript EFTER en fordrojning — precis som i korpusen, fast deterministiskt.
writeFileSync(join(kat, FIL), `<!doctype html><html><head><meta charset="utf-8"><style>
.sc-item{--t:#24382c;--y:#f5f4ed}.sc-item[data-theme="dark"]{--t:#f5f4ed;--y:#17251d}
.sc-item{width:390px}.p{background:var(--y);color:var(--t);padding:16px;font:16px sans-serif}</style></head><body>
<script>setTimeout(() => { document.body.insertAdjacentHTML('beforeend',
 '<div class="sc-item" id="provmork" data-theme-support="light dark"><div class="p" data-conformance-scope="product"><span data-a11y-role="button" data-a11y-name="Spara" data-hit="self" style="display:inline-block;min-width:48px;min-height:48px">Spara</span></div></div>' +
 '<div class="sc-item" id="provljus"><div class="p" data-conformance-scope="product"><span>Bara ljus</span></div></div>'); }, 400);</script></body></html>`);
writeFileSync(join(kat, 'artifacts.json'), JSON.stringify({ artifacts: [
  { artifactId: 'A-provmork', sourceElementId: 'provmork', sourceFile: FIL, viewportProfile: profil.id, viewportClass: 'compact' },
  { artifactId: 'A-provljus', sourceElementId: 'provljus', sourceFile: FIL, viewportProfile: profil.id, viewportClass: 'compact' } ] }));

let logg = '', kod = 0;
try { logg = execFileSync(process.execPath, [join(kat, 'tools', 'render-probe.mjs'), '--theme=authored-dark', '--out=' + join(resolve(OUT), 'ut')], { cwd: kat, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }); }
catch (e) { kod = e.status; logg = String(e.stdout || '') + String(e.stderr || ''); }
let raw = null; try { raw = JSON.parse(readFileSync(join(resolve(OUT), 'ut', 'render-raw.json'), 'utf8')); } catch {}
const src = readFileSync(PROBE, 'utf8');
const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag).slice(0, 200) });
prov('RPD-01', 'vantar in ramarna och mater den morka ramen', raw && raw.ranCases === 1 && raw.failedCases === 0, 'exit ' + kod + ' · ' + (logg.split('\n').find(l => /RENDER-SUMMARY|VERKTYGSFEL/.test(l)) || ''));
prov('RPD-02', 'ram utan morkt stod blir NOT_APPLICABLE', raw && (raw.notApplicable || []).some(n => n.sourceElementId === 'provljus' && n.skal === 'NOT_APPLICABLE_NO_DARK_SUPPORT'), JSON.stringify(raw && raw.notApplicable));
prov('RPD-03', 'breddprober blir NOT_APPLICABLE i morkt', raw && (raw.notApplicable || []).filter(n => n.probe).length === LC.probes.length, JSON.stringify(raw && raw.notApplicable));
prov('RPD-04', 'uppmatt ram ar mork', raw && raw.results && raw.results.length === 1 && raw.results[0].artifacts.every(a => a.id === 'provmork'), JSON.stringify(raw && raw.results && raw.results.map(r => r.artifacts.map(a => a.id))));
const iVan = src.indexOf("addEventListener('load'"), iTema = src.indexOf('APPLICERA_TEMA(');
prov('RPD-05', 'laddningsvantan ligger fore APPLICERA_TEMA i kallan', iVan > 0 && iTema > 0 && iVan < iTema, 'load@' + iVan + ' tema@' + iTema);
for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  → ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
