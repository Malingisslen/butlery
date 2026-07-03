// test/unit/views/recipe_detail/recipe_detail_actions_scaling_test.dart
//
// BUT-1322: RecipeDetailActions owns the portion state behind the recipe
// detail view AND the add-to-shopping handlers (generateShoppingListFromRecipe
// / showAddToCartConfirmation read `currentPortions`). It resolves the
// household-size default itself — a separate copy of the logic in
// CookingModeViewModel — so the cooking-mode tests do NOT cover it.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_actions.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

class _MockUserService extends Mock implements UserService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late Recipe testRecipe;

  setUpAll(() {
    // RecipeDetailActions resolves UserService/AnalyticsService via the
    // production ServiceLocator (bridged to GetIt).
    ServiceLocator.initialize(DIContainer());
  });

  setUp(() {
    testRecipe = RecipeFactory.build(
      id: 'recipe-1',
      title: 'Test Recipe',
      portions: 4,
      ingredients: ['2 dl mjol', '3 st agg', '1 tsk salt'],
      instructions: ['Step 1'],
    );
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) {
      getIt.unregister<UserService>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  void registerUserService(int? size) {
    final mockUser = _MockUserService();
    when(() => mockUser.currentUserProfile).thenReturn(
      UserProfile(
        uid: 'u1',
        displayName: 'Test',
        email: 't@t.se',
        joinedAt: DateTime(2024, 1, 1),
        lastActiveAt: DateTime(2024, 1, 1),
        householdSize: size,
      ),
    );
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) {
      getIt.unregister<UserService>();
    }
    getIt.registerSingleton<UserService>(mockUser);
  }

  _MockAnalyticsService registerAnalytics() {
    final mock = _MockAnalyticsService();
    when(
      () => mock.logPortionScalingApplied(
        recipeId: any(named: 'recipeId'),
        source: any(named: 'source'),
        fromPortions: any(named: 'fromPortions'),
        toPortions: any(named: 'toPortions'),
      ),
    ).thenAnswer((_) async {});
    final getIt = GetIt.instance;
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(mock);
    return mock;
  }

  group('RecipeDetailActions.initializeScaling (BUT-1322)', () {
    test('household default pre-scales the initial state that feeds '
        'add-to-shopping, and logs it as household_default', () {
      registerUserService(6);
      final analytics = registerAnalytics();

      final actions = RecipeDetailActions()..initializeScaling(testRecipe);

      // currentPortions is what generateShoppingListFromRecipe /
      // showAddToCartConfirmation hand to the shopping handlers.
      expect(actions.currentPortions, 6);
      // '2 dl mjol' scaled from 4 → 6 portions (×1.5) = '3 dl mjol'.
      expect(actions.scaledIngredients.first, contains('3'));
      expect(actions.scaledIngredients.first, contains('dl'));

      verify(
        () => analytics.logPortionScalingApplied(
          recipeId: 'recipe-1',
          source: 'household_default',
          fromPortions: 4,
          toPortions: 6,
        ),
      ).called(1);
    });

    test('no UserService registered keeps the pre-BUT-1322 init', () {
      final actions = RecipeDetailActions()..initializeScaling(testRecipe);

      expect(actions.currentPortions, 4);
      expect(actions.scaledIngredients, testRecipe.ingredients);
    });

    test('household equal to recipe portions: no scaling and no bogus '
        'analytics event', () {
      registerUserService(4);
      final analytics = registerAnalytics();

      final actions = RecipeDetailActions()..initializeScaling(testRecipe);

      expect(actions.currentPortions, 4);
      expect(actions.scaledIngredients, testRecipe.ingredients);
      // The scaling event is a per-open monetization signal — a no-op open
      // must not pollute it with from==to noise.
      verifyNever(
        () => analytics.logPortionScalingApplied(
          recipeId: any(named: 'recipeId'),
          source: any(named: 'source'),
          fromPortions: any(named: 'fromPortions'),
          toPortions: any(named: 'toPortions'),
        ),
      );
    });

    test('manual override logs once per open and skips the unit-toggle '
        're-fire with unchanged portions', () {
      registerUserService(6);
      final analytics = registerAnalytics();
      final actions = RecipeDetailActions()..initializeScaling(testRecipe);
      clearInteractions(analytics); // drop the household_default open event

      // The unit-conversion toggle re-fires the callback with UNCHANGED
      // portions — that is not an override and must not log.
      actions.onPortionChanged(6, const ['2 dl mjol']);
      verifyNever(
        () => analytics.logPortionScalingApplied(
          recipeId: any(named: 'recipeId'),
          source: any(named: 'source'),
          fromPortions: any(named: 'fromPortions'),
          toPortions: any(named: 'toPortions'),
        ),
      );

      // First real change logs the override (from the household default)...
      actions.onPortionChanged(2, const ['1 dl mjol']);
      // ...further changes in the same open do not (per-open signal, not a
      // tap counter).
      actions.onPortionChanged(8, const ['4 dl mjol']);

      verify(
        () => analytics.logPortionScalingApplied(
          recipeId: 'recipe-1',
          source: 'manual_override',
          fromPortions: 6,
          toPortions: 2,
        ),
      ).called(1);
      verifyNever(
        () => analytics.logPortionScalingApplied(
          recipeId: any(named: 'recipeId'),
          source: any(named: 'source'),
          fromPortions: any(named: 'fromPortions'),
          toPortions: 8,
        ),
      );
      expect(actions.currentPortions, 8);
      expect(actions.scaledIngredients, const ['4 dl mjol']);
    });

    test('a recipe with NO portion count is never auto-scaled — amounts stay '
        'as printed and no analytics fires (BUT-1322 review)', () {
      registerUserService(6);
      final analytics = registerAnalytics();
      final noPortions = RecipeFactory.build(
        id: 'recipe-2',
        title: 'No portions',
        portions: null,
        ingredients: const ['2 dl mjol', '3 st agg'],
        instructions: const ['Step 1'],
      );

      final actions = RecipeDetailActions()..initializeScaling(noPortions);

      // A null base has no meaningful "per N people" semantics — auto-applying
      // household=6 with a fabricated base of 1 would sextuple every amount.
      expect(
        actions.currentPortions,
        1,
        reason: 'null-portions recipe must not jump to the household size',
      );
      expect(actions.scaledIngredients, noPortions.ingredients);
      verifyNever(
        () => analytics.logPortionScalingApplied(
          recipeId: any(named: 'recipeId'),
          source: any(named: 'source'),
          fromPortions: any(named: 'fromPortions'),
          toPortions: any(named: 'toPortions'),
        ),
      );
    });
  });
}
