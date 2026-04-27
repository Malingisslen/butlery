import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';

/// Firebase implementation for CookSnap storage.
///
/// CookSnaps are stored as a top-level collection (not subcollection) for
/// easier cross-recipe queries during GDPR export/deletion.
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
    // Authorisation enforced at rules layer.
    return true;
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
    required Set<String> allowedUserIds,
    int limit = 20,
  }) async {
    if (allowedUserIds.isEmpty) return const [];

    final chunks = allowedUserIds.chunked(kFirestoreWhereInLimit);
    // Per-chunk over-fetch buffer: each chunk needs at most `limit` of its
    // own to contribute to a global top-N, but we allow a small buffer for
    // ties. Caps total reads at `limit + chunks*buf` instead of `limit*chunks`.
    final perChunkLimit =
        chunks.length == 1 ? limit : (limit ~/ chunks.length) + 5;

    final snapshots = await Future.wait(chunks
        .map((chunk) => _chunkQuery(recipeId, chunk, perChunkLimit).get()));

    return _mergeAndRank(snapshots, limit);
  }

  @override
  Stream<List<CookSnap>> watchCookSnaps(
    String recipeId, {
    required Set<String> allowedUserIds,
    int limit = 20,
  }) {
    if (allowedUserIds.isEmpty) return Stream<List<CookSnap>>.value(const []);

    final chunks = allowedUserIds.chunked(kFirestoreWhereInLimit);
    final perChunkLimit =
        chunks.length == 1 ? limit : (limit ~/ chunks.length) + 5;

    final streams = chunks
        .map((chunk) => _chunkQuery(recipeId, chunk, perChunkLimit).snapshots())
        .toList();

    // combineLatestList waits for every chunk's first emission before
    // producing output (no partial-state UI flashes), and propagates cancel
    // to every inner subscription.
    return Rx.combineLatestList(streams)
        .map((snaps) => _mergeAndRank(snaps, limit));
  }

  Query<Map<String, dynamic>> _chunkQuery(
    String recipeId,
    List<String> chunk,
    int limit,
  ) =>
      collection
          .where('recipeId', isEqualTo: recipeId)
          .where('userId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(limit);

  List<CookSnap> _mergeAndRank(
    List<QuerySnapshot<Map<String, dynamic>>> snapshots,
    int limit,
  ) {
    final merged = snapshots
        .expand((s) => s.docs)
        .map((doc) => fromFirestore(doc))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged.take(limit).toList();
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
  Future<List<CookSnap>> getCookSnapsByUser(String userId) async {
    final snapshot = await collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> exportCookSnapsByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    // GDPR Article 20: caller must be exporting their own snaps.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    final snapshot = await collection
        .where('userId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  @override
  Future<int> deleteAllByUser(String userId) async {
    // GDPR cascade: caller must be deleting their own data.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    final snapshot = await collection.where('userId', isEqualTo: userId).get();
    if (snapshot.docs.isEmpty) return 0;
    await batchDeleteDocs(firestore, snapshot.docs);
    AppLogger.info(
        'Deleted ${snapshot.docs.length} cook snaps for user $userId');
    return snapshot.docs.length;
  }
}
