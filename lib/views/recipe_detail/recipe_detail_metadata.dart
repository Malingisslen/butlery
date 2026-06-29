// lib/views/recipe_detail/recipe_detail_metadata.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/time_format_utils.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/utils/text/text_formatting.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_management_handler.dart';

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
    if (recipe.isPersonal || (recipe.rating ?? 0) <= 0) return;

    try {
      final userRating = await widget.viewModel.recipeService.social
          .getUserRating(recipe.id);
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
      metadataWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: AppDimensions.iconSizeS,
              color: cs.primary,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              TimeFormatUtils.formatCookingTime(recipe.timeMinutes!),
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.isScaled ? cs.primary : cs.onSurface,
                fontWeight: widget.isScaled ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    // Portions with person icon
    if (widget.currentPortions > 0) {
      metadataWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: AppDimensions.iconSizeS,
              color: cs.primary,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              '${widget.currentPortions} ${widget.currentPortions == 1 ? context.l10n.recipePortionSingular : context.l10n.recipePortionAbbreviation}',
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.isScaled ? cs.primary : cs.onSurface,
                fontWeight: widget.isScaled ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    // Star rating row — always visible, tappable to set rating
    metadataWidgets.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarRatingRow(
            rating: recipe.rating ?? 0,
            onRatingChanged: (value) => _rateRecipe(context, value),
            semanticsLabel: (star) => context.l10n.ratingStarLabel(star),
          ),
          if ((recipe.rating ?? 0) > 0) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              // sv-SE decimal comma (4.5 → "4,5"); whole ratings drop the decimal.
              TextFormatting.formatFractional(recipe.rating!),
              style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
            ),
            // Remove own rating — only when the user has rated
            if (_checkedUserRating && _hasUserRating) ...[
              const SizedBox(width: AppDimensions.spacingXs),
              Semantics(
                label: context.l10n.a11yRemoveOwnRating,
                button: true,
                child: GestureDetector(
                  onTap: () => _removeMyRating(context),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );

    // "Lagat idag" chip — disabled after first tap per calendar day.
    // BUT-403: `btn-mark-cooked` identifier for browser a11y tree queries.
    final cookedToday = widget.viewModel.wasCookedToday;
    final cookCount = widget.viewModel.recipe.cookCount;
    metadataWidgets.add(
      Semantics(
        identifier: 'btn-mark-cooked',
        button: true,
        enabled: !cookedToday,
        label: context.l10n.recipeCookedToday,
        child: OutlinedButton.icon(
          key: const ValueKey('test-recipe-detail-mark-cooked'),
          onPressed: cookedToday ? null : () => _markAsCooked(context),
          icon: Icon(
            cookedToday ? Icons.check_circle : Icons.check_circle_outline,
            size: 14,
          ),
          label: Text(
            cookCount > 0
                ? '${context.l10n.recipeCookedToday} ($cookCount)'
                : context.l10n.recipeCookedToday,
            style: AppTextStyles.labelSmall,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.butleryColors.success,
            disabledForegroundColor: context.butleryColors.success.withValues(
              alpha: 0.5,
            ),
            side: BorderSide(
              color: cookedToday
                  ? context.butleryColors.success.withValues(alpha: 0.3)
                  : context.butleryColors.success,
              width: 0.5,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
              vertical: AppDimensions.spacingXxs,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ),
    );

    // Manual "Betygsätt som familj" entry — the second trigger for family
    // rating (the first is the auto-chain after "Lagat idag"). Square outlined
    // button mirroring the cook chip's treatment.
    metadataWidgets.add(
      Semantics(
        button: true,
        label: context.l10n.familyRatingManualButton,
        child: OutlinedButton.icon(
          onPressed: () => RecipeManagementHandler.rateAsFamily(context),
          icon: const Icon(Icons.groups_outlined, size: 14),
          label: Text(
            context.l10n.familyRatingManualButton,
            style: AppTextStyles.labelSmall,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.butleryColors.starGold,
            side: BorderSide(
              color: context.butleryColors.starGold,
              width: 0.5,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
              vertical: AppDimensions.spacingXxs,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
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
    // Delegate to the shared handler so the "vem åt?" picker and the family
    // rating chain fire here too — this is the live "Lagat idag" button, and
    // the handler is the single implementation of the cook flow.
    await RecipeManagementHandler.markAsCooked(context);
  }
}
