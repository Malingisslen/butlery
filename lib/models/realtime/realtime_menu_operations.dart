// lib/models/realtime/realtime_menu_operations.dart

import '../recipe_unified.dart';
import 'realtime_menu_data.dart';

/// Business logic operations for realtime menu data
/// 
/// This class contains ONLY:
/// - Menu content operations (add, remove, move, replace recipes)
/// - Basic statistics and analysis
/// - Validation logic
/// 
/// ❌ DOES NOT CONTAIN: Data representation, serialization, search/filtering, UI concerns
class RealtimeMenuOperations {
  // ===== MENU CONTENT OPERATIONS =====

  /// Add recipe to specific category
  static RealtimeMenuData addRecipeToCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required Recipe recipe,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(data.menuSnapshot);

    // Initialize category if it doesn't exist
    if (!updatedMenu.containsKey(categoryName)) {
      updatedMenu[categoryName] = [];
    }

    // Add recipe to the category
    updatedMenu[categoryName] = [...updatedMenu[categoryName]!, recipe];

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Remove recipe from specific category
  static RealtimeMenuData removeRecipeFromCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required int recipeIndex,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(data.menuSnapshot);

    if (!updatedMenu.containsKey(categoryName) ||
        recipeIndex < 0 ||
        recipeIndex >= updatedMenu[categoryName]!.length) {
      throw ArgumentError(
          'Invalid recipe index for category $categoryName: $recipeIndex');
    }

    // Remove recipe from the category
    final updatedCategoryRecipes =
        List<Recipe>.from(updatedMenu[categoryName]!);
    updatedCategoryRecipes.removeAt(recipeIndex);
    updatedMenu[categoryName] = updatedCategoryRecipes;

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Move recipe between categories
  static RealtimeMenuData moveRecipeBetweenCategories(
    RealtimeMenuData data, {
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(data.menuSnapshot);

    // Validate from-category
    if (!updatedMenu.containsKey(fromCategory) ||
        fromIndex < 0 ||
        fromIndex >= updatedMenu[fromCategory]!.length) {
      throw ArgumentError(
          'Invalid from-index for category $fromCategory: $fromIndex');
    }

    // Initialize to-category if it doesn't exist
    if (!updatedMenu.containsKey(toCategory)) {
      updatedMenu[toCategory] = [];
    }

    // Get the recipe to be moved
    final recipe = updatedMenu[fromCategory]![fromIndex];

    // Remove from original category
    final updatedFromCategory = List<Recipe>.from(updatedMenu[fromCategory]!);
    updatedFromCategory.removeAt(fromIndex);
    updatedMenu[fromCategory] = updatedFromCategory;

    // Add to new category
    final updatedToCategory = List<Recipe>.from(updatedMenu[toCategory]!);
    final insertIndex = toIndex ?? updatedToCategory.length;
    updatedToCategory.insert(
        insertIndex.clamp(0, updatedToCategory.length), recipe);
    updatedMenu[toCategory] = updatedToCategory;

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Replace recipe in specific category and position
  static RealtimeMenuData replaceRecipeInCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required int recipeIndex,
    required Recipe newRecipe,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(data.menuSnapshot);

    if (!updatedMenu.containsKey(categoryName) ||
        recipeIndex < 0 ||
        recipeIndex >= updatedMenu[categoryName]!.length) {
      throw ArgumentError(
          'Invalid recipe index for category $categoryName: $recipeIndex');
    }

    // Replace the recipe
    final updatedCategoryRecipes =
        List<Recipe>.from(updatedMenu[categoryName]!);
    updatedCategoryRecipes[recipeIndex] = newRecipe;
    updatedMenu[categoryName] = updatedCategoryRecipes;

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Clear entire category (remove all recipes)
  static RealtimeMenuData clearCategory(
    RealtimeMenuData data, {
    required String categoryName,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(data.menuSnapshot);
    updatedMenu[categoryName] = [];

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Update entire category with new recipes
  static RealtimeMenuData updateWholeCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required List<Recipe> recipes,
  }) {
    final updatedMenu = Map<String, List<Recipe>>.from(data.menuSnapshot);
    updatedMenu[categoryName] = List<Recipe>.from(recipes);

    return data.copyWith(menuSnapshot: updatedMenu);
  }

  /// Regenerate specific category (for AI generation)
  static RealtimeMenuData regenerateCategory(
    RealtimeMenuData data, {
    required String categoryName,
    required List<Recipe> newRecipes,
  }) {
    return updateWholeCategory(
      data,
      categoryName: categoryName,
      recipes: newRecipes,
    );
  }

  // ===== BASIC STATISTICS =====

  /// Common menu categories (can be extended)
  static const List<String> commonCategories = [
    'Middag',
    'Lunch',
    'Frukost',
    'Mellanmål',
    'Dessert',
    'Bakningar',
  ];

  /// Get categories sorted in logical order
  static List<String> getCategoriesSorted(RealtimeMenuData data) {
    final sorted = List<String>.from(data.categories);
    sorted.sort((a, b) {
      // Prioritize common categories in order
      final aIndex = commonCategories.indexOf(a);
      final bIndex = commonCategories.indexOf(b);

      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      } else if (aIndex != -1) {
        return -1;
      } else if (bIndex != -1) {
        return 1;
      } else {
        return a.compareTo(b);
      }
    });
    return sorted;
  }

  /// Total number of recipes in entire menu
  static int getTotalRecipeCount(RealtimeMenuData data) {
    return data.menuSnapshot.values
        .fold(0, (total, categoryRecipes) => total + categoryRecipes.length);
  }

  /// Number of categories that have recipes
  static int getCategoriesWithRecipes(RealtimeMenuData data) {
    return data.menuSnapshot.values
        .where((categoryRecipes) => categoryRecipes.isNotEmpty)
        .length;
  }

  /// Number of empty categories
  static int getEmptyCategoriesCount(RealtimeMenuData data) {
    return data.menuSnapshot.values
        .where((categoryRecipes) => categoryRecipes.isEmpty)
        .length;
  }

  /// Is menu complete? (has recipes in at least 2 categories)
  static bool isComplete(RealtimeMenuData data) {
    return getCategoriesWithRecipes(data) >= 2;
  }

  /// Is menu well balanced? (has recipes in at least 3 categories)
  static bool isWellBalanced(RealtimeMenuData data) {
    return getCategoriesWithRecipes(data) >= 3;
  }

  /// Get average number of recipes per category
  static double getAverageRecipesPerCategory(RealtimeMenuData data) {
    if (data.categories.isEmpty) return 0.0;
    return getTotalRecipeCount(data) / data.categories.length;
  }

  /// Check if menu has favorites defined
  static bool hasFavorites(RealtimeMenuData data) {
    return data.favoriteRecipeIds?.isNotEmpty == true;
  }

  /// Number of favorite recipes
  static int getFavoritesCount(RealtimeMenuData data) {
    return data.favoriteRecipeIds?.length ?? 0;
  }

  /// Check if menu has notes
  static bool hasNotes(RealtimeMenuData data) {
    return data.menuNotes?.isNotEmpty == true;
  }

  /// Check if menu was generated from prompt
  static bool wasGenerated(RealtimeMenuData data) {
    return data.originalPrompt?.isNotEmpty == true;
  }

  // ===== MENU SUMMARIES =====

  /// Menu summary for UI (compatible with existing SharedMenu)
  static String getMenuSummary(RealtimeMenuData data) {
    final totalRecipes = getTotalRecipeCount(data);
    if (totalRecipes == 0) {
      return 'Tom meny';
    }

    final parts = <String>[];
    for (final entry in data.menuSnapshot.entries) {
      final categoryName = entry.key;
      final count = entry.value.length;
      if (count > 0) {
        parts.add('$count $categoryName');
      }
    }
    return parts.join(', ');
  }

  /// Detailed menu summary with statistics
  static String getDetailedMenuSummary(RealtimeMenuData data) {
    final totalRecipes = getTotalRecipeCount(data);
    if (totalRecipes == 0) {
      return 'Tom meny - inga recept tillagda än';
    }

    final parts = <String>[];
    parts.add('$totalRecipes recept');
    parts.add('${getCategoriesWithRecipes(data)} kategorier');

    if (isWellBalanced(data)) {
      parts.add('väl balanserad');
    } else if (isComplete(data)) {
      parts.add('komplett');
    } else {
      parts.add('pågående');
    }

    return parts.join(' • ');
  }

  // ===== CATEGORY ANALYSIS =====

  /// Get meal type distribution
  static Map<String, int> getMealTypeDistribution(RealtimeMenuData data) {
    final distribution = <String, int>{};

    for (final recipes in data.menuSnapshot.values) {
      for (final recipe in recipes) {
        distribution[recipe.mealType] =
            (distribution[recipe.mealType] ?? 0) + 1;
      }
    }

    return distribution;
  }

  /// Get most active category (with most recipes)
  static String? getMostActiveCategory(RealtimeMenuData data) {
    if (data.menuSnapshot.isEmpty) return null;

    String? maxCategory;
    int maxCount = 0;

    for (final entry in data.menuSnapshot.entries) {
      if (entry.value.length > maxCount) {
        maxCount = entry.value.length;
        maxCategory = entry.key;
      }
    }

    return maxCategory;
  }

  /// Get least active category (with fewest recipes, but not empty)
  static String? getLeastActiveCategory(RealtimeMenuData data) {
    if (data.menuSnapshot.isEmpty) return null;

    String? minCategory;
    int minCount = double.maxFinite.toInt();

    for (final entry in data.menuSnapshot.entries) {
      if (entry.value.isNotEmpty && entry.value.length < minCount) {
        minCount = entry.value.length;
        minCategory = entry.key;
      }
    }

    return minCategory;
  }

  // ===== COMPLETION ANALYSIS =====

  /// Get menu completion percentage (for progress indicators)
  static double getCompletionPercentage(RealtimeMenuData data) {
    if (commonCategories.isEmpty) return 0.0;

    int completedCategories = 0;
    for (final category in commonCategories) {
      if (data.categoryHasRecipes(category)) {
        completedCategories++;
      }
    }

    return completedCategories / commonCategories.length;
  }

  /// Get completion status text
  static String getCompletionStatus(RealtimeMenuData data) {
    final completionPercentage = getCompletionPercentage(data);
    if (completionPercentage >= 1.0) {
      return 'Komplett meny';
    } else if (completionPercentage >= 0.8) {
      return 'Nästan klar';
    } else if (completionPercentage >= 0.5) {
      return 'Halvfärdig';
    } else if (completionPercentage >= 0.2) {
      return 'Påbörjad';
    } else {
      return 'Tom meny';
    }
  }

  /// Get progress color name (for UI widgets to use with AppTheme)
  static String getProgressColorName(RealtimeMenuData data) {
    final completionPercentage = getCompletionPercentage(data);
    if (completionPercentage >= 0.8) {
      return 'success';
    } else if (completionPercentage >= 0.5) {
      return 'primary';
    } else if (completionPercentage >= 0.2) {
      return 'warning';
    } else {
      return 'error';
    }
  }

  // ===== VALIDATION =====

  /// Validate recipe index for category
  static bool isValidRecipeIndex(
    RealtimeMenuData data,
    String categoryName,
    int index,
  ) {
    if (!data.menuSnapshot.containsKey(categoryName)) return false;
    final recipes = data.menuSnapshot[categoryName]!;
    return index >= 0 && index < recipes.length;
  }

  /// Validate category name
  static bool isValidCategoryName(String categoryName) {
    return categoryName.isNotEmpty && categoryName.trim().isNotEmpty;
  }

  /// Get recipes that need attention (incomplete)
  static List<Recipe> getRecipesNeedingAttention(RealtimeMenuData data) {
    final needingAttention = <Recipe>[];

    for (final recipes in data.menuSnapshot.values) {
      for (final recipe in recipes) {
        if (recipe.title.isEmpty ||
            recipe.ingredients.isEmpty ||
            recipe.instructions.isEmpty) {
          needingAttention.add(recipe);
        }
      }
    }

    return needingAttention;
  }

  // ===== UTILITIES =====

  /// Create a personal copy of the menu (compatible with MenuViewModel)
  static Map<String, List<Recipe>> createPersonalMenuCopy(
    RealtimeMenuData data,
    String sourceDisplayName,
  ) {
    final personalMenu = <String, List<Recipe>>{};

    for (final entry in data.menuSnapshot.entries) {
      final categoryName = entry.key;
      final recipes = entry.value;

      // Create copies of recipes with new attribution
      final personalRecipes = recipes
          .map((recipe) => recipe.copyWith(
                sourceUrl: 'Delad meny från $sourceDisplayName',
                lastCookedAt: null,
              ))
          .toList();

      personalMenu[categoryName] = personalRecipes;
    }

    return personalMenu;
  }

  /// Merge two menu snapshots (for collaborative editing)
  static Map<String, List<Recipe>> mergeMenuSnapshots(
    Map<String, List<Recipe>> base,
    Map<String, List<Recipe>> incoming,
  ) {
    final merged = Map<String, List<Recipe>>.from(base);

    for (final entry in incoming.entries) {
      final categoryName = entry.key;
      final incomingRecipes = entry.value;

      if (merged.containsKey(categoryName)) {
        // Merge recipes, avoiding duplicates based on ID
        final baseRecipes = merged[categoryName]!;
        final baseIds = baseRecipes.map((r) => r.id).toSet();
        
        final uniqueIncomingRecipes = incomingRecipes
            .where((recipe) => !baseIds.contains(recipe.id))
            .toList();
            
        merged[categoryName] = [...baseRecipes, ...uniqueIncomingRecipes];
      } else {
        merged[categoryName] = List<Recipe>.from(incomingRecipes);
      }
    }

    return merged;
  }
}