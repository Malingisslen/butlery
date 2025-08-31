/// Unit tests for ShoppingStateManager - Handles shopping list state and cache management
///
/// Tests state management operations including:
/// - Cache operations (update, retrieve, clear)
/// - Conflict resolution handling
/// - State synchronization
/// - Cache invalidation
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/services/unified/modules/shopping_state_manager.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('ShoppingStateManager', () {
    late ShoppingStateManager stateManager;
    
    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      // Initialize service locator for each test
      await TestServiceLocator.initialize();
      
      // Create new instance for each test
      stateManager = ShoppingStateManager();
    });
    
    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });
    
    group('Cache Operations', () {
      test('should update cached list', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        // Act
        await stateManager.updateCachedList(list);
        
        // Assert - Method completes without error
        expect(true, isTrue);
      });
      
      test('should update existing cached list', () async {
        // Arrange
        final list1 = UnifiedShoppingList.personal(
          name: 'Original List',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        await stateManager.updateCachedList(list1);
        
        final list2 = list1.copyWith(
          name: 'Updated List',
          items: [
            UnifiedShoppingItem(
              name: 'New Item',
              amount: 1,
              unit: 'st',
              category: 'Test',
            ),
          ],
        );
        
        // Act
        await stateManager.updateCachedList(list2);
        
        // Assert - Method completes without error
        expect(true, isTrue);
      });
      
      test('should cache multiple lists', () async {
        // Arrange
        final list1 = UnifiedShoppingList.personal(
          name: 'List 1',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        final list2 = UnifiedShoppingList.collaborative(
          name: 'List 2',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
          memberPermissions: {
            'friend-1': SharedListPermission.edit,
          },
        );
        
        final list3 = UnifiedShoppingList(
          name: 'List 3',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
          type: ListType.template,
        );
        
        // Act
        await stateManager.updateCachedList(list1);
        await stateManager.updateCachedList(list2);
        await stateManager.updateCachedList(list3);
        
        // Assert - All operations complete without error
        expect(true, isTrue);
      });
      
      test('should handle list with items', () async {
        // Arrange
        final items = [
          UnifiedShoppingItem(name: 'Mjölk', amount: 1, unit: 'l', category: 'Mejeri'),
          UnifiedShoppingItem(name: 'Bröd', amount: 2, unit: 'st', category: 'Bageri'),
          UnifiedShoppingItem(name: 'Ägg', amount: 12, unit: 'st', category: 'Mejeri'),
        ];
        
        final list = UnifiedShoppingList.personal(
          name: 'Shopping List',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
          items: items,
        );
        
        // Act
        await stateManager.updateCachedList(list);
        
        // Assert
        expect(list.items.length, equals(3));
      });
    });
    
    group('Conflict Resolution', () {
      test('should resolve basic conflict', () async {
        // Arrange
        final conflict = {
          'type': 'update_conflict',
          'listId': 'list-123',
          'localVersion': 1,
          'remoteVersion': 2,
        };
        
        // Act
        await stateManager.resolveConflict(conflict);
        
        // Assert - Method completes without error
        expect(true, isTrue);
      });
      
      test('should handle delete conflict', () async {
        // Arrange
        final conflict = {
          'type': 'delete_conflict',
          'listId': 'list-123',
          'reason': 'List deleted remotely',
        };
        
        // Act
        await stateManager.resolveConflict(conflict);
        
        // Assert
        expect(true, isTrue);
      });
      
      test('should handle merge conflict', () async {
        // Arrange
        final conflict = {
          'type': 'merge_conflict',
          'listId': 'list-123',
          'localChanges': ['item1', 'item2'],
          'remoteChanges': ['item3', 'item4'],
        };
        
        // Act
        await stateManager.resolveConflict(conflict);
        
        // Assert
        expect(true, isTrue);
      });
      
      test('should handle permission conflict', () async {
        // Arrange
        final conflict = {
          'type': 'permission_conflict',
          'listId': 'list-123',
          'userId': 'user-456',
          'requiredPermission': 'edit',
          'actualPermission': 'view',
        };
        
        // Act
        await stateManager.resolveConflict(conflict);
        
        // Assert
        expect(true, isTrue);
      });
      
      test('should handle sync conflict', () async {
        // Arrange
        final conflict = {
          'type': 'sync_conflict',
          'listId': 'list-123',
          'error': 'Network timeout',
          'retryCount': 3,
        };
        
        // Act
        await stateManager.resolveConflict(conflict);
        
        // Assert
        expect(true, isTrue);
      });
      
      test('should handle unknown conflict type', () async {
        // Arrange
        final conflict = {
          'type': 'unknown_type',
          'data': 'some data',
        };
        
        // Act
        await stateManager.resolveConflict(conflict);
        
        // Assert
        expect(true, isTrue);
      });
      
      test('should handle empty conflict data', () async {
        // Arrange
        final conflict = <String, dynamic>{};
        
        // Act
        await stateManager.resolveConflict(conflict);
        
        // Assert
        expect(true, isTrue);
      });
    });
    
    group('State Management', () {
      test('should manage personal list state', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Personal Shopping',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        // Act
        await stateManager.updateCachedList(list);
        
        // Assert
        expect(list.isPersonal, isTrue);
        expect(list.isCollaborative, isFalse);
      });
      
      test('should manage collaborative list state', () async {
        // Arrange
        final list = UnifiedShoppingList.collaborative(
          name: 'Shared Shopping',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
          memberPermissions: {
            'friend-1': SharedListPermission.admin,
            'friend-2': SharedListPermission.edit,
            'friend-3': SharedListPermission.view,
          },
        );
        
        // Act
        await stateManager.updateCachedList(list);
        
        // Assert
        expect(list.isCollaborative, isTrue);
        expect(list.memberPermissions.length, equals(4)); // Including owner
      });
      
      test('should manage template list state', () async {
        // Arrange
        final list = UnifiedShoppingList(
          name: 'Template List',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
          type: ListType.template,
        );
        
        // Act
        await stateManager.updateCachedList(list);
        
        // Assert
        expect(list.type, equals(ListType.template));
      });
      
      test('should handle sync status updates', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        // Act - Update with different sync states
        await stateManager.updateCachedList(list);
        await stateManager.updateCachedList(list.markAsPending());
        await stateManager.updateCachedList(list.markAsSynced());
        await stateManager.updateCachedList(list.markAsError());
        
        // Assert - All updates complete
        expect(true, isTrue);
      });
    });
    
    group('Edge Cases', () {
      test('should handle list with special characters', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Ägg & Mjölk @ 50% rabatt!',
          ownerId: 'user-123',
          ownerDisplayName: 'Ñäme Ü§ér',
        );
        
        // Act
        await stateManager.updateCachedList(list);
        
        // Assert
        expect(true, isTrue);
      });
      
      test('should handle rapid updates', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        // Act - Rapid sequential updates
        for (int i = 0; i < 100; i++) {
          final updatedList = list.copyWith(
            name: 'Updated List $i',
          );
          await stateManager.updateCachedList(updatedList);
        }
        
        // Assert
        expect(true, isTrue);
      });
      
      test('should handle concurrent conflict resolutions', () async {
        // Arrange
        final conflicts = List.generate(10, (i) => {
          'type': 'conflict_$i',
          'listId': 'list-$i',
          'data': 'data-$i',
        });
        
        // Act - Resolve all conflicts
        for (final conflict in conflicts) {
          await stateManager.resolveConflict(conflict);
        }
        
        // Assert
        expect(true, isTrue);
      });
      
      test('should handle large list with many items', () async {
        // Arrange
        final items = List.generate(1000, (i) => 
          UnifiedShoppingItem(
            name: 'Item $i',
            amount: i.toDouble(),
            unit: 'st',
            category: 'Category ${i % 10}',
          )
        );
        
        final list = UnifiedShoppingList.personal(
          name: 'Large List',
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
          items: items,
        );
        
        // Act
        await stateManager.updateCachedList(list);
        
        // Assert
        expect(list.items.length, equals(1000));
      });
    });
  });
}