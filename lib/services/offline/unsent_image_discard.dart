// lib/services/offline/unsent_image_discard.dart
//
// BUT-2294: throws away the unsent images that waited out
// [kUnsentImageKeep]. Local only: it needs no network and no signed-in user,
// so the startup sweep can reach the rows of an account that signed out or
// was switched away from.
library;

import 'package:drift/drift.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/sync_queue_reader.dart'
    show discardQueuedChange, readQueuedChanges;
import 'package:butlery/services/offline/unsent_image_expiry.dart';

/// The rows that failed for good and have waited out the whole period, for
/// [userId] or, when it is null, for every user.
Future<List<UploadQueueEntry>> expiredUnsentRows(
  AppDatabase db,
  DateTime now, {
  String? userId,
}) async {
  final query = db.select(db.uploadQueueEntries)
    ..where(
      (e) =>
          e.permanentlyFailed.equals(true) &
          e.status.isNotIn(const ['completed', 'cancelled']),
    );
  if (userId != null) query.where((e) => e.userId.equals(userId));
  final failed = await query.get();
  return [
    for (final row in failed)
      if (unsentImageExpired(
        unsentImageSince(row.firstFailedAt, row.queuedAt),
        now,
      ))
        row,
  ];
}

/// Discards what [userId] has waiting for the user for longer than the
/// period, by the path of the user's "Släng"; a cook-snap album goes whole.
/// Returns how many items went.
Future<int> discardExpiredUnsent(
  AppDatabase db,
  String userId,
  DateTime now,
) async {
  if ((await expiredUnsentRows(db, now, userId: userId)).isEmpty) return 0;
  var discarded = 0;
  for (final change in await readQueuedChanges(db, userId)) {
    final since = change.unsentSince;
    if (change.kind != QueuedChangeKind.image ||
        !change.needsUser ||
        since == null ||
        !unsentImageExpired(since, now)) {
      continue;
    }
    await discardQueuedChange(db, userId, change);
    discarded++;
  }
  return discarded;
}

/// Discards the expired unsent images of every user on the device. The pass
/// only runs for the signed-in user, so without this a photo of someone who
/// signed out would outlive the 30 days the policy promises. Any image the
/// row had put in Storage keeps its address on the cancelled row for that
/// user's next pass to take back. Also drops cancelled rows that hold no image,
/// which a user who never signs in again would otherwise keep with their
/// caption and recipe; nothing is uploading when the app starts. Never throws.
Future<int> sweepExpiredUnsent(AppDatabase db, DateTime now) async {
  var discarded = 0;
  try {
    final userIds = {
      for (final row in await expiredUnsentRows(db, now)) row.userId,
    };
    for (final userId in userIds) {
      try {
        discarded += await discardExpiredUnsent(db, userId, now);
      } catch (e) {
        AppLogger.error(
          '❌ Gammal osänd bild kunde inte slängas: ${queueErrorCode(e)}',
        );
      }
    }
  } catch (e) {
    AppLogger.error(
      '❌ Genomgång av gamla osända bilder misslyckades: ${queueErrorCode(e)}',
    );
  }
  try {
    await db.uploadQueueDao.dropCancelledWithoutImage();
  } catch (e) {
    AppLogger.error(
      '❌ Avbrutna bilder kunde inte rensas: ${queueErrorCode(e)}',
    );
  }
  return discarded;
}
