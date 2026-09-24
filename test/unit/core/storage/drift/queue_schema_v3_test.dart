// P5-U35: the offline queue's schema (produktregler.md:183-193, § 3.1).
//
// The migration test opens a database written by schema 2 — the exact
// CREATE statements drift emitted for schemaVersion 2, dumped from the code
// at 60b68d37b — with queued rows in both queues, and checks that schema 3
// keeps every row, gives each sync entry an opId and an entity type, and ends
// up with the same tables as a fresh install.

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/app_database_stub_web.dart' as web;
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _v2Schema = <String>[
  'CREATE TABLE "json_cache_entries" ("box_name" TEXT NOT NULL, "user_id" TEXT NOT NULL, "key" TEXT NOT NULL, "value" TEXT NOT NULL, "cached_at" INTEGER NOT NULL, PRIMARY KEY ("box_name", "user_id", "key"));',
  'CREATE TABLE "offline_recipes" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "recipe_json" TEXT NOT NULL, "updated_at" INTEGER NOT NULL, "needs_sync" INTEGER NOT NULL DEFAULT 0 CHECK ("needs_sync" IN (0, 1)), "last_synced_at" INTEGER NULL, PRIMARY KEY ("id", "user_id"));',
  'CREATE TABLE "parse_cache_entries" ("cache_key" TEXT NOT NULL, "user_id" TEXT NOT NULL, "recipe_json" TEXT NOT NULL, "parser_version" TEXT NOT NULL, "source" TEXT NOT NULL, "cached_at" INTEGER NOT NULL, PRIMARY KEY ("cache_key"));',
  'CREATE TABLE "sync_queue_entries" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "user_id" TEXT NOT NULL, "recipe_id" TEXT NOT NULL, "operation" TEXT NOT NULL, "queued_at" INTEGER NOT NULL, "retry_count" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL);',
  'CREATE TABLE "upload_queue_entries" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "local_path" TEXT NOT NULL, "target_path" TEXT NOT NULL, "content_type" TEXT NOT NULL DEFAULT \'image/jpeg\', "file_size_bytes" INTEGER NOT NULL, "status" TEXT NOT NULL DEFAULT \'pending\', "retry_count" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL, "queued_at" INTEGER NOT NULL, "last_attempt_at" INTEGER NULL, "entity_id" TEXT NULL, "entity_type" TEXT NULL, "metadata" TEXT NULL, PRIMARY KEY ("id"));',
];

/// A schema-2 database with three queued sync entries and two uploads.
AppDatabase _openV2WithRows() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (sqlite.Database db) {
        for (final statement in _v2Schema) {
          db.execute(statement);
        }
        db.execute(
          'INSERT INTO sync_queue_entries (user_id, recipe_id, operation, '
          'queued_at, retry_count, last_error) VALUES '
          "('u1', 'r1', 'create', 1700000000, 0, NULL), "
          "('u1', 'r1', 'update', 1700000100, 2, 'timeout'), "
          "('u2', 'r9', 'delete', 1700000200, 0, NULL)",
        );
        db.execute(
          'INSERT INTO upload_queue_entries (id, user_id, local_path, '
          'target_path, file_size_bytes, status, queued_at, entity_id, '
          'entity_type) VALUES '
          "('up-1', 'u1', '/a.jpg', 'x/a.jpg', 10, 'pending', 1700000300, "
          "'r1', 'recipe'), "
          "('up-2', 'u1', '/b.jpg', 'x/b.jpg', 20, 'failed', 1700000400, "
          'NULL, NULL)',
        );
        db.execute('PRAGMA user_version = 2');
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
  // The schema comparison opens a second, fresh database on purpose.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('schema 2 -> 3 migration', () {
    late AppDatabase db;

    setUp(() => db = _openV2WithRows());
    tearDown(() => db.close());

    test('keeps every queued row in both queues', () async {
      final sync = await db.select(db.syncQueueEntries).get();
      final uploads = await db.select(db.uploadQueueEntries).get();

      expect(sync, hasLength(3));
      expect(uploads, hasLength(2));
      final second = sync.singleWhere((e) => e.operation == 'update');
      expect(second.recipeId, 'r1');
      expect(second.retryCount, 2);
      expect(second.lastError, 'timeout');
      expect(
        uploads.map((u) => u.id),
        unorderedEquals(<String>['up-1', 'up-2']),
      );
    });

    test('gives every existing sync entry a distinct opId and the entity '
        'type "recipe"', () async {
      final sync = await db.select(db.syncQueueEntries).get();

      final opIds = sync.map((e) => e.opId).toList();
      expect(
        opIds.every(
          (id) => RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(id),
        ),
        isTrue,
      );
      expect(opIds.toSet(), hasLength(3));
      expect(sync.every((e) => e.entityType == 'recipe'), isTrue);
      expect(sync.every((e) => e.dependsOn == null), isTrue);
      expect(sync.every((e) => !e.permanentlyFailed), isTrue);
    });

    test(
      'marks no upload as permanently failed and adds no dependency',
      () async {
        final uploads = await db.select(db.uploadQueueEntries).get();

        expect(uploads.every((u) => !u.permanentlyFailed), isTrue);
        expect(uploads.every((u) => u.dependsOn == null), isTrue);
      },
    );

    test('ends with the same schema as a fresh install', () async {
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);

      expect(await _schemaOf(db), await _schemaOf(fresh));
    });

    test('records schema version 3', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.data.values.single, 3);
      expect(db.schemaVersion, 3);
    });
  });

  group('sync queue, schema 3', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('enqueue creates a unique opId unless one is given', () async {
      await db.syncQueueDao.enqueue(
        userId: 'u1',
        recipeId: 'r1',
        operation: SyncOperation.create,
      );
      await db.syncQueueDao.enqueue(
        userId: 'u1',
        recipeId: 'r1',
        operation: SyncOperation.update,
        opId: 'op-given',
        dependsOn: const ['op-x'],
      );

      final rows = await db.syncQueueDao.getPendingForUser('u1');
      expect(rows, hasLength(2));
      expect(rows.first.opId, isNot('op-given'));
      expect(rows.first.opId, hasLength(36)); // UUID v4
      expect(rows.last.opId, 'op-given');
      expect(SyncQueueDao.dependsOnOf(rows.last), <String>['op-x']);
      expect(rows.last.entityType, SyncQueueEntityType.recipe);
    });

    test('the same opId cannot be queued twice', () async {
      await db.syncQueueDao.enqueue(
        userId: 'u1',
        recipeId: 'r1',
        operation: SyncOperation.create,
        opId: 'op-1',
      );

      await expectLater(
        db.syncQueueDao.enqueue(
          userId: 'u1',
          recipeId: 'r1',
          operation: SyncOperation.create,
          opId: 'op-1',
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'a permanent failure stays in the queue but no longer drains',
      () async {
        await db.syncQueueDao.enqueue(
          userId: 'u1',
          recipeId: 'r1',
          operation: SyncOperation.create,
          opId: 'op-1',
        );
        await db.syncQueueDao.enqueue(
          userId: 'u1',
          recipeId: 'r2',
          operation: SyncOperation.create,
          opId: 'op-2',
        );

        expect(
          await db.syncQueueDao.markPermanentlyFailed('op-1', reason: '404'),
          isTrue,
        );

        expect(await db.syncQueueDao.countPending('u1'), 1);
        expect(
          (await db.syncQueueDao.getPendingForUser('u1')).single.opId,
          'op-2',
        );
        final failures = await db.syncQueueDao.getPermanentFailures('u1');
        expect(failures.single.opId, 'op-1');
        expect(failures.single.lastError, '404');
      },
    );
  });

  group('the whole chain fails, never half of it (produktregler.md:187)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('marks every direct and indirect dependant in both queues', () async {
      final dao = db.syncQueueDao;
      await dao.enqueue(
        userId: 'u1',
        recipeId: 'r1',
        operation: SyncOperation.create,
        opId: 'add',
      );
      await dao.enqueue(
        userId: 'u1',
        recipeId: 'r1',
        operation: SyncOperation.update,
        opId: 'check',
        dependsOn: const ['add'],
      );
      await dao.enqueue(
        userId: 'u1',
        recipeId: 'r1',
        operation: SyncOperation.tag,
        opId: 'tag',
        dependsOn: const ['check'],
      );
      await dao.enqueue(
        userId: 'u1',
        recipeId: 'r2',
        operation: SyncOperation.create,
        opId: 'other',
      );
      await db.uploadQueueDao.queueUpload(
        id: 'img',
        userId: 'u1',
        localPath: '/a.jpg',
        targetPath: 'x/a.jpg',
        fileSizeBytes: 1,
        dependsOn: const ['add'],
      );

      final marked = await db.markChainPermanentlyFailed(
        'u1',
        'add',
        reason: 'gone',
      );

      expect(marked, <String>{'add', 'check', 'tag', 'img'});
      expect(
        (await dao.getPendingForUser('u1')).map((e) => e.opId),
        <String>['other'],
      );
      expect(await db.uploadQueueDao.countPendingUploads('u1'), 0);
      // Nothing was deleted (produktregler.md:192).
      expect(await db.select(db.syncQueueEntries).get(), hasLength(4));
      expect(await db.select(db.uploadQueueEntries).get(), hasLength(1));
    });
  });

  group('one combined count across both queues', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('draining and needs-user are counted apart, per user', () async {
      await db.syncQueueDao.enqueue(
        userId: 'u1',
        recipeId: 'r1',
        operation: SyncOperation.create,
        opId: 's1',
      );
      await db.syncQueueDao.enqueue(
        userId: 'u1',
        recipeId: 'r2',
        operation: SyncOperation.create,
        opId: 's2',
      );
      await db.syncQueueDao.enqueue(
        userId: 'u2',
        recipeId: 'r3',
        operation: SyncOperation.create,
      );
      for (final id in ['up1', 'up2', 'up3', 'up4']) {
        await db.uploadQueueDao.queueUpload(
          id: id,
          userId: 'u1',
          localPath: '/$id.jpg',
          targetPath: 'x/$id.jpg',
          fileSizeBytes: 1,
        );
      }
      await db.uploadQueueDao.markUploading('up2');
      await db.uploadQueueDao.cancelUpload('up3');
      await db.uploadQueueDao.markPermanentlyFailed('up4');
      await db.syncQueueDao.markPermanentlyFailed('s2');

      final counts = await db.watchQueueCounts('u1').first;

      // s1 + up1 + up2 (uploading still counts) drain by themselves.
      expect(counts.draining, 3);
      // s2 and up4 wait for the user; the cancelled upload counts nowhere.
      expect(counts.needsUser, 2);
      expect(counts.waiting, 5);
      expect(await db.watchPendingCount('u1').first, 5);
      expect(await db.watchPendingCount('u2').first, 1);
    });

    test('the count follows writes to either queue', () async {
      final seen = <int>[];
      final sub = db.watchPendingCount('u1').listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await db.syncQueueDao.enqueue(
        userId: 'u1',
        recipeId: 'r1',
        operation: SyncOperation.create,
      );
      await pumpEventQueue();
      await db.uploadQueueDao.queueUpload(
        id: 'up1',
        userId: 'u1',
        localPath: '/a.jpg',
        targetPath: 'x/a.jpg',
        fileSizeBytes: 1,
      );
      await pumpEventQueue();

      expect(seen, <int>[0, 1, 2]);
    });
  });

  group('web stub keeps the same count surface', () {
    test('every count is zero and every stream emits once', () async {
      final stub = web.AppDatabase();

      expect(stub.schemaVersion, 3);
      expect(await stub.watchQueueCounts('u1').first, QueueCounts.empty);
      expect(await stub.watchPendingCount('u1').first, 0);
      expect(await stub.syncQueueDao.watchPendingCount('u1').first, 0);
      expect(await stub.syncQueueDao.countPending('u1'), 0);
      expect(await stub.syncQueueDao.hasPending('u1'), isFalse);
      expect(await stub.uploadQueueDao.watchPendingCount('u1').first, 0);
      expect(await stub.markChainPermanentlyFailed('u1', 'op'), isEmpty);
    });
  });
}
