// lib/views/recipe_detail/recipe_detail_metadata.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/time_format_utils.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Recipe detail metadata widget — inline row with time, portions, rating,
/// and "Lagat idag" chip. Source URL is shown as subtitle in the parent view.
class RecipeDetailMetadata extends StatefulWidget {
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
  State<RecipeDetailMetadata> createState() => _RecipeDetailMetadataState();
}

class _RecipeDetailMetadataState extends State<RecipeDetailMetadata> {
  bool _hasUserRating = false;
  bool _checkedUserRating = false;

  @override
  void initState() {
    super.initState();
    _checkUserRating();
  }

  Future<void> _checkUserRating() async {
    final recipe = widget.viewModel.recipe;
    if ((recipe.rating ?? 0) <= 0) return;

    try {
      final userRating =
          await widget.viewModel.recipeService.social.getUserRating(recipe.id);
      if (mounted) {
        setState(() {
          _hasUserRating = userRating != null;
          _checkedUserRating = true;
        });
      }
    } catch (_) {
      // Non-critical — just won't show the remove button
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMetadata(context);
  }

  Widget _buildMetadata(BuildContext context) {
    final recipe = widget.viewModel.recipe;

    final metadataWidgets = <Widget>[];

    // Time with clock icon
    if ((recipe.timeMinutes ?? 0) > 0) {
      metadataWidgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 16, color: AppColors.forestGreen),
          const SizedBox(width: 4),
          Text(
            TimeFormatUtils.formatCookingTime(recipe.timeMinutes!),
            style: AppTextStyles.bodySmall.copyWith(
              color:
                  widget.isScaled ? AppColors.forestGreen : AppColors.textDark,
              fontWeight: widget.isScaled ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ));
    }

    // Portions with person icon
    if (widget.currentPortions > 0) {
      metadataWidgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline,
              size: 16, color: AppColors.forestGreen),
          const SizedBox(width: 4),
          Text(
            '${widget.currentPortions} ${widget.currentPortions == 1 ? context.l10n.recipePortionSingular : context.l10n.recipePortionAbbreviation}',
            style: AppTextStyles.bodySmall.copyWith(
              color:
                  widget.isScaled ? AppColors.forestGreen : AppColors.textDark,
              fontWeight: widget.isScaled ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ));
    }

    // Star rating row with optional remove button
    if ((recipe.rating ?? 0) > 0) {
      metadataWidgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStarRating(recipe.rating ?? 0),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            recipe.rating!.toStringAsFixed(1),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDark),
          ),
          // Remove own rating — only when the user has rated
          if (_checkedUserRating && _hasUserRating) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            GestureDetector(
              onTap: () => _removeMyRating(context),
              child: const Icon(
                Icons.close,
                size: 14,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ],
      ));
    }

    // "Lagat idag" as subtle chip (thin border, minimal padding)
    metadataWidgets.add(
      OutlinedButton.icon(
        onPressed: () => _markAsCooked(context),
        icon: const Icon(Icons.check_circle_outline, size: 14),
        label: Text(context.l10n.recipeCookedToday,
            style: AppTextStyles.labelSmall),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.success,
          side: const BorderSide(color: AppColors.success, width: 0.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingSm,
            vertical: 2,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
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

  Future<void> _removeMyRating(BuildContext context) async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.ratingRemoveTitle,
      message: context.l10n.ratingRemoveMessage,
      confirmText: context.l10n.commonDelete,
      icon: Icons.star_border,
      isDangerous: true,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final success = await widget.viewModel.removeMyRating();
      if (!context.mounted) return;
      if (success) {
        setState(() {
          _hasUserRating = false;
        });
        SnackBarUtils.showSuccess(context, context.l10n.ratingRemoved);
      }
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.ratingRemoveError);
    }
  }

  Future<void> _markAsCooked(BuildContext context) async {
    try {
      await widget.viewModel.markAsCooked();
      if (!context.mounted) return;
      _showSnackBarSafely(
        context,
        context.l10n.recipeCookedTodaySuccess,
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBarSafely(
        context,
        context.l10n.recipeCookedTodayError,
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
