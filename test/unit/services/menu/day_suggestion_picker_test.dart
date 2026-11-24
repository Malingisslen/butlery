import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/menu/day_suggestion_picker.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

final _now = DateTime(2026, 11, 23);

Recipe _r(
  String id, {
  DateTime? cooked,
  Set<String> tags = const {},
  String meal = 'Middag',
}) {
  final base = RecipeFactory.build(
    id: id,
    title: id,
    mealType: meal,
    lastCookedAt: cooked,
  );
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: tags,
        allergenStatus: const {},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
      ),
    ),
    type: base.type,
  );
}

WeeklyMenuPlan _plan(List<WeeklyMenuPlanEntry> entries) => WeeklyMenuPlan(
  id: 'p',
  userId: 'u',
  weekStartDate: DateTime(2026, 11, 23),
  entries: entries,
  createdAt: _now,
  updatedAt: _now,
);

WeeklyMenuPlanEntry _entry(DayOfWeek d, String recipeId) => WeeklyMenuPlanEntry(
  id: '$d-$recipeId',
  day: d,
  slot: MealSlot.middag,
  recipeId: recipeId,
  recipeTitle: recipeId,
);

List<String> _ids(List<Recipe> l) => l.map((r) => r.id).toList();

void main() {
  List<Recipe> pickFor(
    List<Recipe> pool,
    int seed, {
    WeeklyMenuPlan? plan,
    List<Recipe> locked = const [],
    Set<String> shown = const {},
    int count = 4,
  }) => DaySuggestionPicker.pick(
    pool: pool,
    plan: plan,
    day: DayOfWeek.tue,
    slot: MealSlot.middag,
    now: _now,
    locked: locked,
    shown: shown,
    count: count,
    random: Random(seed),
  );

  test(
    'only dishes that fit the slot are offered, however the nudge falls',
    () {
      final pool = [
        for (var i = 0; i < 2; i++) _r('m$i'),
        for (var i = 0; i < 8; i++) _r('lunch$i', meal: 'Lunch'),
      ];
      for (var seed = 0; seed < 30; seed++) {
        expect(_ids(pickFor(pool, seed)).toSet(), {
          'm0',
          'm1',
        }, reason: '$seed');
      }
    },
  );

  test('offers four when more fit', () {
    expect(pickFor([for (var i = 0; i < 8; i++) _r('m$i')], 1).length, 4);
  });

  test('dishes already in the week are skipped', () {
    final pool = [
      for (final id in ['a', 'b', 'c', 'd', 'e']) _r(id),
    ];
    for (var seed = 0; seed < 30; seed++) {
      final got = pickFor(
        pool,
        seed,
        plan: _plan([_entry(DayOfWeek.mon, 'a')]),
      );
      expect(_ids(got), isNot(contains('a')), reason: '$seed');
    }
  });

  test('a locked card is never offered again', () {
    final pool = [for (var i = 0; i < 4; i++) _r('r$i')];
    for (var seed = 0; seed < 30; seed++) {
      final got = pickFor(pool, seed, locked: [pool.first]);
      expect(got.length, 3, reason: '$seed');
      expect(_ids(got), isNot(contains('r0')), reason: '$seed');
    }
  });

  test('never-cooked and long-ago dishes come before one cooked yesterday', () {
    final pool = [
      _r('yesterday', cooked: _now.subtract(const Duration(days: 1))),
      _r('never'),
      _r('old', cooked: _now.subtract(const Duration(days: 100))),
    ];
    for (var seed = 0; seed < 30; seed++) {
      expect(_ids(pickFor(pool, seed, count: 2)).toSet(), {'never', 'old'});
    }
  });

  test('a protein planned the day after is pushed down too', () {
    final pool = [
      _r('chicken-wed', tags: {'kyckling'}),
      _r('chicken2', tags: {'kyckling'}),
      _r('chicken3', tags: {'kyckling'}),
      _r('fish', tags: {'lax'}),
    ];
    for (var seed = 0; seed < 30; seed++) {
      final got = pickFor(
        pool,
        seed,
        plan: _plan([_entry(DayOfWeek.wed, 'chicken-wed')]),
        count: 1,
      );
      expect(_ids(got), ['fish'], reason: '$seed');
    }
  });

  test('same protein as a neighbouring day is pushed down', () {
    final pool = [
      _r('chicken-mon', tags: {'kyckling'}),
      _r('chicken2', tags: {'kyckling'}),
      _r('chicken3', tags: {'kyckling'}),
      _r('fish', tags: {'lax'}),
    ];
    for (var seed = 0; seed < 30; seed++) {
      final got = pickFor(
        pool,
        seed,
        plan: _plan([_entry(DayOfWeek.mon, 'chicken-mon')]),
        count: 1,
      );
      expect(_ids(got), ['fish'], reason: '$seed');
    }
  });

  test(
    'shown dishes are skipped, and offered again when nothing else is left',
    () {
      final pool = [
        for (final id in ['a', 'b', 'c', 'd', 'e']) _r(id),
      ];
      for (var seed = 0; seed < 30; seed++) {
        final first = pickFor(pool, seed, shown: {'a', 'b'}, count: 3);
        expect(_ids(first).toSet(), {'c', 'd', 'e'}, reason: '$seed');
      }
      expect(pickFor(pool, 5, shown: {'a', 'b', 'c', 'd'}, count: 3).length, 3);
    },
  );

  test('an empty pool gives no cards', () {
    expect(pickFor(const [], 1), isEmpty);
  });
}
