/// Unit tests for [MenuPlacementViewModel] (BUT-1241).
///
/// Behavior under test (the view's contract):
///  * init loads the week and pre-selects the first unplaced item
///  * baseEntriesOverride replaces the loaded entries for the original week
///    (the ÄNDRA-redo path) but NOT for other weeks
///  * isEligible — only empty cells of the selected item's slot; övrigt is
///    always eligible; nothing is eligible without a selection
///  * placeSelectedAt mutates only the in-memory plan (no save), marks the
///    item placed, and auto-advances the selection
///  * tapItem on a placed item un-places it and re-selects it
///  * placeRemainingAutomatically distributes only the unplaced items and
///    maps the new entries back onto them; overflow count is returned
///  * confirm persists exactly ONE save and returns the placed count;
///    with zero placements it returns null and never saves
///  * week navigation resets every placement
///
/// The repository-facing service methods (getWeek / save) are mocked; the
/// pure placement methods (addEntry / removeEntry /
/// distributeFromGeneratedMenu) are delegated to a real
/// [WeeklyMenuPlanService] so the tests exercise genuine placement
/// semantics instead of restating stubs.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

class _MockWeeklyMenuPlanService extends Mock
    implements WeeklyMenuPlanService {}

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

class _FakeWeeklyMenuPlan extends Fake implements WeeklyMenuPlan {}

// Monday of ISO week 15, 2026 — a fixed past week so the distribution
// anchor is deterministic (Monday, not "today").
final _weekStart = DateTime(2026, 4, 6);

WeeklyMenuPlan _plan({List<WeeklyMenuPlanEntry> entries = const []}) {
  final now = DateTime(2026, 4, 1, 12);
  return WeeklyMenuPlan(
    id: IsoWeekUtils.weekIdFor('u-1', _weekStart),
    userId: 'u-1',
    weekStartDate: _weekStart,
    entries: entries,
    createdAt: now,
    updatedAt: now,
  );
}

WeeklyMenuPlanEntry _entry({
  required DayOfWeek day,
  required MealSlot slot,
  String id = 'pre-1',
  String recipeId = 'pre-r1',
  String title = 'Befintlig rätt',
}) {
  return WeeklyMenuPlanEntry(
    id: id,
    day: day,
    slot: slot,
    recipeId: recipeId,
    recipeTitle: title,
  );
}

Recipe _recipe(String id, {String mealType = 'lunch'}) {
  return RecipeFactory.build(
    id: id,
    title: 'Recept $id',
    description: '',
    ingredients: const [],
    instructions: const [],
    mealType: mealType,
  );
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakeWeeklyMenuPlan());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
    registerFallbackValue(DateTime(2026));
  });

  late _MockWeeklyMenuPlanService service;
  late WeeklyMenuPlanService realService;
  late List<WeeklyMenuPlan> savedPlans;

  /// Delegates the pure placement methods of the mocked service to a real
  /// instance so placement semantics stay genuine.
  void delegatePureMethods() {
    when(() => service.addEntry(
          plan: any(named: 'plan'),
          day: any(named: 'day'),
          slot: any(named: 'slot'),
          recipe: any(named: 'recipe'),
        )).thenAnswer((inv) => realService.addEntry(
          plan: inv.namedArguments[#plan] as WeeklyMenuPlan,
          day: inv.namedArguments[#day] as DayOfWeek,
          slot: inv.namedArguments[#slot] as MealSlot,
          recipe: inv.namedArguments[#recipe] as Recipe,
        ));
    when(() => service.removeEntry(
          plan: any(named: 'plan'),
          entryId: any(named: 'entryId'),
        )).thenAnswer((inv) => realService.removeEntry(
          plan: inv.namedArguments[#plan] as WeeklyMenuPlan,
          entryId: inv.namedArguments[#entryId] as String,
        ));
    when(() => service.distributeFromGeneratedMenu(
          generated: any(named: 'generated'),
          weekStart: any(named: 'weekStart'),
          existing: any(named: 'existing'),
          now: any(named: 'now'),
          dayPins: any(named: 'dayPins'),
        )).thenAnswer(
      (inv) => realService.distributeFromGeneratedMenu(
        generated: inv.namedArguments[#generated] as Map<String, List<Recipe>>,
        weekStart: inv.namedArguments[#weekStart] as DateTime,
        existing: inv.namedArguments[#existing] as WeeklyMenuPlan?,
        // Force the Monday anchor regardless of when the suite runs.
        now: _weekStart,
        dayPins: const [],
      ),
    );
  }

  setUp(() {
    service = _MockWeeklyMenuPlanService();
    final userService = _MockUserService();
    when(() => userService.currentUserProfile).thenReturn(null);
    realService = WeeklyMenuPlanService(
      repository: _MockRepo(),
      userService: userService,
    );
    savedPlans = [];
    when(() => service.getWeek(any())).thenAnswer((_) async => _plan());
    when(() => service.save(any())).thenAnswer((inv) async {
      savedPlans.add(inv.positionalArguments.first as WeeklyMenuPlan);
    });
    delegatePureMethods();
  });

  MenuPlacementViewModel buildVm({
    Map<String, List<Recipe>>? generated,
    bool startFromEmptyWeek = false,
  }) {
    return MenuPlacementViewModel(
      service: service,
      generated: generated ??
          {
            'lunch': [_recipe('l1'), _recipe('l2')],
            'middag': [_recipe('m1', mealType: 'middag')],
          },
      weekStart: _weekStart,
      startFromEmptyWeek: startFromEmptyWeek,
    );
  }

  group('init', () {
    test('loads the week and selects the first unplaced item', () async {
      final vm = buildVm();
      await vm.init();

      expect(vm.plan, isNotNull);
      expect(vm.totalCount, 3);
      expect(vm.placedCount, 0);
      expect(vm.selectedIndex, 0);
      expect(vm.selectedItem!.recipe.id, 'l1');
    });

    test('startFromEmptyWeek hides the saved entries (ÄNDRA redo path)',
        () async {
      when(() => service.getWeek(any())).thenAnswer(
        (_) async => _plan(entries: [
          _entry(day: DayOfWeek.mon, slot: MealSlot.lunch),
        ]),
      );
      final vm = buildVm(startFromEmptyWeek: true);
      await vm.init();

      // The saved auto layout is hidden; the working week starts empty.
      expect(vm.plan!.entries, isEmpty);
    });
  });

  group('eligibility', () {
    test('only empty cells of the selected slot are eligible', () async {
      when(() => service.getWeek(any())).thenAnswer(
        (_) async => _plan(entries: [
          _entry(day: DayOfWeek.mon, slot: MealSlot.lunch),
        ]),
      );
      final vm = buildVm();
      await vm.init();

      // Selected item is a lunch recipe.
      expect(vm.isEligible(DayOfWeek.mon, MealSlot.lunch), isFalse,
          reason: 'mon lunch is occupied');
      expect(vm.isEligible(DayOfWeek.tue, MealSlot.lunch), isTrue);
      expect(vm.isEligible(DayOfWeek.tue, MealSlot.middag), isFalse,
          reason: 'wrong slot for the selected item');
    });

    test('nothing is eligible without a selection', () async {
      final vm = buildVm();
      await vm.init();
      vm.tapItem(0); // toggles the auto-selection off

      expect(vm.selectedItem, isNull);
      expect(vm.isEligible(DayOfWeek.tue, MealSlot.lunch), isFalse);
    });

    test('övrigt is eligible even when the day already has entries', () async {
      when(() => service.getWeek(any())).thenAnswer(
        (_) async => _plan(entries: [
          _entry(day: DayOfWeek.mon, slot: MealSlot.ovrigt),
        ]),
      );
      final vm = buildVm(generated: {
        'dessert': [_recipe('d1', mealType: 'dessert')],
      });
      await vm.init();

      expect(vm.selectedItem!.slot, MealSlot.ovrigt);
      expect(vm.isEligible(DayOfWeek.mon, MealSlot.ovrigt), isTrue);
    });
  });

  group('placeSelectedAt', () {
    test('places in memory, advances selection, and never saves', () async {
      final vm = buildVm();
      await vm.init();

      vm.placeSelectedAt(DayOfWeek.wed);

      expect(vm.placedCount, 1);
      expect(vm.items[0].isPlaced, isTrue);
      expect(vm.plan!.entryAt(DayOfWeek.wed, MealSlot.lunch)!.recipeId, 'l1');
      expect(vm.selectedIndex, 1, reason: 'auto-advanced to next unplaced');
      expect(savedPlans, isEmpty, reason: 'nothing persists before confirm');
    });

    test('ignores ineligible targets', () async {
      when(() => service.getWeek(any())).thenAnswer(
        (_) async => _plan(entries: [
          _entry(day: DayOfWeek.mon, slot: MealSlot.lunch),
        ]),
      );
      final vm = buildVm();
      await vm.init();

      vm.placeSelectedAt(DayOfWeek.mon); // occupied

      expect(vm.placedCount, 0);
      expect(vm.plan!.entries, hasLength(1));
    });
  });

  group('un-placing', () {
    test('tapItem on a placed item removes its entry and re-selects it',
        () async {
      final vm = buildVm();
      await vm.init();
      vm.placeSelectedAt(DayOfWeek.wed);

      vm.tapItem(0);

      expect(vm.items[0].isPlaced, isFalse);
      expect(vm.plan!.entryAt(DayOfWeek.wed, MealSlot.lunch), isNull);
      expect(vm.selectedIndex, 0);
    });

    test('unplaceEntry resolves the owning item from the grid side', () async {
      final vm = buildVm();
      await vm.init();
      vm.placeSelectedAt(DayOfWeek.wed);
      final entryId = vm.items[0].placedEntryId!;

      expect(vm.isSessionEntry(entryId), isTrue);
      vm.unplaceEntry(entryId);

      expect(vm.items[0].isPlaced, isFalse);
      expect(vm.isSessionEntry(entryId), isFalse);
    });
  });

  group('placeRemainingAutomatically', () {
    test('distributes only unplaced items and maps entries back', () async {
      final vm = buildVm();
      await vm.init();
      // Hand-place the first lunch on Wednesday.
      vm.placeSelectedAt(DayOfWeek.wed);

      final overflow = vm.placeRemainingAutomatically();

      expect(overflow, 0);
      expect(vm.allPlaced, isTrue);
      // Remaining lunch fills Monday (first empty from the Mon anchor —
      // Wednesday is taken by the manual placement).
      expect(vm.plan!.entryAt(DayOfWeek.mon, MealSlot.lunch)!.recipeId, 'l2');
      expect(vm.plan!.entryAt(DayOfWeek.mon, MealSlot.middag)!.recipeId, 'm1');
      // Every item knows its entry.
      expect(vm.items.every((i) => i.placedEntryId != null), isTrue);
      expect(savedPlans, isEmpty);
    });

    test('returns the overflow count when the week cannot fit everything',
        () async {
      // 8 lunches into 7 days → 1 overflow.
      final vm = buildVm(generated: {
        'lunch': [for (var i = 0; i < 8; i++) _recipe('l$i')],
      });
      await vm.init();

      final overflow = vm.placeRemainingAutomatically();

      expect(overflow, 1);
      expect(vm.placedCount, 7);
      expect(vm.allPlaced, isFalse);
    });
  });

  group('confirm', () {
    test(
        'persists exactly one save and returns the placed count, the saved '
        'plan, and the session entry ids', () async {
      final vm = buildVm();
      await vm.init();
      vm.placeSelectedAt(DayOfWeek.wed);
      vm.placeRemainingAutomatically();

      final result = await vm.confirm();

      expect(result?.placed, 3);
      expect(savedPlans, hasLength(1));
      expect(savedPlans.single.entries, hasLength(3));
      expect(result?.plan, same(savedPlans.single),
          reason: 'callers adopt the persisted plan without a re-read');
      expect(
        result?.sessionEntryIds,
        savedPlans.single.entries.map((e) => e.id).toSet(),
      );
    });

    test('with zero placements returns null and never saves', () async {
      final vm = buildVm();
      await vm.init();

      final result = await vm.confirm();

      expect(result, isNull);
      expect(savedPlans, isEmpty);
    });

    test('returns null and surfaces the error when the save fails', () async {
      when(() => service.save(any())).thenThrow(Exception('boom'));
      final vm = buildVm();
      await vm.init();
      vm.placeSelectedAt(DayOfWeek.wed);

      final result = await vm.confirm();

      expect(result, isNull);
      expect(vm.hasError, isTrue);
    });
  });

  group('week navigation', () {
    test('moving to another week resets every placement', () async {
      final vm = buildVm();
      await vm.init();
      vm.placeSelectedAt(DayOfWeek.wed);
      expect(vm.placedCount, 1);

      await vm.nextWeek();

      expect(vm.placedCount, 0);
      expect(vm.selectedIndex, 0);
      final nextWeek = _weekStart.add(const Duration(days: 7));
      verify(() => service.getWeek(nextWeek)).called(1);
    });

    test(
        'redo sessions (startFromEmptyWeek) cannot navigate weeks — redoing '
        'this week\'s layout on another week would duplicate the menu',
        () async {
      final vm = buildVm(startFromEmptyWeek: true);
      await vm.init();
      expect(vm.canNavigateWeeks, isFalse);
      vm.placeSelectedAt(DayOfWeek.wed);

      await vm.nextWeek();

      // Still on the original week, placement intact, no extra fetch.
      expect(vm.weekStart, _weekStart);
      expect(vm.placedCount, 1);
      verify(() => service.getWeek(any())).called(1);
    });
  });
}
