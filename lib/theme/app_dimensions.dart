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

  // Aliases for backwards compatibility
  static const double spacingXxs = 2.0; // Extra extra small spacing (2px)
  static const double spacingS = 3.0; // Small spacing (3px) - reduced for tighter grid
  static const double spacingM = 8.0; // Medium spacing (8px) - alias for spacingSm
  static const double spacingL = 12.0; // Large spacing (12px)
  static const double spacingXxxl = 24.0; // Triple extra large spacing (24px) - alias for spacingLg

  // Additional spacing constants for common hardcoded values
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0;
  static const double spacing16 = 16.0;
  static const double spacing18 = 18.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;
  static const double spacing50 = 50.0;
  static const double spacing60 = 60.0;
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

  // ===== GAP CONSTANTS =====

  /// Small gap (8px) - moved to bottom as widget
  // static const double smallGap = spacingM; // Removed duplicate - see widgets section

  /// Medium gap (16px) - moved to bottom as widget
  // static const double mediumGap = spacingXl; // Removed duplicate - see widgets section

  /// Large gap (24px) - moved to bottom as widget
  // static const double largeGap = spacingXxxl; // Removed duplicate - see widgets section

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

  /// Slow animation duration (350ms)
  static const Duration animationDurationSlow = Duration(milliseconds: 350);

  /// Snackbar duration (3000ms)
  static const Duration snackbarDuration = Duration(milliseconds: 3000);

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

  /// Card border radius (alias)
  static const double cardBorderRadius = borderRadiusM;

  /// Chip radius (alias)
  static const double chipRadius = borderRadiusS;

  /// Small radius (alias)
  static const double smallRadius = borderRadiusS;

  /// Medium radius (alias)
  static const double radiusMedium = borderRadiusM;

  /// Large radius (alias)
  static const double largeRadius = borderRadiusL;

  /// Large radius (alias)
  static const double radiusLarge = borderRadiusL;

  /// Small radius (alias)
  static const double radiusSmall = borderRadiusS;

  /// Round radius (alias)
  static const double roundRadius = borderRadiusRound;

  /// Bottom sheet border radius
  static const double bottomSheetBorderRadius = borderRadiusXl;

  /// Divider height
  static const double dividerHeight = 1.0;

  /// Button width (standard)
  static const double buttonWidth = 120.0;


  // ===== UTILITY METHODS =====


  // ===== ELEVATION AND SHADOW CONSTANTS (FROM ORIGINAL APPTHEME) =====
  // Note: Elevation constants are already defined above in the ELEVATION section

  // ===== LEGACY COMPATIBILITY ALIASES =====
  // Additional aliases for backwards compatibility

  /// Extra small border radius (2px)
  static const double borderRadiusXs = 2.0;

  // ===== NEW COMPONENT COMPATIBILITY =====
  // Properties expected by new social platform components

  /// Small radius (alias for borderRadiusS)
  static const double radiusS = borderRadiusS;
  
  /// Medium radius (alias for borderRadiusM)
  static const double radiusM = borderRadiusM;
  
  /// Large radius (alias for borderRadiusL)
  static const double radiusL = borderRadiusL;

  /// Extra large buttons width
  static const double buttonWidthXLarge = 280.0; // Extra large buttons

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