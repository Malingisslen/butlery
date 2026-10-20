// lib/services/offline/cook_snap_group_queue.dart
//
// BUT-2294: a cook snap's photos are one row each in the upload queue but ONE
// item to the user. Split out of sync_queue_reader.dart to keep that file under
// the size limit.
library;

import 'package:drift/drift.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/services/offline/queued_change.dart';

bool isCookSnapRow(UploadQueueEntry row) =>
    row.entityType == SyncQueueEntityType.cookSnap && row.entityId != null;

Map<String, List<UploadQueueEntry>> cookSnapGroups(
  List<UploadQueueEntry> rows,
) {
  final groups = <String, List<UploadQueueEntry>>{};
  for (final row in rows.where(isCookSnapRow)) {
    (groups[row.entityId!] ??= []).add(row);
  }
  return groups;
}

/// The photos of one cook snap as ONE item. The queue marks a failure on the
/// row that failed and leaves its siblings as they are, so the album needs the
/// user as soon as any photo does, and it waits for the user until the whole
/// album is retried or thrown away.
QueuedChange cookSnapChange(
  List<UploadQueueEntry> rows,
  bool Function(String? stored) waits,
) {
  final failed = rows.where((r) => r.permanentlyFailed).toList();
  final first = rows.reduce((a, b) => b.queuedAt.isBefore(a.queuedAt) ? b : a);
  return QueuedChange(
    kind: QueuedChangeKind.image,
    id: first.entityId!,
    operation: QueuedOperation.upload,
    queuedAt: first.queuedAt,
    needsUser: failed.isNotEmpty,
    reason: QueuedChangeReason.parse(failed.firstOrNull?.lastError),
    waitsOnEarlier: failed.isEmpty && rows.any((r) => waits(r.dependsOn)),
    entityType: SyncQueueEntityType.cookSnap,
    entityId: first.entityId,
    photoCount: rows.length,
  );
}

/// Every photo of the album goes back into the queue. One that is already in
/// Storage keeps its status, so it is not uploaded a second time.
Future<void> retryCookSnapGroup(
  AppDatabase db,
  String userId,
  String snapId,
) {
  return db.transaction(() async {
    final inGroup = db.update(db.uploadQueueEntries)
      ..where(
        (e) =>
            e.userId.equals(userId) &
            e.entityType.equals(SyncQueueEntityType.cookSnap) &
            e.entityId.equals(snapId) &
            e.status.isNotIn(const ['completed', 'cancelled']),
      );
    await inGroup.write(
      const UploadQueueEntriesCompanion(
        permanentlyFailed: Value(false),
        retryCount: Value(0),
        lastError: Value(null),
        nextAttemptAt: Value(null),
        firstFailedAt: Value(null),
      ),
    );
    await (db.update(db.uploadQueueEntries)..where(
          (e) =>
              e.userId.equals(userId) &
              e.entityType.equals(SyncQueueEntityType.cookSnap) &
              e.entityId.equals(snapId) &
              e.uploadedUrl.isNull() &
              e.status.isNotIn(const ['completed', 'cancelled']),
        ))
        .write(const UploadQueueEntriesCompanion(status: Value('pending')));
  });
}
