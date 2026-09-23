// Package 4, track T6 (P4-SWEEP-VIEWS): the views are right in dark mode.
//
// ColorScheme.primary is surface.ink #24382C in BOTH schemes
// (lib/theme/app_colors.dart lightColorScheme and darkColorScheme;
// tokens.json:112-115 surface.ink). As a foreground on the page it is ink on
// the dark page #17251D (tokens.json:104-107): gone. text.primary is
// onSurface, #24382C light and #F5F4ED dark (tokens.json:54-57), so a
// foreground takes onSurface and cs.primary stays for what the drawing fills
// with ink: filled buttons, ink bars and badges, and checked controls
// (tokens.json:145-148 control.checked.background).
//
// Every snackbar is the ink snackbar (PQ-09 = A; Komponentark v1:745-750):
// a SnackBar in a view or widget never sets its own backgroundColor.
//
// This test reddens when either comes back.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips comments, keeping offsets stable enough for a scan.
String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

List<String> _dartFiles(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where((p) => p.endsWith('.dart'))
        .toList()
      ..sort();

/// The argument list of the call whose opening parenthesis is at [open].
String _args(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return code.substring(open + 1, i);
    }
  }
  return code.substring(open + 1);
}

/// Top-level named arguments of an argument list.
Set<String> _topLevelNames(String args) {
  final names = <String>{};
  var depth = 0;
  final buf = StringBuffer();
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if (depth == 0) buf.write(c);
  }
  for (final m in RegExp(r'(?:^|,)\s*(\w+)\s*:').allMatches(buf.toString())) {
    names.add(m.group(1)!);
  }
  return names;
}

/// Files under [dir] with a `SnackBar(` that sets its own backgroundColor.
List<String> _snackBarBackgrounds(String dir) {
  final out = <String>[];
  for (final path in _dartFiles(dir)) {
    final code = _code(path);
    for (final m in RegExp(r'(?<![\w.])SnackBar\s*\(').allMatches(code)) {
      final names = _topLevelNames(_args(code, m.end - 1));
      if (names.contains('backgroundColor')) {
        out.add(path);
        break;
      }
    }
  }
  return out;
}

/// lib/widgets files that still paint their own snackbar colour. They belong
/// to track T7 (lib/widgets), which moves them to SnackBarUtils. A file not
/// on it fails, and so does an entry that no longer paints one: the list is
/// a ratchet and a stale entry has to be removed.
const _widgetSnackBarsOwnedByT7 = {
  'lib/widgets/common/feedback/snackbar_widgets.dart',
};

final _primary = RegExp(
  r'(?:\b(?:cs|colorScheme|menuCs|dialogCs)|\)\.colorScheme)\.primary\b',
);

/// Named arguments that are always a foreground.
const _foregroundArgs = {
  'foregroundColor',
  'labelColor',
  'unselectedLabelColor',
  'indicatorColor',
  'checkmarkColor',
  'iconColor',
  'textColor',
  'titleColor',
  'linkColor',
  'chipColor',
};

/// Calls whose `color:` is a foreground: a glyph, a text style, a line.
const _foregroundCalls = {
  'Icon',
  'IconButton',
  'TextStyle',
  'copyWith',
  'BorderSide',
  'all', // Border.all
  'Divider',
  'VerticalDivider',
  'StatItemWidget',
  'BarChartRodData',
};

/// (enclosing call, argument name) of the site at [at], or nulls.
(String?, String?) _role(String code, int at) {
  var depth = 0;
  String? arg;
  var i = at - 1;
  // The argument name: walk back over the current argument at depth 0.
  for (; i >= 0; i--) {
    final c = code[i];
    if (')]}'.contains(c)) depth++;
    if ('([{'.contains(c)) {
      if (depth == 0) break;
      depth--;
    }
    if (depth == 0 && c == ',') break;
  }
  final argText = code.substring(i + 1, at);
  final named = RegExp(r'^\s*(\w+)\s*:').firstMatch(argText);
  if (named != null) arg = named.group(1);
  if (i < 0) return (null, arg);
  // The enclosing call: continue back to the unmatched '('.
  depth = 0;
  for (; i >= 0; i--) {
    final c = code[i];
    if (')]}'.contains(c)) depth++;
    if ('([{'.contains(c)) {
      if (depth == 0) {
        if (c != '(') return (null, arg);
        final before = code.substring(0, i);
        final call = RegExp(r'(\w+)\s*$').firstMatch(before)?.group(1);
        return (call, arg);
      }
      depth--;
    }
  }
  return (null, arg);
}

/// Ink as a foreground that the drawing keeps: ink on a plate that is paper
/// in both modes. One entry per site, by file. The count must equal what is
/// found: a site that goes away fails until its count is lowered.
const _inkOnPaperSites = <String, int>{
  // The font-size plate and the X on paper plates on the cooking base
  // (cs.onPrimary behind them, paper in both modes).
  'lib/views/cooking_mode_view.dart': 2,
  // The hero buttons' glyphs inside _PaperRing (cs.onPrimary, Komponentark
  // v1:81-89).
  'lib/views/recipe_detail_view.dart': 2,
  // The unread count on its paper disc (cs.onPrimary) in the ink bar.
  'lib/views/social/shared_with_me/shared_content_app_bar.dart': 1,
};

void main() {
  test('no SnackBar in lib/views sets its own backgroundColor (PQ-09 = A)', () {
    expect(_snackBarBackgrounds('lib/views'), isEmpty);
  });

  test('no new SnackBar backgroundColor in lib/widgets (PQ-09 = A)', () {
    final offenders = _snackBarBackgrounds(
      'lib/widgets',
    ).where((p) => !_widgetSnackBarsOwnedByT7.contains(p)).toList();
    expect(offenders, isEmpty);
  });

  test('every T7 snackbar entry still paints its own colour (ratchet)', () {
    final found = _snackBarBackgrounds('lib/widgets').toSet();
    final stale = _widgetSnackBarsOwnedByT7.difference(found).toList();
    expect(stale, isEmpty, reason: 'remove these entries from the list');
  });

  test('cs.primary is never a foreground in lib/views (dark mode)', () {
    final offenders = <String>[];
    final counts = <String, int>{};
    for (final path in _dartFiles('lib/views')) {
      final code = _code(path);
      final foreground = <String>[];
      for (final m in _primary.allMatches(code)) {
        final (call, arg) = _role(code, m.start);
        final isForeground =
            _foregroundArgs.contains(arg) ||
            (arg == 'color' && _foregroundCalls.contains(call)) ||
            // `Icon(icon, color: …)` style positional first, named after.
            (call == 'Icon');
        if (!isForeground) continue;
        // A border that matches its own ink fill (a checked control) is
        // the fill's edge, not a line on the page: the same expression
        // colours the fill. Recognised by the ternary `x ? <ink> : …`.
        final line = code.substring(
          code.lastIndexOf('\n', m.start) + 1,
          code.indexOf('\n', m.start) == -1
              ? code.length
              : code.indexOf('\n', m.start),
        );
        if ((call == 'all' || call == 'BorderSide') &&
            RegExp(r'\?\s*$').hasMatch(
              code.substring(0, m.start).trimRight().split('\n').last,
            )) {
          continue;
        }
        foreground.add('$path: ${line.trim()} [$call/$arg]');
      }
      final allowed = _inkOnPaperSites[path] ?? 0;
      counts[path] = foreground.length;
      if (foreground.length > allowed) offenders.addAll(foreground);
    }
    expect(offenders, isEmpty);
    // Ratchet: each ink-on-paper allowance is exactly what is found.
    final stale = <String>[
      for (final e in _inkOnPaperSites.entries)
        if ((counts[e.key] ?? 0) != e.value)
          '${e.key}: allowed ${e.value}, found ${counts[e.key] ?? 0}',
    ];
    expect(stale, isEmpty, reason: 'lower these allowances');
  });
}
