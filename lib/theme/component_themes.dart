// lib/theme/component_themes.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/theme_constants.dart';

/// Component-specific theme configurations for the Butlery app
/// Contains themes for buttons, cards, inputs, and other Material components
class ComponentThemes {
  ComponentThemes._(); // Private constructor to prevent instantiation

  // ===== BUTTON THEMES =====

  /// Elevated button theme - 8px radius as per design spec
  static ElevatedButtonThemeData get elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.cardWhite,
        elevation: 2, // Subtle elevation per spec
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // 8px per spec
        ),
        minimumSize: const Size(double.infinity, 48), // Fixed height per spec
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Filled button theme - 8px radius as per design spec
  static FilledButtonThemeData get filledButtonTheme {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // 8px per spec
        ),
        minimumSize: const Size(double.infinity, 48), // Fixed height per spec
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Outlined button theme - 8px radius as per design spec
  static OutlinedButtonThemeData get outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        backgroundColor: Colors.transparent,
        side: const BorderSide(
          color: AppColors.primaryBlue,
          width: 1, // 1px border per spec
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // 8px per spec
        ),
        minimumSize: const Size(double.infinity, 48), // Fixed height per spec
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Text button theme - 8px radius as per design spec
  static TextButtonThemeData get textButtonTheme {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // 8px per spec
        ),
        minimumSize: const Size(0, 48), // Fixed height per spec
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        textStyle: AppTextStyles.buttonText,
      ),
    );
  }

  /// Icon button theme - consistent 24px sizing per design spec
  static IconButtonThemeData get iconButtonTheme {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: Colors.grey[700], // Grey 700 for action icons per spec
        backgroundColor: Colors.transparent,
        minimumSize: const Size(48, 48), // Standard touch target per spec
        iconSize: 24, // Consistent 24px size per spec
      ),
    );
  }

  /// Floating action button theme - primary blue with proper elevation per design spec
  static FloatingActionButtonThemeData get floatingActionButtonTheme {
    return const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryBlue, // Primary blue per spec
      foregroundColor: AppColors.cardWhite, // White icon per spec
      elevation: 6, // Standard FAB elevation per spec
      highlightElevation: 8, // Elevated when pressed per spec
      shape: CircleBorder(), // Perfect circle per spec
      iconSize: 24, // Standard 24px icon per spec
    );
  }


  // ===== CARD THEMES =====

  /// Card theme - white cards with 8px radius and subtle elevation per design spec
  static CardThemeData get cardTheme {
    return CardThemeData(
      color: AppColors.cardWhite, // White cards against greige background
      elevation: 1, // Subtle elevation per spec
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // 8px radius per spec
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Consistent margins per spec
    );
  }

  // ===== INPUT THEMES =====

  /// Input decoration theme - no fill, 8px radius with proper borders per design spec
  static InputDecorationTheme get inputDecorationTheme {
    return InputDecorationTheme(
      filled: false, // No fill as per design spec
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // 8px radius per spec
        borderSide: const BorderSide(
          color: AppColors.textMedium, // Medium grey border matching text
          width: 1, // 1px border per spec
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // 8px radius per spec
        borderSide: const BorderSide(
          color: AppColors.textMedium, // Medium grey border when enabled
          width: 1, // 1px border per spec
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // 8px radius per spec
        borderSide: const BorderSide(
          color: AppColors.primaryBlue, // Primary blue when focused
          width: 1.5, // Slightly thicker when focused per spec
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // 8px radius per spec
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1, // 1px border per spec
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // 8px radius per spec
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.5, // Slightly thicker when focused per spec
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, // 16px horizontal padding per spec
        vertical: 14, // 14px vertical padding per spec
      ),
      hintStyle: const TextStyle(color: AppColors.textMedium), // Medium grey for hints consistency
      labelStyle: AppTextStyles.bodyMedium,
      errorStyle: AppTextStyles.errorText,
    );
  }

  // ===== APP BAR THEMES =====

  /// App bar theme - follows design spec for blue header with white text
  static AppBarTheme get appBarTheme {
    return AppBarTheme(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.cardWhite,
      elevation: AppDimensions.elevationLow, // 0 or 1 as per design
      shadowColor: Colors.black26,
      centerTitle: false, // Left-aligned titles as per design spec
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

  /// Bottom navigation bar theme - dark background with white icons as per design
  static BottomNavigationBarThemeData get bottomNavigationBarTheme {
    return const BottomNavigationBarThemeData(
      backgroundColor: AppColors.primaryBlue, // Dark background as per design
      selectedItemColor: AppColors.cardWhite, // White when selected
      unselectedItemColor: ThemeConstants.whiteOverlay40, // White with transparency when unselected
      selectedLabelStyle: AppTextStyles.navigationText,
      unselectedLabelStyle: AppTextStyles.navigationText,
      type: BottomNavigationBarType.fixed,
      elevation: AppDimensions.elevationHigh, // 8dp elevation as per design
    );
  }

  // ===== TAB THEMES =====

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

  // ===== LIST TILE THEMES =====

  /// List tile theme - consistent padding and icon colors per design spec
  static ListTileThemeData get listTileTheme {
    return ListTileThemeData(
      tileColor: AppColors.cardWhite,
      selectedTileColor: AppColors.lightColorScheme.primaryContainer,
      iconColor: Colors.grey[700], // Grey 700 for icons per spec
      textColor: AppColors.textDark,
      titleTextStyle: AppTextStyles.listTileTitle,
      subtitleTextStyle: AppTextStyles.listTileSubtitle,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, // 16px horizontal padding per spec
        vertical: 8, // 8px vertical padding per spec
      ),
      minVerticalPadding: 8, // Consistent vertical padding per spec
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // 8px radius per spec
      ),
    );
  }

  // ===== DIALOG THEMES =====

  /// Dialog theme - 8px radius consistent with design spec
  static DialogThemeData get dialogTheme {
    return DialogThemeData(
      backgroundColor: AppColors.cardWhite,
      elevation: 8, // Standard dialog elevation per spec
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // 8px radius per spec
      ),
      titleTextStyle: AppTextStyles.dialogTitle,
      contentTextStyle: AppTextStyles.dialogContent,
    );
  }

  // ===== BOTTOM SHEET THEMES =====

  /// Bottom sheet theme - 16px top radius and proper elevation per design spec
  static BottomSheetThemeData get bottomSheetTheme {
    return const BottomSheetThemeData(
      backgroundColor: AppColors.cardWhite,
      elevation: 16, // Strong elevation for modals per spec
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16), // 16px top radius per spec
        ),
      ),
      modalBackgroundColor: AppColors.cardWhite,
      modalElevation: 16, // Consistent elevation per spec
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

  /// Switch theme - primary blue active colors per design spec
  static SwitchThemeData get switchTheme {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue; // Primary blue when active per spec
        }
        return Colors.grey[400]; // Grey 400 when inactive per spec
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue.withValues(alpha: 0.5); // Primary blue with 50% opacity per spec
        }
        return Colors.grey[300]; // Grey 300 when inactive per spec
      }),
    );
  }

  // ===== CHECKBOX THEMES =====

  /// Checkbox theme - primary blue active with 4px radius per design spec
  static CheckboxThemeData get checkboxTheme {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue; // Primary blue when checked per spec
        }
        return AppColors.cardWhite;
      }),
      checkColor: WidgetStateProperty.all(AppColors.cardWhite), // White checkmark per spec
      side: BorderSide(
        color: Colors.grey[400]!, // Grey 400 border per spec
        width: 1.5, // 1.5px border per spec
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // 4px radius per spec
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
        borderRadius: BorderRadius.circular(8), // 8px radius per spec
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