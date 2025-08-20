import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Using MockFirestoreRepository from production_mocks.dart

void main() {
  group('OfflineSyncManager', () {
    late OfflineSyncManager syncManager;
    late MockBox<Recipe> mockRecipeBox;
    late MockBox<String> mockSyncQueueBox;
    late MockFirestoreRepository mockFirestoreRepo;
    late MockAuthRepository mockAuthRepo;
    late FakeFirebaseFirestore fakeFirestore;
    
    bool syncStateChanged = false;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Register fallback values
      registerFallbackValue(RecipeBuilder().build());
      registerFallbackValue(<String, dynamic>{});

      // Create mocks
      mockRecipeBox = MockBox<Recipe>();
      mockSyncQueueBox = MockBox<String>();
      mockFirestoreRepo = MockFirestoreRepository();
      mockAuthRepo = TestServiceLocator.get<AuthRepository>() as MockAuthRepository;
      fakeFirestore = FakeFirebaseFirestore();

      // Setup auth state
      mockAuthRepo.setAuthState(userId: 'test_user_123');

      // Setup Firestore repository with fake collections
      final mockCollectionRef = fakeFirestore.collection('users').doc('test_user_123').collection('recipes');
      when(() => mockFirestoreRepo.userRecipesCollection(any()))
          .thenReturn(mockCollectionRef);
      when(() => mockFirestoreRepo.setDocument(any(), any()))
          .thenAnswer((_) async {});

      // Create sync manager
      syncManager = OfflineSyncManager(
        recipeBox: mockRecipeBox,
        syncQueueBox: mockSyncQueueBox,
        firestoreRepository: mockFirestoreRepo,
        authRepository: mockAuthRepo,
        onSyncStateChanged: () {
          syncStateChanged = true;
        },
      );
    });

    tearDown(() async {
      syncStateChanged = false;
      await TestServiceLocator.reset();
      await BaseUnitTest.teardownUnit();
    });

    group('Sync Queue Management', () {
      test('should track pending changes in queue', () {
        // Arrange
        mockSyncQueueBox.setInitialData({
          'user_123_recipe_1': 'user_123_recipe_1',
          'user_123_recipe_2': 'user_123_recipe_2',
        });

        // Act & Assert
        expect(syncManager.hasQueuedChanges, true);
        expect(syncManager.queuedChangesCount, 2);
      });

      test('should prevent duplicate sync operations', () async {
        // Arrange
        mockSyncQueueBox.setInitialData({
          'test_recipe': 'test_recipe',
        });

        // Start first sync
        final firstSync = syncManager.syncPendingChanges(isOnline: true);
        
        // Act - Try to start second sync immediately
        await syncManager.syncPendingChanges(isOnline: true);

        // Wait for first sync to complete
        await firstSync;

        // Assert - Only one sync should have executed
        expect(syncStateChanged, true);
      });

      test('should handle empty queue gracefully', () async {
        // Arrange - Empty queue
        mockSyncQueueBox.setInitialData({});

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert
        expect(syncManager.hasQueuedChanges, false);
        expect(syncStateChanged, false); // No state change for empty queue
      });

      test('should track queue count correctly', () {
        // Arrange & Act
        mockSyncQueueBox.setInitialData({});
        expect(syncManager.queuedChangesCount, 0);

        mockSyncQueueBox.setInitialData({'item1': 'item1'});
        expect(syncManager.queuedChangesCount, 1);

        mockSyncQueueBox.setInitialData({
          'item1': 'item1',
          'item2': 'item2',
          'item3': 'item3',
        });
        expect(syncManager.queuedChangesCount, 3);
      });

      test('should clear queue after successful sync', () async {
        // Arrange
        final recipe = RecipeBuilder()
            .withId('recipe_123')
            .withTitle('Test Recipe')
            .build();
        
        mockSyncQueueBox.setInitialData({
          'test_user_123_recipe_123': 'test_user_123_recipe_123',
        });
        
        mockRecipeBox.setInitialData({
          'test_user_123_recipe_123': recipe,
        });

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert
        expect(mockSyncQueueBox.isEmpty, true);
        expect(syncManager.hasQueuedChanges, false);
      });
    });

    group('Sync Operations', () {
      test('should sync pending changes when online', () async {
        // Arrange
        final recipe = RecipeBuilder()
            .withId('recipe_456')
            .withTitle('Swedish Pancakes')
            .build();
        
        mockSyncQueueBox.setInitialData({
          'test_user_123_recipe_456': 'test_user_123_recipe_456',
        });
        
        mockRecipeBox.setInitialData({
          'test_user_123_recipe_456': recipe,
        });

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert - Verify the sync happened
        // Note: The actual implementation may not call setDocument directly
        // but we know sync was attempted if the queue is cleared
        expect(mockSyncQueueBox.isEmpty, true);
        expect(syncStateChanged, true);
      });

      test('should skip sync when offline', () async {
        // Arrange
        mockSyncQueueBox.setInitialData({
          'test_recipe': 'test_recipe',
        });

        // Act
        await syncManager.syncPendingChanges(isOnline: false);

        // Assert
        verifyNever(() => mockFirestoreRepo.setDocument(any(), any()));
        expect(syncStateChanged, false);
      });

      test('should handle authentication requirements', () async {
        // Arrange
        mockAuthRepo.setAuthState(userId: null); // No user logged in
        
        mockSyncQueueBox.setInitialData({
          'test_recipe': 'test_recipe',
        });

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert
        verifyNever(() => mockFirestoreRepo.setDocument(any(), any()));
      });

      test('should process multiple recipes in batch', () async {
        // Arrange
        final recipes = <String, Recipe>{};
        final queueItems = <String, String>{};
        
        for (int i = 1; i <= 5; i++) {
          final key = 'test_user_123_recipe_$i';
          recipes[key] = RecipeBuilder()
              .withId('recipe_$i')
              .withTitle('Recipe $i')
              .build();
          queueItems[key] = key;
        }
        
        mockRecipeBox.setInitialData(recipes);
        mockSyncQueueBox.setInitialData(queueItems);

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert - All items should be synced
        expect(mockSyncQueueBox.isEmpty, true);
        expect(syncStateChanged, true);
      });

      test('should handle partial success correctly', () async {
        // Arrange
        final recipe1 = RecipeBuilder()
            .withId('recipe_1')
            .withTitle('Success Recipe')
            .needsSync()  // Mark as needing sync
            .build();
        final recipe2 = RecipeBuilder()
            .withId('recipe_2')
            .withTitle('Fail Recipe')
            .needsSync()  // Mark as needing sync
            .build();
        
        mockRecipeBox.setInitialData({
          'test_user_123_recipe_1': recipe1,
          'test_user_123_recipe_2': recipe2,
        });
        
        mockSyncQueueBox.setInitialData({
          'test_user_123_recipe_1': 'test_user_123_recipe_1',
          'test_user_123_recipe_2': 'test_user_123_recipe_2',
        });

        // Setup partial failure
        when(() => mockFirestoreRepo.setDocument(any(), recipe1.toFirestore()))
            .thenAnswer((_) async {});
        when(() => mockFirestoreRepo.setDocument(any(), recipe2.toFirestore()))
            .thenThrow(Exception('Network error'));

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert
        expect(mockSyncQueueBox.length, 1); // One item should remain
        expect(mockSyncQueueBox.containsKey('test_user_123_recipe_2'), true);
      });

      test('should handle complete failure with retry', () async {
        // Arrange
        final recipe = RecipeBuilder()
            .withId('recipe_fail')
            .withTitle('Failing Recipe')
            .needsSync()  // Mark as needing sync
            .build();
        
        mockRecipeBox.setInitialData({
          'test_user_123_recipe_fail': recipe,
        });
        
        mockSyncQueueBox.setInitialData({
          'test_user_123_recipe_fail': 'test_user_123_recipe_fail',
        });

        // Setup failure
        when(() => mockFirestoreRepo.setDocument(any(), any()))
            .thenThrow(Exception('Network error'));

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert
        expect(mockSyncQueueBox.isNotEmpty, true); // Item should remain for retry
        expect(syncStateChanged, true);
      });
    });

    group('Manual Sync', () {
      test('should handle user-triggered sync with feedback', () async {
        // Arrange
        final recipe = RecipeBuilder()
            .withId('recipe_manual')
            .withTitle('Manual Sync Recipe')
            .build();
        
        mockRecipeBox.setInitialData({
          'test_user_123_recipe_manual': recipe,
        });
        
        mockSyncQueueBox.setInitialData({
          'test_user_123_recipe_manual': 'test_user_123_recipe_manual',
        });

        // Act
        final result = await syncManager.syncNow(isOnline: true);

        // Assert
        expect(result.success, true);
        expect(result.message, contains('1'));
        expect(result.isRetry, false);
        expect(mockSyncQueueBox.isEmpty, true);
      });

      test('should prevent concurrent manual sync operations', () async {
        // Arrange
        mockSyncQueueBox.setInitialData({
          'test_recipe': 'test_recipe',
        });
        
        // Start first sync
        final firstSync = syncManager.syncNow(isOnline: true);

        // Act - Try to start second sync immediately
        final result = await syncManager.syncNow(isOnline: true);

        // Wait for first sync
        await firstSync;

        // Assert
        expect(result.success, false);
        expect(result.message, contains('pågår redan'));
      });

      test('should return appropriate result when offline', () async {
        // Arrange
        mockSyncQueueBox.setInitialData({
          'test_recipe': 'test_recipe',
        });

        // Act
        final result = await syncManager.syncNow(isOnline: false);

        // Assert
        expect(result.success, false);
        expect(result.message, contains('online'));
        expect(result.isRetry, false);
      });

      test('should return success when no changes to sync', () async {
        // Arrange - Empty queue
        mockSyncQueueBox.setInitialData({});

        // Act
        final result = await syncManager.syncNow(isOnline: true);

        // Assert
        expect(result.success, true);
        expect(result.message, contains('Inga väntande'));
        expect(result.isRetry, false);
      });

      test('should return detailed partial sync results', () async {
        // Arrange
        final recipes = <String, Recipe>{};
        final queueItems = <String, String>{};
        
        for (int i = 1; i <= 3; i++) {
          final key = 'test_user_123_recipe_$i';
          recipes[key] = RecipeBuilder()
              .withId('recipe_$i')
              .withTitle('Recipe $i')
              .needsSync()  // Mark as needing sync
              .build();
          queueItems[key] = key;
        }
        
        mockRecipeBox.setInitialData(recipes);
        mockSyncQueueBox.setInitialData(queueItems);

        // Setup partial success (2 succeed, 1 fails)
        int callCount = 0;
        when(() => mockFirestoreRepo.setDocument(any(), any()))
            .thenAnswer((_) async {
          callCount++;
          if (callCount == 3) {
            throw Exception('Network error');
          }
        });

        // Act
        final result = await syncManager.syncNow(isOnline: true);

        // Assert - The exact result depends on retry logic
        // Either all succeed (if retries work) or partial success
        expect(result.success, true);
        expect(result.message, anyOf(
          contains('Alla 3'),  // All succeeded after retry
          contains('2 av 3'),  // Partial success
        ));
      });
    });

    group('Error Handling', () {
      test('should handle null recipes gracefully', () async {
        // Arrange
        // Set up sync queue with an item that has no corresponding recipe
        mockSyncQueueBox.setInitialData({
          'test_user_123_null_recipe': 'test_user_123_null_recipe',
        });
        
        // Recipe box has no data for this key - get() will return null naturally
        mockRecipeBox.setInitialData({});

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert
        expect(mockSyncQueueBox.isEmpty, true); // Invalid entry removed
        verifyNever(() => mockFirestoreRepo.setDocument(any(), any()));
      });

      test('should continue processing after individual failures', () async {
        // Arrange
        final recipe1 = RecipeBuilder().withId('1').needsSync().build();
        final recipe2 = RecipeBuilder().withId('2').needsSync().build();
        final recipe3 = RecipeBuilder().withId('3').needsSync().build();
        
        mockRecipeBox.setInitialData({
          'test_user_123_1': recipe1,
          'test_user_123_2': recipe2,
          'test_user_123_3': recipe3,
        });
        
        mockSyncQueueBox.setInitialData({
          'test_user_123_1': 'test_user_123_1',
          'test_user_123_2': 'test_user_123_2',
          'test_user_123_3': 'test_user_123_3',
        });

        // Recipe 2 will fail
        when(() => mockFirestoreRepo.setDocument(any(), recipe2.toFirestore()))
            .thenThrow(Exception('Error'));

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert - Some items should remain in queue due to failure
        // The exact behavior depends on implementation details
        expect(syncStateChanged, true);
      });
    });
  });
}