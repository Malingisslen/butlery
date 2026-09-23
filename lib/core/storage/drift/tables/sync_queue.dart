import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

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

  // ── Schema 3 (produktregler.md:183-193, § 3.1) ─────────────────────────

  /// The operation's idempotency key. "Varje köpost bär `opId`. Servern
  /// förkastar dubbletter" (produktregler.md:185). Created on the device
  /// when the entry is queued and never reused, so a retry after a crash
  /// mid-send is safe. Rows queued before schema 3 get a random 128-bit id
  /// in the migration (app_database.dart).
  TextColumn get opId =>
      text().clientDefault(() => const Uuid().v4()).unique()();

  /// What kind of entity the operation writes to ("recipe" for every row
  /// queued before schema 3, since the queue then only carried recipes).
  /// Ordering is FIFO per entity (produktregler.md:186), so the pair
  /// ([entityType], [recipeId]) is the entity.
  TextColumn get entityType =>
      text().withDefault(const Constant(SyncQueueEntityType.recipe))();

  /// JSON array of the opIds this entry waits for, or null. "En post kan
  /// deklarera `dependsOn: [opId]`" (produktregler.md:187).
  TextColumn get dependsOn => text().nullable()();

  /// Set when the entry will never be retried: a 4xx other than 408/429, 24 h
  /// of retries, or a dependency that failed permanently
  /// (produktregler.md:187-189). Such an entry is kept for the user to decide
  /// on ("Väntar på dig") and is never deleted without her
  /// (produktregler.md:192).
  BoolColumn get permanentlyFailed =>
      boolean().withDefault(const Constant(false))();
}

/// Entity types a [SyncQueueEntries] row can carry.
abstract final class SyncQueueEntityType {
  /// A recipe; [SyncQueueEntries.recipeId] is its id.
  static const String recipe = 'recipe';
}
