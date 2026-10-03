// BUT-2149: saffron (colorScheme.secondary, #CE7C1E) is a fill, an edge, a
// marker, never a text colour.
// Accent text takes text.accent, which is bound to its
// surface (modeColors.textAccent on surface.base, modeColors.onWarningContainer
// on surface.raised, modeColors.accentOnInk on surface.ink). A text style's
// own `color:` or a button's `foregroundColor:` may therefore not name
// `secondary`. Fills, borders, icons and indicators keep it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// The argument list of the call whose `(` is at [open], without nested
/// calls' arguments.
String _ownArguments(String code, int open) {
  final own = StringBuffer();
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 1 && c != '(') own.write(c);
    if (depth == 0) break;
  }
  return own.toString();
}

/// `color:` (or `foregroundColor:`) whose value names the scheme's saffron,
/// up to the next argument. `secondaryContainer` and `onSecondary` do not
/// match.
final _saffronColour = RegExp(
  r'\b(color|foregroundColor):[^,]*\b(cs|colorScheme|scheme)\.secondary\b',
);

List<String> saffronTextColours(String path, String code) {
  final found = <String>[];
  final calls = RegExp(r'(\.copyWith|\bTextStyle|\.styleFrom)\(');
  for (final m in calls.allMatches(code)) {
    final own = _ownArguments(code, m.end - 1);
    final hit = _saffronColour.firstMatch(own);
    if (hit == null) continue;
    // A copyWith on a decoration or a border is not a text style.
    final before = code.substring(0, m.start);
    if (RegExp(r'(Border\w*|Decoration|BorderSide)\s*$').hasMatch(before)) {
      continue;
    }
    final line = '\n'.allMatches(before).length + 1;
    found.add('$path:$line ${hit.group(0)}');
  }
  return found;
}

void main() {
  test(
    'no text style or button text takes saffron (colorScheme.secondary)',
    () {
      final files = [
        for (final dir in ['lib/views', 'lib/widgets', 'lib/theme'])
          ...Directory(dir)
              .listSync(recursive: true)
              .whereType<File>()
              .map((f) => f.path.replaceAll('\\', '/'))
              .where((p) => p.endsWith('.dart')),
      ];
      expect(files, isNotEmpty);
      final found = [
        for (final path in files) ...saffronTextColours(path, _code(path)),
      ];
      expect(
        found,
        isEmpty,
        reason:
            'accent text takes modeColors.textAccent (surface.base), '
            'modeColors.onWarningContainer (surface.raised) or '
            'modeColors.accentOnInk (surface.ink)',
      );
    },
  );

  test('the scan finds each shape it guards', () {
    const shapes = [
      'final a = s.copyWith(color: cs.secondary);',
      'final b = TextStyle(color: cs.secondary);',
      'final c = s.copyWith(color: x ? cs.onSurface : cs.secondary);',
      'final d = TextButton.styleFrom(foregroundColor: cs.secondary);',
      'final e = s.copyWith(color: Theme.of(context).colorScheme.secondary);',
      'final f = s.copyWith(color: cs.secondary.withValues(alpha: 0.5));',
    ];
    for (final shape in shapes) {
      expect(saffronTextColours('x', shape), hasLength(1), reason: shape);
    }
    const allowed = [
      'final g = s.copyWith(color: cs.secondaryContainer);',
      'final h = BorderSide(color: cs.secondary);',
      'final i = s.copyWith(color: cs.onSecondary);',
      'final j = s.copyWith(color: context.modeColors.textAccent);',
      'final k = Border.all(color: cs.secondary);',
      'final l = FilledButton.styleFrom(backgroundColor: cs.secondary);',
      'final m = BoxDecoration(color: cs.secondary);',
      'final n = ButleryIcon(x, color: cs.secondary);',
    ];
    for (final shape in allowed) {
      expect(saffronTextColours('x', shape), isEmpty, reason: shape);
    }
  });
}
