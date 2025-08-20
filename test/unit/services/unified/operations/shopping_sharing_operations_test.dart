import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/unified/operations/shopping_sharing_operations.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('ShoppingSharingOperations', () {
    late ShoppingSharingOperations operations;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create operations instance (no dependencies)
      operations = ShoppingSharingOperations();
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Initialization', () {
      test('should initialize without dependencies', () {
        // Assert
        expect(operations, isNotNull);
      });
    });
    
    group('Friend Sharing', () {
      test('should share list with friends', () async {
        // Act
        final result = await operations.shareList(
          listId: 'list-123',
          userIds: ['friend-1', 'friend-2'],
          permission: SharedListPermission.edit,
          shareMessage: 'Check out this shopping list!',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should share list with view permission', () async {
        // Act
        final result = await operations.shareList(
          listId: 'list-123',
          userIds: ['friend-1'],
          permission: SharedListPermission.view,
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should share list with admin permission', () async {
        // Act
        final result = await operations.shareList(
          listId: 'list-123',
          userIds: ['friend-1'],
          permission: SharedListPermission.admin,
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should unshare list from users', () async {
        // Act
        final result = await operations.unshareList(
          listId: 'list-123',
          userIds: ['friend-1', 'friend-2'],
        );
        
        // Assert
        expect(result, isTrue);
      });
    });
    
    group('Group Sharing', () {
      test('should share list with group', () async {
        // Act
        final result = await operations.shareWithGroup(
          listId: 'list-123',
          groupId: 'family-group',
          allowGuestEditing: true,
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should share list with group without guest editing', () async {
        // Act
        final result = await operations.shareWithGroup(
          listId: 'list-123',
          groupId: 'friends-group',
          allowGuestEditing: false,
        );
        
        // Assert
        expect(result, isTrue);
      });
    });
    
    group('Real-time Collaboration', () {
      test('should handle item added update', () async {
        // Arrange
        final update = {
          'type': 'item_added',
          'listId': 'list-123',
          'item': {'name': 'Milk', 'quantity': 2},
        };
        
        // Act & Assert - Should not throw
        await operations.handleRealtimeUpdate(update);
      });
      
      test('should handle item updated update', () async {
        // Arrange
        final update = {
          'type': 'item_updated',
          'listId': 'list-123',
          'itemId': 'item-456',
          'changes': {'quantity': 3},
        };
        
        // Act & Assert - Should not throw
        await operations.handleRealtimeUpdate(update);
      });
      
      test('should handle item removed update', () async {
        // Arrange
        final update = {
          'type': 'item_removed',
          'listId': 'list-123',
          'itemId': 'item-456',
        };
        
        // Act & Assert - Should not throw
        await operations.handleRealtimeUpdate(update);
      });
      
      test('should handle list shared update', () async {
        // Arrange
        final update = {
          'type': 'list_shared',
          'listId': 'list-123',
          'sharedWith': ['user-789'],
        };
        
        // Act & Assert - Should not throw
        await operations.handleRealtimeUpdate(update);
      });
      
      test('should handle permission changed update', () async {
        // Arrange
        final update = {
          'type': 'permission_changed',
          'listId': 'list-123',
          'userId': 'user-789',
          'newPermission': 'edit',
        };
        
        // Act & Assert - Should not throw
        await operations.handleRealtimeUpdate(update);
      });
      
      test('should handle unknown update type', () async {
        // Arrange
        final update = {
          'type': 'unknown_type',
          'listId': 'list-123',
        };
        
        // Act & Assert - Should not throw
        await operations.handleRealtimeUpdate(update);
      });
      
      test('should handle update without listId', () async {
        // Arrange
        final update = {
          'type': 'item_added',
          // Missing listId
        };
        
        // Act & Assert - Should not throw
        await operations.handleRealtimeUpdate(update);
      });
    });
    
    group('Permission Management', () {
      test('should update sharing permission', () async {
        // Act
        final result = await operations.updateSharingPermission(
          listId: 'list-123',
          userId: 'user-456',
          permission: SharedListPermission.edit,
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should get sharing status', () {
        // Act
        final status = operations.getSharingStatus('list-123');
        
        // Assert
        expect(status, isA<Map<String, dynamic>>());
        expect(status['listId'], equals('list-123'));
        expect(status['isShared'], isFalse);
        expect(status['sharedWith'], isA<List>());
        expect(status['permissions'], isA<Map>());
        expect(status['sharingEnabled'], isTrue);
      });
    });
    
    group('Activity Tracking', () {
      test('should get sharing activity', () {
        // Act
        final activity = operations.getSharingActivity('list-123');
        
        // Assert
        expect(activity, isA<List<Map<String, dynamic>>>());
        expect(activity.isNotEmpty, isTrue);
        
        final firstActivity = activity.first;
        expect(firstActivity['type'], equals('list_shared'));
        expect(firstActivity['timestamp'], isA<DateTime>());
        expect(firstActivity['userId'], isNotNull);
        expect(firstActivity['userName'], isNotNull);
        expect(firstActivity['description'], isNotNull);
      });
      
      test('should get sharing statistics', () {
        // Act
        final stats = operations.getSharingStatistics();
        
        // Assert
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['totalSharedLists'], equals(0));
        expect(stats['activeCollaborators'], equals(0));
        expect(stats['sharingActivityThisWeek'], equals(0));
        expect(stats['mostSharedCategories'], isA<Map>());
        expect(stats['collaborationHours'], equals(0.0));
      });
    });
  });
}