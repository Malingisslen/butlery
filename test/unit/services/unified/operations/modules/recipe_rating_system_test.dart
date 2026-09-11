// test/unit/services/unified/operations/modules/recipe_rating_system_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/recipe_rating_system.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RecipeRatingSystem', () {
    late MockRatingsRepository mockRatingsRepository;
    late RecipeRatingSystem ratingSystem;
    late Recipe testRecipe;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(
        Recipe(
          core: RecipeCore(
            id: 'test',
            title: 'Test',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'Test',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          type: RecipeType.personal,
        ),
      );
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks
      mockRatingsRepository = MockRatingsRepository();

      // The owner differs from the rater (`user_123`) used throughout, so an
      // assertion that must tell the two apart cannot be satisfied by the
      // fixture alone.
      testRecipe = RecipeBuilder()
          .withId('recipe_1')
          .withTitle('Test Recipe')
          .withCreatedBy('recipe_owner')
          .build();

      // Initialize production ServiceLocator with MockDIContainer
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());

      // Stub getUserRating (called by rateRecipe to get previous rating for analytics)
      when(
        () => mockRatingsRepository.getUserRating(any(), any()),
      ).thenAnswer((_) async => null);

      // Stub analytics logRecipeRated (called after successful rating)
      final mockAnalytics =
          TestServiceLocator.get<AnalyticsService>() as MockAnalyticsService;
      when(
        () => mockAnalytics.logRecipeRated(
          recipeId: any(named: 'recipeId'),
          rating: any(named: 'rating'),
          previousRating: any(named: 'previousRating'),
        ),
      ).thenAnswer((_) async {});

      // Create rating system instance
      ratingSystem = RecipeRatingSystem(
        ratingsRepository: mockRatingsRepository,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Core Rating Operations', () {
      test('should rate recipe successfully with valid rating', () async {
        // Arrange
        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: 'recipe_1',
            userId: 'user_123',
            rating: 4.5,
            review: 'Great recipe!',
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.5,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          review: 'Great recipe!',
          canRateValidator: (_) => true,
          recipeGetter: (id) => id == 'recipe_1' ? testRecipe : null,
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockRatingsRepository.rateRecipe(
            recipeId: 'recipe_1',
            userId: 'user_123',
            rating: 4.5,
            review: 'Great recipe!',
            recipeOwnerId: 'recipe_owner',
          ),
        ).called(1);
      });

      test('should rate recipe without review', () async {
        // Arrange
        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: 'recipe_1',
            userId: 'user_123',
            rating: 3.0,
            review: null,
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 3.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          review: null,
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        // Assert
        expect(result, isTrue);
      });

      test('should trim review text before saving', () async {
        // Arrange
        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: 'Trimmed review',
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          review: '  Trimmed review  ',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        // Assert
        verify(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: 'Trimmed review',
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).called(1);
      });

      test('passes the recipe owner to the repository, not the rater', () async {
        // Intent (BUT-2057): the owner the rules blocking gate reads is derived
        // from the fetched recipe. The fixture's owner differs from the rater,
        // so a wiring that passed the rater's own uid would not satisfy this.
        final othersRecipe = RecipeBuilder()
            .withId('recipe_1')
            .withTitle('Someone elses recipe')
            .withCreatedBy('owner_999')
            .build();

        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => othersRecipe,
        );

        verify(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: 'owner_999',
          ),
        ).called(1);
      });

      test('prefers socialData.ownerId over createdBy', () async {
        // The fallback half is pinned above. Here the two fields differ, so a
        // regression dropping the socialData branch would stay green against a
        // fixture that only sets createdBy.
        final shared = RecipeBuilder()
            .withId('recipe_1')
            .withCreatedBy('original_author')
            .withSocialData(const RecipeSocialData(ownerId: 'owner_abc'))
            .build();

        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => shared,
        );

        verify(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: 'owner_abc',
          ),
        ).called(1);
      });

      test('an empty socialData.ownerId falls through to createdBy', () async {
        // The fall-through, which neither neighbour reaches. A refactor
        // reading 'an empty owner means no owner' would short-circuit to null
        // here and stay green without it.
        final emptySocial = RecipeBuilder()
            .withId('recipe_1')
            .withCreatedBy('fallback_owner')
            .withSocialData(const RecipeSocialData(ownerId: ''))
            .build();

        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => emptySocial,
        );

        verify(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: 'fallback_owner',
          ),
        ).called(1);
      });
      test('an EMPTY owner resolves to null, not to an empty string', () async {
        // The rule keys on the field's PRESENCE. An empty string would be
        // written, take the enforcing disjunct, and then look up
        // `blocks/_<rater>` — which never exists. Presence without
        // enforcement is the failure this ticket exists to close, so the
        // empty value must omit the key instead.
        final emptyOwner = RecipeBuilder()
            .withId('recipe_1')
            .withCreatedBy('')
            .withSocialData(const RecipeSocialData(ownerId: ''))
            .build();

        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => emptyOwner,
        );

        verify(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: null,
          ),
        ).called(1);
      });
    });

    // BUT-2073. Two counters that measure OPPOSITE halves of the BUT-2057 block
    // gate: one counts it firing, one counts it never running. Neither carries a
    // uid or free text — the assertions below check that too, because "no uid in
    // the event" is the condition the ticket makes binding, and a parameter map
    // that quietly grew one would otherwise ship unnoticed.
    group('Block-gate measurement (BUT-2073)', () {
      late MockAnalyticsService analytics;

      setUp(() {
        analytics =
            app_provider.ServiceLocator.get<AnalyticsService>()
                as MockAnalyticsService;
        analytics.clearCapturedEvents();
      });

      List<({String name, Map<String, Object>? parameters})> eventsNamed(
        String name,
      ) => analytics.capturedEvents.where((e) => e.name == name).toList();

      test('a permission-denied rating write is counted', () async {
        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );

        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        expect(result, isFalse);
        final denied = eventsNamed(AnalyticsEvents.recipeRatingDenied);
        expect(denied, hasLength(1));
        expect(
          denied.single.parameters,
          anyOf(isNull, isEmpty),
          reason:
              'the event must carry a COUNT and nothing else — no uid, no recipe id, no free text',
        );
      });

      test('a SUCCESSFUL rating is not counted as denied', () async {
        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        expect(result, isTrue);
        expect(eventsNamed(AnalyticsEvents.recipeRatingDenied), isEmpty);
      });

      test('an ordinary failure is NOT counted as a refusal', () async {
        // The catch block also covers a dropped connection and a malformed
        // write. Folding those in would make the number unreadable as a signal
        // about the gate, which is the only thing it is for.
        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );

        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        expect(result, isFalse);
        expect(eventsNamed(AnalyticsEvents.recipeRatingDenied), isEmpty);
      });

      test('an UNRESOLVABLE recipe owner is counted separately', () async {
        // Both source fields empty: `socialData.ownerId` and `core.createdBy`.
        // This is the population Malin's 2026-09-11 decision rests on, and
        // nobody has ever counted it.
        final ownerless = RecipeBuilder()
            .withId('recipe_1')
            .withCreatedBy('')
            .withSocialData(const RecipeSocialData(ownerId: ''))
            .build();

        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => ownerless,
        );

        // The rating is still WRITTEN — Malin chose measuring over refusing,
        // and a counter that changed the outcome would be the refusal she
        // declined.
        expect(result, isTrue);
        final unresolved = eventsNamed(
          AnalyticsEvents.recipeRatingOwnerUnresolved,
        );
        expect(unresolved, hasLength(1));
        expect(unresolved.single.parameters, anyOf(isNull, isEmpty));
        expect(eventsNamed(AnalyticsEvents.recipeRatingDenied), isEmpty);
      });

      test('a recipe with NEITHER owner field set is counted too', () async {
        // Both fields null, not empty.
        final ownerless = (RecipeBuilder()..createdBy = null)
            .withId('recipe_1')
            .build();

        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => ownerless,
        );

        expect(ownerless.socialData, isNull);
        expect(ownerless.core.createdBy, isNull);
        expect(
          eventsNamed(AnalyticsEvents.recipeRatingOwnerUnresolved),
          hasLength(1),
        );
      });

      test('an unresolvable owner whose write is REFUSED fires both', () async {
        // The case that pins WHERE the unresolved counter is emitted. Moving it
        // below the write would silently turn it into a counter of SUCCESSFUL
        // ownerless writes, biasing exactly the population Malin's 2026-09-11
        // decision is to be re-opened on.
        final ownerless = RecipeBuilder()
            .withId('recipe_1')
            .withCreatedBy('')
            .withSocialData(const RecipeSocialData(ownerId: ''))
            .build();

        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );

        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => ownerless,
        );

        expect(result, isFalse);
        expect(
          eventsNamed(AnalyticsEvents.recipeRatingOwnerUnresolved),
          hasLength(1),
          reason:
              'the unresolved count describes the CALL, so a refused write must still carry it',
        );
        expect(eventsNamed(AnalyticsEvents.recipeRatingDenied), hasLength(1));
      });

      test('a resolvable owner emits NO unresolved count', () async {
        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        expect(
          eventsNamed(AnalyticsEvents.recipeRatingOwnerUnresolved),
          isEmpty,
        );
      });

      test('an owner resolvable from EITHER field alone emits no unresolved '
          'count', () async {
        // One fixture per field, each with the OTHER field empty: the count
        // fires only when both are unusable.
        final ownerOnlyInSocial = RecipeBuilder()
            .withId('recipe_1')
            .withCreatedBy('')
            .withSocialData(const RecipeSocialData(ownerId: 'owner_abc'))
            .build();
        final ownerOnlyInCreatedBy = RecipeBuilder()
            .withId('recipe_1')
            .withCreatedBy('fallback_owner')
            .withSocialData(const RecipeSocialData(ownerId: ''))
            .build();

        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        for (final recipe in [ownerOnlyInSocial, ownerOnlyInCreatedBy]) {
          final result = await ratingSystem.rateRecipe(
            recipeId: 'recipe_1',
            rating: 4.0,
            currentUserId: 'user_123',
            currentUserDisplayName: 'Test User',
            canRateValidator: (_) => true,
            recipeGetter: (id) => recipe,
          );
          expect(result, isTrue);
        }

        expect(
          eventsNamed(AnalyticsEvents.recipeRatingOwnerUnresolved),
          isEmpty,
        );
      });
    });

    group('Rating Validation', () {
      test('should reject rating below 1.0', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 0.5,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        // Assert
        expect(result, isFalse);
        verifyNever(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        );
      });

      test('should reject rating above 5.0', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 5.5,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should reject NaN rating', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: double.nan,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should reject infinite rating', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: double.infinity,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should accept boundary ratings (1.0 and 5.0)', () async {
        // Arrange
        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        // Act - Test 1.0
        final result1 = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 1.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        // Act - Test 5.0
        final result5 = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 5.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        // Assert
        expect(result1, isTrue);
        expect(result5, isTrue);
      });
    });

    group('Permission Validation', () {
      test('should fail if recipe not found', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'nonexistent',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => null, // Recipe not found
        );

        // Assert
        expect(result, isFalse);
      });

      test('should fail if user lacks permission to rate', () async {
        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => false, // No permission
          recipeGetter: (id) => testRecipe,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should use validator and getter callbacks correctly', () async {
        // Arrange
        var validatorCalled = false;
        var getterCalled = false;

        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (recipe) {
            validatorCalled = true;
            expect(recipe, equals(testRecipe));
            return true;
          },
          recipeGetter: (id) {
            getterCalled = true;
            expect(id, equals('recipe_1'));
            return testRecipe;
          },
        );

        // Assert
        expect(validatorCalled, isTrue);
        expect(getterCalled, isTrue);
      });
    });

    // BUT-2078: the owner check reads the shared accessor, so an EMPTY
    // `socialData.ownerId` falls through to `createdBy` instead of reading as
    // a uid nobody has.
    group('Owner check with an empty socialData.ownerId', () {
      Recipe ownRecipe() => RecipeBuilder()
          .withId('recipe_1')
          .withType(RecipeType.collaborative)
          .withCreatedBy('user_123')
          .withSocialData(
            const RecipeSocialData(
              ownerId: '',
              memberPermissions: {'user_123': ResourcePermission.viewer},
            ),
          )
          .build();

      test('the owner may not rate their own recipe', () {
        expect(
          RecipeRatingSystem.canUserRateRecipe(
            recipe: ownRecipe(),
            currentUserId: 'user_123',
          ),
          isFalse,
        );
      });

      test('a member who is not the owner may rate it', () {
        final recipe = RecipeBuilder()
            .withId('recipe_1')
            .withType(RecipeType.collaborative)
            .withCreatedBy('recipe_owner')
            .withSocialData(
              const RecipeSocialData(
                ownerId: '',
                memberPermissions: {'user_123': ResourcePermission.viewer},
              ),
            )
            .build();

        expect(
          RecipeRatingSystem.canUserRateRecipe(
            recipe: recipe,
            currentUserId: 'user_123',
          ),
          isTrue,
        );
      });

      test(
        'the owner may view ratings on a recipe they are not a member of',
        () {
          final recipe = RecipeBuilder()
              .withId('recipe_1')
              .withType(RecipeType.collaborative)
              .withCreatedBy('user_123')
              .withSocialData(const RecipeSocialData(ownerId: ''))
              .build();

          expect(
            RecipeRatingSystem.canUserViewRatings(
              recipe: recipe,
              currentUserId: 'user_123',
            ),
            isTrue,
          );
        },
      );

      test('a non-member may not view ratings when no owner resolves', () {
        final recipe = RecipeBuilder()
            .withId('recipe_1')
            .withType(RecipeType.collaborative)
            .withCreatedBy('')
            .withSocialData(const RecipeSocialData(ownerId: ''))
            .build();

        expect(
          RecipeRatingSystem.canUserViewRatings(
            recipe: recipe,
            currentUserId: 'user_123',
          ),
          isFalse,
        );
      });
    });

    group('Get Rating Operations', () {
      test('should get user rating for recipe', () async {
        // Arrange
        final testRating = RecipeRating(
          id: 'rating_1',
          recipeId: 'recipe_1',
          userId: 'user_123',
          rating: 4.5,
          review: 'Great!',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          () => mockRatingsRepository.getUserRating('recipe_1', 'user_123'),
        ).thenAnswer((_) async => testRating);

        // Act
        final rating = await ratingSystem.getUserRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );

        // Assert
        expect(rating, equals(testRating));
      });

      test('should handle null user rating', () async {
        // Arrange
        when(
          () => mockRatingsRepository.getUserRating('recipe_1', 'user_123'),
        ).thenAnswer((_) async => null);

        // Act
        final rating = await ratingSystem.getUserRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );

        // Assert
        expect(rating, isNull);
      });

      test('should get all ratings for recipe', () async {
        // Arrange
        final ratings = [
          RecipeRating(
            id: 'rating_1',
            recipeId: 'recipe_1',
            userId: 'user_1',
            rating: 4.5,
            review: 'Great!',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          RecipeRating(
            id: 'rating_2',
            recipeId: 'recipe_1',
            userId: 'user_2',
            rating: 3.0,
            review: 'Good',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(
          () => mockRatingsRepository.getRecipeRatings('recipe_1'),
        ).thenAnswer((_) async => ratings);

        // Act
        final result = await ratingSystem.getRecipeRatings(
          recipeId: 'recipe_1',
        );

        // Assert
        expect(result.length, equals(2));
        expect(result, equals(ratings));
      });

      test('should return empty list on error', () async {
        // Arrange
        when(
          () => mockRatingsRepository.getRecipeRatings('recipe_1'),
        ).thenThrow(Exception('Failed'));

        // Act
        final result = await ratingSystem.getRecipeRatings(
          recipeId: 'recipe_1',
        );

        // Assert
        expect(result, isEmpty);
      });
    });

    group('Delete Rating Operations', () {
      test('should delete rating', () async {
        // Arrange
        when(
          () => mockRatingsRepository.removeRating('recipe_1', 'user_123'),
        ).thenAnswer((_) async {});

        // Act
        final result = await ratingSystem.deleteRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockRatingsRepository.removeRating('recipe_1', 'user_123'),
        ).called(1);
      });

      test('should handle delete errors gracefully', () async {
        // Arrange
        when(
          () => mockRatingsRepository.removeRating('recipe_1', 'user_123'),
        ).thenThrow(Exception('Delete failed'));

        // Act
        final result = await ratingSystem.deleteRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );

        // Assert
        expect(result, isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle repository errors gracefully', () async {
        // Arrange
        when(
          () => mockRatingsRepository.rateRecipe(
            recipeId: any(named: 'recipeId'),
            userId: any(named: 'userId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
            recipeOwnerId: any(named: 'recipeOwnerId'),
          ),
        ).thenThrow(Exception('Repository error'));

        // Act
        final result = await ratingSystem.rateRecipe(
          recipeId: 'recipe_1',
          rating: 4.0,
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
          canRateValidator: (_) => true,
          recipeGetter: (id) => testRecipe,
        );

        // Assert
        expect(result, isFalse);
      });

      test('should handle getUserRating errors', () async {
        // Arrange
        when(
          () => mockRatingsRepository.getUserRating(any(), any()),
        ).thenThrow(Exception('Failed'));

        // Act
        final rating = await ratingSystem.getUserRating(
          recipeId: 'recipe_1',
          userId: 'user_123',
        );

        // Assert
        expect(rating, isNull);
      });
    });
  });
}
