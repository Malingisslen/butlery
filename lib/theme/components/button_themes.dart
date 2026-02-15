/// Button theme configurations for Material Design 3.
///
/// **UI Redesign:**
/// - Primary buttons: Forest green background
/// - Secondary buttons: White with forest green border
/// - Danger buttons: Error red (NOT rust)
/// - FAB: Forest green

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Button-specific theme configurations.
/// All methods accept [ColorScheme] for dark/light mode awareness.
class ButtonThemes {
  ButtonThemes._();

  /// Elevated button theme
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme cs) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
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

  /// Filled button theme
  static FilledButtonThemeData filledButtonTheme(ColorScheme cs) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
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

  /// Outlined button theme
  static OutlinedButtonThemeData outlinedButtonTheme(ColorScheme cs) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: cs.primary,
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

  /// Text button theme
  static TextButtonThemeData textButtonTheme(ColorScheme cs) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        backgroundColor: Colors.transparent,
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
  static IconButtonThemeData iconButtonTheme(ColorScheme cs) {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: cs.onSurfaceVariant,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(
            AppDimensions.minTouchTarget, AppDimensions.minTouchTarget),
        iconSize: AppDimensions.iconSizeL,
      ),
    );
  }

  /// Floating action button theme
  static FloatingActionButtonThemeData floatingActionButtonTheme(
      ColorScheme cs) {
    return FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      elevation: 4,
      highlightElevation: 6,
      shape: const CircleBorder(),
      iconSize: AppDimensions.iconSizeL,
    );
  }

  /// Primary button style
  static ButtonStyle primaryButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
      );

  /// Text button style
  static ButtonStyle textButtonStyle(ColorScheme cs) => TextButton.styleFrom(
        foregroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
      );

  /// Secondary button style
  static ButtonStyle secondaryButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest,
        foregroundColor: cs.primary,
        elevation: 0,
        side: BorderSide(color: cs.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
      );

  /// Danger button style
  static ButtonStyle dangerButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.error,
        foregroundColor: cs.onError,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
      );

  /// Outlined button style
  static ButtonStyle outlinedButtonStyleNamed(ColorScheme cs) =>
      OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
        side: BorderSide(color: cs.primary, width: 1.5),
      );

  /// Delete button style
  static ButtonStyle deleteButtonStyle(ColorScheme cs) =>
      OutlinedButton.styleFrom(
        foregroundColor: cs.error,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
        side: BorderSide(color: cs.error, width: 1.5),
      );

  /// Extended FAB style
  static ButtonStyle extendedFabStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: AppDimensions.elevationMedium,
        shadowColor: cs.shadow,
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
