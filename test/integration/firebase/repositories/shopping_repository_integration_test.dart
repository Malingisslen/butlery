/// Emulator-lane integration tests for FirebaseShoppingRepository.
///
/// Covers what the in-memory fake cannot stand in for: real
/// `FieldValue.serverTimestamp` resolution, the routing between the personal
/// subcollection and the shared collection, and the client-side permission
/// checks on item writes. The emulator runs without security rules, so every
/// denial asserted here comes from the repository, not from `firestore.rules`.
///
/// Mock tier skips the group; the emulator tier runs it through
/// `integration_test/emulator_lane_test.dart` (BUT-1730). Do not call
/// `BaseUnitTest.setupUnit()` here: it installs a fake `FieldValue` platform
/// process-wide and the emulator would receive fake values.
@Tags(['integration', 'firebase'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../../test_support/emulator_lane.dart';

void main() {
  group('FirebaseShoppingRepository (emulator)', () {
    late FirebaseFirestore firestore;
    late MockFirebaseAuth mockAuth;
    late FirebaseAuthRepository authRepository;
    late FirebaseShoppingRepository repository;
    late MockUser mockUser;

    const testUserId = 'test-user-123';
    const testUserEmail = 'test@example.com';
    const testUserDisplayName = 'Test User';

    setUp(() async {
      firestore = await firestoreForLane();
      await clearLane();

      mockUser = MockUser(
        uid: testUserId,
        email: testUserEmail,
        displayName: testUserDisplayName,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      // Set up repositories
      authRepository = FirebaseAuthRepository(firebaseAuth: mockAuth);
      repository = FirebaseShoppingRepository(
        firestore: firestore,
        authRepository: authRepository,
        timestampProvider: const ServerTimestampProvider(),
      );

      // Sign in the test user
      await mockAuth.signInWithEmailAndPassword(
        email: testUserEmail,
        password: 'password',
      );
    });

    tearDown(() async {
      await mockAuth.signOut();
    });

    group('Personal Shopping Lists', () {
      test('should create personal shopping list', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Weekly Groceries',
          ownerId: testUserId,
          ownerDisplayName: testUserDisplayName,
          items: [
            UnifiedShoppingItem.basic(
              name: 'Milk',
              amount: 2,
              unit: 'liter',
              category: 'Dairy',
            ),
            UnifiedShoppingItem.basic(
              name: 'Bread',
              amount: 1,
              unit: 'loaf',
              category: 'Bakery',
            ),
          ],
        );

        // Act
        final created = await repository.create(list);

        // Assert
        expect(created.id, isNotEmpty);
        expect(created.name, equals('Weekly Groceries'));
        expect(created.items, hasLength(2));

        // Verify in Firestore
        final doc = await firestore
            .collection('users')
            .doc(testUserId)
            .collection('unified_shopping_lists')
            .doc(created.id)
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()!['name'], equals('Weekly Groceries'));
        expect(doc.data()!['items'], hasLength(2));
      });

      test('should read personal shopping list', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: testUserId,
          ownerDisplayName: testUserDisplayName,
        );
        final created = await repository.create(list);

        // Act
        final retrieved = await repository.read(created.id);

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals(created.id));
        expect(retrieved.name, equals('Test List'));
        expect(retrieved.ownerId, equals(testUserId));
      });

      test('should update personal shopping list', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Original Name',
          ownerId: testUserId,
          ownerDisplayName: testUserDisplayName,
        );
        final created = await repository.create(list);

        final updated = created.copyWith(
          name: 'Updated Name',
          description: 'Added description',
        );

        // Act
        await repository.update(updated);

        // Assert
        final retrieved = await repository.read(created.id);
        expect(retrieved!.name, equals('Updated Name'));
        expect(retrieved.description, equals('Added description'));
      });

      test('should delete personal shopping list', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'To Delete',
          ownerId: testUserId,
          ownerDisplayName: testUserDisplayName,
        );
        final created = await repository.create(list);

        // Act
        await repository.delete(created.id);

        // Assert
        final retrieved = await repository.read(created.id);
        expect(retrieved, isNull);

        // Verify in Firestore
        final doc = await firestore
            .collection('users')
            .doc(testUserId)
            .collection('unified_shopping_lists')
            .doc(created.id)
            .get();

        expect(doc.exists, isFalse);
      });

      test('should read all personal and shared lists', () async {
        // Arrange
        // Create personal lists
        final personal1 = await repository.create(
          UnifiedShoppingList.personal(
            name: 'Personal 1',
            ownerId: testUserId,
            ownerDisplayName: testUserDisplayName,
          ),
        );

        final personal2 = await repository.create(
          UnifiedShoppingList.personal(
            name: 'Personal 2',
            ownerId: testUserId,
            ownerDisplayName: testUserDisplayName,
          ),
        );

        // Create shared list in the shared collection
        final sharedList = UnifiedShoppingList.collaborative(
          name: 'Shared List',
          ownerId: 'other-user',
          ownerDisplayName: 'Other User',
          memberPermissions: {
            testUserId: SharedListPermission.edit,
            'other-user': SharedListPermission.admin,
          },
        );

        await firestore
            .collection('unified_shared_shopping_lists')
            .doc(sharedList.id)
            .set(sharedList.toFirestore());

        // Act
        final allLists = await repository.readAll();

        // Assert
        expect(allLists, hasLength(3));
        expect(allLists.any((l) => l.id == personal1.id), isTrue);
        expect(allLists.any((l) => l.id == personal2.id), isTrue);
        expect(allLists.any((l) => l.id == sharedList.id), isTrue);

        // Most recent first; ties are allowed because server timestamps of
        // back-to-back writes can resolve to the same instant.
        for (var i = 1; i < allLists.length; i++) {
          expect(
            allLists[i - 1].updatedAt.isBefore(allLists[i].updatedAt),
            isFalse,
            reason: 'readAll must sort by updatedAt descending',
          );
        }
      });
    });

    group('Collaborative Shopping Lists', () {
      test('creating a collaborative list routes it to the shared collection '
          'and seats the owner as admin', () async {
        final list = UnifiedShoppingList.collaborative(
          name: 'Family Shopping',
          ownerId: testUserId,
          ownerDisplayName: testUserDisplayName,
          memberPermissions: {
            'friend-1': SharedListPermission.edit,
            'friend-2': SharedListPermission.view,
          },
          description: 'Shared family shopping list',
          allowGuestEditing: true,
        );

        final created = await repository.create(list);

        expect(created.id, isNotEmpty);
        expect(created.isCollaborative, isTrue);

        final doc = await firestore
            .collection('unified_shared_shopping_lists')
            .doc(created.id)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['type'], equals('collaborative'));
        final permissions = doc.data()!['memberPermissions'] as Map;
        expect(permissions['friend-1'], equals('edit'));
        expect(permissions['friend-2'], equals('view'));
        expect(permissions[testUserId], equals('admin'));

        final personal = await firestore
            .collection('users')
            .doc(testUserId)
            .collection('unified_shopping_lists')
            .doc(created.id)
            .get();
        expect(personal.exists, isFalse);
      });

      test(
        'updating a collaborative list writes to the shared document',
        () async {
          final created = await repository.create(
            UnifiedShoppingList.collaborative(
              name: 'Collaborative List',
              ownerId: testUserId,
              ownerDisplayName: testUserDisplayName,
              memberPermissions: {'friend-1': SharedListPermission.edit},
            ),
          );

          await repository.update(
            created.copyWith(
              name: 'Updated Collaborative',
              description: 'Now with description',
            ),
          );

          final doc = await firestore
              .collection('unified_shared_shopping_lists')
              .doc(created.id)
              .get(const GetOptions(source: Source.server));
          expect(doc.data()!['name'], equals('Updated Collaborative'));
          expect(doc.data()!['description'], equals('Now with description'));
        },
      );

      test('the owner can delete a collaborative list', () async {
        final created = await repository.create(
          UnifiedShoppingList.collaborative(
            name: 'To Delete',
            ownerId: testUserId,
            ownerDisplayName: testUserDisplayName,
            memberPermissions: {},
          ),
        );

        await repository.delete(created.id);

        final doc = await firestore
            .collection('unified_shared_shopping_lists')
            .doc(created.id)
            .get(const GetOptions(source: Source.server));
        expect(doc.exists, isFalse);
      });

      test('a non-owner member cannot delete a collaborative list', () async {
        final list = UnifiedShoppingList.collaborative(
          name: 'Protected List',
          ownerId: 'other-user',
          ownerDisplayName: 'Other User',
          memberPermissions: {testUserId: SharedListPermission.edit},
        );
        await firestore
            .collection('unified_shared_shopping_lists')
            .doc(list.id)
            .set(list.toFirestore());

        await expectLater(
          repository.delete(list.id),
          throwsA(isA<PermissionDeniedException>()),
        );

        final doc = await firestore
            .collection('unified_shared_shopping_lists')
            .doc(list.id)
            .get(const GetOptions(source: Source.server));
        expect(doc.exists, isTrue);
      });
    });

    group('Item Operations', () {
      Future<List<String>> personalItemNames(String listId) async {
        final snapshot = await firestore
            .collection('users')
            .doc(testUserId)
            .collection('unified_shopping_lists')
            .doc(listId)
            .collection('items')
            .get(const GetOptions(source: Source.server));
        return snapshot.docs.map((d) => d.data()['name'] as String).toList()
          ..sort();
      }

      test('adding an item to a personal list stores it in the items '
          'subcollection', () async {
        final list = await repository.create(
          UnifiedShoppingList.personal(
            name: 'Item Test List',
            ownerId: testUserId,
            ownerDisplayName: testUserDisplayName,
          ),
        );

        await repository.addItem(
          list.id,
          UnifiedShoppingItem.basic(
            name: 'New Item',
            amount: 1,
            unit: 'st',
            category: 'Test',
          ),
        );

        expect(await personalItemNames(list.id), ['New Item']);
        final all = await repository.readAll();
        expect(
          all.singleWhere((l) => l.id == list.id).items.map((i) => i.name),
          ['New Item'],
        );
      });

      test(
        'removing an item from a personal list deletes only that row',
        () async {
          final item1 = UnifiedShoppingItem.basic(
            name: 'Item 1',
            amount: 1,
            unit: 'st',
            category: 'Test',
          );
          final item2 = UnifiedShoppingItem.basic(
            name: 'Item 2',
            amount: 2,
            unit: 'st',
            category: 'Test',
          );
          final list = await repository.create(
            UnifiedShoppingList.personal(
              name: 'Remove Item Test',
              ownerId: testUserId,
              ownerDisplayName: testUserDisplayName,
              items: [item1, item2],
            ),
          );
          expect(await personalItemNames(list.id), ['Item 1', 'Item 2']);

          await repository.removeItem(list.id, item1.id);

          expect(await personalItemNames(list.id), ['Item 2']);
        },
      );

      test('a collaborative item keeps its metadata and the adder', () async {
        final list = await repository.create(
          UnifiedShoppingList.collaborative(
            name: 'Collaborative Items',
            ownerId: testUserId,
            ownerDisplayName: testUserDisplayName,
            memberPermissions: {},
          ),
        );

        await repository.addItem(
          list.id,
          UnifiedShoppingItem.collaborative(
            name: 'Collaborative Item',
            amount: 5,
            unit: 'kg',
            category: 'Produce',
            addedByUserId: testUserId,
            addedByDisplayName: testUserDisplayName,
            note: 'Get the organic ones',
            estimatedPrice: 50.0,
            priority: 5,
          ),
        );

        final doc = await firestore
            .collection('unified_shared_shopping_lists')
            .doc(list.id)
            .get(const GetOptions(source: Source.server));
        final items = doc.data()!['items'] as List;
        expect(items, hasLength(1));
        expect(items[0]['name'], equals('Collaborative Item'));
        expect(items[0]['addedByUserId'], equals(testUserId));
        expect(items[0]['note'], equals('Get the organic ones'));
        expect(items[0]['priority'], equals(5));
        expect(doc.data()!['lastActivityByUserId'], equals(testUserId));
      });
    });

    group('Template Operations', () {
      const templatesPath = 'shopping_list_templates';

      Future<UnifiedShoppingList> sourceList({
        String name = 'Template Source',
        List<UnifiedShoppingItem> items = const [],
      }) => repository.create(
        UnifiedShoppingList.personal(
          name: name,
          ownerId: testUserId,
          ownerDisplayName: testUserDisplayName,
          items: items,
        ),
      );

      UnifiedShoppingItem basicItem(String name, double amount, String unit) =>
          UnifiedShoppingItem.basic(
            name: name,
            amount: amount,
            unit: unit,
            category: 'Test',
          );

      test(
        'saving a list as a template stores owner, tags and items',
        () async {
          final list = await sourceList(
            items: [
              basicItem('Template Item 1', 1, 'st'),
              basicItem('Template Item 2', 2, 'kg'),
            ],
          );

          final templateId = await repository.saveAsTemplate(
            listId: list.id,
            templateName: 'My Template',
            description: 'Template description',
            tags: ['weekly', 'groceries'],
            isPublic: false,
          );

          final doc = await firestore
              .collection(templatesPath)
              .doc(templateId)
              .get(const GetOptions(source: Source.server));
          expect(doc.exists, isTrue);
          final data = doc.data()!;
          expect(data['name'], equals('My Template'));
          expect(data['description'], equals('Template description'));
          expect(data['tags'], equals(['weekly', 'groceries']));
          expect(data['isPublic'], isFalse);
          expect(data['ownerId'], equals(testUserId));
          expect(data['originalListId'], equals(list.id));
          expect(data['createdAt'], isA<Timestamp>());
          expect((data['items'] as List).map((i) => i['name']), [
            'Template Item 1',
            'Template Item 2',
          ]);
          expect((data['metadata'] as Map)['itemCount'], equals(2));
        },
      );

      test(
        'a template drops who added or bought a row and its bought state',
        () async {
          final list = await sourceList(
            items: [
              UnifiedShoppingItem.collaborative(
                name: 'Mjölk',
                amount: 1,
                unit: 'l',
                category: 'Dairy',
                addedByUserId: testUserId,
                addedByDisplayName: testUserDisplayName,
                note: 'Laktosfri',
              ).copyWith(
                bought: true,
                lastModifiedByUserId: testUserId,
                lastModifiedByDisplayName: testUserDisplayName,
              ),
            ],
          );

          final templateId = await repository.saveAsTemplate(
            listId: list.id,
            templateName: 'Public Template',
            isPublic: true,
          );

          final doc = await firestore
              .collection(templatesPath)
              .doc(templateId)
              .get(const GetOptions(source: Source.server));
          final row = (doc.data()!['items'] as List).single as Map;
          expect(row['name'], equals('Mjölk'));
          expect(row['note'], equals('Laktosfri'));
          expect(row.keys, isNot(contains('addedByUserId')));
          expect(row.keys, isNot(contains('addedByDisplayName')));
          expect(row.keys, isNot(contains('purchasedByUserId')));
          expect(row.keys, isNot(contains('purchasedByDisplayName')));
          expect(row.keys, isNot(contains('bought')));
        },
      );

      test('updating a template changes only the given fields', () async {
        final list = await sourceList();
        final templateId = await repository.saveAsTemplate(
          listId: list.id,
          templateName: 'Original Template',
          isPublic: false,
        );

        await repository.updateTemplate(
          templateId: templateId,
          name: 'Updated Template',
          description: 'Now with description',
          tags: ['updated'],
          isPublic: true,
        );

        final data =
            (await firestore
                    .collection(templatesPath)
                    .doc(templateId)
                    .get(const GetOptions(source: Source.server)))
                .data()!;
        expect(data['name'], equals('Updated Template'));
        expect(data['description'], equals('Now with description'));
        expect(data['tags'], equals(['updated']));
        expect(data['isPublic'], isTrue);
        expect(data['ownerId'], equals(testUserId));
      });

      test('deleting a template removes it', () async {
        final list = await sourceList();
        final templateId = await repository.saveAsTemplate(
          listId: list.id,
          templateName: 'To Delete',
          isPublic: false,
        );

        await repository.deleteTemplate(templateId);

        final doc = await firestore
            .collection(templatesPath)
            .doc(templateId)
            .get(const GetOptions(source: Source.server));
        expect(doc.exists, isFalse);
      });

      test(
        'getUserTemplates returns only the current user\'s templates',
        () async {
          final list = await sourceList(
            items: [basicItem('Item 1', 1, 'st'), basicItem('Item 2', 2, 'st')],
          );
          await repository.saveAsTemplate(
            listId: list.id,
            templateName: 'Template 1',
            tags: ['tag1'],
            isPublic: false,
          );
          await repository.saveAsTemplate(
            listId: list.id,
            templateName: 'Template 2',
            tags: ['tag2'],
            isPublic: true,
          );
          await firestore.collection(templatesPath).add({
            'name': 'Someone else',
            'ownerId': 'other-user',
            'isPublic': true,
            'createdAt': FieldValue.serverTimestamp(),
            'items': [],
          });

          final templates = await repository.getUserTemplates();

          expect(templates.map((t) => t['name']).toSet(), {
            'Template 1',
            'Template 2',
          });
          expect(
            templates.every((t) => t['ownerId'] == testUserId),
            isTrue,
          );
          expect(
            templates.every((t) => (t['metadata'] as Map)['itemCount'] == 2),
            isTrue,
          );
        },
      );

      test('getPublicTemplates filters by search and tag and hides private '
          'templates', () async {
        final list = await sourceList();
        await repository.saveAsTemplate(
          listId: list.id,
          templateName: 'Weekly Groceries',
          tags: ['weekly', 'groceries'],
          isPublic: true,
        );
        await repository.saveAsTemplate(
          listId: list.id,
          templateName: 'Party Shopping',
          tags: ['party', 'event'],
          isPublic: true,
        );
        await repository.saveAsTemplate(
          listId: list.id,
          templateName: 'Private Weekly Template',
          tags: ['weekly'],
          isPublic: false,
        );
        await firestore.collection(templatesPath).add({
          'name': 'Another Weekly List',
          'description': 'From another user',
          'tags': ['weekly', 'shared'],
          'isPublic': true,
          'ownerId': 'other-user',
          'createdAt': FieldValue.serverTimestamp(),
          'items': [],
        });

        final results = await repository.getPublicTemplates(
          searchQuery: 'weekly',
          tags: ['weekly'],
          limit: 10,
        );

        expect(results.map((t) => t['name']).toSet(), {
          'Weekly Groceries',
          'Another Weekly List',
        });
        expect(results.every((t) => t['isPublic'] == true), isTrue);
      });

      test('creating a list from a template copies its items', () async {
        final source = await sourceList(
          items: [
            basicItem('Template Item 1', 1, 'st'),
            basicItem('Template Item 2', 2, 'kg'),
          ],
        );
        final templateId = await repository.saveAsTemplate(
          listId: source.id,
          templateName: 'Source Template',
          description: 'Template to copy from',
          isPublic: false,
        );

        final newListId = await repository.createListFromTemplate(
          templateId: templateId,
          listName: 'New List from Template',
          description: 'Created from template',
        );

        expect(newListId, isNot(source.id));
        final newList = (await repository.readAll()).singleWhere(
          (l) => l.id == newListId,
        );
        expect(newList.name, equals('New List from Template'));
        expect(newList.description, equals('Created from template'));
        expect(newList.ownerId, equals(testUserId));
        expect(newList.items.map((i) => i.name).toSet(), {
          'Template Item 1',
          'Template Item 2',
        });
      });

      test('a private template cannot be used by another user', () async {
        final ref = await firestore.collection(templatesPath).add({
          'name': 'Private',
          'ownerId': 'other-user',
          'isPublic': false,
          'items': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        await expectLater(
          repository.createListFromTemplate(
            templateId: ref.id,
            listName: 'Stolen',
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('a missing template is reported, not silently ignored', () async {
        await expectLater(
          repository.createListFromTemplate(
            templateId: 'non-existent-template',
            listName: 'New List',
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Permission Validation', () {
      test('a user cannot update another user\'s personal list', () async {
        await firestore
            .collection('users')
            .doc('other-user')
            .collection('unified_shopping_lists')
            .doc('other-list')
            .set({
              'name': 'Other User List',
              'ownerId': 'other-user',
              'ownerDisplayName': 'Other User',
              'items': [],
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'type': 'personal',
            });

        final attempt = UnifiedShoppingList(
          id: 'other-list',
          name: 'Trying to update',
          ownerId: 'other-user',
          ownerDisplayName: 'Other User',
        );

        await expectLater(
          repository.update(attempt),
          throwsA(isA<PermissionDeniedException>()),
        );
        final stored = await firestore
            .collection('users')
            .doc('other-user')
            .collection('unified_shopping_lists')
            .doc('other-list')
            .get(const GetOptions(source: Source.server));
        expect(stored.data()!['name'], equals('Other User List'));
      });

      Future<UnifiedShoppingList> seedSharedList({
        required Map<String, SharedListPermission> members,
        bool allowGuestEditing = false,
      }) async {
        final list = UnifiedShoppingList.collaborative(
          name: 'Seeded shared list',
          ownerId: 'other-user',
          ownerDisplayName: 'Other User',
          memberPermissions: members,
          allowGuestEditing: allowGuestEditing,
        );
        await firestore
            .collection('unified_shared_shopping_lists')
            .doc(list.id)
            .set(list.toFirestore());
        return list;
      }

      Future<List> storedItems(String listId) async {
        final doc = await firestore
            .collection('unified_shared_shopping_lists')
            .doc(listId)
            .get(const GetOptions(source: Source.server));
        return doc.data()!['items'] as List;
      }

      final newItem = UnifiedShoppingItem.basic(
        name: 'New Item',
        amount: 1,
        unit: 'st',
        category: 'Test',
      );

      test('an edit member can add items to a shared list', () async {
        final list = await seedSharedList(
          members: {testUserId: SharedListPermission.edit},
        );

        await repository.addItem(list.id, newItem);

        expect((await storedItems(list.id)).map((i) => i['name']), [
          'New Item',
        ]);
      });

      test('a view-only member cannot add items to a shared list', () async {
        final list = await seedSharedList(
          members: {testUserId: SharedListPermission.view},
        );

        await expectLater(
          repository.addItem(list.id, newItem),
          throwsA(isA<PermissionDeniedException>()),
        );
        expect(await storedItems(list.id), isEmpty);
      });

      test(
        'a non-member cannot add items even when guest editing is on',
        () async {
          final list = await seedSharedList(
            members: {},
            allowGuestEditing: true,
          );

          await expectLater(
            repository.addItem(list.id, newItem),
            throwsA(isA<PermissionDeniedException>()),
          );
          expect(await storedItems(list.id), isEmpty);
        },
      );
    });
  }, skip: emulatorOnlySkip);
}
