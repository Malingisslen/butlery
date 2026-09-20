// Kor: node tools/block289/visuellfrysning.mjs --root=<kallrot> [--ut=<fil>] [--torr]
//
// Block 289 · Den visuella LEVERANSfrysningen. Block 287 fryser kraven ur
// skarmkorpusen; den har fryser vad appen faktiskt far: tokens, mappningen,
// generatorn och de genererade Flutter-filerna - plus kontrastkontraktet for
// de semantiska textrollerna.
//
// Block 287:s artefakter raknas aldrig om har. De binder skarmkorpusen, och
// korpusen ar oforandrad; att skriva om dem for en leveransrattelse vore att
// pasta att ett krav andrats nar det inte har gjort det.
//
// Verktyget ar rent: varje hash och varje kontrastkvot raknas om ur kallan.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const h = x => createHash('sha256').update(typeof x === 'string' ? x : JSON.stringify(x)).digest('hex');
const kort = x => h(x).slice(0, 16);

/* WCAG 2.x relativ luminans och kontrastkvot, full precision. */
const lin = c => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
const lum = hex => { const n = parseInt(hex.slice(1), 16); return 0.2126 * lin((n >> 16) & 255) + 0.7152 * lin((n >> 8) & 255) + 0.0722 * lin(n & 255); };
export const kvot = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };

/** Vilka ytor ett texttoken far sta pa. Tokenets eget namn avgor: ett
 *  .onRaised-token hor till surface.raised, basvarianten till surface.base. */
const YTREGEL = [
  { TOKEN: 'text.secondary', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.secondary.onRaised', YTA: 'surface.raised', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.disabled', YTA: 'surface.base', KRAV: 3.0, SLAG: 'DISABLED' },
  { TOKEN: 'text.disabled.onRaised', YTA: 'surface.raised', KRAV: 3.0, SLAG: 'DISABLED' },
  { TOKEN: 'text.body', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.primary', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' }
];

export function bygg(rot) {
  const las = f => readFileSync(join(rot, f), 'utf8');
  const j = f => JSON.parse(las(f));

  const t = j('tokens.json');
  const map = j('tools/app-theme-map.json');
  const kontrakt = j('legacy-api-contract.json');
  const s = t.semantic;

  /* ---- kontrastkontraktet per token och tillaten yta ---- */
  const kontrast = [];
  for (const r of YTREGEL) {
    for (const lage of ['light', 'dark']) {
      const fg = s[r.TOKEN] && s[r.TOKEN][lage];
      const bg = s[r.YTA] && s[r.YTA][lage];
      if (!fg || !bg) throw new Error('saknat token eller yta: ' + r.TOKEN + ' / ' + r.YTA + ' (' + lage + ')');
      const v = kvot(fg, bg);
      kontrast.push({ TOKEN: r.TOKEN, LAGE: lage, VARDE: fg, YTA: r.YTA, YTVARDE: bg, KRAV: r.KRAV, KVOT: v, PASS: v >= r.KRAV, SLAG: r.SLAG });
    }
  }

  /* ---- Flutter-konstanterna ar ytblinda och maste klara BADA ytorna ---- */
  const ytor = lage => [s['surface.base'][lage], s['surface.raised'][lage]];
  const flutterFarg = (() => {
    const ut = {};
    const src = las('lib/theme/app_colors.dart');
    for (const m of src.matchAll(/static const (?:Color )?(\w+)\s*=\s*Color\(0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})\)/g)) ut[m[1]] = '#' + m[2].toUpperCase();
    return ut;
  })();
  const YTBLINDA = ['textLight', 'textMedium'];
  const ytblind = YTBLINDA.map(namn => {
    const varde = flutterFarg[namn];
    if (!varde) throw new Error('okand Flutter-konstant: ' + namn);
    const kvoter = ytor('light').map(y => kvot(varde, y)).concat([kvot(varde, '#FFFFFF')]);
    const min = Math.min(...kvoter);
    return { NAMN: namn, VARDE: varde, KALLA: (map.colors[namn] || [])[1] || null, MIN_KVOT: min, KRAV: 4.5, PASS: min >= 4.5 };
  });

  /* ---- legacyalias som ska pensioneras ---- */
  const legacy = Object.entries(map.colors)
    .filter(([, v]) => /LEGACY_ALIAS/.test(String(v[2] || '')))
    .map(([k, v]) => ({ NAMN: k, KALLA: v[1], STATUS: 'LEGACY_ALIAS', RETIRE_IN: 'PACKAGE_7' }));

  const fel = [];
  for (const r of kontrast) if (!r.PASS) fel.push('TOKEN_KONTRAST:' + r.TOKEN + '/' + r.LAGE);
  for (const r of ytblind) if (!r.PASS) fel.push('YTBLIND_KONTRAST:' + r.NAMN);
  const typ = las('lib/theme/app_text_styles.dart');
  const utanConst = (typ.match(/=> TextStyle\(/g) || []).length;
  if (utanConst) fel.push('GENERATOR_CONST_DEFEKT:' + utanConst);
  if (Object.keys(flutterFarg).length !== new Set(Object.keys(flutterFarg)).size) fel.push('FARGKOLLISION');
  let morkPopulation = [];
  {
    const morkSrc = las('lib/theme/app_colors_dark.dart');
    const morkaNamn = [...morkSrc.matchAll(/static const Color (\w+)\s*=/g)].map(m => m[1]);
    if (morkaNamn.length !== new Set(morkaNamn).size) fel.push('MORK_DUBBLETT');
    const vantade = new Set([...kontrakt.appColorsDark.members, ...kontrakt.appColorsDark.aliases]);
    for (const n of morkaNamn) if (!vantade.has(n)) fel.push('MORK_OKONTRAKTERAD:' + n);
    morkPopulation = morkaNamn.slice().sort();
    if (/class AppColorsDark/.test(las('lib/theme/app_colors.dart'))) fel.push('LAGEN_HOPBLANDADE');
  }

  const bindning = {
    TOKENS_VERSION: t.version,
    TOKENS_HASH: h(las('tokens.json')),
    THEME_MAP_HASH: h(las('tools/app-theme-map.json')),
    GENERATOR_HASH: h(las('tools/gen-app-theme.mjs')),
    APP_COLORS_HASH: h(las('lib/theme/app_colors.dart')),
    APP_TEXT_STYLES_HASH: h(las('lib/theme/app_text_styles.dart')),
    LEGACY_API_CONTRACT_HASH: h(las('legacy-api-contract.json')),
    APP_COLORS_DARK_HASH: h(las('lib/theme/app_colors_dark.dart')),
    DARK_GENERATOR_HASH: h(las('tools/gen-app-theme-dark.mjs')),
    DARK_CANONICAL_MEMBERS: kontrakt.appColorsDark.members.length,
    DARK_ALIASES: kontrakt.appColorsDark.aliases.length,
    DARK_SEMANTIC_TOKENS: kontrakt.appColorsDark.semanticTokens.length,
    APP_COLORS_MEMBERS: kontrakt.appColors.members.length,
    APP_TEXT_STYLE_GETTERS: kontrakt.appTextStyles.getters.length,
    GENERATED_CONST_TEXTSTYLES: (typ.match(/=> const TextStyle\(/g) || []).length,
    GENERATED_NONCONST_TEXTSTYLES: utanConst,
    CONTRAST_ROWS: kontrast.length,
    CONTRAST_FAILURES: kontrast.filter(r => !r.PASS).length,
    SURFACE_BLIND_CONSTANTS: ytblind.length,
    SURFACE_BLIND_MIN_RATIO: Math.min(...ytblind.map(r => r.MIN_KVOT)),
    LEGACY_ALIASES: legacy.length,
    DARK_DELIVERY_MEMBERS_EMITTED: morkPopulation.length,
    DELIVERY_FINGERPRINT: kort([kontrast, ytblind, legacy, morkPopulation, t.version])
  };

  return {
    $om: 'Block 289 · visuell leveransfrysning. Binder tokens, mappning, generator och de genererade Flutter-filerna, plus kontrastkontraktet for textrollerna.',
    BLOCK: 289,
    STATUS: fel.length === 0 ? 'FROZEN' : 'BLOCKED',
    PROVENIENS: {
      REQUIREMENT_FREEZE: 'fas2/block287k-frysning.json',
      $krav: 'Block 287 binder skarmkorpusen och dess krav. Korpusen ar oforandrad av den har rattelsen, sa den frysningen raknas inte om och forblir giltig.',
      UX_FREEZE: 'fas2/block288-uxfrysning.json',
      $ux: 'Beteendemodellen ar oberord.'
    },
    BINDNING: bindning,
    KONTRASTKONTRAKT: kontrast,
    YTBLINDA_KONSTANTER: ytblind,
    LEGACYALIAS: legacy,
    BLOCKERANDE: fel
  };
}

const arAnropad = process.argv[1] && /visuellfrysning\.mjs$/.test(process.argv[1].replace(/\\/g, '/'));
if (arAnropad && arg('root')) {
  const ut = bygg(arg('root'));
  if (arg('ut') && !process.argv.includes('--torr')) writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + String.fromCharCode(10));
  console.log(JSON.stringify(ut, null, 1));
  process.exit(ut.BLOCKERANDE.length === 0 ? 0 : 1);
}
