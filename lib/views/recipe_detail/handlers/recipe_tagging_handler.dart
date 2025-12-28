// lib/views/recipe_detail/handlers/recipe_tagging_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/providers/application_provider.dart';

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
      title: 'Uppdatera taggar?',
      message:
          'Analyserar ingredienser och uppdaterar allergen- och kosttaggar för "${viewModel.recipe.title}".',
      confirmText: 'Uppdatera',
      icon: Icons.local_offer,
      confirmColor: AppColors.primaryBlue,
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
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Analyserar ingredienser...',
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
          'Kunde inte analysera recept',
          backgroundColor: AppColors.error,
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
        '${tagResult.tags.length} taggar genererade ($coverage% täckning)',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      // Close loading dialog if still open
      Navigator.of(context).pop();
      showSnackBar(
        'Fel vid taggning: $e',
        backgroundColor: AppColors.error,
      );
    }
  }
}
