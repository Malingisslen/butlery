import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/firebase/firestore_batch_utils.dart';

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
    required String viewerId,
    required Set<String> friendIds,
    int limit = 20,
  }) async {
    if (viewerId.isEmpty) return const [];

    final snapshots = await Future.wait(
        _readQueries(recipeId, viewerId, friendIds, limit).map((q) => q.get()));

    return _mergeAndRank(snapshots, limit);
  }

  @override
  Stream<List<CookSnap>> watchCookSnaps(
    String recipeId, {
    required String viewerId,
    required Set<String> friendIds,
    int limit = 20,
  }) {
    if (viewerId.isEmpty) return Stream<List<CookSnap>>.value(const []);

    final streams = _readQueries(recipeId, viewerId, friendIds, limit)
        .map((q) => q.snapshots())
        .toList();

    // combineLatestList waits for every chunk's first emission before
    // producing output (no partial-state UI flashes), and propagates cancel
    // to every inner subscription.
    return Rx.combineLatestList(streams)
        .map((snaps) => _mergeAndRank(snaps, limit));
  }

  /// BUT-1214: the viewer's own snaps are queried WITHOUT a visibility
  /// filter (they see their own `onlyMe` snaps); friends' snaps must carry
  /// an explicit `visibility == sameAsRecipe` constraint — rules deny
  /// foreign `onlyMe` docs and one such doc in a result set would fail the
  /// whole query. Legacy docs are backfilled with the field (see
  /// functions/scripts/backfill-cook-snap-visibility.js).
  List<Query<Map<String, dynamic>>> _readQueries(
    String recipeId,
    String viewerId,
    Set<String> friendIds,
    int limit,
  ) {
    final friendChunks =
        ({...friendIds}..remove(viewerId)).chunked(kFirestoreWhereInLimit);

    // Every query fetches the full `limit`: the global top-N can come
    // entirely from one chunk (a prolific friend, or the viewer's own
    // snaps), so a divided per-chunk budget silently drops the newest
    // snaps. Worst-case reads stay bounded at limit * (1 + chunks).
    final base = collection
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return [
      base.where('userId', isEqualTo: viewerId),
      for (final chunk in friendChunks)
        base.where('userId', whereIn: chunk).where('visibility',
            isEqualTo: CookSnapVisibility.sameAsRecipe.name),
    ];
  }

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
    // BUT-965: server-authoritative createdAt. Model produces an optimistic
    // client timestamp (needed for unit-test determinism + immediate UI);
    // we override at the write boundary so the persisted value defends
    // against client-clock skew/manipulation. In-memory snap keeps the
    // optimistic time — the next read resolves to the server value.
    final data = toFirestore(snap);
    data['createdAt'] = FieldValue.serverTimestamp();
    await collection.doc(snap.id).set(data);
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
