// lib/views/recipe_detail/recipe_detail_metadata.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Recipe detail metadata widget — inline row with time, portions, rating,
/// and "Lagat idag" chip. Source URL is shown as subtitle in the parent view.
class RecipeDetailMetadata extends StatelessWidget {
  final RecipeDetailViewModel viewModel;
  final int currentPortions;
  final bool isScaled;

  const RecipeDetailMetadata({
    super.key,
    required this.viewModel,
    required this.currentPortions,
    required this.isScaled,
  });

  @override
  Widget build(BuildContext context) {
    // UI Redesign: Simple inline metadata only (source URL shown as subtitle in parent)
    return _buildMetadata(context);
  }

  Widget _buildMetadata(BuildContext context) {
    final recipe = viewModel.recipe;

    // UI Redesign: All metadata items + "Lagat idag" chip inline using Wrap
    final metadataWidgets = <Widget>[];

    if ((recipe.timeMinutes ?? 0) > 0) {
      metadataWidgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: AppDimensions.iconSizeS, color: AppColors.textMedium),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            _formatTime(recipe.timeMinutes!),
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMedium),
          ),
        ],
      ));
    }

    if (currentPortions > 0) {
      metadataWidgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people, size: AppDimensions.iconSizeS, color: AppColors.textMedium),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            '$currentPortions ${currentPortions == 1 ? 'portion' : 'port'}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isScaled ? AppColors.forestGreen : AppColors.textMedium,
              fontWeight: isScaled ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ));
    }

    if ((recipe.rating ?? 0) > 0) {
      metadataWidgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStarRating(recipe.rating ?? 0),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            recipe.rating!.toStringAsFixed(1),
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMedium),
          ),
        ],
      ));
    }

    // "Lagat idag" as small outlined chip
    metadataWidgets.add(
      OutlinedButton.icon(
        onPressed: () => _markAsCooked(context),
        icon: const Icon(Icons.check_circle_outline, size: 14),
        label: Text('Lagat idag', style: AppTextStyles.labelSmall),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.success,
          side: const BorderSide(color: AppColors.success, width: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingSm,
            vertical: AppDimensions.spacingXs,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
        ),
      ),
    );

    return Wrap(
      spacing: AppDimensions.spacingMd,
      runSpacing: AppDimensions.spacingSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: metadataWidgets,
    );
  }

  Widget _buildStarRating(double rating) {
    final fullStars = rating.floor();
    final hasHalfStar = rating - fullStars >= 0.5;
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Full stars
        ...List.generate(
            fullStars,
            (index) => const Icon(
                  Icons.star,
                  color: AppColors.warning,
                  size: AppDimensions.iconSizeM,
                )),

        // Half star
        if (hasHalfStar)
          const Icon(
            Icons.star_half,
            color: AppColors.warning,
            size: AppDimensions.iconSizeM,
          ),

        // Empty stars
        ...List.generate(
            emptyStars,
            (index) => const Icon(
                  Icons.star_border,
                  color: AppColors.textMedium,
                  size: AppDimensions.iconSizeM,
                )),
      ],
    );
  }

  String _formatTime(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours h';
      } else {
        return '$hours h $remainingMinutes min';
      }
    }
  }

  Future<void> _markAsCooked(BuildContext context) async {
    try {
      await viewModel.markAsCooked();
      if (!context.mounted) return;
      _showSnackBarSafely(
        context,
        'Recept markerat som lagat idag!',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBarSafely(
        context,
        'Kunde inte markera som lagat',
        backgroundColor: AppColors.error,
      );
    }
  }

  void _showSnackBarSafely(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    if (context.mounted) {
      if (backgroundColor == AppColors.error) {
        SnackBarUtils.showError(context, message);
      } else {
        SnackBarUtils.showSuccess(context, message);
      }
    }
  }
}
