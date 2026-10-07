// lib/services/offline/upload_queue_processor.dart
//
// BUT-2162: sends the upload queue. A recipe image the form could not put on
// the server (offline, or the network failed) waits here, on the device,
// and goes up when the network is back, under the same retry rules as the
// sync queue (queue_retry_policy.dart, produktregler.md:185-192).
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart'
    show decodeDependsOn;
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/queued_change.dart';

/// The upload statuses a pass picks up. "uploading" is only ever seen at the
/// start of a pass when an earlier run stopped mid-upload (passes do not
/// overlap), so it is tried again.
const _sendableStatuses = ['pending', 'uploading', 'failed'];

class UploadQueueProcessor {
  UploadQueueProcessor({
    required AppDatabase database,
    required OfflineUserStorage storage,
    required QueuedImageUploader upload,
    Random? random,
  }) : _db = database,
       _storage = storage,
       _upload = upload,
       _random = random;

  final AppDatabase _db;
  final OfflineUserStorage _storage;
  final QueuedImageUploader _upload;
  final Random? _random;

  /// Whether [userId] has an upload the queue still sends.
  Future<bool> hasPending(String userId) async =>
      (await _sendable(userId)).isNotEmpty;

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
  /// An image that reaches the server is added to its recipe's copy on the
  /// device, and that change is queued like any edit, so the recipe on the
  /// server gets the image's address through the sync queue.
  ///
  /// [isCurrentUser] is asked before each upload: once the account changes,
  /// the rest waits for that user's next pass.
  Future<int> runPass(
    String userId, {
    required DateTime now,
    required bool Function() isCurrentUser,
    bool force = false,
  }) async {
    final ids = await _db.queuedOpIds(userId);
    var sent = 0;
    for (final row in await _sendable(userId)) {
      if (!isCurrentUser()) break;
      final decision = decideQueueEntry(
        QueueEntryState(
          opId: row.id,
          // Uploads are independent of each other.
          entityKey: 'upload:${row.id}',
          dependsOn: decodeDependsOn(row.dependsOn),
          nextAttemptAt: row.nextAttemptAt,
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
            row.id,
            reason: QueuedChangeReason.dependencyFailed.code,
          );
          continue;
        case QueueEntryDecision.waits:
        case QueueEntryDecision.backoff:
          continue;
        case QueueEntryDecision.send:
      }

      await _db.uploadQueueDao.markUploading(row.id);
      final UploadedImage uploaded;
      try {
        uploaded = await _upload(row.localPath, userId);
      } catch (e) {
        AppLogger.error('❌ Bilduppladdning misslyckades: ${queueErrorCode(e)}');
        await _recordFailure(row, userId, e, now);
        continue;
      }
      try {
        await _complete(row, userId, uploaded);
      } catch (e) {
        // The image is up; sending it again would only add a copy. The
        // upload waits for the user instead of retrying.
        AppLogger.error(
          '❌ Bildens adress kunde inte läggas i receptet: ${queueErrorCode(e)}',
        );
        await _db.markChainPermanentlyFailed(
          userId,
          row.id,
          reason: QueuedChangeReason.dependencyFailed.code,
          rootReason: queueErrorCode(e),
        );
        continue;
      }
      sent++;
    }
    return sent;
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

  Future<void> _recordFailure(
    UploadQueueEntry row,
    String userId,
    Object error,
    DateTime now,
  ) async {
    final permanent = permanentFailureReason(error);
    final firstFailedAt = row.firstFailedAt ?? now;
    if (permanent != null || queueRetriesExhausted(firstFailedAt, now)) {
      await (_db.update(_db.uploadQueueEntries)
            ..where((e) => e.id.equals(row.id)))
          .write(const UploadQueueEntriesCompanion(status: Value('failed')));
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
        status: const Value('failed'),
        retryCount: Value(failures),
        lastError: Value(queueErrorCode(error)),
        nextAttemptAt: Value(
          now.add(queueRetryDelay(failures, random: _random)),
        ),
        firstFailedAt: Value(firstFailedAt),
      ),
    );
  }

  /// The image is on the server: its address goes into the recipe on the
  /// device and into the sync queue, and the upload and its file on the
  /// device are done with. One transaction, so a restart never leaves the
  /// upload gone without the address queued.
  Future<void> _complete(
    UploadQueueEntry row,
    String userId,
    UploadedImage uploaded,
  ) async {
    await _db.transaction(() async {
      final recipeId = row.entityType == SyncQueueEntityType.recipe
          ? row.entityId
          : null;
      final stored = recipeId == null
          ? null
          : await _db.recipeDao.getRecipe(recipeId, userId);
      if (stored == null) {
        AppLogger.warning(
          '⚠️ Receptet finns inte på enheten; bilden läggs inte till',
        );
      } else {
        final recipe = Recipe.fromJson(
          jsonDecode(stored.recipeJson) as Map<String, dynamic>,
        );
        if (!recipe.imageUrls.contains(uploaded.url)) {
          recipe.core
            ..imageUrls = [...recipe.imageUrls, uploaded.url]
            ..thumbnailUrl ??= uploaded.thumbnailUrl;
          await _storage.saveRecipeForUser(
            recipe,
            userId,
            queueTagging: false,
          );
        }
      }
      await _db.uploadQueueDao.markCompleted(row.id);
    });
    await _storage.deleteUploadFile(row.localPath);
  }
}
