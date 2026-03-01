import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase repository for personal tag groups (folders for organizing tags).
///
/// Stores groups in user subcollection: users/{userId}/personalTagGroups/{groupId}
/// Each user can only access their own groups (owner-only permissions).
class FirebasePersonalTagGroupRepository
    extends BaseFirebaseRepository<PersonalTagGroup>
    with UserScopedFirebaseRepository<PersonalTagGroup> {
  FirebasePersonalTagGroupRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => FirestoreCollections.userPersonalTagGroups;

  @override
  PersonalTagGroup fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PersonalTagGroup.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(PersonalTagGroup entity) {
    return entity.toFirestore();
  }

  @override
  String getId(PersonalTagGroup entity) => entity.id;

  // Owner-only permissions - user can only access their own subcollection
  @override
  Future<bool> validateCreatePermission(
          String userId, PersonalTagGroup entity) async =>
      true;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    PersonalTagGroup? entity,
  ) async =>
      true;

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    PersonalTagGroup entity,
  ) async =>
      true;

  @override
  Future<bool> validateDeletePermission(
          String userId, String resourceId) async =>
      true;

  /// Gets all groups sorted by sortOrder.
  ///
  /// Uses single-field ordering to avoid requiring composite Firestore indexes.
  /// If sortOrder is equal, Firestore returns documents in document ID order.
  Future<List<PersonalTagGroup>> getAllSorted() async {
    final snapshot = await getCollectionRef().orderBy('sortOrder').get();

    return snapshot.docs.map(fromFirestore).toList();
  }

  /// Watches all groups with real-time updates, sorted by sortOrder.
  ///
  /// Uses single-field ordering to avoid requiring composite Firestore indexes
  /// for user-scoped subcollections.
  Stream<List<PersonalTagGroup>> watchAllSorted() {
    return getCollectionRef()
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
  }

  /// Finds a group by name (case-insensitive).
  Future<PersonalTagGroup?> findByName(String name) async {
    final normalizedName = name.trim().toLowerCase();
    final all = await readAll();

    return all.cast<PersonalTagGroup?>().firstWhere(
          (group) => group!.name.toLowerCase() == normalizedName,
          orElse: () => null,
        );
  }

  /// Checks if a group name already exists (case-insensitive).
  Future<bool> nameExists(String name, {String? excludeId}) async {
    final existing = await findByName(name);
    if (existing == null) return false;
    if (excludeId != null && existing.id == excludeId) return false;
    return true;
  }

  /// Gets the next available sort order value.
  Future<int> getNextSortOrder() async {
    final all = await readAll();
    if (all.isEmpty) return 0;

    final maxOrder =
        all.map((group) => group.sortOrder).reduce((a, b) => a > b ? a : b);
    return maxOrder + 1;
  }

  /// Reorders groups by updating their sortOrder values.
  Future<void> reorder(List<String> groupIds) async {
    requireCurrentUserId();
    final batch = firestore.batch();
    final ref = getCollectionRef();

    for (var i = 0; i < groupIds.length; i++) {
      batch.update(ref.doc(groupIds[i]), {
        'sortOrder': i,
        'updatedAt': Timestamp.now(),
      });
    }

    await batch.commit();
  }

  /// Deletes a group and optionally updates tags that reference it.
  ///
  /// This method ONLY deletes the group document. To unset groupId on
  /// associated tags, use FirebasePersonalTagRepository.clearGroupFromTags()
  /// before or after calling this method.
  ///
  /// The cascade operation is handled at the service layer to maintain
  /// proper separation of concerns.
  @override
  Future<void> delete(String id) async {
    await super.delete(id);
  }

  /// #7: Adds delete operation to an external batch without committing.
  ///
  /// Use this for atomic group deletion with cascade.
  void addDeleteToBatch(WriteBatch batch, String groupId) {
    requireCurrentUserId();
    final ref = getCollectionRef();
    batch.delete(ref.doc(groupId));
  }
}
