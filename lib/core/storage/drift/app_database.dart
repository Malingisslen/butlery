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

  @override
  int get schemaVersion => 2;

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
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
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
    await (delete(syncQueueEntries)..where((t) => t.userId.equals(userId)))
        .go();
    await (delete(jsonCacheEntries)..where((t) => t.userId.equals(userId)))
        .go();
    await (delete(parseCacheEntries)..where((t) => t.userId.equals(userId)))
        .go();
    await (delete(uploadQueueEntries)..where((t) => t.userId.equals(userId)))
        .go();
  }

  /// Get database statistics
  Future<Map<String, int>> getStats() async {
    final recipes = await (selectOnly(offlineRecipes)..addColumns([countAll()]))
        .getSingle();
    final syncQueue = await (selectOnly(syncQueueEntries)
          ..addColumns([countAll()]))
        .getSingle();
    final jsonCache = await (selectOnly(jsonCacheEntries)
          ..addColumns([countAll()]))
        .getSingle();
    final parseCache = await (selectOnly(parseCacheEntries)
          ..addColumns([countAll()]))
        .getSingle();
    final uploadQueue = await (selectOnly(uploadQueueEntries)
          ..addColumns([countAll()]))
        .getSingle();

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
        final cipherVersion =
            (cipherVersionRow?.values.first?.toString()).orEmpty();
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
