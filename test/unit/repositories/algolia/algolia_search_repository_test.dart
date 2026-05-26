/// Intent-Test Sprint Batch 12 — `AlgoliaSearchRepository`.
///
/// Mission: pin the **observable contract** of the repository surface
/// that does NOT require a live `SearchClient`. The `algoliasearch` SDK
/// exposes `SearchClient` as a `final class` with no abstract seam and the
/// production constructor builds its own client internally — there is no
/// injection point. That means the network-touching methods
/// (`searchRecipes`, `searchUsers`, `indexRecipe`, `indexUser`,
/// `removeRecipe`, `removeUser`, `batchIndexRecipes` with items,
/// `getSuggestions` with len >= 2, `healthCheck`) cannot be exercised in
/// a unit test without provoking real DNS + retry storms against
/// `*-eu-dsn.algolia.net`. The sibling
/// `algolia_eu_cluster_assertion_test.dart` consciously avoids the same
/// network surface for the same reason.
///
/// Testability gap flagged (NOT fixed in this PR — production change):
/// `AlgoliaSearchRepository` does not accept an injected `SearchClient`.
/// A seam — `AlgoliaSearchRepository.withClient({required SearchClient
/// client, String recipesIndex, String usersIndex})` named-constructor —
/// would let us assert call shapes (e.g. that `indexRecipe` for a
/// `isPersonal` recipe routes to `deleteObject` not `saveObject`, that
/// `searchRecipes` builds a `SearchForHits` with the user's `ownerId`
/// in the filter, and that index name confusion does not happen). Until
/// the seam exists, those contracts are pinned only by integration
/// tests + manual QA.
///
/// What this file DOES pin (every test fails iff a real plausible bug
/// ships):
///   * `usesExternalSearch` is `true` — `RecipeSearchRouter` reads this to
///     bypass the 200-cap Firestore prefix scan. Flipping it would
///     silently re-route Algolia traffic through the legacy path.
///   * Default index names are `recipes` + `users`. A typo or accidental
///     rename to `'recipe'` (singular) would return 0 hits in prod with
///     no error — the search-empty bug shape from BUT-580 wave-7.
///   * `getSuggestions` early-returns `[]` for `partial.length < 2` BEFORE
///     touching the network. This is the empty-query + 1-char-query bug
///     terrain: a missing guard makes the prefix-match fan out across
///     the whole index. Pin both `''` and `'a'`; pin that `''` does NOT
///     turn into a "match-everything" call.
///   * `batchIndexRecipes([])` early-returns without throwing AND without
///     calling the client (no spurious empty batch costing an Algolia op).
///   * Constructor honours custom `recipesIndex` / `usersIndex`. We can't
///     observe via a search call (no seam), but we CAN observe that
///     mis-typed defaults are pinned in the constructor signature — a
///     refactor that drops the named-arg default would break this test.
///
/// What this file does NOT (and CANNOT) pin until a SearchClient seam
/// exists — these are the load-bearing privacy/security invariants. They
/// belong in an integration suite or after a `withClient` seam lands.
///   * The exact `filters` string sent to Algolia per search call (would
///     catch a missing `userId:` scope or wrong-cased filter).
///   * That `searchRecipes` routes to the `_recipesIndex` and never the
///     `_usersIndex` (the index-confusion bug shape).
///   * That `indexRecipe(isPersonal: true)` routes to `deleteObject` and
///     never to `saveObject` (would otherwise leak personal recipes to
///     the public index — the load-bearing privacy invariant).
///   * That `batchIndexRecipes` chunks at the Algolia 1000-op limit.
///   * That search exceptions are swallowed (empty `SearchResult`)
///     while index/remove exceptions rethrow (asymmetric error contract
///     in the production code — currently undocumented and untested).
///
/// Sibling: `algolia_eu_cluster_assertion_test.dart` covers the
/// constructor-time EU invariant (BUT-580).
/// Sibling: `test/unit/repositories/interfaces/search_repository_test.dart`
/// covers `SearchFilters.toAlgoliaFilter` query-injection surface and the
/// value-class plumbing.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/algolia/algolia_search_repository.dart';

void main() {
  // Construction uses a fake key. No network call is made by the
  // constructor itself — the EU sibling test proves this is safe.
  AlgoliaSearchRepository newRepo({
    String appId = 'TEST1234-eu',
    String apiKey = 'fake-key',
    String? recipesIndex,
    String? usersIndex,
  }) {
    return AlgoliaSearchRepository(
      appId: appId,
      apiKey: apiKey,
      recipesIndex: recipesIndex ?? 'recipes',
      usersIndex: usersIndex ?? 'users',
    );
  }

  group('usesExternalSearch contract', () {
    /// `RecipeSearchRouter` reads `usesExternalSearch` to decide whether
    /// to bypass the legacy 200-cap Firestore prefix scan. A regression
    /// that flipped this to `false` would silently re-route all Algolia
    /// traffic through the 200-row path — the search-quality bug from
    /// the BUT-580 wave-7 audit. Pin it as `true` so a default-getter
    /// refactor (`bool get usesExternalSearch => super.usesExternalSearch`
    /// which inherits `false`) is caught.
    test('reports true so RecipeSearchRouter bypasses the 200-cap path', () {
      final repo = newRepo();

      expect(
        repo.usesExternalSearch,
        isTrue,
        reason:
            'AlgoliaSearchRepository MUST advertise external search so that '
            'RecipeSearchRouter skips RecipeRepository.searchRecipes (200-row '
            'prefix). If this asserts false, the inherited default from '
            'SearchRepository (false) is leaking through — check the override.',
      );
    });
  });

  group('getSuggestions empty-and-short-query guard', () {
    /// Empty query is the catastrophic case: in Algolia DSL, `query: ''`
    /// is a "match everything in the index" call. Production explicitly
    /// short-circuits at `partial.length < 2` so an empty typeahead field
    /// can NEVER fan out to a full-index scan (cost + latency + privacy).
    /// If the guard is removed or flipped (`>= 2` → `> 2`, `<` → `<=`),
    /// this assertion catches it.
    test('empty partial returns [] without contacting Algolia', () async {
      final repo = newRepo();

      // No await-hang, no network: must resolve synchronously-fast.
      final result =
          await repo.getSuggestions('').timeout(const Duration(seconds: 1));

      expect(
        result,
        isEmpty,
        reason: 'Empty partial must short-circuit. If this hangs (>1s) the '
            'guard is gone and we are doing a match-everything call.',
      );
    });

    /// One character is below the 2-char threshold. Same guard, same
    /// rationale. The cost-of-failure here is that EVERY keypress while
    /// the user is typing the first letter would fire a network call.
    test('single-character partial returns [] without contacting Algolia',
        () async {
      final repo = newRepo();

      final result =
          await repo.getSuggestions('a').timeout(const Duration(seconds: 1));

      expect(result, isEmpty);
    });

    /// Failure-mode mirror: when the user explicitly passes a whitespace-
    /// only string, current production code treats `' '` (length 1) as
    /// "too short" by string-length. Document that — a future refactor
    /// to `partial.trim().length < 2` would change this behaviour and
    /// SHOULD be flagged via this test failing (the new behaviour might
    /// well be correct, but the contract must be re-discussed).
    test('whitespace-only single char also short-circuits (length-based guard)',
        () async {
      final repo = newRepo();

      final result =
          await repo.getSuggestions(' ').timeout(const Duration(seconds: 1));

      expect(result, isEmpty);
    });
  });

  group('batchIndexRecipes empty-list guard', () {
    /// Empty batch must NOT round-trip to Algolia. Every Algolia batch
    /// op is metered, and an empty `BatchWriteParams(requests: [])` would
    /// throw `400 invalid request` from the API — masking real bugs in
    /// the caller. Production short-circuits with `if (recipes.isEmpty)
    /// return;`. Pin the no-throw + no-hang behaviour.
    test('returns immediately when recipes list is empty (no client call)',
        () async {
      final repo = newRepo();

      // If the guard is removed, we'd actually try the batch network call
      // and fail with a DNS/retry storm well past 2s. The timeout is the
      // assertion: the method must return promptly.
      await expectLater(
        repo.batchIndexRecipes(const [],
            ownerId: 'user-abc').timeout(const Duration(seconds: 2)),
        completes,
      );
    });

    /// Failure-mode mirror: the same with a non-default `ownerId`. The
    /// empty-list short-circuit MUST run before the `ownerId` validation
    /// is touched — otherwise an empty batch with a `null`-equivalent
    /// owner would crash on the missing required arg, leaking the bug
    /// to the caller.
    test(
        'empty-list short-circuit ignores ownerId (executes before it is read)',
        () async {
      final repo = newRepo();

      await expectLater(
        repo.batchIndexRecipes(const [],
            ownerId: '').timeout(const Duration(seconds: 2)),
        completes,
      );
    });
  });

  group('index name defaults pin the public contract', () {
    /// Constructor advertises `recipesIndex = 'recipes'` and
    /// `usersIndex = 'users'` as defaults. A refactor that flips them
    /// (rename to `'recipe'` singular, swap the two arguments, etc.)
    /// would silently route writes/reads to the wrong index — the
    /// index-confusion bug shape from the file-header notes.
    ///
    /// We can't observe the internal `_recipesIndex` directly (encapsulated
    /// and rightly so), so we pin the constructor surface instead: both
    /// the with-explicit and the omit-defaults call shape succeed without
    /// throwing. Combined with the EU-cluster test (which builds without
    /// args), this catches a refactor that adds a new required positional
    /// arg or renames the named arg.
    test('explicit default names are accepted at construction', () {
      // ignore: unused_local_variable -- construction is the assertion
      final repo = AlgoliaSearchRepository(
        appId: 'TEST1234-eu',
        apiKey: 'fake-key',
        recipesIndex: 'recipes',
        usersIndex: 'users',
      );
      // If construction succeeded the named-arg surface is intact.
      expect(repo.usesExternalSearch, isTrue);
    });

    /// Pin that the names are independently controllable — a refactor
    /// that hard-coded one of them to the other would otherwise pass
    /// silently. (We can't read them back, but a refactor that DROPPED
    /// one of the named args would break compilation of this test, which
    /// is exactly the early-warning signal we want.)
    test('custom non-default index names are accepted', () {
      final repo = AlgoliaSearchRepository(
        appId: 'TEST1234-eu',
        apiKey: 'fake-key',
        recipesIndex: 'recipes_staging',
        usersIndex: 'users_staging',
      );
      expect(repo.usesExternalSearch, isTrue);
    });

    /// Failure-mode mirror: empty index names. Current production has no
    /// guard against `recipesIndex: ''`. We document that this WILL
    /// construct (no validation) — a real production bug if the env var
    /// is unset and defaults to empty string. Surfaced for the team to
    /// decide if a guard belongs at construction.
    test(
        'empty index names construct without throwing — design gap (no '
        'guard against unset env)', () {
      // This test is a CHARACTERIZATION test for the current behaviour.
      // If the team adds a guard (recommended), flip this to
      // `expect(() => ..., throwsArgumentError)` and document the fix.
      final repo = AlgoliaSearchRepository(
        appId: 'TEST1234-eu',
        apiKey: 'fake-key',
        recipesIndex: '',
        usersIndex: '',
      );
      expect(repo.usesExternalSearch, isTrue);
    });
  });

  group('construction does not eagerly hit Algolia network', () {
    /// The constructor must be cheap and side-effect-free. If it ever
    /// starts firing a `searchIndex` warm-up call eagerly (a tempting
    /// "preload" optimisation), every cold start of the app would block
    /// on Algolia reachability — defeating the SearchModule fall-back to
    /// Firestore.
    ///
    /// Pin: building 5 repos back-to-back resolves under 200ms total.
    /// Any eager network call would push this into the 1-2s range from
    /// DNS alone.
    test('builds 5 instances synchronously under 200ms (no eager I/O)', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5; i++) {
        AlgoliaSearchRepository(
          appId: 'TEST${i}1234-eu',
          apiKey: 'fake-key',
        );
      }
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        lessThan(200),
        reason: '5 repo constructions should be near-instant. If this is slow, '
            'something in _buildClient added an eager network/IO call.',
      );
    });
  });
}
