/// Themes for the framework pieces that float over the page or answer a text
/// gesture: text selection, tooltips and popup menus.
///
/// Without these the framework draws its own defaults: a cursor in
/// ColorScheme.primary (ink in both modes, 1.27:1 on the dark base), a grey
/// tooltip and a Material popup surface.
library;

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Text selection, tooltip and popup menu themes, mode aware through
/// [ColorScheme].
class OverlayThemes {
  OverlayThemes._();

  /// Cursor and handles are text.primary (ink light, paper dark); the
  /// highlight is surface.textSelection, with text.primary standing on it.
  static TextSelectionThemeData textSelectionTheme(ColorScheme cs) {
    return TextSelectionThemeData(
      cursorColor: cs.onSurface,
      selectionHandleColor: cs.onSurface,
      selectionColor: AppModeColors.surfaceTextSelection(cs.brightness),
    );
  }

  /// The ink tooltip: surface.ink with paper text in both modes, like the ink
  /// snackbar, and the same 1 px border.subtle edge in dark where ink is a
  /// small step from the page.
  static TooltipThemeData tooltipTheme(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    final ink = dark ? AppColorsDark.forestGreen : AppColors.forestGreen;
    final paper = dark ? AppColorsDark.textOnPrimary : AppColors.textOnPrimary;
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        border: dark ? Border.all(color: AppColorsDark.creamDarker) : null,
      ),
      textStyle: AppTextStyles.bodySmall.copyWith(color: paper),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space8,
      ),
    );
  }

  /// A popup menu opens on surface.base, which is what its press fill
  /// assumes (press_fill_menu_test), with the dialog's edge and radius and no
  /// shadow, so the dark menu has an edge against the dark page.
  static PopupMenuThemeData popupMenuTheme(ColorScheme cs) {
    return PopupMenuThemeData(
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outline),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppDimensions.radiusControl),
        ),
      ),
      textStyle: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
    );
  }
}
