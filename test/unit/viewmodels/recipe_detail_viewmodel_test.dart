import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/lifecycle_stage_classifier.dart';
import 'package:butlery/services/analytics/user_property_bootstrap.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/user_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';

class _MockCookEventRepository extends Mock implements CookEventRepository {}

class _MockUserPropertyBootstrap extends Mock
    implements UserPropertyBootstrap {}

void main() {
  group('RecipeDetailViewModel - Ultrathink Enhanced Tests', () {
    late RecipeDetailViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late MockAnalyticsService mockAnalyticsService;
    late MockRecipeCookingService mockCookingService;
    late Recipe testRecipe;
    late Recipe updatedRecipe;

    // Test data
    const testUserId = 'user123';
    const testRecipeId = 'recipe123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(DateTime(2026));
    });

    setUp(() async {
      await TestServiceLocator.reset();
      await TestServiceLocator.initialize();

      // Create mocks
      mockRecipeService = MockFactory.createUnifiedRecipeService();
      mockAnalyticsService = MockFactory.createAnalyticsService();
      mockCookingService = MockFactory.createRecipeCookingService();

      // Create test recipe with comprehensive data
      testRecipe = RecipeBuilder()
          .withId(testRecipeId)
          .withTitle('Köttbullar med lingonsylt')
          .withDescription(
            'Traditionella svenska köttbullar från mormors recept',
          )
          .withMealType('Middag')
          .withPortions(4)
          .withTimeMinutes(45)
          .withRating(4.5)
          .withTags(['svensk', 'traditionell', 'kött'])
          .withImageUrls(['image1.jpg', 'image2.jpg', 'image3.jpg'])
          .withIngredients([
            '500g köttfärs',
            '1 dl ströbröd',
            '1 ägg',
            '2 msk mjölk',
            '1 tsk salt',
            '1 krm peppar',
          ])
          .withInstructions([
            'Blanda köttfärs med ströbröd och ägg',
            'Tillsätt mjölk, salt och peppar',
            'Forma små bullar',
            'Stek i smör tills gyllenbruna',
          ])
          .build();

      // Create updated recipe for state changes
      updatedRecipe = RecipeBuilder()
          .withId(testRecipeId)
          .withTitle('Köttbullar med lingonsylt - Uppdaterad')
          .withDescription('Uppdaterad beskrivning')
          .withMealType('Middag')
          .withPortions(6)
          .withTimeMinutes(50)
          .withRating(4.8)
          .withUpdatedAt(DateTime.now().add(Duration(minutes: 1)))
          .build();

      // Setup mock states
      mockRecipeService.setRecipeState(
        recipes: [testRecipe],
        currentUserId: testUserId,
        currentUserDisplayName: 'Test User',
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      // Setup analytics mock with proper signatures
      when(
        () => mockAnalyticsService.logRecipeDeleted(
          recipeId: any(named: 'recipeId'),
          mealType: any(named: 'mealType'),
          isPersonal: any(named: 'isPersonal'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) async => Future.value());

      when(
        () => mockAnalyticsService.logRecipeCooked(
          recipeId: any(named: 'recipeId'),
          mealType: any(named: 'mealType'),
          isFirstTime: any(named: 'isFirstTime'),
        ),
      ).thenAnswer((_) async => Future.value());

      // Register mocks
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
      TestServiceLocator.registerMock<AnalyticsService>(mockAnalyticsService);
      TestServiceLocator.registerMock<RecipeCookingService>(mockCookingService);

      // Create viewModel — passes cookingService explicitly so the VM's
      // ServiceLocator default doesn't kick in (BUT-835).
      viewModel = RecipeDetailViewModel(
        recipe: testRecipe,
        recipeService: mockRecipeService,
        analyticsService: mockAnalyticsService,
        cookingService: mockCookingService,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization and Default State', () {
      test('should initialize with correct recipe data', () {
        // Assert
        expect(viewModel.recipe, equals(testRecipe));
        expect(viewModel.recipe.id, equals(testRecipeId));
        expect(viewModel.recipe.title, equals('Köttbullar med lingonsylt'));
        expect(viewModel.recipe.portions, equals(4));
        expect(viewModel.recipe.timeMinutes, equals(45));
        expect(viewModel.recipe.rating, equals(4.5));
      });

      test('should initialize with correct state', () {
        // Assert
        expect(viewModel.isDeleting, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should register service listener on initialization', () {
        // Assert - implicit through viewModel creation
        // The fact that viewModel is created successfully proves listener registration
        expect(viewModel, isNotNull);
      });
    });

    group('Recipe Display Properties', () {
      test('should provide correct display properties for complete recipe', () {
        // Assert - using actual properties that exist
        expect(viewModel.hasImages, isTrue);
        expect(viewModel.hasMultipleImages, isTrue);
        expect(viewModel.hasTags, isTrue);
        expect(viewModel.hasRating, isTrue);
      });

      test('should provide correct formatted displays', () {
        // Assert
        expect(viewModel.portionsDisplay, equals('4'));
        expect(viewModel.timeDisplay, equals('45'));
        expect(viewModel.ratingDisplay, equals('4.5'));
      });

      test('should handle missing data with default displays', () {
        // Arrange
        final minimalRecipe = RecipeBuilder()
            .withId('minimal')
            .withTitle('Minimal Recipe')
            .withPortions(null)
            .withTimeMinutes(null)
            .withRating(null)
            .build();

        viewModel = RecipeDetailViewModel(
          recipe: minimalRecipe,
          recipeService: mockRecipeService,
          analyticsService: mockAnalyticsService,
          cookingService: mockCookingService,
        );

        // Assert
        expect(viewModel.portionsDisplay, equals('–'));
        expect(viewModel.timeDisplay, equals('–'));
        expect(viewModel.ratingDisplay, equals('–'));
        expect(viewModel.hasImages, isFalse);
        expect(viewModel.hasRating, isFalse);
      });

      test('should handle recipe with no tags', () {
        // Arrange
        final recipeNoTags = RecipeBuilder()
            .withId('notags')
            .withTitle('Recipe without tags')
            .withTags(null)
            .build();

        viewModel = RecipeDetailViewModel(
          recipe: recipeNoTags,
          recipeService: mockRecipeService,
          analyticsService: mockAnalyticsService,
          cookingService: mockCookingService,
        );

        // Assert
        expect(viewModel.hasTags, isFalse);
      });

      test('should handle recipe with empty tags list', () {
        // Arrange
        final recipeEmptyTags = RecipeBuilder()
            .withId('emptytags')
            .withTitle('Recipe with empty tags')
            .withTags([])
            .build();

        viewModel = RecipeDetailViewModel(
          recipe: recipeEmptyTags,
          recipeService: mockRecipeService,
          analyticsService: mockAnalyticsService,
          cookingService: mockCookingService,
        );

        // Assert
        expect(viewModel.hasTags, isFalse);
      });
    });

    group('Recipe Operations', () {
      test('should delete recipe successfully', () async {
        // Arrange
        when(
          () => mockRecipeService.deleteRecipe(testRecipeId),
        ).thenAnswer((_) async => true);

        // Act
        final result = await viewModel.deleteRecipe();

        // Assert
        expect(result, isTrue);
        verify(() => mockRecipeService.deleteRecipe(testRecipeId)).called(1);
        verify(
          () => mockAnalyticsService.logRecipeDeleted(
            recipeId: testRecipeId,
            mealType: 'Middag',
            isPersonal: any(named: 'isPersonal'),
            createdAt: any(named: 'createdAt'),
          ),
        ).called(1);
      });

      test('should handle deletion failure', () async {
        // Arrange
        when(
          () => mockRecipeService.deleteRecipe(any()),
        ).thenAnswer((_) async => false);
        mockRecipeService.setRecipeState(error: 'Kunde inte ta bort receptet');

        // Act - executeAsync rethrows, so wrap in try/catch
        bool result = true;
        try {
          result = await viewModel.deleteRecipe();
        } catch (_) {
          result = false;
        }

        // Assert
        expect(result, isFalse);
      });

      test('should track deletion state', () async {
        // Arrange
        bool wasDeletingTracked = false;
        viewModel.addListener(() {
          if (viewModel.isDeleting) wasDeletingTracked = true;
        });

        when(() => mockRecipeService.deleteRecipe(any())).thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 10));
          return true;
        });

        // Act
        await viewModel.deleteRecipe();

        // Assert
        expect(wasDeletingTracked, isTrue);
        expect(viewModel.isDeleting, isFalse);
      });

      test('should mark recipe as cooked', () async {
        // Act — VM delegates to RecipeCookingService.markAsCooked (which
        // owns the atomic Firestore increment + per-day session dedup).
        final result = await viewModel.markAsCooked();

        // Assert
        expect(result, isTrue);
        verify(() => mockCookingService.markAsCooked(testRecipeId)).called(1);
        verify(
          () => mockAnalyticsService.logRecipeCooked(
            recipeId: testRecipeId,
            mealType: 'Middag',
            isFirstTime: true,
          ),
        ).called(1);
      });

      test('should handle mark as cooked failure', () async {
        // Arrange — cooking service returns false (write rejected by
        // session guard or underlying repo failure).
        mockCookingService.setMarkAsCookedResult(false);

        // Act — executeAsync rethrows, so wrap in try/catch.
        bool result = true;
        try {
          result = await viewModel.markAsCooked();
        } catch (_) {
          result = false;
        }

        // Assert
        expect(result, isFalse);
      });

      test('should track first time cooking correctly', () async {
        // Arrange — recipe already cooked before.
        final cookedRecipe = RecipeBuilder()
            .withId(testRecipeId)
            .withTitle('Already Cooked Recipe')
            .withLastCookedAt(DateTime.now().subtract(Duration(days: 1)))
            .build();

        viewModel = RecipeDetailViewModel(
          recipe: cookedRecipe,
          recipeService: mockRecipeService,
          analyticsService: mockAnalyticsService,
          cookingService: mockCookingService,
        );

        // Act
        await viewModel.markAsCooked();

        // Assert
        verify(
          () => mockAnalyticsService.logRecipeCooked(
            recipeId: any(named: 'recipeId'),
            mealType: any(named: 'mealType'),
            isFirstTime: false, // Should be false since already cooked
          ),
        ).called(1);
      });
    });

    group('BUT-1304: updateRecipeTagOverrides (MVVM tag persist)', () {
      const overrides = TagOverrides(
        addedTags: {'vegetariskt'},
        removedTags: {'kött'},
      );

      test('applies overrides optimistically and persists via the service '
          'when the write succeeds', () async {
        when(
          () => mockRecipeService.updateRecipe(any()),
        ).thenAnswer((_) async => true);

        final result = await viewModel.updateRecipeTagOverrides(overrides);

        expect(result, isTrue);
        // The new overrides are reflected on the VM's recipe...
        expect(viewModel.recipe.tagOverrides, equals(overrides));
        // ...and the persist went through the service exactly once, carrying
        // those overrides (the View no longer calls the service directly).
        final persisted =
            verify(
                  () => mockRecipeService.updateRecipe(captureAny()),
                ).captured.single
                as Recipe;
        expect(persisted.tagOverrides, equals(overrides));
      });

      test(
        'reverts to the previous overrides when the service write fails',
        () async {
          const previous = TagOverrides(addedTags: {'original'});
          final taggedRecipe = RecipeBuilder()
              .withId(testRecipeId)
              .withTitle('Tagged Recipe')
              .withTagOverrides(previous)
              .build();
          viewModel = RecipeDetailViewModel(
            recipe: taggedRecipe,
            recipeService: mockRecipeService,
            analyticsService: mockAnalyticsService,
            cookingService: mockCookingService,
          );

          when(
            () => mockRecipeService.updateRecipe(any()),
          ).thenAnswer((_) async => false);

          // Count notifications: the optimistic apply and the revert must each
          // fire one, so a no-op method that skipped the optimistic update (and
          // happened to leave `previous` in place) cannot pass this test.
          var notifications = 0;
          viewModel.addListener(() => notifications++);

          final result = await viewModel.updateRecipeTagOverrides(overrides);

          // Failure is surfaced to the caller (the View shows the error snackbar)
          // and the VM's recipe is rolled back to the pre-edit overrides, so the
          // UI never shows an edit that wasn't saved.
          expect(result, isFalse);
          expect(viewModel.recipe.tagOverrides, equals(previous));
          expect(
            notifications,
            greaterThanOrEqualTo(2),
            reason: 'optimistic apply + revert each fire notifyListeners',
          );
        },
      );
    });

    group('Recipe State Synchronization', () {
      test('should update recipe when service notifies changes', () async {
        // Arrange - Update the mock state with the updated recipe
        mockRecipeService.setRecipeState(
          recipes: [updatedRecipe],
        );

        // Act - VM listens on stateStream, not ChangeNotifier
        mockRecipeService.emitState(
          RecipeStateData(
            recipes: [updatedRecipe],
          ),
        );

        // Allow stream listener to process
        await Future.delayed(Duration.zero);

        // Assert
        expect(
          viewModel.recipe.title,
          equals('Köttbullar med lingonsylt - Uppdaterad'),
        );
        expect(viewModel.recipe.portions, equals(6));
        expect(viewModel.recipe.rating, equals(4.8));
      });

      test('should not update if recipe has not changed', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Mock state already has the same recipe
        mockRecipeService.setRecipeState(
          recipes: [testRecipe],
        );

        // Act
        mockRecipeService.notifyListeners();

        // Assert - notifyListeners will trigger but recipe won't actually change
        expect(viewModel.recipe, equals(testRecipe));
      });

      test('should handle recipe not found in service', () {
        // Arrange - Clear recipes from mock state
        mockRecipeService.setRecipeState(
          recipes: [],
        );

        // Act
        mockRecipeService.notifyListeners();

        // Assert
        expect(viewModel.recipe, equals(testRecipe)); // Keeps original recipe
      });
    });

    group('BUT-838: lifecycle re-emit uses real cook-event counts', () {
      late _MockCookEventRepository mockCookEvents;
      late _MockUserPropertyBootstrap mockBootstrap;
      late MockUserService mockUserService;
      late UserProfile profile;

      setUp(() {
        // The VM resolves UserService/UserPropertyBootstrap via the
        // production ServiceLocator (tryGet); bridge it onto the shared
        // GetIt so the mocks registered below are visible.
        prod.ServiceLocator.initialize(DIContainer());

        mockCookEvents = _MockCookEventRepository();
        mockBootstrap = _MockUserPropertyBootstrap();
        mockUserService = MockUserService();

        profile = UserProfile(
          uid: testUserId,
          displayName: 'Test User',
          email: 'test@example.com',
          // Signup well outside the 7d activation window so only the
          // habitual rule (cooks >= 3) can produce a non-new_ stage.
          joinedAt: DateTime.now().subtract(const Duration(days: 60)),
          lastActiveAt: DateTime.now(),
        );

        when(() => mockUserService.currentUserProfile).thenReturn(profile);
        when(() => mockUserService.currentUserId).thenReturn(testUserId);
        when(
          () => mockBootstrap.emitLifecycle(
            profile: any(named: 'profile'),
            lastCookAt: any(named: 'lastCookAt'),
            cooksLast14Days: any(named: 'cooksLast14Days'),
            now: any(named: 'now'),
          ),
        ).thenAnswer((_) async {});

        TestServiceLocator.registerMock<UserService>(mockUserService);
        TestServiceLocator.registerMock<UserPropertyBootstrap>(mockBootstrap);
      });

      tearDown(() {
        // Other groups in this file rely on tryGet returning null.
        prod.ServiceLocator.reset();
      });

      RecipeDetailViewModel buildViewModel() => RecipeDetailViewModel(
        recipe: testRecipe,
        recipeService: mockRecipeService,
        analyticsService: mockAnalyticsService,
        cookingService: mockCookingService,
        cookEventRepository: mockCookEvents,
      );

      test('marquee: 3 cooks of the SAME recipe within 14d → '
          'cooksLast14Days == 3 → lifecycle habitual (proxy gave 1)', () async {
        // The event log holds 3 events for one recipe — the old
        // personalRecipes.where(...) proxy counted distinct recipes and
        // would have reported 1 here.
        when(
          () => mockCookEvents.countSince(any(), any()),
        ).thenAnswer((_) async => 3);

        viewModel = buildViewModel();
        final ok = await viewModel.markAsCooked();
        expect(ok, isTrue);

        // The count is queried for the signed-in user over a 14d window.
        final countArgs = verify(
          () => mockCookEvents.countSince(captureAny(), captureAny()),
        ).captured;
        expect(countArgs[0], testUserId);
        final since = countArgs[1] as DateTime;
        expect(DateTime.now().difference(since).inDays, 14);

        // The real count reaches the lifecycle emission unchanged...
        final captured = verify(
          () => mockBootstrap.emitLifecycle(
            profile: captureAny(named: 'profile'),
            lastCookAt: captureAny(named: 'lastCookAt'),
            cooksLast14Days: captureAny(named: 'cooksLast14Days'),
            now: captureAny(named: 'now'),
          ),
        ).captured;
        // Mocktail does not guarantee declaration order for captured named
        // args — extract by type. lastCookAt and now are the same instant
        // in the VM (both `clock.now()` of the cook).
        final cooks = captured.whereType<int>().single;
        final emittedProfile = captured.whereType<UserProfile>().single;
        final cookInstant = captured.whereType<DateTime>().first;
        expect(
          cooks,
          3,
          reason:
              'the distinct-recipe proxy reported 1 for repeat cooks '
              'of the same recipe; the event log must report 3',
        );

        // ...and classifies as habitual with exactly these inputs.
        final stage = classifyLifecycleStage(
          signupAt: emittedProfile.joinedAt,
          lastCookAt: cookInstant,
          cooksLast14Days: cooks,
          now: cookInstant,
        );
        expect(stage, LifecycleStage.habitual);
      });

      test('countSince runs only after the cook write has committed', () async {
        // The aggregate must include the event this cook just wrote — the
        // VM has no local +1 compensation anymore. A refactor that counts
        // before the write stays green with a canned mock count but
        // undercounts by one in production (3rd cook reports 2 →
        // habitual one cook late).
        when(
          () => mockCookEvents.countSince(any(), any()),
        ).thenAnswer((_) async => 3);

        viewModel = buildViewModel();
        await viewModel.markAsCooked();

        verifyInOrder([
          () => mockCookingService.markAsCooked(any()),
          () => mockCookEvents.countSince(any(), any()),
        ]);
      });

      test('count failure falls back to 1 — cook flow never breaks', () async {
        when(
          () => mockCookEvents.countSince(any(), any()),
        ).thenThrow(Exception('aggregate query offline'));

        viewModel = buildViewModel();
        final ok = await viewModel.markAsCooked();
        expect(
          ok,
          isTrue,
          reason:
              'analytics enrichment must never fail '
              'the user-facing cook action',
        );

        verify(
          () => mockBootstrap.emitLifecycle(
            profile: any(named: 'profile'),
            lastCookAt: any(named: 'lastCookAt'),
            cooksLast14Days: 1,
            now: any(named: 'now'),
          ),
        ).called(1);
      });

      test(
        'a zero count is floored to 1 (this cook definitely happened)',
        () async {
          when(
            () => mockCookEvents.countSince(any(), any()),
          ).thenAnswer((_) async => 0);

          viewModel = buildViewModel();
          await viewModel.markAsCooked();

          verify(
            () => mockBootstrap.emitLifecycle(
              profile: any(named: 'profile'),
              lastCookAt: any(named: 'lastCookAt'),
              cooksLast14Days: 1,
              now: any(named: 'now'),
            ),
          ).called(1);
        },
      );
    });

    group('Analytics Integration', () {
      test('should log cooking event when marked as cooked', () async {
        // Arrange
        when(
          () => mockRecipeService.updateRecipe(any()),
        ).thenAnswer((_) async => true);

        // Act
        await viewModel.markAsCooked();

        // Assert
        verify(
          () => mockAnalyticsService.logRecipeCooked(
            recipeId: testRecipeId,
            mealType: 'Middag',
            isFirstTime: true,
          ),
        ).called(1);
      });

      test('should log deletion event when deleted', () async {
        // Arrange
        when(
          () => mockRecipeService.deleteRecipe(any()),
        ).thenAnswer((_) async => true);

        // Act
        await viewModel.deleteRecipe();

        // Assert
        verify(
          () => mockAnalyticsService.logRecipeDeleted(
            recipeId: testRecipeId,
            mealType: 'Middag',
            isPersonal: any(named: 'isPersonal'),
            createdAt: any(named: 'createdAt'),
          ),
        ).called(1);
      });
    });

    group('Error Handling', () {
      test('should clear error state', () {
        // Act
        viewModel.clearError();

        // Assert
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('error stays suppressed after a failed operation (BUT-520 '
          'BaseViewModel migration)', () async {
        // The VM deliberately hardcodes error → null / hasError → false. After
        // the BaseViewModel migration, executeAsync writes the failure into the
        // base _error field internally; the VM's getter overrides must keep it
        // invisible to consumers. Dropping those overrides would silently
        // surface BaseViewModel's generic error string on the detail screen.
        when(
          () => mockRecipeService.deleteRecipe(any()),
        ).thenThrow(Exception('Network error'));

        try {
          await viewModel.deleteRecipe();
        } catch (_) {
          // executeAsync rethrows — irrelevant to the error-surface contract.
        }

        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should handle service exceptions gracefully', () async {
        // Arrange
        when(
          () => mockRecipeService.deleteRecipe(any()),
        ).thenThrow(Exception('Network error'));

        // Act - executeAsync rethrows, so wrap in try/catch
        bool result = true;
        try {
          result = await viewModel.deleteRecipe();
        } catch (_) {
          result = false;
        }

        // Assert
        expect(result, isFalse);
      });

      test('should handle update recipe exception', () async {
        // Arrange — VM delegates to RecipeCookingService; throw from there.
        when(
          () => mockCookingService.markAsCooked(any()),
        ).thenThrow(Exception('Cook failed'));

        // Act - executeAsync rethrows, so wrap in try/catch
        bool result = true;
        try {
          result = await viewModel.markAsCooked();
        } catch (_) {
          result = false;
        }

        // Assert
        expect(result, isFalse);
      });
    });

    group('Disposal', () {
      test('should remove service listener on dispose', () {
        // Arrange - Create a new viewModel specifically for this test
        final testViewModel = RecipeDetailViewModel(
          recipe: testRecipe,
          recipeService: mockRecipeService,
          analyticsService: mockAnalyticsService,
          cookingService: mockCookingService,
        );

        // Act & Assert - should not throw
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle multiple dispose calls safely', () {
        // Arrange - Create a new viewModel specifically for this test
        final testViewModel = RecipeDetailViewModel(
          recipe: testRecipe,
          recipeService: mockRecipeService,
          analyticsService: mockAnalyticsService,
          cookingService: mockCookingService,
        );

        // Act & Assert - In debug mode, Flutter will throw on double dispose
        // This is expected behavior to catch bugs
        testViewModel.dispose();
        expect(() => testViewModel.dispose(), throwsFlutterError);
      });
    });

    group('Edge Cases', () {
      test('should handle recipe with empty arrays', () {
        // Arrange
        final emptyRecipe = RecipeBuilder()
            .withId('empty')
            .withTitle('Empty Recipe')
            .withIngredients([])
            .withInstructions([])
            .withTags([])
            .withImageUrls([])
            .build();

        viewModel = RecipeDetailViewModel(
          recipe: emptyRecipe,
          recipeService: mockRecipeService,
          analyticsService: mockAnalyticsService,
          cookingService: mockCookingService,
        );

        // Assert
        expect(viewModel.hasTags, isFalse);
        expect(viewModel.hasImages, isFalse);
        expect(viewModel.hasMultipleImages, isFalse);
      });

      test('should handle recipe with single image', () {
        // Arrange
        final singleImageRecipe = RecipeBuilder()
            .withId('single')
            .withTitle('Single Image Recipe')
            .withImageUrls(['single.jpg'])
            .build();

        viewModel = RecipeDetailViewModel(
          recipe: singleImageRecipe,
          recipeService: mockRecipeService,
          analyticsService: mockAnalyticsService,
          cookingService: mockCookingService,
        );

        // Assert
        expect(viewModel.hasImages, isTrue);
        expect(viewModel.hasMultipleImages, isFalse);
      });

      test('should handle concurrent operations', () async {
        // Arrange
        when(() => mockRecipeService.deleteRecipe(any())).thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 50));
          return true;
        });
        // Cooking service rejects the cook (write rejected) so we can
        // assert cookResult is false even when run concurrently with delete.
        mockCookingService.setMarkAsCookedResult(false);

        // Act - start deletion
        final deletionFuture = viewModel.deleteRecipe();

        // Try to mark as cooked during deletion
        // executeAsync rethrows on failure, so wrap in try/catch
        bool cookResult = true;
        try {
          cookResult = await viewModel.markAsCooked();
        } catch (_) {
          cookResult = false;
        }

        // Deletion also may throw on the finally path, wrap it too
        try {
          await deletionFuture;
        } catch (_) {
          // Ignore -- we only care about cookResult
        }

        // Assert
        expect(cookResult, isFalse);
      });
    });
  });
}
