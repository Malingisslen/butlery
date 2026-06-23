/// Comprehensive test suite for UnifiedShoppingList model
///
/// Tests all aspects of the UnifiedShoppingList model including:
/// - Construction and factory methods
/// - copyWith functionality
/// - Item operations with user tracking
/// - Sync status management
/// - Serialization/deserialization (JSON and Firestore)
/// - Computed properties and analytics
/// - Swedish formatting and localization
/// - Edge cases and validation
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
// SharedListPermission is defined in unified_shopping_list.dart

import 'helpers/model_test_base.dart';
import 'helpers/serialization_helper.dart';
import 'helpers/validation_helper.dart';
import '../../infrastructure/factories/shopping_list_factory.dart';

void main() {
  ModelTestBase.testModelGroup('UnifiedShoppingList Model', () {
    late UnifiedShoppingList testList;
    late Map<String, dynamic> validJson;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024, 1, 1, 12, 0);

      // Create test list with items using factory
      final items = List.generate(
        5,
        (i) => UnifiedShoppingItem.basic(
          name: 'Item ${i + 1}',
          amount: (i + 1).toDouble(),
          unit: 'st',
          category: 'Test',
        ),
      );

      testList = ShoppingListFactory.build(
        id: 'list_123',
        name: 'Veckans inköp',
        ownerId: 'user_123',
        ownerDisplayName: 'Anna Andersson',
        items: items,
        updatedAt:
            testDate, // Set older date to ensure timestamp comparison works
      );

      validJson = SerializationHelper.createValidShoppingListJson();
    });

    group('Construction', () {
      test('should create personal shopping list', () {
        // Act
        final list = UnifiedShoppingList.personal(
          name: 'Min inköpslista',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
        );

        // Assert
        expect(list.id, isNotEmpty);
        expect(list.name, equals('Min inköpslista'));
        expect(list.ownerId, equals('user_123'));
        expect(list.ownerDisplayName, equals('Test User'));
        expect(list.type, equals(ListType.personal));
        expect(list.isPersonal, isTrue);
        expect(list.isCollaborative, isFalse);
        expect(list.items, isEmpty);
        expect(list.createdAt, isA<DateTime>());
        expect(list.updatedAt, isA<DateTime>());
      });

      test('should create collaborative shopping list', () {
        // Act
        final list = UnifiedShoppingList.collaborative(
          name: 'Familjens lista',
          ownerId: 'owner_123',
          ownerDisplayName: 'Owner Name',
          memberPermissions: {
            'member1': SharedListPermission.edit,
            'member2': SharedListPermission.view,
          },
        );

        // Assert
        expect(list.type, equals(ListType.collaborative));
        expect(list.isCollaborative, isTrue);
        expect(list.memberPermissions, isNotNull);
        expect(
          list.memberPermissions['owner_123'],
          equals(SharedListPermission.admin),
        );
        expect(
          list.memberPermissions['member1'],
          equals(SharedListPermission.edit),
        );
        expect(
          list.memberPermissions['member2'],
          equals(SharedListPermission.view),
        );
      });

      test('should generate unique ID if not provided', () {
        // Act
        final list1 = UnifiedShoppingList.personal(
          name: 'List 1',
          ownerId: 'user_123',
          ownerDisplayName: 'User Name',
        );
        final list2 = UnifiedShoppingList.personal(
          name: 'List 2',
          ownerId: 'user_123',
          ownerDisplayName: 'User Name',
        );

        // Assert
        expect(list1.id, isNotEmpty);
        expect(list2.id, isNotEmpty);
        expect(list1.id, isNot(equals(list2.id)));
      });

      test('should use provided optional fields', () {
        // Act
        final list = UnifiedShoppingList(
          id: 'custom_id',
          name: 'Test List',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          description: 'Test description',
          items: [],
          type: ListType.template,
          categoryIds: ['cat1', 'cat2'],
          autoRemoveCompleted: true,
          allowGuestEditing: false,
          createdAt: testDate,
          updatedAt: testDate,
        );

        // Assert
        expect(list.id, equals('custom_id'));
        expect(list.description, equals('Test description'));
        expect(list.type, equals(ListType.template));
        expect(list.categoryIds, equals(['cat1', 'cat2']));
        expect(list.autoRemoveCompleted, isTrue);
        expect(list.allowGuestEditing, isFalse);
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        // Act
        final updated = testList.copyWith(
          name: 'Uppdaterad lista',
          description: 'Ny beskrivning',
          syncStatus: SyncStatus.pending,
        );

        // Assert
        expect(updated.id, equals(testList.id)); // Unchanged
        expect(updated.name, equals('Uppdaterad lista'));
        expect(updated.description, equals('Ny beskrivning'));
        expect(updated.syncStatus, equals(SyncStatus.pending));
        expect(updated.ownerId, equals(testList.ownerId)); // Unchanged
      });

      test('should preserve all fields when not specified', () {
        // Act
        final copy = testList.copyWith();

        // Assert
        expect(copy.id, equals(testList.id));
        expect(copy.name, equals(testList.name));
        expect(copy.ownerId, equals(testList.ownerId));
        expect(copy.items.length, equals(testList.items.length));
        expect(copy.type, equals(testList.type));
        expect(copy.createdAt, equals(testList.createdAt));
      });
    });

    group('Item Operations', () {
      test('should add item with user tracking', () {
        // Arrange
        final item = UnifiedShoppingItem.basic(
          name: 'Mjölk',
          amount: 1,
          unit: 'liter',
        );

        // Act
        final updated = testList.addItem(
          item,
          userId: 'user_456',
          userDisplayName: 'Test User',
        );

        // Assert
        expect(updated.items.length, equals(testList.items.length + 1));
        expect(updated.items.last.name, equals('Mjölk'));
        expect(updated.lastActivityByUserId, equals('user_456'));
        expect(updated.lastActivityByDisplayName, equals('Test User'));
        expect(updated.lastActivityAt, isNotNull);
        expect(updated.updatedAt.isAfter(testList.updatedAt), isTrue);
      });

      test('should remove item by ID', () {
        // Arrange
        final itemId = testList.items.first.id;
        final initialCount = testList.items.length;

        // Act
        final updated = testList.removeItem(
          itemId,
          userId: 'user_123',
          userDisplayName: 'Anna',
        );

        // Assert
        expect(updated.items.length, equals(initialCount - 1));
        expect(updated.items.any((item) => item.id == itemId), isFalse);
        expect(updated.lastActivityByUserId, equals('user_123'));
      });

      test('should update existing item', () {
        // Arrange
        final itemToUpdate = testList.items.first;
        final updatedItem = itemToUpdate.copyWith(
          name: 'Updated Name',
          amount: 2,
        );

        // Act
        final updated = testList.updateItem(
          itemToUpdate.id,
          updatedItem,
          userId: 'user_123',
          userDisplayName: 'Anna',
        );

        // Assert
        final foundItem = updated.items.firstWhere(
          (item) => item.id == itemToUpdate.id,
        );
        expect(foundItem.name, equals('Updated Name'));
        expect(foundItem.amount, equals(2));
      });

      test('should toggle item bought status', () {
        // Arrange
        final item = testList.items.first;
        final initialBought = item.bought;

        // Act
        final updated = testList.toggleItemBought(
          item.id,
          userId: 'user_123',
          userDisplayName: 'Anna',
        );

        // Assert
        final toggledItem = updated.items.firstWhere(
          (i) => i.id == item.id,
        );
        expect(toggledItem.bought, equals(!initialBought));
        if (!initialBought) {
          expect(toggledItem.purchasedByUserId, equals('user_123'));
          expect(toggledItem.purchasedByDisplayName, equals('Anna'));
        }
      });

      test('should clear all bought items', () {
        // Arrange
        // Mark some items as bought first
        var listWithBought = testList;
        for (final item in testList.items.take(3)) {
          listWithBought = listWithBought.toggleItemBought(
            item.id,
            userId: 'user_123',
            userDisplayName: 'Anna',
          );
        }

        // Act
        final cleared = listWithBought.clearBoughtItems(
          userId: 'user_123',
          userDisplayName: 'Anna',
        );

        // Assert
        expect(cleared.items.any((item) => item.bought), isFalse);
        expect(cleared.lastActivityByUserId, equals('user_123'));
      });

      test('should uncheck all items', () {
        // Arrange
        // Mark all items as bought first
        var allBought = testList;
        for (final item in testList.items) {
          allBought = allBought.toggleItemBought(
            item.id,
            userId: 'user_123',
            userDisplayName: 'Anna',
          );
        }

        // Act
        final unchecked = allBought.uncheckAllItems(
          userId: 'user_456',
          userDisplayName: 'Test User',
        );

        // Assert
        expect(unchecked.items.every((item) => !item.bought), isTrue);
        expect(unchecked.lastActivityByUserId, equals('user_456'));
      });
    });

    group('Sync Status Management', () {
      test('should mark as synced with timestamp', () {
        // Arrange
        final pending = testList.copyWith(syncStatus: SyncStatus.pending);

        // Act
        final synced = pending.markAsSynced();

        // Assert
        expect(synced.syncStatus, equals(SyncStatus.synced));
        expect(synced.lastSyncedAt, isNotNull);
        expect(synced.lastSyncedAt!.isAfter(testDate), isTrue);
      });

      test('should mark as pending', () {
        // Act
        final pending = testList.markAsPending();

        // Assert
        expect(pending.syncStatus, equals(SyncStatus.pending));
        expect(pending.needsSync, isTrue);
      });

      test('should mark as error with message', () {
        // Act
        final error = testList.markAsError();

        // Assert
        expect(error.syncStatus, equals(SyncStatus.error));
        expect(error.hasError, isTrue);
      });

      test('should determine needsSync correctly', () {
        // Never synced
        final neverSynced = testList.copyWith(
          lastSyncedAt: null,
          syncStatus: SyncStatus.local,
        );
        expect(
          neverSynced.needsSync,
          isFalse,
        ); // needsSync only true when pending

        // Pending changes
        final pending = testList.copyWith(
          syncStatus: SyncStatus.pending,
        );
        expect(pending.needsSync, isTrue);

        // Synced
        final synced = testList.copyWith(
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
        );
        expect(synced.needsSync, isFalse);
      });
    });

    group('Analytics and Computed Properties', () {
      test('should calculate item counts correctly', () {
        // Arrange
        var list = testList;
        // Mark some items as bought
        list = list.toggleItemBought(
          list.items[0].id,
          userId: 'user',
          userDisplayName: 'User',
        );
        list = list.toggleItemBought(
          list.items[1].id,
          userId: 'user',
          userDisplayName: 'User',
        );

        // Assert
        expect(list.totalItems, equals(5));
        expect(list.boughtItems, equals(2));
        expect(list.unboughtItems, equals(3));
        expect(list.allItemsBought, isFalse);
      });

      test('should calculate completion percentage', () {
        // Empty list
        final emptyList = testList.copyWith(items: []);
        expect(emptyList.completionPercentage, equals(0));

        // No items bought
        expect(testList.completionPercentage, equals(0));

        // Half bought
        var halfBought = testList;
        halfBought = halfBought.toggleItemBought(
          halfBought.items[0].id,
          userId: 'user',
          userDisplayName: 'User',
        );
        halfBought = halfBought.toggleItemBought(
          halfBought.items[1].id,
          userId: 'user',
          userDisplayName: 'User',
        );
        expect(halfBought.completionPercentage, equals(40)); // 2/5 = 40%

        // All bought
        var allBought = testList;
        for (final item in testList.items) {
          allBought = allBought.toggleItemBought(
            item.id,
            userId: 'user',
            userDisplayName: 'User',
          );
        }
        expect(allBought.completionPercentage, equals(100));
        expect(allBought.allItemsBought, isTrue);
      });

      test('should generate Swedish summary', () {
        // Empty list
        final emptyList = testList.copyWith(items: []);
        expect(emptyList.summary, equals('Tom handlingslista'));

        // One item
        final oneItem = testList.copyWith(
          items: [testList.items.first],
        );
        expect(oneItem.summary, equals('1 av 1 artiklar kvar'));

        // Multiple items
        expect(testList.summary, equals('5 av 5 artiklar kvar'));

        // With bought items
        var withBought = testList;
        withBought = withBought.toggleItemBought(
          withBought.items[0].id,
          userId: 'user',
          userDisplayName: 'User',
        );
        expect(withBought.summary, equals('4 av 5 artiklar kvar'));

        // Multiple bought
        withBought = withBought.toggleItemBought(
          withBought.items[1].id,
          userId: 'user',
          userDisplayName: 'User',
        );
        expect(withBought.summary, equals('3 av 5 artiklar kvar'));
      });

      test('should show sync status emoji', () {
        // Synced
        final synced = testList.copyWith(syncStatus: SyncStatus.synced);
        expect(synced.syncStatusEmoji, equals('✅'));

        // Pending
        final pending = testList.copyWith(syncStatus: SyncStatus.pending);
        expect(pending.syncStatusEmoji, equals('🔄'));

        // Error
        final error = testList.copyWith(syncStatus: SyncStatus.error);
        expect(error.syncStatusEmoji, equals('❌'));

        // Conflict
        final conflict = testList.copyWith(syncStatus: SyncStatus.conflict);
        expect(conflict.syncStatusEmoji, equals('⚠️'));

        // Local
        final local = testList.copyWith(syncStatus: SyncStatus.local);
        expect(local.syncStatusEmoji, equals('📱'));
      });

      test('should format activity summary in Swedish', () {
        // Just now
        final justNow = testList.copyWith(
          lastActivityAt: DateTime.now(),
          lastActivityByDisplayName: 'Anna',
        );
        expect(justNow.activitySummary, contains('Anna'));
        expect(justNow.activitySummary, contains('nu'));

        // Minutes ago
        final minutesAgo = testList.copyWith(
          lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
          lastActivityByDisplayName: 'Erik',
        );
        expect(minutesAgo.activitySummary, contains('Erik'));
        expect(minutesAgo.activitySummary, contains('min sedan'));

        // Hours ago
        final hoursAgo = testList.copyWith(
          lastActivityAt: DateTime.now().subtract(const Duration(hours: 2)),
          lastActivityByDisplayName: 'Maria',
        );
        expect(hoursAgo.activitySummary, contains('Maria'));
        expect(hoursAgo.activitySummary, contains('tim sedan'));

        // Days ago
        final daysAgo = testList.copyWith(
          lastActivityAt: DateTime.now().subtract(const Duration(days: 3)),
          lastActivityByDisplayName: 'Johan',
        );
        expect(daysAgo.activitySummary, contains('Johan'));
        expect(daysAgo.activitySummary, contains('dagar sedan'));
      });

      test('should detect recent activity', () {
        // Recent (within 24 hours)
        final recent = testList.copyWith(
          lastActivityAt: DateTime.now().subtract(const Duration(hours: 3)),
        );
        expect(recent.hasRecentActivity, isTrue);

        // Not recent (more than 24 hours)
        final old = testList.copyWith(
          lastActivityAt: DateTime.now().subtract(const Duration(hours: 25)),
        );
        expect(old.hasRecentActivity, isFalse);

        // No activity
        final noActivity = testList.copyWith(lastActivityAt: null);
        expect(noActivity.hasRecentActivity, isFalse);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        // Act
        final json = testList.toJson();

        // Assert
        expect(json, isA<Map<String, dynamic>>());
        expect(json['id'], equals(testList.id));
        expect(json['name'], equals(testList.name));
        expect(json['ownerId'], equals(testList.ownerId));
        expect(json['ownerDisplayName'], equals(testList.ownerDisplayName));
        expect(json['items'], isA<List>());
        expect(json['items'].length, equals(testList.items.length));
        expect(json['type'], equals(testList.type.toString().split('.').last));
        expect(json['createdAt'], isA<String>());
        expect(json['updatedAt'], isA<String>());
      });

      test('should deserialize from JSON correctly', () {
        // Act
        final list = UnifiedShoppingList.fromJson(validJson);

        // Assert
        expect(list.id, equals(validJson['id']));
        expect(list.name, equals(validJson['name']));
        expect(list.ownerId, equals(validJson['ownerId']));
        expect(list.items.length, equals(validJson['items'].length));
        expect(
          list.type.toString().split('.').last,
          equals(validJson['type'] ?? 'personal'),
        );
      });

      test('should round-trip JSON serialization', () {
        // Act
        final json = testList.toJson();
        final deserialized = UnifiedShoppingList.fromJson(json);
        final json2 = deserialized.toJson();

        // Assert
        expect(deserialized.id, equals(testList.id));
        expect(deserialized.name, equals(testList.name));
        expect(deserialized.items.length, equals(testList.items.length));
        expect(json2['id'], equals(json['id']));
      });
    });

    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        // Act
        final firestore = testList.toFirestore();

        // Assert
        expect(firestore['name'], equals(testList.name));
        expect(firestore['ownerId'], equals(testList.ownerId));
        expect(firestore['items'], isA<List>());
        expect(firestore['createdAt'], isA<Timestamp>());
        expect(firestore['updatedAt'], isA<Timestamp>());
        if (testList.lastActivityAt != null) {
          expect(firestore['lastActivityAt'], isA<Timestamp>());
        }
      });

      test('should deserialize from Firestore map', () {
        // Arrange
        final firestoreData = {
          'name': 'Firestore List',
          'ownerId': 'owner_123',
          'ownerDisplayName': 'Owner Name',
          'items': [],
          'type': 'collaborative',
          'createdAt': Timestamp.fromDate(testDate),
          'updatedAt': Timestamp.fromDate(testDate),
        };

        // Act
        final list = UnifiedShoppingList.fromMap('firestore_id', firestoreData);

        // Assert
        expect(list.id, equals('firestore_id'));
        expect(list.name, equals('Firestore List'));
        expect(list.ownerId, equals('owner_123'));
        expect(list.type, equals(ListType.collaborative));
        expect(list.createdAt, equals(testDate));
      });

      test('should handle DateTime vs Timestamp in fromMap', () {
        // With DateTime objects
        final withDateTime = {
          'name': 'Test',
          'ownerId': 'owner_123',
          'items': [],
          'ownerDisplayName': 'Test Owner',
          'createdAt': testDate,
          'updatedAt': testDate,
        };

        final list1 = UnifiedShoppingList.fromMap('id1', withDateTime);
        expect(list1.createdAt, equals(testDate));

        // With Firestore Timestamps
        final withTimestamp = {
          'name': 'Test',
          'ownerId': 'owner_123',
          'ownerDisplayName': 'Test Owner',
          'items': [],
          'createdAt': Timestamp.fromDate(testDate),
          'updatedAt': Timestamp.fromDate(testDate),
        };

        final list2 = UnifiedShoppingList.fromMap('id2', withTimestamp);
        expect(list2.createdAt, equals(testDate));
      });
    });

    group('generatedForWeek marker (BUT-1234)', () {
      // The MenuShoppingListGenerator finds "this week's list" via this
      // marker — if serialization drops it in either format, regeneration
      // would silently start duplicating lists after an app restart.

      test('round-trips through toJson/fromJson', () {
        final marked = testList.copyWith(generatedForWeek: '2026-W24');

        final restored = UnifiedShoppingList.fromJson(marked.toJson());

        expect(restored.generatedForWeek, equals('2026-W24'));
      });

      test('round-trips through toFirestore/fromMap', () {
        final marked = testList.copyWith(generatedForWeek: '2026-W24');

        final restored = UnifiedShoppingList.fromMap(
          marked.id,
          marked.toFirestore(),
        );

        expect(restored.generatedForWeek, equals('2026-W24'));
      });

      test('legacy docs without the field deserialize to null', () {
        // Pre-BUT-1234 Firestore docs and cached JSON have no
        // generatedForWeek key — they must load as unmarked lists, never
        // throw or coerce to ''.
        final legacyMap = {
          'name': 'Inköpslista v.24',
          'ownerId': 'owner_123',
          'ownerDisplayName': 'Owner Name',
          'items': <dynamic>[],
          'createdAt': Timestamp.fromDate(testDate),
          'updatedAt': Timestamp.fromDate(testDate),
        };

        final fromFirestore = UnifiedShoppingList.fromMap('id', legacyMap);
        expect(fromFirestore.generatedForWeek, isNull);

        final legacyJson = testList.toJson()..remove('generatedForWeek');
        final fromCache = UnifiedShoppingList.fromJson(legacyJson);
        expect(fromCache.generatedForWeek, isNull);
      });

      test('copyWith sets the marker and preserves it when omitted', () {
        final marked = testList.copyWith(generatedForWeek: '2026-W24');
        expect(marked.generatedForWeek, equals('2026-W24'));

        // An unrelated copyWith (e.g. the rename flow) must not lose it.
        final renamed = marked.copyWith(name: 'veckans mat');
        expect(renamed.generatedForWeek, equals('2026-W24'));
        expect(
          testList.generatedForWeek,
          isNull,
          reason: 'baseline list starts unmarked',
        );
      });
    });

    group('Edge Cases and Validation', () {
      test('should validate shopping list constraints', () {
        // Valid list
        expect(
          ValidationHelper.isValidShoppingList(
            id: testList.id,
            name: testList.name,
            ownerId: testList.ownerId,
            items: testList.items,
          ),
          isTrue,
        );

        // Invalid - empty ID
        expect(
          ValidationHelper.isValidShoppingList(
            id: '',
            name: 'Test',
            ownerId: 'owner',
            items: [],
          ),
          isFalse,
        );

        // Invalid - empty name
        expect(
          ValidationHelper.isValidShoppingList(
            id: 'id',
            name: '',
            ownerId: 'owner',
            items: [],
          ),
          isFalse,
        );

        // Invalid - null items
        expect(
          ValidationHelper.isValidShoppingList(
            id: 'id',
            name: 'Test',
            ownerId: 'owner',
            items: null,
          ),
          isFalse,
        );
      });

      test('should handle empty items list', () {
        // Arrange
        final emptyList = testList.copyWith(items: []);

        // Assert
        expect(emptyList.isEmpty, isTrue);
        expect(emptyList.totalItems, equals(0));
        expect(emptyList.completionPercentage, equals(0));
        expect(emptyList.summary, equals('Tom handlingslista'));
      });

      test('should handle Swedish characters in names', () {
        // Arrange
        final swedishList = testList.copyWith(
          name: 'Köttbullar och köttfärs',
          description: 'Ingredienser för köttbullar med gräddsås',
        );

        // Act
        final json = swedishList.toJson();
        final deserialized = UnifiedShoppingList.fromJson(json);

        // Assert
        expect(deserialized.name, equals('Köttbullar och köttfärs'));
        expect(deserialized.description, contains('gräddsås'));
      });

      test('should handle large number of items', () {
        // Arrange
        final manyItems = List.generate(
          100,
          (i) => UnifiedShoppingItem.basic(
            name: 'Item $i',
            amount: i.toDouble(),
          ),
        );

        final largeList = testList.copyWith(items: manyItems);

        // Assert
        expect(largeList.items.length, equals(100));
        expect(largeList.totalItems, equals(100));

        // Should serialize/deserialize
        final json = largeList.toJson();
        final deserialized = UnifiedShoppingList.fromJson(json);
        expect(deserialized.items.length, equals(100));
      });

      test('should handle missing optional fields in fromJson', () {
        // Arrange - minimal JSON with required fields
        final minimalJson = {
          'id': 'minimal_list',
          'name': 'Minimal',
          'ownerId': 'owner_123',
          'ownerDisplayName': 'Owner Name',
          'createdAt': '2024-01-01T00:00:00Z',
          'updatedAt': '2024-01-01T00:00:00Z',
        };

        // Act
        final list = UnifiedShoppingList.fromJson(minimalJson);

        // Assert
        expect(list.id, equals('minimal_list'));
        expect(list.name, equals('Minimal'));
        expect(list.ownerId, equals('owner_123'));
        expect(list.items, isEmpty);
        expect(list.type, equals(ListType.personal)); // Default
        expect(list.syncStatus, equals(SyncStatus.local)); // Default
      });

      test('should handle collaborative permissions correctly', () {
        // Arrange
        final collaborative = UnifiedShoppingList.collaborative(
          name: 'Team List',
          ownerId: 'owner_123',
          ownerDisplayName: 'Owner',
          memberPermissions: {
            'editor_1': SharedListPermission.edit,
            'viewer_1': SharedListPermission.view,
          },
        );

        // Assert
        // Owner gets admin permission automatically
        expect(
          collaborative.memberPermissions['owner_123'],
          equals(SharedListPermission.admin),
        );
        // Check member permissions
        expect(collaborative.memberPermissions.length, equals(3));

        // Serialize and deserialize
        final json = collaborative.toJson();
        final deserialized = UnifiedShoppingList.fromJson(json);
        // Check deserialized member permissions
        expect(
          deserialized.memberPermissions['owner_123'],
          equals(SharedListPermission.admin),
        );
      });
    });
  });
}
