// Butlery · REN kontroll av det genererade app-temat mot källorna.
//
// Fas 1 (tredje vändan): TG-01 kontrollerade bara att MEDLEMSNAMNEN fanns. En
// ändring av ett faktiskt färgvärde — forestGreen från #24382C till vitt — gav
// fortfarande exit 0. Aliasens högersida mättes, men inte värdena.
//
// Den här modulen räknar om varje värde ur tokens + mappningen och jämför med
// den genererade Dart-koden. Ingen filsystemsåtkomst: allt skickas in, så
// metatesterna kan mutera källtexten i minnet och kräva att rätt fel faller.
export function argbOf(v) {
  const hx = n => Number(n).toString(16).padStart(2, '0').toUpperCase();
  if (typeof v !== 'string') return null;
  if (v.startsWith('#')) return 'Color(0xFF' + v.slice(1).toUpperCase() + ')';
  const m = v.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)/);
  if (!m) return null;
  const a = Math.round((m[4] === undefined ? 1 : parseFloat(m[4])) * 255);
  return 'Color(0x' + hx(a) + hx(m[1]) + hx(m[2]) + hx(m[3]) + ')';
}

// Löser [kind, key] mot tokens. 'member' pekar på en annan post i map.colors.
export function resolveToken(tokens, map, kind, key, mode = 'light') {
  if (kind === 'semantic') return tokens.semantic?.[key]?.[mode] ?? null;
  if (kind === 'palette') return tokens.palette?.[key] ?? null;
  if (kind === 'member') {
    const e = map.colors?.[key];
    return e ? resolveToken(tokens, map, e[0], e[1], mode) : null;
  }
  if (kind === 'raw') return key;
  return null;
}

const cap = s => s.charAt(0).toUpperCase() + s.slice(1);

export function checkAppTheme({ colorsSrc = '', textSrc = '', tokens, map, brand, legacy }) {
  const errors = [];
  const fail = m => errors.push(m);
  const counts = { colors: 0, aliases: 0, brands: 0, scheme: 0, typeRoles: 0, typeAliases: 0, typeSemantic: 0, legacy: 0 };
  // Endast token-id får stå i mappningen. Fas 1 (fjärde vändan): en rå färg i
  // scheme.darkOverrides regenererades och både GEN-02 och TG-01 blev gröna.
  const KINDS = new Set(['semantic', 'palette', 'member']);
  const RAWISH = /#[0-9A-Fa-f]{3,8}\b|rgba?\(/;
  const constOf = (name) => {
    const m = colorsSrc.match(new RegExp('static const Color ' + name + '\\s*=\\s*([^;]+);'));
    return m ? m[1].trim() : null;
  };

  /* ── app_colors.dart · VÄRDEN, inte bara namn ─────────────────────────── */
  for (const [name, e] of Object.entries(map.colors || {})) {
    counts.colors++;
    if (!KINDS.has(e[0])) fail('app-theme-map.json: colors.' + name + ' har kind "' + e[0] + '" — tillåtna: ' + [...KINDS].join(', '));
    else if (RAWISH.test(String(e[1]))) fail('app-theme-map.json: colors.' + name + ' pekar på färgvärdet ' + e[1] + ' i stället för ett token-id');
    const want = argbOf(resolveToken(tokens, map, e[0], e[1]));
    const got = constOf(name);
    if (got === null) { fail('app_colors.dart: ' + name + ' finns i app-theme-map.json men inte i utdata'); continue; }
    if (want === null) { fail('app-theme-map.json: ' + name + ' pekar på ' + e[0] + '.' + e[1] + ', som inte går att lösa mot tokens'); continue; }
    if (got !== want) fail('app_colors.dart: ' + name + ' är ' + got + ' men ' + e[0] + '.' + e[1] + ' ger ' + want + ' — kör node tools/gen-app-theme.mjs');
  }
  for (const [from, to] of Object.entries(map.aliases || {})) {
    counts.aliases++;
    const got = constOf(from);
    if (got === null) { fail('app_colors.dart: aliaset ' + from + ' saknas i utdata'); continue; }
    if (got !== to) fail('app_colors.dart: aliaset ' + from + ' pekar på ' + got + ' men på ' + to + ' i app-theme-map.json');
  }
  for (const [n, v] of Object.entries((brand || {}).brands || {})) {
    for (const [suffix, val] of [['', v.color], ['Background', v.background], ['Text', v.text]]) {
      if (!val) continue;
      counts.brands++;
      const member = 'brand' + cap(n) + suffix;
      const got = constOf(member);
      const want = argbOf(val);
      if (got === null) { fail('app_colors.dart: ' + member + ' saknas trots att assets/brand-colors.json deklarerar den'); continue; }
      if (got !== want) fail('app_colors.dart: ' + member + ' är ' + got + ' men varumärkeskällan säger ' + want);
    }
  }
  for (const mode of ['light', 'dark']) {
    const cls = mode === 'light' ? 'lightColorScheme' : 'darkColorScheme';
    const body = (colorsSrc.match(new RegExp('static const ColorScheme ' + cls + ' = ColorScheme\\(([\\s\\S]*?)\\);')) || [])[1];
    if (!body) { fail('app_colors.dart: ' + cls + ' saknas'); continue; }
    if (!new RegExp('brightness: Brightness\\.' + mode + ',').test(body)) fail('app_colors.dart: ' + cls + ' saknar brightness: Brightness.' + mode);
    for (const [slot, base] of Object.entries(map.scheme?.slots || {})) {
      const over = mode === 'dark' && map.scheme.darkOverrides?.[slot];
      const e = over || base;
      const branch = 'scheme.' + (over ? 'darkOverrides' : 'slots') + '.' + slot;
      counts.scheme++;
      if (!KINDS.has(e[0])) fail('app-theme-map.json: ' + branch + ' har kind "' + e[0] + '" — tillåtna: ' + [...KINDS].join(', '));
      else if (RAWISH.test(String(e[1]))) fail('app-theme-map.json: ' + branch + ' bär färgvärdet ' + e[1] + ' i stället för ett token-id');
      const want = argbOf(resolveToken(tokens, map, e[0], e[1], mode));
      const got = (body.match(new RegExp('(?:^|\\n)\\s*' + slot + ':\\s*([^,\\n]+),')) || [])[1];
      if (!got) { fail('app_colors.dart: ' + cls + ' saknar slotten ' + slot + ' ur app-theme-map.json'); continue; }
      if (want === null) { fail('app-theme-map.json: slotten ' + slot + ' (' + mode + ') går inte att lösa mot tokens'); continue; }
      if (got.trim() !== want) fail('app_colors.dart: ' + cls + '.' + slot + ' är ' + got.trim() + ' men ' + e[0] + '.' + e[1] + ' ger ' + want + ' i ' + mode);
    }
  }

  /* ── app_text_styles.dart · VÄRDEN per roll ───────────────────────────── */
  const roles = tokens.typography?.roles || {};
  const blocks = new Map([...textSrc.matchAll(/static TextStyle get (\w+) => (?:const )?TextStyle\(([\s\S]*?)\);/g)].map(m => [m[1], m[2]]));
  if (!new RegExp("static const String family = '" + (map.fontFamily || '') + "';").test(textSrc))
    fail('app_text_styles.dart: family ≠ app-theme-map.json → fontFamily (' + map.fontFamily + ')');
  for (const [name, role] of Object.entries(map.typeRoles || {})) {
    counts.typeRoles++;
    const r = roles[role];
    if (!r) { fail('app-theme-map.json: typeRoles.' + name + ' pekar på rollen ' + role + ', som inte finns i tokens'); continue; }
    const body = blocks.get(name);
    if (!body) { fail('app_text_styles.dart: ' + name + ' saknas trots att typeRoles deklarerar den'); continue; }
    const num = re => { const m = body.match(re); return m ? Number(m[1]) : null; };
    const size = num(/fontSize:\s*([\d.]+)/), h = num(/height:\s*([\d.]+)/), w = num(/FontWeight\.w(\d+)/);
    if (size !== r.size || h !== r.lineHeight || w !== r.weight)
      fail('app_text_styles.dart: ' + name + ' är ' + size + '/' + w + '/' + h + ' men tokens.' + role + ' säger ' + r.size + '/' + r.weight + '/' + r.lineHeight);
    const trackWant = r.tracking ? parseFloat(r.tracking) : null;
    const trackGot = num(/letterSpacing:\s*(-?[\d.]+)/);
    if (trackWant !== null && trackGot !== trackWant) fail('app_text_styles.dart: ' + name + ' har letterSpacing ' + trackGot + ' men tokens.' + role + ' säger ' + trackWant);
    if (trackWant === null && trackGot !== null) fail('app_text_styles.dart: ' + name + ' sätter letterSpacing som tokens-rollen inte har');
  }
  for (const [a, b] of Object.entries(map.typeAliases || {})) {
    counts.typeAliases++;
    const got = (textSrc.match(new RegExp('static TextStyle get ' + a + ' => ([A-Za-z0-9_]+);')) || [])[1];
    if (!got) fail('app_text_styles.dart: typaliaset ' + a + ' saknas i utdata');
    else if (got !== b) fail('app_text_styles.dart: typaliaset ' + a + ' pekar på ' + got + ' men på ' + b + ' i app-theme-map.json');
  }
  // MEDLEMMEN bakom typeSemantic.color måste finnas. Fas 1 (fjärde vändan):
  // AppColors.doesNotExist passerade både GEN-02 och TG-01 — den genererade
  // Dart-koden skulle inte ha kompilerat.
  const cap2 = s2 => s2.charAt(0).toUpperCase() + s2.slice(1);
  const FLUTTER_CONST = new Set(['transparent']);
  const colorMembers = new Set([
    ...Object.keys(map.colors || {}),
    ...Object.keys(map.aliases || {}),
    ...Object.entries((brand || {}).brands || {}).flatMap(([n2, v]) => [
      'brand' + cap2(n2), ...(v.background ? ['brand' + cap2(n2) + 'Background'] : []), ...(v.text ? ['brand' + cap2(n2) + 'Text'] : [])]),
    ...FLUTTER_CONST
  ]);
  for (const [n, s] of Object.entries(map.typeSemantic || {})) {
    counts.typeSemantic++;
    if (s.color !== null && s.color !== undefined) {
      const ref = String(s.color).match(/^AppColors\.(\w+)$/);
      if (!ref) fail('app-theme-map.json: typeSemantic.' + n + '.color = "' + s.color + '" — måste vara null eller AppColors.<medlem>');
      else if (!colorMembers.has(ref[1])) fail('app-theme-map.json: typeSemantic.' + n + '.color pekar på AppColors.' + ref[1] + ', som inte finns bland medlemmar, alias, varumärken eller Flutter-konstanter — Dart-koden skulle inte kompilera');
    }
    const m = textSrc.match(new RegExp('static TextStyle get ' + n + ' => ([A-Za-z0-9_]+)\\.copyWith\\(([^)]*)\\);'));
    if (!m) { fail('app_text_styles.dart: den semantiska varianten ' + n + ' saknas i utdata'); continue; }
    if (m[1] !== s.base) fail('app_text_styles.dart: ' + n + ' bygger på ' + m[1] + ' men på ' + s.base + ' i app-theme-map.json');
    const args = m[2] || '';
    if (s.color && !args.includes('color: ' + s.color)) fail('app_text_styles.dart: ' + n + ' saknar färgen ' + s.color);
    if (!s.color && /color:/.test(args)) fail('app_text_styles.dart: ' + n + ' sätter en färg som mappningen inte deklarerar');
    if (s.bold && !args.includes('FontWeight.w' + map.boldWeight)) fail('app_text_styles.dart: ' + n + ' är deklarerad bold men bär inte vikten ' + map.boldWeight);
    if (!s.bold && /fontWeight:/.test(args)) fail('app_text_styles.dart: ' + n + ' sätter en vikt som mappningen inte deklarerar');
  }
  {
    const tt = (textSrc.match(/static TextTheme createTextTheme\(\) \{([\s\S]*?)\n  \}/) || [])[1] || '';
    for (const slot of map.textThemeSlots || [])
      if (!new RegExp('\\b' + slot + ': ' + slot + ',').test(tt)) fail('app_text_styles.dart: createTextTheme saknar slotten ' + slot);
  }
  // Varje tokenroll måste vara representerad någonstans i utdata.
  const sizes = new Set([...textSrc.matchAll(/fontSize:\s*([\d.]+)/g)].map(x => Number(x[1])));
  for (const [role, r] of Object.entries(roles))
    if (!sizes.has(r.size)) fail('app_text_styles.dart: ingen stil har graden ' + r.size + ' (tokens-rollen ' + role + ')');

  /* ── FRYST LEGACY-API · exakt mängdlikhet ─────────────────────────────── */
  // Fas 1 (fjärde vändan): kontrollerna bevisade att utdata stämde med den
  // FÖRÄNDERLIGA mappningen. Ett borttaget alias i app-theme-map.json tog bort
  // medlemmen ur Dart och allt förblev grönt — påståendet att varje medlemsnamn
  // behålls var alltså obevakat. Kontraktet i legacy-api-contract.json är fryst;
  // mängderna måste stämma i BÅDA riktningarna.
  if (legacy) {
    const setEq = (label, wanted, got) => {
      const W = new Set(wanted), G = new Set(got);
      counts.legacy += W.size;
      for (const x of W) if (!G.has(x)) fail('LEGACY-API: ' + label + ' ' + x + ' finns i det frysta kontraktet men inte i utdata — befintlig appkod slutar kompilera');
      for (const x of G) if (!W.has(x)) fail('LEGACY-API: ' + label + ' ' + x + ' finns i utdata men inte i kontraktet — lägg till den i legacy-api-contract.json om ytan medvetet växer');
    };
    setEq('AppColors-medlemmen', legacy.appColors?.members || [], [...colorsSrc.matchAll(/static const Color (\w+)\s*=/g)].map(m2 => m2[1]));
    setEq('ColorScheme', legacy.appColors?.colorSchemes || [], [...colorsSrc.matchAll(/static const ColorScheme (\w+)\s*=/g)].map(m2 => m2[1]));
    setEq('AppTextStyles-gettern', legacy.appTextStyles?.getters || [], [...textSrc.matchAll(/static TextStyle get (\w+)/g)].map(m2 => m2[1]));
    setEq('AppTextStyles-konstanten', legacy.appTextStyles?.stringConstants || [], [...textSrc.matchAll(/static const String (\w+)\s*=/g)].map(m2 => m2[1]));
  } else {
    fail('LEGACY-API: legacy-api-contract.json saknas — den historiska API-ytan kan inte skyddas');
  }
  return { errors, counts };
}
