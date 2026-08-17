/// GDPR Article 20 export operations for the recipe repository — extracted
/// from `firebase_recipe_repository.dart` per BUT-536.
///
/// There is ONE storage shape: `users/{userId}/recipes`. A second method here
/// used to query a top-level `recipes` collection alongside it, described as a
/// legacy shape carrying a `userId` field. No rule grants a CLIENT that read —
/// the only other `recipes` block in `firestore.rules` is the admin-only,
/// READ-ONLY collection-group catch-all, `match /{path=**}/recipes/{recipeId}`
/// — so the query fell to the default deny. And because
/// `ContentExportManager.exportRecipes` wraps both halves in ONE try/catch, the
/// denial threw away the personal recipes it had already collected and returned
/// `recipes-export-failed`. Every Art. 15 bundle lost its whole recipe section
/// (BUT-1801).
///
/// Do not reinstate it HERE. Every recipe this app writes goes to
/// `users/{userId}/recipes`, which the surviving method reads.
///
/// Note the scope of that claim: it is about CLIENTS. The Admin SDK needs no
/// rule, so "no client can read it" was never the same as "nothing can be
/// there" — which is why the account-deletion cascade still sweeps the
/// top-level collection, and why an integration test plants a document there to
/// prove it. Two earlier drafts of this comment got that wrong, first by
/// claiming no rule existed at all and then by inferring write-impossibility
/// from a read denial. Cited by match pattern, not line number, because the
/// first correction cited a line that had already moved.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeGdprExportOperations {
  RecipeGdprExportOperations({
    required this.getCollectionForUser,
    required this.requireCurrentUserId,
    required this.validateOwnership,
  });

  // No `FirebaseFirestore` handle: the only method left reaches its collection
  // through `getCollectionForUser`, which is already user-scoped. A raw handle
  // here is what let the removed top-level query exist at all.
  final CollectionReference<Map<String, dynamic>> Function(String userId)
  getCollectionForUser;
  final String Function() requireCurrentUserId;
  final Future<void> Function({
    required String? currentUserId,
    required String resourceOwnerId,
    required String resourceType,
    String? resourceId,
  })
  validateOwnership;

  /// BUT-501: Export every personal recipe under `users/{userId}/recipes`
  /// for GDPR Article 20. Ownership is structural — caller must verify
  /// the authenticated uid matches [userId] before calling.
  Future<List<Map<String, dynamic>>> exportPersonalRecipesByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: 'recipes',
    );
    final snapshot = await getCollectionForUser(
      userId,
    ).limit(maxDocuments).get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }
}
