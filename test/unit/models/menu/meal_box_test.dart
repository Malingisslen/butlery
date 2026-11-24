/// BUT-2486 part 5: fridge and freezer meal boxes and the takes a week's
/// lunchboxes make from them.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';

MealBox _box(
  String id, {
  int count = 4,
  Map<String, int> takes = const {},
  MealBoxLocation location = MealBoxLocation.fridge,
}) => MealBox(
  id: id,
  recipeId: 'r-$id',
  recipeTitle: 'Gryta $id',
  location: location,
  storedOn: DateTime(2026, 1, 2),
  count: count,
  takes: takes,
);

WeeklyMenuPlan _week(Map<DayOfWeek, Lunchbox> lunchboxes) => WeeklyMenuPlan(
  id: 'u1_2026-W02',
  userId: 'u1',
  weekStartDate: DateTime(2026, 1, 5),
  entries: const [],
  createdAt: DateTime(2026, 1, 5),
  updatedAt: DateTime(2026, 1, 5),
  lunchboxes: lunchboxes,
);

void main() {
  group('MealBox.fromMap', () {
    test('parses every field', () {
      final box = MealBox.fromMap('abc', {
        'recipeId': 'r1',
        'recipeTitle': 'Köttbullar',
        'location': 'freezer',
        'storedOn': Timestamp.fromDate(DateTime(2026, 1, 2)),
        'count': 5,
        'takes': {'2026-01-06': 2, '2026-01-07': 1},
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 3)),
      });

      expect(box.id, 'abc');
      expect(box.recipeId, 'r1');
      expect(box.recipeTitle, 'Köttbullar');
      expect(box.location, MealBoxLocation.freezer);
      expect(box.storedOn, DateTime(2026, 1, 2));
      expect(box.count, 5);
      expect(box.takes, {'2026-01-06': 2, '2026-01-07': 1});
      expect(box.updatedAt, DateTime(2026, 1, 3));
    });

    test('drops takes that are not a positive int', () {
      final box = MealBox.fromMap('abc', {
        'recipeTitle': 'x',
        'storedOn': Timestamp.fromDate(DateTime(2026, 1, 2)),
        'count': 5,
        'takes': {
          '2026-01-06': 2,
          '2026-01-07': 0,
          '2026-01-08': -1,
          '2026-01-09': '2',
          '2026-01-10': 1.5,
        },
      });

      expect(box.takes, {'2026-01-06': 2});
    });

    test('a negative count parses as 0', () {
      final box = MealBox.fromMap('abc', {
        'recipeTitle': 'x',
        'storedOn': Timestamp.fromDate(DateTime(2026, 1, 2)),
        'count': -3,
      });

      expect(box.count, 0);
    });

    test('an unknown location parses as fridge', () {
      final box = MealBox.fromMap('abc', {
        'recipeTitle': 'x',
        'location': 'cellar',
        'storedOn': Timestamp.fromDate(DateTime(2026, 1, 2)),
      });

      expect(box.location, MealBoxLocation.fridge);
    });
  });

  group('remaining and taken', () {
    test('remaining is count minus every take', () {
      final box = _box(
        'a',
        count: 5,
        takes: {'2026-01-06': 2, '2026-01-07': 1},
      );

      expect(box.taken, 3);
      expect(box.remaining, 2);
    });

    test(
      'remaining never goes below 0 when a correction undercut the takes',
      () {
        final box = _box('a', count: 1, takes: {'2026-01-06': 2});

        expect(box.taken, 2);
        expect(box.remaining, 0);
      },
    );
  });

  group('pastTakeKeys', () {
    final box = _box(
      'a',
      takes: {'2026-01-05': 1, '2026-01-06': 1, '2026-01-07': 1},
    );

    test('returns only lunches dated before today', () {
      expect(box.pastTakeKeys(DateTime(2026, 1, 7)).toSet(), {
        '2026-01-05',
        '2026-01-06',
      });
    });

    test('today\'s own lunch is not yet eaten', () {
      expect(box.pastTakeKeys(DateTime(2026, 1, 5)), isEmpty);
    });
  });

  test('dateKey pads month and day so keys sort as dates', () {
    expect(MealBox.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    expect(
      MealBox.dateKey(DateTime(2026, 1, 5)).compareTo(
        MealBox.dateKey(DateTime(2026, 1, 15)),
      ),
      lessThan(0),
    );
  });

  group('isValidId', () {
    test('accepts a 20-character auto id', () {
      expect(MealBox.isValidId('aB3dE6gH9jK2mN5pQ8sT'), isTrue);
    });

    test('rejects empty, path-like, too long and null ids', () {
      expect(MealBox.isValidId(''), isFalse);
      expect(MealBox.isValidId('a/b'), isFalse);
      expect(MealBox.isValidId('a' * 129), isFalse);
      expect(MealBox.isValidId(null), isFalse);
    });

    test('accepts the longest allowed id', () {
      expect(MealBox.isValidId('a' * 128), isTrue);
    });
  });

  group('MealBoxTake.between', () {
    final a = _box('boxA');
    final b = _box('boxB', location: MealBoxLocation.freezer);
    // The week starts Monday 2026-01-05; wed is two days later.
    const wedKey = '2026-01-07';

    test('a stock box in a week with no earlier version is one take', () {
      final takes = MealBoxTake.between(
        null,
        _week({DayOfWeek.wed: Lunchbox.fromStock(a, portions: 2)}),
      );

      expect(takes, hasLength(1));
      expect(takes.single.boxId, 'boxA');
      expect(takes.single.key, wedKey);
      expect(takes.single.portions, 2);
      expect(takes.single.recipeTitle, 'Gryta boxA');
      expect(takes.single.location, MealBoxLocation.fridge);
      expect(takes.single.storedOn, DateTime(2026, 1, 2));
    });

    test('an unchanged stock box writes nothing', () {
      final week = _week({DayOfWeek.wed: Lunchbox.fromStock(a)});

      expect(MealBoxTake.between(week, week), isEmpty);
    });

    test(
      'choosing a stock box on a day takes from it under that day\'s date',
      () {
        final takes = MealBoxTake.between(
          _week({}),
          _week({DayOfWeek.fri: Lunchbox.fromStock(a, portions: 3)}),
        );

        expect(takes.single.key, '2026-01-09');
        expect(takes.single.portions, 3);
      },
    );

    test('changing the portions of the same box rewrites its take', () {
      final takes = MealBoxTake.between(
        _week({DayOfWeek.wed: Lunchbox.fromStock(a, portions: 1)}),
        _week({DayOfWeek.wed: Lunchbox.fromStock(a, portions: 2)}),
      );

      expect(takes, hasLength(1));
      expect(takes.single.boxId, 'boxA');
      expect(takes.single.portions, 2);
    });

    test(
      'switching boxes gives back to the old one and takes from the new',
      () {
        final takes = MealBoxTake.between(
          _week({DayOfWeek.wed: Lunchbox.fromStock(a, portions: 1)}),
          _week({DayOfWeek.wed: Lunchbox.fromStock(b, portions: 2)}),
        );

        expect(takes, hasLength(2));
        final giveBack = takes.singleWhere((t) => t.boxId == 'boxA');
        final take = takes.singleWhere((t) => t.boxId == 'boxB');
        expect(giveBack.portions, isNull);
        expect(giveBack.key, wedKey);
        expect(take.portions, 2);
        expect(take.key, wedKey);
        expect(take.location, MealBoxLocation.freezer);
      },
    );

    test('removing the lunch gives its portions back to the box', () {
      final takes = MealBoxTake.between(
        _week({DayOfWeek.wed: Lunchbox.fromStock(a)}),
        _week({}),
      );

      expect(takes, hasLength(1));
      expect(takes.single.boxId, 'boxA');
      expect(takes.single.key, wedKey);
      expect(takes.single.portions, isNull);
    });

    test('a lunchbox that is not from stock never touches a box', () {
      const suggestion = Lunchbox(
        source: LunchboxSource.suggestion,
        recipeId: 'r1',
        recipeTitle: 'Förslag',
      );
      const prep = Lunchbox(
        source: LunchboxSource.prepDay,
        recipeId: 'r2',
        recipeTitle: 'Matlåda',
      );

      expect(
        MealBoxTake.between(
          _week({DayOfWeek.wed: suggestion}),
          _week({DayOfWeek.wed: prep}),
        ),
        isEmpty,
      );
      expect(
        MealBoxTake.between(_week({}), _week({DayOfWeek.wed: suggestion})),
        isEmpty,
      );
      expect(
        MealBoxTake.between(_week({DayOfWeek.wed: suggestion}), _week({})),
        isEmpty,
      );
    });

    test('replacing a stock box with a suggestion gives the box back', () {
      const suggestion = Lunchbox(
        source: LunchboxSource.suggestion,
        recipeId: 'r1',
        recipeTitle: 'Förslag',
      );

      final takes = MealBoxTake.between(
        _week({DayOfWeek.wed: Lunchbox.fromStock(a)}),
        _week({DayOfWeek.wed: suggestion}),
      );

      expect(takes.single.boxId, 'boxA');
      expect(takes.single.portions, isNull);
    });

    test('A to B to A leaves the boxes\' takes as they started', () {
      // Replays the takes the way the repository applies them: a set under
      // the key, or the key removed when portions is null.
      final stored = <String, Map<String, int>>{
        'boxA': {wedKey: 1},
        'boxB': <String, int>{},
      };
      void apply(List<MealBoxTake> takes) {
        for (final t in takes) {
          final p = t.portions;
          if (p == null) {
            stored[t.boxId]!.remove(t.key);
          } else {
            stored[t.boxId]![t.key] = p;
          }
        }
      }

      final onA = _week({DayOfWeek.wed: Lunchbox.fromStock(a, portions: 1)});
      final onB = _week({DayOfWeek.wed: Lunchbox.fromStock(b, portions: 2)});

      apply(MealBoxTake.between(onA, onB));
      expect(stored['boxA'], isEmpty);
      expect(stored['boxB'], {wedKey: 2});

      apply(MealBoxTake.between(onB, onA));
      expect(stored['boxA'], {wedKey: 1});
      expect(stored['boxB'], isEmpty);
    });
  });
}
