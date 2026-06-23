// lib/services/unified/modules/shopping_item_management_module.dart

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/shopping_category_mapper.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';

/// Shopping item management module for all item operations.
class ShoppingItemManagementModule {
  final ShoppingRepository repository;
  final List<UnifiedShoppingList> lists;
  final String? Function() getActiveListId;
  final void Function() notifyListeners;
  final ShoppingCategoryPreferencesModule Function() getCategoryPreferences;

  ShoppingItemManagementModule({
    required this.repository,
    required this.lists,
    required this.getActiveListId,
    required this.notifyListeners,
    required this.getCategoryPreferences,
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
      lists.firstWhere(
        (list) => list.id == activeListId,
        orElse: () => throw StateError('Active list not found'),
      );

      // Auto-categorize when category is empty or default
      var resolvedCategory = category ?? ShoppingCategory.other;
      if (resolvedCategory.isEmpty ||
          resolvedCategory == ShoppingCategory.other) {
        resolvedCategory = await _autoCategorize(name);
      }

      final item = UnifiedShoppingItem(
        name: name,
        amount: amount ?? 1.0,
        unit: unit.orEmpty(),
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
    List<UnifiedShoppingItem> items,
  ) async {
    final activeListId = getActiveListId();
    if (activeListId == null) {
      return false;
    }

    if (items.isEmpty) {
      return true;
    }

    try {
      final listIndex = lists.indexWhere((list) => list.id == activeListId);
      if (listIndex == -1) return false;

      final existingItems = lists[listIndex].items;
      final itemsToAdd = <UnifiedShoppingItem>[];
      final itemsToUpdate = <UnifiedShoppingItem>[];

      // Dedup: merge quantities for matching items (same name, compatible units)
      for (final newItem in items) {
        final normalizedName = newItem.name.trim().toLowerCase();
        final matchIndex = existingItems.indexWhere((existing) {
          final existingName = existing.name.trim().toLowerCase();
          if (existingName != normalizedName) return false;
          // Compatible units: same unit or both empty
          final unitsMatch =
              existing.unit.trim().toLowerCase() ==
              newItem.unit.trim().toLowerCase();
          return unitsMatch;
        });

        if (matchIndex >= 0) {
          // Merge: sum amounts into existing item
          final existing = existingItems[matchIndex];
          final merged = existing.copyWith(
            amount: existing.amount + newItem.amount,
          );
          itemsToUpdate.add(merged);
        } else {
          itemsToAdd.add(newItem);
        }
      }

      // Snapshot pre-update item values so committed merges can be rolled
      // back if a later updateItem/addItemsBatch throws. Without this, a
      // mid-loop failure leaves Firebase holding partial summed merges that
      // don't match local state — re-running the batch would double-sum.
      final preUpdateById = <String, UnifiedShoppingItem>{
        for (final existing in existingItems)
          if (itemsToUpdate.any((u) => u.id == existing.id))
            existing.id: existing,
      };

      // Apply updates for merged items, tracking which committed so we can
      // restore only those on a partial failure.
      final committedUpdates = <UnifiedShoppingItem>[];
      try {
        for (final updated in itemsToUpdate) {
          await repository.updateItem(activeListId, updated);
          committedUpdates.add(updated);
        }

        // Add genuinely new items
        if (itemsToAdd.isNotEmpty) {
          await repository.addItemsBatch(activeListId, itemsToAdd);
        }
      } catch (e) {
        // Roll back the merges that already committed to Firebase, restoring
        // their original amounts. New items added via addItemsBatch are a
        // single atomic batch op (all-or-nothing), so only updates can leak.
        for (final committed in committedUpdates) {
          final original = preUpdateById[committed.id];
          if (original == null) continue;
          try {
            await repository.updateItem(activeListId, original);
          } catch (_) {
            // Best-effort rollback; original value is logged below.
          }
        }
        AppLogger.error(
          'Failed to add batch to active list (rolled back '
          '${committedUpdates.length} committed merges): $e',
        );
        return false;
      }

      // Update local state
      final currentItems = List<UnifiedShoppingItem>.from(
        lists[listIndex].items,
      );
      for (final updated in itemsToUpdate) {
        final idx = currentItems.indexWhere((i) => i.id == updated.id);
        if (idx >= 0) currentItems[idx] = updated;
      }
      currentItems.addAll(itemsToAdd);
      lists[listIndex] = lists[listIndex].copyWith(items: currentItems);
      notifyListeners();

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

      final itemIndex = lists[listIndex].items.indexWhere(
        (item) => item.id == itemId,
      );
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

      // Atomic update in Firebase
      await repository.updateItem(activeListId, updatedItem);

      // Update local state
      final updatedItems = List<UnifiedShoppingItem>.from(
        lists[listIndex].items,
      );
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
      lists.firstWhere(
        (list) => list.id == activeListId,
        orElse: () => throw StateError('Active list not found'),
      );

      // Remove from Firebase first
      await repository.removeItem(activeListId, itemId);

      // Update local state
      final listIndex = lists.indexWhere((list) => list.id == activeListId);
      if (listIndex >= 0) {
        final updatedItems = lists[listIndex].items
            .where((item) => item.id != itemId)
            .toList();

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

    final itemIndex = lists[listIndex].items.indexWhere(
      (item) => item.id == itemId,
    );
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

    // BACKGROUND SYNC: Atomic update to Firebase
    try {
      await repository.updateItem(activeListId, updatedItem);
      return true;
    } catch (e) {
      // ROLLBACK: Revert to original state on failure
      final rollbackItems = List<UnifiedShoppingItem>.from(
        lists[listIndex].items,
      );
      final rollbackIndex = rollbackItems.indexWhere(
        (item) => item.id == itemId,
      );
      if (rollbackIndex != -1) {
        rollbackItems[rollbackIndex] = currentItem;
        lists[listIndex] = lists[listIndex].copyWith(items: rollbackItems);
        notifyListeners();
      }
      return false;
    }
  }

  /// Attempt to auto-categorize: user override → ingredient lookup → default
  Future<String> _autoCategorize(String name) async {
    // Check user's per-item category override first
    final prefs = getCategoryPreferences();
    final userOverride = prefs.getUserCategoryOverride(name);
    if (userOverride != null) return userOverride;

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
    return ShoppingCategory.other;
  }

  Future<bool> clearCompletedItems() async {
    final activeListId = getActiveListId();
    if (activeListId == null) return false;

    final listIndex = lists.indexWhere((list) => list.id == activeListId);
    if (listIndex == -1) return false;

    final boughtItems = lists[listIndex].items
        .where((item) => item.bought)
        .toList();
    if (boughtItems.isEmpty) return true;

    // Optimistic UI: remove from local state immediately
    final remainingItems = lists[listIndex].items
        .where((item) => !item.bought)
        .toList();
    lists[listIndex] = lists[listIndex].copyWith(items: remainingItems);
    notifyListeners();

    // Background: batch remove from Firebase
    try {
      final itemIds = boughtItems.map((item) => item.id).toList();
      await repository.removeItemsBatch(activeListId, itemIds);
      return true;
    } catch (e) {
      // Rollback on failure
      lists[listIndex] = lists[listIndex].copyWith(
        items: [...remainingItems, ...boughtItems],
      );
      notifyListeners();
      AppLogger.error('Failed to clear completed items: $e');
      return false;
    }
  }

  Future<bool> uncheckAllItems() async {
    final activeListId = getActiveListId();
    if (activeListId == null) return false;

    final listIndex = lists.indexWhere((list) => list.id == activeListId);
    if (listIndex == -1) return false;

    final checkedItems = lists[listIndex].items
        .where((item) => item.bought)
        .toList();
    if (checkedItems.isEmpty) return true;

    // Optimistic UI: uncheck all in local state
    final originalItems = List<UnifiedShoppingItem>.from(
      lists[listIndex].items,
    );
    final updatedItems = lists[listIndex].items.map((item) {
      return item.bought ? item.copyWith(bought: false) : item;
    }).toList();
    lists[listIndex] = lists[listIndex].copyWith(items: updatedItems);
    notifyListeners();

    // Background: update checked items in Firebase (parallel)
    try {
      await Future.wait(
        checkedItems.map(
          (item) =>
              repository.updateItem(activeListId, item.copyWith(bought: false)),
        ),
      );
      return true;
    } catch (e) {
      // Rollback on failure
      lists[listIndex] = lists[listIndex].copyWith(items: originalItems);
      notifyListeners();
      AppLogger.error('Failed to uncheck all items: $e');
      return false;
    }
  }

  Future<bool> addItemsFromRecipe({
    required String recipeId,
    required String recipeName,
    required List<dynamic> items,
  }) async {
    if (items.isEmpty) return true;

    final shoppingItems = items.map((item) {
      if (item is UnifiedShoppingItem) return item;
      return UnifiedShoppingItem(
        name: item.toString(),
        amount: 1,
      );
    }).toList();

    return addItemsBatchToActiveList(shoppingItems);
  }
}
