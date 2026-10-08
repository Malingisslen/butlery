// BUT-2162: the upload queue. A recipe image the form could not upload waits
// on the device and goes up under the sync queue's rules
// (produktregler.md:185-192); once it is up, its address reaches the recipe
// on the server through the sync queue.

import 'dart:convert';
import 'dart:io';

import 'package:butlery/core/exceptions/storage_upload_exception.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/queued_recipe_writer.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';
import 'queue_harness.dart' show MidRandom, QueueHarness, firestoreError;

/// What reached the "server": every recipe write, with the recipe as sent.
class _Writer implements QueuedRecipeWriter {
  final List<(String, Recipe?)> writes = [];
  final Map<String, Object> failWith = {};

  Future<void> _write(String op, String id, Recipe? recipe) async {
    final failure = failWith[id];
    if (failure != null) throw failure;
    writes.add((op, recipe));
  }

  @override
  Future<int> create(Recipe recipe) async {
    await _write('create', recipe.id, recipe);
    return 0;
  }

  @override
  Future<int> update(Recipe recipe) async {
    await _write('update', recipe.id, recipe);
    return (recipe.rev ?? 0) + 1;
  }

  @override
  Future<void> delete(String recipeId) => _write('delete', recipeId, null);
}

void main() {
  const uid = 'u1';
  final t0 = DateTime(2026, 10, 7, 12);

  late AppDatabase db;
  late Directory root;
  late OfflineUserStorage storage;
  late OfflineSyncManager manager;
  late _Writer writer;
  late FakeAuthRepository auth;
  late List<String> uploadedPaths;
  Object? uploadFailure;
  void Function()? onUploaded;

  Future<UploadedImage> upload(String localPath, String userId) async {
    final failure = uploadFailure;
    if (failure != null) throw failure;
    uploadedPaths.add(localPath);
    onUploaded?.call();
    final name = localPath.split('/').last;
    return (url: 'https://img/$name', thumbnailUrl: 'https://thumb/$name');
  }

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    QueueHarness.registerFallbacks();
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('uploads');
    storage = OfflineUserStorage(database: db, uploadsRoot: () async => root);
    writer = _Writer();
    uploadedPaths = [];
    uploadFailure = null;
    onUploaded = null;
    auth = FakeAuthRepository()
      ..setAuthState(user: FakeUser(), userId: uid, isAuthenticated: true);
    manager = OfflineSyncManager(
      database: db,
      authRepository: auth,
      isOnlineNow: () => false,
      random: MidRandom(),
      recipeWriter: writer,
      uploadImage: upload,
      userStorage: storage,
    );
  });

  tearDown(() async {
    manager.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> pass({DateTime? at, bool force = false}) => withClock(
    Clock.fixed(at ?? t0),
    () => manager.syncPendingChanges(isOnline: true, force: force),
  );

  /// A recipe saved offline: on the device, its create queued.
  Future<void> saveOffline(String recipeId) => withClock(
    Clock.fixed(t0),
    () => storage.saveRecipeForUser(
      RecipeFactory.build(id: recipeId, createdBy: uid),
      uid,
      operation: SyncOperation.create,
      queueTagging: false,
    ),
  );

  /// A picked image, outside the queue's folder, queued for [recipeId].
  Future<String> queueImage(String recipeId) async {
    final picked = File('${Directory.systemTemp.path}/picked-$recipeId.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() {
      if (picked.existsSync()) picked.deleteSync();
    });
    return withClock(
      Clock.fixed(t0),
      () => storage.queueRecipeImageForUser(picked.path, recipeId, uid),
    );
  }

  Future<UploadQueueEntry?> uploadRow(String id) => (db.select(
    db.uploadQueueEntries,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<Recipe> deviceRecipe(String recipeId) async {
    final stored = await db.recipeDao.getRecipe(recipeId, uid);
    return Recipe.fromJson(
      jsonDecode(stored!.recipeJson) as Map<String, dynamic>,
    );
  }

  test('keeps its own copy of the image, in a folder per user', () async {
    await saveOffline('r1');
    final id = await queueImage('r1');

    final row = (await uploadRow(id))!;
    expect(row.localPath, startsWith('${root.path}/$uid/'));
    expect(File(row.localPath).existsSync(), isTrue);
    expect(row.entityId, 'r1');
    expect(row.fileSizeBytes, 3);
  });

  test('in one pass the recipe is created, the image goes up and the '
      'recipe on the server gets its address', () async {
    await saveOffline('r1');
    final id = await queueImage('r1');
    final copy = (await uploadRow(id))!.localPath;

    await pass();

    expect(writer.writes.map((w) => w.$1), ['create', 'update']);
    final updated = writer.writes.last.$2!;
    final name = copy.split('/').last;
    expect(updated.imageUrls, ['https://img/$name']);
    expect(updated.core.thumbnailUrl, 'https://thumb/$name');
    expect((await deviceRecipe('r1')).imageUrls, ['https://img/$name']);
    expect(await uploadRow(id), isNull, reason: 'the upload is done');
    expect(File(copy).existsSync(), isFalse, reason: 'its copy is removed');
    expect(await db.syncQueueDao.hasPending(uid), isFalse);
  });

  test('an image waits for the create of its recipe', () async {
    await saveOffline('r1');
    final id = await queueImage('r1');
    writer.failWith['r1'] = firestoreError('unavailable');

    await pass();

    expect(uploadedPaths, isEmpty);
    expect((await uploadRow(id))!.status, 'pending');
  });

  test('a create that fails for good takes its image with it', () async {
    await saveOffline('r1');
    final id = await queueImage('r1');
    writer.failWith['r1'] = firestoreError('permission-denied');

    await pass();

    expect(uploadedPaths, isEmpty);
    final row = (await uploadRow(id))!;
    expect(row.permanentlyFailed, isTrue);
    expect(row.lastError, 'dependency-failed');
  });

  test(
    'a network failure is tried again on the schedule, not before',
    () async {
      await saveOffline('r1');
      final id = await queueImage('r1');
      uploadFailure = const StorageUploadException(
        'network-request-failed',
        'offline',
      );

      await pass();

      final row = (await uploadRow(id))!;
      expect(row.permanentlyFailed, isFalse);
      expect(row.retryCount, 1);
      expect(row.lastError, 'network-request-failed');
      expect(row.firstFailedAt, t0);
      final next = row.nextAttemptAt!;
      expect(next.isAfter(t0), isTrue);

      uploadFailure = null;
      await pass(at: next.subtract(const Duration(milliseconds: 1)));
      expect(uploadedPaths, isEmpty, reason: 'its time has not come');

      await pass(at: next);
      expect(uploadedPaths, hasLength(1));
      expect(await uploadRow(id), isNull);
    },
  );

  test('a too-large image fails for good and keeps its copy for "Försök '
      'mindre"', () async {
    await saveOffline('r1');
    final id = await queueImage('r1');
    uploadFailure = const StorageUploadException(
      StorageUploadException.tooLargeCode,
      'big',
    );

    await pass();

    final row = (await uploadRow(id))!;
    expect(row.permanentlyFailed, isTrue);
    expect(row.lastError, 'too-large');
    expect(File(row.localPath).existsSync(), isTrue);
  });

  test('after 24 h of failures an image fails for good', () async {
    await saveOffline('r1');
    final id = await queueImage('r1');
    uploadFailure = StateError('Image upload failed');

    await pass();
    await pass(at: t0.add(const Duration(hours: 24, seconds: 1)), force: true);

    final row = (await uploadRow(id))!;
    expect(row.permanentlyFailed, isTrue);
    expect(row.lastError, 'retries-exhausted');
  });

  test('an image is not sent for a user who signed out mid-pass', () async {
    await saveOffline('r1');
    await queueImage('r1');
    writer.failWith.clear();
    // The create's send is where the account changes.
    final switching = _SwitchingWriter(writer, () {
      auth.setAuthState(user: FakeUser(), userId: 'u2', isAuthenticated: true);
    });
    manager.recipeWriter = switching;

    await pass();

    expect(uploadedPaths, isEmpty);
  });

  test('an account change between two uploads stops the rest', () async {
    await saveOffline('r1');
    await queueImage('r1');
    final picked = File('${Directory.systemTemp.path}/picked-r1-b.jpg')
      ..writeAsBytesSync([4, 5]);
    addTearDown(picked.deleteSync);
    await withClock(
      Clock.fixed(t0.add(const Duration(seconds: 1))),
      () => storage.queueRecipeImageForUser(picked.path, 'r1', uid),
    );
    onUploaded = () => auth.setAuthState(
      user: FakeUser(),
      userId: 'u2',
      isAuthenticated: true,
    );

    await pass();

    expect(uploadedPaths, hasLength(1));
  });

  test('an image whose address cannot reach its recipe is not uploaded '
      'again', () async {
    await saveOffline('r1');
    final id = await queueImage('r1');
    await pass();
    // A new image of a recipe whose device copy cannot be read.
    final id2 = await queueImage('r2');
    await db.recipeDao.upsertRecipe(
      id: 'r2',
      userId: uid,
      recipeJson: '{',
      needsSync: false,
    );
    expect(await uploadRow(id), isNull);

    await pass(at: t0.add(const Duration(minutes: 1)));
    await pass(at: t0.add(const Duration(hours: 1)), force: true);

    expect(uploadedPaths, hasLength(2), reason: 'r1 once, r2 once');
    final row = (await uploadRow(id2))!;
    expect(row.permanentlyFailed, isTrue);
  });

  test('a recipe that already has a thumbnail keeps it', () async {
    final recipe = RecipeFactory.build(id: 'r1', createdBy: uid);
    recipe.core.thumbnailUrl = 'https://thumb/own.jpg';
    await withClock(
      Clock.fixed(t0),
      () => storage.saveRecipeForUser(
        recipe,
        uid,
        operation: SyncOperation.create,
        queueTagging: false,
      ),
    );
    await queueImage('r1');

    await pass();

    expect(
      writer.writes.last.$2!.core.thumbnailUrl,
      'https://thumb/own.jpg',
    );
  });

  test('"Försök synka nu" counts an upload once, not with the edit it '
      'queues', () async {
    await saveOffline('r1');
    await queueImage('r1');
    await saveOffline('r2');
    await pass();
    writer.writes.clear();
    // r3's create fails and waits for its retry.
    await saveOffline('r3');
    writer.failWith['r3'] = firestoreError('unavailable');
    await queueImage('r2');

    final result = await withClock(
      Clock.fixed(t0.add(const Duration(minutes: 1))),
      () => manager.syncNow(isOnline: true),
    );

    expect(result.isRetry, isTrue, reason: 'r3 still waits');
  });

  test('deleting the recipe cancels its image and removes the copy', () async {
    await saveOffline('r1');
    final id = await queueImage('r1');
    final copy = (await uploadRow(id))!.localPath;

    await storage.queueDeleteForUser('r1', uid);

    expect((await uploadRow(id))!.status, 'cancelled');
    expect(File(copy).existsSync(), isFalse);

    await pass();
    expect(uploadedPaths, isEmpty);
  });

  test('clearing a user leaves nothing of their images on the device, and '
      'nothing of anyone else\'s goes', () async {
    await saveOffline('r1');
    final id = await queueImage('r1');
    final copy = (await uploadRow(id))!.localPath;
    final otherDir = Directory.systemTemp.createTempSync('picked-other');
    addTearDown(() => otherDir.deleteSync(recursive: true));
    final other = File('${otherDir.path}/picked-other.jpg')
      ..writeAsBytesSync([9]);
    final otherId = await withClock(
      Clock.fixed(t0),
      () => storage.queueRecipeImageForUser(other.path, 'r9', 'u2'),
    );

    await storage.clearUserData(uid);

    final rows = await db.select(db.uploadQueueEntries).get();
    expect(rows.where((r) => r.userId == uid), isEmpty);
    expect(File(copy).existsSync(), isFalse);
    expect(Directory('${root.path}/$uid').existsSync(), isFalse);
    final kept = (await uploadRow(otherId))!;
    expect(File(kept.localPath).existsSync(), isTrue);
  });

  test('a waiting image counts as a queued change', () async {
    await saveOffline('r1');
    await queueImage('r1');

    expect(await manager.queuedChangesCount, 2);
    expect(await manager.hasQueuedChanges, isTrue);
  });
}

/// Calls [onCreate] after the create reaches the server.
class _SwitchingWriter implements QueuedRecipeWriter {
  _SwitchingWriter(this._inner, this._onCreate);

  final QueuedRecipeWriter _inner;
  final void Function() _onCreate;

  @override
  Future<int> create(Recipe recipe) async {
    final rev = await _inner.create(recipe);
    _onCreate();
    return rev;
  }

  @override
  Future<int> update(Recipe recipe) => _inner.update(recipe);

  @override
  Future<void> delete(String recipeId) => _inner.delete(recipeId);
}
