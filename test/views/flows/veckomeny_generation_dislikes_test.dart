/// Who dislikes what steers generation and the apply that follows it
/// (BUT-1625), and the view is what wires the first half: it hands the
/// generator the calendar's `unplaceableRecipeIds` after the first frame.
///
/// BUT-2361: nothing else read that wiring, so deleting it left the
/// generation weight dead while placement kept working.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import 'veckomeny_flow_harness.dart';

const _kid = 'kid';
const _adult = 'adult';

Recipe _withOnion() => RecipeFactory.build(
  id: 'dinner-onion',
  title: 'Löksoppa',
  mealType: 'Middag',
  ingredients: const ['2 gul lök'],
  instructions: const ['Laga.'],
);

Recipe _withoutOnion() => RecipeFactory.build(
  id: 'dinner-plain',
  title: 'Pasta',
  mealType: 'Middag',
  ingredients: const ['400 g pasta'],
  instructions: const ['Laga.'],
);

void main() {
  late VeckomenyFlowHarness h;

  setUp(() async {
    h = VeckomenyFlowHarness();
  });

  tearDown(() => h.tearDown());

  Future<void> setUpWith({
    Future<Map<String, Set<String>>> Function()? readDislikes,
  }) => h.setUp(
    library: [_withOnion(), _withoutOnion()],
    readDislikes:
        readDislikes ??
        () async => {
          _kid: {'lök'},
        },
  );

  /// The week with [_adult] alone home for every dinner: [_kid], who
  /// dislikes onion, is away.
  void seedWeekWithoutKid() {
    final weekStart = IsoWeekUtils.weekStartOf(flowMonday);
    final plan = WeeklyMenuPlan(
      id: IsoWeekUtils.weekIdFor(flowUserId, weekStart),
      userId: flowUserId,
      weekStartDate: weekStart,
      entries: const [],
      presenceBySlot: {
        for (final d in DayOfWeek.values)
          d: {
            MealSlot.middag: [_adult],
          },
      },
      createdAt: flowMonday,
      updatedAt: flowMonday,
    );
    h.repository.plans[plan.id] = plan;
  }

  Future<void> openAndGenerate(
    WidgetTester tester, {
    Future<void> Function()? beforeGenerate,
  }) => withClock(Clock.fixed(flowMonday), () async {
    await PersistenceService().setVeckomenyViewMode('lista');
    await h.pump(tester);
    await tester.pumpAndSettle();
    await beforeGenerate?.call();
    h.menu.next = {
      'Middag': [_withOnion(), _withoutOnion()],
    };
    await h.generate(tester, 'två middagar');
    await tester.pumpAndSettle();
  });

  testWidgets('a dish nobody at home can eat is handed to the generator '
      'down-weighted', (tester) async {
    await setUpWith();
    await openAndGenerate(tester);

    expect(h.menu.generations, 1);
    expect(h.menu.lastScoringContext!.dislikedRecipeIds, {'dinner-onion'});
  });

  testWidgets('a dish the people at home can eat keeps its full weight', (
    tester,
  ) async {
    await setUpWith();
    seedWeekWithoutKid();
    await openAndGenerate(tester);

    expect(h.menu.generations, 1);
    expect(h.menu.lastScoringContext!.dislikedRecipeIds, isEmpty);
  });

  testWidgets('browsing to another week does not move the weight off the '
      'week the menu is placed in', (tester) async {
    await setUpWith();
    seedWeekWithoutKid();
    await openAndGenerate(
      tester,
      beforeGenerate: () async {
        final calendar = Provider.of<WeeklyMenuPlanViewModel>(
          tester.element(find.byType(TextField).first),
          listen: false,
        );
        await calendar.nextWeek();
        await tester.pumpAndSettle();
      },
    );

    expect(h.menu.generations, 1);
    expect(h.menu.lastScoringContext!.dislikedRecipeIds, isEmpty);
  });

  test('a week adopted while the dislikes are being read is the one a '
      'refused save puts back', () async {
    await setUpWith();
    final release = Completer<Map<String, Set<String>>>();
    final vm = h.buildPlanViewModel(readDislikes: () => release.future);
    addTearDown(vm.dispose);
    await vm.loadWeek(flowMonday);

    final adopted = WeeklyMenuPlan(
      id: IsoWeekUtils.weekIdFor(
        flowUserId,
        IsoWeekUtils.weekStartOf(flowMonday),
      ),
      userId: flowUserId,
      weekStartDate: IsoWeekUtils.weekStartOf(flowMonday),
      entries: const [
        WeeklyMenuPlanEntry(
          id: 'placed-by-hand',
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'dinner-plain',
          recipeTitle: 'Pasta',
        ),
      ],
      createdAt: flowMonday,
      updatedAt: flowMonday,
    );
    h.repository.saveError = StateError('refused');

    final applying = vm.applyGeneratedMenu({
      'Middag': [_withoutOnion()],
    }, now: flowMonday);
    // Long enough for everything that does not wait on the read to have run.
    await Future<void>.delayed(Duration.zero);
    vm.adoptPlan(adopted);
    release.complete({
      _kid: {'lök'},
    });
    await applying;

    expect(vm.plan, same(adopted));
  });
}
