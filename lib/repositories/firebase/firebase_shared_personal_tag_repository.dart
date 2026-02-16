import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/shared_personal_tag.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

/// Repository for shared personal tags stored in top-level collection.
///
/// Collection path: `shared_personal_tags/{tagId}`
/// Any authenticated user can read a shared tag by ID (link-based sharing).
/// Only the creator can write/delete their shared tags.
class FirebaseSharedPersonalTagRepository
    extends BaseFirebaseRepository<SharedPersonalTag> {
  FirebaseSharedPersonalTagRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => 'shared_personal_tags';

  @override
  SharedPersonalTag fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SharedPersonalTag.fromMap(doc.id, doc.data()!);
  }

  @override
  Map<String, dynamic> toFirestore(SharedPersonalTag entity) {
    return entity.toMap();
  }

  @override
  String getId(SharedPersonalTag entity) => entity.id;

  // Any authenticated user can create a shared tag
  @override
  Future<bool> validateCreatePermission(
    String userId,
    SharedPersonalTag entity,
  ) async =>
      entity.sharedByUserId == userId;

  // Any authenticated user can read shared tags (link-based access)
  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    SharedPersonalTag? entity,
  ) async =>
      true;

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    SharedPersonalTag entity,
  ) async =>
      entity.sharedByUserId == userId;

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    final doc = await getCollectionRef().doc(resourceId).get();
    if (!doc.exists) return false;
    final tag = fromFirestore(doc);
    return tag.sharedByUserId == userId;
  }

  /// Gets all shared tags where the user is a recipient.
  Future<List<SharedPersonalTag>> getPendingForUser(String userId) async {
    try {
      final snapshot = await getCollectionRef()
          .where('recipientUserIds', arrayContains: userId)
          .orderBy('sharedAt', descending: true)
          .get();

      return snapshot.docs.map(fromFirestore).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to get pending shared tags for user $userId: $e', stackTrace);
      return [];
    }
  }

  /// Gets all shared tags created by a specific user.
  Future<List<SharedPersonalTag>> getSharedTagsByUser(String userId) async {
    try {
      final snapshot = await getCollectionRef()
          .where('sharedByUserId', isEqualTo: userId)
          .orderBy('sharedAt', descending: true)
          .get();

      return snapshot.docs.map(fromFirestore).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to get shared tags for user $userId: $e', stackTrace);
      return [];
    }
  }
}
