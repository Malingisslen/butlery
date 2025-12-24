// lib/viewmodels/realtime_menu/realtime_menu_operations.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/realtime/optimistic_update_manager.dart';

/// Focused module for realtime menu recipe operations
/// This module handles ONLY menu content operations:
/// - Recipe CRUD operations in categories
/// - Recipe movement between categories
/// - Category management
/// - Optimistic updates for better UX
/// ❌ DOES NOT CONTAIN: UI state, streaming, participant management
class RealtimeMenuOperations {
  final RealtimeMenuService _menuService;
  final OptimisticUpdateManager _optimisticManager;

  RealtimeMenuOperations({
    required RealtimeMenuService menuService,
    required OptimisticUpdateManager optimisticManager,
  })  : _menuService = menuService,
        _optimisticManager = optimisticManager;

  // ===== RECIPE OPERATIONS =====

  /// Add recipe to specific category
  Future<void> addRecipeToCategory({
    required String menuId,
    required String categoryName,
    required Recipe recipe,
  }) async {
    AppLogger.info('➕ Adding recipe to $categoryName: ${recipe.title}');

    // Apply optimistic update
    _optimisticManager.applyChange(categoryName, (recipes) {
      return [...recipes, recipe];
    });

    try {
      await _menuService.addRecipeToCategory(
        resourceId: menuId,
        categoryName: categoryName,
        recipe: recipe,
      );

      AppLogger.success('✅ Recipe added to $categoryName: ${recipe.title}');
    } catch (e) {
      AppLogger.error('❌ Failed to add recipe to $categoryName', e);
      _optimisticManager.rollback();
      rethrow;
    }
  }

  /// Remove recipe from category by index
  Future<void> removeRecipeFromCategory({
    required String menuId,
    required String categoryName,
    required int recipeIndex,
    required List<Recipe> currentRecipes,
  }) async {
    if (recipeIndex < 0 || recipeIndex >= currentRecipes.length) {
      throw ArgumentError('Invalid recipe index: $recipeIndex');
    }

    final recipe = currentRecipes[recipeIndex];
    AppLogger.info('➖ Removing recipe from $categoryName: ${recipe.title}');

    // Apply optimistic update
    _optimisticManager.applyChange(categoryName, (recipes) {
      final updated = List<Recipe>.from(recipes);
      updated.removeAt(recipeIndex);
      return updated;
    }, currentRecipes);

    try {
      await _menuService.removeRecipeFromCategory(
        resourceId: menuId,
        categoryName: categoryName,
        recipeIndex: recipeIndex,
      );

      AppLogger.success('✅ Recipe removed from $categoryName');
    } catch (e) {
      AppLogger.error('❌ Failed to remove recipe from $categoryName', e);
      _optimisticManager.rollback();
      rethrow;
    }
  }

  /// Move recipe between categories
  Future<void> moveRecipeBetweenCategories({
    required String menuId,
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    required List<Recipe> fromRecipes,
    required List<Recipe> toRecipes,
    int? toIndex,
  }) async {
    if (fromIndex < 0 || fromIndex >= fromRecipes.length) {
      throw ArgumentError('Invalid from index: $fromIndex');
    }

    final recipe = fromRecipes[fromIndex];
    AppLogger.info(
        '🔄 Moving recipe from $fromCategory to $toCategory: ${recipe.title}');

    // Apply optimistic updates for both categories
    _optimisticManager.applyChange(fromCategory, (recipes) {
      final updated = List<Recipe>.from(recipes);
      updated.removeAt(fromIndex);
      return updated;
    }, fromRecipes);

    _optimisticManager.applyChange(toCategory, (recipes) {
      final updated = List<Recipe>.from(recipes);
      final insertIndex = toIndex ?? updated.length;
      updated.insert(insertIndex.clamp(0, updated.length), recipe);
      return updated;
    }, toRecipes);

    try {
      await _menuService.moveRecipeBetweenCategories(
        resourceId: menuId,
        fromCategory: fromCategory,
        fromIndex: fromIndex,
        toCategory: toCategory,
        toIndex: toIndex,
      );

      AppLogger.success('✅ Recipe moved from $fromCategory to $toCategory');
    } catch (e) {
      AppLogger.error('❌ Failed to move recipe between categories', e);
      _optimisticManager.rollback();
      rethrow;
    }
  }

  /// Reorder recipes within a category
  Future<void> reorderRecipesInCategory({
    required String menuId,
    required String categoryName,
    required int fromIndex,
    required int toIndex,
    required List<Recipe> currentRecipes,
  }) async {
    if (fromIndex == toIndex) return;

    if (fromIndex < 0 ||
        fromIndex >= currentRecipes.length ||
        toIndex < 0 ||
        toIndex >= currentRecipes.length) {
      throw ArgumentError('Invalid indices for reordering');
    }

    final recipe = currentRecipes[fromIndex];
    AppLogger.info('🔄 Reordering recipe in $categoryName: ${recipe.title}');

    // Apply optimistic update
    _optimisticManager.applyChange(categoryName, (recipes) {
      final updated = List<Recipe>.from(recipes);
      final movedRecipe = updated.removeAt(fromIndex);
      updated.insert(toIndex, movedRecipe);
      return updated;
    }, currentRecipes);

    try {
      // Use move operation within same category
      await _menuService.moveRecipeBetweenCategories(
        resourceId: menuId,
        fromCategory: categoryName,
        fromIndex: fromIndex,
        toCategory: categoryName,
        toIndex: toIndex,
      );

      AppLogger.success('✅ Recipe reordered in $categoryName');
    } catch (e) {
      AppLogger.error('❌ Failed to reorder recipe in $categoryName', e);
      _optimisticManager.rollback();
      rethrow;
    }
  }

  // ===== CATEGORY OPERATIONS =====

  /// Clear all recipes from a category
  Future<void> clearCategory({
    required String menuId,
    required String categoryName,
    required List<Recipe> currentRecipes,
  }) async {
    AppLogger.info('🗑️ Clearing category: $categoryName');

    // Apply optimistic update
    _optimisticManager.applyChange(
        categoryName, (recipes) => [], currentRecipes);

    try {
      await _menuService.clearCategory(
        resourceId: menuId,
        categoryName: categoryName,
      );

      AppLogger.success('✅ Category cleared: $categoryName');
    } catch (e) {
      AppLogger.error('❌ Failed to clear category: $categoryName', e);
      _optimisticManager.rollback();
      rethrow;
    }
  }

  /// Regenerate category with AI (feature stub - not yet implemented)
  /// This is a placeholder for future AI-powered menu category regeneration.
  /// When implemented, this will use the MenuService to regenerate specific
  /// menu categories with AI-suggested recipes based on user preferences.
  Future<void> regenerateCategory({
    required String menuId,
    required String categoryName,
  }) async {
    AppLogger.info(
        '🤖 AI Menu Regeneration requested for category: $categoryName');

    // FEATURE STUB: AI menu regeneration not yet implemented
    AppLogger.warning('⚠️ AI menu regeneration is not yet available');

    throw UnimplementedError(
        'AI menu regeneration feature is planned for future release. '
        'This will integrate with MenuService to provide AI-powered '
        'category regeneration based on user preferences and dietary needs.');
  }

  // ===== BATCH OPERATIONS =====

  /// Add multiple recipes to category
  Future<void> addMultipleRecipesToCategory({
    required String menuId,
    required String categoryName,
    required List<Recipe> recipes,
  }) async {
    if (recipes.isEmpty) return;

    AppLogger.info('➕ Adding ${recipes.length} recipes to $categoryName');

    // Apply optimistic update
    _optimisticManager.applyChange(categoryName, (currentRecipes) {
      return [...currentRecipes, ...recipes];
    });

    try {
      // Add recipes one by one (or implement batch operation in service)
      for (final recipe in recipes) {
        await _menuService.addRecipeToCategory(
          resourceId: menuId,
          categoryName: categoryName,
          recipe: recipe,
        );
      }

      AppLogger.success('✅ ${recipes.length} recipes added to $categoryName');
    } catch (e) {
      AppLogger.error('❌ Failed to add multiple recipes to $categoryName', e);
      _optimisticManager.rollback();
      rethrow;
    }
  }

  /// Remove multiple recipes from category by indices
  Future<void> removeMultipleRecipesFromCategory({
    required String menuId,
    required String categoryName,
    required List<int> indices,
    required List<Recipe> currentRecipes,
  }) async {
    if (indices.isEmpty) return;

    // Validate all indices
    for (final index in indices) {
      if (index < 0 || index >= currentRecipes.length) {
        throw ArgumentError('Invalid recipe index: $index');
      }
    }

    AppLogger.info('➖ Removing ${indices.length} recipes from $categoryName');

    // Sort indices in descending order to remove from end first
    final sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));

    // Apply optimistic update
    _optimisticManager.applyChange(categoryName, (recipes) {
      final updated = List<Recipe>.from(recipes);
      for (final index in sortedIndices) {
        updated.removeAt(index);
      }
      return updated;
    }, currentRecipes);

    try {
      // Remove recipes one by one from end to beginning
      for (final index in sortedIndices) {
        await _menuService.removeRecipeFromCategory(
          resourceId: menuId,
          categoryName: categoryName,
          recipeIndex: index,
        );
      }

      AppLogger.success(
          '✅ ${indices.length} recipes removed from $categoryName');
    } catch (e) {
      AppLogger.error(
          '❌ Failed to remove multiple recipes from $categoryName', e);
      _optimisticManager.rollback();
      rethrow;
    }
  }

  // ===== OPTIMISTIC UPDATES =====

  /// Apply optimistic changes to menu snapshot
  Map<String, List<Recipe>> applyOptimisticChanges(
      Map<String, List<Recipe>> baseMenu) {
    return _optimisticManager.applyToMenu(baseMenu);
  }

  /// Check if there are pending optimistic changes
  bool get hasOptimisticChanges => _optimisticManager.hasChanges;

  /// Get all optimistic changes
  Map<String, List<Recipe>> get optimisticChanges =>
      _optimisticManager.allChanges;

  /// Clear all optimistic changes (called when real update arrives)
  void clearOptimisticChanges() {
    _optimisticManager.clear();
  }

  /// Rollback all optimistic changes
  void rollbackOptimisticChanges() {
    _optimisticManager.rollback();
  }

  // ===== VALIDATION =====

  /// Validate recipe for addition to category
  bool validateRecipeForCategory(Recipe recipe, String categoryName) {
    if (recipe.title.isEmpty) {
      AppLogger.warning(
          '⚠️ Cannot add recipe with empty title to $categoryName');
      return false;
    }

    return true;
  }

  /// Validate category name
  bool validateCategoryName(String categoryName) {
    if (categoryName.trim().isEmpty) {
      AppLogger.warning('⚠️ Invalid category name');
      return false;
    }

    return true;
  }

  // ===== UTILITY METHODS =====

  /// Get recipe count for category (including optimistic changes)
  int getRecipeCountForCategory(String categoryName, List<Recipe> baseRecipes) {
    if (_optimisticManager.hasChanges &&
        _optimisticManager.allChanges.containsKey(categoryName)) {
      return _optimisticManager.allChanges[categoryName]!.length;
    }
    return baseRecipes.length;
  }

  /// Get recipes for category (including optimistic changes)
  List<Recipe> getRecipesForCategory(
      String categoryName, List<Recipe> baseRecipes) {
    if (_optimisticManager.hasChanges &&
        _optimisticManager.allChanges.containsKey(categoryName)) {
      return _optimisticManager.allChanges[categoryName]!;
    }
    return baseRecipes;
  }
}
