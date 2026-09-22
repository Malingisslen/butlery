/// Feedback and interactive component themes.
///
/// **UI Redesign:**
/// - All interactive elements use primary color
/// - Snackbar: inverseSurface background
/// - Progress indicators: Primary color

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';

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
      // SQUARE-everywhere design rule (BUT-1243): zero radius = no rounded corners.
      shape: const RoundedRectangleBorder(),
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
  ///
  /// On: ink track with a paper knob, opaque (Komponentark v1:172, "Ink =
  /// på"; tokens.json:145-152 control.checked, the same in both modes and
  /// carried by primary/onPrimary in both schemes).
  ///
  /// Disabled: surface.raised track with a 1 px surface.disabled edge and a
  /// surface.disabled knob, never opacity (Komponentark v1:174). Light
  /// #E6EAD9 / #A9B2A0, dark #2F4437 / #4A5C50 (tokens.json:108-123).
  /// Interpretation: the drawing shows the disabled switch only in the off
  /// position; an on-and-disabled switch takes the same colours and keeps
  /// its knob on the right, so position still carries the value.
  static SwitchThemeData switchTheme(ColorScheme cs) {
    final disabled = AppModeColors.surfaceDisabled(cs.brightness);
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabled;
        }
        if (states.contains(WidgetState.selected)) {
          return cs.onPrimary;
        }
        return cs.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return cs.surfaceContainerHighest;
        }
        if (states.contains(WidgetState.selected)) {
          return cs.primary;
        }
        return cs.outlineVariant;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabled;
        }
        return null;
      }),
      trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return 1.0;
        }
        return null;
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
      // The checkbox keeps its own locked radius, 6 (tokens.json
      // controls.checkbox.radius), outside the five-step scale.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.checkboxRadius),
      ),
    );
  }

  /// Radio theme
  ///
  /// Disabled: surface.disabled ring on a surface.raised fill, never
  /// opacity (Komponentark v1:164). Light #A9B2A0 / #E6EAD9, dark
  /// #4A5C50 / #2F4437 (tokens.json:108-123). Interpretation: the drawing
  /// shows only the unselected disabled radio; a selected one takes the same
  /// colours for ring and dot.
  static RadioThemeData radioTheme(ColorScheme cs) {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppModeColors.surfaceDisabled(cs.brightness);
        }
        if (states.contains(WidgetState.selected)) {
          return cs.primary;
        }
        return cs.onSurfaceVariant;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return cs.surfaceContainerHighest;
        }
        return null;
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
