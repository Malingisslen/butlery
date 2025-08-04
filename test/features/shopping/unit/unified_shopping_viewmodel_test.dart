import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:get_it/get_it.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockUnifiedShoppingService extends Mock
    implements UnifiedShoppingService {}

class MockPermissionService extends Mock implements PermissionService {}

void main() {
  late UnifiedShoppingViewModel sut;
  late MockUnifiedShoppingService mockShoppingService;
  late MockPermissionService mockPermissionService;
  late GetIt sl;

  setUpAll(() {
    registerFallbackValue(UnifiedShoppingListFactory.empty());
    registerFallbackValue(UnifiedShoppingItemFactory.empty());
  });

  setUp(() {
    // Set up service locator
    sl = GetIt.instance;
    if (sl.isRegistered<UnifiedShoppingService>()) {
      sl.unregister<UnifiedShoppingService>();
    }
    if (sl.isRegistered<PermissionService>()) {
      sl.unregister<PermissionService>();
    }

    mockShoppingService = MockUnifiedShoppingService();
    mockPermissionService = MockPermissionService();

    sl.registerSingleton<UnifiedShoppingService>(mockShoppingService);
    sl.registerSingleton<PermissionService>(mockPermissionService);

    // Setup default mocks for UnifiedShoppingService
    when(() => mockShoppingService.lists).thenReturn([]);
    when(() => mockShoppingService.personalLists).thenReturn([]);
    when(() => mockShoppingService.collaborativeLists).thenReturn([]);
    when(() => mockShoppingService.activeList).thenReturn(null);
    when(() => mockShoppingService.isLoading).thenReturn(false);
    when(() => mockShoppingService.isSyncing).thenReturn(false);
    when(() => mockShoppingService.isInitialized).thenReturn(false);
    when(() => mockShoppingService.error).thenReturn(null);
    when(() => mockShoppingService.hasError).thenReturn(false);
    when(() => mockShoppingService.hasLists).thenReturn(false);
    when(() => mockShoppingService.currentUserDisplayName).thenReturn('Test User');

    // Setup default permission service
    when(() => mockPermissionService.currentUserId).thenReturn('current_user');

    // Setup listener mock
    when(() => mockShoppingService.addListener(any())).thenReturn(null);
    when(() => mockShoppingService.removeListener(any())).thenReturn(null);

    sut = UnifiedShoppingViewModel();
  });

  tearDown(() {
    sut.dispose();
    sl.unregister<UnifiedShoppingService>();
    sl.unregister<PermissionService>();
  });

  group('UnifiedShoppingViewModel - Initialization', () {
    test('should initialize with empty state', () {
      expect(sut.lists, isEmpty);
      expect(sut.activeList, isNull);
      expect(sut.isLoading, isFalse);
      expect(sut.error, isNull);
    });

    test('should initialize shopping service', () async {
      // Given
      when(() => mockShoppingService.initialize()).thenAnswer((_) async {});
      when(() => mockShoppingService.hasLists).thenReturn(true);

      // When
      await sut.initialize();

      // Then
      verify(() => mockShoppingService.initialize()).called(1);
    });

    test('should create default list for new users', () async {
      // Given
      when(() => mockShoppingService.initialize()).thenAnswer((_) async {});
      when(() => mockShoppingService.hasLists).thenReturn(false);
      when(() => mockShoppingService.createPersonalList(any()))
          .thenAnswer((_) async => 'new_list_id');

      // When
      await sut.initialize();

      // Then
      verify(() => mockShoppingService.createPersonalList('Min Inköpslista'))
          .called(1);
    });
  });

  group('UnifiedShoppingViewModel - List Management', () {
    test('should create personal list', () async {
      // Given
      const name = 'Ny lista';
      when(() => mockShoppingService.createPersonalList(any()))
          .thenAnswer((_) async => 'new_list_id');

      // When
      final result = await sut.createPersonalList(name);

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.createPersonalList(name)).called(1);
    });

    test('should not create personal list with empty name', () async {
      // When
      final result = await sut.createPersonalList('  ');

      // Then
      expect(result, isFalse);
      verifyNever(() => mockShoppingService.createPersonalList(any()));
    });

    test('should create collaborative list', () async {
      // Given
      const name = 'Familjelista';
      final memberIds = ['user1', 'user2'];
      final memberDisplayNames = {'user1': 'User 1', 'user2': 'User 2'};

      when(() => mockShoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
            allowGuestEditing: any(named: 'allowGuestEditing'),
            autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
          )).thenAnswer((_) async => 'collab_list_id');

      // When
      final result = await sut.createCollaborativeList(
        name: name,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
      );

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.createCollaborativeList(
            name: name,
            description: null,
            memberIds: memberIds,
            memberDisplayNames: memberDisplayNames,
            items: null,
            categoryIds: null,
            allowGuestEditing: true,
            autoRemoveCompleted: false,
          )).called(1);
    });

    test('should rename active list', () async {
      // Given
      final activeList = UnifiedShoppingListFactory.build(
        id: 'list1',
        name: 'Old Name',
      );
      when(() => mockShoppingService.activeList).thenReturn(activeList);
      when(() => mockShoppingService.renameList(any(), any()))
          .thenAnswer((_) async => true);

      // When
      final result = await sut.renameActiveList('New Name');

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.renameList('list1', 'New Name'))
          .called(1);
    });

    test('should delete active list', () async {
      // Given
      final activeList = UnifiedShoppingListFactory.build(id: 'list1');
      when(() => mockShoppingService.activeList).thenReturn(activeList);
      when(() => mockShoppingService.deleteList(any()))
          .thenAnswer((_) async => true);

      // When
      final result = await sut.deleteActiveList();

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.deleteList('list1')).called(1);
    });

    test('should set active list', () async {
      // Given
      const listId = 'list1';
      when(() => mockShoppingService.setActiveList(any()))
          .thenAnswer((_) async => true);

      // When
      final result = await sut.setActiveList(listId);

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.setActiveList(listId)).called(1);
    });
  });

  group('UnifiedShoppingViewModel - Item Management', () {
    test('should add item to active list', () async {
      // Given
      final activeList = UnifiedShoppingListFactory.build(id: 'list1');
      when(() => mockShoppingService.activeList).thenReturn(activeList);
      when(() => mockShoppingService.addItemToActiveList(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
            note: any(named: 'note'),
            estimatedPrice: any(named: 'estimatedPrice'),
            priority: any(named: 'priority'),
          )).thenAnswer((_) async => true);

      // When
      final result = await sut.addItem(
        name: 'Mjölk',
        amount: 1.0,
        unit: 'liter',
      );

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.addItemToActiveList(
            name: 'Mjölk',
            amount: 1.0,
            unit: 'liter',
            category: 'Övrigt',
            note: null,
            estimatedPrice: null,
            priority: 3,
          )).called(1);
    });

    test('should not add item with empty name', () async {
      // When
      final result = await sut.addItem(
        name: '   ',
        amount: 1.0,
      );

      // Then
      expect(result, isFalse);
      verifyNever(() => mockShoppingService.addItemToActiveList(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
            note: any(named: 'note'),
            estimatedPrice: any(named: 'estimatedPrice'),
            priority: any(named: 'priority'),
          ));
    });

    test('should toggle item bought status', () async {
      // Given
      const itemId = 'item1';
      when(() => mockShoppingService.toggleItemBought(any()))
          .thenAnswer((_) async => true);

      // When
      final result = await sut.toggleItemBought(itemId);

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.toggleItemBought(itemId)).called(1);
    });

    test('should remove item', () async {
      // Given
      const itemId = 'item1';
      when(() => mockShoppingService.removeItemFromActiveList(any()))
          .thenAnswer((_) async => true);

      // When
      final result = await sut.removeItem(itemId);

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.removeItemFromActiveList(itemId))
          .called(1);
    });

    test('should update item', () async {
      // Given
      when(() => mockShoppingService.updateItemInActiveList(
            itemId: any(named: 'itemId'),
            name: any(named: 'name'),
            quantity: any(named: 'quantity'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
            notes: any(named: 'notes'),
            estimatedPrice: any(named: 'estimatedPrice'),
            priority: any(named: 'priority'),
          )).thenAnswer((_) async => true);

      // When
      final result = await sut.updateItem(
        itemId: 'item1',
        name: 'Updated Item',
        quantity: 2.0,
      );

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.updateItemInActiveList(
            itemId: 'item1',
            name: 'Updated Item',
            quantity: 2.0,
            unit: null,
            category: null,
            notes: null,
            estimatedPrice: null,
            priority: null,
          )).called(1);
    });

    test('should clear bought items', () async {
      // Given
      when(() => mockShoppingService.clearBoughtItems())
          .thenAnswer((_) async => true);

      // When
      final result = await sut.clearBoughtItems();

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.clearBoughtItems()).called(1);
    });

    test('should uncheck all items', () async {
      // Given
      when(() => mockShoppingService.uncheckAllItems())
          .thenAnswer((_) async => true);

      // When
      final result = await sut.uncheckAllItems();

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.uncheckAllItems()).called(1);
    });
  });

  group('UnifiedShoppingViewModel - Recipe Integration', () {
    test('should add items from recipe', () async {
      // Given
      final ingredientData = [
        {'name': 'Mjöl', 'amount': 500.0, 'unit': 'g'},
        {'name': 'Ägg', 'amount': 3.0, 'unit': 'st'},
      ];

      when(() => mockShoppingService.addItemToActiveList(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
            note: any(named: 'note'),
            estimatedPrice: any(named: 'estimatedPrice'),
            priority: any(named: 'priority'),
          )).thenAnswer((_) async => true);

      // When
      final result = await sut.addItemsFromRecipe(ingredientData);

      // Then
      expect(result, isTrue);
      verify(() => mockShoppingService.addItemToActiveList(
            name: 'Mjöl',
            amount: 500.0,
            unit: 'g',
            category: 'Övrigt',
            note: null,
            estimatedPrice: null,
            priority: 3,
          )).called(1);
      verify(() => mockShoppingService.addItemToActiveList(
            name: 'Ägg',
            amount: 3.0,
            unit: 'st',
            category: 'Övrigt',
            note: null,
            estimatedPrice: null,
            priority: 3,
          )).called(1);
    });
  });

  group('UnifiedShoppingViewModel - Grouping and Search', () {
    test('should group items by category', () {
      // Given
      final items = [
        UnifiedShoppingItemFactory.build(
            category: 'Mejeri', name: 'Mjölk', bought: false),
        UnifiedShoppingItemFactory.build(
            category: 'Frukt', name: 'Äpple', bought: false),
        UnifiedShoppingItemFactory.build(
            category: 'Mejeri', name: 'Ost', bought: true),
      ];
      final activeList = UnifiedShoppingListFactory.build(items: items);
      when(() => mockShoppingService.activeList).thenReturn(activeList);

      // When
      final grouped = sut.itemsByCategory;

      // Then
      expect(grouped.keys.length, equals(2));
      expect(grouped['Mejeri']!.length, equals(2));
      expect(grouped['Frukt']!.length, equals(1));
      // Check that unbought items are first
      expect(grouped['Mejeri']!.first.name, equals('Mjölk'));
    });

    test('should get used categories', () {
      // Given
      final items = [
        UnifiedShoppingItemFactory.build(category: 'Mejeri'),
        UnifiedShoppingItemFactory.build(category: 'Frukt'),
        UnifiedShoppingItemFactory.build(category: 'Mejeri'),
      ];
      final activeList = UnifiedShoppingListFactory.build(items: items);
      when(() => mockShoppingService.activeList).thenReturn(activeList);

      // When
      final categories = sut.usedCategories;

      // Then
      expect(categories.length, equals(2));
      expect(categories, contains('Mejeri'));
      expect(categories, contains('Frukt'));
      expect(categories.first, equals('Frukt')); // Alphabetically sorted
    });

    test('should search items', () {
      // Given
      final items = [
        UnifiedShoppingItemFactory.build(name: 'Mjölk', category: 'Mejeri'),
        UnifiedShoppingItemFactory.build(
            name: 'Havremjölk', category: 'Mejeri'),
        UnifiedShoppingItemFactory.build(name: 'Ost', category: 'Mejeri'),
      ];
      final activeList = UnifiedShoppingListFactory.build(items: items);
      when(() => mockShoppingService.activeList).thenReturn(activeList);

      // When
      final searchResults = sut.searchItems('mjölk');

      // Then
      expect(searchResults.length, equals(2));
      expect(searchResults[0].name, equals('Mjölk'));
      expect(searchResults[1].name, equals('Havremjölk'));
    });
  });

  group('UnifiedShoppingViewModel - Permissions', () {
    test('should check if user can edit active list', () {
      // Given
      final activeList = UnifiedShoppingListFactory.build(id: 'list1');
      when(() => mockShoppingService.activeList).thenReturn(activeList);
      when(() => mockPermissionService.canEditShoppingList(any()))
          .thenReturn(true);

      // When
      final canEdit = sut.canEditActiveList;

      // Then
      expect(canEdit, isTrue);
      verify(() => mockPermissionService.canEditShoppingList('list1'))
          .called(1);
    });

    test('should check if user can manage active list', () {
      // Given
      final activeList = UnifiedShoppingListFactory.build(id: 'list1');
      when(() => mockShoppingService.activeList).thenReturn(activeList);
      when(() => mockPermissionService.canManageShoppingList(any()))
          .thenReturn(true);

      // When
      final canManage = sut.canManageActiveList;

      // Then
      expect(canManage, isTrue);
      verify(() => mockPermissionService.canManageShoppingList('list1'))
          .called(1);
    });
  });

  group('UnifiedShoppingViewModel - Statistics', () {
    test('should calculate shopping insights', () {
      // Given
      final items = [
        UnifiedShoppingItemFactory.build(bought: true),
        UnifiedShoppingItemFactory.build(bought: true),
        UnifiedShoppingItemFactory.build(bought: false),
        UnifiedShoppingItemFactory.build(bought: false),
      ];
      final activeList = UnifiedShoppingListFactory.build(
        items: items,
        memberPermissions: {
          'user1': SharedListPermission.admin,
          'user2': SharedListPermission.edit,
          'user3': SharedListPermission.view,
        },
      );
      when(() => mockShoppingService.activeList).thenReturn(activeList);

      // When
      final insights = sut.shoppingInsights;

      // Then
      expect(insights['totalItems'], equals(4));
      expect(insights['boughtItems'], equals(2));
      expect(insights['completionPercentage'], equals(50.0));
      expect(insights['isCollaborative'], isTrue);
      expect(insights['memberCount'], equals(3));
      expect(insights['priorityItems'], equals(2)); // priority > 3
    });
  });

  group('UnifiedShoppingViewModel - Export', () {
    test('should export list as text', () {
      // Given
      when(() => mockShoppingService.exportListAsText())
          .thenReturn('Shopping List Export');

      // When
      final exported = sut.exportListAsText();

      // Then
      expect(exported, equals('Shopping List Export'));
      verify(() => mockShoppingService.exportListAsText()).called(1);
    });

    test('should export list with categories', () {
      // Given
      final items = [
        UnifiedShoppingItemFactory.build(
          name: 'Mjölk',
          amount: 1.0,
          unit: 'l',
          category: 'Mejeri',
          bought: false,
        ),
        UnifiedShoppingItemFactory.build(
          name: 'Ost',
          amount: 200.0,
          unit: 'g',
          category: 'Mejeri',
          bought: true,
        ),
      ];
      final activeList = UnifiedShoppingListFactory.build(
        name: 'Veckohandling',
        items: items,
      );
      when(() => mockShoppingService.activeList).thenReturn(activeList);

      // When
      final exported = sut.exportListAsTextWithCategories();

      // Then
      expect(exported, contains('📝 Veckohandling'));
      expect(exported, contains('🏷️ Mejeri:'));
      expect(exported, contains('⬜ 1.0 l Mjölk'));
      expect(exported, contains('✅ 200.0 g Ost'));
    });
  });

  group('UnifiedShoppingViewModel - Error Handling', () {
    test('should clear error', () {
      // Given
      when(() => mockShoppingService.clearError()).thenReturn(null);

      // When
      sut.clearError();

      // Then
      verify(() => mockShoppingService.clearError()).called(1);
    });

    test('should handle error states', () {
      // Given
      when(() => mockShoppingService.error).thenReturn('Ett fel uppstod');
      when(() => mockShoppingService.hasError).thenReturn(true);

      // When/Then
      expect(sut.error, equals('Ett fel uppstod'));
      expect(sut.hasError, isTrue);
    });
  });
}