/// Unit tests for BlockRecord.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/block_record.dart';

void main() {
  group('compositeId', () {
    test('joins blocker and blocked with underscore', () {
      expect(BlockRecord.compositeId('alice', 'bob'), 'alice_bob');
    });

    test('order matters — blocker first', () {
      expect(
        BlockRecord.compositeId('a', 'b'),
        isNot(BlockRecord.compositeId('b', 'a')),
      );
    });
  });

  group('BlockRecord.create', () {
    test('uses compositeId for id', () {
      final r = BlockRecord.create(blockerId: 'alice', blockedId: 'bob');
      expect(r.id, 'alice_bob');
      expect(r.blockerId, 'alice');
      expect(r.blockedId, 'bob');
    });

    test('stamps blockedAt from clock.now()', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23)), () {
        final r = BlockRecord.create(blockerId: 'alice', blockedId: 'bob');
        expect(r.blockedAt, DateTime.utc(2026, 5, 23));
      });
    });
  });

  group('serialization round-trip', () {
    test('toFirestore + fromFirestore preserves all fields', () {
      final original = BlockRecord(
        id: 'alice_bob',
        blockerId: 'alice',
        blockedId: 'bob',
        blockedAt: DateTime.utc(2026, 1, 1, 10),
      );

      final payload = original.toFirestore();
      expect(payload['blockerId'], 'alice');
      expect(payload['blockedId'], 'bob');
      expect(
        payload['blockedAt'],
        DateTime.utc(2026, 1, 1, 10).toIso8601String(),
      );
      // toFirestore should NOT include id — the doc id IS the composite id
      expect(payload.containsKey('id'), isFalse);

      final restored = BlockRecord.fromFirestore(payload, original.id);
      expect(restored.id, original.id);
      expect(restored.blockerId, original.blockerId);
      expect(restored.blockedId, original.blockedId);
      expect(restored.blockedAt, original.blockedAt);
    });

    test(
      'fromFirestore tolerates missing optional-shape fields via safe defaults',
      () {
        final restored = BlockRecord.fromFirestore({}, 'someid');
        expect(restored.id, 'someid');
        expect(restored.blockerId, '');
        expect(restored.blockedId, '');
        // blockedAt is safeRequiredDateTime — falls back to now/epoch
        expect(restored.blockedAt, isA<DateTime>());
      },
    );
  });
}
