import 'package:cloud_firestore/cloud_firestore.dart';

/// The `shared_content` field naming the groups a share was made to
/// (BUT-2271). Written by every group share path, read by the group page.
const sharedContentGroupIdsField = 'groupIds';

/// Read access to shared content scoped to a friend group.
///
/// BUT-504: extracted from `GroupSharedContentService` so the service layer no
/// longer holds a `FirebaseFirestore` instance directly.
abstract class GroupSharedContentRepository {
  /// Fetch up to [limit] shared-content documents of [contentType] that were
  /// shared with [groupId] and that [viewerId] can read, newest first. Returns
  /// the raw docs so the caller can map them to its own view model.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getSharedContent({
    required String viewerId,
    required String groupId,
    required String contentType,
    int limit = 20,
  });

  /// Realtime variant of [getSharedContent].
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  streamSharedContent({
    required String viewerId,
    required String groupId,
    required String contentType,
    int limit = 20,
  });
}
