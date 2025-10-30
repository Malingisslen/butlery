/// Input and data display theme configurations.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Input, card, and data display component themes.
class InputThemes {
  /// Private constructor
  InputThemes._();

  /// Input decoration theme
  static InputDecorationTheme get inputDecorationTheme {
    return InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.textMedium,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.textMedium,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
        borderSide: const BorderSide(
          color: AppColors.primaryBlue,
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
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingModerate,
      ),
      hintStyle: const TextStyle(color: AppColors.textMedium),
      labelStyle: AppTextStyles.bodyMedium,
      errorStyle: AppTextStyles.errorText,
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
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm),
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
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      minVerticalPadding: AppDimensions.spacingSm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            AppDimensions.borderRadius8),
      ),
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

  // ===== BOX DECORATIONS =====

  /// Trending recipe card decoration
  static BoxDecoration get trendingRecipeCardDecoration => BoxDecoration(
    color: AppColors.primaryContainer.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
  );

  /// Activity timeline item decoration
  static BoxDecoration get activityTimelineItemDecoration => BoxDecoration(
    color: AppColors.secondaryContainer.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
  );

  /// Empty state container decoration
  static BoxDecoration get emptyStateContainerDecoration => BoxDecoration(
    color: AppColors.primaryContainer.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
  );
}
