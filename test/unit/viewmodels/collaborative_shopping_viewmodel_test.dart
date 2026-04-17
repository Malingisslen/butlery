/// Unit tests for CollaborativeShoppingViewModel
///
/// Tests collaborative shopping list functionality including:
/// - Initialization and data loading
/// - List properties and progress tracking
/// - Item management (add, toggle completion)
/// - Permission system
/// - Status display and activity tracking
/// - Error handling and lifecycle
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/shopping_list_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CollaborativeShoppingViewModel', () {
    late CollaborativeShoppingViewModel viewModel;
    late MockUnifiedShoppingService mockShoppingService;
    late FakePermissionService mockPermissionService;
    const testListId = 'test_list_123';
    const testUserId = 'test_user_123';

    // Test shopping list
    final testShoppingList = ShoppingListFactory.build(
      id: testListId,
      name: 'Veckohandling',
      description: 'Handlingslista för veckan',
      ownerId: testUserId,
      items: [
        ShoppingListFactory.buildItem(
          id: 'item1',
          name: 'Mjölk 1L',
          bought: false,
          amount: 2,
        ),
        ShoppingListFactory.buildItem(
          id: 'item2',
          name: 'Bröd',
          bought: true,
          amount: 1,
        ),
        ShoppingListFactory.buildItem(
          id: 'item3',
          name: 'Ägg 12-pack',
          bought: false,
          amount: 1,
        ),
      ],
    );

    final emptyShoppingList = ShoppingListFactory.build(
      id: testListId,
      name: 'Tom lista',
      description: '',
      items: [],
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(ShoppingListFactory.build());
      registerFallbackValue(ShoppingListFactory.buildItem());
    });

    setUp(() async {
      await TestServiceLocator.reset();
      await TestServiceLocator.initialize();

      // Bridge production ServiceLocator (used by ShoppingPermissionManager)
      production.ServiceLocator.initialize(DIContainer());

      // Create mocks
      mockShoppingService = MockUnifiedShoppingService();
      mockPermissionService = FakePermissionService();

      // Register permission service in TestServiceLocator
      // (shared GetIt instance, accessible by production ServiceLocator too)
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

      // Configure default mock behavior
      mockShoppingService.setShoppingState(
        lists: [testShoppingList],
        activeListId: testListId,
      );

      // Stub loadLists since _loadList calls it when list not found initially
      when(() => mockShoppingService.loadLists()).thenAnswer((_) async {});

      // Stub item operations
      when(() => mockShoppingService.addItemToActiveList(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
          )).thenAnswer((_) async => true);

      when(() => mockShoppingService.toggleItemBought(any()))
          .thenAnswer((_) async => true);

      mockPermissionService.setPermissionState(
        currentUserId: testUserId,
        defaultHasPermission: true,
      );

      // Create viewModel
      viewModel = CollaborativeShoppingViewModel(
        listId: testListId,
        shoppingService: mockShoppingService,
      );

      // Allow async initialization to complete
      await Future.delayed(Duration.zero);
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with list ID', () {
        expect(viewModel.listId, equals(testListId));
      });

      test('should load shopping list on initialization', () {
        expect(viewModel.currentList, isNotNull);
      });

      test('should have data after initialization', () {
        expect(viewModel.hasData, isTrue);
      });

      test('should have data after successful load', () {
        expect(viewModel.hasData, isTrue);
        expect(viewModel.currentList, isNotNull);
        expect(viewModel.listTitle, equals('Veckohandling'));
      });

      test('should set error when list not found', () async {
        final emptyMockService = MockUnifiedShoppingService();
        emptyMockService.setShoppingState(lists: [], activeListId: null);
        when(() => emptyMockService.loadLists()).thenAnswer((_) async {});

        // Constructor fires _initialize() which rethrows via executeAsync.
        // Capture that uncaught future error so test framework ignores it.
        late CollaborativeShoppingViewModel missingViewModel;
        await runZonedGuarded(() async {
          missingViewModel = CollaborativeShoppingViewModel(
            listId: 'nonexistent',
            shoppingService: emptyMockService,
          );
          await Future.delayed(Duration.zero);
        }, (_, __) {
          // Expected: rethrown exception from executeAsync
        });

        expect(missingViewModel.hasError, isTrue);
        expect(missingViewModel.listTitle, equals('Laddar...'));

        missingViewModel.dispose();
      });
    });

    group('List Properties', () {
      test('should provide list title and description', () {
        expect(viewModel.listTitle, equals('Veckohandling'));
        expect(viewModel.listDescription, equals('Handlingslista för veckan'));
        expect(viewModel.hasDescription, isTrue);
      });

      test('should handle empty description', () async {
        mockShoppingService.setShoppingState(
          lists: [emptyShoppingList],
          activeListId: testListId,
        );
        await viewModel.refresh();

        expect(viewModel.listDescription, isEmpty);
        expect(viewModel.hasDescription, isFalse);
      });

      test('should calculate item counts correctly', () {
        expect(viewModel.totalItems, equals(3));
        expect(viewModel.completedItems, equals(1));
        expect(viewModel.completedItemsCount, equals(1));
      });

      test('should calculate completion percentage', () {
        // 1 out of 3 items = 33.33%
        expect(viewModel.completionPercentage, closeTo(33.33, 0.01));
      });

      test('should handle empty list completion', () async {
        mockShoppingService.setShoppingState(
          lists: [emptyShoppingList],
          activeListId: testListId,
        );
        await viewModel.refresh();

        expect(viewModel.completionPercentage, equals(0.0));
      });

      test('should separate active and completed items', () {
        final activeItems = viewModel.activeItems;
        final completedItems = viewModel.completedItemsList;

        expect(activeItems.length, equals(2));
        expect(completedItems.length, equals(1));
        expect(activeItems[0].name, equals('Mjölk 1L'));
        expect(activeItems[1].name, equals('Ägg 12-pack'));
        expect(completedItems[0].name, equals('Bröd'));
      });
    });

    group('Item Management', () {
      test('should add item successfully', () async {
        final result = await viewModel.addItem('Smör');

        expect(result, isTrue);
        verify(() => mockShoppingService.addItemToActiveList(
              name: 'Smör',
              amount: 1.0,
              unit: '',
              category: 'Övrigt',
            )).called(1);
      });

      test('should reject empty item name', () async {
        final result = await viewModel.addItem('');

        expect(result, isFalse);
        verifyNever(() => mockShoppingService.addItemToActiveList(
              name: any(named: 'name'),
              amount: any(named: 'amount'),
              unit: any(named: 'unit'),
              category: any(named: 'category'),
            ));
      });

      test('should trim whitespace from item name', () async {
        final result = await viewModel.addItem('  Ost  ');

        expect(result, isTrue);
        verify(() => mockShoppingService.addItemToActiveList(
              name: 'Ost',
              amount: 1.0,
              unit: '',
              category: 'Övrigt',
            )).called(1);
      });

      test('should set loading state during item addition', () async {
        bool wasAddingItem = false;
        viewModel.addListener(() {
          if (viewModel.isAddingItem) wasAddingItem = true;
        });

        await viewModel.addItem('Gurka');

        expect(wasAddingItem, isTrue);
        expect(viewModel.isAddingItem, isFalse);
      });

      test('should handle item addition error', () async {
        when(() => mockShoppingService.addItemToActiveList(
              name: any(named: 'name'),
              amount: any(named: 'amount'),
              unit: any(named: 'unit'),
              category: any(named: 'category'),
            )).thenThrow(Exception('Add failed'));

        final result = await viewModel.addItem('Tomat');

        expect(result, isFalse);
        // Error is set on the internal item operations manager,
        // not on the VM's StateNotifierMixin error
      });
    });

    group('Item Completion', () {
      test('should toggle item completion successfully', () async {
        final result = await viewModel.toggleItemCompletion('item1');

        expect(result, isTrue);
        verify(() => mockShoppingService.toggleItemBought('item1')).called(1);
      });

      test('should handle toggle completion error', () async {
        when(() => mockShoppingService.toggleItemBought(any()))
            .thenThrow(Exception('Toggle failed'));

        final result = await viewModel.toggleItemCompletion('item1');

        expect(result, isFalse);
      });

      test('should return false for non-matching item ID', () async {
        // Empty/non-matching IDs trigger firstWhere to throw,
        // caught by the manager and returned as false
        final result = await viewModel.toggleItemCompletion('nonexistent');

        expect(result, isFalse);
      });
    });

    group('Permission System', () {
      test('should check edit permissions', () {
        expect(viewModel.canEdit, isTrue);
      });

      test('should check view permissions', () {
        expect(viewModel.canView, isTrue);
      });

      test('should handle no edit permissions', () {
        // Use defaultHasPermission: false so canEdit returns false
        final restrictedPermissionService = FakePermissionService();
        restrictedPermissionService.setPermissionState(
          currentUserId: testUserId,
          defaultHasPermission: false,
        );

        TestServiceLocator.registerMock<PermissionService>(
            restrictedPermissionService);

        final restrictedViewModel = CollaborativeShoppingViewModel(
          listId: testListId,
          shoppingService: mockShoppingService,
        );

        // Both canEdit and canView return false with defaultHasPermission: false
        expect(restrictedViewModel.canEdit, isFalse);
        expect(restrictedViewModel.canView, isFalse);

        restrictedViewModel.dispose();

        // Restore
        TestServiceLocator.registerMock<PermissionService>(
            mockPermissionService);
      });
    });

    group('Status and Progress', () {
      test('should provide status text', () {
        final statusText = viewModel.statusText;
        expect(statusText, isA<String>());
        expect(statusText.isNotEmpty, isTrue);
      });

      test('should provide status color', () {
        const cs = ColorScheme.light();
        const butlery = ButleryColors.light;
        final statusColor = viewModel.getStatusColor(cs, butlery);
        expect(statusColor, isA<Color>());
      });

      test('should provide progress color', () {
        const cs = ColorScheme.light();
        const butlery = ButleryColors.light;
        final progressColor = viewModel.getProgressColor(cs, butlery);
        expect(progressColor, isA<Color>());
      });

      test('should handle fully completed list', () async {
        final completedList = ShoppingListFactory.build(
          id: testListId,
          items: [
            ShoppingListFactory.buildItem(bought: true),
            ShoppingListFactory.buildItem(bought: true),
          ],
        );

        mockShoppingService.setShoppingState(
          lists: [completedList],
          activeListId: testListId,
        );
        await viewModel.refresh();

        expect(viewModel.completionPercentage, equals(100.0));
      });
    });

    group('Activity Tracking', () {
      test('should provide activity summary', () {
        final summary = viewModel.activitySummary;
        expect(summary, isA<String>());
        expect(summary, isNotEmpty);
      });

      test('should provide member count text', () {
        final memberText = viewModel.memberCountText;
        expect(memberText, isA<String>());
      });

      test('should track activity after item add', () async {
        await viewModel.addItem('Potatis');

        final summary = viewModel.activitySummary;
        expect(summary, isNotEmpty);
      });
    });

    group('UI Helpers', () {
      test('should provide item subtitle', () {
        final item = testShoppingList.items.first;
        final subtitle = viewModel.getItemSubtitle(item);

        expect(subtitle, isA<String?>());
      });

      test('should provide item trailing widgets', () {
        final item = testShoppingList.items.first;
        final widgets = viewModel.getItemTrailingWidgets(item);

        expect(widgets, isA<List<Widget>>());
      });
    });

    group('Stream Updates', () {
      test('should update when service data changes', () async {
        final updatedList = ShoppingListFactory.build(
          id: testListId,
          name: 'Uppdaterad lista',
          items: [ShoppingListFactory.buildItem(name: 'Ny vara')],
        );

        mockShoppingService.setShoppingState(
          lists: [updatedList],
          activeListId: testListId,
        );
        await viewModel.refresh();

        expect(viewModel.listTitle, equals('Uppdaterad lista'));
        expect(viewModel.totalItems, equals(1));
      });

      test('should handle data load errors', () async {
        final emptyMockService = MockUnifiedShoppingService();
        emptyMockService.setShoppingState(lists: [], activeListId: null);
        when(() => emptyMockService.loadLists()).thenAnswer((_) async {});

        late CollaborativeShoppingViewModel errorViewModel;
        await runZonedGuarded(() async {
          errorViewModel = CollaborativeShoppingViewModel(
            listId: 'nonexistent',
            shoppingService: emptyMockService,
          );
          await Future.delayed(Duration.zero);
        }, (_, __) {});

        expect(errorViewModel.hasError, isTrue);
        errorViewModel.dispose();
      });
    });

    group('Refresh', () {
      test('should refresh list data', () async {
        await viewModel.refresh();
        expect(viewModel.hasData, isTrue);
      });
    });

    group('Error Management', () {
      test('should clear error via clearError', () async {
        // Force an error state by refreshing with no matching list
        mockShoppingService.setShoppingState(lists: [], activeListId: null);
        try {
          await viewModel.refresh();
        } catch (_) {
          // Expected: executeAsync rethrows
        }
        expect(viewModel.hasError, isTrue);

        // clearError sets _error = null via StateNotifierMixin
        viewModel.clearError();
        expect(viewModel.hasError, isFalse);
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors after use', () async {
        final testViewModel = CollaborativeShoppingViewModel(
          listId: testListId,
          shoppingService: mockShoppingService,
        );
        await Future.delayed(Duration.zero);
        expect(() => testViewModel.dispose(), returnsNormally);
      });
    });

    group('Edge Cases', () {
      test('should handle null current list', () async {
        final emptyMockService = MockUnifiedShoppingService();
        emptyMockService.setShoppingState(lists: [], activeListId: null);
        when(() => emptyMockService.loadLists()).thenAnswer((_) async {});

        late CollaborativeShoppingViewModel nullViewModel;
        await runZonedGuarded(() async {
          nullViewModel = CollaborativeShoppingViewModel(
            listId: 'null_list',
            shoppingService: emptyMockService,
          );
          await Future.delayed(Duration.zero);
        }, (_, __) {});

        expect(nullViewModel.hasData, isFalse);
        expect(nullViewModel.listTitle, equals('Laddar...'));
        expect(nullViewModel.totalItems, equals(0));
        expect(nullViewModel.completionPercentage, equals(0.0));
        expect(nullViewModel.hasError, isTrue);

        nullViewModel.dispose();
      });

      test('should handle Swedish characters in item names', () async {
        final result = await viewModel.addItem('Räkor och ägg från Öland');

        expect(result, isTrue);
        verify(() => mockShoppingService.addItemToActiveList(
              name: 'Räkor och ägg från Öland',
              amount: 1.0,
              unit: '',
              category: 'Övrigt',
            )).called(1);
      });

      test('should handle very long item names', () async {
        final longName = 'A' * 200;

        final result = await viewModel.addItem(longName);

        expect(result, isTrue);
        verify(() => mockShoppingService.addItemToActiveList(
              name: longName,
              amount: 1.0,
              unit: '',
              category: 'Övrigt',
            )).called(1);
      });
    });
  });
}
