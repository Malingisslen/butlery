// Komponentark v1:657: a text field shows focus with the ring outside the
// box, and its edge never changes width. The ring comes from LabeledField
// or ButleryFocusRing; the input theme draws no focus edge of its own. This
// test finds every TextField and TextFormField call in lib/ that stands
// outside both.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The field components, which build the field first and put it in the
/// ring further down the same build method.
const _components = <String>{
  'lib/widgets/common/input/styled_input.dart',
  'lib/widgets/common/input/butlery_composer_field.dart',
  'lib/widgets/common/input/butlery_row_field.dart',
  'lib/widgets/common/input/butlery_code_field.dart',
  'lib/widgets/common/butlery_search_box.dart',
};

/// Strips comments so a sentence that names a field is not counted.
String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// The index just past the end of the call whose `(` is at [open].
int _close(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0) return i + 1;
  }
  return code.length;
}

/// Text field calls in [code] that no ring call encloses.
int _fieldsOutsideRing(String code) {
  final rings = [
    for (final m in RegExp(
      r'\b(LabeledField|ButleryFocusRing)\s*\(',
    ).allMatches(code))
      (m.start, _close(code, m.end - 1)),
  ];
  var count = 0;
  for (final m in RegExp(
    r'\bTextFormField\s*\(|\bTextField\s*\(',
  ).allMatches(code)) {
    if (!rings.any((r) => r.$1 < m.start && m.start < r.$2)) count++;
  }
  return count;
}

void main() {
  test('every text field in lib/ stands in the focus ring', () {
    final found = <String, int>{};
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where((p) => p.endsWith('.dart') && !p.endsWith('.g.dart'))
        .where((p) => !_components.contains(p));
    for (final path in files) {
      final n = _fieldsOutsideRing(_code(path));
      if (n > 0) found[path] = n;
    }
    expect(
      found,
      isEmpty,
      reason:
          'A TextField or TextFormField stands outside LabeledField and '
          'ButleryFocusRing, so keyboard focus draws nothing on it. Put it '
          'in LabeledField(child: ...) or use StyledInput.',
    );
  });

  test('the check sees a field outside the ring and none inside', () {
    expect(
      _fieldsOutsideRing('''
        TextField(decoration: InputDecoration(hintText: 'a'));
        LabeledField(label: 'Namn', child: TextFormField());
        ButleryFocusRing(child: Row(children: [TextField()]));
        Column(children: [TextFormField()]);
      '''),
      2,
    );
  });
}
