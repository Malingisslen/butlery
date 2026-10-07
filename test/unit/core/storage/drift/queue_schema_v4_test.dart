// P6-U08b: schema 4, the offline queue's retry schedule (produktregler.md:188).
//
// The migration test opens a database written by schema 3 — the exact CREATE
// statements drift emitted for schemaVersion 3, dumped from the code at
// b9379f0c6 — with queued rows, and checks that schema 4 keeps every row as
// it was, adds the two retry columns empty, and ends up with the same tables
// as a fresh install. Queue data is user data (produktregler.md:192).

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _v3Schema = <String>[
  'CREATE TABLE "json_cache_entries" ("box_name" TEXT NOT NULL, "user_id" TEXT NOT NULL, "key" TEXT NOT NULL, "value" TEXT NOT NULL, "cached_at" INTEGER NOT NULL, PRIMARY KEY ("box_name", "user_id", "key"))',
  'CREATE TABLE "offline_recipes" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "recipe_json" TEXT NOT NULL, "updated_at" INTEGER NOT NULL, "needs_sync" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_sync" IN (0, 1)), "last_synced_at" INTEGER NULL, PRIMARY KEY ("id", "user_id"))',
  'CREATE TABLE "parse_cache_entries" ("cache_key" TEXT NOT NULL, "user_id" TEXT NOT NULL, "recipe_json" TEXT NOT NULL, "parser_version" TEXT NOT NULL, "source" TEXT NOT NULL, "cached_at" INTEGER NOT NULL, PRIMARY KEY ("cache_key"))',
  'CREATE TABLE "sync_queue_entries" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "user_id" TEXT NOT NULL, "recipe_id" TEXT NOT NULL, "operation" TEXT NOT NULL, "queued_at" INTEGER NOT NULL, "retry_count" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL, "op_id" TEXT NOT NULL UNIQUE, "entity_type" TEXT NOT NULL DEFAULT \'recipe\', "depends_on" TEXT NULL, "permanently_failed" INTEGER NOT NULL DEFAULT 0 CHECK ("permanently_failed" IN (0, 1)))',
  'CREATE TABLE "upload_queue_entries" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "local_path" TEXT NOT NULL, "target_path" TEXT NOT NULL, "content_type" TEXT NOT NULL DEFAULT \'image/jpeg\', "file_size_bytes" INTEGER NOT NULL, "status" TEXT NOT NULL DEFAULT \'pending\', "retry_count" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL, "queued_at" INTEGER NOT NULL, "last_attempt_at" INTEGER NULL, "entity_id" TEXT NULL, "entity_type" TEXT NULL, "metadata" TEXT NULL, "depends_on" TEXT NULL, "permanently_failed" INTEGER NOT NULL DEFAULT 0 CHECK ("permanently_failed" IN (0, 1)), PRIMARY KEY ("id"))',
];

/// A schema-3 database with three sync entries (one a permanent failure,
/// one depending on another) and one upload.
AppDatabase _openV3WithRows() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (sqlite.Database db) {
        for (final statement in _v3Schema) {
          db.execute(statement);
        }
        db.execute(
          'INSERT INTO sync_queue_entries (user_id, recipe_id, operation, '
          'queued_at, retry_count, last_error, op_id, entity_type, '
          'depends_on, permanently_failed) VALUES '
          "('u1', 'r1', 'create', 1700000000, 0, NULL, 'op-a', 'recipe', "
          'NULL, 0), '
          "('u1', 'r1', 'tag', 1700000100, 2, 'unavailable', 'op-b', "
          '\'recipe\', \'["op-a"]\', 0), '
          "('u1', 'r2', 'update', 1700000200, 0, 'not-found', 'op-c', "
          "'recipe', NULL, 1)",
        );
        db.execute(
          'INSERT INTO upload_queue_entries (id, user_id, local_path, '
          'target_path, file_size_bytes, status, queued_at, depends_on) '
          "VALUES ('up-1', 'u1', '/a.jpg', 'x/a.jpg', 10, 'pending', "
          '1700000300, \'["op-a"]\')',
        );
        db.execute('PRAGMA user_version = 3');
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

  group('schema 3 -> 4 migration', () {
    late AppDatabase db;

    setUp(() => db = _openV3WithRows());
    tearDown(() => db.close());

    test('keeps every queued row exactly as it was', () async {
      final sync = await db.select(db.syncQueueEntries).get();
      final uploads = await db.select(db.uploadQueueEntries).get();

      expect(sync.map((e) => e.opId), ['op-a', 'op-b', 'op-c']);
      final b = sync.singleWhere((e) => e.opId == 'op-b');
      expect(b.retryCount, 2);
      expect(b.lastError, 'unavailable');
      expect(b.dependsOn, '["op-a"]');
      final c = sync.singleWhere((e) => e.opId == 'op-c');
      expect(c.permanentlyFailed, isTrue);
      expect(c.lastError, 'not-found');
      expect(uploads.single.id, 'up-1');
      expect(uploads.single.dependsOn, '["op-a"]');
    });

    test('adds the retry columns empty: every entry is sent at the next '
        'pass', () async {
      final sync = await db.select(db.syncQueueEntries).get();
      expect(sync.every((e) => e.nextAttemptAt == null), isTrue);
      expect(sync.every((e) => e.firstFailedAt == null), isTrue);
    });

    test('ends with the same schema as a fresh install', () async {
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);

      expect(await _schemaOf(db), await _schemaOf(fresh));
    });

    test('records the current schema version', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data.values.single, 5);
      expect(db.schemaVersion, 5);
    });
  });

  group('schema 4 queue surface', () {
    late AppDatabase db;
    final t0 = DateTime(2026, 9, 27, 12);

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> enqueue(
      String opId,
      String recipeId, {
      List<String> dependsOn = const [],
      String user = 'u1',
    }) => withClock(
      Clock.fixed(t0),
      () => db.syncQueueDao.enqueue(
        userId: user,
        recipeId: recipeId,
        operation: SyncOperation.update,
        opId: opId,
        dependsOn: dependsOn,
      ),
    );

    test('scheduleRetry stores the count, the times and the code', () async {
      await enqueue('op-1', 'r1');
      final entry = (await db.select(db.syncQueueEntries).get()).single;
      await db.syncQueueDao.scheduleRetry(
        entry.id,
        retryCount: 3,
        nextAttemptAt: t0.add(const Duration(seconds: 8)),
        firstFailedAt: t0,
        errorCode: 'unavailable',
      );
      final after = (await db.select(db.syncQueueEntries).get()).single;
      expect(after.retryCount, 3);
      expect(after.nextAttemptAt, t0.add(const Duration(seconds: 8)));
      expect(after.firstFailedAt, t0);
      expect(after.lastError, 'unavailable');
      expect(after.permanentlyFailed, isFalse);
    });

    test('a chain keeps its root cause; the ones after it say they hang on '
        'it', () async {
      await enqueue('op-1', 'r1');
      await enqueue('op-2', 'r1', dependsOn: ['op-1']);
      await enqueue('op-3', 'r9');

      final marked = await db.markChainPermanentlyFailed(
        'u1',
        'op-1',
        reason: 'dependency-failed',
        rootReason: 'not-found',
      );

      expect(marked, {'op-1', 'op-2'});
      final rows = {
        for (final e in await db.select(db.syncQueueEntries).get()) e.opId: e,
      };
      expect(rows['op-1']!.lastError, 'not-found');
      expect(rows['op-2']!.lastError, 'dependency-failed');
      expect(rows['op-1']!.permanentlyFailed, isTrue);
      expect(rows['op-2']!.permanentlyFailed, isTrue);
      expect(rows['op-3']!.permanentlyFailed, isFalse);
      expect(rows, hasLength(3), reason: 'nothing is deleted');
    });

    test('queuedOpIds splits the user\'s ids into waiting and failed, in '
        'both queues', () async {
      await enqueue('op-1', 'r1');
      await enqueue('op-2', 'r2');
      await enqueue('op-x', 'r3', user: 'u2');
      await db.syncQueueDao.markPermanentlyFailed('op-2');
      await withClock(
        Clock.fixed(t0),
        () => db.uploadQueueDao.queueUpload(
          id: 'up-1',
          userId: 'u1',
          localPath: '/a.jpg',
          targetPath: 'x/a.jpg',
          fileSizeBytes: 10,
        ),
      );
      await withClock(
        Clock.fixed(t0),
        () => db.uploadQueueDao.queueUpload(
          id: 'up-gone',
          userId: 'u1',
          localPath: '/b.jpg',
          targetPath: 'x/b.jpg',
          fileSizeBytes: 10,
        ),
      );
      await db.uploadQueueDao.cancelUpload('up-gone');

      final ids = await db.queuedOpIds('u1');
      expect(ids.waiting, {'op-1', 'up-1'});
      expect(ids.failed, {'op-2'});
    });
  });
}
