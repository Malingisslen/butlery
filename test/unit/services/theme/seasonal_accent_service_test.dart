/// Unit tests for SeasonalAccentService — verifies deterministic season
/// mapping and that each season's override produces the expected shifts in
/// the rust/cream families of ButleryColors.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock/clock.dart';

import 'package:butlery/services/theme/seasonal_accent_service.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

void main() {
  group('SeasonalAccentService.seasonOf', () {
    const service = SeasonalAccentService();

    test('Jan 15 → winter', () {
      expect(service.seasonOf(DateTime(2026, 1, 15)), Season.winter);
    });

    test('Apr 15 → spring', () {
      expect(service.seasonOf(DateTime(2026, 4, 15)), Season.spring);
    });

    test('Jul 15 → summer', () {
      expect(service.seasonOf(DateTime(2026, 7, 15)), Season.summer);
    });

    test('Oct 15 → autumn', () {
      expect(service.seasonOf(DateTime(2026, 10, 15)), Season.autumn);
    });

    test('covers every month', () {
      final expected = <int, Season>{
        1: Season.winter,
        2: Season.winter,
        3: Season.spring,
        4: Season.spring,
        5: Season.spring,
        6: Season.summer,
        7: Season.summer,
        8: Season.summer,
        9: Season.autumn,
        10: Season.autumn,
        11: Season.autumn,
        12: Season.winter,
      };
      for (final entry in expected.entries) {
        expect(
          service.seasonOf(DateTime(2026, entry.key, 15)),
          entry.value,
          reason: 'month ${entry.key} should map to ${entry.value}',
        );
      }
    });
  });

  group('SeasonalAccentService.getAccentsFor', () {
    const service = SeasonalAccentService();
    const base = ButleryColors.light;

    test('summer (Jul 15) returns identity palette', () {
      withClock(Clock.fixed(DateTime(2026, 7, 15)), () {
        final result = service.getAccentsFor(clock.now());

        expect(result.navAccent, base.navAccent);
        expect(result.recipeCardBottomBorder, base.recipeCardBottomBorder);
        expect(result.categoryMeatFish, base.categoryMeatFish);
        expect(result.sharedRecipeBackground, base.sharedRecipeBackground);
      });
    });

    test('spring (Apr 15) shifts rust toward sage/olive (hue increases)', () {
      withClock(Clock.fixed(DateTime(2026, 4, 15)), () {
        final result = service.getAccentsFor(clock.now());

        final baseHue = HSLColor.fromColor(base.navAccent).hue;
        final resultHue = HSLColor.fromColor(result.navAccent).hue;

        // Rust (#8B5A3C) sits at ~22°; sage/olive direction is higher hue.
        expect(resultHue, greaterThan(baseHue));
        expect(resultHue - baseHue, closeTo(28, 2));

        // Saturation should drop (softer).
        expect(
          HSLColor.fromColor(result.navAccent).saturation,
          lessThan(HSLColor.fromColor(base.navAccent).saturation),
        );

        // Non-rust fields untouched.
        expect(result.sharedRecipeBackground, base.sharedRecipeBackground);
      });
    });

    test('autumn (Oct 15) deepens rust toward amber/gold (hue decreases)', () {
      withClock(Clock.fixed(DateTime(2026, 10, 15)), () {
        final result = service.getAccentsFor(clock.now());

        final baseHsl = HSLColor.fromColor(base.navAccent);
        final resultHsl = HSLColor.fromColor(result.navAccent);

        // Hue rotates negative (toward gold/amber — lower hue angle).
        expect(resultHsl.hue, lessThan(baseHsl.hue));

        // Saturation bumps up and lightness drops slightly (deeper).
        expect(resultHsl.saturation, greaterThan(baseHsl.saturation));
        expect(resultHsl.lightness, lessThan(baseHsl.lightness));
      });
    });

    test('winter (Jan 15) mutes rust and cools the cream background', () {
      withClock(Clock.fixed(DateTime(2026, 1, 15)), () {
        final result = service.getAccentsFor(clock.now());

        final baseRust = HSLColor.fromColor(base.navAccent);
        final resultRust = HSLColor.fromColor(result.navAccent);

        // Rust becomes muted/dusty.
        expect(resultRust.saturation, lessThan(baseRust.saturation));
        expect(resultRust.lightness, greaterThan(baseRust.lightness));

        // Shared-recipe cream shifts hue (cooler cast).
        expect(
          result.sharedRecipeBackground,
          isNot(equals(base.sharedRecipeBackground)),
        );
      });
    });

    test('uses package:clock for determinism', () {
      // Same fixed clock → identical palette on repeat calls.
      withClock(Clock.fixed(DateTime(2026, 4, 15)), () {
        final first = service.getAccentsFor(clock.now());
        final second = service.getAccentsFor(clock.now());
        expect(first.navAccent, second.navAccent);
      });
    });

    test('honors injected base palette (e.g. dark mode)', () {
      withClock(Clock.fixed(DateTime(2026, 7, 15)), () {
        final result = service.getAccentsFor(
          clock.now(),
          base: ButleryColors.dark,
        );
        // Summer = identity, so dark palette passes through unchanged.
        expect(result.navAccent, ButleryColors.dark.navAccent);
      });
    });
  });
}
