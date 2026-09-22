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
import 'package:butlery/theme/app_mode_colors.dart';

/// BUT-533: shared focus-ring side. Rust at full alpha, 2.5px wide — visible
/// on cream and on button-fill surfaces. WidgetStateProperty so non-focused
/// states keep their existing borders (transparent for filled buttons,
/// primary for outlined).
///
/// [disabled] is the side a disabled button gets. A disabled button cannot
/// take focus, so the disabled branch never hides the focus ring.
WidgetStateProperty<BorderSide?> _focusSide({
  required BorderSide unfocused,
  BorderSide? disabled,
}) {
  return WidgetStateProperty.resolveWith<BorderSide?>((states) {
    if (disabled != null && states.contains(WidgetState.disabled)) {
      return disabled;
    }
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

/// Disabled filled button: surface.disabled with readable ink text, never
/// opacity (Komponentark v1:365, :373; Grafisk manual v6:167, :423).
/// Light: #A9B2A0 behind #24382C. Dark: #4A5C50 behind paper #F5F4ED.
WidgetStateProperty<Color?> _filledBackground(ColorScheme cs, Color enabled) {
  return WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return AppModeColors.surfaceDisabled(cs.brightness);
    }
    return enabled;
  });
}

WidgetStateProperty<Color?> _filledForeground(ColorScheme cs, Color enabled) {
  return WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return _filledDisabledForeground(cs);
    }
    return enabled;
  });
}

/// onSurface carries text.primary: #24382C light, the drawn "brand-ink text"
/// (Komponentark v1:373), and #F5F4ED dark (tokens.json:54-57).
///
/// The dark value is NOT the drawn one. Komponentark v1:500 draws #93A48D,
/// and no token pairs the light ink with that dark value, so the dark text
/// is an open decision. Until it is taken, dark mode keeps paper: the value
/// the ink filled buttons already show today, 6.5:1 on #4A5C50.
Color _filledDisabledForeground(ColorScheme cs) => cs.onSurface;

/// Disabled outlined button text: text.secondary, #627061 light
/// (Komponentark v1:383) and #93A48D dark (tokens.json:62-65), through
/// onSurfaceVariant, which carries text.secondary in both schemes.
Color _outlinedDisabledForeground(ColorScheme cs) => cs.onSurfaceVariant;

/// Disabled outlined border: 1.5 px surface.disabled (Komponentark v1:383).
BorderSide _outlinedDisabledSide(ColorScheme cs) => BorderSide(
  color: AppModeColors.surfaceDisabled(cs.brightness),
  width: 1.5,
);

/// An outline that turns surface.disabled when the button is disabled.
WidgetStateProperty<BorderSide?> _outlineWithDisabled(
  ColorScheme cs,
  BorderSide enabled,
) {
  return WidgetStateProperty.resolveWith<BorderSide?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return _outlinedDisabledSide(cs);
    }
    return enabled;
  });
}

WidgetStateProperty<Color?> _withDisabled(Color enabled, Color disabled) {
  return WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) return disabled;
    return enabled;
  });
}

/// Button-specific theme configurations.
/// All methods accept [ColorScheme] for dark/light mode awareness.
///
/// Radius: every button takes the control radius, 8 (tokens.json
/// space.radius.control; Grafisk manual v6, "8 control knappar/fält"). The
/// FAB and the extended FAB keep their square shape: no canonical source
/// names a radius for them.
class ButtonThemes {
  ButtonThemes._();

  /// Elevated button theme
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme cs) {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: _filledBackground(cs, cs.primary),
        foregroundColor: _filledForeground(cs, cs.onPrimary),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        // BUT-533: keyboard focus ring on cream surfaces.
        side: _focusSide(unfocused: BorderSide.none),
        overlayColor: _focusOverlay(),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
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
        backgroundColor: _filledBackground(cs, cs.primary),
        foregroundColor: _filledForeground(cs, cs.onPrimary),
        // BUT-533: keyboard focus ring on cream surfaces.
        side: _focusSide(unfocused: BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
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
        foregroundColor: _withDisabled(
          cs.primary,
          _outlinedDisabledForeground(cs),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        // BUT-533: focus ring overrides the unfocused outline border for
        // keyboard navigation visibility.
        side: _focusSide(
          unfocused: BorderSide(color: cs.primary, width: 1.5),
          disabled: _outlinedDisabledSide(cs),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
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
        // Disabled text: text.disabled.onRaised, the surface-safe disabled
        // text (tokens.json:198). Interpretation: the text button's disabled
        // state is not drawn.
        foregroundColor: _withDisabled(
          cs.primary,
          AppModeColors.textDisabled(cs.brightness),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        // BUT-533: text buttons get a focus ring via side (visible because
        // shape borderRadius is non-zero) plus a rust-tinted overlay.
        side: _focusSide(unfocused: BorderSide.none),
        overlayColor: _focusOverlay(),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
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
      // The FAB stays square: no canonical source names its radius, so the
      // component package leaves it (BUT-964).
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      iconSize: AppDimensions.iconSizeL,
    );
  }

  /// Primary button style
  static ButtonStyle primaryButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        disabledBackgroundColor: AppModeColors.surfaceDisabled(cs.brightness),
        disabledForegroundColor: _filledDisabledForeground(cs),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      );

  /// Text button style
  static ButtonStyle textButtonStyle(ColorScheme cs) => TextButton.styleFrom(
    foregroundColor: cs.primary,
    disabledForegroundColor: AppModeColors.textDisabled(cs.brightness),
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingL,
      vertical: AppDimensions.paddingM,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
    ),
  );

  /// Secondary button style
  static ButtonStyle secondaryButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest,
        foregroundColor: cs.primary,
        // The surface stays surface.raised when disabled; only the text and
        // the outline change, like the outlined button.
        disabledBackgroundColor: cs.surfaceContainerHighest,
        disabledForegroundColor: _outlinedDisabledForeground(cs),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      ).copyWith(
        side: _outlineWithDisabled(
          cs,
          BorderSide(color: cs.primary, width: 1.5),
        ),
      );

  /// Danger button style
  static ButtonStyle dangerButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.error,
        foregroundColor: cs.onError,
        disabledBackgroundColor: AppModeColors.surfaceDisabled(cs.brightness),
        disabledForegroundColor: _filledDisabledForeground(cs),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      );

  /// Outlined button style
  static ButtonStyle outlinedButtonStyleNamed(ColorScheme cs) =>
      OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        disabledForegroundColor: _outlinedDisabledForeground(cs),
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      ).copyWith(
        side: _outlineWithDisabled(
          cs,
          BorderSide(color: cs.primary, width: 1.5),
        ),
      );

  /// Delete button style
  static ButtonStyle deleteButtonStyle(ColorScheme cs) =>
      OutlinedButton.styleFrom(
        foregroundColor: cs.error,
        disabledForegroundColor: _outlinedDisabledForeground(cs),
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      ).copyWith(
        side: _outlineWithDisabled(
          cs,
          BorderSide(color: cs.error, width: 1.5),
        ),
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
