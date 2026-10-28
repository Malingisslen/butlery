/// Input and data display theme configurations.
///
/// **UI Redesign:**
/// - Cards: Surface with subtle border
/// - Chips: Pill-shaped with primary selection
/// - Error states use error color (NOT rust)

import 'package:butlery/theme/components/butlery_field_border.dart';
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/error_text_style.dart';

/// Input, card, and data display component themes.
/// All methods accept [ColorScheme] for dark/light mode awareness.
class InputThemes {
  InputThemes._();

  /// Input decoration theme
  ///
  /// surface.raised is the DISABLED fill, so a resting field must not use it.
  static InputDecorationTheme inputDecorationTheme(ColorScheme cs) {
    // Fields take the control radius, 8 (tokens.json space.radius.control).
    final radius = BorderRadius.circular(AppDimensions.radiusControl);
    final resting = ButleryFieldBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: cs.outline,
        width: AppDimensions.borderWidthStandard,
      ),
    );
    final error = ButleryFieldBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: cs.error,
        width: AppDimensions.borderWidthOutlinedEdge,
      ),
    );
    return InputDecorationTheme(
      // The decorator is laid out to Material's 48 dp touch target and
      // ButleryFieldBorder draws its box 40 tall (B-03).
      filled: true,
      fillColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? cs.surfaceContainerHighest
            : cs.surface,
      ),
      // BUT-2205: a field on surface.base takes surface.raised on hover.
      hoverColor: cs.surfaceContainerHighest,
      border: resting,
      enabledBorder: resting,
      // test/architecture/text_field_in_ring_test.dart keeps every
      // field in the ring.
      focusedBorder: resting,
      // Error: 1.5 px status-danger; the error is also told in text under
      // the field.
      errorBorder: error,
      focusedErrorBorder: error,
      // Disabled field: 1 px surface.disabled edge on surface.raised, never
      // opacity.
      disabledBorder: ButleryFieldBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: AppModeColors.surfaceDisabled(cs.brightness),
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.fieldVisualPaddingY,
      ),
      hintStyle: TextStyle(color: cs.onSurfaceVariant),
      labelStyle: AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant),
      // Fields sit on the page and in dialogs, which are surface.raised in
      // dark: the surface-safe danger text reads on both.
      errorStyle: errorTextStyle(cs, onRaised: true),
    );
  }

  /// Card theme
  static CardThemeData cardTheme(ColorScheme cs) {
    // A press fills to surface.raised (B83-1).
    // Clipped, so a row inside a card fills to the rounded edge.
    return CardThemeData(
      color: cs.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: BorderSide(
          color: cs.outlineVariant,
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
    );
  }

  /// List tile theme
  ///
  /// Icons, and the selected row's icon and label: text.primary through
  /// cs.onSurface, ink #24382C light and paper #F5F4ED dark (tokens.json:
  /// 54-57). They used to be cs.primary (and Material's selected default,
  /// also cs.primary), ink in both schemes: 1.27:1 on the dark base #17251D
  /// and about 1.5:1 on the dark tile, surface.raised #2F4437. Light is
  /// unchanged: there cs.onSurface == cs.primary.
  ///
  /// Interpretation: the screens' dark variable set draws standalone icons
  /// as --ikon-fristaende-a #C9D3C4, text.bodyMuted (
  /// tokens.json:174-177), which has no generated member; the dark panel
  /// draws its list glyphs in paper, which stands.
  static ListTileThemeData listTileTheme(ColorScheme cs) {
    return ListTileThemeData(
      tileColor: cs.surfaceContainerHighest,
      selectedTileColor: cs.primaryContainer,
      iconColor: cs.onSurface,
      selectedColor: cs.onSurface,
      // A disabled row's label is secondary text, never opacity (decision
      // D5, the disabled radio and switch
      // rows). Those rows are drawn on paper, but this theme paints every
      // tile surface.raised (tileColor above), and the row takes the role's
      // on-raised value, text.secondary.onRaised: #5B6959 light, #A9B2A0 dark
      // (tokens.json:184-187). Switch and radio rows are ListTiles and the
      // theme cannot tell them apart from other rows, so every disabled
      // list row gets it. Without this, Flutter falls back to
      // ThemeData.disabledColor. Selected and enabled rows
      // are text.primary (onSurface); see the selected colour above.
      textColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppModeColors.textSecondaryOnRaised(cs.brightness);
        }
        return cs.onSurface;
      }),
      titleTextStyle: AppTextStyles.listTileTitle.copyWith(
        color: cs.onSurface,
      ),
      subtitleTextStyle: AppTextStyles.listTileSubtitle.copyWith(
        color: cs.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
      minVerticalPadding: AppDimensions.space8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
    );
  }

  /// Chip theme
  ///
  /// The chosen chip is an ink fill, control.checked.background #24382C in
  /// both modes (tokens.json:145-148), drawn so in the dark panel too
  /// On the dark base #17251D that fill is 1.27:1,
  /// so dark mode edges it the way the panel draws it:
  ///
  /// * chosen: a 1 px paper edge and a paper check;
  /// * resting: a 1 px paper edge at 40 %, overlay.paperWash, the screens'
  ///   dark control outline (--ram-kontroll-a);
  /// * disabled: a 1 px surface.disabled #4A5C50 edge, no fill and a
  ///   text.secondary label.
  ///
  /// Interpretation: the panel draws the resting edge at paper 35 %
  /// which is 2.98:1 on #17251D; the screens' 40 % clears 3:1 and
  /// has a generated member, as for the outlined button.
  ///
  /// Light mode: a resting chip has a 1 px
  /// border-control edge (#7D897C), a disabled one a 1 px surface.disabled
  /// edge on surface.raised, and the chosen ink fill carries no edge of its
  /// own. Light sets no check colour.
  static ChipThemeData chipTheme(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    return ChipThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      selectedColor: cs.primary,
      checkmarkColor: dark ? cs.onSurface : null,
      side: dark ? _darkChipSide(cs) : _lightChipSide(cs),
      disabledColor: dark ? Colors.transparent : cs.surfaceContainerHighest,
      labelStyle: AppTextStyles.labelMedium.copyWith(
        // A chosen chip sits on the ink fill, so its label is paper in both
        // modes (cs.onPrimary), never ink on ink.
        color: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.onPrimary;
          if (dark && states.contains(WidgetState.disabled)) {
            return cs.onSurfaceVariant;
          }
          return cs.onSurface;
        }),
      ),
      secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(
        color: cs.onPrimary,
      ),
      brightness: cs.brightness,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space8,
      ),
      // Chips are pill-shaped: tokens.json controls.chip.radius = "pill".
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppDimensions.radiusPill),
        ),
      ),
    );
  }

  static BorderSide _lightChipSide(ColorScheme cs) {
    return WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: AppModeColors.surfaceDisabled(cs.brightness));
      }
      if (states.contains(WidgetState.selected)) {
        return BorderSide(color: cs.primary);
      }
      return BorderSide(color: cs.outline);
    });
  }

  static BorderSide _darkChipSide(ColorScheme cs) {
    return WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: AppModeColors.surfaceDisabled(cs.brightness));
      }
      if (states.contains(WidgetState.selected)) {
        return BorderSide(color: cs.onSurface);
      }
      return BorderSide(color: AppModeColors.paperWash(cs.brightness));
    });
  }
}
