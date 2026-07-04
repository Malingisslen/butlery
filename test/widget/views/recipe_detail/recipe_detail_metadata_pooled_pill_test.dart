// test/widget/views/recipe_detail/recipe_detail_metadata_pooled_pill_test.dart
//
// Increment 6b (AC7) for the DETAIL page: the "Butlery-betyget" community pill.
// Pumps RecipeDetailMetadata over the prod↔test locator bridge and asserts the
// pooled section's four states:
//   • flag on + pool clears the floor (n>=5) → green community pill WITH count,
//     plus the labelled "alla i ditt kök" household context pill;
//   • flag on + below the floor (n<5)        → no community pill (fallback);
//   • flag OFF                                → no fetch, no community pill;
//   • flag on + read error                   → no community pill (never blank).
//
// A personal recipe is used so _checkUserRating short-circuits (no social stub).

library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
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

class _MockFeatureFlagService extends Mock implements FeatureFlagService {}

void main() {
  late MockUnifiedRecipeService recipeService;
  late RatingsRepository ratingsRepo;
  late Recipe recipe;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // Personal recipe, rating 4.5, with a pool-key hint so the read path skips
    // on-the-fly key computation and reads the stubbed aggregate directly.
    recipe = RecipeFactory.build(
      id: 'pooled-detail-1',
      title: 'Köttbullar',
      rating: 4.5,
      type: RecipeType.personal,
    );
    recipe.core.ratingPoolKey = 'v1:kottbullar';

    recipeService = MockUnifiedRecipeService();
    recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);
    TestServiceLocator.registerMock<RecipeCookingService>(
      MockFactory.createRecipeCookingService(),
    );

    ratingsRepo = GetIt.instance<RatingsRepository>();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  /// Register a FeatureFlagService whose pooled flag reads [enabled].
  void setFlag({required bool enabled}) {
    final getIt = GetIt.instance;
    final flags = _MockFeatureFlagService();
    when(
      () => flags.isEnabled(FeatureFlags.enablePooledRatings),
    ).thenReturn(enabled);
    if (getIt.isRegistered<FeatureFlagService>()) {
      getIt.unregister<FeatureFlagService>();
    }
    getIt.registerSingleton<FeatureFlagService>(flags);
  }

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

  Future<void> pump(WidgetTester tester) async {
    final vm = RecipeDetailViewModel(recipe: recipe);
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      localize(
        RecipeDetailMetadata(
          viewModel: vm,
          currentPortions: 4,
          isScaled: false,
        ),
      ),
    );
    // Let the async pooled-stats fetch (thenAnswer future) resolve + rebuild.
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'flag on + n>=5 shows the community pill with count and the household label',
    (tester) async {
      // A real household verdict so the "alla i ditt kök" context pill renders
      // (it shows only when the household has rated together — not a fallback).
      recipe.core.familyAverage = 4.0;
      recipe.core.familyRatingCount = 3;
      setFlag(enabled: true);
      when(() => ratingsRepo.getPooledStats(any())).thenAnswer(
        (_) async => const PooledStats(count: 12, average: 4.3),
      );

      await pump(tester);

      // Community pill carries the vote count ("betyg" is unique to it).
      expect(find.textContaining('12 betyg'), findsOneWidget);
      // Both sections are labelled.
      expect(find.text('butlery-betyget'), findsOneWidget);
      expect(find.text('alla i ditt kök'), findsOneWidget);
    },
  );

  testWidgets('flag on + below the floor (n<5) shows no community pill', (
    tester,
  ) async {
    setFlag(enabled: true);
    when(() => ratingsRepo.getPooledStats(any())).thenAnswer(
      (_) async => const PooledStats(count: 3, average: 4.3),
    );

    await pump(tester);

    // Narrowed to the count shape (leading space) so a sibling "Betygsätt som
    // familj" button can never trip this guard.
    expect(find.textContaining(' betyg'), findsNothing);
    expect(find.text('butlery-betyget'), findsNothing);
  });

  testWidgets('flag OFF never fetches and shows no community pill', (
    tester,
  ) async {
    setFlag(enabled: false);
    when(() => ratingsRepo.getPooledStats(any())).thenAnswer(
      (_) async => const PooledStats(count: 12, average: 4.3),
    );

    await pump(tester);

    expect(find.text('butlery-betyget'), findsNothing);
    verifyNever(() => ratingsRepo.getPooledStats(any()));
  });

  testWidgets('flag on + read error falls back to no pill (never blank)', (
    tester,
  ) async {
    setFlag(enabled: true);
    when(
      () => ratingsRepo.getPooledStats(any()),
    ).thenThrow(Exception('offline'));

    await pump(tester);

    expect(find.text('butlery-betyget'), findsNothing);
    // The per-copy star row is untouched — its 4,5 still renders.
    expect(find.text('4,5'), findsOneWidget);
  });
}
