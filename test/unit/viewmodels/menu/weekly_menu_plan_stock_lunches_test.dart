// BUT-2486 part 6: applying a suggested week places fridge and freezer boxes
// as lunchboxes on the weekdays the user chose, and saves the week together
// with the one it replaces so the boxes are taken in the same batch.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/stock_lunch_fill.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

// Monday of the week the tests build; "now" is that morning, so every other
// weekday is still ahead.
final _weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
final _now = DateTime(2026, 4, 13, 9);

WeeklyMenuPlan _plan({Map<DayOfWeek, Lunchbox> lunchboxes = const {}}) =>
    WeeklyMenuPlan(
      id: IsoWeekUtils.weekIdFor('u-1', _weekStart),
      userId: 'u-1',
      weekStartDate: _weekStart,
      entries: const [],
      lunchboxes: lunchboxes,
      createdAt: DateTime(2026, 4, 12),
      updatedAt: DateTime(2026, 4, 12),
    );

MealBox _box({String id = 'box-1', int count = 1}) => MealBox(
  id: id,
  recipeId: 'r-box',
  recipeTitle: 'Lasagne',
  location: MealBoxLocation.fridge,
  storedOn: DateTime(2026, 4, 13),
  count: count,
);

void main() {
  late _MockService service;
  late _MockRecipes recipes;
  late StreamController<String?> weekWrites;
  late StreamController<LateWeekConflict> lateConflicts;
  late StreamController<RecipeServiceState> recipeStates;
  late WeeklyMenuPlanViewModel vm;
  late int boxReads;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakePlan());
  });

  Future<void> build({
    required Map<DayOfWeek, Lunchbox> lunchboxes,
    List<MealBox>? boxes,
    bool cleanRecipe = true,
  }) async {
    final week = _plan(lunchboxes: lunchboxes);
    when(
      () => service.readWeek(any()),
    ).thenAnswer(
      (_) async => WeeklyMenuPlanRead(plan: week, readFailed: false),
    );
    // The distribution is the service's own job; here it hands back the week
    // the view model built it on, so what the boxes did to it stays visible.
    when(
      () => service.distributeFromGeneratedMenu(
        generated: any(named: 'generated'),
        weekStart: any(named: 'weekStart'),
        existing: any(named: 'existing'),
        now: any(named: 'now'),
        dayPins: any(named: 'dayPins'),
      ),
    ).thenAnswer(
      (i) => WeeklyMenuDistributionResult(
        plan: i.namedArguments[#existing] as WeeklyMenuPlan,
        overflow: const [],
      ),
    );
    when(() => recipes.getRecipeById(any())).thenReturn(null);
    if (cleanRecipe) {
      when(
        () => recipes.getRecipeById('r-box'),
      ).thenReturn(RecipeFactory.build(id: 'r-box', title: 'Lasagne'));
    }
    boxReads = 0;
    vm = WeeklyMenuPlanViewModel(
      service: service,
      recipeService: recipes,
      shoppingListGenerator: _MockShopping(),
      readDislikes: () async => const {},
      stockLunchFill: StockLunchFill(
        enabled: () => true,
        readBoxes: () async {
          boxReads++;
          return boxes ?? [_box()];
        },
        householdPrefs: () async => UserAllergenPreferences.none,
      ),
    );
    await vm.loadWeek(week.weekStartDate);
    vm.clearError();
  }

  setUp(() {
    service = _MockService();
    recipes = _MockRecipes();
    weekWrites = StreamController<String?>.broadcast();
    lateConflicts = StreamController.broadcast();
    recipeStates = StreamController<RecipeServiceState>.broadcast();
    when(() => service.weekWrites).thenAnswer((_) => weekWrites.stream);
    when(() => service.lateConflicts).thenAnswer((_) => lateConflicts.stream);
    when(() => recipes.stateStream).thenAnswer((_) => recipeStates.stream);
    when(
      () => service.saveRevision(any(), previous: any(named: 'previous')),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    vm.dispose();
    await weekWrites.close();
    await lateConflicts.close();
    await recipeStates.close();
  });

  ({WeeklyMenuPlan saved, WeeklyMenuPlan? previous}) savedWeek() {
    final captured = verify(
      () => service.saveRevision(
        captureAny(),
        previous: captureAny(named: 'previous'),
      ),
    ).captured;
    return (
      saved: captured[0] as WeeklyMenuPlan,
      previous: captured[1] as WeeklyMenuPlan?,
    );
  }

  test('a box from the fridge becomes the lunchbox on a chosen day, is '
      'marked new, counted, and saved with the week it replaces', () async {
    await build(lunchboxes: const {});

    final placed = await vm.applyGeneratedMenu(
      const {},
      now: _now,
      lunchboxDays: {DayOfWeek.wed},
    );

    expect(placed, isNotNull);
    expect(boxReads, 1);
    final save = savedWeek();
    final lunch = save.saved.lunchboxes[DayOfWeek.wed];
    expect(lunch?.mealBoxId, 'box-1');
    expect(lunch?.recipeId, 'r-box');
    expect(lunch?.isFromStock, isTrue);
    expect(save.saved.lunchboxes.keys, [DayOfWeek.wed]);
    expect(vm.plan?.lunchboxes[DayOfWeek.wed]?.mealBoxId, 'box-1');
    expect(vm.isLunchboxRecentlyPlaced(DayOfWeek.wed), isTrue);
    expect(vm.isLunchboxRecentlyPlaced(DayOfWeek.thu), isFalse);
    expect(vm.lastStockLunchCount, 1);
    expect(vm.lastStockLunchReadFailed, isFalse);
    expect(
      save.previous,
      isNotNull,
      reason: 'the take is written in the batch only against the replaced week',
    );
    expect(save.previous!.weekStartDate, save.saved.weekStartDate);
    expect(save.previous!.lunchboxes, isEmpty);
  });

  test('a lunchbox already on a chosen day is kept as it was, and the box '
      'goes to the next open chosen day', () async {
    const mine = Lunchbox(
      source: LunchboxSource.prepDay,
      recipeId: 'r-mine',
      recipeTitle: 'Min låda',
      portions: 2,
    );
    await build(lunchboxes: {DayOfWeek.wed: mine});

    await vm.applyGeneratedMenu(
      const {},
      now: _now,
      lunchboxDays: {DayOfWeek.wed, DayOfWeek.thu},
    );

    final lunchboxes = savedWeek().saved.lunchboxes;
    expect(lunchboxes[DayOfWeek.wed]?.toMap(), mine.toMap());
    expect(lunchboxes[DayOfWeek.thu]?.mealBoxId, 'box-1');
    expect(vm.isLunchboxRecentlyPlaced(DayOfWeek.wed), isFalse);
    expect(vm.isLunchboxRecentlyPlaced(DayOfWeek.thu), isTrue);
    expect(vm.lastStockLunchCount, 1);
  });

  test('no chosen days places nothing and reads no boxes', () async {
    await build(lunchboxes: const {});

    await vm.applyGeneratedMenu(const {}, now: _now);

    expect(boxReads, 0);
    expect(savedWeek().saved.lunchboxes, isEmpty);
    expect(vm.lastStockLunchCount, 0);
  });

  test('a box whose recipe is not loaded is left out, so the week still '
      'saves without it', () async {
    await build(lunchboxes: const {}, cleanRecipe: false);

    final placed = await vm.applyGeneratedMenu(
      const {},
      now: _now,
      lunchboxDays: {DayOfWeek.wed},
    );

    expect(placed, isNotNull);
    expect(boxReads, 1, reason: 'the boxes were read; the recipe stopped it');
    expect(savedWeek().saved.lunchboxes, isEmpty);
    expect(vm.lastStockLunchCount, 0);
  });

  test('a refused save takes the placed boxes back off the screen', () async {
    await build(lunchboxes: const {});
    when(
      () => service.saveRevision(any(), previous: any(named: 'previous')),
    ).thenThrow(Exception('denied'));

    final placed = await vm.applyGeneratedMenu(
      const {},
      now: _now,
      lunchboxDays: {DayOfWeek.wed},
    );

    expect(placed, isNull);
    expect(vm.plan?.lunchboxes, isEmpty);
    expect(vm.isLunchboxRecentlyPlaced(DayOfWeek.wed), isFalse);
    expect(vm.lastStockLunchCount, 0);
  });
}
