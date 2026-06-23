/// Tag-cascade operations for the recipe repository — extracted from
/// `firebase_recipe_repository.dart` per BUT-536. Handles the denormalized-tag
/// write paths on user recipes: rename across recipes, remove from all
/// recipes, self-chunking replace/merge (BUT-1186), and a batch-additive
/// remove variant for callers that orchestrate cross-document tag deletion in
/// their own batches.
///
/// All paths read-modify-write the `core.personalTags` rich-object array;
/// `core.personalTagIds` (UUID array) is mutated on remove and replace.
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
      final snap = await getCollectionForUser(
        userId,
      ).where('core.personalTagIds', arrayContains: tagId).get();

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
  /// Removes from both personalTagIds (UUID array) and personalTags (rich
  /// objects). Self-chunking in batches of [kFirestoreBatchSafeChunkSize]
  /// (one op per doc) so a tag on >500 recipes never overflows the Firestore
  /// 500-op-per-batch limit. Returns the number of recipes updated.
  ///
  /// **Errors PROPAGATE (rethrow, not swallow).** Sole caller is
  /// `PersonalTagCrudService.deleteTag`, which removes the tag from recipes
  /// FIRST and only then deletes the tag document. If a cascade chunk fails it
  /// MUST unwind so the tag-doc delete never runs — otherwise the tag
  /// disappears while recipes still reference it (silent orphan). The
  /// legitimate "zero recipes matched" case is the early `return 0` BEFORE any
  /// write and is distinct from a thrown error.
  Future<int> removePersonalTagFromRecipes(
    String? userId,
    String tagId,
  ) async {
    if (tagId.isEmpty) return 0;
    if (userId == null) return 0;

    try {
      final snap = await getCollectionForUser(
        userId,
      ).where('core.personalTagIds', arrayContains: tagId).get();

      if (snap.docs.isEmpty) return 0;

      int updated = 0;

      for (var i = 0; i < snap.docs.length; i += kFirestoreBatchSafeChunkSize) {
        final batch = firestore.batch();
        final chunk = snap.docs.skip(i).take(kFirestoreBatchSafeChunkSize);

        for (final doc in chunk) {
          batch.update(
            doc.reference,
            _buildTagRemovalUpdate(doc.data(), tagId),
          );
        }

        await batch.commit();
        updated += chunk.length;
      }

      return updated;
    } catch (e) {
      AppLogger.warning(
        'Failed to remove tag "$tagId" from recipes '
        '(propagating so caller skips the tag-doc delete): $e',
      );
      rethrow;
    }
  }

  /// Adds remove-personal-tag operations to an external batch without committing.
  /// Queries for affected recipes, then adds update operations to [batch].
  /// Returns the number of recipe updates added.
  /// Caller is responsible for committing the batch and respecting the 500-op limit.
  ///
  /// **Intentionally no try/catch** — this one is batch-additive: the caller
  /// owns the batch lifecycle, and an exception here means the caller's batch
  /// is in a half-built state and MUST not be committed. Letting the exception
  /// propagate forces the caller to handle the error explicitly. (The
  /// self-chunking [removePersonalTagFromRecipes] / [replaceTagInRecipes] also
  /// propagate — they log then rethrow — so their cascade-then-delete callers
  /// skip the tag delete on failure rather than orphaning recipe references.)
  Future<int> addRemovePersonalTagFromRecipesToBatch(
    String? userId,
    WriteBatch batch,
    String tagId,
  ) async {
    if (tagId.isEmpty) return 0;
    if (userId == null) return 0;

    final snap = await getCollectionForUser(
      userId,
    ).where('core.personalTagIds', arrayContains: tagId).get();

    if (snap.docs.isEmpty) return 0;

    for (final doc in snap.docs) {
      batch.update(doc.reference, _buildTagRemovalUpdate(doc.data(), tagId));
    }

    return snap.docs.length;
  }

  /// Replaces (merges) a personal tag across all user recipes that carry it:
  /// [fromTagId] is swapped for [toTagId] in both denormalized arrays.
  /// Self-chunking — queries recipes carrying [fromTagId], then commits the
  /// rewrites in chunks of [kFirestoreBatchSafeChunkSize] (one op per doc),
  /// so a user with >500 recipes on one tag never overflows the Firestore
  /// 500-op-per-batch limit. Returns the number of recipes updated.
  ///
  /// [toTagRichEntry] is the `{tagId, name, sources}` map appended to a
  /// recipe's rich `core.personalTags` array when that recipe didn't already
  /// carry [toTagId] — the caller resolves it from the destination tag.
  ///
  /// **Why SET, not FieldValue transforms** — Firestore rejects two
  /// FieldValue transforms (arrayRemove + arrayUnion) on the same field in
  /// one update, so both arrays are computed from [doc.data] and written as
  /// plain lists (mirroring [_buildTagRemovalUpdate]).
  ///
  /// **Idempotency / partial retry**: same posture as
  /// [renamePersonalTagInRecipes]. The per-doc rewrite is an idempotent SET —
  /// re-running on an already-retagged recipe (fromTagId absent, toTagId
  /// present) produces an identical document. A network drop mid-cascade
  /// leaves some recipes retagged and some not; re-running completes the
  /// rest. This is why the merge caller MUST retag-all-first, THEN delete the
  /// source tag (see PersonalTagCrudService.mergeTags): a failed delete is
  /// then a safe re-run of an idempotent retag + retry-delete.
  ///
  /// **Errors PROPAGATE (rethrow, not swallow).** A query/commit failure here
  /// MUST unwind to the merge caller so its Step-2 source-tag delete never
  /// runs — otherwise a half-done cascade (e.g. chunk 1 committed, chunk 2
  /// threw) followed by an unconditional delete would orphan recipe references
  /// to a deleted tag, with no way to self-heal (the source tag is gone). The
  /// legitimate "zero recipes matched" case is the early `return 0` BEFORE any
  /// write — that is NOT a failure and is distinct from a thrown error. The
  /// warning is logged for diagnostics, then re-thrown.
  Future<int> replaceTagInRecipes(
    String? userId,
    String fromTagId,
    String toTagId,
    Map<String, dynamic> toTagRichEntry,
  ) async {
    if (fromTagId.isEmpty || toTagId.isEmpty) return 0;
    if (userId == null) return 0;
    if (fromTagId == toTagId) return 0;

    try {
      final snap = await getCollectionForUser(
        userId,
      ).where('core.personalTagIds', arrayContains: fromTagId).get();

      if (snap.docs.isEmpty) return 0;

      int updated = 0;

      for (var i = 0; i < snap.docs.length; i += kFirestoreBatchSafeChunkSize) {
        final batch = firestore.batch();
        final chunk = snap.docs.skip(i).take(kFirestoreBatchSafeChunkSize);

        for (final doc in chunk) {
          batch.update(
            doc.reference,
            _buildTagReplaceUpdate(
              doc.data(),
              fromTagId,
              toTagId,
              toTagRichEntry,
            ),
          );
        }

        await batch.commit();
        updated += chunk.length;
      }

      return updated;
    } catch (e) {
      AppLogger.warning(
        'Failed to replace tag "$fromTagId" with "$toTagId" in recipes '
        '(propagating so caller skips the source-tag delete): $e',
      );
      rethrow;
    }
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

  /// Tag-replace (merge) update map used by [replaceTagInRecipes].
  /// Computes both arrays from [data] and SETs them (no FieldValue
  /// transforms — see method doc): pull [fromTagId] from the UUID array and
  /// append [toTagId] if absent; drop the rich entry for [fromTagId] and
  /// append [toTagRichEntry] only when no [toTagId] entry already survives.
  Map<String, dynamic> _buildTagReplaceUpdate(
    Map<String, dynamic> data,
    String fromTagId,
    String toTagId,
    Map<String, dynamic> toTagRichEntry,
  ) {
    final coreData = data['core'] as Map<String, dynamic>? ?? {};

    final ids =
        (coreData['personalTagIds'] as List?)
            ?.where((id) => id != fromTagId)
            .toList() ??
        <dynamic>[];
    if (!ids.contains(toTagId)) {
      ids.add(toTagId);
    }

    final updates = <String, dynamic>{
      'core.personalTagIds': ids,
    };

    final personalTags = coreData['personalTags'] as List?;
    if (personalTags != null) {
      final richTags = personalTags
          .where((entry) => entry is Map && entry['tagId'] != fromTagId)
          .toList();
      final hasTo = richTags.any(
        (entry) => entry is Map && entry['tagId'] == toTagId,
      );
      if (!hasTo) {
        richTags.add(toTagRichEntry);
      }
      updates['core.personalTags'] = richTags;
    }

    return updates;
  }
}
