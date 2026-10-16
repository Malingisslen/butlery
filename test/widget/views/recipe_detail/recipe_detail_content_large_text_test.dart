// At large text every ingredient row puts the amount above the name, so the
// rows read the same; at normal size the amount stays beside the name.

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

Future<void> _pump(
  WidgetTester tester, {
  required double textScale,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final recipe = RecipeFactory.build(
    id: 'allergen-line-1',
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
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
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

  testWidgets('the amount sits beside the name at normal text size', (
    tester,
  ) async {
    await _pump(tester, textScale: 1);

    final amount = tester.getTopLeft(find.text('2 dl'));
    final name = tester.getTopLeft(find.text('mjölk'));
    expect(name.dx, greaterThan(amount.dx));
    expect(name.dy, closeTo(amount.dy, 4));
  });

  testWidgets('the amount sits above the name at 200 % text', (tester) async {
    await _pump(tester, textScale: 2);

    final amount = tester.getBottomLeft(find.text('2 dl'));
    final name = tester.getTopLeft(find.text('mjölk'));
    expect(name.dx, tester.getTopLeft(find.text('2 dl')).dx);
    expect(name.dy, greaterThanOrEqualTo(amount.dy));
  });
}
