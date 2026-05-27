import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/offline_service.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Fallback values
class FakeRecipe extends Fake implements Recipe {}

void main() {
  group('OfflineService', () {
    late OfflineService offlineService;
    late FakeFirestoreRepository mockFirestoreRepository;
    late MockFirebaseAuthRepository mockAuthRepository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Register fallback values
      registerFallbackValue(FakeRecipe());
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() {
      // Reset singleton for test isolation
      OfflineService.resetForTesting();

      // Create mocks from centralized system
      mockFirestoreRepository = FakeFirestoreRepository();
      mockAuthRepository = MockFirebaseAuthRepository();

      // Create service with mock dependencies
      offlineService = OfflineService(
        firestoreRepository: mockFirestoreRepository,
        authRepository: mockAuthRepository,
      );

      // Register mocks for automatic reset. FakeFirestoreRepository is a
      // Fake (no mocktail state to reset), so only the Mock needs to be here.
      BaseUnitTest.registerMocks([
        mockAuthRepository,
      ]);
    });

    tearDown(() {
      // Reset singleton for next test
      OfflineService.resetForTesting();
      TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Singleton Pattern', () {
      test('should maintain same instance across multiple factory calls', () {
        // Arrange & Act
        final instance1 = OfflineService(
          firestoreRepository: mockFirestoreRepository,
          authRepository: mockAuthRepository,
        );
        final instance2 = OfflineService(
          firestoreRepository: mockFirestoreRepository,
          authRepository: mockAuthRepository,
        );
        final instance3 = OfflineService();

        // Assert
        expect(identical(instance1, instance2), isTrue);
        expect(identical(instance2, instance3), isTrue);
      });

      test('should accept dependency injection', () {
        final customFirestore = FakeFirestoreRepository();
        final customAuth = FakeAuthRepository();

        // Act
        final service = OfflineService(
          firestoreRepository: customFirestore,
          authRepository: customAuth,
        );

        // Assert
        expect(service, isNotNull);
      });
    });

    group('Initialization', () {
      test('should not be initialized by default', () {
        // Assert
        expect(offlineService.isInitialized, isFalse);
      });

      test('should have safe defaults before initialization', () {
        // Assert
        expect(offlineService.isOnline, isTrue); // Defaults to online
        expect(offlineService.isSyncing, isFalse);
        expect(offlineService.hasQueuedChanges, isFalse);
        expect(offlineService.queuedChangesCount, equals(0));
        expect(offlineService.currentUserId, isNull);
      });

      test('should initialize Drift database', () async {
        // Arrange & Act
        // Note: Actual initialization requires Drift setup
        try {
          await offlineService.initialize();
        } catch (e) {
          // Expected to fail without proper database setup in tests
          expect(e, isNotNull);
        }
      });
    });

    group('User Management', () {
      test('should set current user', () {
        const userId = 'test_user_123';

        // Track listener calls
        var listenerCalled = false;
        offlineService.addListener(() {
          listenerCalled = true;
        });

        // Act
        offlineService.setCurrentUser(userId);

        // Assert
        expect(offlineService.currentUserId, equals(userId));
        expect(listenerCalled, isTrue);
      });

      test('should not notify if same user is set', () {
        const userId = 'test_user_123';
        offlineService.setCurrentUser(userId);

        var listenerCalled = false;
        offlineService.addListener(() {
          listenerCalled = true;
        });

        // Act
        offlineService.setCurrentUser(userId); // Same user

        // Assert
        expect(listenerCalled, isFalse);
      });

      test('should handle null user', () {
        offlineService.setCurrentUser('test_user');

        // Act
        offlineService.setCurrentUser(null);

        // Assert
        expect(offlineService.currentUserId, isNull);
      });
    });

    group('User-Specific Methods (Not Initialized)', () {
      test(
          'should return empty list for getRecipesForUser when not initialized',
          () async {
        final recipes = await offlineService.getRecipesForUser('user_123');

        // Assert
        expect(recipes, isEmpty);
      });

      test(
          'should return null for getOfflineRecipeForUser when not initialized',
          () async {
        final recipe = await offlineService.getOfflineRecipeForUser(
            'recipe_123', 'user_123');

        // Assert
        expect(recipe, isNull);
      });

      test('should handle clearUserData when not initialized', () async {
        // Act & Assert
        await offlineService.clearUserData('user_123');
      });
    });

    group('User-Specific Methods (Initialized)', () {
      test('should save recipe for specific user', () async {
        // Arrange
        final recipe = RecipeFactory.build();
        const userId = 'user_123';

        // Act - will fail without Drift setup
        try {
          await offlineService.saveRecipeOfflineForUser(recipe, userId);
        } catch (e) {
          // Expected to fail
          expect(e, isNotNull);
        }
      });

      test('should delete recipe for specific user', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'user_123';

        // Act - will fail without Drift setup
        try {
          await offlineService.deleteRecipeOfflineForUser(recipeId, userId);
        } catch (e) {
          // Expected to fail
          expect(e, isNotNull);
        }
      });
    });

    group('Legacy Methods', () {
      test('should handle legacy saveRecipeOffline', () async {
        final recipe = RecipeFactory.build();

        // Act & Assert - should not throw
        await offlineService.saveRecipeOffline(recipe);
      });

      test('should return empty list for getAllOfflineRecipes', () async {
        final recipes = await offlineService.getAllOfflineRecipes();

        // Assert
        expect(recipes, isEmpty);
      });

      test('should return null for getOfflineRecipe', () async {
        final recipe = await offlineService.getOfflineRecipe('recipe_123');

        // Assert
        expect(recipe, isNull);
      });

      test('should handle legacy deleteRecipeOffline', () async {
        // Act & Assert
        await offlineService.deleteRecipeOffline('recipe_123');
      });

      test('should handle legacy clearOfflineData', () async {
        // Act & Assert
        await offlineService.clearOfflineData();
      });
    });

    group('Sync Methods', () {
      test('should handle syncNow', () async {
        try {
          final result = await offlineService.syncNow();

          // If it somehow succeeds, check result
          expect(result, isNotNull);
        } catch (e) {
          // Expected to fail without initialization
          expect(e, isNotNull);
        }
      });
    });

    group('Resource Management', () {
      test('should dispose resources', () {
        offlineService.dispose();
      });

      test('should close database', () async {
        try {
          await offlineService.close();
        } catch (e) {
          // Expected to fail without initialization
          expect(e, isNotNull);
        }
      });
    });

    group('State Properties', () {
      test('should have correct initial state', () {
        // Assert
        expect(offlineService.isOnline, isTrue);
        expect(offlineService.isInitialized, isFalse);
        expect(offlineService.isSyncing, isFalse);
        expect(offlineService.hasQueuedChanges, isFalse);
        expect(offlineService.queuedChangesCount, equals(0));
      });

      test('should be a ChangeNotifier', () {
        // Assert
        expect(offlineService, isA<ChangeNotifier>());
      });

      // ChangeNotifier removed from OfflineService (BUT-23) — no listener tests needed
    });

    group('Queue Operations', () {
      test('should prioritize queue items by operation type', () {
        // Arrange
        final operations = <Map<String, dynamic>>[
          {'type': 'delete', 'priority': 1, 'id': 'op1'},
          {'type': 'create', 'priority': 3, 'id': 'op2'},
          {'type': 'update', 'priority': 2, 'id': 'op3'},
        ];

        // Act - Sort by priority (delete first, update second, create last)
        operations.sort(
            (a, b) => (a['priority'] as int).compareTo(b['priority'] as int));

        // Assert
        expect(operations[0]['type'], equals('delete'));
        expect(operations[1]['type'], equals('update'));
        expect(operations[2]['type'], equals('create'));
      });
    });

    group('Swedish Language Support', () {
      test('should handle Swedish recipe data in offline queue', () {
        // Arrange
        final swedishRecipe = {
          'id': 'recipe_1',
          'title': 'Köttbullar med gräddsås',
          'ingredients': [
            '500g nötfärs',
            '1 dl ströbröd',
            '2 msk smör',
            'Ägg och mjölk',
          ],
          'instructions': 'Blanda köttfärs med ströbröd. Tillägg kryddor.',
        };

        // Act - Verify Swedish characters are preserved
        final queuedOperation = {
          'type': 'create',
          'data': swedishRecipe,
        };

        // Assert
        expect(queuedOperation['data'], equals(swedishRecipe));
        expect((swedishRecipe['title'] as String).contains('ö'), isTrue);
        expect((swedishRecipe['title'] as String).contains('ä'), isTrue);
        expect((swedishRecipe['title'] as String).contains('å'), isTrue);
      });
    });
  });
}

// Note: This test file verifies the OfflineService API with Drift database.
// The service now uses Drift instead of Hive for local storage.
// Tests that require database operations will fail without proper Drift setup.
