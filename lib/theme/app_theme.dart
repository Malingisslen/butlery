/// Application theme orchestrator providing unified design system.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/component_themes.dart';

/// Central theme orchestrator combining colors, typography, and component themes.
class AppTheme {
  AppTheme._();

  /// Creates the complete light theme for the application.
  static ThemeData get lightTheme => createTheme(AppColors.lightColorScheme);

  /// Creates the complete dark theme for the application.
  static ThemeData get darkTheme => createTheme(AppColors.darkColorScheme);

  /// Light theme with an optional seasonal accent override.
  ///
  /// When [accent] is null, behaves identically to [lightTheme]. Used by
  /// `main.dart` to thread `SeasonalAccentService` output into `MaterialApp`.
  static ThemeData lightThemeWith(ButleryColors? accent) =>
      createTheme(AppColors.lightColorScheme, butleryColorsOverride: accent);

  /// Dark theme with an optional seasonal accent override. See [lightThemeWith].
  static ThemeData darkThemeWith(ButleryColors? accent) =>
      createTheme(AppColors.darkColorScheme, butleryColorsOverride: accent);

  /// Creates theme configuration from color scheme.
  ///
  /// [butleryColorsOverride] replaces the default `ButleryColors` extension
  /// — used by `SeasonalAccentService` to apply subtle month-based accents
  /// without duplicating the full theme pipeline.
  static ThemeData createTheme(
    ColorScheme colorScheme, {
    ButleryColors? butleryColorsOverride,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTextStyles.createTextTheme(),

      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Component themes — all ColorScheme-aware
      elevatedButtonTheme: ComponentThemes.elevatedButtonTheme(colorScheme),
      filledButtonTheme: ComponentThemes.filledButtonTheme(colorScheme),
      outlinedButtonTheme: ComponentThemes.outlinedButtonTheme(colorScheme),
      textButtonTheme: ComponentThemes.textButtonTheme(colorScheme),
      iconButtonTheme: ComponentThemes.iconButtonTheme(colorScheme),
      floatingActionButtonTheme: ComponentThemes.floatingActionButtonTheme(
        colorScheme,
      ),

      cardTheme: ComponentThemes.cardTheme(colorScheme),
      inputDecorationTheme: ComponentThemes.inputDecorationTheme(colorScheme),
      appBarTheme: ComponentThemes.appBarTheme(colorScheme),
      bottomNavigationBarTheme: ComponentThemes.bottomNavigationBarTheme(
        colorScheme,
      ),
      tabBarTheme: ComponentThemes.tabBarTheme(colorScheme),
      listTileTheme: ComponentThemes.listTileTheme(colorScheme),
      dialogTheme: ComponentThemes.dialogTheme(colorScheme),
      bottomSheetTheme: ComponentThemes.bottomSheetTheme(colorScheme),
      snackBarTheme: ComponentThemes.snackBarTheme(colorScheme),
      dividerTheme: ComponentThemes.dividerTheme(colorScheme),
      switchTheme: ComponentThemes.switchTheme(colorScheme),
      checkboxTheme: ComponentThemes.checkboxTheme(colorScheme),
      radioTheme: ComponentThemes.radioTheme(colorScheme),
      chipTheme: ComponentThemes.chipTheme(colorScheme),
      sliderTheme: ComponentThemes.sliderTheme(colorScheme),
      progressIndicatorTheme: ComponentThemes.progressIndicatorTheme(
        colorScheme,
      ),
      scrollbarTheme: ComponentThemes.scrollbarTheme(colorScheme),

      scaffoldBackgroundColor: colorScheme.surface,

      // BUT-533: keyboard focus must be visible on cream surfaces. Material 3
      // default focus tint is ~12% primary, which renders near-invisible
      // against #F8F4E8. Rust accent at full alpha gives ≥5.3:1 contrast on
      // cream and ≥3:1 against the inner button surface — well over the
      // WCAG 1.4.11 (3:1) non-text floor. Per-component focus rings are
      // declared in button_themes / input_themes.
      focusColor: AppColors.rust,
      highlightColor: AppColors.rust.withValues(alpha: 0.12),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      extensions: [
        butleryColorsOverride ??
            (isDark ? ButleryColors.dark : ButleryColors.light),
      ],
    );
  }
}
