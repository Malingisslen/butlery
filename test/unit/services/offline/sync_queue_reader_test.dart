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

      await retrySmallerQueuedChange(
        db,
        'u1',
        change,
        shrink: (path) async => Uint8List.fromList(List.filled(300, 2)),
      );

      final row = (await db.select(db.uploadQueueEntries).get()).single;
      expect(row.localPath, '${dir.path}/foto-mindre.jpg');
      expect(File(row.localPath).lengthSync(), 300);
      expect(row.fileSizeBytes, 300);
      expect(row.permanentlyFailed, isFalse);
      expect(row.status, 'pending');
      expect(original.existsSync(), isTrue, reason: 'the original is kept');
    });

    test('an image that cannot be made smaller stays where it was', () async {
      final change = await tooLarge('${dir.path}/foto.jpg', 300);

      await expectLater(
        retrySmallerQueuedChange(
          db,
          'u1',
          change,
          shrink: (path) async => Uint8List.fromList(List.filled(300, 2)),
        ),
        throwsStateError,
      );

      final row = (await db.select(db.uploadQueueEntries).get()).single;
      expect(row.permanentlyFailed, isTrue);
      expect(row.localPath, '${dir.path}/foto.jpg');
    });
  });
}
