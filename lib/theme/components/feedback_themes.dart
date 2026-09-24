/// Feedback and interactive component themes.
///
/// **UI Redesign:**
/// - Filled controls (switch track, checkbox, chosen chip) are ink,
///   control.checked, in both modes; dark mode adds a paper edge where the
///   ink fill would vanish on the dark base
/// - Marks drawn straight on the page (radio, slider, scrollbar) use
///   text.primary: ink in light, paper in dark
/// - Snackbar: the ink snackbar (Komponentark v1:745-750)
/// - Progress indicators: ink in light, saffron in dark

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';

/// Feedback component themes (snackbar, divider, switches, checkboxes, etc.).
/// All methods accept [ColorScheme] for dark/light mode awareness.
class FeedbackThemes {
  FeedbackThemes._();

  /// The ink snackbar's message: 13 px regular (Komponentark v1:747,
  /// `font-size:13px`). Interpretation: the type scale has no 13/400 role,
  /// so it is listItem (13, tokens.json typography.roles) at the drawn
  /// weight.
  static TextStyle get inkSnackBarMessageStyle =>
      AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w400);

  /// The ink snackbar's action: 13/700 (Komponentark v1:747). Same
  /// interpretation as the message.
  static TextStyle get inkSnackBarActionStyle =>
      AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700);

  /// Snackbar theme: the ink snackbar, the only snackbar look (Komponentark
  /// v1:745-750; produktbeslut PQ-09 = A, 2026-09-23).
  ///
  /// * Surface: surface.ink #24382C in both modes (tokens.json semantic
  ///   surface.ink; generated member forestGreen in AppColors and
  ///   AppColorsDark).
  /// * Message: paper #F5F4ED in both modes (control.checked.foreground,
  ///   member textOnPrimary; 11.36:1 on ink).
  /// * Action: light saffron #E09D50 in both modes (palette.saffronLight,
  ///   member textAccentOnInk; 5.43:1 on ink, Block 289 contrast contract).
  /// * Radius 8 (radius.control; Komponentark v1:746 `border-radius:8px`).
  /// * Dark mode: a 1 px border.subtle edge (rgba(245,244,237,0.18)), since
  ///   ink on the dark page (#17251D) is only a small step. Interpretation;
  ///   the drawing is light mode only.
  /// * No shadow: the drawing has none.
  static SnackBarThemeData snackBarTheme(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    final ink = dark ? AppColorsDark.forestGreen : AppColors.forestGreen;
    final paper = dark ? AppColorsDark.textOnPrimary : AppColors.textOnPrimary;
    return SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: inkSnackBarMessageStyle.copyWith(color: paper),
      actionTextColor: AppColors.textAccentOnInk,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        side: dark
            ? const BorderSide(color: AppColorsDark.creamDarker)
            : BorderSide.none,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
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
  /// On, light: ink track with a paper knob, opaque (Komponentark v1:170-172,
  /// :176 "Ink = på"; tokens.json:145-152 control.checked, carried by
  /// primary/onPrimary).
  ///
  /// On, dark: the same ink track #24382C and paper knob, control.checked,
  /// which tokens.json:145-152 keeps identical in dark ("Toggle: ink = på",
  /// Grafisk manual v6:403). The ink track reads 1.27:1 on the dark base
  /// #17251D, so dark mode edges it with 1 px paper, the way the dark panel
  /// draws the chosen chip (Komponentark v1:523: background #24382c,
  /// border 1px solid #F5F4ED). The paper edge reads 15.6:1 on the base and
  /// the paper knob 11.3:1 on the track.
  ///
  /// Interpretation, pending the product owner: one dark screen frame draws
  /// the on-switch saffron (Skarmar v12 del 4:104), but saffron is the
  /// view's single hero action (Grafisk manual v6) and a settings list with
  /// several switches would break that budget. Until that is decided the
  /// switch follows the tokens.
  ///
  /// Disabled: surface.raised track with a 1 px surface.disabled edge and a
  /// surface.disabled knob, never opacity (Komponentark v1:174). Light
  /// #E6EAD9 / #A9B2A0, dark #2F4437 / #4A5C50 (tokens.json:108-123).
  /// Interpretation: the drawing shows the disabled switch only in the off
  /// position; an on-and-disabled switch takes the same colours and keeps
  /// its knob on the right, so position still carries the value.
  static SwitchThemeData switchTheme(ColorScheme cs) {
    final b = cs.brightness;
    final dark = b == Brightness.dark;
    final disabled = AppModeColors.surfaceDisabled(b);
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
        if (dark && states.contains(WidgetState.selected)) {
          return cs.onSurface;
        }
        return null;
      }),
      trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return 1.0;
        }
        if (dark && states.contains(WidgetState.selected)) {
          return 1.0;
        }
        return null;
      }),
    );
  }

  /// Checkbox theme
  ///
  /// Checked: control.checked, an ink #24382C box with a paper #F5F4ED tick
  /// in BOTH modes (tokens.json:145-152). The dark panel draws exactly that,
  /// an ink box with no edge and a paper tick (Komponentark v1:532), and
  /// states the rule: "Bocken i en bockad kontroll är alltid papper — aldrig
  /// ink på ink" (v1:491). So the fill stays cs.primary in dark as well; the
  /// tick carries the state, 12.2:1 on the box (tokens.json:667-668 pair)
  /// and far above 3:1 on the dark base.
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
  ///
  /// Selected: text.primary through cs.onSurface, ink #24382C light as drawn
  /// (Komponentark v1:162) and paper #F5F4ED dark. It used to be cs.primary,
  /// ink in both schemes, 1.27:1 on the dark base #17251D. Interpretation:
  /// no dark radio circle is drawn; the dark panel draws the chosen sort row
  /// with a paper check (Komponentark v1:556) and names paper as the mode's
  /// text and ring colour (v1:491). Light is unchanged: there
  /// cs.onSurface == cs.primary.
  static RadioThemeData radioTheme(ColorScheme cs) {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppModeColors.surfaceDisabled(cs.brightness);
        }
        if (states.contains(WidgetState.selected)) {
          return cs.onSurface;
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
  ///
  /// Active track and thumb: text.primary through cs.onSurface, ink light
  /// and paper dark (tokens.json:54-57). They used to be cs.primary, ink in
  /// both schemes and 1.27:1 on the dark base #17251D. Light is unchanged.
  /// Interpretation: no slider is drawn in either mode; paper is the dark
  /// panel's colour for controls and text (Komponentark v1:491). The value
  /// bubble stays an ink fill with paper text, like the ink snackbar.
  static SliderThemeData sliderTheme(ColorScheme cs) {
    return SliderThemeData(
      activeTrackColor: cs.onSurface,
      inactiveTrackColor: cs.outlineVariant,
      thumbColor: cs.onSurface,
      overlayColor: cs.onSurface.withValues(alpha: AppDimensions.opacityLight),
      valueIndicatorColor: cs.primary,
      valueIndicatorTextStyle: AppTextStyles.labelSmall.copyWith(
        color: cs.onPrimary,
      ),
    );
  }

  /// Progress indicator theme
  ///
  /// Dark: the indicator is progressIndicator, saffron #CE7C1E, on the
  /// progressTrack paper 18 % (tokens.json:161-168), as the dark panel draws
  /// the progress bar (Komponentark v1:545). It used to be cs.primary, ink,
  /// 1.27:1 on the dark base #17251D. The track is cs.outlineVariant, which
  /// is that same paper 18 % in the dark scheme.
  ///
  /// Light keeps ink on border.subtle, unchanged. tokens.json names saffron
  /// on #E6EAD9 for light too; that light change is outside this dark-mode
  /// unit and is left open.
  static ProgressIndicatorThemeData progressIndicatorTheme(ColorScheme cs) {
    return ProgressIndicatorThemeData(
      color: cs.brightness == Brightness.dark
          ? AppColorsDark.progressIndicator
          : cs.primary,
      linearTrackColor: cs.outlineVariant,
      circularTrackColor: cs.outlineVariant,
    );
  }

  /// Scrollbar theme — desktop browsers + macOS/Windows. SQUARE design
  /// (no corner radius), a text.primary thumb at 60% alpha (cs.onSurface:
  /// ink light, unchanged, and paper dark, where the old ink thumb read
  /// 1.27:1 on #17251D), always visible on web/desktop so users discover
  /// scrollable regions without hover. Interpretation: no scrollbar is
  /// drawn.
  static ScrollbarThemeData scrollbarTheme(ColorScheme cs) {
    return ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll<double>(8),
      thumbColor: WidgetStatePropertyAll<Color>(
        cs.onSurface.withValues(alpha: 0.6),
      ),
      radius: Radius.zero,
      thumbVisibility: const WidgetStatePropertyAll<bool>(true),
      trackVisibility: const WidgetStatePropertyAll<bool>(false),
    );
  }
}
