// BUT-2294: a photo the user retries starts its 30 days over, also once an
// upload has cleared `firstFailedAt` and the photo waits for its album.

import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/sync_queue_reader.dart';
import 'package:butlery/services/offline/unsent_image_discard.dart';
import 'package:butlery/services/offline/upload_completion.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'queue_harness.dart' show MidRandom;

class _WaitForGroup implements UploadCompletion {
  @override
  Future<CompletionOutcome> complete(
    UploadQueueEntry row,
    String userId,
  ) async => CompletionOutcome.waitingForGroup;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  final day0 = DateTime(2026, 9, 1, 12);
  final day35 = day0.add(const Duration(days: 35));

  late AppDatabase db;
  late Directory root;
  late UploadQueueProcessor processor;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('retry_clock');
    processor = UploadQueueProcessor(
      database: db,
      storage: OfflineUserStorage(database: db, uploadsRoot: () async => root),
      upload: (path, userId, objectId) async {
        if (objectId == 'p2') throw const SocketException('flaky');
        return (url: 'https://img/$objectId.jpg', thumbnailUrl: null);
      },
      deleteUploaded: (image) async => true,
      completions: {SyncQueueEntityType.cookSnap: _WaitForGroup()},
      random: MidRandom(),
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> queueFailedAlbumPhoto(
    String id, {
    String entityId = 'snap',
    String entityType = SyncQueueEntityType.cookSnap,
  }) async {
    final file = File('${root.path}/$id.jpg')..writeAsBytesSync([1]);
    await withClock(
      Clock.fixed(day0),
      () => db.uploadQueueDao.queueUpload(
        id: id,
        userId: 'u1',
        localPath: file.path,
        targetPath: 'users/u1/$id.jpg',
        fileSizeBytes: 1,
        entityId: entityId,
        entityType: entityType,
      ),
    );
    await db.uploadQueueDao.markPermanentlyFailed(id, reason: 'x');
    await (db.update(
      db.uploadQueueEntries,
    )..where((e) => e.id.equals(id))).write(
      UploadQueueEntriesCompanion(
        firstFailedAt: Value(day0.add(const Duration(days: 10))),
      ),
    );
  }

  test(
    'an album retried on day 35 keeps both photos through the next pass '
    'although one of them uploaded and cleared its first-failed time',
    () async {
      await queueFailedAlbumPhoto('p1');
      await queueFailedAlbumPhoto('p2');
      await withClock(Clock.fixed(day35), () async {
        final album = (await readQueuedChanges(db, 'u1')).single;
        await retryQueuedChange(db, album, userId: 'u1');
      });

      await processor.runPass(
        'u1',
        now: day35,
        isCurrentUser: () => true,
        force: true,
      );
      final uploaded = (await db.uploadQueueDao.getUpload('p1'))!;
      expect(uploaded.status, 'uploaded');
      expect(uploaded.firstFailedAt, isNull, reason: 'the premise');

      final later = day35.add(const Duration(hours: 1));
      await processor.runPass('u1', now: later, isCurrentUser: () => true);

      expect(
        (await db.uploadQueueDao.getUpload('p1'))!.status,
        isNot('cancelled'),
      );
      expect(await db.uploadQueueDao.getUpload('p2'), isNotNull);
    },
  );

  test('a retried photo that fails for good at once is counted from the '
      'retry: its card says so and a sweep for the same user leaves it, '
      'while another expired photo of that user goes', () async {
    await queueFailedAlbumPhoto(
      'old',
      entityId: 'r-old',
      entityType: SyncQueueEntityType.recipe,
    );
    await queueFailedAlbumPhoto(
      'single',
      entityId: 'r-single',
      entityType: SyncQueueEntityType.recipe,
    );
    await queueFailedAlbumPhoto('snap-1', entityId: 'snap-b');
    await queueFailedAlbumPhoto('snap-2', entityId: 'snap-b');
    await withClock(Clock.fixed(day35), () async {
      for (final change in await readQueuedChanges(db, 'u1')) {
        if (change.id != 'old') {
          await retryQueuedChange(db, change, userId: 'u1');
        }
      }
    });
    for (final id in ['single', 'snap-1', 'snap-2']) {
      await db.uploadQueueDao.markPermanentlyFailed(id, reason: 'too-large');
    }

    final changes = {
      for (final c in await readQueuedChanges(db, 'u1')) c.id: c,
    };
    expect(changes['single']!.unsentSince, day35);
    expect(changes['snap-b']!.unsentSince, day35);

    final later = day0.add(const Duration(days: 41));
    expect(await sweepExpiredUnsent(db, later), 1);
    expect(await db.uploadQueueDao.getUpload('old'), isNull);
    expect(await db.uploadQueueDao.getUpload('single'), isNotNull);
    expect(await db.uploadQueueDao.getUpload('snap-1'), isNotNull);
    expect(await db.uploadQueueDao.getUpload('snap-2'), isNotNull);
  });
}
