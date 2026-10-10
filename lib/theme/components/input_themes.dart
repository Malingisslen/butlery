/// Input and data display theme configurations.
///
/// **UI Redesign:**
/// - Cards: Surface with subtle border
/// - Chips: Pill-shaped with primary selection
/// - Error states use error color (NOT rust)

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_shadows.dart';

/// Input, card, and data display component themes.
/// All methods accept [ColorScheme] for dark/light mode awareness.
class InputThemes {
  InputThemes._();

  /// Input decoration theme
  ///
  /// A field is paper with a 1 px border.control edge (Komponentark v1 §07
  /// and §11; Grafisk manual v6:403 "Fält: papper + border-control").
  /// surface.raised is the DISABLED fill, so a resting field must not use it.
  static InputDecorationTheme inputDecorationTheme(ColorScheme cs) {
    // Fields take the control radius, 8 (tokens.json space.radius.control).
    final radius = BorderRadius.circular(AppDimensions.radiusControl);
    final resting = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: cs.outline,
        width: AppDimensions.borderWidthStandard,
      ),
    );
    // Focus on a bare TextField (one not wrapped in ButleryFocusRing, as
    // StyledInput and ButlerySearchBox are): the canonical ring colour and
    // width, ink on light and paper on dark, never saffron. A theme's input
    // border can only draw on the field's own edge, so this is the ring
    // without its 3 px offset: the recorded fallback of decision D3, kept
    // only until the remaining bare fields move onto the ring.
    final focused = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: AppModeColors.focusRing(cs.brightness),
        width: AppDimensions.focusRingWidth,
      ),
    );
    return InputDecorationTheme(
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
      focusedBorder: focused,
      // Error: 1.5 px status-danger; the error is also told in text under
      // the field (Komponentark v1 §11).
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: cs.error,
          width: AppDimensions.borderWidthOutlinedEdge,
        ),
      ),
      focusedErrorBorder: focused,
      // Disabled field: 1 px surface.disabled edge on surface.raised, never
      // opacity (Grafisk manual v6:423; Komponentark v1:423 light, :514 dark).
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: AppModeColors.surfaceDisabled(cs.brightness),
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.space12,
      ),
      hintStyle: TextStyle(color: cs.onSurfaceVariant),
      labelStyle: AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant),
      errorStyle: AppTextStyles.errorText.copyWith(color: cs.error),
    );
  }

  /// Card theme
  static CardThemeData cardTheme(ColorScheme cs) {
    // Cards take the card radius, 12 (tokens.json space.radius.card).
    return CardThemeData(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: BorderSide(
          color: cs.outlineVariant,
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
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
  /// as --ikon-fristaende-a #C9D3C4, text.bodyMuted (Skarmar v12 del 4:30;
  /// tokens.json:174-177), which has no generated member; the dark panel
  /// draws its list glyphs in paper (Komponentark v1:556), which stands.
  static ListTileThemeData listTileTheme(ColorScheme cs) {
    return ListTileThemeData(
      tileColor: cs.surfaceContainerHighest,
      selectedTileColor: cs.primaryContainer,
      iconColor: cs.onSurface,
      selectedColor: cs.onSurface,
      // A disabled row's label is secondary text, never opacity (decision
      // D5; Komponentark v1:164 and :174, the disabled radio and switch
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
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      minVerticalPadding: AppDimensions.spacingSm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
    );
  }

  /// Chip theme
  ///
  /// The chosen chip is an ink fill, control.checked.background #24382C in
  /// both modes (tokens.json:145-148), drawn so in the dark panel too
  /// (Komponentark v1:523). On the dark base #17251D that fill is 1.27:1,
  /// so dark mode edges it the way the panel draws it:
  ///
  /// * chosen: a 1 px paper edge and a paper check (v1:523; "Bocken i en
  ///   bockad kontroll är alltid papper", v1:491);
  /// * resting: a 1 px paper edge at 40 %, overlay.paperWash, the screens'
  ///   dark control outline (Skarmar v12 etapp 2:37, --ram-kontroll-a);
  /// * disabled: a 1 px surface.disabled #4A5C50 edge, no fill and a
  ///   text.secondary label (v1:525).
  ///
  /// Interpretation: the panel draws the resting edge at paper 35 %
  /// (v1:522), which is 2.98:1 on #17251D; the screens' 40 % clears 3:1 and
  /// has a generated member, as for the outlined button. Light mode sets no
  /// side and no check colour.
  static ChipThemeData chipTheme(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    return ChipThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      selectedColor: cs.primary,
      checkmarkColor: dark ? cs.onSurface : null,
      side: dark ? _darkChipSide(cs) : null,
      disabledColor: dark ? Colors.transparent : cs.outlineVariant,
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
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      // Chips are pill-shaped: tokens.json controls.chip.radius = "pill".
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppDimensions.radiusPill),
        ),
      ),
    );
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

  /// Recipe card decoration - Left green border + bottom rust border.
  /// Uses AppColors directly since BoxDecoration is not part of ThemeData
  /// and these are brand-specific decorative borders.
  static BoxDecoration get recipeCardDecoration => BoxDecoration(
    color: AppColors.cardWhite,
    border: const Border(
      left: BorderSide(
        color: AppColors.recipeCardLeftBorder,
        width: 4,
      ),
      bottom: BorderSide(
        color: AppColors.recipeCardBottomBorder,
        width: 3,
      ),
    ),
    boxShadow: AppShadows.cardLifted,
  );
}
