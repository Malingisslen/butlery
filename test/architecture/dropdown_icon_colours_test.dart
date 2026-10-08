// BUT-2185: a dropdown's built-in arrow is drawn in a hard-coded Material grey
// unless the call site names its colours; no ThemeData property reaches it.
// Every DropdownButton and DropdownButtonFormField in lib/ therefore passes
// both iconEnabledColor and iconDisabledColor. This test reddens when one
// does not.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips comments so a sentence that names a dropdown is not counted.
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

void main() {
  test('every dropdown names its arrow colours, enabled and disabled', () {
    final call = RegExp(r'\bDropdownButton(FormField)?\s*(<[^()]*?>)?\s*\(');
    final missing = <String>[];
    var seen = 0;
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path.replaceAll(r'\', '/'))
            .where((p) => p.endsWith('.dart'))
            .toList()
          ..sort();
    for (final path in files) {
      final code = _code(path);
      for (final m in call.allMatches(code)) {
        seen++;
        final args = _ownArguments(code, m.end - 1);
        for (final name in ['iconEnabledColor:', 'iconDisabledColor:']) {
          if (!args.contains(name)) {
            final line = '\n'.allMatches(code.substring(0, m.start)).length + 1;
            missing.add('$path:$line lacks $name');
          }
        }
      }
    }

    expect(seen, greaterThan(0), reason: 'the dropdown pattern found nothing');
    expect(missing, isEmpty);
  });
}
