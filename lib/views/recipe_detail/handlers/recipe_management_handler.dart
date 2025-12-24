// lib/views/recipe_detail/handlers/recipe_management_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/share_service.dart';

/// Recipe management action handler
/// Handles recipe CRUD operations: delete, edit, mark as cooked, and share.
class RecipeManagementHandler {
  /// Delete recipe with confirmation dialog
  static Future<void> deleteRecipe(
    BuildContext context, {
    required VoidCallback onSuccess,
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
    required VoidCallback popNavigation,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final confirmed = await CommonDialogActions.showRecipeDeleteConfirmation(
      context: context,
      recipeName: viewModel.recipe.title,
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final success = await viewModel.deleteRecipe();
      if (!context.mounted) return;
      if (success) {
        popNavigation();
        showSnackBar('Recept borttaget', backgroundColor: AppColors.success);
        onSuccess();
      } else {
        showSnackBar('Kunde inte ta bort recept',
            backgroundColor: AppColors.error);
      }
    }
  }

  /// Navigate to edit recipe view
  static Future<void> editRecipe(
    BuildContext context, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    try {
      await Navigator.pushNamed(
        context,
        Routes.redigeraRecept,
        arguments: viewModel.recipe,
      );
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar('Kunde inte öppna redigeringsvy',
          backgroundColor: AppColors.error);
    }
  }

  /// Mark recipe as cooked
  static Future<void> markAsCooked(
    BuildContext context, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    try {
      await viewModel.markAsCooked();
      if (!context.mounted) return;
      showSnackBar('Recept markerat som lagat idag!',
          backgroundColor: AppColors.success);
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar('Kunde inte markera som lagat',
          backgroundColor: AppColors.error);
    }
  }

  /// Share recipe via share service
  static Future<void> shareRecipe(
    BuildContext context, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final shareService = ServiceLocator.get<ShareService>();

    try {
      await shareService.shareRecipe(viewModel.recipe);
      if (!context.mounted) return;
      showSnackBar('Recept delat', backgroundColor: AppColors.success);
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar('Kunde inte dela recept', backgroundColor: AppColors.error);
    }
  }
}
