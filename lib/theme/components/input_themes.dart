/// Input and data display theme configurations.
///
/// **UI Redesign:**
/// - Inputs: Primary focus border
/// - Cards: Surface with subtle border
/// - Chips: Pill-shaped with primary selection
/// - Error states use error color (NOT rust)

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';

/// BUT-533: keyboard-focus ring for text fields. Rust accent at 3px gives
/// ≥3:1 contrast against cream and against the field's own fill color —
/// satisfies WCAG 1.4.11 (non-text contrast) and 2.4.7 (focus visible).
const double _kFocusRingWidth = 3.0;

/// Input, card, and data display component themes.
/// All methods accept [ColorScheme] for dark/light mode awareness.
class InputThemes {
  InputThemes._();

  /// Input decoration theme
  static InputDecorationTheme inputDecorationTheme(ColorScheme cs) {
    return InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        borderSide: BorderSide(
          color: cs.outlineVariant,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        borderSide: BorderSide(
          color: cs.outlineVariant,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        // BUT-533: rust ring at 3px — visible on cream where the previous
        // 2px primary-color border faded into the surrounding surface.
        borderSide: const BorderSide(
          color: AppColors.rust,
          width: _kFocusRingWidth,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        borderSide: BorderSide(
          color: cs.error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        borderSide: BorderSide(
          color: cs.error,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingModerate,
      ),
      hintStyle: TextStyle(color: cs.outline),
      labelStyle: AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant),
      errorStyle: AppTextStyles.errorText.copyWith(color: cs.error),
    );
  }

  /// Card theme
  static CardThemeData cardTheme(ColorScheme cs) {
    return CardThemeData(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        side: BorderSide(
          color: cs.outlineVariant,
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
    );
  }

  /// List tile theme
  static ListTileThemeData listTileTheme(ColorScheme cs) {
    return ListTileThemeData(
      tileColor: cs.surfaceContainerHighest,
      selectedTileColor: cs.primaryContainer,
      iconColor: cs.primary,
      textColor: cs.onSurface,
      titleTextStyle: AppTextStyles.listTileTitle.copyWith(
        color: cs.onSurface,
      ),
      subtitleTextStyle: AppTextStyles.listTileSubtitle.copyWith(
        color: cs.onSurfaceVariant,
      ),
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

  /// Chip theme
  static ChipThemeData chipTheme(ColorScheme cs) {
    return ChipThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      selectedColor: cs.primary,
      disabledColor: cs.outlineVariant,
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: cs.onSurface,
      ),
      secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(
        color: cs.onPrimary,
      ),
      brightness: cs.brightness,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  /// Recipe card decoration - Left green border + bottom rust border.
  /// Uses AppColors directly since BoxDecoration is not part of ThemeData
  /// and these are brand-specific decorative borders.
  static BoxDecoration get recipeCardDecoration => BoxDecoration(
    color: AppColors.cardWhite,
    border: const Border(
      left: BorderSide(
        color: AppColors.recipeCardLeftBorder,
        width: 4,
      ),
      bottom: BorderSide(
        color: AppColors.recipeCardBottomBorder,
        width: 3,
      ),
    ),
    boxShadow: AppShadows.cardLifted,
  );

  /// Trending recipe card decoration
  static BoxDecoration get trendingRecipeCardDecoration => BoxDecoration(
    color: AppColors.primaryContainer.withValues(
      alpha: AppDimensions.opacityVeryLight,
    ),
    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
    border: Border.all(
      color: AppColors.forestGreen.withValues(
        alpha: AppDimensions.opacityLight,
      ),
    ),
  );

  /// Activity timeline item decoration
  static BoxDecoration get activityTimelineItemDecoration => BoxDecoration(
    color: AppColors.secondaryContainer.withValues(
      alpha: AppDimensions.opacityVeryLight,
    ),
    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
    border: Border.all(
      color: AppColors.rust.withValues(alpha: AppDimensions.opacityLight),
    ),
  );

  /// Empty state container decoration
  static BoxDecoration get emptyStateContainerDecoration => BoxDecoration(
    color: AppColors.primaryContainer.withValues(
      alpha: AppDimensions.opacityVeryLight,
    ),
    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
    border: Border.all(
      color: AppColors.forestGreen.withValues(
        alpha: AppDimensions.opacityLight,
      ),
    ),
  );

  /// Search box decoration — green+rust border always visible
  static BoxDecoration get searchBoxDecoration => BoxDecoration(
    color: AppColors.cardWhite,
    border: const Border(
      top: BorderSide(color: AppColors.forestGreen, width: 1),
      left: BorderSide(color: AppColors.forestGreen, width: 1),
      right: BorderSide(color: AppColors.forestGreen, width: 1),
      bottom: BorderSide(color: AppColors.rust, width: 2),
    ),
    boxShadow: AppShadows.searchBox,
  );

  /// Search box decoration (focused) — heavier green+rust border
  static BoxDecoration get searchBoxDecorationFocused => BoxDecoration(
    color: AppColors.cardWhite,
    border: const Border(
      top: BorderSide(color: AppColors.forestGreen, width: 2),
      left: BorderSide(color: AppColors.forestGreen, width: 2),
      right: BorderSide(color: AppColors.forestGreen, width: 2),
      bottom: BorderSide(color: AppColors.rust, width: 4),
    ),
    boxShadow: AppShadows.searchBox,
  );
}
