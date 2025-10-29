/// Component theme system for unified Material Design styling.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/theme_constants.dart';

/// Central repository for all component-specific theme configurations.
class ComponentThemes {
  /// Private constructor
  ComponentThemes._();

  /// Elevated button theme
  static ElevatedButtonThemeData get elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.cardWhite,
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              AppDimensions.borderRadius8),
        ),
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
          vertical: AppDimensions.spacing12,
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
          borderRadius: BorderRadius.circular(
              AppDimensions.borderRadius8),
        ),
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
          vertical: AppDimensions.spacing12,
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
        backgroundColor: AppColors.transparent,
        side: const BorderSide(
          color: AppColors.primaryBlue,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              AppDimensions.borderRadius8),
        ),
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
          vertical: AppDimensions.spacing12,
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
        backgroundColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              AppDimensions.borderRadius8),
        ),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Icon button theme
  static IconButtonThemeData get iconButtonTheme {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textMedium,
        backgroundColor: AppColors.transparent,
        minimumSize: const Size(48, 48),
        iconSize: AppDimensions.iconSizeL,
      ),
    );
  }

  /// Floating action button theme
  static FloatingActionButtonThemeData get floatingActionButtonTheme {
    return const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.cardWhite, // White icon per spec
      elevation: 6,
      highlightElevation: 8, // Elevated when pressed per spec
      shape: CircleBorder(),
      iconSize: AppDimensions.iconSizeL,
    );
  }

  /// Card theme
  static CardThemeData get cardTheme {
    return CardThemeData(
      color: AppColors.cardWhite,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
      ),
      margin: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing8),
    );
  }

  /// Input decoration theme
  static InputDecorationTheme get inputDecorationTheme {
    return InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.textMedium, // Medium grey border matching text
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.textMedium, // Medium grey border when enabled
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.primaryBlue, // Primary blue when focused
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing14,
      ),
      hintStyle: const TextStyle(
          color: AppColors.textMedium), // Medium grey for hints consistency
      labelStyle: AppTextStyles.bodyMedium,
      errorStyle: AppTextStyles.errorText,
    );
  }

  /// Trending recipe card decoration
  static BoxDecoration get trendingRecipeCardDecoration => BoxDecoration(
    color: AppColors.primaryContainer.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
  );

  /// Activity timeline item decoration
  static BoxDecoration get activityTimelineItemDecoration => BoxDecoration(
    color: AppColors.secondaryContainer.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
  );

  /// Empty state container decoration
  static BoxDecoration get emptyStateContainerDecoration => BoxDecoration(
    color: AppColors.primaryContainer.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
  );

  /// App bar theme
  static AppBarTheme get appBarTheme {
    return AppBarTheme(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.cardWhite,
      elevation: AppDimensions.elevationLow, // 0 or 1 as per design
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
      backgroundColor: AppColors.primaryBlue, // Dark background as per design
      selectedItemColor: AppColors.cardWhite,
      unselectedItemColor: ThemeConstants
          .whiteOverlay40,
      selectedLabelStyle: AppTextStyles.navigationText,
      unselectedLabelStyle: AppTextStyles.navigationText,
      type: BottomNavigationBarType.fixed,
      elevation: AppDimensions.elevationHigh, // 8dp elevation as per design
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
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing8,
      ),
      minVerticalPadding:
          AppDimensions.spacing8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
      ),
    );
  }

  /// Dialog theme
  static DialogThemeData get dialogTheme {
    return DialogThemeData(
      backgroundColor: AppColors.cardWhite,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
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
          top: Radius.circular(
              AppDimensions.borderRadius16),
        ),
      ),
      modalBackgroundColor: AppColors.cardWhite,
      modalElevation: 16,
    );
  }

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

  /// Divider theme
  static DividerThemeData get dividerTheme {
    return const DividerThemeData(
      color: AppColors.divider,
      thickness: AppDimensions.borderWidthThin,
      space: AppDimensions.spacingL,
    );
  }

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
          return AppColors.primaryBlue
              .withValues(alpha: 0.5);
        }
        return AppColors.divider;
      }),
    );
  }

  /// Checkbox theme
  static CheckboxThemeData get checkboxTheme {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue;
        }
        return AppColors.cardWhite;
      }),
      checkColor: WidgetStateProperty.all(
          AppColors.cardWhite),
      side: const BorderSide(
        color: AppColors.textLight,
        width: 1.5, // 1.5px border per spec
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius4),
      ),
    );
  }

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
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
      ),
    );
  }

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

  /// Progress indicator theme
  static ProgressIndicatorThemeData get progressIndicatorTheme {
    return const ProgressIndicatorThemeData(
      color: AppColors.primaryBlue,
      linearTrackColor: AppColors.divider,
      circularTrackColor: AppColors.divider,
    );
  }

  /// Primary button style
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryBlue, foregroundColor: AppColors.cardWhite,
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
  );

  /// Text button style
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: AppColors.primaryBlue,
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
  );

  /// Secondary button style
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.cardWhite, foregroundColor: AppColors.primaryBlue,
    side: const BorderSide(color: AppColors.primaryBlue),
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
  );

  /// Danger button style
  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.error, foregroundColor: AppColors.cardWhite,
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
  );

  /// Outlined button style
  static ButtonStyle get outlinedButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primaryBlue, backgroundColor: AppColors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
    side: const BorderSide(color: AppColors.primaryBlue, width: 1),
  );

  /// Delete button style
  static ButtonStyle get deleteButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.error, backgroundColor: AppColors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
    side: const BorderSide(color: AppColors.error, width: 1),
  );

  /// Extended FAB style for Swedish text with proper sizing
  static ButtonStyle get extendedFabStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryBlue, foregroundColor: AppColors.cardWhite,
    elevation: AppDimensions.elevationMedium, shadowColor: Colors.black26,
    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl, vertical: AppDimensions.paddingM),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound)),
    minimumSize: const Size(200, 56), textStyle: AppTextStyles.buttonText,
  );
}
