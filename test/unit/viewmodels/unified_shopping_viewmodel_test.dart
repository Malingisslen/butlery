// test/unit/viewmodels/unified_shopping_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/shopping/shopping_checkoff_pantry_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';

import '../../infrastructure/factories/shopping_list_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local plain mocks for the BUT-1306 checkoff -> pantry seam. Kept as bare
// `extends Mock` (no concrete bodies) so `when()`/`verify()` work cleanly,
// per the Mock-vs-Fake rule.
class _MockCheckoffPantryService extends Mock
    implements ShoppingCheckoffPantryService {}

class _MockUserServiceForSeam extends Mock implements UserService {}

/// Fake connectivity source with real ChangeNotifier semantics so the VM's
/// `addListener` subscription actually fires when connectivity flips. Overrides
/// `isConnectedToInternet` with a settable flag; never starts the real
/// timer/stream monitoring, so the injected mock repo is only a constructor stub.
class _FakeConnectivity extends ConnectivityMonitoringService {
  _FakeConnectivity(super.repository, {bool online = true}) : _online = online;

  bool _online;

  @override
  bool get isConnectedToInternet => _online;

  void setOnline(bool value) {
    _online = value;
    notifyListeners();
  }
}

UserProfile _seamProfile({
  required bool autoAdd,
  required bool prompted,
}) => UserProfile(
  uid: 'test-user-123',
  displayName: 'Test User',
  email: 't@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  autoAddBoughtToPantry: autoAdd,
  pantryAutoAddPrompted: prompted,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UnifiedShoppingViewModel viewModel;
  late MockUnifiedShoppingService mockShoppingService;
  late FakePermissionService mockPermissionService;

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

    mockShoppingService = MockUnifiedShoppingService();
    mockPermissionService = FakePermissionService();

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

    // stateStream is already overridden in MockUnifiedShoppingService
    when(() => mockShoppingService.hasLists).thenReturn(true);
    when(() => mockShoppingService.clearError()).thenReturn(null);

    // Stub service methods
    when(() => mockShoppingService.initialize()).thenAnswer((_) async {});
    when(() => mockShoppingService.loadLists()).thenAnswer((_) async {});
    when(
      () => mockShoppingService.createPersonalList(any()),
    ).thenAnswer((_) async => 'new-list-id');
    when(
      () => mockShoppingService.createCollaborativeList(
        name: any(named: 'name'),
        description: any(named: 'description'),
        memberIds: any(named: 'memberIds'),
        memberDisplayNames: any(named: 'memberDisplayNames'),
        items: any(named: 'items'),
        categoryIds: any(named: 'categoryIds'),
        allowGuestEditing: any(named: 'allowGuestEditing'),
        autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
      ),
    ).thenAnswer((_) async => 'collab-list-id');
    when(
      () => mockShoppingService.setActiveList(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.renameList(any(), any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.deleteList(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.addItemToActiveList(
        name: any(named: 'name'),
        amount: any(named: 'amount'),
        unit: any(named: 'unit'),
        category: any(named: 'category'),
        note: any(named: 'note'),
        estimatedPrice: any(named: 'estimatedPrice'),
        priority: any(named: 'priority'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.toggleItemBought(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.removeItemFromActiveList(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.updateItemInActiveList(
        itemId: any(named: 'itemId'),
        name: any(named: 'name'),
        quantity: any(named: 'quantity'),
        unit: any(named: 'unit'),
        category: any(named: 'category'),
        notes: any(named: 'notes'),
        estimatedPrice: any(named: 'estimatedPrice'),
        priority: any(named: 'priority'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.clearBoughtItems(),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.uncheckAllItems(),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.addItemsBatch(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockShoppingService.createListFromTemplate(
        templateId: any(named: 'templateId'),
      ),
    ).thenAnswer((_) async => 'template-list-id');
    when(
      () => mockShoppingService.exportListAsText(any()),
    ).thenReturn('Mjolk - 2 liter');

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
      verify(
        () => mockShoppingService.createPersonalList('Min lista'),
      ).called(1);
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
      verify(
        () => mockShoppingService.createPersonalList('Ny lista'),
      ).called(1);
    });

    test('setActiveList delegates to service', () async {
      final result = await viewModel.setActiveList(testListId);
      expect(result, isTrue);
    });

    test('renameActiveList delegates to service', () async {
      final result = await viewModel.renameActiveList('Nytt namn');
      expect(result, isTrue);
      verify(
        () => mockShoppingService.renameList(testListId, 'Nytt namn'),
      ).called(1);
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

      mockShoppingService.emitState(const ShoppingStateLoading());
      // Allow microtask to complete
      await Future.delayed(Duration.zero);

      expect(notified, isTrue);
    });
  });

  group('Computed Properties', () {
    test('totalItems reflects active list', () {
      expect(viewModel.totalItems, 1);
    });

    test(
      'isOnline reflects the live connectivity signal, not init/error state',
      () {
        // BUT-610: isOnline must follow real network connectivity. Inject a
        // connectivity source and flip it offline -> online, asserting the VM's
        // isOnline follows AND that crossing the boundary notifies the view (so
        // the offline banner can appear/disappear).
        final connectivity = _FakeConnectivity(MockConnectivityRepository());
        final vm = UnifiedShoppingViewModel(connectivity: connectivity);
        addTearDown(vm.dispose);

        var notifyCount = 0;
        vm.addListener(() => notifyCount++);

        expect(vm.isOnline, isTrue, reason: 'starts online');

        connectivity.setOnline(false);
        expect(vm.isOnline, isFalse, reason: 'follows source going offline');
        expect(
          notifyCount,
          greaterThan(0),
          reason: 'connectivity change rebuilds the view',
        );

        final afterOffline = notifyCount;
        connectivity.setOnline(true);
        expect(
          vm.isOnline,
          isTrue,
          reason: 'follows source coming back online',
        );
        expect(
          notifyCount,
          greaterThan(afterOffline),
          reason: 'coming back online also notifies',
        );
      },
    );

    test(
      'isOnline defaults to true when no connectivity source is available',
      () {
        // The default-injected VM (used in this suite) has no
        // ConnectivityMonitoringService registered, so it treats the app as
        // online — the offline banner stays hidden by default.
        expect(viewModel.isOnline, isTrue);
      },
    );

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

  // BUT-1306: the VM owns the wiring of the checkoff -> pantry policy seam and
  // the auto-add opt-in preference. The service-level gating (false->true only,
  // preference on) is covered in pantry_from_shopping_test.dart; here we prove
  // the VM (a) captures the pre-toggle bought-state and feeds a faithful
  // wasBought to the service, and (b) surfaces/persists the preference.
  group('Auto-add-to-pantry seam (BUT-1306)', () {
    late _MockCheckoffPantryService mockCheckoff;
    late _MockUserServiceForSeam mockUserService;

    setUp(() {
      final getIt = GetIt.instance;
      mockCheckoff = _MockCheckoffPantryService();
      mockUserService = _MockUserServiceForSeam();

      when(
        () => mockCheckoff.onItemCheckedOff(
          any(),
          any(),
          wasBought: any(named: 'wasBought'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockUserService.setAutoAddToPantry(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockUserService.markPantryAutoAddPrompted(),
      ).thenAnswer((_) async {});

      if (getIt.isRegistered<ShoppingCheckoffPantryService>()) {
        getIt.unregister<ShoppingCheckoffPantryService>();
      }
      getIt.registerSingleton<ShoppingCheckoffPantryService>(mockCheckoff);
      if (getIt.isRegistered<UserService>()) {
        getIt.unregister<UserService>();
      }
      getIt.registerSingleton<UserService>(mockUserService);

      // Rebuild the VM so its lazy `tryGet` fields pick up the new registrations.
      viewModel.dispose();
      viewModel = UnifiedShoppingViewModel();
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ShoppingCheckoffPantryService>()) {
        getIt.unregister<ShoppingCheckoffPantryService>();
      }
      if (getIt.isRegistered<UserService>()) {
        getIt.unregister<UserService>();
      }
    });

    test(
      'toggleItemBought feeds the pre-toggle bought-state as wasBought to the '
      'pantry seam',
      () async {
        // Active item starts NOT bought -> a fresh check-off, wasBought=false.
        final unbought = ShoppingListFactory.buildItem(
          id: 'item-1',
          name: 'Mjolk',
          bought: false,
        );
        mockShoppingService.setShoppingState(
          lists: [
            ShoppingListFactory.build(
              id: testListId,
              ownerId: testUserId,
              items: [unbought],
            ),
          ],
          activeListId: testListId,
          isInitialized: true,
          currentUserId: testUserId,
        );

        await viewModel.toggleItemBought('item-1');

        verify(
          () => mockCheckoff.onItemCheckedOff(
            testUserId,
            any(),
            wasBought: false,
          ),
        ).called(1);
      },
    );

    test(
      'toggleItemBought feeds wasBought=true when un-checking an already-bought '
      'item (lets the service no-op correctly)',
      () async {
        final bought = ShoppingListFactory.buildItem(
          id: 'item-1',
          name: 'Mjolk',
          bought: true,
        );
        mockShoppingService.setShoppingState(
          lists: [
            ShoppingListFactory.build(
              id: testListId,
              ownerId: testUserId,
              items: [bought],
            ),
          ],
          activeListId: testListId,
          isInitialized: true,
          currentUserId: testUserId,
        );

        await viewModel.toggleItemBought('item-1');

        verify(
          () => mockCheckoff.onItemCheckedOff(
            testUserId,
            any(),
            wasBought: true,
          ),
        ).called(1);
      },
    );

    test('autoAddBoughtToPantry reflects the user profile', () {
      when(
        () => mockUserService.currentUserProfile,
      ).thenReturn(_seamProfile(autoAdd: true, prompted: true));
      expect(viewModel.autoAddBoughtToPantry, isTrue);

      when(
        () => mockUserService.currentUserProfile,
      ).thenReturn(_seamProfile(autoAdd: false, prompted: true));
      expect(viewModel.autoAddBoughtToPantry, isFalse);
    });

    test('shouldShowFirstCheckoffPrompt is true only when not yet prompted AND '
        'not already opted in', () {
      // Never prompted, not opted in -> show.
      when(
        () => mockUserService.currentUserProfile,
      ).thenReturn(_seamProfile(autoAdd: false, prompted: false));
      expect(viewModel.shouldShowFirstCheckoffPrompt, isTrue);

      // Already opted in -> never prompt even if unprompted.
      when(
        () => mockUserService.currentUserProfile,
      ).thenReturn(_seamProfile(autoAdd: true, prompted: false));
      expect(viewModel.shouldShowFirstCheckoffPrompt, isFalse);

      // Already prompted -> never prompt again.
      when(
        () => mockUserService.currentUserProfile,
      ).thenReturn(_seamProfile(autoAdd: false, prompted: true));
      expect(viewModel.shouldShowFirstCheckoffPrompt, isFalse);
    });

    test('setAutoAddToPantry persists and notifies listeners', () async {
      var notified = 0;
      viewModel.addListener(() => notified++);

      await viewModel.setAutoAddToPantry(true);

      verify(() => mockUserService.setAutoAddToPantry(true)).called(1);
      expect(notified, greaterThanOrEqualTo(1));
    });

    test('markPantryAutoAddPrompted persists and notifies listeners', () async {
      var notified = 0;
      viewModel.addListener(() => notified++);

      await viewModel.markPantryAutoAddPrompted();

      verify(() => mockUserService.markPantryAutoAddPrompted()).called(1);
      expect(notified, greaterThanOrEqualTo(1));
    });
  });

  // BUT-948: multi-select bulk delete + undo. Intent: bulkRemoveItems removes
  // exactly the selected ids and reports success; restoreItems re-adds each.
  group('Bulk multi-select delete (BUT-948)', () {
    test('bulkRemoveItems removes each selected id and returns true', () async {
      final ok = await viewModel.bulkRemoveItems({'a', 'b', 'c'});

      expect(ok, isTrue);
      verify(() => mockShoppingService.removeItemFromActiveList('a')).called(1);
      verify(() => mockShoppingService.removeItemFromActiveList('b')).called(1);
      verify(() => mockShoppingService.removeItemFromActiveList('c')).called(1);
    });

    test(
      'bulkRemoveItems denies (no removal) when the user cannot edit',
      () async {
        mockPermissionService.setPermissionState(
          currentUserId: testUserId,
          userDisplayName: 'Test User',
          isAuthenticated: true,
          defaultHasPermission: false,
        );

        final ok = await viewModel.bulkRemoveItems({'a', 'b'});

        expect(
          ok,
          isFalse,
          reason: 'permission gate must block bulk delete entirely',
        );
        verifyNever(() => mockShoppingService.removeItemFromActiveList(any()));
      },
    );

    test('bulkRemoveItems returns false if any single removal fails', () async {
      when(
        () => mockShoppingService.removeItemFromActiveList('b'),
      ).thenAnswer((_) async => false);

      final ok = await viewModel.bulkRemoveItems({'a', 'b'});

      expect(
        ok,
        isFalse,
        reason:
            'a partial failure must be reported so the caller can skip '
            'offering an undo that would double-add the survivors',
      );
    });

    test('restoreItems re-adds every removed item', () async {
      final a = ShoppingListFactory.buildItem(id: 'a', name: 'Salt');
      final b = ShoppingListFactory.buildItem(id: 'b', name: 'Peppar');

      final ok = await viewModel.restoreItems([a, b]);

      expect(ok, isTrue);
      verify(
        () => mockShoppingService.addItemToActiveList(
          name: 'Salt',
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
          note: any(named: 'note'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
      verify(
        () => mockShoppingService.addItemToActiveList(
          name: 'Peppar',
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
          note: any(named: 'note'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
    });
  });

  // BUT-520: guards the BaseViewModel migration. The VM overrides error/hasError
  // to delegate to the shopping service, so a failure surfaces the service's
  // SPECIFIC message rather than BaseViewModel.executeAsync's generic fallback.
  // If the overrides were ever dropped, this would regress to a generic string.
  group('Error surfacing (BaseViewModel migration, BUT-520)', () {
    test('error and hasError delegate to the service, not base state', () {
      mockShoppingService.setShoppingState(
        lists: [testList],
        activeListId: testListId,
        isInitialized: true,
        currentUserId: testUserId,
        error: 'Kunde inte ladda inkopslistan',
      );

      expect(viewModel.hasError, isTrue);
      expect(viewModel.error, 'Kunde inte ladda inkopslistan');
    });

    test('no service error means the VM reports no error', () {
      expect(viewModel.hasError, isFalse);
      expect(viewModel.error, isNull);
    });

    // BUT-1628: _shoppingService OUTLIVES this ViewModel, so a late clearError()
    // cannot throw — the discriminating assertion is that the shared service is
    // never touched, i.e. a dead ViewModel can't wipe an error another live
    // listener is still showing. `returnsNormally` alone would be vacuous.
    test('clearError after dispose never reaches the shared service', () {
      final disposable = UnifiedShoppingViewModel();
      disposable.dispose();
      clearInteractions(mockShoppingService);

      disposable.clearError();

      verifyNever(() => mockShoppingService.clearError());
    });

    test(
      'a failed initialize rethrows and still surfaces the SERVICE error, not '
      "BaseViewModel's generic fallback",
      () async {
        // The dangerous quadrant: base executeAsync writes errorUnexpected to
        // its OWN _error and rethrows. Because the service records its own
        // specific error on init failure (as production does), the VM's
        // error/hasError overrides must shadow the generic base value. If the
        // overrides were dropped, viewModel.error would leak
        // AppLocale.current.errorUnexpected onto the shopping screen.
        mockShoppingService.setShoppingState(
          lists: [testList],
          activeListId: testListId,
          isInitialized: false,
          currentUserId: testUserId,
          error: 'Kunde inte initiera inkopslistan',
        );
        when(
          () => mockShoppingService.initialize(),
        ).thenThrow(Exception('init boom'));

        await expectLater(viewModel.initialize(), throwsA(isA<Exception>()));

        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, 'Kunde inte initiera inkopslistan');
        expect(viewModel.error, isNot(AppLocale.current.errorUnexpected));
      },
    );

    test(
      'addItemsFromRecipe propagates (rethrows) failures instead of swallowing '
      'them',
      () async {
        // BUT-520: addItemsFromRecipe wraps its work in executeAsync, which
        // RETHROWS on failure (unlike executeAsyncVoid, which returns false).
        // A future swap to the swallowing variant would silently drop bulk
        // recipe-import errors. Malformed ingredient data (missing 'name')
        // makes the operation throw inside executeAsync.
        await expectLater(
          viewModel.addItemsFromRecipe([<String, dynamic>{}]),
          throwsA(anything),
        );
      },
    );
  });
}
