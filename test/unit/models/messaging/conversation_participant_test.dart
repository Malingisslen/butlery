/// Direct unit tests for [ConversationParticipant] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Per-participant record in a conversation subcollection. Covers the
/// clock-pinned create factory, copyWith (preserves the immutable identity +
/// joinedAt), the Firestore round-trip via a fake document (participantId from
/// doc.id, role via safe-enum, displayName "Unknown" default, missing dates →
/// clock.now()), and identity-by-(conversationId, participantId) equality.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/conversation_participant.dart';

void main() {
  group('create', () {
    test('pins joinedAt/lastReadAt to now and defaults to member', () {
      final t = DateTime.utc(2026, 1, 1);
      withClock(Clock.fixed(t), () {
        final p = ConversationParticipant.create(
          conversationId: 'c1',
          participantId: 'u1',
          displayName: 'Alice',
        );
        expect(p.joinedAt, t);
        expect(p.lastReadAt, t);
        expect(p.role, ParticipantRole.member);
        expect(p.isMuted, isFalse);
      });
    });
  });

  group('copyWith', () {
    test('updates role while preserving identity + joinedAt', () {
      final base = ConversationParticipant(
        conversationId: 'c1',
        participantId: 'u1',
        displayName: 'Alice',
        joinedAt: DateTime.utc(2026, 1, 1),
        lastReadAt: DateTime.utc(2026, 1, 1),
      );
      final promoted = base.copyWith(role: ParticipantRole.admin);
      expect(promoted.role, ParticipantRole.admin);
      expect(promoted.conversationId, 'c1');
      expect(promoted.participantId, 'u1');
      expect(promoted.joinedAt, DateTime.utc(2026, 1, 1));
    });
  });

  group('Firestore round-trip', () {
    test('toFirestore → fromFirestore preserves fields, id from doc', () async {
      final fs = FakeFirebaseFirestore();
      final p = ConversationParticipant(
        conversationId: 'c1',
        participantId: 'u1',
        displayName: 'Alice',
        avatarUrl: 'https://img/a.jpg',
        joinedAt: DateTime.utc(2026, 1, 1),
        lastReadAt: DateTime.utc(2026, 1, 2),
        role: ParticipantRole.owner,
        isMuted: true,
      );
      await fs.collection('p').doc('u1').set(p.toFirestore());
      final snap = await fs.collection('p').doc('u1').get();

      final restored = ConversationParticipant.fromFirestore(snap);
      expect(restored.participantId, 'u1'); // doc.id
      expect(restored.conversationId, 'c1');
      expect(restored.displayName, 'Alice');
      expect(restored.avatarUrl, 'https://img/a.jpg');
      expect(restored.role, ParticipantRole.owner);
      expect(restored.isMuted, isTrue);
      expect(
        restored.lastReadAt.isAtSameMomentAs(DateTime.utc(2026, 1, 2)),
        isTrue,
      );
    });

    test('defaults: Unknown name, member role, clock.now() dates', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('p').doc('u2').set({'conversationId': 'c1'});
      final snap = await fs.collection('p').doc('u2').get();

      final t = DateTime.utc(2026, 6, 1);
      withClock(Clock.fixed(t), () {
        final restored = ConversationParticipant.fromFirestore(snap);
        expect(restored.displayName, 'Unknown');
        expect(restored.role, ParticipantRole.member); // safe-enum default
        expect(restored.joinedAt.isAtSameMomentAs(t), isTrue);
        expect(restored.avatarUrl, isNull);
      });
    });
  });

  group('equality', () {
    test('is by (conversationId, participantId)', () {
      final a = ConversationParticipant(
        conversationId: 'c1',
        participantId: 'u1',
        displayName: 'Alice',
        joinedAt: DateTime.utc(2026),
        lastReadAt: DateTime.utc(2026),
      );
      // Same identity, different display name/role → equal.
      expect(
        a,
        equals(a.copyWith(displayName: 'Bob', role: ParticipantRole.admin)),
      );
      // Different participant → not equal.
      final other = ConversationParticipant(
        conversationId: 'c1',
        participantId: 'u2',
        displayName: 'Alice',
        joinedAt: DateTime.utc(2026),
        lastReadAt: DateTime.utc(2026),
      );
      expect(a == other, isFalse);
    });
  });
}
