// BUT-2294: an upload-queue row goes up in two steps. The image is put in
// Storage and the row becomes "uploaded"; then a handler chosen by the row's
// entity type uses it. These tests drive the processor directly with a
// handler of their own.

import 'dart:io';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/upload_completion.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'queue_harness.dart' show MidRandom;

/// Uses an uploaded image the way a test says: ends the row, waits for its
/// group, or throws.
class _Handler implements UploadCompletion {
  _Handler(this._db);

  final AppDatabase _db;
  Object? failWith;
  final List<String> completed = [];

  @override
  Future<CompletionOutcome> complete(
    UploadQueueEntry row,
    String userId,
  ) async {
    final failure = failWith;
    if (failure != null) throw failure;
    final group = await _db.uploadQueueDao.getGroup(
      userId,
      row.entityType!,
      row.entityId!,
    );
    if (group.any((r) => r.status != 'uploaded')) {
      return CompletionOutcome.waitingForGroup;
    }
    for (final r in group) {
      completed.add(r.id);
      await _db.uploadQueueDao.markCompleted(r.id);
    }
    return CompletionOutcome.done;
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  const uid = 'u1';
  final t0 = DateTime(2026, 10, 19, 12);

  late AppDatabase db;
  late Directory root;
  late _Handler handler;
  late List<(String, String)> uploads;
  late List<String> taken;
  late bool deleteSucceeds;
  late UploadQueueProcessor processor;
  Future<void> Function(String objectId)? onUpload;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('two_step');
    handler = _Handler(db);
    uploads = [];
    taken = [];
    deleteSucceeds = true;
    onUpload = null;
    processor = UploadQueueProcessor(
      database: db,
      storage: OfflineUserStorage(database: db, uploadsRoot: () async => root),
      upload:
          (
            String localPath,
            String userId,
            String objectId,
            String targetPath,
          ) async {
            uploads.add((localPath, objectId));
            await onUpload?.call(objectId);
            return (
              url: 'https://img/$objectId.jpg',
              thumbnailUrl: 'https://img/${objectId}_thumb.jpg',
            );
          },
      deleteUploaded: (UploadedImage image) async {
        taken.add(image.url);
        return deleteSucceeds;
      },
      completions: {'cook_snap': handler},
      random: MidRandom(),
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> queue(String id, {String entityId = 'snap-1'}) {
    return db.uploadQueueDao.queueUpload(
      id: id,
      userId: uid,
      localPath: '/device/$id.jpg',
      targetPath: 'users/$uid/recipes/$id.jpg',
      fileSizeBytes: 10,
      entityId: entityId,
      entityType: 'cook_snap',
    );
  }

  Future<int> pass({Duration after = Duration.zero, bool force = false}) {
    return withClock(
      Clock.fixed(t0.add(after)),
      () => processor.runPass(
        uid,
        now: t0.add(after),
        isCurrentUser: () => true,
        force: force,
      ),
    );
  }

  Future<UploadQueueEntry?> row(String id) => db.uploadQueueDao.getUpload(id);

  test('the object is named after the row, so a second upload of the same '
      'row overwrites instead of adding a copy', () async {
    await queue('row-1');

    await pass();

    expect(uploads, [('/device/row-1.jpg', 'row-1')]);
  });

  test('the first row of a group waits in "uploaded" and the last one '
      'completes the whole group', () async {
    await queue('a');
    await queue('b');

    final sent = await pass();

    expect(uploads.map((u) => u.$2), ['a', 'b']);
    expect(handler.completed, ['a', 'b']);
    expect(sent, 1, reason: 'only the row that finished the group counts');
    expect(await row('a'), isNull);
    expect(await row('b'), isNull);
  });

  test('a row thrown away while its image uploads publishes nothing and the '
      'image is taken back out of Storage', () async {
    await queue('a');
    onUpload = (id) => db.uploadQueueDao.cancelUpload(id);

    final sent = await pass();

    expect(sent, 0);
    expect(handler.completed, isEmpty);
    expect(taken, ['https://img/a.jpg']);
    expect(await row('a'), isNull, reason: 'cancelled and nothing in Storage');
  });

  test('a failed use of an uploaded image is retried without uploading '
      'again', () async {
    await queue('a');
    handler.failWith = StateError('network');

    await pass();

    final waiting = (await row('a'))!;
    expect(waiting.status, 'uploaded');
    expect(waiting.uploadedUrl, 'https://img/a.jpg');
    expect(waiting.permanentlyFailed, isFalse);
    expect(waiting.nextAttemptAt, isNotNull);

    handler.failWith = null;
    await pass(after: const Duration(minutes: 1));

    expect(uploads, hasLength(1), reason: 'uploaded once, used once');
    expect(handler.completed, ['a']);
    expect(taken, isEmpty);
  });

  test('a use the server refuses takes the image back out and waits for the '
      'user, who can send it again', () async {
    await queue('a');
    handler.failWith = PermissionDeniedException('no');

    await pass();

    final refused = (await row('a'))!;
    expect(refused.permanentlyFailed, isTrue);
    expect(refused.status, 'failed');
    expect(refused.uploadedUrl, isNull);
    expect(taken, ['https://img/a.jpg']);
  });

  test('a refused image that cannot be taken back keeps its address for the '
      'next pass', () async {
    await queue('a');
    deleteSucceeds = false;
    handler.failWith = PermissionDeniedException('no');

    await pass();

    expect((await row('a'))!.uploadedUrl, 'https://img/a.jpg');
  });

  test('an image still in Storage for a row thrown away earlier is taken '
      'back at the next pass, and kept on a failure to try again', () async {
    await queue('a');
    handler.failWith = StateError('network');
    await pass();
    await db.uploadQueueDao.cancelUpload('a');
    deleteSucceeds = false;

    await pass(after: const Duration(minutes: 1));

    expect((await row('a'))!.uploadedUrl, 'https://img/a.jpg');

    deleteSucceeds = true;
    await pass(after: const Duration(minutes: 2));

    expect(taken, ['https://img/a.jpg', 'https://img/a.jpg']);
    expect(await row('a'), isNull);
    expect(uploads, hasLength(1));
  });

  test('a row marked refused while its image uploads has the image taken '
      'back at the next pass', () async {
    await queue('a');
    onUpload = (id) => db.uploadQueueDao.markPermanentlyFailed(id);

    await pass();
    expect(handler.completed, isEmpty);

    await pass(after: const Duration(minutes: 1));

    expect(taken, ['https://img/a.jpg']);
    expect((await row('a'))!.uploadedUrl, isNull);
  });

  test('an image whose recipe is gone but cannot be taken back keeps its '
      'address and the row is thrown away', () async {
    await db.uploadQueueDao.queueUpload(
      id: 'a',
      userId: uid,
      localPath: '/device/a.jpg',
      targetPath: 'users/$uid/recipes/a.jpg',
      fileSizeBytes: 10,
      entityId: 'no-such-recipe',
      entityType: 'recipe',
    );
    deleteSucceeds = false;

    await pass();

    final left = (await row('a'))!;
    expect(left.status, 'cancelled');
    expect(left.uploadedUrl, 'https://img/a.jpg');
  });

  test('a row thrown away during the upload keeps the address of an image '
      'that cannot be taken back, so the next pass tries again', () async {
    await queue('a');
    deleteSucceeds = false;
    onUpload = (id) => db.uploadQueueDao.cancelUpload(id);

    await pass();

    final cancelled = (await row('a'))!;
    expect(cancelled.status, 'cancelled');
    expect(cancelled.uploadedUrl, 'https://img/a.jpg');
    expect(await processor.hasPending(uid), isTrue);

    deleteSucceeds = true;
    await pass(after: const Duration(minutes: 1));

    expect(taken, ['https://img/a.jpg', 'https://img/a.jpg']);
    expect(await row('a'), isNull);
    expect(await processor.hasPending(uid), isFalse);
  });

  test('an image left in Storage for a thrown-away row is work for a pass '
      'even when no other row waits', () async {
    await queue('a');
    handler.failWith = StateError('network');
    await pass();
    await db.uploadQueueDao.cancelUpload('a');

    expect(await processor.hasPending(uid), isTrue);
  });

  test('a row thrown away while its upload fails stays thrown away', () async {
    await queue('a');
    processor = UploadQueueProcessor(
      database: db,
      storage: OfflineUserStorage(database: db, uploadsRoot: () async => root),
      upload: (path, userId, objectId, targetPath) async {
        await db.uploadQueueDao.cancelUpload(objectId);
        throw StateError('lost connection');
      },
      deleteUploaded: (UploadedImage image) async {
        taken.add(image.url);
        return true;
      },
      completions: {'cook_snap': handler},
      random: MidRandom(),
    );

    await pass();

    expect(handler.completed, isEmpty);
    expect(
      taken,
      isEmpty,
      reason: 'the upload failed, so nothing is in Storage',
    );
    expect(
      await row('a'),
      isNull,
      reason:
          'neither revived as failed nor kept: it was cancelled mid-upload '
          'and holds no address, so the pass ends by dropping it',
    );
  });

  test('an image whose recipe is gone from the device is taken back and the '
      'row is dropped', () async {
    await db.uploadQueueDao.queueUpload(
      id: 'a',
      userId: uid,
      localPath: '/device/a.jpg',
      targetPath: 'users/$uid/recipes/a.jpg',
      fileSizeBytes: 10,
      entityId: 'no-such-recipe',
      entityType: 'recipe',
    );

    await pass();

    expect(taken, ['https://img/a.jpg']);
    expect(await row('a'), isNull);
  });

  test('a row for an entity type nobody handles waits for the user and its '
      'image is taken back', () async {
    await db.uploadQueueDao.queueUpload(
      id: 'a',
      userId: uid,
      localPath: '/device/a.jpg',
      targetPath: 'users/$uid/recipes/a.jpg',
      fileSizeBytes: 10,
      entityId: 'x',
      entityType: 'something_new',
    );

    await pass();

    final stuck = (await row('a'))!;
    expect(stuck.permanentlyFailed, isTrue);
    expect(stuck.uploadedUrl, isNull);
    expect(taken, ['https://img/a.jpg']);
  });

  test('an earlier failure of the upload does not count against the retries '
      'of the second step', () async {
    await queue('a');
    await db.uploadQueueDao.recordFailure('a', 'unavailable');
    await (db.update(
      db.uploadQueueEntries,
    )..where((e) => e.id.equals('a'))).write(
      UploadQueueEntriesCompanion(
        firstFailedAt: Value(t0.subtract(const Duration(hours: 23))),
        retryCount: const Value(4),
      ),
    );
    handler.failWith = StateError('network');

    await pass(force: true);

    final waiting = (await row('a'))!;
    expect(waiting.permanentlyFailed, isFalse);
    expect(waiting.retryCount, 1);
    expect(waiting.firstFailedAt, t0);
  });

  test('the recipe handler publishes nothing for a row thrown away since the '
      'queue last looked', () async {
    final recipeHandler = RecipeImageCompletion(
      database: db,
      storage: OfflineUserStorage(database: db, uploadsRoot: () async => root),
    );
    await db.uploadQueueDao.queueUpload(
      id: 'a',
      userId: uid,
      localPath: '/device/a.jpg',
      targetPath: 'users/$uid/recipes/a.jpg',
      fileSizeBytes: 10,
      entityId: 'r1',
      entityType: 'recipe',
    );
    await db.uploadQueueDao.markUploaded('a', url: 'https://img/a.jpg');
    final seen = (await row('a'))!;
    await db.uploadQueueDao.cancelUpload('a');

    final outcome = await recipeHandler.complete(seen, uid);

    expect(outcome, CompletionOutcome.discarded);
    expect((await row('a'))!.status, 'cancelled');
  });
}
