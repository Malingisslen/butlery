/// BUT-2140: the service half of "Återställ varor" keeps the in-memory list in
/// step with what the repository wrote, and turns a failure into the sentence
/// the shopping view shows.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/unified/shopping_row_snapshot.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/services/unified/modules/shopping_restore_module.dart';

class _MockRepository extends Mock implements ShoppingRepository {}

final _entry = ShoppingRowSnapshot(
  id: 'mjölk',
  name: 'mjölk',
  amount: 1,
  unit: 'l',
  category: ShoppingCategory.other,
  at: DateTime.utc(2026, 10, 7),
);

UnifiedShoppingList _list({
  List<UnifiedShoppingItem> items = const [],
  ListType type = ListType.personal,
}) => UnifiedShoppingList(
  id: 'L',
  name: 'Lista',
  ownerId: 'alice',
  ownerDisplayName: 'Alice',
  items: items,
  type: type,
  recentlyRemoved: [_entry],
);

void main() {
  late _MockRepository repository;
  late List<UnifiedShoppingList> lists;
  late List<String> reported;
  late int notified;

  setUpAll(() => registerFallbackValue(_entry));

  setUp(() {
    repository = _MockRepository();
    lists = [];
    reported = [];
    notified = 0;
  });

  ShoppingRestoreModule build() => ShoppingRestoreModule(
    repository: repository,
    lists: lists,
    notifyListeners: () => notified++,
    reportFailure: reported.add,
  );

  test('a restored row is shown and its entry leaves the history', () async {
    lists.add(_list());
    when(
      () => repository.restoreRemovedRow('L', _entry),
    ).thenAnswer((_) async => _entry.toItem());

    final ok = await build().restoreRemovedRow('L', _entry);

    expect(ok, isTrue);
    expect(lists.single.items.map((i) => i.id), ['mjölk']);
    expect(lists.single.recentlyRemoved, isEmpty);
    expect(notified, 1);
  });

  test('a row already back counts as restored and is not doubled', () async {
    lists.add(_list(items: [_entry.toItem()]));
    when(
      () => repository.restoreRemovedRow('L', _entry),
    ).thenAnswer((_) async => null);

    final ok = await build().restoreRemovedRow('L', _entry);

    expect(ok, isTrue);
    expect(lists.single.items, hasLength(1));
    expect(lists.single.recentlyRemoved, isEmpty);
  });

  test('a changed row is replaced by what the repository wrote', () async {
    final current = UnifiedShoppingItem(id: 'ägg', name: 'ägg', amount: 6);
    lists.add(_list(items: [current]));
    when(
      () => repository.restoreChangedRow('L', 'ägg'),
    ).thenAnswer((_) async => current.copyWith(amount: 12));

    final ok = await build().restoreChangedRow('L', 'ägg');

    expect(ok, isTrue);
    expect(lists.single.items.single.amount, 12);
  });

  test('nothing restorable is a false without a message', () async {
    lists.add(_list());
    when(
      () => repository.restoreChangedRow('L', 'ägg'),
    ).thenAnswer((_) async => null);

    expect(await build().restoreChangedRow('L', 'ägg'), isFalse);
    expect(reported, isEmpty);
  });

  test('a refusal is reported and the history stays', () async {
    lists.add(_list(type: ListType.collaborative));
    when(
      () => repository.restoreRemovedRow('L', any()),
    ).thenThrow(PermissionDeniedException('view only'));

    final ok = await build().restoreRemovedRow('L', _entry);

    expect(ok, isFalse);
    expect(reported, hasLength(1));
    expect(lists.single.recentlyRemoved, [_entry]);
  });
}
