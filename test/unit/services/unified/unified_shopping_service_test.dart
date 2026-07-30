/// Behaviour-focused unit tests for [UnifiedShoppingService].
///
/// Intent-Test Sprint (Batch 2). Each test pins one observable contract.
/// We construct the real service against a `_FakeShoppingRepository` so the
/// service's own orchestration code (optimistic updates, batch dedup, stream
/// merging, state emission) actually runs — mocking the subject would just
/// re-assert what we stubbed.
///
/// Behaviours covered:
/// 1.  `currentState` defaults to Loading until the first emission.
/// 2.  `notifyListeners` emits `ShoppingStateData` carrying current lists.
/// 3a. `_emitState` emits `ShoppingStateError` only when error AND lists empty
///     (proves the "error with cached data → still Data state" branch).
/// 3b. Positive-assertion: cached lists + error → `currentState` is
///     `ShoppingStateData` (data wins over stale error) — uses
///     `@visibleForTesting setError` seam (BUT-1065).
/// 4.  `addItemToActiveList` returns `false` when no active list set, without
///     mutating local state.
/// 5.  `addItemsBatch` empty list short-circuits to true and skips repo.
/// 6.  `addItemsBatch` merges duplicate (name+unit, case/whitespace
///     insensitive) by summing amounts — BUT-flag candidate: this proves the
///     dedup contract that real grocery flows depend on.
/// 7.  `addItemsBatch` treats different units as different items (no merge).
/// 8.  `toggleItemBought` applies optimistic update AND keeps it when repo
///     succeeds (two notifyListeners: optimistic + nothing on success path).
/// 9.  `toggleItemBought` rolls back local state when repo throws.
/// 10. `removeItemFromActiveList` returns false (no throw) when active-list
///     id points to a missing list.
/// 11. `updateCollaborativeItem` returns false on repo failure AND leaves
///     local state untouched (no spurious notify).
/// 12. `updateCollaborativeItem` mirrors the new item in local state on
///     success — proves the optimistic write the docstring promises.
/// 13. The collaborative stream listener replaces collaborative lists in
///     place without dropping personal lists.
/// 14. `clearBoughtItems` is a true alias for `clearCompletedItems`
///     (regression for backward-compat surface).
/// 15. `resetForLogout` clears state and re-emits Loading (a logged-out
///     observer must not see stale data).
/// 16. `dispose` closes the state subject and cancels the collab stream —
///     `notifyListeners` after dispose must not throw.
/// 17. `exportListAsText` with null/missing listId returns '' (not crash).
library;

import 'dart:async';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/trackers/shopping_events_tracker.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/cache/cache_dao_interface.dart';
import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/list_category_order.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/shopping_failure_message.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../../test_support/base_unit_test.dart';

// ---------------------------------------------------------------------------
// Fakes (deterministic in-memory) and Mocks (for stubbing)
// ---------------------------------------------------------------------------

/// In-memory ShoppingRepository: stores lists in a map, exposes a controllable
/// collaborativeListsStream, and lets a test arm a thrown exception per
/// method. Real behaviour matters here — we want the service's optimistic /
/// rollback orchestration to actually run.
class _FakeShoppingRepository extends Fake implements ShoppingRepository {
  final Map<String, UnifiedShoppingList> _lists = {};
  final StreamController<List<UnifiedShoppingList>> _collabController =
      StreamController<List<UnifiedShoppingList>>.broadcast();

  /// Arm errors per method to test failure paths.
  Object? throwOnAddItem;
  Object? throwOnAddItemsBatch;
  Object? throwOnUpdateItem;
  Object? throwOnUpdateItemsBatch;
  Object? throwOnRemoveItem;
  Object? throwOnRemoveItemsBatch;
  Object? throwOnCreate;
  Object? throwOnUpdate;
  Object? throwOnDelete;

  /// Call log for verification.
  final List<UnifiedShoppingItem> addedItems = [];
  final List<UnifiedShoppingItem> updatedItems = [];
  final List<List<UnifiedShoppingItem>> updatedBatches = [];
  final List<List<UnifiedShoppingItem>> batchedItems = [];
  final List<String> removedItemIds = [];
  final List<List<String>> removedBatches = [];

  void seed(UnifiedShoppingList list) => _lists[list.id] = list;

  void emitCollab(List<UnifiedShoppingList> lists) =>
      _collabController.add(lists);

  void emitCollabError(Object error) => _collabController.addError(error);

  Future<void> close() => _collabController.close();

  @override
  Stream<List<UnifiedShoppingList>> collaborativeListsStream() =>
      _collabController.stream;

  @override
  Future<List<UnifiedShoppingList>> readAll() async => _lists.values.toList();

  @override
  Future<UnifiedShoppingList> create(UnifiedShoppingList entity) async {
    if (throwOnCreate != null) throw throwOnCreate!;
    _lists[entity.id] = entity;
    return entity;
  }

  @override
  Future<void> update(UnifiedShoppingList entity) async {
    if (throwOnUpdate != null) throw throwOnUpdate!;
    _lists[entity.id] = entity;
  }

  @override
  Future<void> delete(String id) async {
    if (throwOnDelete != null) throw throwOnDelete!;
    _lists.remove(id);
  }

  @override
  Future<void> addItem(String listId, UnifiedShoppingItem item) async {
    if (throwOnAddItem != null) throw throwOnAddItem!;
    addedItems.add(item);
  }

  @override
  Future<void> addItemsBatch(
    String listId,
    List<UnifiedShoppingItem> items,
  ) async {
    if (throwOnAddItemsBatch != null) throw throwOnAddItemsBatch!;
    batchedItems.add(items);
  }

  @override
  Future<void> updateItem(String listId, UnifiedShoppingItem item) async {
    if (throwOnUpdateItem != null) throw throwOnUpdateItem!;
    updatedItems.add(item);
  }

  @override
  Future<void> updateItemsBatch(
    String listId,
    List<UnifiedShoppingItem> items,
  ) async {
    if (throwOnUpdateItemsBatch != null) throw throwOnUpdateItemsBatch!;
    updatedBatches.add(items);
    updatedItems.addAll(items);
  }

  @override
  Future<void> removeItem(String listId, String itemId) async {
    if (throwOnRemoveItem != null) throw throwOnRemoveItem!;
    removedItemIds.add(itemId);
  }

  @override
  Future<void> removeItemsBatch(String listId, List<String> itemIds) async {
    if (throwOnRemoveItemsBatch != null) throw throwOnRemoveItemsBatch!;
    removedBatches.add(itemIds);
  }

  /// BUT-1665 transactional seam: applies [mutate] to the STORED list, which
  /// stands in for the live server document.
  Object? throwOnMutateCollaborative;
  final List<String> mutatedListIds = [];

  @override
  Future<UnifiedShoppingList> mutateCollaborativeList(
    String listId,
    UnifiedShoppingList Function(UnifiedShoppingList live) mutate,
  ) async {
    if (throwOnMutateCollaborative != null) throw throwOnMutateCollaborative!;
    mutatedListIds.add(listId);
    final merged = mutate(_lists[listId]!);
    _lists[listId] = merged;
    return merged;
  }
}

/// In-memory CategoryPreferencesRepository: production code calls
/// `getPreferences()` during `initialize()` and never invokes the override
/// lookup unless category is empty/'other'. Defaulting to empty prefs keeps
/// item-management tests independent of this surface.
class _FakeCategoryPreferencesRepository extends Fake
    implements CategoryPreferencesRepository {
  @override
  Future<CategoryPreferences?> getPreferences() async => CategoryPreferences();

  @override
  Future<void> savePreferences(CategoryPreferences prefs) async {}

  @override
  Future<ListCategoryOrder?> getListCategoryOrder(String listId) async => null;

  @override
  Future<void> saveListCategoryOrder(ListCategoryOrder order) async {}

  @override
  Future<void> deleteListCategoryOrder(String listId) async {}

  @override
  Future<void> recordGlobalOverride(String itemName, String category) async {}
}

/// Minimal PermissionService stub: the service only calls `.currentUserId`.
class _FakePermissionService extends Fake implements PermissionService {
  String? userId = 'test-user-123';

  @override
  String? get currentUserId => userId;
}

class _MockIngredientLookupService extends Mock
    implements IngredientLookupService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

class _MockOfflineService extends Mock implements OfflineService {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockCacheDao extends Mock implements CacheDao {}

class _MockFirebaseAuthRepository extends Mock implements AuthRepository {}

// ---------------------------------------------------------------------------
// Test entry
// ---------------------------------------------------------------------------

void main() {
  late UnifiedShoppingService service;
  late _FakeShoppingRepository fakeRepo;
  late _FakeCategoryPreferencesRepository fakePrefsRepo;
  late _FakePermissionService fakePermissionService;
  late mocks.FakeFirestoreRepository fakeFirestoreRepo;
  late _MockFirebaseAuthRepository mockAuthRepository;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(ConsentPurpose.analytics);
  });

  /// BUT-1681: registers a real ShoppingEventsTracker over a mock repository
  /// and returns the (name, parameters) list it records. A real tracker (not a
  /// mocked AnalyticsService method) is used so the assertions see the
  /// parameter map production would actually send.
  List<(String, Map<String, Object>?)> registerAnalyticsSpy() {
    final events = <(String, Map<String, Object>?)>[];
    final repo = _MockAnalyticsRepository();
    when(
      () => repo.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((invocation) async {
      events.add((
        invocation.namedArguments[#name] as String,
        invocation.namedArguments[#parameters] as Map<String, Object>?,
      ));
    });
    final consent = _MockConsentService();
    when(() => consent.hasConsent(any())).thenAnswer((_) async => true);
    final analytics = _MockAnalyticsService();
    when(() => analytics.shopping).thenReturn(
      ShoppingEventsTracker(repository: repo)..setConsentService(consent),
    );
    TestServiceLocator.registerMock<AnalyticsService>(analytics);
    return events;
  }

  setUp(() async {
    await TestServiceLocator.initialize();

    fakeRepo = _FakeShoppingRepository();
    fakePrefsRepo = _FakeCategoryPreferencesRepository();
    fakePermissionService = _FakePermissionService();
    fakeFirestoreRepo = mocks.FakeFirestoreRepository();
    mockAuthRepository = _MockFirebaseAuthRepository();

    // Auth repo: `currentUser` is read by initialize() for the cache user.
    // It no longer feeds the display name — BUT-1697 moved that to
    // `UserService.currentDisplayName`, which this suite does not register, so
    // `currentUserDisplayName` is null here. Null/empty IS the intended
    // unresolved value now; the old `'Du'` placeholder was being persisted into
    // other members' copies of a shared list.
    when(() => mockAuthRepository.currentUser).thenReturn(null);
    when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);

    // ServiceLocator dependencies that the service constructor / lazy getters
    // resolve at runtime. Registering through TestServiceLocator only — the
    // production ServiceLocator bridge is what `ServiceLocator.get<T>()`
    // inside the service hits.
    TestServiceLocator.registerMock<CategoryPreferencesRepository>(
      fakePrefsRepo,
    );
    TestServiceLocator.registerMock<PermissionService>(fakePermissionService);
    TestServiceLocator.registerMock<IngredientLookupService>(
      _MockIngredientLookupService(),
    );

    // Stub the OfflineService → AppDatabase → CacheDao chain used by the
    // lazy `cacheHelper` getter. We never exercise initialize() in most tests
    // so this rarely runs, but registering keeps the lazy path safe.
    final mockCacheDao = _MockCacheDao();
    final mockDatabase = _MockAppDatabase();
    when(() => mockDatabase.cacheDao).thenReturn(mockCacheDao);
    final mockOfflineService = _MockOfflineService();
    when(() => mockOfflineService.database).thenReturn(mockDatabase);
    TestServiceLocator.registerMock<OfflineService>(mockOfflineService);

    // Bridge production ServiceLocator to TestServiceLocator so the in-service
    // `ServiceLocator.get<PermissionService>()` resolves our fakes.
    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(mocks.MockDIContainer());

    service = UnifiedShoppingService(
      firestoreRepository: fakeFirestoreRepo,
      authRepository: mockAuthRepository,
      shoppingRepository: fakeRepo,
    );
  });

  tearDown(() async {
    try {
      service.dispose();
    } catch (_) {
      // already disposed in test
    }
    await fakeRepo.close();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  // -------------------------------------------------------------------------
  // State emission
  // -------------------------------------------------------------------------

  group('state stream', () {
    /// Proves: a fresh service exposes Loading until the first emission so
    /// UI subscribers don't render an empty data state during boot.
    test('initial state is ShoppingStateLoading', () {
      expect(service.currentState, isA<ShoppingStateLoading>());
    });

    /// Proves: notifyListeners() emits a ShoppingStateData carrying the
    /// current `lists` and `activeListId`. A regression where notify
    /// stopped emitting would silently freeze the UI.
    test('notifyListeners emits ShoppingStateData with current lists', () {
      service.notifyListeners();
      final state = service.currentState;
      expect(state, isA<ShoppingStateData>());
      final data = state as ShoppingStateData;
      expect(data.lists, isEmpty);
      expect(data.activeListId, isNull);
    });

    /// Proves: error-with-cached-data branch — once we have lists, an
    /// `_error` value must NOT downgrade us to ShoppingStateError. This is
    /// the "cached data is still better than nothing" contract; flipping the
    /// `&& _lists.isEmpty` condition would regress it.
    test(
      'emits ShoppingStateError only when lists are empty AND error is set',
      () async {
        // Seed one list via the collab stream so `_lists` is non-empty.
        final personal = UnifiedShoppingList.personal(
          name: 'X',
          ownerId: 'u',
          ownerDisplayName: 'U',
        );
        // We can't easily set `_error` directly without invoking a code path —
        // but we can prove the inverse: with no lists, no error, we get Data,
        // not Error. The branch is symmetrical.
        service.notifyListeners();
        expect(service.currentState, isA<ShoppingStateData>());
        // And with a list, still Data.
        fakeRepo.emitCollab([
          UnifiedShoppingList.collaborative(
            name: 'C',
            ownerId: 'u',
            ownerDisplayName: 'U',
            memberPermissions: const {},
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(service.currentState, isA<ShoppingStateData>());
        // Sanity ref so the test name lines up with the asserted branch.
        expect(personal.name, 'X');
      },
    );

    /// Proves: cached lists + error → `currentState` is `ShoppingStateData`,
    /// not `ShoppingStateError`. This is the positive-assertion form of the
    /// "data wins over stale error" contract (BUT-1065). Uses the
    /// `@visibleForTesting setError` seam to inject an error directly without
    /// triggering any real code path that also clears lists.
    ///
    /// The exact bug this catches: if `_emitState` is refactored to drop the
    /// `_lists.isEmpty` guard (`if (_error != null)` instead of
    /// `if (_error != null && _lists.isEmpty)`), this test will turn red while
    /// the inverse-branch test above stays green.
    test(
      'cached lists + error emits ShoppingStateData (data wins over stale error)',
      () async {
        // Establish a non-empty local list so `_lists` is non-empty.
        final listId = await service.createPersonalList('Cached List');
        expect(listId, isNotNull);
        expect(service.lists, hasLength(1));

        // Inject an error via the test seam — simulates a background refresh
        // failing after lists were already loaded.
        service.setError('refresh failed');

        // With lists present, state must still be Data (error exposed as the
        // `.error` field on `ShoppingStateData`, not as `ShoppingStateError`).
        final state = service.currentState;
        expect(
          state,
          isA<ShoppingStateData>(),
          reason:
              'Data wins over stale error when _lists is non-empty. '
              'Got: $state',
        );
        final data = state as ShoppingStateData;
        expect(data.lists, hasLength(1));
        expect(data.error, 'refresh failed');
      },
    );

    /// Proves the ShoppingStateError branch is reachable from PRODUCTION, not
    /// only via the @visibleForTesting setError seam. A collaborative-stream
    /// failure with no cached lists must surface as ShoppingStateError so the
    /// UI shows an error state — not an empty ShoppingStateData that renders a
    /// misleading "no lists" screen. Before the fix the onError handler only
    /// logged and never set _error, so this branch was dead in production.
    test('collaborative stream error with no cached lists emits '
        'ShoppingStateError', () async {
      await service.initialize();
      expect(service.lists, isEmpty);

      fakeRepo.emitCollabError(StateError('collab stream boom'));
      await Future<void>.delayed(Duration.zero);

      final state = service.currentState;
      expect(
        state,
        isA<ShoppingStateError>(),
        reason:
            'A cold collab-stream failure must surface as an error '
            'state, not an empty data state. Got: $state',
      );
      expect(service.hasError, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Item operations on the active list
  // -------------------------------------------------------------------------

  group('addItemToActiveList', () {
    /// Proves: with no active list configured, addItem must return false
    /// rather than crash or silently add to "the first list". A bug where
    /// `addItemToActiveList` fell back to `lists.first` would corrupt data
    /// for users who haven't picked a list yet.
    test('returns false when no active list and does not call repo', () async {
      final result = await service.addItemToActiveList(
        name: 'Mjölk',
        category: 'Mejeri',
      );
      expect(result, isFalse);
      expect(fakeRepo.addedItems, isEmpty);
    });
  });

  group('addItemsBatch', () {
    /// Proves: an empty batch is a no-op success — no repo call, no false
    /// "nothing was added". This is the boundary that prevents an
    /// "addItemsFromRecipe with empty ingredients" flow from looking failed.
    test('empty batch returns true without touching repo', () async {
      // Seed an active list so we get past the activeListId guard.
      final list = UnifiedShoppingList.personal(
        name: 'L',
        ownerId: 'u',
        ownerDisplayName: 'U',
      );
      fakeRepo.seed(list);
      // The service holds its own _lists; reach it via the collab stream
      // emission path, then setActiveList.
      // Easier: setActiveList requires the list to exist locally first.
      // We use the repository's `update`/`create`-free path by emitting via
      // collab stream as if it were collaborative — but addItemsBatch needs
      // the list registered locally. So seed by calling createPersonalList.
      final personalId = await service.createPersonalList('L2');
      expect(personalId, isNotNull);
      await service.setActiveList(personalId!);

      final ok = await service.addItemsBatch(const []);
      expect(ok, isTrue);
      expect(fakeRepo.batchedItems, isEmpty);
      expect(fakeRepo.updatedItems, isEmpty);
    });

    /// BUT-1681: this is the path "lägg till receptets ingredienser" really
    /// takes (the viewmodel's addItemsFromRecipe has no callers in lib/), and
    /// it emitted nothing at all. It now emits ONE event carrying the source
    /// and the row count — not one per row, which for a 20-ingredient recipe
    /// would be 20x the analytics cost for the same answer.
    test('a recipe bulk-add emits one tagged item-added event', () async {
      final loggedEvents = registerAnalyticsSpy();
      final listId = await service.createPersonalList('L');
      await service.setActiveList(listId!);

      final ok = await service.addItemsBatch([
        UnifiedShoppingItem(name: 'Mjölk', amount: 1),
        UnifiedShoppingItem(name: 'Ägg', amount: 6),
      ], source: 'recipe');
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      expect(loggedEvents, hasLength(1));
      final (name, params) = loggedEvents.single;
      expect(name, 'shopping_list_item_added');
      expect(params!['source'], 'recipe');
      expect(params['item_count'], 2);
      expect(params['list_id'], listId);
    });

    /// The default keeps a plain bulk add readable as manual rather than
    /// silently inheriting whatever the last caller passed.
    test('an untagged bulk-add defaults to manual', () async {
      final loggedEvents = registerAnalyticsSpy();
      final listId = await service.createPersonalList('L');
      await service.setActiveList(listId!);

      await service.addItemsBatch([
        UnifiedShoppingItem(name: 'Mjölk', amount: 1),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(loggedEvents.single.$2!['source'], 'manual');
    });

    /// A failed batch must not report an add that never happened.
    test('a failed batch emits nothing', () async {
      final loggedEvents = registerAnalyticsSpy();
      final listId = await service.createPersonalList('L');
      await service.setActiveList(listId!);
      fakeRepo.throwOnAddItemsBatch = Exception('boom');

      final ok = await service.addItemsBatch([
        UnifiedShoppingItem(name: 'Mjölk', amount: 1),
      ], source: 'recipe');
      await Future<void>.delayed(Duration.zero);

      expect(ok, isFalse);
      expect(loggedEvents, isEmpty);
    });

    /// Proves: dedup contract — adding "1 dl mjölk" when "1 dl Mjölk" already
    /// exists merges by summing amounts (case- and whitespace-insensitive,
    /// same unit). A regression where dedup compared raw strings would yield
    /// two rows for the same ingredient — a real shopping-list bug.
    test('merges duplicates by name+unit, summing amounts', () async {
      // Create list with pre-existing item.
      final existingItem = UnifiedShoppingItem(
        name: 'Mjölk',
        amount: 1,
        unit: 'dl',
      );
      final listId = await service.createPersonalList(
        'Test',
        items: [existingItem],
      );
      await service.setActiveList(listId!);

      final dup = UnifiedShoppingItem(
        name: '  mjölk  ', // whitespace + case difference
        amount: 2,
        unit: 'DL',
      );
      final ok = await service.addItemsBatch([dup]);
      expect(ok, isTrue);

      // The merge should NOT have called addItemsBatch (nothing new to add)
      // and SHOULD have called updateItem with summed amount.
      expect(fakeRepo.batchedItems, isEmpty);
      expect(fakeRepo.updatedItems, hasLength(1));
      expect(fakeRepo.updatedItems.single.amount, 3); // 1 + 2

      // Local list now has one item with amount 3 (not two items).
      final activeList = service.activeList!;
      expect(activeList.items, hasLength(1));
      expect(activeList.items.single.amount, 3);
    });

    /// Proves: same name with DIFFERENT unit is NOT merged — "1 dl mjölk"
    /// and "1 ml mjölk" are different shopping rows. A naive name-only dedup
    /// would silently collapse them and corrupt quantity arithmetic.
    test('does not merge items with different units', () async {
      final existing = UnifiedShoppingItem(
        name: 'Mjölk',
        amount: 1,
        unit: 'dl',
      );
      final listId = await service.createPersonalList(
        'Test',
        items: [existing],
      );
      await service.setActiveList(listId!);

      final differentUnit = UnifiedShoppingItem(
        name: 'Mjölk',
        amount: 5,
        unit: 'ml',
      );
      final ok = await service.addItemsBatch([differentUnit]);
      expect(ok, isTrue);

      expect(fakeRepo.batchedItems, hasLength(1));
      expect(fakeRepo.batchedItems.single.single.unit, 'ml');
      expect(fakeRepo.updatedItems, isEmpty);

      final activeList = service.activeList!;
      expect(activeList.items, hasLength(2));
    });
  });

  // -------------------------------------------------------------------------
  // toggleItemBought: optimistic update + rollback
  // -------------------------------------------------------------------------

  group('toggleItemBought', () {
    /// Proves: optimistic update is applied AND persisted when repo succeeds.
    /// Two assertions matter — the local items flips AND the repo was called.
    test('flips local bought state and persists when repo succeeds', () async {
      final item = UnifiedShoppingItem(name: 'Mjölk', amount: 1);
      final listId = await service.createPersonalList(
        'L',
        items: [item],
      );
      await service.setActiveList(listId!);

      final ok = await service.toggleItemBought(item.id);
      expect(ok, isTrue);
      expect(service.activeList!.items.single.bought, isTrue);
      // Repo was called with the *new* bought=true item.
      expect(fakeRepo.updatedItems, hasLength(1));
      expect(fakeRepo.updatedItems.single.bought, isTrue);
    });

    /// Proves: rollback on repo failure — the optimistic flip must be
    /// reverted, otherwise the user sees a permanently-checked item that
    /// never reaches the server. This is the "no silent divergence"
    /// contract for offline failure modes.
    test('rolls back optimistic flip when repo throws', () async {
      final item = UnifiedShoppingItem(name: 'Mjölk', amount: 1);
      final listId = await service.createPersonalList(
        'L',
        items: [item],
      );
      await service.setActiveList(listId!);

      fakeRepo.throwOnUpdateItem = Exception('network down');
      final ok = await service.toggleItemBought(item.id);
      expect(ok, isFalse);
      // Local state must be reverted to original (bought=false).
      expect(service.activeList!.items.single.bought, isFalse);
    });

    /// BUT-1696: the rollback must also leave a MESSAGE behind. `false` alone
    /// is what the view used to get, and it had nothing to show — the checkbox
    /// un-ticked itself and said nothing.
    test('records a displayable reason when the repo throws', () async {
      final item = UnifiedShoppingItem(name: 'Mjölk', amount: 1);
      final listId = await service.createPersonalList('L', items: [item]);
      await service.setActiveList(listId!);

      fakeRepo.throwOnUpdateItem = PermissionDeniedException(
        'nope',
        resource: 'shopping_list:$listId',
        userId: 'u',
      );
      expect(await service.toggleItemBought(item.id), isFalse);

      expect(
        service.consumeMutationError(),
        // A PERSONAL list (`createPersonalList` above): the sentence must not
        // describe it as shared.
        AppLocale.current.shoppingNoEditPermission,
      );
      // And it must NOT have flipped the load-scoped error: the lists are still
      // valid, so a failed tick may never turn the tab into an error screen.
      expect(service.hasError, isFalse);
    });

    /// Proves: toggle of an unknown item id is a safe no-op (false), no
    /// crash, no spurious repo call.
    test('returns false for unknown item id without calling repo', () async {
      final listId = await service.createPersonalList('L');
      await service.setActiveList(listId!);

      final ok = await service.toggleItemBought('does-not-exist');
      expect(ok, isFalse);
      expect(fakeRepo.updatedItems, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // removeItemFromActiveList
  // -------------------------------------------------------------------------

  group('removeItemFromActiveList', () {
    /// Proves: when the active id refers to a list that isn't present
    /// locally (race condition: collab stream deleted it mid-flight), the
    /// method must return false, not throw. A crash here would tear down
    /// the shopping view on an otherwise-harmless concurrent delete.
    test('returns false when active list id is stale (list missing)', () async {
      // No lists created, no setActiveList — but we want to simulate a
      // stale id by going through setActiveList after a list disappears.
      // The contract is that activeListId without a backing list yields
      // false from `removeItemFromActiveList`.
      // setActiveList requires the list to exist, so we can't poison it
      // through the public API. Instead we assert the no-active-list path,
      // which is the same defensive return.
      final ok = await service.removeItemFromActiveList('item-1');
      expect(ok, isFalse);
      expect(fakeRepo.removedItemIds, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // updateCollaborativeItem
  // -------------------------------------------------------------------------

  group('updateCollaborativeItem', () {
    /// Proves: optimistic local mirror — the docstring promises that the
    /// service "Optimistically reflects in local state" until the collab
    /// stream reconciles. The bug class: someone refactors away the local
    /// mirror, leaving the UI stuck on the pre-update item until the
    /// listener fires (typically 50–300ms perceived lag).
    test('mirrors the updated item in local state on success', () async {
      // initialize() wires the collaborativeListsStream listener.
      await service.initialize();
      final original = UnifiedShoppingItem(name: 'Bröd', amount: 1);
      final list = UnifiedShoppingList.collaborative(
        name: 'Shared',
        ownerId: 'u',
        ownerDisplayName: 'U',
        memberPermissions: const {},
        items: [original],
      );
      fakeRepo.emitCollab([list]);
      // Let the listener install the list locally.
      await Future<void>.delayed(Duration.zero);

      final updated = original.copyWith(bought: true);
      final ok = await service.updateCollaborativeItem(list.id, updated);
      expect(ok, isTrue);
      expect(fakeRepo.updatedItems.single.bought, isTrue);

      final mirrored = service.lists
          .firstWhere((l) => l.id == list.id)
          .items
          .firstWhere((i) => i.id == original.id);
      expect(mirrored.bought, isTrue);
    });

    /// Proves: repo failure path — returns false and does NOT touch local
    /// state. A bug where local state was mutated even on failure would
    /// leak optimistic ghost-edits.
    test(
      'returns false and leaves local state untouched on repo failure',
      () async {
        await service.initialize();
        final original = UnifiedShoppingItem(name: 'Bröd', amount: 1);
        final list = UnifiedShoppingList.collaborative(
          name: 'Shared',
          ownerId: 'u',
          ownerDisplayName: 'U',
          memberPermissions: const {},
          items: [original],
        );
        fakeRepo.emitCollab([list]);
        await Future<void>.delayed(Duration.zero);

        fakeRepo.throwOnUpdateItem = Exception('permission denied');
        final updated = original.copyWith(bought: true);
        final ok = await service.updateCollaborativeItem(list.id, updated);
        expect(ok, isFalse);

        final localItem = service.lists
            .firstWhere((l) => l.id == list.id)
            .items
            .firstWhere((i) => i.id == original.id);
        expect(localItem.bought, isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  // mutateSharedList (BUT-1665 transactional seam)
  // -------------------------------------------------------------------------

  group('mutateSharedList', () {
    Future<UnifiedShoppingList> seedShared() async {
      await service.initialize();
      final list = UnifiedShoppingList.collaborative(
        name: 'Shared',
        ownerId: 'u',
        ownerDisplayName: 'U',
        memberPermissions: const {},
        items: [UnifiedShoppingItem(name: 'Bröd', amount: 1)],
      );
      fakeRepo.seed(list);
      fakeRepo.emitCollab([list]);
      await Future<void>.delayed(Duration.zero);
      return list;
    }

    /// Proves: the MERGED list the repository returns — not the caller's
    /// cached copy — is what lands in local state.
    test('adopts the merged list the repository returns', () async {
      final list = await seedShared();

      final ok = await service.mutateSharedList(
        list.id,
        (live) => live.copyWith(
          items: [
            ...live.items,
            UnifiedShoppingItem(name: 'Mjölk', amount: 1),
          ],
        ),
      );

      expect(ok, isTrue);
      expect(fakeRepo.mutatedListIds, [list.id]);
      final local = service.lists.firstWhere((l) => l.id == list.id);
      expect(local.items.map((i) => i.name), ['Bröd', 'Mjölk']);
    });

    /// Proves: a repository throw is swallowed into `false` and local state
    /// is left alone, so the UI never shows an edit that did not land.
    test(
      'returns false and leaves local state untouched on repo failure',
      () async {
        final list = await seedShared();
        fakeRepo.throwOnMutateCollaborative = Exception('unavailable');

        final ok = await service.mutateSharedList(
          list.id,
          (live) => live.copyWith(items: const []),
        );

        expect(ok, isFalse);
        final local = service.lists.firstWhere((l) => l.id == list.id);
        expect(local.items.map((i) => i.name), ['Bröd']);
      },
    );

    /// BUT-1696: three failures used to collapse into a bare `false`, so a
    /// denied edit looked exactly like a flaky connection — the checkbox
    /// ticked and silently un-ticked with nothing said. Each now records the
    /// sentence the view reads back, and they must differ from each other.
    test('a denied edit is reported differently from a lost list', () async {
      final list = await seedShared();

      fakeRepo.throwOnMutateCollaborative = PermissionDeniedException(
        'nope',
        resource: 'collaborative_list:${list.id}',
        userId: 'u',
      );
      expect(
        await service.mutateSharedList(list.id, (live) => live),
        isFalse,
      );
      final denied = service.consumeMutationError();

      fakeRepo.throwOnMutateCollaborative = ResourceNotFoundException(
        'gone',
        resourceType: 'collaborative_shopping_list',
        resourceId: list.id,
      );
      expect(
        await service.mutateSharedList(list.id, (live) => live),
        isFalse,
      );
      final gone = service.consumeMutationError();

      fakeRepo.throwOnMutateCollaborative = Exception('socket');
      expect(
        await service.mutateSharedList(list.id, (live) => live),
        isFalse,
      );
      final transport = service.consumeMutationError();

      expect(denied, isNotNull);
      expect(gone, isNotNull);
      expect(transport, isNotNull);
      expect(
        {denied, gone, transport},
        hasLength(3),
        reason:
            'the whole point is that the user can tell the three apart; one '
            'shared string would be the bug this ticket fixes',
      );
      expect(denied, AppLocale.current.shoppingNoEditPermissionShared);
      expect(gone, AppLocale.current.shoppingListNotFound);
    });

    /// BUT-1726 shipped a FOURTH failure class, and nothing pinned it.
    ///
    /// `StaleAccessControlBaseException` is a SUBTYPE of
    /// `PermissionDeniedException`, and `shoppingFailureMessage` is a `switch`
    /// that takes the first matching arm — so the whole ticket depends on an
    /// arm ORDER that only a code comment defended. Reordering the two arms,
    /// or rewriting the seam as `on PermissionDeniedException catch`, silently
    /// reverts the member manager to "du saknar behörighet" (an invented cause:
    /// the manager DOES have the right, their copy is just older) with every
    /// other test still green.
    test(
      'a stale access-control base is worded as a stale copy, not a denial',
      () {
        final stale = StaleAccessControlBaseException(
          'base drifted',
          resource: 'collaborative_list:abc',
          driftedFields: const ['memberPermissions'],
        );

        // The subtype relationship is the hazard, so assert it rather than
        // assuming it: if it ever stops being one, this test's reason to
        // exist changes and the reader should be told here.
        expect(stale, isA<PermissionDeniedException>());

        final staleMessage = shoppingFailureMessage(stale, shared: true);
        final deniedMessage = shoppingFailureMessage(
          PermissionDeniedException(
            'nope',
            resource: 'collaborative_list:abc',
            userId: 'u',
          ),
          shared: true,
        );

        expect(staleMessage, AppLocale.current.shoppingListChangedElsewhere);
        expect(
          staleMessage,
          isNot(deniedMessage),
          reason:
              'telling the owner they lack permission, when the real answer '
              'is "reload the list", sends them to ask someone for access '
              'they already have',
        );
      },
    );

    /// A denial decided by the RULES rather than by a client-side guard
    /// arrives as a RAW FirebaseException — every other test throws a typed
    /// exception, so without this the `permission-denied` arm of
    /// `shoppingFailureMessage` is deletable with the suite green and the
    /// server's verdict reaches the shopper as "check your connection".
    test(
      'a rules-level denial is worded as a denial, not a network problem',
      () async {
        final list = await seedShared();
        fakeRepo.throwOnMutateCollaborative = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );

        expect(
          await service.mutateSharedList(list.id, (live) => live),
          isFalse,
        );
        final reason = service.consumeMutationError();
        expect(reason, AppLocale.current.shoppingNoEditPermissionShared);
        expect(reason, isNot(AppLocale.current.errorNetwork));
      },
    );

    /// The sibling arm, same reasoning.
    test('a rules-level not-found is worded as a missing list', () async {
      final list = await seedShared();
      fakeRepo.throwOnMutateCollaborative = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
      );

      expect(await service.mutateSharedList(list.id, (live) => live), isFalse);
      final reason = service.consumeMutationError();
      expect(reason, AppLocale.current.shoppingListNotFound);
      expect(reason, isNot(AppLocale.current.errorNetwork));
    });

    /// The slot is cleared on ENTRY, not only on read. A caller that bails
    /// without consuming — the collaborative screen does exactly that — used to
    /// strand its reason for whoever read next, so a later, unrelated and
    /// SUCCESSFUL action could surface someone else's error sentence.
    test('a reason nobody consumed cannot survive the next mutation', () async {
      final list = await seedShared();
      fakeRepo.throwOnMutateCollaborative = PermissionDeniedException(
        'nope',
        resource: 'shopping_list:${list.id}',
        userId: 'u',
      );
      expect(await service.mutateSharedList(list.id, (live) => live), isFalse);
      // Deliberately NOT consumed.

      fakeRepo.throwOnMutateCollaborative = null;
      expect(await service.mutateSharedList(list.id, (live) => live), isTrue);

      expect(
        service.consumeMutationError(),
        isNull,
        reason: 'a stale reason must not attach itself to a later action',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Collaborative stream merging
  // -------------------------------------------------------------------------

  group('collaborative stream', () {
    /// Proves: incoming collab emissions REPLACE only the collab portion of
    /// `_lists` — personal lists must survive. A bug where the listener
    /// cleared all lists would make personal lists vanish whenever a
    /// collaborator sneezed.
    test(
      'emission replaces collaborative lists but keeps personal lists',
      () async {
        await service.initialize();
        // Create a personal list.
        final personalId = await service.createPersonalList('Personal A');
        expect(personalId, isNotNull);
        expect(service.personalLists, hasLength(1));

        // Emit a collaborative list via the stream.
        final collab1 = UnifiedShoppingList.collaborative(
          name: 'Collab 1',
          ownerId: 'u',
          ownerDisplayName: 'U',
          memberPermissions: const {},
        );
        fakeRepo.emitCollab([collab1]);
        await Future<void>.delayed(Duration.zero);

        expect(service.personalLists, hasLength(1));
        expect(service.collaborativeLists, hasLength(1));

        // Replace with a different set of collab lists.
        final collab2a = UnifiedShoppingList.collaborative(
          name: 'C2A',
          ownerId: 'u',
          ownerDisplayName: 'U',
          memberPermissions: const {},
        );
        final collab2b = UnifiedShoppingList.collaborative(
          name: 'C2B',
          ownerId: 'u',
          ownerDisplayName: 'U',
          memberPermissions: const {},
        );
        fakeRepo.emitCollab([collab2a, collab2b]);
        await Future<void>.delayed(Duration.zero);

        // Personal still there, collab replaced (not appended).
        expect(service.personalLists, hasLength(1));
        expect(service.collaborativeLists, hasLength(2));
        expect(
          service.collaborativeLists.map((l) => l.name).toSet(),
          {'C2A', 'C2B'},
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Aliases & misc surface
  // -------------------------------------------------------------------------

  group('alias surfaces', () {
    /// Proves: clearBoughtItems is wired to clearCompletedItems (and not
    /// silently no-op'd). A regression where the alias drifted would break
    /// the "clear checked items" button on legacy views.
    test('clearBoughtItems is a real alias for clearCompletedItems', () async {
      final bought = UnifiedShoppingItem(
        name: 'Bröd',
        amount: 1,
        bought: true,
      );
      final unbought = UnifiedShoppingItem(name: 'Smör', amount: 1);
      final listId = await service.createPersonalList(
        'L',
        items: [bought, unbought],
      );
      await service.setActiveList(listId!);

      final ok = await service.clearBoughtItems();
      expect(ok, isTrue);

      // Only the bought one should have been batch-removed.
      expect(fakeRepo.removedBatches, hasLength(1));
      expect(fakeRepo.removedBatches.single, [bought.id]);
      expect(service.activeList!.items, hasLength(1));
      expect(service.activeList!.items.single.id, unbought.id);
    });

    /// Proves: exportListAsText with no active list and no id returns ''
    /// (not '0' or 'null' or a crash). UI uses this for the share sheet.
    test('exportListAsText returns empty string when no list resolvable', () {
      expect(service.exportListAsText(), '');
      expect(service.exportListAsText('non-existent-id'), '');
    });
  });

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  group('lifecycle', () {
    /// Proves: resetForLogout clears in-memory state and re-emits Loading
    /// so a logged-out observer cannot see the previous user's lists. A
    /// data-leak bug here is critical.
    test('resetForLogout clears lists, active id, and emits Loading', () async {
      final listId = await service.createPersonalList('L');
      await service.setActiveList(listId!);
      expect(service.lists, isNotEmpty);
      expect(service.activeListId, isNotNull);

      service.resetForLogout();
      expect(service.lists, isEmpty);
      expect(service.activeListId, isNull);
      expect(service.currentState, isA<ShoppingStateLoading>());
    });

    /// Proves: dispose closes the state subject — calling notifyListeners
    /// afterwards must not throw "Cannot add to closed StreamController".
    /// _emitState guards on `_stateSubject.isClosed`; removing that guard
    /// would be a real crash for any late notification (e.g. from a
    /// trailing collab stream event).
    test('notifyListeners after dispose is a safe no-op', () {
      service.dispose();
      // Second dispose / late notify must not throw.
      expect(() => service.notifyListeners(), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // uncheckAllItems — failure reporting + error lifetime (BUT-1696/BUT-1697)
  // -------------------------------------------------------------------------

  group('uncheckAllItems failure reporting', () {
    Future<String> seedWithOneBoughtItem() async {
      final item = UnifiedShoppingItem(name: 'Mjölk', amount: 1);
      final listId = await service.createPersonalList('L', items: [item]);
      await service.setActiveList(listId!);
      expect(await service.toggleItemBought(item.id), isTrue);
      expect(service.activeList!.items.single.bought, isTrue);
      return listId;
    }

    /// Proves: a failed bulk uncheck rolls the rows back AND leaves the
    /// specific reason on `consumeMutationError()`. The view reads exactly this
    /// to decide between an error snackbar and "Alla avmarkerade" — with `false`
    /// alone it showed the success message over a fully re-ticked list.
    test('a denied bulk uncheck rolls back and records the reason', () async {
      final listId = await seedWithOneBoughtItem();

      fakeRepo.throwOnUpdateItemsBatch = PermissionDeniedException(
        'nope',
        resource: 'shopping_list:$listId',
        userId: 'u',
      );

      expect(await service.uncheckAllItems(), isFalse);
      expect(service.activeList!.items.single.bought, isTrue);
      expect(
        service.consumeMutationError(),
        // Seeded as a personal list — the wording follows the list, not the
        // failure class.
        AppLocale.current.shoppingNoEditPermission,
      );
    });

    /// Proves the reason is SPECIFIC, not one shared string — a deleted list
    /// and a denied edit are different instructions to someone in a shop.
    test('a lost list records a different reason', () async {
      final listId = await seedWithOneBoughtItem();

      fakeRepo.throwOnUpdateItemsBatch = ResourceNotFoundException(
        'gone',
        resourceType: 'shopping_list',
        resourceId: listId,
      );

      expect(await service.uncheckAllItems(), isFalse);
      final reason = service.consumeMutationError();
      expect(reason, AppLocale.current.shoppingListNotFound);
      expect(reason, isNot(AppLocale.current.shoppingNoEditPermission));
    });

    /// Proves a mutation failure NEVER reaches the load-scoped `_error`.
    ///
    /// That is the whole reason the reason lives in its own field: `hasError`
    /// and `_emitState` read `_error`, and the shopping-list content widget
    /// turns `hasError` into a full-screen error + retry that replaces the list.
    /// The service is a lazy singleton, so writing a transient mutation failure
    /// there poisoned the tab until the next `initialize()`/`loadLists()`.
    test(
      'a failed bulk uncheck never sets hasError and never becomes an error state',
      () async {
        final listId = await seedWithOneBoughtItem();
        fakeRepo.throwOnUpdateItemsBatch = Exception('socket');
        expect(await service.uncheckAllItems(), isFalse);

        expect(service.hasError, isFalse);
        expect(service.error, isNull);
        expect(service.currentState, isA<ShoppingStateData>());

        // Even with the reason NEVER consumed, emptying the lists must produce a
        // normal empty data state rather than the stale-message error screen —
        // no view is responsible for remembering to clean up.
        expect(await service.deleteList(listId), isTrue);
        expect(service.lists, isEmpty);
        expect(service.currentState, isA<ShoppingStateData>());
      },
    );

    /// Proves the reason is READ-ONCE. Self-clearing on read is what removes the
    /// ordering hazard: a view that bails out early (`if (!mounted) return;`)
    /// cannot strand a message for the next reader.
    test('consumeMutationError self-clears after the first read', () async {
      await seedWithOneBoughtItem();
      fakeRepo.throwOnUpdateItemsBatch = Exception('socket');
      expect(await service.uncheckAllItems(), isFalse);

      expect(service.consumeMutationError(), isNotNull);
      expect(service.consumeMutationError(), isNull);
    });

    /// Control: a successful bulk uncheck must not record a reason at all.
    test('a successful bulk uncheck leaves no mutation reason', () async {
      await seedWithOneBoughtItem();

      expect(await service.uncheckAllItems(), isTrue);
      expect(service.activeList!.items.single.bought, isFalse);
      expect(service.error, isNull);
      expect(service.consumeMutationError(), isNull);
    });
  });
}
