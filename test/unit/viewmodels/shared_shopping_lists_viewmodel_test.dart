/// Unit tests for [SharedShoppingListsViewModel].
///
/// This test proves that the viewmodel surfaces the right state to the UI
/// across three scenarios: successful load with lists, successful load with
/// an empty result, and a service error.
///
/// Intent per test:
///   1. loadSharedLists exposes the collaborative lists from the service and
///      notifies listeners — so the UI renders the actual list.
///   2. loadSharedLists leaves sharedLists empty and no error when the service
///      returns no collaborative lists — so the UI can show an empty state.
///   3. loadSharedLists sets hasError and sharedLists stays empty when the
///      service throws — so the UI shows an error instead of stale data.
///   4. refreshData re-invokes loadSharedLists and overwrites prior state —
///      so a pull-to-refresh correctly replaces old data.
library;

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/shared_shopping_lists_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UnifiedShoppingList _collabList(String id, {String name = 'Veckohandling'}) =>
    UnifiedShoppingList.collaborative(
      name: name,
      ownerId: 'owner-uid',
      ownerDisplayName: 'Anna',
      memberPermissions: const {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUnifiedShoppingService mockShoppingService;
  late SharedShoppingListsViewModel vm;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  // Build the VM fresh with the current mock state. The ctor fires
  // loadSharedLists() immediately, so we configure the mock BEFORE building.
  Future<SharedShoppingListsViewModel> buildVm() async {
    final v = SharedShoppingListsViewModel(
      shoppingService: mockShoppingService,
    );
    // Wait for the constructor-triggered loadSharedLists to complete.
    await Future<void>.delayed(Duration.zero);
    return v;
  }

  tearDown(() {
    vm.dispose();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  // -------------------------------------------------------------------------
  // 1. Happy path — lists returned
  // -------------------------------------------------------------------------

  test(
    'loadSharedLists exposes collaborative lists and notifies listeners on success',
    () async {
      final list1 = _collabList('list-1', name: 'Handla torsdag');
      final list2 = _collabList('list-2', name: 'Grillkväll');

      mockShoppingService = MockUnifiedShoppingService();
      mockShoppingService.setShoppingState(
        collaborativeLists: [list1, list2],
      );
      when(() => mockShoppingService.loadLists()).thenAnswer((_) async {});

      var notificationCount = 0;
      vm = SharedShoppingListsViewModel(shoppingService: mockShoppingService);
      vm.addListener(() => notificationCount++);
      await Future<void>.delayed(Duration.zero);

      expect(
        vm.sharedLists,
        hasLength(2),
        reason: 'Both collaborative lists must be exposed after load.',
      );
      expect(
        vm.sharedLists.map((l) => l.name),
        containsAll(['Handla torsdag', 'Grillkväll']),
      );
      expect(vm.hasError, isFalse);
      expect(
        notificationCount,
        greaterThanOrEqualTo(1),
        reason: 'At least one notifyListeners call must reach listeners.',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 2. Empty-list path
  // -------------------------------------------------------------------------

  test(
    'loadSharedLists leaves sharedLists empty and no error when service has no collaborative lists',
    () async {
      mockShoppingService = MockUnifiedShoppingService();
      mockShoppingService.setShoppingState(collaborativeLists: []);
      when(() => mockShoppingService.loadLists()).thenAnswer((_) async {});

      vm = await buildVm();

      expect(
        vm.sharedLists,
        isEmpty,
        reason:
            'Empty service result must yield an empty list, not stale data.',
      );
      expect(
        vm.hasError,
        isFalse,
        reason:
            'An empty result is not an error — UI should render empty state.',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 3. Error path
  // -------------------------------------------------------------------------

  test(
    'loadSharedLists sets hasError and keeps sharedLists empty when service throws',
    () async {
      mockShoppingService = MockUnifiedShoppingService();
      mockShoppingService.setShoppingState(collaborativeLists: []);
      when(
        () => mockShoppingService.loadLists(),
      ).thenThrow(Exception('Network timeout'));

      vm = await buildVm();

      expect(
        vm.hasError,
        isTrue,
        reason:
            'A service exception must surface as hasError=true so the UI shows '
            'an error state instead of silently showing nothing.',
      );
      expect(
        vm.sharedLists,
        isEmpty,
        reason:
            'On error the list must stay empty — no stale partial data shown.',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 4. refreshData re-fetches and overwrites prior state
  // -------------------------------------------------------------------------

  test(
    'refreshData overwrites stale list when new data is available',
    () async {
      final staleList = _collabList('old', name: 'Gammalt');
      final freshList = _collabList('new', name: 'Nytt');

      mockShoppingService = MockUnifiedShoppingService();
      // First load returns the stale list.
      mockShoppingService.setShoppingState(collaborativeLists: [staleList]);
      when(() => mockShoppingService.loadLists()).thenAnswer((_) async {});

      vm = await buildVm();
      expect(vm.sharedLists.map((l) => l.name), contains('Gammalt'));

      // Simulate a refresh where the service now returns fresh data.
      mockShoppingService.setShoppingState(collaborativeLists: [freshList]);
      await vm.refreshData();

      expect(
        vm.sharedLists.map((l) => l.name),
        contains('Nytt'),
        reason: 'refreshData must replace stale lists with the new result.',
      );
      expect(vm.sharedLists.map((l) => l.name), isNot(contains('Gammalt')));
    },
  );
}
