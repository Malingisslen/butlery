/// BUT-2140: answers [UnifiedShoppingService.applyPersonalMerge] and
/// [UnifiedShoppingService.undoPersonalMerge] on a mock, in memory, the way
/// the repository answers when no other device has written to the list. What
/// the repository does when one has is pinned in
/// test/unit/repositories/firebase/modules/shopping_personal_merge_module_test.dart.
library;

import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

void registerPersonalMergeFallbacks() {
  registerFallbackValue(
    PersonalMergeRequest(rows: (_) => const [], replace: false),
  );
  registerFallbackValue(<UnifiedShoppingItem>[]);
  registerFallbackValue(<String>[]);
}

/// Every list the merge writes is appended to [writes], and the mock's lists
/// are updated, as the service updates its own.
void stubPersonalMerge(
  MockUnifiedShoppingService shopping,
  List<UnifiedShoppingList> writes,
) {
  void store(UnifiedShoppingList next) {
    writes.add(next);
    List<UnifiedShoppingList> swap(List<UnifiedShoppingList> lists) => [
      for (final l in lists) l.id == next.id ? next : l,
    ];
    shopping.setShoppingState(
      lists: swap(shopping.lists),
      personalLists: swap(shopping.personalLists),
    );
  }

  when(() => shopping.applyPersonalMerge(any(), any())).thenAnswer((
    invocation,
  ) async {
    final listId = invocation.positionalArguments[0] as String;
    final request = invocation.positionalArguments[1] as PersonalMergeRequest;
    final list = shopping.lists.firstWhere((l) => l.id == listId);
    final menuIds = (list.menuItemIds ?? const <String>[]).toSet();
    final removed = request.replace
        ? list.items.where((i) => menuIds.contains(i.id)).toList()
        : <UnifiedShoppingItem>[];
    final added = request.rows(removed);
    final gone = {for (final i in removed) i.id};
    final next = list.copyWith(
      items: [...list.items.where((i) => !gone.contains(i.id)), ...added],
      menuItemIds: [
        if (!request.replace) ...menuIds,
        for (final i in added) i.id,
      ],
      generatedForWeek: request.generatedForWeek,
    );
    store(next);
    return PersonalMergeResult(
      list: next,
      added: added,
      removed: removed,
      concurrentChange: false,
    );
  });

  when(() => shopping.undoPersonalMerge(any(), any(), any())).thenAnswer((
    invocation,
  ) async {
    final listId = invocation.positionalArguments[0] as String;
    final added = (invocation.positionalArguments[1] as List<String>).toSet();
    final restore =
        invocation.positionalArguments[2] as List<UnifiedShoppingItem>;
    final restored = {for (final i in restore) i.id};
    final list = shopping.lists.firstWhere((l) => l.id == listId);
    store(
      list.copyWith(
        items: [
          ...list.items.where(
            (i) => !added.contains(i.id) && !restored.contains(i.id),
          ),
          ...restore,
        ],
        menuItemIds: [
          ...?list.menuItemIds?.where(
            (id) => !added.contains(id) && !restored.contains(id),
          ),
          ...restored,
        ],
      ),
    );
  });
}
