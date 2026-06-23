/// Seasonal accent service — applies subtle month-based color shifts to the
/// Butlery palette so the UI feels quietly attuned to the time of year.
///
/// Deterministic and pure: same `DateTime` in → same `ButleryColors` out.
/// No auth, no async, no network — intentionally a plain class rather than
/// a `BaseService` subclass (matches the `ThemeService` precedent).
///
/// Season mapping (northern-hemisphere calendar):
/// - Spring (Mar–May) → rust family shifted toward sage/olive
/// - Summer (Jun–Aug) → unchanged (identity)
/// - Autumn (Sep–Nov) → rust family shifted toward warm amber
/// - Winter (Dec–Feb) → rust muted, cream tinted cool
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/butlery_colors_extension.dart';

/// Four-way season enumeration keyed off month-of-year.
enum Season { spring, summer, autumn, winter }

/// Deterministic seasonal accent overrider for `ButleryColors`.
class SeasonalAccentService {
  const SeasonalAccentService();

  /// Returns the [ButleryColors] palette for [now], optionally overriding
  /// accent-family fields of [base] (defaults to `ButleryColors.light`).
  ///
  /// Callers should feed this into `ThemeData.extensions` so widgets that
  /// pull from `context.butleryColors` pick up the seasonal tint.
  ButleryColors getAccentsFor(DateTime now, {ButleryColors? base}) {
    final palette = base ?? ButleryColors.light;
    switch (seasonOf(now)) {
      case Season.spring:
        return _spring(palette);
      case Season.summer:
        return palette;
      case Season.autumn:
        return _autumn(palette);
      case Season.winter:
        return _winter(palette);
    }
  }

  /// Exposed for tests and callers that need the season without the palette.
  Season seasonOf(DateTime now) {
    final m = now.month;
    if (m >= 3 && m <= 5) return Season.spring;
    if (m >= 6 && m <= 8) return Season.summer;
    if (m >= 9 && m <= 11) return Season.autumn;
    return Season.winter;
  }

  // Spring: soft-green lean — rust rotated +28° toward olive/sage, slight
  // desaturation. Keeps the warm undertone so it still reads as Butlery.
  ButleryColors _spring(ButleryColors base) {
    return base.copyWith(
      navAccent: _shift(base.navAccent, hue: 28, sat: -0.08),
      recipeCardBottomBorder: _shift(
        base.recipeCardBottomBorder,
        hue: 26,
        sat: -0.06,
      ),
      categoryMeatFish: _shift(base.categoryMeatFish, hue: 28, sat: -0.08),
    );
  }

  // Autumn: amber warmth — rust rotated -10° toward gold, +6% saturation,
  // slightly deeper. Makes the rust accents feel like fallen leaves.
  ButleryColors _autumn(ButleryColors base) {
    return base.copyWith(
      navAccent: _shift(base.navAccent, hue: -10, sat: 0.06, light: -0.02),
      recipeCardBottomBorder: _shift(
        base.recipeCardBottomBorder,
        hue: -8,
        sat: 0.05,
      ),
      categoryMeatFish: _shift(
        base.categoryMeatFish,
        hue: -10,
        sat: 0.06,
        light: -0.02,
      ),
    );
  }

  // Winter: cool-cream — rust muted/dusty (-14% sat, +3% lightness), the
  // shared-recipe cream background gains a faint blue cast.
  ButleryColors _winter(ButleryColors base) {
    return base.copyWith(
      navAccent: _shift(base.navAccent, sat: -0.14, light: 0.03),
      recipeCardBottomBorder: _shift(
        base.recipeCardBottomBorder,
        sat: -0.14,
        light: 0.03,
      ),
      categoryMeatFish: _shift(base.categoryMeatFish, sat: -0.14, light: 0.03),
      sharedRecipeBackground: _shift(
        base.sharedRecipeBackground,
        hue: 30,
        sat: 0.02,
      ),
    );
  }

  // HSL tweak helper — delta values are additive (hue in degrees, sat/light
  // in 0–1). Clamped so we never produce invalid HSL.
  Color _shift(Color c, {double hue = 0, double sat = 0, double light = 0}) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withHue((hsl.hue + hue) % 360)
        .withSaturation((hsl.saturation + sat).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + light).clamp(0.0, 1.0))
        .toColor();
  }
}
