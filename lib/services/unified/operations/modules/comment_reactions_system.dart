// lib/services/unified/operations/modules/comment_reactions_system.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Focused module for comment emoji reactions.
/// Handles toggling emoji reactions on comments using atomic Firestore
/// array operations. Each reaction type stores a list of user IDs
/// under `reactions.<emoji>` in the comment document.
class CommentReactionsSystem {
  static FirestoreRepository get _firestoreRepository =>
      GetIt.instance<FirestoreRepository>();

  /// Toggle an emoji reaction on a comment.
  /// Adds the user if not present, removes if already reacted.
  /// Uses FieldValue.arrayUnion/arrayRemove for atomic updates.
  static Future<bool> toggleCommentReaction({
    required String commentId,
    required String recipeId,
    required String userId,
    required String emoji,
  }) async {
    try {
      AppLogger.info(
          'Toggling reaction "$emoji" on comment $commentId for user $userId');

      final docRef = _firestoreRepository.firestore
          .collection(FirestoreCollections.recipeComments)
          .doc(commentId);

      final doc = await docRef.get();
      if (!doc.exists) {
        AppLogger.error('Comment $commentId not found');
        return false;
      }

      final data = doc.data() ?? {};
      final reactions = data['reactions'] as Map<String, dynamic>? ?? {};
      final emojiReactions = reactions[emoji] as List<dynamic>? ?? [];
      final hasReacted = emojiReactions.contains(userId);

      if (hasReacted) {
        // Remove the user's reaction
        await docRef.update({
          'reactions.$emoji': FieldValue.arrayRemove([userId]),
        });
        AppLogger.success('Reaction "$emoji" removed from comment');
      } else {
        // Add the user's reaction
        await docRef.update({
          'reactions.$emoji': FieldValue.arrayUnion([userId]),
        });
        AppLogger.success('Reaction "$emoji" added to comment');
      }

      return true;
    } catch (e) {
      AppLogger.error('Failed to toggle comment reaction', e);
      return false;
    }
  }

  /// Get all reactions for a comment.
  /// Returns a map of emoji key to list of user IDs.
  static Future<Map<String, List<String>>> getCommentReactions({
    required String commentId,
  }) async {
    try {
      final docRef = _firestoreRepository.firestore
          .collection(FirestoreCollections.recipeComments)
          .doc(commentId);

      final doc = await docRef.get();
      if (!doc.exists) return {};

      final data = doc.data() ?? {};
      final raw = data['reactions'];
      if (raw == null || raw is! Map) return {};

      final result = <String, List<String>>{};
      for (final entry in (raw as Map<String, dynamic>).entries) {
        if (entry.value is List) {
          result[entry.key] = List<String>.from(entry.value as List);
        }
      }
      return result;
    } catch (e) {
      AppLogger.error('Failed to get comment reactions', e);
      return {};
    }
  }
}
