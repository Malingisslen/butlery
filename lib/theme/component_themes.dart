// lib/theme/component_themes.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_dimensions.dart';

/// Component-specific theme configurations for the Butlery app
/// Contains themes for buttons, cards, inputs, and other Material components
class ComponentThemes {
  ComponentThemes._(); // Private constructor to prevent instantiation

  // ===== BUTTON THEMES =====

  /// Elevated button theme
  static ElevatedButtonThemeData get elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.cardWhite,
        elevation: AppDimensions.elevationMedium,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        ),
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXl,
          vertical: AppDimensions.paddingM,
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Filled button theme
  static FilledButtonThemeData get filledButtonTheme {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        ),
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXl,
          vertical: AppDimensions.paddingM,
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Outlined button theme
  static OutlinedButtonThemeData get outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        backgroundColor: Colors.transparent,
        side: const BorderSide(
          color: AppColors.primaryBlue,
          width: AppDimensions.borderWidthStandard,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        ),
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXl,
          vertical: AppDimensions.paddingM,
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Text button theme
  static TextButtonThemeData get textButtonTheme {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        minimumSize: const Size(0, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Icon button theme
  static IconButtonThemeData get iconButtonTheme {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textDark,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(
          AppDimensions.minTouchTarget,
          AppDimensions.minTouchTarget,
        ),
        iconSize: AppDimensions.iconSizeL,
      ),
    );
  }

  /// Floating action button theme
  static FloatingActionButtonThemeData get floatingActionButtonTheme {
    return const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.cardWhite,
      elevation: AppDimensions.elevationHigh,
      highlightElevation: AppDimensions.elevationXHigh,
      shape: CircleBorder(),
    );
  }

  // ===== CARD THEMES =====

  /// Card theme
  static CardThemeData get cardTheme {
    return CardThemeData(
      color: AppColors.cardWhite,
      elevation: AppDimensions.elevationLow,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
      ),
      margin: const EdgeInsets.all(AppDimensions.marginM),
    );
  }

  // ===== INPUT THEMES =====

  /// Input decoration theme
  static InputDecorationTheme get inputDecorationTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        borderSide: const BorderSide(
          color: AppColors.divider,
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        borderSide: const BorderSide(
          color: AppColors.divider,
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        borderSide: const BorderSide(
          color: AppColors.primaryBlue,
          width: AppDimensions.borderWidthThick,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: AppDimensions.borderWidthThick,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      hintStyle: AppTextStyles.hintText,
      labelStyle: AppTextStyles.bodyMedium,
      errorStyle: AppTextStyles.errorText,
    );
  }

  // ===== APP BAR THEMES =====

  /// App bar theme
  static AppBarTheme get appBarTheme {
    return AppBarTheme(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.cardWhite,
      elevation: AppDimensions.elevationLow,
      shadowColor: Colors.black26,
      centerTitle: true,
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

  // ===== BOTTOM NAVIGATION THEMES =====

  /// Bottom navigation bar theme
  static BottomNavigationBarThemeData get bottomNavigationBarTheme {
    return const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardWhite,
      selectedItemColor: AppColors.primaryBlue,
      unselectedItemColor: AppColors.textMedium,
      selectedLabelStyle: AppTextStyles.navigationText,
      unselectedLabelStyle: AppTextStyles.navigationText,
      type: BottomNavigationBarType.fixed,
      elevation: AppDimensions.elevationMedium,
    );
  }

  // ===== TAB THEMES =====

  /// Tab bar theme
  static TabBarThemeData get tabBarTheme {
    return TabBarThemeData(
      labelColor: AppColors.primaryBlue,
      unselectedLabelColor: AppColors.textMedium,
      labelStyle: AppTextStyles.tabText,
      unselectedLabelStyle: AppTextStyles.tabText,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(
          color: AppColors.primaryBlue,
          width: AppDimensions.borderWidthThick,
        ),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
    );
  }

  // ===== LIST TILE THEMES =====

  /// List tile theme
  static ListTileThemeData get listTileTheme {
    return ListTileThemeData(
      tileColor: AppColors.cardWhite,
      selectedTileColor: AppColors.lightColorScheme.primaryContainer,
      iconColor: AppColors.textMedium,
      textColor: AppColors.textDark,
      titleTextStyle: AppTextStyles.listTileTitle,
      subtitleTextStyle: AppTextStyles.listTileSubtitle,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      minVerticalPadding: AppDimensions.paddingS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
    );
  }

  // ===== DIALOG THEMES =====

  /// Dialog theme
  static DialogThemeData get dialogTheme {
    return DialogThemeData(
      backgroundColor: AppColors.cardWhite,
      elevation: AppDimensions.elevationXHigh,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXl),
      ),
      titleTextStyle: AppTextStyles.dialogTitle,
      contentTextStyle: AppTextStyles.dialogContent,
    );
  }

  // ===== BOTTOM SHEET THEMES =====

  /// Bottom sheet theme
  static BottomSheetThemeData get bottomSheetTheme {
    return BottomSheetThemeData(
      backgroundColor: AppColors.cardWhite,
      elevation: AppDimensions.elevationXHigh,
      shadowColor: Colors.black26,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusXl),
        ),
      ),
      modalBackgroundColor: AppColors.cardWhite,
      modalElevation: AppDimensions.elevationMax,
    );
  }

  // ===== SNACKBAR THEMES =====

  /// Snackbar theme
  static SnackBarThemeData get snackBarTheme {
    return SnackBarThemeData(
      backgroundColor: AppColors.darkNavy,
      contentTextStyle: AppTextStyles.snackbarText.copyWith(
        color: AppColors.cardWhite,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: AppDimensions.elevationHigh,
    );
  }

  // ===== DIVIDER THEMES =====

  /// Divider theme
  static DividerThemeData get dividerTheme {
    return const DividerThemeData(
      color: AppColors.divider,
      thickness: AppDimensions.borderWidthThin,
      space: AppDimensions.spacingL,
    );
  }

  // ===== SWITCH THEMES =====

  /// Switch theme
  static SwitchThemeData get switchTheme {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue;
        }
        return AppColors.textLight;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue.withValues(alpha: 0.3);
        }
        return AppColors.divider;
      }),
    );
  }

  // ===== CHECKBOX THEMES =====

  /// Checkbox theme
  static CheckboxThemeData get checkboxTheme {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue;
        }
        return AppColors.cardWhite;
      }),
      checkColor: WidgetStateProperty.all(AppColors.cardWhite),
      side: const BorderSide(
        color: AppColors.divider,
        width: AppDimensions.borderWidthStandard,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
    );
  }

  // ===== RADIO THEMES =====

  /// Radio theme
  static RadioThemeData get radioTheme {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue;
        }
        return AppColors.textMedium;
      }),
    );
  }

  // ===== CHIP THEMES =====

  /// Chip theme
  static ChipThemeData get chipTheme {
    return ChipThemeData(
      backgroundColor: AppColors.lightColorScheme.surfaceContainerHighest,
      selectedColor: AppColors.primaryBlue,
      disabledColor: AppColors.divider,
      labelStyle: AppTextStyles.labelMedium,
      secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(
        color: AppColors.cardWhite,
      ),
      brightness: Brightness.light,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXl),
      ),
    );
  }

  // ===== SLIDER THEMES =====

  /// Slider theme
  static SliderThemeData get sliderTheme {
    return SliderThemeData(
      activeTrackColor: AppColors.primaryBlue,
      inactiveTrackColor: AppColors.divider,
      thumbColor: AppColors.primaryBlue,
      overlayColor: AppColors.primaryBlue.withValues(alpha: 0.2),
      valueIndicatorColor: AppColors.primaryBlue,
      valueIndicatorTextStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.cardWhite,
      ),
    );
  }

  // ===== PROGRESS INDICATOR THEMES =====

  /// Progress indicator theme
  static ProgressIndicatorThemeData get progressIndicatorTheme {
    return const ProgressIndicatorThemeData(
      color: AppColors.primaryBlue,
      linearTrackColor: AppColors.divider,
      circularTrackColor: AppColors.divider,
    );
  }
}