// BUT-1340 (SET-06): Behavioural gate for CollectionStatsView + a VM-level
// projection test driven through the new @visibleForTesting seam on
// RecipeQueryViewModel.
//
// CollectionStatsView owns a RecipeQueryViewModel and renders aggregate
// projections (total recipes, meal-type chart, popular tags, completeness).
// The view constructs the VM with the zero-arg constructor, which resolves
// UnifiedRecipeService from the ServiceLocator — so the widget test registers
// a MockUnifiedRecipeService carrying a known recipe set and asserts the
// rendered totals reflect it.
//
// The VM-level test injects the same mock directly via
// `RecipeQueryViewModel(recipeService: ...)` to prove the insights MATH
// (totalRecipes / meal-type counts) without standing up the whole DI graph —
// this is the seam the brief asked for, and it documents that the view's
// numbers come from the service, not a hardcoded stub.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';
import 'package:butlery/views/settings/collection_stats_view.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('CollectionStatsView (BUT-1340 SET-06)', () {
    late MockUnifiedRecipeService recipeService;

    setUp(() async {
      await GetIt.instance.reset();
      ServiceLocator.reset();

      recipeService = MockUnifiedRecipeService();
      recipeService.setRecipeState(
        isInitialized: true,
        currentUserId: 'u1',
        recipes: [
          RecipeFactory.build(
              id: 'r1', title: 'Pannkakor', mealType: 'Frukost'),
          RecipeFactory.build(id: 'r2', title: 'Lasagne', mealType: 'Middag'),
          RecipeFactory.build(id: 'r3', title: 'Soppa', mealType: 'Middag'),
        ],
      );

      final container = DIContainer();
      container.container
          .registerSingleton<UnifiedRecipeService>(recipeService);
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    testWidgets('hero banner shows the live total recipe count',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createLocalizedTestApp(
        wrapInScaffold: false, // view supplies its own Scaffold.
        child: const CollectionStatsView(),
      ));
      await tester.pumpAndSettle();

      // Three recipes were registered; the hero banner must surface "3".
      expect(find.text('3'), findsWidgets,
          reason: 'The total-recipes hero stat must reflect the registered '
              'recipe set (3), proving the view reads the live service.');
    });

    testWidgets('meal-type chart lists the two distinct meal types',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createLocalizedTestApp(
        wrapInScaffold: false,
        child: const CollectionStatsView(),
      ));
      await tester.pumpAndSettle();

      // Frukost x1, Middag x2 — both labels must render in the chart.
      expect(find.text('Frukost'), findsOneWidget);
      expect(find.text('Middag'), findsOneWidget);
    });
  });

  group('RecipeQueryViewModel insights via seam (BUT-1340 SET-06)', () {
    test('recipeInsights and meal-type counts reflect the injected service',
        () async {
      await GetIt.instance.reset();
      ServiceLocator.reset();
      // tryGet<AnalyticsService>/<UserService> must resolve to null cleanly
      // when nothing is registered — the seam test proves the VM works with
      // ONLY the recipe service injected.
      ServiceLocator.initialize(DIContainer());

      final service = MockUnifiedRecipeService();
      service.setRecipeState(
        isInitialized: true,
        currentUserId: 'u1',
        recipes: [
          RecipeFactory.build(id: 'r1', mealType: 'Frukost'),
          RecipeFactory.build(id: 'r2', mealType: 'Middag'),
          RecipeFactory.build(id: 'r3', mealType: 'Middag'),
        ],
      );

      final vm = RecipeQueryViewModel(recipeService: service);
      addTearDown(vm.dispose);

      expect(vm.recipeInsights.totalRecipes, 3,
          reason: 'totalRecipes must equal the injected recipe count.');

      final mealTypes = vm.getMostUsedMealTypes();
      // Middag has 2 recipes and must rank first; Frukost has 1.
      expect(mealTypes.first.key, 'Middag');
      expect(mealTypes.first.value, 2);
      expect(
        mealTypes.firstWhere((e) => e.key == 'Frukost').value,
        1,
      );

      await GetIt.instance.reset();
      ServiceLocator.reset();
    });
  });
}
