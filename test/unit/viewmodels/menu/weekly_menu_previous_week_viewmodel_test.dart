/// BUT-2486 part 5: the week menu's own edits and "Behåll min" hand the
/// service the week they replaced. That argument is what makes the service
/// write a lunch's box take in the same batch; a save that passes none writes
/// none, so dropping it here loses every take with every other suite green.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockService extends Mock implements WeeklyMenuPlanService {}

class _MockRecipes extends Mock implements UnifiedRecipeService {}

class _MockShopping extends Mock implements MenuShoppingListGenerator {}

class _FakePlan extends Fake implements WeeklyMenuPlan {}

final _monday = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));

WeeklyMenuPlan _week({Map<DayOfWeek, Lunchbox> lunchboxes = const {}}) =>
    WeeklyMenuPlan(
      id: IsoWeekUtils.weekIdFor('u1', _monday),
      userId: 'u1',
      weekStartDate: _monday,
      entries: const [],
      lunchboxes: lunchboxes,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );

const _box = Lunchbox(
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
  late WeeklyMenuPlanViewModel vm;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakePlan());
  });

  setUp(() {
    service = _MockService();
    recipes = _MockRecipes();
    recipeStates = StreamController.broadcast();
    when(() => service.weekWrites).thenAnswer((_) => const Stream.empty());
    when(() => service.lateConflicts).thenAnswer((_) => const Stream.empty());
    when(() => service.overflowTrayOwnerId).thenReturn(null);
    when(() => recipes.stateStream).thenAnswer((_) => recipeStates.stream);
    when(() => recipes.getRecipeById(any())).thenReturn(null);
    when(
      () => service.saveRevision(
        any(),
        previous: any(named: 'previous'),
      ),
    ).thenAnswer((_) async {});
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

  Future<void> load(WeeklyMenuPlan week) async {
    when(
      () => service.readWeek(any()),
    ).thenAnswer(
      (_) async => WeeklyMenuPlanRead(plan: week, readFailed: false),
    );
    await vm.loadWeek(_monday);
  }

  test('an edit saves the new week with the week it replaced as previous, '
      'so the service can write the lunch\'s box take', () async {
    final before = _week();
    await load(before);

    expect(await vm.setLunchbox(DayOfWeek.tue, _box), isTrue);

    final captured = verify(
      () => service.saveRevision(
        captureAny(),
        previous: captureAny(named: 'previous'),
      ),
    ).captured;
    final saved = captured[0] as WeeklyMenuPlan;
    final previous = captured[1] as WeeklyMenuPlan?;
    expect(saved.lunchboxes.keys, [DayOfWeek.tue]);
    expect(previous, same(before));
    expect(previous!.lunchboxes, isEmpty);
  });

  test(
    'Behåll min on the shown week saves with the shown week as previous',
    () async {
      final shown = _week();
      await load(shown);
      final remote = _week(); // same id: this is the week on screen
      final local = _week(lunchboxes: {DayOfWeek.wed: _box});

      expect(
        await vm.keepMine(WeekConflict(local: local, remote: remote)),
        isTrue,
      );

      final captured = verify(
        () => service.saveRevision(
          captureAny(),
          previous: captureAny(named: 'previous'),
        ),
      ).captured;
      expect((captured[0] as WeeklyMenuPlan).lunchboxes.keys, [DayOfWeek.wed]);
      expect(captured[1], same(shown));
    },
  );

  test('Behåll min for a week no longer on screen saves with the server\'s '
      'week as previous', () async {
    await load(_week());
    final nextMonday = _monday.add(const Duration(days: 7));
    final remote = WeeklyMenuPlan(
      id: IsoWeekUtils.weekIdFor('u1', nextMonday),
      userId: 'u1',
      weekStartDate: nextMonday,
      entries: const [],
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );
    final local = WeeklyMenuPlan(
      id: remote.id,
      userId: 'u1',
      weekStartDate: nextMonday,
      entries: const [],
      lunchboxes: {DayOfWeek.wed: _box},
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );

    expect(
      await vm.keepMine(WeekConflict(local: local, remote: remote)),
      isTrue,
    );

    final captured = verify(
      () => service.saveRevision(
        captureAny(),
        previous: captureAny(named: 'previous'),
      ),
    ).captured;
    expect((captured[0] as WeeklyMenuPlan).lunchboxes.keys, [DayOfWeek.wed]);
    expect(captured[1], same(remote));
  });
}
