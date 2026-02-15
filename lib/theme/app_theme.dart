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

  /// Creates a light theme with a dynamic color scheme.
  static ThemeData dynamicLightTheme(ColorScheme? dynamicScheme) {
    return createTheme(dynamicScheme ?? AppColors.lightColorScheme);
  }

  /// Creates a dark theme with a dynamic color scheme.
  static ThemeData dynamicDarkTheme(ColorScheme? dynamicScheme) {
    return createTheme(dynamicScheme ?? AppColors.darkColorScheme);
  }

  /// Creates theme configuration from color scheme.
  static ThemeData createTheme(ColorScheme colorScheme) {
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
      floatingActionButtonTheme:
          ComponentThemes.floatingActionButtonTheme(colorScheme),

      cardTheme: ComponentThemes.cardTheme(colorScheme),
      inputDecorationTheme: ComponentThemes.inputDecorationTheme(colorScheme),
      appBarTheme: ComponentThemes.appBarTheme(colorScheme),
      bottomNavigationBarTheme:
          ComponentThemes.bottomNavigationBarTheme(colorScheme),
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
      progressIndicatorTheme:
          ComponentThemes.progressIndicatorTheme(colorScheme),

      scaffoldBackgroundColor: colorScheme.surface,

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      extensions: [
        isDark ? ButleryColors.dark : ButleryColors.light,
      ],
    );
  }
}
