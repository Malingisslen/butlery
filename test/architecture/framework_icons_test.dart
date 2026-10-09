// The framework draws its own Material icon on a few widgets unless the
// call site hands it one. Every use in lib/ names the Butlery glyph instead
// (the back and close buttons are covered by the theme's ActionIconThemeData).
// This test reddens when a new call site forgets.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAllMapped(
      RegExp(r'/\*[\s\S]*?\*/'),
      (m) => '\n' * '\n'.allMatches(m[0]!).length,
    )
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

List<String> _callsMissing({
  required RegExp call,
  required RegExp argument,
  RegExp? onlyWhen,
}) {
  final missing = <String>[];
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final code = _code(f.path);
    for (final m in call.allMatches(code)) {
      final args = _ownArguments(code, m.end - 1);
      if (onlyWhen != null && !onlyWhen.hasMatch(args)) continue;
      if (!argument.hasMatch(args)) {
        final line = '\n'.allMatches(code.substring(0, m.start)).length + 1;
        missing.add('${f.path.replaceAll(r'\', '/')}:$line');
      }
    }
  }
  return missing;
}

void main() {
  test('every dropdown names its arrow glyph', () {
    expect(
      _callsMissing(
        call: RegExp(r'\bDropdownButton(FormField)?\s*(<[^()]*?>)?\s*\('),
        argument: RegExp(r'\bicon:'),
      ),
      isEmpty,
    );
  });

  test('every expansion tile names its chevron', () {
    expect(
      _callsMissing(
        call: RegExp(r'\bExpansionTile\s*\('),
        argument: RegExp(r'\btrailing:'),
      ),
      isEmpty,
    );
  });

  test('every deletable chip names its delete glyph', () {
    expect(
      _callsMissing(
        call: RegExp(r'\b(Chip|InputChip)\s*\('),
        argument: RegExp(r'\bdeleteIcon:'),
        onlyWhen: RegExp(r'\bonDeleted:'),
      ),
      isEmpty,
    );
  });

  test('date pickers name both entry mode glyphs', () {
    expect(
      _callsMissing(
        call: RegExp(r'\bshowDatePicker\s*\('),
        argument: RegExp(
          r'^(?=[\s\S]*\bswitchToInputEntryModeIcon:)'
          r'(?=[\s\S]*\bswitchToCalendarEntryModeIcon:)',
        ),
      ),
      isEmpty,
    );
  });

  test('time pickers name both entry mode glyphs', () {
    expect(
      _callsMissing(
        call: RegExp(r'\bshowTimePicker\s*\('),
        argument: RegExp(
          r'^(?=[\s\S]*\bswitchToInputEntryModeIcon:)'
          r'(?=[\s\S]*\bswitchToTimerEntryModeIcon:)',
        ),
      ),
      isEmpty,
    );
  });
}
