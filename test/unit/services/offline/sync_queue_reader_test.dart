// P4-U19: the queue view's read of schema 3 (P5-U35), and its two actions.
//
// produktregler.md:190: count, what the changes concern, their age, and the
// permanent failures first. :187: a chain fails whole, never halfway. :192:
// nothing leaves the queue without the server or the user.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/sync_queue_reader.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  late AppDatabase db;
  final t0 = DateTime(2026, 9, 27, 12);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> recipe(String id, String title, {String user = 'u1'}) => db
      .into(db.offlineRecipes)
      .insert(
        OfflineRecipesCompanion.insert(
          id: id,
          userId: user,
          recipeJson: '{"id":"$id","title":"$title"}',
          updatedAt: t0,
        ),
      );

  Future<void> enqueue(
    String opId,
    String recipeId,
    SyncOperation op, {
    DateTime? at,
    List<String> dependsOn = const [],
    String user = 'u1',
  }) => withClock(
    Clock.fixed(at ?? t0),
    () => db.syncQueueDao.enqueue(
      userId: user,
      recipeId: recipeId,
      operation: op,
      opId: opId,
      dependsOn: dependsOn,
    ),
  );

  test('reads both queues for the user only, with titles and kinds', () async {
    await recipe('r1', 'Citronrisotto');
    await enqueue('op-1', 'r1', SyncOperation.update);
    await enqueue('op-x', 'r9', SyncOperation.create, user: 'u2');
    await withClock(
      Clock.fixed(t0),
      () => db.uploadQueueDao.queueUpload(
        id: 'up-1',
        userId: 'u1',
        localPath: '/a.jpg',
        targetPath: 'x/a.jpg',
        fileSizeBytes: 10,
        entityId: 'r1',
        entityType: 'recipe',
      ),
    );

    final changes = await readQueuedChanges(db, 'u1');
    expect(changes.map((c) => c.id), unorderedEquals(['op-1', 'up-1']));
    final write = changes.firstWhere((c) => c.id == 'op-1');
    expect(write.kind, QueuedChangeKind.recipe);
    expect(write.operation, QueuedOperation.update);
    expect(write.subject, 'Citronrisotto');
    expect(write.queuedAt, t0);
    expect(write.needsUser, isFalse);
    final image = changes.firstWhere((c) => c.id == 'up-1');
    expect(image.kind, QueuedChangeKind.image);
    expect(image.subject, 'Citronrisotto');
  });

  test('a recipe the device has no copy of has no subject', () async {
    await enqueue('op-1', 'unknown', SyncOperation.delete);
    final changes = await readQueuedChanges(db, 'u1');
    expect(changes.single.subject, isNull);
    expect(changes.single.operation, QueuedOperation.delete);
  });

  test('permanent failures come first, each group oldest first', () async {
    await enqueue('late', 'r1', SyncOperation.update, at: t0);
    await enqueue(
      'early',
      'r2',
      SyncOperation.update,
      at: t0.subtract(const Duration(hours: 1)),
    );
    await enqueue(
      'failed',
      'r3',
      SyncOperation.update,
      at: t0.add(const Duration(hours: 1)),
    );
    await db.syncQueueDao.markPermanentlyFailed('failed', reason: 'not-found');

    final queue = QueueSnapshot(await readQueuedChanges(db, 'u1'));
    expect(queue.needsUser.map((c) => c.id), ['failed']);
    expect(queue.needsUser.single.reason, QueuedChangeReason.notFound);
    expect(queue.draining.map((c) => c.id), ['early', 'late']);
    expect(queue.total, 3);
  });

  test('a raw error is never a reason', () {
    expect(
      QueuedChangeReason.parse('SocketException: failed host lookup'),
      QueuedChangeReason.unknown,
    );
    expect(QueuedChangeReason.parse(null), QueuedChangeReason.unknown);
    for (final reason in QueuedChangeReason.values) {
      if (reason == QueuedChangeReason.unknown) continue;
      expect(QueuedChangeReason.parse(reason.code), reason);
    }
  });

  test('an entry waiting on a queued one says so', () async {
    await enqueue('add', 'r1', SyncOperation.create);
    await enqueue('check', 'r1', SyncOperation.update, dependsOn: ['add']);
    final changes = await readQueuedChanges(db, 'u1');
    expect(changes.firstWhere((c) => c.id == 'check').waitsOnEarlier, isTrue);
    expect(changes.firstWhere((c) => c.id == 'add').waitsOnEarlier, isFalse);
  });

  test('Försök igen puts a permanent failure back in the queue', () async {
    await enqueue('op-1', 'r1', SyncOperation.update);
    await db.syncQueueDao.markPermanentlyFailed('op-1', reason: 'not-found');
    final failed = (await readQueuedChanges(db, 'u1')).single;
    expect(failed.needsUser, isTrue);

    await retryQueuedChange(db, failed);

    final again = (await readQueuedChanges(db, 'u1')).single;
    expect(again.needsUser, isFalse);
    expect(await db.syncQueueDao.countPending('u1'), 1);
  });

  test('Släng removes only the chosen change and fails its chain', () async {
    await enqueue('add', 'r1', SyncOperation.create);
    await enqueue('check', 'r1', SyncOperation.update, dependsOn: ['add']);
    await enqueue('other', 'r2', SyncOperation.update);
    await db.syncQueueDao.markPermanentlyFailed('add', reason: 'not-found');
    final add = (await readQueuedChanges(
      db,
      'u1',
    )).firstWhere((c) => c.id == 'add');

    await discardQueuedChange(db, 'u1', add);

    final queue = QueueSnapshot(await readQueuedChanges(db, 'u1'));
    expect(queue.needsUser.map((c) => c.id), ['check']);
    expect(queue.needsUser.single.reason, QueuedChangeReason.dependencyFailed);
    expect(queue.draining.map((c) => c.id), ['other']);
  });

  // Q6-11 = B (produktbeslut 2026-09-27b): a new recipe the server never had
  // exists only on this phone, so Släng (after its confirmation) takes the
  // device's copy with it rather than leaving it to never be sent.
  test('Släng on a phone-only new recipe takes the recipe with it', () async {
    await recipe('r1', 'Kålpudding');
    await recipe('r2', 'Pannbiffar');
    await enqueue('new', 'r1', SyncOperation.create);
    await enqueue('edit', 'r2', SyncOperation.update);
    await db.syncQueueDao.markPermanentlyFailed('new', reason: 'not-found');
    await db.syncQueueDao.markPermanentlyFailed('edit', reason: 'not-found');
    final all = await readQueuedChanges(db, 'u1');
    final created = all.firstWhere((c) => c.id == 'new');
    final changed = all.firstWhere((c) => c.id == 'edit');
    expect(created.isNeverSyncedRecipe, isTrue);
    expect(created.canDiscard, isTrue);
    expect(created.discardAsksFirst, isTrue);
    expect(changed.discardAsksFirst, isFalse);

    await discardQueuedChange(db, 'u1', created);
    await discardQueuedChange(db, 'u1', changed);

    expect(await db.recipeDao.getRecipe('r1', 'u1'), isNull);
    expect(
      await db.recipeDao.getRecipe('r2', 'u1'),
      isNotNull,
      reason: 'a change to a recipe the server has keeps the device copy',
    );
    expect(await readQueuedChanges(db, 'u1'), isEmpty);
  });

  test('Släng on an image cancels the upload and it stops counting', () async {
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
    await db.uploadQueueDao.markPermanentlyFailed('up-1', reason: 'too-large');
    final image = (await readQueuedChanges(db, 'u1')).single;
    expect(image.reason, QueuedChangeReason.tooLarge);

    await discardQueuedChange(db, 'u1', image);

    expect(await readQueuedChanges(db, 'u1'), isEmpty);
    final counts = await db.watchQueueCounts('u1').first;
    expect(counts.waiting, 0);
  });

  test('the view and the counts agree on the number', () async {
    await enqueue('a', 'r1', SyncOperation.update);
    await enqueue('b', 'r2', SyncOperation.update);
    await db.syncQueueDao.markPermanentlyFailed('b');
    final queue = QueueSnapshot(await readQueuedChanges(db, 'u1'));
    final counts = await db.watchQueueCounts('u1').first;
    expect(queue.total, counts.waiting);
    expect(queue.needsUser.length, counts.needsUser);
  });

  test('the live read follows the queue', () async {
    final seen = <int>[];
    final sub = watchQueuedChanges(db, 'u1').listen((c) => seen.add(c.length));
    await pumpEventQueue();
    await enqueue('a', 'r1', SyncOperation.update);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.first, 0);
    expect(seen.last, 1);
  });

  // ── P6-U08b ────────────────────────────────────────────────────────────

  test('a failed change carries its next attempt; a permanent failure does '
      'not', () async {
    await enqueue('a', 'r1', SyncOperation.update);
    await enqueue('b', 'r2', SyncOperation.update);
    final rows = await db.select(db.syncQueueEntries).get();
    for (final row in rows) {
      await db.syncQueueDao.scheduleRetry(
        row.id,
        retryCount: 1,
        nextAttemptAt: t0.add(const Duration(seconds: 8)),
        firstFailedAt: t0,
      );
    }
    await db.syncQueueDao.markPermanentlyFailed('b', reason: 'not-found');

    final changes = await readQueuedChanges(db, 'u1');
    expect(
      changes.firstWhere((c) => c.id == 'a').nextAttemptAt,
      t0.add(const Duration(seconds: 8)),
    );
    expect(changes.firstWhere((c) => c.id == 'b').nextAttemptAt, isNull);
  });

  test('Försök igen starts the retry schedule over', () async {
    await enqueue('a', 'r1', SyncOperation.update);
    final row = (await db.select(db.syncQueueEntries).get()).single;
    await db.syncQueueDao.scheduleRetry(
      row.id,
      retryCount: 6,
      nextAttemptAt: t0.add(const Duration(minutes: 10)),
      firstFailedAt: t0.subtract(const Duration(hours: 25)),
    );
    await db.syncQueueDao.markPermanentlyFailed(
      'a',
      reason: 'retries-exhausted',
    );

    await retryQueuedChange(db, (await readQueuedChanges(db, 'u1')).single);

    final after = (await db.select(db.syncQueueEntries).get()).single;
    expect(after.permanentlyFailed, isFalse);
    expect(after.nextAttemptAt, isNull);
    expect(after.firstFailedAt, isNull);
    expect(after.retryCount, 0);
  });

  test('the title is read from a stored Recipe (under "core")', () async {
    await db
        .into(db.offlineRecipes)
        .insert(
          OfflineRecipesCompanion.insert(
            id: 'r7',
            userId: 'u1',
            recipeJson: '{"core":{"id":"r7","title":"Pannbiffar"},"type":0}',
            updatedAt: t0,
          ),
        );
    await enqueue('a', 'r7', SyncOperation.update);
    expect((await readQueuedChanges(db, 'u1')).single.subject, 'Pannbiffar');
  });

  group('Spara som kopia', () {
    Future<void> storedRecipe(String id) => db.recipeDao.upsertRecipe(
      id: id,
      userId: 'u1',
      recipeJson: jsonEncode(
        RecipeFactory.build(
          id: id,
          title: 'Citronrisotto',
          createdBy: 'anna',
        ).toJson(),
      ),
      needsSync: true,
    );

    test('keeps the content as a new recipe of your own, queued to be '
        'saved, and the failure leaves the queue', () async {
      await storedRecipe('r1');
      await enqueue('op-1', 'r1', SyncOperation.update);
      await enqueue('other', 'r2', SyncOperation.update);
      await db.syncQueueDao.markPermanentlyFailed('op-1', reason: 'not-found');
      final failed = (await readQueuedChanges(
        db,
        'u1',
      )).firstWhere((c) => c.id == 'op-1');
      expect(failed.canSaveAsCopy, isTrue);

      final id = await withClock(
        Clock.fixed(t0),
        () => saveQueuedChangeAsCopy(db, 'u1', failed, newId: 'copy-1'),
      );

      expect(id, 'copy-1');
      final queue = QueueSnapshot(await readQueuedChanges(db, 'u1'));
      expect(queue.needsUser, isEmpty);
      final copy = queue.draining.firstWhere((c) => c.id != 'other');
      expect(copy.operation, QueuedOperation.create);
      expect(copy.subject, 'Citronrisotto');
      final stored = await db.recipeDao.getRecipe('copy-1', 'u1');
      expect(stored!.needsSync, isTrue);
      final recipe = Recipe.fromJson(
        jsonDecode(stored.recipeJson) as Map<String, dynamic>,
      );
      expect(recipe.id, 'copy-1');
      expect(recipe.title, 'Citronrisotto');
      expect(recipe.createdBy, 'u1', reason: 'the copy is yours');
      expect(recipe.type, RecipeType.personal);
      expect(recipe.socialData, isNull, reason: 'no sharing is carried over');
      expect(
        queue.draining.map((c) => c.id),
        contains('other'),
        reason: 'the rest of the queue is untouched',
      );
    });

    test('with no copy on the device nothing changes and it says so', () async {
      await enqueue('op-1', 'gone', SyncOperation.update);
      await db.syncQueueDao.markPermanentlyFailed('op-1', reason: 'not-found');
      final failed = (await readQueuedChanges(db, 'u1')).single;

      await expectLater(
        saveQueuedChangeAsCopy(db, 'u1', failed),
        throwsStateError,
      );

      final again = (await readQueuedChanges(db, 'u1')).single;
      expect(again.id, 'op-1');
      expect(again.needsUser, isTrue);
    });
  });

  group('Försök mindre', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('mindre'));
    tearDown(() => dir.delete(recursive: true));

    Future<QueuedChange> tooLarge(String path, int size) async {
      await withClock(
        Clock.fixed(t0),
        () => db.uploadQueueDao.queueUpload(
          id: 'up-1',
          userId: 'u1',
          localPath: path,
          targetPath: 'x/a.jpg',
          fileSizeBytes: size,
        ),
      );
      await db.uploadQueueDao.markPermanentlyFailed(
        'up-1',
        reason: 'too-large',
      );
      return (await readQueuedChanges(db, 'u1')).single;
    }

    test('writes a smaller copy next to the original and queues it from '
        'the start', () async {
      final original = File('${dir.path}/foto.png')
        ..writeAsBytesSync(List.filled(4000, 1));
      final change = await tooLarge(original.path, 4000);
      expect(change.canTrySmaller, isTrue);

      final smaller = _jpeg(40, 30);
      await retrySmallerQueuedChange(
        db,
        'u1',
        change,
        shrink: (path) async => smaller,
      );

      final row = (await db.select(db.uploadQueueEntries).get()).single;
      expect(row.localPath, '${dir.path}/foto-mindre.jpg');
      expect(File(row.localPath).lengthSync(), smaller.length);
      expect(row.fileSizeBytes, smaller.length);
      expect(row.permanentlyFailed, isFalse);
      expect(row.status, 'pending');
      expect(original.existsSync(), isTrue, reason: 'the original is kept');
    });

    test('an image that cannot be made smaller stays where it was', () async {
      final same = _jpeg(40, 30);
      final change = await tooLarge('${dir.path}/foto.jpg', same.length);

      await expectLater(
        retrySmallerQueuedChange(
          db,
          'u1',
          change,
          shrink: (path) async => same,
        ),
        throwsStateError,
      );

      final row = (await db.select(db.uploadQueueEntries).get()).single;
      expect(row.permanentlyFailed, isTrue);
      expect(row.localPath, '${dir.path}/foto.jpg');
    });

    // flows-roles-budget.md:143: "≤ 250 kB, långsida ≤ 1600 px".
    for (final entry in {
      'a long side over 1600 px': _jpeg(1700, 10),
      'a file over 250 kB': Uint8List.fromList([
        ..._jpeg(40, 30),
        ...List.filled(kRecipeImageMaxBytes, 0),
      ]),
      'bytes that are not an image': Uint8List.fromList(List.filled(300, 2)),
    }.entries) {
      test('a result with ${entry.key} is not queued again', () async {
        final change = await tooLarge('${dir.path}/foto.jpg', 4000000);

        await expectLater(
          retrySmallerQueuedChange(
            db,
            'u1',
            change,
            shrink: (path) async => entry.value,
          ),
          throwsStateError,
        );

        final row = (await db.select(db.uploadQueueEntries).get()).single;
        expect(row.permanentlyFailed, isTrue);
        expect(row.localPath, '${dir.path}/foto.jpg');
      });
    }
  });

  group('the recipe-image budget (flows-roles-budget.md:143)', () {
    // What flutter_image_compress does with minWidth/minHeight:
    // scale = max(1, min(w / minW, h / minH)); out = side / scale
    // (flutter_image_compress_common-1.1.1 BitmapCompressExt.kt:68-75).
    (int, int) pluginOutput(int w, int h, int minW, int minH) {
      final scale = [
        1.0,
        [w / minW, h / minH].reduce((a, b) => a < b ? a : b),
      ].reduce((a, b) => a > b ? a : b);
      return ((w / scale).floor(), (h / scale).floor());
    }

    test('the long side ends at most 1600 px, landscape or portrait', () {
      for (final (w, h) in [
        (4000, 3000),
        (3000, 4000),
        (4032, 3024),
        (1600, 1601),
        (9000, 100),
        (2000, 2000),
      ]) {
        final side = recipeImageMinSide(w, h);
        final (outW, outH) = pluginOutput(w, h, side, side);
        expect(
          outW > outH ? outW : outH,
          lessThanOrEqualTo(kRecipeImageMaxSide),
          reason: '${w}x$h',
        );
        expect(
          outW > outH ? outW : outH,
          greaterThanOrEqualTo(1500),
          reason: '${w}x$h is not made smaller than it must be',
        );
      }
      // The bug this replaces: 1600/1600 turns 4000x3000 into 2133x1600.
      expect(pluginOutput(4000, 3000, 1600, 1600).$1, 2133);
    });

    test('an image already within 1600 px is not scaled', () {
      final side = recipeImageMinSide(1200, 800);
      expect(pluginOutput(1200, 800, side, side), (1200, 800));
    });

    test('the size is read from the image header', () {
      expect(recipeImageSize(_jpeg(40, 30)), (40, 30));
      expect(recipeImageSize(Uint8List.fromList([1, 2, 3])), isNull);
      expect(fitsRecipeImageBudget(_jpeg(1600, 20)), isTrue);
      expect(fitsRecipeImageBudget(_jpeg(20, 1601)), isFalse);
    });
  });
}

Uint8List _jpeg(int width, int height) =>
    img.encodeJpg(img.Image(width: width, height: height), quality: 50);
