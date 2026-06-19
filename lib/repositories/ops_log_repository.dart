import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/admin/ops_event.dart';

/// Admin-only, read-only repository for the ops-log dashboard tab.
///
/// Reads recent scheduled-job run records from `system_events`, newest first.
/// Admin-gated by `firestore.rules` (system_events read = isAdmin). The records
/// are written server-side by the cleanup Cloud Functions; this never writes.
///
/// Follows the lightweight admin-repo pattern (cf. [SiteConfigRepository]):
/// direct Firestore, no PermissionValidationMixin; admin-only ops data.
///
/// Coverage note: only the cleanup jobs currently write here. The analytics /
/// retention jobs do not yet record a run, so this tab is sparse by design
/// until that server-side logging is added (tracked as a follow-up).
class OpsLogRepository {
  final FirebaseFirestore _firestore;

  OpsLogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// The most recent [limit] job-run events, newest first. Returns an empty
  /// list on error so the tab degrades to an empty state rather than crashing.
  ///
  /// NOTE: Firestore excludes documents that lack `executedAt` from this
  /// ordered query — any new Cloud Function writing to `system_events` must
  /// set that field or its records will be invisible here.
  Future<List<OpsEvent>> getRecentEvents({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.systemEvents)
          .orderBy('executedAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => OpsEvent.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      AppLogger.warning('OpsLogRepository: failed to load system events: $e');
      return [];
    }
  }
}
