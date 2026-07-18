// test/unit/viewmodels/cooking_mode_viewmodel_test.dart

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';
import 'package:butlery/models/recipe/ingredient_display_row.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/trackers/recipe_events_tracker.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';

import '../../infrastructure/factories/recipe_factory.dart';

class MockPersistenceService extends Mock implements PersistenceService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockRecipeEventsTracker extends Mock implements RecipeEventsTracker {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersistenceService mockPersistence;
  late Recipe testRecipe;

  setUpAll(() {
    // Production ServiceLocator bridge — CookingModeViewModel uses ServiceLocator.get<>()
    final testContainer = DIContainer();
    ServiceLocator.initialize(testContainer);
  });

  setUp(() {
    mockPersistence = MockPersistenceService();

    // Register mock PersistenceService with GetIt (shared by DIContainer)
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
    getIt.registerSingleton<PersistenceService>(mockPersistence);

    // Default: no saved font scale
    when(() => mockPersistence.getInt(any())).thenAnswer((_) async => null);
    when(() => mockPersistence.setInt(any(), any())).thenAnswer((_) async {});

    testRecipe = RecipeFactory.build(
      id: 'recipe-1',
      title: 'Test Recipe',
      portions: 4,
      ingredients: ['2 dl mjol', '3 st agg', '1 tsk salt'],
      instructions: ['Step 1', 'Step 2', 'Step 3'],
    );
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
  });

  group('CookingModeViewModel - Initial State', () {
    test('should initialize with recipe portions and step 0', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      expect(vm.currentPortions, 4);
      expect(vm.originalPortions, 4);
      expect(vm.currentStepIndex, 0);
      expect(vm.totalSteps, 3);
      expect(vm.title, 'Test Recipe');
      expect(vm.scaleFactor, 1.0);

      vm.dispose();
    });

    test('should default portions to 1 when recipe has no portions', () {
      final noPortionsRecipe = RecipeFactory.build(
        id: 'np-1',
        portions: null,
        instructions: ['Step 1'],
      );
      final vm = CookingModeViewModel(recipe: noPortionsRecipe);

      expect(vm.currentPortions, 1);
      expect(vm.originalPortions, 1);

      vm.dispose();
    });

    test('should load font scale from persistence on init', () async {
      when(
        () => mockPersistence.getInt('butlery_cooking_font_scale'),
      ).thenAnswer((_) async => 2); // index 2 = 1.5

      final vm = CookingModeViewModel(recipe: testRecipe);

      // Allow async _loadFontScale to complete
      await Future.delayed(Duration.zero);

      expect(vm.fontScale, 1.5);

      vm.dispose();
    });

    test(
      'should default to fontScale 1.0 when persistence returns null',
      () async {
        when(() => mockPersistence.getInt(any())).thenAnswer((_) async => null);

        final vm = CookingModeViewModel(recipe: testRecipe);
        await Future.delayed(Duration.zero);

        expect(vm.fontScale, 1.0);

        vm.dispose();
      },
    );
  });

  group('CookingModeViewModel - Step Navigation', () {
    test('should advance to next step', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.nextStep();

      expect(vm.currentStepIndex, 1);
      expect(vm.hasPreviousStep, true);
      expect(vm.hasNextStep, true);
      expect(notifyCount, greaterThanOrEqualTo(1));

      vm.dispose();
    });

    test('should go back to previous step', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      vm.nextStep();
      vm.nextStep();

      vm.previousStep();

      expect(vm.currentStepIndex, 1);

      vm.dispose();
    });

    test('should not go below step 0', () {
      // Behavior: pressing "previous" at step 0 does nothing
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.previousStep();

      expect(vm.currentStepIndex, 0);
      expect(vm.hasPreviousStep, false);
      expect(notifyCount, 0);

      vm.dispose();
    });

    test('should not go above max step', () {
      // Behavior: pressing "next" at the last step does nothing
      final vm = CookingModeViewModel(recipe: testRecipe);
      vm.nextStep(); // 1
      vm.nextStep(); // 2 (last)

      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.nextStep(); // should be no-op

      expect(vm.currentStepIndex, 2);
      expect(vm.hasNextStep, false);
      expect(notifyCount, 0);

      vm.dispose();
    });

    test('should jump to a specific step with goToStep', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.goToStep(2);

      expect(vm.currentStepIndex, 2);
      expect(vm.hasNextStep, false);
      expect(vm.hasPreviousStep, true);

      vm.dispose();
    });

    test('should ignore goToStep with out-of-range index', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.goToStep(-1);
      expect(vm.currentStepIndex, 0);

      vm.goToStep(100);
      expect(vm.currentStepIndex, 0);

      vm.dispose();
    });
  });

  group('CookingModeViewModel - Portion Scaling', () {
    test('should update portions within valid range', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.updatePortions(8);

      expect(vm.currentPortions, 8);
      expect(vm.scaleFactor, 2.0);
      expect(notifyCount, greaterThanOrEqualTo(1));

      vm.dispose();
    });

    test('should reject portions below minimum (1)', () {
      // Behavior: 0 or negative portions are invalid
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.updatePortions(0);

      expect(vm.currentPortions, 4); // unchanged

      vm.dispose();
    });

    test('should reject portions above maximum (50)', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.updatePortions(51);

      expect(vm.currentPortions, 4); // unchanged

      vm.dispose();
    });

    test('should accept boundary values (1 and 50)', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.updatePortions(1);
      expect(vm.currentPortions, 1);

      vm.updatePortions(50);
      expect(vm.currentPortions, 50);

      vm.dispose();
    });

    test('should not notify when portions unchanged', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.updatePortions(4); // same as original

      expect(notifyCount, 0);

      vm.dispose();
    });

    test('scales via persisted structured amounts (BUT-444) — '
        'string-unscalable line still scales', () {
      // The v1 string path mangles "ca 2,5 dl ..." (quantity coerced to 1.0,
      // "ca" dropped → '2 dl vispgrädde' at factor 2). Only the structured
      // route (scaleEntries over recipe.structuredIngredients) scales it
      // correctly — this test fails if updatePortions reverts to
      // scaleIngredients(recipe.ingredients, ...).
      // Recipe.copyWith doesn't forward structuredIngredients (only
      // RecipeCore.copyWith does), so construct the core directly.
      final structuredRecipe = Recipe(
        core: RecipeCore(
          id: 'recipe-structured',
          title: 'Pannkakor',
          description: '',
          portions: 4,
          ingredients: ['ca 2,5 dl vispgrädde'],
          structuredIngredients: const [
            RecipeIngredient(
              amount: 2.5,
              unit: 'dl',
              name: 'vispgrädde',
              raw: 'ca 2,5 dl vispgrädde',
            ),
          ],
          instructions: ['Vispa'],
          mealType: 'Middag',
        ),
        type: RecipeType.personal,
      );
      final vm = CookingModeViewModel(recipe: structuredRecipe);

      vm.updatePortions(8); // factor 2.0

      expect(
        vm.scaledIngredients.single,
        '5 dl vispgrädde',
        reason:
            'seeing "2 dl vispgrädde" here means cooking mode fell '
            'back to the string path',
      );

      vm.dispose();
    });

    test('should rescale ingredients when portions change', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      // Original ingredients are '2 dl mjol', '3 st agg', '1 tsk salt'
      // After doubling portions: ingredients should change
      vm.updatePortions(8);

      expect(vm.scaledIngredients, isNotEmpty);
      // Just verify it changed from original — the exact scaling is PortionScalerLogic's responsibility
      expect(vm.scaledIngredients, isNot(equals(testRecipe.ingredients)));

      vm.dispose();
    });
  });

  group('CookingModeViewModel - ingredientRows (section grouping)', () {
    Recipe sectionedRecipe() => Recipe(
      core: RecipeCore(
        id: 'sectioned',
        title: 'Kanelbullar',
        description: '',
        portions: 4,
        ingredients: const ['5 dl vetemjöl', '75 g smör'],
        structuredIngredients: const [
          RecipeIngredient(
            amount: 5,
            unit: 'dl',
            name: 'vetemjöl',
            raw: '5 dl vetemjöl',
            section: 'Deg',
          ),
          RecipeIngredient(
            amount: 75,
            unit: 'g',
            name: 'smör',
            raw: '75 g smör',
            section: 'Fyllning',
          ),
        ],
        instructions: const ['Baka'],
        mealType: 'Fika',
      ),
      type: RecipeType.personal,
    );

    test('builds heading + line rows from the recipe sections', () {
      final vm = CookingModeViewModel(recipe: sectionedRecipe());

      final headings = vm.ingredientRows
          .whereType<IngredientHeadingRow>()
          .map((r) => r.label)
          .toList();
      expect(headings, ['Deg', 'Fyllning']);
      expect(vm.ingredientRows.whereType<IngredientLineRow>(), hasLength(2));

      vm.dispose();
    });

    test(
      'rebuilds rows with rescaled text on portion change (headings kept)',
      () {
        final vm = CookingModeViewModel(recipe: sectionedRecipe());

        vm.updatePortions(8); // factor 2.0 (scaler may normalize units)

        final lines = vm.ingredientRows
            .whereType<IngredientLineRow>()
            .map((r) => r.text)
            .toList();
        expect(
          lines.first,
          isNot('5 dl vetemjöl'),
          reason: 'row text is rescaled from the original, not stale',
        );
        expect(
          lines.first,
          contains('vetemjöl'),
          reason: 'still the same ingredient, just rescaled',
        );
        // Headings survive the rebuild.
        expect(
          vm.ingredientRows.whereType<IngredientHeadingRow>().map(
            (r) => r.label,
          ),
          ['Deg', 'Fyllning'],
        );

        vm.dispose();
      },
    );

    test('a flat recipe yields line rows only (no headings)', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      expect(vm.ingredientRows.whereType<IngredientHeadingRow>(), isEmpty);
      expect(
        vm.ingredientRows.whereType<IngredientLineRow>(),
        hasLength(testRecipe.ingredients.length),
      );
      vm.dispose();
    });
  });

  group('CookingModeViewModel - Font Scale Cycling', () {
    test(
      'should cycle through font scale options: 1.0 -> 1.25 -> 1.5 -> 1.0',
      () {
        final vm = CookingModeViewModel(recipe: testRecipe);

        expect(vm.fontScale, 1.0);

        vm.cycleFontScale();
        expect(vm.fontScale, 1.25);

        vm.cycleFontScale();
        expect(vm.fontScale, 1.5);

        vm.cycleFontScale();
        expect(vm.fontScale, 1.0); // wraps around

        vm.dispose();
      },
    );

    test('should persist font scale index to PersistenceService', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.cycleFontScale(); // 1.0 -> 1.25 (index 1)

      verify(
        () => mockPersistence.setInt('butlery_cooking_font_scale', 1),
      ).called(1);

      vm.dispose();
    });

    test('should notify listeners on font scale change', () {
      final vm = CookingModeViewModel(recipe: testRecipe);
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.cycleFontScale();

      expect(notifyCount, greaterThanOrEqualTo(1));

      vm.dispose();
    });
  });

  group('CookingModeViewModel - Computed Properties', () {
    test('should expose recipe instructions directly', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      expect(vm.instructions, ['Step 1', 'Step 2', 'Step 3']);

      vm.dispose();
    });

    test('should report correct hasNextStep and hasPreviousStep', () {
      final singleStepRecipe = RecipeFactory.build(
        id: 'single-1',
        instructions: ['Only step'],
      );
      final vm = CookingModeViewModel(recipe: singleStepRecipe);

      expect(vm.hasNextStep, false);
      expect(vm.hasPreviousStep, false);
      expect(vm.totalSteps, 1);

      vm.dispose();
    });

    test('should calculate scale factor correctly', () {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.updatePortions(2);
      expect(vm.scaleFactor, 0.5);

      vm.updatePortions(12);
      expect(vm.scaleFactor, 3.0);

      vm.dispose();
    });
  });

  // BUT-802 HIGH-PA4: cooking-mode analytics lifecycle. Tests verify the
  // viewmodel emits the documented events at the documented lifecycle points,
  // not the analytics-service implementation (that's covered in the tracker
  // test). The `try`/`catchError` swallowing in the viewmodel means a missing
  // tracker registration won't fail the test silently — we register one
  // explicitly per test so verify() can assert call shape.
  group('CookingModeViewModel - BUT-802 analytics', () {
    late _MockAnalyticsService mockAnalytics;
    late _MockRecipeEventsTracker mockTracker;

    setUp(() {
      mockAnalytics = _MockAnalyticsService();
      mockTracker = _MockRecipeEventsTracker();
      when(() => mockAnalytics.recipe).thenReturn(mockTracker);
      when(
        () => mockTracker.logCookingSessionStarted(
          recipeId: any(named: 'recipeId'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockTracker.logCookingStepAdvanced(
          recipeId: any(named: 'recipeId'),
          sessionId: any(named: 'sessionId'),
          fromStep: any(named: 'fromStep'),
          toStep: any(named: 'toStep'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockTracker.logCookingSessionCompleted(
          recipeId: any(named: 'recipeId'),
          sessionId: any(named: 'sessionId'),
          durationSec: any(named: 'durationSec'),
          stepsViewed: any(named: 'stepsViewed'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockTracker.logCookingSessionAbandoned(
          recipeId: any(named: 'recipeId'),
          sessionId: any(named: 'sessionId'),
          durationSec: any(named: 'durationSec'),
          lastStep: any(named: 'lastStep'),
        ),
      ).thenAnswer((_) async {});

      final getIt = GetIt.instance;
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
      getIt.registerSingleton<AnalyticsService>(mockAnalytics);
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
    });

    test(
      'onEnter fires cooking_session_started with recipe id + uuid',
      () async {
        final vm = CookingModeViewModel(recipe: testRecipe);

        await vm.onEnter();

        final captured = verify(
          () => mockTracker.logCookingSessionStarted(
            recipeId: captureAny(named: 'recipeId'),
            sessionId: captureAny(named: 'sessionId'),
          ),
        ).captured;
        expect(captured[0], 'recipe-1');
        expect(captured[1], isA<String>());
        expect(
          (captured[1] as String).length,
          36,
          reason: 'sessionId is a v4 UUID — 36 chars with dashes.',
        );

        vm.dispose();
      },
    );

    test('onEnter twice does not regenerate sessionId', () async {
      final vm = CookingModeViewModel(recipe: testRecipe);

      await vm.onEnter();
      await vm.onEnter();

      // Only one started event; the second onEnter is a no-op because the
      // session is already active.
      verify(
        () => mockTracker.logCookingSessionStarted(
          recipeId: any(named: 'recipeId'),
          sessionId: any(named: 'sessionId'),
        ),
      ).called(1);

      vm.dispose();
    });

    test(
      'nextStep emits cooking_step_advanced with from/to + sessionId',
      () async {
        final vm = CookingModeViewModel(recipe: testRecipe);
        await vm.onEnter();

        vm.nextStep();

        final captured = verify(
          () => mockTracker.logCookingStepAdvanced(
            recipeId: captureAny(named: 'recipeId'),
            sessionId: captureAny(named: 'sessionId'),
            fromStep: captureAny(named: 'fromStep'),
            toStep: captureAny(named: 'toStep'),
          ),
        ).captured;
        expect(captured[0], 'recipe-1');
        expect(captured[2], 0);
        expect(captured[3], 1);

        vm.dispose();
      },
    );

    test('step events do not fire before onEnter (no session)', () async {
      final vm = CookingModeViewModel(recipe: testRecipe);

      vm.nextStep();

      verifyNever(
        () => mockTracker.logCookingStepAdvanced(
          recipeId: any(named: 'recipeId'),
          sessionId: any(named: 'sessionId'),
          fromStep: any(named: 'fromStep'),
          toStep: any(named: 'toStep'),
        ),
      );

      vm.dispose();
    });

    test(
      'onExit at last step fires session_completed with steps_viewed',
      () async {
        // Two fixed-clock blocks: onEnter at T=0 captures startedAt; onExit
        // 90s later computes duration_sec = 90. Hoisting `vm` out of both
        // closures keeps the same instance across the timeline.
        late CookingModeViewModel vm;
        await withClock(
          Clock.fixed(DateTime.utc(2026, 5, 21, 12, 0, 0)),
          () async {
            vm = CookingModeViewModel(recipe: testRecipe);
            await vm.onEnter();
            vm.nextStep(); // step 1
            vm.nextStep(); // step 2 (last — totalSteps - 1 = 2)
          },
        );
        await withClock(
          Clock.fixed(DateTime.utc(2026, 5, 21, 12, 1, 30)),
          () async {
            await vm.onExit();
          },
        );

        final captured = verify(
          () => mockTracker.logCookingSessionCompleted(
            recipeId: captureAny(named: 'recipeId'),
            sessionId: captureAny(named: 'sessionId'),
            durationSec: captureAny(named: 'durationSec'),
            stepsViewed: captureAny(named: 'stepsViewed'),
          ),
        ).captured;
        expect(captured[0], 'recipe-1');
        expect(captured[2], 90, reason: '90s between fixed clocks.');
        expect(captured[3], 3, reason: 'Reached steps 0, 1, 2 — all 3 viewed.');

        verifyNever(
          () => mockTracker.logCookingSessionAbandoned(
            recipeId: any(named: 'recipeId'),
            sessionId: any(named: 'sessionId'),
            durationSec: any(named: 'durationSec'),
            lastStep: any(named: 'lastStep'),
          ),
        );

        vm.dispose();
      },
    );

    test('onExit mid-recipe fires session_abandoned with last_step', () async {
      late CookingModeViewModel vm;
      await withClock(
        Clock.fixed(DateTime.utc(2026, 5, 21, 12, 0, 0)),
        () async {
          vm = CookingModeViewModel(recipe: testRecipe);
          await vm.onEnter();
          vm.nextStep(); // step 1
        },
      );
      await withClock(
        Clock.fixed(DateTime.utc(2026, 5, 21, 12, 0, 45)),
        () async {
          await vm.onExit();
        },
      );

      final captured = verify(
        () => mockTracker.logCookingSessionAbandoned(
          recipeId: captureAny(named: 'recipeId'),
          sessionId: captureAny(named: 'sessionId'),
          durationSec: captureAny(named: 'durationSec'),
          lastStep: captureAny(named: 'lastStep'),
        ),
      ).captured;
      expect(captured[0], 'recipe-1');
      expect(captured[2], 45);
      expect(captured[3], 1, reason: 'Abandoned at step 1, not last (2).');

      verifyNever(
        () => mockTracker.logCookingSessionCompleted(
          recipeId: any(named: 'recipeId'),
          sessionId: any(named: 'sessionId'),
          durationSec: any(named: 'durationSec'),
          stepsViewed: any(named: 'stepsViewed'),
        ),
      );

      vm.dispose();
    });

    test(
      'onExit without prior onEnter is a no-op (no session emitted)',
      () async {
        final vm = CookingModeViewModel(recipe: testRecipe);

        await vm.onExit();

        verifyNever(
          () => mockTracker.logCookingSessionCompleted(
            recipeId: any(named: 'recipeId'),
            sessionId: any(named: 'sessionId'),
            durationSec: any(named: 'durationSec'),
            stepsViewed: any(named: 'stepsViewed'),
          ),
        );
        verifyNever(
          () => mockTracker.logCookingSessionAbandoned(
            recipeId: any(named: 'recipeId'),
            sessionId: any(named: 'sessionId'),
            durationSec: any(named: 'durationSec'),
            lastStep: any(named: 'lastStep'),
          ),
        );

        vm.dispose();
      },
    );

    test('revisiting a step does not double-count steps_viewed', () async {
      late CookingModeViewModel vm;
      await withClock(
        Clock.fixed(DateTime.utc(2026, 5, 21, 12, 0, 0)),
        () async {
          vm = CookingModeViewModel(recipe: testRecipe);
          await vm.onEnter();
          vm.nextStep(); // step 1
          vm.previousStep(); // back to 0 (already in set)
          vm.nextStep(); // step 1 again (already in set)
          vm.nextStep(); // step 2 (last)
        },
      );
      await withClock(
        Clock.fixed(DateTime.utc(2026, 5, 21, 12, 1, 0)),
        () async {
          await vm.onExit();
        },
      );

      final captured = verify(
        () => mockTracker.logCookingSessionCompleted(
          recipeId: any(named: 'recipeId'),
          sessionId: any(named: 'sessionId'),
          durationSec: any(named: 'durationSec'),
          stepsViewed: captureAny(named: 'stepsViewed'),
        ),
      ).captured;
      expect(
        captured.single,
        3,
        reason: 'Steps 0, 1, 2 visited — set semantics dedupe revisits.',
      );

      vm.dispose();
    });
  });

  group('CookingModeViewModel - BUT-1322 household default', () {
    UserProfile profileWith(int? size) => UserProfile(
      uid: 'u1',
      displayName: 'Test',
      email: 't@t.se',
      joinedAt: DateTime(2024, 1, 1),
      lastActiveAt: DateTime(2024, 1, 1),
      householdSize: size,
    );

    void registerUserService(int? size) {
      final mockUser = _MockUserService();
      when(() => mockUser.currentUserProfile).thenReturn(profileWith(size));
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UserService>()) {
        getIt.unregister<UserService>();
      }
      getIt.registerSingleton<UserService>(mockUser);
    }

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UserService>()) {
        getIt.unregister<UserService>();
      }
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
    });

    test('opens pre-scaled to householdSize when it differs from recipe', () {
      registerUserService(6);

      final vm = CookingModeViewModel(recipe: testRecipe);

      expect(vm.currentPortions, 6);
      // '2 dl mjol' scaled from 4 → 6 portions (×1.5) = '3 dl mjol'
      expect(vm.scaledIngredients.first, contains('3'));
      expect(vm.scaledIngredients.first, contains('dl'));

      vm.dispose();
    });

    test('manual override always wins over the household default', () {
      registerUserService(6);

      final vm = CookingModeViewModel(recipe: testRecipe);
      vm.updatePortions(2); // explicit user choice

      expect(vm.currentPortions, 2);
      // Base stays the RECIPE's portions (4): '2 dl mjol' × 0.5 = '1 dl mjol'.
      expect(vm.scaledIngredients.first, contains('1'));

      vm.dispose();
    });

    test('no household default keeps the pre-BUT-1322 init byte-for-byte', () {
      // No UserService registered at all.
      final vm = CookingModeViewModel(recipe: testRecipe);

      expect(vm.currentPortions, 4);
      expect(vm.scaledIngredients, testRecipe.ingredients);

      vm.dispose();
    });

    test('householdSize equal to recipe portions applies no scaling', () {
      registerUserService(4);

      final vm = CookingModeViewModel(recipe: testRecipe);

      expect(vm.currentPortions, 4);
      expect(vm.scaledIngredients, testRecipe.ingredients);

      vm.dispose();
    });

    test('household-default open logs scaling_applied with correct source', () {
      registerUserService(6);
      final mockAnalytics = _MockAnalyticsService();
      when(
        () => mockAnalytics.logPortionScalingApplied(
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
      getIt.registerSingleton<AnalyticsService>(mockAnalytics);

      final vm = CookingModeViewModel(recipe: testRecipe);

      verify(
        () => mockAnalytics.logPortionScalingApplied(
          recipeId: testRecipe.id,
          source: 'household_default',
          fromPortions: 4,
          toPortions: 6,
        ),
      ).called(1);

      vm.dispose();
    });
  });

  // BUT-1515: cold deep-link boot race. When the VM is constructed before the
  // user profile has loaded, the household default falls back to the recipe's
  // portions; it must re-apply once UserService notifies that the profile
  // loaded — unless the user has already scaled by hand.
  group('CookingModeViewModel - BUT-1515 boot-race re-apply', () {
    UserProfile profileWith(int? size) => UserProfile(
      uid: 'u1',
      displayName: 'Test',
      email: 't@t.se',
      joinedAt: DateTime(2024, 1, 1),
      lastActiveAt: DateTime(2024, 1, 1),
      householdSize: size,
    );

    _FakeUserService registerFake() {
      final fake = _FakeUserService();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UserService>()) {
        getIt.unregister<UserService>();
      }
      getIt.registerSingleton<UserService>(fake);
      return fake;
    }

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<UserService>()) {
        getIt.unregister<UserService>();
      }
    });

    test('re-applies the household default when the profile loads after '
        'construction', () {
      final fake = registerFake(); // profile null at construction

      final vm = CookingModeViewModel(recipe: testRecipe);
      expect(vm.currentPortions, 4, reason: 'fell back to recipe portions');

      var notified = 0;
      vm.addListener(() => notified++);

      // Profile finishes loading with a household size of 6.
      fake.setProfile(profileWith(6));

      expect(vm.currentPortions, 6);
      // '2 dl mjol' scaled from 4 → 6 (×1.5) = '3 dl mjol'.
      expect(vm.scaledIngredients.first, contains('3'));
      expect(vm.scaledIngredients.first, contains('dl'));
      expect(notified, greaterThanOrEqualTo(1));

      vm.dispose();
    });

    test('a manual override during the boot race is never clobbered by the '
        'late profile load', () {
      final fake = registerFake();

      final vm = CookingModeViewModel(recipe: testRecipe);
      vm.updatePortions(2); // user scales by hand while profile still loading

      fake.setProfile(profileWith(6));

      expect(vm.currentPortions, 2);
      // Base stays the recipe's portions (4): '2 dl mjol' × 0.5 = '1 dl mjol'.
      expect(vm.scaledIngredients.first, contains('1'));

      vm.dispose();
    });

    test('an unrelated notification with an unchanged household is an '
        'idempotent no-op', () {
      final fake = registerFake();
      fake.setProfileSilently(profileWith(6)); // present at construction

      final vm = CookingModeViewModel(recipe: testRecipe);
      expect(vm.currentPortions, 6);

      var notified = 0;
      vm.addListener(() => notified++);

      // e.g. an online-status write notifies but the household is unchanged.
      fake.setProfile(profileWith(6));

      expect(vm.currentPortions, 6);
      expect(notified, 0, reason: 'no re-scale, so no rebuild');

      vm.dispose();
    });
  });
}

class _MockUserService extends Mock implements UserService {}

/// A real [ChangeNotifier] fake so tests can fire notifyListeners() (mocktail
/// mocks stub addListener into a no-op). Only [currentUserProfile] is needed by
/// CookingModeViewModel's boot-race path; everything else routes to
/// noSuchMethod.
class _FakeUserService extends ChangeNotifier implements UserService {
  UserProfile? _profile;

  void setProfile(UserProfile? profile) {
    _profile = profile;
    notifyListeners();
  }

  void setProfileSilently(UserProfile? profile) {
    _profile = profile;
  }

  @override
  UserProfile? get currentUserProfile => _profile;

  // UserService overrides ChangeNotifier.dispose to return Future<void>; match
  // it so the interface is satisfied.
  @override
  Future<void> dispose() async => super.dispose();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
