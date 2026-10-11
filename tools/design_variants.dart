// BUT-2375: variants per component type, counted from lib/ and app_sv.arb.
//
// The census answers "is the old name gone?". This answers "is there only
// one way to draw X?": each row counts the places that draw a component type
// outside its canonical widget. The ceilings live in
// test/architecture/component_variants_test.dart (`variantCeilings`), which
// fails when a count rises above its ceiling.

import 'dart:convert';

import 'design_migration_census.dart';

/// One component type, how it is counted, and the ticket that brings it
/// down to [target].
class VariantSpec {
  const VariantSpec(this.key, this.ticket, this.target, this.description);

  final String key;
  final String ticket;
  final int target;
  final String description;
}

const variantSpecs = <VariantSpec>[
  VariantSpec(
    'raw_destructive_alert_dialogs',
    'BUT-2366',
    0,
    'AlertDialog built in place that uses the error colour, instead of '
        'the shared destructive confirmation dialog',
  ),
  VariantSpec(
    'hero_style_outside_hero_button',
    'BUT-2367',
    0,
    'ComponentThemes.heroButtonStyle used outside HeroButton',
  ),
  VariantSpec(
    'raw_button_style_from',
    'BUT-2367',
    0,
    'Filled/Elevated/OutlinedButton.styleFrom in views and widgets, '
        'outside lib/widgets/common/buttons/',
  ),
  VariantSpec(
    'raw_snackbars',
    'BUT-2371',
    0,
    'SnackBar( built outside SnackBarUtils',
  ),
  VariantSpec(
    'own_empty_states',
    'BUT-2371',
    0,
    'classes whose name holds Empty...State, or _Empty, outside '
        'lib/widgets/common/state/, each its own empty state',
  ),
  VariantSpec(
    'card_surface_overrides',
    'BUT-2370',
    0,
    'Card( with its own shape or elevation instead of the theme surface',
  ),
  VariantSpec(
    'chevron_sizes',
    'BUT-2370',
    1,
    'distinct size: values on ButleryIcon(chevronRight/chevronLeft) '
        '("default" when none is given)',
  ),
  VariantSpec(
    'sheet_shape_overrides',
    'BUT-2373',
    0,
    'showModalBottomSheet( with its own shape instead of the theme',
  ),
  VariantSpec(
    'direct_font_weights',
    'BUT-2369',
    0,
    'fontWeight: written in views and widgets instead of a text style',
  ),
  VariantSpec(
    'hardcoded_max_width',
    'BUT-2368',
    0,
    'maxWidth: with a number literal outside lib/theme/ and '
        'lib/core/responsive/',
  ),
  VariantSpec(
    'raw_white_black',
    'BUT-2376',
    0,
    'Colors.white or Colors.black in views and widgets instead of a theme '
        'or mode colour',
  ),
  VariantSpec(
    'alpha_literals',
    'BUT-2376',
    0,
    'alpha: with a number literal, or withOpacity(, outside lib/theme/ '
        'instead of a step on the opacity ladder',
  ),
  VariantSpec(
    'icon_size_literals',
    'BUT-2376',
    0,
    'ButleryIcon size: written as a number instead of an AppDimensions '
        'icon size',
  ),
  VariantSpec(
    'spacing_literals',
    'BUT-2376',
    0,
    'EdgeInsets with a non-zero number, or a SizedBox gap of 32 or less '
        'written as a number, in views and widgets instead of space4…space32',
  ),
  VariantSpec(
    'scale_aliases',
    'BUT-2376',
    0,
    'AppDimensions names that repeat a value the scale already names '
        '(spacingSm for space8, iconSizeAction for iconSizeM …)',
  ),
  VariantSpec(
    'forbidden_words_sv',
    'BUT-2372',
    0,
    'app_sv.arb values with "artikel", "handlingslista", "matsedel", "..." '
        'or a straight double quote',
  ),
];

const _svArb = 'lib/l10n/app_sv.arb';
const _snackBarUtils = 'lib/core/utils/snackbar_utils.dart';
const _heroButton = 'lib/widgets/common/buttons/hero_button.dart';

final _errorColour = RegExp(
  r'\b(?:colorScheme|cs|scheme|colors|theme\.colorScheme)\.error\b'
  r'|\bAppColors\.error\b',
);
final _numberLiteral = RegExp(r'(?<![\w.$])(?:\d+\.?\d*|\.\d+)(?![\w.])');
final _edgeInsetsCall = RegExp(
  r'(?<![\w.$])EdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB|fromSTEB)\s*\(',
);
final _sizedBoxGap = RegExp(
  r'^\s*(?:width|height)\s*:\s*(\d+(?:\.\d+)?)\s*,?\s*$',
);
final _scaleAlias = RegExp(
  r'\bAppDimensions\.(?:spacing(?:Xs|Sm|M|Md|L|Lg|Xl|Xxxl)|'
  r'padding(?:S|M|Md|L)|iconSize(?:Action|Info|Display|EmptyState))\b',
);
final _forbiddenSv = RegExp(
  r'artik(?:el|l)|handlingslist|matsedel|\.\.\.|"',
  caseSensitive: false,
);

/// The count per row of [variantSpecs], each with the files it was found in.
Map<String, ({int count, Map<String, int> files, List<String> values})>
countVariants(CensusSource src) {
  final files = <String, Map<String, int>>{
    for (final s in variantSpecs) s.key: {},
  };
  final chevronSizes = <String, Set<String>>{};
  void add(String key, String path, [int n = 1]) {
    if (n == 0) return;
    files[key]![path] = (files[key]![path] ?? 0) + n;
  }

  for (final path in src.libDartFiles()) {
    final code = stripComments(src.read(path));
    final uiLayer =
        path.startsWith('lib/views/') || path.startsWith('lib/widgets/');

    for (final args in callArguments(code, 'AlertDialog')) {
      if (_errorColour.hasMatch(args)) {
        add('raw_destructive_alert_dialogs', path);
      }
    }
    if (path != _heroButton) {
      add(
        'hero_style_outside_hero_button',
        path,
        RegExp(r'\bComponentThemes\.heroButtonStyle\b').allMatches(code).length,
      );
    }
    if (uiLayer && !path.startsWith('lib/widgets/common/buttons/')) {
      add(
        'raw_button_style_from',
        path,
        RegExp(
          r'\b(?:Filled|Elevated|Outlined)Button\.styleFrom\(',
        ).allMatches(code).length,
      );
    }
    if (path != _snackBarUtils) {
      add('raw_snackbars', path, callArguments(code, 'SnackBar').length);
    }
    if (!path.startsWith('lib/widgets/common/state/')) {
      add(
        'own_empty_states',
        path,
        RegExp(
          r'\bclass\s+(?:_?\w*Empty\w*State\w*|_Empty)\b',
        ).allMatches(code).length,
      );
    }
    for (final args in callArguments(code, 'Card')) {
      if (namedArgument(args, 'shape') != null ||
          namedArgument(args, 'elevation') != null) {
        add('card_surface_overrides', path);
      }
    }
    for (final args in callArguments(code, 'ButleryIcon')) {
      if (!RegExp(r'ButleryIcons\.chevron(?:Right|Left)\b').hasMatch(args)) {
        continue;
      }
      final size = namedArgument(args, 'size') ?? 'default';
      chevronSizes.putIfAbsent(size, () => {}).add(path);
    }
    for (final args in callArguments(code, 'showModalBottomSheet')) {
      if (namedArgument(args, 'shape') != null) {
        add('sheet_shape_overrides', path);
      }
    }
    if (uiLayer) {
      add(
        'direct_font_weights',
        path,
        RegExp(r'\bfontWeight\s*:').allMatches(code).length,
      );
    }
    if (uiLayer) {
      add(
        'raw_white_black',
        path,
        RegExp(r'\bColors\.(?:white|black)\w*').allMatches(code).length,
      );
      for (final m in _edgeInsetsCall.allMatches(code)) {
        final close = _matchingParen(code, m.end - 1);
        if (close < 0) continue;
        final args = code.substring(m.end, close);
        if (_numberLiteral
            .allMatches(args)
            .any((n) => double.parse(n.group(0)!) != 0)) {
          add('spacing_literals', path);
        }
      }
      for (final args in callArguments(code, 'SizedBox')) {
        final gap = _sizedBoxGap.firstMatch(args);
        if (gap != null && double.parse(gap.group(1)!) <= 32) {
          add('spacing_literals', path);
        }
      }
    }
    if (!path.startsWith('lib/theme/')) {
      add(
        'alpha_literals',
        path,
        RegExp(
          r'\balpha\s*:\s*\.?\d|\.withOpacity\(',
        ).allMatches(code).length,
      );
      for (final args in callArguments(code, 'ButleryIcon')) {
        final size = namedArgument(args, 'size');
        if (size != null && RegExp(r'^\d').hasMatch(size)) {
          add('icon_size_literals', path);
        }
      }
    }
    if (path != 'lib/theme/app_dimensions.dart') {
      add('scale_aliases', path, _scaleAlias.allMatches(code).length);
    }
    if (!path.startsWith('lib/theme/') &&
        !path.startsWith('lib/core/responsive/')) {
      add(
        'hardcoded_max_width',
        path,
        RegExp(r'\bmaxWidth\s*:\s*\d').allMatches(code).length,
      );
    }
  }

  final arb = src.read(_svArb);
  final forbidden = <String>[];
  if (arb != null) {
    final values = jsonDecode(arb) as Map<String, dynamic>;
    for (final e in values.entries) {
      if (e.key.startsWith('@')) continue;
      final v = e.value;
      if (v is String && _forbiddenSv.hasMatch(v)) forbidden.add(e.key);
    }
  }

  final out =
      <String, ({int count, Map<String, int> files, List<String> values})>{};
  for (final s in variantSpecs) {
    switch (s.key) {
      case 'chevron_sizes':
        final sizes = chevronSizes.keys.toList()..sort();
        out[s.key] = (
          count: sizes.length,
          files: {
            for (final f in chevronSizes.values.expand((p) => p)) f: 1,
          },
          values: sizes,
        );
      case 'forbidden_words_sv':
        out[s.key] = (
          count: forbidden.length,
          files: forbidden.isEmpty ? const {} : {_svArb: forbidden.length},
          values: forbidden..sort(),
        );
      default:
        final f = files[s.key]!;
        out[s.key] = (
          count: f.values.fold(0, (t, n) => t + n),
          files: f,
          values: const [],
        );
    }
  }
  return out;
}

/// The argument text of every call to [name] in [code] (comments already
/// stripped). `Foo.name(` and `_name(` do not match; `const name(` and
/// `name<T>(` do.
List<String> callArguments(String code, String name) {
  final out = <String>[];
  final opener = RegExp(
    r'(?<![\w.$])' + RegExp.escape(name) + r'\s*(?:<[^()]*?>)?\s*\(',
  );
  for (final m in opener.allMatches(code)) {
    final close = _matchingParen(code, m.end - 1);
    if (close > 0) out.add(code.substring(m.end, close));
  }
  return out;
}

/// The expression passed as [name]: at the top level of [args], or null.
String? namedArgument(String args, String name) {
  var depth = 0;
  var start = 0;
  final parts = <String>[];
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if (c == "'" || c == '"') {
      i = _endOfString(args, i) - 1;
    } else if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      depth--;
    } else if (c == ',' && depth == 0) {
      parts.add(args.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(args.substring(start));
  final label = RegExp('^\\s*${RegExp.escape(name)}\\s*:\\s*');
  for (final p in parts) {
    final m = label.firstMatch(p);
    if (m != null) {
      return p.substring(m.end).replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }
  return null;
}

int _matchingParen(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == "'" || c == '"') {
      i = _endOfString(code, i) - 1;
    } else if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Index just past the string literal opening at [i]. Interpolations with
/// braces are skipped by brace depth, so a quote inside `${...}` does not
/// end the literal.
int _endOfString(String code, int i) {
  final q = code[i];
  final triple = code.startsWith(q * 3, i);
  final raw = i > 0 && code[i - 1] == 'r';
  final end = triple ? q * 3 : q;
  var j = i + end.length;
  while (j < code.length) {
    if (!raw && code[j] == r'\') {
      j += 2;
      continue;
    }
    if (!raw && code.startsWith(r'${', j)) {
      var depth = 1;
      j += 2;
      while (j < code.length && depth > 0) {
        final c = code[j];
        if (c == "'" || c == '"') {
          j = _endOfString(code, j);
          continue;
        }
        if (c == '{') depth++;
        if (c == '}') depth--;
        j++;
      }
      continue;
    }
    if (code.startsWith(end, j)) return j + end.length;
    if (!triple && code[j] == '\n') return j;
    j++;
  }
  return code.length;
}
