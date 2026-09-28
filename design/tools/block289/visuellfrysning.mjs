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
  { TOKEN: 'text.primary', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  // Statusrollerna. De var inte med forr, och det doldes att info pekade pa
  // ett pensionerat varde som gav 1,99:1 pa mork upphojd yta. En textroll som
  // inte provas ar en textroll som far vara fel.
  { TOKEN: 'text.link', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.link', YTA: 'surface.raised', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.success', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.success.onRaised', YTA: 'surface.raised', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.danger', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.danger.onRaised', YTA: 'surface.raised', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.warning', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.accent', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.accent.onRaised', YTA: 'surface.raised', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.bodyMuted', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.completed', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
  // Paket 2. Hjalteknappens text star bara pa sin egen saffransyta och byts i
  // par med den (beslut B-14): ink pa vilande, papper pa nedtryckt. Paren ar
  // tokens.json contrastPairs.
  { TOKEN: 'text.onActionPrimary', YTA: 'action.primary', KRAV: 4.5, SLAG: 'READABLE' },
  { TOKEN: 'text.onActionPrimaryPressed', YTA: 'action.primaryPressed', KRAV: 4.5, SLAG: 'READABLE' },
  // Fokusringen ar grafik, inte text: golvet ar graphicAndUi 3:1. contrastPairs
  // mater den mot papper; en ring runt ett kort star pa upphojd yta, sa den
  // provas dar ocksa.
  { TOKEN: 'focusRing', YTA: 'surface.base', KRAV: 3.0, SLAG: 'GRAPHIC' },
  { TOKEN: 'focusRing', YTA: 'surface.raised', KRAV: 3.0, SLAG: 'GRAPHIC' }
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
  // Varje Flutter-konstant som bar LASBAR TEXT ar ytblind och maste darfor
  // klara bade base och raised. info las in har efter att den visat sig
  // falla i morkt lage utan att nagot prov sag det.
  // textDisabled ar avstangd text: golvet ar systemets eget 3:1
  // (contrastPolicy.floors.disabled), inte 4,5. Den ar lika ytblind som de
  // andra och provas darfor mot samma ytor.
  const YTBLINDA = [
    { NAMN: 'textLight', KRAV: 4.5, SLAG: 'READABLE' },
    { NAMN: 'textMedium', KRAV: 4.5, SLAG: 'READABLE' },
    { NAMN: 'info', KRAV: 4.5, SLAG: 'READABLE' },
    { NAMN: 'success', KRAV: 4.5, SLAG: 'READABLE' },
    { NAMN: 'onWarningContainer', KRAV: 4.5, SLAG: 'READABLE' },
    { NAMN: 'textDisabled', KRAV: 3.0, SLAG: 'DISABLED' },
    // Paket 3. textWarning bar offlinebannerns varningsglyf och kontur och ar
    // lika ytblind som de andra textkonstanterna.
    { NAMN: 'textWarning', KRAV: 4.5, SLAG: 'READABLE' },
    // BUT-2159. textBodyMuted ar text.bodyMuted och klarar bada ytorna i
    // bada lagena (minst 6,79:1, morkt pa surface.raised), sa den ar ytblind.
    { NAMN: 'textBodyMuted', KRAV: 4.5, SLAG: 'READABLE' }
  ];
  const morkFarg = (() => {
    const ut = {};
    const src = las('lib/theme/app_colors_dark.dart');
    for (const m of src.matchAll(/static const Color (\w+)\s*=\s*Color\(0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})\)/g)) ut[m[1]] = '#' + m[2].toUpperCase();
    return ut;
  })();
  const ytblind = YTBLINDA.map(({ NAMN: namn, KRAV: krav, SLAG: slag }) => {
    const ljus = flutterFarg[namn];
    if (!ljus) throw new Error('okand Flutter-konstant: ' + namn);
    // Saknas ett morkt varde ar konstanten lagesoberoende och provas mot bada
    // lagens ytor med samma varde - det ar just sa info foll.
    const mork = morkFarg[namn] || ljus;
    const kvoter = [
      ...ytor('light').map(y => kvot(ljus, y)),
      kvot(ljus, '#FFFFFF'),
      ...ytor('dark').map(y => kvot(mork, y))
    ];
    const min = Math.min(...kvoter);
    return {
      NAMN: namn, VARDE: ljus, VARDE_MORKT: mork,
      HAR_EGET_MORKT: Boolean(morkFarg[namn]),
      KALLA: (map.colors[namn] || [])[1] || null,
      MIN_KVOT: min, KRAV: krav, SLAG: slag, PASS: min >= krav
    };
  });

  /* ---- Ytbundna Flutter-konstanter ----
   * En konstant som bara far sta pa EN yta provas mot just den ytan, i bada
   * lagena. Paket 4: textAccentOnInk ar snackbarens atgard (#E09D50,
   * Komponentark v1:747, produktbeslut PQ-09 = A). Den ar en palettfarg utan
   * morkt varde och star pa surface.ink, som ar #24382C i bada lagena. Den
   * ar inte ytblind: pa papper vore den 2,1:1, och den far darfor aldrig sta
   * dar. */
  const YTBUNDNA = [
    { NAMN: 'textAccentOnInk', YTA: 'surface.ink', KRAV: 4.5, SLAG: 'READABLE' },
    // Produktbeslut R6-01 = A. textAccent ar text.accent och bunden till
    // surface.base i bada lagena: det ljusa #A15A0A ger 4,30:1 pa
    // surface.raised (dar galler text.accent.onRaised) och ar darfor inte
    // ytblind. Hem-kortets Ikvall-rubrik star pa surface.ink och tar
    // text.accent bara i morkt lage (Skarmar v12 del 1:47, --r04slot-765
    // #dca968); i ljust lage ritar samma rad #e09d50, textAccentOnInk, eftersom
    // #A15A0A ger 2,37:1 pa ink. Den raden provas darfor bara i morkt lage.
    { NAMN: 'textAccent', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' },
    { NAMN: 'textAccent', YTA: 'surface.ink', LAGEN: ['dark'], KRAV: 4.5, SLAG: 'READABLE' },
    // BUT-2191. textDisabledOnBase ar text.disabled och bunden till
    // surface.base: golvet ar 3:1 (contrastPolicy disabled) och nas dar (3,32:1
    // ljust, 3,04:1 morkt) men inte pa surface.raised (2,98:1 ljust, 2,00:1
    // morkt), dar textDisabled (text.disabled.onRaised) galler.
    { NAMN: 'textDisabledOnBase', YTA: 'surface.base', KRAV: 3.0, SLAG: 'DISABLED' },
    // BUT-2147. textCompleted ar text.completed och bunden till surface.base:
    // det morka #93A48D ger 6,02:1 dar men 3,96:1 pa surface.raised.
    { NAMN: 'textCompleted', YTA: 'surface.base', KRAV: 4.5, SLAG: 'READABLE' }
  ];
  const ytbunden = YTBUNDNA.map(({ NAMN: namn, YTA: yta, LAGEN: lagen, KRAV: krav, SLAG: slag }) => {
    const ljus = flutterFarg[namn];
    if (!ljus) throw new Error('okand Flutter-konstant: ' + namn);
    const mork = morkFarg[namn] || ljus;
    const ytaLjus = s[yta] && s[yta].light;
    const ytaMork = s[yta] && s[yta].dark;
    if (!ytaLjus || !ytaMork) throw new Error('saknad yta: ' + yta);
    // LAGEN begransar raden till de lagen konstanten faktiskt star pa ytan i.
    // Utan LAGEN provas bada lagena, som forr.
    const provas = lage => !lagen || lagen.includes(lage);
    const kvotLjus = provas('light') ? kvot(ljus, ytaLjus) : null;
    const kvotMork = provas('dark') ? kvot(mork, ytaMork) : null;
    const min = Math.min(...[kvotLjus, kvotMork].filter(v => v !== null));
    return {
      NAMN: namn, VARDE: ljus, VARDE_MORKT: mork,
      HAR_EGET_MORKT: Boolean(morkFarg[namn]),
      KALLA: (map.colors[namn] || [])[1] || null,
      YTA: yta, YTVARDE: ytaLjus, YTVARDE_MORKT: ytaMork,
      ...(lagen ? { LAGEN: lagen } : {}),
      KVOT_LJUST: kvotLjus, KVOT_MORKT: kvotMork,
      MIN_KVOT: min, KRAV: krav, SLAG: slag, PASS: min >= krav
    };
  });

  /* ---- legacyalias som ska pensioneras ---- */
  const legacy = Object.entries(map.colors)
    .filter(([, v]) => /LEGACY_ALIAS/.test(String(v[2] || '')))
    .map(([k, v]) => ({ NAMN: k, KALLA: v[1], STATUS: 'LEGACY_ALIAS', RETIRE_IN: 'PACKAGE_7' }));

  const fel = [];
  for (const r of kontrast) if (!r.PASS) fel.push('TOKEN_KONTRAST:' + r.TOKEN + '/' + r.LAGE);
  for (const r of ytblind) if (!r.PASS) fel.push('YTBLIND_KONTRAST:' + r.NAMN);
  for (const r of ytbunden) if (!r.PASS) fel.push('YTBUNDEN_KONTRAST:' + r.NAMN + '/' + r.YTA);
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
    SURFACE_BLIND_MIN_RATIO: Math.min(...ytblind.filter(r => r.SLAG === 'READABLE').map(r => r.MIN_KVOT)),
    SURFACE_BLIND_DISABLED_MIN_RATIO: Math.min(...ytblind.filter(r => r.SLAG === 'DISABLED').map(r => r.MIN_KVOT)),
    SURFACE_BOUND_CONSTANTS: ytbunden.length,
    SURFACE_BOUND_MIN_RATIO: Math.min(...ytbunden.map(r => r.MIN_KVOT)),
    LEGACY_ALIASES: legacy.length,
    DARK_DELIVERY_MEMBERS_EMITTED: morkPopulation.length,
    DELIVERY_FINGERPRINT: kort([kontrast, ytblind, legacy, morkPopulation, t.version, ytbunden])
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
    YTBUNDNA_KONSTANTER: ytbunden,
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
