// test/unit/viewmodels/menu/menu_generator_personalization_test.dart
//
// BUT-1321 personalisation-context plumbing. Verifies that MenuGenerator
// assembles the pantry signal and threads it into
// MenuService.generateMenuFromPrompt as a MenuScoringContext — and, crucially,
// that a missing or failing PantryService degrades to an empty context instead
// of blocking generation (the BUT-1279 "a failing/absent pantry must never
// block generation" contract, applied to the pantry-aware scoring read).
//
// (BUT-1594 removed the cuisine-affinity + cooking-skill menu nudges. BUT-1516
// added the pooled "Butlery-betyget" signal — flag-gated, fail-open — tested in
// its own group below.)
//
// Kept in its own file (like menu_generator_present_aware_test.dart) because
// the generator resolves PantryService via the global ServiceLocator; a
// dedicated file gives a clean locator without the 60+ prior tests' shared
// state.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryService extends Mock implements PantryService {}

class _MockRatingsRepository extends Mock implements RatingsRepository {}

class _MockFeatureFlagService extends Mock implements FeatureFlagService {}

UserProfile _profile() => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 'test@example.com',
  joinedAt: DateTime(2026),
  lastActiveAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator generator;
  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;

  // MenuGenerator resolves PantryService via ServiceLocator.tryGet, which reads
  // the PRODUCTION container — bridge it (same as the present-aware test).
  setUpAll(() async {
    registerFallbackValue(<Recipe>[]);
    registerFallbackValue(<String>[]);
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userService = MockUserService();

    when(() => userService.allergenPreferences).thenReturn(
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
    );
    when(() => userService.currentUserId).thenReturn('u1');
    when(() => userService.currentUserProfile).thenReturn(_profile());

    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
    );

    recipeService.setRecipeState(
      isInitialized: true,
      recipes: [
        RecipeFactory.build(id: 'r1', title: 'r1', mealType: 'middag'),
        RecipeFactory.build(id: 'r2', title: 'r2', mealType: 'middag'),
      ],
    );
    menuService.setGenerateMenuResult({
      'middag': [RecipeFactory.build(id: 'r1', title: 'r1')],
    });
  });

  tearDown(() {
    // Clear any PantryService registered during a test so the next test's
    // "unregistered" scenario is honest. TestServiceLocator and the production
    // ServiceLocator share GetIt.instance, so removing it here is sufficient.
    if (GetIt.instance.isRegistered<PantryService>()) {
      GetIt.instance.unregister<PantryService>();
    }
  });

  group('MenuGenerator - pantry context plumbing (BUT-1321)', () {
    test(
      'memoises the pantry overlap by recipe id into the scoring context',
      () async {
        final pantry = _MockPantryService();
        when(() => pantry.getMatchingRecipes(any(), any())).thenAnswer(
          (_) async => [
            (
              recipe: RecipeFactory.build(id: 'r1', title: 'r1'),
              matchPercent: 0.8,
            ),
          ],
        );
        TestServiceLocator.registerSingleton<PantryService>(pantry);

        await generator.generateMenuFromPrompt('veckomeny');

        final ctx = menuService.lastScoringContext;
        expect(ctx, isNotNull);
        expect(
          ctx!.pantryMatchByRecipeId['r1'],
          0.8,
          reason: 'the pantry overlap must be memoised by recipe id',
        );
      },
    );

    test(
      'a failing pantry read degrades to an empty pantry map, generation '
      'still completes (BUT-1279 fail-open)',
      () async {
        final pantry = _MockPantryService();
        when(
          () => pantry.getMatchingRecipes(any(), any()),
        ).thenThrow(StateError('boom — pantry read failed'));
        TestServiceLocator.registerSingleton<PantryService>(pantry);

        final result = await generator.generateMenuFromPrompt('veckomeny');

        expect(
          result,
          isNotEmpty,
          reason: 'a pantry read failure must never block menu generation',
        );
        final ctx = menuService.lastScoringContext;
        expect(ctx, isNotNull);
        expect(
          ctx!.pantryMatchByRecipeId,
          isEmpty,
          reason: 'the failed pantry read contributes no boost, not a crash',
        );
      },
    );

    test(
      'no PantryService registered -> empty pantry map, generation completes',
      () async {
        // No PantryService registered (tearDown/absence). tryGet returns null.
        final result = await generator.generateMenuFromPrompt('veckomeny');

        expect(result, isNotEmpty);
        final ctx = menuService.lastScoringContext!;
        expect(ctx.pantryMatchByRecipeId, isEmpty);
      },
    );

    test(
      'a null profile yields an empty-but-non-null context (no crash)',
      () async {
        when(() => userService.currentUserProfile).thenReturn(null);

        final result = await generator.generateMenuFromPrompt('veckomeny');

        expect(result, isNotEmpty);
        final ctx = menuService.lastScoringContext!;
        expect(ctx.pantryMatchByRecipeId, isEmpty);
      },
    );
  });

  group('MenuGenerator - pooled Butlery-betyget plumbing (BUT-1516)', () {
    late _MockRatingsRepository ratings;
    late _MockFeatureFlagService flags;

    setUp(() {
      ratings = _MockRatingsRepository();
      flags = _MockFeatureFlagService();

      // Give the pool pre-stamped poolKey hints so the plumbing doesn't hinge on
      // CanonicalPoolKey.compute succeeding over the factory's ingredients.
      final r1 = RecipeFactory.build(id: 'r1', title: 'r1', mealType: 'middag');
      r1.core.ratingPoolKey = 'v1:pool1';
      final r2 = RecipeFactory.build(id: 'r2', title: 'r2', mealType: 'middag');
      r2.core.ratingPoolKey = 'v1:pool2';
      recipeService.setRecipeState(isInitialized: true, recipes: [r1, r2]);

      // Override any real bindings the production locator may hold for the
      // duration of the group (guard: register throws on double-registration).
      if (GetIt.instance.isRegistered<FeatureFlagService>()) {
        GetIt.instance.unregister<FeatureFlagService>();
      }
      GetIt.instance.registerSingleton<FeatureFlagService>(flags);
      if (GetIt.instance.isRegistered<RatingsRepository>()) {
        GetIt.instance.unregister<RatingsRepository>();
      }
      GetIt.instance.registerSingleton<RatingsRepository>(ratings);
    });

    tearDown(() {
      if (GetIt.instance.isRegistered<FeatureFlagService>()) {
        GetIt.instance.unregister<FeatureFlagService>();
      }
      if (GetIt.instance.isRegistered<RatingsRepository>()) {
        GetIt.instance.unregister<RatingsRepository>();
      }
    });

    test(
      'flag ON: reads pooled stats and threads them into the context by recipe id',
      () async {
        when(
          () => flags.isEnabled(FeatureFlags.enablePooledRatings),
        ).thenReturn(true);
        when(() => ratings.getBulkPooledStats(any())).thenAnswer(
          (_) async => {'v1:pool1': const PooledStats(count: 40, average: 4.6)},
        );

        await generator.generateMenuFromPrompt('veckomeny');

        final ctx = menuService.lastScoringContext!;
        expect(
          ctx.pooledStatsByRecipeId['r1']?.average,
          4.6,
          reason: 'the pool stats must be keyed back by recipe id',
        );
        expect(
          ctx.pooledStatsByRecipeId.containsKey('r2'),
          isFalse,
          reason: 'a recipe whose pool has no stat doc gets no pooled entry',
        );
        verify(() => ratings.getBulkPooledStats(any())).called(1);
      },
    );

    test(
      'flag OFF: the ratings repo is never read (zero Firestore reads)',
      () async {
        when(
          () => flags.isEnabled(FeatureFlags.enablePooledRatings),
        ).thenReturn(false);

        await generator.generateMenuFromPrompt('veckomeny');

        final ctx = menuService.lastScoringContext!;
        expect(ctx.pooledStatsByRecipeId, isEmpty);
        verifyNever(() => ratings.getBulkPooledStats(any()));
      },
    );

    test(
      'flag ON but the pooled read throws: empty map, generation still completes',
      () async {
        when(
          () => flags.isEnabled(FeatureFlags.enablePooledRatings),
        ).thenReturn(true);
        when(
          () => ratings.getBulkPooledStats(any()),
        ).thenThrow(StateError('boom — pooled read failed'));

        final result = await generator.generateMenuFromPrompt('veckomeny');

        expect(
          result,
          isNotEmpty,
          reason: 'a pooled-ratings read failure must never block generation',
        );
        expect(menuService.lastScoringContext!.pooledStatsByRecipeId, isEmpty);
      },
    );
  });
}
