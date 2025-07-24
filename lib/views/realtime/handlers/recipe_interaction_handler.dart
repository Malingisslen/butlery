// lib/views/realtime/handlers/recipe_interaction_handler.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/realtime_menu_viewmodel.dart';
import '../../../models/recipe_unified.dart';
import '../../../widgets/common/navigation_components.dart';
import '../../../theme/app_colors.dart';
import '../../../core/utils/logger.dart';

/// Handler för recipe interactions med kategori-struktur
class RecipeInteractionHandler {
  final RealtimeMenuViewModel viewModel;
  final BuildContext context;

  RecipeInteractionHandler({
    required this.viewModel,
    required this.context,
  });

  /// Visa dialog för att lägga till recept till kategori
  /// ✅ UPPDATERAD: Använder NavigationComponents.showMenuRecipeSelector()
  Future<void> showAddRecipeDialog(String categoryName) async {
    final result = await NavigationComponents.showMenuRecipeSelector(
      context,
      categoryName: categoryName,
    );

    if (result != null && result.isNotEmpty) {
      for (final recipe in result) {
        await viewModel.addRecipeToCategory(
          categoryName: categoryName,
          recipe: recipe,
        );
      }

      // ✅ BONUS: Visa bekräftelse
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.length} recept tillagda i $categoryName',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  /// Bekräfta borttagning av recept
  Future<bool> confirmRemoveRecipe(String recipeTitle) async {
    return await NavigationComponents.showConfirmationDialog(
      context,
      title: 'Ta bort recept',
      message: 'Vill du ta bort "$recipeTitle" från denna kategori?',
      confirmText: 'Ta bort',
      cancelText: 'Avbryt',
      confirmColor: AppColors.error,
    );
  }

  /// Bekräfta rensning av hela kategorin
  Future<void> confirmClearCategory(String categoryName) async {
    final confirmed = await NavigationComponents.showConfirmationDialog(
      context,
      title: 'Rensa kategori',
      message: 'Vill du ta bort alla recept från $categoryName?',
      confirmText: 'Rensa',
      cancelText: 'Avbryt',
      confirmColor: AppColors.error,
    );

    if (confirmed) {
      await viewModel.clearCategory(categoryName);

      // ✅ BONUS: Visa bekräftelse
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$categoryName rensad'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  /// Visa dialog för att regenerera kategori (AI-funktion)
  Future<void> showRegenerateCategoryDialog(String categoryName) async {
    final confirmed = await NavigationComponents.showConfirmationDialog(
      context,
      title: 'Regenerera kategori',
      message: 'Vill du låta AI:n generera nya recept för $categoryName? '
          'Detta kommer ersätta alla nuvarande recept i kategorin.',
      confirmText: 'Regenerera',
      cancelText: 'Avbryt',
    );

    if (confirmed) {
      await viewModel.regenerateCategory(categoryName);

      // ✅ BONUS: Visa bekräftelse
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$categoryName regenererad'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  /// Hantera recipe reordering inom kategori
  void handleRecipeReorder(
    String categoryName,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    AppLogger.info(
        '🔄 Reordering recipe: $oldIndex -> $newIndex in $categoryName');

    // Anropa viewModel för att ändra ordning på recept
    viewModel.reorderRecipeInCategory(
      categoryName: categoryName,
      fromIndex: oldIndex,
      toIndex: newIndex,
    );
  }

  /// Navigera till receptdetaljer
  void showRecipeDetails(Recipe recipe) {
    Navigator.of(context).pushNamed('/recipe-detail', arguments: recipe);
  }

  /// Visa dialog för att flytta recept mellan kategorier
  Future<void> showMoveRecipeDialog(
    String fromCategory,
    int recipeIndex,
    Recipe recipe,
  ) async {
    final availableCategories = viewModel.currentMenu?.categories
            .where((cat) => cat != fromCategory)
            .toList() ??
        [];

    if (availableCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inga andra kategorier att flytta till'),
        ),
      );
      return;
    }

    final selectedCategory = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Flytta "${recipe.title}" till:'),
        children: availableCategories.map((category) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(category),
            child: Text(category),
          );
        }).toList(),
      ),
    );

    if (selectedCategory != null) {
      await viewModel.moveRecipeBetweenCategories(
        fromCategory: fromCategory,
        fromIndex: recipeIndex,
        toCategory: selectedCategory,
      );

      // ✅ BONUS: Visa bekräftelse
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${recipe.title}" flyttad till $selectedCategory',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}
