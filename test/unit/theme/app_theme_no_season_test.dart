/// The app theme is the same all year (package 7, P7-C1).
///
/// The seasonal tint (BUT-347) computed colours at runtime from the month;
/// tokens.json:522 allows no colour outside the generated files, so it is
/// gone. The app wires the plain light and dark themes, and they do not
/// move with the clock.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

void main() {
  final october = DateTime(2026, 10, 15);
  final january = DateTime(2027, 1, 15);
  final july = DateTime(2026, 7, 15);

  ButleryColors ext(ThemeData t) => t.extension<ButleryColors>()!;

  for (final (name, theme, base, brightness) in [
    ('light', () => AppTheme.lightTheme, ButleryColors.light, Brightness.light),
    ('dark', () => AppTheme.darkTheme, ButleryColors.dark, Brightness.dark),
  ]) {
    test('$name theme is the same in October, January and July', () {
      final inOctober = withClock(Clock.fixed(october), theme);
      final inJanuary = withClock(Clock.fixed(january), theme);
      final inJuly = withClock(Clock.fixed(july), theme);

      // ThemeData has no value equality for every component theme, so the
      // parts a season could move are compared: the scheme and the extension.
      for (final t in [inOctober, inJanuary, inJuly]) {
        expect(t.colorScheme, inJuly.colorScheme);
        expect(t.focusColor, inJuly.focusColor);
        expect(identical(ext(t), base), isTrue);
        expect(
          ext(t).recipeCardBottomBorder,
          ModeColors.of(brightness).recipeCardBottomBorder,
        );
        expect(
          ext(t).categoryMeatFish,
          ModeColors.of(brightness).categoryMeatFish,
        );
      }
    });
  }

  test('the app and the admin app wire the plain themes', () {
    final app = File('lib/app/butlery_app.dart').readAsStringSync();
    expect(app, contains('theme: AppTheme.lightTheme,'));
    expect(app, contains('darkTheme: AppTheme.darkTheme,'));
    final admin = File('lib/admin_main.dart').readAsStringSync();
    expect(admin, contains('theme: AppTheme.lightTheme,'));
    for (final src in [app, admin]) {
      expect(src, isNot(contains('SeasonalAccentService')));
      expect(src, isNot(contains('ThemeWith(')));
    }
  });
}
