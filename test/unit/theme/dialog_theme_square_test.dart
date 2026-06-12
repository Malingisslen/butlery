/// BUT-1237: pins the global dialog contract — SQUARE shape (the
/// design-language rule) and `cs.surface` background (cream in light mode,
/// mockup spec §4.17). Dialogs must inherit these from the theme; the four
/// per-dialog `shape:` overrides this rule replaced were deleted in the
/// same change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/components/navigation_themes.dart';

void main() {
  group('global dialogTheme (BUT-1237)', () {
    test('is square — no border radius in light or dark', () {
      for (final brightness in Brightness.values) {
        final cs = ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        );
        final theme = NavigationThemes.dialogTheme(cs);

        expect(theme.shape, isA<RoundedRectangleBorder>());
        final shape = theme.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.zero,
            reason: 'SQUARE-everywhere design rule ($brightness): new '
                'dialogs must not silently render rounded corners — that '
                'was the BUT-1237 bug.');
      }
    });

    test('background is the scheme surface (cream in the light scheme)', () {
      final cs = ColorScheme.fromSeed(seedColor: Colors.green);
      final theme = NavigationThemes.dialogTheme(cs);

      expect(theme.backgroundColor, cs.surface,
          reason: 'Mockup spec §4.17: dialog box renders on cream — '
              'cs.surface maps to cream in the app light scheme and stays '
              'scheme-correct in dark mode.');
    });
  });
}
