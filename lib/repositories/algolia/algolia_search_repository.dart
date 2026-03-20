// lib/repositories/algolia/algolia_search_repository.dart

import 'package:algoliasearch/algoliasearch.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Algolia implementation of SearchRepository.
///
/// Migration-ready design:
/// - Implements provider-agnostic SearchRepository interface
/// - Can be swapped with MeilisearchSearchRepository or TypesenseSearchRepository
/// - Feature flag controlled via FeatureFlagService
///
/// Index structure:
/// - `recipes` index: Public/shared recipes for discovery
/// - `users` index: Public user profiles for search
///
/// Configuration:
/// - App ID and API keys should be stored in .env or Firebase Remote Config
/// - Write API key for indexing (server-side or secure storage)
/// - Search API key for client-side queries (public, rate-limited)
class AlgoliaSearchRepository implements SearchRepository {
  final SearchClient _searchClient;
  final String _recipesIndex;
  final String _usersIndex;

  AlgoliaSearchRepository({
    required String appId,
    required String apiKey,
    String recipesIndex = 'recipes',
    String usersIndex = 'users',
  })  : _searchClient = SearchClient(appId: appId, apiKey: apiKey),
        _recipesIndex = recipesIndex,
        _usersIndex = usersIndex;

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
          id: data['objectID'] as String? ?? '',
          title: data['title'] as String? ?? '',
          description: data['description'] as String?,
          imageUrl: data['imageUrl'] as String?,
          timeMinutes: data['timeMinutes'] as int?,
          portions: data['portions'] as int?,
          rating: (data['rating'] as num?)?.toDouble(),
          mealType: data['mealType'] as String? ?? 'Middag',
          tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
          ownerDisplayName: data['ownerDisplayName'] as String? ?? '',
          ownerId: data['ownerId'] as String? ?? '',
          highlightedTitle: _extractHighlightValue(highlight, 'title'),
          highlightedDescription:
              _extractHighlightValue(highlight, 'description'),
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
      AppLogger.error('Algolia recipe search failed', e);
      return const SearchResult(
        hits: [],
        totalHits: 0,
        page: 0,
        totalPages: 0,
        processingTimeMs: 0,
      );
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
          id: data['objectID'] as String? ?? '',
          displayName: data['displayName'] as String? ?? '',
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
      AppLogger.error('Algolia user search failed', e);
      return const SearchResult(
        hits: [],
        totalHits: 0,
        page: 0,
        totalPages: 0,
        processingTimeMs: 0,
      );
    }
  }

  @override
  Future<void> indexRecipe(Recipe recipe, {required String ownerId}) async {
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

  @override
  Future<void> batchIndexRecipes(
    List<Recipe> recipes, {
    required String ownerId,
  }) async {
    if (recipes.isEmpty) return;

    try {
      final objects = recipes
          .map((recipe) => _recipeToSearchDocument(recipe, ownerId))
          .toList();

      await _searchClient.batch(
        indexName: _recipesIndex,
        batchWriteParams: BatchWriteParams(
          requests: objects
              .map((obj) => BatchRequest(
                    action: Action.addObject,
                    body: obj,
                  ))
              .toList(),
        ),
      );
      AppLogger.debug('Batch indexed ${recipes.length} recipes to Algolia');
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
            return data[attributeToSearch] as String? ?? '';
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
      'ingredients': recipe.ingredients,
      'ownerId': ownerId,
      'ownerDisplayName': '', // Should be set by caller with user data
      'isPublic': true,
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
