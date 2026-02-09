/// Color palette system for the Butlery cooking application.
/// **Naming Strategy:**
/// - Primary names: Semantic and descriptive (e.g., `forestGreen`, `rust`, `cream`)
/// - Component-specific aliases: Allowed for semantic clarity (e.g., `sharedRecipeTextColor`)
/// - Generic aliases: Being phased out in future versions
/// **Usage Guidelines:**
/// - Prefer primary names for new code
/// - Use Material 3 ColorScheme for theme-aware components
/// - Modern syntax: Use `color.withValues(alpha: AppDimensions.opacityVeryDark)` not deprecated `withOpacity()`
/// **Color System (UI Redesign):**
/// - Primary: Forest green (#4A7C59) - headers, buttons, primary actions
/// - Rust (#8B5A3C): Decorative accents ONLY - never for errors
/// - Error (#C44536): Distinct from rust - only for error states
/// - Background: Warm cream (#F8F4E8)

import 'package:flutter/material.dart';

/// Central repository for all color definitions in the Butlery application.
class AppColors {
  AppColors._();

  // ============================================================
  // PRIMARY BRAND COLORS (UI Redesign)
  // ============================================================

  /// Forest green - primary brand color for headers, buttons, primary actions
  static const Color forestGreen = Color(0xFF4A7C59);

  /// Darker forest green - for pressed states, emphasis
  static const Color forestGreenDark = Color(0xFF3D6849);

  /// Light forest green variant - for containers, subtle backgrounds
  static const Color forestGreenLight = Color(0xFF6B9B7A);

  /// Rust - decorative accent ONLY (borders, indicators, illustrations)
  /// NEVER use for error states - use [error] instead
  static const Color rust = Color(0xFF8B5A3C);

  /// Rust light - for subtle decorative backgrounds
  static const Color rustLight = Color(0xFFA77B5E);

  /// Warm cream - primary background color
  static const Color cream = Color(0xFFF8F4E8);

  /// Slightly darker cream - for cards, elevated surfaces
  static const Color creamDark = Color(0xFFF0EAD6);

  /// Card white - for elevated cards and surfaces
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardWhite54 = Color(0x8AFFFFFF); // 54% opacity white

  // ============================================================
  // TEXT COLORS
  // ============================================================

  /// Dark text - primary text color (on light backgrounds)
  static const Color textDark = Color(0xFF2C3E50);

  /// Medium text - secondary text, descriptions
  static const Color textMedium = Color(0xFF6B7280);
  static const Color textMedium200 =
      Color(0xFFE5E7EB); // Lighter variant for backgrounds
  static const Color textMedium300 = Color(0xFFD1D5DB); // Medium-light variant
  static const Color textMedium600 =
      Color(0xFF4B5563); // Darker variant for text

  /// Light text - tertiary text, placeholders
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFFD1D5DB);
  static const Color textSecondary = textMedium;

  /// Text on primary (white text on green backgrounds)
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Text on cream backgrounds - slightly warmer dark
  static const Color textOnCream = Color(0xFF3D3D3D);

  // ============================================================
  // SEMANTIC COLORS
  // ============================================================

  /// Accent - rust for decorative purposes only
  static const Color accent = rust;

  /// Success green
  static const Color success = Color(0xFF10B981);

  /// Warning gold/amber - updated to match new palette
  static const Color warning = Color(0xFFD4A03C);

  /// Error red - DISTINCT from rust, only for errors
  static const Color error = Color(0xFFC44536);

  /// Error container background
  static const Color errorContainer = Color(0xFFFEF2F2);
  static const Color onErrorContainer = Color(0xFF991B1B);

  /// Success container
  static const Color successContainer = Color(0xFFF0FDF4);
  static const Color onSuccessContainer = Color(0xFF166534);

  /// Warning container - updated to match new warning color
  static const Color warningContainer = Color(0xFFFFF8E1);
  static const Color onWarningContainer = Color(0xFF8B6914);

  /// Info container
  static const Color infoContainer = Color(0xFFF0F9FF);
  static const Color onInfoContainer = Color(0xFF1E40AF);
  static const Color info = Color(0xFF3B82F6);

  /// Divider color
  static const Color divider = Color(0xFFE5E7EB);

  // ============================================================
  // SPECIALIZED COLORS
  // ============================================================

  /// Recipe metadata text
  static const Color recipeMeta = Color(0xFF757575);

  /// Section header text
  static const Color sectionHeader = Color(0xFF374151);

  /// Star/rating gold
  static const Color starGold = Color(0xFFFBBF24);

  // ============================================================
  // SHOPPING LIST CATEGORY COLORS
  // ============================================================

  /// Meat & Fish category
  static const Color categoryMeatFish = rust;

  /// Dairy category
  static const Color categoryDairy = Color(0xFFD4A03C);

  /// Vegetables category
  static const Color categoryVegetables = forestGreen;

  /// Fruit category
  static const Color categoryFruit = Color(0xFF7CB87C);

  /// Bread & Grains category
  static const Color categoryBreadGrains = Color(0xFFC4A35A);

  /// Frozen category
  static const Color categoryFrozen = Color(0xFF8BA5B5);

  /// Dry goods category
  static const Color categoryDryGoods = Color(0xFF9C7A5C);

  /// Other category
  static const Color categoryOther = Color(0xFF9CA3AF);

  // ============================================================
  // UTILITY COLORS
  // ============================================================

  /// Background tint for subtle elevation
  static const Color backgroundTint = Color(0xFFFAF8F3);

  /// Overlay for modals/dialogs
  static const Color overlay = Color(0x80000000);

  /// Transparent
  static const Color transparent = Colors.transparent;

  // Neutral colors
  static const Color neutralLight = Color(0xFFFFFFFF);
  static const Color neutralMedium = Color(0xFF9CA3AF);
  static const Color neutralDark = Color(0xFF1F2937);

  // Shared recipe colors - updated for new palette
  static const Color sharedRecipeText = Color(0xFF9CA3AF);
  static const Color sharedRecipeIcon = Color(0xFFD1D5DB);
  static const Color sharedRecipeBackground = Color(0xFFFAF8F3);

  static const Color sharedRecipeTextColor = sharedRecipeText;
  static const Color sharedRecipeIconColor = sharedRecipeIcon;
  static const Color sharedRecipeBackgroundColor = sharedRecipeBackground;

  // ============================================================
  // CHAT BUBBLE COLORS (UI Redesign)
  // ============================================================

  /// Outgoing message bubble (user's messages)
  static const Color chatBubbleOutgoing = forestGreenLight;

  /// Incoming message bubble (other's messages)
  static const Color chatBubbleIncoming = creamDark;

  /// Text on outgoing bubble
  static const Color chatTextOutgoing = textOnPrimary;

  /// Text on incoming bubble
  static const Color chatTextIncoming = textDark;

  // ============================================================
  // MATERIAL 3 COLOR SCHEME
  // ============================================================

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary - Forest Green
    primary: forestGreen,
    onPrimary: cardWhite,
    primaryContainer: Color(0xFFD4E8D9), // Light green container
    onPrimaryContainer: forestGreenDark,
    // Secondary - Rust (decorative)
    secondary: rust,
    onSecondary: cardWhite,
    secondaryContainer: Color(0xFFF5E6DC), // Light rust container
    onSecondaryContainer: Color(0xFF5C3D29),
    // Tertiary - Gold/Star color
    tertiary: starGold,
    onTertiary: textDark,
    tertiaryContainer: Color(0xFFFFF8E1),
    onTertiaryContainer: textDark,
    // Error - Distinct from rust
    error: error,
    onError: cardWhite,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF991B1B),
    // Surface - Warm cream
    surface: cream,
    onSurface: textDark,
    surfaceContainerHighest: cardWhite,
    onSurfaceVariant: textMedium,
    // Outline
    outline: divider,
    outlineVariant: Color(0xFFE8E4DC),
    // Shadow/Scrim
    shadow: Colors.black26,
    scrim: Colors.black54,
    // Inverse
    inverseSurface: forestGreenDark,
    onInverseSurface: cardWhite,
    inversePrimary: forestGreenLight,
    // Tint
    surfaceTint: forestGreen,
  );

  // Dark mode not in scope for redesign, but keep for compatibility
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: forestGreenLight,
    onPrimary: Color(0xFF1A3D24),
    primaryContainer: forestGreen,
    onPrimaryContainer: Color(0xFFD4E8D9),
    secondary: rustLight,
    onSecondary: Color(0xFF3D2517),
    secondaryContainer: rust,
    onSecondaryContainer: Color(0xFFF5E6DC),
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
    inversePrimary: forestGreen,
    surfaceTint: forestGreenLight,
  );

  // ============================================================
  // LEGACY COMPATIBILITY (use new names in new code)
  // ============================================================

  static const Color shadowColor = Color(0x1A000000);
  static const Color backgroundLight = cream;
  static const Color secondaryPurple = Color(0xFF9C27B0);
  static const Color backgroundDark = neutralDark;
  static const Color surfaceDark = Color(0xFF374151);

  // Material 3 compatibility - use ColorScheme instead where possible
  static const Color primary = forestGreen;
  static const Color secondary = rust;
  static const Color surface = cream;
  static const Color surfaceVariant = cardWhite;
  static const Color onSurface = textDark;
  static const Color primaryContainer = Color(0xFFD4E8D9);
  static const Color secondaryContainer = Color(0xFFF5E6DC);
  static const Color onPrimaryContainer = forestGreenDark;
  static const Color onPrimary = cardWhite;
  static const Color outline = divider;
  static const Color shadow = shadowColor;
  static const Color onSuccess = cardWhite;
  static const Color onError = cardWhite;
  static const Color onWarning = textDark;
  static const Color onInfo = cardWhite;

  // ============================================================
  // RECIPE CARD BORDER COLORS (UI Redesign)
  // ============================================================

  /// Left border color for recipe cards
  static const Color recipeCardLeftBorder = forestGreen;

  /// Bottom border color for recipe cards
  static const Color recipeCardBottomBorder = rust;

  // ============================================================
  // HEADER COLORS (UI Redesign)
  // ============================================================

  /// Header background
  static const Color headerBackground = forestGreen;

  /// Header accent bar (rust bottom border)
  static const Color headerAccent = rust;

  /// Text/icons on header
  static const Color headerForeground = cardWhite;

  // ============================================================
  // NAVIGATION COLORS (UI Redesign)
  // ============================================================

  /// Navigation background
  static const Color navBackground = forestGreen;

  /// Selected nav item indicator
  static const Color navSelectedIndicator = rust;

  /// Selected nav item text/icon
  static const Color navSelectedItem = cardWhite;

  /// Unselected nav item text/icon
  static const Color navUnselectedItem = Color(0xB3FFFFFF); // 70% white
}
