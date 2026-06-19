// test/widget/views/recipe_detail/recipe_detail_metadata_rating_format_test.dart
//
// recipe-detail-polish bug 22: the rating badge rendered the raw Dart double
// (`4.5`) instead of the Swedish decimal-comma form (`4,5`). The fix routes the
// value through TextFormatting.formatFractional. This pumps RecipeDetailMetadata
// alone over the prod↔test locator bridge and asserts the on-screen string.
//
// A personal recipe is used deliberately: _checkUserRating short-circuits for
// personal recipes (no social rating record), so the social service never has
// to be stubbed for this assertion.

library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_metadata.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/helpers/view_test_helpers.dart';

void main() {
  late MockUnifiedRecipeService recipeService;
  late Recipe recipe;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // Personal recipe, rating 4.5 — the RecipeFactory default rating.
    recipe = RecipeFactory.build(
      id: 'recipe-rating-1',
      title: 'Köttbullar',
      rating: 4.5,
      type: RecipeType.personal,
    );

    recipeService = MockUnifiedRecipeService();
    recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);

    TestServiceLocator.registerMock<RecipeCookingService>(
        MockFactory.createRecipeCookingService());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget localize(Widget child) {
    return MaterialApp(
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  testWidgets('rating renders with Swedish decimal comma (4,5 not 4.5)',
      (tester) async {
    final vm = RecipeDetailViewModel(recipe: recipe);
    addTearDown(vm.dispose);

    await tester.pumpWidget(localize(
      RecipeDetailMetadata(
        viewModel: vm,
        currentPortions: 4,
        isScaled: false,
      ),
    ));
    await tester.pump();

    expect(find.text('4,5'), findsOneWidget,
        reason: 'rating must use sv-SE decimal comma');
    expect(find.text('4.5'), findsNothing,
        reason: 'the raw English decimal point is the bug');
  });
}
