// lib/repositories/firebase/comments/comment_visibility_queries.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

/// Reads a recipe's comments through queries the `recipe_comments` read rule
/// can prove (BUT-2269).
///
/// The rule lets a reader see a comment they wrote, one on their own recipe,
/// or one whose `sharedWithUserIds` names them. Rules are not filters: a query
/// on `recipeId` alone is refused outright, so each reason gets its own query
/// and the answers are merged.
mixin CommentVisibilityQueries on BaseFirebaseRepository<RecipeComment> {
  static const int visibleCommentLimit = 50;

  List<Query<Map<String, dynamic>>> _visibilityLegs(
    String recipeId, {
    required int limit,
  }) {
    final uid = requireCurrentUserId();
    final byRecipe = collection.where('recipeId', isEqualTo: recipeId);
    return [
      byRecipe.where('recipeOwnerId', isEqualTo: uid),
      byRecipe.where('sharedWithUserIds', arrayContains: uid),
      byRecipe.where('authorId', isEqualTo: uid),
    ].map((leg) => leg.orderBy('createdAt').limit(limit)).toList();
  }

  List<RecipeComment> _merge(
    Iterable<QuerySnapshot<Map<String, dynamic>>> snapshots, {
    required int limit,
  }) {
    // A comment can match two legs (an owner commenting on their own recipe),
    // so the id decides.
    final byId = <String, RecipeComment>{
      for (final snapshot in snapshots)
        for (final doc in snapshot.docs) doc.id: fromFirestore(doc),
    };
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged.take(limit).toList();
  }

  /// Oldest first, at most [limit].
  Future<List<RecipeComment>> fetchVisibleComments(
    String recipeId, {
    int limit = visibleCommentLimit,
  }) async {
    final legs = _visibilityLegs(recipeId, limit: limit);
    final snapshots = await Future.wait(legs.map((leg) => leg.get()));
    return _merge(snapshots, limit: limit);
  }

  Stream<List<RecipeComment>> watchVisibleComments(String recipeId) {
    final legs = _visibilityLegs(recipeId, limit: visibleCommentLimit);
    return Rx.combineLatestList(
      legs.map((leg) => leg.snapshots()),
    ).map((snapshots) => _merge(snapshots, limit: visibleCommentLimit));
  }
}
