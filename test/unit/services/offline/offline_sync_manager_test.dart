import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
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
  group('OfflineSyncManager (Drift)', () {
    late OfflineSyncManager syncManager;
    late MockAppDatabase mockDatabase;
    late MockRecipeDao mockRecipeDao;
    late MockSyncQueueDao mockSyncQueueDao;
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
      mockDatabase = MockAppDatabase();
      mockRecipeDao = MockRecipeDao();
      mockSyncQueueDao = MockSyncQueueDao();
      mockFirestoreRepo = MockFirestoreRepository();
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
        // Act
        await syncManager.syncPendingChanges(isOnline: false);

        // Assert - Should not query database when offline
        verifyNever(() => mockSyncQueueDao.hasPending(any()));
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

        // Assert
        expect(result.success, isFalse);
        expect(result.message, contains('pågår'));
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
  });
}
