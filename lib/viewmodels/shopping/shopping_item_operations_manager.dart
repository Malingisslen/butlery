/// Shopping item operations manager for search, grouping, and bulk operations.
/// Handles item search, category grouping, and bulk operations like recipe imports.
/// Part of UnifiedShoppingViewModel's modular architecture.

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/shopping_category_mapper.dart';

/// Shopping item operations manager for search, grouping, and bulk operations.
class ShoppingItemOperationsManager {
  /// Group items by category with sorting
  Map<String, List<UnifiedShoppingItem>> groupItemsByCategory(
      List<UnifiedShoppingItem> items) {
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
      List<UnifiedShoppingItem> items, String query) {
    if (query.trim().isEmpty) return items;

    final lowercaseQuery = query.toLowerCase();
    return items
        .where((item) =>
            item.name.toLowerCase().contains(lowercaseQuery) ||
            item.category.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Map an ingredient group path to a shopping category.
  /// Delegates to shared utility to avoid service→viewmodel dependency.
  static String categoryFromIngredientGroup(String group) =>
      ShoppingCategoryMapper.categoryFromIngredientGroup(group);

  /// Bulk add items from recipe ingredients, merging duplicates by name.
  Future<bool> addItemsFromRecipe(
    List<Map<String, dynamic>> ingredientData,
    Future<bool> Function({
      required String name,
      required double amount,
      required String unit,
      required String category,
    }) addItemCallback, {
    List<dynamic>? existingItems,
    Future<bool> Function({
      required String itemId,
      required double newAmount,
    })? updateItemCallback,
  }) async {
    for (final ingredient in ingredientData) {
      final name = ingredient['name'] as String;
      final amount = (ingredient['amount'] as num).toDouble();
      final unit = ingredient['unit'] as String? ?? '';
      final category =
          ingredient['category'] as String? ?? ShoppingCategory.other;

      // Check for existing item with same name (case-insensitive)
      if (existingItems != null && updateItemCallback != null) {
        final normalizedName = name.trim().toLowerCase();
        final existing = existingItems.cast<dynamic>().where((item) {
          final itemName = (item.name as String?)?.trim().toLowerCase() ?? '';
          return itemName == normalizedName;
        }).toList();

        if (existing.isNotEmpty) {
          final existingItem = existing.first;
          await updateItemCallback(
            itemId: existingItem.id as String,
            newAmount: (existingItem.amount as num).toDouble() + amount,
          );
          continue;
        }
      }

      await addItemCallback(
        name: name,
        amount: amount,
        unit: unit,
        category: category,
      );
    }
    return true;
  }
}
