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

/// BUT-533: shared focus-ring side. Rust at full alpha, 2.5px wide — visible
/// on cream and on button-fill surfaces. WidgetStateProperty so non-focused
/// states keep their existing borders (transparent for filled buttons,
/// primary for outlined).
WidgetStateProperty<BorderSide?> _focusSide({
  required BorderSide unfocused,
}) {
  return WidgetStateProperty.resolveWith<BorderSide?>((states) {
    if (states.contains(WidgetState.focused)) {
      return const BorderSide(
        color: AppColors.rust,
        width: 2.5,
      );
    }
    return unfocused;
  });
}

/// BUT-533: rust-tinted overlay shown on the focused state of buttons whose
/// shape would otherwise hide the side ring (filled / text / icon).
/// `alpha` defaults to 0.12 — bumped to 0.16 for IconButton because its
/// circular shape gives the ring less visual weight on its own.
WidgetStateProperty<Color?> _focusOverlay({double alpha = 0.12}) {
  return WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.focused)) {
      return AppColors.rust.withValues(alpha: alpha);
    }
    return null;
  });
}

/// Button-specific theme configurations.
/// All methods accept [ColorScheme] for dark/light mode awareness.
class ButtonThemes {
  ButtonThemes._();

  /// Elevated button theme
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme cs) {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(cs.primary),
        foregroundColor: WidgetStatePropertyAll(cs.onPrimary),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        // BUT-533: keyboard focus ring on cream surfaces.
        side: _focusSide(unfocused: BorderSide.none),
        overlayColor: _focusOverlay(),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, AppDimensions.minTouchTarget),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
          ),
        ),
        textStyle: WidgetStatePropertyAll(AppTextStyles.buttonText),
      ),
    );
  }

  /// Filled button theme
  static FilledButtonThemeData filledButtonTheme(ColorScheme cs) {
    return FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(cs.primary),
        foregroundColor: WidgetStatePropertyAll(cs.onPrimary),
        // BUT-533: keyboard focus ring on cream surfaces.
        side: _focusSide(unfocused: BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, AppDimensions.minTouchTarget),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
          ),
        ),
        textStyle: WidgetStatePropertyAll(AppTextStyles.buttonText),
      ),
    );
  }

  /// Outlined button theme
  static OutlinedButtonThemeData outlinedButtonTheme(ColorScheme cs) {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(cs.primary),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        // BUT-533: focus ring overrides the unfocused outline border for
        // keyboard navigation visibility.
        side: _focusSide(
          unfocused: BorderSide(color: cs.primary, width: 1.5),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, AppDimensions.minTouchTarget),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
          ),
        ),
        textStyle: WidgetStatePropertyAll(AppTextStyles.buttonText),
      ),
    );
  }

  /// Text button theme
  static TextButtonThemeData textButtonTheme(ColorScheme cs) {
    return TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(cs.primary),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        // BUT-533: text buttons get a focus ring via side (visible because
        // shape borderRadius is non-zero) plus a rust-tinted overlay.
        side: _focusSide(unfocused: BorderSide.none),
        overlayColor: _focusOverlay(),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(0, AppDimensions.minTouchTarget),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
          ),
        ),
        textStyle: WidgetStatePropertyAll(AppTextStyles.buttonText),
      ),
    );
  }

  /// Icon button theme
  static IconButtonThemeData iconButtonTheme(ColorScheme cs) {
    return IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(cs.onSurfaceVariant),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        // BUT-533: focus ring + tint. IconButton renders shape as a circle,
        // so the side is what becomes a visible focus outline.
        side: _focusSide(unfocused: BorderSide.none),
        overlayColor: _focusOverlay(alpha: 0.16),
        minimumSize: const WidgetStatePropertyAll(
          Size(AppDimensions.minTouchTarget, AppDimensions.minTouchTarget),
        ),
        iconSize: const WidgetStatePropertyAll(AppDimensions.iconSizeL),
      ),
    );
  }

  /// Floating action button theme
  static FloatingActionButtonThemeData floatingActionButtonTheme(
    ColorScheme cs,
  ) {
    return FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      elevation: 4,
      highlightElevation: 6,
      // BUT-964: square design language — FABs are square, not round.
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
      );

  /// Text button style
  static ButtonStyle textButtonStyle(ColorScheme cs) => TextButton.styleFrom(
    foregroundColor: cs.primary,
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingL,
      vertical: AppDimensions.paddingM,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
    ),
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
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
      );

  /// Danger button style
  static ButtonStyle dangerButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.error,
        foregroundColor: cs.onError,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
      );

  /// Outlined button style
  static ButtonStyle outlinedButtonStyleNamed(ColorScheme cs) =>
      OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        side: BorderSide(color: cs.primary, width: 1.5),
      );

  /// Delete button style
  static ButtonStyle deleteButtonStyle(ColorScheme cs) =>
      OutlinedButton.styleFrom(
        foregroundColor: cs.error,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
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
          vertical: AppDimensions.paddingM,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        minimumSize: const Size(200, 56),
        textStyle: AppTextStyles.buttonText,
      );
}
