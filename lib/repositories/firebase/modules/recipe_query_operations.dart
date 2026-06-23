/// Read-only "find recipes by X" queries extracted from
/// `firebase_recipe_repository.dart` per BUT-536. Three thin wrappers
/// around `where(...).limit(...).get()` that fan out across separate
/// indexed fields (`core.personalTagIds`, `core.sourceUrl`,
/// `core.titleLower`). Each takes the caller's `userId` rather than
/// reading it from auth state — keeps the module pure.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';

class RecipeQueryOperations {
  RecipeQueryOperations({
    required this.getCollectionForUser,
    required this.fromFirestore,
  });

  final CollectionReference<Map<String, dynamic>> Function(String userId)
  getCollectionForUser;
  final Recipe Function(DocumentSnapshot<Map<String, dynamic>> doc)
  fromFirestore;

  /// Most-recent-first list of recipes carrying [tagId] in
  /// `core.personalTagIds`. Returns up to [limit] docs (default 100).
  Future<List<Recipe>> fetchRecipesByTagId(
    String? userId,
    String tagId, {
    int limit = 100,
  }) async {
    if (userId == null) return [];

    try {
      final snap = await getCollectionForUser(userId)
          .where('core.personalTagIds', arrayContains: tagId)
          .orderBy('core.updatedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(fromFirestore).toList();
    } catch (e) {
      AppLogger.warning('Failed to get recipes with tag "$tagId": $e');
      return [];
    }
  }

  /// Up to 5 recipes whose `core.sourceUrl` exactly matches [url].
  /// Used for import-deduplication.
  Future<List<Recipe>> findBySourceUrl(String? userId, String url) async {
    if (url.isEmpty) return [];
    if (userId == null) return [];

    try {
      final snap = await getCollectionForUser(
        userId,
      ).where('core.sourceUrl', isEqualTo: url).limit(5).get();
      return snap.docs.map(fromFirestore).toList();
    } catch (e) {
      AppLogger.warning('Failed to find recipes by source URL: $e');
      return [];
    }
  }

  /// Up to 5 recipes whose `core.titleLower` exactly matches the
  /// normalized (trimmed + lowercased) [title]. Used for title-collision
  /// detection on create.
  Future<List<Recipe>> findByTitle(String? userId, String title) async {
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    if (userId == null) return [];

    try {
      final snap = await getCollectionForUser(
        userId,
      ).where('core.titleLower', isEqualTo: normalized).limit(5).get();
      return snap.docs.map(fromFirestore).toList();
    } catch (e) {
      AppLogger.warning('Failed to find recipes by title: $e');
      return [];
    }
  }
}
