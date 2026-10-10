// P6-U08b: the retry schedule (produktregler.md:188, TR::FLOW::08::ko::
// omforsok-backoff): "Exponentiell backoff 2 s → 4 s → 8 s → 30 s → 2 min →
// 10 min, med jitter. Max 24 h, därefter permanent fel. Ingen omförsöksstorm
// vid återkommande nät."

import 'dart:math';

import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_support/base_unit_test.dart';
import 'queue_harness.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    QueueHarness.registerFallbacks();
  });

  group('the schedule', () {
    const steps = [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
    ];

    test('is the six steps of produktregler.md, in order', () {
      expect(kQueueRetrySchedule, steps);
      expect(kQueueMaxRetryAge, const Duration(hours: 24));
    });

    test('every delay falls inside its ±25 % jitter band, and the last step '
        'repeats', () {
      final random = Random(7);
      for (var failures = 1; failures <= 9; failures++) {
        final base = steps[min(failures, steps.length) - 1];
        for (var i = 0; i < 200; i++) {
          final delay = queueRetryDelay(failures, random: random);
          expect(
            delay.inMicroseconds,
            inInclusiveRange(
              (base.inMicroseconds * 0.75).floor(),
              (base.inMicroseconds * 1.25).ceil(),
            ),
            reason: 'failure $failures',
          );
        }
      }
    });

    test('the jitter spreads delays: two devices do not retry in step', () {
      final random = Random(3);
      final delays = {
        for (var i = 0; i < 50; i++) queueRetryDelay(3, random: random),
      };
      expect(delays.length, greaterThan(40));
    });

    test('24 h counts from the first failure', () {
      final first = DateTime(2026, 9, 27, 12);
      expect(
        queueRetriesExhausted(first, first.add(const Duration(hours: 23))),
        isFalse,
      );
      expect(
        queueRetriesExhausted(first, first.add(const Duration(hours: 24))),
        isTrue,
      );
    });
  });

  group('the queue follows it', () {
    late QueueHarness q;
    final t0 = QueueHarness.t0;

    setUp(() => q = QueueHarness.create());
    tearDown(() => q.dispose());

    test('a transient failure keeps the entry and sets its next attempt '
        '2 s out', () async {
      await q.queueRecipe('op-1', 'r1');
      q.failWith['r1'] = firestoreError('unavailable');

      await q.pass();

      final row = (await q.rows())['op-1']!;
      expect(row.permanentlyFailed, isFalse);
      expect(row.retryCount, 1);
      expect(row.nextAttemptAt, t0.add(const Duration(seconds: 2)));
      expect(row.firstFailedAt, t0);
      expect(row.lastError, 'unavailable');
      expect(q.manager.hasScheduledRetry, isTrue);
    });

    test('before its time the entry is not sent again, even when the network '
        'comes back; at its time it is, and the next step is 4 s', () async {
      await q.queueRecipe('op-1', 'r1');
      q.failWith['r1'] = firestoreError('unavailable');
      await q.pass();

      q.failWith.remove('r1');
      // The reconnect pass: "Ingen omförsöksstorm vid återkommande nät".
      await q.pass(at: t0.add(const Duration(seconds: 1)));
      expect(q.sent, isEmpty);

      q.failWith['r1'] = firestoreError('deadline-exceeded');
      final second = t0.add(const Duration(seconds: 3));
      await q.pass(at: second);
      final row = (await q.rows())['op-1']!;
      expect(row.retryCount, 2);
      expect(row.nextAttemptAt, second.add(const Duration(seconds: 4)));
      expect(row.firstFailedAt, t0, reason: 'the 24 h window does not move');
    });

    test('"Försök synka nu" does not wait for the retry time', () async {
      await q.queueRecipe('op-1', 'r1');
      q.failWith['r1'] = firestoreError('unavailable');
      await q.pass();
      q.failWith.remove('r1');

      await q.pass(at: t0.add(const Duration(seconds: 1)), force: true);

      expect(q.sent, ['r1']);
      expect(await q.rows(), isEmpty);
    });

    test('after 24 h of failures the entry becomes a permanent failure that '
        'waits for the user', () async {
      await q.queueRecipe('op-1', 'r1');
      q.failWith['r1'] = firestoreError('unavailable');
      await q.pass();

      await q.pass(at: t0.add(const Duration(hours: 23, minutes: 59)));
      expect((await q.rows())['op-1']!.permanentlyFailed, isFalse);

      await q.pass(at: t0.add(const Duration(hours: 24, minutes: 10)));
      final row = (await q.rows())['op-1']!;
      expect(row.permanentlyFailed, isTrue);
      expect(
        QueuedChangeReason.parse(row.lastError),
        QueuedChangeReason.retriesExhausted,
      );
    });

    test('a phone offline for days has not been retrying: its first failure '
        'starts the 24 h', () async {
      await q.queueRecipe('op-1', 'r1');
      q.failWith['r1'] = firestoreError('unavailable');

      await q.pass(at: t0.add(const Duration(days: 3)));

      final row = (await q.rows())['op-1']!;
      expect(row.permanentlyFailed, isFalse);
      expect(row.firstFailedAt, t0.add(const Duration(days: 3)));
    });

    test(
      'a success leaves the queue and marks the device copy saved',
      () async {
        await q.queueRecipe('op-1', 'r1');

        await q.pass();

        expect(q.sent, ['r1']);
        expect(await q.rows(), isEmpty);
        final stored = await q.db.recipeDao.getRecipe('r1', QueueHarness.uid);
        expect(stored!.needsSync, isFalse);
      },
    );
  });
}
