// Komponentark v1 §11: a text field's label stands above the box
// (LabeledField or StyledInput), never floating in its edge, and an error
// carries a glyph. The first test counts the TextField and TextFormField
// calls in lib/ whose own InputDecoration still sets labelText. The files
// below have not moved yet; the count for each is pinned, so a new floating
// label reddens, and so does a move that forgets to shrink the list.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _notYetMoved = <String, int>{
  'lib/admin_main.dart': 2,
  'lib/views/auth/mfa_challenge_view.dart': 2,
  'lib/views/personal_tags/personal_tag_dialogs.dart': 5,
  'lib/views/settings/account_security_view.dart': 5,
  'lib/views/settings/mfa_enrollment_forms.dart': 3,
  'lib/widgets/common/input/instruction_editor.dart': 1,
};

/// Strips comments so a sentence that names a field is not counted.
String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// The whole argument list of the call whose `(` is at [open].
String _arguments(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0) return code.substring(open, i + 1);
  }
  return code.substring(open);
}

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

int _floatingLabels(String code) {
  final field = RegExp(r'\bTextFormField\s*\(|\bTextField\s*\(');
  final decoration = RegExp(
    r'\bdecoration\s*:\s*(const\s+)?InputDecoration\s*\(',
  );
  var count = 0;
  for (final m in field.allMatches(code)) {
    final args = _arguments(code, m.end - 1);
    for (final d in decoration.allMatches(args)) {
      if (RegExp(r'\blabelText\s*:').hasMatch(_ownArguments(args, d.end - 1))) {
        count++;
      }
    }
  }
  return count;
}

/// LabeledField calls whose TextFormField validates but draws its error
/// without the glyph (no errorBuilder).
int _errorsWithoutGlyph(String code) {
  final frame = RegExp(r'\bLabeledField\s*\(');
  var count = 0;
  for (final m in frame.allMatches(code)) {
    final args = _arguments(code, m.end - 1);
    if (args.contains(RegExp(r'\bTextFormField\s*\(')) &&
        args.contains(RegExp(r'\bvalidator\s*:')) &&
        !args.contains(RegExp(r'\berrorBuilder\s*:'))) {
      count++;
    }
  }
  return count;
}

void main() {
  test('text field labels stand above the box, not in its edge', () {
    final found = <String, int>{};
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where((p) => p.endsWith('.dart') && !p.endsWith('.g.dart'));
    for (final path in files) {
      final n = _floatingLabels(_code(path));
      if (n > 0) found[path] = n;
    }
    expect(
      found,
      _notYetMoved,
      reason:
          'A text field in lib/ floats its label (labelText). Put the field '
          'in LabeledField(label: ...) or use StyledInput. If you moved one, '
          'lower or remove its line in _notYetMoved.',
    );
  });

  test('a validated field in LabeledField draws its error with the glyph', () {
    final missing = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where((p) => p.endsWith('.dart'));
    for (final path in files) {
      if (_errorsWithoutGlyph(_code(path)) > 0) missing.add(path);
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Give the TextFormField errorBuilder: FieldErrorLine.builder, so '
          'its error is not shown by colour and text alone.',
    );
  });

  test('the glyph check sees a validator without errorBuilder', () {
    expect(
      _errorsWithoutGlyph('''
        LabeledField(label: 'Namn', child: TextFormField(validator: v));
        LabeledField(label: 'År', child: TextFormField(
          validator: v, errorBuilder: FieldErrorLine.builder));
        LabeledField(label: 'Not', child: TextField());
      '''),
      1,
    );
  });

  test('the counter sees a floating label and ignores one above the box', () {
    expect(
      _floatingLabels('''
        TextFormField(decoration: InputDecoration(labelText: 'Namn'));
        TextField(decoration: const InputDecoration(labelText: 'År'));
      '''),
      2,
    );
    expect(
      _floatingLabels('''
        LabeledField(label: 'Namn', child: TextFormField(
          decoration: InputDecoration(hintText: 'T.ex.'),
        ));
        DropdownButtonFormField(decoration: InputDecoration(labelText: 'Typ'));
      '''),
      0,
    );
  });
}
