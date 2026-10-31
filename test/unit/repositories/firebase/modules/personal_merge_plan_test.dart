/// BUT-2140: the pure half of a personal list sync. What a menu merge may write
/// into a list's rows, and whether that leaves the list as it is, decided
/// without a database.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/personal_merge_plan.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';

const _weekKey = '2026-W24';

UnifiedShoppingItem _row(String id, String name, {int amount = 1}) =>
    UnifiedShoppingItem(
      id: id,
      name: name,
      amount: amount.toDouble(),
      unit: 'st',
    );

UnifiedShoppingList _list(
  List<UnifiedShoppingItem> items, {
  List<String>? menuItemIds,
  String? generatedForWeek = _weekKey,
}) => UnifiedShoppingList(
  id: 'week-list',
  name: 'Inköpslista v.24',
  ownerId: 'u',
  ownerDisplayName: 'Test',
  items: items,
  generatedForWeek: generatedForWeek,
  menuItemIds: menuItemIds,
);

PersonalMergeRequest _request(
  PersonalMergeWrite Function(List<UnifiedShoppingItem> rows) sync, {
  String? week = _weekKey,
}) => PersonalMergeRequest(generatedForWeek: week, sync: sync);

void main() {
  group('PersonalMergePlan.of', () {
    final own = _row('own', 'kaffe');
    final menu = _row('menu', 'gul lök');

    test('hands the sync only the rows menuItemIds names', () {
      List<UnifiedShoppingItem>? seen;

      final plan = PersonalMergePlan.of(
        _list([own, menu], menuItemIds: ['menu']),
        _request((rows) {
          seen = rows;
          return const PersonalMergeWrite();
        }),
      );

      expect(seen!.map((i) => i.id), ['menu']);
      expect(plan.current.map((i) => i.id), ['menu']);
    });

    test('hands the sync the rows in menuItemIds order, whatever order the '
        'list holds them in', () {
      // The server read returns rows by document id, the transaction reads
      // them by menuItemIds; the sync is order-sensitive, so both must agree.
      final a = _row('a', 'mjölk');
      final b = _row('b', 'mjölk');
      List<UnifiedShoppingItem>? seen;

      PersonalMergePlan.of(
        _list([a, b], menuItemIds: ['b', 'a']),
        _request((rows) {
          seen = rows;
          return const PersonalMergeWrite();
        }),
      );

      expect(seen!.map((i) => i.id), ['b', 'a']);
    });

    test('changes nothing: an empty write, every named row present, same '
        'week', () {
      final plan = PersonalMergePlan.of(
        _list([own, menu], menuItemIds: ['menu']),
        _request((_) => const PersonalMergeWrite()),
      );

      expect(plan.changesNothing, isTrue);
      expect(plan.write.isEmpty, isTrue);
    });

    test('changes nothing when the only asks concern rows outside the menu '
        'rows', () {
      final plan = PersonalMergePlan.of(
        _list([own, menu], menuItemIds: ['menu']),
        _request(
          (_) => PersonalMergeWrite(
            update: [own.copyWith(amount: 9)],
            remove: [own],
          ),
        ),
      );

      expect(plan.changesNothing, isTrue);
    });

    test('an added row changes something', () {
      final plan = PersonalMergePlan.of(
        _list([own, menu], menuItemIds: ['menu']),
        _request((_) => PersonalMergeWrite(add: [_row('new', 'mjölk')])),
      );

      expect(plan.changesNothing, isFalse);
      expect(plan.write.add.single.id, 'new');
    });

    test('an updated menu row changes something', () {
      final plan = PersonalMergePlan.of(
        _list([own, menu], menuItemIds: ['menu']),
        _request((_) => PersonalMergeWrite(update: [menu.copyWith(amount: 3)])),
      );

      expect(plan.changesNothing, isFalse);
      expect(plan.write.update.single.amount, 3);
    });

    test('a removed menu row changes something', () {
      final plan = PersonalMergePlan.of(
        _list([own, menu], menuItemIds: ['menu']),
        _request((rows) => PersonalMergeWrite(remove: rows)),
      );

      expect(plan.changesNothing, isFalse);
      expect(plan.write.remove.single.id, 'menu');
    });

    test('a different week changes something even with an empty write', () {
      final plan = PersonalMergePlan.of(
        _list([own, menu], menuItemIds: ['menu']),
        _request((_) => const PersonalMergeWrite(), week: '2026-W25'),
      );

      expect(plan.write.isEmpty, isTrue);
      expect(plan.changesNothing, isFalse);
    });

    test('a list with no week yet differs from a request that names one', () {
      final plan = PersonalMergePlan.of(
        _list([menu], menuItemIds: ['menu'], generatedForWeek: null),
        _request((_) => const PersonalMergeWrite()),
      );

      expect(plan.changesNothing, isFalse);
    });

    test('a menuItemIds id with no row changes something: the dead id has '
        'to be dropped', () {
      final plan = PersonalMergePlan.of(
        _list([own, menu], menuItemIds: ['menu', 'gone']),
        _request((_) => const PersonalMergeWrite()),
      );

      expect(plan.current.map((i) => i.id), ['menu']);
      expect(plan.changesNothing, isFalse);
    });

    test('a list with no menuItemIds and a matching week changes nothing', () {
      final plan = PersonalMergePlan.of(
        _list([own]),
        _request((_) => const PersonalMergeWrite()),
      );

      expect(plan.current, isEmpty);
      expect(plan.changesNothing, isTrue);
    });
  });

  group('PersonalMergePlan.within', () {
    final known = _row('known', 'kaffe');

    test('drops updates and removals of rows outside the current rows', () {
      final write = PersonalMergePlan.within(
        PersonalMergeWrite(
          update: [known, _row('typed', 'te')],
          remove: [known, _row('typed', 'te')],
        ),
        [known],
      );

      expect(write.update.map((i) => i.id), ['known']);
      expect(write.remove.map((i) => i.id), ['known']);
    });

    test('drops an add whose id already exists and keeps a fresh one', () {
      final write = PersonalMergePlan.within(
        PersonalMergeWrite(add: [_row('known', 'kaffe'), _row('fresh', 'te')]),
        [known],
      );

      expect(write.add.map((i) => i.id), ['fresh']);
    });
  });

  group('PersonalMergePlan.applied', () {
    test('removes, overwrites in place and appends adds, keeping the order '
        'of the rest', () {
      final list = _list([
        _row('a', 'kaffe'),
        _row('b', 'te'),
        _row('c', 'mjölk'),
      ]);

      final result = PersonalMergePlan.applied(
        list,
        PersonalMergeWrite(
          remove: [_row('b', 'te')],
          update: [_row('c', 'mjölk', amount: 4)],
          add: [_row('d', 'ost')],
        ),
      );

      expect(result.items.map((i) => i.id), ['a', 'c', 'd']);
      expect(result.items[1].amount, 4);
      expect(result.items[0].amount, 1);
    });

    test('an empty write leaves the rows as they were', () {
      final list = _list([_row('a', 'kaffe'), _row('b', 'te')]);

      final result = PersonalMergePlan.applied(
        list,
        const PersonalMergeWrite(),
      );

      expect(result.items.map((i) => i.id), ['a', 'b']);
    });
  });

  group('PersonalMergePlan.before', () {
    test('returns the rows an update overwrites, as they were', () {
      final current = [
        _row('a', 'kaffe'),
        _row('b', 'te'),
        _row('c', 'mjölk'),
      ];

      final result = PersonalMergePlan.before(current, [
        _row('c', 'mjölk', amount: 7),
        _row('a', 'kaffe', amount: 5),
      ]);

      expect(result.map((i) => i.id), ['a', 'c']);
      expect(result.map((i) => i.amount), [1, 1]);
    });

    test('is empty when no update names a current row', () {
      final result = PersonalMergePlan.before(
        [_row('a', 'kaffe')],
        [_row('zzz', 'x')],
      );

      expect(result, isEmpty);
    });
  });

  group('PersonalMergePlan.unchanged', () {
    test('wraps the list as is, with nothing added or removed', () {
      final list = _list([_row('a', 'kaffe')]);

      final withChange = PersonalMergePlan.unchanged(
        list,
        concurrentChange: true,
      );
      final without = PersonalMergePlan.unchanged(
        list,
        concurrentChange: false,
      );

      expect(withChange.list, same(list));
      expect(withChange.added, isEmpty);
      expect(withChange.removed, isEmpty);
      expect(withChange.updated, isEmpty);
      expect(withChange.concurrentChange, isTrue);
      expect(without.concurrentChange, isFalse);
    });
  });
}
