// lib/services/offline/unsent_image_discard.dart
//
// BUT-2294: throws away the unsent images that waited out
// [kUnsentImageKeep]. Local only: it needs no network and no signed-in user,
// so the startup sweep can reach the rows of an account that signed out or
// was switched away from.
library;

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/sync_queue_reader.dart'
    show discardQueuedChange, readQueuedChanges;
import 'package:butlery/services/offline/unsent_image_expiry.dart';

/// The unsent rows that have waited out the whole period, whether or not they
/// ever failed for good (Malin 2026-10-20), for [userId] or, when it is null,
/// for every user.
Future<List<UploadQueueEntry>> expiredUnsentRows(
  AppDatabase db,
  DateTime now, {
  String? userId,
}) async {
  final query = db.select(db.uploadQueueEntries)
    ..where((e) => e.status.isNotIn(const ['completed', 'cancelled']));
  if (userId != null) query.where((e) => e.userId.equals(userId));
  final unsent = await query.get();
  return [
    for (final row in unsent)
      if (unsentImageExpired(
        unsentImageSince(
          row.firstFailedAt,
          row.queuedAt,
          retriedAt: row.retriedAt,
        ),
        now,
      ))
        row,
  ];
}

/// Discards what [userId] has waiting for longer than the period, by the path
/// of the user's "Släng"; a cook-snap album goes whole. A row that was still
/// retrying is first marked failed for good, which is what puts it on that
/// path. Returns how many items went.
Future<int> discardExpiredUnsent(
  AppDatabase db,
  String userId,
  DateTime now,
) async {
  final expired = await expiredUnsentRows(db, now, userId: userId);
  if (expired.isEmpty) return 0;
  for (final row in expired) {
    if (!row.permanentlyFailed) {
      await db.uploadQueueDao.markPermanentlyFailed(row.id, reason: 'expired');
    }
  }
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
