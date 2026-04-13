// test/unit/viewmodels/unified_shopping_viewmodel_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';

import '../../infrastructure/factories/shopping_list_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UnifiedShoppingViewModel viewModel;
  late MockUnifiedShoppingService mockShoppingService;
  late MockPermissionService mockPermissionService;
  late StreamController<ShoppingServiceState> stateController;

  const testUserId = 'test-user-123';
  const testListId = 'list-1';

  final testItem = ShoppingListFactory.buildItem(
    id: 'item-1',
    name: 'Mjolk',
    amount: 2.0,
    unit: 'liter',
    category: 'Mejeri',
  );

  final testList = ShoppingListFactory.build(
    id: testListId,
    name: 'Veckans inkop',
    ownerId: testUserId,
    items: [testItem],
  );

  setUpAll(() {
    final container = DIContainer();
    ServiceLocator.initialize(container);
    registerFallbackValue(ShoppingListFactory.build());
    registerFallbackValue(ShoppingListFactory.buildItem());
    registerFallbackValue(<UnifiedShoppingItem>[]);
  });

  setUp(() {
    final getIt = GetIt.instance;
    stateController = StreamController<ShoppingServiceState>.broadcast();

    mockShoppingService = MockUnifiedShoppingService();
    mockPermissionService = MockPermissionService();

    // Configure state
    mockShoppingService.setShoppingState(
      lists: [testList],
      personalLists: [testList],
      collaborativeLists: [],
      activeListId: testListId,
      isInitialized: true,
      isLoading: false,
      currentUserId: testUserId,
      currentUserDisplayName: 'Test User',
    );

    mockPermissionService.setPermissionState(
      currentUserId: testUserId,
      userDisplayName: 'Test User',
      isAuthenticated: true,
      defaultHasPermission: true,
    );

    // Stub stateStream (not overridden in MockUnifiedShoppingService)
    when(() => mockShoppingService.stateStream)
        .thenAnswer((_) => stateController.stream);
    when(() => mockShoppingService.hasLists).thenReturn(true);
    when(() => mockShoppingService.clearError()).thenReturn(null);

    // Stub service methods
    when(() => mockShoppingService.initialize()).thenAnswer((_) async {});
    when(() => mockShoppingService.loadLists()).thenAnswer((_) async {});
    when(() => mockShoppingService.createPersonalList(any()))
        .thenAnswer((_) async => 'new-list-id');
    when(() => mockShoppingService.createCollaborativeList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
          items: any(named: 'items'),
          categoryIds: any(named: 'categoryIds'),
          allowGuestEditing: any(named: 'allowGuestEditing'),
          autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
        )).thenAnswer((_) async => 'collab-list-id');
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
    when(() => mockShoppingService.clearBoughtItems())
        .thenAnswer((_) async => true);
    when(() => mockShoppingService.uncheckAllItems())
        .thenAnswer((_) async => true);
    when(() => mockShoppingService.addItemsBatch(any()))
        .thenAnswer((_) async => true);
    when(() => mockShoppingService.createListFromTemplate(
          templateId: any(named: 'templateId'),
        )).thenAnswer((_) async => 'template-list-id');
    when(() => mockShoppingService.exportListAsText(any()))
        .thenReturn('Mjolk - 2 liter');

    // Register mocks
    if (getIt.isRegistered<UnifiedShoppingService>()) {
      getIt.unregister<UnifiedShoppingService>();
    }
    getIt.registerSingleton<UnifiedShoppingService>(mockShoppingService);

    if (getIt.isRegistered<PermissionService>()) {
      getIt.unregister<PermissionService>();
    }
    getIt.registerSingleton<PermissionService>(mockPermissionService);

    viewModel = UnifiedShoppingViewModel();
  });

  tearDown(() {
    viewModel.dispose();
    stateController.close();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UnifiedShoppingService>()) {
      getIt.unregister<UnifiedShoppingService>();
    }
    if (getIt.isRegistered<PermissionService>()) {
      getIt.unregister<PermissionService>();
    }
  });

  group('Read State', () {
    test('lists returns service lists', () {
      expect(viewModel.lists, hasLength(1));
    });

    test('personalLists returns only personal', () {
      expect(viewModel.personalLists, hasLength(1));
    });

    test('collaborativeLists returns empty when none', () {
      expect(viewModel.collaborativeLists, isEmpty);
    });

    test('activeList returns the active list', () {
      expect(viewModel.activeList, isNotNull);
      expect(viewModel.activeList!.id, testListId);
    });

    test('items returns active list items', () {
      expect(viewModel.items, hasLength(1));
      expect(viewModel.items.first.name, 'Mjolk');
    });

    test('isLoading reflects service state', () {
      expect(viewModel.isLoading, isFalse);
    });

    test('isInitialized reflects service state', () {
      expect(viewModel.isInitialized, isTrue);
    });

    test('hasLists reflects service state', () {
      expect(viewModel.hasLists, isTrue);
    });

    test('hasItems reflects item list', () {
      expect(viewModel.hasItems, isTrue);
    });

    test('currentUserId comes from permission service', () {
      expect(viewModel.currentUserId, testUserId);
    });
  });

  group('List Management', () {
    test('initialize delegates to service', () async {
      await viewModel.initialize();
      verify(() => mockShoppingService.initialize()).called(1);
    });

    test('createPersonalList delegates to service', () async {
      final result = await viewModel.createPersonalList('Min lista');
      expect(result, isTrue);
      verify(() => mockShoppingService.createPersonalList('Min lista'))
          .called(1);
    });

    test('createPersonalList rejects empty name', () async {
      final result = await viewModel.createPersonalList('');
      expect(result, isFalse);
    });

    test('createPersonalList rejects whitespace name', () async {
      final result = await viewModel.createPersonalList('   ');
      expect(result, isFalse);
    });

    test('createList is alias for createPersonalList', () async {
      final result = await viewModel.createList('Ny lista');
      expect(result, isTrue);
      verify(() => mockShoppingService.createPersonalList('Ny lista'))
          .called(1);
    });

    test('setActiveList delegates to service', () async {
      final result = await viewModel.setActiveList(testListId);
      expect(result, isTrue);
    });

    test('renameActiveList delegates to service', () async {
      final result = await viewModel.renameActiveList('Nytt namn');
      expect(result, isTrue);
      verify(() => mockShoppingService.renameList(testListId, 'Nytt namn'))
          .called(1);
    });

    test('renameActiveList rejects empty name', () async {
      final result = await viewModel.renameActiveList('');
      expect(result, isFalse);
    });

    test('deleteActiveList delegates to service', () async {
      final result = await viewModel.deleteActiveList();
      expect(result, isTrue);
      verify(() => mockShoppingService.deleteList(testListId)).called(1);
    });

    test('renameList delegates to service', () async {
      final result = await viewModel.renameList(testListId, 'New Name');
      expect(result, isTrue);
    });

    test('deleteList delegates to service', () async {
      final result = await viewModel.deleteList(testListId);
      expect(result, isTrue);
    });

    test('loadLists delegates to service', () async {
      await viewModel.loadLists();
      verify(() => mockShoppingService.loadLists()).called(1);
    });
  });

  group('Item Operations', () {
    test('addItem delegates to service', () async {
      final result = await viewModel.addItem(
        name: 'Brod',
        amount: 1,
        unit: 'st',
      );
      expect(result, isTrue);
    });

    test('addItem rejects empty name', () async {
      final result = await viewModel.addItem(name: '', amount: 1);
      expect(result, isFalse);
    });

    test('addItemToActiveList is alias for addItem', () async {
      final result = await viewModel.addItemToActiveList(
        name: 'Agg',
        amount: 6,
        unit: 'st',
      );
      expect(result, isTrue);
    });

    test('toggleItemBought delegates to service', () async {
      final result = await viewModel.toggleItemBought('item-1');
      expect(result, isTrue);
      verify(() => mockShoppingService.toggleItemBought('item-1')).called(1);
    });

    test('removeItem delegates to service', () async {
      final result = await viewModel.removeItem('item-1');
      expect(result, isTrue);
    });

    test('removeItemFromActiveList is alias for removeItem', () async {
      final result = await viewModel.removeItemFromActiveList('item-1');
      expect(result, isTrue);
    });

    test('updateItem delegates to service', () async {
      final result = await viewModel.updateItem(
        itemId: 'item-1',
        name: 'Havremjolk',
      );
      expect(result, isTrue);
    });

    test('clearBoughtItems delegates to service', () async {
      final result = await viewModel.clearBoughtItems();
      expect(result, isTrue);
    });

    test('uncheckAllItems delegates to service', () async {
      final result = await viewModel.uncheckAllItems();
      expect(result, isTrue);
    });
  });

  group('Item Grouping and Search', () {
    test('itemsByCategory groups items', () {
      final grouped = viewModel.itemsByCategory;
      expect(grouped, isA<Map<String, List<UnifiedShoppingItem>>>());
      expect(grouped.isNotEmpty, isTrue);
    });

    test('usedCategories returns category list', () {
      final categories = viewModel.usedCategories;
      expect(categories, contains('Mejeri'));
    });

    test('searchItems finds by name', () {
      final results = viewModel.searchItems('Mjolk');
      expect(results, hasLength(1));
    });

    test('searchItems returns empty for no match', () {
      final results = viewModel.searchItems('xyz');
      expect(results, isEmpty);
    });
  });

  group('Permissions', () {
    test('canEditActiveList checks permission service', () {
      final canEdit = viewModel.canEditActiveList;
      expect(canEdit, isTrue);
    });

    test('canEditActiveList false when no active list', () {
      mockShoppingService.setShoppingState(
        lists: [],
        activeListId: null,
        currentUserId: testUserId,
        isInitialized: true,
      );
      expect(viewModel.canEditActiveList, isFalse);
    });

    test('addItem respects permission check', () async {
      mockPermissionService.setPermissionState(
        currentUserId: null,
        isAuthenticated: false,
      );
      final result = await viewModel.addItem(name: 'Test', amount: 1);
      expect(result, isFalse);
    });
  });

  group('Collaborative List Creation', () {
    test('createCollaborativeList delegates to service', () async {
      final result = await viewModel.createCollaborativeList(
        name: 'Familjelista',
        memberIds: ['user-2'],
        memberDisplayNames: {'user-2': 'Partner'},
      );
      expect(result, isTrue);
    });

    test('createCollaborativeList rejects empty name', () async {
      final result = await viewModel.createCollaborativeList(
        name: '',
        memberIds: ['user-2'],
        memberDisplayNames: {'user-2': 'Partner'},
      );
      expect(result, isFalse);
    });
  });

  group('Export', () {
    test('exportList returns text', () {
      final text = viewModel.exportList();
      expect(text, isA<String>());
    });

    test('exportListAsText returns text', () {
      final text = viewModel.exportListAsText();
      expect(text, isA<String>());
    });
  });

  group('Service State Stream', () {
    test('notifies listeners when service emits state', () async {
      var notified = false;
      viewModel.addListener(() => notified = true);

      stateController.add(const ShoppingStateLoading());
      // Allow microtask to complete
      await Future.delayed(Duration.zero);

      expect(notified, isTrue);
    });
  });

  group('Computed Properties', () {
    test('totalItems reflects active list', () {
      expect(viewModel.totalItems, 1);
    });

    test('isOnline is true when initialized and no error', () {
      expect(viewModel.isOnline, isTrue);
    });

    test('listSummary returns string', () {
      expect(viewModel.listSummary, isA<String>());
    });
  });

  group('No Active List', () {
    setUp(() {
      mockShoppingService.setShoppingState(
        lists: [testList],
        personalLists: [testList],
        activeListId: null,
        isInitialized: true,
        currentUserId: testUserId,
      );
    });

    test('items returns empty when no active list', () {
      expect(viewModel.items, isEmpty);
    });

    test('deleteActiveList returns false', () async {
      final result = await viewModel.deleteActiveList();
      expect(result, isFalse);
    });

    test('renameActiveList returns false', () async {
      final result = await viewModel.renameActiveList('New');
      expect(result, isFalse);
    });
  });

  group('Debug Info', () {
    test('debugInfo returns complete map', () {
      final info = viewModel.debugInfo;
      expect(info, contains('listsCount'));
      expect(info, contains('isInitialized'));
      expect(info, contains('currentUserId'));
    });
  });
}
