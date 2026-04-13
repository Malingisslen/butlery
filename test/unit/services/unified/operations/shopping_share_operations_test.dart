import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/shopping_share_operations.dart';
import 'package:butlery/services/unified/operations/modules/shopping_social_share_module.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

// Local pure mock — avoids concrete overrides on centralized MockFirestoreRepository
class _MockFirestoreRepository extends Mock implements FirestoreRepository {}

const _testUserId = 'test-user-123';
const _testListId = 'list-123';

void main() {
  group('ShoppingShareOperations', () {
    late ShoppingShareOperations operations;
    late FakeFirebaseFirestore fakeFirestore;
    late MockPermissionService mockPermissionService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      fakeFirestore = FakeFirebaseFirestore();

      final mockFirestoreRepository = _MockFirestoreRepository();
      when(() => mockFirestoreRepository.firestore).thenReturn(fakeFirestore);

      // Configure permission service with authenticated state
      mockPermissionService = MockPermissionService();
      mockPermissionService.setPermissionState(
        isAuthenticated: true,
        currentUserId: _testUserId,
        userDisplayName: 'Test User',
      );

      operations = ShoppingShareOperations(
        firestoreRepository: mockFirestoreRepository,
        permissionService: mockPermissionService,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    /// Seed a shopping list doc in FakeFirebaseFirestore so social share can find it.
    Future<void> seedShoppingList({
      String listId = _testListId,
      String userId = _testUserId,
    }) async {
      await fakeFirestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.unifiedShoppingLists)
          .doc(listId)
          .set({
        'name': 'Test Shopping List',
        'items': ['Milk', 'Bread'],
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    /// Seed a shared content doc for import/view tests.
    Future<void> seedSharedContent({
      String sharedListId = 'shared-list-123',
      String sharedByUserId = 'other-user',
      List<String> sharedWithUserIds = const [_testUserId],
    }) async {
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc(sharedListId)
          .set({
        'contentType': 'shopping_list',
        'title': 'Shared List',
        'listData': {
          'name': 'Shared List',
          'items': ['Eggs']
        },
        'sharedByUserId': sharedByUserId,
        'sharedByDisplayName': 'Other User',
        'sharedAt': DateTime.now().toIso8601String(),
        'sharedWithUserIds': sharedWithUserIds,
        'isActive': true,
        'listType': 'shopping_list_shared',
      });
    }

    /// Seed a received-list record for the current user.
    Future<void> seedReceivedList({
      String sharedListId = 'shared-list-123',
      String userId = _testUserId,
    }) async {
      await fakeFirestore
          .collection(FirestoreCollections.userSharedShoppingLists)
          .doc(userId)
          .collection(FirestoreCollections.receivedLists)
          .doc(sharedListId)
          .set({
        'sharedListId': sharedListId,
        'sharedByUserId': 'other-user',
        'sharedByDisplayName': 'Other User',
        'listTitle': 'Shared List',
        'sharedAt': DateTime.now().toIso8601String(),
        'isViewed': false,
        'isImported': false,
      });
    }

    group('Initialization', () {
      test('should initialize with all modules', () {
        expect(operations, isNotNull);
        expect(operations.export, isNotNull);
        expect(operations.externalShare, isNotNull);
        expect(operations.template, isNotNull);
        expect(operations.import, isNotNull);
        expect(operations.socialShare, isNotNull);
      });
    });

    group('Export Operations', () {
      test('should export list as text', () {
        final result = operations.exportListAsText('list-123');
        expect(result, isA<String>());
        expect(result, contains('Shopping List'));
      });

      test('should export list as minimal text', () {
        final result = operations.exportListAsMinimalText('list-123');
        expect(result, isA<String>());
        expect(result, contains('List list-123'));
      });

      test('should export list as JSON', () {
        final result = operations.exportListAsJson('list-123');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['listId'], equals('list-123'));
        expect(result['items'], isA<List>());
      });

      test('should export list as CSV', () {
        final result = operations.exportListAsCSV('list-123');
        expect(result, isA<String>());
        expect(result, contains('Item'));
        expect(result, contains('Quantity'));
      });
    });

    group('External Sharing Operations', () {
      test('should share list via external apps', () async {
        final result = await operations.shareList(
          listId: 'list-123',
          format: 'text',
          customMessage: 'Check out my shopping list',
        );
        expect(result, isTrue);
      });

      test('should share list in JSON format', () async {
        final result = await operations.shareList(
          listId: 'list-123',
          format: 'json',
        );
        expect(result, isTrue);
      });

      test('should create public link', () async {
        // createPublicLink needs currentUserId and calls DeepLinkService static
        // methods. With auth configured, it generates a URL containing the listId.
        // generateShortUrl falls back to the long URL in test env.
        final result = await operations.createPublicLink('list-123');

        // The URL is generated by DeepLinkService.generateShoppingListShareLink
        // which includes the listId as a query param, then generateShortUrl
        // returns the long URL as fallback. The result should contain 'list-123'.
        expect(result, isA<String>());
        expect(result, contains('list-123'));
      });
    });

    group('Template Operations', () {
      test('should save list as template', () async {
        final result = await operations.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Weekly Shopping',
          description: 'My weekly shopping template',
        );
        expect(result, isTrue);
      });

      test('should create list from template', () async {
        final result = await operations.createFromTemplate(
          templateId: 'template-456',
          customName: 'This Week Shopping',
        );
        expect(result, isA<String?>());
        expect(result, contains('list'));
      });
    });

    group('Import Operations', () {
      test('should import from text', () async {
        const text = '''
        Milk - 2 liters
        Bread - 1 loaf
        Eggs - 12
        ''';

        final result = await operations.importFromText(
          text: text,
          listName: 'Imported List',
        );
        expect(result, isA<String?>());
        expect(result, contains('list'));
      });

      test('should import from JSON', () async {
        final jsonData = {
          'name': 'Shopping List',
          'items': [
            {'name': 'Milk', 'quantity': 2, 'unit': 'liters'},
            {'name': 'Bread', 'quantity': 1, 'unit': 'loaf'},
          ],
        };

        final result = await operations.importFromJson(jsonData);
        expect(result, isA<String?>());
        expect(result, contains('list'));
      });
    });

    group('Social Sharing Operations', () {
      test('should share with friends', () async {
        await seedShoppingList();

        final result = await operations.shareWithFriends(
          listId: _testListId,
          friendIds: ['friend-1', 'friend-2'],
          message: 'Check out my shopping list!',
        );
        expect(result, isTrue);
      });

      test('should share with single friend', () async {
        await seedShoppingList();

        final result =
            await operations.shareListWithFriend(_testListId, 'friend-1');
        expect(result, isTrue);
      });

      test('should share with multiple friends', () async {
        await seedShoppingList();

        final result = await operations.shareListWithMultipleFriends(
          listId: _testListId,
          friendIds: ['friend-1', 'friend-2', 'friend-3'],
          message: 'Shopping together!',
        );
        expect(result, isTrue);
      });

      test('should share with groups', () async {
        await seedShoppingList();

        // Seed group docs with friend member lists
        await fakeFirestore
            .collection(FirestoreCollections.userFriendCategories)
            .doc('family')
            .set({
          'friendUserIds': ['friend-1', 'friend-2'],
        });
        await fakeFirestore
            .collection(FirestoreCollections.userFriendCategories)
            .doc('roommates')
            .set({
          'friendUserIds': ['friend-3'],
        });

        final result = await operations.shareWithGroups(
          listId: _testListId,
          groupIds: ['family', 'roommates'],
          message: 'Weekly shopping',
        );
        expect(result, isTrue);
      });

      test('should share with single group', () async {
        await seedShoppingList();

        await fakeFirestore
            .collection(FirestoreCollections.userFriendCategories)
            .doc('family')
            .set({
          'friendUserIds': ['friend-1'],
        });

        final result =
            await operations.shareListWithGroup(_testListId, 'family');
        expect(result, isTrue);
      });

      test('should share with multiple groups', () async {
        await seedShoppingList();

        await fakeFirestore
            .collection(FirestoreCollections.userFriendCategories)
            .doc('family')
            .set({
          'friendUserIds': ['friend-1'],
        });
        await fakeFirestore
            .collection(FirestoreCollections.userFriendCategories)
            .doc('friends')
            .set({
          'friendUserIds': ['friend-2'],
        });
        await fakeFirestore
            .collection(FirestoreCollections.userFriendCategories)
            .doc('colleagues')
            .set({
          'friendUserIds': ['friend-3'],
        });

        final result = await operations.shareListWithMultipleGroups(
          listId: _testListId,
          groupIds: ['family', 'friends', 'colleagues'],
          message: 'Group shopping',
        );
        expect(result, isTrue);
      });

      test('should send collaboration invite', () async {
        await seedShoppingList();

        final result = await operations.sendCollaborationInvite(
          listId: _testListId,
          recipientId: 'user-456',
          message: 'Join my shopping list!',
        );
        expect(result, isTrue);
      });

      test('should get shopping lists shared with me', () async {
        final result = await operations.getShoppingListsSharedWithMe();
        expect(result, isA<List<Map<String, dynamic>>>());
        // No received lists seeded -> empty
        expect(result.isEmpty, isTrue);
      });

      test('should get shopping lists shared by me', () async {
        final result = await operations.getShoppingListsSharedByMe();
        expect(result, isA<List<Map<String, dynamic>>>());
        // No shared content seeded by current user -> empty
        expect(result.isEmpty, isTrue);
      });

      test('should import shared shopping list', () async {
        await seedSharedContent();
        await seedReceivedList();

        final result =
            await operations.importSharedShoppingList('shared-list-123');
        expect(result, isA<String?>());
        expect(result, equals('shared-list-123'));
      });

      test('should mark shared list as viewed', () async {
        await seedReceivedList();

        // Should not throw
        await operations.markSharedShoppingListAsViewed('shared-list-123');

        // Verify the document was updated
        final doc = await fakeFirestore
            .collection(FirestoreCollections.userSharedShoppingLists)
            .doc(_testUserId)
            .collection(FirestoreCollections.receivedLists)
            .doc('shared-list-123')
            .get();
        expect(doc.data()?['isViewed'], isTrue);
      });

      test('should get shopping list sharing stats', () async {
        // No shared content by current user -> stats show 0
        final result =
            await operations.getShoppingListSharingStats(_testListId);
        expect(result, isA<Map<String, dynamic>>());
        expect(result['sharedWith'], equals(0));
        expect(result['totalShared'], equals(0));
      });
    });

    group('Module Access', () {
      test('should provide access to export module', () {
        final module = operations.export;
        expect(module, isA<ShoppingExportModule>());
        expect(module.exportListAsText('list-123'), isA<String>());
      });

      test('should provide access to external share module', () {
        final module = operations.externalShare;
        expect(module, isA<ShoppingExternalShareModule>());
      });

      test('should provide access to template module', () {
        final module = operations.template;
        expect(module, isA<ShoppingTemplateModule>());
      });

      test('should provide access to import module', () {
        final module = operations.import;
        expect(module, isA<ShoppingImportModule>());
      });

      test('should provide access to social share module', () {
        final module = operations.socialShare;
        expect(module, isA<ShoppingSocialShareModule>());
      });
    });
  });
}
