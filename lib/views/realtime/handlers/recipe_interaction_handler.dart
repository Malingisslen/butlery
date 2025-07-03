// lib/views/realtime/handlers/recipe_interaction_handler.dart - PROPERLY FIXED

import 'package:flutter/material.dart';
import '../../../viewmodels/realtime_menu_viewmodel.dart';
import '../../../models/recipe.dart';
import '../../../widgets/menu_recipe_selection_dialog.dart'; // ✅ RÄTT DIALOG
import '../../../theme/app_theme.dart'; // ✅ FIX: Lägg till AppTheme import
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
  /// ✅ PROPER FIX: Använd MenuRecipeSelectionDialog istället
  Future<void> showAddRecipeDialog(String categoryName) async {
    final result = await showDialog<List<Recipe>>(
      context: context,
      builder: (context) => MenuRecipeSelectionDialog(
        categoryName: categoryName, // ✅ CORRECT: Skicka kategori-namn
      ),
    );

    if (result != null && result.isNotEmpty) {
      for (final recipe in result) {
        await viewModel.addRecipeToCategory(categoryName, recipe);
      }

      // ✅ BONUS: Visa bekräftelse
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.length} recept tillagda i $categoryName',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  /// Bekräfta borttagning av recept
  Future<bool> confirmRemoveRecipe(String recipeTitle) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ta bort recept'),
            content:
                Text('Vill du ta bort "$recipeTitle" från denna kategori?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Ta bort'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Bekräfta rensning av hela kategorin
  Future<void> confirmClearCategory(String categoryName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rensa kategori'),
        content: Text('Vill du ta bort alla recept från $categoryName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rensa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.clearCategory(categoryName);

      // ✅ BONUS: Visa bekräftelse
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$categoryName rensad'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  /// Visa dialog för att regenerera kategori (AI-funktion)
  Future<void> showRegenerateCategoryDialog(String categoryName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerera kategori'),
        content: Text(
          'Vill du låta AI:n generera nya recept för $categoryName? '
          'Detta kommer ersätta alla nuvarande recept i kategorin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Regenerera'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.regenerateCategory(categoryName);

      // ✅ BONUS: Visa bekräftelse
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$categoryName regenererad'),
            backgroundColor: AppTheme.successColor,
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

    // TODO: Implementera viewModel.reorderRecipeInCategory() metod
    // För nu - bara logga att funktionen anropas
    AppLogger.info(
        '📝 Recipe reordering inom $categoryName kommer implementeras');
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
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }
}
