// lib/services/unified/modules/shopping_item_management_module.dart

import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/shopping_category_mapper.dart';

/// Shopping item management module for all item operations.
class ShoppingItemManagementModule {
  final ShoppingRepository repository;
  final List<UnifiedShoppingList> lists;
  final String? Function() getActiveListId;
  final void Function() notifyListeners;

  ShoppingItemManagementModule({
    required this.repository,
    required this.lists,
    required this.getActiveListId,
    required this.notifyListeners,
  });

  UnifiedShoppingList? get activeList {
    final activeListId = getActiveListId();
    if (activeListId == null) return null;
    try {
      return lists.firstWhere((list) => list.id == activeListId);
    } catch (e) {
      return null;
    }
  }

  Future<String?> addItemToList(String listId, String itemName) async {
    try {
      final item = UnifiedShoppingItem(
        name: itemName,
        amount: 1,
      );
      await repository.addItem(listId, item);

      // Update local state
      final listIndex = lists.indexWhere((list) => list.id == listId);
      if (listIndex >= 0) {
        lists[listIndex] = lists[listIndex].copyWith(
          items: [...lists[listIndex].items, item],
        );
        notifyListeners();
      }

      return item.id;
    } catch (e) {
      return null;
    }
  }

  Future<bool> addItemToActiveList({
    required String name,
    double? amount,
    String? unit,
    String? category,
    String? note,
    double? estimatedPrice,
    int? priority,
    String? recipeId,
    String? recipeName,
  }) async {
    final activeListId = getActiveListId();
    if (activeListId == null) {
      return false;
    }

    try {
      // Verify the active list exists
      lists.firstWhere((list) => list.id == activeListId,
          orElse: () => throw StateError('Active list not found'));

      // Auto-categorize when category is empty or default
      var resolvedCategory = category ?? 'Övrigt';
      if (resolvedCategory.isEmpty || resolvedCategory == 'Övrigt') {
        resolvedCategory = await _autoCategorize(name);
      }

      final item = UnifiedShoppingItem(
        name: name,
        amount: amount ?? 1.0,
        unit: unit ?? '',
        category: resolvedCategory,
        note: note,
        estimatedPrice: estimatedPrice,
        priority: priority ?? 3,
      );

      await repository.addItem(activeListId, item);

      // Update local state
      final listIndex = lists.indexWhere((list) => list.id == activeListId);
      if (listIndex >= 0) {
        lists[listIndex] = lists[listIndex].copyWith(
          items: [...lists[listIndex].items, item],
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      AppLogger.error('Failed to add item to active list: $e');
      return false;
    }
  }

  /// Add multiple items to active list using batch operations for better performance
  Future<bool> addItemsBatchToActiveList(
      List<UnifiedShoppingItem> items) async {
    final activeListId = getActiveListId();
    if (activeListId == null) {
      return false;
    }

    if (items.isEmpty) {
      return true;
    }

    try {
      // Use batch repository method for atomic Firebase operation
      await repository.addItemsBatch(activeListId, items);

      // Update local state with all items at once
      final listIndex = lists.indexWhere((list) => list.id == activeListId);
      if (listIndex >= 0) {
        lists[listIndex] = lists[listIndex].copyWith(
          items: [...lists[listIndex].items, ...items],
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update item in active shopping list with real Firebase integration
  Future<bool> updateItemInActiveList({
    required String itemId,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    String? notes,
    double? estimatedPrice,
    int? priority,
  }) async {
    final activeListId = getActiveListId();
    if (activeListId == null) {
      return false;
    }

    try {
      // Find the item in local state to get current values
      final listIndex = lists.indexWhere((list) => list.id == activeListId);
      if (listIndex == -1) {
        return false;
      }

      final itemIndex =
          lists[listIndex].items.indexWhere((item) => item.id == itemId);
      if (itemIndex == -1) {
        return false;
      }

      final currentItem = lists[listIndex].items[itemIndex];

      // Create updated item with provided values or keep existing ones
      final updatedItem = currentItem.copyWith(
        name: name ?? currentItem.name,
        amount: quantity ?? currentItem.amount,
        unit: unit ?? currentItem.unit,
        category: category ?? currentItem.category,
        note: notes ?? currentItem.note,
        estimatedPrice: estimatedPrice ?? currentItem.estimatedPrice,
        priority: priority ?? currentItem.priority,
      );

      // Update in Firebase using repository's removeItem + addItem pattern
      await repository.removeItem(activeListId, itemId);
      await repository.addItem(activeListId, updatedItem);

      // Update local state
      final updatedItems =
          List<UnifiedShoppingItem>.from(lists[listIndex].items);
      updatedItems[itemIndex] = updatedItem;

      lists[listIndex] = lists[listIndex].copyWith(items: updatedItems);
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove item from active shopping list with real Firebase integration
  Future<bool> removeItemFromActiveList(String itemId) async {
    final activeListId = getActiveListId();
    if (activeListId == null) {
      return false;
    }

    try {
      // Verify the active list exists
      lists.firstWhere((list) => list.id == activeListId,
          orElse: () => throw StateError('Active list not found'));

      // Remove from Firebase first
      await repository.removeItem(activeListId, itemId);

      // Update local state
      final listIndex = lists.indexWhere((list) => list.id == activeListId);
      if (listIndex >= 0) {
        final updatedItems =
            lists[listIndex].items.where((item) => item.id != itemId).toList();

        lists[listIndex] = lists[listIndex].copyWith(items: updatedItems);

        notifyListeners();
      }

      return true;
    } catch (e) {
      AppLogger.error('Failed to remove item from active list: $e');
      return false;
    }
  }

  /// Toggle item bought status in active shopping list with optimistic updates
  ///
  /// Applies the state change immediately for instant UI feedback,
  /// then syncs to Firebase in background. Rolls back on failure.
  Future<bool> toggleItemBought(String itemId) async {
    final activeListId = getActiveListId();
    if (activeListId == null) {
      return false;
    }

    // Find the item in local state
    final listIndex = lists.indexWhere((list) => list.id == activeListId);
    if (listIndex == -1) {
      return false;
    }

    final itemIndex =
        lists[listIndex].items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) {
      return false;
    }

    final currentItem = lists[listIndex].items[itemIndex];
    final updatedItem = currentItem.copyWith(bought: !currentItem.bought);

    // OPTIMISTIC UPDATE: Apply state change immediately for instant UI feedback
    final updatedItems = List<UnifiedShoppingItem>.from(lists[listIndex].items);
    updatedItems[itemIndex] = updatedItem;
    lists[listIndex] = lists[listIndex].copyWith(items: updatedItems);
    notifyListeners();

    // BACKGROUND SYNC: Update Firebase asynchronously
    try {
      await repository.removeItem(activeListId, itemId);
      await repository.addItem(activeListId, updatedItem);
      return true;
    } catch (e) {
      // ROLLBACK: Revert to original state on failure
      final rollbackItems =
          List<UnifiedShoppingItem>.from(lists[listIndex].items);
      final rollbackIndex =
          rollbackItems.indexWhere((item) => item.id == itemId);
      if (rollbackIndex != -1) {
        rollbackItems[rollbackIndex] = currentItem;
        lists[listIndex] = lists[listIndex].copyWith(items: rollbackItems);
        notifyListeners();
      }
      return false;
    }
  }

  /// Attempt to auto-categorize an item name via IngredientLookupService.
  Future<String> _autoCategorize(String name) async {
    try {
      final lookupService = ServiceLocator.get<IngredientLookupService>();
      final result = await lookupService.lookupFromRaw([name]);
      if (result.matched.isNotEmpty) {
        return ShoppingCategoryMapper.categoryFromIngredientGroup(
          result.matched.first.group,
        );
      }
    } catch (_) {
      // Silently fall back to default
    }
    return 'Övrigt';
  }

  Future<bool> clearCompletedItems() async => true;
  Future<bool> uncheckAllItems() async => true;
  Future<bool> addItemsFromRecipe({
    required String recipeId,
    required String recipeName,
    required List<dynamic> items,
  }) async =>
      true;
}
