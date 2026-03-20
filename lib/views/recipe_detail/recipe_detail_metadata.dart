// lib/views/recipe_detail/recipe_detail_metadata.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
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
    final cs = Theme.of(context).colorScheme;
    final recipe = widget.viewModel.recipe;

    final metadataWidgets = <Widget>[];

    // Time with clock icon
    if ((recipe.timeMinutes ?? 0) > 0) {
      metadataWidgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 16, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            TimeFormatUtils.formatCookingTime(recipe.timeMinutes!),
            style: AppTextStyles.bodySmall.copyWith(
              color: widget.isScaled ? cs.primary : cs.onSurface,
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
          Icon(Icons.person_outline, size: 16, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            '${widget.currentPortions} ${widget.currentPortions == 1 ? context.l10n.recipePortionSingular : context.l10n.recipePortionAbbreviation}',
            style: AppTextStyles.bodySmall.copyWith(
              color: widget.isScaled ? cs.primary : cs.onSurface,
              fontWeight: widget.isScaled ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ));
    }

    // Star rating row — always visible, tappable to set rating
    metadataWidgets.add(Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInteractiveStarRating(context, recipe.rating ?? 0),
        if ((recipe.rating ?? 0) > 0) ...[
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            recipe.rating!.toStringAsFixed(1),
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
          ),
          // Remove own rating — only when the user has rated
          if (_checkedUserRating && _hasUserRating) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            GestureDetector(
              onTap: () => _removeMyRating(context),
              child: Icon(
                Icons.close,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    ));

    // "Lagat idag" as subtle chip (thin border, minimal padding)
    metadataWidgets.add(
      OutlinedButton.icon(
        onPressed: () => _markAsCooked(context),
        icon: const Icon(Icons.check_circle_outline, size: 14),
        label: Text(context.l10n.recipeCookedToday,
            style: AppTextStyles.labelSmall),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.butleryColors.success,
          side: BorderSide(color: context.butleryColors.success, width: 0.5),
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

  Widget _buildInteractiveStarRating(BuildContext context, double rating) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = starValue <= rating;
        final isHalf = !isFilled && starValue - 0.5 <= rating;

        return Semantics(
          label: context.l10n.ratingStarLabel(starValue),
          child: GestureDetector(
            onTap: () => _rateRecipe(context, starValue.toDouble()),
            child: Icon(
              isFilled
                  ? Icons.star
                  : isHalf
                      ? Icons.star_half
                      : Icons.star_border,
              color: isFilled || isHalf
                  ? context.butleryColors.starGold
                  : cs.onSurfaceVariant,
              size: AppDimensions.iconSizeL,
            ),
          ),
        );
      }),
    );
  }

  Future<void> _rateRecipe(BuildContext context, double rating) async {
    try {
      final success = await widget.viewModel.rateRecipe(rating);
      if (!context.mounted) return;
      if (success) {
        // Only track user rating state for shared/collaborative recipes
        // (personal recipes store rating directly, no social rating record)
        if (!widget.viewModel.recipe.isPersonal) {
          setState(() {
            _hasUserRating = true;
            _checkedUserRating = true;
          });
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.ratingError);
    }
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
      SnackBarUtils.showSuccess(
        context,
        context.l10n.recipeCookedTodaySuccess,
      );
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        context.l10n.recipeCookedTodayError,
      );
    }
  }
}
