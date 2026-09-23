/// Firebase implementation of [OverwrittenVersionRepository] (P5-U26b).
///
/// Stores at `users/{uid}/overwritten_versions/{autoId}`. Owner-only, as in
/// the acquisition and onboarding subcollections: the uid is the document
/// path, so every permission check is "is the caller that user". The rules
/// block in firestore.rules enforces the same server-side and forbids updates,
/// so a kept version cannot be altered, only restored or forgotten.
///
/// The queries use equality filters only (entity, and resourceId when given),
/// which Firestore serves from single-field indexes; the ordering is done here
/// so no composite index is needed.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/overwritten_version_repository.dart';

class FirebaseOverwrittenVersionRepository
    extends BaseFirebaseRepository<OverwrittenVersion>
    implements OverwrittenVersionRepository {
  FirebaseOverwrittenVersionRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => FirestoreCollections.overwrittenVersions;

  @override
  OverwrittenVersion fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final parsed = OverwrittenVersion.fromFirestore(doc.id, doc.data() ?? {});
    if (parsed == null) {
      throw FormatException('Not a restorable overwritten version: ${doc.id}');
    }
    return parsed;
  }

  @override
  Map<String, dynamic> toFirestore(OverwrittenVersion entity) =>
      entity.toFirestore();

  @override
  String getId(OverwrittenVersion entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(
    String userId,
    OverwrittenVersion entity,
  ) async => userId == requireCurrentUserId() && entity.ownerId == userId;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    OverwrittenVersion? entity,
  ) async => userId == requireCurrentUserId();

  /// A kept version is never changed; it is restored or forgotten.
  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    OverwrittenVersion entity,
  ) async => false;

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => userId == requireCurrentUserId();

  CollectionReference<Map<String, dynamic>> _mine(String uid) => firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection(FirestoreCollections.overwrittenVersions);

  @override
  Future<OverwrittenVersion> keep(OverwrittenVersion version) async {
    final uid = requireCurrentUserId();
    if (!await validateCreatePermission(uid, version)) {
      throw PermissionDeniedException(
        'An overwritten version can only be kept for its own user',
      );
    }
    final ref = _mine(uid).doc();
    await ref.set(version.toFirestore());
    return version.withId(ref.id);
  }

  @override
  Stream<List<OverwrittenVersion>> watch({
    required ConflictEntity entity,
    String? resourceId,
  }) {
    final uid = requireCurrentUserId();
    Query<Map<String, dynamic>> query = _mine(
      uid,
    ).where('entity', isEqualTo: entity.name);
    if (resourceId != null) {
      query = query.where('resourceId', isEqualTo: resourceId);
    }
    return query.snapshots().map((snap) {
      final versions = [
        for (final doc in snap.docs)
          ?OverwrittenVersion.fromFirestore(doc.id, doc.data()),
      ]..sort((a, b) => b.overwrittenAt.compareTo(a.overwrittenAt));
      return versions;
    });
  }

  @override
  Future<void> forget(String versionId) async {
    final uid = requireCurrentUserId();
    await _mine(uid).doc(versionId).delete();
  }
}
