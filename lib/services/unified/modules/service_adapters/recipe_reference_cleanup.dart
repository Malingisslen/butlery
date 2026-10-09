// lib/services/unified/modules/service_adapters/recipe_reference_cleanup.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

/// What other people's content a deleted recipe leaves behind, removed when
/// its owner deletes it (F6: none of it goes to the owner's trash).
abstract final class RecipeReferenceCleanup {
  /// Remove orphan comments, ratings, and social_stats for a deleted recipe
  static Future<void> run(FirebaseFirestore firestore, String recipeId) async {
    try {
      // Delete comments (paginated to respect batch limits)
      final commentQuery = firestore
          .collection(FirestoreCollections.recipeComments)
          .where('recipeId', isEqualTo: recipeId)
          .limit(450);
      var snapshot = await commentQuery.get();
      while (snapshot.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < 450) break;
        snapshot = await commentQuery.get();
      }

      // Delete ratings (paginated)
      final ratingQuery = firestore
          .collection(FirestoreCollections.recipeRatings)
          .where('recipeId', isEqualTo: recipeId)
          .limit(450);
      snapshot = await ratingQuery.get();
      while (snapshot.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < 450) break;
        snapshot = await ratingQuery.get();
      }

      // Delete social stats aggregate doc
      await firestore
          .collection(FirestoreCollections.recipeSocialStats)
          .doc(recipeId)
          .delete();

      // BUT-892: Delete cook_snaps records pointing at this recipe
      // (paginated). Cook snaps by ANY user (including non-owners with
      // share access) lose their parent recipe when the owner deletes it;
      // without this cleanup the snap doc persists with a dangling
      // recipeId reference.
      final cookSnapQuery = firestore
          .collection(FirestoreCollections.cookSnaps)
          .where('recipeId', isEqualTo: recipeId)
          .limit(450);
      snapshot = await cookSnapQuery.get();
      while (snapshot.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < 450) break;
        snapshot = await cookSnapQuery.get();
      }

      // BUT-894: Delete shared_content recipe records pointing at this
      // recipe (paginated). Otherwise recipients keep a dead reference
      // in their inbox after the owner deletes the source recipe.
      // Each shared_content doc may have a `members` subcollection
      // (FirestoreCollections.members) — drain it before deleting the
      // parent so we don't leave orphaned member docs that would still
      // surface via collectionGroup queries.
      final sharedQuery = firestore
          .collection(FirestoreCollections.sharedContent)
          .where('originalRecipeId', isEqualTo: recipeId)
          .limit(450);
      snapshot = await sharedQuery.get();
      while (snapshot.docs.isNotEmpty) {
        for (final doc in snapshot.docs) {
          // Drain members subcollection (soft-cascade — best effort).
          final memberDocs = await doc.reference
              .collection(FirestoreCollections.members)
              .limit(450)
              .get();
          if (memberDocs.docs.isNotEmpty) {
            final memberBatch = firestore.batch();
            for (final m in memberDocs.docs) {
              memberBatch.delete(m.reference);
            }
            await memberBatch.commit();
          }
        }
        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < 450) break;
        snapshot = await sharedQuery.get();
      }
    } catch (e) {
      // Log but don't fail the recipe deletion for cleanup errors
      AppLogger.warning('⚠️ Partial cleanup failure for recipe $recipeId: $e');
    }
  }
}
