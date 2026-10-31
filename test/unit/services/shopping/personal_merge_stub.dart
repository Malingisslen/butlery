/// BUT-2140: answers [UnifiedShoppingService.applyPersonalMerge] and
/// [UnifiedShoppingService.undoPersonalMerge] on a mock, in memory, the way
/// the repository answers when no other device has written to the list. What
/// the repository does when one has is pinned in
/// test/unit/repositories/firebase/modules/shopping_personal_merge_module_test.dart.
library;

import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

void registerPersonalMergeFallbacks() {
  registerFallbackValue(
    PersonalMergeRequest(sync: (_) => const PersonalMergeWrite()),
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

  // Unloaded, so no row is moved to a category of the user's.
  when(() => shopping.categoryPreferences).thenReturn(
    ShoppingCategoryPreferencesModule(
      repository: _Prefs(CategoryPreferences()),
    ),
  );

  when(() => shopping.applyPersonalMerge(any(), any())).thenAnswer((
    invocation,
  ) async {
    final listId = invocation.positionalArguments[0] as String;
    final request = invocation.positionalArguments[1] as PersonalMergeRequest;
    final list = shopping.lists.firstWhere((l) => l.id == listId);
    final menuIds = (list.menuItemIds ?? const <String>[]).toSet();
    final write = request.sync(
      list.items.where((i) => menuIds.contains(i.id)).toList(),
    );
    final gone = {for (final i in write.remove) i.id};
    final updated = {for (final i in write.update) i.id: i};
    final before = {for (final i in list.items) i.id: i};
    final next = list.copyWith(
      items: [
        for (final i in list.items)
          if (!gone.contains(i.id)) updated[i.id] ?? i,
        ...write.add,
      ],
      menuItemIds: [
        ...menuIds.where((id) => !gone.contains(id)),
        for (final i in write.add) i.id,
      ],
      generatedForWeek: request.generatedForWeek,
    );
    store(next);
    return PersonalMergeResult(
      list: next,
      added: write.add,
      updated: write.update,
      changedFrom: [
        for (final i in write.update)
          if (before[i.id] != null) before[i.id]!,
      ],
      removed: write.remove,
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

/// The user has moved each name in [overrides] to its category.
Future<void> stubCategoryOverrides(
  MockUnifiedShoppingService shopping,
  Map<String, String> overrides,
) async {
  final module = ShoppingCategoryPreferencesModule(
    repository: _Prefs(
      CategoryPreferences(
        itemCategoryOverrides: {
          for (final e in overrides.entries)
            CategoryPreferences.normalizeItemName(e.key): e.value,
        },
      ),
    ),
  );
  await module.load();
  when(() => shopping.categoryPreferences).thenReturn(module);
}

class _Prefs extends Fake implements CategoryPreferencesRepository {
  _Prefs(this.prefs);

  final CategoryPreferences prefs;

  @override
  Future<CategoryPreferences?> getPreferences() async => prefs;
}
