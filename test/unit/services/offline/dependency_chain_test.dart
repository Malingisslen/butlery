// P6-U08b: order and dependencies (produktregler.md:186-187,
// TR::FLOW::08::ko::beroendekedja-misslyckas): "FIFO per entitet, parallellt
// mellan entiteter." "En post kan deklarera dependsOn: [opId] … Om beroendet
// permanent misslyckas markeras hela kedjan som misslyckad — aldrig
// halvvägs."

import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_support/base_unit_test.dart';
import 'queue_harness.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    QueueHarness.registerFallbacks();
  });

  group('decideQueueEntry', () {
    final now = DateTime(2026, 9, 27, 12);
    QueueEntryState entry({
      List<String> dependsOn = const [],
      DateTime? next,
      String entity = 'recipe:r1',
    }) => QueueEntryState(
      opId: 'op-b',
      entityKey: entity,
      dependsOn: dependsOn,
      nextAttemptAt: next,
    );

    QueueEntryDecision decide(
      QueueEntryState e, {
      Set<String> waiting = const {},
      Set<String> failed = const {},
      Set<String> blocked = const {},
      bool force = false,
    }) => decideQueueEntry(
      e,
      now: now,
      waiting: waiting,
      failed: failed,
      blockedEntities: blocked,
      force: force,
    );

    test('waits while a dependency is still queued', () {
      expect(
        decide(entry(dependsOn: ['op-a']), waiting: {'op-a', 'op-b'}),
        QueueEntryDecision.waits,
      );
    });

    test('a dependency that failed for good fails the entry too', () {
      expect(
        decide(entry(dependsOn: ['op-a']), failed: {'op-a'}),
        QueueEntryDecision.dependencyFailed,
      );
    });

    test('a dependency in neither queue has reached the server', () {
      expect(
        decide(entry(dependsOn: ['op-a']), waiting: {'op-b'}),
        QueueEntryDecision.send,
      );
    });

    test('an earlier entry to the same entity holds it back', () {
      expect(decide(entry(), blocked: {'recipe:r1'}), QueueEntryDecision.waits);
      expect(
        decide(entry(entity: 'recipe:r2'), blocked: {'recipe:r1'}),
        QueueEntryDecision.send,
      );
    });

    test('force skips the retry time but never the order', () {
      final later = now.add(const Duration(seconds: 5));
      expect(decide(entry(next: later)), QueueEntryDecision.backoff);
      expect(decide(entry(next: later), force: true), QueueEntryDecision.send);
      expect(
        decide(entry(dependsOn: ['op-a']), waiting: {'op-a'}, force: true),
        QueueEntryDecision.waits,
      );
    });
  });

  group('the queue', () {
    late QueueHarness q;

    setUp(() => q = QueueHarness.create());
    tearDown(() => q.dispose());

    test('the dependent entry waits while its dependency is retried', () async {
      await q.queueRecipe('op-a', 'r1', operation: SyncOperation.create);
      await q.queueRecipe('op-b', 'r2', dependsOn: ['op-a']);
      q.failWith['r1'] = firestoreError('unavailable');

      await q.pass();

      final rows = await q.rows();
      expect(q.sent, isEmpty);
      expect(rows['op-b']!.retryCount, 0, reason: 'never attempted');
      expect(rows['op-b']!.permanentlyFailed, isFalse);
    });

    test('when the dependency fails for good, the whole chain is marked and '
        'the dependent is never sent', () async {
      await q.queueRecipe('op-a', 'r1', operation: SyncOperation.create);
      await q.queueRecipe('op-b', 'r2', dependsOn: ['op-a']);
      await q.queueRecipe('op-c', 'r3', dependsOn: ['op-b']);
      q.failWith['r1'] = firestoreError('permission-denied');

      await q.pass();

      final rows = await q.rows();
      expect(q.sent, isEmpty);
      expect(rows.values.every((r) => r.permanentlyFailed), isTrue);
      expect(
        QueuedChangeReason.parse(rows['op-a']!.lastError),
        QueuedChangeReason.permissionDenied,
      );
      expect(
        QueuedChangeReason.parse(rows['op-b']!.lastError),
        QueuedChangeReason.dependencyFailed,
      );
      expect(
        QueuedChangeReason.parse(rows['op-c']!.lastError),
        QueuedChangeReason.dependencyFailed,
      );
    });

    test('once the dependency is saved, the dependent goes in the same '
        'pass', () async {
      await q.queueRecipe('op-a', 'r1', operation: SyncOperation.create);
      await q.queueRecipe('op-b', 'r2', dependsOn: ['op-a']);

      await q.pass();

      expect(q.sent, ['r1', 'r2']);
      expect(await q.rows(), isEmpty);
    });

    test('an entry depending on one that already waits for the user is '
        'marked at the next pass', () async {
      await q.queueRecipe('op-a', 'r1');
      await q.db.syncQueueDao.markPermanentlyFailed(
        'op-a',
        reason: 'not-found',
      );
      await q.queueRecipe('op-b', 'r2', dependsOn: ['op-a']);

      await q.pass();

      final rows = await q.rows();
      expect(q.sent, isEmpty);
      expect(rows['op-b']!.permanentlyFailed, isTrue);
      expect(rows['op-a']!.lastError, 'not-found', reason: 'kept its cause');
    });

    test('FIFO per entity, parallel between entities', () async {
      await q.queueRecipe('op-1', 'r1');
      await q.queueRecipe(
        'op-2',
        'r1',
        at: QueueHarness.t0.add(const Duration(seconds: 1)),
      );
      await q.queueRecipe(
        'op-3',
        'r2',
        at: QueueHarness.t0.add(const Duration(seconds: 2)),
      );
      q.failWith['r1'] = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await q.pass(at: QueueHarness.t0.add(const Duration(seconds: 3)));

      final rows = await q.rows();
      expect(q.sent, ['r2'], reason: 'the other recipe does not wait');
      expect(rows['op-1']!.retryCount, 1);
      expect(
        rows['op-2']!.retryCount,
        0,
        reason: 'the later change to r1 waits for the earlier one',
      );
    });
  });
}
