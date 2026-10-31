// A photo in the recipe's gallery that was taken from the source web page is
// credited to that site; the user's own photos are not.

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

const _source = 'https://www.matbloggen.se/recept/laxpudding';
const _ownPhoto =
    'https://firebasestorage.googleapis.com/v0/b/butlery-prod.firebasestorage.app/o/users%2Fu1%2Fa.jpg?alt=media';

Future<void> _pump(WidgetTester tester, List<String> imageUrls) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final recipe = RecipeFactory.build(
    id: 'gallery-credit-1',
    ingredients: ['600 g potatis'],
    instructions: ['Skiva potatisen.'],
    sourceUrl: _source,
  ).copyWith(imageUrls: imageUrls);
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
            scaledIngredients: const ['600 g potatis'],
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

  testWidgets('a borrowed photo in the gallery names its site', (
    tester,
  ) async {
    await _pump(tester, ['https://matbloggen.se/bilder/lax.jpg']);

    expect(find.text('Bild: matbloggen.se'), findsOneWidget);
  });

  testWidgets('a gallery of the user\'s own photos has no credit', (
    tester,
  ) async {
    await _pump(tester, [_ownPhoto]);

    expect(find.textContaining('Bild:'), findsNothing);
  });
}
