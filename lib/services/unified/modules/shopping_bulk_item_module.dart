// lib/services/unified/modules/shopping_bulk_item_module.dart

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/core/utils/logger.dart';

/// Bulk actions over the active shopping list: "rensa klara" and
/// "avmarkera alla".
///
/// Split out of `ShoppingItemManagementModule` to keep that module a focused
/// per-item facade under the 500-line limit. Both methods share one shape —
/// mutate local state optimistically, write once, roll the local state back and
/// REPORT A REASON if the write fails — and the reporting seams are passed in
/// so the failure wording stays owned by the parent module.
class ShoppingBulkItemModule {
  final ShoppingRepository repository;
  final List<UnifiedShoppingList> lists;
  final String? Function() getActiveListId;
  final void Function() notifyListeners;

  /// Maps a caught error to the user-facing reason. Supplied by the parent so
  /// there is exactly one mapping (see `shoppingFailureMessage`).
  final void Function(Object error) report;

  /// Records "the list is gone" and returns false, in one call.
  final bool Function() failListMissing;

  ShoppingBulkItemModule({
    required this.repository,
    required this.lists,
    required this.getActiveListId,
    required this.notifyListeners,
    required this.report,
    required this.failListMissing,
  });

  /// Re-finds [listId] in [lists] AFTER an await.
  ///
  /// An index captured before the network call cannot be trusted afterwards:
  /// `UnifiedShoppingService`'s collaborative snapshot handler rebuilds the very
  /// `_lists` instance this module holds (`removeWhere(isCollaborative)` then
  /// `addAll`), so a shared list arriving, leaving or being touched by another
  /// member during the await reorders it. Rolling back through a stale index
  /// writes one list's rows into another — silent cross-list corruption that the
  /// next mutation then persists — or throws RangeError if the list shrank.
  int? _reindex(String listId) {
    final index = lists.indexWhere((list) => list.id == listId);
    if (index >= 0) return index;
    // The list itself is gone: nothing to roll back to, and the snapshot that
    // removed it is the authority.
    AppLogger.warning(
      'Shopping list $listId disappeared during a bulk write — skipping the '
          'local rollback; the snapshot stream is the authority now',
      'ShoppingBulkItemModule',
    );
    return null;
  }

  Future<bool> clearCompletedItems() async {
    final activeListId = getActiveListId();
    if (activeListId == null) return failListMissing();

    final listIndex = lists.indexWhere((list) => list.id == activeListId);
    if (listIndex == -1) return failListMissing();

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
      // Rollback on failure. BUT-1696: this is a DESTRUCTIVE bulk action, so a
      // silent rollback is the worst version of the defect the ticket exists to
      // remove — the rows come back and the caller says "Rensat". Report the
      // reason with the same three-way mapping as the checkbox and the bulk
      // uncheck; the caller shows it instead of the success message.
      final rollbackIndex = _reindex(activeListId);
      if (rollbackIndex != null) {
        lists[rollbackIndex] = lists[rollbackIndex].copyWith(
          items: [...remainingItems, ...boughtItems],
        );
      }
      report(e);
      notifyListeners();
      AppLogger.error('Failed to clear completed items: $e');
      return false;
    }
  }

  Future<bool> uncheckAllItems() async {
    final activeListId = getActiveListId();
    if (activeListId == null) return failListMissing();

    final listIndex = lists.indexWhere((list) => list.id == activeListId);
    if (listIndex == -1) return failListMissing();

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

    // Background: one write for the whole set.
    //
    // BUT-1697: this used to be `Future.wait` over N `updateItem` calls. Since
    // BUT-1665 each of those is a Firestore transaction on the SAME document,
    // so unchecking a 30-item list fired 30 transactions at one doc: they
    // contend, exhaust the plugin's retry budget, and leave the list half
    // unchecked after the rollback. `updateItemsBatch` applies all the
    // unchecks inside a single transaction instead.
    try {
      await repository.updateItemsBatch(
        activeListId,
        checkedItems.map((item) => item.copyWith(bought: false)).toList(),
      );
      return true;
    } catch (e) {
      // Rollback on failure, through a FRESH index — see [_reindex].
      final rollbackIndex = _reindex(activeListId);
      if (rollbackIndex != null) {
        lists[rollbackIndex] = lists[rollbackIndex].copyWith(
          items: originalItems,
        );
      }
      report(e);
      notifyListeners();
      AppLogger.error('Failed to uncheck all items: $e');
      return false;
    }
  }
}
