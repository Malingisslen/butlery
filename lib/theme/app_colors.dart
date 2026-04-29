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

  /// Darker cream - for nav bars, portion scalers (mockup --cream-dark)
  static const Color creamDarker = Color(0xFFE8E2D6);

  /// Pale green - for hero image backgrounds (mockup --green-pale)
  static const Color greenPale = Color(0xFFE8F0EA);

  /// Muted green - nav unselected (WCAG AA ≥4.6:1 on creamDarker)
  static const Color greenMuted = Color(0xFF526A55);

  /// Card white - for elevated cards and surfaces
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardWhite54 = Color(0x8AFFFFFF); // 54% opacity white

  /// Dark text - primary text color (on light backgrounds)
  static const Color textDark = Color(0xFF1A1A1A);

  /// Medium text - secondary text (WCAG AA ≥4.6:1 on cream, ≥5.7:1 on white)
  static const Color textMedium = Color(0xFF666666);

  /// Placeholder icon color - for avatar/icon placeholders
  static const Color placeholderIcon = Color(0xFF4B5563);

  /// Light text - tertiary text, placeholders.
  /// Darkened from #767676 (BUT-514) to satisfy WCAG 1.4.3 AA on cream surfaces.
  /// Measured contrast: ≥6.2:1 on cream (#F8F4E8), ≥6.8:1 on white.
  static const Color textLight = Color(0xFF5A5A5A);
  static const Color textTertiary = Color(0xFFD1D5DB);
  static const Color textSecondary = textMedium;

  /// Text on primary (white text on green backgrounds)
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Text on cream backgrounds - slightly warmer dark
  static const Color textOnCream = Color(0xFF3D3D3D);

  /// Accent - rust for decorative purposes only
  static const Color accent = rust;

  /// Success green - alias to forestGreen per design system
  static const Color success = forestGreen;

  /// Warning warm gold per mockup (use for containers/icons only, NOT text)
  static const Color warning = Color(0xFFD4A03C);

  /// Warning text color (WCAG AA on cream/white)
  static const Color warningText = onWarningContainer;

  /// Error red - DISTINCT from rust, only for errors
  static const Color error = Color(0xFFC44536);

  /// Error container background
  static const Color errorContainer = Color(0xFFFEF2F2);
  static const Color onErrorContainer = Color(0xFF991B1B);

  /// Success container
  static const Color successContainer = Color(0xFFF0FDF4);
  static const Color onSuccessContainer = Color(0xFF166534);

  /// Warning container - warm gold tint
  static const Color warningContainer = Color(0xFFFFF8E1);
  static const Color onWarningContainer = Color(0xFF7A5B10);

  /// Info container
  static const Color infoContainer = Color(0xFFF0F9FF);
  static const Color onInfoContainer = Color(0xFF1E40AF);

  /// Info blue (WCAG AA 4.5:1 on infoContainer)
  static const Color info = Color(0xFF2563CA);

  /// Divider color
  static const Color divider = Color(0xFFE5E7EB);

  /// Recipe metadata text (WCAG AA ≥4.6:1 on cream, ≥4.8:1 on white)
  static const Color recipeMeta = Color(0xFF6B6B6B);

  /// Section header text
  static const Color sectionHeader = Color(0xFF374151);

  /// Star/rating gold
  static const Color starGold = Color(0xFFFBBF24);

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

  /// Background tint for subtle elevation
  static const Color backgroundTint = Color(0xFFFAF8F3);

  // Illustration decorative colors (static across themes)
  static const Color illustrationBrown = Color(0xFFA08060);
  static const Color illustrationOrange = Color(0xFFE07020);
  static const Color illustrationPurpleRed = Color(0xFF8B2252);

  /// Overlay for modals/dialogs
  static const Color overlay = Color(0x80000000);

  /// Transparent
  static const Color transparent = Colors.transparent;

  // Neutral colors
  static const Color neutralLight = Color(0xFFFFFFFF);
  static const Color neutralMedium = Color(0xFF9CA3AF);
  static const Color neutralDark = Color(0xFF1F2937);

  /// Shared recipe secondary text (WCAG AA ≥4.8:1 on backgroundTint)
  static const Color sharedRecipeText = Color(0xFF6B7280);
  static const Color sharedRecipeIcon = Color(0xFFD1D5DB);
  static const Color sharedRecipeBackground = Color(0xFFFAF8F3);

  static const Color sharedRecipeTextColor = sharedRecipeText;
  static const Color sharedRecipeIconColor = sharedRecipeIcon;
  static const Color sharedRecipeBackgroundColor = sharedRecipeBackground;

  /// Outgoing message bubble (user's messages)
  static const Color chatBubbleOutgoing = forestGreenLight;

  /// Incoming message bubble (other's messages)
  static const Color chatBubbleIncoming = creamDark;

  /// Text on outgoing bubble
  static const Color chatTextOutgoing = textOnPrimary;

  /// Text on incoming bubble
  static const Color chatTextIncoming = textDark;

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
    outline: textLight,
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

  /// M3-compliant dark color scheme using seed generation with brand overrides.
  /// Uses ColorScheme.fromSeed for proper tonal palette, surface containers,
  /// and tonal elevation, then overrides secondary (rust) and error slots.
  static ColorScheme get darkColorScheme {
    final base = ColorScheme.fromSeed(
      seedColor: forestGreen,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      // Warm dark surfaces — brown-tinted instead of cold auto-generated greens
      surface: const Color(0xFF1A1611), // warm dark brown
      onSurface: const Color(0xFFEDE0D4), // warm off-white
      surfaceContainerLowest: const Color(0xFF12100C),
      surfaceContainerLow: const Color(0xFF1E1A14),
      surfaceContainer: const Color(0xFF231E17),
      surfaceContainerHigh: const Color(0xFF2D271F),
      surfaceContainerHighest: const Color(0xFF383127),
      inverseSurface: const Color(0xFFEDE0D4),
      onInverseSurface: const Color(0xFF1A1611),
      // Override secondary toward rust (seed ignores this)
      secondary: const Color(0xFFD4A88A), // rust tone 80
      onSecondary: const Color(0xFF3D2517),
      secondaryContainer: const Color(0xFF6B4630),
      onSecondaryContainer: const Color(0xFFF5DCC8),
      // Override error (ensure proper red, not orange)
      error: const Color(0xFFFFB4AB), // M3 error tone 80
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
    );
  }

  // Legacy compatibility (use new names in new code)
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
  static const Color outline = textLight;
  static const Color shadow = shadowColor;
  static const Color onSuccess = cardWhite;
  static const Color onError = cardWhite;
  static const Color onWarning = textDark;
  static const Color onInfo = cardWhite;

  /// Left border color for recipe cards
  static const Color recipeCardLeftBorder = forestGreen;

  /// Bottom border color for recipe cards (rust-light per mockup)
  static const Color recipeCardBottomBorder = rustLight;

  /// Header background
  static const Color headerBackground = forestGreen;

  /// Header accent bar (rust bottom border)
  static const Color headerAccent = rust;

  /// Text/icons on header
  static const Color headerForeground = cardWhite;

  /// Navigation background - cream-dark per mockup
  static const Color navBackground = creamDarker;

  /// Selected nav item indicator
  static const Color navSelectedIndicator = rust;

  /// Selected nav item text/icon - dark green on cream bg
  static const Color navSelectedItem = forestGreenDark;

  /// Unselected nav item text/icon - muted green on cream bg
  static const Color navUnselectedItem = greenMuted;

  // BUT-690: Overlay colors lifted from theme_constants. Pre-multiplied
  // alpha is intentional — withValues(alpha:) at every callsite would
  // be deprecation-thrash without saving any cycles.
  /// White overlay with 40% opacity (used for layered tint over images)
  static const Color overlayWhite40 = Color(0x66FFFFFF);

  /// Black overlay with 10% opacity (subtle scrim)
  static const Color overlayBlack10 = Color(0x1A000000);

  /// Black overlay with 20% opacity (light scrim)
  static const Color overlayBlack20 = Color(0x33000000);

  /// Black overlay with 40% opacity (medium scrim)
  static const Color overlayBlack40 = Color(0x66000000);

  /// Black overlay with 60% opacity (heavy scrim)
  static const Color overlayBlack60 = Color(0x99000000);

  // BUT-690: Brand colors centralized for theme-aware token discoverability.
  // BrandColors is preserved as the public API and re-exports these.
  /// YouTube brand red
  static const Color brandYoutube = Color(0xFFFF0000);

  /// TikTok brand cyan
  static const Color brandTiktok = Color(0xFF00F2EA);

  /// Instagram brand pink
  static const Color brandInstagram = Color(0xFFE1306C);

  /// Twitter (X) brand blue
  static const Color brandTwitter = Color(0xFF1DA1F2);

  /// Pinterest brand red
  static const Color brandPinterest = Color(0xFFE60023);

  /// WhatsApp brand green
  static const Color brandWhatsapp = Color(0xFF25D366);

  /// Telegram brand blue
  static const Color brandTelegram = Color(0xFF0088CC);

  /// Facebook brand blue
  static const Color brandFacebook = Color(0xFF1877F2);

  /// Reddit brand orange
  static const Color brandReddit = Color(0xFFFF4500);

  /// AllRecipes brand red
  static const Color brandAllrecipes = Color(0xFFBD081C);

  /// ICA brand orange
  static const Color brandIca = Color(0xFFFF6600);

  /// Coop brand green
  static const Color brandCoop = Color(0xFF006341);

  /// Arla brand red
  static const Color brandArla = Color(0xFFE30613);

  /// Koket.se brand black
  static const Color brandKoketSe = Color(0xFF000000);

  /// Generic platform color (neutral gray)
  static const Color brandGeneric = Color(0xFF6B7280);

  /// YouTube light background tint
  static const Color brandYoutubeBackground = Color(0xFFFFE0E0);

  /// TikTok light background tint
  static const Color brandTiktokBackground = Color(0xFFE0F7FA);

  /// Instagram light background tint
  static const Color brandInstagramBackground = Color(0xFFFCE4EC);

  /// YouTube dark text color
  static const Color brandYoutubeText = Color(0xFFCC0000);

  /// TikTok dark text color (black per brand guidelines)
  static const Color brandTiktokText = Color(0xFF161823);

  /// Instagram dark text color
  static const Color brandInstagramText = Color(0xFFC13584);
}
