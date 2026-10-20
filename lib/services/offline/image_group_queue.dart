// lib/services/offline/image_group_queue.dart
//
// BUT-2294: a cook snap's or a comment's photos are one row each in the upload
// queue but ONE item to the user. Split out of sync_queue_reader.dart to keep
// that file under the size limit.
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/unsent_image_expiry.dart';

bool isImageGroupRow(UploadQueueEntry row) =>
    SyncQueueEntityType.grouped.contains(row.entityType) &&
    row.entityId != null;

/// The groups by type and id, so a comment and a cook snap that happen to
/// share an id stay two items.
Map<String, List<UploadQueueEntry>> imageGroups(List<UploadQueueEntry> rows) {
  final groups = <String, List<UploadQueueEntry>>{};
  for (final row in rows.where(isImageGroupRow)) {
    (groups['${row.entityType}/${row.entityId}'] ??= []).add(row);
  }
  return groups;
}

/// What the list calls a comment's recipe, from the metadata the comment
/// was queued with.
String? _recipeNameOf(UploadQueueEntry row) {
  try {
    final meta = jsonDecode(row.metadata ?? '{}');
    final name = meta is Map<String, dynamic> ? meta['recipeName'] : null;
    return name is String ? name : null;
  } on FormatException {
    return null;
  }
}

/// The photos of one cook snap or comment as ONE item. The queue marks a
/// failure on the row that failed and leaves its siblings as they are, so the
/// group needs the user as soon as any photo does, and it waits for the user
/// until the whole group is retried or thrown away.
QueuedChange imageGroupChange(
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
    subject: first.entityType == SyncQueueEntityType.comment
        ? _recipeNameOf(first)
        : null,
    entityType: first.entityType,
    entityId: first.entityId,
    photoCount: rows.length,
    // One photo that waited out the period takes the whole group with it.
    unsentSince: failed.isEmpty
        ? null
        : failed
              .map(
                (r) => unsentImageSince(
                  r.firstFailedAt,
                  r.queuedAt,
                  retriedAt: r.retriedAt,
                ),
              )
              .reduce((a, b) => b.isBefore(a) ? b : a),
  );
}

/// Every photo of the group goes back into the queue. One that is already in
/// Storage keeps its status, so it is not uploaded a second time.
Future<void> retryImageGroup(
  AppDatabase db,
  String userId,
  String entityType,
  String entityId,
) {
  return db.transaction(() async {
    final inGroup = db.update(db.uploadQueueEntries)
      ..where(
        (e) =>
            e.userId.equals(userId) &
            e.entityType.equals(entityType) &
            e.entityId.equals(entityId) &
            e.status.isNotIn(const ['completed', 'cancelled']),
      );
    await inGroup.write(
      UploadQueueEntriesCompanion(
        permanentlyFailed: const Value(false),
        retryCount: const Value(0),
        lastError: const Value(null),
        nextAttemptAt: const Value(null),
        firstFailedAt: const Value(null),
        retriedAt: Value(clock.now()),
      ),
    );
    await (db.update(db.uploadQueueEntries)..where(
          (e) =>
              e.userId.equals(userId) &
              e.entityType.equals(entityType) &
              e.entityId.equals(entityId) &
              e.uploadedUrl.isNull() &
              e.status.isNotIn(const ['completed', 'cancelled']),
        ))
        .write(const UploadQueueEntriesCompanion(status: Value('pending')));
  });
}
