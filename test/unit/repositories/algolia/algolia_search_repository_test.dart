/// Intent-Test Sprint Batch 12 + BUT-1130 — `AlgoliaSearchRepository`.
///
/// BUT-1130 closed the testability gap flagged in the original header: the
/// `algoliasearch` SDK exposes `SearchClient` as a `final class` with no
/// abstract seam, so the network-touching privacy invariants could not be
/// unit-verified without provoking real DNS + retry storms against
/// `*-eu.algolia.net`. The production code now depends on a thin
/// [AlgoliaClient] wrapper and exposes `AlgoliaSearchRepository.withClient`
/// for injection. This file fakes that wrapper to pin the load-bearing
/// contracts directly:
///
///   * `searchRecipes` carries the caller's `ownerId` into the Algolia
///     `filters` string and queries the `recipes` index — never the
///     `users` index (the index-confusion + missing-scope bug shapes).
///   * `indexRecipe` gates on the recipe's actual discoverability
///     (`recipe.isPublic`), NOT on the inverse of `isPersonal`. A recipe
///     that is not publicly discoverable — personal, OR a group-scoped
///     shared/collaborative recipe with `isPublic:false` — routes to
///     `deleteObject` and NEVER to `saveObject` (the load-bearing privacy
///     invariant: nothing group-scoped may land in the global discovery
///     index). Only a truly-public recipe routes to `saveObject` with
///     `isPublic:true`.
///   * Asymmetric error contract: a failing SEARCH swallows the error and
///     returns an empty `SearchResult`; a failing INDEX/REMOVE rethrows so
///     the caller (Cloud Function / write path) can retry. Mixing these up
///     would either hide write failures or crash the user's search box.
///
/// The remaining no-seam contracts (constructor surface, empty-query
/// guards, no-eager-IO) are still pinned below without the seam — they
/// don't need it and the timeout-based assertions are a useful belt-and-
/// suspenders against a removed guard re-introducing a network fan-out.
///
/// Sibling: `algolia_eu_cluster_assertion_test.dart` covers the
/// constructor-time EU invariant (BUT-580).
/// Sibling: `test/unit/repositories/interfaces/search_repository_test.dart`
/// covers `SearchFilters.toAlgoliaFilter` query-injection surface.
library;

import 'package:algoliasearch/algoliasearch.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/algolia/algolia_search_repository.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';

/// Records every call so tests can assert the exact endpoint, index, and
/// payload the repository sent — the whole point of the BUT-1130 seam.
///
/// Each method either returns a canned success response or throws the
/// configured error, so the search-swallows-vs-index-rethrows contract is
/// exercisable. No network, no SDK internals.
class _FakeAlgoliaClient implements AlgoliaClient {
  _FakeAlgoliaClient({
    this.searchHits = const [],
    this.throwOnSearch = false,
    this.throwOnSave = false,
    this.throwOnDelete = false,
    this.throwOnBatch = false,
  });

  final List<Hit> searchHits;
  final bool throwOnSearch;
  final bool throwOnSave;
  final bool throwOnDelete;
  final bool throwOnBatch;

  final List<SearchForHits> searchRequests = [];
  final List<({String indexName, Object body})> saveCalls = [];
  final List<({String indexName, String objectID})> deleteCalls = [];
  final List<({String indexName, BatchWriteParams params})> batchCalls = [];

  @override
  Future<SearchResponse> searchIndex({required SearchForHits request}) async {
    searchRequests.add(request);
    if (throwOnSearch) throw StateError('algolia search boom');
    return SearchResponse(
      hits: searchHits,
      query: request.query ?? '',
      params: '',
      nbHits: searchHits.length,
      page: 0,
      nbPages: 1,
      processingTimeMS: 1,
    );
  }

  @override
  Future<SaveObjectResponse> saveObject({
    required String indexName,
    required Object body,
  }) async {
    saveCalls.add((indexName: indexName, body: body));
    if (throwOnSave) throw StateError('algolia save boom');
    return SaveObjectResponse(createdAt: '2026-01-01T00:00:00Z', taskID: 1);
  }

  @override
  Future<DeletedAtResponse> deleteObject({
    required String indexName,
    required String objectID,
  }) async {
    deleteCalls.add((indexName: indexName, objectID: objectID));
    if (throwOnDelete) throw StateError('algolia delete boom');
    return DeletedAtResponse(taskID: 1, deletedAt: '2026-01-01T00:00:00Z');
  }

  @override
  Future<BatchResponse> batch({
    required String indexName,
    required BatchWriteParams batchWriteParams,
  }) async {
    batchCalls.add((indexName: indexName, params: batchWriteParams));
    if (throwOnBatch) throw StateError('algolia batch boom');
    return const BatchResponse(taskID: 1, objectIDs: []);
  }
}

Recipe _personalRecipe({String title = 'Hemlig pasta'}) => Recipe.personal(
      title: title,
      description: 'desc',
      ingredients: const ['mjölk'],
      instructions: const ['blanda'],
      mealType: 'Middag',
      createdBy: 'user-alice',
    );

/// A truly-public, discoverable recipe (`isPublic == true`).
Recipe _sharedRecipe({String title = 'Delad pasta'}) => Recipe.collaborative(
      title: title,
      description: 'desc',
      ingredients: const ['mjölk'],
      instructions: const ['blanda'],
      mealType: 'Middag',
      ownerId: 'user-alice',
      ownerDisplayName: 'Alice',
    );

/// A group-scoped recipe shared with a specific group/friend but NOT publicly
/// discoverable (`isPublic == false`). `collaborative`/`shared` only describe
/// the editing/visibility model within a closed group — they do not imply
/// global discovery. Such a recipe must NEVER land in the public Algolia index.
Recipe _groupScopedRecipe({String title = 'Grupprecept'}) =>
    _sharedRecipe(title: title).copyWith(isPublic: false);

void main() {
  AlgoliaSearchRepository repoWith(_FakeAlgoliaClient client) =>
      AlgoliaSearchRepository.withClient(client: client);

  // ---------------------------------------------------------------------
  // BUT-1130 — privacy invariants, now unit-verifiable via the seam.
  // ---------------------------------------------------------------------

  group('searchRecipes ownerId scoping + index isolation (BUT-1130)', () {
    /// The most security-relevant contract: when a caller scopes a search
    /// to their own recipes, the `ownerId` MUST reach Algolia in the
    /// `filters` string. A regression that dropped the filter would expose
    /// every user's recipes to every search — a horizontal-privilege leak.
    test('carries the caller ownerId into the Algolia filters string',
        () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      await repo.searchRecipes(
        'pasta',
        filters: const SearchFilters(ownerId: 'user-alice'),
      );

      expect(fake.searchRequests, hasLength(1));
      expect(
        fake.searchRequests.single.filters,
        contains('ownerId:"user-alice"'),
        reason: 'Missing ownerId scope leaks other users\' recipes into '
            'the result set.',
      );
    });

    /// Recipe search must hit the recipes index, never the users index.
    /// Index confusion would return user-profile docs (with emails /
    /// follower graphs) shaped as recipe hits.
    test('queries the recipes index, never the users index', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      await repo.searchRecipes('pasta');

      expect(fake.searchRequests.single.indexName, 'recipes');
    });

    /// A search failure must degrade gracefully to an empty result — the
    /// user's search box must not crash because Algolia hiccuped. This is
    /// half of the asymmetric error contract.
    test('swallows a search failure and returns an empty SearchResult',
        () async {
      final fake = _FakeAlgoliaClient(throwOnSearch: true);
      final repo = repoWith(fake);

      final result = await repo.searchRecipes('pasta');

      expect(result.hits, isEmpty);
      expect(result.totalHits, 0);
    });

    /// And the happy path actually maps hits through, proving the fake
    /// round-trips real data (not a vacuously-passing empty default).
    test('maps Algolia hits into RecipeSearchHit on success', () async {
      final fake = _FakeAlgoliaClient(searchHits: [
        const Hit(
          objectID: 'recipe-1',
          additionalProperties: {
            'title': 'Pasta carbonara',
            'ownerId': 'user-alice',
          },
        ),
      ]);
      final repo = repoWith(fake);

      final result = await repo.searchRecipes('pasta');

      expect(result.hits, hasLength(1));
      expect(result.hits.single.id, 'recipe-1');
      expect(result.hits.single.title, 'Pasta carbonara');
      expect(result.hits.single.ownerId, 'user-alice');
    });
  });

  group('searchUsers index isolation (BUT-1130)', () {
    /// Mirror of the recipe-index check: user search must hit the users
    /// index and apply the `isPublic:true` filter so private profiles are
    /// never surfaced.
    test('queries the users index with the isPublic:true filter', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      await repo.searchUsers('alice');

      expect(fake.searchRequests.single.indexName, 'users');
      expect(fake.searchRequests.single.filters, 'isPublic:true');
    });

    /// Pins the user-hit field mapping. A regression that read the wrong
    /// keys (e.g. `name` instead of `displayName`) would silently render
    /// every result as a blank profile row — the social-search-broken
    /// bug shape. This complements the recipe-hit mapping test above so
    /// both index shapes are round-tripped, not just routed.
    test('maps Algolia hits into UserSearchHit on success', () async {
      final fake = _FakeAlgoliaClient(searchHits: [
        const Hit(
          objectID: 'user-bob',
          additionalProperties: {
            'displayName': 'Bob',
            'recipeCount': 7,
            'followerCount': 42,
          },
        ),
      ]);
      final repo = repoWith(fake);

      final result = await repo.searchUsers('bob');

      expect(result.hits, hasLength(1));
      expect(result.hits.single.id, 'user-bob');
      expect(result.hits.single.displayName, 'Bob');
      expect(result.hits.single.recipeCount, 7);
      expect(result.hits.single.followerCount, 42);
    });

    /// Symmetry with the recipe-search swallow test: a users-index search
    /// failure must also degrade to an empty result, never crash the
    /// people-search box.
    test('swallows a search failure and returns an empty SearchResult',
        () async {
      final fake = _FakeAlgoliaClient(throwOnSearch: true);
      final repo = repoWith(fake);

      final result = await repo.searchUsers('alice');

      expect(result.hits, isEmpty);
      expect(result.totalHits, 0);
    });
  });

  group('indexUser / removeUser route to the users index (BUT-1130)', () {
    /// User indexing is a write that must land on the USERS index, never
    /// the recipes index. Index confusion here would pollute recipe
    /// discovery with profile documents (the inverse of the recipe-search
    /// index-confusion bug). The seam now lets us pin the routing directly
    /// instead of trusting the constructor surface.
    test('indexUser routes saveObject to the users index', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      await repo.indexUser(
        const UserSearchData(
          id: 'user-bob',
          displayName: 'Bob',
          isPublic: true,
        ),
      );

      expect(fake.saveCalls, hasLength(1));
      expect(fake.saveCalls.single.indexName, 'users');
      final body = fake.saveCalls.single.body as Map<String, dynamic>;
      expect(body['objectID'], 'user-bob');
    });

    test('removeUser routes deleteObject to the users index', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      await repo.removeUser('user-bob');

      expect(fake.deleteCalls, hasLength(1));
      expect(fake.deleteCalls.single.indexName, 'users');
      expect(fake.deleteCalls.single.objectID, 'user-bob');
    });

    /// Writes rethrow — same asymmetric contract as recipe writes. A
    /// swallowed indexUser failure would leave a stale/missing profile in
    /// the public index with no signal to retry.
    test('indexUser rethrows when saveObject fails', () async {
      final fake = _FakeAlgoliaClient(throwOnSave: true);
      final repo = repoWith(fake);

      await expectLater(
        () => repo.indexUser(
          const UserSearchData(
            id: 'user-bob',
            displayName: 'Bob',
            isPublic: true,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('removeUser rethrows when deleteObject fails', () async {
      final fake = _FakeAlgoliaClient(throwOnDelete: true);
      final repo = repoWith(fake);

      await expectLater(
        () => repo.removeUser('user-bob'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('getSuggestions happy path: index switching + extraction (BUT-1130)',
      () {
    /// A >=2-char recipe suggestion query must hit the RECIPES index and
    /// extract the `title` attribute. The default `index: 'recipes'` path
    /// is the typeahead users see most; a regression that read the wrong
    /// attribute would return blank suggestions.
    test('recipes suggestions query the recipes index and return titles',
        () async {
      final fake = _FakeAlgoliaClient(searchHits: [
        const Hit(
          objectID: 'r1',
          additionalProperties: {'title': 'Pasta carbonara'},
        ),
      ]);
      final repo = repoWith(fake);

      final result = await repo.getSuggestions('pa');

      expect(fake.searchRequests.single.indexName, 'recipes');
      expect(result, ['Pasta carbonara']);
    });

    /// The `index: 'users'` branch must switch to the USERS index and
    /// extract `displayName` — the other half of the index-switch fork.
    /// This pins that the two branches don't collapse to one index.
    test('users suggestions query the users index and return displayNames',
        () async {
      final fake = _FakeAlgoliaClient(searchHits: [
        const Hit(
          objectID: 'u1',
          additionalProperties: {'displayName': 'Alice'},
        ),
      ]);
      final repo = repoWith(fake);

      final result = await repo.getSuggestions('al', index: 'users');

      expect(fake.searchRequests.single.indexName, 'users');
      expect(result, ['Alice']);
    });

    /// Hits missing the searched attribute resolve to empty strings and
    /// MUST be filtered out — otherwise the typeahead shows blank rows.
    test('drops hits with an empty/absent attribute value', () async {
      final fake = _FakeAlgoliaClient(searchHits: const [
        Hit(objectID: 'r1', additionalProperties: {'title': 'Pizza'}),
        Hit(objectID: 'r2', additionalProperties: {}),
      ]);
      final repo = repoWith(fake);

      final result = await repo.getSuggestions('pi');

      expect(result, ['Pizza']);
    });
  });

  group('healthCheck (BUT-1130)', () {
    /// healthCheck is the SearchModule's reachability probe used to decide
    /// whether to use Algolia or fall back to Firestore. A reachable index
    /// must report true.
    test('returns true when the probe search succeeds', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      expect(await repo.healthCheck(), isTrue);
    });

    /// And it must return FALSE (not rethrow) when Algolia is unreachable,
    /// so the caller can fall back cleanly. A rethrow here would crash the
    /// fallback decision instead of triggering it.
    test('returns false when the probe search fails', () async {
      final fake = _FakeAlgoliaClient(throwOnSearch: true);
      final repo = repoWith(fake);

      expect(await repo.healthCheck(), isFalse);
    });
  });

  group('indexRecipe personal-vs-shared routing (BUT-1130)', () {
    /// THE load-bearing privacy invariant: a personal recipe must be
    /// REMOVED from the public index (deleteObject), never saved into it.
    /// If this routed to saveObject, every personal recipe would leak into
    /// public discovery search.
    test('personal recipe routes to deleteObject, never saveObject', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);
      final recipe = _personalRecipe();

      await repo.indexRecipe(recipe, ownerId: 'user-alice');

      expect(
        fake.saveCalls,
        isEmpty,
        reason: 'A personal recipe must NEVER be written to the public '
            'recipes index.',
      );
      expect(fake.deleteCalls, hasLength(1));
      expect(fake.deleteCalls.single.indexName, 'recipes');
      expect(fake.deleteCalls.single.objectID, recipe.id);
    });

    /// A truly-public recipe (isPublic:true) routes to saveObject on the
    /// recipes index with the indexed `isPublic` flag mirroring the model.
    test('public recipe routes to saveObject on the recipes index', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);
      final recipe = _sharedRecipe();

      await repo.indexRecipe(recipe, ownerId: 'user-alice');

      expect(fake.deleteCalls, isEmpty);
      expect(fake.saveCalls, hasLength(1));
      expect(fake.saveCalls.single.indexName, 'recipes');
      final body = fake.saveCalls.single.body as Map<String, dynamic>;
      expect(body['objectID'], recipe.id);
      expect(body['ownerId'], 'user-alice');
      expect(body['isPublic'], isTrue);
    });

    /// THE privacy fix: a group-scoped shared/collaborative recipe whose own
    /// `isPublic` flag is false must be EVICTED from the public index
    /// (deleteObject), never saved into it — mirroring the personal-recipe
    /// invariant. The previous `!recipe.isPersonal` guard leaked these into
    /// global discovery. This test fails against that buggy guard.
    test(
        'group-scoped recipe (isPublic:false) routes to deleteObject, '
        'never saveObject', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);
      final recipe = _groupScopedRecipe();
      expect(recipe.isPersonal, isFalse,
          reason: 'Guards the test premise: this is a non-personal recipe '
              'that is nonetheless not publicly discoverable.');

      await repo.indexRecipe(recipe, ownerId: 'user-alice');

      expect(
        fake.saveCalls,
        isEmpty,
        reason: 'A group-scoped recipe must NEVER be written to the public '
            'discovery index just because it is non-personal.',
      );
      expect(fake.deleteCalls, hasLength(1));
      expect(fake.deleteCalls.single.indexName, 'recipes');
      expect(fake.deleteCalls.single.objectID, recipe.id);
    });
  });

  group('asymmetric error contract: search swallows, write rethrows (BUT-1130)',
      () {
    /// The write path must rethrow so the Cloud Function / caller can
    /// retry or alert. Silently swallowing an index failure would leave
    /// the public index permanently stale.
    test('indexRecipe rethrows when saveObject fails', () async {
      final fake = _FakeAlgoliaClient(throwOnSave: true);
      final repo = repoWith(fake);

      await expectLater(
        () => repo.indexRecipe(_sharedRecipe(), ownerId: 'user-alice'),
        throwsA(isA<StateError>()),
      );
    });

    /// removeRecipe is also a write — a failed delete must rethrow so a
    /// personal recipe is not silently left in the public index.
    test('removeRecipe rethrows when deleteObject fails', () async {
      final fake = _FakeAlgoliaClient(throwOnDelete: true);
      final repo = repoWith(fake);

      await expectLater(
        () => repo.removeRecipe('recipe-1'),
        throwsA(isA<StateError>()),
      );
    });

    /// batchIndexRecipes is a write — a failed batch must rethrow.
    test('batchIndexRecipes rethrows when batch fails', () async {
      final fake = _FakeAlgoliaClient(throwOnBatch: true);
      final repo = repoWith(fake);

      await expectLater(
        () => repo.batchIndexRecipes([_sharedRecipe()], ownerId: 'user-alice'),
        throwsA(isA<StateError>()),
      );
    });

    /// getSuggestions is a read — like search it must swallow and return
    /// an empty list rather than crash the typeahead.
    test('getSuggestions swallows a search failure and returns []', () async {
      final fake = _FakeAlgoliaClient(throwOnSearch: true);
      final repo = repoWith(fake);

      final result = await repo.getSuggestions('pasta');

      expect(result, isEmpty);
    });
  });

  group('batchIndexRecipes routes to the recipes index (BUT-1130)', () {
    test('non-empty batch targets the recipes index', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      await repo.batchIndexRecipes(
        [_sharedRecipe(title: 'A'), _sharedRecipe(title: 'B')],
        ownerId: 'user-alice',
      );

      expect(fake.batchCalls, hasLength(1));
      expect(fake.batchCalls.single.indexName, 'recipes');
      expect(fake.batchCalls.single.params.requests, hasLength(2));
    });

    /// Group-scoped (isPublic:false) recipes must be filtered out of the batch
    /// — same discoverability invariant as the single-write path. Only the
    /// public recipe is sent.
    test('drops group-scoped (isPublic:false) recipes from the batch',
        () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      await repo.batchIndexRecipes(
        [_sharedRecipe(title: 'Public'), _groupScopedRecipe(title: 'Private')],
        ownerId: 'user-alice',
      );

      expect(fake.batchCalls, hasLength(1));
      expect(fake.batchCalls.single.params.requests, hasLength(1));
    });

    /// If every recipe in the batch is group-scoped, nothing is discoverable,
    /// so no client call is made at all (an empty BatchWriteParams is a
    /// metered 400 from Algolia).
    test('makes no client call when all recipes are non-public', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      await repo.batchIndexRecipes(
        [_groupScopedRecipe(title: 'a'), _groupScopedRecipe(title: 'b')],
        ownerId: 'user-alice',
      );

      expect(fake.batchCalls, isEmpty);
    });

    /// LATENT PRODUCTION BUG fix: Algolia caps a single batch at 1000 ops; a
    /// larger payload 400s/partial-fails. A full-library reindex must be
    /// chunked into <=1000-op calls. 2500 public recipes => 3 calls
    /// (1000 + 1000 + 500). This test fails against the old single-batch code.
    test('splits a >1000 batch into multiple <=1000-op calls', () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      final recipes = List.generate(
        2500,
        (i) => _sharedRecipe(title: 'recipe-$i'),
      );

      await repo.batchIndexRecipes(recipes, ownerId: 'user-alice');

      expect(fake.batchCalls, hasLength(3));
      expect(fake.batchCalls[0].params.requests, hasLength(1000));
      expect(fake.batchCalls[1].params.requests, hasLength(1000));
      expect(fake.batchCalls[2].params.requests, hasLength(500));
    });
  });

  // ---------------------------------------------------------------------
  // No-seam contracts (pre-BUT-1130) — still valuable, kept as-is.
  // ---------------------------------------------------------------------

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
    test('empty partial returns [] without contacting Algolia', () async {
      final repo = newRepo();

      final result =
          await repo.getSuggestions('').timeout(const Duration(seconds: 1));

      expect(
        result,
        isEmpty,
        reason: 'Empty partial must short-circuit. If this hangs (>1s) the '
            'guard is gone and we are doing a match-everything call.',
      );
    });

    test('single-character partial returns [] without contacting Algolia',
        () async {
      final repo = newRepo();

      final result =
          await repo.getSuggestions('a').timeout(const Duration(seconds: 1));

      expect(result, isEmpty);
    });

    test('whitespace-only single char also short-circuits (length-based guard)',
        () async {
      final repo = newRepo();

      final result =
          await repo.getSuggestions(' ').timeout(const Duration(seconds: 1));

      expect(result, isEmpty);
    });
  });

  group('batchIndexRecipes empty-list guard', () {
    test('returns immediately when recipes list is empty (no client call)',
        () async {
      final fake = _FakeAlgoliaClient();
      final repo = repoWith(fake);

      await repo.batchIndexRecipes(const [], ownerId: 'user-abc');

      expect(
        fake.batchCalls,
        isEmpty,
        reason: 'Empty batch must short-circuit before any client call — '
            'an empty BatchWriteParams is a metered 400 from Algolia.',
      );
    });
  });

  group('index name defaults pin the public contract', () {
    test('explicit default names are accepted at construction', () {
      final repo = AlgoliaSearchRepository(
        appId: 'TEST1234-eu',
        apiKey: 'fake-key',
        recipesIndex: 'recipes',
        usersIndex: 'users',
      );
      expect(repo.usesExternalSearch, isTrue);
    });

    test('custom non-default index names are accepted', () {
      final repo = AlgoliaSearchRepository(
        appId: 'TEST1234-eu',
        apiKey: 'fake-key',
        recipesIndex: 'recipes_staging',
        usersIndex: 'users_staging',
      );
      expect(repo.usesExternalSearch, isTrue);
    });

    /// Custom index names propagate through the seam: a repo built with a
    /// non-default recipes index routes writes there, not to the literal
    /// `'recipes'`. This pins that the named arg is actually wired through
    /// (a refactor that hard-coded `'recipes'` would break this).
    test('custom recipesIndex propagates to write routing', () async {
      final fake = _FakeAlgoliaClient();
      final repo = AlgoliaSearchRepository.withClient(
        client: fake,
        recipesIndex: 'recipes_staging',
      );

      await repo.indexRecipe(_sharedRecipe(), ownerId: 'user-alice');

      expect(fake.saveCalls.single.indexName, 'recipes_staging');
    });
  });

  group('construction does not eagerly hit Algolia network', () {
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
