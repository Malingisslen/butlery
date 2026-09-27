// P6-U08b: permanent errors (produktregler.md:189, TR::FLOW::08::ko::
// permanent-fel): "4xx utom 408/429 försöks aldrig igen. Posten flyttas till
// Väntar på dig med orsak i ord." Classified from the error code, never from
// the message text.

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_support/base_unit_test.dart';
import 'queue_harness.dart';

FirebaseException _error(String code, {String plugin = 'cloud_firestore'}) =>
    FirebaseException(plugin: plugin, code: code);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    QueueHarness.registerFallbacks();
  });

  group('the classifier', () {
    test('not found and no permission are permanent, with their cause', () {
      expect(
        permanentFailureReason(_error('not-found')),
        QueuedChangeReason.notFound,
      );
      expect(
        permanentFailureReason(
          _error('object-not-found', plugin: 'firebase_storage'),
        ),
        QueuedChangeReason.notFound,
      );
      expect(
        permanentFailureReason(_error('permission-denied')),
        QueuedChangeReason.permissionDenied,
      );
      expect(
        permanentFailureReason(
          _error('unauthorized', plugin: 'firebase_storage'),
        ),
        QueuedChangeReason.permissionDenied,
      );
    });

    test('a request the server will always refuse is permanent', () {
      for (final code in [
        'invalid-argument',
        'failed-precondition',
        'out-of-range',
        'already-exists',
      ]) {
        expect(
          permanentFailureReason(_error(code)),
          QueuedChangeReason.unknown,
          reason: code,
        );
      }
    });

    test('401 for the signed-in user is retried: the token refreshes', () {
      // QUEUE-401: the one exception to "4xx utom 408/429"
      // (produktregler.md:188); the 24 h limit still applies (:187).
      expect(permanentFailureReason(_error('unauthenticated')), isNull);
      expect(
        permanentFailureReason(_error('permission-denied')),
        QueuedChangeReason.permissionDenied,
      );
    });

    test('408, 429 and server trouble are retried', () {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'resource-exhausted',
        'aborted',
        'internal',
        'unknown',
        'cancelled',
      ]) {
        expect(permanentFailureReason(_error(code)), isNull, reason: code);
      }
      expect(
        permanentFailureReason(
          _error('quota-exceeded', plugin: 'firebase_storage'),
        ),
        isNull,
      );
    });

    test('the message text is never read', () {
      expect(
        permanentFailureReason(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'not-found permission-denied too large',
          ),
        ),
        isNull,
      );
      expect(permanentFailureReason(Exception('permission-denied')), isNull);
      expect(permanentFailureReason(StateError('not-found')), isNull);
    });

    test('the stored diagnostic is the code, never the message', () {
      expect(
        queueErrorCode(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Pannbiffar för Anna',
          ),
        ),
        'unavailable',
      );
    });
  });

  group('the queue', () {
    late QueueHarness q;

    setUp(() => q = QueueHarness.create());
    tearDown(() => q.dispose());

    test('a refused write goes to "Väntar på dig" with its cause, is kept, '
        'and is never sent again by itself', () async {
      await q.queueRecipe('op-1', 'r1');
      q.failWith['r1'] = _error('permission-denied');

      await q.pass();

      final row = (await q.rows())['op-1']!;
      expect(row.permanentlyFailed, isTrue);
      expect(
        QueuedChangeReason.parse(row.lastError),
        QueuedChangeReason.permissionDenied,
      );

      q.failWith.remove('r1');
      await q.pass(at: QueueHarness.t0.add(const Duration(hours: 1)));
      await q.pass(force: true);
      expect(q.sent, isEmpty);
      expect(await q.rows(), contains('op-1'));
    });

    test('a 401 is retried within the 24 h and sent once the token is '
        'fresh', () async {
      await q.queueRecipe('op-1', 'r1');
      q.failWith['r1'] = _error('unauthenticated');

      await q.pass();

      final row = (await q.rows())['op-1']!;
      expect(row.permanentlyFailed, isFalse);

      q.failWith.remove('r1');
      await q.pass(at: QueueHarness.t0.add(const Duration(hours: 1)));
      expect(q.sent, ['r1']);
    });

    test(
      'a 401 that lasts past the 24 h becomes a permanent failure',
      () async {
        await q.queueRecipe('op-1', 'r1');
        q.failWith['r1'] = _error('unauthenticated');

        await q.pass();
        await q.pass(at: QueueHarness.t0.add(const Duration(hours: 25)));

        final row = (await q.rows())['op-1']!;
        expect(row.permanentlyFailed, isTrue);
        expect(
          QueuedChangeReason.parse(row.lastError),
          QueuedChangeReason.retriesExhausted,
        );
      },
    );

    test('"Försök synka nu" does not call a refused change saved', () async {
      await q.queueRecipe('op-1', 'r1');
      q.failWith['r1'] = _error('permission-denied');

      final result = await withClock(
        Clock.fixed(QueueHarness.t0),
        () => q.manager.syncNow(isOnline: true),
      );

      expect(result.success, isFalse);
      expect((await q.rows())['op-1']!.permanentlyFailed, isTrue);
    });

    test('the failure is what the saffron counter counts', () async {
      await q.queueRecipe('op-1', 'r1');
      await q.queueRecipe('op-2', 'r2');
      q.failWith['r1'] = _error('not-found');
      q.failWith['r2'] = _error('unavailable');

      await q.pass();

      final counts = await q.db.watchQueueCounts(QueueHarness.uid).first;
      expect(counts, const QueueCounts(draining: 1, needsUser: 1));
      expect(
        QueuedChangeReason.parse((await q.rows())['op-1']!.lastError),
        QueuedChangeReason.notFound,
      );
    });
  });
}
