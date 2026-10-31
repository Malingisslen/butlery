/// Kärnflöde 8B: the rules that keep a week's list in step with the week
/// menu without doubling a row or overwriting the user's own work.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/services/shopping/week_list_reconciler.dart';

const _plan = ShoppingRowOrigin.plan;
const _menu = ShoppingRowOrigin.menu;

UnifiedShoppingItem _item(
  String id,
  String name, {
  double amount = 1,
  String unit = 'st',
  String category = ShoppingCategory.other,
  String? note,
  bool bought = false,
}) => UnifiedShoppingItem(
  id: id,
  name: name,
  amount: amount,
  unit: unit,
  category: category,
  note: note,
  bought: bought,
);

/// What an earlier sync of [origin] left on the list.
UnifiedShoppingItem _written(
  String id,
  String name, {
  double amount = 1,
  String unit = 'st',
  String category = ShoppingCategory.other,
  String? note,
  bool bought = false,
  ShoppingRowOrigin origin = _plan,
}) => WeekListReconciler.stamp([
  _item(
    id,
    name,
    amount: amount,
    unit: unit,
    category: category,
    note: note,
    bought: bought,
  ),
], origin).single;

/// What the week menu would write now.
List<UnifiedShoppingItem> _fresh(
  List<UnifiedShoppingItem> items, [
  ShoppingRowOrigin origin = _plan,
]) => WeekListReconciler.stamp(items, origin);

void main() {
  group('fingerprint', () {
    test('a whole amount reads the same however it is written: 2.0 is 2', () {
      final whole = _item('a', 'mjöl', amount: 2.0, unit: 'dl');

      expect(WeekListReconciler.fingerprint(whole), isNot(contains('2.0')));
      expect(
        WeekListReconciler.fingerprint(whole),
        WeekListReconciler.fingerprint(
          _item('b', 'mjöl', amount: 2, unit: 'dl'),
        ),
      );
      expect(
        WeekListReconciler.fingerprint(
          _item('c', 'mjöl', amount: 2.5, unit: 'dl'),
        ),
        isNot(WeekListReconciler.fingerprint(whole)),
      );
    });

    test('changes with what the user can see and edit, not with the id or '
        'the tick', () {
      final base = _item('a', 'mjöl', amount: 2, unit: 'dl');
      final fp = WeekListReconciler.fingerprint(base);

      expect(
        WeekListReconciler.fingerprint(base.copyWith(name: 'vetemjöl')),
        isNot(fp),
      );
      expect(
        WeekListReconciler.fingerprint(base.copyWith(amount: 3)),
        isNot(fp),
      );
      expect(
        WeekListReconciler.fingerprint(
          base.copyWith(category: ShoppingCategory.dairy),
        ),
        isNot(fp),
      );
      expect(
        WeekListReconciler.fingerprint(base.copyWith(note: '2 recept')),
        isNot(fp),
      );
      expect(WeekListReconciler.fingerprint(base.copyWith(bought: true)), fp);
      expect(
        WeekListReconciler.fingerprint(
          _item('other-id', 'mjöl', amount: 2, unit: 'dl'),
        ),
        fp,
      );
    });

    test('names spelled differently but meaning the same ingredient match', () {
      expect(
        WeekListReconciler.fingerprint(_item('a', 'Mjöl', unit: 'dl')),
        WeekListReconciler.fingerprint(_item('b', 'mjöl', unit: 'dl')),
      );
      expect(
        WeekListReconciler.fingerprint(_item('a', 'salt', unit: 'msk')),
        WeekListReconciler.fingerprint(_item('b', 'salt', unit: 'matsked')),
      );
    });
  });

  group('stamp', () {
    test('marks each row with its origin and the fingerprint it was written '
        'as', () {
      final stamped = WeekListReconciler.stamp([
        _item('a', 'mjöl'),
      ], _menu).single;

      expect(stamped.generatedFrom, 'menu');
      expect(stamped.generatedAs, WeekListReconciler.fingerprint(stamped));
    });
  });

  group('reconcile', () {
    PersonalMergeWrite run(
      List<UnifiedShoppingItem> listRows,
      List<UnifiedShoppingItem> fresh, [
      ShoppingRowOrigin origin = _plan,
    ]) {
      return WeekListReconciler.reconcile(
        listRows: listRows,
        fresh: _fresh(fresh, origin),
        origin: origin,
      );
    }

    test('i03: syncing a second time writes nothing, however often', () {
      final fresh = [
        _item('n1', 'gul lök', amount: 3),
        _item('n2', 'mjölk', amount: 2, unit: 'dl'),
      ];
      final first = run(const [], fresh);
      expect(first.addIds, ['n1', 'n2']);
      final onList = _fresh(fresh);

      final second = run(onList, [
        _item('x1', 'gul lök', amount: 3),
        _item('x2', 'mjölk', amount: 2, unit: 'dl'),
      ]);

      expect(second.isEmpty, isTrue, reason: 'same rows, same values');
    });

    test('an untouched row whose value changed is updated in place, keeping '
        'its id', () {
      final onList = [_written('keep', 'mjölk', amount: 2, unit: 'dl')];

      final result = run(onList, [
        _item('new', 'mjölk', amount: 5, unit: 'dl'),
      ]);

      expect(result.add, isEmpty);
      expect(result.remove, isEmpty);
      expect(result.update.single.id, 'keep');
      expect(result.update.single.amount, 5);
      expect(
        result.update.single.generatedAs,
        WeekListReconciler.fingerprint(result.update.single),
        reason: 'the updated row is untouched again, so the next sync follows',
      );
    });

    test('i04: an amount, a name or a category the user changed is kept, and '
        'nothing is added beside it', () {
      final byAmount = _written(
        'a',
        'mjölk',
        amount: 2,
        unit: 'dl',
      ).copyWith(amount: 9);
      final byName = _written(
        'b',
        'pasta',
        unit: 'g',
      ).copyWith(name: 'spagetti');
      final byCategory = _written(
        'c',
        'ost',
        unit: 'g',
      ).copyWith(category: ShoppingCategory.dairy);

      final result = run(
        [byAmount, byName, byCategory],
        [
          _item('n1', 'mjölk', amount: 5, unit: 'dl'),
          _item('n2', 'pasta', amount: 4, unit: 'g'),
          _item('n3', 'ost', amount: 7, unit: 'g'),
        ],
      );

      expect(result.isEmpty, isTrue);
    });

    test('a renamed row still answers for its ingredient, so the ingredient '
        'is not added again beside it', () {
      final renamed = _written(
        'a',
        'pasta',
        unit: 'g',
      ).copyWith(name: 'spagetti');

      final result = run(
        [renamed],
        [_item('n', 'pasta', amount: 500, unit: 'g')],
      );

      expect(result.add, isEmpty);
      expect(result.remove, isEmpty, reason: 'the user\'s version stays');
    });

    test('a bought row is never updated and never removed', () {
      final bought = _written(
        'a',
        'mjölk',
        amount: 2,
        unit: 'dl',
        bought: true,
      );
      final gone = _written('b', 'ost', unit: 'g', bought: true);

      final result = run(
        [bought, gone],
        [_item('n', 'mjölk', amount: 5, unit: 'dl')],
      );

      expect(result.isEmpty, isTrue);
    });

    test('a dish taken off the week: its untouched row comes off, a changed '
        'one stays', () {
      final untouched = _written('a', 'pasta', unit: 'g');
      final edited = _written('b', 'ost', unit: 'g').copyWith(amount: 42);

      final result = run([untouched, edited], const []);

      expect(result.remove.map((i) => i.id), ['a']);
      expect(result.add, isEmpty);
      expect(result.update, isEmpty);
    });

    test('a row nobody has written yet is added', () {
      final result = run(
        [_written('a', 'pasta', unit: 'g')],
        [
          _item('n1', 'pasta', amount: 1, unit: 'g'),
          _item('n2', 'ris', amount: 2, unit: 'dl'),
        ],
      );

      expect(result.addIds, ['n2']);
    });

    test('the same name in another unit is another row', () {
      final onList = [_written('a', 'mjölk', amount: 2, unit: 'dl')];

      final result = run(onList, [
        _item('n1', 'mjölk', amount: 2, unit: 'dl'),
        _item('n2', 'mjölk', amount: 1, unit: 'st'),
      ]);

      expect(result.addIds, ['n2']);
    });

    test('rows from the other source are never touched, updated or removed, '
        'and do not answer for this source\'s ingredient', () {
      final fromMenu = _written('m', 'pasta', unit: 'g', origin: _menu);

      final result = run(
        [fromMenu],
        [_item('n', 'pasta', amount: 500, unit: 'g')],
      );

      expect(result.remove, isEmpty);
      expect(result.update, isEmpty);
      expect(result.addIds, ['n']);
    });

    test('a row without origin and with the amount the sync would write is '
        'taken over as this source\'s row, with nothing else changed', () {
      final legacy = _item('old', 'gul lök', amount: 3, bought: true);

      final result = run([legacy], [_item('n', 'gul lök', amount: 3)]);

      expect(result.add, isEmpty);
      final taken = result.update.single;
      expect(taken.id, 'old');
      expect(taken.generatedFrom, 'plan');
      expect(taken.generatedAs, WeekListReconciler.fingerprint(legacy));
      expect(taken.bought, isTrue);
      expect(taken.amount, 3);
    });

    test('a row without origin and with another amount is left alone and '
        'nothing is added beside it', () {
      final legacy = _item('old', 'gul lök', amount: 7);

      final result = run([legacy], [_item('n', 'gul lök', amount: 3)]);

      expect(result.isEmpty, isTrue);
    });

    test('a row without origin that no fresh row answers for is left on the '
        'list', () {
      final result = run([_item('old', 'kaffe')], const []);

      expect(result.remove, isEmpty);
    });

    test('two rows of one ingredient on the list answer for two fresh rows '
        'of it, one each', () {
      final onList = [
        _written('a', 'ägg', amount: 3),
        _written('b', 'ägg', amount: 6),
      ];

      final result = run(onList, [
        _item('n1', 'ägg', amount: 3),
        _item('n2', 'ägg', amount: 6),
      ]);

      expect(result.isEmpty, isTrue);
    });
  });

  group('holdsRowsFrom', () {
    UnifiedShoppingList list(
      List<UnifiedShoppingItem> items, [
      List<String>? menuIds,
    ]) => UnifiedShoppingList(
      name: 'v.24',
      ownerId: 'u',
      ownerDisplayName: 'U',
      items: items,
      menuItemIds: menuIds,
    );

    test('only rows the list names count, so a row you typed does not', () {
      final row = _written('a', 'pasta');

      expect(
        WeekListReconciler.holdsRowsFrom(list([row], ['a']), _plan),
        isTrue,
      );
      expect(
        WeekListReconciler.holdsRowsFrom(list([row], const []), _plan),
        isFalse,
      );
      expect(WeekListReconciler.holdsRowsFrom(list([row]), _plan), isFalse);
    });

    test('another origin does not count', () {
      final row = _written('a', 'pasta', origin: _menu);

      expect(
        WeekListReconciler.holdsRowsFrom(list([row], ['a']), _plan),
        isFalse,
      );
      expect(
        WeekListReconciler.holdsRowsFrom(list([row], ['a']), _menu),
        isTrue,
      );
    });

    test('a row from before origins counts only when asked for', () {
      final legacy = _item('a', 'pasta');
      final l = list([legacy], ['a']);

      expect(WeekListReconciler.holdsRowsFrom(l, _plan), isFalse);
      expect(
        WeekListReconciler.holdsRowsFrom(l, _plan, orLegacy: true),
        isTrue,
      );
    });
  });
}

extension on PersonalMergeWrite {
  List<String> get addIds => [for (final i in add) i.id];
}
