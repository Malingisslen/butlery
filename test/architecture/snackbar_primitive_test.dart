// BUT-2371: every snackbar is built by the primitive.
//
// SnackBarUtils and CapturedSnackBars own the ink look, "Stäng" instead of
// a bare text, the alert role on a failure and the screen-reader rule. A
// hand-built `SnackBar(` skips all four, which is how they ended up as plain
// text with no way to close them.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The files allowed to construct a SnackBar.
const _primitives = {
  'lib/core/utils/snackbar_utils.dart',
  'lib/core/utils/captured_snackbars.dart',
};

/// Files another track of the design review owns, with their count. A count
/// may only fall; the owner removes the row when the file is moved over.
const _pending = {
  // Spår D1 (BUT-2370) owns the admin views.
  'lib/views/admin/feedback_inbox_view.dart': 2,
  // Spår D2 (BUT-2373) owns the sheets.
  'lib/views/recipe_detail/recipe_detail_content.dart': 1,
  'lib/widgets/social/ping_compose_sheet.dart': 1,
};

final _constructor = RegExp(r'(?<![\w.])SnackBar\(');

void main() {
  test('no SnackBar is built outside the primitive', () {
    final counts = <String, int>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/l10n/') || _primitives.contains(path)) continue;
      final n = _constructor.allMatches(entity.readAsStringSync()).length;
      if (n > 0) counts[path] = n;
    }

    final offenders = [
      for (final MapEntry(key: path, value: n) in counts.entries)
        if (n > (_pending[path] ?? 0)) '$path: $n',
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'Show a snackbar with SnackBarUtils (showSuccess, showInfo, '
          'showWarning, showFailure, showUndo), or with '
          'CapturedSnackBars.capture(context) when the context will be gone.',
    );

    final stale = [
      for (final MapEntry(key: path, value: n) in _pending.entries)
        if ((counts[path] ?? 0) < n) '$path: ${counts[path] ?? 0} < $n',
    ];
    expect(
      stale,
      isEmpty,
      reason: 'Lower the count in _pending, or remove the row at 0.',
    );
  });
}
