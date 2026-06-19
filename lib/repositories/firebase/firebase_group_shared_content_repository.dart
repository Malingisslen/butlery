import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:butlery/repositories/interfaces/group_shared_content_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';

/// Firestore-backed group shared-content reader.
///
/// BUT-504: this is an infrastructure-layer repository (like
/// [FirestoreRepository]), not a model-typed [BaseFirebaseRepository]. It
/// returns raw `shared_content` documents so the caller
/// (`GroupSharedContentService`) can map them into its own `SharedContentItem`
/// view model — there is no single domain model at this layer to type against.
///
/// Read access is enforced by Firestore security rules. The `list` rule on
/// `shared_content` allows either the sharer (`sharedByUserId`) OR a recipient
/// (`request.auth.uid in sharedToUserIds`); the rules engine evaluates that
/// branch per candidate document, so a recipient can only list documents whose
/// `sharedToUserIds` actually contains their uid. The queries below filter by
/// `sharedToUserIds arrayContainsAny [...]`, which must stay aligned with that
/// rule — otherwise the query is permission-denied and silently returns empty.
/// Member lists are chunked at the 30-value `arrayContainsAny` cap and the
/// per-chunk results are merged, deduped, re-sorted and capped at `limit`.
class FirebaseGroupSharedContentRepository
    implements GroupSharedContentRepository {
  final FirebaseFirestore _firestore;

  FirebaseGroupSharedContentRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Builds one query per member-id chunk. `arrayContainsAny` caps at
  /// [kFirestoreWhereInLimit] (30) values, so a group with 30+ members must
  /// fan out into multiple queries (mirrors the chunking in
  /// `firebase_activity_event_repository.dart`). Each chunk fetches the full
  /// [limit]: the global newest-N can come entirely from one chunk, so a
  /// divided per-chunk budget would silently drop the newest docs.
  List<Query<Map<String, dynamic>>> _buildQueries({
    required List<String> memberIds,
    required String contentType,
    required int limit,
  }) {
    return [
      for (final chunk in memberIds.chunked(kFirestoreWhereInLimit))
        _firestore
            .collection(FirestoreCollections.sharedContent)
            .where('contentType', isEqualTo: contentType)
            .where('sharedToUserIds', arrayContainsAny: chunk)
            .orderBy('sharedAt', descending: true)
            .limit(limit),
    ];
  }

  /// Merges chunk results: dedupes by doc id (a doc shared to members in two
  /// different chunks matches both), re-sorts newest-first, caps at [limit].
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergeChunks(
    Iterable<List<QueryDocumentSnapshot<Map<String, dynamic>>>> chunkResults,
    int limit,
  ) {
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final docs in chunkResults) {
      for (final doc in docs) {
        byId[doc.id] = doc;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final aAt = a.data()['sharedAt'];
        final bAt = b.data()['sharedAt'];
        if (aAt is Timestamp && bAt is Timestamp) {
          return bAt.compareTo(aAt);
        }
        return 0;
      });
    return merged.take(limit).toList();
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getSharedContent({
    required List<String> memberIds,
    required String contentType,
    int limit = 20,
  }) async {
    if (memberIds.isEmpty) return const [];

    final snapshots = await Future.wait(
      _buildQueries(
        memberIds: memberIds,
        contentType: contentType,
        limit: limit,
      ).map((q) => q.get()),
    );
    return _mergeChunks(snapshots.map((s) => s.docs), limit);
  }

  @override
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamSharedContent({
    required List<String> memberIds,
    required String contentType,
    int limit = 20,
  }) {
    if (memberIds.isEmpty) {
      return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value(
          const []);
    }

    final streams = _buildQueries(
      memberIds: memberIds,
      contentType: contentType,
      limit: limit,
    ).map((q) => q.snapshots()).toList();

    // combineLatestList waits for every chunk's first emission before
    // producing output (no partial-state flashes) and propagates cancel to
    // every inner subscription.
    return Rx.combineLatestList(streams)
        .map((snaps) => _mergeChunks(snaps.map((s) => s.docs), limit));
  }
}
