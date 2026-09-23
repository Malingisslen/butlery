import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
// The generated sync-queue table creates each opId with Uuid (tables/sync_queue.dart).
import 'package:uuid/uuid.dart';
import 'package:butlery/core/utils/logger.dart';

import 'package:butlery/core/storage/drift/tables/offline_recipes.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/core/storage/drift/tables/json_cache.dart';
import 'package:butlery/core/storage/drift/tables/parse_cache.dart';
import 'package:butlery/core/storage/drift/tables/upload_queue.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/daos/cache_dao.dart';
import 'package:butlery/core/storage/drift/daos/upload_queue_dao.dart';
import 'package:butlery/core/storage/drift/queue_counts.dart';

export 'package:butlery/core/storage/drift/queue_counts.dart';

part 'app_database.g.dart';

/// Main Drift database for Butlery app
/// Replaces Hive for local storage with SQL-based persistence
@DriftDatabase(
  tables: [
    OfflineRecipes,
    SyncQueueEntries,
    JsonCacheEntries,
    ParseCacheEntries,
    UploadQueueEntries,
  ],
  daos: [
    RecipeDao,
    SyncQueueDao,
    CacheDao,
    UploadQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing: create an in-memory database
  AppDatabase.forTesting(super.e);

  /// 3: the offline queue's schema (produktregler.md:183-193, § 3.1) —
  /// opId, entity type, dependsOn and a permanent-failure flag.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from version 1 to 2: Add upload_queue_entries table
        if (from < 2) {
          await m.createTable(uploadQueueEntries);
        }
        if (from < 3) {
          await _migrateQueuesToV3(m);
        }
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Schema 2 → 3. Both queue tables are rebuilt in place with
  /// [Migrator.alterTable], which copies every row, so no queued change is
  /// lost (produktregler.md:192: the app never deletes a queue entry without
  /// a server confirmation or showing it to the user).
  ///
  /// Every existing sync entry gets a fresh random UUID v4 as its opId, the
  /// same format new entries get, and the entity type "recipe", the only entity the queue carried before
  /// schema 3. No entry is marked permanently failed.
  Future<void> _migrateQueuesToV3(Migrator m) async {
    await m.alterTable(
      TableMigration(
        syncQueueEntries,
        columnTransformer: {
          syncQueueEntries.opId: const CustomExpression<String>(
            _uuidV4Sql,
          ),
        },
        newColumns: [
          syncQueueEntries.opId,
          syncQueueEntries.entityType,
          syncQueueEntries.dependsOn,
          syncQueueEntries.permanentlyFailed,
        ],
      ),
    );
    await m.alterTable(
      TableMigration(
        uploadQueueEntries,
        newColumns: [
          uploadQueueEntries.dependsOn,
          uploadQueueEntries.permanentlyFailed,
        ],
      ),
    );
  }

  /// A random UUID v4 per row, in SQL, so migrated opIds have the same
  /// format as the ones new entries get.
  static const String _uuidV4Sql =
      "lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' "
      "|| substr(lower(hex(randomblob(2))), 2) || '-' "
      "|| substr('89ab', 1 + (abs(random()) % 4), 1) "
      "|| substr(lower(hex(randomblob(2))), 2) || '-' "
      '|| lower(hex(randomblob(6)))';

  /// The user's queue counts across both queues, live. See [QueueCounts].
  ///
  /// An upload counts while it is pending, uploading, or failed; a completed
  /// or cancelled one does not. A failed upload counts as draining until it
  /// is marked permanently failed: no caller yet passes a retry limit to
  /// [UploadQueueDao.getRetryableUploads], so the count cannot tell an
  /// upload with retries left from one that has run out (open question for
  /// when the count is surfaced, produktregler.md:188-189).
  Stream<QueueCounts> watchQueueCounts(String userId) {
    return customSelect(
      _queueCountsSql,
      variables: [Variable.withString(userId)],
      readsFrom: {syncQueueEntries, uploadQueueEntries},
    ).watchSingle().map(
      (row) => QueueCounts(
        draining: row.read<int>('draining'),
        needsUser: row.read<int>('needs_user'),
      ),
    );
  }

  /// The combined number of the user's changes not yet saved, live: one
  /// number across the sync and upload queues ([QueueCounts.waiting]).
  Stream<int> watchPendingCount(String userId) =>
      watchQueueCounts(userId).map((c) => c.waiting).distinct();

  static const String _queueCountsSql = """
SELECT
  (SELECT COUNT(*) FROM sync_queue_entries
     WHERE user_id = ?1 AND permanently_failed = 0)
  + (SELECT COUNT(*) FROM upload_queue_entries
     WHERE user_id = ?1 AND permanently_failed = 0
       AND status IN ('pending', 'uploading', 'failed')) AS draining,
  (SELECT COUNT(*) FROM sync_queue_entries
     WHERE user_id = ?1 AND permanently_failed = 1)
  + (SELECT COUNT(*) FROM upload_queue_entries
     WHERE user_id = ?1 AND permanently_failed = 1
       AND status NOT IN ('completed', 'cancelled')) AS needs_user
""";

  /// Marks the operation [opId] and every entry that depends on it, directly
  /// or through another entry, as permanently failed — in both queues and
  /// in one transaction. "Om beroendet permanent misslyckas markeras hela
  /// kedjan som misslyckad — aldrig halvvägs" (produktregler.md:187).
  ///
  /// Nothing is deleted. Returns the opIds that were marked (for an upload,
  /// its id).
  Future<Set<String>> markChainPermanentlyFailed(
    String userId,
    String opId, {
    String? reason,
  }) {
    return transaction(() async {
      final syncRows = await (select(
        syncQueueEntries,
      )..where((e) => e.userId.equals(userId))).get();
      final uploadRows = await (select(
        uploadQueueEntries,
      )..where((e) => e.userId.equals(userId))).get();

      final dependants = <String, Set<String>>{};
      void link(String id, String? stored) {
        for (final dep in decodeDependsOn(stored)) {
          (dependants[dep] ??= <String>{}).add(id);
        }
      }

      for (final row in syncRows) {
        link(row.opId, row.dependsOn);
      }
      for (final row in uploadRows) {
        link(row.id, row.dependsOn);
      }

      final failed = <String>{};
      final toVisit = <String>[opId];
      while (toVisit.isNotEmpty) {
        final id = toVisit.removeLast();
        if (!failed.add(id)) continue;
        toVisit.addAll(dependants[id] ?? const <String>{});
      }

      final syncIds = syncRows
          .map((r) => r.opId)
          .where(failed.contains)
          .toList();
      final uploadIds = uploadRows
          .map((r) => r.id)
          .where(failed.contains)
          .toList();
      final Value<String?> error = reason == null
          ? const Value.absent()
          : Value(reason);
      if (syncIds.isNotEmpty) {
        await (update(
          syncQueueEntries,
        )..where((e) => e.opId.isIn(syncIds))).write(
          SyncQueueEntriesCompanion(
            permanentlyFailed: const Value(true),
            lastError: error,
          ),
        );
      }
      if (uploadIds.isNotEmpty) {
        await (update(
          uploadQueueEntries,
        )..where((e) => e.id.isIn(uploadIds))).write(
          UploadQueueEntriesCompanion(
            permanentlyFailed: const Value(true),
            lastError: error,
          ),
        );
      }
      return {...syncIds, ...uploadIds};
    });
  }

  /// Clear all data (for testing or user logout)
  Future<void> clearAllData() async {
    await delete(offlineRecipes).go();
    await delete(syncQueueEntries).go();
    await delete(jsonCacheEntries).go();
    await delete(parseCacheEntries).go();
    await delete(uploadQueueEntries).go();
  }

  /// Clear all data for a specific user
  Future<void> clearUserData(String userId) async {
    await (delete(offlineRecipes)..where((t) => t.userId.equals(userId))).go();
    await (delete(
      syncQueueEntries,
    )..where((t) => t.userId.equals(userId))).go();
    await (delete(
      jsonCacheEntries,
    )..where((t) => t.userId.equals(userId))).go();
    await (delete(
      parseCacheEntries,
    )..where((t) => t.userId.equals(userId))).go();
    await (delete(
      uploadQueueEntries,
    )..where((t) => t.userId.equals(userId))).go();
  }

  /// Get database statistics
  Future<Map<String, int>> getStats() async {
    final recipes = await (selectOnly(
      offlineRecipes,
    )..addColumns([countAll()])).getSingle();
    final syncQueue = await (selectOnly(
      syncQueueEntries,
    )..addColumns([countAll()])).getSingle();
    final jsonCache = await (selectOnly(
      jsonCacheEntries,
    )..addColumns([countAll()])).getSingle();
    final parseCache = await (selectOnly(
      parseCacheEntries,
    )..addColumns([countAll()])).getSingle();
    final uploadQueue = await (selectOnly(
      uploadQueueEntries,
    )..addColumns([countAll()])).getSingle();

    return {
      'offlineRecipes': recipes.read(countAll()) ?? 0,
      'syncQueue': syncQueue.read(countAll()) ?? 0,
      'jsonCache': jsonCache.read(countAll()) ?? 0,
      'parseCache': parseCache.read(countAll()) ?? 0,
      'uploadQueue': uploadQueue.read(countAll()) ?? 0,
    };
  }
}

/// Secure storage instance for database encryption key
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

/// Storage key for the database encryption key
const _dbEncryptionKeyName = 'drift_db_encryption_key';

/// Opens a connection to the encrypted SQLite database using SQLCipher
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Use SQLCipher native library instead of default sqlite3
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);

    final dbFolder = await getApplicationDocumentsDirectory();
    // Use a new filename to avoid conflicts with old unencrypted database
    final file = File(p.join(dbFolder.path, 'butlery_drift_encrypted.sqlite'));

    // Get or generate the encryption key
    final encryptionKey = await _getDatabaseEncryptionKey();

    // Use NativeDatabase (not createInBackground) because background isolates
    // don't inherit the open.overrideFor SQLCipher library override
    return NativeDatabase(
      file,
      setup: (db) {
        // SQLite PRAGMAs are parsed at compile time and do NOT support
        // parameter binding (`PRAGMA key = ?` raises "syntax error near ?").
        // Use the literal-string form. The encryption key is base64Url-encoded
        // (alphabet `[A-Za-z0-9_-=]`), so it contains no characters that need
        // SQL escaping — but we escape single quotes defensively in case the
        // key generator ever changes format.
        final escapedKey = encryptionKey.replaceAll("'", "''");
        db.execute("PRAGMA key = '$escapedKey'");

        // Verify SQLCipher is actually loaded (not stock SQLite). If
        // libsqlcipher.so failed to load for the device ABI, the override
        // silently falls back to stock sqlite3 and the database opens
        // *unencrypted* — fail loudly here instead of silently degrading.
        final cipherVersionRow = db.select('PRAGMA cipher_version').firstOrNull;
        final cipherVersion = (cipherVersionRow?.values.first?.toString())
            .orEmpty();
        if (cipherVersion.isEmpty) {
          throw StateError(
            'SQLCipher library failed to load — database would open unencrypted. '
            'Check that libsqlcipher.so is present in the APK for this device '
            'ABI (run "unzip -l <apk> | grep libsqlcipher.so").',
          );
        }
      },
    );
  });
}

/// Gets or generates the database encryption key from secure storage
Future<String> _getDatabaseEncryptionKey() async {
  try {
    // Try to read existing key
    var key = await _secureStorage.read(key: _dbEncryptionKeyName);

    if (key == null) {
      // Generate a new 32-byte (256-bit) random key
      key = _generateSecureKey();
      await _secureStorage.write(key: _dbEncryptionKeyName, value: key);
      AppLogger.info('Generated new database encryption key');
    }

    return key;
  } catch (e) {
    AppLogger.error('Failed to access database encryption key: $e');
    // Generate a temporary key if secure storage fails
    // Note: This means data won't persist across app restarts if secure storage is unavailable
    return _generateSecureKey();
  }
}

/// Generates a cryptographically secure random key
String _generateSecureKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}

/// Creates an in-memory database for testing (unencrypted)
QueryExecutor createInMemoryDatabase() {
  return NativeDatabase.memory();
}
