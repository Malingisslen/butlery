/// Comprehensive unit tests for FirebaseSharedShoppingRepository.
///
/// Tests shared shopping list operations including create, read, status management (viewed/joined/dismissed),
/// permission validation, and direct collaboration support.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseSharedShoppingRepository - Shared Shopping List Management',
      () {
    late FirebaseSharedShoppingRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test data
    const testUserId = 'user-123';
    const testOtherUserId = 'other-user-456';
    const testFriendId = 'friend-789';
    const testListId = 'shared-list-1';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: testUserId, displayName: 'Test User');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

      // Create repository with fake Firestore
      repository = FirebaseSharedShoppingRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    // ===== HELPER METHODS =====

    UnifiedShoppingItem createTestItem(String name) {
      return UnifiedShoppingItem.basic(
        name: name,
        amount: 1.0,
        unit: 'st',
      );
    }

    List<UnifiedShoppingItem> createTestItems() {
      return [
        createTestItem('Mjölk'),
        createTestItem('Bröd'),
        createTestItem('Äpplen'),
      ];
    }

    SharedShoppingList createSharedShoppingList({
      String? id,
      String? sharedByUserId,
      String? sharedByDisplayName,
      List<String>? sharedToUserIds,
      List<UnifiedShoppingItem>? listItems,
      String? listName,
      String? listDescription,
      String? shareMessage,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
      String? originalOwnerId,
      String? originalOwnerDisplayName,
    }) {
      return SharedShoppingList(
        id: id ?? testListId,
        sharedByUserId: sharedByUserId ?? testUserId,
        sharedByDisplayName: sharedByDisplayName ?? 'Test User',
        sharedToUserIds: sharedToUserIds ?? [testOtherUserId],
        shareMessage: shareMessage,
        sharedAt: DateTime(2025, 1, 15),
        listName: listName ?? 'Veckohandling',
        listDescription: listDescription,
        listItems: listItems ?? createTestItems(),
        viewedByUserIds: viewedByUserIds ?? [],
        engagedByUserIds: engagedByUserIds ?? [],
        dismissedByUserIds: dismissedByUserIds ?? [],
        originalOwnerId: originalOwnerId ?? sharedByUserId ?? testUserId,
        originalOwnerDisplayName:
            originalOwnerDisplayName ?? sharedByDisplayName ?? 'Test User',
      );
    }

    Future<void> seedSharedShoppingList(SharedShoppingList sharedList) async {
      await fakeFirestore
          .collection('shared_shopping_lists')
          .doc(sharedList.id)
          .set(sharedList.toFirestore());
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow user to create shared shopping list as themselves',
          () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testUserId,
          sharedToUserIds: [testFriendId],
        );

        // Act & Assert - Should not throw
        await repository.createSharedShoppingList(sharedList);
      });

      test(
          'should reject user from creating shared shopping list as another user',
          () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId, // Different from authenticated user
          sharedToUserIds: [testFriendId],
        );

        // Act & Assert
        expect(
          () => repository.createSharedShoppingList(sharedList),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject shared shopping list with no recipients', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testUserId,
          sharedToUserIds: [], // Empty list
        );

        // Act & Assert
        expect(
          () => repository.createSharedShoppingList(sharedList),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should allow user to view shared shopping list sent to them',
          () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId], // Current user is recipient
        );
        await seedSharedShoppingList(sharedList);

        // Act
        final result = await repository.getSharedShoppingList(testListId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testListId);
      });

      test(
          'should reject user from viewing shared shopping list not sent to them',
          () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testFriendId], // Current user not in list
        );
        await seedSharedShoppingList(sharedList);

        // Act & Assert
        expect(
          () => repository.getSharedShoppingList(testListId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    // ===== CRUD OPERATIONS =====

    group('CRUD Operations', () {
      test('should create shared shopping list successfully', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          id: 'new-list',
          listName: 'My Weekly Shopping',
          sharedByUserId: testUserId,
          sharedToUserIds: [testFriendId, testOtherUserId],
          shareMessage: 'Check out my shopping list!',
        );

        // Act
        final listId = await repository.createSharedShoppingList(sharedList);

        // Assert
        expect(listId, isNotEmpty);

        final doc = await fakeFirestore
            .collection('shared_shopping_lists')
            .doc(listId)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['sharedByUserId'], testUserId);
        expect(doc.data()?['listName'], 'My Weekly Shopping');
      });

      test('should get all shared shopping lists for user', () async {
        // Arrange - Create multiple shared lists
        final list1 = createSharedShoppingList(
          id: 'list-1',
          listName: 'List 1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
        );
        final list2 = createSharedShoppingList(
          id: 'list-2',
          listName: 'List 2',
          sharedByUserId: testFriendId,
          sharedToUserIds: [testUserId],
        );
        final list3 = createSharedShoppingList(
          id: 'list-3',
          listName: 'List 3',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testFriendId], // Not for current user
        );

        await seedSharedShoppingList(list1);
        await seedSharedShoppingList(list2);
        await seedSharedShoppingList(list3);

        // Act
        final lists =
            await repository.getSharedShoppingListsForUser(testUserId);

        // Assert
        expect(lists.length, 2);
        expect(lists.any((l) => l.id == 'list-1'), isTrue);
        expect(lists.any((l) => l.id == 'list-2'), isTrue);
        expect(lists.any((l) => l.id == 'list-3'), isFalse);
      });

      test('should get specific shared shopping list by ID', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          listName: 'Weekly Shopping',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
        );
        await seedSharedShoppingList(sharedList);

        // Act
        final result = await repository.getSharedShoppingList(testListId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testListId);
        expect(result.listName, 'Weekly Shopping');
      });

      test('should return null for non-existent shared shopping list',
          () async {
        // Act
        final result = await repository.getSharedShoppingList('non-existent');

        // Assert
        expect(result, isNull);
      });

      test('should delete shared shopping list by creator', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testUserId, // Creator
          sharedToUserIds: [testFriendId],
        );
        await seedSharedShoppingList(sharedList);

        // Act
        await repository.deleteSharedShoppingList(testListId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_shopping_lists')
            .doc(testListId)
            .get();
        expect(doc.exists, isFalse);
      });
    });

    // ===== STATUS MANAGEMENT =====

    group('Status Management', () {
      test('should mark shared shopping list as viewed', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [], // Not yet viewed
        );
        await seedSharedShoppingList(sharedList);

        // Act
        await repository.markAsViewed(testListId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_shopping_lists')
            .doc(testListId)
            .get();
        final viewedByUserIds =
            List<String>.from(doc.data()?['viewedByUserIds'] ?? []);
        expect(viewedByUserIds, contains(testUserId));
      });

      test('should mark shared shopping list as joined', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          engagedByUserIds: [], // Not yet joined
        );
        await seedSharedShoppingList(sharedList);

        // Act
        await repository.markAsJoined(testListId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_shopping_lists')
            .doc(testListId)
            .get();
        final joinedByUserIds =
            List<String>.from(doc.data()?['joinedByUserIds'] ?? []);
        expect(joinedByUserIds, contains(testUserId));
      });

      test('should mark shared shopping list as dismissed', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [],
        );
        await seedSharedShoppingList(sharedList);

        // Act
        await repository.markAsDismissed(testListId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_shopping_lists')
            .doc(testListId)
            .get();
        final dismissedByUserIds =
            List<String>.from(doc.data()?['dismissedByUserIds'] ?? []);
        expect(dismissedByUserIds, contains(testUserId));
      });

      test('should undismiss shared shopping list', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [testUserId], // Already dismissed
        );
        await seedSharedShoppingList(sharedList);

        // Act
        await repository.undismiss(testListId, testUserId);

        // Assert
        final doc = await fakeFirestore
            .collection('shared_shopping_lists')
            .doc(testListId)
            .get();
        final dismissedByUserIds =
            List<String>.from(doc.data()?['dismissedByUserIds'] ?? []);
        expect(dismissedByUserIds, isNot(contains(testUserId)));
      });
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test('should get unread count for user', () async {
        // Arrange - Create lists, some viewed, some not
        final list1 = createSharedShoppingList(
          id: 'list-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [], // Unread
        );
        final list2 = createSharedShoppingList(
          id: 'list-2',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [testUserId], // Read
        );
        final list3 = createSharedShoppingList(
          id: 'list-3',
          sharedByUserId: testFriendId,
          sharedToUserIds: [testUserId],
          viewedByUserIds: [], // Unread
        );

        await seedSharedShoppingList(list1);
        await seedSharedShoppingList(list2);
        await seedSharedShoppingList(list3);

        // Act
        final unreadCount = await repository.getUnreadCountForUser(testUserId);

        // Assert
        expect(unreadCount, 2); // list-1 and list-3 are unread
      });

      test('should get joined shopping lists for user', () async {
        // Arrange
        final list1 = createSharedShoppingList(
          id: 'list-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          engagedByUserIds: [testUserId], // Joined
        );
        final list2 = createSharedShoppingList(
          id: 'list-2',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          engagedByUserIds: [], // Not joined
        );

        await seedSharedShoppingList(list1);
        await seedSharedShoppingList(list2);

        // Act
        final joinedLists =
            await repository.getJoinedShoppingListsForUser(testUserId);

        // Assert
        expect(joinedLists.length, 1);
        expect(joinedLists.first.id, 'list-1');
      });

      test('should filter out dismissed shopping lists from user query',
          () async {
        // Arrange
        final list1 = createSharedShoppingList(
          id: 'list-1',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [], // Not dismissed
        );
        final list2 = createSharedShoppingList(
          id: 'list-2',
          sharedByUserId: testOtherUserId,
          sharedToUserIds: [testUserId],
          dismissedByUserIds: [testUserId], // Dismissed
        );

        await seedSharedShoppingList(list1);
        await seedSharedShoppingList(list2);

        // Act
        final lists =
            await repository.getSharedShoppingListsForUser(testUserId);

        // Assert
        expect(lists.length, 1);
        expect(lists.first.id, 'list-1');
        expect(lists.any((l) => l.id == 'list-2'), isFalse);
      });
    });

    // ===== EDGE CASES =====

    group('Edge Cases', () {
      test('should handle user not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );

        final sharedList = createSharedShoppingList();

        // Act & Assert
        expect(
          () => repository.createSharedShoppingList(sharedList),
          throwsA(isA<Exception>()), // AuthenticationException
        );
      });

      test('should handle empty shared shopping lists list', () async {
        // Act - No lists seeded
        final lists =
            await repository.getSharedShoppingListsForUser(testUserId);

        // Assert
        expect(lists, isEmpty);
      });

      test('should handle shopping list with empty items', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          listItems: [], // Empty items
          sharedByUserId: testUserId,
          sharedToUserIds: [testFriendId],
        );

        // Act & Assert - Should still create successfully
        await repository.createSharedShoppingList(sharedList);
      });
    });
  });
}
