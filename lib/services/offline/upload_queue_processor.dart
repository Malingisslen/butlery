// lib/services/offline/upload_queue_processor.dart
//
// BUT-2162: sends the upload queue. A recipe image the form could not put on
// the server (offline, or the network failed) waits here, on the device,
// and goes up when the network is back, under the same retry rules as the
// sync queue (queue_retry_policy.dart, produktregler.md:185-192).
library;

import 'dart:math';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart'
    show decodeDependsOn;
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/unsent_image_discard.dart';
import 'package:butlery/services/offline/upload_completion.dart';

/// The upload statuses a pass picks up. "uploading" is only ever seen at the
/// start of a pass when an earlier run stopped mid-upload (passes do not
/// overlap), so it is tried again. "uploaded" is a row whose image is in
/// Storage and whose use of it is still to do.
const _sendableStatuses = liveUploadStatuses;

class UploadQueueProcessor {
  UploadQueueProcessor({
    required AppDatabase database,
    required OfflineUserStorage storage,
    required QueuedImageUploader upload,
    UploadedImageDeleter? deleteUploaded,
    Map<String, UploadCompletion> completions = const {},
    Future<void> Function(String userId)? ensureSession,
    Random? random,
  }) : _db = database,
       _ensureSession = ensureSession,
       _upload = upload,
       _deleteUploaded = deleteUploaded,
       _completions = {
         SyncQueueEntityType.recipe: RecipeImageCompletion(
           database: database,
           storage: storage,
         ),
         ...completions,
       },
       _random = random;

  final AppDatabase _db;
  final QueuedImageUploader _upload;
  final UploadedImageDeleter? _deleteUploaded;
  final Map<String, UploadCompletion> _completions;
  final Random? _random;

  /// Run before a row is sent: refreshes the sign-in so a write is not made
  /// on a token that outlived the account, and throws [SessionEnded] when the
  /// account can no longer write.
  final Future<void> Function(String userId)? _ensureSession;

  /// Whether [userId] has an upload the queue still sends.
  ///
  /// An image still in Storage for a row that no longer uses it counts too:
  /// taking it back is a pass's work.
  ///
  /// A photo that waited out its 30 days counts as well: a pass is what
  /// throws it away.
  Future<bool> hasPending(String userId) async =>
      (await _sendable(userId)).isNotEmpty ||
      (await _unusedUploads(userId)).isNotEmpty ||
      (await _expiredFailures(userId, clock.now())).isNotEmpty;

  /// Throws away what has waited for the user longer than
  /// [kUnsentImageKeep], whatever it belongs to: a cook-snap album goes whole,
  /// by the same path as the user's "Släng". Returns how many items went.
  ///
  /// The image a row had already put in Storage stays on the cancelled row
  /// until [_takeBackUnused] has taken it back, so a failed take-back is
  /// tried again by the next pass.
  Future<int> discardExpired(String userId, {required DateTime now}) =>
      discardExpiredUnsent(_db, userId, now);

  Future<List<UploadQueueEntry>> _expiredFailures(
    String userId,
    DateTime now,
  ) => expiredUnsentRows(_db, now, userId: userId);

  /// The earliest time an upload waiting for its retry may be tried again.
  Future<DateTime?> earliestRetry(String userId) async {
    DateTime? earliest;
    for (final row in await _sendable(userId)) {
      final next = row.nextAttemptAt;
      if (next != null && (earliest == null || next.isBefore(earliest))) {
        earliest = next;
      }
    }
    return earliest;
  }

  /// Tries every upload of [userId] whose dependencies have reached the
  /// server and whose retry time has come ([force] ignores the time).
  /// Returns how many reached the server.
  ///
  /// A row goes up in two steps. The image is put in Storage and the row
  /// becomes `uploaded`; then the handler for its entity type uses it. A
  /// failure of the second step retries only that step, so the image is
  /// never uploaded twice. For a recipe image the handler adds the address
  /// to the recipe's copy on the device, and that change is queued like any
  /// edit, so the recipe on the server gets it through the sync queue.
  ///
  /// The row is read again before the upload and before the second step: a
  /// row the user threw away meanwhile must not publish its image, and an
  /// image uploaded for such a row is taken back out of Storage.
  ///
  /// [isCurrentUser] is asked before each upload: once the account changes,
  /// the rest waits for that user's next pass.
  Future<int> runPass(
    String userId, {
    required DateTime now,
    required bool Function() isCurrentUser,
    bool force = false,
  }) async {
    try {
      await discardExpired(userId, now: now);
    } catch (e) {
      // A failed discard must not stall the sends; the next pass tries again.
      AppLogger.error(
        '❌ Gamla osända bilder kunde inte slängas: ${queueErrorCode(e)}',
      );
    }
    // No upload of this user is in flight at the start of a pass, so a row
    // cancelled mid-upload that never got an address can go.
    await _dropAbandoned(userId);
    await _takeBackUnused(userId);
    final ids = await _db.queuedOpIds(userId);
    var sent = 0;
    for (final listed in await _sendable(userId)) {
      if (!isCurrentUser()) break;
      final decision = decideQueueEntry(
        QueueEntryState(
          opId: listed.id,
          // Uploads are independent of each other.
          entityKey: 'upload:${listed.id}',
          dependsOn: decodeDependsOn(listed.dependsOn),
          nextAttemptAt: listed.nextAttemptAt,
        ),
        now: now,
        waiting: ids.waiting,
        failed: ids.failed,
        blockedEntities: const {},
        force: force,
      );
      switch (decision) {
        case QueueEntryDecision.dependencyFailed:
          await _db.markChainPermanentlyFailed(
            userId,
            listed.id,
            reason: QueuedChangeReason.dependencyFailed.code,
          );
          continue;
        case QueueEntryDecision.waits:
        case QueueEntryDecision.backoff:
          continue;
        case QueueEntryDecision.send:
      }

      var row = await _stillQueued(listed.id, userId);
      if (row == null) continue;

      try {
        await _ensureSession?.call(userId);
      } on SessionEnded {
        return sent;
      }
      // The refresh took time: the account may have changed meanwhile.
      if (!isCurrentUser()) break;

      if (row.status != 'uploaded') {
        await _db.uploadQueueDao.markUploading(row.id);
        final UploadedImage uploaded;
        try {
          uploaded = await _upload(row.localPath, userId, row.id);
        } catch (e) {
          AppLogger.error(
            '❌ Bilduppladdning misslyckades: ${queueErrorCode(e)}',
          );
          // A row thrown away meanwhile stays thrown away, and a refusal
          // that came from the account changing under the upload says
          // nothing about the row.
          if (await _stillQueued(row.id, userId) == null) continue;
          if (!isCurrentUser()) continue;
          await _recordFailure(row, userId, e, now, status: 'failed');
          continue;
        }
        final marked = await _db.uploadQueueDao.markUploaded(
          row.id,
          url: uploaded.url,
          thumbnailUrl: uploaded.thumbnailUrl,
        );
        if (!marked) {
          await _takeBack(row.id, uploaded);
          continue;
        }
        row = await _stillQueued(row.id, userId);
        if (row == null) continue;
      }

      final handler = row.entityType == null
          ? _completions[SyncQueueEntityType.recipe]
          : _completions[row.entityType];
      if (handler == null) {
        AppLogger.error('❌ Ingen hanterare för ${row.entityType}');
        await _recordFailure(
          row,
          userId,
          StateError('no handler'),
          now,
          status: 'uploaded',
          permanent: QueuedChangeReason.unknown,
        );
        continue;
      }
      try {
        switch (await handler.complete(row, userId)) {
          case CompletionOutcome.done:
            sent++;
          case CompletionOutcome.waitingForGroup:
          case CompletionOutcome.discarded:
            break;
          case CompletionOutcome.targetGone:
            await _takeBack(row.id, (
              url: row.uploadedUrl!,
              thumbnailUrl: row.uploadedThumbnailUrl,
            ), thenDropRow: true);
        }
      } on CompletionDeferred catch (deferred) {
        final rowId = row.id;
        await (_db.update(
          _db.uploadQueueEntries,
        )..where((e) => e.id.equals(rowId))).write(
          UploadQueueEntriesCompanion(
            nextAttemptAt: Value(now.add(deferred.wait)),
          ),
        );
      } catch (e) {
        AppLogger.error(
          '❌ Bilden kunde inte användas: ${queueErrorCode(e)}',
        );
        if (!isCurrentUser()) continue;
        await _recordFailure(row, userId, e, now, status: 'uploaded');
      }
    }
    // A discarded album leaves its bare cancelled photos behind while its last
    // row is still live; none is in flight now.
    await _dropAbandoned(userId);
    return sent;
  }

  Future<void> _dropAbandoned(String userId) async {
    try {
      await _db.uploadQueueDao.dropCancelledWithoutImage(userId);
    } catch (e) {
      AppLogger.error(
        '❌ Avbrutna bilder kunde inte rensas: ${queueErrorCode(e)}',
      );
    }
  }

  /// The row as it is now, or null when it is gone, thrown away, waiting for
  /// the user, or not this user's.
  Future<UploadQueueEntry?> _stillQueued(String id, String userId) async {
    final row = await _db.uploadQueueDao.getUpload(id);
    return uploadRowIsLive(row, userId) ? row : null;
  }

  /// Rows that hold the address of an image in Storage they no longer use:
  /// thrown away, or waiting for the user after the image was taken back
  /// and the take-back failed.
  Future<List<UploadQueueEntry>> _unusedUploads(String userId) {
    return (_db.select(_db.uploadQueueEntries)..where(
          (e) =>
              e.userId.equals(userId) &
              e.uploadedUrl.isNotNull() &
              (e.status.equals('cancelled') | e.permanentlyFailed.equals(true)),
        ))
        .get();
  }

  Future<void> _takeBackUnused(String userId) async {
    for (final row in await _unusedUploads(userId)) {
      await _takeBack(row.id, (
        url: row.uploadedUrl!,
        thumbnailUrl: row.uploadedThumbnailUrl,
      ));
    }
  }

  /// Takes every image [userId]'s rows still hold in Storage back out, for a
  /// clear of the user's data: the rows go right after, so a failed
  /// take-back is not retried.
  Future<void> takeBackAllUploaded(String userId) async {
    final rows =
        await (_db.select(_db.uploadQueueEntries)..where(
              (e) => e.userId.equals(userId) & e.uploadedUrl.isNotNull(),
            ))
            .get();
    for (final row in rows) {
      await _takeBack(row.id, (
        url: row.uploadedUrl!,
        thumbnailUrl: row.uploadedThumbnailUrl,
      ));
    }
  }

  /// Takes [image] out of Storage. When it cannot be, its address is kept on
  /// the row [rowId] so a later pass tries again; with [thenDropRow] the row
  /// goes once the image is gone. True when the image is gone.
  Future<bool> _takeBack(
    String rowId,
    UploadedImage image, {
    bool thenDropRow = false,
  }) async {
    var gone = false;
    try {
      gone = await _deleteUploaded?.call(image) ?? false;
    } catch (e) {
      AppLogger.error(
        '❌ Uppladdad bild kunde inte tas tillbaka: ${queueErrorCode(e)}',
      );
    }
    if (!gone) {
      await _db.uploadQueueDao.rememberUploaded(
        rowId,
        url: image.url,
        thumbnailUrl: image.thumbnailUrl,
      );
      if (thenDropRow) await _db.uploadQueueDao.cancelUpload(rowId);
      return false;
    }
    if (thenDropRow) {
      await _db.uploadQueueDao.markCompleted(rowId);
    } else {
      await _forgetUploaded(rowId);
    }
    return true;
  }

  /// The image of [rowId] is gone from Storage. A row that was waiting to be
  /// used goes back to `failed`, so a retry by the user uploads it again.
  Future<void> _forgetUploaded(String rowId) async {
    final row = await _db.uploadQueueDao.getUpload(rowId);
    if (row == null) return;
    await (_db.update(
      _db.uploadQueueEntries,
    )..where((e) => e.id.equals(rowId))).write(
      UploadQueueEntriesCompanion(
        status: Value(row.status == 'uploaded' ? 'failed' : row.status),
        uploadedUrl: const Value(null),
        uploadedThumbnailUrl: const Value(null),
      ),
    );
    // A thrown-away row whose image is gone has nothing left to keep.
    await _db.uploadQueueDao.dropIfBare(rowId, uploadFinished: true);
  }

  Future<List<UploadQueueEntry>> _sendable(String userId) {
    return (_db.select(_db.uploadQueueEntries)
          ..where(
            (e) =>
                e.userId.equals(userId) &
                e.status.isIn(_sendableStatuses) &
                e.permanentlyFailed.equals(false),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.queuedAt)]))
        .get();
  }

  /// [status] is where the row rests while it waits for its retry: `failed`
  /// before the image is up, `uploaded` after, so a retry of the second step
  /// does not upload again.
  Future<void> _recordFailure(
    UploadQueueEntry row,
    String userId,
    Object error,
    DateTime now, {
    required String status,
    QueuedChangeReason? permanent,
  }) async {
    permanent ??= permanentFailureReason(error);
    final firstFailedAt = row.firstFailedAt ?? now;
    if (permanent != null || queueRetriesExhausted(firstFailedAt, now)) {
      // The image is never used from here, so it does not stay in Storage; a
      // retry by the user uploads it again.
      final url = row.uploadedUrl;
      if (url != null) {
        await _takeBack(row.id, (
          url: url,
          thumbnailUrl: row.uploadedThumbnailUrl,
        ));
      } else {
        await (_db.update(_db.uploadQueueEntries)
              ..where((e) => e.id.equals(row.id)))
            .write(UploadQueueEntriesCompanion(status: Value(status)));
      }
      await _db.markChainPermanentlyFailed(
        userId,
        row.id,
        reason: QueuedChangeReason.dependencyFailed.code,
        rootReason: (permanent ?? QueuedChangeReason.retriesExhausted).code,
      );
      return;
    }
    final failures = row.retryCount + 1;
    await (_db.update(
      _db.uploadQueueEntries,
    )..where((e) => e.id.equals(row.id))).write(
      UploadQueueEntriesCompanion(
        status: Value(status),
        retryCount: Value(failures),
        lastError: Value(queueErrorCode(error)),
        nextAttemptAt: Value(
          now.add(queueRetryDelay(failures, random: _random)),
        ),
        firstFailedAt: Value(firstFailedAt),
      ),
    );
  }
}
