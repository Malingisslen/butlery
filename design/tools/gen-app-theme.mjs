#!/usr/bin/env node
// Butlery · tokens.json + tools/app-theme-map.json + assets/brand-colors.json
// → lib/theme/app_colors.dart och lib/theme/app_text_styles.dart.
// Kör: node tools/gen-app-theme.mjs
//
// Etapp 8.1–8.2 i arbetsplanen. Skillnaden mot gen-flutter.mjs: den skriver ett
// NYTT tema (ButleryColors/ButleryType). Den här skriver om appens BEFINTLIGA
// två temafiler och behåller varje medlemsnamn enligt det frysta
// legacy-api-contract.json, medan värdena byter källa till tokens.json. Att den
// ytan motsvarar app-repots faktiska anrop är overifierat till Fas 2 (§ 9E).
//
// FAS 1 (andra vändan) — tre fel rättade:
//   1 importen av header() saknades: generatorn kraschade i varje körning.
//   2 T.typography.weights refererade en variabel som inte fanns (den heter t).
//   3 alias, ColorScheme-slottar, typroller, semantiska varianter, fetstilsvikt
//     och Material 3-slottarna låg som sju tabeller HÄR. Generatorn var därmed
//     en parallell mappningskälla: en ändring i app-theme-map.json syntes inte i
//     utdata. Allt sådant läses nu ur mappningsfilen, som har eget schema och
//     valideras av T-01. Generatorn innehåller ingen designdata alls.
import { readFileSync } from 'node:fs';
import { header } from './gen-header.mjs';
import { emit } from './gen-check.mjs';

const GENERATOR = 'tools/gen-app-theme.mjs';
const GENERATOR_VERSION = '2.3';
const INPUTS = ['tokens.json', 'tools/app-theme-map.json', 'assets/brand-colors.json'];

const t = JSON.parse(readFileSync('tokens.json', 'utf8'));
const map = JSON.parse(readFileSync('tools/app-theme-map.json', 'utf8'));
const BRAND_SRC = JSON.parse(readFileSync('assets/brand-colors.json', 'utf8'));

const die = m => { console.error('✖ ' + m); process.exitCode = 1; throw new Error(m); };

const hx = n => Number(n).toString(16).padStart(2, '0').toUpperCase();
function argb(v) {
  if (typeof v !== 'string') die('Okänt färgvärde: ' + JSON.stringify(v));
  if (v.startsWith('#')) return 'Color(0xFF' + v.slice(1).toUpperCase() + ')';
  const m = v.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)/);
  if (!m) die('Okänt färgformat: ' + v);
  const a = Math.round((m[4] === undefined ? 1 : parseFloat(m[4])) * 255);
  return 'Color(0x' + hx(a) + hx(m[1]) + hx(m[2]) + hx(m[3]) + ')';
}

// EN uppslagsfunktion för hela filen. 'member' pekar på en annan post i
// map.colors, så en rå färg aldrig behöver upprepas.
function val(kind, key, mode = 'light') {
  if (kind === 'semantic') {
    const s = t.semantic[key];
    if (!s || s[mode] === undefined) die('tokens.semantic.' + key + ' saknar läget ' + mode);
    return s[mode];
  }
  if (kind === 'palette') {
    if (t.palette[key] === undefined) die('tokens.palette.' + key + ' finns inte');
    return t.palette[key];
  }
  if (kind === 'raw') return key;
  if (kind === 'member') {
    const e = map.colors[key];
    if (!e) die('scheme-slotten pekar på medlemmen ' + key + ', som inte finns i map.colors');
    return val(e[0], e[1], mode);
  }
  return die('okänd kind "' + kind + '" i app-theme-map.json');
}
const col = (kind, key, mode) => argb(val(kind, key, mode));

/* ── Mappningens interna integritet, före all rendering ───────────────────── */
{
  const R = t.typography.roles;
  // Endast token-id. Fas 1 (fjärde vändan): 'raw' var förbjudet i colors och
  // scheme.slots men INTE i scheme.darkOverrides, så en rå färg där gick igenom
  // hela kedjan. Nu prövas varje gren mot samma tillåtna kinds.
  const KINDS = new Set(['semantic', 'palette', 'member']);
  const RAWISH = /#[0-9A-Fa-f]{3,8}\b|rgba?\(/;
  const kindOk = (branch, e) => {
    if (!KINDS.has(e[0])) die(branch + ' har kind "' + e[0] + '" — tillåtna: ' + [...KINDS].join(', '));
    if (RAWISH.test(String(e[1]))) die(branch + ' bär färgvärdet ' + e[1] + ' i stället för ett token-id');
  };
  for (const [name, e] of Object.entries(map.colors)) {
    if (!Array.isArray(e) || e.length !== 3) die('map.colors.' + name + ' ska vara [kind, tokenId, note]');
    kindOk('map.colors.' + name, e);
    val(e[0], e[1]);                                  // fäller på okänd kind/token
  }
  if (map.derivedStyles) die('map.derivedStyles bär typmått — en typografisk storlek hör i tokens.typography.roles');
  for (const [a, b] of Object.entries(map.aliases))
    if (!map.colors[b]) die('aliaset ' + a + ' pekar på ' + b + ', som inte finns i map.colors');
  for (const [slot, e] of Object.entries(map.scheme.slots)) {
    kindOk('map.scheme.slots.' + slot, e);
    val(e[0], e[1], 'light');
  }
  for (const [slot, e] of Object.entries(map.scheme.darkOverrides)) {
    if (!map.scheme.slots[slot]) die('darkOverrides.' + slot + ' saknar motsvarande slot');
    kindOk('map.scheme.darkOverrides.' + slot, e);
    val(e[0], e[1], 'dark');
  }
  for (const [name, role] of Object.entries(map.typeRoles))
    if (!R[role]) die('typeRoles.' + name + ' pekar på tokens-rollen ' + role + ', som inte finns');
  if (!(t.typography.weights || []).includes(map.boldWeight))
    die('boldWeight ' + map.boldWeight + ' finns inte i tokens.typography.weights (' + (t.typography.weights || []).join(', ') + ')');
  const styleNames = new Set(Object.keys(map.typeRoles));
  // FÄRGREFERENSEN måste peka på en medlem som faktiskt renderas. Fas 1 (fjärde
  // vändan): AppColors.doesNotExist passerade hela kedjan — Dart-koden hade inte
  // kompilerat.
  const colorMembers = new Set([...Object.keys(map.colors), ...Object.keys(map.aliases), 'transparent']);
  {
    const c2 = s2 => s2.charAt(0).toUpperCase() + s2.slice(1);
    for (const [n2, v] of Object.entries(BRAND_SRC.brands)) {
      colorMembers.add('brand' + c2(n2));
      if (v.background) colorMembers.add('brand' + c2(n2) + 'Background');
      if (v.text) colorMembers.add('brand' + c2(n2) + 'Text');
    }
  }
  for (const [n, s] of Object.entries(map.typeSemantic)) {
    if (!styleNames.has(s.base)) die('typeSemantic.' + n + ' bygger på ' + s.base + ', som inte är en stil');
    if (s.color === null || s.color === undefined) continue;
    const ref = String(s.color).match(/^AppColors\.(\w+)$/);
    if (!ref) die('typeSemantic.' + n + '.color = "' + s.color + '" — måste vara null eller AppColors.<medlem>');
    if (!colorMembers.has(ref[1])) die('typeSemantic.' + n + '.color pekar på AppColors.' + ref[1] + ', som inte finns');
  }
  const withSemantic = new Set([...styleNames, ...Object.keys(map.typeSemantic)]);
  for (const [a, b] of Object.entries(map.typeAliases))
    if (!withSemantic.has(b)) die('typeAliases.' + a + ' pekar på ' + b + ', som inte är en stil');
  const all = new Set([...withSemantic, ...Object.keys(map.typeAliases)]);
  for (const slot of map.textThemeSlots)
    if (!all.has(slot)) die('textThemeSlots innehåller ' + slot + ', som inte är en stil');
}

const cap = s => s.charAt(0).toUpperCase() + s.slice(1);
// Varumärkesfärgerna låg tidigare hårdkodade här, vilket gjorde generatorn till
// en parallell designkälla. De ligger nu i assets/brand-colors.json med eget
// schema, ägare (PRODUKT) och proveniens. Fas 1.
const BRANDS = Object.entries(BRAND_SRC.brands).flatMap(([name, v]) => [
  ['brand' + cap(name), v.color],
  ...(v.background ? [['brand' + cap(name) + 'Background', v.background]] : []),
  ...(v.text ? [['brand' + cap(name) + 'Text', v.text]] : [])
]);

function scheme(mode) {
  const L = ['  static const ColorScheme ' + (mode === 'light' ? 'lightColorScheme' : 'darkColorScheme') + ' = ColorScheme(',
    '    brightness: Brightness.' + mode + ','];
  for (const [slot, base] of Object.entries(map.scheme.slots)) {
    const e = (mode === 'dark' && map.scheme.darkOverrides[slot]) || base;
    L.push('    ' + slot + ': ' + col(e[0], e[1], mode) + ',');
  }
  L.push('  );');
  return L;
}

function renderColors() {
  const L = [];
  for (const h of header({ generator: GENERATOR, generatorVersion: GENERATOR_VERSION, tokenVersion: t.version, inputs: INPUTS, date: t.date }).lines) L.push(h);
  L.push('//');
  L.push('// Migration (etapp 8.1): varje medlem har samma NAMN som i det FRYSTA');
  L.push('// leveranskontraktet (legacy-api-contract.json), som TG-01 mäter med exakt');
  L.push('// mängdlikhet. Att ytan motsvarar app-repots faktiska anrop är OVERIFIERAT');
  L.push('// till Fas 2 (styrdokumentet § 9E). VÄRDET kommer ur tokens.json. Färgnamn som');
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
  L.push('  // Alias — oförändrade, pekar på medlemmar ovan. Deklarerade i');
  L.push('  // tools/app-theme-map.json; högersidan mäts mot utdata av TG-01.');
  for (const [a, b] of Object.entries(map.aliases)) L.push('  static const Color ' + a + ' = ' + b + ';');
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

function renderType() {
  const R = t.typography.roles;
  const fw = w => 'FontWeight.w' + w;
  const L = [];
  for (const h of header({ generator: GENERATOR, generatorVersion: GENERATOR_VERSION, tokenVersion: t.version, inputs: INPUTS, date: t.date }).lines) L.push(h);
  L.push('//');
  L.push('// Migration (etapp 8.2): samma medlemsnamn som i det frysta kontraktet, värden ur');
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
  L.push("  static const String family = '" + map.fontFamily + "';");
  L.push('  static const String headerFont = family;');
  L.push('  static const String bodyFont = family;');
  L.push('');
  for (const [name, role] of Object.entries(map.typeRoles)) {
    const r = R[role];
    if (r.lineHeight === undefined) die('tokens.typography.roles.' + role + ' saknar lineHeight');
    L.push('  /// tokens: typography.roles.' + role + ' — ' + r.size + '/' + r.weight + (r.note ? ' · ' + r.note : ''));
    L.push('  static TextStyle get ' + name + ' => const TextStyle(');
    L.push('    fontFamily: family,');
    L.push('    fontSize: ' + r.size + ',');
    L.push('    fontWeight: ' + fw(r.weight) + ',');
    if (r.tracking) L.push('    letterSpacing: ' + parseFloat(r.tracking) + ',');
    L.push('    height: ' + r.lineHeight + ',');
    L.push('  );');
    L.push('');
  }
  // HÄRLEDDA stilar utgår. Fas 1 (tredje vändan): bodyMedium låg först som ett
  // dolt medelvärde i generatorn, sedan som ett uttryckligt mått i mappningsfilen
  // — men ett typmått är ett designvärde. Rollen finns nu i tokens.typography.roles
  // och renderas som alla andra roller ovan.
  L.push('  // ── Alias · samma stil, historiska namn ──');
  for (const [a, b] of Object.entries(map.typeAliases)) L.push('  static TextStyle get ' + a + ' => ' + b + ';');
  L.push('');
  L.push('  // ── Semantiska varianter · färgen bär betydelsen ──');
  for (const [n, s] of Object.entries(map.typeSemantic)) {
    const w = s.bold ? 'fontWeight: ' + fw(map.boldWeight) : null;
    const args = [s.color ? 'color: ' + s.color : null, w].filter(Boolean).join(', ');
    L.push('  static TextStyle get ' + n + ' => ' + s.base + '.copyWith(' + args + ');');
  }
  L.push('');
  L.push('  /// Material 3-TextTheme. Färg utelämnad — M3 lägger på colorScheme.onSurface.');
  L.push('  static TextTheme createTextTheme() {');
  L.push('    return TextTheme(');
  for (const k of map.textThemeSlots) L.push('      ' + k + ': ' + k + ',');
  L.push('    );');
  L.push('  }');
  L.push('}');
  L.push('');
  return L.join('\n');
}

emit({ 'lib/theme/app_colors.dart': renderColors(), 'lib/theme/app_text_styles.dart': renderType() },
  { label: 'gen-app-theme' });
console.log('app_colors.dart och app_text_styles.dart skrivna ur tokens ' + t.version);
