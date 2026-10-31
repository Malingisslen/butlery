// On a phone the system bars put insets on MediaQuery. The ingredient and
// instruction lists must not add them as padding above their first row.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
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

Future<double> _gapBelowHeaders(
  WidgetTester tester, {
  required double topInset,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final recipe = RecipeFactory.build(
    id: 'insets-1',
    ingredients: _ingredients,
    instructions: ['Blanda.'],
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
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(top: topInset, bottom: topInset),
        ),
        child: app!,
      ),
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

  final ingredientGap =
      tester.getTopLeft(find.text('2 dl')).dy -
      tester.getBottomLeft(find.text('Ingredienser')).dy;
  final instructionGap =
      tester.getTopLeft(find.text('Blanda.')).dy -
      tester.getBottomLeft(find.text('Instruktioner')).dy;
  return ingredientGap > instructionGap ? ingredientGap : instructionGap;
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

  testWidgets('system insets do not open a gap under the section headers', (
    tester,
  ) async {
    final withoutInsets = await _gapBelowHeaders(tester, topInset: 0);
    final withInsets = await _gapBelowHeaders(tester, topInset: 80);
    expect(withInsets, closeTo(withoutInsets, 1));
  });
}
