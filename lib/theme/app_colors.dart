// lib/theme/app_colors.dart

import 'package:flutter/material.dart';

/// Centralized color palette for the Butlery app
/// Based on Figma prototype with Material 3 design
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ===== PRIMARY COLOR PALETTE =====

  static const Color primaryBlue = Color(0xFF4A7C93); // Header blue from "Din meny"
  static const Color darkNavy = Color(0xFF2C3E50); // Bottom navigation
  static const Color backgroundBeige = Color(0xFFF5F5F0); // Main background
  static const Color cardWhite = Color(0xFFFFFFFF); // White cards
  
  // ===== TEXT COLORS =====
  
  static const Color textDark = Color(0xFF2C3E50); // Dark text
  static const Color textMedium = Color(0xFF6B7280); // Medium gray text
  static const Color textLight = Color(0xFF9CA3AF); // Light gray text
  static const Color textTertiary = Color(0xFFD1D5DB); // Tertiary gray text
  static const Color textSecondary = textMedium; // Alias for backwards compatibility
  
  // ===== SEMANTIC COLORS =====
  
  static const Color accent = Color(0xFF60A5FA); // Accent blue for buttons
  static const Color success = Color(0xFF10B981); // Green for success
  static const Color warning = Color(0xFFF59E0B); // Yellow for warnings
  static const Color error = Color(0xFFEF4444); // Red for errors
  static const Color divider = Color(0xFFE5E7EB); // Dividers
  
  // ===== SPECIALIZED COLORS =====
  
  static const Color recipeMeta = Color(0xFF8B9AAF); // For "6 portioner | 30 minuter"
  static const Color sectionHeader = Color(0xFF374151); // For "Middagar", "Lunch" etc
  static const Color starGold = Color(0xFFFBBF24); // Gold yellow for stars
  
  // ===== ALIAS COLORS =====
  
  static const Color accentColor = accent; // Alias for accent
  static const Color warningColor = warning; // Alias for warning
  static const Color backgroundColor = backgroundBeige; // Alias for background
  static const Color cardColor = cardWhite; // Alias for card white
  static const Color dividerColor = divider; // Alias for divider
  static const Color starColor = starGold; // Alias for star color
  static const Color backgroundTint = Color(0xFFF8F9FA); // Light background tint
  static const Color textPrimary = textDark; // Alias for primary text
  static const Color overlay = Color(0x80000000); // Semi-transparent overlay
  static const Color transparent = Colors.transparent; // Transparent color

  // ===== NEUTRAL COLORS =====
  
  static const Color neutralLight = Color(0xFFFFFFFF); // Light neutral (white)
  static const Color neutralMedium = Color(0xFF9CA3AF); // Medium neutral (gray)
  static const Color neutralDark = Color(0xFF1F2937); // Dark neutral (dark gray)

  // ===== SHARED RECIPE COLORS =====

  /// Colors for recipes that have already been shared with friends
  static const Color sharedRecipeText = Color(0xFF9CA3AF); // Light gray for text
  static const Color sharedRecipeIcon = Color(0xFFD1D5DB); // Even lighter for icons
  static const Color sharedRecipeBackground = Color(0xFFF9FAFB); // Very light background
  
  // Aliases for shared recipe colors
  static const Color sharedRecipeTextColor = sharedRecipeText;
  static const Color sharedRecipeIconColor = sharedRecipeIcon;
  static const Color sharedRecipeBackgroundColor = sharedRecipeBackground;

  // ===== MATERIAL 3 COLOR SCHEME =====

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
    surface: cardWhite,
    onSurface: textDark,
    surfaceContainerHighest: Color(0xFFF5F5F5),
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

  // ===== GRADIENT DEFINITIONS =====

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warning, Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [error, Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===== COLOR UTILITIES =====

  /// Get color based on recipe type
  static Color getRecipeTypeColor(String recipeType) {
    switch (recipeType.toLowerCase()) {
      case 'breakfast':
      case 'frukost':
        return const Color(0xFFFF9800);
      case 'lunch':
        return const Color(0xFF4CAF50);
      case 'dinner':
      case 'middag':
        return primaryBlue;
      case 'snack':
      case 'mellanmål':
        return const Color(0xFF9C27B0);
      case 'dessert':
        return const Color(0xFFE91E63);
      default:
        return textMedium;
    }
  }

  /// Get difficulty color
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
      case 'lätt':
        return success;
      case 'medium':
      case 'medel':
        return warning;
      case 'hard':
      case 'svår':
        return error;
      default:
        return textMedium;
    }
  }

  /// Get surface color with elevation tint
  static Color getSurfaceColorWithElevation(double elevation) {
    final tintOpacity = (elevation * 0.05).clamp(0.0, 0.12);
    return Color.alphaBlend(
      lightColorScheme.surfaceTint.withValues(alpha: tintOpacity),
      lightColorScheme.surface,
    );
  }

  // ===== LEGACY COMPATIBILITY COLORS =====
  // Additional colors for backwards compatibility

  /// Shadow color for elevation effects
  static const Color shadowColor = Color(0x1A000000);

  /// Light background color
  static const Color backgroundLight = backgroundBeige;

  /// Secondary purple color for special highlights
  static const Color secondaryPurple = Color(0xFF9C27B0);

  /// Background dark color
  static const Color backgroundDark = neutralDark;

  // ===== MEAL TYPE COLORS (FROM ORIGINAL APPTHEME) =====

  /// Colors for different meal types - centralized instead of hardcoded
  static const Color frukostColor = Color(0xFFFF8C00); // Orange
  static const Color lunchColor = Color(0xFF16A085); // Teal
  static const Color middagColor = primaryBlue; // Uses theme blue
  static const Color dessertColor = Color(0xFFE91E63); // Pink
  static const Color mellanmalColor = Color(0xFF9C27B0); // Purple
  static const Color fikaColor = Color(0xFF8D6E63); // Brown
  static const Color defaultMealColor = textSecondary; // Fallback color

  // ===== OVERLAY OPACITY CONSTANTS =====

  /// Overlay opacity for loading screens and dialogs
  static const double overlayOpacity = 0.7;
  static const double cardOverlayOpacity = 0.8;

  // ===== SHADOW COLOR =====

  /// Shadow color for card shadows (with opacity)
  static const Color cardShadowColor = Color(0x1A2C3E50); // textDark with opacity as Color
  
  /// Primary blue shadow for buttons
  static const Color primaryBlueShadow = Color(0x1A4A7C93); // primaryBlue with opacity as Color

  /// Utility method to get meal type color
  static Color getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'frukost':
        return frukostColor;
      case 'lunch':
        return lunchColor;
      case 'middag':
        return middagColor;
      case 'dessert':
        return dessertColor;
      case 'mellanmål':
        return mellanmalColor;
      case 'fika':
        return fikaColor;
      default:
        return defaultMealColor;
    }
  }
}