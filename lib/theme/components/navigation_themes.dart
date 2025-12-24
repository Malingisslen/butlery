/// Navigation and container theme configurations.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/theme_constants.dart';

/// Navigation, app bar, dialog, and container component themes.
class NavigationThemes {
  /// Private constructor
  NavigationThemes._();

  /// App bar theme
  static AppBarTheme get appBarTheme {
    return AppBarTheme(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.cardWhite,
      elevation: AppDimensions.elevationLow,
      shadowColor: Colors.black26,
      centerTitle: false,
      titleTextStyle: AppTextStyles.appBarTitle.copyWith(
        color: AppColors.cardWhite,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.cardWhite,
        size: AppDimensions.iconSizeL,
      ),
      actionsIconTheme: const IconThemeData(
        color: AppColors.cardWhite,
        size: AppDimensions.iconSizeL,
      ),
    );
  }

  /// Bottom navigation bar theme
  static BottomNavigationBarThemeData get bottomNavigationBarTheme {
    return const BottomNavigationBarThemeData(
      backgroundColor: AppColors.primaryBlue,
      selectedItemColor: AppColors.cardWhite,
      unselectedItemColor: ThemeConstants.whiteOverlay40,
      selectedLabelStyle: AppTextStyles.navigationText,
      unselectedLabelStyle: AppTextStyles.navigationText,
      type: BottomNavigationBarType.fixed,
      elevation: AppDimensions.elevationHigh,
    );
  }

  /// Tab bar theme
  static TabBarThemeData get tabBarTheme {
    return const TabBarThemeData(
      labelColor: AppColors.primaryBlue,
      unselectedLabelColor: AppColors.textMedium,
      labelStyle: AppTextStyles.tabText,
      unselectedLabelStyle: AppTextStyles.tabText,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: AppColors.primaryBlue,
          width: AppDimensions.borderWidthThick,
        ),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
    );
  }

  /// Dialog theme
  static DialogThemeData get dialogTheme {
    return DialogThemeData(
      backgroundColor: AppColors.cardWhite,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
      ),
      titleTextStyle: AppTextStyles.dialogTitle,
      contentTextStyle: AppTextStyles.dialogContent,
    );
  }

  /// Bottom sheet theme
  static BottomSheetThemeData get bottomSheetTheme {
    return const BottomSheetThemeData(
      backgroundColor: AppColors.cardWhite,
      elevation: 16,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadius16),
        ),
      ),
      modalBackgroundColor: AppColors.cardWhite,
      modalElevation: 16,
    );
  }
}
