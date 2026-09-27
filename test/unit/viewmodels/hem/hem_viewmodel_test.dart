// HEM-HERO: what Hem shows above the library.
//
// produktregler.md:265-271 (§ 6.1): today's dinner marked IKVÄLL, else the
// next planned day marked with its weekday, never IKVÄLL; a failed read is
// the error state (produktregler.md:291-293); a plan read offline has no
// fetch time of its own (produktregler.md:294).

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/viewmodels/hem/hem_viewmodel.dart';

import '../../../infrastructure/builders/recipe_builder.dart';

// Thursday 9 July 2026, evening.
final _thursday = DateTime(2026, 7, 9, 18);

WeeklyMenuPlanEntry _dinner(DayOfWeek day, String recipeId) =>
    WeeklyMenuPlanEntry.create(
      day: day,
      slot: MealSlot.middag,
      recipeId: recipeId,
      recipeTitle: 'Rätt $recipeId',
    );

WeeklyMenuPlan _plan(List<WeeklyMenuPlanEntry> entries) =>
    WeeklyMenuPlan.empty(userId: 'u1', date: _thursday).copyWith(
      entries: entries,
    );

Recipe _recipe(String id, {List<String>? normalized}) {
  final recipe =
      (RecipeBuilder()
            ..id = id
            ..title = 'Recept $id')
          .build();
  recipe.core.ingredientsNormalized = normalized;
  return recipe;
}

HemViewModel _vm({
  required WeeklyMenuPlanRead Function() read,
  Map<String, Recipe> recipes = const {},
  Set<String> pantry = const {},
  bool online = true,
}) => HemViewModel(
  readWeek: (_) async => read(),
  recipeById: (id) => recipes[id],
  pantryIngredientIds: () async => pantry,
  isOnline: () => online,
);

void main() {
  group('hemHeroEntry', () {
    test("today's dinner is tonight", () {
      final picked = hemHeroEntry(
        _plan([
          _dinner(DayOfWeek.fri, 'b'),
          _dinner(DayOfWeek.thu, 'a'),
        ]),
        _thursday,
      );
      expect(picked?.entry.recipeId, 'a');
      expect(picked?.isTonight, isTrue);
    });

    test('lunch today is not tonight; the next dinner is, by weekday', () {
      final plan = _plan([
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.thu,
          slot: MealSlot.lunch,
          recipeId: 'lunch',
          recipeTitle: 'Lunch',
        ),
        _dinner(DayOfWeek.sat, 'sat'),
        _dinner(DayOfWeek.fri, 'fri'),
      ]);
      final picked = hemHeroEntry(plan, _thursday);
      expect(picked?.entry.recipeId, 'fri');
      expect(picked?.isTonight, isFalse);
    });

    test('an earlier day is never picked', () {
      expect(
        hemHeroEntry(_plan([_dinner(DayOfWeek.mon, 'mon')]), _thursday),
        isNull,
      );
    });

    test('a plan for another week is never read as this week', () {
      final nextWeek = _thursday.add(const Duration(days: 7));
      expect(
        hemHeroEntry(_plan([_dinner(DayOfWeek.fri, 'x')]), nextWeek),
        isNull,
      );
    });
  });

  group('hemAllInPantry', () {
    test('every normalised ingredient at home', () {
      expect(
        hemAllInPantry(_recipe('r', normalized: ['a', 'b']), {'a', 'b', 'c'}),
        isTrue,
      );
      expect(
        hemAllInPantry(_recipe('r', normalized: ['a', 'b']), {'a'}),
        isFalse,
      );
    });

    test('no ingredient data is never "allt i skafferiet"', () {
      expect(hemAllInPantry(_recipe('r'), {'a'}), isFalse);
      expect(hemAllInPantry(_recipe('r', normalized: []), {'a'}), isFalse);
    });
  });

  group('HemViewModel', () {
    test('starts loading, then shows tonight with its recipe', () async {
      final vm = _vm(
        read: () => WeeklyMenuPlanRead(
          plan: _plan([_dinner(DayOfWeek.thu, 'a')]),
          readFailed: false,
        ),
        recipes: {
          'a': _recipe('a', normalized: ['x']),
        },
        pantry: {'x'},
      );
      expect(vm.status, HemPlanStatus.loading);
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.status, HemPlanStatus.ready);
      expect(vm.hero?.isTonight, isTrue);
      expect(vm.hero?.recipe?.id, 'a');
      expect(vm.hero?.allInPantry, isTrue);
      expect(vm.fetchedAt, _thursday);
      vm.dispose();
    });

    test('a failed read is the error state, and a retry can recover', () async {
      var fail = true;
      final vm = _vm(
        read: () => WeeklyMenuPlanRead(
          plan: _plan([_dinner(DayOfWeek.thu, 'a')]),
          readFailed: fail,
        ),
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.status, HemPlanStatus.failed);
      expect(vm.hero, isNull);

      fail = false;
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.status, HemPlanStatus.ready);
      expect(vm.hero?.entry.recipeId, 'a');
      vm.dispose();
    });

    test('a plan read offline carries no fetch time of its own', () async {
      final vm = _vm(
        read: () => WeeklyMenuPlanRead(
          plan: _plan([_dinner(DayOfWeek.thu, 'a')]),
          readFailed: false,
        ),
        online: false,
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.status, HemPlanStatus.ready);
      expect(vm.fetchedAt, isNull);
      vm.dispose();
    });

    test('a recipe the library cannot answer for still shows the plan, '
        'without a pantry claim', () async {
      final vm = _vm(
        read: () => WeeklyMenuPlanRead(
          plan: _plan([_dinner(DayOfWeek.thu, 'gone')]),
          readFailed: false,
        ),
        pantry: {'x'},
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.hero?.recipe, isNull);
      expect(vm.hero?.entry.recipeTitle, 'Rätt gone');
      expect(vm.hero?.allInPantry, isFalse);
      vm.dispose();
    });

    test('an empty week has no hero (row 3 is not built)', () async {
      final vm = _vm(
        read: () => WeeklyMenuPlanRead(plan: _plan([]), readFailed: false),
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.status, HemPlanStatus.ready);
      expect(vm.hero, isNull);
      vm.dispose();
    });
  });
}
