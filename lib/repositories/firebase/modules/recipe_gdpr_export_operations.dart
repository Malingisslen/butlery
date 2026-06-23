/// GDPR Article 20 export operations for the recipe repository — extracted
/// from `firebase_recipe_repository.dart` per BUT-536. Both methods cover
/// one of the two storage shapes recipes have lived in: the per-user
/// subcollection (`users/{userId}/recipes`) and the legacy top-level
/// `recipes` collection with a `userId` field. Together they fully cover
/// the personal-recipes export surface (BUT-501).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';

class RecipeGdprExportOperations {
  RecipeGdprExportOperations({
    required this.firestore,
    required this.getCollectionForUser,
    required this.requireCurrentUserId,
    required this.validateOwnership,
  });

  final FirebaseFirestore firestore;
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

  /// BUT-501: Export every top-level `recipes` doc owned by [userId]
  /// (legacy `userId` field). Used alongside [exportPersonalRecipesByUser]
  /// to fully cover both storage shapes.
  Future<List<Map<String, dynamic>>> exportTopLevelRecipesByOwner(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: 'recipes',
    );
    final snapshot = await firestore
        .collection(FirestoreCollections.recipes)
        .where('userId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();
    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }
}
