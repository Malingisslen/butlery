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
/// Read access is enforced by Firestore security rules. The `list` rule on
/// `shared_content` allows either the sharer (`sharedByUserId`) OR a recipient
/// (`request.auth.uid in sharedToUserIds`); the rules engine evaluates that
/// branch per candidate document, so a recipient can only list documents whose
/// `sharedToUserIds` actually contains their uid. The query below filters by
/// `sharedToUserIds arrayContainsAny [...]`, which must stay aligned with that
/// rule — otherwise the query is permission-denied and silently returns empty.
class FirebaseGroupSharedContentRepository
    implements GroupSharedContentRepository {
  final FirebaseFirestore _firestore;

  FirebaseGroupSharedContentRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  Query<Map<String, dynamic>> _buildQuery({
    required List<String> memberIds,
    required String contentType,
    required int limit,
  }) {
    return _firestore
        .collection(FirestoreCollections.sharedContent)
        .where('contentType', isEqualTo: contentType)
        // arrayContainsAny supports up to 30 values — sufficient for current
        // group sizes.
        .where('sharedToUserIds', arrayContainsAny: memberIds)
        .orderBy('sharedAt', descending: true)
        .limit(limit);
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getSharedContent({
    required List<String> memberIds,
    required String contentType,
    int limit = 20,
  }) async {
    final snapshot = await _buildQuery(
      memberIds: memberIds,
      contentType: contentType,
      limit: limit,
    ).get();
    return snapshot.docs;
  }

  @override
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamSharedContent({
    required List<String> memberIds,
    required String contentType,
    int limit = 20,
  }) {
    return _buildQuery(
      memberIds: memberIds,
      contentType: contentType,
      limit: limit,
    ).snapshots().map((snapshot) => snapshot.docs);
  }
}
