import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart';

/// Handles collaborative shopping list item operations (add, remove, toggle).
class ListItemOperations {
  final UnifiedShoppingService _parent;
  final ListLifecycleOperations _lifecycleOps;

  ListItemOperations(this._parent, this._lifecycleOps);

  Future<bool> addItem({
    required String listId,
    required String name,
    required double amount,
    String unit = '',
    String category = ShoppingCategory.other,
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) async {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot add item: Collaborative list not found');
      return false;
    }

    if (!canEdit(listId)) {
      AppLogger.error('Cannot add item: No edit permission');
      return false;
    }

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName;
    if (currentUserId == null || currentUserDisplayName == null) {
      AppLogger.error('Cannot add item: User information incomplete');
      return false;
    }

    try {
      final item = UnifiedShoppingItem.collaborative(
        name: name.trim(),
        amount: amount,
        unit: unit,
        category: category,
        addedByUserId: currentUserId,
        addedByDisplayName: currentUserDisplayName,
        note: note?.trim(),
        estimatedPrice: estimatedPrice,
        priority: priority,
      );

      final updatedList = list.addItem(
        item,
        userId: _parent.currentUserId,
        userDisplayName: _parent.currentUserDisplayName,
      );

      await _parent.updateList(updatedList);

      AppLogger.success('Added item "$name" to ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to add item to collaborative list', e);
      return false;
    }
  }

  Future<bool> toggleItemBought({
    required String listId,
    required String itemId,
  }) async {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot toggle item: Collaborative list not found');
      return false;
    }

    if (!canEdit(listId)) {
      AppLogger.error('Cannot toggle item: No edit permission');
      return false;
    }

    try {
      final updatedList = list.toggleItemBought(
        itemId,
        userId: _parent.currentUserId,
        userDisplayName: _parent.currentUserDisplayName,
      );

      await _parent.updateList(updatedList);

      AppLogger.success('Toggled item status in ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to toggle item in collaborative list', e);
      return false;
    }
  }

  Future<bool> removeItem({
    required String listId,
    required String itemId,
  }) async {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot remove item: Collaborative list not found');
      return false;
    }

    if (!canEdit(listId)) {
      AppLogger.error('Cannot remove item: No edit permission');
      return false;
    }

    try {
      final updatedList = list.removeItem(
        itemId,
        userId: _parent.currentUserId,
        userDisplayName: _parent.currentUserDisplayName,
      );

      await _parent.updateList(updatedList);

      AppLogger.success('Removed item from ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to remove item from collaborative list', e);
      return false;
    }
  }

  bool canEdit(String listId) {
    return ServiceLocator.get<PermissionService>().canEditShoppingList(listId);
  }
}
