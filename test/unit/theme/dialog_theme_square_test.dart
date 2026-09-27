/// BUT-1237 and P7-U04: pins the global dialog contract. The shape takes
/// the control radius, 8 (Komponentark v1:336 draws the dialog box with
/// border-radius 8px; tokens.json space.radius.control), and the background
/// is `cs.surface`. Dialogs inherit both from the theme; no dialog sets its
/// own `shape:`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/components/navigation_themes.dart';

void main() {
  group('global dialogTheme (BUT-1237)', () {
    test('takes the control radius, 8, in light and dark', () {
      for (final brightness in Brightness.values) {
        final cs = ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        );
        final theme = NavigationThemes.dialogTheme(cs);

        expect(theme.shape, isA<RoundedRectangleBorder>());
        final shape = theme.shape! as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          const BorderRadius.all(Radius.circular(8)),
          reason:
              'Komponentark v1:336 ($brightness): the dialog box is drawn '
              'with border-radius 8px.',
        );
      }
    });

    test('background is the scheme surface (cream in the light scheme)', () {
      final cs = ColorScheme.fromSeed(seedColor: Colors.green);
      final theme = NavigationThemes.dialogTheme(cs);

      expect(
        theme.backgroundColor,
        cs.surface,
        reason:
            'Mockup spec §4.17: dialog box renders on cream — '
            'cs.surface maps to cream in the app light scheme and stays '
            'scheme-correct in dark mode.',
      );
    });
  });
}
