// Kor: node tools/block289/visuellprov.mjs --root=<kallrot>
//
// VF-01..VF-09 · det aktiva provet for Block 289:s visuella leveransfrysning.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { bygg, kvot } from './visuellfrysning.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root') || '.';
const las = f => readFileSync(join(ROT, f), 'utf8');
const j = f => JSON.parse(las(f));

const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });

const m = bygg(ROT);
const b = m.BINDNING;
const map = j('tools/app-theme-map.json');

/* VF-01 · textLight ar sekundartext, inte avstangd text */
{
  const kalla = (map.colors.textLight || [])[1];
  prov('VF-01', 'textLight pekar pa en sekundartextroll, aldrig pa text.disabled',
    /^text\.secondary/.test(String(kalla)), 'kalla=' + kalla);
}

/* VF-02 · varje ytblind Flutter-konstant klarar 4,5 pa alla tillatna ytor */
{
  const fel = m.YTBLINDA_KONSTANTER.filter(x => !x.PASS);
  prov('VF-02', 'varje ytblind textkonstant klarar 4,5:1 pa bade base och raised',
    fel.length === 0, fel.map(x => x.NAMN + '=' + x.MIN_KVOT.toFixed(6)).join(', '));
}

/* VF-03 · varje token klarar sitt eget golv pa sin egen tillatna yta */
{
  const fel = m.KONTRASTKONTRAKT.filter(r => !r.PASS);
  prov('VF-03', 'varje texttoken klarar sitt eget golv pa sin egen yta',
    fel.length === 0, fel.map(r => r.TOKEN + '/' + r.LAGE + '=' + r.KVOT.toFixed(6)).join(', '));
}

/* VF-04 · avstangd text ar kvar som ett eget token */
{
  const t = j('tokens.json').semantic;
  const skilt = t['text.disabled'] && t['text.secondary']
    && t['text.disabled'].light !== t['text.secondary'].light;
  prov('VF-04', 'avstangd text ar fortfarande ett eget semantiskt token',
    skilt, 'disabled=' + (t['text.disabled'] || {}).light + ' secondary=' + (t['text.secondary'] || {}).light);
}

/* VF-05 · generatorn skriver const, sa appens analysatorgrind haller */
prov('VF-05', 'varje genererad textstil ar const', b.GENERATED_NONCONST_TEXTSTYLES === 0,
  'utan const=' + b.GENERATED_NONCONST_TEXTSTYLES + ' med const=' + b.GENERATED_CONST_TEXTSTYLES);

/* VF-06 · leveranskontraktets yta ar oforandrad */
{
  const k = j('legacy-api-contract.json');
  prov('VF-06', 'leveranskontraktets publika yta ar oforandrad',
    b.APP_COLORS_MEMBERS === k.appColors.members.length && b.APP_TEXT_STYLE_GETTERS === k.appTextStyles.getters.length,
    b.APP_COLORS_MEMBERS + ' farger, ' + b.APP_TEXT_STYLE_GETTERS + ' stilar');
}

/* VF-07 · kravfrysningen raknas inte om har */
{
  const krav = j('fas2/block287k-frysning.json');
  prov('VF-07', 'Block 287:s kravfrysning ar oberord och fortfarande FROZEN',
    krav.STATUS === 'FROZEN' && m.PROVENIENS.REQUIREMENT_FREEZE === 'fas2/block287k-frysning.json'
    && !('POPULATION_COUNT' in b), 'krav STATUS=' + krav.STATUS);
}

/* VF-08 · UX-frysningen ar oberord */
{
  const ux = j('fas2/block288-uxfrysning.json');
  prov('VF-08', 'Block 288:s UX-frysning ar oberord och fortfarande FROZEN',
    ux.STATUS === 'FROZEN' && ux.BINDNING.DESIGN_DECISION_REQUIRED === 0,
    'ux STATUS=' + ux.STATUS);
}

/* VF-09 · tva ombyggnader ger samma bindning */
{
  const igen = bygg(ROT);
  prov('VF-09', 'tva ombyggnader ger samma bindning',
    JSON.stringify(igen.BINDNING) === JSON.stringify(b), 'avtryck=' + igen.BINDNING.DELIVERY_FINGERPRINT);
}

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id.padEnd(8) + r.vad + (r.ok ? '' : '  -> ' + r.diag));
console.log('\nVF ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
