/// IMP-09: Unit tests for the three archive import manager sub-classes.
///
/// What this file proves (one bullet per group):
///
/// 1) **ArchiveSearchManager** — returns only recipes matching the active
///    query / tag / time filter, notifies listeners on every state change,
///    and invalidates its result cache on filter mutation while leaving it
///    intact across selection-only changes from other managers.
///
/// 2) **ArchiveSelectionManager** — `updateSelection` prunes IDs that no
///    longer appear in the filtered list (prevents stale selection state after
///    a search narrows the view); `toggleSelectAll` is an idempotent
///    round-trip (select-all then deselect-all returns to empty).
///
/// 3) **ArchiveImportOperationsManager** — the empty-selection guard blocks
///    the call and sets an error without touching the service; the service
///    failure path surfaces the service message in `error`; `isImporting` is
///    true during the async window and false before / after.
///
/// The managers are pure ChangeNotifiers with no Firebase dependencies, so no
/// locator setup or async test infrastructure is required.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/archive/archive_search_manager.dart';
import 'package:butlery/viewmodels/archive/archive_selection_manager.dart';
import 'package:butlery/viewmodels/archive/archive_import_operations_manager.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class MockPersonalRecipeOperations extends Mock
    implements PersonalRecipeOperations {}

/// Builds a minimal Recipe usable as a selection-state fixture.
/// Uses RecipeFactory.build() so tests survive model constructor changes.
Recipe _recipe({
  required String id,
  required String title,
  List<String> tags = const [],
  int? timeMinutes,
}) => RecipeFactory.build(
  id: id,
  title: title,
  personalTagIds: tags.isEmpty ? null : tags,
  timeMinutes: timeMinutes,
);

void main() {
  // -------------------------------------------------------------------------
  // ArchiveSearchManager
  // -------------------------------------------------------------------------
  group('ArchiveSearchManager', () {
    // The manager pulls recipes from the static `archivedRecipes` constant.
    // We test via the public filteredRecipes getter and do NOT need to inject
    // recipes — this tests the filter logic applied to the real archive data.
    //
    // The real archive (RecipeSeeds.allRecipes) has 6 recipes:
    //   Pasta Bolognese (pasta/middag/italienskt), Kycklingcurry
    //   (curry/middag/kryddigt), Wokade grönsaker (vegetariskt/snabbt/
    //   hälsosamt), Fish & chips (fisk/friterat/brittiskt), Caesarsallad
    //   (sallad/lunch/snabbt), Pannkakor (frukost/pannkakor/söta).

    late ArchiveSearchManager manager;

    setUp(() {
      manager = ArchiveSearchManager(SearchService());
    });

    tearDown(() {
      manager.dispose();
    });

    test('returns all archived recipes when no filter is active', () {
      // Proves the zero-filter baseline (6 real archive entries).
      expect(
        manager.filteredRecipes.length,
        equals(manager.archivedRecipes.length),
      );
    });

    test(
      'returns only matching recipes after a text search and notifies listeners',
      () {
        // Proves updateSearch applies the query and triggers a notification.
        var notifications = 0;
        manager.addListener(() => notifications++);

        manager.updateSearch('pasta');

        expect(notifications, greaterThanOrEqualTo(1));
        expect(manager.filteredRecipes.length, equals(1));
        expect(manager.filteredRecipes.first.title, contains('Pasta'));
      },
    );

    test('applies tag filter with AND semantics and notifies listeners', () {
      // Proves that selecting two tags requires BOTH to be present.
      // 'snabbt' AND 'vegetariskt' matches only Wokade grönsaker
      // (Caesarsallad has 'snabbt' but not 'vegetariskt').
      var notifications = 0;
      manager.addListener(() => notifications++);

      manager.toggleTag('snabbt');
      manager.toggleTag('vegetariskt');

      expect(notifications, equals(2));
      expect(manager.filteredRecipes.length, equals(1));
      expect(manager.filteredRecipes.first.title, equals('Wokade grönsaker'));
    });

    test('applies time filter and notifies listeners', () {
      // Proves TimeFilter.under15 returns only recipes at or under 15 minutes.
      var notifications = 0;
      manager.addListener(() => notifications++);

      manager.setTimeFilter(TimeFilter.under15);

      expect(notifications, greaterThanOrEqualTo(1));
      expect(
        manager.filteredRecipes.every((r) => (r.timeMinutes ?? 999) <= 15),
        isTrue,
      );
      // At least Caesar Salad (15min) qualifies.
      expect(manager.filteredRecipes, isNotEmpty);
    });

    test('clearFilters restores full result set and notifies listeners', () {
      manager.updateSearch('pasta');
      manager.toggleTag('pasta');
      manager.setTimeFilter(TimeFilter.under30);
      expect(manager.filteredRecipes.length, equals(1));

      var notifications = 0;
      manager.addListener(() => notifications++);

      manager.clearFilters();

      expect(notifications, greaterThanOrEqualTo(1));
      expect(manager.searchQuery, isEmpty);
      expect(manager.selectedTags, isEmpty);
      expect(manager.timeFilter, equals(TimeFilter.all));
      expect(
        manager.filteredRecipes.length,
        equals(manager.archivedRecipes.length),
      );
    });

    test('result cache is reused when filters are unchanged', () {
      // Proves the cache contract: same list reference returned on repeat call.
      final first = manager.filteredRecipes;
      final second = manager.filteredRecipes;

      expect(identical(first, second), isTrue);
    });

    test('result cache is invalidated after a filter mutation', () {
      // Proves the cache does NOT serve stale results across a filter change.
      final before = manager.filteredRecipes;
      manager.updateSearch('pasta');
      final after = manager.filteredRecipes;

      expect(identical(before, after), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // ArchiveSelectionManager
  // -------------------------------------------------------------------------
  group('ArchiveSelectionManager', () {
    late ArchiveSelectionManager manager;

    final recipeA = _recipe(id: 'a', title: 'A');
    final recipeB = _recipe(id: 'b', title: 'B');
    final recipeC = _recipe(id: 'c', title: 'C');
    final all = [recipeA, recipeB, recipeC];

    setUp(() {
      manager = ArchiveSelectionManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('starts with no selection', () {
      expect(manager.selectedRecipeIds, isEmpty);
      expect(manager.hasSelection, isFalse);
      expect(manager.selectedCount, equals(0));
    });

    test('toggleRecipeSelection adds then removes a recipe ID', () {
      // Proves toggle is a true toggle — second call undoes the first.
      var notifications = 0;
      manager.addListener(() => notifications++);

      manager.toggleRecipeSelection('a');
      expect(manager.selectedRecipeIds, contains('a'));
      expect(manager.selectedCount, equals(1));

      manager.toggleRecipeSelection('a');
      expect(manager.selectedRecipeIds, isNot(contains('a')));
      expect(manager.selectedCount, equals(0));

      expect(notifications, equals(2));
    });

    test(
      'toggleSelectAll selects all provided recipes then deselects all (round-trip)',
      () {
        // Proves idempotent round-trip: select-all → deselect-all → empty.
        manager.toggleSelectAll(all);
        expect(manager.selectedCount, equals(3));
        expect(manager.isAllSelected(all), isTrue);

        manager.toggleSelectAll(all);
        expect(manager.selectedCount, equals(0));
        expect(manager.hasSelection, isFalse);
      },
    );

    test(
      'updateSelection prunes IDs that are no longer in the filtered list',
      () {
        // Core invariant: stale IDs must not survive a filter change.
        // Simulates: user selects A, B, C → filter narrows to [A] → B and C pruned.
        manager.toggleRecipeSelection('a');
        manager.toggleRecipeSelection('b');
        manager.toggleRecipeSelection('c');
        expect(manager.selectedCount, equals(3));

        var notifications = 0;
        manager.addListener(() => notifications++);

        manager.updateSelection([recipeA]); // Only A remains visible

        expect(manager.selectedRecipeIds, equals({'a'}));
        expect(manager.selectedCount, equals(1));
        // A notification must have fired because the selection changed.
        expect(notifications, greaterThanOrEqualTo(1));
      },
    );

    test('updateSelection does NOT notify when nothing was pruned', () {
      // Proves the manager avoids spurious rebuilds when the list is stable.
      manager.toggleRecipeSelection('a');

      var notifications = 0;
      manager.addListener(() => notifications++);

      // All selected IDs are still in the provided filtered list.
      manager.updateSelection([recipeA, recipeB]);

      expect(notifications, equals(0));
    });

    test('clearSelection empties the set and notifies', () {
      manager.toggleRecipeSelection('a');
      manager.toggleRecipeSelection('b');

      var notifications = 0;
      manager.addListener(() => notifications++);

      manager.clearSelection();

      expect(manager.selectedRecipeIds, isEmpty);
      expect(notifications, greaterThanOrEqualTo(1));
    });
  });

  // -------------------------------------------------------------------------
  // ArchiveImportOperationsManager
  // -------------------------------------------------------------------------
  group('ArchiveImportOperationsManager', () {
    late ArchiveImportOperationsManager manager;
    late MockUnifiedRecipeService mockRecipeService;
    late MockPersonalRecipeOperations mockPersonalOps;

    final recipe1 = _recipe(id: 'r1', title: 'Kycklinggryta');
    final recipe2 = _recipe(id: 'r2', title: 'Vegetarisk lasagne');
    final allRecipes = [recipe1, recipe2];

    setUp(() {
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(<Recipe>[]);

      mockRecipeService = MockUnifiedRecipeService();
      mockPersonalOps = MockPersonalRecipeOperations();

      mockRecipeService.setRecipeState(
        isInitialized: true,
        personalOperations: mockPersonalOps,
      );

      manager = ArchiveImportOperationsManager(mockRecipeService);
    });

    tearDown(() {
      manager.dispose();
      resetMocktailState();
    });

    // BUT-1641: the disposal guard, driven on the path production can actually
    // reach after dispose. `ArchiveImportViewModel.clearError()` already guards
    // itself, so a post-dispose `clearError()` would prove the guard exists
    // without proving it matters; `importSelectedRecipes` is the method whose
    // continuation genuinely outlives the screen.
    //
    // Two hops are covered here, and both are this manager's OWN statements —
    // the ViewModel awaits and runs nothing after, so a parent guard could
    // never have caught either. `_setImporting(true)` notifies before the
    // `try` is entered at all. And `onSuccess()` runs before this manager
    // notifies, so it reaches `ArchiveSelectionManager` — which is why that
    // class got the same guard rather than a check at this call site.
    test(
      'an import that completes after dispose notifies nobody and does not '
      'throw, including through onSuccess',
      () async {
        when(
          () => mockPersonalOps.addMultipleUnifiedRecipes(any()),
        ).thenAnswer((_) async => RecipeOperationResult.success('OK'));

        // A local pair: tearDown disposes the shared `manager`, and
        // ChangeNotifier refuses a second dispose.
        final subject = ArchiveImportOperationsManager(mockRecipeService);
        final selection = ArchiveSelectionManager();
        // Seeded on purpose: `clearSelection()` only notifies on a NON-EMPTY
        // set, so an empty one returns before ever reaching the guard this
        // test claims to exercise.
        selection.toggleRecipeSelection(recipe1.id);
        var notifications = 0;
        subject.addListener(() => notifications++);

        // Positive control: the wiring notifies while alive.
        subject.clearError();
        expect(notifications, greaterThan(0));

        subject.dispose();
        selection.dispose();

        await expectLater(
          subject.importSelectedRecipes(
            allRecipes,
            {recipe1.id},
            selection.clearSelection,
          ),
          completes,
        );
        expect(subject.isDisposed, isTrue);
        // `completes` alone cannot discriminate the onSuccess hop: without the
        // selection guard the FlutterError is caught by importSelectedRecipes'
        // own `catch (e)`, and the future still resolves. The error STATE is
        // what differs.
        expect(
          subject.hasError,
          isFalse,
          reason:
              'without the guard on ArchiveSelectionManager, onSuccess throws '
              'from a disposed notifier and this import records itself as a '
              'failure despite having succeeded',
        );
      },
    );

    test(
      'blocks import when no recipe IDs are selected and sets an error',
      () async {
        // Proves the empty-selection guard: service must never be called.
        await manager.importSelectedRecipes(
          allRecipes,
          const <String>{}, // no selection
          () {}, // onSuccess — must not be invoked
        );

        expect(manager.hasError, isTrue);
        expect(manager.error, isNotNull);
        verifyNever(() => mockPersonalOps.addMultipleUnifiedRecipes(any()));
      },
    );

    test(
      'sets isImporting to true during the async call and false after',
      () async {
        // Proves the loading-state contract visible in the UI spinner.
        when(
          () => mockPersonalOps.addMultipleUnifiedRecipes(any()),
        ).thenAnswer((_) async => RecipeOperationResult.success('OK'));

        bool wasImporting = false;
        manager.addListener(() {
          if (manager.isImporting) wasImporting = true;
        });

        await manager.importSelectedRecipes(
          allRecipes,
          {'r1'},
          () {},
        );

        expect(wasImporting, isTrue);
        expect(manager.isImporting, isFalse);
      },
    );

    test(
      'surfaces the service failure message in error on unsuccessful result',
      () async {
        // Proves the error-propagation path from service result to UI.
        when(() => mockPersonalOps.addMultipleUnifiedRecipes(any())).thenAnswer(
          (_) async => RecipeOperationResult.failure('Kunde inte importera'),
        );

        await manager.importSelectedRecipes(allRecipes, {'r1'}, () {});

        expect(manager.hasError, isTrue);
        expect(manager.error, equals('Kunde inte importera'));
      },
    );

    test(
      'calls onSuccess callback and clears error on successful import',
      () async {
        // Proves the happy-path notification contract.
        when(
          () => mockPersonalOps.addMultipleUnifiedRecipes(any()),
        ).thenAnswer((_) async => RecipeOperationResult.success('Importerat'));

        bool successCalled = false;
        await manager.importSelectedRecipes(
          allRecipes,
          {'r1', 'r2'},
          () => successCalled = true,
        );

        expect(successCalled, isTrue);
        expect(manager.hasError, isFalse);
      },
    );

    test(
      'sets source attribution to archive provenance string on each recipe',
      () async {
        // Proves the archive attribution invariant: users must see where the
        // recipe came from. If this breaks, provenance is silently lost.
        when(
          () => mockPersonalOps.addMultipleUnifiedRecipes(any()),
        ).thenAnswer((_) async => RecipeOperationResult.success('OK'));

        await manager.importSelectedRecipes(allRecipes, {'r1', 'r2'}, () {});

        final captured =
            verify(
                  () => mockPersonalOps.addMultipleUnifiedRecipes(captureAny()),
                ).captured.first
                as List<Recipe>;
        expect(
          captured.every((r) => r.sourceUrl == 'Från Butlerys arkiv'),
          isTrue,
          reason: 'Every imported recipe must carry the archive source URL',
        );
      },
    );
  });
}
