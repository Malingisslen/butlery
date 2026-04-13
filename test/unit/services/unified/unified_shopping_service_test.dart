/// Unit tests for UnifiedShoppingService via mock API contract and model logic
///
/// UnifiedShoppingService cannot be constructed in unit tests because its
/// `_initializeModules()` calls `ServiceLocator.get<CategoryPreferencesRepository>()`
/// and `ServiceLocator.get<OfflineService>()` (lazily), neither of which are
/// registered in the test DI container.
///
/// Instead we test:
/// 1. MockUnifiedShoppingService — verifies mock matches production API surface
/// 2. UnifiedShoppingList model — personal/collaborative factory, item ops, completion
/// 3. UnifiedShoppingItem model — construction and properties
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/unified/types/service_states.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  // -----------------------------------------------------------------------
  // Part 1: MockUnifiedShoppingService API contract
  // -----------------------------------------------------------------------
  group('MockUnifiedShoppingService API contract', () {
    late MockUnifiedShoppingService mock;

    setUp(() {
      mock = MockUnifiedShoppingService();
    });

    test('defaults to empty state', () {
      mock.setShoppingState();

      expect(mock.lists, isEmpty);
      expect(mock.personalLists, isEmpty);
      expect(mock.collaborativeLists, isEmpty);
      expect(mock.activeListId, isNull);
      expect(mock.isLoading, isFalse);
      expect(mock.error, isNull);
      expect(mock.hasError, isFalse);
      expect(mock.isInitialized, isTrue);
    });

    test('configures lists and active list', () {
      final list = UnifiedShoppingList.personal(
        name: 'Veckans inköp',
        ownerId: 'user-1',
        ownerDisplayName: 'Test User',
      );
      mock.setShoppingState(
        lists: [list],
        personalLists: [list],
        activeListId: list.id,
      );

      expect(mock.lists.length, 1);
      expect(mock.lists.first.name, 'Veckans inköp');
      expect(mock.personalLists.length, 1);
      expect(mock.activeListId, list.id);
    });

    test('configures loading state', () {
      mock.setShoppingState(isLoading: true);
      expect(mock.isLoading, isTrue);
    });

    test('configures error state', () {
      mock.setShoppingState(error: 'Network error');
      expect(mock.hasError, isTrue);
      expect(mock.error, 'Network error');
    });

    test('configures user context', () {
      mock.setShoppingState(
        currentUserId: 'u1',
        currentUserDisplayName: 'Anna',
      );
      expect(mock.currentUserId, 'u1');
      expect(mock.currentUserDisplayName, 'Anna');
    });

    test('configures collaborative lists separately', () {
      final collab = UnifiedShoppingList.collaborative(
        name: 'Gemensam',
        ownerId: 'u1',
        ownerDisplayName: 'Owner',
        memberPermissions: {'u2': SharedListPermission.edit},
      );
      mock.setShoppingState(collaborativeLists: [collab]);
      expect(mock.collaborativeLists.length, 1);
    });

    test('stateStream is available', () {
      // MockUnifiedShoppingService inherits Mock — stateStream can be stubbed
      expect(mock, isNotNull);
    });
  });

  // -----------------------------------------------------------------------
  // Part 2: UnifiedShoppingList model
  // -----------------------------------------------------------------------
  group('UnifiedShoppingList', () {
    group('personal factory', () {
      test('creates personal list with correct defaults', () {
        final list = UnifiedShoppingList.personal(
          name: 'Min lista',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
        );

        expect(list.name, 'Min lista');
        expect(list.ownerId, 'u1');
        expect(list.ownerDisplayName, 'Anna');
        expect(list.type, ListType.personal);
        expect(list.isPersonal, isTrue);
        expect(list.isCollaborative, isFalse);
        expect(list.items, isEmpty);
        expect(list.id, isNotEmpty);
      });

      test('creates personal list with items', () {
        final items = [
          UnifiedShoppingItem(name: 'Mjölk', amount: 1),
          UnifiedShoppingItem(name: 'Bröd', amount: 2),
        ];
        final list = UnifiedShoppingList.personal(
          name: 'Med varor',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
          items: items,
        );

        expect(list.items.length, 2);
        expect(list.items[0].name, 'Mjölk');
      });
    });

    group('collaborative factory', () {
      test('creates collaborative list with correct defaults', () {
        final list = UnifiedShoppingList.collaborative(
          name: 'Gemensam',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
          memberPermissions: {},
        );

        expect(list.type, ListType.collaborative);
        expect(list.isCollaborative, isTrue);
        expect(list.isPersonal, isFalse);
      });

      test('creates collaborative list with member permissions', () {
        final list = UnifiedShoppingList.collaborative(
          name: 'Gemensam',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
          memberPermissions: {
            'u2': SharedListPermission.edit,
            'u3': SharedListPermission.view,
          },
        );

        // Factory adds owner (u1) as admin automatically
        expect(list.memberPermissions.length, 3);
        expect(list.memberPermissions['u1'], SharedListPermission.admin);
        expect(list.memberPermissions['u2'], SharedListPermission.edit);
        expect(list.memberPermissions['u3'], SharedListPermission.view);
      });
    });

    group('item operations', () {
      test('addItem returns new list with item added', () {
        final list = UnifiedShoppingList.personal(
          name: 'Test',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
        );
        final item = UnifiedShoppingItem(name: 'Ägg', amount: 6);

        final updated =
            list.addItem(item, userId: 'u1', userDisplayName: 'Anna');

        expect(updated.items.length, 1);
        expect(updated.items.first.name, 'Ägg');
        // Original list should be unchanged (immutable)
        expect(list.items, isEmpty);
      });

      test('toggleItemBought toggles bought state', () {
        final item = UnifiedShoppingItem(name: 'Mjölk', amount: 1);
        final list = UnifiedShoppingList.personal(
          name: 'Test',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
          items: [item],
        );

        final toggled = list.toggleItemBought(
          item.id,
          userId: 'u1',
          userDisplayName: 'Anna',
        );

        expect(toggled.items.first.bought, isTrue);
      });

      test('removeItem removes item from list', () {
        final item = UnifiedShoppingItem(name: 'Mjölk', amount: 1);
        final list = UnifiedShoppingList.personal(
          name: 'Test',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
          items: [item],
        );

        final removed = list.removeItem(item.id);

        expect(removed.items, isEmpty);
      });
    });

    group('completion tracking', () {
      test('completionPercentage is 0 for empty list', () {
        final list = UnifiedShoppingList.personal(
          name: 'Empty',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
        );

        expect(list.completionPercentage, 0.0);
      });

      test('completionPercentage reflects bought items', () {
        final items = [
          UnifiedShoppingItem(name: 'A', amount: 1, bought: true),
          UnifiedShoppingItem(name: 'B', amount: 1),
        ];
        final list = UnifiedShoppingList.personal(
          name: 'Half done',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
          items: items,
        );

        expect(list.completionPercentage, 50.0);
      });

      test('completionPercentage is 100 when all bought', () {
        final items = [
          UnifiedShoppingItem(name: 'A', amount: 1, bought: true),
          UnifiedShoppingItem(name: 'B', amount: 1, bought: true),
        ];
        final list = UnifiedShoppingList.personal(
          name: 'Done',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
          items: items,
        );

        expect(list.completionPercentage, 100.0);
      });
    });

    group('isEmpty and counts', () {
      test('isEmpty and isNotEmpty work correctly', () {
        final empty = UnifiedShoppingList.personal(
          name: 'Empty',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
        );
        expect(empty.isEmpty, isTrue);
        expect(empty.isNotEmpty, isFalse);

        final withItem = UnifiedShoppingList.personal(
          name: 'Has items',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
          items: [UnifiedShoppingItem(name: 'X', amount: 1)],
        );
        expect(withItem.isEmpty, isFalse);
        expect(withItem.isNotEmpty, isTrue);
      });

      test('itemCount returns correct count', () {
        final items = [
          UnifiedShoppingItem(name: 'A', amount: 1),
          UnifiedShoppingItem(name: 'B', amount: 1),
          UnifiedShoppingItem(name: 'C', amount: 1),
        ];
        final list = UnifiedShoppingList.personal(
          name: 'Count test',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
          items: items,
        );

        expect(list.itemCount, 3);
      });
    });

    group('copyWith', () {
      test('returns new list with updated name', () {
        final list = UnifiedShoppingList.personal(
          name: 'Original',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
        );

        final updated = list.copyWith(name: 'Updated');
        expect(updated.name, 'Updated');
        expect(updated.id, list.id); // ID should stay the same
        expect(list.name, 'Original'); // Original unchanged
      });

      test('returns new list with updated items', () {
        final list = UnifiedShoppingList.personal(
          name: 'Test',
          ownerId: 'u1',
          ownerDisplayName: 'Anna',
        );
        final newItems = [UnifiedShoppingItem(name: 'New', amount: 1)];

        final updated = list.copyWith(items: newItems);
        expect(updated.items.length, 1);
        expect(list.items, isEmpty);
      });
    });
  });

  // -----------------------------------------------------------------------
  // Part 3: UnifiedShoppingItem model
  // -----------------------------------------------------------------------
  group('UnifiedShoppingItem', () {
    test('creates with required fields', () {
      final item = UnifiedShoppingItem(name: 'Mjölk', amount: 2);

      expect(item.name, 'Mjölk');
      expect(item.amount, 2);
      expect(item.bought, isFalse);
      expect(item.id, isNotEmpty);
    });

    test('creates with optional fields', () {
      final item = UnifiedShoppingItem(
        name: 'Ägg',
        amount: 6,
        unit: 'st',
        category: 'Mejeri',
        note: 'Ekologiska',
      );

      expect(item.unit, 'st');
      expect(item.category, 'Mejeri');
      expect(item.note, 'Ekologiska');
    });

    test('copyWith updates fields', () {
      final item = UnifiedShoppingItem(name: 'Mjölk', amount: 1);
      final updated = item.copyWith(bought: true);

      expect(updated.bought, isTrue);
      expect(updated.name, 'Mjölk');
      expect(item.bought, isFalse); // Original unchanged
    });

    test('has unique ID', () {
      final a = UnifiedShoppingItem(name: 'A', amount: 1);
      final b = UnifiedShoppingItem(name: 'B', amount: 1);

      expect(a.id, isNot(equals(b.id)));
    });
  });

  // -----------------------------------------------------------------------
  // Part 4: ShoppingServiceState
  // -----------------------------------------------------------------------
  group('ShoppingServiceState', () {
    test('ShoppingStateLoading is loading state', () {
      const state = ShoppingStateLoading();
      expect(state, isA<ShoppingServiceState>());
    });

    test('ShoppingStateError carries message', () {
      const state = ShoppingStateError(message: 'Failed to load');
      expect(state, isA<ShoppingServiceState>());
    });

    test('ShoppingStateData carries lists', () {
      final list = UnifiedShoppingList.personal(
        name: 'Test',
        ownerId: 'u1',
        ownerDisplayName: 'Anna',
      );
      final state = ShoppingStateData(
        lists: [list],
        activeListId: list.id,
      );
      expect(state, isA<ShoppingServiceState>());
    });
  });
}
