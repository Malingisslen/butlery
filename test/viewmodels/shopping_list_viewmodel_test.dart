// test/viewmodels/shopping_list_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:butlery/models/shopping_item.dart';
import 'package:butlery/models/shopping_list.dart';

// Import generated mocks
import '../helpers/test_helpers.mocks.dart';

void main() {
  late ShoppingListViewModel viewModel;
  late MockMultiShoppingListService mockService;
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockService = MockMultiShoppingListService();
    mockPrefs = MockSharedPreferences();

    // Default stubs
    when(mockService.lists).thenReturn([]);
    when(mockService.activeList).thenReturn(null);
    when(mockService.activeListId).thenReturn(null);
    when(mockService.isSyncing).thenReturn(false);
    when(mockService.error).thenReturn(null);
    when(mockService.initialize()).thenAnswer((_) async {});
    when(mockPrefs.getString(any)).thenReturn(null);

    viewModel = ShoppingListViewModel(
      service: mockService,
      prefs: mockPrefs,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('ShoppingListViewModel - Initialization', () {
    test('should initialize with empty state', () {
      expect(viewModel.lists, isEmpty);
      expect(viewModel.activeList, isNull);
      expect(viewModel.shoppingItems, isEmpty);
      expect(viewModel.hasLists, isFalse);
      expect(viewModel.hasItems, isFalse);
    });

    test('should load last selected list from preferences', () async {
      // Arrange
      const lastListId = 'last-list-id';
      when(mockPrefs.getString('last_selected_list')).thenReturn(lastListId);

      // Act
      viewModel = ShoppingListViewModel(
        service: mockService,
        prefs: mockPrefs,
      );
      await Future.delayed(Duration.zero); // Let initialization complete

      // Assert
      verify(mockPrefs.getString('last_selected_list')).called(1);
    });

    test('should handle initialization errors gracefully', () async {
      // Arrange
      when(mockService.initialize()).thenThrow(Exception('Init failed'));

      // Act
      viewModel = ShoppingListViewModel(
        service: mockService,
        prefs: mockPrefs,
      );
      await Future.delayed(Duration.zero);

      // Assert
      expect(viewModel.error, contains('Init failed'));
      expect(viewModel.isLoading, isFalse);
    })
  });

  group('ShoppingListViewModel - List Management', () {
    test('should select list and save to preferences', () async {
      // Arrange
      const listId = 'test-list-id';
      final testList = ShoppingList(
        id: listId,
        name: 'Test List',
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id', // Lägg till denna
      );

      when(mockService.setActiveList(listId)).thenAnswer((_) async {});
      when(mockService.activeList).thenReturn(testList);
      when(mockService.lists).thenReturn([testList]);
      when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

      // Act
      await viewModel.selectList(listId);

      // Assert
      verify(mockService.setActiveList(listId)).called(1);
      verify(mockPrefs.setString('last_selected_list', listId)).called(1);
      expect(viewModel.isChangingList, isFalse);
    });

    test('should create new list', () async {
      // Arrange
      const listName = 'New List';
      final newList = ShoppingList(
        id: 'new-list-id',
        name: listName,
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id', // Lägg till denna
      );

      when(mockService.createList(listName)).thenAnswer((_) async => newList);

      // Act
      final result = await viewModel.createList(listName);

      // Assert
      expect(result, isTrue);
      verify(mockService.createList(listName)).called(1);
      expect(viewModel.isCreatingList, isFalse);
    });

    test('should validate empty list name', () async {
      // Act
      final result = await viewModel.createList('  ');

      // Assert
      expect(result, isFalse);
      expect(viewModel.error, contains('tomt'));
      verifyNever(mockService.createList(any));
    });

    test('should rename list', () async {
      // Arrange
      const listId = 'test-list-id';
      const newName = 'Renamed List';

      when(mockService.renameList(listId, newName))
          .thenAnswer((_) async => true);

      // Act
      final result = await viewModel.renameList(listId, newName);

      // Assert
      expect(result, isTrue);
      verify(mockService.renameList(listId, newName)).called(1);
    });

    test('should delete list and update selection', () async {
      // Arrange
      const listId = 'test-list-id';
      const newActiveId = 'new-active-id';

      when(mockService.deleteList(listId)).thenAnswer((_) async => true);
      when(mockService.activeListId).thenReturn(newActiveId);

      // Act
      final result = await viewModel.deleteList(listId);

      // Assert
      expect(result, isTrue);
      verify(mockService.deleteList(listId)).called(1);
    });
  });

  group('ShoppingListViewModel - Item Management', () {
    late ShoppingList activeList;
    late List<ShoppingItem> items;

    setUp(() {
      items = [
        ShoppingItem(
          name: 'Mjölk',
          amount: 1,
          unit: 'l',
          category: 'Mejeri',
          bought: false,
        ),
        ShoppingItem(
          name: 'Bröd',
          amount: 2,
          unit: 'st',
          category: 'Bageri',
          bought: true,
        ),
      ];

      activeList = ShoppingList(
        id: 'active-list',
        name: 'Test List',
        items: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockService.activeList).thenReturn(activeList);
      when(mockService.lists).thenReturn([activeList]);

      // Trigger cache update
      viewModel.notifyListeners();
    });

    test('should add item optimistically', () async {
      // Arrange
      final newItem = ShoppingItem(
        name: 'Ägg',
        amount: 12,
        unit: 'st',
        category: 'Mejeri',
      );

      when(mockService.addItemToActiveList(newItem))
          .thenAnswer((_) async => true);

      // Act
      final initialCount = viewModel.totalCount;
      final result = await viewModel.addItem(newItem);

      // Assert
      expect(result, isTrue);
      expect(viewModel.totalCount, equals(initialCount + 1));
      verify(mockService.addItemToActiveList(newItem)).called(1);
    });

    test('should toggle item bought status', () async {
      // Arrange
      when(mockService.toggleItemBought(0)).thenAnswer((_) async {});

      // Act
      final initialBoughtStatus = viewModel.shoppingItems[0].bought;
      await viewModel.toggleItem(0);

      // Assert
      expect(viewModel.shoppingItems[0].bought, equals(!initialBoughtStatus));
      verify(mockService.toggleItemBought(0)).called(1);
    });

    test('should remove item with undo support', () async {
      // Arrange
      when(mockService.removeItemFromActiveList(0))
          .thenAnswer((_) async => true);

      // Act
      final removedItem = viewModel.shoppingItems[0];
      final initialCount = viewModel.totalCount;
      final result = await viewModel.removeItem(0);

      // Assert
      expect(result, isTrue);
      expect(viewModel.totalCount, equals(initialCount - 1));

      // Test undo
      await viewModel.undoRemove();
      expect(viewModel.totalCount, equals(initialCount));
      expect(viewModel.shoppingItems.contains(removedItem), isTrue);
    });

    test('should clear checked items', () async {
      // Arrange
      when(mockService.clearBoughtItems()).thenAnswer((_) async {});

      // Act
      final initialCheckedCount = viewModel.checkedCount;
      await viewModel.clearCheckedItems();

      // Assert
      expect(viewModel.checkedCount, lessThan(initialCheckedCount));
      verify(mockService.clearBoughtItems()).called(1);
    });

    test('should handle invalid index gracefully', () async {
      // Act
      await viewModel.toggleItem(999);
      await viewModel.removeItem(-1);

      // Assert
      verifyNever(mockService.toggleItemBought(any));
      verifyNever(mockService.removeItemFromActiveList(any));
    });
  });

  group('ShoppingListViewModel - Computed Properties', () {
    test('should correctly compute unbought and bought items', () {
      // Arrange
      final items = [
        ShoppingItem(name: 'Item 1', amount: 1, bought: false),
        ShoppingItem(name: 'Item 2', amount: 1, bought: true),
        ShoppingItem(name: 'Item 3', amount: 1, bought: false),
      ];

      final list = ShoppingList(
        id: 'test',
        name: 'Test',
        items: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockService.activeList).thenReturn(list);
      viewModel.notifyListeners();

      // Assert
      expect(viewModel.unboughtItems.length, equals(2));
      expect(viewModel.boughtItems.length, equals(1));
      expect(viewModel.checkedCount, equals(1));
      expect(viewModel.uncheckedCount, equals(2));
    });

    test('should format items correctly', () {
      // Arrange
      final items = [
        ShoppingItem(name: 'Mjölk', amount: 1.5, unit: 'l'),
        ShoppingItem(name: 'Ägg', amount: 12, unit: 'st'),
        ShoppingItem(name: 'Salt', amount: 1, unit: ''),
      ];

      final list = ShoppingList(
        id: 'test',
        name: 'Test',
        items: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockService.activeList).thenReturn(list);
      viewModel.notifyListeners();

      // Assert
      expect(viewModel.formattedItems[0], equals('1,5 l Mjölk'));
      expect(viewModel.formattedItems[1], equals('12 st Ägg'));
      expect(viewModel.formattedItems[2], equals('1 Salt'));
    });

    test('should find original index correctly', () {
      // Arrange
      final items = [
        ShoppingItem(name: 'Item 1', amount: 1, bought: false),
        ShoppingItem(name: 'Item 2', amount: 1, bought: true),
        ShoppingItem(name: 'Item 3', amount: 1, bought: false),
      ];

      final list = ShoppingList(
        id: 'test',
        name: 'Test',
        items: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockService.activeList).thenReturn(list);
      viewModel.notifyListeners();

      // Act
      final boughtItem = viewModel.boughtItems.first;
      final originalIndex = viewModel.getOriginalIndex(boughtItem);

      // Assert
      expect(originalIndex, equals(1));
      expect(viewModel.shoppingItems[originalIndex], equals(boughtItem));
    });
  });

  group('ShoppingListViewModel - Sync Operations', () {
    test('should force sync', () async {
      // Arrange
      when(mockService.syncAllLists()).thenAnswer((_) async {});

      // Act
      await viewModel.forceSync();

      // Assert
      verify(mockService.syncAllLists()).called(1);
      expect(viewModel.isSyncing, isFalse);
    });

    test('should refresh with loading state', () async {
      // Arrange
      when(mockService.refresh()).thenAnswer((_) async {});

      bool wasSyncing = false;
      viewModel.addListener(() {
        if (viewModel.isSyncing) wasSyncing = true;
      });

      // Act
      await viewModel.refresh();

      // Assert
      expect(wasSyncing, isTrue);
      expect(viewModel.isSyncing, isFalse);
      verify(mockService.refresh()).called(1);
    });

    test('should handle sync errors', () async {
      // Arrange
      when(mockService.syncAllLists()).thenThrow(Exception('Sync failed'));

      // Act
      await viewModel.forceSync();

      // Assert
      expect(viewModel.lastError, contains('Sync failed'));
      expect(viewModel.isSyncing, isFalse);
    });
  });

  group('ShoppingListViewModel - Export', () {
    test('should export list as formatted text', () {
      // Arrange
      final items = [
        ShoppingItem(
          name: 'Mjölk',
          amount: 1,
          unit: 'l',
          category: 'Mejeri',
          bought: false,
        ),
        ShoppingItem(
          name: 'Ost',
          amount: 200,
          unit: 'g',
          category: 'Mejeri',
          bought: true,
        ),
        ShoppingItem(
          name: 'Bröd',
          amount: 1,
          unit: 'st',
          category: 'Bageri',
          bought: false,
        ),
      ];

      final list = ShoppingList(
        id: 'test',
        name: 'Veckans inköp',
        items: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockService.activeList).thenReturn(list);
      viewModel.notifyListeners();

      // Act
      final exported = viewModel.exportAsText();

      // Assert
      expect(exported, contains('🛒 Veckans inköp'));
      expect(exported, contains('Mejeri:'));
      expect(exported, contains('☐ 1 l Mjölk'));
      expect(exported, contains('✓ 200 g Ost'));
      expect(exported, contains('Bageri:'));
      expect(exported, contains('☐ 1 st Bröd'));
    });

    test('should return empty string if no active list', () {
      // Arrange
      when(mockService.activeList).thenReturn(null);

      // Act
      final exported = viewModel.exportAsText();

      // Assert
      expect(exported, isEmpty);
    });
  });

  group('ShoppingListViewModel - Error Handling', () {
    test('should clear errors', () {
      // Arrange
      viewModel.clearError();
      when(mockService.clearError()).thenReturn(null);

      // Act
      viewModel.clearError();

      // Assert
      expect(viewModel.error, isNull);
      expect(viewModel.lastError, isNull);
      verify(mockService.clearError()).called(1);
    });

    test('should handle service listener updates', () {
      // Arrange
      int notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      // Act - Simulate service change
      // This would normally be triggered by the service
      viewModel.notifyListeners();

      // Assert
      expect(notifyCount, greaterThan(0));
    });
  });

  group('ShoppingListViewModel - Cache Management', () {
    test('should invalidate cache when items change', () async {
      // Arrange
      final items = [
        ShoppingItem(name: 'Item 1', amount: 1, bought: false),
        ShoppingItem(name: 'Item 2', amount: 1, bought: false),
      ];

      final list = ShoppingList(
        id: 'test',
        name: 'Test',
        items: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockService.activeList).thenReturn(list);
      when(mockService.addItemToActiveList(any)).thenAnswer((_) async => true);
      viewModel.notifyListeners();

      // Act - Access cache to populate it
      final unboughtBefore = viewModel.unboughtItems;
      expect(unboughtBefore.length, equals(2));

      // Add new item
      final newItem = ShoppingItem(name: 'Item 3', amount: 1);
      await viewModel.addItem(newItem);

      // Assert - Cache should be invalidated and repopulated
      final unboughtAfter = viewModel.unboughtItems;
      expect(unboughtAfter.length, equals(3));
    });
  });
}
