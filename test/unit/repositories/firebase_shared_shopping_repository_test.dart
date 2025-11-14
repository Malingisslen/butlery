/// Comprehensive unit tests for FirebaseSharedShoppingRepository.
///
/// **Issue #014**: Migrated to subcollection-based status tracking (removed arrays).
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

    /// Create a SharedShoppingList with count fields (Issue #014 - arrays removed).
    SharedShoppingList createSharedShoppingList({
      String? id,
      String? sharedByUserId,
      String? sharedByDisplayName,
      List<UnifiedShoppingItem>? listItems,
      String? listName,
      String? listDescription,
      String? shareMessage,
      String? originalOwnerId,
      String? originalOwnerDisplayName,
      int? viewCount,
      int? engagementCount,
      int? dismissalCount,
    }) {
      return SharedShoppingList(
        id: id ?? testListId,
        sharedByUserId: sharedByUserId ?? testUserId,
        sharedByDisplayName: sharedByDisplayName ?? 'Test User',
        shareMessage: shareMessage,
        sharedAt: DateTime(2025, 1, 15),
        listName: listName ?? 'Veckohandling',
        listDescription: listDescription,
        listItems: listItems ?? createTestItems(),
        originalOwnerId: originalOwnerId ?? sharedByUserId ?? testUserId,
        originalOwnerDisplayName:
            originalOwnerDisplayName ?? sharedByDisplayName ?? 'Test User',
        viewCount: viewCount ?? 0,
        engagementCount: engagementCount ?? 0,
        dismissalCount: dismissalCount ?? 0,
      );
    }

    /// Seed a SharedShoppingList into FakeFirestore with optional subcollection data (Issue #014).
    Future<void> seedSharedShoppingList(
      SharedShoppingList sharedList, {
      List<String>? memberUserIds,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
      List<String>? collaboratorUserIds,
    }) async {
      // Create main document
      await fakeFirestore
          .collection('shared_shopping_lists')
          .doc(sharedList.id)
          .set(sharedList.toFirestore());

      // Create subcollection documents (Issue #014)
      final listRef = fakeFirestore.collection('shared_shopping_lists').doc(sharedList.id);

      // Seed members subcollection
      if (memberUserIds != null) {
        for (final userId in memberUserIds) {
          await listRef.collection('members').doc(userId).set({
            'userId': userId,
            'addedBy': sharedList.sharedByUserId,
            'addedAt': DateTime.now(),
            'role': 'member',
          });
        }
      }

      // Seed collaborators subcollection (shopping lists allow real-time collaboration)
      if (collaboratorUserIds != null) {
        for (final userId in collaboratorUserIds) {
          await listRef.collection('collaborators').doc(userId).set({
            'userId': userId,
            'joinedAt': DateTime.now(),
            'isActive': true,
          });
        }
      }

      // Seed views subcollection
      if (viewedByUserIds != null) {
        for (final userId in viewedByUserIds) {
          await listRef.collection('views').doc(userId).set({
            'userId': userId,
            'viewedAt': DateTime.now(),
          });
        }
      }

      // Seed engagements subcollection
      if (engagedByUserIds != null) {
        for (final userId in engagedByUserIds) {
          await listRef.collection('engagements').doc(userId).set({
            'userId': userId,
            'action': 'join',
            'engagedAt': DateTime.now(),
          });
        }
      }

      // Seed dismissals subcollection
      if (dismissedByUserIds != null) {
        for (final userId in dismissedByUserIds) {
          await listRef.collection('dismissals').doc(userId).set({
            'userId': userId,
            'dismissedAt': DateTime.now(),
          });
        }
      }
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow user to create shared shopping list with recipients',
          () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testUserId,
        );

        // Act & Assert - Should not throw
        await repository.createSharedShoppingList(
          sharedList,
          recipientIds: [testFriendId], // Share with friend
        );
      });

      test(
          'should reject user from creating shared shopping list as another user',
          () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId, // Different from authenticated user
        );

        // Act & Assert
        expect(
          () => repository.createSharedShoppingList(
            sharedList,
            recipientIds: [testFriendId],
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject shared shopping list with no recipients', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testUserId,
        );

        // Act & Assert
        expect(
          () => repository.createSharedShoppingList(
            sharedList,
            recipientIds: [], // Empty list - should fail
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should allow user to view shared shopping list sent to them',
          () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
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
          shareMessage: 'Check out my shopping list!',
        );

        // Act
        final listId = await repository.createSharedShoppingList(
          sharedList,
          recipientIds: [testFriendId],
        );

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
        );
        final list2 = createSharedShoppingList(
          id: 'list-2',
          listName: 'List 2',
          sharedByUserId: testFriendId,
        );
        final list3 = createSharedShoppingList(
          id: 'list-3',
          listName: 'List 3',
          sharedByUserId: testOtherUserId,
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
        );
        await seedSharedShoppingList(sharedList);

        // Act
        await repository.markAsViewed(testListId, testUserId);

        // Assert - Check views subcollection (Issue #014)
        final viewDoc = await fakeFirestore
            .collection('shared_shopping_lists')
            .doc(testListId)
            .collection('views')
            .doc(testUserId)
            .get();
        expect(viewDoc.exists, isTrue);
        expect(viewDoc.data()?['userId'], testUserId);
      });

      test('should mark shared shopping list as joined', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
        );
        await seedSharedShoppingList(sharedList);

        // Act
        await repository.markAsJoined(testListId, testUserId);

        // Assert - Check engagements subcollection (Issue #014)
        final engagementDoc = await fakeFirestore
            .collection('shared_shopping_lists')
            .doc(testListId)
            .collection('engagements')
            .doc(testUserId)
            .get();
        expect(engagementDoc.exists, isTrue);
        expect(engagementDoc.data()?['userId'], testUserId);
        expect(engagementDoc.data()?['action'], 'join');
      });

      test('should mark shared shopping list as dismissed', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
        );
        await seedSharedShoppingList(sharedList);

        // Act
        await repository.markAsDismissed(testListId, testUserId);

        // Assert - Check dismissals subcollection (Issue #014)
        final dismissalDoc = await fakeFirestore
            .collection('shared_shopping_lists')
            .doc(testListId)
            .collection('dismissals')
            .doc(testUserId)
            .get();
        expect(dismissalDoc.exists, isTrue);
        expect(dismissalDoc.data()?['userId'], testUserId);
      });

      test('should undismiss shared shopping list', () async {
        // Arrange
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
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
        );
        final list2 = createSharedShoppingList(
          id: 'list-2',
          sharedByUserId: testOtherUserId,
        );
        final list3 = createSharedShoppingList(
          id: 'list-3',
          sharedByUserId: testFriendId,
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
        );
        final list2 = createSharedShoppingList(
          id: 'list-2',
          sharedByUserId: testOtherUserId,
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
        );
        final list2 = createSharedShoppingList(
          id: 'list-2',
          sharedByUserId: testOtherUserId,
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
          () => repository.createSharedShoppingList(
            sharedList,
            recipientIds: [testFriendId],
          ),
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
        );

        // Act & Assert - Should still create successfully
        await repository.createSharedShoppingList(
          sharedList,
          recipientIds: [testFriendId],
        );
      });
    });
  });
}
