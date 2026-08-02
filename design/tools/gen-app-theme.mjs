#!/usr/bin/env node
// Butlery · tokens.json (+ tools/app-theme-map.json) → lib/theme/app_colors.dart
// och lib/theme/app_text_styles.dart. Kör: node tools/gen-app-theme.mjs
//
// Etapp 8.1–8.2 i arbetsplanen. Skillnaden mot gen-flutter.mjs: den skriver ett
// NYTT tema (ButleryColors/ButleryType). Den här skriver om appens BEFINTLIGA
// två temafiler och behåller varje medlemsnamn, så att de 50 vyerna kompilerar
// oförändrade medan värdena byter källa till tokens.json.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const t = JSON.parse(readFileSync('tokens.json', 'utf8'));
const map = JSON.parse(readFileSync('tools/app-theme-map.json', 'utf8'));

const hx = n => Number(n).toString(16).padStart(2, '0').toUpperCase();
function argb(v) {
  if (v.startsWith('#')) return 'Color(0xFF' + v.slice(1).toUpperCase() + ')';
  const m = v.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)/);
  if (!m) throw new Error('Okänt färgformat: ' + v);
  const a = Math.round((m[4] === undefined ? 1 : parseFloat(m[4])) * 255);
  return 'Color(0x' + hx(a) + hx(m[1]) + hx(m[2]) + hx(m[3]) + ')';
}
const val = (kind, key, mode = 'light') =>
  kind === 'semantic' ? t.semantic[key][mode] : kind === 'palette' ? t.palette[key] : key;
const col = (kind, key, mode) => argb(val(kind, key, mode));

const ALIASES = [
  ['textSecondary', 'textMedium'], ['accent', 'rust'], ['warningText', 'onWarningContainer'],
  ['sharedRecipeTextColor', 'sharedRecipeText'], ['sharedRecipeIconColor', 'sharedRecipeIcon'],
  ['sharedRecipeBackgroundColor', 'sharedRecipeBackground'], ['chatBubbleOutgoing', 'forestGreen'],
  ['chatBubbleIncoming', 'creamDark'], ['chatTextOutgoing', 'textOnPrimary'], ['chatTextIncoming', 'textDark'],
  ['categoryMeatFish', 'illustrationPurpleRed'], ['backgroundLight', 'cream'], ['backgroundDark', 'neutralDark'],
  ['primary', 'forestGreen'], ['secondary', 'rust'], ['surface', 'cream'], ['surfaceVariant', 'creamDark'],
  ['onSurface', 'textDark'], ['primaryContainer', 'creamDark'], ['secondaryContainer', 'creamDark'],
  ['onPrimaryContainer', 'forestGreen'], ['onPrimary', 'textOnPrimary'], ['outline', 'placeholderIcon'],
  ['shadow', 'shadowColor'], ['onSuccess', 'textOnPrimary'], ['onError', 'textOnPrimary'],
  ['onWarning', 'textDark'], ['onInfo', 'textOnPrimary'], ['recipeCardLeftBorder', 'forestGreen'],
  ['recipeCardBottomBorder', 'rustLight'], ['headerBackground', 'forestGreen'], ['headerAccent', 'rust'],
  ['headerForeground', 'textOnPrimary'], ['navBackground', 'creamDarker'], ['navSelectedIndicator', 'rust'],
  ['navSelectedItem', 'forestGreenDark'], ['navUnselectedItem', 'greenMuted']
];
const BRANDS = [
  ['brandYoutube', '#FF0000'], ['brandTiktok', '#00F2EA'], ['brandInstagram', '#E1306C'],
  ['brandTwitter', '#1DA1F2'], ['brandPinterest', '#E60023'], ['brandWhatsapp', '#25D366'],
  ['brandTelegram', '#0088CC'], ['brandFacebook', '#1877F2'], ['brandReddit', '#FF4500'],
  ['brandAllrecipes', '#BD081C'], ['brandIca', '#FF6600'], ['brandCoop', '#006341'],
  ['brandArla', '#E30613'], ['brandKoketSe', '#000000'], ['brandGeneric', '#6B7280'],
  ['brandYoutubeBackground', '#FFE0E0'], ['brandTiktokBackground', '#E0F7FA'],
  ['brandInstagramBackground', '#FCE4EC'], ['brandYoutubeText', '#CC0000'],
  ['brandTiktokText', '#161823'], ['brandInstagramText', '#C13584']
];

function scheme(mode) {
  const g = k => col('semantic', k, mode);
  const p = k => argb(t.palette[k]);
  return [
    '  static const ColorScheme ' + (mode === 'light' ? 'lightColorScheme' : 'darkColorScheme') + ' = ColorScheme(',
    '    brightness: Brightness.' + mode + ',',
    '    primary: ' + g('surface.ink') + ',',
    '    onPrimary: ' + g('control.checked.foreground') + ',',
    '    primaryContainer: ' + g('surface.raised') + ',',
    '    onPrimaryContainer: ' + g('text.primary') + ',',
    '    secondary: ' + g('action.primary') + ',',
    '    onSecondary: ' + g('text.onActionPrimary') + ',',
    '    secondaryContainer: ' + g('surface.raised') + ',',
    '    onSecondaryContainer: ' + g('text.accent.onRaised') + ',',
    '    tertiary: ' + g('text.success') + ',',
    '    onTertiary: ' + g('control.checked.foreground') + ',',
    '    tertiaryContainer: ' + g('surface.raised') + ',',
    '    onTertiaryContainer: ' + g('text.success.onRaised') + ',',
    '    error: ' + g('text.danger') + ',',
    '    onError: ' + (mode === 'dark' ? p('inkDeep') : g('control.checked.foreground')) + ',',
    '    errorContainer: ' + g('surface.raised') + ',',
    '    onErrorContainer: ' + g('text.danger.onRaised') + ',',
    '    surface: ' + g('surface.base') + ',',
    '    onSurface: ' + g('text.primary') + ',',
    '    surfaceContainerHighest: ' + g('surface.raised') + ',',
    '    onSurfaceVariant: ' + g('text.secondary') + ',',
    '    outline: ' + g('border.control') + ',',
    '    outlineVariant: ' + g('border.subtle') + ',',
    '    shadow: ' + argb('rgba(23,37,29,0.10)') + ',',
    '    scrim: ' + g('scrim') + ',',
    '    inverseSurface: ' + (mode === 'dark' ? g('surface.base') : g('surface.ink')) + ',',
    '    onInverseSurface: ' + (mode === 'dark' ? g('text.primary') : g('control.checked.foreground')) + ',',
    '    inversePrimary: ' + p('greenLight') + ',',
    '    surfaceTint: ' + g('surface.ink') + ',',
    '  );'
  ];
}

function renderColors() {
  const L = [];
  L.push('// GENERERAD FIL — ändra tokens.json eller tools/app-theme-map.json, inte den här.');
  L.push('// tokens ' + t.version + ' · ' + t.date + ' · generator tools/gen-app-theme.mjs');
  L.push('//');
  L.push('// Migration (etapp 8.1): varje medlem har samma NAMN som före — appens 50 vyer');
  L.push('// kompilerar oförändrade — men VÄRDET kommer nu ur tokens.json. Färgnamn som');
  L.push('// forestGreen och cream är därför historiska: de bär ink respektive paper.');
  L.push('// Att döpa om dem är en separat, mekanisk vända (BUT-nr saknas).');
  L.push('//');
  L.push('// Undantag: brand*-färgerna nedan är externa varumärkesidentiteter och');
  L.push('// tokeniseras inte — de är citat, inte design.');
  L.push("import 'package:flutter/material.dart';");
  L.push('');
  L.push('class AppColors {');
  L.push('  AppColors._();');
  L.push('');
  for (const [name, [kind, key, note]] of Object.entries(map.colors)) {
    if (note) L.push('  /// ' + note + (kind === 'raw' ? '' : ' · ' + kind + '.' + key));
    else if (kind !== 'raw') L.push('  /// ' + kind + '.' + key);
    L.push('  static const Color ' + name + ' = ' + col(kind, key) + ';');
  }
  L.push('');
  L.push('  // Alias — oförändrade, pekar på medlemmar ovan.');
  for (const [a, b] of ALIASES) L.push('  static const Color ' + a + ' = ' + b + ';');
  L.push('  static const Color transparent = Colors.transparent;');
  L.push('');
  L.push('  /// Ljust schema — varje slot ur tokens.json, inga härledda toner.');
  L.push(...scheme('light'));
  L.push('');
  L.push('  /// Mörkt schema. **Ändring mot tidigare:** det byggdes med');
  L.push('  /// `ColorScheme.fromSeed`, som räknade fram toner systemet aldrig godkänt');
  L.push('  /// och som därför behövde tio handöverskrivningar. Nu är varje slot en');
  L.push('  /// token med ett mätt kontrastpar bakom sig, och schemat är `const`.');
  L.push(...scheme('dark'));
  L.push('');
  L.push('  // ── Externa varumärken · tokeniseras inte (se kommentaren ovan) ──');
  for (const [n, v] of BRANDS) L.push('  static const Color ' + n + ' = ' + argb(v) + ';');
  L.push('}');
  L.push('');
  return L.join('\n');
}

const ROLE_STYLES = [
  ['displaySmall', 'display.compact', {}], ['headlineMedium', 'display.compact', {}],
  ['headlineSmall', 'title', {}], ['headlineBold', 'display', {}],
  ['titleLarge', 'stepper', { height: 1.3 }], ['titleMedium', 'cardTitle', { height: 1.3 }],
  ['bodyLarge', 'body', { height: 1.5 }], ['bodySmall', 'listItem', { height: 1.35 }],
  ['labelLarge', 'label', {}], ['labelMedium', 'meta', {}], ['labelSmall', 'navLabel', {}],
  ['overline', 'overline', {}], ['statNumber', 'stat', {}],
  ['cookingStep', 'cookingStep', { height: 1.35 }], ['captionBase', 'caption', { height: 1.45 }]
];
const TYPE_ALIASES = [
  ['titleSmall', 'headlineSmall'], ['buttonText', 'labelLarge'], ['labelText', 'labelMedium'],
  ['captionText', 'captionBase'], ['buttonPrimary', 'labelLarge'], ['buttonTextStyle', 'labelLarge'],
  ['tabText', 'labelMedium'], ['navigationText', 'labelSmall'], ['navLabel', 'labelSmall'],
  ['cardTitle', 'titleMedium'], ['cardTitleStyle', 'titleMedium'], ['listTileTitle', 'titleMedium'],
  ['listTileSubtitle', 'bodyMedium'], ['dialogTitle', 'titleLarge'], ['dialogContent', 'bodyLarge'],
  ['appBarTitle', 'headlineSmall'], ['headerTitle', 'headlineSmall'], ['mainViewTitle', 'headlineBold'],
  ['sectionTitleStyle', 'sectionHeader'], ['emptyStateBody', 'bodyMedium'], ['bodyMediumMuted', 'bodyMedium'],
  ['titleMediumMuted', 'titleMedium'], ['labelMediumMuted', 'labelMedium'], ['badge', 'overline'],
  ['badgeLarge', 'labelMedium'], ['badgeText', 'labelMedium'], ['textXs', 'overline'],
  ['textXsBold', 'overline'], ['textSm', 'labelSmall'], ['filterChip', 'labelMedium'],
  ['formOption', 'bodyMedium'], ['contentLabel', 'labelLarge'], ['contentTitle', 'bodyLarge'],
  ['groupTitle', 'headlineSmall'], ['recipeCardTitle', 'titleMedium'], ['recipeCardDescription', 'bodySmall'],
  ['recipeCardMeta', 'labelSmall'], ['emptyStateTitle', 'headlineSmall'], ['recipeMetaBase', 'labelMedium']
];
const TYPE_SEMANTIC = [
  ['recipeMeta', 'labelMedium', 'AppColors.recipeMeta'], ['sectionHeader', 'headlineSmall', 'AppColors.sectionHeader'],
  ['errorText', 'bodySmall', 'AppColors.error'], ['successText', 'bodySmall', 'AppColors.success'],
  ['warningText', 'bodySmall', 'AppColors.warningText'], ['infoText', 'bodySmall', 'AppColors.info'],
  ['hintText', 'bodyMedium', 'AppColors.textLight'], ['metadataEmphasized', 'labelMedium', null],
  ['titleBold', 'titleMedium', null], ['bodyBold', 'bodyMedium', null], ['bodyLargeBold', 'bodyLarge', null],
  ['bodyMediumError', 'bodyMedium', 'AppColors.error'], ['bodyMediumSuccess', 'bodyMedium', 'AppColors.success'],
  ['bodyMediumWarning', 'bodyMedium', 'AppColors.warningText'],
  ['labelSmallSuccess', 'labelSmall', 'AppColors.onSuccessContainer'], ['linkSmall', 'bodySmall', 'AppColors.info'],
  ['bodyLargeLight', 'bodyLarge', 'AppColors.neutralLight'], ['snackbarText', 'bodyMedium', 'AppColors.neutralLight'],
  ['buttonTextLight', 'labelLarge', 'AppColors.textOnPrimary'],
  ['headerCountBadge', 'labelMedium', 'AppColors.rustLight'], ['sectionLabel', 'overline', 'AppColors.onWarningContainer']
];

function renderType() {
  const R = t.typography.roles;
  const fw = w => 'FontWeight.w' + w;
  const L = [];
  L.push('// GENERERAD FIL — ändra tokens.json, inte den här.');
  L.push('// tokens ' + t.version + ' · ' + t.date + ' · generator tools/gen-app-theme.mjs');
  L.push('//');
  L.push('// Migration (etapp 8.2): samma medlemsnamn som före, värden ur');
  L.push('// tokens.json → typography.roles. Tre ändringar som INTE är kosmetiska:');
  L.push('//');
  L.push('//  1. **En familj, inte två.** Josefin Sans (rubrik) och Space Grotesk (brödtext)');
  L.push('//     ersätts av Butlery Sans. Den plattformsberoende gaffeln — iOS fick');
  L.push('//     `null` och därmed San Francisco — är borta: appen såg olika ut på iOS');
  L.push('//     och Android, vilket ingen bad om.');
  L.push('//  2. **10 px utgår.** Systemets regel: ingen 400-vikt under 12 px, och 10,5 px');
  L.push('//     endast i 700. `textXs`, `badge` och `navLabel` följer nu overline/navLabel.');
  L.push('//  3. **44 px finns inte.** `mainViewTitle` bar 44 px utan token; närmaste');
  L.push('//     avsedda roll är display (32/700). Skalan slutar där med flit.');
  L.push("import 'package:flutter/material.dart';");
  L.push("import 'package:butlery/theme/app_colors.dart';");
  L.push('');
  L.push('class AppTextStyles {');
  L.push('  AppTextStyles._();');
  L.push('');
  L.push('  /// En familj för allt. Namnen headerFont/bodyFont behålls för anropande kod.');
  L.push("  static const String family = 'ButlerySans';");
  L.push('  static const String headerFont = family;');
  L.push('  static const String bodyFont = family;');
  L.push('');
  for (const [name, role, o] of ROLE_STYLES) {
    const r = R[role];
    L.push('  /// tokens: typography.roles.' + role + ' — ' + r.size + '/' + r.weight + (r.note ? ' · ' + r.note : ''));
    L.push('  static TextStyle get ' + name + ' => TextStyle(');
    L.push('    fontFamily: family,');
    L.push('    fontSize: ' + r.size + ',');
    L.push('    fontWeight: ' + fw(r.weight) + ',');
    if (r.tracking) L.push('    letterSpacing: ' + parseFloat(r.tracking) + ',');
    if (o.height) L.push('    height: ' + o.height + ',');
    L.push('  );');
    L.push('');
  }
  L.push('  /// 14/400 — härledd: body i 14 px. Ingen egen roll i tokens, tillåten av');
  L.push('  /// regeln (ingen 400-vikt under 12 px).');
  L.push('  static TextStyle get bodyMedium => const TextStyle(');
  L.push('    fontFamily: family,');
  L.push('    fontSize: 14,');
  L.push('    fontWeight: FontWeight.w400,');
  L.push('    height: 1.4,');
  L.push('  );');
  L.push('');
  L.push('  // ── Alias · samma stil, historiska namn ──');
  for (const [a, b] of TYPE_ALIASES) L.push('  static TextStyle get ' + a + ' => ' + b + ';');
  L.push('');
  L.push('  // ── Semantiska varianter · färgen bär betydelsen ──');
  for (const [n, base, c] of TYPE_SEMANTIC) {
    const w = ['titleBold', 'bodyBold', 'bodyLargeBold'].includes(n) ? 'fontWeight: FontWeight.w700' : null;
    const args = [c ? 'color: ' + c : null, w].filter(Boolean).join(', ');
    L.push('  static TextStyle get ' + n + ' => ' + base + '.copyWith(' + args + ');');
  }
  L.push('');
  L.push('  /// Material 3-TextTheme. Färg utelämnad — M3 lägger på colorScheme.onSurface.');
  L.push('  static TextTheme createTextTheme() {');
  L.push('    return TextTheme(');
  for (const k of ['displaySmall', 'headlineMedium', 'headlineSmall', 'titleLarge', 'titleMedium',
    'bodyLarge', 'bodyMedium', 'bodySmall', 'labelLarge', 'labelMedium', 'labelSmall'])
    L.push('      ' + k + ': ' + k + ',');
  L.push('    );');
  L.push('  }');
  L.push('}');
  L.push('');
  return L.join('\n');
}

mkdirSync('lib/theme', { recursive: true });
const c = renderColors();
const y = renderType();
writeFileSync('lib/theme/app_colors.dart', c);
writeFileSync('lib/theme/app_text_styles.dart', y);
console.log('app_colors.dart ' + c.split('\n').length + ' rader · app_text_styles.dart ' + y.split('\n').length + ' rader');
