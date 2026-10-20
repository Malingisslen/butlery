// BUT-2294: the 30-day rule for unsent images reaches rows no pass will ever
// visit (a user who signed out), and a thrown-away row keeps no metadata.

import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/upload_completion.dart';
import 'package:butlery/services/offline/unsent_image_discard.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'queue_harness.dart' show MidRandom;

class _TargetGone implements UploadCompletion {
  @override
  Future<CompletionOutcome> complete(
    UploadQueueEntry row,
    String userId,
  ) async => CompletionOutcome.targetGone;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  final t0 = DateTime(2026, 10, 20, 12);
  final old = t0.subtract(const Duration(days: 31));
  final recent = t0.subtract(const Duration(days: 29));

  late AppDatabase db;
  late Directory root;
  late List<String> taken;
  late List<String> uploaded;
  late UploadQueueProcessor processor;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('unsent_sweep');
    taken = [];
    uploaded = [];
    processor = UploadQueueProcessor(
      database: db,
      storage: OfflineUserStorage(database: db, uploadsRoot: () async => root),
      upload: (path, userId, objectId) async {
        uploaded.add(objectId);
        return (url: 'https://img/$objectId.jpg', thumbnailUrl: null);
      },
      deleteUploaded: (image) async {
        taken.add(image.url);
        return true;
      },
      random: MidRandom(),
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<String> queue(
    String id,
    String userId, {
    DateTime? failedAt,
    String? url,
    String? entityId,
    String entityType = 'recipe',
  }) async {
    final file = File('${root.path}/$id.jpg')..writeAsBytesSync([1]);
    await withClock(
      Clock.fixed(failedAt ?? t0),
      () => db.uploadQueueDao.queueUpload(
        id: id,
        userId: userId,
        localPath: file.path,
        targetPath: 'users/$userId/$id.jpg',
        fileSizeBytes: 1,
        entityId: entityId ?? 'r-$id',
        entityType: entityType,
        metadata: '{"caption":"hemligt"}',
      ),
    );
    if (failedAt != null) {
      await db.uploadQueueDao.markPermanentlyFailed(id, reason: 'x');
      await (db.update(
        db.uploadQueueEntries,
      )..where((e) => e.id.equals(id))).write(
        UploadQueueEntriesCompanion(
          firstFailedAt: Value(failedAt),
          uploadedUrl: Value(url),
        ),
      );
    }
    return file.path;
  }

  Future<UploadQueueEntry?> row(String id) => db.uploadQueueDao.getUpload(id);

  group('startup sweep', () {
    test('discards an expired photo of a user who is not signed in, with its '
        'device copy, and leaves what has not expired', () async {
      final oldCopy = await queue('old', 'signed-out', failedAt: old);
      final recentCopy = await queue('recent', 'signed-out', failedAt: recent);
      final otherOld = await queue('other-old', 'u2', failedAt: old);
      final waiting = await queue('waiting', 'u2');

      expect(await sweepExpiredUnsent(db, t0), 2);

      expect(await row('old'), isNull);
      expect(File(oldCopy).existsSync(), isFalse);
      expect(await row('other-old'), isNull);
      expect(File(otherOld).existsSync(), isFalse);
      expect((await row('recent'))!.status, isNot('cancelled'));
      expect(File(recentCopy).existsSync(), isTrue);
      expect((await row('waiting'))!.status, isNot('cancelled'));
      expect(File(waiting).existsSync(), isTrue);
    });

    test('keeps the address of an image already in Storage for that user\'s '
        'next pass, which takes it back and drops the row', () async {
      await queue('up', 'signed-out', failedAt: old, url: 'https://img/up.jpg');

      await sweepExpiredUnsent(db, t0);

      final kept = (await row('up'))!;
      expect(kept.status, 'cancelled');
      expect(kept.uploadedUrl, 'https://img/up.jpg');
      expect(taken, isEmpty, reason: 'the sweep makes no network call');

      await processor.runPass(
        'signed-out',
        now: t0,
        isCurrentUser: () => true,
      );

      expect(taken, ['https://img/up.jpg']);
      expect(await row('up'), isNull);
    });

    test('an album goes whole when one photo expired', () async {
      await queue(
        'p1',
        'signed-out',
        entityType: 'cook_snap',
        entityId: 'snap',
      );
      await queue(
        'p2',
        'signed-out',
        failedAt: old,
        entityType: 'cook_snap',
        entityId: 'snap',
      );

      await sweepExpiredUnsent(db, t0);

      expect(await row('p1'), isNull);
      expect(await row('p2'), isNull);
    });

    test('never throws, even when the database is unusable', () async {
      await queue('old', 'u1', failedAt: old);
      await db.close();

      expect(await sweepExpiredUnsent(db, t0), 0);

      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
  });

  group('a cancelled row keeps no metadata', () {
    test('cancelling a row with no address in Storage deletes it', () async {
      await queue('a', 'u1');

      await db.uploadQueueDao.cancelUpload('a');

      expect(await row('a'), isNull);
    });

    test('cancelling a row with an address keeps it until the take-back '
        'succeeds', () async {
      await queue('a', 'u1', failedAt: old, url: 'https://img/a.jpg');

      await db.uploadQueueDao.cancelUpload('a');

      final kept = (await row('a'))!;
      expect(kept.status, 'cancelled');
      expect(kept.uploadedUrl, 'https://img/a.jpg');
      expect(kept.metadata, isNull, reason: 'only the take-back is owed');
    });

    test('cancelling a row mid-upload keeps it for the upload to record '
        'where the image landed', () async {
      await queue('a', 'u1');
      await db.uploadQueueDao.markUploading('a');

      await db.uploadQueueDao.cancelUpload('a');

      expect((await row('a'))!.status, 'cancelled');
    });

    test('a cancelled photo stays while a photo of its album is still live, '
        'so the album knows it is dead; it goes with the last one', () async {
      for (final id in ['p1', 'p2']) {
        await queue(
          id,
          'u1',
          entityType: 'cook_snap',
          entityId: 'snap',
        );
      }

      await db.uploadQueueDao.cancelUpload('p1');
      expect((await row('p1'))!.status, 'cancelled');

      await db.uploadQueueDao.cancelUpload('p2');
      expect(await row('p1'), isNull);
      expect(await row('p2'), isNull);
    });

    test('an album photo cancelled mid-upload survives the cancelling of '
        'its siblings, so the upload can still record its address', () async {
      for (final id in ['p1', 'p2', 'p3']) {
        await queue(id, 'u1', entityType: 'cook_snap', entityId: 'snap');
      }
      await db.uploadQueueDao.markUploading('p1');

      await db.uploadQueueDao.cancelUpload('p1');
      await db.uploadQueueDao.cancelUpload('p2');
      await db.uploadQueueDao.cancelUpload('p3');

      expect(await row('p1'), isNotNull);
      expect(await row('p2'), isNull);
      expect(await row('p3'), isNull);
    });

    test('a pass ends with no bare cancelled photo left from an album whose '
        'target was gone', () async {
      await queue('p1', 'u1', entityType: 'cook_snap', entityId: 'snap');
      await queue('p2', 'u1', entityType: 'cook_snap', entityId: 'snap');
      await db.uploadQueueDao.cancelUpload('p2');
      expect((await row('p2'))!.status, 'cancelled');
      final sender = UploadQueueProcessor(
        database: db,
        storage: OfflineUserStorage(
          database: db,
          uploadsRoot: () async => root,
        ),
        upload: (path, userId, objectId) async =>
            (url: 'https://img/$objectId.jpg', thumbnailUrl: null),
        deleteUploaded: (image) async => true,
        completions: {SyncQueueEntityType.cookSnap: _TargetGone()},
        random: MidRandom(),
      );

      await sender.runPass('u1', now: t0, isCurrentUser: () => true);

      expect(await row('p1'), isNull);
      expect(await row('p2'), isNull);
    });

    test('a pass drops a cancelled album photo that was mid-upload when it '
        'was thrown away', () async {
      await queue('a', 'u1', entityType: 'cook_snap', entityId: 'snap');
      await db.uploadQueueDao.markUploading('a');
      await db.uploadQueueDao.cancelUpload('a');
      expect((await row('a'))!.status, 'cancelled');

      await processor.runPass('u1', now: t0, isCurrentUser: () => true);

      expect(await row('a'), isNull);
    });

    test('a pass drops a cancelled row that never got an address', () async {
      await queue('a', 'u1');
      await db.uploadQueueDao.markUploading('a');
      await db.uploadQueueDao.cancelUpload('a');

      await processor.runPass('u1', now: t0, isCurrentUser: () => true);

      expect(await row('a'), isNull);
    });
    test('the startup sweep drops a bare cancelled row of a user who never '
        'signs in again, and keeps one that holds an address', () async {
      await queue('a', 'gone');
      await db.uploadQueueDao.markUploading('a');
      await db.uploadQueueDao.cancelUpload('a');
      await queue('b', 'gone', failedAt: old, url: 'https://img/b.jpg');
      await db.uploadQueueDao.cancelUpload('b');

      await sweepExpiredUnsent(db, t0);

      expect(await row('a'), isNull);
      expect((await row('b'))!.status, 'cancelled');
    });
  });

  group('the 30-day rule inside a pass', () {
    test('another user\'s expired row is not discarded by this user\'s pass '
        'and does not make this user have pending work', () async {
      await queue('theirs', 'u2', failedAt: old);

      expect(
        await withClock(Clock.fixed(t0), () => processor.hasPending('u1')),
        isFalse,
      );
      await processor.runPass('u1', now: t0, isCurrentUser: () => true);

      expect((await row('theirs'))!.status, isNot('cancelled'));
    });

    test('nothing expired is no pending work', () async {
      await queue('recent', 'u1', failedAt: recent);

      expect(
        await withClock(Clock.fixed(t0), () => processor.hasPending('u1')),
        isFalse,
      );
    });

    test('a failing discard does not stall the sends of the pass', () async {
      await queue('old', 'u1', failedAt: old);
      await queue('fresh', 'u1');
      await db.customStatement(
        'CREATE TRIGGER no_discard BEFORE DELETE ON upload_queue_entries '
        "WHEN OLD.id = 'old' "
        "BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );

      await processor.runPass(
        'u1',
        now: t0,
        isCurrentUser: () => true,
        force: true,
      );

      expect(uploaded, ['fresh']);
    });
  });

  test('a cook-snap row with no snap id is not an album', () {
    final change = QueuedChange(
      kind: QueuedChangeKind.image,
      id: 'x',
      operation: QueuedOperation.upload,
      queuedAt: DateTime(2026),
      entityType: cookSnapEntityType,
    );

    expect(change.isCookSnapGroup, isFalse);
  });
}
