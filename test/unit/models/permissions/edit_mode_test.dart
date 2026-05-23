/// Unit tests for EditMode + EditModeExtension.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/permissions/edit_mode.dart';

void main() {
  group('canEdit', () {
    test('owner / collaborative / edit allow editing', () {
      expect(EditMode.owner.canEdit, isTrue);
      expect(EditMode.collaborative.canEdit, isTrue);
      expect(EditMode.edit.canEdit, isTrue);
    });

    test('readOnlyWithFork / noAccess / view do NOT allow editing', () {
      expect(EditMode.readOnlyWithFork.canEdit, isFalse);
      expect(EditMode.noAccess.canEdit, isFalse);
      expect(EditMode.view.canEdit, isFalse);
    });
  });

  group('canFork', () {
    test('true for every mode except noAccess', () {
      for (final m in EditMode.values) {
        if (m == EditMode.noAccess) {
          expect(m.canFork, isFalse, reason: m.name);
        } else {
          expect(m.canFork, isTrue, reason: m.name);
        }
      }
    });
  });

  group('showForkButton', () {
    test('only readOnlyWithFork + collaborative show the fork button', () {
      expect(EditMode.readOnlyWithFork.showForkButton, isTrue);
      expect(EditMode.collaborative.showForkButton, isTrue);

      expect(EditMode.owner.showForkButton, isFalse);
      expect(EditMode.edit.showForkButton, isFalse);
      expect(EditMode.view.showForkButton, isFalse);
      expect(EditMode.noAccess.showForkButton, isFalse);
    });
  });

  group('description', () {
    test('returns the matching AppLocale string per mode', () {
      final l = AppLocale.current;
      expect(EditMode.owner.description, l.editModeOwner);
      expect(EditMode.collaborative.description, l.editModeCollaborative);
      expect(EditMode.readOnlyWithFork.description, l.editModeReadOnlyWithFork);
      expect(EditMode.noAccess.description, l.editModeNoAccess);
      expect(EditMode.edit.description, l.editModeEdit);
      expect(EditMode.view.description, l.editModeView);
    });
  });
}
