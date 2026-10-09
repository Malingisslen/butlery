/// Shopping item operations manager for search and grouping.
/// Handles item search and category grouping.
/// Part of UnifiedShoppingViewModel's modular architecture.

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/shopping_category_mapper.dart';

/// Shopping item operations manager for search and grouping.
class ShoppingItemOperationsManager {
  /// Group items by category with sorting
  Map<String, List<UnifiedShoppingItem>> groupItemsByCategory(
    List<UnifiedShoppingItem> items,
  ) {
    final Map<String, List<UnifiedShoppingItem>> grouped = {};

    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    // Sort categories and items
    final sortedGrouped = <String, List<UnifiedShoppingItem>>{};
    final sortedKeys = grouped.keys.toList()..sort();

    for (final key in sortedKeys) {
      final sortedItems = grouped[key]!;
      sortedItems.sort((a, b) {
        // Unbought first, then alphabetically
        if (a.bought != b.bought) {
          return a.bought ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });
      sortedGrouped[key] = sortedItems;
    }

    return sortedGrouped;
  }

  /// Get all used categories (sorted)
  List<String> getUsedCategories(List<UnifiedShoppingItem> items) {
    final categories = items.map((item) => item.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// Search items by name or category
  List<UnifiedShoppingItem> searchItems(
    List<UnifiedShoppingItem> items,
    String query,
  ) {
    if (query.trim().isEmpty) return items;

    final lowercaseQuery = query.toLowerCase();
    return items
        .where(
          (item) =>
              item.name.toLowerCase().contains(lowercaseQuery) ||
              item.category.toLowerCase().contains(lowercaseQuery),
        )
        .toList();
  }

  /// Map an ingredient group path to a shopping category.
  /// Delegates to shared utility to avoid service→viewmodel dependency.
  static String categoryFromIngredientGroup(String group) =>
      ShoppingCategoryMapper.categoryFromIngredientGroup(group);
}
