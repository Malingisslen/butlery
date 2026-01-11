/// Dimension system providing unified spacing, sizing, and layout constants.

import 'package:flutter/material.dart';
import 'package:butlery/core/responsive/breakpoints.dart';

/// Central repository for spatial and sizing constants.
class AppDimensions {
  /// Private constructor to prevent instantiation of utility class
  AppDimensions._();

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

  /// Huge spacing (80px) - for large gaps like avatar widths, empty states
  static const double spacingHuge = 80.0;

  /// Tight spacing (6px) - between scale points, for compact layouts
  static const double spacingTight = 6.0;

  /// Moderate spacing (14px) - between scale points, for input padding
  static const double spacingModerate = 14.0;

  /// **Spacing Scale Guide:**
  /// Use semantic names instead of numeric constants
  /// Scale: Xs(4) → Sm(8) → Md(16) → Lg(24) → Xl(32) → Xxl(48)
  /// For values between scale points, combine semantically:
  /// - 12px = spacingSm + spacingXs (8 + 4)
  /// - 20px = spacingMd + spacingXs (16 + 4)
  /// - 28px = spacingLg + spacingXs (24 + 4)
  /// ❌ Don't: padding: spacing12
  /// ✅ Do: padding: spacingMd or combine: spacingSm + spacingXs

  // Minimal aliases for backward compatibility with existing code
  static const double spacingXxs = 2.0; // Extra extra small (2px)
  static const double spacingS = 3.0; // 3px - use sparingly
  static const double spacing6 = 6.0; // 6px - for compact layouts
  static const double spacingM = spacingSm; // Alias for 8px
  static const double spacingL = (spacingSm + spacingXs); // 12px (8+4)
  static const double spacingXxxl = spacingLg; // Alias for 24px

  /// Extra extra small padding (2px)
  static const double paddingXxs = 2.0;

  /// Small padding (8px)
  static const double paddingS = 8.0;

  /// Medium-small padding (10px)
  static const double paddingMs = 10.0;

  /// Medium padding (12px)
  static const double paddingM = 12.0;

  /// Large padding (16px)
  static const double paddingL = 16.0;

  /// Extra large padding (20px)
  static const double paddingXl = 20.0;

  /// Medium margin (8px)
  static const double marginM = 8.0;

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

  /// Standard button height (matching original AppTheme)
  static const double buttonHeight = 56.0;

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

  /// Thin stroke width (0.5px)
  static const double strokeWidth05 = 0.5;

  /// Standard stroke width (2px)
  static const double strokeWidth2 = 2.0;

  /// Standard dot size (8px)
  static const double dotSize = 8.0;

  /// Large minimum height (200px)
  static const double minHeightLarge = 200.0;

  /// Empty state icon size (alias)
  static const double iconSizeEmptyState = iconSizeXl;

  // Removed redundant numeric aliases - use semantic names instead

  /// Extra small avatar size (24px)
  static const double avatarSizeXs = 24.0;

  /// Small avatar size (32px)
  static const double avatarSizeSm = 32.0;

  /// Medium avatar size (32px) - alias for backward compatibility
  static const double avatarSizeM = 32.0;

  /// Medium avatar size (alias)
  static const double avatarSizeMedium = avatarSizeM;

  /// Large avatar size (48px)
  static const double avatarSizeLg = 48.0;

  /// Extra large avatar size (64px)
  static const double avatarSizeXl = 64.0;

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

  // Card Dimensions
  /// Small card width (160px)
  static const double cardWidthSmall = 160.0;

  /// Small card image height (100px)
  static const double cardImageHeightSmall = 100.0;

  // Spinner/Progress Indicators
  /// Small spinner size (20px)
  static const double spinnerSizeSmall = 20.0;

  /// Medium spinner size (30px)
  static const double spinnerSizeMedium = 30.0;

  // Dialog Constraints
  /// Small dialog max width (300px)
  static const double dialogMaxWidthSmall = 300.0;

  /// Medium dialog max width (500px)
  static const double dialogMaxWidthMedium = 500.0;

  /// Large dialog max width (700px)
  static const double dialogMaxWidthLarge = 700.0;

  /// Small dialog max height (400px)
  static const double dialogMaxHeightSmall = 400.0;

  /// Medium dialog max height (600px)
  static const double dialogMaxHeightMedium = 600.0;

  /// Large dialog max height (800px)
  static const double dialogMaxHeightLarge = 800.0;

  /// Minimum touch target size (Material Design requirement)
  static const double minTouchTarget = 48.0;

  /// Thin border width
  static const double borderWidthThin = 0.5;

  /// Standard border width
  static const double borderWidthStandard = 1.0;

  /// Thick border width
  static const double borderWidthThick = 2.0;

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

  /// Extended animation duration (1200ms)
  static const Duration animationDurationExtended = Duration(milliseconds: 1200);

  /// Snackbar duration (3000ms)
  static const Duration snackbarDuration = Duration(milliseconds: 3000);

  /// Extra very light transparency (0.05)
  static const double opacityExtraVeryLight = 0.05;

  /// Very light transparency (0.1)
  static const double opacityVeryLight = 0.1;

  /// Light subtle transparency (0.15)
  static const double opacityLightSubtle = 0.15;

  /// Light transparency (0.2)
  static const double opacityLight = 0.2;

  /// Light medium transparency (0.25)
  static const double opacityLightMedium = 0.25;

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

  /// Extra dark transparency (0.9)
  static const double opacityExtraDark = 0.9;

  /// Thumbnail height (80px)
  static const double heightThumbnail = 80.0;

  /// Medium container height (100px)
  static const double heightMedium = 100.0;

  /// Large container height (120px)
  static const double heightLarge = 120.0;

  /// Extra large container height (200px)
  static const double heightXLarge = 200.0;

  /// Grid aspect ratio for recipe cards
  static const double gridAspectRatio = 0.75;

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

  /// Extra small border radius (2px)
  static const double borderRadiusXs = 2.0;

  /// Extra large buttons width
  static const double buttonWidthXLarge = 280.0;

  /// Optimal button size for mobile recipe grid (prevents text wrapping)
  static const double gridButtonSize = 160.0;

  /// Spacing between grid buttons
  static const double gridButtonSpacing = 24.0;

  /// Spacing between grid rows
  static const double gridRowSpacing = 20.0;

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

  /// Get responsive spacing based on screen size
  /// Automatically scales spacing:
  /// - Mobile: base value
  /// - Tablet: base * 1.25
  /// - Desktop: base * 1.5
  /// Example:
  /// ```dart
  /// final padding = AppDimensions.responsiveSpacing(context, spacingMd);
  /// // Mobile: 16px, Tablet: 20px, Desktop: 24px
  /// ```
  static double responsiveSpacing(BuildContext context, double base) {
    return Breakpoints.valueFor(
      context: context,
      mobile: base,
      tablet: base * 1.25,
      desktop: base * 1.5,
    );
  }

  /// Get responsive padding based on screen size
  /// Automatically scales padding values for different screen sizes.
  /// Example:
  /// ```dart
  /// final padding = AppDimensions.responsivePadding(context);
  /// // Mobile: 16px, Tablet: 20px, Desktop: 24px
  /// ```
  static double responsivePadding(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: paddingL,
      tablet: paddingXl,
      desktop: spacingLg,
    );
  }

  /// Get responsive icon size based on screen size
  /// Example:
  /// ```dart
  /// final iconSize = AppDimensions.responsiveIconSize(context, iconSizeL);
  /// // Mobile: 24px, Tablet: 27.6px, Desktop: 30px
  /// ```
  static double responsiveIconSize(BuildContext context, double base) {
    return Breakpoints.valueFor(
      context: context,
      mobile: base,
      tablet: base * 1.15,
      desktop: base * 1.25,
    );
  }

  /// Get responsive content padding (horizontal screen padding)
  /// Returns EdgeInsets for screen content:
  /// - Mobile: 16px
  /// - Tablet: 24px
  /// - Desktop: 32px
  static EdgeInsets responsiveContentPadding(BuildContext context) {
    final padding = Breakpoints.valueFor(
      context: context,
      mobile: spacingMd,
      tablet: spacingLg,
      desktop: spacingXl,
    );
    return EdgeInsets.all(padding);
  }

  /// Get responsive horizontal padding only
  /// Useful for list items and cards that need horizontal padding
  static EdgeInsets responsiveHorizontalPadding(BuildContext context) {
    final padding = Breakpoints.valueFor(
      context: context,
      mobile: spacingMd,
      tablet: spacingLg,
      desktop: spacingXl,
    );
    return EdgeInsets.symmetric(horizontal: padding);
  }

  /// Get responsive grid spacing based on screen size
  /// Returns spacing for grid layouts:
  /// - Mobile: 16px
  /// - Tablet: 20px
  /// - Desktop: 24px
  static double responsiveGridSpacing(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: spacingMd,
      tablet: spacingLg - spacingXs,
      desktop: spacingLg,
    );
  }

  /// Get responsive card padding
  /// Returns padding for cards:
  /// - Mobile: 16px
  /// - Tablet: 20px
  /// - Desktop: 24px
  static EdgeInsets responsiveCardPadding(BuildContext context) {
    final padding = Breakpoints.valueFor(
      context: context,
      mobile: spacingMd,
      tablet: spacingLg - spacingXs,
      desktop: spacingLg,
    );
    return EdgeInsets.all(padding);
  }

  /// Get responsive avatar size
  /// Returns avatar size based on screen:
  /// - Mobile: 40px
  /// - Tablet: 48px
  /// - Desktop: 56px
  static double responsiveAvatarSize(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: 40.0,
      tablet: 48.0,
      desktop: 56.0,
    );
  }

  /// Get responsive button height
  /// Returns button height:
  /// - Mobile: 48px (min touch target)
  /// - Tablet: 52px
  /// - Desktop: 56px
  static double responsiveButtonHeight(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: minTouchTarget,
      tablet: 52.0,
      desktop: buttonHeight,
    );
  }

  /// Get responsive image size for thumbnails
  /// Returns thumbnail size:
  /// - Mobile: 80px
  /// - Tablet: 96px
  /// - Desktop: 120px
  static double responsiveThumbnailSize(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: imageSizeThumbnail,
      tablet: 96.0,
      desktop: thumbnailLargeSize,
    );
  }

  /// Get responsive recipe card image height
  /// Returns image height for recipe cards:
  /// - Mobile: 160px
  /// - Tablet: 200px
  /// - Desktop: 240px
  static double responsiveRecipeImageHeight(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: recipeImageHeight,
      tablet: 200.0,
      desktop: 240.0,
    );
  }

  /// Get responsive grid cross-axis count
  /// Returns number of columns for grid:
  /// - Mobile: 1 column
  /// - Tablet: 2 columns
  /// - Desktop: 3 columns
  static int responsiveGridColumns(BuildContext context) {
    return Breakpoints.getGridColumnCount(context);
  }

  /// Get responsive card grid columns
  /// Returns number of columns for card grid (more conservative):
  /// - Mobile: 1 column
  /// - Tablet: 2 columns
  /// - Desktop: 2 columns
  /// - Large Desktop: 3 columns
  static int responsiveCardColumns(BuildContext context) {
    return Breakpoints.getCardColumnCount(context);
  }

  /// Get maximum content width for readability
  /// Prevents content from being too wide on large screens:
  /// - Mobile: No limit
  /// - Tablet: 800px
  /// - Desktop: 1200px
  static double responsiveMaxContentWidth(BuildContext context) {
    return Breakpoints.getMaxContentWidth(context);
  }

  /// Get maximum form width
  /// Forms should be centered and constrained on large screens:
  /// - Mobile: No limit
  /// - Tablet: 600px
  /// - Desktop: 600px
  static double responsiveMaxFormWidth(BuildContext context) {
    return Breakpoints.getMaxFormWidth(context);
  }

  /// Get responsive dialog width
  /// Dialogs should be comfortable to read:
  /// - Mobile: No limit (full width with padding)
  /// - Tablet: 500px
  /// - Desktop: 600px
  static double responsiveDialogWidth(BuildContext context) {
    return Breakpoints.getMaxDialogWidth(context);
  }

  /// Get responsive elevation for cards
  /// Subtle elevation on mobile, more prominent on larger screens:
  /// - Mobile: 2.0
  /// - Tablet: 4.0
  /// - Desktop: 4.0
  static double responsiveCardElevation(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: elevationLow,
      tablet: elevationMedium,
      desktop: elevationMedium,
    );
  }

  /// Get sidebar/navigation rail width
  /// Returns:
  /// - Mobile: 0 (no sidebar, uses bottom nav)
  /// - Tablet: 72 (NavigationRail compact)
  /// - Desktop: 256 (Drawer expanded)
  static double responsiveSidebarWidth(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: 0,
      tablet: 72,
      desktop: 256,
    );
  }
}
