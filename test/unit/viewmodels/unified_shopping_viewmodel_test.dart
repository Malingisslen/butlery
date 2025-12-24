import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/shopping_list_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('UnifiedShoppingViewModel', () {
    late UnifiedShoppingViewModel viewModel;
    late MockUnifiedShoppingService mockShoppingService;
    late MockPermissionService mockPermissionService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(ShoppingListFactory.build());
      registerFallbackValue(ShoppingListFactory.buildItem());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockShoppingService = MockUnifiedShoppingService();
      mockPermissionService = MockPermissionService();

      // Configure mock state using configuration method
      mockShoppingService.setShoppingState(
        lists: [],
        personalLists: [],
        collaborativeLists: [],
        activeListId: null,
        isInitialized: true,
        isLoading: false,
        error: null,
        currentUserId: 'test-user-123',
        currentUserDisplayName: 'Test User',
      );

      // Configure permission service using configuration method
      mockPermissionService.setPermissionState(
        currentUserId: 'test-user-123',
        userDisplayName: 'Test User',
        isAuthenticated: true,
        defaultHasPermission:
            true, // This will make permission checks return true
      );

      // Setup default mock behaviors for UnifiedShoppingService methods
      when(() => mockShoppingService.initialize()).thenAnswer((_) async {});
      when(() => mockShoppingService.loadLists()).thenAnswer((_) async {});
      when(() => mockShoppingService.createPersonalList(any()))
          .thenAnswer((_) async => 'list-123');
      when(() => mockShoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
            allowGuestEditing: any(named: 'allowGuestEditing'),
            autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
          )).thenAnswer((_) async => 'collab-list-123');
      when(() => mockShoppingService.setActiveList(any()))
          .thenAnswer((_) async => true);
      when(() => mockShoppingService.renameList(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockShoppingService.deleteList(any()))
          .thenAnswer((_) async => true);
      when(() => mockShoppingService.addItemToActiveList(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
            note: any(named: 'note'),
            estimatedPrice: any(named: 'estimatedPrice'),
            priority: any(named: 'priority'),
          )).thenAnswer((_) async => true);
      when(() => mockShoppingService.toggleItemBought(any()))
          .thenAnswer((_) async => true);
      when(() => mockShoppingService.removeItemFromActiveList(any()))
          .thenAnswer((_) async => true);
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
      when(() => mockShoppingService.uncheckAllItems())
          .thenAnswer((_) async => true);

      // Register mocks in test service locator
      TestServiceLocator.registerMock<UnifiedShoppingService>(
          mockShoppingService);
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

      // Create viewModel
      viewModel = UnifiedShoppingViewModel();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
      viewModel.dispose();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with default state', () {
        // Arrange - viewModel already initialized in setUp

        // Act - no action needed, checking initial state

        // Assert
        expect(viewModel.lists, isEmpty);
        expect(viewModel.personalLists, isEmpty);
        expect(viewModel.collaborativeLists, isEmpty);
        expect(viewModel.activeList, isNull);
        expect(viewModel.items, isEmpty);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.isInitialized, isTrue);
        expect(viewModel.hasError, isFalse);
      });

      test('should register listener for service updates', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act - trigger service update
        mockShoppingService.notifyListeners();

        // Assert - viewModel should propagate the notification
        expect(notificationCount, equals(1));
      });

      test('should initialize shopping system', () async {
        // Arrange - mock already configured in setUp

        // Act
        await viewModel.initialize();

        // Assert
        verify(() => mockShoppingService.initialize()).called(1);
      });

      test('should create default list for new users', () async {
        // Arrange
        mockShoppingService.setShoppingState(
          lists: [],
          currentUserId: 'test-user-123',
        );

        // Act
        await viewModel.initialize();

        // Assert
        verify(() => mockShoppingService.createPersonalList('Min Inköpslista'))
            .called(1);
      });

      test('should not create default list if user has lists', () async {
        // Arrange
        final existingList = ShoppingListFactory.build();
        mockShoppingService.setShoppingState(
          lists: [existingList],
          currentUserId: 'test-user-123',
        );

        // Act
        await viewModel.initialize();

        // Assert
        verifyNever(() => mockShoppingService.createPersonalList(any()));
      });
    });

    group('State Accessors', () {
      test('should return correct shopping lists', () {
        // Arrange
        final personalList = ShoppingListFactory.build(type: ListType.personal);
        final collaborativeList = ShoppingListFactory.build(
          type: ListType.collaborative,
          name: 'Shared List',
        );
        final lists = [personalList, collaborativeList];

        mockShoppingService.setShoppingState(
          lists: lists,
          personalLists: [personalList],
          collaborativeLists: [collaborativeList],
        );

        // Act & Assert
        expect(viewModel.lists, equals(lists));
        expect(viewModel.personalLists, contains(personalList));
        expect(viewModel.collaborativeLists, contains(collaborativeList));
        expect(viewModel.hasLists, isTrue);
      });

      test('should return active list and items', () {
        // Arrange
        final item1 = ShoppingListFactory.buildItem(name: 'Mjölk');
        final item2 = ShoppingListFactory.buildItem(name: 'Bröd');
        final activeList = ShoppingListFactory.build(
          id: 'active-list',
          items: [item1, item2],
        );

        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: 'active-list',
        );

        // Act & Assert
        expect(viewModel.activeList, equals(activeList));
        expect(viewModel.items, hasLength(2));
        expect(viewModel.hasItems, isTrue);
      });

      test('should return loading and sync states', () {
        // Arrange
        mockShoppingService.setShoppingState(
          isLoading: true,
          isSyncing: true,
        );

        // Act & Assert
        expect(viewModel.isLoading, isTrue);
        expect(viewModel.isSyncing, isTrue);
      });

      test('should return error state', () {
        // Arrange
        const errorMessage = 'Nätverksfel';
        mockShoppingService.setShoppingState(
          error: errorMessage,
        );

        // Act & Assert
        expect(viewModel.error, equals(errorMessage));
        expect(viewModel.hasError, isTrue);
        expect(viewModel.isOnline, isFalse);
      });

      test('should return user information', () {
        // Arrange - state already configured in setUp

        // Act & Assert
        expect(viewModel.currentUserId, equals('test-user-123'));
        expect(viewModel.currentUserDisplayName, equals('Test User'));
      });

      test('should calculate shopping statistics', () {
        // Arrange
        final item1 =
            ShoppingListFactory.buildItem(name: 'Mjölk', bought: true);
        final item2 =
            ShoppingListFactory.buildItem(name: 'Bröd', bought: false);
        final item3 = ShoppingListFactory.buildItem(name: 'Ägg', bought: true);
        final activeList = ShoppingListFactory.build(
          id: 'active-list',
          items: [item1, item2, item3],
        );

        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: 'active-list',
        );

        // Act & Assert
        expect(viewModel.totalItems, equals(3));
        expect(viewModel.boughtItems, equals(2));
        expect(viewModel.unboughtItems, equals(1));
        expect(viewModel.completionPercentage, closeTo(66.67, 0.01));
        expect(viewModel.allItemsBought, isFalse);
      });

      test('should return online status based on error and initialization', () {
        // Arrange & Act & Assert - test no error, initialized
        mockShoppingService.setShoppingState(
          error: null,
          isInitialized: true,
        );
        expect(viewModel.isOnline, isTrue);

        // Arrange & Act & Assert - test has error
        mockShoppingService.setShoppingState(
          error: 'Some error',
          isInitialized: true,
        );
        expect(viewModel.isOnline, isFalse);
      });
    });

    group('Personal List Management', () {
      test('should create personal list successfully', () async {
        // Arrange - mock already configured in setUp

        // Act
        final result = await viewModel.createPersonalList('Veckans Inköp');

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.createPersonalList('Veckans Inköp'))
            .called(1);
      });

      test('should reject empty personal list name', () async {
        // Arrange - empty name

        // Act
        final result = await viewModel.createPersonalList('  ');

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockShoppingService.createPersonalList(any()));
      });

      test('should rename active list', () async {
        // Arrange
        final activeList = ShoppingListFactory.build(id: 'active-list');
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: 'active-list',
        );

        // Act
        final result = await viewModel.renameActiveList('Nytt Namn');

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.renameList('active-list', 'Nytt Namn'))
            .called(1);
      });

      test('should not rename if no active list', () async {
        // Arrange
        mockShoppingService.setShoppingState(
          lists: [],
          activeListId: null,
        );

        // Act
        final result = await viewModel.renameActiveList('Nytt Namn');

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockShoppingService.renameList(any(), any()));
      });

      test('should delete active list', () async {
        // Arrange
        final activeList = ShoppingListFactory.build(id: 'active-list');
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: 'active-list',
        );

        // Act
        final result = await viewModel.deleteActiveList();

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.deleteList('active-list')).called(1);
      });

      test('should set active list', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.setActiveList('list-123');

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.setActiveList('list-123')).called(1);
      });
    });

    group('Collaborative List Management', () {
      test('should create collaborative list successfully', () async {
        // Arrange
        const memberIds = ['user1', 'user2'];
        final memberDisplayNames = {
          'user1': 'Anna Andersson',
          'user2': 'Erik Svensson',
        };

        // Act
        final result = await viewModel.createCollaborativeList(
          name: 'Familjen Inköpslista',
          description: 'Veckohandling',
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
          allowGuestEditing: true,
          autoRemoveCompleted: false,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.createCollaborativeList(
              name: 'Familjen Inköpslista',
              description: 'Veckohandling',
              memberIds: memberIds,
              memberDisplayNames: memberDisplayNames,
              items: null,
              categoryIds: null,
              allowGuestEditing: true,
              autoRemoveCompleted: false,
            )).called(1);
      });

      test('should reject empty collaborative list name', () async {
        // Arrange
        const memberIds = ['user1'];
        final memberDisplayNames = {'user1': 'User'};

        // Act
        final result = await viewModel.createCollaborativeList(
          name: '  ',
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockShoppingService.createCollaborativeList(
              name: any(named: 'name'),
              description: any(named: 'description'),
              memberIds: any(named: 'memberIds'),
              memberDisplayNames: any(named: 'memberDisplayNames'),
              items: any(named: 'items'),
              categoryIds: any(named: 'categoryIds'),
              allowGuestEditing: any(named: 'allowGuestEditing'),
              autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
            ));
      });

      test('should check edit permissions', () {
        // Arrange
        final activeList = ShoppingListFactory.build(id: 'active-list');
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: 'active-list',
        );

        // Act & Assert
        expect(viewModel.canEditActiveList, isTrue);
        // canEditShoppingList is called internally, verified by the result
      });

      test('should check manage permissions', () {
        // Arrange
        final activeList = ShoppingListFactory.build(id: 'active-list');
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: 'active-list',
        );

        // Act & Assert
        expect(viewModel.canManageActiveList, isTrue);
        // canManageShoppingList is called internally, verified by the result
      });

      test('should get active list members', () {
        // Arrange
        final collaborativeList = ShoppingListFactory.build(
          id: 'active-list',
          type: ListType.collaborative,
          memberPermissions: {
            'user1': SharedListPermission.edit,
            'user2': SharedListPermission.view,
          },
        );
        mockShoppingService.setShoppingState(
          lists: [collaborativeList],
          activeListId: collaborativeList.id,
        );

        // Act
        final members = viewModel.activeListMembers;

        // Assert
        expect(members, hasLength(2));
        expect(members, contains('user1'));
        expect(members, contains('user2'));
      });
    });

    group('Item Management', () {
      test('should add item to active list', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.addItem(
          name: 'Mjölk',
          amount: 2.0,
          unit: 'liter',
          category: 'Mejeri',
          note: 'Laktosfri',
          priority: 4,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.addItemToActiveList(
              name: 'Mjölk',
              amount: 2.0,
              unit: 'liter',
              category: 'Mejeri',
              note: 'Laktosfri',
              estimatedPrice: null,
              priority: 4,
            )).called(1);
      });

      test('should reject empty item name', () async {
        // Arrange - empty name

        // Act
        final result = await viewModel.addItem(
          name: '  ',
          amount: 1.0,
        );

        // Assert
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
        // Arrange - mock already configured

        // Act
        final result = await viewModel.toggleItemBought('item-123');

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.toggleItemBought('item-123'))
            .called(1);
      });

      test('should remove item from active list', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.removeItem('item-123');

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.removeItemFromActiveList('item-123'))
            .called(1);
      });

      test('should update item in active list', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.updateItem(
          itemId: 'item-123',
          name: 'Updated Name',
          quantity: 3.0,
          category: 'New Category',
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.updateItemInActiveList(
              itemId: 'item-123',
              name: 'Updated Name',
              quantity: 3.0,
              unit: null,
              category: 'New Category',
              notes: null,
              estimatedPrice: null,
              priority: null,
            )).called(1);
      });

      test('should restore deleted item', () async {
        // Arrange
        final item = ShoppingListFactory.buildItem(
          name: 'Restored Item',
          amount: 2.0,
          unit: 'kg',
          category: 'Test',
        );

        // Act
        final result = await viewModel.restoreItem(item);

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.addItemToActiveList(
              name: 'Restored Item',
              amount: 2.0,
              unit: 'kg',
              category: 'Test',
              note: null,
              estimatedPrice: null,
              priority: 3,
            )).called(1);
      });

      test('should clear bought items', () async {
        // Arrange
        final activeList = ShoppingListFactory.build(
          items: [
            ShoppingListFactory.buildItem(bought: true),
            ShoppingListFactory.buildItem(bought: false),
          ],
        );
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final result = await viewModel.clearBoughtItems();

        // Assert
        expect(result, isTrue);
        // clearBoughtItems is a concrete method, no need to verify
      });

      test('should uncheck all items', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.uncheckAllItems();

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.uncheckAllItems()).called(1);
      });
    });

    group('Bulk Operations', () {
      test('should add items from recipe', () async {
        // Arrange
        final ingredientData = [
          {'name': 'Mjöl', 'amount': 500, 'unit': 'g', 'category': 'Bakning'},
          {'name': 'Ägg', 'amount': 3, 'unit': 'st', 'category': 'Mejeri'},
        ];

        // Act
        final result = await viewModel.addItemsFromRecipe(ingredientData);

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.addItemToActiveList(
              name: 'Mjöl',
              amount: 500.0,
              unit: 'g',
              category: 'Bakning',
              note: null,
              estimatedPrice: null,
              priority: 3,
            )).called(1);
        verify(() => mockShoppingService.addItemToActiveList(
              name: 'Ägg',
              amount: 3.0,
              unit: 'st',
              category: 'Mejeri',
              note: null,
              estimatedPrice: null,
              priority: 3,
            )).called(1);
      });

      test('should add items to specific list', () async {
        // Arrange
        final items = [
          ShoppingListFactory.buildItem(name: 'Item 1'),
          ShoppingListFactory.buildItem(name: 'Item 2'),
        ];

        // Act
        final result = await viewModel.addItemsToList('list-123', items);

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.setActiveList('list-123')).called(1);
        verify(() => mockShoppingService.addItemToActiveList(
              name: any(named: 'name'),
              amount: any(named: 'amount'),
              unit: any(named: 'unit'),
              category: any(named: 'category'),
              note: any(named: 'note'),
              estimatedPrice: any(named: 'estimatedPrice'),
              priority: any(named: 'priority'),
            )).called(2);
      });
    });

    group('Categorization and Search', () {
      test('should group items by category', () {
        // Arrange
        final items = [
          ShoppingListFactory.buildItem(name: 'Mjölk', category: 'Mejeri'),
          ShoppingListFactory.buildItem(name: 'Ost', category: 'Mejeri'),
          ShoppingListFactory.buildItem(name: 'Bröd', category: 'Bageri'),
        ];
        final activeList = ShoppingListFactory.build(items: items);
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final grouped = viewModel.itemsByCategory;

        // Assert
        expect(grouped, hasLength(2));
        expect(grouped['Mejeri'], hasLength(2));
        expect(grouped['Bageri'], hasLength(1));
      });

      test('should get used categories', () {
        // Arrange
        final items = [
          ShoppingListFactory.buildItem(category: 'Mejeri'),
          ShoppingListFactory.buildItem(category: 'Bageri'),
          ShoppingListFactory.buildItem(category: 'Mejeri'), // Duplicate
        ];
        final activeList = ShoppingListFactory.build(items: items);
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final categories = viewModel.usedCategories;

        // Assert
        expect(categories, hasLength(2));
        expect(categories, contains('Mejeri'));
        expect(categories, contains('Bageri'));
        expect(categories[0], equals('Bageri')); // Alphabetically sorted
      });

      test('should search items', () {
        // Arrange
        final items = [
          ShoppingListFactory.buildItem(name: 'Mjölk', category: 'Mejeri'),
          ShoppingListFactory.buildItem(name: 'Bröd', category: 'Bageri'),
          ShoppingListFactory.buildItem(name: 'Mjukost', category: 'Mejeri'),
        ];
        final activeList = ShoppingListFactory.build(items: items);
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final results = viewModel.searchItems('mjö');

        // Assert
        expect(results, hasLength(1));
        expect(results[0].name, equals('Mjölk'));
      });

      test('should search by category', () {
        // Arrange
        final items = [
          ShoppingListFactory.buildItem(name: 'Mjölk', category: 'Mejeri'),
          ShoppingListFactory.buildItem(name: 'Bröd', category: 'Bageri'),
          ShoppingListFactory.buildItem(name: 'Ost', category: 'Mejeri'),
        ];
        final activeList = ShoppingListFactory.build(items: items);
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final results = viewModel.searchItems('mejeri');

        // Assert
        expect(results, hasLength(2));
      });
    });

    group('Analytics and Insights', () {
      test('should provide shopping insights', () {
        // Arrange
        final items = [
          ShoppingListFactory.buildItem(bought: true, priority: 5),
          ShoppingListFactory.buildItem(bought: false, priority: 3),
          ShoppingListFactory.buildItem(bought: true, priority: 4),
        ];
        final activeList = ShoppingListFactory.build(
          items: items,
          type: ListType.collaborative,
        );
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final insights = viewModel.shoppingInsights;

        // Assert
        expect(insights['totalItems'], equals(3));
        expect(insights['boughtItems'], equals(2));
        expect(insights['completionPercentage'], closeTo(66.67, 0.01));
        expect(insights['isCollaborative'], isTrue);
        expect(insights['priorityItems'], equals(2)); // Items with priority > 3
      });

      test('should return empty insights when no active list', () {
        // Arrange
        mockShoppingService.setShoppingState(
          lists: [],
          activeListId: null,
        );

        // Act
        final insights = viewModel.shoppingInsights;

        // Assert
        expect(insights, isEmpty);
      });

      test('should get list summary', () {
        // Arrange
        final activeList = ShoppingListFactory.build();
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final summary = viewModel.listSummary;

        // Assert
        expect(summary, isNotEmpty);
      });

      test('should return default summary when no active list', () {
        // Arrange
        mockShoppingService.setShoppingState(
          lists: [],
          activeListId: null,
        );

        // Act
        final summary = viewModel.listSummary;

        // Assert
        expect(summary, equals('Ingen aktiv lista'));
      });
    });

    group('Export Functionality', () {
      test('should export list as text', () {
        // Arrange
        final activeList = ShoppingListFactory.build(name: 'Test Export List');
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final exported = viewModel.exportListAsText();

        // Assert
        expect(exported, equals('Test Export List'));
        // exportListAsText is a concrete method, no need to verify
      });

      test('should export list with categories', () {
        // Arrange
        final items = [
          ShoppingListFactory.buildItem(
              name: 'Mjölk', category: 'Mejeri', bought: true),
          ShoppingListFactory.buildItem(
              name: 'Bröd', category: 'Bageri', bought: false),
        ];
        final activeList = ShoppingListFactory.build(
          name: 'Test Lista',
          items: items,
        );
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final exported = viewModel.exportListAsTextWithCategories();

        // Assert
        expect(exported, contains('📝 Test Lista'));
        expect(exported, contains('🏷️ Mejeri:'));
        expect(exported, contains('✅')); // Bought item
        expect(exported, contains('⬜')); // Unbought item
        expect(exported, contains('Mjölk'));
        expect(exported, contains('Bröd'));
      });

      test('should return empty export when no active list', () {
        // Arrange
        mockShoppingService.setShoppingState(
          lists: [],
          activeListId: null,
        );

        // Act
        final exported = viewModel.exportListAsTextWithCategories();

        // Assert
        expect(exported, isEmpty);
      });
    });

    group('Backward Compatibility API', () {
      test('should load lists using backward compatible method', () async {
        // Arrange - mock already configured

        // Act
        await viewModel.loadLists();

        // Assert
        verify(() => mockShoppingService.loadLists()).called(1);
      });

      test('should create list using backward compatible method', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.createList('Test List');

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.createPersonalList('Test List'))
            .called(1);
      });

      test('should rename list using backward compatible method', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.renameList('list-123', 'New Name');

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.renameList('list-123', 'New Name'))
            .called(1);
      });

      test('should delete list using backward compatible method', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.deleteList('list-123');

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.deleteList('list-123')).called(1);
      });

      test('should export list using backward compatible method', () {
        // Arrange
        final activeList =
            ShoppingListFactory.build(name: 'Backward Compatible Export');
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act
        final exported = viewModel.exportList();

        // Assert
        expect(exported, equals('Backward Compatible Export'));
        // exportListAsText is a concrete method, no need to verify
      });

      test('should add item using backward compatible method', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.addItemToActiveList(
          name: 'Test Item',
          amount: 1.0,
          unit: 'st',
          category: 'Test',
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.addItemToActiveList(
              name: 'Test Item',
              amount: 1.0,
              unit: 'st',
              category: 'Test',
              note: null,
              estimatedPrice: null,
              priority: 3,
            )).called(1);
      });

      test('should remove item using backward compatible method', () async {
        // Arrange - mock already configured

        // Act
        final result = await viewModel.removeItemFromActiveList('item-123');

        // Assert
        expect(result, isTrue);
        verify(() => mockShoppingService.removeItemFromActiveList('item-123'))
            .called(1);
      });
    });

    group('Error Handling', () {
      test('should clear error state', () {
        // Arrange
        mockShoppingService.setShoppingState(error: 'Test error');

        // Act
        viewModel.clearError();

        // Assert - clearError is a concrete method that sets error to null
        expect(mockShoppingService.error, isNull);
      });

      test('should handle null current user for permissions', () {
        // Arrange
        mockPermissionService.setPermissionState(
          currentUserId: null,
          isAuthenticated: false,
        );
        final activeList = ShoppingListFactory.build();
        mockShoppingService.setShoppingState(
          lists: [activeList],
          activeListId: activeList.id,
        );

        // Act & Assert
        expect(viewModel.canEditActiveList, isFalse);
        expect(viewModel.canManageActiveList, isFalse);
      });
    });

    group('Debug Information', () {
      test('should provide debug information', () {
        // Arrange
        final personalList = ShoppingListFactory.build(type: ListType.personal);
        final collaborativeList =
            ShoppingListFactory.build(type: ListType.collaborative);
        mockShoppingService.setShoppingState(
          lists: [personalList, collaborativeList],
          personalLists: [personalList],
          collaborativeLists: [collaborativeList],
          isInitialized: true,
          isLoading: false,
          error: null,
        );

        // Act
        final debugInfo = viewModel.debugInfo;

        // Assert
        expect(debugInfo['listsCount'], equals(2));
        expect(debugInfo['personalListsCount'], equals(1));
        expect(debugInfo['collaborativeListsCount'], equals(1));
        expect(debugInfo['isInitialized'], isTrue);
        expect(debugInfo['isLoading'], isFalse);
        expect(debugInfo['hasError'], isFalse);
        expect(debugInfo['currentUserId'], equals('test-user-123'));
      });
    });

    group('Lifecycle', () {
      test('should cleanup on dispose', () {
        // Arrange
        final testViewModel = UnifiedShoppingViewModel();

        // Act & Assert - verify dispose doesn't throw
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should notify listeners on state changes', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act - trigger multiple service updates
        mockShoppingService.notifyListeners();
        mockShoppingService.notifyListeners();
        mockShoppingService.notifyListeners();

        // Assert
        expect(notificationCount, equals(3));
      });
    });
  });
}
