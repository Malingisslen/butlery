/// P8-U01 hosts: the week menu (four rows) and week generation (three).
///
/// Both are VeckomenyView (lib/views/veckomeny_view.dart): its Kalender tab
/// is the week menu, its Lista tab with the prompt and Generera is week
/// generation. The view is pumped whole, with the real MenuViewModel and
/// WeeklyMenuPlanViewModel over mocked services. The empty week's BEVIS,
/// calendar_cells.dart, is the calendar's empty slots inside the same view.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/views/veckomeny_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../state_host.dart';

class _MockPlanService extends Mock implements WeeklyMenuPlanService {
  // BUT-2215: the week menu listens from its constructor.
  @override
  Stream<String?> get weekWrites => const Stream.empty();
}

class _MockMenuService extends Mock implements MenuService {}

class _MockPersistence extends Mock implements PersistenceService {}

class _MockListGenerator extends Mock implements MenuShoppingListGenerator {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _me = 'test-user-123';

List<Recipe> _library() => [
  RecipeFactory.build(id: 'r1', title: 'Linsgryta med kokos'),
  RecipeFactory.build(id: 'r2', title: 'Ugnsbakad lax med dill'),
  RecipeFactory.build(id: 'r3', title: 'Krämig svamppasta'),
];

WeeklyMenuPlan _week({required bool filled}) {
  final plan = WeeklyMenuPlan.empty(userId: _me, date: clock.now());
  if (!filled) return plan;
  return plan.copyWith(
    entries: [
      for (final (day, id, title) in [
        (DayOfWeek.mon, 'r1', 'Linsgryta med kokos'),
        (DayOfWeek.tue, 'r2', 'Ugnsbakad lax med dill'),
        (DayOfWeek.thu, 'r3', 'Krämig svamppasta'),
      ])
        WeeklyMenuPlanEntry.create(
          day: day,
          slot: MealSlot.middag,
          recipeId: id,
          recipeTitle: title,
        ),
    ],
  );
}

/// The week menu in [mode] ('kalender' or 'lista'), reading [week].
///
/// With [libraryLoading] the recipe library has not finished loading, so a
/// generation that starts waits for it (MenuGenerator
/// .ensureRecipeServiceInitialized) and the view stays in its planning
/// state.
Widget _veckomeny(
  String mode, {
  Future<WeeklyMenuPlanRead> Function()? week,
  bool libraryLoading = false,
}) {
  final recipes = MockUnifiedRecipeService()
    ..setRecipeState(recipes: _library(), isInitialized: !libraryLoading);
  when(recipes.initialize).thenAnswer((_) => Completer<void>().future);
  TestServiceLocator.registerMock<UnifiedRecipeService>(recipes);
  final plans = _MockPlanService();
  when(() => plans.readWeek(any())).thenAnswer(
    (_) =>
        week?.call() ??
        Future.value(
          WeeklyMenuPlanRead(plan: _week(filled: true), readFailed: false),
        ),
  );
  when(() => plans.overflowTrayOwnerId).thenReturn(_me);
  TestServiceLocator.registerMock<WeeklyMenuPlanService>(plans);
  TestServiceLocator.registerFactory<WeeklyMenuPlanViewModel>(
    () => WeeklyMenuPlanViewModel(
      service: plans,
      recipeService: recipes,
      shoppingListGenerator: _MockListGenerator(),
    ),
  );
  final menus = _MockMenuService();
  when(
    () => menus.generateMenuFromPrompt(
      any(),
      any(),
      recentlyUsedRecipeIds: any(named: 'recentlyUsedRecipeIds'),
      scoringContext: any(named: 'scoringContext'),
    ),
  ).thenAnswer((_) async => const {});
  when(() => menus.parsePrompt(any())).thenAnswer((_) async => null);
  TestServiceLocator.registerMock<MenuService>(menus);
  final analytics = _MockAnalytics();
  when(
    () => analytics.logMenuGenerationStarted(
      promptLength: any(named: 'promptLength'),
    ),
  ).thenAnswer((_) async {});
  TestServiceLocator.registerMock<AnalyticsService>(analytics);
  final persistence = _MockPersistence();
  when(persistence.getVeckomenyViewMode).thenAnswer((_) async => mode);
  when(
    () => persistence.setVeckomenyViewMode(any()),
  ).thenAnswer((_) async {});
  TestServiceLocator.registerMock<PersistenceService>(persistence);
  return const VeckomenyView();
}

/// Types a week description, the way generation starts.
Future<void> _describeWeek(WidgetTester tester, HostContext ctx) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.enterText(
    find.byType(TextField).first,
    'Vegetariskt i veckan, snabba middagar',
  );
  await tester.pump();
}

final menuHosts = <String, StateHost>{
  'veckomeny::DEFAULT': StateHost(
    build: (ctx) async => _veckomeny('kalender'),
  ),
  'veckomeny::EMPTY': StateHost(
    build: (ctx) async => _veckomeny(
      'kalender',
      week: () async =>
          WeeklyMenuPlanRead(plan: _week(filled: false), readFailed: false),
    ),
  ),
  'veckomeny::LOADING': StateHost(
    build: (ctx) async => _veckomeny(
      'kalender',
      week: () => Completer<WeeklyMenuPlanRead>().future,
    ),
  ),
  'veckomeny::OFFLINE': StateHost(
    online: false,
    build: (ctx) async => _veckomeny('kalender'),
  ),
  'veckogenerering::DEFAULT': StateHost(
    build: (ctx) async => _veckomeny('lista'),
    reach: _describeWeek,
  ),
  'veckogenerering::LOADING': StateHost(
    build: (ctx) async => _veckomeny('lista', libraryLoading: true),
    reach: (tester, ctx) async {
      await _describeWeek(tester, ctx);
      final generate = find.byKey(const ValueKey('test-veckomeny-generate'));
      await tester.ensureVisible(generate);
      await tester.tap(
        find.descendant(of: generate, matching: find.byType(InkWell)).first,
      );
      await tester.pump();
    },
  ),
  'veckogenerering::OFFLINE': StateHost(
    online: false,
    build: (ctx) async => _veckomeny('lista'),
    reach: _describeWeek,
  ),
};
