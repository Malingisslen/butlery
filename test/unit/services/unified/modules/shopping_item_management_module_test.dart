/// Behaviour-focused unit tests for [ShoppingItemManagementModule].
///
/// Intent-Test Sprint (Batch 7). The module is the CRUD core that
/// `UnifiedShoppingService` delegates to; tests here pin its observable
/// contract on items: add / update / remove / toggle / clearCompleted /
/// uncheckAll / batch dedup / addItemsFromRecipe and the active-list
/// resolution + optimistic-rollback semantics.
///
/// The subject is constructed directly with a `_FakeShoppingRepository`,
/// a real `ShoppingCategoryPreferencesModule` over a fake prefs repo, and
/// a mutable `lists` list — so the module's own state mutations and
/// rollbacks actually run end-to-end. Mocking the subject would prove
/// nothing.
///
/// Behaviours covered:
/// 1.  `activeList` returns null when no active id is set.
/// 2.  `activeList` returns null when active id points to a missing list
///     (no throw — production wraps `firstWhere` in try/catch).
/// 3.  `activeList` returns the matching list when present.
/// 4.  `addItemToList` mirrors the new item into local state, calls
///     `notifyListeners`, and returns the item id.
/// 5.  `addItemToList` returns null on repo failure (no notify, no
///     local-state mutation).
/// 6.  `addItemToActiveList` returns false when no active list is set.
/// 7.  `addItemToActiveList` auto-categorizes via IngredientLookupService
///     when category is empty or 'other'.
/// 8.  `addItemToActiveList` respects user override before lookup.
/// 9.  `addItemToActiveList` short-circuits to false on repo failure
///     (caught in try/catch — no spurious mutation, no rethrow).
/// 10. `addItemsBatchToActiveList` empty input returns true without
///     touching repo (no spurious false).
/// 11. `addItemsBatchToActiveList` merges duplicates by name+unit
///     (case + whitespace insensitive) and SUMS amounts (BUT-1085 family
///     dedup contract).
/// 12. `addItemsBatchToActiveList` does NOT merge same-name across
///     different units (otherwise quantity arithmetic corrupts).
/// 13. `updateItemInActiveList` returns false when item id is missing
///     from active list (no repo call).
/// 14. `updateItemInActiveList` preserves untouched fields via copyWith
///     (only-name update keeps amount/unit/category).
/// 15. `removeItemFromActiveList` returns false (not throw) when active
///     list id resolves to a missing list.
/// 16. `removeItemFromActiveList` returns false on repo failure
///     (silently caught) — verifies graceful degradation.
/// 17. `toggleItemBought` applies optimistic update BEFORE the repo
///     call, so UI sees the flip instantly.
/// 18. `toggleItemBought` ROLLS BACK local state when the repo throws —
///     this is the optimistic-rollback invariant that batch 7 was asked
///     to pin.
/// 18b.`toggleItemBought` REPORTS a distinct Swedish sentence per failure
///     kind (denied / list gone / transport) — BUT-1696. `reportFailure`
///     is wired in `buildModule()`; without it `_report` is a silent
///     no-op and these assertions would be vacuous.
/// 19. `clearCompletedItems` short-circuits with true (no repo call)
///     when nothing is bought — must not call `removeItemsBatch([])`.
/// 20. `clearCompletedItems` rolls back the bought items into local
///     state when the batch delete throws.
/// 21. `uncheckAllItems` short-circuits with true when nothing is bought.
/// 22. `uncheckAllItems` rolls back the original item shape (not just
///     bought=true; the whole snapshot) when the parallel update fails.
/// 22b.`uncheckAllItems` reports the SAME three-way mapping on failure and
///     reports nothing on success (BUT-1696/BUT-1697).
/// 23. `addItemsFromRecipe` empty list returns true without touching repo.
/// 24. `addItemsFromRecipe` accepts dynamic input (e.g. strings) and
///     wraps each in a `UnifiedShoppingItem` before batching.
library;

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/list_category_order.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/services/unified/modules/shopping_item_management_module.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../../../test_support/base_unit_test.dart';

// ---------------------------------------------------------------------------
// Fakes — deterministic in-memory; we want the module's orchestration to run.
// ---------------------------------------------------------------------------

class _FakeShoppingRepository extends Fake implements ShoppingRepository {
  // Arm errors per method for failure-mode tests.
  Object? throwOnAddItem;
  Object? throwOnAddItemsBatch;
  Object? throwOnUpdateItem;
  Object? throwOnUpdateItemsBatch;
  Object? throwOnRemoveItem;
  Object? throwOnRemoveItemsBatch;

  // Call log.
  final List<UnifiedShoppingItem> addedItems = [];
  final List<List<UnifiedShoppingItem>> batchedItems = [];
  final List<UnifiedShoppingItem> updatedItems = [];
  final List<List<UnifiedShoppingItem>> updatedBatches = [];
  final List<String> removedItemIds = [];
  final List<List<String>> removedBatches = [];

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
}

class _FakeCategoryPreferencesRepository extends Fake
    implements CategoryPreferencesRepository {
  CategoryPreferences? prefsToReturn = CategoryPreferences();

  @override
  Future<CategoryPreferences?> getPreferences() async => prefsToReturn;

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

class _MockIngredientLookupService extends Mock
    implements IngredientLookupService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IngredientData _ingredient({
  required String id,
  required String group,
}) {
  return IngredientData(
    id: id,
    swedish: id,
    english: id,
    group: group,
    properties: const <String>{},
    aliasesSv: const [],
    aliasesEn: const [],
    searchTerms: const [],
    status: 'verified',
  );
}

UnifiedShoppingList _seedList({
  String id = 'list-1',
  List<UnifiedShoppingItem>? items,
  ListType type = ListType.personal,
}) {
  return UnifiedShoppingList(
    id: id,
    name: 'L',
    ownerId: 'owner',
    ownerDisplayName: 'O',
    items: items ?? const [],
    type: type,
  );
}

// ---------------------------------------------------------------------------

void main() {
  late _FakeShoppingRepository fakeRepo;
  late _FakeCategoryPreferencesRepository fakePrefsRepo;
  late ShoppingCategoryPreferencesModule prefsModule;
  late _MockIngredientLookupService mockLookup;
  late List<UnifiedShoppingList> lists;
  late String? activeListId;
  late int notifyCalls;

  /// BUT-1696: every message the module hands back for display. Wired into
  /// `buildModule()` so the reporting half of the fix is never vacuous —
  /// leaving `reportFailure` null (the constructor default) made `_report`
  /// a no-op and the whole suite stayed green with the call deleted.
  late List<String> reported;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    fakeRepo = _FakeShoppingRepository();
    fakePrefsRepo = _FakeCategoryPreferencesRepository();
    prefsModule = ShoppingCategoryPreferencesModule(repository: fakePrefsRepo);
    await prefsModule.load(); // populate _preferences so overrides work
    mockLookup = _MockIngredientLookupService();

    // Default lookup behaviour: no match (returns empty IngredientLookupResult).
    when(() => mockLookup.lookupFromRaw(any())).thenAnswer(
      (_) async => IngredientLookupResult.fromLists(
        matched: const [],
        unmatched: const [],
      ),
    );

    // Bridge ServiceLocator for `_autoCategorize` which resolves
    // IngredientLookupService at runtime via the global locator.
    TestServiceLocator.registerMock<IngredientLookupService>(mockLookup);
    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(mocks.MockDIContainer());

    lists = <UnifiedShoppingList>[];
    activeListId = null;
    notifyCalls = 0;
    reported = <String>[];
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  ShoppingItemManagementModule buildModule() {
    return ShoppingItemManagementModule(
      repository: fakeRepo,
      lists: lists,
      getActiveListId: () => activeListId,
      notifyListeners: () => notifyCalls++,
      getCategoryPreferences: () => prefsModule,
      reportFailure: reported.add,
    );
  }

  // -------------------------------------------------------------------------
  // activeList resolution
  // -------------------------------------------------------------------------

  group('activeList', () {
    /// Proves: with no active id set, `activeList` is null (not the first
    /// list as a fallback) — a fallback would silently mutate the wrong
    /// list when the user hasn't selected one yet.
    test('returns null when no active id is set', () {
      lists.add(_seedList(id: 'a'));
      activeListId = null;
      expect(buildModule().activeList, isNull);
    });

    /// Proves: a stale active id (list deleted underneath us) returns null
    /// instead of throwing. The production code uses firstWhere in try/catch;
    /// a regression that dropped the catch would crash the UI.
    test('returns null when active id resolves to missing list', () {
      lists.add(_seedList(id: 'a'));
      activeListId = 'does-not-exist';
      expect(buildModule().activeList, isNull);
    });

    /// Proves the happy resolution — id → matching list — exists.
    test('returns the matching list when present', () {
      final l = _seedList(id: 'a');
      lists.add(l);
      activeListId = 'a';
      expect(buildModule().activeList?.id, 'a');
    });
  });

  // -------------------------------------------------------------------------
  // addItemToList
  // -------------------------------------------------------------------------

  group('addItemToList', () {
    /// Proves: success path calls repo, mirrors into local state,
    /// notifies, and returns the item id. A regression that forgot to
    /// notify would freeze the UI; one that returned null would mark
    /// the optimistic write as failed in the caller.
    test('mirrors into local state, notifies, returns item id', () async {
      lists.add(_seedList(id: 'L'));
      final id = await buildModule().addItemToList('L', 'Mjölk');

      expect(id, isNotNull);
      expect(fakeRepo.addedItems, hasLength(1));
      expect(fakeRepo.addedItems.single.name, 'Mjölk');
      expect(lists.first.items, hasLength(1));
      expect(lists.first.items.single.name, 'Mjölk');
      expect(notifyCalls, 1);
    });

    /// Proves: repo failure returns null AND leaves local state untouched
    /// (no spurious notify). The bug-shape this guards: a refactor that
    /// notifies before the await would leak an unmirrored item into UI.
    test('repo failure returns null and does not mutate state', () async {
      lists.add(_seedList(id: 'L'));
      fakeRepo.throwOnAddItem = StateError('boom');

      final id = await buildModule().addItemToList('L', 'Mjölk');

      expect(id, isNull);
      expect(lists.first.items, isEmpty);
      expect(notifyCalls, 0);
    });
  });

  // -------------------------------------------------------------------------
  // addItemToActiveList
  // -------------------------------------------------------------------------

  group('addItemToActiveList', () {
    /// Proves: no active list → false, no repo call. A regression that
    /// fell back to `lists.first` would corrupt data for users who haven't
    /// selected a list yet.
    test('returns false when no active list is set', () async {
      lists.add(_seedList(id: 'L'));
      activeListId = null;

      final ok = await buildModule().addItemToActiveList(name: 'Mjölk');

      expect(ok, isFalse);
      expect(fakeRepo.addedItems, isEmpty);
      expect(notifyCalls, 0);
    });

    /// Proves: auto-categorization runs when category is empty/'other' and
    /// uses the FIRST matched ingredient's group. A regression that picked
    /// the second match or skipped lookup would mis-categorise items —
    /// degrades the store-aisle ordering UX.
    test('auto-categorizes via lookup when category is empty/other', () async {
      lists.add(_seedList(id: 'L'));
      activeListId = 'L';

      when(() => mockLookup.lookupFromRaw(['Mjölk'])).thenAnswer(
        (_) async => IngredientLookupResult.fromLists(
          matched: [_ingredient(id: 'milk', group: 'protein/dairy')],
          unmatched: const [],
        ),
      );

      final ok = await buildModule().addItemToActiveList(
        name: 'Mjölk',
      ); // no category → auto

      expect(ok, isTrue);
      expect(fakeRepo.addedItems, hasLength(1));
      // The mapper maps 'protein/dairy' → dairy. We assert it isn't
      // ShoppingCategory.other to prove the lookup branch actually fired.
      expect(
        fakeRepo.addedItems.single.category,
        isNot(equals(ShoppingCategory.other)),
      );
    });

    /// Proves: user override beats lookup. Production checks prefs FIRST,
    /// short-circuiting the lookup; an inverted order would silently
    /// override the user's manual classification.
    test('user category override wins over lookup', () async {
      lists.add(_seedList(id: 'L'));
      activeListId = 'L';
      await prefsModule.setItemCategory('Bananer', ShoppingCategory.fruitVeg);

      // Lookup would say dairy if called — but it must NOT be called.
      when(() => mockLookup.lookupFromRaw(any())).thenAnswer(
        (_) async => IngredientLookupResult.fromLists(
          matched: [_ingredient(id: 'milk', group: 'protein/dairy')],
          unmatched: const [],
        ),
      );

      final ok = await buildModule().addItemToActiveList(name: 'Bananer');

      expect(ok, isTrue);
      expect(fakeRepo.addedItems.single.category, ShoppingCategory.fruitVeg);
      verifyNever(() => mockLookup.lookupFromRaw(any()));
    });

    /// Proves: repo failure is caught (try/catch around the orchestration)
    /// and surfaces as false. The bug-shape: a regression dropping the
    /// catch would crash the UI from a flaky network call.
    test(
      'returns false on repo failure without mutating local state',
      () async {
        lists.add(_seedList(id: 'L'));
        activeListId = 'L';
        fakeRepo.throwOnAddItem = StateError('boom');

        final ok = await buildModule().addItemToActiveList(name: 'Mjölk');

        expect(ok, isFalse);
        expect(lists.first.items, isEmpty);
        expect(notifyCalls, 0);
      },
    );
  });

  // -------------------------------------------------------------------------
  // addItemsBatchToActiveList — dedup + arithmetic contract
  // -------------------------------------------------------------------------

  group('addItemsBatchToActiveList', () {
    /// Proves: empty batch is a no-op success — must not call repo,
    /// must not return false. addItemsFromRecipe with no ingredients
    /// depends on this.
    test('empty batch returns true and skips repo', () async {
      lists.add(_seedList(id: 'L'));
      activeListId = 'L';

      final ok = await buildModule().addItemsBatchToActiveList(const []);

      expect(ok, isTrue);
      expect(fakeRepo.batchedItems, isEmpty);
      expect(fakeRepo.updatedItems, isEmpty);
    });

    /// Proves: dedup is by `name+unit` case-and-whitespace-insensitive,
    /// merges by SUMMING amounts. The mirrored test in batch 2
    /// (`unified_shopping_service_test`) pins the service-level surface;
    /// this pins the module surface so the contract can't drift between
    /// the two layers.
    test('merges duplicates by name+unit and sums amounts', () async {
      final existing = UnifiedShoppingItem(
        name: 'Mjölk',
        amount: 1,
        unit: 'dl',
      );
      lists.add(_seedList(id: 'L', items: [existing]));
      activeListId = 'L';

      final dup = UnifiedShoppingItem(
        name: '  mjölk  ', // whitespace + case
        amount: 2,
        unit: 'DL',
      );
      final ok = await buildModule().addItemsBatchToActiveList([dup]);

      expect(ok, isTrue);
      // No new add — only an update with the summed amount.
      expect(fakeRepo.batchedItems, isEmpty);
      expect(fakeRepo.updatedItems, hasLength(1));
      expect(fakeRepo.updatedItems.single.amount, 3); // 1 + 2

      expect(lists.first.items, hasLength(1));
      expect(lists.first.items.single.amount, 3);
      expect(notifyCalls, 1);
    });

    /// Proves (BUT-1106): when a later repo call throws AFTER some merged
    /// updates already committed, the committed merges are rolled back to
    /// their original amounts and the method returns false. The bug-shape:
    /// without rollback, Firebase keeps the partial summed merge while local
    /// state stays unchanged and the caller sees failure — re-running the
    /// batch would then double-sum the leaked merge.
    test('rolls back committed merges when a later repo call throws', () async {
      // One existing item that will be merged (update), plus the incoming
      // batch also carries a brand-new item so addItemsBatch runs after the
      // update commits. addItemsBatch is armed to throw.
      final existing = UnifiedShoppingItem(
        name: 'Mjölk',
        amount: 1,
        unit: 'dl',
      );
      lists.add(_seedList(id: 'L', items: [existing]));
      activeListId = 'L';
      fakeRepo.throwOnAddItemsBatch = StateError('boom');

      final merge = UnifiedShoppingItem(name: 'Mjölk', amount: 2, unit: 'dl');
      final fresh = UnifiedShoppingItem(name: 'Bröd', amount: 1);
      final ok = await buildModule().addItemsBatchToActiveList([merge, fresh]);

      expect(ok, isFalse);
      // updateItem was called twice on the same id: first the summed merge
      // (amount 3), then the rollback restoring the original amount (1).
      expect(fakeRepo.updatedItems, hasLength(2));
      expect(fakeRepo.updatedItems.first.amount, 3); // committed merge
      expect(fakeRepo.updatedItems.last.id, existing.id);
      expect(fakeRepo.updatedItems.last.amount, 1); // rolled back to original
      // Local state untouched — never mutated on the failure path.
      expect(lists.first.items, hasLength(1));
      expect(lists.first.items.single.amount, 1);
      expect(notifyCalls, 0);
    });

    /// Proves: SAME NAME + DIFFERENT UNIT → no merge. A naive name-only
    /// dedup would silently collapse "1 dl mjölk" and "1 ml mjölk" into a
    /// single bogus row with garbage units.
    test('does not merge same-name items with different units', () async {
      final existing = UnifiedShoppingItem(
        name: 'Mjölk',
        amount: 1,
        unit: 'dl',
      );
      lists.add(_seedList(id: 'L', items: [existing]));
      activeListId = 'L';

      final ml = UnifiedShoppingItem(name: 'Mjölk', amount: 5, unit: 'ml');
      final ok = await buildModule().addItemsBatchToActiveList([ml]);

      expect(ok, isTrue);
      expect(fakeRepo.batchedItems, hasLength(1));
      expect(fakeRepo.batchedItems.single.single.unit, 'ml');
      expect(fakeRepo.updatedItems, isEmpty);
      expect(lists.first.items, hasLength(2));
    });
  });

  // -------------------------------------------------------------------------
  // updateItemInActiveList
  // -------------------------------------------------------------------------

  group('updateItemInActiveList', () {
    /// Proves: an unknown item id (e.g. concurrent delete elsewhere) ends
    /// in a clean false — no repo call, no notify. The bug-shape: a
    /// regression using a sentinel item would push garbage to Firebase.
    test('returns false when item id is missing from active list', () async {
      lists.add(_seedList(id: 'L'));
      activeListId = 'L';

      final ok = await buildModule().updateItemInActiveList(itemId: 'nope');

      expect(ok, isFalse);
      expect(fakeRepo.updatedItems, isEmpty);
      expect(notifyCalls, 0);
    });

    /// Proves: an update that only changes one field PRESERVES the rest
    /// via copyWith semantics. A regression that constructed a new item
    /// from defaults would wipe amount/unit/category — the classic
    /// "partial update wiped my data" bug.
    test('partial update preserves untouched fields via copyWith', () async {
      final existing = UnifiedShoppingItem(
        name: 'Mjölk',
        amount: 1.5,
        unit: 'l',
        category: ShoppingCategory.dairy,
        priority: 5,
      );
      lists.add(_seedList(id: 'L', items: [existing]));
      activeListId = 'L';

      final ok = await buildModule().updateItemInActiveList(
        itemId: existing.id,
        name: 'Standardmjölk', // only field changed
      );

      expect(ok, isTrue);
      expect(fakeRepo.updatedItems.single.name, 'Standardmjölk');
      expect(fakeRepo.updatedItems.single.amount, 1.5);
      expect(fakeRepo.updatedItems.single.unit, 'l');
      expect(fakeRepo.updatedItems.single.category, ShoppingCategory.dairy);
      expect(fakeRepo.updatedItems.single.priority, 5);
      expect(notifyCalls, 1);
    });
  });

  // -------------------------------------------------------------------------
  // removeItemFromActiveList
  // -------------------------------------------------------------------------

  group('removeItemFromActiveList', () {
    /// Proves: stale active id (list gone) returns false, doesn't throw.
    /// A regression dropping the orElse on firstWhere would crash callers.
    test('returns false when active id resolves to missing list', () async {
      activeListId = 'ghost';
      final ok = await buildModule().removeItemFromActiveList('any');
      expect(ok, isFalse);
    });

    /// Proves: repo failure surfaces as false (caught silently) — UI can
    /// re-fetch and recover rather than crash.
    test('returns false on repo failure', () async {
      final item = UnifiedShoppingItem(name: 'A', amount: 1);
      lists.add(_seedList(id: 'L', items: [item]));
      activeListId = 'L';
      fakeRepo.throwOnRemoveItem = StateError('boom');

      final ok = await buildModule().removeItemFromActiveList(item.id);

      expect(ok, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // toggleItemBought — optimistic + rollback (the asked-for invariant)
  // -------------------------------------------------------------------------

  group('toggleItemBought', () {
    /// Proves: optimistic write fires BEFORE the repo call (i.e. the user
    /// sees an instant flip). We arm the repo to take "forever" by
    /// throwing AFTER we've already observed the state. Concretely we
    /// observe notifyCalls == 1 before awaiting completion: the toggle
    /// must have notified to apply the optimistic state.
    test('applies optimistic update before repo call returns', () async {
      final item = UnifiedShoppingItem(name: 'A', amount: 1);
      lists.add(_seedList(id: 'L', items: [item]));
      activeListId = 'L';

      final module = buildModule();
      final future = module.toggleItemBought(item.id);

      // Synchronously after the call returns the unawaited future, the
      // optimistic update has been applied and notified.
      expect(notifyCalls, greaterThanOrEqualTo(1));
      expect(lists.first.items.single.bought, isTrue);

      await future;
    });

    /// Proves: repo failure ROLLS BACK to the original bought state.
    /// This is the optimistic-rollback invariant batch 7 was asked to
    /// pin. The bug-shape: a regression that swallowed the catch but
    /// forgot the rollback would leave the UI showing a checked item
    /// that Firebase doesn't have.
    test('rolls back local state when repo update throws', () async {
      final item = UnifiedShoppingItem(name: 'A', amount: 1);
      lists.add(_seedList(id: 'L', items: [item]));
      activeListId = 'L';
      fakeRepo.throwOnUpdateItem = StateError('boom');

      final ok = await buildModule().toggleItemBought(item.id);

      expect(ok, isFalse);
      // Bought must be back to original false.
      expect(lists.first.items.single.bought, isFalse);
      // Two notifies: optimistic apply + rollback.
      expect(notifyCalls, 2);
    });

    /// BUT-1696: this is the LIVE checkbox path — view `_onItemTap` →
    /// `UnifiedShoppingViewModel.toggleItemBought` → service →
    /// `ShoppingItemManagementModule.toggleItemBought`. It does NOT go through
    /// `mutateSharedList`, so the service-level three-way test does not cover
    /// it. Without these two, deleting `_report(e)` from the rollback leaves
    /// the whole suite green and the checkbox silently un-ticks again.
    test(
      'a denied edit reports the permission sentence and rolls back',
      () async {
        final item = UnifiedShoppingItem(name: 'A', amount: 1);
        lists.add(_seedList(id: 'L', items: [item]));
        activeListId = 'L';
        fakeRepo.throwOnUpdateItem = PermissionDeniedException(
          'nope',
          resource: 'shopping_list:L',
          userId: 'u',
        );

        final ok = await buildModule().toggleItemBought(item.id);

        expect(ok, isFalse);
        expect(lists.first.items.single.bought, isFalse);
        expect(
          reported.single,
          // The fixture is a PERSONAL list, so the sentence must not call it a
          // shared one — see the collaborative twin below.
          AppLocale.current.shoppingNoEditPermission,
        );
      },
    );

    /// The wording branch itself. A member denied on a SHARED list must be
    /// told it is shared — and someone on their own list must not be. Without
    /// this twin, dropping the `shared:` argument from `shoppingFailureMessage`
    /// leaves the suite green with every list described as shared.
    test(
      'a denied edit on a COLLABORATIVE list reports the shared sentence',
      () async {
        final item = UnifiedShoppingItem(name: 'A', amount: 1);
        lists.add(
          _seedList(id: 'L', items: [item], type: ListType.collaborative),
        );
        activeListId = 'L';
        fakeRepo.throwOnUpdateItem = PermissionDeniedException(
          'nope',
          resource: 'shopping_list:L',
          userId: 'u',
        );

        final ok = await buildModule().toggleItemBought(item.id);

        expect(ok, isFalse);
        expect(
          reported.single,
          AppLocale.current.shoppingNoEditPermissionShared,
        );
        expect(
          reported.single,
          isNot(AppLocale.current.shoppingNoEditPermission),
        );
      },
    );

    /// The two "nothing happened" branches are deliberately DIFFERENT, and the
    /// difference is the whole BUT-1696 lesson: say what is true, or say
    /// nothing. A list that is gone gets a sentence; a row that vanished from a
    /// list still on screen gets silence, because "Lista hittades inte" would
    /// be a fresh invented cause. Swapping the two goes unnoticed without both
    /// halves of this pair.
    test('no active list reports that the list is gone', () async {
      lists.clear();
      activeListId = null;

      expect(await buildModule().toggleItemBought('whatever'), isFalse);

      expect(reported.single, AppLocale.current.shoppingListNotFound);
    });

    test('a vanished ROW on a present list reports nothing', () async {
      lists.add(
        _seedList(
          id: 'L',
          items: [UnifiedShoppingItem(name: 'A', amount: 1)],
        ),
      );
      activeListId = 'L';

      expect(await buildModule().toggleItemBought('no-such-item'), isFalse);

      expect(
        reported,
        isEmpty,
        reason:
            'the list is right there on screen — claiming it is missing would '
            'be the invented cause this ticket exists to remove',
      );
    });

    /// Proves the SECOND branch of the mapping, and that it differs from the
    /// first — telling "du får inte ändra" apart from "listan finns inte" is
    /// the entire point of the ticket for someone standing in a shop.
    test(
      'a lost list reports a different sentence than a denied edit',
      () async {
        final item = UnifiedShoppingItem(name: 'A', amount: 1);
        lists.add(_seedList(id: 'L', items: [item]));
        activeListId = 'L';
        fakeRepo.throwOnUpdateItem = ResourceNotFoundException(
          'gone',
          resourceType: 'shopping_list',
          resourceId: 'L',
        );

        final ok = await buildModule().toggleItemBought(item.id);

        expect(ok, isFalse);
        expect(lists.first.items.single.bought, isFalse);
        expect(reported.single, AppLocale.current.shoppingListNotFound);
        expect(
          reported.single,
          // The fixture is a PERSONAL list, so the competing sentence is the
          // personal one — asserting against the shared string cannot fail here.
          isNot(AppLocale.current.shoppingNoEditPermission),
          reason:
              'one shared string for both failures would be the bug BUT-1696 '
              'fixed',
        );
      },
    );

    /// Proves the fallback branch is distinct too, so all three outcomes are
    /// separable rather than two-plus-a-collapse.
    test('an unclassified failure reports the transport sentence', () async {
      final item = UnifiedShoppingItem(name: 'A', amount: 1);
      lists.add(_seedList(id: 'L', items: [item]));
      activeListId = 'L';
      fakeRepo.throwOnUpdateItem = StateError('socket');

      expect(await buildModule().toggleItemBought(item.id), isFalse);

      expect(reported.single, AppLocale.current.errorNetwork);
      expect(
        {
          AppLocale.current.shoppingNoEditPermissionShared,
          AppLocale.current.shoppingListNotFound,
          AppLocale.current.errorNetwork,
        },
        hasLength(3),
        reason: 'the three sentences must be distinguishable to the user',
      );
    });
  });

  // -------------------------------------------------------------------------
  // clearCompletedItems — bulk + rollback
  // -------------------------------------------------------------------------

  // The rollback path takes an index BEFORE the network round-trip and uses it
  // AFTER. In production `UnifiedShoppingService`'s collaborative snapshot
  // handler rebuilds the very `lists` instance these modules hold
  // (`removeWhere(isCollaborative)` then `addAll`), so that index can point at a
  // different list by the time the rollback runs — or past the end of a shorter
  // one. Every other fixture in this file seeds ONE list, where a stale index
  // and a re-found index are equal by construction, so nothing here could ever
  // have caught it.
  //
  // The seam is `notifyListeners`: the module calls it after applying the
  // optimistic change and before awaiting, and the harness already injects it.
  // Reordering `lists` from inside that callback reproduces the snapshot.
  group('a snapshot reordering lists mid-write', () {
    /// Returns a `notifyListeners` that performs [drift] exactly once, on its
    /// first call — i.e. in the window between the optimistic mutation and the
    /// await, which is where the real handler lands.
    void Function() driftOnce(void Function() drift) {
      var fired = false;
      return () {
        notifyCalls++;
        if (fired) return;
        fired = true;
        drift();
      };
    }

    test('a failed bulk uncheck rolls back the RIGHT list', () async {
      final kanel = UnifiedShoppingItem(name: 'kanel', amount: 1);
      final ticked = UnifiedShoppingItem(
        name: 'mjölk',
        amount: 1,
        bought: true,
      );
      final personal = _seedList(id: 'A', items: [kanel]);
      final shared = _seedList(
        id: 'B',
        items: [ticked],
        type: ListType.collaborative,
      );
      lists.addAll([personal, shared]);
      activeListId = 'B';
      fakeRepo.throwOnUpdateItemsBatch = StateError('boom');

      final module = ShoppingItemManagementModule(
        repository: fakeRepo,
        lists: lists,
        getActiveListId: () => activeListId,
        // The snapshot moves the collaborative list to the front, so the index
        // captured for B (1) now addresses A.
        notifyListeners: driftOnce(() {
          lists
            ..clear()
            ..addAll([shared, personal]);
        }),
        getCategoryPreferences: () => prefsModule,
        reportFailure: reported.add,
      );

      expect(await module.uncheckAllItems(), isFalse);

      // The discriminator: with a stale index, B's rows land on A.
      final a = lists.firstWhere((l) => l.id == 'A');
      expect(
        a.items.map((i) => i.name),
        ['kanel'],
        reason: "list A must not receive list B's rows",
      );
      final b = lists.firstWhere((l) => l.id == 'B');
      expect(b.items.single.bought, isTrue, reason: 'B must be rolled back');
    });

    test('a list that disappears mid-write does not throw', () async {
      final ticked = UnifiedShoppingItem(
        name: 'mjölk',
        amount: 1,
        bought: true,
      );
      final shared = _seedList(
        id: 'B',
        items: [ticked],
        type: ListType.collaborative,
      );
      final other = _seedList(id: 'A', items: []);
      lists.addAll([other, shared]);
      activeListId = 'B';
      fakeRepo.throwOnUpdateItemsBatch = StateError('boom');

      final module = ShoppingItemManagementModule(
        repository: fakeRepo,
        lists: lists,
        getActiveListId: () => activeListId,
        // The snapshot drops the collaborative list entirely: the captured
        // index is now out of range.
        notifyListeners: driftOnce(() {
          lists
            ..clear()
            ..addAll([other]);
        }),
        getCategoryPreferences: () => prefsModule,
        reportFailure: reported.add,
      );

      expect(await module.uncheckAllItems(), isFalse);
      expect(lists.map((l) => l.id), ['A']);
      expect(lists.single.items, isEmpty, reason: 'A must be untouched');
      expect(reported, isNotEmpty, reason: 'the failure still needs a reason');
    });
  });

  group('clearCompletedItems', () {
    /// Proves: nothing bought → true short-circuit, NO repo call. A
    /// regression that called `removeItemsBatch([])` would still hit the
    /// network and may even be rejected by the backend.
    test('returns true and skips repo when nothing is bought', () async {
      final item = UnifiedShoppingItem(name: 'A', amount: 1); // bought=false
      lists.add(_seedList(id: 'L', items: [item]));
      activeListId = 'L';

      final ok = await buildModule().clearCompletedItems();

      expect(ok, isTrue);
      expect(fakeRepo.removedBatches, isEmpty);
    });

    /// Proves: batch delete failure restores the bought items into local
    /// state. The bug-shape: a regression that only rolled back the
    /// `lists[listIndex]` reference without re-adding the bought items
    /// would silently drop them — the user's checked items vanish.
    test(
      'rolls back bought items into local state when batch delete throws',
      () async {
        final bought = UnifiedShoppingItem(
          name: 'Bought',
          amount: 1,
        ).copyWith(bought: true);
        final notBought = UnifiedShoppingItem(name: 'Keep', amount: 1);
        lists.add(_seedList(id: 'L', items: [bought, notBought]));
        activeListId = 'L';
        fakeRepo.throwOnRemoveItemsBatch = StateError('boom');

        final ok = await buildModule().clearCompletedItems();

        expect(ok, isFalse);
        // Both items present again — order may differ (rollback appends
        // bought items to the end), but the set must be intact.
        final ids = lists.first.items.map((i) => i.id).toSet();
        expect(ids, {bought.id, notBought.id});
        // Two notifies: optimistic remove + rollback.
        expect(notifyCalls, 2);
      },
    );

    /// BUT-1696: the DESTRUCTIVE sibling of the bulk uncheck, and the last of
    /// the three optimistic-rollback paths to get the fix. The caller discarded
    /// the bool and always said "Rensat", so a denied clear rolled the bought
    /// rows back on screen while the user was told the delete worked. The
    /// existing rollback test above stays green with `_report` deleted, so this
    /// group is what actually pins the reporting half.
    test('a denied clear reports the permission sentence', () async {
      final bought = UnifiedShoppingItem(
        name: 'Bought',
        amount: 1,
      ).copyWith(bought: true);
      lists.add(_seedList(id: 'L', items: [bought]));
      activeListId = 'L';
      fakeRepo.throwOnRemoveItemsBatch = PermissionDeniedException(
        'nope',
        resource: 'shopping_list:L',
        userId: 'u',
      );

      expect(await buildModule().clearCompletedItems(), isFalse);

      expect(lists.first.items.map((i) => i.id), [bought.id]);
      expect(reported.single, AppLocale.current.shoppingNoEditPermission);
    });

    /// Proves the clear path distinguishes a deleted list from a denied edit —
    /// "someone removed the list" and "you may not edit it" are different
    /// instructions to someone standing in a shop.
    test('a lost list reports a different sentence on clear', () async {
      final bought = UnifiedShoppingItem(
        name: 'Bought',
        amount: 1,
      ).copyWith(bought: true);
      lists.add(_seedList(id: 'L', items: [bought]));
      activeListId = 'L';
      fakeRepo.throwOnRemoveItemsBatch = ResourceNotFoundException(
        'gone',
        resourceType: 'shopping_list',
        resourceId: 'L',
      );

      expect(await buildModule().clearCompletedItems(), isFalse);

      expect(reported.single, AppLocale.current.shoppingListNotFound);
      expect(
        reported.single,
        // The fixture is a PERSONAL list, so the competing sentence is the
        // personal one — asserting against the shared string cannot fail here.
        isNot(AppLocale.current.shoppingNoEditPermission),
      );
    });

    /// Anything that is neither denial nor a missing list is transport.
    test(
      'a transport failure reports the connection sentence on clear',
      () async {
        final bought = UnifiedShoppingItem(
          name: 'Bought',
          amount: 1,
        ).copyWith(bought: true);
        lists.add(_seedList(id: 'L', items: [bought]));
        activeListId = 'L';
        fakeRepo.throwOnRemoveItemsBatch = StateError('socket');

        expect(await buildModule().clearCompletedItems(), isFalse);

        expect(reported.single, AppLocale.current.errorNetwork);
      },
    );

    /// Proves the happy path stays SILENT — a success that also reported a
    /// failure would make the caller show an error over a completed delete.
    test('reports nothing when the clear succeeds', () async {
      final bought = UnifiedShoppingItem(
        name: 'Bought',
        amount: 1,
      ).copyWith(bought: true);
      final keep = UnifiedShoppingItem(name: 'Keep', amount: 1);
      lists.add(_seedList(id: 'L', items: [bought, keep]));
      activeListId = 'L';

      expect(await buildModule().clearCompletedItems(), isTrue);

      expect(lists.first.items.map((i) => i.id), [keep.id]);
      expect(reported, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // uncheckAllItems
  // -------------------------------------------------------------------------

  group('uncheckAllItems', () {
    /// Proves: nothing checked → true short-circuit, no repo call.
    test('returns true and skips repo when nothing is checked', () async {
      final a = UnifiedShoppingItem(name: 'A', amount: 1);
      lists.add(_seedList(id: 'L', items: [a]));
      activeListId = 'L';

      final ok = await buildModule().uncheckAllItems();

      expect(ok, isTrue);
      expect(fakeRepo.updatedItems, isEmpty);
    });

    /// Proves: parallel updateItem failure restores the ORIGINAL items
    /// snapshot — not just bought=true on the formerly-checked items, but
    /// the exact instances (preserving `purchasedByUserId` etc).
    /// The bug-shape: a regression that rebuilt the snapshot from the
    /// mutated copies would lose collaborative metadata.
    test(
      'rolls back original items snapshot when update batch fails',
      () async {
        final checked = UnifiedShoppingItem(
          name: 'A',
          amount: 1,
        ).copyWith(bought: true);
        lists.add(_seedList(id: 'L', items: [checked]));
        activeListId = 'L';
        fakeRepo.throwOnUpdateItemsBatch = StateError('boom');

        final ok = await buildModule().uncheckAllItems();

        expect(ok, isFalse);
        // Bought must be true again post-rollback.
        expect(lists.first.items.single.bought, isTrue);
        // Two notifies: optimistic uncheck + rollback.
        expect(notifyCalls, 2);
      },
    );

    /// BUT-1696/BUT-1697: the bulk sibling of the checkbox path. A rollback
    /// that re-ticks 30 rows with nothing said is the same silent failure, so
    /// the same three-way mapping must fire here — and the view must have a
    /// message to show instead of a green "Alla avmarkerade".
    test('a denied bulk uncheck reports the permission sentence', () async {
      final checked = UnifiedShoppingItem(
        name: 'A',
        amount: 1,
      ).copyWith(bought: true);
      lists.add(_seedList(id: 'L', items: [checked]));
      activeListId = 'L';
      fakeRepo.throwOnUpdateItemsBatch = PermissionDeniedException(
        'nope',
        resource: 'shopping_list:L',
        userId: 'u',
      );

      expect(await buildModule().uncheckAllItems(), isFalse);

      expect(lists.first.items.single.bought, isTrue);
      expect(reported.single, AppLocale.current.shoppingNoEditPermission);
    });

    /// Proves the bulk path distinguishes a deleted list from a denied edit.
    test('a lost list reports a different sentence on bulk uncheck', () async {
      final checked = UnifiedShoppingItem(
        name: 'A',
        amount: 1,
      ).copyWith(bought: true);
      lists.add(_seedList(id: 'L', items: [checked]));
      activeListId = 'L';
      fakeRepo.throwOnUpdateItemsBatch = ResourceNotFoundException(
        'gone',
        resourceType: 'shopping_list',
        resourceId: 'L',
      );

      expect(await buildModule().uncheckAllItems(), isFalse);

      expect(reported.single, AppLocale.current.shoppingListNotFound);
      expect(
        reported.single,
        // The fixture is a PERSONAL list, so the competing sentence is the
        // personal one — asserting against the shared string cannot fail here.
        isNot(AppLocale.current.shoppingNoEditPermission),
      );
    });

    /// Proves the happy path stays SILENT — a success that also reported a
    /// failure would make the view show an error snackbar over a green result.
    test('reports nothing when the bulk uncheck succeeds', () async {
      final checked = UnifiedShoppingItem(
        name: 'A',
        amount: 1,
      ).copyWith(bought: true);
      lists.add(_seedList(id: 'L', items: [checked]));
      activeListId = 'L';

      expect(await buildModule().uncheckAllItems(), isTrue);

      expect(lists.first.items.single.bought, isFalse);
      expect(reported, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // addItemsFromRecipe — dispatch + dynamic wrapping
  // -------------------------------------------------------------------------

  group('addItemsFromRecipe', () {
    /// Proves: empty ingredients short-circuits with true and never
    /// touches the active-list resolution path. addItemsFromRecipe is
    /// called for every recipe→list dispatch; flaky empties would
    /// produce confusing "Couldn't add" toasts.
    test('returns true on empty input without touching repo', () async {
      lists.add(_seedList(id: 'L'));
      activeListId = 'L';

      final ok = await buildModule().addItemsFromRecipe(
        recipeId: 'r1',
        recipeName: 'Pasta',
        items: const [],
      );

      expect(ok, isTrue);
      expect(fakeRepo.batchedItems, isEmpty);
    });

    /// Proves: dynamic input that isn't a UnifiedShoppingItem (e.g. a
    /// string) gets wrapped into one with amount 1 before batching.
    /// The bug-shape: a regression that called `as UnifiedShoppingItem`
    /// would crash on the legacy string-ingredient callsites.
    test('wraps non-UnifiedShoppingItem entries via toString', () async {
      lists.add(_seedList(id: 'L'));
      activeListId = 'L';

      final ok = await buildModule().addItemsFromRecipe(
        recipeId: 'r1',
        recipeName: 'Pasta',
        items: const ['Tomater', 'Vitlök'],
      );

      expect(ok, isTrue);
      expect(fakeRepo.batchedItems, hasLength(1));
      final added = fakeRepo.batchedItems.single;
      expect(added.map((i) => i.name).toList(), ['Tomater', 'Vitlök']);
      expect(added.every((i) => i.amount == 1.0), isTrue);
    });
  });
}
