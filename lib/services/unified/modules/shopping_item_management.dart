// lib/services/unified/modules/shopping_item_management.dart

import 'dart:async';
import 'package:collection/collection.dart';
import '../../../models/unified/unified_shopping_list.dart';
import '../../../models/unified/unified_shopping_item.dart';
import '../../../core/utils/logger.dart';
import '../operations/personal_shopping_operations.dart';

/// Handles shopping item management operations
class ShoppingItemManagement {
  final List<UnifiedShoppingList> _lists;
  final String? Function() _getActiveListId;
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final void Function(String) _setError;
  final Future<bool> Function(UnifiedShoppingList) _updateListInternal;
  final PersonalShoppingOperations _personalOps;

  ShoppingItemManagement({
    required List<UnifiedShoppingList> lists,
    required String? Function() getActiveListId,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required Future<bool> Function(UnifiedShoppingList) updateListInternal,
    required PersonalShoppingOperations personalOps,
  }) : _lists = lists,
       _getActiveListId = getActiveListId,
       _getCurrentUserId = getCurrentUserId,
       _getCurrentUserDisplayName = getCurrentUserDisplayName,
       _setError = setError,
       _updateListInternal = updateListInternal,
       _personalOps = personalOps;

  UnifiedShoppingList? get activeList => _getActiveListId() != null
      ? _lists.where((list) => list.id == _getActiveListId()!).firstOrNull
      : (_lists.isNotEmpty ? _lists.first : null);

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
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    if (name.trim().isEmpty) {
      _setError('Artikelnamn kan inte vara tomt');
      return false;
    }

    try {
      final item = recipeId != null
          ? UnifiedShoppingItem.collaborative(
              name: name.trim(),
              amount: amount ?? 1.0,
              unit: unit ?? '',
              category: category ?? 'Övrigt',
              addedByUserId: _getCurrentUserId() ?? '',
              addedByDisplayName: _getCurrentUserDisplayName() ?? '',
              note: note,
              estimatedPrice: estimatedPrice,
              priority: priority ?? 3,
            )
          : UnifiedShoppingItem.basic(
              name: name.trim(),
              amount: amount ?? 1.0,
              unit: unit ?? '',
              category: category ?? 'Övrigt',
            );

      final updatedList = activeList!.addItem(
        item,
        userId: _getCurrentUserId(),
        userDisplayName: _getCurrentUserDisplayName(),
      );

      return await _updateListInternal(updatedList);
    } catch (e) {
      AppLogger.error('❌ Kunde inte lägga till artikel: $e');
      _setError('Kunde inte lägga till artikel: $e');
      return false;
    }
  }

  Future<bool> toggleItemBought(String itemId) async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      final updatedList = activeList!.toggleItemBought(
        itemId,
        userId: _getCurrentUserId(),
        userDisplayName: _getCurrentUserDisplayName(),
      );

      return await _updateListInternal(updatedList);
    } catch (e) {
      AppLogger.error('❌ Kunde inte ändra artikel-status: $e');
      _setError('Kunde inte ändra status: $e');
      return false;
    }
  }

  Future<bool> removeItemFromActiveList(String itemId) async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      final updatedList = activeList!.removeItem(
        itemId,
        userId: _getCurrentUserId(),
        userDisplayName: _getCurrentUserDisplayName(),
      );

      return await _updateListInternal(updatedList);
    } catch (e) {
      AppLogger.error('❌ Kunde inte ta bort artikel: $e');
      _setError('Kunde inte ta bort artikel: $e');
      return false;
    }
  }

  /// Update an item in the active list
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
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      if (activeList!.isPersonal) {
        // Use personal operations for personal lists
        return await _personalOps.updateItem(
          listId: activeList!.id,
          itemId: itemId,
          name: name,
          amount: quantity,
          unit: unit,
          category: category,
          note: notes,
          estimatedPrice: estimatedPrice,
          priority: priority,
        );
      } else {
        // For collaborative lists, we need to implement the method
        // For now, use the fallback approach of remove and add
        final item = activeList!.items.where((i) => i.id == itemId).firstOrNull;
        if (item == null) {
          _setError('Artikel hittades inte');
          return false;
        }

        // Create updated item
        final updatedItem = item.copyWith(
          name: name ?? item.name,
          amount: quantity ?? item.amount,
          unit: unit ?? item.unit,
          category: category ?? item.category,
          note: notes ?? item.note,
          estimatedPrice: estimatedPrice ?? item.estimatedPrice,
          priority: priority ?? item.priority,
        );

        // Remove old item and add updated item
        var updatedList = activeList!.removeItem(
          itemId,
          userId: _getCurrentUserId(),
          userDisplayName: _getCurrentUserDisplayName(),
        );

        updatedList = updatedList.addItem(
          updatedItem,
          userId: _getCurrentUserId(),
          userDisplayName: _getCurrentUserDisplayName(),
        );

        return await _updateListInternal(updatedList);
      }
    } catch (e) {
      AppLogger.error('❌ Kunde inte uppdatera artikel: $e');
      _setError('Kunde inte uppdatera artikel: $e');
      return false;
    }
  }

  Future<bool> clearCompletedItems() async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      final updatedItems = activeList!.items.where((item) => !item.isCompleted).toList();
      final updatedList = activeList!.copyWith(items: updatedItems);

      final result = await _updateListInternal(updatedList);
      if (result) {
        AppLogger.success('✅ Färdiga artiklar rensade');
      }
      return result;
    } catch (e) {
      AppLogger.error('❌ Kunde inte rensa färdiga artiklar: $e');
      _setError('Kunde inte rensa artiklar: $e');
      return false;
    }
  }

  Future<bool> uncheckAllItems() async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      final updatedItems = activeList!.items.map((item) => 
        item.copyWith(bought: false)
      ).toList();
      final updatedList = activeList!.copyWith(items: updatedItems);

      final result = await _updateListInternal(updatedList);
      if (result) {
        AppLogger.success('✅ Alla artiklar avbockade');
      }
      return result;
    } catch (e) {
      AppLogger.error('❌ Kunde inte avbocka artiklar: $e');
      _setError('Kunde inte avbocka artiklar: $e');
      return false;
    }
  }

  Future<bool> addItemsFromRecipe({
    required String recipeId,
    required String recipeName,
    required List<UnifiedShoppingItem> items,
  }) async {
    if (activeList == null) {
      _setError('Ingen aktiv lista');
      return false;
    }

    try {
      var updatedList = activeList!;
      
      for (final item in items) {
        final recipeItem = item.copyWith(
          note: item.note != null ? '${item.note} (från $recipeName)' : 'från $recipeName',
        );
        
        updatedList = updatedList.addItem(
          recipeItem,
          userId: _getCurrentUserId(),
          userDisplayName: _getCurrentUserDisplayName(),
        );
      }

      final result = await _updateListInternal(updatedList);
      if (result) {
        AppLogger.success('✅ ${items.length} artiklar från "$recipeName" tillagda');
      }
      return result;
    } catch (e) {
      AppLogger.error('❌ Kunde inte lägga till artiklar från recept: $e');
      _setError('Kunde inte lägga till artiklar från recept: $e');
      return false;
    }
  }
}