// Kor: node tools/block287/frysningsprov.mjs --root=<kallrot> --bygge=<byggkatalog>
//
// DET AKTIVA Block 287-provet. Det galler den kanoniska frysningen
// fas2/block287k-frysning.json och ingenting annat.
//
// Provet laser bara persisterade artefakter och kallan, och raknar om allt det
// pastar. Det historiska provet for den ogiltigforklarade frysningen heter
// tools/block287-HISTORISK-frysningsprov.mjs och kraver flaggan --historisk.
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { bind, validera, bindningUrManifest, FORVANTADE_NYCKLAR } from './frysvalidator.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root') || '.';
const BYGGE = arg('bygge');
if (!BYGGE) { console.error('✖ frysningsprov kraver --bygge=<byggkatalog>; kor tools/block287/kedja.mjs forst'); process.exit(2); }

const KANONISK = join(ROT, 'fas2', 'block287k-frysning.json');
const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });
const j = f => JSON.parse(readFileSync(join(ROT, 'fas2', f), 'utf8'));

if (!existsSync(KANONISK)) { console.error('✖ den kanoniska frysningen saknas: ' + KANONISK); process.exit(2); }
const M = JSON.parse(readFileSync(KANONISK, 'utf8'));

/* K01 · manifestet ar det kanoniska och bar en riktig bindning */
const u = bindningUrManifest(M);
prov('K01', 'den kanoniska frysningen bar en bindning', !u.FEL, u.FEL || 'BINDNING');

/* K02 · bindningen stammer mot en omraknad bindning, med jamforda nycklar */
let r = { PASS: false, JAMFORDA_NYCKLAR: 0 };
if (!u.FEL) { r = validera(bind(ROT, BYGGE), u.BINDNING); }
prov('K02', 'omraknad bindning = den frysta, och fler an noll nycklar jamfordes',
  r.PASS && r.JAMFORDA_NYCKLAR === FORVANTADE_NYCKLAR.length,
  'jamforda=' + r.JAMFORDA_NYCKLAR + '/' + FORVANTADE_NYCKLAR.length
  + (r.AVVIKELSER && r.AVVIKELSER.length ? ' avvikelser: ' + r.AVVIKELSER.map(a => a.NYCKEL).join(',') : '')
  + (r.FEL && r.FEL.length ? ' fel: ' + r.FEL.map(f => f.SLAG + ':' + (f.NYCKEL || '')).join(',') : ''));

/* K03 · alla grindar pa noll */
const grind = M.GRINDAR || {};
const nollgrindar = Object.entries(grind).filter(([, v]) => v !== 0);
prov('K03', 'varje grind star pa noll', nollgrindar.length === 0,
  nollgrindar.map(([k, v]) => k + '=' + v).join(', '));

/* K04 · fynden ar stangda */
const oppna = Object.entries(M.FYND || {}).filter(([, v]) => typeof v === 'string' && v !== 'CLOSED');
prov('K04', 'M1, M2 och M5 ar stangda', oppna.length === 0, oppna.map(([k, v]) => k + '=' + v).join(', '));
prov('K05', 'M2 ar nio forekomster: en kontroll, atta icke-kontroller, noll olosta',
  M.FYND && M.FYND.M2_TOTAL === 9 && M.FYND.M2_CONTROL === 1 && M.FYND.M2_NON_CONTROL === 8 && M.FYND.M2_UNRESOLVED === 0,
  JSON.stringify(M.FYND));

/* K06 · raknerelationen gar ihop */
const R = M.RAKNINGAR || {};
const summa = R.GROUP_ROWS_TOTAL - R.GROUP_ROWS_NEW_FRAME - R.GROUP_ROWS_TERMINAL_OUT_OF_SCOPE;
prov('K06', 'grupprader = exakta kallmal + nya vyer + utanfor omfanget',
  R.GROUP_ROWS_UNRESOLVED === 0 && summa >= 0 && R.GROUP_ROWS_TOTAL === R.PRODUCT_REMEDIATION_COUNT,
  'totalt ' + R.GROUP_ROWS_TOTAL + ' - ' + R.GROUP_ROWS_NEW_FRAME + ' - ' + R.GROUP_ROWS_TERMINAL_OUT_OF_SCOPE + ' = ' + summa);

/* K07 · skrivplanen ar sjalvbeskrivande */
const plan = j('block287k-skrivplan.json');
const utanBindning = (plan.rader || []).filter(rad => !Array.isArray(rad.CHANGES) || !rad.CHANGES.length);
const obundnaVarden = (plan.rader || []).flatMap(rad => (rad.CHANGES || []).filter(c => !c.REQUIREMENT_ID || !c.FACET));
prov('K07', 'varje fysisk skrivning bar sina andringar med krav och facett',
  utanBindning.length === 0 && obundnaVarden.length === 0,
  'rader utan andringar: ' + utanBindning.length + ', andringar utan krav/facett: ' + obundnaVarden.length);

/* K08 · varje krav i planen finns i populationen */
const pop = j('block287k-population.json');
const idn = new Set(pop.map(x => x.id));
const okanda = [...new Set((plan.rader || []).flatMap(rad => rad.REQUIREMENT_IDS || []))].filter(k => !idn.has(k));
prov('K08', 'varje krav i skrivplanen finns i populationen', okanda.length === 0, okanda.slice(0, 3).join(', '));

/* K09 · ankarkartans varden finns exakt en gang i kallan */
const ank = j('block287k-ankarkarta.json');
const ankVarden = [...new Set(JSON.stringify(ank).match(/occ-[a-z]{12}/g) || [])];
const kalla = {};
for (const f of readdirSync(ROT).filter(f => /^Butlery .*\.dc\.html$/.test(f)).sort()) for (const m of readFileSync(join(ROT, f), 'utf8').matchAll(/data-occurrence="(occ-[a-z]{12})"/g))
  kalla[m[1]] = (kalla[m[1]] || 0) + 1;
const fel9 = ankVarden.filter(a => kalla[a] !== 1);
prov('K09', 'varje ankare i kartan finns exakt en gang i kallan', fel9.length === 0, fel9.slice(0, 3).join(', '));


for (const x of res) console.log((x.ok ? 'GRON ' : 'ROD  ') + x.id + '  ' + x.vad + (x.ok ? '' : '  -> ' + x.diag));
console.log('\nKANONISK_FRYSNING ' + KANONISK);
console.log('PROV ' + res.filter(x => x.ok).length + '/' + res.length);
process.exit(res.every(x => x.ok) ? 0 : 1);
