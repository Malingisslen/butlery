/// Typography system for unified text styling in the Butlery application.
///
/// **UI Redesign Typography:**
/// - Headers & Navigation: Josefin Sans (lowercase, with letter-spacing)
/// - Body text: Space Grotesk
///
/// **Usage:**
/// - Use [headerFont] for app headers, navigation items
/// - Use [bodyFont] for body text, labels, buttons

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';

/// Central repository for all text styles in the Butlery application.
class AppTextStyles {
  /// Private constructor
  AppTextStyles._();

  /// Header font family - Josefin Sans for headers and navigation
  static const String headerFont = 'JosefinSans';

  /// Body font family - Space Grotesk for body text
  static const String bodyFont = 'SpaceGrotesk';

  /// Primary font family for body text.
  /// Uses Space Grotesk, falls back to system font on iOS.
  static String? get _primaryFontFamily {
    if (kIsWeb) return bodyFont;
    return Platform.isIOS ? null : bodyFont;
  }

  /// Header font family for headers and navigation.
  /// Uses Josefin Sans, falls back to system font on iOS.
  static String? get _headerFontFamily {
    if (kIsWeb) return headerFont;
    return Platform.isIOS ? null : headerFont;
  }

  /// Display Small - For prominent section headlines (Josefin Sans)
  static TextStyle get displaySmall => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        letterSpacing: 0.5,
      );

  /// Headline Medium - For section headers and content categories (Josefin Sans)
  static TextStyle get headlineMedium => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.sectionHeader,
        letterSpacing: 0.5,
      );

  /// Headline Small - For subsection titles and secondary headers (Josefin Sans)
  static TextStyle get headlineSmall => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        letterSpacing: 0.5,
      );

  /// Headline Bold - For prominent countdown timers and emphasis (Josefin Sans)
  static TextStyle get headlineBold => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        letterSpacing: 0.5,
      );

  /// Title Large - For recipe names and primary content (Space Grotesk)
  static TextStyle get titleLarge => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        height: 1.3,
      );

  /// Title Medium - For secondary titles and content headers (Space Grotesk)
  static TextStyle get titleMedium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        height: 1.3,
      );

  /// Title Small - Alias for headlineSmall
  static TextStyle get titleSmall => headlineSmall;

  /// Body Large - For main content text and instructions
  static TextStyle get bodyLarge => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textDark,
        height: 1.5,
      );

  /// Body Medium - For secondary content and descriptions
  static TextStyle get bodyMedium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textMedium,
        height: 1.4,
      );

  /// Body Small - For metadata and supplementary information
  static TextStyle get bodySmall => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: AppColors.recipeMeta,
        height: 1.3,
      );

  /// Label Large - For prominent buttons
  static TextStyle get labelLarge => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );

  /// Label Medium - For standard buttons
  static TextStyle get labelMedium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textMedium,
      );

  /// Label Small - For small buttons and tags
  static TextStyle get labelSmall => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textLight,
      );

  /// Recipe metadata style
  static TextStyle get recipeMeta => bodySmall.copyWith(
        color: AppColors.recipeMeta,
        fontWeight: FontWeight.w500,
      );

  /// Section header style
  static TextStyle get sectionHeader => headlineSmall.copyWith(
        color: AppColors.sectionHeader,
        fontWeight: FontWeight.w700,
      );

  /// Section title style (alias for section header)
  static TextStyle get sectionTitleStyle => sectionHeader;

  /// Button text style
  static TextStyle get buttonText => labelLarge;

  /// Label text style for form fields
  static TextStyle get labelText => labelMedium;

  /// Caption text style for helper text
  static TextStyle get captionText => labelSmall;

  /// Primary button text style
  static TextStyle get buttonPrimary => labelLarge;

  /// Button text style (alias)
  static TextStyle get buttonTextStyle => buttonText;

  /// Tab text style
  static TextStyle get tabText => labelMedium;

  /// Navigation text style (Josefin Sans for nav items)
  static TextStyle get navigationText => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.navUnselectedItem,
        letterSpacing: 0.3,
      );

  /// Error text style
  static TextStyle get errorText => bodySmall.copyWith(
        color: AppColors.error,
        fontWeight: FontWeight.w500,
      );

  /// Success text style
  static TextStyle get successText => bodySmall.copyWith(
        color: AppColors.success,
        fontWeight: FontWeight.w500,
      );

  /// App bar title style (Josefin Sans, lowercase style)
  static TextStyle get appBarTitle => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.headerForeground,
        letterSpacing: 0.5,
      );

  /// Card title style
  static TextStyle get cardTitle => titleMedium;

  /// Card title style (alias)
  static TextStyle get cardTitleStyle => cardTitle;

  /// List tile title style
  static TextStyle get listTileTitle => titleMedium;

  /// List tile subtitle style
  static TextStyle get listTileSubtitle => bodyMedium;

  /// Dialog title style
  static TextStyle get dialogTitle => titleLarge;

  /// Dialog content style
  static TextStyle get dialogContent => bodyLarge;

  /// Hint text style
  static TextStyle get hintText => bodyMedium.copyWith(
        color: AppColors.textLight,
      );

  // ============================================================
  // ADDITIONAL SEMANTIC TEXT STYLES (ACTUALLY USED)
  // ============================================================

  /// Metadata emphasized - for timestamps, counts with emphasis (56 usages)
  static TextStyle get metadataEmphasized => bodySmall.copyWith(
        color: AppColors.textMedium,
        fontWeight: FontWeight.w500,
      );

  /// Badge text style (7 usages)
  static TextStyle get badge => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
      );

  /// Badge text style large (5 usages)
  static TextStyle get badgeLarge => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMedium,
      );

  /// Title bold - for emphasized titles (52 usages)
  static TextStyle get titleBold => titleMedium.copyWith(
        fontWeight: FontWeight.w700,
      );

  /// Body bold - for emphasized body text (34 usages)
  static TextStyle get bodyBold => bodyMedium.copyWith(
        fontWeight: FontWeight.w600,
      );

  /// Body large bold (16 usages)
  static TextStyle get bodyLargeBold => bodyLarge.copyWith(
        fontWeight: FontWeight.w600,
      );

  /// Small text - 10px for very small labels (5 usages)
  static TextStyle get textXs => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.normal,
        color: AppColors.textMedium,
      );

  /// Small text emphasized - 10px bold (3 usages)
  static TextStyle get textXsBold => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMedium,
      );

  /// Medium small text - 11px (1 usage)
  static TextStyle get textSm => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: AppColors.textMedium,
      );

  /// 14px regular text (5 usages)
  static TextStyle get text14 => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textDark,
      );

  /// 14px medium weight text (19 usages)
  static TextStyle get text14Medium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      );

  /// 16px medium weight text (24 usages)
  static TextStyle get text16Medium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      );

  /// 20px semibold text (2 usages)
  static TextStyle get text20SemiBold => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );

  /// Body medium with error color - for inline error messages
  static TextStyle get bodyMediumError => bodyMedium.copyWith(
        color: AppColors.error,
      );

  /// Body medium with success color - for success state messages
  static TextStyle get bodyMediumSuccess => bodyMedium.copyWith(
        color: AppColors.success,
      );

  /// Body medium with warning color - for warning state messages
  static TextStyle get bodyMediumWarning => bodyMedium.copyWith(
        color: AppColors.warning,
      );

  /// Body medium muted - for secondary/muted body text
  static TextStyle get bodyMediumMuted => bodyMedium.copyWith(
        color: AppColors.textMedium,
      );

  /// Title medium muted - for muted/disabled titles
  static TextStyle get titleMediumMuted => titleMedium.copyWith(
        color: AppColors.textMedium,
      );

  /// Label small success - for success badges/indicators
  static TextStyle get labelSmallSuccess => labelSmall.copyWith(
        color: AppColors.success,
      );

  /// Small link text - for clickable metadata links
  static TextStyle get linkSmall => bodySmall.copyWith(
        color: AppColors.forestGreen,
      );

  /// Muted label - for section headers in cards
  static TextStyle get labelMediumMuted => labelMedium.copyWith(
        color: AppColors.textMedium,
      );

  /// Light body large - for text on dark/overlay backgrounds
  static TextStyle get bodyLargeLight => bodyLarge.copyWith(
        color: AppColors.neutralLight,
      );

  /// Snackbar/toast text - light text on dark backgrounds
  static TextStyle get snackbarText => bodyMedium.copyWith(
        color: AppColors.neutralLight,
      );

  /// Button text on colored backgrounds - white text for contrast
  static TextStyle get buttonTextLight => labelLarge.copyWith(
        color: AppColors.cardWhite,
      );

  /// Warning text - for warning state messages
  static TextStyle get warningText => bodySmall.copyWith(
        color: AppColors.warning,
      );

  /// Info text - for informational messages
  static TextStyle get infoText => bodySmall.copyWith(
        color: AppColors.info,
      );

  // ============================================================
  // UI REDESIGN SPECIFIC STYLES
  // ============================================================

  /// Header title style - for ButleryHeader (Josefin Sans, lowercase)
  static TextStyle get headerTitle => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.headerForeground,
        letterSpacing: 0.5,
      );

  /// Main view header title - large style for main views (32px, Josefin Sans)
  /// Used for "dina recept", "veckans meny", "inkopslista" headers
  static TextStyle get mainViewTitle => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.headerForeground,
        letterSpacing: 2,
        height: 1.1,
      );

  /// Header count badge text style
  static TextStyle get headerCountBadge => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.forestGreenDark,
        letterSpacing: 1,
      );

  /// Section header label style (uppercase, small, with letter-spacing)
  static TextStyle get sectionLabel => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 3,
        color: AppColors.rust,
      );

  /// Filter chip text style
  static TextStyle get filterChip => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  /// Navigation item label (Josefin Sans)
  static TextStyle get navLabel => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      );

  /// Empty state title (Josefin Sans)
  static TextStyle get emptyStateTitle => TextStyle(
        fontFamily: _headerFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        letterSpacing: 0.5,
      );

  /// Empty state body
  static TextStyle get emptyStateBody => bodyMedium.copyWith(
        color: AppColors.textMedium,
      );

  /// Recipe card title
  static TextStyle get recipeCardTitle => titleMedium.copyWith(
        fontWeight: FontWeight.w500,
      );

  /// Badge text style for unified badges
  static TextStyle get badgeText => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      );

  /// Creates a complete Material 3 TextTheme with platform-adaptive font family.
  /// Uses Josefin Sans for headers, Space Grotesk for body.
  static TextTheme createTextTheme() {
    return TextTheme(
      displaySmall: displaySmall,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }
}
