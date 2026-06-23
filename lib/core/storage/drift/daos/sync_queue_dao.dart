import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';

part 'sync_queue_dao.g.dart';

/// Data Access Object for sync queue management
@DriftAccessor(tables: [SyncQueueEntries])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Get all pending sync operations for a user
  Future<List<SyncQueueEntry>> getPendingForUser(String userId) {
    return (select(syncQueueEntries)
          ..where((e) => e.userId.equals(userId))
          ..orderBy([(e) => OrderingTerm.asc(e.queuedAt)]))
        .get();
  }

  /// Check if there are pending operations for a user
  Future<bool> hasPending(String userId) async {
    final count = countAll();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([count])
      ..where(syncQueueEntries.userId.equals(userId));
    final result = await query.getSingle();
    return (result.read(count) ?? 0) > 0;
  }

  /// Count pending operations for a user
  Future<int> countPending(String userId) async {
    final count = countAll();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([count])
      ..where(syncQueueEntries.userId.equals(userId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Add an operation to the queue
  Future<void> enqueue({
    required String userId,
    required String recipeId,
    required SyncOperation operation,
  }) {
    return into(syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        userId: userId,
        recipeId: recipeId,
        operation: operation.name,
        queuedAt: clock.now(),
      ),
    );
  }

  /// Remove a completed operation from the queue
  Future<void> dequeue(int id) {
    return (delete(syncQueueEntries)..where((e) => e.id.equals(id))).go();
  }

  /// Remove all operations for a specific recipe
  Future<void> removeForRecipe(String userId, String recipeId) {
    return (delete(syncQueueEntries)
          ..where((e) => e.userId.equals(userId) & e.recipeId.equals(recipeId)))
        .go();
  }

  /// Increment retry count and record error
  Future<void> recordFailure(int id, String errorMessage) async {
    // Get current entry to increment retry count
    final entry = await (select(
      syncQueueEntries,
    )..where((e) => e.id.equals(id))).getSingleOrNull();

    if (entry != null) {
      await (update(syncQueueEntries)..where((e) => e.id.equals(id))).write(
        SyncQueueEntriesCompanion(
          retryCount: Value(entry.retryCount + 1),
          lastError: Value(errorMessage),
        ),
      );
    }
  }

  /// Get operations that have failed too many times
  Future<List<SyncQueueEntry>> getFailedOperations(
    String userId,
    int maxRetries,
  ) {
    return (select(syncQueueEntries)..where(
          (e) =>
              e.userId.equals(userId) &
              e.retryCount.isBiggerThanValue(maxRetries),
        ))
        .get();
  }

  /// Clear all pending operations for a user
  Future<void> clearForUser(String userId) {
    return (delete(
      syncQueueEntries,
    )..where((e) => e.userId.equals(userId))).go();
  }

  /// Watch pending count for a user (reactive)
  Stream<int> watchPendingCount(String userId) {
    final count = countAll();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([count])
      ..where(syncQueueEntries.userId.equals(userId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }
}
