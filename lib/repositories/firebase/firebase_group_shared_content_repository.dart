import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/group_shared_content_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firestore-backed group shared-content reader.
///
/// BUT-504: this is an infrastructure-layer repository (like
/// [FirestoreRepository]), not a model-typed [BaseFirebaseRepository]. It
/// returns raw `shared_content` documents so the caller
/// (`GroupSharedContentService`) can map them into its own `SharedContentItem`
/// view model — there is no single domain model at this layer to type against.
///
/// BUT-2271: the `shared_content` list rule admits a document only when the
/// reader is its sharer or is in its `sharedToUserIds`, and a query must be
/// provable against that rule. So the query asks for what the VIEWER can read
/// (`sharedToUserIds array-contains viewerId`) and the group is matched afterwards on `groupIds`. Asking for
/// other members' ids, as this did before, was refused outright. Firestore
/// allows one array-contains per query, which is why the group match is not
/// part of the query.
class FirebaseGroupSharedContentRepository
    implements GroupSharedContentRepository {
  final FirebaseFirestore _firestore;

  FirebaseGroupSharedContentRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// How many of the viewer's newest shares of one type are scanned for the
  /// group. Shares to other groups and private shares compete for the window.
  static const scanWindow = 100;

  Query<Map<String, dynamic>> _query(String viewerId, String contentType) =>
      _firestore
          .collection(FirestoreCollections.sharedContent)
          .where('contentType', isEqualTo: contentType)
          .where('sharedToUserIds', arrayContains: viewerId)
          .orderBy('sharedAt', descending: true)
          .limit(scanWindow);

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _forGroup(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String groupId,
    int limit,
  ) => docs
      .where((doc) {
        final groupIds = doc.data()[sharedContentGroupIdsField];
        return groupIds is List && groupIds.contains(groupId);
      })
      .take(limit)
      .toList();

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getSharedContent({
    required String viewerId,
    required String groupId,
    required String contentType,
    int limit = 20,
  }) async {
    final snapshot = await _query(viewerId, contentType).get();
    return _forGroup(snapshot.docs, groupId, limit);
  }

  @override
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  streamSharedContent({
    required String viewerId,
    required String groupId,
    required String contentType,
    int limit = 20,
  }) => _query(
    viewerId,
    contentType,
  ).snapshots().map((s) => _forGroup(s.docs, groupId, limit));
}
