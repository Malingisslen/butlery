/// BUT-2486 part 4: what a week's lunchboxes add to its shopping list.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/shopping/lunchbox_shopping_portions.dart';

Recipe _recipe(String id, int? portions) => Recipe(
  core: RecipeCore(
    id: id,
    title: id,
    description: '',
    ingredients: const [],
    instructions: const ['x'],
    mealType: 'Middag',
    portions: portions,
  ),
  type: RecipeType.personal,
);

WeeklyMenuPlan _plan({List<(DayOfWeek, String)> middagar = const []}) =>
    WeeklyMenuPlan(
      id: 'p',
      userId: 'u',
      weekStartDate: DateTime(2026, 6, 8),
      entries: [
        for (final (day, id) in middagar)
          WeeklyMenuPlanEntry(
            id: 'e-${day.name}',
            day: day,
            slot: MealSlot.middag,
            recipeId: id,
            recipeTitle: id,
          ),
      ],
      createdAt: DateTime(2026, 6, 8),
      updatedAt: DateTime(2026, 6, 8),
    );

Lunchbox _leftovers(DayOfWeek from, {int portions = 1}) => Lunchbox(
  source: LunchboxSource.leftovers,
  fromDay: from,
  portions: portions,
);

Lunchbox _own(LunchboxSource source, String? recipeId, {int portions = 1}) =>
    Lunchbox(source: source, recipeId: recipeId, portions: portions);

void main() {
  final recipes = {
    'chili': _recipe('chili', 4),
    'soppa': _recipe('soppa', 2),
    'noportions': _recipe('noportions', null),
    'zero': _recipe('zero', 0),
  };
  Recipe? lookup(String id) => recipes[id];

  group('same-week leftovers', () {
    test('cook the middag bigger and count the boxes', () {
      final plan = _plan(
        middagar: [(DayOfWeek.mon, 'chili')],
      ).withLunchbox(DayOfWeek.tue, _leftovers(DayOfWeek.mon, portions: 2));

      final result = LunchboxShoppingPortions.of(plan, lookup);

      expect(result.extraMiddagPortions, {DayOfWeek.mon: 2});
      expect(result.portions, 2);
      expect(result.placements, isEmpty);
    });

    test('two boxes from the same middag sum', () {
      final plan = _plan(middagar: [(DayOfWeek.mon, 'chili')])
          .withLunchbox(DayOfWeek.tue, _leftovers(DayOfWeek.mon, portions: 2))
          .withLunchbox(DayOfWeek.wed, _leftovers(DayOfWeek.mon));

      final result = LunchboxShoppingPortions.of(plan, lookup);

      expect(result.extraMiddagPortions, {DayOfWeek.mon: 3});
      expect(result.portions, 3);
    });

    test('a middag that is gone adds nothing', () {
      final plan = _plan().withLunchbox(
        DayOfWeek.tue,
        _leftovers(DayOfWeek.mon),
      );

      final result = LunchboxShoppingPortions.of(plan, lookup);

      expect(result.extraMiddagPortions, isEmpty);
      expect(result.portions, 0);
      expect(result.isEmpty, isTrue);
    });

    test('a middag whose recipe cannot be resolved adds nothing', () {
      final plan = _plan(
        middagar: [(DayOfWeek.mon, 'missing')],
      ).withLunchbox(DayOfWeek.tue, _leftovers(DayOfWeek.mon));

      expect(LunchboxShoppingPortions.of(plan, lookup).portions, 0);
    });

    test('a recipe with no or zero portions cannot be scaled, so adds '
        'nothing', () {
      for (final id in ['noportions', 'zero']) {
        final plan = _plan(
          middagar: [(DayOfWeek.mon, id)],
        ).withLunchbox(DayOfWeek.tue, _leftovers(DayOfWeek.mon));

        final result = LunchboxShoppingPortions.of(plan, lookup);

        expect(result.extraMiddagPortions, isEmpty, reason: id);
        expect(result.portions, 0, reason: id);
      }
    });

    test('leftovers from the previous week were bought then: nothing now', () {
      final plan = _plan().withLunchbox(
        DayOfWeek.mon,
        const Lunchbox(
          source: LunchboxSource.leftovers,
          fromPreviousWeek: true,
          fromDay: DayOfWeek.sun,
          recipeId: 'chili',
          portions: 2,
        ),
      );

      final result = LunchboxShoppingPortions.of(plan, lookup);

      expect(result.portions, 0);
      expect(result.placements, isEmpty);
      expect(result.extraMiddagPortions, isEmpty);
    });
  });

  group('boxes cooked as their own dish', () {
    test('prep day and suggestion each become one placement scaled '
        'box portions / recipe portions', () {
      final plan = _plan()
          .withLunchbox(
            DayOfWeek.tue,
            _own(LunchboxSource.prepDay, 'chili', portions: 2),
          )
          .withLunchbox(
            DayOfWeek.wed,
            _own(LunchboxSource.suggestion, 'soppa', portions: 3),
          );

      final result = LunchboxShoppingPortions.of(plan, lookup);

      expect(result.portions, 5);
      expect(result.placements.map((p) => p.recipe.id), ['chili', 'soppa']);
      expect(result.placements.map((p) => p.factor), [0.5, 1.5]);
      expect(result.extraMiddagPortions, isEmpty);
    });

    test('an unresolved recipe or one with no portions is skipped', () {
      final plan = _plan()
          .withLunchbox(DayOfWeek.tue, _own(LunchboxSource.prepDay, 'missing'))
          .withLunchbox(
            DayOfWeek.wed,
            _own(LunchboxSource.suggestion, 'noportions'),
          )
          .withLunchbox(DayOfWeek.thu, _own(LunchboxSource.suggestion, null));

      final result = LunchboxShoppingPortions.of(plan, lookup);

      expect(result.placements, isEmpty);
      expect(result.portions, 0);
    });
  });

  group('recipeIdsOf', () {
    test('names the dishes cooked for a box, not leftovers', () {
      final plan = _plan(middagar: [(DayOfWeek.mon, 'chili')])
          .withLunchbox(DayOfWeek.tue, _leftovers(DayOfWeek.mon))
          .withLunchbox(DayOfWeek.wed, _own(LunchboxSource.prepDay, 'soppa'))
          .withLunchbox(
            DayOfWeek.thu,
            _own(LunchboxSource.suggestion, 'noportions'),
          );

      expect(LunchboxShoppingPortions.recipeIdsOf(plan), {
        'soppa',
        'noportions',
      });
    });
  });

  test('a box from the fridge or freezer buys nothing, even for a recipe '
      'with authored portions', () {
    final stock = Lunchbox.fromStock(
      MealBox(
        id: 'box1',
        recipeId: 'chili',
        recipeTitle: 'Chili',
        location: MealBoxLocation.freezer,
        storedOn: DateTime(2026, 6, 1),
        count: 4,
      ),
      portions: 2,
    );
    final plan = _plan(
      middagar: [(DayOfWeek.mon, 'chili')],
    ).withLunchbox(DayOfWeek.tue, stock);

    final result = LunchboxShoppingPortions.of(plan, lookup);

    expect(result.placements, isEmpty);
    expect(result.extraMiddagPortions, isEmpty);
    expect(result.portions, 0);
    expect(LunchboxShoppingPortions.recipeIdsOf(plan), isEmpty);
  });

  test('a week without boxes is empty', () {
    final result = LunchboxShoppingPortions.of(
      _plan(middagar: [(DayOfWeek.mon, 'chili')]),
      lookup,
    );

    expect(identical(result, LunchboxShoppingPortions.empty), isTrue);
    expect(result.isEmpty, isTrue);
    expect(LunchboxShoppingPortions.recipeIdsOf(_plan()), isEmpty);
  });
}
