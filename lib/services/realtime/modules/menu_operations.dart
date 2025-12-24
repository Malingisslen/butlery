// lib/services/realtime/modules/menu_operations.dart

import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Menu operation types for analytics and logging
enum MenuOperationType {
  createFromExisting,
  updateBasicInfo,
  addRecipeToCategory,
  removeRecipeFromCategory,
  moveRecipeBetweenCategories,
  replaceRecipeInCategory,
  clearCategory,
  updateWholeCategory,
  regenerateCategory,
  addParticipant,
  removeParticipant,
  updatePermissions,
}

/// Menu-specific error handling
class MenuOperationError {
  final MenuOperationType operation;
  final String message;
  final String? resourceId;
  final String? categoryName;
  final dynamic originalError;

  MenuOperationError({
    required this.operation,
    required this.message,
    this.resourceId,
    this.categoryName,
    this.originalError,
  });

  @override
  String toString() => 'MenuOperationError(${operation.name}): $message';
}

/// Focused module for menu content operations
/// This module handles ONLY menu content manipulation:
/// - Basic menu information updates
/// - Recipe CRUD operations within categories
/// - Category management operations
/// - Recipe movement between categories
/// ❌ DOES NOT CONTAIN: Participant management, state management, synchronization
class MenuOperations {
  // ===== BASIC MENU OPERATIONS =====

  /// Update basic menu information
  static RealtimeMenu updateBasicInfo(
    RealtimeMenu menu, {
    String? menuTitle,
    DateTime? createdForDate,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    AppLogger.info('📝 Updating basic info for menu: ${menu.menuTitle}');

    return menu.updateBasicInfo(
      menuTitle: menuTitle,
      createdForDate: createdForDate,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  // ===== RECIPE OPERATIONS =====

  /// Add recipe to specific category
  static RealtimeMenu addRecipeToCategory(
    RealtimeMenu menu, {
    required String categoryName,
    required Recipe recipe,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (!isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.addRecipeToCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: menu.id,
        categoryName: categoryName,
      );
    }

    AppLogger.info(
        '➕ Adding recipe "${recipe.title}" to category: $categoryName');

    return menu.addRecipeToCategory(
      categoryName: categoryName,
      recipe: recipe,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Remove recipe from specific category
  static RealtimeMenu removeRecipeFromCategory(
    RealtimeMenu menu, {
    required String categoryName,
    required int recipeIndex,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (!isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.removeRecipeFromCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: menu.id,
        categoryName: categoryName,
      );
    }

    AppLogger.info(
        '➖ Removing recipe at index $recipeIndex from category: $categoryName');

    return menu.removeRecipeFromCategory(
      categoryName: categoryName,
      recipeIndex: recipeIndex,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Move recipe between categories
  static RealtimeMenu moveRecipeBetweenCategories(
    RealtimeMenu menu, {
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (!isValidCategoryName(fromCategory) ||
        !isValidCategoryName(toCategory)) {
      throw MenuOperationError(
        operation: MenuOperationType.moveRecipeBetweenCategories,
        message: 'Ogiltiga kategorinamn: $fromCategory -> $toCategory',
        resourceId: menu.id,
      );
    }

    AppLogger.info(
        '🔄 Moving recipe from $fromCategory[$fromIndex] to $toCategory${toIndex != null ? '[$toIndex]' : ''}');

    return menu.moveRecipeBetweenCategories(
      fromCategory: fromCategory,
      fromIndex: fromIndex,
      toCategory: toCategory,
      toIndex: toIndex,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Replace recipe in specific category and position
  static RealtimeMenu replaceRecipeInCategory(
    RealtimeMenu menu, {
    required String categoryName,
    required int recipeIndex,
    required Recipe newRecipe,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (!isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.replaceRecipeInCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: menu.id,
        categoryName: categoryName,
      );
    }

    AppLogger.info(
        '🔄 Replacing recipe at index $recipeIndex in category: $categoryName');

    return menu.replaceRecipeInCategory(
      categoryName: categoryName,
      recipeIndex: recipeIndex,
      newRecipe: newRecipe,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  // ===== CATEGORY OPERATIONS =====

  /// Clear entire category
  static RealtimeMenu clearCategory(
    RealtimeMenu menu, {
    required String categoryName,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (!isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.clearCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: menu.id,
        categoryName: categoryName,
      );
    }

    AppLogger.info('🧹 Clearing category: $categoryName');

    return menu.clearCategory(
      categoryName: categoryName,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Update entire category with new recipes
  static RealtimeMenu updateWholeCategory(
    RealtimeMenu menu, {
    required String categoryName,
    required List<Recipe> recipes,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (!isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.updateWholeCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: menu.id,
        categoryName: categoryName,
      );
    }

    AppLogger.info(
        '📋 Updating entire category $categoryName with ${recipes.length} recipes');

    return menu.updateWholeCategory(
      categoryName: categoryName,
      recipes: recipes,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  /// Regenerate category with new AI-generated recipes
  static RealtimeMenu regenerateCategory(
    RealtimeMenu menu, {
    required String categoryName,
    required List<Recipe> newRecipes,
    required String editedBy,
    required String editedByDisplayName,
  }) {
    if (!isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.regenerateCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: menu.id,
        categoryName: categoryName,
      );
    }

    AppLogger.info(
        '🔄 Regenerating category $categoryName with ${newRecipes.length} new recipes');

    return menu.regenerateCategory(
      categoryName: categoryName,
      newRecipes: newRecipes,
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
    );
  }

  // ===== VALIDATION UTILITIES =====

  /// Validate category name
  static bool isValidCategoryName(String categoryName) {
    // Accept all non-empty categories (flexible system)
    return categoryName.trim().isNotEmpty;
  }

  /// Get category names from menu
  static List<String> getCategoryNames(RealtimeMenu menu) {
    return menu.categories;
  }

  /// Check if category exists in menu
  static bool categoryExists(RealtimeMenu menu, String categoryName) {
    return menu.categories.contains(categoryName);
  }

  /// Get recipe count in category
  static int getRecipeCountInCategory(RealtimeMenu menu, String categoryName) {
    final recipes = menu.menuSnapshot[categoryName];
    return recipes?.length ?? 0;
  }

  /// Get total recipe count across all categories
  static int getTotalRecipeCount(RealtimeMenu menu) {
    return menu.menuSnapshot.values
        .map((recipes) => recipes.length)
        .fold(0, (sum, count) => sum + count);
  }

  // ===== MENU UTILITIES =====

  /// Create personal copy of realtime menu
  static Map<String, List<Recipe>> createPersonalCopy(RealtimeMenu menu) {
    AppLogger.info('📋 Creating personal copy of: ${menu.menuTitle}');
    return menu.createPersonalMenuCopy();
  }

  /// Check if menu has changed since timestamp
  static bool hasMenuChangedSince(RealtimeMenu menu, DateTime timestamp) {
    return menu.hasChangedSince(timestamp);
  }

  /// Get summary of recent changes
  static String getMenuChangesSummary(RealtimeMenu menu) {
    return menu.getChangesSummary();
  }

  /// Get menu statistics
  static Map<String, dynamic> getMenuStatistics(RealtimeMenu menu) {
    final stats = <String, dynamic>{
      'totalCategories': menu.categories.length,
      'totalRecipes': getTotalRecipeCount(menu),
      'categoriesWithRecipes': menu.categories
          .where((cat) => getRecipeCountInCategory(menu, cat) > 0)
          .length,
      'averageRecipesPerCategory': menu.categories.isNotEmpty
          ? (getTotalRecipeCount(menu) / menu.categories.length).round()
          : 0,
    };

    // Add per-category breakdown
    final categoryBreakdown = <String, int>{};
    for (final category in menu.categories) {
      categoryBreakdown[category] = getRecipeCountInCategory(menu, category);
    }
    stats['categoryBreakdown'] = categoryBreakdown;

    return stats;
  }

  /// Validate menu state
  static List<String> validateMenuState(RealtimeMenu menu) {
    final errors = <String>[];

    // Check basic requirements
    if (menu.menuTitle.trim().isEmpty) {
      errors.add('Menu title is empty');
    }

    if (menu.categories.isEmpty) {
      errors.add('Menu has no categories');
    }

    // Check each category
    for (final category in menu.categories) {
      if (!isValidCategoryName(category)) {
        errors.add('Invalid category name: $category');
      }

      final recipes = menu.menuSnapshot[category];
      if (recipes == null) {
        errors.add('Category $category has no recipe list');
      }
    }

    return errors;
  }
}
