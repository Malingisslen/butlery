// BUT-2199: some AppTextStyles getters carry a fixed light-mode colour
// (`copyWith(color: AppColors.x)` in the generated app_text_styles.dart), so
// a screen that uses one as is draws the light value in dark mode — the
// "Veckans inköp" header did. Every use in lib/views and lib/widgets therefore
// names its own colour through `.copyWith(color: ...)`. The getters are read
// from the generated file.

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

void main() {
  test('a text style with a fixed light colour always gets its own colour', () {
    final styles = _code('lib/theme/app_text_styles.dart');
    final getters = {
      for (final m in RegExp(
        r'static TextStyle get (\w+)\s*=>([^;]*);',
      ).allMatches(styles))
        m.group(1)!: m.group(2)!.trim(),
    };
    final baked = {
      for (final e in getters.entries)
        if (RegExp(r'color:\s*AppColors\.').hasMatch(e.value)) e.key,
    };
    expect(baked, isNotEmpty, reason: 'no fixed-colour getter was found');
    // An alias (`get a => b;`) of a fixed-colour getter draws the same colour.
    for (var grew = true; grew;) {
      grew = false;
      for (final e in getters.entries) {
        if (!baked.contains(e.key) && baked.contains(e.value)) {
          grew = baked.add(e.key);
        }
      }
    }

    final use = RegExp(r'AppTextStyles\.(' + baked.join('|') + r')\b');
    final missing = <String>[];
    final files = [
      for (final dir in ['lib/views', 'lib/widgets'])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path.replaceAll(r'\', '/'))
            .where((p) => p.endsWith('.dart')),
    ]..sort();
    for (final path in files) {
      final code = _code(path);
      for (final m in use.allMatches(code)) {
        final rest = code.substring(m.end);
        final copy = RegExp(r'^\s*\.copyWith\s*\(').firstMatch(rest);
        final named =
            copy != null &&
            _ownArguments(code, m.end + copy.end - 1).contains('color:');
        if (!named) {
          final line = '\n'.allMatches(code.substring(0, m.start)).length + 1;
          missing.add('$path:$line ${m.group(0)}');
        }
      }
    }

    expect(missing, isEmpty);
  });
}
