/// Navigation and container theme configurations.
///
/// **UI Redesign:**
/// - AppBar: Forest green background with rust bottom accent
/// - Bottom Nav: Forest green with rust selected indicator
/// - Tab Bar: Forest green indicator on cream background
/// - Dialogs/Sheets: Cream/white with green accents

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Navigation, app bar, dialog, and container component themes.
class NavigationThemes {
  /// Private constructor
  NavigationThemes._();

  /// App bar theme - Forest green with white text
  static AppBarTheme get appBarTheme {
    return AppBarTheme(
      backgroundColor: AppColors.headerBackground,
      foregroundColor: AppColors.headerForeground,
      elevation: 0, // Flat design, accent bar provides visual separation
      shadowColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: AppTextStyles.appBarTitle,
      iconTheme: const IconThemeData(
        color: AppColors.headerForeground,
        size: AppDimensions.iconSizeL,
      ),
      actionsIconTheme: const IconThemeData(
        color: AppColors.headerForeground,
        size: AppDimensions.iconSizeL,
      ),
    );
  }

  /// Bottom navigation bar theme - Forest green with rust indicator
  static BottomNavigationBarThemeData get bottomNavigationBarTheme {
    return BottomNavigationBarThemeData(
      backgroundColor: AppColors.navBackground,
      selectedItemColor: AppColors.navSelectedItem,
      unselectedItemColor: AppColors.navUnselectedItem,
      selectedLabelStyle: AppTextStyles.navLabel.copyWith(
        color: AppColors.navSelectedItem,
      ),
      unselectedLabelStyle: AppTextStyles.navLabel.copyWith(
        color: AppColors.navUnselectedItem,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 0, // Flat design
    );
  }

  /// Tab bar theme - Forest green indicator
  static TabBarThemeData get tabBarTheme {
    return TabBarThemeData(
      labelColor: AppColors.forestGreen,
      unselectedLabelColor: AppColors.textMedium,
      labelStyle: AppTextStyles.tabText.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppTextStyles.tabText,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(
          color: AppColors.forestGreen,
          width: AppDimensions.borderWidthThick,
        ),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
    );
  }

  /// Dialog theme - Cream/white with rounded corners
  static DialogThemeData get dialogTheme {
    return DialogThemeData(
      backgroundColor: AppColors.cardWhite,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
      ),
      titleTextStyle: AppTextStyles.dialogTitle.copyWith(
        color: AppColors.textDark,
      ),
      contentTextStyle: AppTextStyles.dialogContent,
    );
  }

  /// Bottom sheet theme - Cream background
  static BottomSheetThemeData get bottomSheetTheme {
    return const BottomSheetThemeData(
      backgroundColor: AppColors.cream,
      elevation: 16,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadius16),
        ),
      ),
      modalBackgroundColor: AppColors.cream,
      modalElevation: 16,
    );
  }
}
