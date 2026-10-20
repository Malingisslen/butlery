// BUT-2294 (G1): clearing a user's data ("Logga ut och släng", account
// deletion) must not race a pass that is publishing the same images, and
// must take back what the queue already put in Storage.

import 'dart:async';
import 'dart:io';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/queued_recipe_writer.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';
import 'queue_harness.dart' show MidRandom, QueueHarness;

/// Accepts every recipe write, so the queued images can go up after it.
class _Writer implements QueuedRecipeWriter {
  @override
  Future<int> create(Recipe recipe) async => 0;

  @override
  Future<int> update(Recipe recipe) async => (recipe.rev ?? 0) + 1;

  @override
  Future<void> delete(String recipeId) async {}
}

void main() {
  const uid = 'u1';
  final t0 = DateTime(2026, 10, 20, 8);

  late AppDatabase db;
  late Directory root;
  late OfflineUserStorage storage;
  late OfflineSyncManager manager;
  late List<String> events;
  late List<String> taken;
  Completer<void>? uploadGate;
  var deleterHangs = false;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    QueueHarness.registerFallbacks();
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('clear_user');
    storage = OfflineUserStorage(database: db, uploadsRoot: () async => root);
    events = [];
    taken = [];
    uploadGate = null;
    deleterHangs = false;
    final auth = FakeAuthRepository()
      ..setAuthState(user: FakeUser(), userId: uid, isAuthenticated: true);
    manager = OfflineSyncManager(
      database: db,
      authRepository: auth,
      isOnlineNow: () => false,
      random: MidRandom(),
      uploadImage:
          (
            String localPath,
            String userId,
            String objectId,
            String targetPath,
          ) async {
            events.add('upload started');
            await uploadGate?.future;
            events.add('upload done');
            return (url: 'https://img/$objectId.jpg', thumbnailUrl: null);
          },
      deleteUploadedImage: (UploadedImage image) async {
        taken.add(image.url);
        if (deleterHangs) return Completer<bool>().future;
        return true;
      },
      recipeWriter: _Writer(),
      clearPatience: const Duration(milliseconds: 200),
      userStorage: storage,
    );
  });

  tearDown(() async {
    manager.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> pass() => withClock(
    Clock.fixed(t0),
    () => manager.syncPendingChanges(isOnline: true),
  );

  Future<void> queueImage(String recipeId) async {
    await withClock(
      Clock.fixed(t0),
      () => storage.saveRecipeForUser(
        RecipeFactory.build(id: recipeId, createdBy: uid),
        uid,
        operation: SyncOperation.create,
        queueTagging: false,
      ),
    );
    final picked = File('${Directory.systemTemp.path}/clear-$recipeId.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() {
      if (picked.existsSync()) picked.deleteSync();
    });
    await withClock(
      Clock.fixed(t0),
      () => storage.queueRecipeImageForUser(picked.path, recipeId, uid),
    );
  }

  test('a clear waits for the pass in flight and runs after it', () async {
    await queueImage('r1');
    uploadGate = Completer<void>();
    final running = pass();
    await pumpEventQueue();
    expect(events, ['upload started']);

    final cleared = manager.clearUserData(uid, () async {
      events.add('clear');
    });
    await pumpEventQueue();
    expect(events, ['upload started'], reason: 'the clear must still wait');

    uploadGate!.complete();
    await running;
    await cleared;

    expect(events, ['upload started', 'upload done', 'clear']);
  });

  test('no pass starts while the data is being cleared', () async {
    await queueImage('r1');
    final inClear = Completer<void>();
    final releaseClear = Completer<void>();

    final cleared = manager.clearUserData(uid, () async {
      inClear.complete();
      await releaseClear.future;
    });
    await inClear.future;
    await pass();

    expect(events, isEmpty, reason: 'nothing may upload during a clear');

    releaseClear.complete();
    await cleared;
    await pass();

    expect(events, ['upload started', 'upload done']);
  });

  test('images the queue already put in Storage are taken back before the '
      'rows are cleared', () async {
    await queueImage('r1');
    final row = (await db.select(db.uploadQueueEntries).get()).single;
    await db.uploadQueueDao.markUploaded(row.id, url: 'https://img/r1.jpg');

    await manager.clearUserData(uid, () async {
      events.add('clear');
      expect(taken, ['https://img/r1.jpg']);
    });

    expect(events, ['clear']);
  });

  test(
    'a second clear ending does not reopen the gate for the first',
    () async {
      await queueImage('r1');
      final inFirst = Completer<void>();
      final releaseFirst = Completer<void>();

      final first = manager.clearUserData(uid, () async {
        inFirst.complete();
        await releaseFirst.future;
      });
      await inFirst.future;
      await manager.clearUserData(uid, () async {});
      await pass();

      expect(events, isEmpty, reason: 'the first clear is still running');

      releaseFirst.complete();
      await first;
    },
  );

  test('a clear does not hang on a take-back that never answers', () async {
    await queueImage('r1');
    final row = (await db.select(db.uploadQueueEntries).get()).single;
    await db.uploadQueueDao.markUploaded(row.id, url: 'https://img/r1.jpg');
    deleterHangs = true;

    await manager.clearUserData(uid, () async => events.add('clear'));

    expect(events, ['clear']);
  });

  test('a clear does not hang on a pass that never ends', () async {
    await queueImage('r1');
    uploadGate = Completer<void>();
    unawaited(pass());
    await pumpEventQueue();

    await manager.clearUserData(uid, () async => events.add('clear'));

    expect(events, ['upload started', 'clear']);
  });
}
