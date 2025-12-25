import 'package:drift/drift.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
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
  }) {
    return into(uploadQueueEntries).insert(
      UploadQueueEntriesCompanion.insert(
        id: id,
        userId: userId,
        localPath: localPath,
        targetPath: targetPath,
        contentType: Value(contentType),
        fileSizeBytes: fileSizeBytes,
        queuedAt: DateTime.now(),
        entityId: Value(entityId),
        entityType: Value(entityType),
        metadata: Value(metadata),
      ),
    );
  }

  /// Get all pending uploads for a user
  Future<List<UploadQueueEntry>> getPendingUploads(String userId) {
    return (select(uploadQueueEntries)
          ..where((e) => e.userId.equals(userId) & e.status.equals('pending'))
          ..orderBy([(e) => OrderingTerm.asc(e.queuedAt)]))
        .get();
  }

  /// Get all uploads that need retry (failed but under max retries)
  Future<List<UploadQueueEntry>> getRetryableUploads(
      String userId, int maxRetries) {
    return (select(uploadQueueEntries)
          ..where((e) =>
              e.userId.equals(userId) &
              e.status.equals('failed') &
              e.retryCount.isSmallerThanValue(maxRetries))
          ..orderBy([(e) => OrderingTerm.asc(e.queuedAt)]))
        .get();
  }

  /// Check if there are pending uploads for a user
  Future<bool> hasPendingUploads(String userId) async {
    final count = countAll();
    final query = selectOnly(uploadQueueEntries)
      ..addColumns([count])
      ..where(uploadQueueEntries.userId.equals(userId) &
          (uploadQueueEntries.status.equals('pending') |
              uploadQueueEntries.status.equals('failed')));
    final result = await query.getSingle();
    return (result.read(count) ?? 0) > 0;
  }

  /// Count pending uploads for a user
  Future<int> countPendingUploads(String userId) async {
    final count = countAll();
    final query = selectOnly(uploadQueueEntries)
      ..addColumns([count])
      ..where(uploadQueueEntries.userId.equals(userId) &
          (uploadQueueEntries.status.equals('pending') |
              uploadQueueEntries.status.equals('failed')));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Mark upload as in progress
  Future<void> markUploading(String id) {
    return (update(uploadQueueEntries)..where((e) => e.id.equals(id))).write(
      UploadQueueEntriesCompanion(
        status: const Value('uploading'),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark upload as completed and remove from queue
  Future<void> markCompleted(String id) {
    return (delete(uploadQueueEntries)..where((e) => e.id.equals(id))).go();
  }

  /// Record a failure and increment retry count
  Future<void> recordFailure(String id, String errorMessage) async {
    final entry = await (select(uploadQueueEntries)
          ..where((e) => e.id.equals(id)))
        .getSingleOrNull();

    if (entry != null) {
      await (update(uploadQueueEntries)..where((e) => e.id.equals(id))).write(
        UploadQueueEntriesCompanion(
          status: const Value('failed'),
          retryCount: Value(entry.retryCount + 1),
          lastError: Value(errorMessage),
          lastAttemptAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Reset failed upload back to pending for retry
  Future<void> resetForRetry(String id) {
    return (update(uploadQueueEntries)..where((e) => e.id.equals(id))).write(
      const UploadQueueEntriesCompanion(
        status: Value('pending'),
      ),
    );
  }

  /// Cancel an upload
  Future<void> cancelUpload(String id) {
    return (update(uploadQueueEntries)..where((e) => e.id.equals(id))).write(
      const UploadQueueEntriesCompanion(
        status: Value('cancelled'),
      ),
    );
  }

  /// Remove completed and cancelled uploads older than given duration
  Future<void> cleanupOldEntries(Duration olderThan) {
    final cutoff = DateTime.now().subtract(olderThan);
    return (delete(uploadQueueEntries)
          ..where((e) =>
              (e.status.equals('completed') | e.status.equals('cancelled')) &
              e.queuedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Get upload by ID
  Future<UploadQueueEntry?> getUpload(String id) {
    return (select(uploadQueueEntries)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
  }

  /// Clear all uploads for a user
  Future<void> clearForUser(String userId) {
    return (delete(uploadQueueEntries)..where((e) => e.userId.equals(userId)))
        .go();
  }

  /// Watch pending count for a user (reactive)
  Stream<int> watchPendingCount(String userId) {
    final count = countAll();
    final query = selectOnly(uploadQueueEntries)
      ..addColumns([count])
      ..where(uploadQueueEntries.userId.equals(userId) &
          (uploadQueueEntries.status.equals('pending') |
              uploadQueueEntries.status.equals('failed')));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Get all uploads for an entity (e.g., recipe)
  Future<List<UploadQueueEntry>> getUploadsForEntity(
      String entityId, String entityType) {
    return (select(uploadQueueEntries)
          ..where((e) =>
              e.entityId.equals(entityId) & e.entityType.equals(entityType)))
        .get();
  }

  /// Remove all uploads for an entity
  Future<void> removeUploadsForEntity(String entityId, String entityType) {
    return (delete(uploadQueueEntries)
          ..where((e) =>
              e.entityId.equals(entityId) & e.entityType.equals(entityType)))
        .go();
  }
}
