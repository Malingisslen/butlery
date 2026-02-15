/// Navigation and container theme configurations.
///
/// **UI Redesign:**
/// - AppBar: Primary background with onPrimary text
/// - Bottom Nav: Primary background
/// - Tab Bar: Primary indicator
/// - Dialogs/Sheets: Surface with proper elevation

import 'package:flutter/material.dart';
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

  /// Tab bar theme
  static TabBarThemeData tabBarTheme(ColorScheme cs) {
    return TabBarThemeData(
      labelColor: cs.primary,
      unselectedLabelColor: cs.onSurfaceVariant,
      labelStyle: AppTextStyles.tabText.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppTextStyles.tabText,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: cs.primary,
          width: AppDimensions.borderWidthThick,
        ),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
    );
  }

  /// Dialog theme
  static DialogThemeData dialogTheme(ColorScheme cs) {
    return DialogThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      elevation: 8,
      shadowColor: cs.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
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
      backgroundColor: cs.surface,
      elevation: 16,
      shadowColor: cs.shadow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadius16),
        ),
      ),
      modalBackgroundColor: cs.surface,
      modalElevation: 16,
    );
  }
}
