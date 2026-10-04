/// Application theme orchestrator providing unified design system.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Central theme orchestrator combining colors, typography, and component themes.
class AppTheme {
  AppTheme._();

  /// Creates the complete light theme for the application.
  static ThemeData get lightTheme => createTheme(AppColors.lightColorScheme);

  /// Creates the complete dark theme for the application.
  static ThemeData get darkTheme => createTheme(AppColors.darkColorScheme);

  /// Creates theme configuration from color scheme.
  ///
  /// The theme is the same every day of the year: no colour is computed at
  /// runtime (tokens.json:522).
  static ThemeData createTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTextStyles.createTextTheme(),

      visualDensity: VisualDensity.adaptivePlatformDensity,

      // P7-U08: the framework back and close buttons draw the Butlery
      // glyphs (beslutslogg.md:9, B-02; plattformsmatris.md:75), in the
      // ambient IconTheme colour of the bar they sit in.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const ButleryIcon(ButleryIcons.back),
        closeButtonIconBuilder: (_) => const ButleryIcon(ButleryIcons.close),
      ),

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

      // BUT-2185: a disabled DropdownButton draws its selected value in
      // disabledColor; the token is
      // text.disabled, the same as its disabled arrow.
      disabledColor: AppModeColors.textDisabled(colorScheme.brightness),

      // BUT-533: keyboard focus must be visible on cream surfaces. Material 3
      // default focus tint is ~12% primary, which renders near-invisible
      // against #F8F4E8. Rust accent at full alpha gives ≥5.3:1 contrast on
      // cream and ≥3:1 against the inner button surface — well over the
      // WCAG 1.4.11 (3:1) non-text floor. Per-component focus rings are
      // declared in button_themes / input_themes.
      focusColor: AppColors.rust,

      // BUT-2205: every ListTile paints a raised tile (listTileTheme), so the
      // default press and hover fill is the step on raised.
      highlightColor: ModeColors.of(colorScheme.brightness).pressedOnRaised,
      hoverColor: ModeColors.of(colorScheme.brightness).pressedOnRaised,

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
