// HEM-HERO: what Hem shows above the library.

import 'package:clock/clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/viewmodels/hem/hem_viewmodel.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

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

Recipe _tagged(
  String id,
  TriState gluten, {
  int? minutes,
  TriState? vegetarian,
}) {
  final recipe =
      (RecipeBuilder()
            ..id = id
            ..title = 'Recept $id'
            ..withTagResult(
              TagResult(
                tags: const {},
                allergenStatus: {'gluten': gluten},
                dietaryStatus: {'vegetarisk': ?vegetarian},
                coverage: 1.0,
                generatedAt: DateTime(2026, 1, 1),
                generatorVersion: kTagGeneratorVersion,
                hasCoverageAnomaly: false,
              ),
            ))
          .build();
  recipe.core.timeMinutes = minutes;
  return recipe;
}

const _glutenAllergy = UserAllergenPreferences(
  trackedAllergens: {'gluten'},
  trackedDietary: {},
  includeUnknownInMenu: true,
);

HemViewModel _vm({
  required WeeklyMenuPlanRead Function() read,
  Map<String, Recipe> recipes = const {},
  Set<String> pantry = const {},
  bool online = true,
  List<Recipe>? library,
  UserAllergenPreferences? prefs = UserAllergenPreferences.none,
}) => HemViewModel(
  readWeek: (_) async => read(),
  recipeById: (id) => recipes[id],
  pantryIngredientIds: () async => pantry,
  isOnline: () => online,
  library: library == null ? null : () => library,
  householdPrefs: library == null ? null : () async => prefs,
);

WeeklyMenuPlanRead _emptyWeek() =>
    WeeklyMenuPlanRead(plan: _plan(const []), readFailed: false);

class _MockUserService extends Mock implements UserService {}

class _MockProfile extends Mock implements UserProfile {}

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
      expect(vm.hero?.entry?.recipeId, 'a');
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
      expect(vm.hero?.entry?.recipeTitle, 'Rätt gone');
      expect(vm.hero?.allInPantry, isFalse);
      vm.dispose();
    });

    test('an empty week has no hero without a library', () async {
      final vm = _vm(
        read: () => WeeklyMenuPlanRead(plan: _plan([]), readFailed: false),
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.status, HemPlanStatus.ready);
      expect(vm.hero, isNull);
      vm.dispose();
    });

    test('the recipe arrives after the week: the hero gets it', () async {
      // The week is read before the library has loaded (cold start), then
      // the library fills in. The card must not stay title-only.
      final recipes = <String, Recipe>{};
      final vm = _vm(
        read: () => WeeklyMenuPlanRead(
          plan: _plan([_dinner(DayOfWeek.thu, 'a')]),
          readFailed: false,
        ),
        recipes: recipes,
        pantry: {'x'},
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.hero?.entry?.recipeId, 'a');
      expect(vm.hero?.recipe, isNull);

      var notified = 0;
      vm.addListener(() => notified++);
      await vm.resolveRecipe();
      expect(notified, 0, reason: 'nothing to fill in yet');

      recipes['a'] = _recipe('a', normalized: ['x']);
      await vm.resolveRecipe();
      expect(vm.hero?.recipe?.id, 'a');
      expect(vm.hero?.isTonight, isTrue);
      expect(vm.hero?.allInPantry, isTrue);
      expect(notified, 1);

      await vm.resolveRecipe();
      expect(notified, 1, reason: 'a resolved hero is left alone');
      vm.dispose();
    });
  });

  group('hemHouseholdPrefs', () {
    final user = _MockUserService();
    Future<(UserAllergenPreferences, MenuPrefSource)> complete(
      UserService _,
    ) async => (_glutenAllergy, MenuPrefSource.household);

    test('no profile loaded gives nothing', () async {
      when(() => user.currentUserProfile).thenReturn(null);
      expect(await hemHouseholdPrefs(user, resolve: complete), isNull);
    });

    test('a failing read gives nothing', () async {
      when(() => user.currentUserProfile).thenReturn(_MockProfile());
      expect(
        await hemHouseholdPrefs(user, resolve: (_) => throw StateError('x')),
        isNull,
      );
    });

    test('an incomplete roster gives nothing', () async {
      when(() => user.currentUserProfile).thenReturn(_MockProfile());
      expect(
        await hemHouseholdPrefs(
          user,
          resolve: (_) async =>
              (_glutenAllergy, MenuPrefSource.householdIncomplete),
        ),
        isNull,
      );
    });

    test('a complete household gives its preferences', () async {
      when(() => user.currentUserProfile).thenReturn(_MockProfile());
      expect(
        await hemHouseholdPrefs(user, resolve: complete),
        _glutenAllergy,
      );
    });
  });

  group('hemPrefsOrNull', () {
    test('an incomplete roster gives no preferences to suggest by', () {
      for (final source in MenuPrefSource.values) {
        final prefs = hemPrefsOrNull(_glutenAllergy, source);
        expect(
          prefs == null,
          source.isRosterIncomplete,
          reason: '$source',
        );
      }
    });
  });

  group('hemSuggestionPool', () {
    test('an allergy household gets only recipes proven free, even when it '
        'allows unknown in the menu', () {
      final pool = hemSuggestionPool([
        _tagged('free', TriState.free),
        _tagged('contains', TriState.contains),
        _tagged('unknown', TriState.unknown),
        _recipe('untagged'),
      ], _glutenAllergy);
      expect(pool.map((r) => r.id), ['free']);
    });

    test('a household without a requirement may be suggested anything', () {
      final pool = hemSuggestionPool([
        _recipe('b'),
        _recipe('a'),
      ], UserAllergenPreferences.none);
      expect(pool.map((r) => r.id), ['a', 'b']);
    });

    test('a dietary requirement counts unknown as unsafe too', () {
      const vegetarian = UserAllergenPreferences(
        trackedAllergens: {},
        trackedDietary: {'vegetarisk'},
        includeUnknownInMenu: true,
      );
      final pool = hemSuggestionPool([
        _tagged('free', TriState.free, vegetarian: TriState.free),
        _tagged('contains', TriState.free, vegetarian: TriState.contains),
        _tagged('unknown', TriState.free, vegetarian: TriState.unknown),
        _recipe('untagged'),
      ], vegetarian);
      expect(pool.map((r) => r.id), ['free']);
    });

    test('45 minutes is still quick, 46 is not', () {
      final pool = hemSuggestionPool([
        _tagged('edge', TriState.free, minutes: 45),
        _tagged('over', TriState.free, minutes: 46),
      ], _glutenAllergy);
      expect(pool.map((r) => r.id), ['edge']);
    });

    test('quick dishes come alone when there are any', () {
      final pool = hemSuggestionPool([
        _tagged('slow', TriState.free, minutes: 90),
        _tagged('quick', TriState.free, minutes: 30),
      ], _glutenAllergy);
      expect(pool.map((r) => r.id), ['quick']);
    });
  });

  group('HemViewModel suggestion (row 3)', () {
    test('an empty week suggests a safe library recipe', () async {
      final vm = _vm(
        read: _emptyWeek,
        library: [
          _tagged('contains', TriState.contains),
          _tagged('free', TriState.free),
        ],
        prefs: _glutenAllergy,
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.hero?.isSuggestion, isTrue);
      expect(vm.hero?.isTonight, isFalse);
      expect(vm.hero?.recipe?.id, 'free');
      expect(vm.canSwapSuggestion, isFalse);
      vm.dispose();
    });

    test(
      'nothing is suggested when the household cannot be resolved',
      () async {
        final vm = _vm(
          read: _emptyWeek,
          library: [_tagged('free', TriState.free)],
          prefs: null,
        );
        await withClock(Clock.fixed(_thursday), vm.load);
        expect(vm.hero, isNull);
        vm.dispose();
      },
    );

    test('nothing is suggested when no recipe is safe', () async {
      final vm = _vm(
        read: _emptyWeek,
        library: [_tagged('unknown', TriState.unknown)],
        prefs: _glutenAllergy,
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.hero, isNull);
      vm.dispose();
    });

    test('a planned dinner wins over a suggestion', () async {
      final vm = _vm(
        read: () => WeeklyMenuPlanRead(
          plan: _plan([_dinner(DayOfWeek.thu, 'a')]),
          readFailed: false,
        ),
        recipes: {'a': _recipe('a')},
        library: [_recipe('a'), _recipe('b')],
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.hero?.isSuggestion, isFalse);
      expect(vm.hero?.isTonight, isTrue);
      vm.dispose();
    });

    test(
      'a library that lands after the week still gets a suggestion',
      () async {
        final library = <Recipe>[];
        final vm = HemViewModel(
          readWeek: (_) async => _emptyWeek(),
          recipeById: (_) => null,
          pantryIngredientIds: () async => const {},
          isOnline: () => true,
          library: () => library,
          householdPrefs: () async => UserAllergenPreferences.none,
        );
        await withClock(Clock.fixed(_thursday), vm.load);
        expect(vm.hero, isNull);
        library.add(_recipe('late'));
        await withClock(Clock.fixed(_thursday), vm.resolveRecipe);
        expect(vm.hero?.recipe?.id, 'late');
        vm.dispose();
      },
    );

    test('the same dish all day, another tomorrow', () async {
      final vm = _vm(
        read: _emptyWeek,
        library: [_recipe('a'), _recipe('b'), _recipe('c')],
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      final today = vm.hero?.recipe?.id;
      await withClock(
        Clock.fixed(_thursday.add(const Duration(hours: 2))),
        vm.load,
      );
      expect(vm.hero?.recipe?.id, today);
      await withClock(
        Clock.fixed(_thursday.add(const Duration(days: 1))),
        vm.load,
      );
      expect(vm.hero?.recipe?.id, isNot(today));
      vm.dispose();
    });

    test('"Byt förslag" steps through the safe pool', () async {
      final vm = _vm(
        read: _emptyWeek,
        library: [_recipe('a'), _recipe('b'), _recipe('c')],
      );
      await withClock(Clock.fixed(_thursday), vm.load);
      expect(vm.canSwapSuggestion, isTrue);
      final seen = <String?>{vm.hero?.recipe?.id};
      await withClock(Clock.fixed(_thursday), vm.nextSuggestion);
      seen.add(vm.hero?.recipe?.id);
      await withClock(Clock.fixed(_thursday), vm.nextSuggestion);
      seen.add(vm.hero?.recipe?.id);
      expect(seen, {'a', 'b', 'c'});
      vm.dispose();
    });
  });
}
