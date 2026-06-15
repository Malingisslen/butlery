/// BUT-964: pins the global FloatingActionButton contract — SQUARE shape, the
/// design-language rule. Before this, the FAB theme used `CircleBorder`, which
/// rendered the friends-group, messaging, and friend-request FABs as round
/// circles in violation of the square-everywhere rule. This test guards against
/// a silent regression back to a rounded/circular FAB.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/components/button_themes.dart';

void main() {
  group('global floatingActionButtonTheme (BUT-964)', () {
    test('is square — RoundedRectangleBorder with zero radius in both modes',
        () {
      for (final brightness in Brightness.values) {
        final cs = ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        );
        final theme = ButtonThemes.floatingActionButtonTheme(cs);

        expect(theme.shape, isA<RoundedRectangleBorder>(),
            reason: 'SQUARE-everywhere ($brightness): the FAB must not be a '
                'CircleBorder — that was the BUT-964 inconsistency.');
        final shape = theme.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.zero,
            reason: 'SQUARE-everywhere ($brightness): FAB corners must be '
                'sharp, matching every other create-action surface.');
      }
    });
  });
}
