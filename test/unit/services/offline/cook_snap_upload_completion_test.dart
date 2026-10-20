// BUT-2294: a queued cook snap. Each photo is a row of one group named after
// the snap; the snap is created once, when every photo is in Storage.

import 'dart:convert';
import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/services/offline/cook_snap_upload_completion.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'queue_harness.dart' show MidRandom, firestoreError;

class _Repository extends Fake implements CookSnapRepository {
  final List<CookSnap> created = [];
  final Set<String> onServer = {};

  /// Thrown by the next creates, one per call, until empty.
  final List<Object> failures = [];

  /// Creates before this time are refused, as the five-second guard does.
  DateTime? refuseUntil;

  /// Whether a create that throws has reached the server all the same.
  bool landsDespiteFailure = false;

  /// Runs while the server is asked whether the snap is there.
  Future<void> Function()? whileAsking;

  @override
  Future<bool> ownSnapExists(String snapId) async {
    await whileAsking?.call();
    return onServer.contains(snapId);
  }

  @override
  Future<CookSnap> addCookSnap(CookSnap snap) async {
    final guard = refuseUntil;
    if (guard != null && clock.now().isBefore(guard)) {
      throw firestoreError('permission-denied');
    }
    if (failures.isNotEmpty) {
      if (landsDespiteFailure) onServer.add(snap.id);
      throw failures.removeAt(0);
    }
    created.add(snap);
    onServer.add(snap.id);
    return snap;
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  const uid = 'u1';
  final t0 = DateTime(2026, 10, 20, 12);

  late AppDatabase db;
  late Directory root;
  late OfflineUserStorage storage;
  late _Repository repository;
  late List<String> announced;
  late List<String> taken;
  late Set<String> uploadFails;
  late bool profileLoaded;
  late UploadQueueProcessor processor;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cook_snap_queue');
    storage = OfflineUserStorage(
      database: db,
      uploadsRoot: () async => Directory('${root.path}/queue'),
      copyImage: (source, base) => source.copy('$base.jpg'),
    );
    repository = _Repository();
    announced = [];
    taken = [];
    uploadFails = {};
    profileLoaded = true;
    processor = UploadQueueProcessor(
      database: db,
      storage: storage,
      upload: (String localPath, String userId, String objectId) async {
        if (uploadFails.contains(objectId)) throw firestoreError('unavailable');
        return (
          url: 'https://img/$objectId.jpg',
          thumbnailUrl: 'https://img/${objectId}_thumb.jpg',
        );
      },
      deleteUploaded: (UploadedImage image) async {
        taken.add(image.url);
        return true;
      },
      completions: {
        SyncQueueEntityType.cookSnap: CookSnapUploadCompletion(
          database: db,
          storage: storage,
          repository: () => repository,
          author: (_) {
            if (!profileLoaded) throw StateError('profile not loaded');
            return (displayName: 'Malin', avatarUrl: 'https://img/me');
          },
          announce:
              (
                snap, {
                required recipeAuthorId,
                required recipeName,
                required senderName,
              }) => announced.add('${snap.id}:$recipeAuthorId:$recipeName'),
        ),
      },
      random: MidRandom(),
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  /// Queues a snap of [photos] photos and returns its id and the rows' ids in
  /// the order the user picked them.
  Future<(String, List<String>)> queueSnap(
    String snapId, {
    int photos = 2,
    String? caption,
  }) async {
    final sources = <String>[];
    for (var i = 0; i < photos; i++) {
      final file = File('${root.path}/$snapId-$i.jpg');
      await file.writeAsBytes([i]);
      sources.add(file.path);
    }
    final ids = await withClock(
      Clock.fixed(t0),
      () => storage.queueImageGroupForUser(
        imagePaths: sources,
        entityType: SyncQueueEntityType.cookSnap,
        entityId: snapId,
        userId: uid,
        targetPath: 'users/$uid/recipes',
        metadata: cookSnapQueueMetadata(
          recipeId: 'recipe-1',
          recipeAuthorId: 'author-1',
          recipeName: 'Kladdkaka',
          visibility: CookSnapVisibility.onlyMe,
          caption: caption,
        ),
      ),
    );
    return (snapId, ids);
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

  Future<UploadQueueEntry?> row(String id) => db.uploadQueueDao.getUpload(id);

  test('an album is created once, with the photos in the order they were '
      'picked and the cover first, even when the rows tie on time', () async {
    final (snapId, ids) = await queueSnap(
      'snap-1',
      photos: 3,
      caption: 'Mums',
    );
    // The table lists the rows in the reverse of the pick order, so only the
    // rows' own `order` can put the photos right.
    for (var i = 0; i < ids.length; i++) {
      await (db.update(
        db.uploadQueueEntries,
      )..where((e) => e.id.equals(ids[i]))).write(
        UploadQueueEntriesCompanion(
          queuedAt: Value(t0.subtract(Duration(seconds: i))),
        ),
      );
    }

    await pass();

    expect(repository.created, hasLength(1));
    final snap = repository.created.single;
    expect(snap.id, snapId);
    expect(snap.photoUrls, [for (final id in ids) 'https://img/$id.jpg']);
    expect(snap.thumbnailUrl, 'https://img/${ids.first}_thumb.jpg');
    expect(snap.caption, 'Mums');
    expect(snap.visibility, CookSnapVisibility.onlyMe);
    expect(snap.userDisplayName, 'Malin');
    expect(snap.userAvatarUrl, 'https://img/me');
    expect(announced, ['snap-1:author-1:Kladdkaka']);
    for (final id in ids) {
      expect(await row(id), isNull);
    }
    expect(
      await root.list(recursive: true).where((f) => f is File).toList(),
      hasLength(3),
    ); // the picker's own files; the queue's copies are gone
  });

  test('nothing is created while a photo is still on its way, and the '
      'photos already up are not uploaded again', () async {
    final (_, ids) = await queueSnap('snap-1');
    uploadFails.add(ids.last);

    await pass();

    expect(repository.created, isEmpty);
    final uploaded = (await row(ids.first))!;
    expect(uploaded.status, 'uploaded');
    // Waiting for the group is not a failed attempt.
    expect(uploaded.retryCount, 0);
    expect(uploaded.lastError, isNull);

    uploadFails.clear();
    await pass(after: const Duration(minutes: 1));

    expect(repository.created, hasLength(1));
    expect(repository.created.single.photoUrls, hasLength(2));
  });

  test('a snap that is already on the server is not created again and its '
      'photos stay', () async {
    final (snapId, ids) = await queueSnap('snap-1');
    repository.onServer.add(snapId);

    await pass();

    expect(repository.created, isEmpty);
    expect(announced, isEmpty);
    expect(taken, isEmpty);
    for (final id in ids) {
      expect(await row(id), isNull);
    }
  });

  test('a second snap waits out the five seconds the rules insist on '
      'without counting as a failed attempt', () async {
    final (_, first) = await queueSnap('snap-1', photos: 1);
    final (_, second) = await queueSnap('snap-2', photos: 1);

    await pass();

    expect(repository.created.map((s) => s.id), ['snap-1']);
    final waiting = (await row(second.single))!;
    expect(waiting.status, 'uploaded');
    expect(waiting.retryCount, 0);
    expect(waiting.firstFailedAt, isNull);
    expect(waiting.nextAttemptAt, isNotNull);
    expect(await row(first.single), isNull);

    await pass(after: const Duration(seconds: 7));

    expect(repository.created.map((s) => s.id), ['snap-1', 'snap-2']);
  });

  test('a refused create is given one more try after the spacing, in case '
      'the refusal was the five-second guard, and is final the second '
      'time', () async {
    final (_, ids) = await queueSnap('snap-1', photos: 1);
    repository.failures.addAll([
      firestoreError('permission-denied'),
      firestoreError('permission-denied'),
    ]);

    await pass();
    final held = (await row(ids.single))!;
    expect(held.status, 'uploaded');
    expect(held.permanentlyFailed, isFalse);
    expect(taken, isEmpty);

    await pass(after: const Duration(seconds: 7));

    final refused = (await row(ids.single))!;
    expect(refused.permanentlyFailed, isTrue);
    expect(repository.created, isEmpty);
    expect(taken, ['https://img/${ids.single}.jpg']);
    expect(announced, isEmpty);
  });

  test('every photo of an album waits out the first refusal: the second row '
      'of the same pass does not spend the one extra try', () async {
    final (_, ids) = await queueSnap('snap-1', photos: 3);
    // Every photo is up already, as after a restart, so every row of the
    // album reaches the create in the same pass.
    for (final id in ids) {
      await db.uploadQueueDao.markUploaded(
        id,
        url: 'https://img/$id.jpg',
        thumbnailUrl: 'https://img/${id}_thumb.jpg',
      );
    }
    repository.refuseUntil = t0.add(const Duration(seconds: 5));

    await pass();

    for (final id in ids) {
      final held = (await row(id))!;
      expect(held.status, 'uploaded');
      expect(held.permanentlyFailed, isFalse);
    }
    expect(taken, isEmpty);

    await pass(after: const Duration(seconds: 7));

    expect(repository.created, hasLength(1));
    expect(repository.created.single.photoUrls, hasLength(3));
  });

  test('a photo thrown away after the snap reached the server does not take '
      'the rest of the album with it', () async {
    final (snapId, ids) = await queueSnap('snap-1', photos: 3);
    repository.onServer.add(snapId);
    await db.uploadQueueDao.cancelUpload(ids.last);

    await pass();

    expect(repository.created, isEmpty);
    expect(taken, isNot(contains('https://img/${ids.first}.jpg')));
    expect(taken, isNot(contains('https://img/${ids[1]}.jpg')));
    for (final id in ids) {
      expect(await row(id), isNull);
    }
  });

  test('a refusal after which the snap is found on the server is a success '
      'that does not announce itself twice', () async {
    final (_, ids) = await queueSnap('snap-1', photos: 1);
    repository
      ..landsDespiteFailure = true
      ..failures.add(firestoreError('permission-denied'));

    await pass();

    expect(announced, isEmpty);
    expect(taken, isEmpty);
    expect(await row(ids.single), isNull);
  });

  test('a snap thrown away while the server is asked about it is not '
      'created', () async {
    final (_, ids) = await queueSnap('snap-1');
    repository.whileAsking = () async {
      for (final id in ids) {
        await db.uploadQueueDao.cancelUpload(id);
      }
    };

    await pass();

    expect(repository.created, isEmpty);
    expect(announced, isEmpty);
  });

  test('one photo thrown away while the server is asked about the snap '
      'stops the snap and throws the album away', () async {
    final (_, ids) = await queueSnap('snap-1', photos: 3);
    repository.whileAsking = () async {
      repository.whileAsking = null;
      await db.uploadQueueDao.cancelUpload(ids.first);
    };

    await pass();
    await pass(after: const Duration(minutes: 1));

    expect(repository.created, isEmpty);
    expect(announced, isEmpty);
    expect(
      taken,
      unorderedEquals([for (final id in ids) 'https://img/$id.jpg']),
    );
  });

  test('a failure the server does not mean as a refusal is retried on the '
      'queue schedule and the photos are not uploaded again', () async {
    final (_, ids) = await queueSnap('snap-1', photos: 1);
    repository.failures.add(firestoreError('unavailable'));

    await pass();

    final waiting = (await row(ids.single))!;
    expect(waiting.status, 'uploaded');
    expect(waiting.retryCount, 1);
    expect(repository.created, isEmpty);

    await pass(after: const Duration(minutes: 5));

    expect(repository.created, hasLength(1));
  });

  test('throwing one photo away throws the whole album away and takes its '
      'photos back out of Storage', () async {
    final (_, ids) = await queueSnap('snap-1', photos: 3);
    uploadFails.add(ids.last);
    await pass();
    await db.uploadQueueDao.cancelUpload(ids.last);
    uploadFails.clear();

    await pass(after: const Duration(minutes: 1));
    await pass(after: const Duration(minutes: 2));

    expect(repository.created, isEmpty);
    expect(
      taken,
      unorderedEquals([
        'https://img/${ids[0]}.jpg',
        'https://img/${ids[1]}.jpg',
      ]),
    );
  });

  test('a snap thrown away before it was created is never created', () async {
    final (_, ids) = await queueSnap('snap-1');
    for (final id in ids) {
      await db.uploadQueueDao.cancelUpload(id);
    }

    await pass();

    expect(repository.created, isEmpty);
    expect(announced, isEmpty);
  });

  test('a snap is not published before the author is known; it is tried '
      'again once the profile has loaded', () async {
    final (_, ids) = await queueSnap('snap-1', photos: 1);
    profileLoaded = false;

    await pass();

    expect(repository.created, isEmpty);
    expect((await row(ids.single))!.status, 'uploaded');

    profileLoaded = true;
    await pass(after: const Duration(minutes: 5));

    expect(repository.created.single.userDisplayName, 'Malin');
  });

  test('queueing a group leaves no copies behind when the rows cannot be '
      'written', () async {
    final photo = File('${root.path}/photo.jpg')..writeAsBytesSync([1]);

    await expectLater(
      storage.queueImageGroupForUser(
        imagePaths: [photo.path, photo.path],
        entityType: SyncQueueEntityType.cookSnap,
        entityId: 'snap-y',
        userId: uid,
        targetPath: 'users/$uid/recipes',
        // Cannot be written as JSON, so the transaction fails.
        metadata: {'bad': Object()},
      ),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );

    expect(
      await db.uploadQueueDao.getGroup(
        uid,
        SyncQueueEntityType.cookSnap,
        'snap-y',
      ),
      isEmpty,
    );
    final queueDir = Directory('${root.path}/queue/$uid');
    expect(queueDir.listSync(), isEmpty);
  });

  test('queueing a group is all or nothing: a picture that cannot be copied '
      'leaves no rows and no copies behind', () async {
    final good = File('${root.path}/good.jpg')..writeAsBytesSync([1]);
    final broken = OfflineUserStorage(
      database: db,
      uploadsRoot: () async => Directory('${root.path}/queue'),
      copyImage: (source, base) async {
        if (source.path.endsWith('bad.jpg')) {
          // Stops half way through writing its copy.
          File('$base.jpg').writeAsBytesSync([9]);
          throw const FileSystemException();
        }
        return source.copy('$base.jpg');
      },
    );

    await expectLater(
      broken.queueImageGroupForUser(
        imagePaths: [good.path, '${root.path}/bad.jpg'],
        entityType: SyncQueueEntityType.cookSnap,
        entityId: 'snap-x',
        userId: uid,
        targetPath: 'users/$uid/recipes',
        metadata: const {},
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(
      await db.uploadQueueDao.getGroup(
        uid,
        SyncQueueEntityType.cookSnap,
        'snap-x',
      ),
      isEmpty,
    );
    final queueDir = Directory('${root.path}/queue/$uid');
    expect(
      queueDir.existsSync() ? queueDir.listSync() : const [],
      isEmpty,
    );
  });
}
