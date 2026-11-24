/// BUT-2486 del 3: the week menu's lunchboxes through the view model — a box
/// is saved and removed as one write, a week holding only boxes counts as
/// empty as before, and a box is never drawn as judged without a judgement.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/weekly_allergen_marks.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

final _monday = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));

WeeklyMenuPlan _week({
  List<WeeklyMenuPlanEntry> entries = const [],
  Map<DayOfWeek, Lunchbox> lunchboxes = const {},
}) => WeeklyMenuPlan(
  id: IsoWeekUtils.weekIdFor('u1', _monday),
  userId: 'u1',
  weekStartDate: _monday,
  entries: entries,
  lunchboxes: lunchboxes,
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
);

Recipe _tagged(String id, {Set<String> tags = const {}}) {
  final base = RecipeFactory.build(id: id, title: id, mealType: 'Middag');
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: tags,
        allergenStatus: const {'nötter': TriState.free},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: kTagGeneratorVersion,
      ),
    ),
    type: base.type,
  );
}

const _prepBox = Lunchbox(
  source: LunchboxSource.prepDay,
  recipeId: 'chili',
  recipeTitle: 'Chili',
  portions: 2,
  takerIds: ['a'],
);

void main() {
  late _MockService service;
  late _MockRecipes recipes;
  late StreamController<RecipeServiceState> recipeStates;
  late List<WeeklyMenuPlan> saved;
  late WeeklyMenuPlanViewModel vm;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakePlan());
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.lunch);
    registerFallbackValue(_tagged('fallback'));
  });

  setUp(() {
    service = _MockService();
    recipes = _MockRecipes();
    recipeStates = StreamController.broadcast();
    saved = [];
    when(() => service.weekWrites).thenAnswer((_) => const Stream.empty());
    when(() => service.lateConflicts).thenAnswer((_) => const Stream.empty());
    when(() => service.overflowTrayOwnerId).thenReturn(null);
    when(() => recipes.stateStream).thenAnswer((_) => recipeStates.stream);
    when(() => recipes.getRecipeById(any())).thenReturn(null);
    when(() => service.saveRevision(any())).thenAnswer((inv) async {
      saved.add(inv.positionalArguments.first as WeeklyMenuPlan);
    });
    vm = WeeklyMenuPlanViewModel(
      service: service,
      recipeService: recipes,
      shoppingListGenerator: _MockShopping(),
    );
  });

  tearDown(() async {
    vm.dispose();
    await recipeStates.close();
  });

  Future<void> load(WeeklyMenuPlan week, {bool readFailed = false}) async {
    when(() => service.readWeek(any())).thenAnswer(
      (_) async => WeeklyMenuPlanRead(plan: week, readFailed: readFailed),
    );
    await vm.loadWeek(_monday);
  }

  group('setLunchbox', () {
    test('saves the box as the day\'s lunch and takes the lunch dish out of '
        'the entries in the same write', () async {
      final lunch = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.tue,
        slot: MealSlot.lunch,
        recipeId: 'soup',
        recipeTitle: 'Soppa',
      );
      final middag = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.tue,
        slot: MealSlot.middag,
        recipeId: 'stew',
        recipeTitle: 'Gryta',
      );
      await load(_week(entries: [lunch, middag]));

      expect(await vm.setLunchbox(DayOfWeek.tue, _prepBox), isTrue);

      final write = saved.single;
      expect(write.lunchboxes.keys, [DayOfWeek.tue]);
      expect(write.lunchboxes[DayOfWeek.tue]!.recipeId, 'chili');
      expect(write.entries.map((e) => e.id), [middag.id]);
      expect(vm.lunchboxAt(DayOfWeek.tue), isNotNull);
    });

    test('a refused save puts the week back and says so', () async {
      await load(_week());
      when(() => service.saveRevision(any())).thenThrow(Exception('denied'));

      expect(await vm.setLunchbox(DayOfWeek.tue, _prepBox), isFalse);

      expect(vm.lunchboxAt(DayOfWeek.tue), isNull);
      expect(vm.error, isNotNull);
    });

    test('nothing is written over a week whose read failed', () async {
      await load(_week(), readFailed: true);

      expect(await vm.setLunchbox(DayOfWeek.tue, _prepBox), isFalse);
      verifyNever(() => service.saveRevision(any()));
    });
  });

  test(
    'assignRecipe answers false and writes nothing when the service '
    'places no dish (a box day\'s lunch), so the tray keeps its chip',
    () async {
      final week = _week(lunchboxes: {DayOfWeek.tue: _prepBox});
      await load(week);
      when(
        () => service.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        ),
      ).thenAnswer((inv) => inv.namedArguments[#plan] as WeeklyMenuPlan);

      final placed = await vm.assignRecipe(
        day: DayOfWeek.tue,
        slot: MealSlot.lunch,
        recipe: _tagged('soup'),
      );

      expect(placed, isFalse);
      verifyNever(() => service.saveRevision(any()));
    },
  );

  group('clearLunchbox', () {
    test('removes only that day\'s box', () async {
      await load(
        _week(lunchboxes: {DayOfWeek.tue: _prepBox, DayOfWeek.wed: _prepBox}),
      );

      expect(await vm.clearLunchbox(DayOfWeek.tue), isTrue);

      expect(saved.single.lunchboxes.keys, [DayOfWeek.wed]);
    });

    test('a day without a box writes nothing and answers false, so no undo '
        'is offered', () async {
      await load(_week(lunchboxes: {DayOfWeek.wed: _prepBox}));

      expect(await vm.clearLunchbox(DayOfWeek.tue), isFalse);
      verifyNever(() => service.saveRevision(any()));
    });
  });

  group('a week with only lunchboxes behaves as an empty week', () {
    test(
      'it has no entries, and "Rensa veckan" has nothing to clear',
      () async {
        await load(_week(lunchboxes: {DayOfWeek.tue: _prepBox}));

        expect(vm.plan!.isEmpty, isTrue);
        expect(vm.hasEntries, isFalse);
        expect(await vm.clearWeek(), isFalse);
        verifyNever(() => service.clearWeek(any()));
        verifyNever(() => service.saveRevision(any()));
      },
    );
  });

  group('the dish on a box', () {
    test(
      'same-week leftovers take the name of the middag they follow, live',
      () async {
        final middag = WeeklyMenuPlanEntry.create(
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'stew',
          recipeTitle: 'Linsgryta',
        );
        await load(
          _week(
            entries: [middag],
            lunchboxes: {
              DayOfWeek.tue: const Lunchbox(
                source: LunchboxSource.leftovers,
                fromDay: DayOfWeek.mon,
              ),
            },
          ),
        );

        expect(vm.lunchboxTitle(DayOfWeek.tue), 'Linsgryta');
      },
    );

    test('leftovers from a day without a middag have no dish', () async {
      await load(
        _week(
          lunchboxes: {
            DayOfWeek.tue: const Lunchbox(
              source: LunchboxSource.leftovers,
              fromDay: DayOfWeek.mon,
            ),
          },
        ),
      );

      expect(vm.lunchboxTitle(DayOfWeek.tue), isNull);
    });

    test(
      'a stored dish keeps its stored name while the recipe is not loaded',
      () async {
        await load(_week(lunchboxes: {DayOfWeek.tue: _prepBox}));

        expect(vm.lunchboxTitle(DayOfWeek.tue), 'Chili');
      },
    );
  });

  test('without allergen marks wired, a box is reported unjudged, never '
      'safe', () async {
    await load(_week(lunchboxes: {DayOfWeek.tue: _prepBox}));

    expect(vm.lunchboxVerdict(DayOfWeek.tue), LunchboxVerdict.unjudged);
    expect(vm.lunchboxVerdict(DayOfWeek.wed), isNull);
  });

  test('suggestions are the loaded recipes that suit a lunchbox, with no '
      'read made', () {
    when(() => recipes.recipes).thenReturn([
      _tagged('stekt fisk'),
      _tagged('pastasallad', tags: {'meal-prep'}),
      _tagged('linsgryta', tags: {'meal-prep'}),
    ]);

    expect(vm.lunchboxSuggestions.map((r) => r.id), [
      'linsgryta',
      'pastasallad',
    ]);
  });
}
