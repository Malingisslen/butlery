/// Navigation and container theme configurations.
///
/// **UI Redesign:**
/// - Bottom Nav: Primary background
/// - Tab Bar: the saffron plate line under the selected word
/// - Dialogs/Sheets: Surface

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Navigation, app bar, dialog, and container component themes.
/// All methods accept [ColorScheme] for dark/light mode awareness.
class NavigationThemes {
  NavigationThemes._();

  /// App bar theme
  static AppBarTheme appBarTheme(ColorScheme cs) {
    return AppBarTheme(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: AppTextStyles.appBarTitle.copyWith(
        color: cs.onPrimary,
      ),
      iconTheme: IconThemeData(
        color: cs.onPrimary,
        size: AppDimensions.iconSizeL,
      ),
      actionsIconTheme: IconThemeData(
        color: cs.onPrimary,
        size: AppDimensions.iconSizeL,
      ),
    );
  }

  /// Bottom navigation bar theme
  static BottomNavigationBarThemeData bottomNavigationBarTheme(ColorScheme cs) {
    return BottomNavigationBarThemeData(
      backgroundColor: cs.primary,
      selectedItemColor: cs.onPrimary,
      unselectedItemColor: cs.onPrimary.withValues(alpha: 0.7),
      selectedLabelStyle: AppTextStyles.navLabel.copyWith(
        color: cs.onPrimary,
      ),
      unselectedLabelStyle: AppTextStyles.navLabel.copyWith(
        color: cs.onPrimary.withValues(alpha: 0.7),
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    );
  }

  static const double tabPlateLineHeight = 3.0;

  static const double tabPlateLineOverhang = 5.0;

  /// Tab bar theme
  ///
  /// The selected tab carries the plate line under its word, saffron in both
  /// modes: token progressIndicator #D68523 (the drawing,
  /// has `background:#ce7c1e`). It used to be cs.primary,
  /// which is surface.ink in both schemes and vanished on the dark page
  /// (#17251D).
  ///
  /// A view that
  /// sets its own labelColor (friends_list_view.dart,
  /// group_shared_content_section.dart) still overrides this.
  static TabBarThemeData tabBarTheme(ColorScheme cs) {
    final plateLine = cs.brightness == Brightness.dark
        ? AppColorsDark.progressIndicator
        : AppColors.progressIndicator;
    return TabBarThemeData(
      labelColor: cs.onSurface,
      unselectedLabelColor: cs.onSurfaceVariant,
      labelStyle: AppTextStyles.tabText.copyWith(
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: AppTextStyles.tabText,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: plateLine, width: tabPlateLineHeight),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppDimensions.radiusKnob),
        ),
        insets: const EdgeInsets.symmetric(
          horizontal: -tabPlateLineOverhang,
        ),
      ),
      indicatorSize: TabBarIndicatorSize.label,
    );
  }

  /// The surface of a layer over the page, a dialog or a sheet. Light stays
  /// paper; dark steps up to surface.raised, since the dark base is also the
  /// page and a layer in the same tone has no edge to find.
  static Color _layerSurface(ColorScheme cs) => cs.brightness == Brightness.dark
      ? cs.surfaceContainerHighest
      : cs.surface;

  /// Dialog theme
  ///
  /// Corners take the control radius, 8: the drawn dialog box has
  /// border-radius 8px (tokens.json space.radius.control).
  /// Background is paper in light mode and surface.raised in dark mode.
  /// Like a sheet, the layer has no shadow: the scrim and a 1 px edge in
  /// border-control separate it from the page. Dialogs
  /// must NOT hand-override shape/background (BUT-1237): the theme is the
  /// single source.
  static DialogThemeData dialogTheme(ColorScheme cs) {
    return DialogThemeData(
      backgroundColor: _layerSurface(cs),
      barrierColor: cs.scrim,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outline),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppDimensions.radiusControl),
        ),
      ),
      titleTextStyle: AppTextStyles.dialogTitle.copyWith(
        color: cs.onSurface,
      ),
      contentTextStyle: AppTextStyles.dialogContent.copyWith(
        color: cs.onSurface,
      ),
    );
  }

  /// Bottom sheet theme
  static BottomSheetThemeData bottomSheetTheme(ColorScheme cs) {
    return BottomSheetThemeData(
      backgroundColor: _layerSurface(cs),
      // The
      // layer is separated by the scrim and a border-control edge.
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      // The bottom edge meets the screen edge and stays sharp.
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outline),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusCard),
        ),
      ),
      modalBackgroundColor: _layerSurface(cs),
      modalElevation: 0,
      modalBarrierColor: cs.scrim,
      // On a wide screen every sheet keeps one column.
      constraints: const BoxConstraints(
        maxWidth: AppDimensions.dialogMaxWidthLarge,
      ),
      // The handle is 44 × 4 in border-control. Only
      // showButlerySheet turns it on.
      dragHandleColor: cs.outline,
      dragHandleSize: const Size(44, 4),
    );
  }
}
