/// Tag-cascade operations for the recipe repository — extracted from
/// `firebase_recipe_repository.dart` per BUT-536. Handles the three
/// denormalized-tag write paths: rename across user recipes, remove from
/// all user recipes, and a batch-additive variant for callers that
/// orchestrate cross-document tag deletion in their own batches.
///
/// All three paths read-modify-write the `core.personalTags` rich-object
/// array; `core.personalTagIds` (UUID array) is only mutated on remove.
/// No CRUD `read`/`update` calls are needed — operations work directly on
/// the user-scoped collection reference, so this class only depends on
/// the repository's `firestore` handle and a `getCollectionForUser`
/// callback.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/extensions/iterable_extensions.dart';
import 'package:butlery/core/utils/logger.dart';

class RecipeTagOperations {
  RecipeTagOperations({
    required this.firestore,
    required this.getCollectionForUser,
  });

  final FirebaseFirestore firestore;
  final CollectionReference<Map<String, dynamic>> Function(String userId)
      getCollectionForUser;

  /// Renames a personal tag across all user recipes that contain it.
  ///
  /// Read-modify-write of the denormalized `personalTags` array (array of maps);
  /// `personalTagIds` (UUIDs) is unchanged since IDs don't change on rename.
  /// Returns the number of recipes updated.
  ///
  /// **Idempotency**: re-running with the same `(tagId, newName)` is a no-op
  /// for already-renamed entries — the inner map rebuild only mutates the
  /// `entry['tagId'] == tagId` slot, and an entry already at `newName`
  /// produces an identical document. Safe to retry on partial failure
  /// (network drop mid-batch leaves the user with some recipes renamed and
  /// some not; next rename attempt completes the rest, or the cascade
  /// re-fires from the next `updateTag` call). Stale recipe names are
  /// otherwise recoverable via re-tag.
  ///
  /// **Scale**: client-side fetch-all + chunked batch writes. Fine for current
  /// scale (typical user has <500 recipes per tag). Bottleneck at ~10K recipes
  /// per tag — at that point migrate to a Cloud Function trigger (BUT-480
  /// deferred CF path).
  Future<int> renamePersonalTagInRecipes(
    String? userId,
    String tagId,
    String newName,
  ) async {
    if (tagId.isEmpty || newName.isEmpty) return 0;
    if (userId == null) return 0;

    try {
      final snap = await getCollectionForUser(userId)
          .where('core.personalTagIds', arrayContains: tagId)
          .get();

      if (snap.docs.isEmpty) return 0;

      int updated = 0;

      for (var i = 0; i < snap.docs.length; i += kFirestoreBatchSafeChunkSize) {
        final batch = firestore.batch();
        final chunk = snap.docs.skip(i).take(kFirestoreBatchSafeChunkSize);

        for (final doc in chunk) {
          final data = doc.data();
          final coreData = data['core'] as Map<String, dynamic>? ?? {};
          final personalTags = coreData['personalTags'] as List?;

          if (personalTags != null) {
            final updatedTags = personalTags.map((entry) {
              if (entry is Map && entry['tagId'] == tagId) {
                return {...entry, 'name': newName};
              }
              return entry;
            }).toList();

            batch.update(doc.reference, {
              'core.personalTags': updatedTags,
            });
          }
        }

        await batch.commit();
        updated += chunk.length;
      }

      return updated;
    } catch (e) {
      AppLogger.warning('Failed to rename tag "$tagId" to "$newName": $e');
      return 0;
    }
  }

  /// Removes a personal tag from all user recipes that contain it.
  ///
  /// Removes from both personalTagIds (UUID array) and personalTags (rich objects).
  /// Returns the number of recipes updated.
  Future<int> removePersonalTagFromRecipes(
    String? userId,
    String tagId,
  ) async {
    if (tagId.isEmpty) return 0;
    if (userId == null) return 0;

    try {
      final snap = await getCollectionForUser(userId)
          .where('core.personalTagIds', arrayContains: tagId)
          .get();

      if (snap.docs.isEmpty) return 0;

      const batchLimit = 500; // 1 op per doc (consolidated update)
      int updated = 0;

      for (var i = 0; i < snap.docs.length; i += batchLimit) {
        final batch = firestore.batch();
        final chunk = snap.docs.skip(i).take(batchLimit);

        for (final doc in chunk) {
          batch.update(
              doc.reference, _buildTagRemovalUpdate(doc.data(), tagId));
        }

        await batch.commit();
        updated += chunk.length;
      }

      return updated;
    } catch (e) {
      AppLogger.warning('Failed to remove tag "$tagId" from recipes: $e');
      return 0;
    }
  }

  /// Adds remove-personal-tag operations to an external batch without committing.
  /// Queries for affected recipes, then adds update operations to [batch].
  /// Returns the number of recipe updates added.
  /// Caller is responsible for committing the batch and respecting the 500-op limit.
  ///
  /// **Intentionally no try/catch** — the other two tag methods swallow
  /// errors and return 0 because they're self-contained operations. This
  /// one is batch-additive: the caller owns the batch lifecycle, and an
  /// exception here means the caller's batch is in a half-built state and
  /// MUST not be committed. Letting the exception propagate forces the
  /// caller to handle the error explicitly.
  Future<int> addRemovePersonalTagFromRecipesToBatch(
    String? userId,
    WriteBatch batch,
    String tagId,
  ) async {
    if (tagId.isEmpty) return 0;
    if (userId == null) return 0;

    final snap = await getCollectionForUser(userId)
        .where('core.personalTagIds', arrayContains: tagId)
        .get();

    if (snap.docs.isEmpty) return 0;

    for (final doc in snap.docs) {
      batch.update(doc.reference, _buildTagRemovalUpdate(doc.data(), tagId));
    }

    return snap.docs.length;
  }

  /// Tag-removal update map shared by [removePersonalTagFromRecipes] and
  /// [addRemovePersonalTagFromRecipesToBatch]. Single point of truth for
  /// the two-field mutation: pull [tagId] from the UUID array, and rebuild
  /// the rich `personalTags` array with that entry filtered out.
  Map<String, dynamic> _buildTagRemovalUpdate(
    Map<String, dynamic> data,
    String tagId,
  ) {
    final coreData = data['core'] as Map<String, dynamic>? ?? {};
    final personalTags = coreData['personalTags'] as List?;

    final updates = <String, dynamic>{
      'core.personalTagIds': FieldValue.arrayRemove([tagId]),
    };

    if (personalTags != null) {
      updates['core.personalTags'] = personalTags
          .where((entry) => entry is Map && entry['tagId'] != tagId)
          .toList();
    }

    return updates;
  }
}
