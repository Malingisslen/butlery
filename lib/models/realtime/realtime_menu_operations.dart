/// Comprehensive realtime menu operations providing advanced business logic and collaborative recipe management for meal planning.
/// This class implements sophisticated menu operation management following Single Responsibility Principle,
/// handling all aspects of menu business logic including recipe manipulation, category management, statistical analysis,
/// and validation operations. It provides complete operational capabilities while maintaining clean separation
/// from data representation, search analytics, and UI presentation concerns.

// lib/models/realtime/realtime_menu_operations.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';

/// Comprehensive realtime menu operations with advanced business logic and collaborative recipe management for meal planning.
/// Provides complete operational capabilities for menu manipulation including recipe management, category operations,
/// statistical analysis, and validation systems through focused business logic algorithms and Swedish meal planning optimization.
/// This class serves as the operational intelligence layer for all menu business logic and collaborative features.
class RealtimeMenuOperations {
  /// Menu content operations for advanced recipe management and category manipulation.

  /// Adds a recipe to a specified category with automatic category creation and immutable data patterns.
  static RealtimeMenuData addRecipeToCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required Recipe recipe,
  }) {
    // Create deep copy of the menu snapshot
    final updatedMenu = <String, List<Recipe>>{};
    for (final entry in data.menuSnapshot.entries) {
      updatedMenu[entry.key] = List<Recipe>.from(entry.value);
    }

    if (!updatedMenu.containsKey(categoryName)) {
      updatedMenu[categoryName] = [];
    }

    updatedMenu[categoryName]!.add(recipe);

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Removes a recipe from a specified category by index.
  static RealtimeMenuData removeRecipeFromCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required int recipeIndex,
  }) {
    // Create deep copy of the menu snapshot
    final updatedMenu = <String, List<Recipe>>{};
    for (final entry in data.menuSnapshot.entries) {
      updatedMenu[entry.key] = List<Recipe>.from(entry.value);
    }

    if (updatedMenu.containsKey(categoryName) && 
        recipeIndex >= 0 && 
        recipeIndex < updatedMenu[categoryName]!.length) {
      updatedMenu[categoryName]!.removeAt(recipeIndex);
    }

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Moves a recipe between categories.
  static RealtimeMenuData moveRecipeBetweenCategories(
    RealtimeMenuData data, {
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
  }) {
    // Create deep copy of the menu snapshot
    final updatedMenu = <String, List<Recipe>>{};
    for (final entry in data.menuSnapshot.entries) {
      updatedMenu[entry.key] = List<Recipe>.from(entry.value);
    }

    if (!updatedMenu.containsKey(fromCategory) || 
        fromIndex < 0 || 
        fromIndex >= updatedMenu[fromCategory]!.length) {
      return data;
    }

    final recipe = updatedMenu[fromCategory]!.removeAt(fromIndex);

    if (!updatedMenu.containsKey(toCategory)) {
      updatedMenu[toCategory] = [];
    }

    final targetIndex = toIndex ?? updatedMenu[toCategory]!.length;
    updatedMenu[toCategory]!.insert(targetIndex, recipe);

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Replaces a recipe in a category.
  static RealtimeMenuData replaceRecipeInCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required int recipeIndex,
    required Recipe newRecipe,
  }) {
    // Create deep copy of the menu snapshot
    final updatedMenu = <String, List<Recipe>>{};
    for (final entry in data.menuSnapshot.entries) {
      updatedMenu[entry.key] = List<Recipe>.from(entry.value);
    }

    if (updatedMenu.containsKey(categoryName) && 
        recipeIndex >= 0 && 
        recipeIndex < updatedMenu[categoryName]!.length) {
      updatedMenu[categoryName]![recipeIndex] = newRecipe;
    }

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Clears all recipes from a category.
  static RealtimeMenuData clearCategory(
    RealtimeMenuData data, {
    required String categoryName,
  }) {
    // Create deep copy of the menu snapshot
    final updatedMenu = <String, List<Recipe>>{};
    for (final entry in data.menuSnapshot.entries) {
      updatedMenu[entry.key] = List<Recipe>.from(entry.value);
    }
    
    if (updatedMenu.containsKey(categoryName)) {
      updatedMenu[categoryName] = [];
    }

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Updates an entire category with new recipes.
  static RealtimeMenuData updateWholeCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required List<Recipe> recipes,
  }) {
    // Create deep copy of the menu snapshot
    final updatedMenu = <String, List<Recipe>>{};
    for (final entry in data.menuSnapshot.entries) {
      updatedMenu[entry.key] = List<Recipe>.from(entry.value);
    }
    updatedMenu[categoryName] = List.from(recipes);
    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Regenerates a category with new recipes.
  static RealtimeMenuData regenerateCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required List<Recipe> newRecipes,
  }) {
    return updateWholeCategory(data, categoryName: categoryName, recipes: newRecipes);
  }

  // ===== STATISTICS AND ANALYSIS =====

  /// Common Swedish menu categories
  static List<String> get commonCategories => [
    'Frukost',
    'Lunch', 
    'Middag',
    'Huvudrätter',
    'Förrätter',
    'Efterrätter',
    'Mellanmål',
    'Drycker',
    'Bakverk',
    'Sallader'
  ];

  /// Get categories sorted in logical order
  static List<String> getCategoriesSorted(RealtimeMenuData data) {
    final categories = data.categories;
    final sorted = <String>[];
    
    // Add common categories first in order
    for (final common in commonCategories) {
      if (categories.contains(common)) {
        sorted.add(common);
      }
    }
    
    // Add any remaining categories
    for (final category in categories) {
      if (!sorted.contains(category)) {
        sorted.add(category);
      }
    }
    
    return sorted;
  }

  /// Get total recipe count across all categories
  static int getTotalRecipeCount(RealtimeMenuData data) {
    return data.allUniqueRecipes.length;
  }

  /// Get number of categories that have recipes
  static int getCategoriesWithRecipes(RealtimeMenuData data) {
    return data.menuSnapshot.values.where((recipes) => recipes.isNotEmpty).length;
  }

  /// Get number of empty categories
  static int getEmptyCategoriesCount(RealtimeMenuData data) {
    return data.menuSnapshot.values.where((recipes) => recipes.isEmpty).length;
  }

  /// Check if menu is complete (has recipes in at least 2 categories)
  static bool isComplete(RealtimeMenuData data) {
    return getCategoriesWithRecipes(data) >= 2;
  }

  /// Check if menu is well balanced (has recipes in at least 3 categories)
  static bool isWellBalanced(RealtimeMenuData data) {
    return getCategoriesWithRecipes(data) >= 3;
  }

  /// Get average recipes per category
  static double getAverageRecipesPerCategory(RealtimeMenuData data) {
    final totalCategories = data.categories.length;
    if (totalCategories == 0) return 0.0;
    return getTotalRecipeCount(data) / totalCategories;
  }

  /// Check if menu has favorites
  static bool hasFavorites(RealtimeMenuData data) {
    return data.favoriteRecipeIds?.isNotEmpty ?? false;
  }

  /// Get favorites count
  static int getFavoritesCount(RealtimeMenuData data) {
    return data.favoriteRecipeIds?.length ?? 0;
  }

  /// Check if menu has notes
  static bool hasNotes(RealtimeMenuData data) {
    return data.menuNotes?.isNotEmpty ?? false;
  }

  /// Check if menu was generated
  static bool wasGenerated(RealtimeMenuData data) {
    return data.originalPrompt?.isNotEmpty ?? false;
  }

  /// Get menu summary
  static String getMenuSummary(RealtimeMenuData data) {
    final total = getTotalRecipeCount(data);
    final categories = getCategoriesWithRecipes(data);
    return '$total recept i $categories kategorier';
  }

  /// Get completion percentage
  static double getCompletionPercentage(RealtimeMenuData data) {
    final categoriesWithRecipes = getCategoriesWithRecipes(data);
    final totalCategories = data.categories.length;
    if (totalCategories == 0) return 0.0;
    return categoriesWithRecipes / totalCategories;
  }

  /// Get completion status text
  static String getCompletionStatus(RealtimeMenuData data) {
    final percentage = (getCompletionPercentage(data) * 100).round();
    return '$percentage% färdig';
  }

  /// Get progress color name
  static String getProgressColorName(RealtimeMenuData data) {
    final percentage = getCompletionPercentage(data);
    if (percentage < 0.3) return 'red';
    if (percentage < 0.7) return 'yellow';
    return 'green';
  }

  /// Get recipes that need attention (empty placeholder method)
  static List<Recipe> getRecipesNeedingAttention(RealtimeMenuData data) {
    return [];
  }

  /// Create personal copy of menu
  static Map<String, List<Recipe>> createPersonalMenuCopy(RealtimeMenuData data, String sourceDisplayName) {
    return Map.from(data.menuSnapshot);
  }
}