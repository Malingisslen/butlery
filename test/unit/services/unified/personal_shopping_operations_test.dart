/// Comprehensive unit tests for PersonalShoppingOperations
/// 
/// Tests the personal shopping operations coordinator that handles individual
/// shopping list management, item operations, import/export, and analytics.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/personal_shopping_operations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

import '../../../infrastructure/helpers/_base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock parent service that PersonalShoppingOperations delegates to
class MockParentService extends Mock {
  String? activeListId;
  List<UnifiedShoppingList> personalLists = [];
  UnifiedShoppingList? activeList;
  
  // Mock methods that operations will delegate to
  Future<String?> createPersonalList(String name, {List<UnifiedShoppingItem>? items}) async {
    final list = UnifiedShoppingList.personal(
      name: name,
      ownerId: 'test-user',
      ownerDisplayName: 'Test User',
      items: items ?? [],
    );
    personalLists.add(list);
    return list.id;
  }
  
  Future<bool> renameList(String listId, String newName) async => true;
  Future<bool> deleteList(String listId) async => true;
  Future<bool> setActiveList(String listId) async {
    activeListId = listId;
    activeList = personalLists.firstWhere((l) => l.id == listId);
    return true;
  }
  
  Future<bool> addItemToActiveList({
    required String name,
    required double amount,
    String unit = '',
    String category = 'Övrigt',
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) async => true;
  
  Future<bool> toggleItemBought(String itemId) async => true;
  Future<bool> removeItemFromActiveList(String itemId) async => true;
  Future<bool> clearBoughtItems() async => true;
  Future<bool> uncheckAllItems() async => true;
  Future<bool> _updateList(UnifiedShoppingList list) async => true;
}

void main() {
  group('PersonalShoppingOperations', () {
    late PersonalShoppingOperations operations;
    late MockParentService mockParent;
    late UnifiedShoppingList testList;
    late UnifiedShoppingItem testItem;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(UnifiedShoppingList.personal(
        name: 'Test',
        ownerId: 'test',
        ownerDisplayName: 'Test',
      ));
      registerFallbackValue(UnifiedShoppingItem.basic(
        name: 'Test',
        amount: 1.0,
        unit: 'st',
        category: 'Test',
      ));
    });
    
    setUp(() {
      mockParent = MockParentService();
      operations = PersonalShoppingOperations(mockParent);
      
      testItem = UnifiedShoppingItem.basic(
        name: 'Mjölk',
        amount: 1.5,
        unit: 'liter',
        category: 'Mejeri',
      );
      
      testList = UnifiedShoppingList.personal(
        name: 'Veckans inköp',
        ownerId: 'test-user',
        ownerDisplayName: 'Test User',
        items: [testItem],
      );
      
      mockParent.personalLists = [testList];
      mockParent.activeList = testList;
      mockParent.activeListId = testList.id;
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Personal List CRUD', () {
      test('should create personal shopping list', () async {
        // Act
        final listId = await operations.createList(
          'Måndagslista',
          items: [testItem],
        );
        
        // Assert
        expect(listId, isNotNull);
        expect(mockParent.personalLists.length, equals(2));
      });
      
      test('should get all personal lists', () {
        // Act
        final lists = operations.getAllLists();
        
        // Assert
        expect(lists, isNotEmpty);
        expect(lists.first.name, equals('Veckans inköp'));
      });
      
      test('should get list by ID', () {
        // Act
        final list = operations.getListById(testList.id);
        
        // Assert
        expect(list, isNotNull);
        expect(list?.name, equals('Veckans inköp'));
      });
      
      test('should rename personal list', () async {
        // Arrange
        when(() => mockParent.renameList(any(), any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.renameList(testList.id, 'Uppdaterad lista');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should delete personal list', () async {
        // Arrange
        when(() => mockParent.deleteList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.deleteList(testList.id);
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should set active list', () async {
        // Arrange
        when(() => mockParent.setActiveList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.setActiveList(testList.id);
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should get active list', () {
        // Act
        final activeList = operations.getActiveList();
        
        // Assert
        expect(activeList, isNotNull);
        expect(activeList?.name, equals('Veckans inköp'));
      });
      
      test('should not delete collaborative list', () async {
        // Arrange
        final collabList = UnifiedShoppingList.collaborative(
          name: 'Delad lista',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
          memberPermissions: {},
        );
        mockParent.personalLists.add(collabList);
        
        // Act
        final success = await operations.deleteList(collabList.id);
        
        // Assert
        expect(success, isFalse);
      });
    });
    
    group('Item Management', () {
      test('should add item to active list', () async {
        // Arrange
        when(() => mockParent.addItemToActiveList(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
          note: any(named: 'note'),
          estimatedPrice: any(named: 'estimatedPrice'),
          priority: any(named: 'priority'),
        )).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.addItem(
          name: 'Bröd',
          amount: 2.0,
          unit: 'st',
          category: 'Bageri',
          note: 'Fullkorn',
          estimatedPrice: 35.0,
          priority: 2,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should add item to specific list', () async {
        // Arrange
        when(() => mockParent.setActiveList(any())).thenAnswer((_) async => true);
        when(() => mockParent.addItemToActiveList(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
          note: any(named: 'note'),
          estimatedPrice: any(named: 'estimatedPrice'),
          priority: any(named: 'priority'),
        )).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.addItem(
          listId: testList.id,
          name: 'Ägg',
          amount: 12.0,
          unit: 'st',
          category: 'Mejeri',
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should update item in list', () async {
        // Arrange
        when(() => mockParent._updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.updateItem(
          listId: testList.id,
          itemId: testItem.id,
          name: 'Mjölk (ekologisk)',
          amount: 2.0,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should toggle item bought status', () async {
        // Arrange
        when(() => mockParent.toggleItemBought(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.toggleItemBought(testItem.id);
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should remove item from list', () async {
        // Arrange
        when(() => mockParent.removeItemFromActiveList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.removeItem(testItem.id);
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should clear bought items', () async {
        // Arrange
        when(() => mockParent.clearBoughtItems()).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.clearBoughtItems();
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should uncheck all items', () async {
        // Arrange
        when(() => mockParent.uncheckAllItems()).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.uncheckAllItems();
        
        // Assert
        expect(success, isTrue);
      });
    });
    
    group('List Analysis', () {
      test('should get list statistics', () {
        // Act
        final stats = operations.getListStats(testList.id);
        
        // Assert
        expect(stats, isNotEmpty);
        expect(stats['totalItems'], equals(1));
        expect(stats['boughtItems'], equals(0));
        expect(stats['remainingItems'], equals(1));
        expect(stats['completionPercentage'], equals(0));
      });
      
      test('should get items by category', () {
        // Act
        final categories = operations.getItemsByCategory(testList.id);
        
        // Assert
        expect(categories, isNotEmpty);
        expect(categories['Mejeri'], isNotNull);
        expect(categories['Mejeri']?.length, equals(1));
      });
      
      test('should handle empty category', () {
        // Arrange
        final itemNoCategory = UnifiedShoppingItem.basic(
          name: 'Test',
          amount: 1.0,
          unit: 'st',
          category: '',
        );
        final listWithEmptyCategory = UnifiedShoppingList.personal(
          name: 'Test',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
          items: [itemNoCategory],
        );
        mockParent.personalLists.add(listWithEmptyCategory);
        
        // Act
        final categories = operations.getItemsByCategory(listWithEmptyCategory.id);
        
        // Assert
        expect(categories['Övrigt'], isNotNull);
      });
    });
    
    group('Export Functionality', () {
      test('should export list as text', () {
        // Act
        final text = operations.exportListAsText(testList.id);
        
        // Assert
        expect(text, contains('Veckans inköp'));
        expect(text, contains('Mjölk'));
        expect(text, contains('☐'));
      });
      
      test('should export list as structured data', () {
        // Act
        final data = operations.exportListAsData(testList.id);
        
        // Assert
        expect(data['format'], equals('personal_shopping_list'));
        expect(data['list'], isNotNull);
        expect(data['statistics'], isNotNull);
      });
      
      test('should handle missing list in export', () {
        // Act
        final text = operations.exportListAsText('non-existent');
        final data = operations.exportListAsData('non-existent');
        
        // Assert
        expect(text, equals('Lista hittades inte'));
        expect(data['error'], equals('Lista hittades inte'));
      });
    });
    
    group('Import Functionality', () {
      test('should import items from text', () async {
        // Arrange
        when(() => mockParent._updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.importItemsFromText(
          listId: testList.id,
          text: '2 liter Mjölk\n12 st Ägg\nBröd',
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should create list from recipe', () async {
        // Act
        final listId = await operations.createListFromRecipe(
          recipeName: 'Köttbullar',
          ingredients: ['500g köttfärs', '2 dl grädde', '1 gul lök'],
          servingMultiplier: 2.0,
        );
        
        // Assert
        expect(listId, isNotNull);
      });
      
      test('should handle import with clear existing', () async {
        // Arrange
        when(() => mockParent._updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.importItemsFromText(
          listId: testList.id,
          text: 'Nytt innehåll',
          clearExisting: true,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should skip headers in import', () async {
        // Arrange
        when(() => mockParent._updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.importItemsFromText(
          listId: testList.id,
          text: '📋 Min lista\n======\n2 liter Mjölk',
        );
        
        // Assert
        expect(success, isTrue);
      });
    });
    
    group('Edge Cases', () {
      test('should handle list not found errors', () async {
        // Act
        final renameSuccess = await operations.renameList('non-existent', 'New Name');
        final deleteSuccess = await operations.deleteList('non-existent');
        final setActiveSuccess = await operations.setActiveList('non-existent');
        
        // Assert
        expect(renameSuccess, isFalse);
        expect(deleteSuccess, isFalse);
        expect(setActiveSuccess, isFalse);
      });
      
      test('should handle item not found in update', () async {
        // Act
        final success = await operations.updateItem(
          listId: testList.id,
          itemId: 'non-existent-item',
          name: 'Updated',
        );
        
        // Assert
        expect(success, isFalse);
      });
      
      test('should handle no active list errors', () async {
        // Arrange
        mockParent.activeList = null;
        
        // Act
        final toggleSuccess = await operations.toggleItemBought('item-id');
        final removeSuccess = await operations.removeItem('item-id');
        
        // Assert
        expect(toggleSuccess, isFalse);
        expect(removeSuccess, isFalse);
      });
      
      test('should handle import errors gracefully', () async {
        // Arrange
        when(() => mockParent._updateList(any())).thenThrow(Exception('Import error'));
        
        // Act
        final success = await operations.importItemsFromText(
          listId: testList.id,
          text: 'Test import',
        );
        
        // Assert
        expect(success, isFalse);
      });
      
      test('should handle recipe creation errors', () async {
        // Arrange
        when(() => mockParent.createPersonalList(any(), items: any(named: 'items')))
            .thenThrow(Exception('Creation error'));
        
        // Act
        final listId = await operations.createListFromRecipe(
          recipeName: 'Test',
          ingredients: ['item'],
        );
        
        // Assert
        expect(listId, isNull);
      });
    });
  });
}