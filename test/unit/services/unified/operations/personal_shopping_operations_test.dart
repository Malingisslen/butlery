/// Comprehensive unit tests for PersonalShoppingOperations
///
/// Tests the personal shopping operations facade that handles CRUD operations,
/// item management, import/export functionality, and analytics for
/// individual shopping list management.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/personal_shopping_operations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('PersonalShoppingOperations', () {
    late PersonalShoppingOperations operations;
    late MockUnifiedShoppingService mockParent;
    late UnifiedShoppingList testList;
    late UnifiedShoppingItem testItem;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(UnifiedShoppingList.personal(
        name: 'fallback',
        ownerId: 'test-user',
        ownerDisplayName: 'Test User',
      ));
      registerFallbackValue(
          UnifiedShoppingItem.basic(name: 'fallback', amount: 1));
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockParent = MockUnifiedShoppingService();

      // Create test data
      testItem = UnifiedShoppingItem(
        id: 'item-1',
        name: 'Mjölk',
        amount: 2.0,
        unit: 'l',
        category: 'Mejeri',
        priority: 1,
        bought: false,
        addedAt: DateTime.now(),
      );

      testList = UnifiedShoppingList(
        id: 'test-list-1',
        name: 'Veckohandling',
        ownerId: 'test-user',
        ownerDisplayName: 'Test User',
        items: [testItem],
        type: ListType.personal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Configure mock parent
      mockParent.setShoppingState(
        activeListId: 'test-list-1',
        personalLists: [testList],
        lists: [testList],
      );

      operations = PersonalShoppingOperations(
        getPersonalLists: () => mockParent.personalLists,
        getActiveList: () => mockParent.activeList,
        getActiveListId: () => mockParent.activeListId,
        createPersonalList: (name, {items}) =>
            mockParent.createPersonalList(name, items: items),
        renameList: (listId, newName) => mockParent.renameList(listId, newName),
        deleteList: (listId) => mockParent.deleteList(listId),
        setActiveList: (listId) => mockParent.setActiveList(listId),
        addItemToActiveList: ({
          required String name,
          double? amount,
          String? unit,
          String? category,
          String? note,
          double? estimatedPrice,
          int? priority,
          String? recipeId,
          String? recipeName,
        }) =>
            mockParent.addItemToActiveList(
          name: name,
          amount: amount,
          unit: unit,
          category: category,
          note: note,
          estimatedPrice: estimatedPrice,
          priority: priority,
          recipeId: recipeId,
          recipeName: recipeName,
        ),
        updateList: (list) => mockParent.updateList(list),
        toggleItemBought: (itemId) => mockParent.toggleItemBought(itemId),
        removeItemFromActiveList: (itemId) =>
            mockParent.removeItemFromActiveList(itemId),
        clearBoughtItems: () => mockParent.clearBoughtItems(),
        uncheckAllItems: () => mockParent.uncheckAllItems(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('List CRUD Operations', () {
      test('should create personal list successfully', () async {
        // Arrange
        when(() => mockParent.createPersonalList(
              any(),
              items: any(named: 'items'),
            )).thenAnswer((_) async => 'new-list-id');

        // Act
        final result = await operations.createList('Ny lista');

        // Assert
        expect(result, equals('new-list-id'));
        verify(() => mockParent.createPersonalList('Ny lista', items: null))
            .called(1);
      });

      test('should create list with initial items', () async {
        // Arrange
        final items = [
          UnifiedShoppingItem.basic(name: 'Bröd', amount: 1),
          UnifiedShoppingItem.basic(name: 'Smör', amount: 200, unit: 'g'),
        ];

        when(() => mockParent.createPersonalList(
              any(),
              items: any(named: 'items'),
            )).thenAnswer((_) async => 'new-list-id');

        // Act
        final result =
            await operations.createList('Frukostlista', items: items);

        // Assert
        expect(result, equals('new-list-id'));
        verify(() =>
                mockParent.createPersonalList('Frukostlista', items: items))
            .called(1);
      });

      test('should get all personal lists', () {
        // Arrange
        final secondList = UnifiedShoppingList(
          id: 'test-list-2',
          name: 'Extra lista',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
          items: [],
          type: ListType.personal,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        mockParent.setShoppingState(
          personalLists: [testList, secondList],
          lists: [testList, secondList],
          activeListId: 'test-list-1',
        );

        // Act
        final lists = operations.getAllLists();

        // Assert
        expect(lists, hasLength(2));
        expect(lists[0].name, equals('Veckohandling'));
        expect(lists[1].name, equals('Extra lista'));
      });

      test('should get list by ID', () {
        // Act
        final list = operations.getListById('test-list-1');

        // Assert
        expect(list, isNotNull);
        expect(list!.name, equals('Veckohandling'));
      });

      test('should return null for non-existent list ID', () {
        // Act
        final list = operations.getListById('non-existent');

        // Assert
        expect(list, isNull);
      });

      test('should rename list successfully', () async {
        // Arrange
        when(() => mockParent.renameList(any(), any()))
            .thenAnswer((_) async => true);

        // Act
        final result =
            await operations.renameList('test-list-1', 'Månadshandling');

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.renameList('test-list-1', 'Månadshandling'))
            .called(1);
      });

      test('should fail to rename non-existent list', () async {
        // Act
        final result = await operations.renameList('non-existent', 'New Name');

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParent.renameList(any(), any()));
      });

      test('should delete personal list successfully', () async {
        // Arrange
        when(() => mockParent.deleteList(any())).thenAnswer((_) async => true);

        // Act
        final result = await operations.deleteList('test-list-1');

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.deleteList('test-list-1')).called(1);
      });

      test('should not delete collaborative list', () async {
        // Arrange
        final collaborativeList = UnifiedShoppingList(
          id: testList.id,
          name: testList.name,
          ownerId: testList.ownerId,
          ownerDisplayName: testList.ownerDisplayName,
          items: testList.items,
          type: ListType.collaborative,
          createdAt: testList.createdAt,
          updatedAt: testList.updatedAt,
        );
        mockParent.setShoppingState(
          personalLists: [collaborativeList],
          lists: [collaborativeList],
          activeListId: 'test-list-1',
        );

        // Act
        final result = await operations.deleteList('test-list-1');

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParent.deleteList(any()));
      });

      test('should set active list successfully', () async {
        // Arrange
        when(() => mockParent.setActiveList(any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await operations.setActiveList('test-list-1');

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.setActiveList('test-list-1')).called(1);
      });

      test('should get active personal list', () {
        // Act
        final activeList = operations.getActiveList();

        // Assert
        expect(activeList, isNotNull);
        expect(activeList!.id, equals('test-list-1'));
      });

      test('should return null if active list is collaborative', () {
        // Arrange
        final collaborativeList = UnifiedShoppingList(
          id: testList.id,
          name: testList.name,
          ownerId: testList.ownerId,
          ownerDisplayName: testList.ownerDisplayName,
          items: testList.items,
          type: ListType.collaborative,
          createdAt: testList.createdAt,
          updatedAt: testList.updatedAt,
        );
        mockParent.setShoppingState(
          personalLists: [collaborativeList],
          lists: [collaborativeList],
          activeListId: 'test-list-1',
        );

        // Act
        final activeList = operations.getActiveList();

        // Assert
        expect(activeList, isNull);
      });
    });

    group('Item Management', () {
      test('should add item to specific list', () async {
        // Arrange
        when(() => mockParent.setActiveList(any()))
            .thenAnswer((_) async => true);
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
        final result = await operations.addItem(
          listId: 'test-list-1',
          name: 'Ägg',
          amount: 12,
          unit: 'st',
          category: 'Mejeri',
          priority: 2,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.addItemToActiveList(
              name: 'Ägg',
              amount: 12,
              unit: 'st',
              category: 'Mejeri',
              note: null,
              estimatedPrice: null,
              priority: 2,
            )).called(1);
      });

      test('should add item to active list when no listId specified', () async {
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
        final result = await operations.addItem(
          name: 'Kaffe',
          amount: 500,
          unit: 'g',
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.addItemToActiveList(
              name: 'Kaffe',
              amount: 500,
              unit: 'g',
              category: 'Övrigt',
              note: null,
              estimatedPrice: null,
              priority: 3,
            )).called(1);
      });

      test('should update item successfully', () async {
        // Arrange
        when(() => mockParent.updateList(any())).thenAnswer((_) async => true);

        // Act
        final result = await operations.updateItem(
          listId: 'test-list-1',
          itemId: 'item-1',
          name: 'Mjölk 3%',
          amount: 3.0,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.updateList(any())).called(1);
      });

      test('should fail to update item in non-existent list', () async {
        // Act
        final result = await operations.updateItem(
          listId: 'non-existent',
          itemId: 'item-1',
          name: 'Updated',
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParent.updateList(any()));
      });

      test('should toggle item bought status', () async {
        // Arrange
        when(() => mockParent.toggleItemBought(any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await operations.toggleItemBought('item-1');

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.toggleItemBought('item-1')).called(1);
      });

      test('should remove item from active list', () async {
        // Arrange
        when(() => mockParent.removeItemFromActiveList(any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await operations.removeItem('item-1');

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.removeItemFromActiveList('item-1')).called(1);
      });

      test('should clear bought items from active list', () async {
        // Arrange
        when(() => mockParent.clearBoughtItems()).thenAnswer((_) async => true);

        // Act
        final result = await operations.clearBoughtItems();

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.clearBoughtItems()).called(1);
      });

      test('should clear bought items from specific list', () async {
        // Arrange
        when(() => mockParent.setActiveList(any()))
            .thenAnswer((_) async => true);
        when(() => mockParent.clearBoughtItems()).thenAnswer((_) async => true);

        // Act
        final result = await operations.clearBoughtItems(listId: 'test-list-1');

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.clearBoughtItems()).called(1);
      });

      test('should uncheck all items in active list', () async {
        // Arrange
        when(() => mockParent.uncheckAllItems()).thenAnswer((_) async => true);

        // Act
        final result = await operations.uncheckAllItems();

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.uncheckAllItems()).called(1);
      });
    });

    group('List Analysis', () {
      test('should get list statistics', () {
        // Arrange
        final items = [
          UnifiedShoppingItem(
            id: 'item-1',
            name: 'Mjölk',
            amount: 2.0,
            unit: 'l',
            category: 'Mejeri',
            estimatedPrice: 15.90,
            bought: false,
            addedAt: DateTime.now(),
          ),
          UnifiedShoppingItem(
            id: 'item-2',
            name: 'Bröd',
            amount: 1.0,
            unit: 'st',
            category: 'Bageri',
            estimatedPrice: 25.00,
            bought: true,
            addedAt: DateTime.now(),
          ),
          UnifiedShoppingItem(
            id: 'item-3',
            name: 'Smör',
            amount: 1.0,
            unit: 'paket',
            category: 'Mejeri',
            estimatedPrice: 35.50,
            bought: false,
            addedAt: DateTime.now(),
          ),
        ];

        final listWithItems = testList.copyWith(items: items);
        mockParent.setShoppingState(
          personalLists: [listWithItems],
          lists: [listWithItems],
          activeListId: 'test-list-1',
        );

        // Act
        final stats = operations.getListStats('test-list-1');

        // Assert
        expect(stats['totalItems'], equals(3));
        expect(stats['boughtItems'], equals(1));
        expect(stats['remainingItems'], equals(2));
        expect(stats['completionPercentage'], equals(33));
        expect(stats['estimatedTotal'], equals(2 * 15.90 + 25.00 + 35.50));
        expect(stats['categoryBreakdown'], isA<Map<String, int>>());
        expect(stats['categoryBreakdown']['Mejeri'], equals(2));
        expect(stats['categoryBreakdown']['Bageri'], equals(1));
      });

      test('should return empty stats for non-existent list', () {
        // Act
        final stats = operations.getListStats('non-existent');

        // Assert
        expect(stats, isEmpty);
      });

      test('should get items grouped by category', () {
        // Arrange
        final items = [
          UnifiedShoppingItem(
            id: 'item-1',
            name: 'Mjölk',
            category: 'Mejeri',
            amount: 1,
            priority: 1,
            bought: false,
            addedAt: DateTime.now(),
          ),
          UnifiedShoppingItem(
            id: 'item-2',
            name: 'Yoghurt',
            category: 'Mejeri',
            amount: 1,
            priority: 2,
            bought: false,
            addedAt: DateTime.now(),
          ),
          UnifiedShoppingItem(
            id: 'item-3',
            name: 'Bröd',
            category: 'Bageri',
            amount: 1,
            priority: 1,
            bought: false,
            addedAt: DateTime.now(),
          ),
        ];

        final listWithItems = testList.copyWith(items: items);
        mockParent.setShoppingState(
          personalLists: [listWithItems],
          lists: [listWithItems],
          activeListId: 'test-list-1',
        );

        // Act
        final categoryMap = operations.getItemsByCategory('test-list-1');

        // Assert
        expect(categoryMap, hasLength(2));
        expect(categoryMap['Mejeri'], hasLength(2));
        expect(categoryMap['Bageri'], hasLength(1));
        expect(categoryMap['Mejeri']![0].name,
            equals('Mjölk')); // Sorted by priority
        expect(categoryMap['Mejeri']![1].name, equals('Yoghurt'));
      });
    });

    group('Export Functionality', () {
      test('should export list as text', () {
        // Arrange
        final items = [
          UnifiedShoppingItem(
            id: 'item-1',
            name: 'Mjölk',
            amount: 2.0,
            unit: 'l',
            category: 'Mejeri',
            bought: false,
            addedAt: DateTime.now(),
          ),
          UnifiedShoppingItem(
            id: 'item-2',
            name: 'Bröd',
            amount: 1.0,
            unit: 'st',
            category: 'Bageri',
            bought: true,
            addedAt: DateTime.now(),
          ),
        ];

        final listWithItems = testList.copyWith(items: items);
        mockParent.setShoppingState(
          personalLists: [listWithItems],
          lists: [listWithItems],
          activeListId: 'test-list-1',
        );

        // Act
        final text = operations.exportListAsText('test-list-1');

        // Assert
        expect(text, contains('📋 Veckohandling'));
        expect(text, contains('📝 Kvar att handla:'));
        expect(text, contains('☐'));
        expect(text, contains('✅ Inhandlat:'));
        expect(text, contains('☑'));
      });

      test('should export list as structured data', () {
        // Act
        final data = operations.exportListAsData('test-list-1');

        // Assert
        expect(data['format'], equals('personal_shopping_list'));
        expect(data['list'], isA<Map<String, dynamic>>());
        expect(data['list']['id'], equals('test-list-1'));
        expect(data['list']['name'], equals('Veckohandling'));
        expect(data['list']['items'], isA<List>());
        expect(data['statistics'], isA<Map<String, dynamic>>());
      });

      test('should return error for non-existent list in data export', () {
        // Act
        final data = operations.exportListAsData('non-existent');

        // Assert
        expect(data['error'], equals('Lista hittades inte'));
      });
    });

    group('Import Functionality', () {
      test('should import items from text', () async {
        // Arrange
        when(() => mockParent.updateList(any())).thenAnswer((_) async => true);

        const text = '''
        2 l Mjölk
        500 g Kaffe
        1 Bröd
        Smör
        ''';

        // Act
        final result = await operations.importItemsFromText(
          listId: 'test-list-1',
          text: text,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.updateList(any())).called(1);
      });

      test('should skip headers and separators when importing', () async {
        // Arrange
        when(() => mockParent.updateList(any())).thenAnswer((_) async => true);

        const text = '''
        📋 Shopping List
        ================
        📝 Items to buy:
        Mjölk
        Bröd
        ✅ Already bought:
        ☑ Smör
        ''';

        // Act
        final result = await operations.importItemsFromText(
          listId: 'test-list-1',
          text: text,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParent.updateList(any())).called(1);
      });

      test('should clear existing items when clearExisting is true', () async {
        // Arrange
        when(() => mockParent.updateList(any())).thenAnswer((_) async => true);

        const text = 'Nytt innehåll';

        // Act
        final result = await operations.importItemsFromText(
          listId: 'test-list-1',
          text: text,
          clearExisting: true,
        );

        // Assert
        expect(result, isTrue);

        final capturedList = verify(() => mockParent.updateList(captureAny()))
            .captured
            .single as UnifiedShoppingList;
        expect(capturedList.items, hasLength(1));
        expect(capturedList.items.first.name, equals('Nytt innehåll'));
      });

      test('should create list from recipe ingredients', () async {
        // Arrange
        when(() => mockParent.createPersonalList(
              any(),
              items: any(named: 'items'),
            )).thenAnswer((_) async => 'recipe-list-id');

        final ingredients = [
          '500 g köttfärs',
          '2 dl grädde',
          '1 gul lök',
          'salt och peppar',
        ];

        // Act
        final result = await operations.createListFromRecipe(
          recipeName: 'Köttbullar',
          ingredients: ingredients,
          servingMultiplier: 2.0,
        );

        // Assert
        expect(result, equals('recipe-list-id'));

        final capturedArgs = verify(() => mockParent.createPersonalList(
              captureAny(),
              items: captureAny(named: 'items'),
            )).captured;

        expect(capturedArgs[0], equals('Inköp för Köttbullar'));
        final items = capturedArgs[1] as List<UnifiedShoppingItem>;
        expect(items, hasLength(4));
        expect(items[0].amount, equals(1000.0)); // 500 * 2
        expect(items[0].unit, equals('g'));
      });

      test('should handle recipe creation error', () async {
        // Arrange
        when(() => mockParent.createPersonalList(
              any(),
              items: any(named: 'items'),
            )).thenThrow(Exception('Database error'));

        // Act
        final result = await operations.createListFromRecipe(
          recipeName: 'Test Recipe',
          ingredients: ['ingredient 1'],
        );

        // Assert
        expect(result, isNull);
      });
    });

    group('Edge Cases', () {
      test('should handle empty personal lists', () {
        // Arrange
        mockParent.setShoppingState(
          personalLists: [],
          lists: [],
          activeListId: 'test-list-1',
        );

        // Act
        final lists = operations.getAllLists();

        // Assert
        expect(lists, isEmpty);
      });

      test('should handle null active list', () {
        // Arrange
        mockParent.setShoppingState(
          activeListId: null,
          personalLists: mockParent.personalLists,
          lists: mockParent.lists,
        );

        // Act
        final activeList = operations.getActiveList();

        // Assert
        expect(activeList, isNull);
      });

      test('should handle list with no items', () {
        // Arrange
        final emptyList = testList.copyWith(items: []);
        mockParent.setShoppingState(
          personalLists: [emptyList],
          lists: [emptyList],
          activeListId: 'test-list-1',
        );

        // Act
        final stats = operations.getListStats('test-list-1');

        // Assert
        expect(stats['totalItems'], equals(0));
        expect(stats['completionPercentage'], equals(0));
        expect(stats['estimatedTotal'], equals(0.0));
      });

      test('should handle import with invalid list ID', () async {
        // Act
        final result = await operations.importItemsFromText(
          listId: 'non-existent',
          text: 'Some text',
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParent.updateList(any()));
      });

      test('should handle items with empty category', () {
        // Arrange
        final items = [
          UnifiedShoppingItem(
            id: 'item-1',
            name: 'Item 1',
            category: '',
            amount: 1,
            priority: 1,
            bought: false,
            addedAt: DateTime.now(),
          ),
          UnifiedShoppingItem(
            id: 'item-2',
            name: 'Item 2',
            category: 'Category',
            amount: 1,
            priority: 1,
            bought: false,
            addedAt: DateTime.now(),
          ),
        ];

        final listWithItems = testList.copyWith(items: items);
        mockParent.setShoppingState(
          personalLists: [listWithItems],
          lists: [listWithItems],
          activeListId: 'test-list-1',
        );

        // Act
        final categoryMap = operations.getItemsByCategory('test-list-1');

        // Assert
        expect(categoryMap['Övrigt'], hasLength(1));
        expect(categoryMap['Category'], hasLength(1));
      });
    });

    group('Advanced Item Operations', () {
      test('should handle batch item operations', () async {
        // Arrange
        when(() => mockParent.updateList(any())).thenAnswer((_) async => true);
        when(() => mockParent.setActiveList(any()))
            .thenAnswer((invocation) async {
          mockParent.setShoppingState(
            activeListId: invocation.positionalArguments[0] as String,
            personalLists: mockParent.personalLists,
            lists: mockParent.lists,
          );
          return true;
        });
        when(() => mockParent.addItemToActiveList(
              name: any(named: 'name'),
              amount: any(named: 'amount'),
              unit: any(named: 'unit'),
              category: any(named: 'category'),
              note: any(named: 'note'),
              estimatedPrice: any(named: 'estimatedPrice'),
              priority: any(named: 'priority'),
              recipeId: any(named: 'recipeId'),
              recipeName: any(named: 'recipeName'),
            )).thenAnswer((_) async => true);

        final itemsToAdd = [
          'Mjölk 2 liter',
          'Bröd 2 st',
          'Ägg 12 st',
          'Smör 500 g',
          'Ost 300 g',
        ];

        // Act
        final results = <bool>[];
        for (final itemText in itemsToAdd) {
          final result = await operations.addItem(
            listId: 'test-list-1',
            name: itemText.split(' ')[0],
            amount: double.tryParse(itemText.split(' ')[1]) ?? 1.0,
            unit: itemText.split(' ').length > 2 ? itemText.split(' ')[2] : '',
          );
          results.add(result);
        }

        // Assert
        expect(results, everyElement(isTrue));
        verify(() => mockParent.addItemToActiveList(
              name: any(named: 'name'),
              amount: any(named: 'amount'),
              unit: any(named: 'unit'),
              category: any(named: 'category'),
              note: any(named: 'note'),
              estimatedPrice: any(named: 'estimatedPrice'),
              priority: any(named: 'priority'),
              recipeId: any(named: 'recipeId'),
              recipeName: any(named: 'recipeName'),
            )).called(5);
      });

      test('should manage item priorities correctly', () async {
        // Arrange
        final prioritizedItems = List.generate(
          5,
          (i) => UnifiedShoppingItem(
            id: 'item-$i',
            name: 'Item $i',
            amount: 1.0,
            priority: 5 - i, // Descending priority
            bought: false,
            category: 'Test',
            addedAt: DateTime.now(),
          ),
        );

        final listWithPrioritizedItems =
            testList.copyWith(items: prioritizedItems);
        mockParent.setShoppingState(
          personalLists: [listWithPrioritizedItems],
          lists: [listWithPrioritizedItems],
          activeListId: 'test-list-1',
        );

        // Act
        final items = operations.getListById('test-list-1')?.items ?? [];
        final priorities = items.map((item) => item.priority).toList();

        // Assert
        expect(priorities, equals([5, 4, 3, 2, 1]));
        expect(items.first.priorityEmoji, equals('🔴')); // Highest priority
        expect(items.last.priorityEmoji, equals('⚪')); // Lowest priority
      });

      test('should handle item notes and metadata', () async {
        // Arrange
        when(() => mockParent.updateList(any())).thenAnswer((_) async => true);
        when(() => mockParent.setActiveList(any()))
            .thenAnswer((invocation) async {
          mockParent.setShoppingState(
            activeListId: invocation.positionalArguments[0] as String,
            personalLists: mockParent.personalLists,
            lists: mockParent.lists,
          );
          return true;
        });
        when(() => mockParent.addItemToActiveList(
              name: any(named: 'name'),
              amount: any(named: 'amount'),
              unit: any(named: 'unit'),
              category: any(named: 'category'),
              note: any(named: 'note'),
              estimatedPrice: any(named: 'estimatedPrice'),
              priority: any(named: 'priority'),
              recipeId: any(named: 'recipeId'),
              recipeName: any(named: 'recipeName'),
            )).thenAnswer((_) async => true);

        // Act
        final result = await operations.addItem(
          listId: 'test-list-1',
          name: 'Specialost',
          amount: 200.0,
          unit: 'g',
          category: 'Mejeri',
          note: 'Endast från Arla, helst lagrad 12 månader',
          estimatedPrice: 89.90,
          priority: 4,
        );

        // Assert
        expect(result, isTrue);

        // Verify the addItemToActiveList was called with correct parameters
        verify(() => mockParent.addItemToActiveList(
              name: 'Specialost',
              amount: 200.0,
              unit: 'g',
              category: 'Mejeri',
              note: 'Endast från Arla, helst lagrad 12 månader',
              estimatedPrice: 89.90,
              priority: 4,
              recipeId: any(named: 'recipeId'),
              recipeName: any(named: 'recipeName'),
            )).called(1);
      });
    });

    group('Swedish Language Support', () {
      test('should parse Swedish units correctly', () async {
        // Arrange
        when(() => mockParent.createPersonalList(
              any(),
              items: any(named: 'items'),
            )).thenAnswer((_) async => 'swedish-list');

        final swedishIngredients = [
          '2 msk smör',
          '3 tsk salt',
          '1 dl mjöl',
          '5 dl mjölk',
          '1 krm peppar',
          '2 förp bacon',
        ];

        // Act
        final result = await operations.createListFromRecipe(
          recipeName: 'Svenska Recept',
          ingredients: swedishIngredients,
        );

        // Assert
        expect(result, equals('swedish-list'));

        final capturedArgs = verify(() => mockParent.createPersonalList(
              captureAny(),
              items: captureAny(named: 'items'),
            )).captured;

        final items = capturedArgs[1] as List<UnifiedShoppingItem>;
        expect(items[0].unit, equals('msk'));
        expect(items[1].unit, equals('tsk'));
        expect(items[2].unit, equals('dl'));
        expect(items[3].unit, equals('dl'));
        expect(items[4].unit, equals('krm'));
        expect(items[5].unit, equals('förp'));
      });

      test('should handle Swedish category names and sorting', () {
        // Arrange
        final swedishItems = [
          UnifiedShoppingItem(
              id: '1',
              name: 'Mjölk',
              category: 'Mejeri',
              amount: 1.0,
              bought: false),
          UnifiedShoppingItem(
              id: '2',
              name: 'Bröd',
              category: 'Bageri',
              amount: 1.0,
              bought: false),
          UnifiedShoppingItem(
              id: '3',
              name: 'Äpplen',
              category: 'Frukt & Grönt',
              amount: 1.0,
              bought: false),
          UnifiedShoppingItem(
              id: '4',
              name: 'Kött',
              category: 'Kött & Fisk',
              amount: 1.0,
              bought: false),
          UnifiedShoppingItem(
              id: '5',
              name: 'Öl',
              category: 'Drycker',
              amount: 1.0,
              bought: false),
        ];

        final listWithSwedishItems = testList.copyWith(items: swedishItems);
        mockParent.setShoppingState(
          personalLists: [listWithSwedishItems],
          lists: [listWithSwedishItems],
          activeListId: 'test-list-1',
        );

        // Act
        final categoryMap = operations.getItemsByCategory('test-list-1');

        // Assert
        expect(
            categoryMap.keys,
            containsAll([
              'Mejeri',
              'Bageri',
              'Frukt & Grönt',
              'Kött & Fisk',
              'Drycker',
            ]));

        // Verify Swedish alphabetical sorting
        final sortedCategories = categoryMap.keys.toList()..sort();
        expect(sortedCategories.first, equals('Bageri'));
        expect(sortedCategories.last, equals('Mejeri'));
      });
    });

    group('Performance and Concurrency', () {
      test('should handle large lists efficiently', () {
        // Arrange
        final largeItemList = List.generate(
          150,
          (i) => UnifiedShoppingItem(
            id: 'item-$i',
            name: 'Product ${i + 1}',
            amount: (i % 5 + 1).toDouble(),
            unit: ['st', 'kg', 'l', 'g', 'dl'][i % 5],
            category: ['Mejeri', 'Bageri', 'Frukt', 'Kött', 'Övrigt'][i % 5],
            bought: i % 3 == 0,
            priority: (i % 5) + 1,
            addedAt: DateTime.now().subtract(Duration(days: i)),
            estimatedPrice: (i * 10.5),
          ),
        );

        final largeList = testList.copyWith(items: largeItemList);
        mockParent.setShoppingState(
          personalLists: [largeList],
          lists: [largeList],
          activeListId: 'test-list-1',
        );

        // Act
        final stopwatch = Stopwatch()..start();
        final stats = operations.getListStats('test-list-1');
        final categoryMap = operations.getItemsByCategory('test-list-1');
        final exportData = operations.exportListAsData('test-list-1');
        stopwatch.stop();

        // Assert
        expect(stats['totalItems'], equals(150));
        expect(stats['boughtItems'], equals(50)); // Every 3rd item is bought
        expect(categoryMap.keys.length, equals(5));
        expect(exportData, isNotNull);
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      });

      test('should handle concurrent item operations safely', () async {
        // Arrange
        when(() => mockParent.updateList(any())).thenAnswer((_) async {
          await Future.delayed(
              Duration(milliseconds: 10)); // Simulate async delay
          return true;
        });
        when(() => mockParent.setActiveList(any()))
            .thenAnswer((invocation) async {
          mockParent.setShoppingState(
            activeListId: invocation.positionalArguments[0] as String,
            personalLists: mockParent.personalLists,
            lists: mockParent.lists,
          );
          return true;
        });
        when(() => mockParent.addItemToActiveList(
              name: any(named: 'name'),
              amount: any(named: 'amount'),
              unit: any(named: 'unit'),
              category: any(named: 'category'),
              note: any(named: 'note'),
              estimatedPrice: any(named: 'estimatedPrice'),
              priority: any(named: 'priority'),
              recipeId: any(named: 'recipeId'),
              recipeName: any(named: 'recipeName'),
            )).thenAnswer((_) async => true);

        // Act
        final operations = PersonalShoppingOperations(
          getPersonalLists: () => mockParent.personalLists,
          getActiveList: () => mockParent.activeList,
          getActiveListId: () => mockParent.activeListId,
          createPersonalList: (name, {items}) =>
              mockParent.createPersonalList(name, items: items),
          renameList: (listId, newName) =>
              mockParent.renameList(listId, newName),
          deleteList: (listId) => mockParent.deleteList(listId),
          setActiveList: (listId) => mockParent.setActiveList(listId),
          addItemToActiveList: ({
            required String name,
            double? amount,
            String? unit,
            String? category,
            String? note,
            double? estimatedPrice,
            int? priority,
            String? recipeId,
            String? recipeName,
          }) =>
              mockParent.addItemToActiveList(
            name: name,
            amount: amount,
            unit: unit,
            category: category,
            note: note,
            estimatedPrice: estimatedPrice,
            priority: priority,
            recipeId: recipeId,
            recipeName: recipeName,
          ),
          updateList: (list) => mockParent.updateList(list),
          toggleItemBought: (itemId) => mockParent.toggleItemBought(itemId),
          removeItemFromActiveList: (itemId) =>
              mockParent.removeItemFromActiveList(itemId),
          clearBoughtItems: () => mockParent.clearBoughtItems(),
          uncheckAllItems: () => mockParent.uncheckAllItems(),
        );
        final futures = List.generate(
          10,
          (i) => operations.addItem(
            listId: 'test-list-1',
            name: 'Concurrent Item $i',
            amount: i.toDouble(),
            category: 'Test',
          ),
        );

        final results = await Future.wait(futures);

        // Assert
        expect(results, everyElement(isTrue));
        verify(() => mockParent.addItemToActiveList(
              name: any(named: 'name'),
              amount: any(named: 'amount'),
              unit: any(named: 'unit'),
              category: any(named: 'category'),
              note: any(named: 'note'),
              estimatedPrice: any(named: 'estimatedPrice'),
              priority: any(named: 'priority'),
              recipeId: any(named: 'recipeId'),
              recipeName: any(named: 'recipeName'),
            )).called(10);
      });
    });

    group('Template Operations', () {
      test('should create list from template', () async {
        // Arrange
        final templateItems = [
          UnifiedShoppingItem(
              id: '1',
              name: 'Mjölk',
              amount: 2.0,
              unit: 'l',
              category: 'Mejeri',
              bought: false),
          UnifiedShoppingItem(
              id: '2',
              name: 'Bröd',
              amount: 1.0,
              unit: 'st',
              category: 'Bageri',
              bought: false),
          UnifiedShoppingItem(
              id: '3',
              name: 'Ägg',
              amount: 12.0,
              unit: 'st',
              category: 'Mejeri',
              bought: false),
        ];

        when(() => mockParent.createPersonalList(
              any(),
              items: any(named: 'items'),
            )).thenAnswer((_) async => 'template-list-id');

        // Act - Simulate creating from template
        final result = await operations.createList(
          'Veckohandling från mall',
          items: templateItems,
        );

        // Assert
        expect(result, equals('template-list-id'));

        final capturedArgs = verify(() => mockParent.createPersonalList(
              captureAny(),
              items: captureAny(named: 'items'),
            )).captured;

        expect(capturedArgs[0], equals('Veckohandling från mall'));
        final items = capturedArgs[1] as List<UnifiedShoppingItem>;
        expect(items.length, equals(3));
        expect(items.every((item) => !item.bought),
            isTrue); // All items start unchecked
      });

      test('should save current list as template', () {
        // Arrange
        final currentItems = [
          UnifiedShoppingItem(
              id: '1',
              name: 'Standardvara 1',
              amount: 1.0,
              bought: true,
              category: 'Test'),
          UnifiedShoppingItem(
              id: '2',
              name: 'Standardvara 2',
              amount: 2.0,
              bought: false,
              category: 'Test'),
        ];

        final listToSave = testList.copyWith(items: currentItems);
        mockParent.setShoppingState(
          personalLists: [listToSave],
          lists: [listToSave],
          activeListId: 'test-list-1',
        );

        // Act - Export as template (without bought status)
        final templateData = operations.exportListAsData('test-list-1');

        // Assert
        expect(templateData, isNotNull);
        expect(templateData['list']['name'], equals('Veckohandling'));
        expect(templateData['list']['items'], isA<List>());

        final exportedItems = templateData['list']['items'] as List;
        expect(exportedItems.length, equals(2));

        // Template export includes bought status as-is
        expect(exportedItems[0]['bought'], isTrue); // First item was bought
        expect(
            exportedItems[1]['bought'], isFalse); // Second item wasn't bought
      });

      test('should apply template to existing list', () async {
        // Arrange
        final templateItems = [
          UnifiedShoppingItem(
              id: 'new-1',
              name: 'Mall Vara 1',
              amount: 1.0,
              category: 'Kategori 1',
              bought: false),
          UnifiedShoppingItem(
              id: 'new-2',
              name: 'Mall Vara 2',
              amount: 2.0,
              category: 'Kategori 2',
              bought: false),
        ];

        when(() => mockParent.updateList(any())).thenAnswer((_) async => true);

        // Act - Apply template (merge with existing)
        final itemTexts = templateItems
            .map((item) => '${item.name} ${item.amount} ${item.unit}'.trim())
            .join('\n');

        final result = await operations.importItemsFromText(
          listId: 'test-list-1',
          text: itemTexts,
          clearExisting: false, // Merge with existing
        );

        // Assert
        expect(result, isTrue);

        final capturedList = verify(() => mockParent.updateList(captureAny()))
            .captured
            .single as UnifiedShoppingList;
        expect(capturedList.items.length, greaterThan(testList.items.length));
      });
    });

    group('Advanced Analytics', () {
      test('should analyze historical buying patterns', () {
        // Arrange
        final now = DateTime.now();
        final historicalItems = [
          UnifiedShoppingItem(
            id: '1',
            name: 'Mjölk',
            amount: 2.0,
            unit: 'l',
            bought: true,
            category: 'Mejeri',
            purchasedAt: now.subtract(Duration(days: 7)),
          ),
          UnifiedShoppingItem(
            id: '2',
            name: 'Mjölk',
            amount: 2.0,
            unit: 'l',
            bought: true,
            category: 'Mejeri',
            purchasedAt: now.subtract(Duration(days: 14)),
          ),
          UnifiedShoppingItem(
            id: '3',
            name: 'Mjölk',
            amount: 2.0,
            unit: 'l',
            bought: true,
            category: 'Mejeri',
            purchasedAt: now.subtract(Duration(days: 21)),
          ),
        ];

        final listWithHistory = testList.copyWith(items: historicalItems);
        mockParent.setShoppingState(
          personalLists: [listWithHistory],
          lists: [listWithHistory],
          activeListId: 'test-list-1',
        );

        // Act
        final stats = operations.getListStats('test-list-1');

        // Assert
        expect(stats['totalItems'], equals(3));
        expect(stats['boughtItems'], equals(3));
        expect(stats['completionPercentage'], equals(100));

        // All milk purchases are weekly
        final milkItems =
            historicalItems.where((item) => item.name == 'Mjölk').toList();
        expect(milkItems.length, equals(3));
      });

      test('should identify frequent items', () {
        // Arrange
        final frequentItems = [
          UnifiedShoppingItem(
              id: '1',
              name: 'Mjölk',
              amount: 2.0,
              bought: true,
              category: 'Mejeri'),
          UnifiedShoppingItem(
              id: '2',
              name: 'Bröd',
              amount: 1.0,
              bought: true,
              category: 'Bageri'),
          UnifiedShoppingItem(
              id: '3',
              name: 'Mjölk',
              amount: 2.0,
              bought: false,
              category: 'Mejeri'),
          UnifiedShoppingItem(
              id: '4',
              name: 'Ägg',
              amount: 12.0,
              bought: true,
              category: 'Mejeri'),
          UnifiedShoppingItem(
              id: '5',
              name: 'Mjölk',
              amount: 2.0,
              bought: true,
              category: 'Mejeri'),
          UnifiedShoppingItem(
              id: '6',
              name: 'Bröd',
              amount: 1.0,
              bought: false,
              category: 'Bageri'),
        ];

        final listWithFrequent = testList.copyWith(items: frequentItems);
        mockParent.setShoppingState(
          personalLists: [listWithFrequent],
          lists: [listWithFrequent],
          activeListId: 'test-list-1',
        );

        // Act
        final categoryMap = operations.getItemsByCategory('test-list-1');

        // Assert
        final mejeriItems = categoryMap['Mejeri'] ?? [];
        final breadItems = categoryMap['Bageri'] ?? [];

        // Mjölk appears 3 times
        expect(mejeriItems.where((item) => item.name == 'Mjölk').length,
            equals(3));
        // Bröd appears 2 times
        expect(
            breadItems.where((item) => item.name == 'Bröd').length, equals(2));
      });

      test('should calculate cost estimation and budget tracking', () {
        // Arrange
        final pricedItems = [
          UnifiedShoppingItem(
            id: '1',
            name: 'Mjölk',
            amount: 2.0,
            unit: 'l',
            estimatedPrice: 25.90,
            bought: false,
            category: 'Mejeri',
          ),
          UnifiedShoppingItem(
            id: '2',
            name: 'Bröd',
            amount: 1.0,
            unit: 'st',
            estimatedPrice: 32.50,
            bought: false,
            category: 'Bageri',
          ),
          UnifiedShoppingItem(
            id: '3',
            name: 'Ägg',
            amount: 12.0,
            unit: 'st',
            estimatedPrice: 45.90,
            bought: true,
            category: 'Mejeri',
          ),
          UnifiedShoppingItem(
            id: '4',
            name: 'Ost',
            amount: 500.0,
            unit: 'g',
            estimatedPrice: 89.90,
            bought: false,
            category: 'Mejeri',
          ),
        ];

        final listWithPrices = testList.copyWith(items: pricedItems);
        mockParent.setShoppingState(
          personalLists: [listWithPrices],
          lists: [listWithPrices],
          activeListId: 'test-list-1',
        );

        // Act
        final stats = operations.getListStats('test-list-1');

        // Assert
        expect(stats['totalItems'], equals(4));
        expect(stats['boughtItems'], equals(1));

        // Calculate estimated total (price * amount for each item)
        final estimatedTotal = pricedItems
            .map((item) => (item.estimatedPrice ?? 0.0) * item.amount)
            .reduce((a, b) => a + b);
        expect(stats['estimatedTotal'], closeTo(estimatedTotal, 0.01));

        // Calculate remaining budget (unbought items)
        final remainingBudget = pricedItems
            .where((item) => !item.bought)
            .map((item) => (item.estimatedPrice ?? 0.0) * item.amount)
            .reduce((a, b) => a + b);
        expect(remainingBudget, closeTo(51.80 + 32.50 + 44950.00, 0.01));
      });
    });
  });
}
