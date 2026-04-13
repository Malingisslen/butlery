/// Unit tests for [WeeklyMenuPlanViewModel].
///
/// Focused on the resolveForNavigation method (BUT-360).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockWeeklyMenuPlanService extends Mock
    implements WeeklyMenuPlanService {}

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

void main() {
  group('WeeklyMenuPlanViewModel', () {
    late WeeklyMenuPlanViewModel viewModel;
    late _MockWeeklyMenuPlanService mockService;
    late _MockUnifiedRecipeService mockRecipeService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      mockService = _MockWeeklyMenuPlanService();
      mockRecipeService = _MockUnifiedRecipeService();

      viewModel = WeeklyMenuPlanViewModel(
        service: mockService,
        recipeService: mockRecipeService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    group('resolveForNavigation', () {
      test('returns recipe when found in service', () {
        final recipe = Recipe.personal(
          title: 'Test Recipe',
          description: '',
          ingredients: const [],
          instructions: const [],
          mealType: 'middag',
        );
        when(() => mockRecipeService.getRecipeById(recipe.id))
            .thenReturn(recipe);

        final result = viewModel.resolveForNavigation(recipe.id);

        expect(result, recipe);
        verify(() => mockRecipeService.getRecipeById(recipe.id)).called(1);
      });

      test('returns null when recipe not found', () {
        when(() => mockRecipeService.getRecipeById('deleted-id'))
            .thenReturn(null);

        final result = viewModel.resolveForNavigation('deleted-id');

        expect(result, isNull);
      });
    });
  });
}
