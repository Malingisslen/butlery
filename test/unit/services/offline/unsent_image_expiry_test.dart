// BUT-2294: the 30 days an unsent photo waits in "Väntar på dig" before the
// queue throws it away (Malin 2026-10-20).

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/services/offline/unsent_image_expiry.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final since = DateTime(2026, 9, 1, 12);
  DateTime after(Duration d) => since.add(d);

  group('unsentImageDaysLeft', () {
    test('day 29 has one day left', () {
      expect(
        unsentImageDaysLeft(since, after(const Duration(days: 29))),
        1,
      );
    });

    test('day 30 is due, and so is day 31', () {
      expect(unsentImageDaysLeft(since, after(const Duration(days: 30))), 0);
      expect(unsentImageDaysLeft(since, after(const Duration(days: 31))), 0);
      expect(
        unsentImageExpired(since, after(const Duration(days: 30))),
        isTrue,
      );
    });

    test('a started day counts as a day, so the card never says 0 early', () {
      final almost = after(const Duration(days: 29, seconds: 1));
      expect(unsentImageDaysLeft(since, almost), 1);
      expect(unsentImageExpired(since, almost), isFalse);
      expect(unsentImageDaysLeft(since, after(const Duration(hours: 1))), 30);
      expect(unsentImageDaysLeft(since, since), 30);
    });

    test('the days left are measured from the given clock', () {
      expect(
        unsentImageDaysLeft(since, since.subtract(const Duration(days: 5))),
        35,
      );
    });
  });

  group('unsentImageSince', () {
    final queuedAt = DateTime(2026, 8, 1);

    test('starts at the first failure', () {
      expect(unsentImageSince(since, queuedAt), since);
    });

    test('falls back to when the photo was queued', () {
      expect(unsentImageSince(null, queuedAt), queuedAt);
      expect(
        unsentImageDaysLeft(
          unsentImageSince(null, queuedAt),
          queuedAt.add(const Duration(days: 29)),
        ),
        1,
      );
    });
  });

  group('the clock starts when a chain is marked as failed', () {
    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> queue(String id, {String? dependsOn}) => withClock(
      Clock.fixed(DateTime(2026, 9, 1)),
      () => db.uploadQueueDao.queueUpload(
        id: id,
        userId: 'u1',
        localPath: '/x/$id.jpg',
        targetPath: 'users/u1/recipes',
        fileSizeBytes: 1,
        dependsOn: [?dependsOn],
      ),
    );

    test(
      'rows without a first-failure time get one; rows with one keep it',
      () async {
        await queue('a');
        await queue('b', dependsOn: 'a');
        final kept = DateTime(2026, 8, 20);
        await (db.update(db.uploadQueueEntries)..where((e) => e.id.equals('b')))
            .write(UploadQueueEntriesCompanion(firstFailedAt: Value(kept)));
        final marked = DateTime(2026, 9, 5, 8);

        await withClock(
          Clock.fixed(marked),
          () => db.markChainPermanentlyFailed('u1', 'a', reason: 'x'),
        );

        expect((await db.uploadQueueDao.getUpload('a'))!.firstFailedAt, marked);
        expect((await db.uploadQueueDao.getUpload('b'))!.firstFailedAt, kept);
      },
    );
  });
}
