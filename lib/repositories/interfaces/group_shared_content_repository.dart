import 'package:cloud_firestore/cloud_firestore.dart';

/// Read access to shared content scoped to a friend group.
///
/// BUT-504: extracted from `GroupSharedContentService` so the service layer no
/// longer holds a `FirebaseFirestore` instance directly. The group view needs a
/// cross-content-type `arrayContainsAny` query against the unified
/// `shared_content` collection — a pattern distinct from the per-type
/// subcollection queries in [BaseSharedContentRepository], so it lives in its
/// own repository rather than reusing the typed shared-content repos.
abstract class GroupSharedContentRepository {
  /// Fetch up to [limit] shared-content documents of [contentType] visible to
  /// any of [memberIds], newest first. Returns the raw docs so the caller can
  /// map them to its own view model.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getSharedContent({
    required List<String> memberIds,
    required String contentType,
    int limit = 20,
  });

  /// Realtime variant of [getSharedContent].
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamSharedContent({
    required List<String> memberIds,
    required String contentType,
    int limit = 20,
  });
}
