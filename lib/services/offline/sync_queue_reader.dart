// lib/services/offline/sync_queue_reader.dart
//
// P4-U19: the native side of the "Väntar på synk" view. Reads both queues of
// schema 3 (P5-U35) and acts on one entry at the user's request. The web has
// no offline queue (sync_queue_reader_web.dart).
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/services/offline/queued_change.dart';

/// Upload statuses that still count as waiting, as in
/// AppDatabase.watchQueueCounts: pending, uploading and failed.
const _waitingUploadStatuses = ['pending', 'uploading', 'failed'];

/// Every change of [userId] that has not reached the server, live, across
/// the sync queue and the upload queue. Re-read whenever either table (or a
/// recipe title) changes.
Stream<List<QueuedChange>> watchQueuedChanges(AppDatabase db, String userId) {
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.syncQueueEntries,
          db.uploadQueueEntries,
          db.offlineRecipes,
        },
      )
      .watch()
      .asyncMap((_) => readQueuedChanges(db, userId));
}

/// One read of [watchQueuedChanges].
Future<List<QueuedChange>> readQueuedChanges(
  AppDatabase db,
  String userId,
) async {
  final syncRows = await (db.select(
    db.syncQueueEntries,
  )..where((e) => e.userId.equals(userId))).get();
  final uploadRows =
      await (db.select(db.uploadQueueEntries)..where(
            (e) =>
                e.userId.equals(userId) &
                (e.status.isIn(_waitingUploadStatuses) |
                    (e.permanentlyFailed.equals(true) &
                        e.status.isNotIn(const ['completed', 'cancelled']))),
          ))
          .get();

  final recipeIds = <String>{
    for (final row in syncRows)
      if (row.entityType == SyncQueueEntityType.recipe) row.recipeId,
    for (final row in uploadRows)
      if (row.entityType == SyncQueueEntityType.recipe && row.entityId != null)
        row.entityId!,
  };
  final titles = await _recipeTitles(db, userId, recipeIds);

  // An entry waits on an earlier one when one of its dependsOn opIds is still
  // in either queue (produktregler.md:187).
  final queuedIds = <String>{
    for (final row in syncRows) row.opId,
    for (final row in uploadRows) row.id,
  };
  bool waits(String? stored) => decodeDependsOn(stored).any(queuedIds.contains);

  return [
    for (final row in syncRows)
      QueuedChange(
        kind: QueuedChangeKind.recipe,
        id: row.opId,
        operation: _operation(row.operation),
        queuedAt: row.queuedAt,
        subject: row.entityType == SyncQueueEntityType.recipe
            ? titles[row.recipeId]
            : null,
        needsUser: row.permanentlyFailed,
        reason: QueuedChangeReason.parse(row.lastError),
        waitsOnEarlier: !row.permanentlyFailed && waits(row.dependsOn),
      ),
    for (final row in uploadRows)
      QueuedChange(
        kind: QueuedChangeKind.image,
        id: row.id,
        operation: QueuedOperation.upload,
        queuedAt: row.queuedAt,
        subject: row.entityType == SyncQueueEntityType.recipe
            ? titles[row.entityId]
            : null,
        needsUser: row.permanentlyFailed,
        reason: QueuedChangeReason.parse(row.lastError),
        waitsOnEarlier: !row.permanentlyFailed && waits(row.dependsOn),
      ),
  ];
}

/// "Försök igen": the entry leaves "Väntar på dig" and the queue sends it
/// again from the start. Nothing is deleted.
Future<void> retryQueuedChange(AppDatabase db, QueuedChange change) async {
  switch (change.kind) {
    case QueuedChangeKind.recipe:
      await (db.update(
        db.syncQueueEntries,
      )..where((e) => e.opId.equals(change.id))).write(
        const SyncQueueEntriesCompanion(
          permanentlyFailed: Value(false),
          retryCount: Value(0),
          lastError: Value(null),
        ),
      );
    case QueuedChangeKind.image:
      await (db.update(
        db.uploadQueueEntries,
      )..where((e) => e.id.equals(change.id))).write(
        const UploadQueueEntriesCompanion(
          permanentlyFailed: Value(false),
          status: Value('pending'),
          retryCount: Value(0),
          lastError: Value(null),
        ),
      );
  }
}

/// "Släng ändringen", chosen by the user. What depended on the change can
/// never be sent without it, so the whole chain is marked as failed first and
/// stays for her to decide on ("aldrig halvvägs", produktregler.md:187). Only
/// the chosen entry itself goes.
Future<void> discardQueuedChange(
  AppDatabase db,
  String userId,
  QueuedChange change,
) async {
  await db.markChainPermanentlyFailed(
    userId,
    change.id,
    reason: QueuedChangeReason.dependencyFailed.code,
  );
  switch (change.kind) {
    case QueuedChangeKind.recipe:
      await (db.delete(
        db.syncQueueEntries,
      )..where((e) => e.opId.equals(change.id))).go();
    case QueuedChangeKind.image:
      await db.uploadQueueDao.cancelUpload(change.id);
  }
}

QueuedOperation _operation(String stored) => switch (stored) {
  'create' => QueuedOperation.create,
  'delete' => QueuedOperation.delete,
  'tag' => QueuedOperation.tag,
  _ => QueuedOperation.update,
};

/// The titles of the device copies of [ids], by recipe id. A recipe the
/// device has no copy of has no entry.
Future<Map<String, String>> _recipeTitles(
  AppDatabase db,
  String userId,
  Set<String> ids,
) async {
  if (ids.isEmpty) return const {};
  final rows = await (db.select(
    db.offlineRecipes,
  )..where((r) => r.userId.equals(userId) & r.id.isIn(ids))).get();
  final titles = <String, String>{};
  for (final row in rows) {
    try {
      final decoded = jsonDecode(row.recipeJson);
      final title = decoded is Map ? decoded['title'] : null;
      if (title is String && title.trim().isNotEmpty) {
        titles[row.id] = title.trim();
      }
    } on FormatException {
      // A copy that cannot be read has no title; the row says "Ett recept".
    }
  }
  return titles;
}
