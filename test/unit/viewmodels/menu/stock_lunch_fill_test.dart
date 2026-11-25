// What a suggested week takes from the fridge and freezer: it reads the boxes
// at most once, and any doubt leaves a box out.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/meal_dislikes.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu/stock_lunch_fill.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

final _weekStart = DateTime(2026, 4, 13);
final _monday = DateTime(2026, 4, 13, 9);

const _gluten = UserAllergenPreferences(
  trackedAllergens: {'gluten'},
  trackedDietary: {},
);
const _vegetarian = UserAllergenPreferences(
  trackedAllergens: {},
  trackedDietary: {'vegetarisk'},
);

WeeklyMenuPlan _week({List<WeeklyMenuPlanEntry> entries = const []}) =>
    WeeklyMenuPlan(
      id: 'u-1_2026-W16',
      userId: 'u-1',
      weekStartDate: _weekStart,
      entries: entries,
      createdAt: DateTime(2026, 4, 12),
      updatedAt: DateTime(2026, 4, 12),
    );

MealBox _box(String id, {String? recipeId = 'r-clean'}) => MealBox(
  id: id,
  recipeId: recipeId,
  recipeTitle: 'Rätt $id',
  location: MealBoxLocation.fridge,
  storedOn: DateTime(2026, 4, 13),
  count: 1,
);

Recipe _recipe(
  String id, {
  Map<String, TriState>? allergens,
  Map<String, TriState>? dietary,
}) {
  final base = RecipeFactory.build(id: id, title: id);
  if (allergens == null && dietary == null) return base;
  return base.copyWith(
    tagResult: TagResult(
      tags: const {},
      allergenStatus: allergens ?? const {},
      dietaryStatus: dietary ?? const {},
      coverage: 1.0,
      generatedAt: DateTime(2026),
      generatorVersion: kTagGeneratorVersion,
    ),
  );
}

void main() {
  late int reads;
  late int prefReads;
  late Map<String, Recipe> recipes;

  Recipe? recipeFor(String id) => recipes[id];

  StockLunchFill fill({
    bool enabled = true,
    Future<List<MealBox>> Function()? readBoxes,
    Future<UserAllergenPreferences> Function()? prefs,
    Duration readTimeout = const Duration(seconds: 3),
  }) => StockLunchFill(
    enabled: () => enabled,
    readBoxes:
        readBoxes ??
        () async {
          reads++;
          return [_box('a')];
        },
    householdPrefs:
        prefs ??
        () async {
          prefReads++;
          return UserAllergenPreferences.none;
        },
    readTimeout: readTimeout,
  );

  setUp(() {
    reads = 0;
    prefReads = 0;
    recipes = {'r-clean': _recipe('r-clean')};
  });

  Future<StockLunches> run(
    StockLunchFill f, {
    Set<DayOfWeek> days = const {DayOfWeek.wed},
    WeeklyMenuPlan? week,
  }) => f.plan(
    week: week ?? _week(),
    days: days,
    now: _monday,
    recipeFor: recipeFor,
  );

  group('when it reads', () {
    test(
      'a clean box on a chosen day is placed after exactly one read',
      () async {
        final result = await run(fill());

        expect(reads, 1);
        expect(result.readFailed, isFalse);
        expect(result.boxes.keys, [DayOfWeek.wed]);
        expect(result.boxes[DayOfWeek.wed]!.mealBoxId, 'a');
      },
    );

    test('no days chosen reads nothing', () async {
      final result = await run(fill(), days: const {});

      expect(reads, 0);
      expect(prefReads, 0);
      expect(result.boxes, isEmpty);
      expect(result.readFailed, isFalse);
    });

    test('the switch off reads nothing', () async {
      final result = await run(fill(enabled: false));

      expect(reads, 0);
      expect(result.boxes, isEmpty);
    });

    test('no open day reads nothing', () async {
      // Wednesday already has a lunch dish; Monday is today but not chosen.
      final week = _week(
        entries: [
          const WeeklyMenuPlanEntry(
            id: 'e',
            day: DayOfWeek.wed,
            slot: MealSlot.lunch,
            recipeId: 'x',
            recipeTitle: 'X',
          ),
        ],
      );

      final result = await run(fill(), week: week);

      expect(reads, 0);
      expect(result.boxes, isEmpty);
      expect(result.readFailed, isFalse);
    });
  });

  group('when something cannot be read', () {
    test('a box read that throws is reported and places nothing', () async {
      final result = await run(
        fill(readBoxes: () async => throw StateError('offline')),
      );

      expect(result.readFailed, isTrue);
      expect(result.boxes, isEmpty);
    });

    test('a box read that never answers times out and places nothing', () {
      fakeAsync((async) {
        StockLunches? result;
        run(
          fill(
            readBoxes: () => Completer<List<MealBox>>().future,
            readTimeout: const Duration(seconds: 3),
          ),
        ).then((r) => result = r);

        async.elapse(const Duration(seconds: 2));
        expect(result, isNull, reason: 'still within the timeout');
        async.elapse(const Duration(seconds: 2));

        expect(result?.readFailed, isTrue);
        expect(result?.boxes, isEmpty);
      });
    });

    test('an unreadable household fails closed even though the boxes were '
        'read', () async {
      final result = await run(
        fill(
          readBoxes: () async {
            reads++;
            return [_box('a')];
          },
          prefs: () async => throw StateError('no household'),
        ),
      );

      expect(
        reads,
        1,
        reason:
            'the boxes were read, so only the household '
            'can be what stopped the placement',
      );
      expect(result.readFailed, isTrue);
      expect(result.boxes, isEmpty);
    });
  });

  group('isSafe', () {
    bool safe(
      MealBox box, {
      UserAllergenPreferences prefs = UserAllergenPreferences.none,
    }) => StockLunchFill.isSafe(
      box,
      DayOfWeek.wed,
      prefs: prefs,
      dislikes: MealDislikes.none,
      recipeFor: recipeFor,
    );

    test('a clean recipe is safe', () {
      expect(safe(_box('a')), isTrue);
    });

    test('a box with no recipe id is not', () {
      expect(safe(_box('a', recipeId: null)), isFalse);
      expect(safe(_box('a', recipeId: '')), isFalse);
    });

    test('a box whose recipe is not found is not', () {
      expect(safe(_box('a', recipeId: 'gone')), isFalse);
    });

    test('a recipe containing a tracked allergen is not', () {
      recipes['bread'] = _recipe(
        'bread',
        allergens: {'gluten': TriState.contains},
      );

      expect(safe(_box('a', recipeId: 'bread'), prefs: _gluten), isFalse);
    });

    test('a recipe proven free of the tracked allergen is', () {
      recipes['salad'] = _recipe('salad', allergens: {'gluten': TriState.free});

      expect(safe(_box('a', recipeId: 'salad'), prefs: _gluten), isTrue);
    });

    test('an unchecked allergen is not, though the menu pool would let the '
        'recipe through', () {
      recipes['new'] = _recipe('new');
      recipes['maybe'] = _recipe(
        'maybe',
        allergens: {'gluten': TriState.unknown},
      );

      expect(safe(_box('a', recipeId: 'new'), prefs: _gluten), isFalse);
      expect(safe(_box('a', recipeId: 'maybe'), prefs: _gluten), isFalse);
    });

    test('a recipe failing a tracked diet is not', () {
      recipes['steak'] = _recipe(
        'steak',
        allergens: const {},
        dietary: {'vegetarisk': TriState.contains},
      );

      expect(safe(_box('a', recipeId: 'steak'), prefs: _vegetarian), isFalse);
    });

    group('dislikes', () {
      final mushroom = RecipeFactory.build(
        id: 'soup',
        title: 'soup',
        ingredients: const ['200 g champinjoner'],
      );

      bool safeFor(MealDislikes dislikes) {
        recipes['soup'] = mushroom;
        return StockLunchFill.isSafe(
          _box('a', recipeId: 'soup'),
          DayOfWeek.wed,
          prefs: UserAllergenPreferences.none,
          dislikes: dislikes,
          recipeFor: recipeFor,
        );
      }

      WeeklyMenuPlan lunchWith(List<String> present) => _week().copyWith(
        presenceBySlot: {
          DayOfWeek.wed: {MealSlot.lunch: present},
        },
      );

      test('a recipe someone eating that lunch dislikes is not', () {
        final dislikes = MealDislikes(
          dislikesByMember: {
            'kid': {'svamp'},
          },
          plan: lunchWith(['kid', 'parent']),
        );

        expect(safeFor(dislikes), isFalse);
      });

      test('the same dislike by someone away that lunch does not stop it', () {
        final dislikes = MealDislikes(
          dislikesByMember: {
            'kid': {'svamp'},
          },
          plan: lunchWith(['parent']),
        );

        expect(safeFor(dislikes), isTrue);
      });

      test('a dislike of another ingredient does not stop it', () {
        final dislikes = MealDislikes(
          dislikesByMember: {
            'kid': {'koriander'},
          },
          plan: lunchWith(['kid', 'parent']),
        );

        expect(safeFor(dislikes), isTrue);
      });
    });
  });

  group('plan with dislikes', () {
    test('a disliked box is left out and a clean one is placed', () async {
      recipes['soup'] = RecipeFactory.build(
        id: 'soup',
        title: 'soup',
        ingredients: const ['200 g champinjoner'],
      );
      final f = fill(
        readBoxes: () async => [_box('a', recipeId: 'soup'), _box('b')],
      );
      Future<StockLunches> place(MealDislikes? dislikes) => f.plan(
        week: _week(),
        days: const {DayOfWeek.wed, DayOfWeek.thu},
        now: _monday,
        recipeFor: recipeFor,
        dislikes: dislikes,
      );

      final without = await place(null);
      expect(
        without.boxes.values.map((l) => l.mealBoxId),
        containsAll(['a', 'b']),
        reason: 'premise: absent the dislike, the mushroom box is placed',
      );

      final result = await place(
        MealDislikes(
          dislikesByMember: {
            'kid': {'svamp'},
          },
          plan: null,
        ),
      );

      expect(result.boxes.values.map((l) => l.mealBoxId), ['b']);
    });
  });
}
