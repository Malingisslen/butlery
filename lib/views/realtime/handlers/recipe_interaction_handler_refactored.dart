// lib/views/realtime/handlers/recipe_interaction_handler_refactored.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/base/base_action_handler.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/common/navigation_components.dart';
import 'package:butlery/theme/app_colors.dart';

/// Refactored RecipeInteractionHandler using BaseActionHandler
/// 
/// This class provides standardized recipe interaction operations with:
/// - Consistent error handling and user feedback
/// - Proper confirmation dialogs for destructive operations
/// - Safe context handling for UI operations
/// - Standardized navigation and dialog patterns
class RecipeInteractionHandler extends BaseActionHandler with ActionStateMixin {
  final RealtimeMenuViewModel viewModel;

  @override
  String get serviceName => 'RecipeInteractionHandler';

  RecipeInteractionHandler({
    required this.viewModel,
  });

  // ===== RECIPE MANAGEMENT OPERATIONS =====

  /// Show dialog for adding recipes to category
  Future<void> showAddRecipeDialog(
    BuildContext context,
    String categoryName,
  ) async {
    if (!validateContext(context) || !validateRequired([categoryName], 'adding recipe to category')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        final result = await NavigationComponents.showMenuRecipeSelector(
          context,
          categoryName: categoryName,
        );

        if (result == null || result.isEmpty) {
          throw Exception('Inget recept valt');
        }

        // Add all selected recipes to the category
        for (final recipe in result) {
          await viewModel.addRecipeToCategory(
            categoryName: categoryName,
            recipe: recipe,
          );
        }

        return result.length;
      },
      successMessage: 'Recept tillagda i $categoryName',
      errorMessage: 'Kunde inte lägga till recept',
      metadata: {
        'category_name': categoryName,
        'action': 'add_recipes_to_category',
      },
    );
  }

  /// Remove recipe from category with confirmation
  Future<void> removeRecipeFromCategory(
    BuildContext context,
    String categoryName,
    int recipeIndex,
    Recipe recipe,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([categoryName, recipe.id], 'removing recipe from category')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () => viewModel.removeRecipeFromCategory(
        categoryName: categoryName,
        recipeIndex: recipeIndex,
      ),
      confirmationTitle: 'Ta bort recept',
      confirmationMessage: 'Vill du ta bort "${recipe.title}" från $categoryName?',
      confirmActionText: 'Ta bort',
      confirmationIcon: Icons.delete_outline,
      isDangerous: true,
      successMessage: '"${recipe.title}" borttaget från $categoryName',
      errorMessage: 'Kunde inte ta bort recept',
      metadata: {
        'category_name': categoryName,
        'recipe_id': recipe.id,
        'recipe_title': recipe.title,
        'recipe_index': recipeIndex,
        'action': 'remove_recipe_from_category',
      },
    );
  }

  /// Clear entire category with confirmation
  Future<void> clearCategory(
    BuildContext context,
    String categoryName,
  ) async {
    if (!validateContext(context) || !validateRequired([categoryName], 'clearing category')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () => viewModel.clearCategory(categoryName),
      confirmationTitle: 'Rensa kategori',
      confirmationMessage: 'Vill du ta bort alla recept från $categoryName?\n\nDetta går inte att ångra.',
      confirmActionText: 'Rensa',
      confirmationIcon: Icons.clear_all,
      isDangerous: true,
      successMessage: '$categoryName rensad',
      errorMessage: 'Kunde inte rensa kategori',
      metadata: {
        'category_name': categoryName,
        'action': 'clear_category',
      },
    );
  }

  /// Regenerate category with AI
  Future<void> regenerateCategory(
    BuildContext context,
    String categoryName,
  ) async {
    if (!validateContext(context) || !validateRequired([categoryName], 'regenerating category')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () => viewModel.regenerateCategory(categoryName),
      confirmationTitle: 'Regenerera kategori',
      confirmationMessage: 'Vill du låta AI:n generera nya recept för $categoryName?\n\nDetta kommer ersätta alla nuvarande recept i kategorin.',
      confirmActionText: 'Regenerera',
      confirmationIcon: Icons.auto_awesome,
      isDangerous: true,
      successMessage: '$categoryName regenererad med nya recept',
      errorMessage: 'Kunde inte regenerera kategori',
      metadata: {
        'category_name': categoryName,
        'action': 'regenerate_category',
      },
    );
  }

  // ===== RECIPE ORGANIZATION OPERATIONS =====

  /// Handle recipe reordering within category
  Future<void> handleRecipeReorder(
    BuildContext context,
    String categoryName,
    int oldIndex,
    int newIndex,
  ) async {
    if (!validateContext(context) || !validateRequired([categoryName], 'reordering recipes')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Adjust index for Flutter's ReorderableListView behavior
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }

        await viewModel.reorderRecipeInCategory(
          categoryName: categoryName,
          fromIndex: oldIndex,
          toIndex: newIndex,
        );

        return true;
      },
      logAction: false, // Don't log every reorder operation
      metadata: {
        'category_name': categoryName,
        'old_index': oldIndex,
        'new_index': newIndex,
        'action': 'reorder_recipe',
      },
    );
  }

  /// Move recipe between categories
  Future<void> moveRecipeBetweenCategories(
    BuildContext context,
    String fromCategory,
    int recipeIndex,
    Recipe recipe,
  ) async {
    if (!validateContext(context) || 
        !validateRequired([fromCategory, recipe.id], 'moving recipe between categories')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        final availableCategories = viewModel.currentMenu?.categories
                .where((cat) => cat != fromCategory)
                .toList() ??
            [];

        if (availableCategories.isEmpty) {
          throw Exception('Inga andra kategorier att flytta till');
        }

        final selectedCategory = await _showCategorySelectionDialog(
          context, 
          recipe.title, 
          availableCategories,
        );

        if (selectedCategory == null) {
          throw Exception('Ingen kategori vald');
        }

        await viewModel.moveRecipeBetweenCategories(
          fromCategory: fromCategory,
          fromIndex: recipeIndex,
          toCategory: selectedCategory,
        );

        return selectedCategory;
      },
      successMessage: '"${recipe.title}" flyttad mellan kategorier',
      errorMessage: 'Kunde inte flytta recept',
      metadata: {
        'from_category': fromCategory,
        'recipe_id': recipe.id,
        'recipe_title': recipe.title,
        'recipe_index': recipeIndex,
        'action': 'move_recipe_between_categories',
      },
    );
  }

  // ===== BATCH OPERATIONS =====

  /// Add multiple recipes to category
  Future<void> addMultipleRecipesToCategory(
    BuildContext context,
    String categoryName,
    List<Recipe> recipes,
  ) async {
    if (!validateContext(context) || recipes.isEmpty) {
      showErrorMessage(context, 'Inga recept att lägga till');
      return;
    }

    await executeWithLoadingState(
      context: context,
      action: () async {
        int successCount = 0;

        for (final recipe in recipes) {
          try {
            await viewModel.addRecipeToCategory(
              categoryName: categoryName,
              recipe: recipe,
            );
            successCount++;
          } catch (e) {
            // Log individual failures but continue
            continue;
          }
        }

        if (successCount == 0) {
          throw Exception('Kunde inte lägga till några recept');
        }

        return successCount;
      },
      successMessage: '${recipes.length} recept tillagda i $categoryName',
      errorMessage: 'Kunde inte lägga till alla recept',
      metadata: {
        'category_name': categoryName,
        'recipe_count': recipes.length,
        'recipe_ids': recipes.map((r) => r.id).toList(),
        'action': 'add_multiple_recipes',
      },
    );
  }

  /// Remove multiple recipes from category
  Future<void> removeMultipleRecipesFromCategory(
    BuildContext context,
    String categoryName,
    List<int> recipeIndexes,
    List<Recipe> recipes,
  ) async {
    if (!validateContext(context) || recipeIndexes.isEmpty) {
      showErrorMessage(context, 'Inga recept valda för borttagning');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Sort indexes in descending order to avoid index shifting issues
        final sortedIndexes = recipeIndexes.toList()..sort((a, b) => b.compareTo(a));
        
        for (final index in sortedIndexes) {
          await viewModel.removeRecipeFromCategory(
            categoryName: categoryName,
            recipeIndex: index,
          );
        }

        return recipeIndexes.length;
      },
      confirmationTitle: 'Ta bort valda recept',
      confirmationMessage: 'Vill du ta bort ${recipeIndexes.length} recept från $categoryName?',
      confirmActionText: 'Ta bort alla',
      confirmationIcon: Icons.delete_outline,
      isDangerous: true,
      successMessage: '${recipeIndexes.length} recept borttagna från $categoryName',
      errorMessage: 'Kunde inte ta bort alla recept',
      metadata: {
        'category_name': categoryName,
        'recipe_count': recipeIndexes.length,
        'recipe_indexes': recipeIndexes,
        'action': 'remove_multiple_recipes',
      },
    );
  }

  // ===== NAVIGATION OPERATIONS =====

  /// Navigate to recipe details
  Future<void> showRecipeDetails(
    BuildContext context,
    Recipe recipe,
  ) async {
    if (!validateContext(context) || !validateRequired([recipe.id], 'showing recipe details')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        Navigator.of(context).pushNamed('/recipe-detail', arguments: recipe);
        return true;
      },
      errorMessage: 'Kunde inte öppna receptdetaljer',
      metadata: {
        'recipe_id': recipe.id,
        'recipe_title': recipe.title,
        'action': 'show_recipe_details',
      },
    );
  }

  /// Share recipe from menu
  Future<void> shareRecipe(
    BuildContext context,
    Recipe recipe,
  ) async {
    if (!validateContext(context) || !validateRequired([recipe.id], 'sharing recipe')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // In real implementation, this would open share dialog
        await Future.delayed(const Duration(milliseconds: 300));
        return true;
      },
      successMessage: 'Recept "${recipe.title}" delat',
      errorMessage: 'Kunde inte dela recept',
      metadata: {
        'recipe_id': recipe.id,
        'recipe_title': recipe.title,
        'action': 'share_recipe',
      },
    );
  }

  // ===== HELPER DIALOGS =====

  /// Show category selection dialog for moving recipes
  Future<String?> _showCategorySelectionDialog(
    BuildContext context,
    String recipeTitle,
    List<String> availableCategories,
  ) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Flytta "$recipeTitle" till:'),
        children: [
          ...availableCategories.map((category) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(category),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.grey, size: 20),
                  SizedBox(width: 12),
                  Text('Avbryt', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== UTILITY METHODS =====

  /// Check if category can be cleared
  bool canClearCategory(String categoryName) {
    final menu = viewModel.currentMenu;
    if (menu == null) return false;

    final categoryRecipes = menu.menuSnapshot[categoryName];
    return categoryRecipes != null && categoryRecipes.isNotEmpty;
  }

  /// Check if recipe can be moved
  bool canMoveRecipe(String fromCategory) {
    final menu = viewModel.currentMenu;
    if (menu == null) return false;

    final otherCategories = menu.categories.where((cat) => cat != fromCategory);
    return otherCategories.isNotEmpty;
  }

  /// Get category statistics
  Map<String, dynamic> getCategoryStats(String categoryName) {
    final menu = viewModel.currentMenu;
    if (menu == null) return {};

    final categoryRecipes = menu.menuSnapshot[categoryName] ?? [];
    
    return {
      'category_name': categoryName,
      'recipe_count': categoryRecipes.length,
      'can_clear': categoryRecipes.isNotEmpty,
      'can_regenerate': true, // Simplified permission check
      'can_move_recipes': canMoveRecipe(categoryName),
    };
  }

  /// Get available actions for recipe
  List<String> getAvailableRecipeActions(Recipe recipe, String categoryName) {
    final actions = <String>[];
    
    actions.add('view_details');
    actions.add('share');
    
    if (true) { // Simplified permission check
      actions.add('remove');
      if (canMoveRecipe(categoryName)) {
        actions.add('move');
      }
    }
    
    return actions;
  }

  // ===== CLEANUP =====

  /// Dispose resources
  void dispose() {
    clearError();
  }
}