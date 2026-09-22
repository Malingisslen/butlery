// P3-U1: undo belongs to the operation, classed by recoverability
// (produktregler.md:125-140, § 2.4, BUT-954).
//
// Every class-1 undo goes through SnackBarUtils.showUndo / UndoSnackBar, which
// own the 7 s window and the "Ångra" label. A hand-rolled SnackBarAction with
// `commonUndo` anywhere else is how the copies drifted to 4, 5 and 7 seconds,
// so this test reddens on the next one.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one file allowed to read `commonUndo` for a snackbar.
const _primitive = 'lib/core/utils/snackbar_utils.dart';

/// "Dölj delat innehåll" undo: the `dismiss` operation is not in the
/// produktregler.md:129-136 table and is classed nowhere, so these keep their
/// current snackbar until that is decided. Not to be grown.
const _unclassifiedDismiss = {
  'lib/views/social/menu_preview_view.dart',
  'lib/views/social/shared_with_me/shared_content_actions.dart',
};

void main() {
  test('every undo label is read by the primitive alone', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/l10n/')) continue;
      if (path == _primitive || _unclassifiedDismiss.contains(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('.commonUndo')) {
          offenders.add('$path:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Class-1 undo must use SnackBarUtils.showUndo or '
          'UndoSnackBar.capture(context).show — they fix the window to '
          'kUndoWindow (7 s) and the label to commonUndo.',
    );
  });

  test('no deferred commit runs on a timer of its own', () {
    // A delayed-commit delete must commit when its snackbar closes. Flutter
    // starts a snackbar's timer after the entrance animation and only at the
    // head of the queue, so any parallel Timer, even one reading kUndoWindow,
    // lands while Ångra is still on screen.
    for (final path in [
      'lib/viewmodels/recipe_list/recipe_delete_manager.dart',
      'lib/views/recipe_detail/handlers/recipe_management_handler.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        RegExp(r'Timer\(').hasMatch(source),
        isFalse,
        reason: '$path must commit when the undo snackbar closes',
      );
    }
    for (final path in [
      'lib/views/recipe_detail/handlers/recipe_management_handler.dart',
      'lib/views/mina_recept_view.dart',
      'lib/views/mina_recept/selection_app_bar.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('kUndoWindow')),
        reason: '$path must not time its own commit',
      );
      expect(
        RegExp(r'show(Undo)?Deferred\(').hasMatch(source),
        isTrue,
        reason: '$path commits through UndoSnackBar.showDeferred',
      );
    }
  });
}
