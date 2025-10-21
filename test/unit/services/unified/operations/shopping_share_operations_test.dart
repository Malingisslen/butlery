import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/unified/operations/shopping_share_operations.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('ShoppingShareOperations', () {
    late ShoppingShareOperations operations;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create operations instance with required dependencies
      operations = ShoppingShareOperations(
        firestore: FakeFirebaseFirestore(),
        permissionService: MockPermissionService(),
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Initialization', () {
      test('should initialize with all modules', () {
        // Assert
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
        // Act
        final result = operations.exportListAsText('list-123');
        
        // Assert
        expect(result, isA<String>());
        expect(result, contains('Shopping List'));
      });
      
      test('should export list as minimal text', () {
        // Act
        final result = operations.exportListAsMinimalText('list-123');
        
        // Assert
        expect(result, isA<String>());
        expect(result, contains('List list-123'));
      });
      
      test('should export list as JSON', () {
        // Act
        final result = operations.exportListAsJson('list-123');
        
        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result['listId'], equals('list-123'));
        expect(result['items'], isA<List>());
      });
      
      test('should export list as CSV', () {
        // Act
        final result = operations.exportListAsCSV('list-123');
        
        // Assert
        expect(result, isA<String>());
        expect(result, contains('Item'));
        expect(result, contains('Quantity'));
      });
    });
    
    group('External Sharing Operations', () {
      test('should share list via external apps', () async {
        // Act
        final result = await operations.shareList(
          listId: 'list-123',
          format: 'text',
          customMessage: 'Check out my shopping list',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should share list in JSON format', () async {
        // Act
        final result = await operations.shareList(
          listId: 'list-123',
          format: 'json',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should create public link', () async {
        // Act
        final result = await operations.createPublicLink('list-123');
        
        // Assert
        expect(result, isA<String?>());
        expect(result, contains('list-123'));
      });
    });
    
    group('Template Operations', () {
      test('should save list as template', () async {
        // Act
        final result = await operations.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Weekly Shopping',
          description: 'My weekly shopping template',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should create list from template', () async {
        // Act
        final result = await operations.createFromTemplate(
          templateId: 'template-456',
          customName: 'This Week Shopping',
        );
        
        // Assert
        expect(result, isA<String?>());
        expect(result, contains('list'));
      });
    });
    
    group('Import Operations', () {
      test('should import from text', () async {
        // Arrange
        const text = '''
        Milk - 2 liters
        Bread - 1 loaf
        Eggs - 12
        ''';
        
        // Act
        final result = await operations.importFromText(
          text: text,
          listName: 'Imported List',
        );
        
        // Assert
        expect(result, isA<String?>());
        expect(result, contains('list'));
      });
      
      test('should import from JSON', () async {
        // Arrange
        final jsonData = {
          'name': 'Shopping List',
          'items': [
            {'name': 'Milk', 'quantity': 2, 'unit': 'liters'},
            {'name': 'Bread', 'quantity': 1, 'unit': 'loaf'},
          ],
        };
        
        // Act
        final result = await operations.importFromJson(jsonData);
        
        // Assert
        expect(result, isA<String?>());
        expect(result, contains('list'));
      });
    });
    
    group('Social Sharing Operations', () {
      test('should share with friends', () async {
        // Act
        final result = await operations.shareWithFriends(
          listId: 'list-123',
          friendIds: ['friend-1', 'friend-2'],
          message: 'Check out my shopping list!',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should share with single friend', () async {
        // Act
        final result = await operations.shareListWithFriend('list-123', 'friend-1');
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should share with multiple friends', () async {
        // Act
        final result = await operations.shareListWithMultipleFriends(
          listId: 'list-123',
          friendIds: ['friend-1', 'friend-2', 'friend-3'],
          message: 'Shopping together!',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should share with groups', () async {
        // Act
        final result = await operations.shareWithGroups(
          listId: 'list-123',
          groupIds: ['family', 'roommates'],
          message: 'Weekly shopping',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should share with single group', () async {
        // Act
        final result = await operations.shareListWithGroup('list-123', 'family');
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should share with multiple groups', () async {
        // Act
        final result = await operations.shareListWithMultipleGroups(
          listId: 'list-123',
          groupIds: ['family', 'friends', 'colleagues'],
          message: 'Group shopping',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should send collaboration invite', () async {
        // Act
        final result = await operations.sendCollaborationInvite(
          listId: 'list-123',
          recipientId: 'user-456',
          message: 'Join my shopping list!',
        );
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should get shopping lists shared with me', () async {
        // Act
        final result = await operations.getShoppingListsSharedWithMe();
        
        // Assert
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(result.isEmpty, isTrue);  // Simplified implementation returns empty list
      });
      
      test('should get shopping lists shared by me', () async {
        // Act
        final result = await operations.getShoppingListsSharedByMe();
        
        // Assert
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(result.isEmpty, isTrue);  // Simplified implementation returns empty list
      });
      
      test('should import shared shopping list', () async {
        // Act
        final result = await operations.importSharedShoppingList('shared-list-123');
        
        // Assert
        expect(result, isA<String?>());
        expect(result, contains('list'));
      });
      
      test('should mark shared list as viewed', () async {
        // Act & Assert - Should not throw
        await operations.markSharedShoppingListAsViewed('shared-list-123');
      });
      
      test('should get shopping list sharing stats', () async {
        // Act
        final result = await operations.getShoppingListSharingStats('list-123');
        
        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result['sharedWith'], equals(0));
        expect(result['views'], equals(0));
        expect(result['lastShared'], isA<String>());
      });
    });
    
    group('Module Access', () {
      test('should provide access to export module', () {
        // Act
        final module = operations.export;
        
        // Assert
        expect(module, isA<ShoppingExportModule>());
        expect(module.exportListAsText('list-123'), isA<String>());
      });
      
      test('should provide access to external share module', () {
        // Act
        final module = operations.externalShare;
        
        // Assert
        expect(module, isA<ShoppingExternalShareModule>());
      });
      
      test('should provide access to template module', () {
        // Act
        final module = operations.template;
        
        // Assert
        expect(module, isA<ShoppingTemplateModule>());
      });
      
      test('should provide access to import module', () {
        // Act
        final module = operations.import;
        
        // Assert
        expect(module, isA<ShoppingImportModule>());
      });
      
      test('should provide access to social share module', () {
        // Act
        final module = operations.socialShare;
        
        // Assert
        expect(module, isA<ShoppingSocialShareModule>());
      });
    });
  });
}