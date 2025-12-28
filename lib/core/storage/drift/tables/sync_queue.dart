import 'package:drift/drift.dart';

/// Sync operation types
enum SyncOperation {
  create,
  update,
  delete,

  /// Tag a recipe (generate tags when online)
  tag,
}

/// Table for tracking pending sync operations (replaces Hive sync_queue box)
class SyncQueueEntries extends Table {
  /// Auto-incrementing ID
  IntColumn get id => integer().autoIncrement()();

  /// User ID for data isolation
  TextColumn get userId => text()();

  /// Recipe ID to sync
  TextColumn get recipeId => text()();

  /// Type of operation: create, update, delete
  TextColumn get operation => text()();

  /// When the operation was queued
  DateTimeColumn get queuedAt => dateTime()();

  /// Number of sync retry attempts
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Last error message if sync failed
  TextColumn get lastError => text().nullable()();
}
