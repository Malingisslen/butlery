/// P5-U23/U24: the overflow tray in the week-menu view model.
///
/// U23 (produktregler.md:206, :890, :1123-1127): the tray counts in dishes
/// ("2 av 5 rätter placerade"), says why the rest did not fit, offers next
/// week as a choice in the tray, and the cells show the placement order.
/// U24 (produktregler.md:164-172, :1125; Q-A11): the tray survives a reload
/// on the device of the person who generated it, lives 30 days, and is gone
/// once emptied.
library;

import 'dart:async';

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/meal_dislikes.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {
  // BUT-2215: the week menu listens from its constructor.
  @override
  Stream<String?> get weekWrites => const Stream.empty();
}

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

/// The Wednesday of [_monday]'s week: "today" for every test unless one
/// sets its own clock, so the kept tray's next week is still ahead.
final _wednesday = DateTime(2026, 4, 15, 12);

/// A test that runs on [_wednesday].
void wedTest(String name, Future<void> Function() body) =>
    test(name, () => withClock(Clock.fixed(_wednesday), body));

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

  WeeklyMenuPlanViewModel newVm({
    Future<List<Recipe>> Function()? safePool,
    Future<Map<String, Set<String>>> Function()? readDislikes,
  }) {
    final vm = WeeklyMenuPlanViewModel(
      service: service,
      recipeService: recipes,
      shoppingListGenerator: _MockShopping(),
      safePool: safePool,
      readDislikes: readDislikes,
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
    when(() => service.saveRevision(any())).thenAnswer((_) async {});
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
    wedTest('the tray counts in dishes and keeps its reason', () async {
      final vm = await generated();

      expect(vm.overflow.map((r) => r.title), ['Ugnspannkaka', 'Ärtsoppa']);
      expect(vm.overflowTotal, 5);
      expect(vm.overflowPlacedCount, 3);
      expect(vm.overflowReason!.weekStart, _monday);
      expect(vm.overflowReason!.pastDaysSkipped, isTrue);
      expect(vm.canPlaceOverflowInNextWeek, isTrue);
    });

    wedTest('the cells get the order the placement followed', () async {
      final vm = await generated();

      // The order of the distribution, not the order of the days.
      expect(vm.placementOrderOf('e-3'), 1);
      expect(vm.placementOrderOf('e-1'), 2);
      expect(vm.placementOrderOf('e-2'), 3);
      expect(vm.placementOrderOf('not-placed'), isNull);
    });

    wedTest('placing a chip counts it as placed', () async {
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

    wedTest('moves the tray into the following week and saves it', () async {
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
        () => service.saveRevision(
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

    wedTest(
      'what does not fit there stays, with no third week offered',
      () async {
        final vm = await generated();
        stubNextWeek(rest: [soppa]);

        final moved = await vm.placeOverflowInNextWeek();

        expect(moved, 1);
        expect(vm.overflow.map((r) => r.id), ['o2']);
        expect(vm.overflowReason!.weekStart, _nextMonday);
        // produktregler.md:893: the two-week limit is visible, not silent.
        expect(vm.canPlaceOverflowInNextWeek, isFalse);
        expect(await vm.placeOverflowInNextWeek(), isNull);
      },
    );

    wedTest('a refused save puts the tray back', () async {
      final vm = await generated();
      stubNextWeek();
      when(() => service.saveRevision(any())).thenThrow(Exception('denied'));

      final moved = await vm.placeOverflowInNextWeek();

      expect(moved, isNull);
      expect(vm.overflow.map((r) => r.id), ['o1', 'o2']);
      expect(vm.canPlaceOverflowInNextWeek, isTrue);
      expect(vm.error, isNotNull);
    });

    wedTest('an unreadable next week writes nothing', () async {
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
      verifyNever(() => service.saveRevision(any()));
    });
  });

  group('P5-U24: the tray survives a reload on this device', () {
    wedTest('a new view model brings the tray back', () async {
      await generated();

      final reopened = newVm();
      await reopened.loadWeek(_monday);
      await pumpEventQueue();

      expect(reopened.overflow.map((r) => r.id), ['o1', 'o2']);
      expect(reopened.overflowTotal, 5);
      expect(reopened.overflowReason!.weekStart, _monday);
      expect(reopened.canPlaceOverflowInNextWeek, isTrue);
    });

    wedTest('an emptied tray does not come back', () async {
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

    wedTest('another person on the same device does not get it', () async {
      await generated();
      when(() => service.overflowTrayOwnerId).thenReturn('johan');

      final other = newVm();
      await other.loadWeek(_monday);
      await pumpEventQueue();

      expect(other.overflow, isEmpty);
    });

    wedTest('after 30 days untouched it is gone', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 15)), generated);

      final later = newVm();
      await withClock(Clock.fixed(DateTime(2026, 5, 16)), () async {
        await later.loadWeek(_monday);
        await pumpEventQueue();
      });

      expect(later.overflow, isEmpty);
    });

    wedTest(
      'a recipe list that has not loaded yet never wipes the kept tray',
      () async {
        await generated();
        // Cold start or web: the recipe list answers for nothing yet.
        final states = StreamController<RecipeServiceState>.broadcast();
        addTearDown(states.close);
        when(() => recipes.stateStream).thenAnswer((_) => states.stream);
        when(() => recipes.getRecipeById(any())).thenReturn(null);

        final reopened = newVm();
        await reopened.loadWeek(_monday);
        await pumpEventQueue();

        expect(reopened.overflow, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        final kept = WeeklyMenuOverflowTraySnapshot.fromJson(
          jsonDecode(
            prefs.getString(WeeklyMenuOverflowTrayStore.keyFor('malin'))!,
          ),
        );
        expect(kept!.recipeIds, ['o1', 'o2']);

        // The list arrives: the chips come back, and nothing was lost.
        when(() => recipes.getRecipeById('o1')).thenReturn(pannkaka);
        when(() => recipes.getRecipeById('o2')).thenReturn(soppa);
        states.add(const RecipeStateLoading());
        await pumpEventQueue();

        expect(reopened.overflow.map((r) => r.id), ['o1', 'o2']);
        expect(reopened.overflowTotal, 5);
      },
    );

    wedTest(
      'a chip still waiting for the list is kept when another is placed',
      () async {
        await generated();
        final states = StreamController<RecipeServiceState>.broadcast();
        addTearDown(states.close);
        when(() => recipes.stateStream).thenAnswer((_) => states.stream);
        when(() => recipes.getRecipeById('o2')).thenReturn(null);
        when(
          () => service.addEntry(
            plan: any(named: 'plan'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any(named: 'recipe'),
          ),
        ).thenReturn(_plan(_monday, placed));

        final reopened = newVm();
        await reopened.loadWeek(_monday);
        await pumpEventQueue();
        expect(reopened.overflow.map((r) => r.id), ['o1']);

        // Placing the only visible chip empties the tray the user can see,
        // and an emptied tray is gone (produktregler.md:171).
        await reopened.assignFromOverflow(
          recipe: pannkaka,
          day: DayOfWeek.sun,
          slot: MealSlot.middag,
        );
        await pumpEventQueue();
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.containsKey(WeeklyMenuOverflowTrayStore.keyFor('malin')),
          isFalse,
        );
      },
    );

    test(
      'a kept tray whose next week has passed offers no next week',
      () async {
        await withClock(Clock.fixed(_wednesday), generated);

        // Three weeks later: the kept tray is still within its 30 days, but
        // the week it offered (v. 17) lies in the past.
        final later = newVm();
        await withClock(Clock.fixed(DateTime(2026, 5, 6, 12)), () async {
          await later.loadWeek(_monday);
          await pumpEventQueue();
          expect(later.overflow.map((r) => r.id), ['o1', 'o2']);
          expect(later.canPlaceOverflowInNextWeek, isFalse);
          clearInteractions(service);
          expect(await later.placeOverflowInNextWeek(), isNull);
        });
        verifyNever(() => service.saveRevision(any()));
        verifyNever(
          () => service.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          ),
        );
      },
    );

    test('a kept tray whose next week is this week still offers it', () async {
      await withClock(Clock.fixed(_wednesday), generated);

      final later = newVm();
      await withClock(Clock.fixed(DateTime(2026, 4, 22, 12)), () async {
        await later.loadWeek(_monday);
        await pumpEventQueue();
        expect(later.canPlaceOverflowInNextWeek, isTrue);
      });
    });

    wedTest('a restore never overwrites a newer tray', () async {
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

    wedTest('adopting a manual placement clears the kept tray', () async {
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
  // Q5-01 = A (produktbeslut 2026-09-24): the tray comes back quietly and
  // "Släng resten" empties it, with a 7 s Ångra (produktregler.md:131).
  group('Q5-01: Släng resten', () {
    wedTest('empties the tray and its copy on this device', () async {
      final vm = await generated();

      final discarded = vm.discardOverflow();
      await pumpEventQueue();

      expect(discarded, isNotNull);
      expect(discarded!.count, 2);
      expect(vm.hasOverflow, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(WeeklyMenuOverflowTrayStore.keyFor('malin')),
        isFalse,
      );

      // A new view model has nothing to bring back.
      final reopened = newVm();
      await reopened.restoreOverflowTray();
      expect(reopened.hasOverflow, isFalse);
    });

    wedTest('Ångra brings the tray back as it was', () async {
      final vm = await generated();
      final discarded = vm.discardOverflow()!;

      expect(vm.undoDiscardOverflow(discarded), isTrue);
      await pumpEventQueue();

      expect(vm.overflow.map((r) => r.id), ['o1', 'o2']);
      expect(vm.overflowTotal, 5);
      expect(vm.overflowReason!.weekStart, _monday);
      final reopened = newVm();
      await reopened.restoreOverflowTray();
      expect(reopened.overflow.map((r) => r.id), ['o1', 'o2']);
    });

    wedTest('Ångra never overwrites a tray that filled again', () async {
      final vm = await generated();
      final discarded = vm.discardOverflow()!;
      await vm.applyGeneratedMenu({
        'middag': [pannkaka, soppa],
      });

      expect(vm.undoDiscardOverflow(discarded), isFalse);
      expect(vm.overflow.map((r) => r.id), ['o1', 'o2']);
    });

    // A newer generation that overflowed nothing also leaves the tray
    // empty: Ångra must still not bring the old tray back over it.
    wedTest('Ångra never overwrites a newer tray that is empty', () async {
      final vm = await generated();
      final discarded = vm.discardOverflow()!;
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
          overflow: const [],
        ),
      );
      await vm.applyGeneratedMenu({
        'middag': [pannkaka],
      });
      await pumpEventQueue();

      expect(vm.hasOverflow, isFalse);
      expect(vm.undoDiscardOverflow(discarded), isFalse);
      expect(vm.hasOverflow, isFalse);
    });

    wedTest('an empty tray has nothing to discard', () async {
      final vm = newVm();
      await vm.loadWeek(_monday);

      expect(vm.discardOverflow(), isNull);
    });
  });

  // BUT-2345 (Malin 2026-10-10, "Kontrollera alla"): a kept tray comes back
  // through the allergen-safe household pool, like a weekly-menu draft.
  group('BUT-2345: the restored tray passes the allergen-safe pool', () {
    Future<List<String>?> keptIds() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(WeeklyMenuOverflowTrayStore.keyFor('malin'));
      if (raw == null) return null;
      return WeeklyMenuOverflowTraySnapshot.fromJson(
        jsonDecode(raw),
      )!.recipeIds;
    }

    wedTest('a dish the pool no longer holds is removed and counted', () async {
      await generated();

      // Ärtsoppa no longer passes the household's allergens.
      final reopened = newVm(safePool: () async => [pannkaka]);
      final dropped = <int>[];
      final sub = reopened.trayDroppedAsUnsafe.listen(dropped.add);
      addTearDown(sub.cancel);
      await reopened.loadWeek(_monday);
      await pumpEventQueue();

      expect(reopened.overflow.map((r) => r.id), ['o1']);
      expect(dropped, [1]);
      expect(await keptIds(), ['o1']);
      expect(reopened.overflowTotal, 4);
      expect(reopened.overflowPlacedCount, 3);
    });

    wedTest('several removed dishes are counted in one notice', () async {
      await generated();

      final other = _recipe('z1', 'Linsgryta');
      final reopened = newVm(safePool: () async => [other]);
      final dropped = <int>[];
      final sub = reopened.trayDroppedAsUnsafe.listen(dropped.add);
      addTearDown(sub.cancel);
      await reopened.loadWeek(_monday);
      await pumpEventQueue();

      expect(reopened.overflow, isEmpty);
      expect(dropped, [2]);
      expect(await keptIds(), isNull);
    });

    wedTest('an empty pool is not read as every dish being unsafe', () async {
      await generated();
      when(
        () => recipes.stateStream,
      ).thenAnswer((_) => const Stream.empty());

      final reopened = newVm(safePool: () async => <Recipe>[]);
      final dropped = <int>[];
      final sub = reopened.trayDroppedAsUnsafe.listen(dropped.add);
      addTearDown(sub.cancel);
      await reopened.loadWeek(_monday);
      await pumpEventQueue();

      expect(reopened.overflow, isEmpty);
      expect(dropped, isEmpty);
      expect(await keptIds(), ['o1', 'o2']);
    });

    wedTest(
      'a pool read that fails is tried again when recipes change',
      () async {
        await generated();
        final states = StreamController<RecipeServiceState>.broadcast();
        addTearDown(states.close);
        when(() => recipes.stateStream).thenAnswer((_) => states.stream);
        var reads = 0;

        final reopened = newVm(
          safePool: () async {
            reads++;
            if (reads == 1) throw StateError('offline');
            return [pannkaka, soppa];
          },
        );
        await reopened.loadWeek(_monday);
        await pumpEventQueue();
        expect(reopened.overflow, isEmpty);

        states.add(const RecipeStateLoading());
        await pumpEventQueue();

        expect(reopened.overflow.map((r) => r.id), ['o1', 'o2']);
      },
    );

    wedTest('a slow pool read never overwrites a newer tray', () async {
      await generated();
      final pool = Completer<List<Recipe>>();
      stubDistribution();

      final reopened = newVm(safePool: () => pool.future);
      await reopened.loadWeek(_monday);
      await pumpEventQueue();
      expect(reopened.overflow, isEmpty);

      // A new generation fills the tray while the kept one is checked.
      final fresh = _recipe('o3', 'Fiskgratäng');
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
          overflow: [fresh],
          overflowMealTypes: const {'o3': 'middag'},
        ),
      );
      await reopened.applyGeneratedMenu({
        'middag': [fresh],
      });
      pool.complete([pannkaka, soppa]);
      await pumpEventQueue();

      expect(reopened.overflow.map((r) => r.id), ['o3']);
    });

    wedTest(
      'a tray whose dishes all pass comes back whole, silently',
      () async {
        await generated();

        final reopened = newVm(safePool: () async => [pannkaka, soppa]);
        final dropped = <int>[];
        final sub = reopened.trayDroppedAsUnsafe.listen(dropped.add);
        addTearDown(sub.cancel);
        await reopened.loadWeek(_monday);
        await pumpEventQueue();

        expect(reopened.overflow.map((r) => r.id), ['o1', 'o2']);
        expect(dropped, isEmpty);
        expect(await keptIds(), ['o1', 'o2']);
      },
    );

    wedTest('an unreadable pool shows nothing and keeps the tray', () async {
      await generated();
      when(
        () => recipes.stateStream,
      ).thenAnswer((_) => const Stream.empty());

      final reopened = newVm(safePool: () async => throw StateError('offline'));
      final dropped = <int>[];
      final sub = reopened.trayDroppedAsUnsafe.listen(dropped.add);
      addTearDown(sub.cancel);
      await reopened.loadWeek(_monday);
      await pumpEventQueue();

      expect(reopened.overflow, isEmpty);
      expect(dropped, isEmpty);
      expect(await keptIds(), ['o1', 'o2']);
    });

    wedTest(
      'a dish that arrives with the recipe list is checked too',
      () async {
        await generated();
        final states = StreamController<RecipeServiceState>.broadcast();
        addTearDown(states.close);
        when(() => recipes.stateStream).thenAnswer((_) => states.stream);
        when(() => recipes.getRecipeById('o2')).thenReturn(null);

        final reopened = newVm(safePool: () async => [pannkaka]);
        final dropped = <int>[];
        final sub = reopened.trayDroppedAsUnsafe.listen(dropped.add);
        addTearDown(sub.cancel);
        await reopened.loadWeek(_monday);
        await pumpEventQueue();
        expect(reopened.overflow.map((r) => r.id), ['o1']);
        expect(dropped, isEmpty);

        when(() => recipes.getRecipeById('o2')).thenReturn(soppa);
        states.add(const RecipeStateLoading());
        await pumpEventQueue();

        expect(reopened.overflow.map((r) => r.id), ['o1']);
        expect(dropped, [1]);
        expect(await keptIds(), ['o1']);
        expect(reopened.overflowTotal, 4);
      },
    );
  });

  // BUT-1625: the tray's next-week placement goes through the same
  // distribution, and who is home is the TARGET week's, not the week on
  // screen.
  group('BUT-1625: the tray into next week respects who is home there', () {
    const kid = 'kid';
    const parent = 'parent';
    final onionDish = RecipeFactory.build(
      id: 'o1',
      title: 'Löksoppa',
      mealType: 'middag',
      ingredients: const ['1 gul lök, hackad'],
    );

    wedTest(
      'the dislikes carry next week\'s presence, not this week\'s',
      () async {
        var reads = 0;
        final vm = newVm(
          readDislikes: () async {
            reads++;
            return {
              kid: {'lök'},
            };
          },
        );
        // This week: nobody has a selection (everyone home). Next week: the
        // kid is away Monday middag.
        final nextWeek = _plan(_nextMonday).copyWith(
          presenceBySlot: {
            DayOfWeek.mon: {
              MealSlot.middag: [parent],
            },
          },
        );
        when(() => service.readWeek(_nextMonday)).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: nextWeek, readFailed: false),
        );
        when(
          () => service.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
            dislikes: any(named: 'dislikes'),
          ),
        ).thenAnswer((inv) {
          final week = inv.namedArguments[#weekStart] as DateTime;
          return week == _monday
              ? WeeklyMenuDistributionResult(
                  plan: _plan(_monday, placed),
                  overflow: [onionDish],
                  overflowMealTypes: const {'o1': 'middag'},
                  overflowReason: WeeklyMenuOverflowReason(
                    weekStart: _monday,
                    pastDaysSkipped: true,
                  ),
                )
              : WeeklyMenuDistributionResult(
                  plan: nextWeek,
                  overflow: const [],
                );
        });
        await vm.loadWeek(_monday);
        await vm.applyGeneratedMenu({
          'middag': [onionDish],
        });
        await pumpEventQueue();
        final readsBefore = reads;

        await vm.placeOverflowInNextWeek();

        expect(reads, greaterThan(readsBefore), reason: 'asked again, fresh');
        final passed =
            verify(
                  () => service.distributeFromGeneratedMenu(
                    generated: any(named: 'generated'),
                    weekStart: _nextMonday,
                    existing: any(named: 'existing'),
                    now: any(named: 'now'),
                    dayPins: any(named: 'dayPins'),
                    dislikes: captureAny(named: 'dislikes'),
                  ),
                ).captured.single
                as MealDislikes?;
        expect(passed, isNotNull);
        expect(
          passed!.avoids(onionDish, DayOfWeek.mon, MealSlot.middag),
          isFalse,
        );
        expect(
          passed.avoids(onionDish, DayOfWeek.tue, MealSlot.middag),
          isTrue,
        );
      },
    );
  });
}
