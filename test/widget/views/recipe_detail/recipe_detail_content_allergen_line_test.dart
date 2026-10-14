// An ingredient row that matches a tracked allergen the recipe is known to
// contain says so in words ("innehåller mjölk"); a recipe or a user without
// that allergen gets no such line.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_content.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/helpers/view_test_helpers.dart';

const _ingredients = ['2 dl mjölk', '1 dl vatten'];

Future<void> _pump(
  WidgetTester tester, {
  required Set<String>? userPrefs,
  required Map<String, TriState> status,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final recipe =
      RecipeFactory.build(
        id: 'allergen-line-1',
        ingredients: _ingredients,
        instructions: ['Blanda.'],
      ).copyWith(
        tagResult: TagResult(
          tags: const {},
          allergenStatus: status,
          dietaryStatus: const {},
          coverage: 1,
          generatedAt: DateTime(2026, 1, 1),
        ),
      );
  final service = MockUnifiedRecipeService();
  service.setRecipeState(recipes: [recipe], isInitialized: true);
  TestServiceLocator.registerMock<UnifiedRecipeService>(service);
  final cooking = MockFactory.createRecipeCookingService();
  TestServiceLocator.registerMock<RecipeCookingService>(cooking);
  final viewModel = RecipeDetailViewModel(
    recipe: recipe,
    recipeService: service,
    cookingService: cooking,
  );
  addTearDown(viewModel.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          child: RecipeDetailContent(
            viewModel: viewModel,
            scaledIngredients: _ingredients,
            currentPortions: 4,
            onPortionChanged: (_, _) {},
            onImageTap: (_, _) {},
            userAllergenPrefs: userPrefs,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  testWidgets('a tracked allergen the recipe contains is named on its row', (
    tester,
  ) async {
    await _pump(
      tester,
      userPrefs: {'mjölk'},
      status: const {'mjölk': TriState.contains},
    );

    // Only the milk row, not the water row.
    expect(find.text('innehåller mjölk'), findsOneWidget);
    expect(find.textContaining('innehåller'), findsOneWidget);
  });

  testWidgets('an allergen the user does not track gets no line', (
    tester,
  ) async {
    await _pump(
      tester,
      userPrefs: {'gluten'},
      status: const {'mjölk': TriState.contains},
    );

    expect(find.textContaining('innehåller'), findsNothing);
    expect(
      find.text('mjölk'),
      findsOneWidget,
      reason: 'the row is still shown',
    );
  });

  testWidgets('a tracked allergen the recipe is free of gets no line', (
    tester,
  ) async {
    await _pump(
      tester,
      userPrefs: {'mjölk'},
      status: const {'mjölk': TriState.free},
    );

    expect(find.textContaining('innehåller'), findsNothing);
  });
}
