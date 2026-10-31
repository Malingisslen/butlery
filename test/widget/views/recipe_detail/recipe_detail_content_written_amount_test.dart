// The amount column shows "2-3" and "ca 500 g" as the recipe wrote them,
// not only the number the parser reads from them, and nothing for a line
// that names no amount.

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

const _ingredients = ['2-3 tomater', 'ca 500 g potatis', '2 dl mjölk'];

Future<void> _pump(
  WidgetTester tester, {
  List<String> ingredients = _ingredients,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final recipe = RecipeFactory.build(
    id: 'allergen-line-1',
    ingredients: ingredients,
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
      home: Scaffold(
        body: SingleChildScrollView(
          child: RecipeDetailContent(
            viewModel: viewModel,
            scaledIngredients: ingredients,
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

  testWidgets('a range or an approximate amount is shown as written', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('2-3'), findsOneWidget);
    expect(find.text('ca 500 g'), findsOneWidget);
    expect(find.text('2 dl'), findsOneWidget);
  });

  testWidgets('a line without an amount shows no "1"', (tester) async {
    await _pump(tester, ingredients: ['salt', '1 ägg']);

    Finder amountIn(String name) => find.descendant(
      of: find
          .ancestor(of: find.text(name), matching: find.byType(LayoutBuilder))
          .first,
      matching: find.text('1'),
    );

    expect(find.text('salt'), findsOneWidget);
    expect(amountIn('salt'), findsNothing);
    expect(amountIn('ägg'), findsOneWidget);
  });

  testWidgets('a common fraction is shown as a fraction', (tester) async {
    await _pump(tester, ingredients: ['3/4 dl ströbröd', '1,5 dl mjölk']);

    expect(find.text('¾ dl'), findsOneWidget);
    expect(find.text('1 ½ dl'), findsOneWidget);
    expect(find.textContaining('0,75'), findsNothing);
  });
}
