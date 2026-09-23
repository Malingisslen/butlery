/// P5-U23/U24: the overflow tray in the week-menu view model.
///
/// U23 (produktregler.md:206, :890, :1123-1127): the tray counts in dishes
/// ("2 av 5 rätter placerade"), says why the rest did not fit, offers next
/// week as a choice in the tray, and the cells show the placement order.
/// U24 (produktregler.md:164-172, :1125; Q-A11): the tray survives a reload
/// on the device of the person who generated it, lives 30 days, and is gone
/// once emptied.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

final _monday = DateTime(2026, 4, 13);
final _nextMonday = DateTime(2026, 4, 20);

WeeklyMenuPlan _plan(DateTime weekStart, [List<WeeklyMenuPlanEntry>? e]) {
  final ws = IsoWeekUtils.weekStartOf(weekStart);
  return WeeklyMenuPlan(
    id: IsoWeekUtils.weekIdFor('malin', ws),
    userId: 'malin',
    weekStartDate: ws,
    entries: e ?? const [],
    createdAt: DateTime(2026, 4, 1),
    updatedAt: DateTime(2026, 4, 1),
  );
}

WeeklyMenuPlanEntry _entry(String id, DayOfWeek day, String recipeId) =>
    WeeklyMenuPlanEntry(
      id: id,
      day: day,
      slot: MealSlot.middag,
      recipeId: recipeId,
      recipeTitle: 'Rätt $recipeId',
    );

Recipe _recipe(String id, String title) =>
    RecipeFactory.build(id: id, title: title);

void main() {
  late _MockService service;
  late _MockRecipes recipes;
  final vms = <WeeklyMenuPlanViewModel>[];

  final placed = [
    _entry('e-3', DayOfWeek.wed, 'p3'),
    _entry('e-1', DayOfWeek.mon, 'p1'),
    _entry('e-2', DayOfWeek.tue, 'p2'),
  ];
  final pannkaka = _recipe('o1', 'Ugnspannkaka');
  final soppa = _recipe('o2', 'Ärtsoppa');

  WeeklyMenuPlanViewModel newVm() {
    final vm = WeeklyMenuPlanViewModel(
      service: service,
      recipeService: recipes,
      shoppingListGenerator: _MockShopping(),
    );
    vms.add(vm);
    return vm;
  }

  /// Stubs a distribution into the visible week that places [placed] (in
  /// that order) and overflows the two recipes, for the current week on a
  /// Wednesday.
  void stubDistribution() {
    when(
      () => service.distributeFromGeneratedMenu(
        generated: any(named: 'generated'),
        weekStart: _monday,
        existing: any(named: 'existing'),
        now: any(named: 'now'),
        dayPins: any(named: 'dayPins'),
      ),
    ).thenReturn(
      WeeklyMenuDistributionResult(
        plan: _plan(_monday, placed),
        overflow: [pannkaka, soppa],
        overflowMealTypes: const {'o1': 'middag', 'o2': 'middag'},
        overflowReason: WeeklyMenuOverflowReason(
          weekStart: _monday,
          pastDaysSkipped: true,
        ),
      ),
    );
  }

  Future<WeeklyMenuPlanViewModel> generated() async {
    stubDistribution();
    final vm = newVm();
    await vm.loadWeek(_monday);
    await vm.applyGeneratedMenu({
      'middag': [pannkaka, soppa],
    });
    await pumpEventQueue();
    return vm;
  }

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakePlan());
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _MockService();
    recipes = _MockRecipes();
    when(() => service.overflowTrayOwnerId).thenReturn('malin');
    when(() => service.save(any())).thenAnswer((_) async {});
    when(
      () => service.readWeek(any()),
    ).thenAnswer(
      (_) async => WeeklyMenuPlanRead(
        plan: _plan(_monday),
        readFailed: false,
      ),
    );
    when(() => recipes.getRecipeById('o1')).thenReturn(pannkaka);
    when(() => recipes.getRecipeById('o2')).thenReturn(soppa);
  });

  tearDown(() {
    for (final vm in vms) {
      if (!vm.isDisposed) vm.dispose();
    }
    vms.clear();
  });

  group('P5-U23: count, reason, order', () {
    test('the tray counts in dishes and keeps its reason', () async {
      final vm = await generated();

      expect(vm.overflow.map((r) => r.title), ['Ugnspannkaka', 'Ärtsoppa']);
      expect(vm.overflowTotal, 5);
      expect(vm.overflowPlacedCount, 3);
      expect(vm.overflowReason!.weekStart, _monday);
      expect(vm.overflowReason!.pastDaysSkipped, isTrue);
      expect(vm.canPlaceOverflowInNextWeek, isTrue);
    });

    test('the cells get the order the placement followed', () async {
      final vm = await generated();

      // The order of the distribution, not the order of the days.
      expect(vm.placementOrderOf('e-3'), 1);
      expect(vm.placementOrderOf('e-1'), 2);
      expect(vm.placementOrderOf('e-2'), 3);
      expect(vm.placementOrderOf('not-placed'), isNull);
    });

    test('placing a chip counts it as placed', () async {
      final vm = await generated();
      when(
        () => service.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        ),
      ).thenReturn(_plan(_monday, placed));

      await vm.assignFromOverflow(
        recipe: pannkaka,
        day: DayOfWeek.sun,
        slot: MealSlot.middag,
      );

      expect(vm.overflowPlacedCount, 4);
      expect(vm.overflowTotal, 5);
    });
  });

  group('P5-U23: next week is a choice in the tray', () {
    void stubNextWeek({List<Recipe> rest = const []}) {
      when(
        () => service.readWeek(_nextMonday),
      ).thenAnswer(
        (_) async => WeeklyMenuPlanRead(
          plan: _plan(_nextMonday),
          readFailed: false,
        ),
      );
      when(
        () => service.distributeFromGeneratedMenu(
          generated: any(named: 'generated'),
          weekStart: _nextMonday,
          existing: any(named: 'existing'),
          now: any(named: 'now'),
          dayPins: any(named: 'dayPins'),
        ),
      ).thenReturn(
        WeeklyMenuDistributionResult(
          plan: _plan(_nextMonday, [_entry('n-1', DayOfWeek.mon, 'o1')]),
          overflow: rest,
        ),
      );
    }

    test('moves the tray into the following week and saves it', () async {
      final vm = await generated();
      stubNextWeek();

      final moved = await vm.placeOverflowInNextWeek();

      expect(moved, 2);
      expect(vm.overflow, isEmpty);
      final generatedArg =
          verify(
                () => service.distributeFromGeneratedMenu(
                  generated: captureAny(named: 'generated'),
                  weekStart: _nextMonday,
                  existing: any(named: 'existing'),
                  now: any(named: 'now'),
                  dayPins: any(named: 'dayPins'),
                ),
              ).captured.single
              as Map<String, List<Recipe>>;
      expect(generatedArg['middag']!.map((r) => r.id), ['o1', 'o2']);
      verify(
        () => service.save(
          any(
            that: isA<WeeklyMenuPlan>().having(
              (p) => p.weekStartDate,
              'week',
              _nextMonday,
            ),
          ),
        ),
      ).called(1);
    });

    test('what does not fit there stays, with no third week offered', () async {
      final vm = await generated();
      stubNextWeek(rest: [soppa]);

      final moved = await vm.placeOverflowInNextWeek();

      expect(moved, 1);
      expect(vm.overflow.map((r) => r.id), ['o2']);
      expect(vm.overflowReason!.weekStart, _nextMonday);
      // produktregler.md:893: the two-week limit is visible, not silent.
      expect(vm.canPlaceOverflowInNextWeek, isFalse);
      expect(await vm.placeOverflowInNextWeek(), isNull);
    });

    test('a refused save puts the tray back', () async {
      final vm = await generated();
      stubNextWeek();
      when(() => service.save(any())).thenThrow(Exception('denied'));

      final moved = await vm.placeOverflowInNextWeek();

      expect(moved, isNull);
      expect(vm.overflow.map((r) => r.id), ['o1', 'o2']);
      expect(vm.canPlaceOverflowInNextWeek, isTrue);
      expect(vm.error, isNotNull);
    });

    test('an unreadable next week writes nothing', () async {
      final vm = await generated();
      when(
        () => service.readWeek(_nextMonday),
      ).thenAnswer(
        (_) async => WeeklyMenuPlanRead(
          plan: _plan(_nextMonday),
          readFailed: true,
        ),
      );
      clearInteractions(service);

      expect(await vm.placeOverflowInNextWeek(), isNull);
      expect(vm.overflow, hasLength(2));
      verifyNever(() => service.save(any()));
    });
  });

  group('P5-U24: the tray survives a reload on this device', () {
    test('a new view model brings the tray back', () async {
      await generated();

      final reopened = newVm();
      await reopened.loadWeek(_monday);
      await pumpEventQueue();

      expect(reopened.overflow.map((r) => r.id), ['o1', 'o2']);
      expect(reopened.overflowTotal, 5);
      expect(reopened.overflowReason!.weekStart, _monday);
      expect(reopened.canPlaceOverflowInNextWeek, isTrue);
    });

    test('an emptied tray does not come back', () async {
      final vm = await generated();
      when(
        () => service.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        ),
      ).thenReturn(_plan(_monday, placed));
      await vm.assignFromOverflow(
        recipe: pannkaka,
        day: DayOfWeek.sat,
        slot: MealSlot.middag,
      );
      await vm.assignFromOverflow(
        recipe: soppa,
        day: DayOfWeek.sun,
        slot: MealSlot.middag,
      );
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(WeeklyMenuOverflowTrayStore.keyFor('malin')),
        isFalse,
      );
      final reopened = newVm();
      await reopened.loadWeek(_monday);
      await pumpEventQueue();
      expect(reopened.overflow, isEmpty);
    });

    test('another person on the same device does not get it', () async {
      await generated();
      when(() => service.overflowTrayOwnerId).thenReturn('johan');

      final other = newVm();
      await other.loadWeek(_monday);
      await pumpEventQueue();

      expect(other.overflow, isEmpty);
    });

    test('after 30 days untouched it is gone', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 15)), generated);

      final later = newVm();
      await withClock(Clock.fixed(DateTime(2026, 5, 16)), () async {
        await later.loadWeek(_monday);
        await pumpEventQueue();
      });

      expect(later.overflow, isEmpty);
    });

    test('a recipe deleted since is dropped from the tray', () async {
      await generated();
      when(() => recipes.getRecipeById('o1')).thenReturn(null);

      final reopened = newVm();
      await reopened.loadWeek(_monday);
      await pumpEventQueue();

      expect(reopened.overflow.map((r) => r.id), ['o2']);
    });

    test('a restore never overwrites a newer tray', () async {
      await generated();

      // The reopened view generates again, with a different rest, before
      // its restore lands.
      when(
        () => service.distributeFromGeneratedMenu(
          generated: any(named: 'generated'),
          weekStart: _monday,
          existing: any(named: 'existing'),
          now: any(named: 'now'),
          dayPins: any(named: 'dayPins'),
        ),
      ).thenReturn(
        WeeklyMenuDistributionResult(
          plan: _plan(_monday, placed),
          overflow: [soppa],
          overflowReason: WeeklyMenuOverflowReason(weekStart: _monday),
        ),
      );
      final reopened = newVm();
      await withClock(Clock.fixed(DateTime(2026, 4, 15)), () async {
        await reopened.applyGeneratedMenu({
          'middag': [soppa],
        });
        await reopened.restoreOverflowTray();
      });

      expect(reopened.overflow.map((r) => r.id), ['o2']);
      expect(reopened.overflowTotal, 4);
    });

    test('adopting a manual placement clears the kept tray', () async {
      final vm = await generated();

      vm.adoptPlan(_plan(_monday, placed));
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(WeeklyMenuOverflowTrayStore.keyFor('malin')),
        isFalse,
      );
      expect(vm.placementOrderOf('e-3'), isNull);
    });
  });
}
