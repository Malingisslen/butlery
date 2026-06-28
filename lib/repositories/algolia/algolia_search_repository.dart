// lib/repositories/algolia/algolia_search_repository.dart

import 'package:algoliasearch/algoliasearch.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/repositories/algolia/algolia_pinning_interceptor.dart';
import 'package:butlery/services/security/cert_pin_telemetry.dart';

/// Algolia implementation of SearchRepository.
///
/// Migration-ready design:
/// - Implements provider-agnostic SearchRepository interface
/// - Can be swapped with MeilisearchSearchRepository or TypesenseSearchRepository
/// - Feature flag controlled via FeatureFlagService
///
/// BUT-886 (wave-7 audit gap): intentional bypass of [BaseFirebaseRepository]
/// + [PermissionValidationMixin] + Firestore audit logging.
///
/// This repository does not touch Firestore — every query goes to Algolia
/// via the `SearchClient`. Firestore audit logging would be incoherent
/// (no Firestore op to audit). Index population is server-side via Cloud
/// Functions (`functions/src/algolia/`) which have their own logging.
///
/// Algolia-side telemetry (`userToken`, `clickAnalytics`, `analyticsTags`)
/// is intentionally NOT sent per BUT-580 (GDPR — queries reach Algolia
/// anonymously). If query-level audit ever becomes required, the right
/// surface is a Firestore `search_audit_logs` row written here per call,
/// NOT a `PermissionValidationMixin` extension.
///
/// Feature-flagged off in production (`FeatureFlagService.algoliaEnabled`).
/// Reassess this bypass when the feature flips on.
///
/// Index structure:
/// - `recipes` index: Public/shared recipes for discovery
/// - `users` index: Public user profiles for search
///
/// Configuration:
/// - App ID and API keys should be stored in .env or Firebase Remote Config
/// - Write API key for indexing (server-side or secure storage)
/// - Search API key for client-side queries (public, rate-limited)
///
/// GDPR (BUT-580):
/// - We do NOT pass `userToken`, `clickAnalytics`, or `analyticsTags` on any
///   `SearchForHits` request — queries reach Algolia anonymously.
/// - `assertEuCluster` enforces an EU-cluster app id at construction. Algolia
///   routes by app id; an EU app id keeps queries inside the EU region. If
///   the app id cannot be confirmed as EU, construction throws to surface a
///   Chapter V cross-border-transfer misconfiguration loudly rather than
///   silently leaking traffic to a US/AP cluster. Toggle off only for tests
///   that intentionally exercise the assertion path.
///
/// BUT-1130 (testability seam): the underlying `algoliasearch`
/// `SearchClient` is a `final class` with no abstract surface, so it can
/// neither be subclassed nor faked by Mockito. To make the load-bearing
/// privacy invariants unit-verifiable WITHOUT a live network — that
/// personal recipes route to `deleteObject` (never `saveObject` on the
/// public index), that `searchRecipes` carries the caller's `ownerId`
/// filter, that recipe ops never touch the users index, and the
/// search-swallows-vs-index-rethrows asymmetric error contract — the
/// repository depends on a thin [AlgoliaClient] wrapper instead of the
/// SDK type directly. Production wraps the real `SearchClient`; tests
/// inject a fake via [AlgoliaSearchRepository.withClient]. The wrapper is
/// deliberately minimal (only the four endpoints this repository calls)
/// to keep the seam cheap and avoid leaking the whole Algolia API.
class AlgoliaSearchRepository implements SearchRepository {
  final AlgoliaClient _searchClient;
  final String _recipesIndex;
  final String _usersIndex;

  /// Throws [ArgumentError] when the appId is not recognised as EU.
  ///
  /// Algolia EU dedicated clusters expose an app id ending in `-eu`
  /// (e.g. `XYZ123-eu`). Shared clusters cannot be region-asserted from the
  /// app id alone and require an explicit `assertEuCluster: false` plus an
  /// out-of-band region confirmation in the dashboard.
  static bool isLikelyEuAppId(String appId) {
    final lower = appId.toLowerCase();
    return lower.endsWith('-eu');
  }

  AlgoliaSearchRepository({
    required String appId,
    required String apiKey,
    String recipesIndex = 'recipes',
    String usersIndex = 'users',
    bool assertEuCluster = true,
  }) : _searchClient = _DefaultAlgoliaClient(
         _buildClient(
           appId: appId,
           apiKey: apiKey,
           assertEuCluster: assertEuCluster,
         ),
       ),
       _recipesIndex = recipesIndex,
       _usersIndex = usersIndex;

  /// Test seam (BUT-1130). Injects a fake [AlgoliaClient] so the privacy
  /// invariants — `ownerId` scoping, personal-recipe `deleteObject`
  /// routing, recipes-vs-users index isolation, and the
  /// search-swallows-vs-index-rethrows error contract — are assertable
  /// without provoking real DNS/retry storms against `*-eu.algolia.net`.
  /// This bypasses the EU-cluster assertion intentionally: the fake never
  /// leaves the process, so there is no cross-border transfer to guard.
  @visibleForTesting
  AlgoliaSearchRepository.withClient({
    required AlgoliaClient client,
    String recipesIndex = 'recipes',
    String usersIndex = 'users',
  }) : _searchClient = client,
       _recipesIndex = recipesIndex,
       _usersIndex = usersIndex;

  /// Build the underlying SearchClient, enforcing the EU-cluster invariant.
  ///
  /// Runtime check (not `assert`) so release builds enforce too — a mis-
  /// configured app id silently routing to a US cluster would be a GDPR
  /// Chapter V breach. Throws [ArgumentError] loudly so the DI module can
  /// catch and fall back to Firestore search.
  static SearchClient _buildClient({
    required String appId,
    required String apiKey,
    required bool assertEuCluster,
  }) {
    if (assertEuCluster && !isLikelyEuAppId(appId)) {
      throw ArgumentError.value(
        appId,
        'appId',
        'BUT-580: Algolia appId is not recognised as EU. GDPR Chapter V '
            'forbids unverified cross-border transfer. Use an EU dedicated '
            'cluster (app id ending in "-eu") or pass assertEuCluster: '
            'false after confirming region in the Algolia dashboard.',
      );
    }
    return SearchClient(
      appId: appId,
      apiKey: apiKey,
      // BUT-427: per-host SSL pinning interceptor. Pinning is no-op for
      // hosts without configured pins (CertPinConfig). The interceptor
      // logs `ssl_pin_mismatch` analytics events and rejects the request
      // on mismatch — soft-fail at the app level, not at the cert level.
      options: ClientOptions(
        interceptors: [
          PinningDioInterceptor(
            onPinMismatch: reportSslPinMismatch,
          ),
        ],
      ),
    );
  }

  @override
  bool get usesExternalSearch => true;

  @override
  Future<SearchResult<RecipeSearchHit>> searchRecipes(
    String query, {
    SearchFilters? filters,
    int page = 0,
    int hitsPerPage = 20,
  }) async {
    try {
      final searchRequest = SearchForHits(
        indexName: _recipesIndex,
        query: query,
        page: page,
        hitsPerPage: hitsPerPage,
        filters: filters?.toAlgoliaFilter(),
        attributesToHighlight: ['title', 'description'],
        highlightPreTag: '<em>',
        highlightPostTag: '</em>',
      );

      final response = await _searchClient.searchIndex(request: searchRequest);

      final hits = response.hits.map((hit) {
        final data = hit.toJson();
        final highlight = data['_highlightResult'] as Map<String, dynamic>?;

        return RecipeSearchHit(
          id: (data['objectID'] as String?).orEmpty(),
          title: (data['title'] as String?).orEmpty(),
          description: data['description'] as String?,
          imageUrl: data['imageUrl'] as String?,
          timeMinutes: data['timeMinutes'] as int?,
          portions: data['portions'] as int?,
          rating: (data['rating'] as num?)?.toDouble(),
          mealType: data['mealType'] as String? ?? 'Middag',
          tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
          ownerDisplayName: (data['ownerDisplayName'] as String?).orEmpty(),
          ownerId: (data['ownerId'] as String?).orEmpty(),
          highlightedTitle: _extractHighlightValue(highlight, 'title'),
          highlightedDescription: _extractHighlightValue(
            highlight,
            'description',
          ),
        );
      }).toList();

      return SearchResult(
        hits: hits,
        totalHits: response.nbHits ?? 0,
        page: response.page ?? 0,
        totalPages: response.nbPages ?? 1,
        processingTimeMs: response.processingTimeMS ?? 0,
        queryId: response.queryID,
      );
    } catch (e) {
      // Flag the failure (vs a legitimate 0-hit search) so callers can fall
      // back to Firestore / show an offline banner instead of a silent empty
      // state — e.g. on an SSL-pin mismatch or Algolia outage (BUT-1416).
      AppLogger.error('Algolia recipe search failed', e);
      return SearchResult<RecipeSearchHit>.failure(page: page);
    }
  }

  @override
  Future<SearchResult<UserSearchHit>> searchUsers(
    String query, {
    int page = 0,
    int hitsPerPage = 20,
  }) async {
    try {
      final searchRequest = SearchForHits(
        indexName: _usersIndex,
        query: query,
        page: page,
        hitsPerPage: hitsPerPage,
        filters: 'isPublic:true',
      );

      final response = await _searchClient.searchIndex(request: searchRequest);

      final hits = response.hits.map((hit) {
        final data = hit.toJson();
        return UserSearchHit(
          id: (data['objectID'] as String?).orEmpty(),
          displayName: (data['displayName'] as String?).orEmpty(),
          avatarUrl: data['avatarUrl'] as String?,
          recipeCount: data['recipeCount'] as int? ?? 0,
          followerCount: data['followerCount'] as int? ?? 0,
        );
      }).toList();

      return SearchResult(
        hits: hits,
        totalHits: response.nbHits ?? 0,
        page: response.page ?? 0,
        totalPages: response.nbPages ?? 1,
        processingTimeMs: response.processingTimeMS ?? 0,
        queryId: response.queryID,
      );
    } catch (e) {
      // See searchRecipes: flag provider failure so callers can degrade
      // gracefully rather than render a misleading empty result (BUT-1416).
      AppLogger.error('Algolia user search failed', e);
      return SearchResult<UserSearchHit>.failure(page: page);
    }
  }

  @override
  Future<void> indexRecipe(Recipe recipe, {required String ownerId}) async {
    // Gate on the recipe's actual discoverability flag, not on the inverse of
    // isPersonal. `shared`/`collaborative`/`realtime` are group-scoped sharing
    // models — they do NOT imply GLOBAL public discovery. A recipe shared only
    // with a friend/group has isPublic:false and must be evicted from the
    // public discovery index, otherwise it leaks into global search
    // (horizontal-privilege/privacy leak).
    if (!recipe.isPublic) {
      await removeRecipe(recipe.id);
      return;
    }

    try {
      await _searchClient.saveObject(
        indexName: _recipesIndex,
        body: _recipeToSearchDocument(recipe, ownerId),
      );
      AppLogger.debug('Indexed recipe ${recipe.id} to Algolia');
    } catch (e) {
      AppLogger.error('Failed to index recipe ${recipe.id}', e);
      rethrow;
    }
  }

  @override
  Future<void> removeRecipe(String recipeId) async {
    try {
      await _searchClient.deleteObject(
        indexName: _recipesIndex,
        objectID: recipeId,
      );
      AppLogger.debug('Removed recipe $recipeId from Algolia');
    } catch (e) {
      AppLogger.error('Failed to remove recipe $recipeId', e);
      rethrow;
    }
  }

  @override
  Future<void> indexUser(UserSearchData user) async {
    try {
      await _searchClient.saveObject(
        indexName: _usersIndex,
        body: user.toSearchDocument(),
      );
      AppLogger.debug('Indexed user ${user.id} to Algolia');
    } catch (e) {
      AppLogger.error('Failed to index user ${user.id}', e);
      rethrow;
    }
  }

  @override
  Future<void> removeUser(String userId) async {
    try {
      await _searchClient.deleteObject(
        indexName: _usersIndex,
        objectID: userId,
      );
      AppLogger.debug('Removed user ${userId.maskedUserId} from Algolia');
    } catch (e) {
      AppLogger.error('Failed to remove user ${userId.maskedUserId}', e);
      rethrow;
    }
  }

  /// Algolia caps a single `batch` call at 1000 operations; a larger payload
  /// 400s / partial-fails. Mirror the Firestore 500-op batch pattern and chunk.
  static const int _algoliaBatchLimit = 1000;

  @override
  Future<void> batchIndexRecipes(
    List<Recipe> recipes, {
    required String ownerId,
  }) async {
    // Only publicly-discoverable recipes belong in the public index — same
    // invariant as indexRecipe. Group-scoped (isPublic:false) recipes are
    // dropped here rather than leaked into global discovery.
    final requests = recipes
        .where((recipe) => recipe.isPublic)
        .map(
          (recipe) => BatchRequest(
            action: Action.addObject,
            body: _recipeToSearchDocument(recipe, ownerId),
          ),
        )
        .toList();

    if (requests.isEmpty) return;

    try {
      for (
        var start = 0;
        start < requests.length;
        start += _algoliaBatchLimit
      ) {
        final chunk = requests.sublist(
          start,
          (start + _algoliaBatchLimit).clamp(0, requests.length),
        );
        await _searchClient.batch(
          indexName: _recipesIndex,
          batchWriteParams: BatchWriteParams(requests: chunk),
        );
      }
      AppLogger.debug('Batch indexed ${requests.length} recipes to Algolia');
    } catch (e) {
      AppLogger.error('Failed to batch index recipes', e);
      rethrow;
    }
  }

  @override
  Future<List<String>> getSuggestions(
    String partial, {
    String index = 'recipes',
    int limit = 5,
  }) async {
    if (partial.length < 2) return [];

    try {
      final indexName = index == 'recipes' ? _recipesIndex : _usersIndex;
      final attributeToSearch = index == 'recipes' ? 'title' : 'displayName';

      final searchRequest = SearchForHits(
        indexName: indexName,
        query: partial,
        hitsPerPage: limit,
        attributesToRetrieve: [attributeToSearch],
      );

      final response = await _searchClient.searchIndex(request: searchRequest);

      return response.hits
          .map((hit) {
            final data = hit.toJson();
            return (data[attributeToSearch] as String?).orEmpty();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get suggestions', e);
      return [];
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final searchRequest = SearchForHits(
        indexName: _recipesIndex,
        query: '',
        hitsPerPage: 1,
      );

      await _searchClient.searchIndex(request: searchRequest);
      return true;
    } catch (e) {
      AppLogger.error('Algolia health check failed', e);
      return false;
    }
  }

  /// Convert recipe to Algolia document format.
  Map<String, dynamic> _recipeToSearchDocument(Recipe recipe, String ownerId) {
    return {
      'objectID': recipe.id,
      'title': recipe.title,
      'description': recipe.description,
      'imageUrl': recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
      'timeMinutes': recipe.timeMinutes,
      'portions': recipe.portions,
      'rating': recipe.rating,
      'mealType': recipe.mealType,
      'tags': recipe.personalTagIds ?? [],
      'ownerId': ownerId,
      'ownerDisplayName': '', // Should be set by caller with user data
      'isPublic': recipe.isPublic,
      'createdAt': recipe.createdAt.millisecondsSinceEpoch,
      'updatedAt': recipe.updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Extract highlighted value from Algolia response.
  String? _extractHighlightValue(
    Map<String, dynamic>? highlight,
    String field,
  ) {
    if (highlight == null) return null;
    final fieldHighlight = highlight[field] as Map<String, dynamic>?;
    return fieldHighlight?['value'] as String?;
  }
}

/// Thin seam over the `algoliasearch` `SearchClient` (BUT-1130).
///
/// The SDK's `SearchClient` is a `final class`, so it cannot be subclassed
/// or mocked. This interface exposes only the four endpoints
/// [AlgoliaSearchRepository] actually calls, letting tests inject a fake
/// to assert call shapes (index name, `ownerId` filter, save-vs-delete
/// routing) and error propagation without any network I/O.
///
/// Signatures mirror the SDK exactly so [_DefaultAlgoliaClient] is a
/// pass-through and the production code path is unchanged.
abstract class AlgoliaClient {
  Future<SearchResponse> searchIndex({required SearchForHits request});

  Future<SaveObjectResponse> saveObject({
    required String indexName,
    required Object body,
  });

  Future<DeletedAtResponse> deleteObject({
    required String indexName,
    required String objectID,
  });

  Future<BatchResponse> batch({
    required String indexName,
    required BatchWriteParams batchWriteParams,
  });
}

/// Production [AlgoliaClient] delegating to the real `SearchClient`.
class _DefaultAlgoliaClient implements AlgoliaClient {
  _DefaultAlgoliaClient(this._client);

  final SearchClient _client;

  @override
  Future<SearchResponse> searchIndex({required SearchForHits request}) =>
      _client.searchIndex(request: request);

  @override
  Future<SaveObjectResponse> saveObject({
    required String indexName,
    required Object body,
  }) => _client.saveObject(indexName: indexName, body: body);

  @override
  Future<DeletedAtResponse> deleteObject({
    required String indexName,
    required String objectID,
  }) => _client.deleteObject(indexName: indexName, objectID: objectID);

  @override
  Future<BatchResponse> batch({
    required String indexName,
    required BatchWriteParams batchWriteParams,
  }) => _client.batch(indexName: indexName, batchWriteParams: batchWriteParams);
}
