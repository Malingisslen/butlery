// lib/theme/app_colors.dart

import 'package:flutter/material.dart';

/// Centralized color palette for the Butlery app
/// Based on Figma prototype with Material 3 design
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ===== PRIMARY COLOR PALETTE =====

  static const Color primaryBlue = Color(0xFF4E6F8B); // Updated primary blue per user request
  static const Color darkNavy = Color(0xFF2C3E50); // Bottom navigation
  static const Color backgroundBeige = Color(0xFFEFE9E3); // Main background
  static const Color cardWhite = Color(0xFFFFFFFF); // White cards
  
  // ===== TEXT COLORS =====
  
  static const Color textDark = Color(0xFF2C3E50); // Dark text
  static const Color textMedium = Color(0xFF6B7280); // Medium gray text
  static const Color textLight = Color(0xFF9CA3AF); // Light gray text
  static const Color textTertiary = Color(0xFFD1D5DB); // Tertiary gray text
  static const Color textSecondary = textMedium; // Alias for backwards compatibility
  
  // ===== SEMANTIC COLORS =====
  
  static const Color accent = Color(0xFFA7C4D9); // Accent blue for buttons
  static const Color success = Color(0xFF10B981); // Green for success
  static const Color warning = Color(0xFFF59E0B); // Yellow for warnings
  static const Color error = Color(0xFFEF4444); // Red for errors
  static const Color errorContainer = Color(0xFFFEF2F2); // Light red container
  static const Color onErrorContainer = Color(0xFF991B1B); // Dark red on error container
  static const Color successContainer = Color(0xFFF0FDF4); // Light green container  
  static const Color onSuccessContainer = Color(0xFF166534); // Dark green on success container
  static const Color warningContainer = Color(0xFFFFFBEB); // Light yellow container
  static const Color onWarningContainer = Color(0xFF92400E); // Dark yellow on warning container
  static const Color infoContainer = Color(0xFFF0F9FF); // Light blue container
  static const Color onInfoContainer = Color(0xFF1E40AF); // Dark blue on info container
  static const Color info = Color(0xFF3B82F6); // Blue for info
  static const Color divider = Color(0xFFE5E7EB); // Dividers
  
  // ===== SPECIALIZED COLORS =====
  
  static const Color recipeMeta = Color(0xFF757575); // Colors.grey[600] - better contrast for metadata
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
  static const Color surfaceDark = Color(0xFF374151); // Dark surface color


}