/// Store → list → default precedence and the store bookkeeping around it.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/list_category_order.dart';
import 'package:butlery/models/shopping_store.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';

class _FakeRepo implements CategoryPreferencesRepository {
  CategoryPreferences? saved;
  final Map<String, ListCategoryOrder> listOrders = {};

  @override
  Future<CategoryPreferences?> getPreferences() async => saved;

  @override
  Future<void> savePreferences(CategoryPreferences preferences) async {
    saved = preferences;
  }

  @override
  Future<ListCategoryOrder?> getListCategoryOrder(String listId) async =>
      listOrders[listId];

  @override
  Future<void> saveListCategoryOrder(ListCategoryOrder order) async {
    listOrders[order.listId] = order;
  }

  @override
  Future<void> deleteListCategoryOrder(String listId) async {
    listOrders.remove(listId);
  }

  @override
  Future<void> recordGlobalOverride(String itemName, String category) async {}
}

void main() {
  late _FakeRepo repo;
  late ShoppingCategoryPreferencesModule module;

  setUp(() async {
    repo = _FakeRepo();
    module = ShoppingCategoryPreferencesModule(repository: repo);
    await module.load();
  });

  test('with no store the order is the default', () {
    expect(
      module.getEffectiveCategoryOrder('list1'),
      ShoppingCategory.defaultStoreOrder,
    );
  });

  test('a store with an order beats the list order', () async {
    await module.saveListCategoryOrder('list1', ['dairy']);
    final store = (await module.addStore('ICA Maxi'))!;
    await module.saveStoreCategoryOrder(store.id, ['meat', 'dairy']);
    await module.setActiveStore('list1', store.id);

    expect(module.getEffectiveCategoryOrder('list1'), ['meat', 'dairy']);
    expect(
      module.getEffectiveCategoryOrder('list2'),
      ShoppingCategory.defaultStoreOrder,
    );
  });

  test(
    'a store with no order of its own falls back to the list order',
    () async {
      await module.saveListCategoryOrder('list1', ['dairy']);
      final store = (await module.addStore('Willys'))!;
      await module.setActiveStore('list1', store.id);

      expect(module.getEffectiveCategoryOrder('list1'), ['dairy']);
    },
  );

  test('choosing no store goes back to the list order', () async {
    final store = (await module.addStore('Coop'))!;
    await module.saveStoreCategoryOrder(store.id, ['meat']);
    await module.setActiveStore('list1', store.id);
    await module.setActiveStore('list1', null);

    expect(module.activeStoreFor('list1'), isNull);
    expect(
      module.getEffectiveCategoryOrder('list1'),
      ShoppingCategory.defaultStoreOrder,
    );
  });

  test('a blank name adds nothing and a long one is cut', () async {
    expect(await module.addStore('   '), isNull);
    final long = await module.addStore('x' * 100);
    expect(long!.name.length, ShoppingStore.maxNameLength);
  });

  test('the store limit is enforced', () async {
    for (var i = 0; i < ShoppingStore.maxStores; i++) {
      expect(await module.addStore('Butik $i'), isNotNull);
    }
    expect(await module.addStore('En till'), isNull);
    expect(module.stores.length, ShoppingStore.maxStores);
  });

  test('deleting the active store clears it from the list', () async {
    final store = (await module.addStore('ICA'))!;
    await module.setActiveStore('list1', store.id);
    await module.deleteStore(store.id);

    expect(module.stores, isEmpty);
    expect(module.activeStoreFor('list1'), isNull);
    expect(repo.saved!.activeStoreByList['list1'], '');
  });

  test('stores survive a reload from the saved document', () async {
    final store = (await module.addStore('ICA'))!;
    await module.saveStoreCategoryOrder(store.id, ['meat']);
    await module.setActiveStore('list1', store.id);

    final reloaded = ShoppingCategoryPreferencesModule(repository: repo);
    await reloaded.load();
    expect(reloaded.getEffectiveCategoryOrder('list1'), ['meat']);
  });

  test('deleting a store leaves other lists on their own store', () async {
    final a = (await module.addStore('ICA'))!;
    final b = (await module.addStore('Willys'))!;
    await module.setActiveStore('list1', a.id);
    await module.setActiveStore('list2', b.id);
    await module.deleteStore(a.id);

    expect(module.activeStoreFor('list1'), isNull);
    expect(module.activeStoreFor('list2')?.id, b.id);
  });

  test('a store name is trimmed', () async {
    expect((await module.addStore('  ICA  '))!.name, 'ICA');
  });
}
