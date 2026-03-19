import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase repository for user-defined personal tags.
///
/// Stores tags in user subcollection: users/{userId}/personalTagIds/{tagId}
/// Each user can only access their own tags (owner-only permissions).
class FirebasePersonalTagRepository extends BaseFirebaseRepository<PersonalTag>
    with UserScopedFirebaseRepository<PersonalTag> {
  FirebasePersonalTagRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => FirestoreCollections.userPersonalTags;

  @override
  PersonalTag fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PersonalTag.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(PersonalTag entity) {
    return entity.toFirestore();
  }

  @override
  String getId(PersonalTag entity) => entity.id;

  // Owner-only permissions - user can only access their own subcollection
  @override
  Future<bool> validateCreatePermission(
          String userId, PersonalTag entity) async =>
      true;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    PersonalTag? entity,
  ) async =>
      true;

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    PersonalTag entity,
  ) async =>
      true;

  @override
  Future<bool> validateDeletePermission(
          String userId, String resourceId) async =>
      true;

  // Ownership is structural (user subcollection) — skip per-document
  // validation and audit logging that the base readAll() does.
  @override
  Future<List<PersonalTag>> readAll() async {
    requireCurrentUserId();
    try {
      final snapshot = await getCollectionRef().get();
      return snapshot.docs.map(fromFirestore).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to read all PersonalTag: $e', stackTrace);
      rethrow;
    }
  }

  /// Gets all tags sorted by sortOrder.
  ///
  /// Uses single-field ordering to avoid requiring composite Firestore indexes.
  /// If sortOrder is equal, Firestore returns documents in document ID order.
  Future<List<PersonalTag>> getAllSorted() async {
    final snapshot = await getCollectionRef().orderBy('sortOrder').get();

    return snapshot.docs.map(fromFirestore).toList();
  }

  /// Watches all tags with real-time updates, sorted by sortOrder.
  ///
  /// Uses single-field ordering to avoid requiring composite Firestore indexes
  /// for user-scoped subcollections.
  Stream<List<PersonalTag>> watchAllSorted() {
    return getCollectionRef()
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
  }

  /// Finds a tag by name (case-insensitive).
  Future<PersonalTag?> findByName(String name) async {
    final normalizedName = name.trim().toLowerCase();
    final all = await readAll();

    return all.cast<PersonalTag?>().firstWhere(
          (tag) => tag!.name.toLowerCase() == normalizedName,
          orElse: () => null,
        );
  }

  /// Checks if a tag name already exists (case-insensitive).
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
        all.map((tag) => tag.sortOrder).reduce((a, b) => a > b ? a : b);
    return maxOrder + 1;
  }

  /// Gets multiple tags by their IDs efficiently.
  ///
  /// Returns only tags that exist. Missing IDs are silently ignored.
  /// Useful for resolving recipe.personalTagIds to full PersonalTag objects.
  /// Batches into whereIn queries of 30 (Firestore limit) to reduce reads.
  Future<List<PersonalTag>> getByIds(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];

    requireCurrentUserId();
    final ref = getCollectionRef();
    final results = <PersonalTag>[];

    // Firestore whereIn supports max 30 values per query
    const batchSize = 30;
    for (var i = 0; i < tagIds.length; i += batchSize) {
      final batch = tagIds.sublist(
        i,
        (i + batchSize).clamp(0, tagIds.length),
      );
      final snapshot =
          await ref.where(FieldPath.documentId, whereIn: batch).get();
      results.addAll(snapshot.docs.map(fromFirestore));
    }

    return results;
  }

  /// Reorders tags by updating their sortOrder values.
  Future<void> reorder(List<String> tagIds) async {
    requireCurrentUserId();
    final batch = firestore.batch();
    final ref = getCollectionRef();

    for (var i = 0; i < tagIds.length; i++) {
      batch.update(ref.doc(tagIds[i]), {
        'sortOrder': i,
        'updatedAt': Timestamp.now(),
      });
    }

    await batch.commit();
  }

  /// Gets tags belonging to a specific group.
  /// Pass null to get ungrouped tags.
  Future<List<PersonalTag>> getByGroupId(String? groupId) async {
    Query<Map<String, dynamic>> query;

    if (groupId == null) {
      // Tags with no group (groupId is null or missing)
      query = getCollectionRef().where('groupId', isNull: true);
    } else {
      query = getCollectionRef().where('groupId', isEqualTo: groupId);
    }

    final snapshot = await query.orderBy('sortOrder').get();
    return snapshot.docs.map(fromFirestore).toList();
  }

  /// Watches tags belonging to a specific group with real-time updates.
  /// Pass null to watch ungrouped tags.
  Stream<List<PersonalTag>> watchByGroupId(String? groupId) {
    Query<Map<String, dynamic>> query;

    if (groupId == null) {
      query = getCollectionRef().where('groupId', isNull: true);
    } else {
      query = getCollectionRef().where('groupId', isEqualTo: groupId);
    }

    return query
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
  }

  /// Gets all ungrouped tags (convenience method).
  Future<List<PersonalTag>> getUngrouped() => getByGroupId(null);

  /// Watches all ungrouped tags (convenience method).
  Stream<List<PersonalTag>> watchUngrouped() => watchByGroupId(null);

  /// Moves a tag to a different group.
  /// Pass null to remove from group (make ungrouped).
  Future<void> moveToGroup(String tagId, String? groupId) async {
    requireCurrentUserId();
    await getCollectionRef().doc(tagId).update({
      'groupId': groupId,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Clears groupId from all tags in a group (used before group deletion).
  /// Returns the number of tags updated.
  Future<int> clearGroupFromTags(String groupId) async {
    requireCurrentUserId();
    final tagsInGroup = await getByGroupId(groupId);

    if (tagsInGroup.isEmpty) return 0;

    final batch = firestore.batch();
    final ref = getCollectionRef();

    for (final tag in tagsInGroup) {
      batch.update(ref.doc(tag.id), {
        'groupId': FieldValue.delete(),
        'updatedAt': Timestamp.now(),
      });
    }

    await batch.commit();
    return tagsInGroup.length;
  }

  /// #7: Adds clear-group operations to an external batch without committing.
  ///
  /// Use this for atomic group deletion with cascade.
  /// Returns the number of tags that will be updated.
  Future<int> addClearGroupToBatch(WriteBatch batch, String groupId) async {
    requireCurrentUserId();
    final tagsInGroup = await getByGroupId(groupId);

    if (tagsInGroup.isEmpty) return 0;

    final ref = getCollectionRef();
    for (final tag in tagsInGroup) {
      batch.update(ref.doc(tag.id), {
        'groupId': FieldValue.delete(),
        'updatedAt': Timestamp.now(),
      });
    }

    return tagsInGroup.length;
  }

  /// #7: Creates a new WriteBatch for atomic cross-repository operations.
  WriteBatch newWriteBatch() => firestore.batch();
}
