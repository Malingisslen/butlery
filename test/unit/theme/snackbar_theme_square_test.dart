/// BUT-1243: pins the global snackbar contract — SQUARE shape (the
/// design-language rule) per mockup §4.18. SnackBars must inherit the
/// square shape from the theme; the per-call rounded shape override
/// was deleted in the same change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/components/feedback_themes.dart';

void main() {
  group('global snackBarTheme (BUT-1243)', () {
    test('is square — no border radius in light or dark', () {
      for (final brightness in Brightness.values) {
        final cs = ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        );
        final theme = FeedbackThemes.snackBarTheme(cs);

        expect(theme.shape, isA<RoundedRectangleBorder>());
        final shape = theme.shape! as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          BorderRadius.zero,
          reason:
              'SQUARE-everywhere design rule ($brightness): new '
              'snackbars must not silently render rounded corners — that '
              'was the BUT-1243 bug.',
        );
      }
    });

    test('floating behavior is preserved', () {
      final cs = ColorScheme.fromSeed(seedColor: Colors.green);
      final theme = FeedbackThemes.snackBarTheme(cs);

      expect(
        theme.behavior,
        SnackBarBehavior.floating,
        reason: 'Floating behavior must not regress while fixing shape.',
      );
    });

    test('background is inverseSurface (forestGreenDark in light scheme)', () {
      final cs = ColorScheme.fromSeed(seedColor: Colors.green);
      final theme = FeedbackThemes.snackBarTheme(cs);

      expect(
        theme.backgroundColor,
        cs.inverseSurface,
        reason:
            'Mockup §4.18: toast renders on green-dark background — '
            'cs.inverseSurface maps to forestGreenDark in the app light '
            'scheme and stays scheme-correct in dark mode.',
      );
    });
  });
}
