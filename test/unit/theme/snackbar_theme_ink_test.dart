/// The global snackbar theme is the ink snackbar (Komponentark v1:745-750;
/// produktbeslut PQ-09 = A, 2026-09-23). It replaces the square
/// inverseSurface snackbar of BUT-1243: the drawing has radius 8.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/feedback_themes.dart';

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    group('ink snackbar theme ($mode)', () {
      final t = theme.snackBarTheme;

      test('surface is surface.ink #24382C', () {
        expect(t.backgroundColor, const Color(0xFF24382C));
        expect(
          t.backgroundColor,
          mode == 'dark' ? AppColorsDark.forestGreen : AppColors.forestGreen,
        );
      });

      test('message is paper #F5F4ED, 13 px regular', () {
        expect(t.contentTextStyle?.color, const Color(0xFFF5F4ED));
        expect(t.contentTextStyle?.fontSize, 13);
        expect(t.contentTextStyle?.fontWeight, FontWeight.w400);
      });

      test('action is light saffron #E09D50 (text accent on ink)', () {
        expect(t.actionTextColor, AppColors.textAccentOnInk);
        expect(t.actionTextColor, const Color(0xFFE09D50));
        expect(
          FeedbackThemes.inkSnackBarActionStyle.fontWeight,
          FontWeight.w700,
        );
      });

      test('radius 8, floating, no shadow', () {
        final shape = t.shape! as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          BorderRadius.circular(AppDimensions.radiusControl),
        );
        expect(t.behavior, SnackBarBehavior.floating);
        expect(t.elevation, 0);
      });

      test('edge: none in light, 1 px border.subtle in dark', () {
        final side = (t.shape! as RoundedRectangleBorder).side;
        if (mode == 'dark') {
          expect(side.color, AppColorsDark.creamDarker);
          expect(side.color, const Color(0x2EF5F4ED));
          expect(side.width, 1);
        } else {
          expect(side, BorderSide.none);
        }
      });
    });
  }
}
