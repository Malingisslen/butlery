// BUT-2294 PR 5a: a queued cook-snap album is ONE item to the user. The rows of
// the group (one per photo) are one line in Väntar på synk, one number in the
// counts and in the sign-out warning, and are retried and thrown away as a
// whole.

import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/sync_queue_reader.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/views/sync/sync_queue_row.dart';
import 'package:clock/clock.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _FakeOfflineService extends Fake implements OfflineService {
  _FakeOfflineService(this.database);

  @override
  final AppDatabase database;

  @override
  bool get isInitialized => true;
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    production.ServiceLocator.initialize(DIContainer());
  });

  const uid = 'u1';
  final t0 = DateTime(2026, 10, 20, 12);
  late AppDatabase db;
  late Directory root;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cook_snap_queue_view');
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  /// The rows of a snap of [photos] photos; returns the rows' ids. The copies
  /// on the device are real files so a discard can be seen to remove them.
  Future<List<String>> queueSnap(
    String snapId, {
    int photos = 3,
    DateTime? at,
    String user = uid,
  }) async {
    final ids = <String>[];
    for (var i = 0; i < photos; i++) {
      final file = File('${root.path}/$user-$snapId-$i.jpg')
        ..writeAsBytesSync([i]);
      final id = '$user-$snapId-row-$i';
      ids.add(id);
      await withClock(
        Clock.fixed((at ?? t0).add(Duration(milliseconds: i))),
        () => db.uploadQueueDao.queueUpload(
          id: id,
          userId: user,
          localPath: file.path,
          targetPath: 'users/$user/recipes',
          fileSizeBytes: 1,
          entityId: snapId,
          entityType: SyncQueueEntityType.cookSnap,
          metadata: '{"recipeName":"Kladdkaka","order":$i}',
        ),
      );
    }
    return ids;
  }

  Future<void> queueRecipeImage(String id) => withClock(
    Clock.fixed(t0),
    () => db.uploadQueueDao.queueUpload(
      id: id,
      userId: uid,
      localPath: '/x/$id.jpg',
      targetPath: 'users/$uid/recipes',
      fileSizeBytes: 1,
      entityId: 'r1',
      entityType: SyncQueueEntityType.recipe,
    ),
  );

  Future<List<UploadQueueEntry>> rows() =>
      db.select(db.uploadQueueEntries).get();

  test(
    'the queued-change model and the database name the same entity type',
    () {
      expect(cookSnapEntityType, SyncQueueEntityType.cookSnap);
    },
  );

  group('the list', () {
    test(
      'three photos of one snap are ONE item beside a recipe image',
      () async {
        // Proves: the rows of a group count as one item, and a recipe image
        // stays its own item.
        await queueRecipeImage('img-1');
        await queueSnap('snap-1', at: t0.add(const Duration(seconds: 5)));

        final changes = await readQueuedChanges(db, uid);

        expect(changes, hasLength(2));
        final album = changes.singleWhere((c) => c.isCookSnapGroup);
        expect(album.id, 'snap-1');
        expect(album.photoCount, 3);
        expect(album.kind, QueuedChangeKind.image);
        expect(album.queuedAt, t0.add(const Duration(seconds: 5)));
        final image = changes.singleWhere((c) => !c.isCookSnapGroup);
        expect(image.id, 'img-1');
        expect(image.photoCount, 1);
        expect(image.entityType, SyncQueueEntityType.recipe);
      },
    );

    test(
      'the label names the album and its photos, in Swedish and English',
      () async {
        await queueSnap('snap-3');
        await queueSnap('snap-1', photos: 1);
        final byId = {
          for (final c in await readQueuedChanges(db, uid)) c.id: c,
        };

        expect(
          describeQueuedChange(AppLocalizationsSv(), byId['snap-3']!),
          'Matlagningsfoton (3 bilder)',
        );
        expect(
          describeQueuedChange(AppLocalizationsSv(), byId['snap-1']!),
          'Matlagningsfoton (1 bild)',
        );
        expect(
          describeQueuedChange(AppLocalizationsEn(), byId['snap-3']!),
          'Cooking photos (3 photos)',
        );
      },
    );

    test('one failed photo makes the whole album ONE item that needs the '
        'user', () async {
      // Proves: the queue marks only the photo that failed; the view must not
      // show it as one failure plus two items still waiting.
      final ids = await queueSnap('snap-1');
      await db.uploadQueueDao.markUploaded(ids[0], url: 'https://img/0.jpg');
      await db.uploadQueueDao.markPermanentlyFailed(
        ids[2],
        reason: 'permission-denied',
      );

      final changes = await readQueuedChanges(db, uid);
      final queue = QueueSnapshot(changes);

      expect(changes, hasLength(1));
      expect(changes.single.needsUser, isTrue);
      expect(changes.single.reason, QueuedChangeReason.permissionDenied);
      expect(changes.single.photoCount, 3);
      expect(queue.needsUser, hasLength(1));
      expect(queue.draining, isEmpty);
      final counts = await db.watchQueueCounts(uid).first;
      expect(counts.needsUser, 1);
      expect(counts.draining, 0);
    });

    test('recipe images that share an entity id stay separate items', () async {
      // Proves: only cook-snap rows are grouped; the photos of one recipe are
      // each a thing the user can retry or throw away.
      await queueRecipeImage('img-1');
      await queueRecipeImage('img-2');

      final changes = await readQueuedChanges(db, uid);

      expect(changes, hasLength(2));
      expect(QueueSnapshot(changes).total, 2);
      expect((await db.watchQueueCounts(uid).first).waiting, 2);
    });

    test('an album counts its 30 days from its OLDEST failed photo, and a '
        'photo that has not failed starts nothing', () async {
      final ids = await queueSnap('snap-1');
      await db.uploadQueueDao.markPermanentlyFailed(ids[1], reason: 'x');
      await db.uploadQueueDao.markPermanentlyFailed(ids[2], reason: 'x');
      final early = t0.subtract(const Duration(days: 10));
      await (db.update(db.uploadQueueEntries)
            ..where((e) => e.id.equals(ids[2])))
          .write(UploadQueueEntriesCompanion(firstFailedAt: Value(early)));
      // ids[0] was queued before both and has not failed: it must not count.
      await (db.update(
        db.uploadQueueEntries,
      )..where((e) => e.id.equals(ids[0]))).write(
        UploadQueueEntriesCompanion(
          queuedAt: Value(t0.subtract(const Duration(days: 40))),
        ),
      );

      final album = (await readQueuedChanges(db, uid)).single;

      expect(album.unsentSince, early);
    });

    test('Väntar på dig tells an unsent photo how many days are left, in '
        'Swedish and English, and says nothing for a recipe write', () async {
      await queueRecipeImage('img-1');
      await db.uploadQueueDao.markPermanentlyFailed('img-1', reason: 'x');
      final image = (await readQueuedChanges(db, uid)).single;
      String? at(Duration d, AppLocalizations l10n) => withClock(
        Clock.fixed(t0.add(d)),
        () => describeAutoDiscard(l10n, image),
      );

      expect(
        at(const Duration(days: 1), AppLocalizationsSv()),
        'Slängs automatiskt om 29 dagar',
      );
      expect(
        at(const Duration(days: 29), AppLocalizationsSv()),
        'Slängs automatiskt om 1 dag',
      );
      expect(
        at(const Duration(days: 30), AppLocalizationsSv()),
        'Slängs automatiskt i dag',
      );
      expect(
        at(const Duration(days: 29), AppLocalizationsEn()),
        'Will be discarded automatically in 1 day',
      );
      final queued = QueuedChange(
        kind: QueuedChangeKind.recipe,
        id: 'op',
        operation: QueuedOperation.update,
        queuedAt: t0,
        needsUser: true,
      );
      expect(describeAutoDiscard(AppLocalizationsSv(), queued), isNull);
    });

    test('another user\'s album is not listed', () async {
      await queueSnap('snap-x', user: 'u2');

      expect(await readQueuedChanges(db, uid), isEmpty);
    });
  });

  group('the counts and the sign-out warning', () {
    test('an album counts once, from queued until the snap is created, '
        'uploaded photos included', () async {
      // Proves: 3 photos = 1 item, and a photo already in Storage still
      // counts, because the snap does not exist until all are up.
      final ids = await queueSnap('snap-1');
      await queueRecipeImage('img-1');
      expect((await db.watchQueueCounts(uid).first).waiting, 2);

      for (final id in ids) {
        await db.uploadQueueDao.markUploaded(id, url: 'https://img/$id.jpg');
      }
      expect((await db.watchQueueCounts(uid).first).waiting, 2);

      for (final id in ids) {
        await db.uploadQueueDao.markCompleted(id);
      }
      expect((await db.watchQueueCounts(uid).first).waiting, 1);
    });

    test('the list and the counts agree on the number', () async {
      final ids = await queueSnap('snap-1');
      await queueSnap('snap-2', photos: 2);
      await db.uploadQueueDao.markPermanentlyFailed(ids[1]);

      final queue = QueueSnapshot(await readQueuedChanges(db, uid));
      final counts = await db.watchQueueCounts(uid).first;

      expect(queue.total, 2);
      expect(counts.waiting, queue.total);
      expect(counts.needsUser, queue.needsUser.length);
    });

    test('the sign-out warning counts a three-photo snap as one image upload '
        'and an uploaded photo still counts', () async {
      final ids = await queueSnap('snap-1');
      for (final id in ids) {
        await db.uploadQueueDao.markUploaded(id, url: 'https://img/$id.jpg');
      }
      await db.syncQueueDao.enqueue(
        userId: uid,
        recipeId: 'r1',
        operation: SyncOperation.update,
      );
      TestServiceLocator.registerMock<OfflineService>(
        _FakeOfflineService(db),
      );

      final pending = await const OfflinePendingChangesSource().read(uid);

      expect(pending.imageUploads, 1);
      expect(pending.recipeChanges, 1);
      expect(pending.total, 2);
    });
  });

  group('the actions', () {
    test('Försök igen puts every photo of the album back, and a photo already '
        'in Storage is not uploaded again', () async {
      final ids = await queueSnap('snap-1');
      await db.uploadQueueDao.markUploaded(ids[0], url: 'https://img/0.jpg');
      await db.uploadQueueDao.markPermanentlyFailed(
        ids[2],
        reason: 'retries-exhausted',
      );
      await (db.update(db.uploadQueueEntries)).write(
        UploadQueueEntriesCompanion(
          retryCount: const Value(5),
          nextAttemptAt: Value(t0.add(const Duration(hours: 1))),
          firstFailedAt: Value(t0),
        ),
      );
      final album = (await readQueuedChanges(db, uid)).single;
      expect(album.needsUser, isTrue);

      await retryQueuedChange(db, album, userId: uid);

      final after = {for (final r in await rows()) r.id: r};
      expect(after.values.every((r) => !r.permanentlyFailed), isTrue);
      expect(after[ids[0]]!.status, 'uploaded');
      expect(after[ids[0]]!.uploadedUrl, 'https://img/0.jpg');
      expect(after[ids[1]]!.status, 'pending');
      expect(after[ids[2]]!.status, 'pending');
      expect(after[ids[2]]!.lastError, isNull);
      expect(after.values.every((r) => r.retryCount == 0), isTrue);
      expect(after.values.every((r) => r.nextAttemptAt == null), isTrue);
      expect(after.values.every((r) => r.firstFailedAt == null), isTrue);
      final again = (await readQueuedChanges(db, uid)).single;
      expect(again.needsUser, isFalse);
    });

    test('Försök igen on a single photo starts its 30 days over', () async {
      await queueRecipeImage('img-1');
      await db.uploadQueueDao.markPermanentlyFailed('img-1', reason: 'x');
      await (db.update(db.uploadQueueEntries)).write(
        UploadQueueEntriesCompanion(
          firstFailedAt: Value(t0.subtract(const Duration(days: 28))),
          nextAttemptAt: Value(t0),
        ),
      );
      final image = (await readQueuedChanges(db, uid)).single;

      await retryQueuedChange(db, image, userId: uid);

      final after = (await rows()).single;
      expect(after.permanentlyFailed, isFalse);
      expect(after.firstFailedAt, isNull);
      expect(after.nextAttemptAt, isNull);
    });

    test('Försök igen retries only the signed-in user\'s album when another '
        'user has a snap with the same id', () async {
      final mine = await queueSnap('snap-1', photos: 2);
      final theirs = await queueSnap('snap-1', photos: 2, user: 'u2');
      for (final id in [...mine, ...theirs]) {
        await db.uploadQueueDao.markPermanentlyFailed(id, reason: 'x');
      }
      final album = (await readQueuedChanges(db, uid)).single;

      await retryQueuedChange(db, album, userId: uid);

      final after = {for (final r in await rows()) r.id: r};
      // queueSnap ids are per snap, so the other user's rows get distinct ids.
      expect(mine.every((id) => !after[id]!.permanentlyFailed), isTrue);
      expect(theirs.every((id) => after[id]!.permanentlyFailed), isTrue);
    });

    testWidgets('a too-large photo in an album offers Försök igen, never '
        'Försök mindre', (tester) async {
      // Proves: "Försök mindre" would throw for an album (it works on one
      // file), so the card must not offer it.
      final ids = await queueSnap('snap-1');
      await db.uploadQueueDao.markPermanentlyFailed(
        ids[1],
        reason: 'too-large',
      );
      final album = (await readQueuedChanges(db, uid)).single;
      expect(album.reason, QueuedChangeReason.tooLarge);
      expect(album.canTrySmaller, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SyncQueueNeedsYouCard(
              change: album,
              onRetry: () {},
              onDiscard: () {},
              onTrySmaller: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(SyncQueueNeedsYouCard.retryKey(album)), findsOneWidget);
      expect(find.byKey(SyncQueueNeedsYouCard.smallerKey(album)), findsNothing);
    });

    test('Släng throws the whole album away, copies on the device included, '
        'and leaves another snap alone', () async {
      final ids = await queueSnap('snap-1');
      final other = await queueSnap('snap-2', photos: 2);
      await db.uploadQueueDao.markPermanentlyFailed(ids[1], reason: 'x');
      final album = (await readQueuedChanges(
        db,
        uid,
      )).singleWhere((c) => c.id == 'snap-1');
      final copies = [for (final r in await rows()) r.localPath];

      expect(await discardQueuedChange(db, uid, album), isNull);

      final after = {for (final r in await rows()) r.id: r};
      for (final id in ids) {
        expect(after[id]!.status, 'cancelled', reason: id);
      }
      for (final id in other) {
        expect(after[id]!.status, isNot('cancelled'), reason: id);
      }
      final gone = copies.where((p) => p.contains('/$uid-snap-1-'));
      expect(gone, hasLength(3));
      expect(gone.every((p) => !File(p).existsSync()), isTrue);
      expect(
        copies
            .where((p) => p.contains('/$uid-snap-2-'))
            .every(
              (p) => File(p).existsSync(),
            ),
        isTrue,
      );
      expect(
        (await readQueuedChanges(db, uid)).map((c) => c.id),
        ['snap-2'],
      );
    });
  });
}
