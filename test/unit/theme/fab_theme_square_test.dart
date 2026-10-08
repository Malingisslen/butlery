/// P7-U04: pins the global FloatingActionButton contract. The create button
/// is round: the central plus in the bottom row is a 56 dp circle drawn with
/// border-radius 999 (Komponentark v1:665; tokens.json space.radius.pill).
/// This reverses BUT-964's square FAB, which predates the drawing. An
/// extended create button is the same shape stretched to fit its label: a
/// pill. Radius does not depend on the mode, so both modes are checked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/components/button_themes.dart';

void main() {
  group('global floatingActionButtonTheme (P7-U04)', () {
    test('is a circle in both modes (Komponentark v1:665)', () {
      for (final brightness in Brightness.values) {
        final cs = ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        );
        final theme = ButtonThemes.floatingActionButtonTheme(cs);

        expect(theme.shape, isA<CircleBorder>(), reason: '$brightness');
      }
    });

    test('the extended create button is a pill in both modes', () {
      for (final brightness in Brightness.values) {
        final cs = ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        );
        final shape = ButtonThemes.extendedFabStyle(
          cs,
        ).shape?.resolve(<WidgetState>{});

        expect(shape, isA<RoundedRectangleBorder>(), reason: '$brightness');
        expect(
          (shape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.all(Radius.circular(999)),
          reason: '$brightness',
        );
      }
    });
  });
}
