// lib/widgets/common/dialogs/recipe_selection/recipe_selection_builders.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Common builders for recipe selection components
class RecipeSelectionBuilders {
  /// Build recipe placeholder image
  static Widget recipeImagePlaceholder({
    bool isShared = false,
    double? width,
    double? height,
  }) {
    return Container(
      width: width ?? AppDimensions.iconSizeXxl,
      height: height ?? AppDimensions.iconSizeXxl,
      decoration: BoxDecoration(
        color: isShared
            ? AppColors.sharedRecipeBackground
            : AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Icon(
        Icons.restaurant_menu,
        color: isShared
            ? AppColors.sharedRecipeIcon
            : AppColors.primaryBlue,
        size: AppDimensions.iconSizeAction,
      ),
    );
  }

  /// Build recipe image with fallback
  static Widget recipeImage({
    required Recipe recipe,
    bool isShared = false,
    double? width,
    double? height,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: recipe.imageUrls.isNotEmpty
          ? Image.network(
              recipe.imageUrls.first,
              width: width ?? AppDimensions.iconSizeXxl,
              height: height ?? AppDimensions.iconSizeXxl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  recipeImagePlaceholder(
                isShared: isShared,
                width: width,
                height: height,
              ),
            )
          : recipeImagePlaceholder(
              isShared: isShared,
              width: width,
              height: height,
            ),
    );
  }

  /// Build recipe metadata row (time, portions)
  static Widget recipeMetadata({
    required Recipe recipe,
    bool isShared = false,
  }) {
    return Row(
      children: [
        if (recipe.timeMinutes != null) ...[
          Icon(
            Icons.access_time,
            size: AppDimensions.iconSizeM,
            color: isShared
                ? AppColors.sharedRecipeIcon
                : AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            '${recipe.timeMinutes} min',
            style: isShared
                ? AppTextStyles.bodySmall.copyWith(
                    color: AppColors.sharedRecipeIcon,
                    fontSize: AppTextStyles.labelSmall.fontSize,
                  )
                : AppTextStyles.bodySmall.copyWith(fontSize: AppTextStyles.labelSmall.fontSize),
          ),
        ],
        if (recipe.portions != null) ...[
          if (recipe.timeMinutes != null) ...[
            const SizedBox(width: AppDimensions.spacingS),
            const Text('•', style: AppTextStyles.bodySmall),
            const SizedBox(width: AppDimensions.spacingS),
          ],
          Icon(
            Icons.people,
            size: AppDimensions.iconSizeM,
            color: isShared
                ? AppColors.sharedRecipeIcon
                : AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            '${recipe.portions} port',
            style: isShared
                ? AppTextStyles.bodySmall.copyWith(
                    color: AppColors.sharedRecipeIcon,
                    fontSize: AppTextStyles.labelSmall.fontSize,
                  )
                : AppTextStyles.bodySmall.copyWith(fontSize: AppTextStyles.labelSmall.fontSize),
          ),
        ],
      ],
    );
  }

  /// Build selection info chip
  static Widget selectionInfoChip({
    required int selectedCount,
    required VoidCallback onClear,
    String? customText,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingXs,
            vertical: AppDimensions.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: Text(
            customText ?? '$selectedCount valda',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onClear,
          child: const Text('Rensa val'),
        ),
      ],
    );
  }

  /// Build recipe subtitle with meal type and description
  static Widget recipeSubtitle({
    required Recipe recipe,
    bool isShared = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.mealType,
          style: isShared
              ? AppTextStyles.bodySmall.copyWith(
                  color: AppColors.sharedRecipeText,
                  fontWeight: FontWeight.w600,
                )
              : AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
        ),
        if (recipe.description.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            recipe.description,
            style: isShared
                ? AppTextStyles.bodySmall
                    .copyWith(color: AppColors.sharedRecipeText)
                : AppTextStyles.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppDimensions.spacingXs),
        recipeMetadata(recipe: recipe, isShared: isShared),
      ],
    );
  }

  /// Build shared recipe badge
  static Widget sharedRecipeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingXs,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.sharedRecipeBackground,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Text(
        'Delad',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.sharedRecipeText,
        ),
      ),
    );
  }
}