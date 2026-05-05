/// Feedback and interactive component themes.
///
/// **UI Redesign:**
/// - All interactive elements use primary color
/// - Snackbar: inverseSurface background
/// - Progress indicators: Primary color

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Feedback component themes (snackbar, divider, switches, checkboxes, etc.).
/// All methods accept [ColorScheme] for dark/light mode awareness.
class FeedbackThemes {
  FeedbackThemes._();

  /// Snackbar theme
  static SnackBarThemeData snackBarTheme(ColorScheme cs) {
    return SnackBarThemeData(
      backgroundColor: cs.inverseSurface,
      contentTextStyle: AppTextStyles.snackbarText.copyWith(
        color: cs.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: AppDimensions.elevationMedium,
    );
  }

  /// Divider theme
  static DividerThemeData dividerTheme(ColorScheme cs) {
    return DividerThemeData(
      color: cs.outlineVariant,
      thickness: AppDimensions.borderWidthThin,
      space: AppDimensions.spacingL,
    );
  }

  /// Switch theme
  static SwitchThemeData switchTheme(ColorScheme cs) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return cs.primary;
        }
        return cs.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return cs.primary.withValues(alpha: AppDimensions.opacityHalf);
        }
        return cs.outlineVariant;
      }),
    );
  }

  /// Checkbox theme
  static CheckboxThemeData checkboxTheme(ColorScheme cs) {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return cs.primary;
        }
        return cs.surfaceContainerHighest;
      }),
      checkColor: WidgetStateProperty.all(cs.onPrimary),
      side: BorderSide(
        color: cs.outline,
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius4),
      ),
    );
  }

  /// Radio theme
  static RadioThemeData radioTheme(ColorScheme cs) {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return cs.primary;
        }
        return cs.onSurfaceVariant;
      }),
    );
  }

  /// Slider theme
  static SliderThemeData sliderTheme(ColorScheme cs) {
    return SliderThemeData(
      activeTrackColor: cs.primary,
      inactiveTrackColor: cs.outlineVariant,
      thumbColor: cs.primary,
      overlayColor: cs.primary.withValues(alpha: AppDimensions.opacityLight),
      valueIndicatorColor: cs.primary,
      valueIndicatorTextStyle: AppTextStyles.labelSmall.copyWith(
        color: cs.onPrimary,
      ),
    );
  }

  /// Progress indicator theme
  static ProgressIndicatorThemeData progressIndicatorTheme(ColorScheme cs) {
    return ProgressIndicatorThemeData(
      color: cs.primary,
      linearTrackColor: cs.outlineVariant,
      circularTrackColor: cs.outlineVariant,
    );
  }

  /// Scrollbar theme — desktop browsers + macOS/Windows. SQUARE design
  /// (no corner radius), forestGreen thumb at 60% alpha, always visible
  /// on web/desktop so users discover scrollable regions without hover.
  static ScrollbarThemeData scrollbarTheme(ColorScheme cs) {
    return ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll<double>(8),
      thumbColor: WidgetStatePropertyAll<Color>(
        cs.primary.withValues(alpha: 0.6),
      ),
      radius: Radius.zero,
      thumbVisibility: const WidgetStatePropertyAll<bool>(true),
      trackVisibility: const WidgetStatePropertyAll<bool>(false),
    );
  }
}
