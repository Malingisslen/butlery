// The tags box of the recipe detail says the tags are uncertain when too few
// ingredients are known.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/tag_result.dart';
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
  required double coverage,
  required List<String> unknown,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final recipe =
      RecipeFactory.build(
        id: 'uncertain-tags-1',
        ingredients: _ingredients,
        instructions: ['Blanda.'],
      ).copyWith(
        tagResult: TagResult(
          tags: const {'gryta'},
          allergenStatus: const {},
          dietaryStatus: const {},
          coverage: coverage,
          unknownIngredients: unknown,
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

  testWidgets('a low-coverage recipe says its tags are uncertain', (
    tester,
  ) async {
    await _pump(tester, coverage: 0.5, unknown: ['okänd 1', 'okänd 2']);

    expect(find.text('Osäkra taggar, 2 ingredienser okända'), findsOneWidget);
  });

  testWidgets('a fully known recipe gets no uncertainty line', (tester) async {
    await _pump(tester, coverage: 1.0, unknown: const []);

    expect(find.textContaining('Osäkra taggar'), findsNothing);
  });
}
