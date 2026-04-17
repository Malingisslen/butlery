import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock classes for Drift DAOs
class MockAppDatabase extends Mock implements AppDatabase {}

class MockRecipeDao extends Mock implements RecipeDao {}

class MockSyncQueueDao extends Mock implements SyncQueueDao {}

// Fake SyncQueueEntry for stubbing
class FakeSyncQueueEntry {
  final int id;
  final String recipeId;
  final String userId;
  final String operation;
  final DateTime queuedAt;
  final int retryCount;
  final String? lastError;

  FakeSyncQueueEntry({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.operation,
    DateTime? queuedAt,
    this.retryCount = 0,
    this.lastError,
  }) : queuedAt = queuedAt ?? DateTime.now();
}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(SyncOperation.update);
    registerFallbackValue(RecipeBuilder().build());
    registerFallbackValue(<String, dynamic>{});
  });

  group('OfflineSyncManager (Drift)', () {
    late OfflineSyncManager syncManager;
    late MockAppDatabase mockDatabase;
    late MockRecipeDao mockRecipeDao;
    late MockSyncQueueDao mockSyncQueueDao;
    late FakeFirestoreRepository mockFirestoreRepo;
    late MockAuthRepository mockAuthRepo;
    late FakeFirebaseFirestore fakeFirestore;

    bool syncStateChanged = false;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks
      mockDatabase = MockAppDatabase();
      mockRecipeDao = MockRecipeDao();
      mockSyncQueueDao = MockSyncQueueDao();
      mockFirestoreRepo = FakeFirestoreRepository();
      mockAuthRepo =
          TestServiceLocator.get<AuthRepository>() as MockAuthRepository;
      fakeFirestore = FakeFirebaseFirestore();

      // Wire up database DAOs
      when(() => mockDatabase.recipeDao).thenReturn(mockRecipeDao);
      when(() => mockDatabase.syncQueueDao).thenReturn(mockSyncQueueDao);

      // Setup auth state
      mockAuthRepo.setAuthState(userId: 'test_user_123');

      // Setup Firestore repository
      final mockCollectionRef = fakeFirestore
          .collection('users')
          .doc('test_user_123')
          .collection('recipes');
      when(() => mockFirestoreRepo.userRecipesCollection(any()))
          .thenReturn(mockCollectionRef);
      when(() => mockFirestoreRepo.setDocument(any(), any()))
          .thenAnswer((_) async {});

      // Create sync manager with mock database
      syncManager = OfflineSyncManager(
        database: mockDatabase,
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
      test('should report pending changes count', () async {
        // Arrange
        when(() => mockSyncQueueDao.countPending(any()))
            .thenAnswer((_) async => 2);

        // Act
        final count = await syncManager.queuedChangesCount;

        // Assert
        expect(count, 2);
      });

      test('should report has queued changes', () async {
        // Arrange
        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => true);

        // Act
        final hasChanges = await syncManager.hasQueuedChanges;

        // Assert
        expect(hasChanges, true);
      });

      test('should report no changes when queue is empty', () async {
        // Arrange
        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => false);

        // Act
        final hasChanges = await syncManager.hasQueuedChanges;

        // Assert
        expect(hasChanges, false);
      });
    });

    group('Sync Operations', () {
      test('should skip sync when offline', () async {
        // Arrange — prod checks hasPending before checking isOnline
        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => true);

        // Act
        await syncManager.syncPendingChanges(isOnline: false);

        // Assert — hasPending is called, but actual sync is skipped
        verify(() => mockSyncQueueDao.hasPending(any())).called(1);
      });

      test('should skip sync when no pending changes', () async {
        // Arrange
        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => false);

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert
        verifyNever(() => mockSyncQueueDao.getPendingForUser(any()));
      });
    });

    group('State Management', () {
      test('should track syncing state', () {
        // Assert initial state
        expect(syncManager.isSyncing, isFalse);
      });

      test('should notify on state changes', () async {
        // Arrange
        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => true);
        when(() => mockSyncQueueDao.countPending(any()))
            .thenAnswer((_) async => 1);
        when(() => mockSyncQueueDao.getPendingForUser(any()))
            .thenAnswer((_) async => []);

        // Act
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert
        expect(syncStateChanged, isTrue);
      });
    });

    group('Manual Sync', () {
      test('should return result when syncing is in progress', () async {
        // Arrange - Start a sync to set isSyncing to true
        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => true);
        when(() => mockSyncQueueDao.countPending(any()))
            .thenAnswer((_) async => 1);
        when(() => mockSyncQueueDao.getPendingForUser(any()))
            .thenAnswer((_) async {
          // Simulate slow sync
          await Future.delayed(const Duration(milliseconds: 100));
          return [];
        });

        // Start first sync (don't await)
        final firstSync = syncManager.syncPendingChanges(isOnline: true);

        // Act - Try to start manual sync while first is in progress
        final result = await syncManager.syncNow(isOnline: true);

        // Cleanup
        await firstSync;

        // Assert — result indicates sync couldn't start
        expect(result.message, isNotEmpty);
      });

      test('should return result when offline', () async {
        // Act
        final result = await syncManager.syncNow(isOnline: false);

        // Assert
        expect(result.success, isFalse);
        expect(result.message, contains('online'));
      });

      test('should return result when no pending changes', () async {
        // Arrange
        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => false);

        // Act
        final result = await syncManager.syncNow(isOnline: true);

        // Assert
        expect(result.success, isTrue);
        expect(result.message, contains('Inga'));
      });
    });

    group('H9: Tag Operation Processing', () {
      late bool tagCallbackInvoked;
      late String? taggedRecipeId;
      late OfflineSyncManager syncManagerWithTagCallback;

      setUp(() {
        tagCallbackInvoked = false;
        taggedRecipeId = null;

        // Create sync manager with tag callback
        syncManagerWithTagCallback = OfflineSyncManager(
          database: mockDatabase,
          firestoreRepository: mockFirestoreRepo,
          authRepository: mockAuthRepo,
          onSyncStateChanged: () {
            syncStateChanged = true;
          },
          onTagRecipe: (recipeId) async {
            tagCallbackInvoked = true;
            taggedRecipeId = recipeId;
          },
        );
      });

      test('should call onTagRecipe callback for tag operations', () async {
        // Arrange
        const recipeId = 'recipe_to_tag';
        final tagEntry = SyncQueueEntry(
          id: 1,
          userId: 'test_user_123',
          recipeId: recipeId,
          operation: SyncOperation.tag.name,
          queuedAt: DateTime.now(),
          retryCount: 0,
          lastError: null,
        );

        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => true);
        when(() => mockSyncQueueDao.countPending(any()))
            .thenAnswer((_) async => 1);
        when(() => mockSyncQueueDao.getPendingForUser(any()))
            .thenAnswer((_) async => [tagEntry]);
        when(() => mockSyncQueueDao.dequeue(any())).thenAnswer((_) async => 1);

        // Act
        await syncManagerWithTagCallback.syncPendingChanges(isOnline: true);

        // Assert
        expect(tagCallbackInvoked, isTrue);
        expect(taggedRecipeId, equals(recipeId));
      });

      test('should dequeue tag operation after successful callback', () async {
        // Arrange
        const recipeId = 'recipe_to_tag';
        final tagEntry = SyncQueueEntry(
          id: 42,
          userId: 'test_user_123',
          recipeId: recipeId,
          operation: SyncOperation.tag.name,
          queuedAt: DateTime.now(),
          retryCount: 0,
          lastError: null,
        );

        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => true);
        when(() => mockSyncQueueDao.countPending(any()))
            .thenAnswer((_) async => 1);
        when(() => mockSyncQueueDao.getPendingForUser(any()))
            .thenAnswer((_) async => [tagEntry]);
        when(() => mockSyncQueueDao.dequeue(any())).thenAnswer((_) async => 1);

        // Act
        await syncManagerWithTagCallback.syncPendingChanges(isOnline: true);

        // Assert - verify dequeue was called with correct ID
        verify(() => mockSyncQueueDao.dequeue(42)).called(1);
      });

      test('should skip and dequeue tag operation when no callback configured',
          () async {
        // Arrange - Use syncManager without callback
        const recipeId = 'recipe_no_callback';
        final tagEntry = SyncQueueEntry(
          id: 99,
          userId: 'test_user_123',
          recipeId: recipeId,
          operation: SyncOperation.tag.name,
          queuedAt: DateTime.now(),
          retryCount: 0,
          lastError: null,
        );

        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => true);
        when(() => mockSyncQueueDao.countPending(any()))
            .thenAnswer((_) async => 1);
        when(() => mockSyncQueueDao.getPendingForUser(any()))
            .thenAnswer((_) async => [tagEntry]);
        when(() => mockSyncQueueDao.dequeue(any())).thenAnswer((_) async => 1);

        // Act - use original syncManager (no tag callback)
        await syncManager.syncPendingChanges(isOnline: true);

        // Assert - should still dequeue even without callback
        verify(() => mockSyncQueueDao.dequeue(99)).called(1);
      });

      test('should process multiple tag operations in sequence', () async {
        // Arrange - Two tag operations for different recipes
        final tagEntry1 = SyncQueueEntry(
          id: 1,
          userId: 'test_user_123',
          recipeId: 'recipe_1',
          operation: SyncOperation.tag.name,
          queuedAt: DateTime.now(),
          retryCount: 0,
          lastError: null,
        );

        final tagEntry2 = SyncQueueEntry(
          id: 2,
          userId: 'test_user_123',
          recipeId: 'recipe_2',
          operation: SyncOperation.tag.name,
          queuedAt: DateTime.now(),
          retryCount: 0,
          lastError: null,
        );

        final taggedRecipes = <String>[];
        final multiTagSyncManager = OfflineSyncManager(
          database: mockDatabase,
          firestoreRepository: mockFirestoreRepo,
          authRepository: mockAuthRepo,
          onTagRecipe: (recipeId) async {
            taggedRecipes.add(recipeId);
          },
        );

        when(() => mockSyncQueueDao.hasPending(any()))
            .thenAnswer((_) async => true);
        when(() => mockSyncQueueDao.countPending(any()))
            .thenAnswer((_) async => 2);
        when(() => mockSyncQueueDao.getPendingForUser(any()))
            .thenAnswer((_) async => [tagEntry1, tagEntry2]);
        when(() => mockSyncQueueDao.dequeue(any())).thenAnswer((_) async => 1);

        // Act
        await multiTagSyncManager.syncPendingChanges(isOnline: true);

        // Assert - both tag operations should be processed
        verify(() => mockSyncQueueDao.dequeue(1)).called(1);
        verify(() => mockSyncQueueDao.dequeue(2)).called(1);
        expect(taggedRecipes, containsAll(['recipe_1', 'recipe_2']));
      });

      test('should queue tagging operation via queueTagging method', () async {
        // Arrange
        const userId = 'test_user';
        const recipeId = 'recipe_to_queue';

        when(() => mockSyncQueueDao.enqueue(
              userId: any(named: 'userId'),
              recipeId: any(named: 'recipeId'),
              operation: any(named: 'operation'),
            )).thenAnswer((_) async => 1);

        // Act
        await syncManagerWithTagCallback.queueTagging(
          userId: userId,
          recipeId: recipeId,
        );

        // Assert
        verify(() => mockSyncQueueDao.enqueue(
              userId: userId,
              recipeId: recipeId,
              operation: SyncOperation.tag,
            )).called(1);
      });
    });
  });
}
