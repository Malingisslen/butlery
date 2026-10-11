// Komponentark v1 §11: a text field's label stands above the box
// (LabeledField or StyledInput), never floating in its edge. This test
// counts the TextField and TextFormField calls in lib/ whose own
// InputDecoration still sets labelText. The files below have not moved yet;
// the count for each is pinned, so a new floating label reddens, and so does
// a move that forgets to shrink the list.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _notYetMoved = <String, int>{
  'lib/admin_main.dart': 2,
  'lib/views/auth/mfa_challenge_view.dart': 2,
  'lib/views/auth/set_new_password_view.dart': 2,
  'lib/views/auth_view.dart': 1,
  'lib/views/messaging/conversation_group_detail_view.dart': 1,
  'lib/views/pantry/add_pantry_item_sheet.dart': 3,
  'lib/views/personal_tags/personal_tag_dialogs.dart': 5,
  'lib/views/quick_capture_view.dart': 1,
  'lib/views/recipe_detail/recipe_detail_comments.dart': 1,
  'lib/views/settings/account_security_view.dart': 5,
  'lib/views/settings/mfa_enrollment_forms.dart': 3,
  'lib/widgets/common/input/instruction_editor.dart': 1,
  'lib/widgets/common/menu_persistence/menu_save_dialog.dart': 3,
  'lib/widgets/common/profile/dialogs/profile_dialogs.dart': 2,
  'lib/widgets/import/assisted_import_dialog.dart': 4,
  'lib/widgets/messaging/poll_creation_dialog.dart': 2,
  'lib/widgets/social/groups/edit_group_dialog.dart': 2,
  'lib/widgets/tagging/personal_tag_rule_dialog.dart': 1,
  'lib/widgets/tagging/rule_builder_sheet.dart': 1,
  'lib/widgets/tagging/tag_editor_dialog.dart': 1,
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
