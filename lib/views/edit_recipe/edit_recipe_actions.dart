// lib/views/edit_recipe/edit_recipe_actions.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/widgets/common/utility_components.dart';

/// Recipe save and fork actions for edit recipe view
/// 
/// ARCHITECTURAL FIX: Removed form validation from actions class to fix encapsulation violation.
/// Form validation should be handled by the view that owns the form, not by external utility classes.
/// This class now focuses purely on business logic after validation has been confirmed.
class EditRecipeActions {
  
  /// Save recipe with collaborative cache invalidation
  /// 
  /// FIXED: No longer takes form key - validation must be done by caller
  static Future<void> saveRecipe(
    BuildContext context,
    String recipeId,
  ) async {
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
  /// 
  /// FIXED: No longer takes form key - validation must be done by caller
  static Future<void> forkRecipe(BuildContext context) async {
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
}