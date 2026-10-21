// BUT-2294: a profile picture chosen without a connection. The picture is put
// on the profile only if the profile still holds the one the user was looking
// at; a newer picture elsewhere stays.

import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/avatar_write_outcome.dart';
import 'package:butlery/services/offline/avatar_queue_metadata.dart';
import 'package:butlery/services/offline/avatar_upload_completion.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'queue_harness.dart' show MidRandom, firestoreError;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  const uid = 'u1';
  final t0 = DateTime(2026, 10, 20, 12);

  late AppDatabase db;
  late Directory root;
  late OfflineUserStorage storage;
  late List<({String? expected, String url})> asked;
  late AvatarWriteOutcome outcome;
  Object? failure;
  var failAlways = false;
  late List<String> taken;
  late List<String> uploadFolders;
  late UploadQueueProcessor processor;
  late String rowId;
  late String copyPath;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('avatar_queue');
    storage = OfflineUserStorage(
      database: db,
      uploadsRoot: () async => Directory('${root.path}/queue'),
      copyImage: (source, base) => source.copy('$base.jpg'),
    );
    asked = [];
    outcome = AvatarWriteOutcome.set;
    failure = null;
    failAlways = false;
    taken = [];
    uploadFolders = [];
    processor = UploadQueueProcessor(
      database: db,
      storage: storage,
      upload:
          (
            String localPath,
            String userId,
            String objectId,
            String targetPath,
          ) async {
            uploadFolders.add(targetPath);
            return (url: 'https://img/$objectId.jpg', thumbnailUrl: null);
          },
      deleteUploaded: (UploadedImage image) async {
        taken.add(image.url);
        return true;
      },
      completions: {
        SyncQueueEntityType.avatar: AvatarUploadCompletion(
          database: db,
          storage: storage,
          setAvatar:
              ({required userId, required expected, required url}) async {
                asked.add((expected: expected, url: url));
                if (failAlways) throw firestoreError('unavailable');
                final thrown = failure;
                if (thrown != null) {
                  failure = null;
                  throw thrown;
                }
                return outcome;
              },
        ),
      },
      random: MidRandom(),
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> queue({String? base = 'https://img/old.jpg'}) async {
    final file = File('${root.path}/photo.jpg')..writeAsBytesSync([1]);
    final ids = await withClock(
      Clock.fixed(t0),
      () => storage.queueImageGroupForUser(
        imagePaths: [file.path],
        entityType: SyncQueueEntityType.avatar,
        entityId: uid,
        userId: uid,
        targetPath: 'users/$uid/avatars',
        metadata: avatarQueueMetadata(baseAvatarUrl: base),
        replaceWaiting: true,
      ),
    );
    rowId = ids.single;
    copyPath = (await db.uploadQueueDao.getUpload(rowId))!.localPath;
  }

  Future<int> pass({Duration after = Duration.zero}) => withClock(
    Clock.fixed(t0.add(after)),
    () => processor.runPass(
      uid,
      now: t0.add(after),
      isCurrentUser: () => true,
      force: true,
    ),
  );

  Future<UploadQueueEntry?> row() => db.uploadQueueDao.getUpload(rowId);

  test('the picture goes to the avatar folder and is set against the one the '
      'user was looking at; the row and the copy are gone', () async {
    await queue();

    await pass();

    expect(uploadFolders, ['users/$uid/avatars']);
    expect(asked, [
      (expected: 'https://img/old.jpg', url: 'https://img/$rowId.jpg'),
    ]);
    expect(await row(), isNull);
    expect(File(copyPath).existsSync(), isFalse);
    expect(taken, isEmpty);
  });

  test('a profile that had no picture is compared as such', () async {
    await queue(base: null);

    await pass();

    expect(asked.single.expected, isNull);
  });

  test(
    'a picture already on the profile is done and stays in Storage',
    () async {
      await queue();
      outcome = AvatarWriteOutcome.alreadySet;

      await pass();

      expect(await row(), isNull);
      expect(taken, isEmpty);
    },
  );

  for (final gone in [
    AvatarWriteOutcome.superseded,
    AvatarWriteOutcome.accountGone,
  ]) {
    test('$gone takes the unused picture back out of Storage and drops the '
        'row', () async {
      await queue();
      outcome = gone;

      await pass();

      expect(taken, ['https://img/$rowId.jpg']);
      expect(await row(), isNull);
      expect(File(copyPath).existsSync(), isFalse);
    });
  }

  test('a failure that may pass is tried again and the picture is not '
      'uploaded twice', () async {
    await queue();
    failure = firestoreError('unavailable');

    await pass();

    expect((await row())!.retryCount, 1);
    expect(uploadFolders, hasLength(1));

    await pass(after: const Duration(hours: 1));

    expect(asked, hasLength(2));
    expect(uploadFolders, hasLength(1));
    expect(await row(), isNull);
  });

  test('after eight failed tries the picture waits for the user and is taken '
      'back out of Storage', () async {
    await queue();
    failAlways = true;
    for (var i = 0; i < 8; i++) {
      await pass(after: Duration(hours: i));
    }
    expect((await row())!.retryCount, 8);
    expect((await row())!.permanentlyFailed, isFalse);

    await pass(after: const Duration(hours: 9));

    final waiting = (await row())!;
    expect(waiting.permanentlyFailed, isTrue);
    expect(waiting.lastError, isNot(contains('unavailable')));
    expect(taken, ['https://img/$rowId.jpg']);
    expect(asked, hasLength(8), reason: 'the ninth try never asks');
  });

  test('seven failed tries still get another', () async {
    await queue();
    failAlways = true;
    for (var i = 0; i < 7; i++) {
      await pass(after: Duration(hours: i));
    }
    failAlways = false;

    await pass(after: const Duration(hours: 8));

    expect(asked, hasLength(8));
    expect(await row(), isNull);
  });

  test('a row that does not say which picture it replaces cannot be placed: '
      'the upload is taken back', () async {
    await queue();
    await (db.update(db.uploadQueueEntries)..where((e) => e.id.equals(rowId)))
        .write(const UploadQueueEntriesCompanion(metadata: Value(null)));

    await pass();

    expect(asked, isEmpty);
    expect(taken, ['https://img/$rowId.jpg']);
    expect(await row(), isNull);
  });

  test(
    'a picture chosen later replaces one still waiting, in one step',
    () async {
      await queue();
      final first = rowId;
      final firstCopy = copyPath;

      await queue(base: 'https://img/other.jpg');

      expect(rowId, isNot(first));
      expect((await db.uploadQueueDao.getUpload(first)), isNull);
      expect(File(firstCopy).existsSync(), isFalse);
      expect(File(copyPath).existsSync(), isTrue);

      await pass();

      expect(asked, hasLength(1));
      expect(asked.single.expected, 'https://img/other.jpg');
    },
  );

  test(
    'a picture chosen later also replaces one that waits for the user',
    () async {
      await queue();
      await db.uploadQueueDao.markPermanentlyFailed(rowId);
      final first = rowId;

      await queue();

      expect(await db.uploadQueueDao.getUpload(first), isNull);
      await pass();
      expect(asked, hasLength(1));
    },
  );

  test('replacing a waiting picture leaves the same user\'s other unsent '
      'images and their copies alone', () async {
    final others = <String, String>{};
    for (final type in [
      SyncQueueEntityType.chatImage,
      SyncQueueEntityType.comment,
      SyncQueueEntityType.cookSnap,
    ]) {
      final file = File('${root.path}/$type.jpg')..writeAsBytesSync([2]);
      others['$type-row'] = file.path;
      await db.uploadQueueDao.queueUpload(
        id: '$type-row',
        userId: uid,
        localPath: file.path,
        targetPath: 'users/$uid/recipes',
        fileSizeBytes: 1,
        entityId: '$type-1',
        entityType: type,
      );
    }
    await queue();

    await queue();

    for (final entry in others.entries) {
      final kept = await db.uploadQueueDao.getUpload(entry.key);
      expect(kept, isNotNull, reason: entry.key);
      expect(kept!.status, isNot('cancelled'), reason: entry.key);
      expect(File(entry.value).existsSync(), isTrue, reason: entry.key);
    }
  });

  test('another user\'s waiting picture is left alone', () async {
    await queue();
    final mine = rowId;
    await db.uploadQueueDao.queueUpload(
      id: 'theirs',
      userId: 'u2',
      localPath: '/x.jpg',
      targetPath: 'users/u2/avatars',
      fileSizeBytes: 1,
      entityId: 'u2',
      entityType: SyncQueueEntityType.avatar,
    );

    await queue();

    expect(await db.uploadQueueDao.getUpload('theirs'), isNotNull);
    expect(await db.uploadQueueDao.getUpload(mine), isNull);
  });
}
