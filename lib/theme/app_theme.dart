/// Application theme orchestrator providing unified design system.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';

/// Central theme orchestrator combining colors, typography, and component themes.
class AppTheme {
  /// Private constructor to prevent instantiation of utility class
  AppTheme._();

  // ===== MAIN THEME FACTORY =====

  /// Creates the complete light theme for the application.
  static ThemeData get lightTheme => _createTheme(AppColors.lightColorScheme);

  /// Creates theme configuration from color scheme.
  static ThemeData _createTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTextStyles.createTextTheme(),
      
      // Visual density for different platforms
      visualDensity: VisualDensity.adaptivePlatformDensity,
      
      // Component themes - these automatically adapt to the color scheme
      elevatedButtonTheme: ComponentThemes.elevatedButtonTheme,
      filledButtonTheme: ComponentThemes.filledButtonTheme,
      outlinedButtonTheme: ComponentThemes.outlinedButtonTheme,
      textButtonTheme: ComponentThemes.textButtonTheme,
      iconButtonTheme: ComponentThemes.iconButtonTheme,
      floatingActionButtonTheme: ComponentThemes.floatingActionButtonTheme,
      
      cardTheme: ComponentThemes.cardTheme,
      inputDecorationTheme: ComponentThemes.inputDecorationTheme,
      appBarTheme: ComponentThemes.appBarTheme,
      bottomNavigationBarTheme: ComponentThemes.bottomNavigationBarTheme,
      tabBarTheme: ComponentThemes.tabBarTheme,
      listTileTheme: ComponentThemes.listTileTheme,
      dialogTheme: ComponentThemes.dialogTheme,
      bottomSheetTheme: ComponentThemes.bottomSheetTheme,
      snackBarTheme: ComponentThemes.snackBarTheme,
      dividerTheme: ComponentThemes.dividerTheme,
      switchTheme: ComponentThemes.switchTheme,
      checkboxTheme: ComponentThemes.checkboxTheme,
      radioTheme: ComponentThemes.radioTheme,
      chipTheme: ComponentThemes.chipTheme,
      sliderTheme: ComponentThemes.sliderTheme,
      progressIndicatorTheme: ComponentThemes.progressIndicatorTheme,
      
      // Background colors - explicit for consistency
      scaffoldBackgroundColor: AppColors.backgroundBeige,
      
      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      
      // Extensions
      extensions: const [
        AppThemeExtension(),
      ],
    );
  }

}

/// Extension for additional theme properties
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension();

  @override
  AppThemeExtension copyWith() {
    return const AppThemeExtension();
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    return const AppThemeExtension();
  }
}