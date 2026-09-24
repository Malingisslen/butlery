import 'dart:convert';

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

  /// The user's entries that the queue still sends by itself: everything
  /// except the permanent failures, which wait for the user
  /// (produktregler.md:189).
  Expression<bool> _drainingFor(
    $SyncQueueEntriesTable e,
    String userId,
  ) => e.userId.equals(userId) & e.permanentlyFailed.equals(false);

  /// Get all pending sync operations for a user, oldest first. Permanent
  /// failures are left out: they are never retried (produktregler.md:189).
  Future<List<SyncQueueEntry>> getPendingForUser(String userId) {
    return (select(syncQueueEntries)
          ..where((e) => _drainingFor(e, userId))
          ..orderBy([(e) => OrderingTerm.asc(e.queuedAt)]))
        .get();
  }

  /// Check if there are pending operations for a user
  Future<bool> hasPending(String userId) async {
    return await countPending(userId) > 0;
  }

  /// Count pending operations for a user (permanent failures excluded)
  Future<int> countPending(String userId) async {
    final count = countAll();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([count])
      ..where(_drainingFor(syncQueueEntries, userId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Add an operation to the queue.
  ///
  /// [opId] is the operation's idempotency key (produktregler.md:185). Pass
  /// one when a later entry must name this one in its [dependsOn]; otherwise
  /// a UUID v4 is created here. [dependsOn] lists the opIds this entry waits
  /// for (produktregler.md:187).
  Future<void> enqueue({
    required String userId,
    required String recipeId,
    required SyncOperation operation,
    String entityType = SyncQueueEntityType.recipe,
    String? opId,
    List<String> dependsOn = const [],
  }) {
    return into(syncQueueEntries).insert(
      SyncQueueEntriesCompanion.insert(
        userId: userId,
        recipeId: recipeId,
        operation: operation.name,
        queuedAt: clock.now(),
        entityType: Value(entityType),
        opId: opId == null ? const Value.absent() : Value(opId),
        dependsOn: Value(encodeDependsOn(dependsOn)),
      ),
    );
  }

  /// The opIds [entry] waits for.
  static List<String> dependsOnOf(SyncQueueEntry entry) =>
      decodeDependsOn(entry.dependsOn);

  /// Marks one entry as a permanent failure, keeping it in the queue for the
  /// user (produktregler.md:189, :192). [reason] is stored as the last error.
  /// Returns whether an entry was marked.
  Future<bool> markPermanentlyFailed(String opId, {String? reason}) async {
    final written =
        await (update(
          syncQueueEntries,
        )..where((e) => e.opId.equals(opId))).write(
          SyncQueueEntriesCompanion(
            permanentlyFailed: const Value(true),
            lastError: reason == null ? const Value.absent() : Value(reason),
          ),
        );
    return written > 0;
  }

  /// The user's permanent failures, oldest first — "de permanenta felen
  /// först" in the queue view (produktregler.md:191).
  Future<List<SyncQueueEntry>> getPermanentFailures(String userId) {
    return (select(syncQueueEntries)
          ..where(
            (e) => e.userId.equals(userId) & e.permanentlyFailed.equals(true),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.queuedAt)]))
        .get();
  }

  /// Watch how many of the user's entries wait for her (permanent failures).
  Stream<int> watchPermanentFailureCount(String userId) {
    final count = countAll();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([count])
      ..where(
        syncQueueEntries.userId.equals(userId) &
            syncQueueEntries.permanentlyFailed.equals(true),
      );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
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

  /// Watch pending count for a user (reactive, permanent failures excluded)
  Stream<int> watchPendingCount(String userId) {
    final count = countAll();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([count])
      ..where(_drainingFor(syncQueueEntries, userId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }
}

/// Encodes a dependsOn list for storage: null when empty, else a JSON array.
String? encodeDependsOn(List<String> opIds) =>
    opIds.isEmpty ? null : jsonEncode(opIds);

/// Decodes a stored dependsOn value. A value that is not a JSON array of
/// strings reads as no dependencies.
List<String> decodeDependsOn(String? stored) {
  if (stored == null || stored.isEmpty) return const [];
  try {
    final decoded = jsonDecode(stored);
    if (decoded is List) return decoded.whereType<String>().toList();
  } on FormatException {
    return const [];
  }
  return const [];
}
