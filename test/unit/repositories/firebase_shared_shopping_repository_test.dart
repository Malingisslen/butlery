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
import 'package:butlery/core/utils/timestamp_provider.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseSharedShoppingRepository - Shared Shopping List Management', () {
    late FirebaseSharedShoppingRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;
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
      fakeFirestore = FakeFirebaseFirestore();

      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser(uid: testUserId, displayName: 'Test User');

      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

      repository = FirebaseSharedShoppingRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
        timestampProvider: const TestTimestampProvider(),
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
      List<UnifiedShoppingItem>? items,
      int? itemCount,
      String? listName,
      String? listDescription,
      String? shareMessage,
      String? originalOwnerId,
      String? originalOwnerDisplayName,
      int? viewCount,
      int? engagementCount,
      int? dismissalCount,
    }) {
      final finalItemCount =
          itemCount ?? items?.length ?? createTestItems().length;

      return SharedShoppingList(
        id: id ?? testListId,
        sharedByUserId: sharedByUserId ?? testUserId,
        sharedByDisplayName: sharedByDisplayName ?? 'Test User',
        shareMessage: shareMessage,
        sharedAt: DateTime(2025, 1, 15),
        listName: listName ?? 'Veckohandling',
        listDescription: listDescription,
        itemCount: finalItemCount,
        originalOwnerId: originalOwnerId ?? sharedByUserId ?? testUserId,
        originalOwnerDisplayName:
            originalOwnerDisplayName ?? sharedByDisplayName ?? 'Test User',
        viewCount: viewCount ?? 0,
        engagementCount: engagementCount ?? 0,
        dismissalCount: dismissalCount ?? 0,
      );
    }

    /// Seed a SharedShoppingList into FakeFirestore with subcollection data.
    /// Includes contentType discriminator required by subcollection queries.
    Future<void> seedSharedShoppingList(
      SharedShoppingList sharedList, {
      List<String>? memberUserIds,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
      List<String>? collaboratorUserIds,
    }) async {
      // Create main document with contentType discriminator
      final data = sharedList.toFirestore();
      data['contentType'] = 'shopping_list';
      await fakeFirestore
          .collection('shared_content')
          .doc(sharedList.id)
          .set(data);

      final listRef = fakeFirestore
          .collection('shared_content')
          .doc(sharedList.id);

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

      if (collaboratorUserIds != null) {
        for (final userId in collaboratorUserIds) {
          await listRef.collection('collaborators').doc(userId).set({
            'userId': userId,
            'joinedAt': DateTime.now(),
            'isActive': true,
          });
        }
      }

      if (viewedByUserIds != null) {
        for (final userId in viewedByUserIds) {
          await listRef.collection('views').doc(userId).set({
            'userId': userId,
            'viewedAt': DateTime.now(),
          });
        }
      }

      if (engagedByUserIds != null) {
        for (final userId in engagedByUserIds) {
          await listRef.collection('engagements').doc(userId).set({
            'userId': userId,
            'action': 'join',
            'engagedAt': DateTime.now(),
          });
        }
      }

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
      test('should allow user to create shared shopping list with '
          'recipients', () async {
        final sharedList = createSharedShoppingList(sharedByUserId: testUserId);

        final listId = await repository.createSharedShoppingList(
          sharedList,
          recipientIds: [testFriendId],
        );

        // The recipient is seated as a member...
        final memberDoc = await fakeFirestore
            .collection('shared_content')
            .doc(listId)
            .collection('members')
            .doc(testFriendId)
            .get();
        expect(memberDoc.exists, isTrue);

        // ...and BUT-1798's sole membership field names them, which is what
        // the group queries and the GDPR export both scope on.
        final listDoc = await fakeFirestore
            .collection('shared_content')
            .doc(listId)
            .get();
        expect(
          listDoc.data()?['sharedToUserIds'],
          equals([testUserId, testFriendId]),
        );

        // ...and their unread badge counted this share once.
        final counters = await fakeFirestore
            .collection('users')
            .doc(testFriendId)
            .collection('counters')
            .doc('shared_content')
            .get();
        expect(counters.data()?['unreadSharedShoppingLists'], equals(1));
      });

      test(
        'should reject user from creating shared shopping list as another user',
        () async {
          final sharedList = createSharedShoppingList(
            sharedByUserId: testOtherUserId,
          );

          expect(
            () => repository.createSharedShoppingList(
              sharedList,
              recipientIds: [testFriendId],
            ),
            throwsA(isA<PermissionDeniedException>()),
          );
        },
      );

      test('should reject shared shopping list with no recipients', () async {
        final sharedList = createSharedShoppingList(
          sharedByUserId: testUserId,
        );

        expect(
          () => repository.createSharedShoppingList(
            sharedList,
            recipientIds: [],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'should allow user to view shared shopping list sent to them',
        () async {
          final sharedList = createSharedShoppingList(
            sharedByUserId: testOtherUserId,
          );
          // Seed testUserId as member so permission check passes
          await seedSharedShoppingList(
            sharedList,
            memberUserIds: [testUserId],
          );

          final result = await repository.getSharedShoppingList(testListId);

          expect(result, isNotNull);
          expect(result!.id, testListId);
        },
      );

      test(
        'should reject user from viewing shared shopping list not sent to them',
        () async {
          final sharedList = createSharedShoppingList(
            sharedByUserId: testOtherUserId,
          );
          // No member seeding -- testUserId is neither owner nor member
          await seedSharedShoppingList(sharedList);

          expect(
            () => repository.getSharedShoppingList(testListId),
            throwsA(isA<PermissionDeniedException>()),
          );
        },
      );
    });

    // ===== CRUD OPERATIONS =====

    group('CRUD Operations', () {
      test(
        'should create shared shopping list successfully',
        () async {
          final sharedList = createSharedShoppingList(
            id: 'new-list',
            listName: 'My Weekly Shopping',
            sharedByUserId: testUserId,
            shareMessage: 'Check out my shopping list!',
          );

          final listId = await repository.createSharedShoppingList(
            sharedList,
            recipientIds: [testFriendId],
          );

          expect(listId, isNotEmpty);

          final doc = await fakeFirestore
              .collection('shared_content')
              .doc(listId)
              .get();
          expect(doc.exists, isTrue);
          expect(doc.data()?['sharedByUserId'], testUserId);
          expect(doc.data()?['listName'], 'My Weekly Shopping');
        },
      );

      test('should get all shared shopping lists for user', () async {
        // testUserId is a member of list-1 and list-2 but not list-3
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

        await seedSharedShoppingList(list1, memberUserIds: [testUserId]);
        await seedSharedShoppingList(list2, memberUserIds: [testUserId]);
        await seedSharedShoppingList(list3);

        final lists = await repository.getSharedShoppingListsForUser(
          testUserId,
        );

        expect(lists.length, 2);
        expect(lists.any((l) => l.id == 'list-1'), isTrue);
        expect(lists.any((l) => l.id == 'list-2'), isTrue);
        expect(lists.any((l) => l.id == 'list-3'), isFalse);
      });

      test('should get specific shared shopping list by ID', () async {
        final sharedList = createSharedShoppingList(
          listName: 'Weekly Shopping',
          sharedByUserId: testOtherUserId,
        );
        await seedSharedShoppingList(
          sharedList,
          memberUserIds: [testUserId],
        );

        final result = await repository.getSharedShoppingList(testListId);

        expect(result, isNotNull);
        expect(result!.id, testListId);
        expect(result.listName, 'Weekly Shopping');
      });

      test(
        'should return null for non-existent shared shopping list',
        () async {
          final result = await repository.getSharedShoppingList('non-existent');

          expect(result, isNull);
        },
      );

      test('should delete shared shopping list by creator', () async {
        final sharedList = createSharedShoppingList(
          sharedByUserId: testUserId,
        );
        await seedSharedShoppingList(sharedList);

        await repository.deleteSharedShoppingList(testListId);

        final doc = await fakeFirestore
            .collection('shared_content')
            .doc(testListId)
            .get();
        expect(doc.exists, isFalse);
      });
    });

    // ===== STATUS MANAGEMENT =====

    group('Status Management', () {
      test(
        'should mark shared shopping list as viewed',
        () async {
          final sharedList = createSharedShoppingList(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedShoppingList(sharedList);

          await repository.markAsViewed(testListId, testUserId);

          // Check views subcollection (Issue #014)
          final viewDoc = await fakeFirestore
              .collection('shared_content')
              .doc(testListId)
              .collection('views')
              .doc(testUserId)
              .get();
          expect(viewDoc.exists, isTrue);
          expect(viewDoc.data()?['userId'], testUserId);
        },
      );

      test(
        'should mark shared shopping list as joined',
        () async {
          final sharedList = createSharedShoppingList(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedShoppingList(sharedList);

          await repository.markAsJoined(testListId, testUserId);

          // Check engagements subcollection (Issue #014)
          final engagementDoc = await fakeFirestore
              .collection('shared_content')
              .doc(testListId)
              .collection('engagements')
              .doc(testUserId)
              .get();
          expect(engagementDoc.exists, isTrue);
          expect(engagementDoc.data()?['userId'], testUserId);
          expect(engagementDoc.data()?['action'], 'join');
        },
      );

      test(
        'should mark shared shopping list as dismissed',
        () async {
          final sharedList = createSharedShoppingList(
            sharedByUserId: testOtherUserId,
          );
          await seedSharedShoppingList(sharedList);

          await repository.markAsDismissed(testListId, testUserId);

          // Check dismissals subcollection (Issue #014)
          final dismissalDoc = await fakeFirestore
              .collection('shared_content')
              .doc(testListId)
              .collection('dismissals')
              .doc(testUserId)
              .get();
          expect(dismissalDoc.exists, isTrue);
          expect(dismissalDoc.data()?['userId'], testUserId);
        },
      );

      test('should undismiss shared shopping list', () async {
        final sharedList = createSharedShoppingList(
          sharedByUserId: testOtherUserId,
        );
        // Seed with testUserId already dismissed
        await seedSharedShoppingList(
          sharedList,
          dismissedByUserIds: [testUserId],
        );

        // Verify dismissal exists before undismiss
        var dismissalDoc = await fakeFirestore
            .collection('shared_content')
            .doc(testListId)
            .collection('dismissals')
            .doc(testUserId)
            .get();
        expect(dismissalDoc.exists, isTrue);

        await repository.undismiss(testListId, testUserId);

        // Verify dismissal subcollection doc was removed (Issue #014)
        dismissalDoc = await fakeFirestore
            .collection('shared_content')
            .doc(testListId)
            .collection('dismissals')
            .doc(testUserId)
            .get();
        expect(dismissalDoc.exists, isFalse);
      });
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test('should get unread count of 0 when no counter exists', () async {
        // getUnreadCountForUser uses denormalized counters.
        // Without seeding, the counter doc doesn't exist -> returns 0.
        final unreadCount = await repository.getUnreadCountForUser(testUserId);

        expect(unreadCount, 0);
      });

      test('should get joined shopping lists for user', () async {
        final list1 = createSharedShoppingList(
          id: 'list-1',
          sharedByUserId: testOtherUserId,
        );
        final list2 = createSharedShoppingList(
          id: 'list-2',
          sharedByUserId: testOtherUserId,
        );

        // list-1 has engagement, list-2 does not
        await seedSharedShoppingList(list1, engagedByUserIds: [testUserId]);
        await seedSharedShoppingList(list2);

        final joinedLists = await repository.getJoinedShoppingListsForUser(
          testUserId,
        );

        expect(joinedLists.length, 1);
        expect(joinedLists.first.id, 'list-1');
      });

      test('should return empty list when user has no memberships', () async {
        // No lists seeded with testUserId as member
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

        final lists = await repository.getSharedShoppingListsForUser(
          testUserId,
        );

        expect(lists, isEmpty);
      });
    });

    // ===== EDGE CASES =====

    group('Edge Cases', () {
      test('should handle user not authenticated', () async {
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );

        final sharedList = createSharedShoppingList();

        expect(
          () => repository.createSharedShoppingList(
            sharedList,
            recipientIds: [testFriendId],
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle empty shared shopping lists list', () async {
        final lists = await repository.getSharedShoppingListsForUser(
          testUserId,
        );

        expect(lists, isEmpty);
      });

      test('should handle shopping list with empty items', () async {
        final sharedList = createSharedShoppingList(
          items: [],
          sharedByUserId: testUserId,
        );

        final listId = await repository.createSharedShoppingList(
          sharedList,
          recipientIds: [testFriendId],
        );

        // An empty list is still shareable: the document lands and the
        // recipient is still seated. BUT-1716 removed the item API this used to
        // read back through, so the assertion is on the two things that still
        // exist — the share document and the member row.
        final listDoc = await fakeFirestore
            .collection('shared_content')
            .doc(listId)
            .get();
        expect(listDoc.exists, isTrue);
        final memberDoc = await fakeFirestore
            .collection('shared_content')
            .doc(listId)
            .collection('members')
            .doc(testFriendId)
            .get();
        expect(memberDoc.exists, isTrue);
      });
    });
  });
}
