// BUT-2184: a TextField or TextFormField that can be disabled draws its typed
// text with fieldTextStyle, so the disabled state is text.disabled rather than
// Material's onSurface at 38 %. This test reddens when one passes `enabled:`
// without a `style:` built by fieldTextStyle, or when the `enabled:` it gives
// fieldTextStyle is not the field's own.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// The argument list of the call whose `(` is at [open], with nested calls'
/// text kept only where it belongs to one of this call's arguments.
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

/// The text of the [name] argument of the call whose `(` is at [open].
String? _argument(String code, int open, String name) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0) return null;
    if (depth == 1 && code.startsWith('$name:', i)) {
      final prev = code[i - 1];
      if (RegExp(r'\w').hasMatch(prev)) continue;
      var d = 1;
      final start = i + '$name:'.length;
      for (var j = start; j < code.length; j++) {
        final k = code[j];
        if (k == '(' || k == '[' || k == '{') d++;
        if (k == ')' || k == ']' || k == '}') d--;
        if ((k == ',' && d == 1) || d == 0) return code.substring(start, j);
      }
    }
  }
  return null;
}

void main() {
  test('every field that can be disabled styles its text with '
      'fieldTextStyle', () {
    final call = RegExp(r'\b(TextField|TextFormField)\s*\(');
    final missing = <String>[];
    var seen = 0;
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path.replaceAll(r'\', '/'))
            .where((p) => p.endsWith('.dart') && !p.startsWith('lib/theme/'))
            .toList()
          ..sort();
    for (final path in files) {
      final code = _code(path);
      for (final m in call.allMatches(code)) {
        final open = m.end - 1;
        if (!RegExp(r'\benabled\s*:').hasMatch(_ownArguments(code, open))) {
          continue;
        }
        seen++;
        final line = '\n'.allMatches(code.substring(0, m.start)).length + 1;
        final style = _argument(code, open, 'style');
        final helper = style?.indexOf('fieldTextStyle(') ?? -1;
        if (style == null || helper < 0) {
          missing.add('$path:$line has no fieldTextStyle');
          continue;
        }
        String squash(String? t) => (t ?? '').replaceAll(RegExp(r'\s'), '');
        final own = squash(_argument(code, open, 'enabled'));
        final given = squash(
          _argument(style, helper + 'fieldTextStyle'.length, 'enabled'),
        );
        if (own != given) {
          missing.add('$path:$line enabled: $own, fieldTextStyle: $given');
        }
      }
    }

    expect(seen, greaterThan(0), reason: 'no field passing enabled: found');
    expect(missing, isEmpty);
  });
}
