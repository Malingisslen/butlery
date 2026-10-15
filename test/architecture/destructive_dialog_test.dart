// BUT-2366: one destructive confirmation. Everything that asks before
// something is deleted, removed or left goes through
// DestructiveConfirmationDialog (lib/widgets/common/dialogs/), which draws the
// red button, its onError label and Avbryt the same way every time. This test
// reddens on the next raw AlertDialog with its own error-coloured button.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Raw dialogs still allowed a red button, with how many and why. The list
/// may only shrink.
const _allowed = <String, ({int count, String why})>{
  // Signing out with unsynced changes is a choice between waiting and
  // discarding, not a delete confirmation: waiting is drawn as the answer.
  'lib/widgets/common/profile/dialogs/profile_dialogs.dart': (
    count: 1,
    why: 'sign-out with unsynced changes',
  ),
  // Multi-choice dialogs, not confirmations: the red text button is one
  // choice among several, as drawn in #dialogosparat.
  'lib/widgets/common/dialogs/draft_recovery_dialog.dart': (
    count: 1,
    why: 'discard-all choice among the drafts',
  ),
};

final _redButton = RegExp(
  r'(backgroundColor|foregroundColor)\s*:\s*[^,\n]*\berror\b'
  r'|child:\s*ErrorText\(',
);

/// The source of the call starting at [start], up to its closing paren.
String _call(String source, int start) {
  var depth = 0;
  for (var i = source.indexOf('(', start); i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return source.substring(start, i + 1);
  }
  return source.substring(start);
}

Map<String, int> _rawRedDialogs() {
  final found = <String, int>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.startsWith('lib/l10n/')) continue;
    final source = entity.readAsStringSync();
    for (final m in RegExp(r'\bAlertDialog\(').allMatches(source)) {
      if (_redButton.hasMatch(_call(source, m.start))) {
        found[path] = (found[path] ?? 0) + 1;
      }
    }
  }
  return found;
}

void main() {
  test('no raw AlertDialog draws its own red button', () {
    final offenders = <String>[];
    _rawRedDialogs().forEach((path, count) {
      final allowed = _allowed[path]?.count ?? 0;
      if (count > allowed) offenders.add('$path: $count (allowed $allowed)');
    });
    expect(
      offenders,
      isEmpty,
      reason:
          'Ask with DestructiveConfirmationDialog.show (or a '
          'CommonDialogActions preset) and name what disappears on its '
          'button instead of styling a raw AlertDialog.',
    );
  });

  test('the allow-list only names dialogs that still exist', () {
    final found = _rawRedDialogs();
    final stale = [
      for (final e in _allowed.entries)
        if ((found[e.key] ?? 0) < e.value.count)
          '${e.key}: ${found[e.key] ?? 0} left, list says ${e.value.count}',
    ];
    expect(
      stale,
      isEmpty,
      reason: 'Lower the count (or drop the row) when a dialog moves.',
    );
  });
}
