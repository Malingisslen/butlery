// lib/views/recipe_detail/handlers/recipe_tagging_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Recipe tagging action handler.
/// Handles manual re-tagging of recipes from the detail view.
class RecipeTaggingHandler {
  /// Re-tag recipe with confirmation dialog.
  /// Generates new tags from ingredients and updates the recipe.
  static Future<void> retagRecipe(
    BuildContext context, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final taggingService = ServiceLocator.get<TaggingService>();
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();

    // Confirm with user
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.taggingUpdateTagsTitle,
      message: context.l10n.taggingUpdateTagsMessage(viewModel.recipe.title),
      confirmText: context.l10n.commonUpdate,
      icon: Icons.local_offer,
      confirmColor: Theme.of(context).colorScheme.primary,
    );

    if (confirmed != true || !context.mounted) return;

    // Show blocking loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Text(
                  context.l10n.taggingAnalyzingIngredients,
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Generate new tags
      final tagResult = await taggingService.generateTags(viewModel.recipe);

      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (tagResult == null) {
        showSnackBar(
          context.l10n.taggingCouldNotAnalyze,
          backgroundColor: Theme.of(context).colorScheme.error,
        );
        return;
      }

      // Create updated recipe with new tags
      final updatedRecipe = Recipe(
        core: viewModel.recipe.core.copyWith(tagResult: tagResult),
        type: viewModel.recipe.type,
        socialData: viewModel.recipe.socialData,
        realtimeData: viewModel.recipe.realtimeData,
        offlineData: viewModel.recipe.offlineData,
      );

      // Save to database
      await recipeService.updateRecipe(updatedRecipe);

      // Update view model
      viewModel.updateRecipe(updatedRecipe);

      if (!context.mounted) return;

      // Show success with tag summary
      final coverage = (tagResult.coverage * 100).toInt();
      showSnackBar(
        context.l10n.taggingTagsGenerated(tagResult.tags.length, coverage),
        backgroundColor: context.butleryColors.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      // Close loading dialog if still open
      Navigator.of(context).pop();
      showSnackBar(
        context.l10n.taggingError(
          SnackBarUtils.userFriendlyMessage(context, e),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      );
    }
  }
}
