/// Typography system for unified text styling in the Butlery application.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';

/// Central repository for all text styles in the Butlery application.
class AppTextStyles {
  /// Private constructor
  AppTextStyles._();

  /// Platform-adaptive font family.
  /// Returns null on iOS to use the system font (SF Pro).
  /// Returns 'Inter' on Android and other platforms.
  static String? get _primaryFontFamily {
    if (kIsWeb) return 'Inter';
    return Platform.isIOS ? null : 'Inter';
  }

  /// Display Small - For prominent section headlines
  static TextStyle get displaySmall => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );

  /// Headline Medium - For section headers and content categories
  static TextStyle get headlineMedium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.sectionHeader,
        letterSpacing: -0.25,
      );

  /// Headline Small - For subsection titles and secondary headers
  static TextStyle get headlineSmall => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );

  /// Title Large - For recipe names and primary content
  static TextStyle get titleLarge => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        height: 1.3,
      );

  /// Title Medium - For secondary titles and content headers
  static TextStyle get titleMedium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
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

  /// Navigation text style
  static TextStyle get navigationText => labelSmall;

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

  /// App bar title style
  static TextStyle get appBarTitle => headlineMedium;

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

  /// Snackbar text style
  static TextStyle get snackbarText => bodyMedium;

  /// Hint text style
  static TextStyle get hintText => bodyMedium.copyWith(
        color: AppColors.textLight,
      );

  // ============================================================
  // ADDITIONAL SEMANTIC TEXT STYLES
  // Use these instead of inline TextStyle() with hardcoded values
  // ============================================================

  /// Caption style - small supplementary text
  static TextStyle get caption => bodySmall.copyWith(
        color: AppColors.textLight,
      );

  /// Caption emphasized - small text with emphasis
  static TextStyle get captionEmphasized => bodySmall.copyWith(
        color: AppColors.textMedium,
        fontWeight: FontWeight.w500,
      );

  /// Overline style - uppercase small labels
  static TextStyle get overline => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textMedium,
        letterSpacing: 1.5,
      );

  /// Metadata style - for timestamps, counts, etc.
  static TextStyle get metadata => bodySmall.copyWith(
        color: AppColors.textMedium,
        fontWeight: FontWeight.w400,
      );

  /// Metadata emphasized
  static TextStyle get metadataEmphasized => bodySmall.copyWith(
        color: AppColors.textMedium,
        fontWeight: FontWeight.w500,
      );

  /// Price/number display style
  static TextStyle get price => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );

  /// Badge text style
  static TextStyle get badge => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
      );

  /// Badge text style large
  static TextStyle get badgeLarge => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMedium,
      );

  /// Chip text style
  static TextStyle get chip => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textMedium,
      );

  /// Input text style
  static TextStyle get input => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textDark,
      );

  /// Counter text style (for character counts, etc.)
  static TextStyle get counter => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textLight,
      );

  /// Link text style
  static TextStyle get link => bodyMedium.copyWith(
        color: AppColors.primaryBlue,
        decoration: TextDecoration.underline,
      );

  /// Timestamp style
  static TextStyle get timestamp => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: AppColors.textLight,
      );

  /// Status text style (online, offline, etc.)
  static TextStyle get status => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textMedium,
      );

  /// Warning text style
  static TextStyle get warningText => bodySmall.copyWith(
        color: AppColors.warning,
        fontWeight: FontWeight.w500,
      );

  /// Info text style
  static TextStyle get infoText => bodySmall.copyWith(
        color: AppColors.info,
        fontWeight: FontWeight.w500,
      );

  /// Title bold - for emphasized titles
  static TextStyle get titleBold => titleMedium.copyWith(
        fontWeight: FontWeight.w700,
      );

  /// Body bold - for emphasized body text
  static TextStyle get bodyBold => bodyMedium.copyWith(
        fontWeight: FontWeight.w600,
      );

  /// Body large bold
  static TextStyle get bodyLargeBold => bodyLarge.copyWith(
        fontWeight: FontWeight.w600,
      );

  /// Small text - 10px for very small labels
  static TextStyle get textXs => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.normal,
        color: AppColors.textMedium,
      );

  /// Small text emphasized - 10px bold
  static TextStyle get textXsBold => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMedium,
      );

  /// Medium small text - 11px
  static TextStyle get textSm => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: AppColors.textMedium,
      );

  /// Medium small text emphasized - 11px medium weight
  static TextStyle get textSmMedium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textMedium,
      );

  /// 14px regular text
  static TextStyle get text14 => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textDark,
      );

  /// 14px medium weight text
  static TextStyle get text14Medium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      );

  /// 14px semibold text
  static TextStyle get text14SemiBold => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );

  /// 16px medium weight text
  static TextStyle get text16Medium => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      );

  /// 20px semibold text (for dialog headers, etc.)
  static TextStyle get text20SemiBold => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      );

  /// Avatar initials text style
  static TextStyle get avatarInitials => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.cardWhite,
        letterSpacing: 0.5,
      );

  /// Avatar initials small text style
  static TextStyle get avatarInitialsSmall => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.cardWhite,
        letterSpacing: 0.5,
      );

  /// Empty state title style
  static TextStyle get emptyStateTitle => titleLarge.copyWith(
        color: AppColors.textMedium,
      );

  /// Empty state subtitle style
  static TextStyle get emptyStateSubtitle => bodyMedium.copyWith(
        color: AppColors.textLight,
      );

  /// Creates a complete Material 3 TextTheme with platform-adaptive font family.
  /// Uses SF Pro (system font) on iOS, Inter on Android.
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
