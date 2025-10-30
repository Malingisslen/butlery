/// Color palette system for the Butlery cooking application.
///
/// **Naming Strategy:**
/// - Primary names: Semantic and descriptive (e.g., `primaryBlue`, `success`, `backgroundBeige`)
/// - Component-specific aliases: Allowed for semantic clarity (e.g., `sharedRecipeTextColor`)
/// - Generic aliases: Being phased out in future versions
///
/// **Usage Guidelines:**
/// - Prefer primary names for new code
/// - Use Material 3 ColorScheme for theme-aware components
/// - Modern syntax: Use `color.withValues(alpha: 0.8)` not deprecated `withOpacity()`

import 'package:flutter/material.dart';

/// Central repository for all color definitions in the Butlery application.
class AppColors {
  AppColors._();

  // Primary colors
  static const Color primaryBlue = Color(0xFF4E6F8B);
  static const Color darkNavy = Color(0xFF2C3E50);
  static const Color backgroundBeige = Color(0xFFEFE9E3);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardWhite54 = Color(0x8AFFFFFF);  // 54% opacity white
  
  // Text colors
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textMedium = Color(0xFF6B7280);
  static const Color textMedium200 = Color(0xFFE5E7EB);  // Lighter variant for backgrounds
  static const Color textMedium300 = Color(0xFFD1D5DB);  // Medium-light variant
  static const Color textMedium600 = Color(0xFF4B5563);  // Darker variant for text
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFFD1D5DB);
  static const Color textSecondary = textMedium;
  
  // Semantic colors
  static const Color accent = Color(0xFFA7C4D9);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFEF2F2);
  static const Color onErrorContainer = Color(0xFF991B1B);
  static const Color successContainer = Color(0xFFF0FDF4);
  static const Color onSuccessContainer = Color(0xFF166534);
  static const Color warningContainer = Color(0xFFFFFBEB);
  static const Color onWarningContainer = Color(0xFF92400E);
  static const Color infoContainer = Color(0xFFF0F9FF);
  static const Color onInfoContainer = Color(0xFF1E40AF);
  static const Color info = Color(0xFF3B82F6);
  static const Color divider = Color(0xFFE5E7EB);
  
  // Specialized colors
  static const Color recipeMeta = Color(0xFF757575);
  static const Color sectionHeader = Color(0xFF374151);
  static const Color starGold = Color(0xFFFBBF24);
  
  // Utility colors (keep these - not simple aliases)
  static const Color backgroundTint = Color(0xFFF8F9FA);
  static const Color overlay = Color(0x80000000);
  static const Color transparent = Colors.transparent;

  // Neutral colors
  static const Color neutralLight = Color(0xFFFFFFFF);
  static const Color neutralMedium = Color(0xFF9CA3AF);
  static const Color neutralDark = Color(0xFF1F2937);

  // Shared recipe colors
  static const Color sharedRecipeText = Color(0xFF9CA3AF);
  static const Color sharedRecipeIcon = Color(0xFFD1D5DB);
  static const Color sharedRecipeBackground = Color(0xFFF9FAFB);
  
  static const Color sharedRecipeTextColor = sharedRecipeText;
  static const Color sharedRecipeIconColor = sharedRecipeIcon;
  static const Color sharedRecipeBackgroundColor = sharedRecipeBackground;

  // Material 3 ColorScheme

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primaryBlue,
    onPrimary: cardWhite,
    primaryContainer: Color(0xFFE3F2FD),
    onPrimaryContainer: darkNavy,
    secondary: accent,
    onSecondary: cardWhite,
    secondaryContainer: Color(0xFFE1F5FE),
    onSecondaryContainer: darkNavy,
    tertiary: starGold,
    onTertiary: darkNavy,
    tertiaryContainer: Color(0xFFFFF8E1),
    onTertiaryContainer: darkNavy,
    error: error,
    onError: cardWhite,
    errorContainer: Color(0xFFFFEBEE),
    onErrorContainer: Color(0xFFB71C1C),
    surface: backgroundBeige,
    onSurface: textDark,
    surfaceContainerHighest: cardWhite,
    onSurfaceVariant: textMedium,
    outline: divider,
    outlineVariant: Color(0xFFE0E0E0),
    shadow: Colors.black26,
    scrim: Colors.black54,
    inverseSurface: darkNavy,
    onInverseSurface: cardWhite,
    inversePrimary: Color(0xFF90CAF9),
    surfaceTint: primaryBlue,
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF90CAF9),
    onPrimary: Color(0xFF0D47A1),
    primaryContainer: Color(0xFF1976D2),
    onPrimaryContainer: Color(0xFFE3F2FD),
    secondary: Color(0xFF81D4FA),
    onSecondary: Color(0xFF006064),
    secondaryContainer: Color(0xFF0097A7),
    onSecondaryContainer: Color(0xFFE0F7FA),
    tertiary: Color(0xFFFFD54F),
    onTertiary: Color(0xFF333333),
    tertiaryContainer: Color(0xFFFF8F00),
    onTertiaryContainer: Color(0xFFFFF8E1),
    error: Color(0xFFFFAB91),
    onError: Color(0xFFBF360C),
    errorContainer: Color(0xFFD84315),
    onErrorContainer: Color(0xFFFFCCBC),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFE0E0E0),
    surfaceContainerHighest: Color(0xFF424242),
    onSurfaceVariant: Color(0xFFBDBDBD),
    outline: Color(0xFF616161),
    outlineVariant: Color(0xFF424242),
    shadow: Colors.black,
    scrim: Colors.black87,
    inverseSurface: Color(0xFFE0E0E0),
    onInverseSurface: Color(0xFF121212),
    inversePrimary: primaryBlue,
    surfaceTint: Color(0xFF90CAF9),
  );



  // Legacy compatibility colors (minimal set)
  static const Color shadowColor = Color(0x1A000000);
  static const Color backgroundLight = backgroundBeige;
  static const Color secondaryPurple = Color(0xFF9C27B0);
  static const Color backgroundDark = neutralDark;
  static const Color surfaceDark = Color(0xFF374151);

  // Material 3 compatibility - use ColorScheme instead where possible
  static const Color primary = primaryBlue;
  static const Color secondary = accent;
  static const Color surface = backgroundBeige;
  static const Color surfaceVariant = cardWhite;
  static const Color onSurface = textDark;
  static const Color primaryContainer = Color(0xFFE3F2FD);
  static const Color secondaryContainer = Color(0xFFE1F5FE);
  static const Color onPrimaryContainer = darkNavy;
  static const Color onPrimary = cardWhite;
  static const Color outline = divider;
  static const Color shadow = shadowColor;
  static const Color onSuccess = cardWhite;
  static const Color onError = cardWhite;
  static const Color onWarning = darkNavy;
  static const Color onInfo = cardWhite;
}