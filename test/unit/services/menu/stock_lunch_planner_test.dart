// Which fridge and freezer boxes a suggested week takes as lunches.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/stock_lunch_planner.dart';

// A Monday.
final _weekStart = DateTime(2026, 4, 13);
final _monday = DateTime(2026, 4, 13, 9, 30);

WeeklyMenuPlan _week({
  Map<DayOfWeek, Lunchbox> lunchboxes = const {},
  List<WeeklyMenuPlanEntry> entries = const [],
}) => WeeklyMenuPlan(
  id: 'u-1_2026-W16',
  userId: 'u-1',
  weekStartDate: _weekStart,
  entries: entries,
  lunchboxes: lunchboxes,
  createdAt: DateTime(2026, 4, 12),
  updatedAt: DateTime(2026, 4, 12),
);

WeeklyMenuPlanEntry _entry(DayOfWeek day, MealSlot slot) => WeeklyMenuPlanEntry(
  id: '${day.name}-${slot.name}',
  day: day,
  slot: slot,
  recipeId: 'r',
  recipeTitle: 'Rätt',
);

MealBox _box(
  String id, {
  MealBoxLocation location = MealBoxLocation.fridge,
  DateTime? storedOn,
  int count = 1,
  Map<String, int> takes = const {},
}) => MealBox(
  id: id,
  recipeId: 'recipe-$id',
  recipeTitle: 'Rätt $id',
  location: location,
  storedOn: storedOn ?? DateTime(2026, 4, 13),
  count: count,
  takes: takes,
);

bool _always(MealBox box, DayOfWeek day) => true;

Map<DayOfWeek, String?> _ids(Map<DayOfWeek, Lunchbox> placed) => {
  for (final e in placed.entries) e.key: e.value.mealBoxId,
};

void main() {
  group('openDays', () {
    test('only chosen days from today on, today included', () {
      final open = StockLunchPlanner.openDays(
        week: _week(),
        days: {DayOfWeek.mon, DayOfWeek.wed, DayOfWeek.sun},
        // Wednesday late in the evening: Monday is past, Wednesday is today.
        today: DateTime(2026, 4, 15, 23, 59),
      );

      expect(open, [DayOfWeek.wed, DayOfWeek.sun]);
    });

    test('a day with a lunchbox or a lunch dish is not open, a middag is '
        'no obstacle', () {
      final week = _week(
        lunchboxes: {
          DayOfWeek.tue: const Lunchbox(source: LunchboxSource.prepDay),
        },
        entries: [
          _entry(DayOfWeek.wed, MealSlot.lunch),
          _entry(DayOfWeek.thu, MealSlot.middag),
        ],
      );

      final open = StockLunchPlanner.openDays(
        week: week,
        days: {DayOfWeek.tue, DayOfWeek.wed, DayOfWeek.thu, DayOfWeek.fri},
        today: _monday,
      );

      expect(open, [DayOfWeek.thu, DayOfWeek.fri]);
    });
  });

  group('plan', () {
    test('one box per open day in weekday order, as a stock lunchbox', () {
      final placed = StockLunchPlanner.plan(
        week: _week(),
        boxes: [_box('a', count: 5)],
        days: {DayOfWeek.fri, DayOfWeek.tue},
        today: _monday,
        isSafe: _always,
      );

      expect(placed.keys, [DayOfWeek.tue, DayOfWeek.fri]);
      final lunch = placed[DayOfWeek.tue]!;
      expect(lunch.source, LunchboxSource.leftovers);
      expect(lunch.fromPreviousWeek, isTrue);
      expect(lunch.mealBoxId, 'a');
      expect(lunch.recipeId, 'recipe-a');
      expect(lunch.portions, 1);
      expect(lunch.isFromStock, isTrue);
    });

    test('fridge goes before freezer even when the freezer box is older, '
        'and the oldest comes first within each', () {
      final placed = StockLunchPlanner.plan(
        week: _week(),
        boxes: [
          _box(
            'freezer-old',
            location: MealBoxLocation.freezer,
            storedOn: DateTime(2026, 1, 1),
          ),
          _box('fridge-new', storedOn: DateTime(2026, 4, 12)),
          _box('fridge-old', storedOn: DateTime(2026, 4, 10)),
        ],
        days: {DayOfWeek.tue, DayOfWeek.wed, DayOfWeek.thu},
        today: _monday,
        isSafe: _always,
      );

      expect(_ids(placed), {
        DayOfWeek.tue: 'fridge-old',
        DayOfWeek.wed: 'fridge-new',
        DayOfWeek.thu: 'freezer-old',
      });
    });

    test('a fridge box is fine at 5 days old on its lunch date and skipped '
        'at 6', () {
      // Stored Friday the 10th: Wednesday the 15th is 5 days, Thursday 6.
      final placed = StockLunchPlanner.plan(
        week: _week(),
        boxes: [_box('a', count: 2, storedOn: DateTime(2026, 4, 10))],
        days: {DayOfWeek.wed, DayOfWeek.thu},
        today: _monday,
        isSafe: _always,
      );

      expect(_ids(placed), {DayOfWeek.wed: 'a'});
    });

    test('a too old fridge box leaves the day to a freezer box, which has no '
        'age limit', () {
      final placed = StockLunchPlanner.plan(
        week: _week(),
        boxes: [
          _box('stale', storedOn: DateTime(2026, 4, 1)),
          _box(
            'frozen',
            location: MealBoxLocation.freezer,
            storedOn: DateTime(2025, 1, 1),
          ),
        ],
        days: {DayOfWeek.tue},
        today: _monday,
        isSafe: _always,
      );

      expect(_ids(placed), {DayOfWeek.tue: 'frozen'});
    });

    test('remaining is count minus takes and shrinks per placement in the '
        'same run', () {
      final placed = StockLunchPlanner.plan(
        week: _week(),
        boxes: [
          // 3 in the box, 1 already planned: two left.
          _box('a', count: 3, takes: {'2026-04-20': 1}),
        ],
        days: {DayOfWeek.tue, DayOfWeek.wed, DayOfWeek.thu},
        today: _monday,
        isSafe: _always,
      );

      expect(_ids(placed), {DayOfWeek.tue: 'a', DayOfWeek.wed: 'a'});
    });

    test('a box with nothing remaining is never placed', () {
      final placed = StockLunchPlanner.plan(
        week: _week(),
        boxes: [
          _box('a', count: 1, takes: {'2026-04-20': 1}),
        ],
        days: {DayOfWeek.tue},
        today: _monday,
        isSafe: _always,
      );

      expect(placed, isEmpty);
    });

    test('a box the safety check rejects for a day is used on another day, '
        'and the check is asked about that very day', () {
      final asked = <(String, DayOfWeek)>[];
      final placed = StockLunchPlanner.plan(
        week: _week(),
        boxes: [_box('a', count: 2)],
        days: {DayOfWeek.tue, DayOfWeek.wed},
        today: _monday,
        isSafe: (box, day) {
          asked.add((box.id, day));
          return day != DayOfWeek.tue;
        },
      );

      expect(_ids(placed), {DayOfWeek.wed: 'a'});
      expect(asked, contains(('a', DayOfWeek.tue)));
    });

    test('days that are past, not chosen or already filled get nothing', () {
      final placed = StockLunchPlanner.plan(
        week: _week(
          lunchboxes: {
            DayOfWeek.thu: const Lunchbox(source: LunchboxSource.prepDay),
          },
        ),
        boxes: [_box('a', count: 9)],
        days: {DayOfWeek.mon, DayOfWeek.wed, DayOfWeek.thu},
        today: DateTime(2026, 4, 14),
        isSafe: _always,
      );

      expect(_ids(placed), {DayOfWeek.wed: 'a'});
    });
  });
}
