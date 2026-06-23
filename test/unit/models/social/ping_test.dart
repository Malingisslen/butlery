/// Model round-trip + behaviour tests for [Ping] (BUT-407).
///
/// Focus: the model can survive a Firestore-shaped Map round-trip without
/// losing data, PingType.fromString falls back safely for unknown values
/// (forward-compat with newer clients), defaults are sensible, and the
/// message cap is enforced by the factory.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/social/ping.dart';

void main() {
  group('Ping model', () {
    test(
      'create() populates defaults: id, createdAt, expiresAt +10min, not acknowledged',
      () {
        final before = DateTime.now();
        final ping = Ping.create(
          groupId: 'group-1',
          fromUserId: 'user-1',
          type: PingType.nudge,
        );
        final after = DateTime.now();

        expect(ping.id, isNotEmpty);
        expect(ping.id.length, equals(36), reason: 'UUID v4 format');
        expect(ping.acknowledged, isFalse);
        expect(ping.toUserId, isNull);
        expect(ping.message, isNull);

        // createdAt is within the test window
        expect(
          ping.createdAt.isBefore(before.subtract(const Duration(seconds: 1))),
          isFalse,
        );
        expect(
          ping.createdAt.isAfter(after.add(const Duration(seconds: 1))),
          isFalse,
        );

        // expiresAt defaults to createdAt + 10min
        final delta = ping.expiresAt.difference(ping.createdAt);
        expect(delta, equals(kPingDefaultTtl));
        expect(delta, equals(const Duration(minutes: 10)));
      },
    );

    test('round-trips through toMap/fromMap without losing fields', () {
      final original = Ping.create(
        groupId: 'group-abc',
        fromUserId: 'alice',
        toUserId: 'bob',
        type: PingType.helpMe,
        message: 'Behöver hjälp med ugnen',
      );

      final map = original.toMap();
      final restored = Ping.fromMap(original.id, map);

      expect(restored.id, equals(original.id));
      expect(restored.groupId, equals(original.groupId));
      expect(restored.fromUserId, equals(original.fromUserId));
      expect(restored.toUserId, equals(original.toUserId));
      expect(restored.type, equals(original.type));
      expect(restored.message, equals(original.message));
      expect(restored.acknowledged, equals(original.acknowledged));
      // Timestamps round-trip within millisecond precision
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        equals(original.createdAt.millisecondsSinceEpoch),
      );
      expect(
        restored.expiresAt.millisecondsSinceEpoch,
        equals(original.expiresAt.millisecondsSinceEpoch),
      );
    });

    test(
      'broadcast ping (toUserId null) serializes and restores correctly',
      () {
        final broadcast = Ping.create(
          groupId: 'g1',
          fromUserId: 'sender',
          type: PingType.timerAlert,
        );

        expect(broadcast.isBroadcast, isTrue);

        final restored = Ping.fromMap(broadcast.id, broadcast.toMap());
        expect(restored.isBroadcast, isTrue);
        expect(restored.toUserId, isNull);
        expect(restored.type, equals(PingType.timerAlert));
      },
    );

    test(
      'PingType.fromString falls back to unknown for unrecognized values',
      () {
        expect(PingType.fromString('nudge'), equals(PingType.nudge));
        expect(PingType.fromString('timerAlert'), equals(PingType.timerAlert));
        expect(PingType.fromString('helpMe'), equals(PingType.helpMe));
        // Unknown / future types → `unknown` sentinel (not silently relabeled
        // as nudge, which would render wrong copy + wrong semantics).
        expect(PingType.fromString('newFutureType'), equals(PingType.unknown));
        expect(PingType.fromString(null), equals(PingType.unknown));
        expect(PingType.fromString(''), equals(PingType.unknown));
      },
    );

    test('message longer than 100 chars is truncated by create()', () {
      final longMsg = 'a' * 150;
      final ping = Ping.create(
        groupId: 'g',
        fromUserId: 'u',
        type: PingType.nudge,
        message: longMsg,
      );

      expect(ping.message, isNotNull);
      expect(ping.message!.length, equals(kPingMaxMessageLength));
      expect(ping.message!.length, equals(100));
    });

    test('acknowledged ping round-trips via copyWith + toMap/fromMap', () {
      final ping = Ping.create(
        groupId: 'g',
        fromUserId: 'u',
        type: PingType.nudge,
      );

      final acked = ping.copyWith(acknowledged: true);
      expect(acked.acknowledged, isTrue);
      expect(acked.id, equals(ping.id), reason: 'id preserved');

      final restored = Ping.fromMap(acked.id, acked.toMap());
      expect(restored.acknowledged, isTrue);
    });

    test('fromMap tolerates missing fields with safe defaults', () {
      final restored = Ping.fromMap('some-id', <String, dynamic>{});

      expect(restored.id, equals('some-id'));
      expect(restored.groupId, equals(''));
      expect(restored.fromUserId, equals(''));
      expect(restored.toUserId, isNull);
      expect(
        restored.type,
        equals(PingType.unknown),
        reason: 'fallback for missing type — unknown sentinel, not nudge',
      );
      expect(restored.acknowledged, isFalse);
      // expiresAt defaults to createdAt + 10min when absent
      final delta = restored.expiresAt.difference(restored.createdAt);
      expect(delta, equals(kPingDefaultTtl));
    });

    test('isExpired reflects expiresAt relative to now', () {
      final now = DateTime.now();
      final fresh = Ping(
        id: 'p1',
        groupId: 'g',
        fromUserId: 'u',
        type: PingType.nudge,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
      );
      final stale = Ping(
        id: 'p2',
        groupId: 'g',
        fromUserId: 'u',
        type: PingType.nudge,
        createdAt: now.subtract(const Duration(minutes: 20)),
        expiresAt: now.subtract(const Duration(minutes: 10)),
      );

      expect(fresh.isExpired, isFalse);
      expect(stale.isExpired, isTrue);
    });
  });
}
