// BUT-1710: the manager is where a refused add/tick on a shared list becomes a
// Swedish reason. The view reads it through consumeItemOperationError, so a
// wrong or missing reason here is a checkbox that reverts without a word.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  final sv = AppLocalizationsSv();
  late MockUnifiedShoppingService shopping;
  late ShoppingItemOperationsManager manager;
  late UnifiedShoppingItem item;
  late UnifiedShoppingList list;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    shopping = MockUnifiedShoppingService();
    manager = ShoppingItemOperationsManager(shopping, 'list-1');
    item = UnifiedShoppingItem(name: 'Mjölk', amount: 1);
    list = UnifiedShoppingList(
      id: 'list-1',
      name: 'Handla',
      ownerId: 'owner',
      ownerDisplayName: 'Owner',
      items: [item],
    );
  });

  tearDown(() {
    manager.dispose();
  });

  Future<bool> toggle({
    bool canEdit = true,
    UnifiedShoppingList? on,
    bool noList = false,
  }) => manager.toggleItemCompletion(
    item.id,
    noList ? null : (on ?? list),
    canEdit,
    () async {},
    (_, _) {},
  );

  test('a tick without edit rights is refused with the permission reason and '
      'never reaches the service', () async {
    expect(await toggle(canEdit: false), isFalse);

    expect(manager.error, sv.shoppingNoEditPermissionShared);
    verifyNever(() => shopping.toggleItemBought(any()));
  });

  test('a tick with no list loaded says the list is gone', () async {
    expect(await toggle(noList: true), isFalse);

    expect(manager.error, sv.shoppingListNotFound);
    verifyNever(() => shopping.toggleItemBought(any()));
  });

  test('a tick on a row the list no longer has gets the cause-neutral '
      'sentence, not "list not found"', () async {
    final emptied = UnifiedShoppingList(
      id: 'list-1',
      name: 'Handla',
      ownerId: 'owner',
      ownerDisplayName: 'Owner',
    );

    expect(await toggle(on: emptied), isFalse);

    expect(manager.error, sv.errorCouldNotUpdateItem);
    verifyNever(() => shopping.toggleItemBought(any()));
  });

  test(
    "a refusal from the service surfaces the service's own reason",
    () async {
      when(
        () => shopping.toggleItemBought(item.id),
      ).thenAnswer((_) async => false);
      when(() => shopping.consumeMutationError()).thenReturn(sv.errorNetwork);

      expect(await toggle(), isFalse);

      expect(manager.error, sv.errorNetwork);
      expect(manager.error, isNot(sv.errorCouldNotUpdateItem));
    },
  );

  test(
    'a refusal with no parked reason falls back to the generic sentence',
    () async {
      when(
        () => shopping.toggleItemBought(item.id),
      ).thenAnswer((_) async => false);
      when(() => shopping.consumeMutationError()).thenReturn(null);

      expect(await toggle(), isFalse);

      expect(manager.error, sv.errorCouldNotUpdateItem);
    },
  );

  test('a throwing service gives the generic sentence, not silence', () async {
    when(() => shopping.toggleItemBought(item.id)).thenThrow(Exception('x'));

    expect(await toggle(), isFalse);

    expect(manager.error, sv.errorCouldNotUpdateItem);
  });

  test('a success after a refusal starts clean instead of inheriting the old '
      'reason', () async {
    expect(await toggle(canEdit: false), isFalse);
    expect(manager.hasError, isTrue);

    when(
      () => shopping.toggleItemBought(item.id),
    ).thenAnswer((_) async => true);
    expect(await toggle(), isTrue);

    expect(manager.hasError, isFalse);
  });

  test(
    'an add without edit rights is refused with the permission reason',
    () async {
      final id = await manager.addItem('Ägg', false, () async {}, (_, _) {});

      expect(id, isNull);
      expect(manager.error, sv.shoppingNoEditPermissionShared);
      verifyNever(
        () => shopping.addItemToActiveListWithId(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
        ),
      );
    },
  );

  test('an empty add is not a refusal and sets no reason', () async {
    final id = await manager.addItem('  ', false, () async {}, (_, _) {});

    expect(id, isNull);
    expect(manager.hasError, isFalse);
  });
}
