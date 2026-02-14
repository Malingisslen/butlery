/// Button theme configurations for Material Design 3.
///
/// **UI Redesign:**
/// - Primary buttons: Forest green background
/// - Secondary buttons: White with forest green border
/// - Danger buttons: Error red (NOT rust)
/// - FAB: Forest green

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Button-specific theme configurations.
class ButtonThemes {
  /// Private constructor
  ButtonThemes._();

  /// Elevated button theme - Forest green primary
  static ElevatedButtonThemeData get elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.cardWhite,
        elevation: 0, // Flat design
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        ),
        minimumSize: const Size(double.infinity, AppDimensions.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingLg,
          vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Filled button theme - Forest green
  static FilledButtonThemeData get filledButtonTheme {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        ),
        minimumSize: const Size(double.infinity, AppDimensions.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingLg,
          vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Outlined button theme - Forest green border
  static OutlinedButtonThemeData get outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.forestGreen,
        backgroundColor: AppColors.transparent,
        side: const BorderSide(
          color: AppColors.forestGreen,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        ),
        minimumSize: const Size(double.infinity, AppDimensions.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingLg,
          vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Text button theme - Forest green text
  static TextButtonThemeData get textButtonTheme {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.forestGreen,
        backgroundColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        ),
        minimumSize: const Size(0, AppDimensions.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Icon button theme
  static IconButtonThemeData get iconButtonTheme {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textMedium,
        backgroundColor: AppColors.transparent,
        minimumSize: const Size(
            AppDimensions.minTouchTarget, AppDimensions.minTouchTarget),
        iconSize: AppDimensions.iconSizeL,
      ),
    );
  }

  /// Floating action button theme - Forest green
  static FloatingActionButtonThemeData get floatingActionButtonTheme {
    return const FloatingActionButtonThemeData(
      backgroundColor: AppColors.forestGreen,
      foregroundColor: AppColors.cardWhite,
      elevation: 4,
      highlightElevation: 6,
      shape: CircleBorder(),
      iconSize: AppDimensions.iconSizeL,
    );
  }

  /// Primary button style - Forest green
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.cardWhite,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
      );

  /// Text button style - Forest green text
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
        foregroundColor: AppColors.forestGreen,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
      );

  /// Secondary button style - White with forest green border
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.forestGreen,
        elevation: 0,
        side: const BorderSide(color: AppColors.forestGreen, width: 1.5),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
      );

  /// Danger button style - Error red (NOT rust)
  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.cardWhite,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
      );

  /// Outlined button style - Forest green border
  static ButtonStyle get outlinedButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: AppColors.forestGreen,
        backgroundColor: AppColors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
        side: const BorderSide(color: AppColors.forestGreen, width: 1.5),
      );

  /// Delete button style - Error red border (NOT rust)
  static ButtonStyle get deleteButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        backgroundColor: AppColors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
        side: const BorderSide(color: AppColors.error, width: 1.5),
      );

  /// Extended FAB style - Forest green
  static ButtonStyle get extendedFabStyle => ElevatedButton.styleFrom(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.cardWhite,
        elevation: AppDimensions.elevationMedium,
        shadowColor: AppColors.lightColorScheme.shadow,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingXl,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.borderRadiusRound)),
        minimumSize: const Size(200, 56),
        textStyle: AppTextStyles.buttonText,
      );
}
