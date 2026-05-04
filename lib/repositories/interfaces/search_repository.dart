// lib/repositories/interfaces/search_repository.dart

import 'package:clock/clock.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Provider-agnostic search repository interface.
///
/// This abstraction allows swapping search providers without changing consumers:
/// - Algolia (current) - managed, fast, but expensive at scale
/// - Meilisearch (future) - self-hosted, open source
/// - Typesense (future) - self-hosted, Algolia-like API
/// - Elasticsearch (future) - self-hosted, battle-tested
///
/// Usage:
/// ```dart
/// final searchRepo = ServiceLocator.get<SearchRepository>();
/// final results = await searchRepo.searchRecipes('pasta carbonara');
/// ```
abstract class SearchRepository {
  /// Whether this repo provides server-side search (e.g. Algolia, Meilisearch)
  /// that scans the full corpus. False for the Firestore fallback, which
  /// applies a client-side filter on a 200-row prefix.
  ///
  /// [RecipeSearchRouter] uses this to decide whether to bypass the legacy
  /// `RecipeRepository.searchRecipes` 200-cap path.
  bool get usesExternalSearch => false;

  /// Search recipes with optional filters.
  /// Returns paginated results with metadata.
  Future<SearchResult<RecipeSearchHit>> searchRecipes(
    String query, {
    SearchFilters? filters,
    int page = 0,
    int hitsPerPage = 20,
  });

  /// Search users by display name or username.
  Future<SearchResult<UserSearchHit>> searchUsers(
    String query, {
    int page = 0,
    int hitsPerPage = 20,
  });

  /// Index a recipe for search.
  /// Called when recipe is created or updated.
  Future<void> indexRecipe(Recipe recipe, {required String ownerId});

  /// Remove a recipe from search index.
  /// Called when recipe is deleted or made private.
  Future<void> removeRecipe(String recipeId);

  /// Index a user for search.
  Future<void> indexUser(UserSearchData user);

  /// Remove a user from search index.
  Future<void> removeUser(String userId);

  /// Batch index multiple recipes (more efficient for bulk operations).
  Future<void> batchIndexRecipes(
    List<Recipe> recipes, {
    required String ownerId,
  });

  /// Get search suggestions as user types.
  Future<List<String>> getSuggestions(
    String partial, {
    String index = 'recipes',
    int limit = 5,
  });

  /// Check if the search service is available.
  Future<bool> healthCheck();
}

/// Generic search result with pagination metadata.
class SearchResult<T> {
  final List<T> hits;
  final int totalHits;
  final int page;
  final int totalPages;
  final int processingTimeMs;
  final String? queryId; // For analytics

  const SearchResult({
    required this.hits,
    required this.totalHits,
    required this.page,
    required this.totalPages,
    required this.processingTimeMs,
    this.queryId,
  });

  bool get hasMore => page < totalPages - 1;
  bool get isEmpty => hits.isEmpty;

  SearchResult<R> map<R>(R Function(T) transform) {
    return SearchResult<R>(
      hits: hits.map(transform).toList(),
      totalHits: totalHits,
      page: page,
      totalPages: totalPages,
      processingTimeMs: processingTimeMs,
      queryId: queryId,
    );
  }
}

/// Recipe search hit with highlighted matches.
class RecipeSearchHit {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int? timeMinutes;
  final int? portions;
  final double? rating;
  final String mealType;
  final List<String> tags;
  final String ownerDisplayName;
  final String ownerId;

  /// Highlighted title with <em> tags around matches
  final String? highlightedTitle;

  /// Highlighted description with <em> tags around matches
  final String? highlightedDescription;

  const RecipeSearchHit({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.timeMinutes,
    this.portions,
    this.rating,
    required this.mealType,
    this.tags = const [],
    required this.ownerDisplayName,
    required this.ownerId,
    this.highlightedTitle,
    this.highlightedDescription,
  });

  /// Convert to minimal Recipe for display.
  Recipe toRecipe() {
    return Recipe(
      core: RecipeCore(
        id: id,
        title: title,
        description: description ?? '',
        ingredients: const [],
        instructions: const [],
        imageUrls: imageUrl != null ? [imageUrl!] : const [],
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: tags,
        createdAt: clock.now(),
        updatedAt: clock.now(),
      ),
      type: RecipeType.shared,
    );
  }
}

/// User search hit.
class UserSearchHit {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final int recipeCount;
  final int followerCount;

  const UserSearchHit({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.recipeCount = 0,
    this.followerCount = 0,
  });
}

/// User data for indexing.
class UserSearchData {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final int recipeCount;
  final int followerCount;
  final bool isPublic;

  const UserSearchData({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.recipeCount = 0,
    this.followerCount = 0,
    this.isPublic = true,
  });

  Map<String, dynamic> toSearchDocument() {
    return {
      'objectID': id,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'recipeCount': recipeCount,
      'followerCount': followerCount,
      'isPublic': isPublic,
    };
  }
}

/// Search filters for recipes.
class SearchFilters {
  final String? mealType;
  final List<String>? tags;
  final int? maxTimeMinutes;
  final double? minRating;
  final int? minPortions;
  final int? maxPortions;
  final String? ownerId;
  final bool? isPublic;

  const SearchFilters({
    this.mealType,
    this.tags,
    this.maxTimeMinutes,
    this.minRating,
    this.minPortions,
    this.maxPortions,
    this.ownerId,
    this.isPublic,
  });

  /// Convert to Algolia filter string.
  /// Format: "mealType:Middag AND timeMinutes <= 30 AND rating >= 4"
  String toAlgoliaFilter() {
    final filters = <String>[];

    if (mealType != null) {
      filters.add('mealType:"$mealType"');
    }
    if (tags != null && tags!.isNotEmpty) {
      for (final tag in tags!) {
        filters.add('tags:"$tag"');
      }
    }
    if (maxTimeMinutes != null) {
      filters.add('timeMinutes <= $maxTimeMinutes');
    }
    if (minRating != null) {
      filters.add('rating >= $minRating');
    }
    if (minPortions != null) {
      filters.add('portions >= $minPortions');
    }
    if (maxPortions != null) {
      filters.add('portions <= $maxPortions');
    }
    if (ownerId != null) {
      filters.add('ownerId:"$ownerId"');
    }
    if (isPublic != null) {
      filters.add('isPublic:${isPublic! ? 'true' : 'false'}');
    }

    return filters.join(' AND ');
  }

  /// Convert to Meilisearch filter format (for future migration).
  String toMeilisearchFilter() {
    final filters = <String>[];

    if (mealType != null) {
      filters.add('mealType = "$mealType"');
    }
    if (tags != null && tags!.isNotEmpty) {
      for (final tag in tags!) {
        filters.add('tags = "$tag"');
      }
    }
    if (maxTimeMinutes != null) {
      filters.add('timeMinutes <= $maxTimeMinutes');
    }
    if (minRating != null) {
      filters.add('rating >= $minRating');
    }
    if (minPortions != null) {
      filters.add('portions >= $minPortions');
    }
    if (maxPortions != null) {
      filters.add('portions <= $maxPortions');
    }
    if (ownerId != null) {
      filters.add('ownerId = "$ownerId"');
    }
    if (isPublic != null) {
      filters.add('isPublic = ${isPublic!}');
    }

    return filters.join(' AND ');
  }

  /// Convert to Typesense filter format (for future migration).
  String toTypesenseFilter() {
    final filters = <String>[];

    if (mealType != null) {
      filters.add('mealType:=$mealType');
    }
    if (tags != null && tags!.isNotEmpty) {
      filters.add('tags:[${tags!.join(",")}]');
    }
    if (maxTimeMinutes != null) {
      filters.add('timeMinutes:<=$maxTimeMinutes');
    }
    if (minRating != null) {
      filters.add('rating:>=$minRating');
    }
    if (minPortions != null) {
      filters.add('portions:>=$minPortions');
    }
    if (maxPortions != null) {
      filters.add('portions:<=$maxPortions');
    }
    if (ownerId != null) {
      filters.add('ownerId:=$ownerId');
    }
    if (isPublic != null) {
      filters.add('isPublic:=${isPublic!}');
    }

    return filters.join(' && ');
  }
}

/// Search provider type for feature flag routing.
enum SearchProvider {
  algolia,
  meilisearch,
  typesense,
  firestore, // Fallback: native Firestore text search (limited)
}
