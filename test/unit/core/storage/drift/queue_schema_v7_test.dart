// BUT-2294: schema 7, where the 30 days of an unsent photo restart.
//
// The migration test opens a database written by schema 6 with a queued
// upload, and checks that schema 7 keeps it as it was, adds `retried_at`
// empty, and ends up with the same tables as a fresh install.

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _v6Schema = <String>[
  'CREATE TABLE "json_cache_entries" ("box_name" TEXT NOT NULL, "user_id" TEXT NOT NULL, "key" TEXT NOT NULL, "value" TEXT NOT NULL, "cached_at" INTEGER NOT NULL, PRIMARY KEY ("box_name", "user_id", "key"))',
  'CREATE TABLE "offline_recipes" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "recipe_json" TEXT NOT NULL, "updated_at" INTEGER NOT NULL, "needs_sync" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_sync" IN (0, 1)), "last_synced_at" INTEGER NULL, PRIMARY KEY ("id", "user_id"))',
  'CREATE TABLE "parse_cache_entries" ("cache_key" TEXT NOT NULL, "user_id" TEXT NOT NULL, "recipe_json" TEXT NOT NULL, "parser_version" TEXT NOT NULL, "source" TEXT NOT NULL, "cached_at" INTEGER NOT NULL, PRIMARY KEY ("cache_key"))',
  'CREATE TABLE "sync_queue_entries" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "user_id" TEXT NOT NULL, "recipe_id" TEXT NOT NULL, "operation" TEXT NOT NULL, "queued_at" INTEGER NOT NULL, "retry_count" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL, "op_id" TEXT NOT NULL UNIQUE, "entity_type" TEXT NOT NULL DEFAULT \'recipe\', "depends_on" TEXT NULL, "permanently_failed" INTEGER NOT NULL DEFAULT 0 CHECK ("permanently_failed" IN (0, 1)), "next_attempt_at" INTEGER NULL, "first_failed_at" INTEGER NULL)',
  'CREATE TABLE "upload_queue_entries" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "local_path" TEXT NOT NULL, "target_path" TEXT NOT NULL, "content_type" TEXT NOT NULL DEFAULT \'image/jpeg\', "file_size_bytes" INTEGER NOT NULL, "status" TEXT NOT NULL DEFAULT \'pending\', "retry_count" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL, "queued_at" INTEGER NOT NULL, "last_attempt_at" INTEGER NULL, "entity_id" TEXT NULL, "entity_type" TEXT NULL, "metadata" TEXT NULL, "depends_on" TEXT NULL, "permanently_failed" INTEGER NOT NULL DEFAULT 0 CHECK ("permanently_failed" IN (0, 1)), "next_attempt_at" INTEGER NULL, "first_failed_at" INTEGER NULL, "uploaded_url" TEXT NULL, "uploaded_thumbnail_url" TEXT NULL, PRIMARY KEY ("id"))',
];

AppDatabase _openV6WithUpload() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (sqlite.Database db) {
        for (final statement in _v6Schema) {
          db.execute(statement);
        }
        db.execute(
          'INSERT INTO upload_queue_entries (id, user_id, local_path, '
          'target_path, file_size_bytes, status, retry_count, queued_at, '
          'first_failed_at, uploaded_url) VALUES '
          "('up-1', 'u1', '/a.jpg', 'users/u1/recipes', 10, 'uploaded', 2, "
          "1700000300, 1700000400, 'https://x/a.jpg')",
        );
        db.execute('PRAGMA user_version = 6');
      },
    ),
  );
}

Future<Map<String, String>> _schemaOf(AppDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name '
        "NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .get();
  return {
    for (final r in rows) r.read<String>('name'): r.read<String>('sql'),
  };
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('schema 6 -> 7 migration', () {
    late AppDatabase db;

    setUp(() => db = _openV6WithUpload());
    tearDown(() => db.close());

    test('keeps the queued upload as it was, never retried', () async {
      final upload = (await db.select(db.uploadQueueEntries).get()).single;

      expect(upload.id, 'up-1');
      expect(upload.status, 'uploaded');
      expect(upload.retryCount, 2);
      expect(upload.uploadedUrl, 'https://x/a.jpg');
      expect(upload.firstFailedAt, isNotNull);
      expect(upload.retriedAt, isNull);
    });

    test('ends with the same tables as a fresh install', () async {
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);

      expect(await _schemaOf(db), await _schemaOf(fresh));
    });

    test('records the current schema version', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data.values.single, db.schemaVersion);
    });
  });
}
