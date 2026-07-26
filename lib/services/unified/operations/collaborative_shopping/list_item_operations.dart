import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart';

/// Handles collaborative shopping list item operations (add, remove, toggle).
///
/// BUT-1665: every mutation here is a SINGLE-item change to a list two people
/// may be holding open at once. The cached list is used only for the existence
/// and permission checks; the actual edit is applied to the live document
/// inside a Firestore transaction ([_mutateSharedList]), so one member ticking
/// "mjölk" no longer erases the other member's tick on "bröd".
class ListItemOperations {
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final Future<bool> Function(
    String listId,
    UnifiedShoppingList Function(UnifiedShoppingList live) mutate,
  )
  _mutateSharedList;
  final ListLifecycleOperations _lifecycleOps;

  ListItemOperations({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required Future<bool> Function(
      String listId,
      UnifiedShoppingList Function(UnifiedShoppingList live) mutate,
    )
    mutateSharedList,
    required ListLifecycleOperations lifecycleOps,
  }) : _getCurrentUserId = getCurrentUserId,
       _getCurrentUserDisplayName = getCurrentUserDisplayName,
       _mutateSharedList = mutateSharedList,
       _lifecycleOps = lifecycleOps;

  /// Existence + edit-permission preflight shared by every item mutation.
  ///
  /// Returns the CACHED list, which is all the cached copy is good for here
  /// (its name for the success log, and telling "no such list" apart from "no
  /// permission") — the edit itself is applied to the live document inside the
  /// transaction. Returns null when the caller must bail; [action] only shapes
  /// the log line.
  UnifiedShoppingList? _preflight(String listId, String action) {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot $action item: Collaborative list not found');
      return null;
    }

    if (!canEdit(listId)) {
      AppLogger.error('Cannot $action item: No edit permission');
      return null;
    }

    return list;
  }

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
    final list = _preflight(listId, 'add');
    if (list == null) return false;

    final currentUserId = _getCurrentUserId();
    final currentUserDisplayName = _getCurrentUserDisplayName();
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

      final applied = await _mutateSharedList(
        listId,
        (live) => live.addItem(
          item,
          userId: currentUserId,
          userDisplayName: currentUserDisplayName,
        ),
      );
      if (!applied) return false;

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
    final list = _preflight(listId, 'toggle');
    if (list == null) return false;

    try {
      final applied = await _mutateSharedList(listId, (live) {
        // The item may have been removed by another member between the cached
        // read and the transaction; toggling a gone item is a no-op, not an
        // error, so return the live list untouched.
        if (!live.items.any((item) => item.id == itemId)) return live;
        return live.toggleItemBought(
          itemId,
          userId: _getCurrentUserId(),
          userDisplayName: _getCurrentUserDisplayName(),
        );
      });
      if (!applied) return false;

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
    final list = _preflight(listId, 'remove');
    if (list == null) return false;

    try {
      final applied = await _mutateSharedList(
        listId,
        (live) => live.removeItem(
          itemId,
          userId: _getCurrentUserId(),
          userDisplayName: _getCurrentUserDisplayName(),
        ),
      );
      if (!applied) return false;

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
