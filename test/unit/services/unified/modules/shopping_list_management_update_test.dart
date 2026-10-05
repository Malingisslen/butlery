/// A personal list keeps its items in the `items` subcollection, which is
/// what the next launch reads. `updateList` is how the menu writes its rows,
/// so it has to reach that subcollection: before, a menu merge showed for the
/// rest of the session and was gone after the next login.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/modules/shopping_list_management_module.dart';

import '../../../../infrastructure/mocks/production_mocks.dart';

UnifiedShoppingItem _item(String id) =>
    UnifiedShoppingItem(id: id, name: id, amount: 1, unit: '');

UnifiedShoppingList _list(
  List<UnifiedShoppingItem> items, {
  ListType type = ListType.personal,
}) => UnifiedShoppingList(
  id: 'list-1',
  name: 'Inköpslista v.41',
  ownerId: 'me',
  ownerDisplayName: 'Me',
  type: type,
  items: items,
);

void main() {
  late MockShoppingRepository repository;
  late List<UnifiedShoppingList> lists;

  setUpAll(() {
    registerFallbackValue(_list(const []));
    registerFallbackValue(<UnifiedShoppingItem>[]);
  });

  ShoppingListManagementModule build() => ShoppingListManagementModule(
    repository: repository,
    lists: lists,
    getActiveListId: () => 'list-1',
    setActiveListId: (_) {},
    notifyListeners: () {},
    getCurrentUserId: () => 'me',
    getCurrentUserDisplayName: () => 'Me',
    saveActiveListId: () async {},
  );

  setUp(() {
    repository = MockShoppingRepository();
    when(
      () => repository.update(any()),
    ).thenAnswer((i) async => i.positionalArguments[0] as UnifiedShoppingList);
    when(
      () => repository.addItemsBatch(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => repository.removeItemsBatch(any(), any()),
    ).thenAnswer((_) async {});
  });

  test('a personal list writes new rows and drops removed ones', () async {
    final kept = _item('kept');
    final dropped = _item('dropped');
    lists = [
      _list([kept, dropped]),
    ];
    final added = _item('added');

    final ok = await build().updateList(_list([kept, added]));

    expect(ok, isTrue);
    final written =
        verify(
              () => repository.addItemsBatch('list-1', captureAny()),
            ).captured.single
            as List<UnifiedShoppingItem>;
    expect(written.map((i) => i.id), ['added']);
    verify(() => repository.removeItemsBatch('list-1', ['dropped'])).called(1);
  });

  test('a collaborative list keeps its items inline only', () async {
    lists = [
      _list([_item('a')], type: ListType.collaborative),
    ];

    await build().updateList(
      _list([_item('a'), _item('b')], type: ListType.collaborative),
    );

    verifyNever(() => repository.addItemsBatch(any(), any()));
    verifyNever(() => repository.removeItemsBatch(any(), any()));
  });
}
