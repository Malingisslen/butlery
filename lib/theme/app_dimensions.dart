/// Dimension system providing unified spacing, sizing, and layout constants.

import 'package:flutter/material.dart';

/// Central repository for spatial and sizing constants.
class AppDimensions {
  /// Private constructor to prevent instantiation of utility class
  AppDimensions._();

  // ===== SPACING CONSTANTS (MATCHING ORIGINAL APPTHEME) =====

  /// Extra small spacing (4px) - matches original spacingXs
  static const double spacingXs = 4.0;

  /// Small spacing (8px) - matches original spacingSm  
  static const double spacingSm = 8.0;

  /// Medium spacing (16px) - matches original spacingMd
  static const double spacingMd = 16.0;

  /// Large spacing (24px) - matches original spacingLg
  static const double spacingLg = 24.0;

  /// Extra large spacing (32px) - matches original spacingXl
  static const double spacingXl = 32.0;

  /// Extra extra large spacing (48px) - matches original spacingXxl
  static const double spacingXxl = 48.0;

  /// **Spacing Scale Guide:**
  /// Use semantic names instead of numeric constants
  ///
  /// Scale: Xs(4) → Sm(8) → Md(16) → Lg(24) → Xl(32) → Xxl(48)
  ///
  /// For values between scale points, combine semantically:
  /// - 12px = spacingSm + spacingXs (8 + 4)
  /// - 20px = spacingMd + spacingXs (16 + 4)
  /// - 28px = spacingLg + spacingXs (24 + 4)
  ///
  /// ❌ Don't: padding: spacing12
  /// ✅ Do: padding: spacingMd or combine: spacingSm + spacingXs

  // Minimal aliases for backward compatibility
  static const double spacingXxs = 2.0;  // Extra extra small (2px) - use sparingly
  static const double spacingS = 3.0;    // Small (3px) - use sparingly
  static const double spacingM = spacingSm;  // Alias for 8px
  static const double spacingL = 12.0;   // 12px - consider using spacingSm + spacingXs
  static const double spacingXxxl = spacingLg; // Alias for 24px

  // Numeric spacing aliases (legacy - prefer semantic names above)
  static const double spacing2 = spacingXxs;
  static const double spacing4 = spacingXs;
  static const double spacing6 = 6.0;
  static const double spacing8 = spacingSm;
  static const double spacing12 = spacingL;
  static const double spacing14 = 14.0;
  static const double spacing16 = spacingMd;
  static const double spacing20 = 20.0;
  static const double spacing24 = spacingLg;
  static const double spacing80 = 80.0;

  // ===== PADDING CONSTANTS =====

  /// Small padding (8px)
  static const double paddingS = 8.0;

  /// Medium padding (12px)
  static const double paddingM = 12.0;

  /// Large padding (16px)
  static const double paddingL = 16.0;

  /// Extra large padding (20px)
  static const double paddingXl = 20.0;

  // ===== MARGIN CONSTANTS =====

  /// Medium margin (8px)
  static const double marginM = 8.0;

  // ===== BORDER RADIUS CONSTANTS =====

  /// Small border radius (4px)
  static const double borderRadiusS = 4.0;

  /// Medium border radius (8px)
  static const double borderRadiusM = 8.0;

  /// Large border radius (12px)
  static const double borderRadiusL = 12.0;

  /// Extra large border radius (12px) - max allowed per design spec
  static const double borderRadiusXl = 12.0;

  /// Round border radius (50px) for fully rounded elements
  static const double borderRadiusRound = 50.0;

  // Legacy radius aliases (prefer borderRadius* names above)
  static const double radiusS = borderRadiusS;
  static const double radiusM = borderRadiusM;
  static const double radiusL = borderRadiusL;
  static const double smallRadius = borderRadiusS;
  static const double radiusMedium = borderRadiusM;
  static const double radiusLarge = borderRadiusL;

  // Additional border radius constants for common hardcoded values
  static const double borderRadius0 = 0.0;
  static const double borderRadius4 = 4.0;
  static const double borderRadius6 = 6.0;
  static const double borderRadius7 = 7.0;
  static const double borderRadius8 = 8.0;
  static const double borderRadius10 = 10.0;
  static const double borderRadius12 = 12.0;
  static const double borderRadius16 = 16.0;
  static const double borderRadius20 = 20.0;
  static const double borderRadius25 = 25.0;
  static const double borderRadius100 = 100.0;

  // ===== ELEVATION CONSTANTS =====

  /// Low elevation (matching original AppTheme)
  static const double elevationLow = 2.0;

  /// Medium elevation (matching original AppTheme)
  static const double elevationMedium = 4.0;

  /// High elevation (matching original AppTheme)
  static const double elevationHigh = 8.0;

  /// Extra high elevation (8dp)
  static const double elevationXHigh = 8.0;

  /// Maximum elevation (12dp)
  static const double elevationMax = 12.0;

  // ===== COMPONENT DIMENSIONS =====

  /// Standard button height (matching original AppTheme)
  static const double buttonHeight = 56.0;

  // ===== ICON DIMENSIONS =====

  /// Small icon size
  static const double iconSizeS = 16.0;

  /// Medium icon size
  static const double iconSizeM = 20.0;

  /// Large icon size
  static const double iconSizeL = 24.0;

  /// Extra large icon size
  static const double iconSizeXl = 32.0;

  /// Extra extra large icon size
  static const double iconSizeXxl = 48.0;

  /// Hero icon size (72px)
  static const double iconSizeHero = 72.0;

  /// Action icon size (20px)
  static const double iconSizeAction = 20.0;

  /// Display icon size (alias)
  static const double iconSizeDisplay = iconSizeXl;

  /// Info icon size (alias)
  static const double iconSizeInfo = iconSizeM;

  /// Extra small icon size (12px)
  static const double iconSizeXs = 12.0;

  /// Icon size 14px
  static const double iconSize14 = 14.0;

  /// Icon size 18px
  static const double iconSize18 = 18.0;

  /// Icon size 28px
  static const double iconSize28 = 28.0;

  /// Extra extra extra large icon size (64px)
  static const double iconSizeXXXl = 64.0;

  // ===== STROKE/BORDER WIDTH CONSTANTS =====

  /// Thin stroke width (0.5px)
  static const double strokeWidth05 = 0.5;

  /// Standard stroke width (2px)
  static const double strokeWidth2 = 2.0;

  // ===== DOT AND INDICATOR CONSTANTS =====

  /// Standard dot size (8px)
  static const double dotSize = 8.0;

  // ===== HEIGHT CONSTANTS =====

  /// Large minimum height (200px)
  static const double minHeightLarge = 200.0;

  /// Empty state icon size (alias)
  static const double iconSizeEmptyState = iconSizeXl;

  // Removed redundant numeric aliases - use semantic names instead

  // ===== AVATAR DIMENSIONS =====

  /// Medium avatar size
  static const double avatarSizeM = 32.0;

  /// Medium avatar size (alias)
  static const double avatarSizeMedium = avatarSizeM;

  // ===== IMAGE DIMENSIONS =====

  /// Thumbnail image size
  static const double imageSizeThumbnail = 80.0; // Back to original size

  /// Large image size
  static const double imageSizeL = 300.0;

  /// Recipe card image height
  static const double recipeImageHeight = 160.0;

  /// Thumbnail large size
  static const double thumbnailLargeSize = 120.0;

  /// Image height medium
  static const double imageHeightMedium = 160.0;

  /// Image size large
  static const double imageSizeLarge = imageSizeL;

  /// Image size card
  static const double imageSizeCard = 150.0;

  /// Image size hero
  static const double imageSizeHero = 400.0;


  /// Minimum touch target size (Material Design requirement)
  static const double minTouchTarget = 48.0;

  // ===== BORDER WIDTH CONSTANTS =====

  /// Thin border width
  static const double borderWidthThin = 0.5;

  /// Standard border width
  static const double borderWidthStandard = 1.0;

  /// Thick border width
  static const double borderWidthThick = 2.0;


  // ===== ANIMATION DURATIONS =====

  /// Fast animation duration (150ms)
  static const Duration animationDurationFast = Duration(milliseconds: 150);

  /// Medium animation duration (200ms)
  static const Duration animationDurationMedium = Duration(milliseconds: 200);

  /// Common animation duration (300ms)
  static const Duration animationDurationCommon = Duration(milliseconds: 300);

  /// Slow animation duration (350ms)
  static const Duration animationDurationSlow = Duration(milliseconds: 350);

  /// Long animation duration (500ms)
  static const Duration animationDurationLong = Duration(milliseconds: 500);

  /// Snackbar duration (3000ms)
  static const Duration snackbarDuration = Duration(milliseconds: 3000);

  // ===== OPACITY/ALPHA CONSTANTS =====

  /// Very light transparency (0.1)
  static const double opacityVeryLight = 0.1;

  /// Light transparency (0.2)
  static const double opacityLight = 0.2;

  /// Medium light transparency (0.3)
  static const double opacityMediumLight = 0.3;

  /// Medium transparency (0.4)
  static const double opacityMedium = 0.4;

  /// Half transparency (0.5)
  static const double opacityHalf = 0.5;

  /// Medium dark transparency (0.6)
  static const double opacityMediumDark = 0.6;

  /// Dark transparency (0.7)
  static const double opacityDark = 0.7;

  /// Very dark transparency (0.8)
  static const double opacityVeryDark = 0.8;

  // ===== COMMON HEIGHT CONSTANTS =====

  /// Thumbnail height (80px)
  static const double heightThumbnail = 80.0;

  /// Medium container height (100px)
  static const double heightMedium = 100.0;

  /// Large container height (120px)
  static const double heightLarge = 120.0;

  /// Extra large container height (200px)
  static const double heightXLarge = 200.0;

  // ===== GRID CONSTANTS =====

  /// Grid aspect ratio for recipe cards
  static const double gridAspectRatio = 0.75;

  // ===== SCREEN LAYOUT DIMENSIONS =====

  /// Standard screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(paddingL);

  /// Medium padding (12px) - Alias
  static const double paddingMd = paddingM;

  /// List item padding
  static const EdgeInsets listItemPadding = EdgeInsets.all(paddingM);

  /// Section padding
  static const EdgeInsets sectionPadding = EdgeInsets.all(paddingL);

  // Component-specific radius aliases (semantic value)
  /// Card border radius (8px)
  static const double cardBorderRadius = borderRadiusM;

  /// Chip radius (4px)
  static const double chipRadius = borderRadiusS;

  /// Bottom sheet border radius (12px)
  static const double bottomSheetBorderRadius = borderRadiusXl;

  /// Divider height
  static const double dividerHeight = 1.0;

  /// Button width (standard)
  static const double buttonWidth = 120.0;


  // ===== UTILITY METHODS =====


  // ===== ELEVATION AND SHADOW CONSTANTS (FROM ORIGINAL APPTHEME) =====
  // Note: Elevation constants are already defined above in the ELEVATION section

  // ===== LEGACY COMPATIBILITY ALIASES =====

  /// Extra small border radius (2px)
  static const double borderRadiusXs = 2.0;

  /// Extra large buttons width
  static const double buttonWidthXLarge = 280.0;

  // ===== GRID BUTTON LAYOUT CONSTANTS =====

  /// Optimal button size for mobile recipe grid (prevents text wrapping)
  static const double gridButtonSize = 160.0;
  
  /// Spacing between grid buttons
  static const double gridButtonSpacing = 24.0;
  
  /// Spacing between grid rows
  static const double gridRowSpacing = 20.0;



  // ===== SHADOWS (FROM ORIGINAL APPTHEME) =====

  /// Card shadow definition
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000), // Subtle shadow like in Figma
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x05000000), // Extra subtle shadow for depth
      blurRadius: 4,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];


  // ===== STANDARDIZED EDGE INSETS (FROM ORIGINAL APPTHEME) =====


}