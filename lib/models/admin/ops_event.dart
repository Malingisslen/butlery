import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-model for the admin ops-log tab: one scheduled-job run record from the
/// `system_events` collection. Different cleanup jobs write slightly different
/// shapes (e.g. `totalDeleted` vs `deletionAuditDeletedCount`), so this
/// normalizes the bits the dashboard shows: type, when it ran, how much it
/// removed.
class OpsEvent {
  final String type;
  final DateTime? executedAt;

  /// How many records the run removed, when the job reports it. Null when the
  /// event carries no count.
  final int? deletedCount;

  const OpsEvent({
    required this.type,
    this.executedAt,
    this.deletedCount,
  });

  factory OpsEvent.fromFirestore(Map<String, dynamic> data) {
    final ts = data['executedAt'];
    // Cleanup jobs use different field names for the removed-count; take
    // whichever is present.
    final rawCount = data['totalDeleted'] ?? data['deletionAuditDeletedCount'];
    return OpsEvent(
      type: (data['type'] as String?) ?? 'unknown',
      executedAt: ts is Timestamp ? ts.toDate() : null,
      deletedCount: rawCount is num ? rawCount.toInt() : null,
    );
  }
}
