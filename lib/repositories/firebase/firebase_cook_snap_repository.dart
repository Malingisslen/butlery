import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';

/// Firebase implementation for CookSnap storage.
///
/// CookSnaps are stored as a top-level collection (not subcollection)
/// for easier cross-recipe queries during GDPR export/deletion.
class FirebaseCookSnapRepository extends BaseFirebaseRepository<CookSnap>
    implements CookSnapRepository {
  FirebaseCookSnapRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.cookSnaps;

  @override
  CookSnap fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      CookSnap.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(CookSnap entity) => entity.toFirestore();

  @override
  String getId(CookSnap entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(String userId, CookSnap entity) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, CookSnap? entity) async {
    return true; // All authenticated users can read cook snaps
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, CookSnap entity) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    try {
      final snap = await read(resourceId);
      if (snap == null) return false;
      return snap.userId == userId;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<CookSnap>> getCookSnapsForRecipe(
    String recipeId, {
    int limit = 20,
  }) async {
    final snapshot = await collection
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  @override
  Future<CookSnap> addCookSnap(CookSnap snap) async {
    requireCurrentUserId();
    await collection.doc(snap.id).set(toFirestore(snap));
    return snap;
  }

  @override
  Future<void> deleteCookSnap(String snapId) async {
    final userId = requireCurrentUserId();
    final doc = await collection.doc(snapId).get();
    if (!doc.exists) return;
    final snap = fromFirestore(doc);
    if (snap.userId != userId) {
      throw Exception('Permission denied: cannot delete this cook snap');
    }
    await collection.doc(snapId).delete();
  }

  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) {
    return collection
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }

  @override
  Future<List<CookSnap>> getCookSnapsByUser(String userId) async {
    final snapshot = await collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  @override
  Future<int> deleteAllByUser(String userId) async {
    final snapshot = await collection.where('userId', isEqualTo: userId).get();

    if (snapshot.docs.isEmpty) return 0;

    await batchDeleteDocs(firestore, snapshot.docs);
    AppLogger.info(
        'Deleted ${snapshot.docs.length} cook snaps for user $userId');
    return snapshot.docs.length;
  }
}
