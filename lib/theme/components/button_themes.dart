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
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

/// Focus on every themed button is the canonical ring: 2 px, 3 px outside
/// the button, ink on light and paper on dark, never saffron, identical on
/// all variants (
/// tokens.json:155-160). The theme inserts it through backgroundBuilder, and
/// ButleryFocusRing paints it in the Overlay so no clip around the button
/// cuts it off. It shows for keyboard focus, like CSS :focus-visible.
///
/// This replaces BUT-533's saffron side (2.5 px on the button's own edge)
/// and saffron focus tint. Using backgroundBuilder makes Flutter default the
/// button Material's clipBehavior to antiAlias; the button's content already
/// sits inside its shape, so nothing visible is cut.
ButtonLayerBuilder _focusRing(BorderRadius radius) {
  return (context, states, child) => ButleryFocusRing(
    focused: states.contains(WidgetState.focused),
    borderRadius: radius,
    child: child ?? const SizedBox.shrink(),
  );
}

/// The ring carries focus alone, so the focused state gets no tint: an
/// opacity tint is a state carried by opacity, which the system forbids
/// (tokens.json:40-53, opacityLadder). Only focus on its own is answered
/// here. InkWell resolves the splash against the whole state set, so a
/// focused button that is also pressed (Enter, Space, or a click while
/// focused) or hovered resolves to null and falls through to Material's
/// default press and hover overlays, the same as an unfocused button.
final WidgetStateProperty<Color?> _noFocusTint =
    WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered)) {
        return null;
      }
      if (states.contains(WidgetState.focused)) return Colors.transparent;
      return null;
    });

const BorderRadius _controlRadius = BorderRadius.all(
  Radius.circular(AppDimensions.radiusControl),
);

/// Icon-button overlay only (B83-1 = A, BUT-2183):
/// pressed and hovered resolve to surface.raised. The other themed buttons
/// are not part of this decision and keep [_noFocusTint]. Focus is untouched: the ring alone carries focus, same as
/// every other themed button.
WidgetStateProperty<Color?> _iconButtonOverlay(ColorScheme cs) {
  return WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.pressed) ||
        states.contains(WidgetState.hovered)) {
      return cs.surfaceContainerHighest;
    }
    if (states.contains(WidgetState.focused)) return Colors.transparent;
    return null;
  });
}

/// Disabled filled button: surface.disabled with readable ink text, never
/// opacity.
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

/// onSurface carries text.primary: #24382C light
/// and #F5F4ED dark (tokens.json:54-57).
Color _filledDisabledForeground(ColorScheme cs) => cs.onSurface;

/// Foreground of every unfilled button (outlined, text, secondary): the
/// text.primary role through cs.onSurface, #24382C light and paper #F5F4ED
/// dark (tokens.json:54-57). It used to be cs.primary, which is surface.ink
/// #24382C in BOTH schemes and so read 1.27:1 on the dark base #17251D.
/// Light
/// is unchanged: there cs.onSurface == cs.primary.
///
/// Interpretation: the screens' dark variable set gives secondary-control
/// text as --text-kontroll-a #C9D3C4, text.bodyMuted (
/// tokens.json:174-177), which has no generated member. Paper
/// stands until one is delivered.
Color _unfilledForeground(ColorScheme cs) => cs.onSurface;

/// The 1.5 px outline of an unfilled button. Light: ink #24382C, as before.
/// Dark: overlay.paperWash rgba(245,244,237,0.40),
/// 3.5:1 on #17251D.
Color _unfilledOutline(ColorScheme cs) => cs.brightness == Brightness.dark
    ? AppModeColors.paperWash(cs.brightness)
    : cs.onSurface;

/// Disabled outlined button text: text.secondary (
/// tokens.json), through onSurfaceVariant, which carries
/// text.secondary in both schemes.
Color _outlinedDisabledForeground(ColorScheme cs) => cs.onSurfaceVariant;

/// Disabled outlined border: 1.5 px surface.disabled.
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

/// The dark rest edge of the saffron hero button: paperWash (3.5:1) round the
/// fill. A disabled button keeps none.
WidgetStateProperty<BorderSide?> _heroRestEdge(ColorScheme cs) =>
    WidgetStateProperty.resolveWith((states) {
      if (cs.brightness != Brightness.dark ||
          states.contains(WidgetState.disabled)) {
        return null;
      }
      return BorderSide(color: _unfilledOutline(cs), width: 1.5);
    });

/// action.fill and the text on it: the primary button and the create button.
Color _fill(ColorScheme cs) => AppModeColors.actionFill(cs.brightness);
Color _onFill(ColorScheme cs) => AppModeColors.onActionFill(cs.brightness);

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
/// space.radius.control). The
/// FAB and the extended FAB keep their square shape: no canonical source
/// names a radius for them.
class ButtonThemes {
  ButtonThemes._();

  /// Elevated button theme
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme cs) {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: _filledBackground(cs, _fill(cs)),
        foregroundColor: _filledForeground(cs, _onFill(cs)),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: _noFocusTint,
        backgroundBuilder: _focusRing(_controlRadius),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, AppDimensions.controlVisualHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space8,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: WidgetStatePropertyAll(AppTextStyles.buttonText),
      ),
    );
  }

  /// Filled button theme
  static FilledButtonThemeData filledButtonTheme(ColorScheme cs) {
    return FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: _filledBackground(cs, _fill(cs)),
        foregroundColor: _filledForeground(cs, _onFill(cs)),
        overlayColor: _noFocusTint,
        backgroundBuilder: _focusRing(_controlRadius),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, AppDimensions.controlVisualHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space8,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: WidgetStatePropertyAll(AppTextStyles.buttonText),
      ),
    );
  }

  /// Outlined button theme
  static OutlinedButtonThemeData outlinedButtonTheme(ColorScheme cs) {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: _withDisabled(
          _unfilledForeground(cs),
          _outlinedDisabledForeground(cs),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        // The outline keeps its 1.5 px at focus; the ring sits outside it.
        side: _outlineWithDisabled(
          cs,
          BorderSide(color: _unfilledOutline(cs), width: 1.5),
        ),
        overlayColor: _noFocusTint,
        backgroundBuilder: _focusRing(_controlRadius),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, AppDimensions.controlVisualHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space8,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
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
          _unfilledForeground(cs),
          AppModeColors.textDisabled(cs.brightness),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: _noFocusTint,
        backgroundBuilder: _focusRing(_controlRadius),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(0, AppDimensions.controlVisualHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space8,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: WidgetStatePropertyAll(AppTextStyles.buttonText),
      ),
    );
  }

  /// Icon button theme
  static IconButtonThemeData iconButtonTheme(ColorScheme cs) {
    return IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: _withDisabled(
          cs.onSurfaceVariant,
          AppModeColors.textDisabled(cs.brightness),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: _iconButtonOverlay(cs),
        // The ring goes round the whole 48 dp button, not the glyph.
        backgroundBuilder: _focusRing(
          const BorderRadius.all(Radius.circular(AppDimensions.radiusPill)),
        ),
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
      backgroundColor: _fill(cs),
      foregroundColor: _onFill(cs),
      elevation: 4,
      highlightElevation: 6,
      // The create button is round: the central plus in the bottom row is a
      // 56 dp circle, border-radius 999 (tokens.json
      // space.radius.pill). Interpretation of an unlabelled drawing (Q10).
      shape: const CircleBorder(),
      iconSize: AppDimensions.iconSizeL,
    );
  }

  /// Primary button style
  static ButtonStyle primaryButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: _fill(cs),
        foregroundColor: _onFill(cs),
        disabledBackgroundColor: AppModeColors.surfaceDisabled(cs.brightness),
        disabledForegroundColor: _filledDisabledForeground(cs),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      );

  /// Every
  /// other primary stays ink. Views choose their hero in package 4; nothing
  /// uses this style yet.
  ///
  /// Rest: action.primary behind text.onActionPrimary, #D68523 / #17251D.
  /// Pressed: action.primaryPressed behind text.onActionPrimaryPressed,
  /// #9A5C14 / #F5F4ED, 4.84:1 (tokens.json:81-91,
  /// :137-144; contrast pairs tokens.json:657-666). Paper on pressed saffron,
  /// never ink: ink there is 2.97:1. The same values in
  /// both modes.
  ///
  /// Background and foreground switch as a pair: both resolve from the same
  /// state, and animationDuration is zero so the background does not fade
  /// under text that has already switched. Pressed gets no Material overlay,
  /// so no ink tint competes with the pressed saffron.
  ///
  /// Focus is the shared ring.
  static ButtonStyle heroButtonStyle(ColorScheme cs) {
    final b = cs.brightness;
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppModeColors.surfaceDisabled(b);
        }
        if (states.contains(WidgetState.pressed)) {
          return AppModeColors.actionPrimaryPressed(b);
        }
        return AppModeColors.actionPrimary(b);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return _filledDisabledForeground(cs);
        }
        if (states.contains(WidgetState.pressed)) {
          return AppModeColors.onActionPrimaryPressed(b);
        }
        return AppModeColors.onActionPrimary(b);
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused)) {
          return Colors.transparent;
        }
        return null;
      }),
      side: _heroRestEdge(cs),
      animationDuration: Duration.zero,
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundBuilder: _focusRing(_controlRadius),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _controlRadius),
      ),
      minimumSize: const WidgetStatePropertyAll(
        Size(double.infinity, AppDimensions.controlVisualHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppDimensions.space24,
          vertical: AppDimensions.space8,
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: WidgetStatePropertyAll(AppTextStyles.buttonText),
    );
  }

  /// Text button style
  static ButtonStyle textButtonStyle(ColorScheme cs) => TextButton.styleFrom(
    foregroundColor: _unfilledForeground(cs),
    disabledForegroundColor: AppModeColors.textDisabled(cs.brightness),
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.space16,
      vertical: AppDimensions.space12,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
    ),
  );

  /// Secondary button style
  static ButtonStyle secondaryButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest,
        foregroundColor: _unfilledForeground(cs),
        // The surface stays surface.raised when disabled; only the text and
        // the outline change, like the outlined button.
        // The text is the same
        // role's on-raised value, text.secondary.onRaised: #5B6959 light,
        // #A9B2A0 dark (tokens.json).
        disabledBackgroundColor: cs.surfaceContainerHighest,
        disabledForegroundColor: AppModeColors.textSecondaryOnRaised(
          cs.brightness,
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      ).copyWith(
        side: _outlineWithDisabled(
          cs,
          BorderSide(color: _unfilledOutline(cs), width: 1.5),
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
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      );

  /// Outlined button style
  static ButtonStyle outlinedButtonStyleNamed(ColorScheme cs) =>
      OutlinedButton.styleFrom(
        foregroundColor: _unfilledForeground(cs),
        disabledForegroundColor: _outlinedDisabledForeground(cs),
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      ).copyWith(
        side: _outlineWithDisabled(
          cs,
          BorderSide(color: _unfilledOutline(cs), width: 1.5),
        ),
      );

  /// A filled button on surface.ink (the Hem hero band, an ink overlay):
  /// paper behind ink text, the ink primary turned inside out.
  static ButtonStyle onInkButtonStyle(ColorScheme cs) =>
      ElevatedButton.styleFrom(
        backgroundColor: cs.onPrimary,
        foregroundColor: cs.primary,
        disabledBackgroundColor: AppModeColors.surfaceDisabled(cs.brightness),
        disabledForegroundColor: _filledDisabledForeground(cs),
        elevation: 0,
      );

  /// An outlined button on surface.ink: paper text and a paper outline at
  /// 35 %, as the Hem hero band drew its second action.
  static ButtonStyle outlinedOnInkButtonStyle(ColorScheme cs) =>
      OutlinedButton.styleFrom(
        foregroundColor: cs.onPrimary,
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: cs.onPrimary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      );

  /// Delete button style
  static ButtonStyle deleteButtonStyle(ColorScheme cs) =>
      OutlinedButton.styleFrom(
        foregroundColor: cs.error,
        disabledForegroundColor: _outlinedDisabledForeground(cs),
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
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
        backgroundColor: _fill(cs),
        foregroundColor: _onFill(cs),
        elevation: AppDimensions.elevationMedium,
        shadowColor: cs.shadow,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        // An extended create button is the round plus stretched to fit its
        // label: a pill (tokens.json space.radius.pill).
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppDimensions.radiusPill),
          ),
        ),
        minimumSize: const Size(200, 56),
        textStyle: AppTextStyles.buttonText,
      );
}
