// lib/views/edit_recipe/edit_recipe_actions.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/widgets/common/utility_components.dart';

/// Recipe save and fork actions for edit recipe view
class EditRecipeActions {
  
  /// Save recipe with collaborative cache invalidation
  static Future<void> saveRecipe(
    BuildContext context,
    GlobalKey<FormState> formKey,
    String recipeId,
  ) async {
    if (!formKey.currentState!.validate()) return;

    final viewModel = context.read<RecipeFormViewModel>();
    final savedRecipe = await viewModel.saveRecipe();

    if (context.mounted) {
      if (savedRecipe != null) {
        // Invalidate collaborative cache after save
        final collaborativeViewModel =
            context.read<CollaborativeStatusViewModel>();
        collaborativeViewModel.invalidateRecipeStatus(recipeId);

        UtilityComponents.showSuccessSnackbar(context, 'Ändringar sparade!');
        Navigator.pop(context, true);
      } else {
        UtilityComponents.showErrorSnackbar(
            context, viewModel.error ?? 'Kunde inte spara ändringar');
      }
    }
  }

  /// Fork recipe functionality for collaborative editing
  static Future<void> forkRecipe(
    BuildContext context,
    GlobalKey<FormState> formKey,
  ) async {
    if (!formKey.currentState!.validate()) return;

    final viewModel = context.read<RecipeFormViewModel>();
    final forkedRecipe = await viewModel.saveFork();

    if (context.mounted) {
      if (forkedRecipe != null) {
        UtilityComponents.showSuccessSnackbar(
          context,
          'Din kopia av receptet sparades!',
        );
        Navigator.pop(context, true);
      } else {
        UtilityComponents.showErrorSnackbar(
          context,
          viewModel.error ?? 'Kunde inte spara din kopia',
        );
      }
    }
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}