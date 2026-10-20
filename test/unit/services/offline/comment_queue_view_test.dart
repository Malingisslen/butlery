// BUT-2294 PR 7: a queued comment's photos are ONE item to the user, like a
// cook snap's album. The list, the counts, "Försök igen", "Släng" and the 30
// days an unsent photo waits all treat the comment as a whole, and never mix it
// up with a cook snap that happens to share its id.

import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/sync_queue_reader.dart';
import 'package:butlery/services/offline/unsent_image_discard.dart';
import 'package:butlery/views/sync/sync_queue_row.dart';
import 'package:clock/clock.dart';

import '../../../test_support/base_unit_test.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  const uid = 'u1';
  final t0 = DateTime(2026, 10, 20, 12);
  late AppDatabase db;
  late Directory root;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('comment_queue_view');
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
    BaseUnitTest.resetMocks();
  });

  /// The rows of one group; returns the rows' ids. The copies on the device
  /// are real files so a discard can be seen to remove them.
  Future<List<String>> queueGroup(
    String entityType,
    String groupId, {
    int photos = 2,
    String recipeName = 'Kladdkaka',
    DateTime? at,
  }) async {
    final ids = <String>[];
    for (var i = 0; i < photos; i++) {
      final file = File('${root.path}/$entityType-$groupId-$i.jpg')
        ..writeAsBytesSync([i]);
      final id = '$entityType-$groupId-row-$i';
      ids.add(id);
      await withClock(
        Clock.fixed((at ?? t0).add(Duration(milliseconds: i))),
        () => db.uploadQueueDao.queueUpload(
          id: id,
          userId: uid,
          localPath: file.path,
          targetPath: entityType == SyncQueueEntityType.comment
              ? 'users/$uid/comment_images'
              : 'users/$uid/recipes',
          fileSizeBytes: 1,
          entityId: groupId,
          entityType: entityType,
          metadata: '{"recipeName":"$recipeName","order":$i}',
        ),
      );
    }
    return ids;
  }

  Future<List<UploadQueueEntry>> rows() =>
      db.select(db.uploadQueueEntries).get();

  test('the queued-change model and the database name the same entity types '
      'and the counts SQL groups exactly those', () {
    expect(commentEntityType, SyncQueueEntityType.comment);
    expect(cookSnapEntityType, SyncQueueEntityType.cookSnap);
    expect(imageGroupEntityTypes, SyncQueueEntityType.grouped);
    for (final type in SyncQueueEntityType.grouped) {
      expect(queueCountsSql, contains("'$type'"), reason: type);
    }
  });

  group('the list', () {
    test('a comment\'s photos are ONE item named after the recipe, in Swedish '
        'and English', () async {
      await queueGroup(SyncQueueEntityType.comment, 'c1', photos: 3);

      final changes = await readQueuedChanges(db, uid);

      expect(changes, hasLength(1));
      final comment = changes.single;
      expect(comment.isCommentGroup, isTrue);
      expect(comment.photoCount, 3);
      expect(comment.id, 'c1');
      expect(
        describeQueuedChange(AppLocalizationsSv(), comment),
        'Kommentar på Kladdkaka',
      );
      expect(
        describeQueuedChange(AppLocalizationsEn(), comment),
        'Comment on Kladdkaka',
      );
    });

    test('a comment whose recipe name was not kept is still named', () async {
      await queueGroup(SyncQueueEntityType.comment, 'c1');
      await (db.update(db.uploadQueueEntries)).write(
        const UploadQueueEntriesCompanion(metadata: Value(null)),
      );

      final comment = (await readQueuedChanges(db, uid)).single;

      expect(comment.subject, isNull);
      expect(describeQueuedChange(AppLocalizationsSv(), comment), 'Kommentar');
      expect(describeQueuedChange(AppLocalizationsEn(), comment), 'Comment');
    });

    test('metadata the list cannot read does not break the list: the comment '
        'is still named', () async {
      for (final bad in ['not json', '[1]', '{"recipeName": 5}']) {
        await db.delete(db.uploadQueueEntries).go();
        await queueGroup(SyncQueueEntityType.comment, 'c1');
        await (db.update(db.uploadQueueEntries)).write(
          UploadQueueEntriesCompanion(metadata: Value(bad)),
        );

        final comment = (await readQueuedChanges(db, uid)).single;

        expect(comment.subject, isNull, reason: bad);
        expect(
          describeQueuedChange(AppLocalizationsSv(), comment),
          'Kommentar',
          reason: bad,
        );
      }
    });

    test('a comment and a cook snap with the same id stay two items, each '
        'with its own label', () async {
      await queueGroup(SyncQueueEntityType.comment, 'same', photos: 2);
      await queueGroup(SyncQueueEntityType.cookSnap, 'same', photos: 3);

      final changes = await readQueuedChanges(db, uid);

      expect(changes, hasLength(2));
      final labels = {
        for (final c in changes)
          c.entityType: describeQueuedChange(AppLocalizationsSv(), c),
      };
      expect(labels[SyncQueueEntityType.comment], 'Kommentar på Kladdkaka');
      expect(
        labels[SyncQueueEntityType.cookSnap],
        'Matlagningsfoton (3 bilder)',
      );
      expect((await db.watchQueueCounts(uid).first).waiting, 2);
    });

    test('one failed photo makes the comment ONE item that needs the user, '
        'with the words for a comment', () async {
      final ids = await queueGroup(
        SyncQueueEntityType.comment,
        'c1',
        photos: 3,
      );
      await db.uploadQueueDao.markUploaded(ids[0], url: 'https://img/0.jpg');
      await db.uploadQueueDao.markPermanentlyFailed(
        ids[2],
        reason: 'permission-denied',
      );

      final changes = await readQueuedChanges(db, uid);
      final counts = await db.watchQueueCounts(uid).first;

      expect(changes, hasLength(1));
      expect(changes.single.needsUser, isTrue);
      expect(changes.single.canDiscard, isTrue);
      expect(changes.single.canTrySmaller, isFalse);
      expect(counts.needsUser, 1);
      expect(counts.draining, 0);
      expect(
        describeQueuedReason(AppLocalizationsSv(), changes.single),
        'Kommentaren kunde inte skickas.',
      );
      expect(
        describeQueuedReason(AppLocalizationsEn(), changes.single),
        'The comment could not be sent.',
      );
    });
  });

  group('the actions', () {
    test('Försök igen puts every photo of the comment back and leaves a cook '
        'snap with the same id as it was', () async {
      final mine = await queueGroup(SyncQueueEntityType.comment, 'same');
      final snap = await queueGroup(SyncQueueEntityType.cookSnap, 'same');
      for (final id in [...mine, ...snap]) {
        await db.uploadQueueDao.markPermanentlyFailed(id, reason: 'x');
      }
      final comment = (await readQueuedChanges(
        db,
        uid,
      )).singleWhere((c) => c.isCommentGroup);

      await retryQueuedChange(db, comment, userId: uid);

      final after = {for (final r in await rows()) r.id: r};
      expect(mine.every((id) => !after[id]!.permanentlyFailed), isTrue);
      expect(snap.every((id) => after[id]!.permanentlyFailed), isTrue);
    });

    test('Släng throws the whole comment away, copies on the device '
        'included, and leaves a cook snap with the same id alone', () async {
      final mine = await queueGroup(SyncQueueEntityType.comment, 'same');
      final snap = await queueGroup(SyncQueueEntityType.cookSnap, 'same');
      await db.uploadQueueDao.markPermanentlyFailed(mine[1], reason: 'x');
      final comment = (await readQueuedChanges(
        db,
        uid,
      )).singleWhere((c) => c.isCommentGroup);
      final copies = [for (final r in await rows()) r.localPath];

      expect(await discardQueuedChange(db, uid, comment), isNull);

      final after = {for (final r in await rows()) r.id: r};
      for (final id in mine) {
        expect(after[id], isNull, reason: id);
      }
      for (final id in snap) {
        expect(after[id]!.status, isNot('cancelled'), reason: id);
      }
      final gone = copies.where((p) => p.contains('/comment-same-'));
      expect(gone, hasLength(2));
      expect(gone.every((p) => !File(p).existsSync()), isTrue);
      expect(
        copies
            .where((p) => p.contains('/cook_snap-same-'))
            .every((p) => File(p).existsSync()),
        isTrue,
      );
    });
  });

  group('the 30 days', () {
    test('a comment that waited out the period goes whole, even if only one '
        'photo had failed, and a newer one stays', () async {
      final old = await queueGroup(
        SyncQueueEntityType.comment,
        'old',
        photos: 3,
        at: t0.subtract(const Duration(days: 31)),
      );
      final fresh = await queueGroup(
        SyncQueueEntityType.comment,
        'fresh',
        at: t0.subtract(const Duration(days: 2)),
      );
      await db.uploadQueueDao.markPermanentlyFailed(old[1], reason: 'x');
      final copies = {
        for (final r in await rows()) r.id: r.localPath,
      };

      final discarded = await discardExpiredUnsent(db, uid, t0);

      expect(discarded, 1);
      final after = {for (final r in await rows()) r.id: r};
      for (final id in old) {
        expect(after[id], isNull, reason: id);
        expect(File(copies[id]!).existsSync(), isFalse, reason: id);
      }
      for (final id in fresh) {
        expect(after[id]!.status, isNot('cancelled'), reason: id);
        expect(File(copies[id]!).existsSync(), isTrue, reason: id);
      }
    });

    test('the startup sweep throws away the comment of an account that '
        'signed out', () async {
      final old = await queueGroup(
        SyncQueueEntityType.comment,
        'old',
        at: t0.subtract(const Duration(days: 31)),
      );

      final discarded = await sweepExpiredUnsent(db, t0);

      expect(discarded, 1);
      final after = {for (final r in await rows()) r.id: r};
      for (final id in old) {
        expect(after[id], isNull, reason: id);
      }
    });
  });
}
