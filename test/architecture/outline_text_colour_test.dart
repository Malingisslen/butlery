// BUT-2220: colorScheme.outline is border.control, a line colour with a 3:1
// floor. As text it measured 3.32:1 on surface.base in light (BUT-2196), under
// the 4.5:1 text floor; muted text takes text.secondary (onSurfaceVariant).
// A text style's own `color:` or a button's `foregroundColor:` may therefore
// not name `outline`. Borders, icons and indicators keep it.

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

/// `color:` (or `foregroundColor:`) whose value names `.outline`, up to the
/// next argument.
final _outlineColour = RegExp(
  r'\b(color|foregroundColor):[^,]*\.outline\b(?!Variant)',
);

List<String> outlineTextColours(String path, String code) {
  final found = <String>[];
  final calls = RegExp(r'(\.copyWith|\bTextStyle|\.styleFrom)\(');
  for (final m in calls.allMatches(code)) {
    final own = _ownArguments(code, m.end - 1);
    final hit = _outlineColour.firstMatch(own);
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
  test('no text style or button text takes the border colour (outline)', () {
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
      for (final path in files) ...outlineTextColours(path, _code(path)),
    ];
    expect(found, isEmpty, reason: 'use cs.onSurfaceVariant for muted text');
  });

  test('the scan finds each shape it guards', () {
    const shapes = [
      'final a = s.copyWith(color: cs.outline);',
      'final b = TextStyle(color: cs.outline);',
      'final c = s.copyWith(color: x ? cs.onSurface : cs.outline);',
      'final d = TextButton.styleFrom(foregroundColor: cs.outline);',
      'final e = s.copyWith(color: Theme.of(context).colorScheme.outline);',
    ];
    for (final shape in shapes) {
      expect(outlineTextColours('x', shape), hasLength(1), reason: shape);
    }
    const allowed = [
      'final f = s.copyWith(color: cs.outlineVariant);',
      'final g = BorderSide(color: cs.outline);',
      'final h = s.copyWith(color: cs.onSurfaceVariant);',
    ];
    for (final shape in allowed) {
      expect(outlineTextColours('x', shape), isEmpty, reason: shape);
    }
  });
}
