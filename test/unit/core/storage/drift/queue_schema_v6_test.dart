// BUT-2294: schema 6, the upload step's result on the upload queue.
//
// The migration test opens a database written by schema 5 — the CREATE
// statements drift emits for schemaVersion 5 — with a queued upload, and
// checks that schema 6 keeps it as it was, adds the two result columns empty,
// and ends up with the same tables as a fresh install.

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _v5Schema = <String>[
  'CREATE TABLE "json_cache_entries" ("box_name" TEXT NOT NULL, "user_id" TEXT NOT NULL, "key" TEXT NOT NULL, "value" TEXT NOT NULL, "cached_at" INTEGER NOT NULL, PRIMARY KEY ("box_name", "user_id", "key"))',
  'CREATE TABLE "offline_recipes" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "recipe_json" TEXT NOT NULL, "updated_at" INTEGER NOT NULL, "needs_sync" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_sync" IN (0, 1)), "last_synced_at" INTEGER NULL, PRIMARY KEY ("id", "user_id"))',
  'CREATE TABLE "parse_cache_entries" ("cache_key" TEXT NOT NULL, "user_id" TEXT NOT NULL, "recipe_json" TEXT NOT NULL, "parser_version" TEXT NOT NULL, "source" TEXT NOT NULL, "cached_at" INTEGER NOT NULL, PRIMARY KEY ("cache_key"))',
  'CREATE TABLE "sync_queue_entries" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "user_id" TEXT NOT NULL, "recipe_id" TEXT NOT NULL, "operation" TEXT NOT NULL, "queued_at" INTEGER NOT NULL, "retry_count" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL, "op_id" TEXT NOT NULL UNIQUE, "entity_type" TEXT NOT NULL DEFAULT \'recipe\', "depends_on" TEXT NULL, "permanently_failed" INTEGER NOT NULL DEFAULT 0 CHECK ("permanently_failed" IN (0, 1)), "next_attempt_at" INTEGER NULL, "first_failed_at" INTEGER NULL)',
  'CREATE TABLE "upload_queue_entries" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "local_path" TEXT NOT NULL, "target_path" TEXT NOT NULL, "content_type" TEXT NOT NULL DEFAULT \'image/jpeg\', "file_size_bytes" INTEGER NOT NULL, "status" TEXT NOT NULL DEFAULT \'pending\', "retry_count" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL, "queued_at" INTEGER NOT NULL, "last_attempt_at" INTEGER NULL, "entity_id" TEXT NULL, "entity_type" TEXT NULL, "metadata" TEXT NULL, "depends_on" TEXT NULL, "permanently_failed" INTEGER NOT NULL DEFAULT 0 CHECK ("permanently_failed" IN (0, 1)), "next_attempt_at" INTEGER NULL, "first_failed_at" INTEGER NULL, PRIMARY KEY ("id"))',
];

AppDatabase _openV5WithUpload() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (sqlite.Database db) {
        for (final statement in _v5Schema) {
          db.execute(statement);
        }
        db.execute(
          'INSERT INTO upload_queue_entries (id, user_id, local_path, '
          'target_path, file_size_bytes, status, retry_count, last_error, '
          'queued_at, entity_id, entity_type, depends_on) VALUES '
          "('up-1', 'u1', '/a.jpg', 'users/u1/recipes', 10, 'failed', 2, "
          "'unavailable', 1700000300, 'r1', 'recipe', '[\"op-a\"]')",
        );
        db.execute('PRAGMA user_version = 5');
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

  group('schema 5 -> 6 migration', () {
    late AppDatabase db;

    setUp(() => db = _openV5WithUpload());
    tearDown(() => db.close());

    test('keeps the queued upload as it was, with no upload result', () async {
      final upload = (await db.select(db.uploadQueueEntries).get()).single;

      expect(upload.id, 'up-1');
      expect(upload.status, 'failed');
      expect(upload.retryCount, 2);
      expect(upload.lastError, 'unavailable');
      expect(upload.entityId, 'r1');
      expect(upload.dependsOn, '["op-a"]');
      expect(upload.permanentlyFailed, isFalse);
      expect(upload.uploadedUrl, isNull);
      expect(upload.uploadedThumbnailUrl, isNull);
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

  group('the uploaded status', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> queue(String id, {String entityId = 'snap-1'}) {
      return db.uploadQueueDao.queueUpload(
        id: id,
        userId: 'u1',
        localPath: '/$id.jpg',
        targetPath: 'users/u1/recipes/$id.jpg',
        fileSizeBytes: 10,
        entityId: entityId,
        entityType: 'cook_snap',
      );
    }

    test(
      'markUploaded keeps the result so a retry does not upload again',
      () async {
        await queue('a');

        await db.uploadQueueDao.markUploaded(
          'a',
          url: 'https://x/a.jpg',
          thumbnailUrl: 'https://x/a_t.jpg',
        );

        final row = (await db.uploadQueueDao.getUpload('a'))!;
        expect(row.status, 'uploaded');
        expect(row.uploadedUrl, 'https://x/a.jpg');
        expect(row.uploadedThumbnailUrl, 'https://x/a_t.jpg');
        expect(await db.uploadQueueDao.getPendingUploads('u1'), isEmpty);
      },
    );

    test('markUploaded writes nothing for a row thrown away meanwhile, so a '
        'discard cannot be undone by the upload finishing', () async {
      await queue('a');
      await db.uploadQueueDao.markUploading('a');
      await db.uploadQueueDao.cancelUpload('a');

      final written = await db.uploadQueueDao.markUploaded(
        'a',
        url: 'https://x/a.jpg',
      );

      expect(written, isFalse);
      final after = await db.uploadQueueDao.getUpload('a');
      expect(after!.status, 'cancelled');
      expect(after.uploadedUrl, isNull);
      expect(await db.uploadQueueDao.markUploaded('nope', url: 'u'), isFalse);
    });

    test('markUploaded starts the retry schedule over', () async {
      await queue('a');
      await db.uploadQueueDao.recordFailure('a', 'unavailable');

      await db.uploadQueueDao.markUploaded('a', url: 'https://x/a.jpg');

      final row = (await db.uploadQueueDao.getUpload('a'))!;
      expect(row.retryCount, 0);
      expect(row.lastError, isNull);
      expect(row.firstFailedAt, isNull);
      expect(row.nextAttemptAt, isNull);
    });

    test('an uploaded row still counts as waiting, so a sign-out is warned '
        'about the photo that is in Storage but not on the snap', () async {
      await queue('a');
      await db.uploadQueueDao.markUploaded('a', url: 'https://x/a.jpg');

      expect(await db.uploadQueueDao.hasPendingUploads('u1'), isTrue);
      expect(await db.uploadQueueDao.countPendingUploads('u1'), 1);
      expect((await db.watchQueueCounts('u1').first).draining, 1);
      expect(await db.uploadQueueDao.watchPendingCount('u1').first, 1);
    });

    test('getGroup returns one entity\'s rows in the order they were '
        'queued, ties by id, and no one else\'s', () async {
      Future<void> queueAt(String id, int seconds, {String? entityId}) =>
          withClock(
            Clock.fixed(DateTime.utc(2026, 10, 19, 12, 0, seconds)),
            () => queue(id, entityId: entityId ?? 'snap-1'),
          );
      // The earlier-queued row has the later id, and `y`/`z` share an
      // instant, so only the two orderings together give [b, a, y, z].
      await queueAt('z', 5);
      await queueAt('a', 2);
      await queueAt('b', 1);
      await queueAt('y', 5);
      await queueAt('other', 3, entityId: 'snap-2');

      final group = await db.uploadQueueDao.getGroup(
        'u1',
        'cook_snap',
        'snap-1',
      );

      expect(group.map((r) => r.id), ['b', 'a', 'y', 'z']);
      expect(
        await db.uploadQueueDao.getGroup('u2', 'cook_snap', 'snap-1'),
        isEmpty,
      );
    });
  });
}
