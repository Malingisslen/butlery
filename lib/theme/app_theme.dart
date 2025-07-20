// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'component_themes.dart';

/// Main theme orchestrator for the Butlery app
/// Combines colors, typography, dimensions, and component themes
/// Refactored from monolithic 1,057-line file into modular theme system
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  // ===== MAIN THEME FACTORY =====

  /// Create the complete light theme for the app
  static ThemeData get lightTheme => _createTheme(AppColors.lightColorScheme);

  /// Create the dark theme for the app (future enhancement)
  static ThemeData get darkTheme => _createTheme(AppColors.darkColorScheme);

  /// Private helper to create theme with given color scheme
  /// Eliminates duplication between light and dark themes
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

  // ===== ESSENTIAL TEXT CONSTANTS =====
  // These are content formatting constants, not theme properties

  /// Text divider character for recipes
  static const String dividerChar = ' • ';

  /// Bullet point character for lists
  static const String bulletPoint = '• ';

  /// Number divider for numbered lists
  static const String numberDivider = '. ';

  // ===== UNICODE SYMBOLS =====
  // UI symbols for various elements

  /// Unicode symbols for various UI elements
  static const String checkMark = '✓';
  static const String xMark = '✗';
  static const String star = '★';
  static const String starOutline = '☆';
  static const String heart = '♥';
  static const String heartOutline = '♡';
  static const String clock = '⏰';
  static const String portions = '👥';
  static const String difficulty = '🔥';
  static const String share = '📤';
  static const String download = '📥';
}

/// Extension for additional theme properties
/// This extension provides access to custom theme properties
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