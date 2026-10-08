/// A personal list keeps its items in the `items` subcollection, which is
/// what the next launch reads.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
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

  test('BUT-2140: a menu merge replaces the local copy with the server-based '
      'result, so the other device\'s rows show at once', () async {
    lists = [
      _list([_item('own')]),
    ];
    final merged = _list([_item('own'), _item('theirs'), _item('ours')]);
    final request = PersonalMergeRequest(
      rows: (_) => [_item('ours')],
      replace: false,
    );
    when(() => repository.applyPersonalMerge(any(), request)).thenAnswer(
      (_) async => PersonalMergeResult(
        list: merged,
        added: [_item('ours')],
        removed: const [],
        concurrentChange: true,
      ),
    );

    final result = await build().applyPersonalMerge('list-1', request);

    expect(result.concurrentChange, isTrue);
    expect(lists.single.items.map((i) => i.id), ['own', 'theirs', 'ours']);
    final base =
        verify(
              () => repository.applyPersonalMerge(captureAny(), request),
            ).captured.single
            as UnifiedShoppingList;
    expect(base.items.map((i) => i.id), ['own'], reason: 'the memory copy');
  });
}
