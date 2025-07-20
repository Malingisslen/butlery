// lib/theme/app_dimensions.dart

import 'package:flutter/material.dart';

/// Spacing, sizing, and layout constants for the Butlery app
/// Provides consistent dimensions throughout the application
/// 
/// Design Philosophy:
/// - Semantic naming over numeric values (e.g., spacingM vs spacing8)
/// - Separate constants for different contexts (spacing, padding, margin)
/// - This allows for easy global adjustments and semantic clarity
class AppDimensions {
  AppDimensions._(); // Private constructor to prevent instantiation

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
  static const double spacingS = 6.0; // Small spacing (6px)
  static const double spacingM = 8.0; // Medium spacing (8px) - alias for spacingSm
  static const double spacingL = 12.0; // Large spacing (12px)
  static const double spacingXxxl = 24.0; // Triple extra large spacing (24px) - alias for spacingLg
  static const double spacingHuge = 64.0; // For large section-separators - matches original
  static const double spacingMassive = 48.0; // Massive spacing (48px)

  // ===== PADDING CONSTANTS =====

  /// Extra small padding (4px)
  static const double paddingXs = 4.0;

  /// Small padding (8px)
  static const double paddingS = 8.0;

  /// Medium padding (12px)
  static const double paddingM = 12.0;

  /// Large padding (16px)
  static const double paddingL = 16.0;

  /// Extra large padding (20px)
  static const double paddingXl = 20.0;

  /// Extra extra large padding (24px)
  static const double paddingXxl = 24.0;

  /// Triple extra large padding (32px)
  static const double paddingXxxl = 32.0;

  // ===== MARGIN CONSTANTS =====

  /// Small margin (4px)
  static const double marginS = 4.0;

  /// Medium margin (8px)
  static const double marginM = 8.0;

  /// Large margin (12px)
  static const double marginL = 12.0;

  /// Extra large margin (16px)
  static const double marginXl = 16.0;

  /// Extra extra large margin (20px)
  static const double marginXxl = 20.0;

  /// Triple extra large margin (24px)
  static const double marginXxxl = 24.0;

  // ===== BORDER RADIUS CONSTANTS =====

  /// Small border radius (4px)
  static const double borderRadiusS = 4.0;

  /// Medium border radius (8px)
  static const double borderRadiusM = 8.0;

  /// Large border radius (12px)
  static const double borderRadiusL = 12.0;

  /// Extra large border radius (16px)
  static const double borderRadiusXl = 16.0;

  /// Extra extra large border radius (20px)
  static const double borderRadiusXxl = 20.0;

  /// Circular border radius (999px)
  static const double borderRadiusCircular = 999.0;

  /// Round border radius (50px) for fully rounded elements
  static const double borderRadiusRound = 50.0;

  // ===== ELEVATION CONSTANTS =====

  /// No elevation
  static const double elevationNone = 0.0;

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

  /// Small button height
  static const double buttonHeightSmall = 36.0;

  /// Large button height
  static const double buttonHeightLarge = 56.0;

  /// Standard text field height
  static const double textFieldHeight = 48.0;

  /// App bar height
  static const double appBarHeight = 56.0;

  /// Bottom navigation bar height
  static const double bottomNavHeight = 80.0;

  /// Tab bar height
  static const double tabBarHeight = 48.0;

  /// List tile height
  static const double listTileHeight = 72.0;

  /// Small list tile height
  static const double listTileHeightSmall = 56.0;

  /// Large list tile height
  static const double listTileHeightLarge = 88.0;

  /// Card minimum height
  static const double cardMinHeight = 120.0;

  /// Floating action button size
  static const double fabSize = 56.0;

  /// Small floating action button size
  static const double fabSizeSmall = 40.0;

  /// Large floating action button size
  static const double fabSizeLarge = 64.0;

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

  /// Small icon size (alias)
  static const double iconSizeSmall = iconSizeS;

  /// Large icon size (alias) 
  static const double iconSizeLarge = iconSizeL;

  /// Display icon size (alias)
  static const double iconSizeDisplay = iconSizeXl;

  /// Info icon size (alias)
  static const double iconSizeInfo = iconSizeM;

  /// Navigation icon size (alias)
  static const double iconSizeNavigation = iconSizeM;

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

  /// Small avatar size
  static const double avatarSizeS = 24.0;

  /// Medium avatar size
  static const double avatarSizeM = 32.0;

  /// Large avatar size
  static const double avatarSizeL = 48.0;

  /// Extra large avatar size
  static const double avatarSizeXl = 64.0;

  /// Profile avatar size
  static const double avatarSizeProfile = 96.0;

  /// Medium avatar size (alias)
  static const double avatarSizeMedium = avatarSizeM;

  // ===== IMAGE DIMENSIONS =====

  /// Thumbnail image size
  static const double imageSizeThumbnail = 80.0;

  /// Small image size
  static const double imageSizeS = 120.0;

  /// Medium image size
  static const double imageSizeM = 200.0;

  /// Large image size
  static const double imageSizeL = 300.0;

  /// Recipe card image height
  static const double recipeImageHeight = 160.0;

  /// Recipe detail image height
  static const double recipeDetailImageHeight = 240.0;

  /// Thumbnail large size
  static const double thumbnailLargeSize = 120.0;

  /// Thumbnail size
  static const double thumbnailSize = 80.0;

  /// Recipe image size (matching original AppTheme - 70x70 pixels)
  static const double recipeImageSize = 70.0;

  /// Image height medium
  static const double imageHeightMedium = 160.0;

  /// Image size large
  static const double imageSizeLarge = imageSizeL;

  /// Image size card
  static const double imageSizeCard = 150.0;

  /// Image size hero
  static const double imageSizeHero = 400.0;

  // ===== SPECIFIC IMAGE CONSTANTS FROM ORIGINAL APPTHEME =====

  /// Image height small (matching original AppTheme)
  static const double imageHeightSmall = 100.0;

  /// Image height large (matching original AppTheme)
  static const double imageHeightLarge = 300.0;

  /// Input height (matching original AppTheme)
  static const double inputHeight = 48.0;

  /// Image aspect ratio (matching original AppTheme)
  static const double imageAspectRatio = 16 / 9;

  // ===== LAYOUT DIMENSIONS =====

  /// Maximum content width for large screens
  static const double maxContentWidth = 1200.0;

  /// Maximum dialog width
  static const double maxDialogWidth = 400.0;

  /// Maximum bottom sheet height ratio
  static const double maxBottomSheetHeightRatio = 0.9;

  /// Minimum touch target size (Material Design requirement)
  static const double minTouchTarget = 48.0;

  // ===== BORDER WIDTH CONSTANTS =====

  /// Thin border width
  static const double borderWidthThin = 0.5;

  /// Standard border width
  static const double borderWidthStandard = 1.0;

  /// Thick border width
  static const double borderWidthThick = 2.0;

  /// Extra thick border width
  static const double borderWidthXThick = 3.0;

  // ===== ANIMATION DURATIONS =====

  /// Fast animation duration (150ms)
  static const Duration animationFast = Duration(milliseconds: 150);

  /// Standard animation duration (250ms)
  static const Duration animationStandard = Duration(milliseconds: 250);

  /// Slow animation duration (350ms)
  static const Duration animationSlow = Duration(milliseconds: 350);

  /// Page transition duration (300ms)
  static const Duration pageTransition = Duration(milliseconds: 300);

  /// Loading animation duration (1000ms)
  static const Duration loadingAnimation = Duration(milliseconds: 1000);

  /// Extra fast animation duration (100ms)
  static const Duration animationXFast = Duration(milliseconds: 100);

  /// Fast animation duration (150ms) - alias for consistency
  static const Duration animationDurationFast = animationFast;

  /// Standard animation duration (250ms) - alias for consistency
  static const Duration animationDurationStandard = animationStandard;

  /// Slow animation duration (350ms) - alias for consistency
  static const Duration animationDurationSlow = animationSlow;

  /// Delay animation duration (500ms)
  static const Duration animationDurationDelay = Duration(milliseconds: 500);

  /// Medium animation duration (200ms)
  static const Duration animationDurationMedium = Duration(milliseconds: 200);

  /// Snackbar duration (3000ms)
  static const Duration snackbarDuration = Duration(milliseconds: 3000);

  /// Wait duration 2 seconds
  static const Duration wait2s = Duration(seconds: 2);

  /// Wait duration 3 seconds
  static const Duration wait3s = Duration(seconds: 3);

  // ===== SCREEN LAYOUT DIMENSIONS =====

  /// Standard screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(paddingL);

  /// Medium padding (12px) - Alias
  static const double paddingMd = paddingM;

  /// Standard input padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: paddingM,
    vertical: paddingS,
  );

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

  /// Button width XLarge - moved to specialized section
  // static const double buttonWidthXLarge = 200.0; // Removed duplicate

  /// Standard button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: paddingXl,
    vertical: paddingM,
  );

  // ===== RESPONSIVE BREAKPOINTS =====

  /// Mobile breakpoint
  static const double breakpointMobile = 600.0;

  /// Tablet breakpoint
  static const double breakpointTablet = 900.0;

  /// Desktop breakpoint
  static const double breakpointDesktop = 1200.0;

  // ===== GRID CONSTANTS =====

  /// Grid spacing
  static const double gridSpacing = 16.0;

  /// Grid cross axis count for mobile
  static const int gridCrossAxisCountMobile = 2;

  /// Grid cross axis count for tablet
  static const int gridCrossAxisCountTablet = 3;

  /// Grid cross axis count for desktop
  static const int gridCrossAxisCountDesktop = 4;

  /// Grid aspect ratio for recipe cards
  static const double gridAspectRatio = 0.75;

  // ===== UTILITY METHODS =====

  /// Get responsive grid cross axis count based on screen width
  static int getGridCrossAxisCount(double screenWidth) {
    if (screenWidth >= breakpointDesktop) {
      return gridCrossAxisCountDesktop;
    } else if (screenWidth >= breakpointTablet) {
      return gridCrossAxisCountTablet;
    } else {
      return gridCrossAxisCountMobile;
    }
  }

  /// Get responsive padding based on screen width
  static double getResponsivePadding(double screenWidth) {
    if (screenWidth >= breakpointDesktop) {
      return paddingXxxl;
    } else if (screenWidth >= breakpointTablet) {
      return paddingXxl;
    } else {
      return paddingL;
    }
  }

  /// Check if screen size is mobile
  static bool isMobile(double screenWidth) {
    return screenWidth < breakpointMobile;
  }

  /// Check if screen size is tablet
  static bool isTablet(double screenWidth) {
    return screenWidth >= breakpointMobile && screenWidth < breakpointDesktop;
  }

  /// Check if screen size is desktop
  static bool isDesktop(double screenWidth) {
    return screenWidth >= breakpointDesktop;
  }

  // ===== ELEVATION AND SHADOW CONSTANTS (FROM ORIGINAL APPTHEME) =====
  // Note: Elevation constants are already defined above in the ELEVATION section

  // ===== LEGACY COMPATIBILITY ALIASES =====
  // Additional aliases for backwards compatibility

  /// Extra small border radius (2px)
  static const double borderRadiusXs = 2.0;

  /// Medium horizontal gap (16px) - Alias - moved to widgets section
  // static const double mediumHorizontalGap = spacingXl; // Removed duplicate

  // ===== GAP WIDGETS (FROM ORIGINAL APPTHEME) =====

  /// Pre-configured SizedBox widgets for common gaps
  static Widget get tinyGap => const SizedBox(height: spacingXs); // 4px
  static Widget get smallGap => const SizedBox(height: spacingSm); // 8px
  static Widget get mediumGap => const SizedBox(height: spacingMd); // 16px
  static Widget get largeGap => const SizedBox(height: spacingLg); // 24px
  static Widget get extraLargeGap => const SizedBox(height: spacingXl); // 32px
  static Widget get hugeGap => const SizedBox(height: spacingXxl); // 48px

  /// Horizontal SizedBox widgets for gaps between elements
  static Widget get smallHorizontalGap => const SizedBox(width: spacingSm); // 8px
  static Widget get mediumHorizontalGap => const SizedBox(width: spacingMd); // 16px
  static Widget get largeHorizontalGap => const SizedBox(width: spacingLg); // 24px

  // ===== CONTAINER HEIGHTS (FROM ORIGINAL APPTHEME) =====

  /// Standardized container heights for consistency
  static const double containerHeightSmall = 200.0; // Small containers
  static const double containerHeightMedium = 300.0; // Medium containers
  static const double containerHeightLarge = 400.0; // Large containers
  static const double containerHeightXLarge = 500.0; // Extra large containers

  // ===== BUTTON WIDTHS (FROM ORIGINAL APPTHEME) =====

  /// Standardized button widths for consistency
  static const double buttonWidthSmall = 80.0; // Small buttons (e.g. "OK")
  static const double buttonWidthMedium = 140.0; // Medium buttons (e.g. "Skapa & Dela")
  static const double buttonWidthLarge = 200.0; // Large buttons
  static const double buttonWidthXLarge = 280.0; // Extra large buttons

  // ===== IMAGE CAROUSEL AND THUMBNAILS =====

  /// Image sizes for RecipeImageManager
  static const double imageWidthSmall = 120.0;
  static const double imageCarouselHeight = 250.0;

  /// Thumbnails
  static const double thumbnailSmallSize = 40.0;
  static const double thumbnailAspectRatio = 1.0;

  // ===== BORDER RADIUS CONSTANTS (ADDITIONAL) =====

  /// Bottom sheet border radius
  static const BorderRadius bottomSheetBorderRadiusShape = BorderRadius.only(
    topLeft: Radius.circular(borderRadiusXl), // 16px
    topRight: Radius.circular(borderRadiusXl), // 16px
  );

  /// Card border radius constant
  static const BorderRadius cardBorderRadiusShape = BorderRadius.all(
    Radius.circular(borderRadiusM), // 8px
  );

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

  /// Button shadow definition
  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x1A3B82F6), // Blue shadow for buttons
      blurRadius: 8,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  /// Floating button shadow definition
  static const List<BoxShadow> floatingButtonShadow = [
    BoxShadow(
      color: Color(0x1F000000), // Stronger shadow for floating buttons
      blurRadius: 16,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // ===== STANDARDIZED EDGE INSETS (FROM ORIGINAL APPTHEME) =====

  /// Recipe card margins
  static const EdgeInsets recipeCardMargin = EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0);

  /// Recipe card padding
  static const EdgeInsets recipeCardPadding = EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);

  // ===== STANDARD DECORATIONS GETTERS =====

  /// Standard card decoration
  static BoxDecoration get standardCardDecoration => BoxDecoration(
    borderRadius: BorderRadius.circular(radiusLarge),
    boxShadow: cardShadow,
  );

  /// Small radius decoration
  static BoxDecoration get smallRadiusDecoration => BoxDecoration(
    borderRadius: BorderRadius.circular(radiusSmall),
  );

  /// Medium radius decoration
  static BoxDecoration get mediumRadiusDecoration => BoxDecoration(
    borderRadius: BorderRadius.circular(radiusMedium),
  );

  /// Large radius decoration
  static BoxDecoration get largeRadiusDecoration => BoxDecoration(
    borderRadius: BorderRadius.circular(radiusLarge),
  );
}