// lib/services/unified/modules/shopping_restore_module.dart

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/services/unified/shopping_failure_message.dart';

/// BUT-2140: "Återställ varor" — putting a row removed or changed in the last
/// 30 days back, on a personal list and a shared one alike.
///
/// The repository does the write; this module keeps the in-memory list in
/// step so a personal list shows the result at once. A shared list's snapshot
/// stream lands right after and is the authority there.
class ShoppingRestoreModule {
  final ShoppingRepository repository;
  final List<UnifiedShoppingList> lists;
  final void Function() notifyListeners;

  /// Records the sentence the shopping view shows for a failure; read back by
  /// the caller via `UnifiedShoppingService.consumeMutationError`.
  final void Function(String message) reportFailure;

  ShoppingRestoreModule({
    required this.repository,
    required this.lists,
    required this.notifyListeners,
    required this.reportFailure,
  });

  /// Puts the removed row [entry] back on [listId]. True when the list now
  /// holds the row, whether this call wrote it or it was already back.
  Future<bool> restoreRemovedRow(
    String listId,
    ShoppingRowSnapshot entry,
  ) async {
    try {
      final row = await repository.restoreRemovedRow(listId, entry);
      final list = _replace(
        listId,
        (list) => list.copyWith(
          items: row == null || list.items.any((i) => i.id == row.id)
              ? list.items
              : [...list.items, row],
          recentlyRemoved: [
            for (final s in list.recentlyRemoved)
              if (s != entry) s,
          ],
          updatedAt: list.updatedAt,
        ),
      );
      return list?.items.any((i) => i.id == entry.id) ?? row != null;
    } catch (e) {
      return _fail(listId, e, 'restore a removed row');
    }
  }

  /// Swaps row [itemId] on [listId] back to its earlier version. False when
  /// the row has nothing restorable any more.
  Future<bool> restoreChangedRow(String listId, String itemId) async {
    try {
      final row = await repository.restoreChangedRow(listId, itemId);
      if (row == null) return false;
      _replace(
        listId,
        (list) => list.copyWith(
          items: [
            for (final item in list.items) item.id == row.id ? row : item,
          ],
          updatedAt: list.updatedAt,
        ),
      );
      return true;
    } catch (e) {
      return _fail(listId, e, 'restore a changed row');
    }
  }

  /// Looked up by id after the await: a snapshot can rebuild [lists] while
  /// the write is in flight.
  UnifiedShoppingList? _replace(
    String listId,
    UnifiedShoppingList Function(UnifiedShoppingList list) change,
  ) {
    final index = lists.indexWhere((l) => l.id == listId);
    if (index < 0) return null;
    lists[index] = change(lists[index]);
    notifyListeners();
    return lists[index];
  }

  bool _fail(String listId, Object error, String action) {
    AppLogger.error('Failed to $action on shopping list $listId', error);
    final shared = lists.any((l) => l.id == listId && l.isCollaborative);
    reportFailure(shoppingFailureMessage(error, shared: shared));
    return false;
  }
}
