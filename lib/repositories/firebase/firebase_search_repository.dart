// lib/repositories/firebase/firebase_search_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/search_repository.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firestore-based fallback search implementation.
///
/// Limited but free - uses basic text matching with prefix queries.
/// Used when Algolia is disabled via feature flag or unavailable.
///
/// Limitations:
/// - No full-text search (only prefix matching)
/// - No relevance scoring
/// - No typo tolerance
/// - Slower for complex queries
class FirestoreSearchRepository implements SearchRepository {
  final FirebaseFirestore _firestore;

  FirestoreSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  bool get usesExternalSearch => false;

  @override
  Future<SearchResult<RecipeSearchHit>> searchRecipes(
    String query, {
    SearchFilters? filters,
    int page = 0,
    int hitsPerPage = 20,
  }) async {
    try {
      // Firestore doesn't support full-text search
      // Use array-contains-any for tags or basic filtering
      var queryRef = _firestore
          .collection(FirestoreCollections.sharedContent)
          .where('contentType', isEqualTo: 'recipe')
          .limit(hitsPerPage);

      // Apply filters
      if (filters?.isPublic == true) {
        queryRef = queryRef.where('isPublic', isEqualTo: true);
      }
      if (filters?.mealType != null) {
        queryRef = queryRef.where('mealType', isEqualTo: filters!.mealType);
      }

      final snapshot = await queryRef.get();
      final lowerQuery = query.toLowerCase();

      // Client-side filtering for text match
      final hits = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final title = (data['recipeTitle'] as String?).orEmpty();
            final description =
                (data['recipeDescription'] as String?).orEmpty();

            // Simple text matching
            if (query.isEmpty ||
                title.toLowerCase().contains(lowerQuery) ||
                description.toLowerCase().contains(lowerQuery)) {
              return RecipeSearchHit(
                id: doc.id,
                title: title,
                description: description,
                imageUrl: data['recipeImageUrl'] as String?,
                timeMinutes: data['recipeTimeMinutes'] as int?,
                portions: data['recipePortions'] as int?,
                rating: (data['rating'] as num?)?.toDouble(),
                mealType: (data['mealType'] as String?) ?? 'Middag',
                tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
                ownerDisplayName:
                    (data['sharedByDisplayName'] as String?).orEmpty(),
                ownerId: (data['sharedByUserId'] as String?).orEmpty(),
              );
            }
            return null;
          })
          .whereType<RecipeSearchHit>()
          .toList();

      return SearchResult(
        hits: hits,
        totalHits: hits.length,
        page: 0,
        totalPages: 1,
        processingTimeMs: 0,
      );
    } catch (e) {
      AppLogger.error('Firestore recipe search failed', e);
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
      // BUT-840: read the canonical `public_profiles` doc — written on every
      // profile save (incl. rename) by FirebaseUserRepository.saveProfile — so
      // search results stay fresh when a user changes their name/avatar. The
      // bare `users/{uid}` root doc this previously queried never carries
      // displayName/avatarUrl, and the discoverability field is `isSearchable`
      // (the user's own toggle), not `isPublic`.
      final snapshot = await _firestore
          .collection(FirestoreCollections.publicProfiles)
          .where('isSearchable', isEqualTo: true)
          .limit(hitsPerPage)
          .get();

      final lowerQuery = query.toLowerCase();

      final hits = snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Exclude moderation-hidden profiles from search results.
            if (data['isHidden'] == true) return null;
            final displayName = (data['displayName'] as String?).orEmpty();

            if (query.isEmpty ||
                displayName.toLowerCase().contains(lowerQuery)) {
              return UserSearchHit(
                id: doc.id,
                displayName: displayName,
                avatarUrl: data['avatarUrl'] as String?,
                recipeCount: data['publicRecipeCount'] as int? ?? 0,
                followerCount: data['friendsCount'] as int? ?? 0,
              );
            }
            return null;
          })
          .whereType<UserSearchHit>()
          .toList();

      return SearchResult(
        hits: hits,
        totalHits: hits.length,
        page: 0,
        totalPages: 1,
        processingTimeMs: 0,
      );
    } catch (e) {
      AppLogger.error('Firestore user search failed', e);
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
    // No-op: Firestore uses live data, no separate index needed
  }

  @override
  Future<void> removeRecipe(String recipeId) async {
    // No-op: Firestore uses live data
  }

  @override
  Future<void> indexUser(UserSearchData user) async {
    // No-op: Firestore uses live data
  }

  @override
  Future<void> removeUser(String userId) async {
    // No-op: Firestore uses live data
  }

  @override
  Future<void> batchIndexRecipes(
    List<Recipe> recipes, {
    required String ownerId,
  }) async {
    // No-op: Firestore uses live data
  }

  @override
  Future<List<String>> getSuggestions(
    String partial, {
    String index = 'recipes',
    int limit = 5,
  }) async {
    // Basic implementation using local data
    return [];
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await _firestore
          .collection(FirestoreCollections.connectivityTest)
          .limit(1)
          .get();
      return true;
    } catch (e) {
      return false;
    }
  }
}
