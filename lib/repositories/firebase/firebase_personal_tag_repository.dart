import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

/// Firebase repository for user-defined personal tags.
///
/// Stores tags in user subcollection: users/{userId}/personalTags/{tagId}
/// Each user can only access their own tags (owner-only permissions).
class FirebasePersonalTagRepository extends BaseFirebaseRepository<PersonalTag>
    with UserScopedFirebaseRepository<PersonalTag> {
  FirebasePersonalTagRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => 'personalTags';

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
  Future<bool> validateCreatePermission(String userId, PersonalTag entity) async => true;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    PersonalTag? entity,
  ) async => true;

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    PersonalTag entity,
  ) async => true;

  @override
  Future<bool> validateDeletePermission(String userId, String resourceId) async => true;

  /// Gets all tags sorted by sortOrder.
  Future<List<PersonalTag>> getAllSorted() async {
    final snapshot = await getCollectionRef()
        .orderBy('sortOrder')
        .orderBy('createdAt')
        .get();

    return snapshot.docs.map(fromFirestore).toList();
  }

  /// Watches all tags with real-time updates, sorted by sortOrder.
  Stream<List<PersonalTag>> watchAllSorted() {
    return getCollectionRef()
        .orderBy('sortOrder')
        .orderBy('createdAt')
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

    final maxOrder = all
        .map((tag) => tag.sortOrder)
        .reduce((a, b) => a > b ? a : b);
    return maxOrder + 1;
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
}
