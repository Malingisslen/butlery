import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart'
    show encodeDependsOn;
import 'package:butlery/core/storage/drift/tables/sync_queue.dart'
    show SyncQueueEntityType;
import 'package:butlery/core/storage/drift/tables/upload_queue.dart';

part 'upload_queue_dao.g.dart';

/// Data Access Object for upload queue management.
/// Provides persistence for image uploads to survive app restarts
/// and ensure uploads resume on network reconnection.
@DriftAccessor(tables: [UploadQueueEntries])
class UploadQueueDao extends DatabaseAccessor<AppDatabase>
    with _$UploadQueueDaoMixin {
  UploadQueueDao(super.db);

  /// Queue a new upload
  Future<void> queueUpload({
    required String id,
    required String userId,
    required String localPath,
    required String targetPath,
    required int fileSizeBytes,
    String contentType = 'image/jpeg',
    String? entityId,
    String? entityType,
    String? metadata,
    List<String> dependsOn = const [],
  }) {
    return into(uploadQueueEntries).insert(
      UploadQueueEntriesCompanion.insert(
        id: id,
        userId: userId,
        localPath: localPath,
        targetPath: targetPath,
        contentType: Value(contentType),
        fileSizeBytes: fileSizeBytes,
        queuedAt: clock.now(),
        entityId: Value(entityId),
        entityType: Value(entityType),
        metadata: Value(metadata),
        dependsOn: Value(encodeDependsOn(dependsOn)),
      ),
    );
  }

  /// Get all pending uploads for a user
  Future<List<UploadQueueEntry>> getPendingUploads(String userId) {
    return (select(uploadQueueEntries)
          ..where(
            (e) =>
                e.userId.equals(userId) &
                e.status.equals('pending') &
                e.permanentlyFailed.equals(false),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.queuedAt)]))
        .get();
  }

  /// Get all uploads that need retry (failed but under max retries)
  Future<List<UploadQueueEntry>> getRetryableUploads(
    String userId,
    int maxRetries,
  ) {
    return (select(uploadQueueEntries)
          ..where(
            (e) =>
                e.userId.equals(userId) &
                e.status.equals('failed') &
                e.permanentlyFailed.equals(false) &
                e.retryCount.isSmallerThanValue(maxRetries),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.queuedAt)]))
        .get();
  }

  /// Check if there are pending uploads for a user
  Future<bool> hasPendingUploads(String userId) async {
    final count = countAll();
    final query = selectOnly(uploadQueueEntries)
      ..addColumns([count])
      ..where(
        uploadQueueEntries.userId.equals(userId) &
            uploadQueueEntries.permanentlyFailed.equals(false) &
            (uploadQueueEntries.status.equals('pending') |
                uploadQueueEntries.status.equals('uploaded') |
                uploadQueueEntries.status.equals('failed')),
      );
    final result = await query.getSingle();
    return (result.read(count) ?? 0) > 0;
  }

  /// Count pending uploads for a user
  Future<int> countPendingUploads(String userId) async {
    final count = countAll();
    final query = selectOnly(uploadQueueEntries)
      ..addColumns([count])
      ..where(
        uploadQueueEntries.userId.equals(userId) &
            uploadQueueEntries.permanentlyFailed.equals(false) &
            (uploadQueueEntries.status.equals('pending') |
                uploadQueueEntries.status.equals('uploaded') |
                uploadQueueEntries.status.equals('failed')),
      );
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Mark upload as in progress
  Future<void> markUploading(String id) {
    return (update(uploadQueueEntries)..where((e) => e.id.equals(id))).write(
      UploadQueueEntriesCompanion(
        status: const Value('uploading'),
        lastAttemptAt: Value(clock.now()),
      ),
    );
  }

  /// Records that the object is in Storage and the entity it belongs to is
  /// not yet written, so a retry of the completion does not upload again.
  /// The retry schedule starts over: earlier failures were the upload's.
  ///
  /// Writes nothing, and returns false, for a row that was thrown away or
  /// removed while the image went up. The check and the write are one
  /// statement, so a discard cannot land between them and be undone.
  Future<bool> markUploaded(
    String id, {
    required String url,
    String? thumbnailUrl,
  }) async {
    final written =
        await (update(uploadQueueEntries)..where(
              (e) => e.id.equals(id) & e.status.isNotIn(['cancelled']),
            ))
            .write(
              UploadQueueEntriesCompanion(
                status: const Value('uploaded'),
                uploadedUrl: Value(url),
                uploadedThumbnailUrl: Value(thumbnailUrl),
                retryCount: const Value(0),
                lastError: const Value(null),
                nextAttemptAt: const Value(null),
                firstFailedAt: const Value(null),
              ),
            );
    if (written > 0) _cancelledInFlight.remove(id);
    return written > 0;
  }

  /// Keeps the address of an uploaded image on a row that no longer uses it,
  /// so the queue can still take the image out of Storage later.
  Future<void> rememberUploaded(
    String id, {
    required String url,
    String? thumbnailUrl,
  }) {
    return (update(uploadQueueEntries)..where((e) => e.id.equals(id))).write(
      UploadQueueEntriesCompanion(
        uploadedUrl: Value(url),
        uploadedThumbnailUrl: Value(thumbnailUrl),
      ),
    );
  }

  /// Mark upload as completed and remove from queue
  Future<void> markCompleted(String id) {
    return (delete(uploadQueueEntries)..where((e) => e.id.equals(id))).go();
  }

  /// Record a failure and increment retry count
  Future<void> recordFailure(String id, String errorMessage) async {
    final entry = await (select(
      uploadQueueEntries,
    )..where((e) => e.id.equals(id))).getSingleOrNull();

    if (entry != null) {
      await (update(uploadQueueEntries)..where((e) => e.id.equals(id))).write(
        UploadQueueEntriesCompanion(
          status: const Value('failed'),
          retryCount: Value(entry.retryCount + 1),
          lastError: Value(errorMessage),
          lastAttemptAt: Value(clock.now()),
        ),
      );
    }
  }

  /// Marks an upload as a permanent failure. It stays in the queue for the
  /// user to decide on (produktregler.md:189, :192). Returns whether an
  /// upload was marked.
  Future<bool> markPermanentlyFailed(String id, {String? reason}) async {
    final written =
        await (update(
          uploadQueueEntries,
        )..where((e) => e.id.equals(id))).write(
          UploadQueueEntriesCompanion(
            permanentlyFailed: const Value(true),
            lastError: reason == null ? const Value.absent() : Value(reason),
          ),
        );
    return written > 0;
  }

  /// Reset failed upload back to pending for retry
  Future<void> resetForRetry(String id) {
    return (update(uploadQueueEntries)..where((e) => e.id.equals(id))).write(
      const UploadQueueEntriesCompanion(
        status: Value('pending'),
      ),
    );
  }

  /// Rows cancelled while their upload was in flight. Afterwards they look
  /// like any cancelled row, but the upload still needs them to record where
  /// the image landed. Memory is enough: an upload cannot outlive the process.
  final Set<String> _cancelledInFlight = {};

  /// Cancel an upload. A row that holds no address in Storage goes with it
  /// ([dropIfBare]), so a thrown-away photo leaves no caption, recipe name or
  /// author behind. A row mid-upload stays: the upload in flight still needs
  /// it to record where the image landed.
  Future<void> cancelUpload(String id) => transaction(() async {
    final before = await getUpload(id);
    await (update(uploadQueueEntries)..where((e) => e.id.equals(id))).write(
      const UploadQueueEntriesCompanion(
        status: Value('cancelled'),
        // Caption, recipe name and the recipe author's uid are of no use to a
        // row that is only waiting for its Storage take-back.
        metadata: Value(null),
      ),
    );
    if (before == null) return;
    if (before.status == 'uploading') {
      _cancelledInFlight.add(id);
    } else {
      await dropIfBare(id);
    }
  });

  /// Deletes the cancelled row [id] when it holds no address in Storage. A
  /// cancelled photo of a cook-snap album or a comment is what tells its
  /// still-live siblings that the group is dead, so it stays while one of them
  /// is live; once none is, the group's other bare cancelled rows go with it.
  Future<void> dropIfBare(String id, {bool uploadFinished = false}) async {
    if (uploadFinished) _cancelledInFlight.remove(id);
    final row = await getUpload(id);
    if (row == null || row.status != 'cancelled' || row.uploadedUrl != null) {
      return;
    }
    final groupId = row.entityId;
    if (!SyncQueueEntityType.grouped.contains(row.entityType) ||
        groupId == null) {
      await markCompleted(id);
      return;
    }
    final group = await getGroup(row.userId, row.entityType!, groupId);
    if (group.any((r) => r.status != 'cancelled' && r.status != 'completed')) {
      return;
    }
    await (delete(uploadQueueEntries)..where(
          (e) =>
              e.uploadedUrl.isNull() &
              e.id.isIn([
                for (final r in group)
                  if (r.status == 'cancelled' &&
                      r.uploadedUrl == null &&
                      !_cancelledInFlight.contains(r.id))
                    r.id,
              ]),
        ))
        .go();
  }

  /// [dropIfBare] for every cancelled row of [userId], or of every user when
  /// it is null. For rows cancelled while their upload was in flight, which
  /// [cancelUpload] had to leave; only called when no upload is in flight.
  Future<void> dropCancelledWithoutImage([String? userId]) async {
    _cancelledInFlight.clear();
    final query = select(uploadQueueEntries)
      ..where((e) => e.status.equals('cancelled') & e.uploadedUrl.isNull());
    if (userId != null) query.where((e) => e.userId.equals(userId));
    final rows = await query.get();
    for (final row in rows) {
      await dropIfBare(row.id);
    }
  }

  /// Remove completed and cancelled uploads older than given duration
  Future<void> cleanupOldEntries(Duration olderThan) {
    final cutoff = clock.now().subtract(olderThan);
    return (delete(uploadQueueEntries)..where(
          (e) =>
              (e.status.equals('completed') | e.status.equals('cancelled')) &
              e.queuedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  /// Get upload by ID
  Future<UploadQueueEntry?> getUpload(String id) {
    return (select(
      uploadQueueEntries,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  /// Clear all uploads for a user
  Future<void> clearForUser(String userId) {
    return (delete(
      uploadQueueEntries,
    )..where((e) => e.userId.equals(userId))).go();
  }

  /// Watch pending count for a user (reactive)
  Stream<int> watchPendingCount(String userId) {
    final count = countAll();
    final query = selectOnly(uploadQueueEntries)
      ..addColumns([count])
      ..where(
        uploadQueueEntries.userId.equals(userId) &
            uploadQueueEntries.permanentlyFailed.equals(false) &
            (uploadQueueEntries.status.equals('pending') |
                uploadQueueEntries.status.equals('uploaded') |
                uploadQueueEntries.status.equals('failed')),
      );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Get all uploads for an entity (e.g., recipe)
  Future<List<UploadQueueEntry>> getUploadsForEntity(
    String entityId,
    String entityType,
  ) {
    return (select(uploadQueueEntries)..where(
          (e) => e.entityId.equals(entityId) & e.entityType.equals(entityType),
        ))
        .get();
  }

  /// The rows of one entity in the order they were queued, so a completion
  /// that needs every row of a group (a cook snap's photos) reads them in
  /// one place.
  Future<List<UploadQueueEntry>> getGroup(
    String userId,
    String entityType,
    String entityId,
  ) {
    return (select(uploadQueueEntries)
          ..where(
            (e) =>
                e.userId.equals(userId) &
                e.entityType.equals(entityType) &
                e.entityId.equals(entityId),
          )
          ..orderBy([
            (e) => OrderingTerm.asc(e.queuedAt),
            (e) => OrderingTerm.asc(e.id),
          ]))
        .get();
  }

  /// Throws away every unfinished row of [entityType] of [userId], one that
  /// waits for the user included, and returns the device copies they held. The
  /// caller removes the files once its transaction has committed.
  Future<List<String>> cancelWaiting(String userId, String entityType) =>
      transaction(() async {
        final rows =
            await (select(uploadQueueEntries)..where(
                  (e) =>
                      e.userId.equals(userId) &
                      e.entityType.equals(entityType) &
                      e.status.isNotIn(const ['completed', 'cancelled']),
                ))
                .get();
        for (final row in rows) {
          await cancelUpload(row.id);
        }
        return [for (final row in rows) row.localPath];
      });

  /// Whether [userId] has any unsent group of [entityType] (a comment's
  /// photos), however far it has come. A group that is thrown away or whose
  /// record is complete no longer counts.
  Future<bool> hasLiveGroup(String userId, String entityType) async {
    final row =
        await (select(uploadQueueEntries)
              ..where(
                (e) =>
                    e.userId.equals(userId) &
                    e.entityType.equals(entityType) &
                    e.status.isNotIn(const ['completed', 'cancelled']),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Remove all uploads for an entity
  Future<void> removeUploadsForEntity(String entityId, String entityType) {
    return (delete(uploadQueueEntries)..where(
          (e) => e.entityId.equals(entityId) & e.entityType.equals(entityType),
        ))
        .go();
  }
}
