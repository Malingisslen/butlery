/// Navigation and container theme configurations.
///
/// **UI Redesign:**
/// - AppBar: Primary background with onPrimary text
/// - Bottom Nav: Primary background
/// - Tab Bar: the saffron plate line under the selected word
/// - Dialogs/Sheets: Surface with proper elevation

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

  /// The selected tab's plate line: 3 px tall, radius 2 (Komponentark
  /// v1:112, `height:3px;border-radius:2px`).
  static const double tabPlateLineHeight = 3.0;

  /// The plate line runs 5 px past the word on each side (Komponentark
  /// v1:106, "tallrikslinje = ordets bredd + 5 px per sida").
  static const double tabPlateLineOverhang = 5.0;

  /// Tab bar theme
  ///
  /// The selected tab carries the plate line under its word, saffron in both
  /// modes: token progressIndicator #CE7C1E (tokens.json:165-168; drawn as
  /// `background:#ce7c1e` in Komponentark v1:112). It used to be cs.primary,
  /// which is surface.ink in both schemes and vanished on the dark page
  /// (#17251D).
  ///
  /// Labels: the selected word is text.primary (cs.onSurface: #24382C light,
  /// #F5F4ED dark), the resting word text.secondary (cs.onSurfaceVariant:
  /// #627061 light, #93A48D dark), as drawn in Komponentark v1:112-113. The
  /// selected label was cs.primary, ink on the dark page too.
  ///
  /// Interpretation: "the word's width" is the tab's label box. A
  /// [ButleryTab] label box is at least 48 dp wide, so for a very short word
  /// the line is 48 dp + 5 px per side.
  static TabBarThemeData tabBarTheme(ColorScheme cs) {
    final plateLine = cs.brightness == Brightness.dark
        ? AppColorsDark.progressIndicator
        : AppColors.progressIndicator;
    return TabBarThemeData(
      labelColor: cs.onSurface,
      unselectedLabelColor: cs.onSurfaceVariant,
      labelStyle: AppTextStyles.tabText.copyWith(
        fontWeight: FontWeight.w600,
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

  /// Dialog theme
  ///
  /// BUT-1237: square (no border radius) per the SQUARE-everywhere design
  /// rule, cream background per mockup spec §4.17 (`cs.surface` = cream in
  /// light mode, stays scheme-correct in dark mode). Dialogs must NOT
  /// hand-override shape/background — the theme is the single source.
  static DialogThemeData dialogTheme(ColorScheme cs) {
    return DialogThemeData(
      backgroundColor: cs.surface,
      elevation: 8,
      shadowColor: cs.shadow,
      shape: const RoundedRectangleBorder(),
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
      backgroundColor: cs.surface,
      elevation: 16,
      shadowColor: cs.shadow,
      // Sheets round only their top edge, 12 (Komponentark: "Ark: 12 px
      // överkant"). The bottom edge meets the screen edge and stays sharp.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusCard),
        ),
      ),
      modalBackgroundColor: cs.surface,
      modalElevation: 16,
    );
  }
}
