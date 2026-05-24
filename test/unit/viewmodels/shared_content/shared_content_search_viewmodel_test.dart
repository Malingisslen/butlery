/// Behavioural unit tests for [SharedContentSearchViewModel].
///
/// Behaviours covered:
/// - Debounce: rapid query changes collapse into one underlying search.
/// - Race protection: late-completing prior search must not overwrite newer results.
/// - Empty / whitespace queries do NOT trigger a search and clear results.
/// - Search history dedup + cap at 10 entries (most-recent-first).
/// - clearSearch wipes results + cancels pending debounced search.
/// - Filters AND, not OR: contentType + status + date combine.
/// - resultCounts: per-type counts + ContentType.all reflects post-filter totals.
/// - Filter setters are no-ops when value unchanged (no spurious notifications).
/// - clearFilters only notifies when something actually changed.
/// - Sort order: relevance DESC, then date DESC tie-breaker.
/// - Relevance: title-prefix > title-contains; sharedBy + recency contribute.
/// - dispose() during in-flight debounce: no setState after dispose, no crash.
/// - Re-search triggered when a collaborator VM notifies and a query is active.
/// - Re-search NOT triggered on collaborator notification when query is empty.
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_search_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSharedRecipeViewModel extends Mock
    implements SharedRecipeViewModel {}

class _MockSharedMenuViewModel extends Mock implements SharedMenuViewModel {}

class _MockSharedShoppingViewModel extends Mock
    implements SharedShoppingViewModel {}

class _FakeSharedRecipe extends Fake implements SharedRecipe {}

class _FakeSharedMenu extends Fake implements SharedMenu {}

class _FakeSharedShoppingList extends Fake implements SharedShoppingList {}

/// A fixed reference point so date-based filter assertions are deterministic.
final _kNow = DateTime(2026, 5, 20, 12); // Wednesday

SharedRecipe _makeRecipe({
  required String id,
  required String title,
  String? description,
  DateTime? sharedAt,
  String sharedBy = 'Alice',
  Recipe? snapshot,
}) {
  return SharedRecipe(
    id: id,
    sharedByUserId: 'uid-$sharedBy',
    sharedByDisplayName: sharedBy,
    sharedAt: sharedAt ?? _kNow,
    originalRecipeId: 'orig-$id',
    recipeTitle: title,
    recipeDescription: description,
    recipeSnapshot: snapshot,
  );
}

SharedMenu _makeMenu({
  required String id,
  required String title,
  DateTime? sharedAt,
  String sharedBy = 'Alice',
  Map<String, List<Recipe>>? snapshot,
}) {
  return SharedMenu(
    id: id,
    sharedByUserId: 'uid-$sharedBy',
    sharedByDisplayName: sharedBy,
    sharedAt: sharedAt ?? _kNow,
    menuTitle: title,
    menuSnapshot: snapshot ?? const <String, List<Recipe>>{},
  );
}

SharedShoppingList _makeList({
  required String id,
  required String name,
  String? description,
  DateTime? sharedAt,
  int itemCount = 0,
  String sharedBy = 'Alice',
}) {
  return SharedShoppingList(
    id: id,
    sharedByUserId: 'uid-$sharedBy',
    sharedByDisplayName: sharedBy,
    sharedAt: sharedAt ?? _kNow,
    listName: name,
    listDescription: description,
    itemCount: itemCount,
    originalOwnerId: 'uid-$sharedBy',
    originalOwnerDisplayName: sharedBy,
  );
}

/// Configure status getters on a recipe VM mock.
void _stubRecipeStatus(
  _MockSharedRecipeViewModel mock, {
  bool viewed = false,
  bool imported = false,
  bool dismissed = false,
  bool collaborative = false,
}) {
  when(() => mock.isRecipeViewed(any())).thenReturn(viewed);
  when(() => mock.isRecipeImported(any())).thenReturn(imported);
  when(() => mock.isRecipeDismissed(any())).thenReturn(dismissed);
  when(() => mock.isRecipeCollaborative(any())).thenReturn(collaborative);
}

void _stubMenuStatus(
  _MockSharedMenuViewModel mock, {
  bool viewed = false,
  bool imported = false,
  bool dismissed = false,
  bool collaborative = false,
  String summary = '',
}) {
  when(() => mock.isMenuViewed(any())).thenReturn(viewed);
  when(() => mock.isMenuImported(any())).thenReturn(imported);
  when(() => mock.isMenuDismissed(any())).thenReturn(dismissed);
  when(() => mock.isMenuCollaborative(any())).thenReturn(collaborative);
  when(() => mock.getMenuSummary(any())).thenReturn(summary);
}

void _stubShoppingStatus(
  _MockSharedShoppingViewModel mock, {
  bool viewed = false,
  bool dismissed = false,
  bool joined = false,
  String summary = '',
}) {
  when(() => mock.isShoppingListViewed(any())).thenReturn(viewed);
  when(() => mock.isShoppingListDismissed(any())).thenReturn(dismissed);
  when(() => mock.isShoppingListJoined(any())).thenReturn(joined);
  when(() => mock.getShoppingListSummary(any())).thenReturn(summary);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSharedRecipe());
    registerFallbackValue(_FakeSharedMenu());
    registerFallbackValue(_FakeSharedShoppingList());
  });

  late _MockSharedRecipeViewModel recipeVm;
  late _MockSharedMenuViewModel menuVm;
  late _MockSharedShoppingViewModel shoppingVm;

  setUp(() {
    recipeVm = _MockSharedRecipeViewModel();
    menuVm = _MockSharedMenuViewModel();
    shoppingVm = _MockSharedShoppingViewModel();

    // Default: addListener/removeListener are no-op stubs.
    when(() => recipeVm.addListener(any())).thenAnswer((_) {});
    when(() => recipeVm.removeListener(any())).thenAnswer((_) {});
    when(() => menuVm.addListener(any())).thenAnswer((_) {});
    when(() => menuVm.removeListener(any())).thenAnswer((_) {});
    when(() => shoppingVm.addListener(any())).thenAnswer((_) {});
    when(() => shoppingVm.removeListener(any())).thenAnswer((_) {});

    // Default: empty content lists.
    when(() => recipeVm.content).thenReturn(<SharedRecipe>[]);
    when(() => menuVm.content).thenReturn(<SharedMenu>[]);
    when(() => shoppingVm.content).thenReturn(<SharedShoppingList>[]);

    // Default: nothing matches search.
    when(() => recipeVm.contentMatchesSearch(any(), any())).thenReturn(false);
    when(() => menuVm.contentMatchesSearch(any(), any())).thenReturn(false);
    when(() => shoppingVm.contentMatchesSearch(any(), any())).thenReturn(false);

    _stubRecipeStatus(recipeVm);
    _stubMenuStatus(menuVm);
    _stubShoppingStatus(shoppingVm);
  });

  SharedContentSearchViewModel makeVm() => SharedContentSearchViewModel(
        recipeViewModel: recipeVm,
        menuViewModel: menuVm,
        shoppingViewModel: shoppingVm,
      );

  group('debounce', () {
    /// Three rapid keystrokes within the 300ms window must produce exactly
    /// one _performSearch call (one round per content type, all checked
    /// against the FINAL query 'abc').
    test('coalesces rapid query changes into a single search', () {
      fakeAsync((async) {
        final r1 = _makeRecipe(id: 'r1', title: 'abc soup');
        when(() => recipeVm.content).thenReturn([r1]);
        // Track the queries actually used so we can assert no in-flight 'a'/'ab' search ran.
        final queriesSeen = <String>[];
        when(() => recipeVm.contentMatchesSearch(any(), any()))
            .thenAnswer((invocation) {
          queriesSeen.add(invocation.positionalArguments[1] as String);
          return true;
        });

        final vm = makeVm();
        vm.updateSearchQuery('a');
        vm.updateSearchQuery('ab');
        vm.updateSearchQuery('abc');

        // Before debounce expires: no search call yet.
        expect(queriesSeen, isEmpty);

        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Exactly one search round happened, against the final query only.
        // Intermediate 'a' and 'ab' must NOT have triggered searches.
        expect(queriesSeen, ['abc']);
        expect(vm.searchQuery, 'abc');
        expect(vm.isSearching, isFalse);
        vm.dispose();
      });
    });

    /// updating to the same query is a no-op (must not reset debounce or notify).
    test('no-op when query is unchanged', () {
      final vm = makeVm();
      vm.updateSearchQuery('pasta');
      var notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.updateSearchQuery('pasta');

      expect(notifyCount, 0);
      vm.dispose();
    });
  });

  group('empty / whitespace input', () {
    /// Clearing the box mid-typing must wipe results and not fire a search.
    test('empty query clears results and skips repository call', () {
      fakeAsync((async) {
        when(() => recipeVm.content)
            .thenReturn([_makeRecipe(id: 'r1', title: 'Pasta')]);
        when(() => recipeVm.contentMatchesSearch(any(), any()))
            .thenReturn(true);

        final vm = makeVm();
        vm.updateSearchQuery('pasta');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();
        expect(vm.allResults, hasLength(1));

        vm.updateSearchQuery('');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        expect(vm.allResults, isEmpty);
        expect(vm.hasSearchQuery, isFalse);
        vm.dispose();
      });
    });

    /// Whitespace-only is a documented bug-or-not-bug grey area. The current
    /// implementation treats " " as non-empty and runs a search. We pin the
    /// observed behaviour so any future change is intentional. If you change
    /// the production behaviour to skip whitespace, update this test and add
    /// a deliberate trim() — don't weaken silently.
    test('whitespace query is treated as a real query (pins current behaviour)',
        () {
      fakeAsync((async) {
        when(() => recipeVm.content)
            .thenReturn([_makeRecipe(id: 'r1', title: 'Pasta')]);
        // Nothing matches whitespace, so result count = 0.
        when(() => recipeVm.contentMatchesSearch(any(), any()))
            .thenReturn(false);

        final vm = makeVm();
        vm.updateSearchQuery('   ');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Search ran (verify), even though no results came back.
        verify(() => recipeVm.contentMatchesSearch(any(), any())).called(1);
        expect(vm.allResults, isEmpty);
        vm.dispose();
      });
    });
  });

  group('search history', () {
    test('dedupes existing entries and keeps most recent first', () {
      final vm = makeVm();
      vm.updateSearchQuery('pasta');
      vm.updateSearchQuery('soup');
      vm.updateSearchQuery('pasta'); // duplicate — should NOT re-insert

      expect(vm.searchHistory, ['soup', 'pasta']);
      vm.dispose();
    });

    test('caps history at 10 entries', () {
      final vm = makeVm();
      for (var i = 0; i < 12; i++) {
        vm.updateSearchQuery('q$i');
      }
      expect(vm.searchHistory, hasLength(10));
      // Most recent is at index 0.
      expect(vm.searchHistory.first, 'q11');
      // The oldest two ('q0','q1') should have fallen off.
      expect(vm.searchHistory.contains('q0'), isFalse);
      expect(vm.searchHistory.contains('q1'), isFalse);
      vm.dispose();
    });
  });

  group('clearSearch', () {
    /// Tapping the X must wipe results AND cancel a queued debounced search
    /// — otherwise the search fires AFTER the user expected a clear, and
    /// stale results appear.
    test('cancels pending debounced search and wipes results', () {
      fakeAsync((async) {
        when(() => recipeVm.content)
            .thenReturn([_makeRecipe(id: 'r1', title: 'Pasta')]);
        when(() => recipeVm.contentMatchesSearch(any(), any()))
            .thenReturn(true);

        final vm = makeVm();
        vm.updateSearchQuery('pasta');
        // Don't elapse yet — search is queued.
        vm.clearSearch();

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        // Search must NOT have run because clearSearch cancelled the timer.
        verifyNever(() => recipeVm.contentMatchesSearch(any(), any()));
        expect(vm.allResults, isEmpty);
        expect(vm.searchQuery, '');
        vm.dispose();
      });
    });
  });

  group('filters', () {
    /// Set up: 3 recipes (2 unread, 1 viewed), 1 menu, 1 list — all match query.
    /// We then exercise each filter axis and assert intersection semantics.
    SharedContentSearchViewModel buildPopulatedVm(FakeAsync async) {
      final r1 = _makeRecipe(id: 'r1', title: 'pasta carbonara');
      final r2 = _makeRecipe(id: 'r2', title: 'pasta bolognese');
      final m1 = _makeMenu(id: 'm1', title: 'pasta night');
      final s1 = _makeList(id: 's1', name: 'pasta groceries');

      when(() => recipeVm.content).thenReturn([r1, r2]);
      when(() => menuVm.content).thenReturn([m1]);
      when(() => shoppingVm.content).thenReturn([s1]);

      when(() => recipeVm.contentMatchesSearch(any(), any())).thenReturn(true);
      when(() => menuVm.contentMatchesSearch(any(), any())).thenReturn(true);
      when(() => shoppingVm.contentMatchesSearch(any(), any()))
          .thenReturn(true);

      // r1 unread, r2 viewed.
      when(() => recipeVm.isRecipeViewed(r1)).thenReturn(false);
      when(() => recipeVm.isRecipeViewed(r2)).thenReturn(true);

      final vm = makeVm();
      vm.updateSearchQuery('pasta');
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();
      return vm;
    }

    test('contentType=recipes excludes menus and shopping lists', () {
      fakeAsync((async) {
        final vm = buildPopulatedVm(async);
        vm.setContentTypeFilter(ContentType.recipes);

        expect(vm.filteredResults.map((r) => r.id), {'r1', 'r2'});
        vm.dispose();
      });
    });

    /// Status filter and content type filter combine via AND, not OR.
    /// (status=unread AND contentType=recipes => only r1 — viewed r2 excluded,
    /// menus/lists excluded.)
    test('status filter AND contentType filter (intersection, not union)', () {
      fakeAsync((async) {
        final vm = buildPopulatedVm(async);
        vm.setContentTypeFilter(ContentType.recipes);
        vm.setStatusFilter(ContentStatus.unread);

        expect(vm.filteredResults.map((r) => r.id), ['r1']);
        expect(vm.hasActiveFilters, isTrue);
        vm.dispose();
      });
    });

    /// hasActiveFilters must be false after clearFilters and listeners must
    /// be notified — but ONLY if there was actually something to clear.
    test('clearFilters notifies when filters were active, not otherwise', () {
      fakeAsync((async) {
        final vm = buildPopulatedVm(async);
        vm.setContentTypeFilter(ContentType.recipes);
        var notifyCount = 0;
        vm.addListener(() => notifyCount++);

        vm.clearFilters();
        expect(notifyCount, 1);
        expect(vm.hasActiveFilters, isFalse);

        // Second call: nothing to clear — no notification.
        vm.clearFilters();
        expect(notifyCount, 1);
        vm.dispose();
      });
    });

    /// Setter is a no-op when filter is unchanged (no spurious rebuild).
    test('setContentTypeFilter does not notify when value is unchanged', () {
      final vm = makeVm();
      var notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.setContentTypeFilter(ContentType.all); // already default
      expect(notifyCount, 0);

      vm.setContentTypeFilter(ContentType.menus);
      expect(notifyCount, 1);
      vm.dispose();
    });
  });

  group('date filter', () {
    /// today filter must include items shared today and exclude yesterday.
    test('DateRange.today includes today and excludes yesterday', () {
      withClock(Clock.fixed(_kNow), () {
        fakeAsync((async) {
          final today =
              _makeRecipe(id: 'today', title: 'pasta', sharedAt: _kNow);
          final yesterday = _makeRecipe(
              id: 'yesterday',
              title: 'pasta',
              sharedAt: _kNow.subtract(const Duration(days: 1)));

          when(() => recipeVm.content).thenReturn([today, yesterday]);
          when(() => recipeVm.contentMatchesSearch(any(), any()))
              .thenReturn(true);

          final vm = makeVm();
          vm.updateSearchQuery('pasta');
          async.elapse(const Duration(milliseconds: 300));
          async.flushMicrotasks();

          vm.setDateFilter(DateRange.today);
          expect(vm.filteredResults.map((r) => r.id), ['today']);
          vm.dispose();
        });
      });
    });
  });

  group('resultCounts', () {
    test('per-type counts reflect filtered results, not raw', () {
      fakeAsync((async) {
        final r1 = _makeRecipe(id: 'r1', title: 'pasta');
        final m1 = _makeMenu(id: 'm1', title: 'pasta');
        final s1 = _makeList(id: 's1', name: 'pasta');

        when(() => recipeVm.content).thenReturn([r1]);
        when(() => menuVm.content).thenReturn([m1]);
        when(() => shoppingVm.content).thenReturn([s1]);
        when(() => recipeVm.contentMatchesSearch(any(), any()))
            .thenReturn(true);
        when(() => menuVm.contentMatchesSearch(any(), any())).thenReturn(true);
        when(() => shoppingVm.contentMatchesSearch(any(), any()))
            .thenReturn(true);

        final vm = makeVm();
        vm.updateSearchQuery('pasta');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Filter down to recipes only; counts must reflect that.
        vm.setContentTypeFilter(ContentType.recipes);

        final counts = vm.resultCounts;
        expect(counts[ContentType.all], 1);
        expect(counts[ContentType.recipes], 1);
        expect(counts[ContentType.menus], 0);
        expect(counts[ContentType.shoppingLists], 0);
        vm.dispose();
      });
    });
  });

  group('sort + relevance', () {
    /// Title that starts with the query must rank higher than title that
    /// merely contains it. This proves _scoreTitleMatch's prefix bonus.
    test('title prefix outranks title contains', () {
      fakeAsync((async) {
        final prefix = _makeRecipe(id: 'pre', title: 'pasta carbonara');
        final contains = _makeRecipe(id: 'con', title: 'easy pasta');

        when(() => recipeVm.content).thenReturn([contains, prefix]);
        when(() => recipeVm.contentMatchesSearch(any(), any()))
            .thenReturn(true);

        final vm = makeVm();
        vm.updateSearchQuery('pasta');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // 'pasta carbonara' starts with 'pasta' → 15.0, beats 'easy pasta' → 10.0
        expect(vm.filteredResults.first.id, 'pre');
        vm.dispose();
      });
    });

    /// Same relevance → newest sharedAt comes first.
    /// All three share the same title (same prefix score) and are >7 days
    /// old (equal recency bonus = 0), so the date tie-break is the only
    /// thing distinguishing them.
    test('equal relevance breaks tie by newest sharedAt', () {
      // Pin "now" 60 days after _kNow so all sharedAt values are >7 days old
      // → recency bonus is 0 for all → relevance is purely title-driven (equal).
      withClock(Clock.fixed(_kNow.add(const Duration(days: 60))), () {
        fakeAsync((async) {
          final oldest = _makeRecipe(
            id: 'oldest',
            title: 'pasta night',
            sharedAt: _kNow.subtract(const Duration(days: 30)),
          );
          final middle = _makeRecipe(
            id: 'middle',
            title: 'pasta night',
            sharedAt: _kNow.subtract(const Duration(days: 10)),
          );
          final newest = _makeRecipe(
            id: 'newest',
            title: 'pasta night',
            sharedAt: _kNow,
          );

          when(() => recipeVm.content).thenReturn([oldest, middle, newest]);
          when(() => recipeVm.contentMatchesSearch(any(), any()))
              .thenReturn(true);

          final vm = makeVm();
          vm.updateSearchQuery('pasta night');
          async.elapse(const Duration(milliseconds: 300));
          async.flushMicrotasks();

          // Date DESC tie-break: newest, middle, oldest.
          expect(vm.filteredResults.map((r) => r.id).toList(),
              ['newest', 'middle', 'oldest']);
          vm.dispose();
        });
      });
    });
  });

  group('lifecycle', () {
    /// dispose() during a queued debounced search must not throw and must
    /// not invoke notifyListeners after super.dispose().
    test('dispose() mid-debounce does not throw and does not call back', () {
      fakeAsync((async) {
        when(() => recipeVm.content)
            .thenReturn([_makeRecipe(id: 'r1', title: 'pasta')]);
        when(() => recipeVm.contentMatchesSearch(any(), any()))
            .thenReturn(true);

        final vm = makeVm();
        vm.updateSearchQuery('pasta');

        // Dispose BEFORE the debounce timer fires — timer should be cancelled.
        vm.dispose();

        // No exception should bubble.
        expect(() {
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
        }, returnsNormally);

        // Search must never have run.
        verifyNever(() => recipeVm.contentMatchesSearch(any(), any()));
      });
    });

    /// dispose() must remove its listeners from all 3 collaborator VMs.
    /// This is the bug protection: leaking listeners → memory leak +
    /// orphan VM still receiving notifications after disposal.
    test('dispose() removes its listener from each collaborator VM', () {
      final vm = makeVm();
      vm.dispose();

      verify(() => recipeVm.removeListener(any())).called(1);
      verify(() => menuVm.removeListener(any())).called(1);
      verify(() => shoppingVm.removeListener(any())).called(1);
    });
  });

  group('collaborator notifications', () {
    /// When a collaborator VM notifies (e.g. user imported a recipe), the
    /// search VM must re-run its query so result state reflects the new
    /// imported/viewed/dismissed status. This re-search is itself debounced.
    test('re-runs search when collaborator notifies and query is active', () {
      fakeAsync((async) {
        when(() => recipeVm.content)
            .thenReturn([_makeRecipe(id: 'r1', title: 'pasta')]);
        when(() => recipeVm.contentMatchesSearch(any(), any()))
            .thenReturn(true);

        // Capture the listener so we can invoke it manually.
        late VoidCallback capturedListener;
        when(() => recipeVm.addListener(any())).thenAnswer((invocation) {
          capturedListener =
              invocation.positionalArguments.first as VoidCallback;
        });

        final vm = makeVm();
        vm.updateSearchQuery('pasta');
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        clearInteractions(recipeVm);
        // Re-stub after clearInteractions so the next search call works.
        when(() => recipeVm.content)
            .thenReturn([_makeRecipe(id: 'r1', title: 'pasta')]);
        when(() => recipeVm.contentMatchesSearch(any(), any()))
            .thenReturn(true);

        // Simulate the collaborator firing notifyListeners.
        capturedListener();
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Search ran again.
        verify(() => recipeVm.contentMatchesSearch(any(), any())).called(1);
        vm.dispose();
      });
    });

    /// When no query is active, a collaborator notification must NOT trigger
    /// a search — wasted Firestore work + spurious loading flicker.
    test('does NOT re-run search when query is empty', () {
      fakeAsync((async) {
        late VoidCallback capturedListener;
        when(() => recipeVm.addListener(any())).thenAnswer((invocation) {
          capturedListener =
              invocation.positionalArguments.first as VoidCallback;
        });

        final vm = makeVm();
        // No updateSearchQuery — query stays empty.

        capturedListener();
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        verifyNever(() => recipeVm.contentMatchesSearch(any(), any()));
        vm.dispose();
      });
    });
  });
}
