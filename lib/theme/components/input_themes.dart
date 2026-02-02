/// Input and data display theme configurations.
///
/// **UI Redesign:**
/// - Inputs: Forest green focus border
/// - Cards: White with subtle shadow, recipe cards get left green + bottom rust borders
/// - Chips: Pill-shaped with forest green selection
/// - Error states use error red (NOT rust)

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Input, card, and data display component themes.
class InputThemes {
  /// Private constructor
  InputThemes._();

  /// Input decoration theme - Forest green focus
  static InputDecorationTheme get inputDecorationTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.forestGreen,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingModerate,
      ),
      hintStyle: const TextStyle(color: AppColors.textLight),
      labelStyle: AppTextStyles.bodyMedium,
      errorStyle: AppTextStyles.errorText,
    );
  }

  /// Card theme - White with subtle shadow
  static CardThemeData get cardTheme {
    return CardThemeData(
      color: AppColors.cardWhite,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        side: const BorderSide(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm),
    );
  }

  /// List tile theme
  static ListTileThemeData get listTileTheme {
    return ListTileThemeData(
      tileColor: AppColors.cardWhite,
      selectedTileColor: AppColors.lightColorScheme.primaryContainer,
      iconColor: AppColors.forestGreen,
      textColor: AppColors.textDark,
      titleTextStyle: AppTextStyles.listTileTitle,
      subtitleTextStyle: AppTextStyles.listTileSubtitle,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      minVerticalPadding: AppDimensions.spacingSm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
      ),
    );
  }

  /// Chip theme - Pill-shaped with forest green selection
  static ChipThemeData get chipTheme {
    return ChipThemeData(
      backgroundColor: AppColors.creamDark,
      selectedColor: AppColors.forestGreen,
      disabledColor: AppColors.divider,
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: AppColors.textDark,
      ),
      secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(
        color: AppColors.cardWhite,
      ),
      brightness: Brightness.light,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
      ),
    );
  }

  /// Recipe card decoration - Left green border + bottom rust border
  /// Note: Cannot use borderRadius with non-uniform border colors in Flutter
  static BoxDecoration get recipeCardDecoration => const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(
          left: BorderSide(
            color: AppColors.recipeCardLeftBorder,
            width: 3,
          ),
          bottom: BorderSide(
            color: AppColors.recipeCardBottomBorder,
            width: 2,
          ),
          top: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
          right: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),
      );

  /// Trending recipe card decoration - Uses new palette
  static BoxDecoration get trendingRecipeCardDecoration => BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.forestGreen.withValues(alpha: AppDimensions.opacityLight)),
      );

  /// Activity timeline item decoration - Uses rust accent
  static BoxDecoration get activityTimelineItemDecoration => BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.rust.withValues(alpha: AppDimensions.opacityLight)),
      );

  /// Empty state container decoration - Light green background
  static BoxDecoration get emptyStateContainerDecoration => BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.forestGreen.withValues(alpha: AppDimensions.opacityLight)),
      );

  /// Search box decoration - Custom for ButlerySearchBox
  static BoxDecoration get searchBoxDecoration => BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      );

  /// Search box decoration (focused) - Green/rust accent
  /// Note: Cannot use borderRadius with non-uniform border colors in Flutter
  static BoxDecoration get searchBoxDecorationFocused => const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(
          left: BorderSide(
            color: AppColors.forestGreen,
            width: 2,
          ),
          bottom: BorderSide(
            color: AppColors.rust,
            width: 2,
          ),
          top: BorderSide(
            color: AppColors.forestGreen,
            width: 1,
          ),
          right: BorderSide(
            color: AppColors.forestGreen,
            width: 1,
          ),
        ),
      );
}
