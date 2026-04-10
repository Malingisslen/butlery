import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

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
    final canDelete = await validateDeletePermission(userId, snapId);
    if (!canDelete) {
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
    final snaps = await getCookSnapsByUser(userId);
    if (snaps.isEmpty) return 0;

    // Batch delete in groups of 500 (Firestore limit)
    final batches = <WriteBatch>[];
    var currentBatch = firestore.batch();
    var count = 0;

    for (final snap in snaps) {
      currentBatch.delete(collection.doc(snap.id));
      count++;
      if (count % 500 == 0) {
        batches.add(currentBatch);
        currentBatch = firestore.batch();
      }
    }
    if (count % 500 != 0) {
      batches.add(currentBatch);
    }

    for (final batch in batches) {
      await batch.commit();
    }

    AppLogger.info('Deleted $count cook snaps for user $userId');
    return count;
  }
}
