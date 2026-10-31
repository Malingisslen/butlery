// lib/repositories/firebase/modules/personal_merge_plan.dart

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart'
    show PersonalMergeRequest, PersonalMergeResult, PersonalMergeWrite;

/// The pure half of a personal list sync
/// (`ShoppingPersonalMergeModule`): what a request writes to a list's rows,
/// computed without reading or writing anything.
abstract final class PersonalMergePlan {
  /// The sync of [list]'s rows: the rows `menuItemIds` names that exist, what
  /// [request] writes to them, and whether that leaves the list as it is.
  static ({
    List<UnifiedShoppingItem> current,
    PersonalMergeWrite write,
    bool changesNothing,
  })
  of(UnifiedShoppingList list, PersonalMergeRequest request) {
    final menuIds = (list.menuItemIds ?? const <String>[]).toSet();
    // In `menuItemIds` order, the order the transaction reads them in: the
    // sync is order-sensitive when two of its rows share a key.
    final byId = {for (final item in list.items) item.id: item};
    final current = [for (final id in menuIds) ?byId[id]];
    final write = within(request.sync(current), current);
    return (
      current: current,
      write: write,
      changesNothing:
          write.isEmpty &&
          current.length == menuIds.length &&
          list.generatedForWeek == request.generatedForWeek,
    );
  }

  static PersonalMergeResult unchanged(
    UnifiedShoppingList list, {
    required bool concurrentChange,
  }) => PersonalMergeResult(
    list: list,
    added: const [],
    removed: const [],
    concurrentChange: concurrentChange,
  );

  /// [write] with only the overwrites and removals of rows in [current], so
  /// a sync can never change a row the user typed by hand.
  static PersonalMergeWrite within(
    PersonalMergeWrite write,
    List<UnifiedShoppingItem> current,
  ) {
    final known = {for (final item in current) item.id};
    return PersonalMergeWrite(
      add: write.add.where((i) => !known.contains(i.id)).toList(),
      update: write.update.where((i) => known.contains(i.id)).toList(),
      remove: write.remove.where((i) => known.contains(i.id)).toList(),
    );
  }

  /// [list] with [write] applied to its rows, in their order.
  static UnifiedShoppingList applied(
    UnifiedShoppingList list,
    PersonalMergeWrite write,
  ) {
    final removed = {for (final item in write.remove) item.id};
    final updated = {for (final item in write.update) item.id: item};
    return list.copyWith(
      items: [
        for (final item in list.items)
          if (!removed.contains(item.id)) updated[item.id] ?? item,
        ...write.add,
      ],
    );
  }

  /// The rows of [current] that [updated] overwrites, as they were.
  static List<UnifiedShoppingItem> before(
    List<UnifiedShoppingItem> current,
    List<UnifiedShoppingItem> updated,
  ) {
    final ids = {for (final item in updated) item.id};
    return List.unmodifiable(current.where((i) => ids.contains(i.id)));
  }
}
