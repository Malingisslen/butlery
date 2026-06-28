/// Direct unit tests for [ConversationMembership] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Inverse-index record for per-user conversation lookups. Covers: the create
/// factory (clock-pinned, both timestamps equal, flags default false), copyWith
/// (preserves id/isGroup/joinedAt), the Firestore round-trip through a fake
/// document (id comes from the doc, missing dates fall back to clock.now()), and
/// identity-by-conversationId equality.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/conversation_membership.dart';

void main() {
  group('create', () {
    test('pins both timestamps to now and defaults flags off', () {
      final t = DateTime.utc(2026, 1, 1);
      withClock(Clock.fixed(t), () {
        final m = ConversationMembership.create(
          conversationId: 'c1',
          conversationTitle: 'Chat',
          isGroup: true,
        );
        expect(m.lastActivityAt, t);
        expect(m.joinedAt, t);
        expect(m.hasUnread, isFalse);
        expect(m.isMuted, isFalse);
        expect(m.isPinned, isFalse);
        expect(m.isArchived, isFalse);
      });
    });
  });

  group('copyWith', () {
    test('changes a flag while preserving id, isGroup and joinedAt', () {
      final base = ConversationMembership(
        conversationId: 'c1',
        conversationTitle: 'Chat',
        isGroup: true,
        lastActivityAt: DateTime.utc(2026, 1, 2),
        joinedAt: DateTime.utc(2026, 1, 1),
      );
      final pinned = base.copyWith(isPinned: true);
      expect(pinned.isPinned, isTrue);
      expect(pinned.conversationId, 'c1');
      expect(pinned.isGroup, isTrue);
      expect(pinned.joinedAt, DateTime.utc(2026, 1, 1));
    });
  });

  group('Firestore round-trip', () {
    test('toFirestore → fromFirestore preserves the fields', () async {
      final fs = FakeFirebaseFirestore();
      final m = ConversationMembership(
        conversationId: 'conv1',
        conversationTitle: 'Family',
        isGroup: true,
        lastActivityAt: DateTime.utc(2026, 1, 2),
        joinedAt: DateTime.utc(2026, 1, 1),
        hasUnread: true,
        isMuted: true,
      );
      await fs.collection('m').doc('conv1').set(m.toFirestore());
      final snap = await fs.collection('m').doc('conv1').get();

      final restored = ConversationMembership.fromFirestore(snap);
      expect(restored.conversationId, 'conv1'); // from doc.id
      expect(restored.conversationTitle, 'Family');
      expect(restored.isGroup, isTrue);
      expect(restored.hasUnread, isTrue);
      expect(restored.isMuted, isTrue);
      expect(
        restored.lastActivityAt.isAtSameMomentAs(DateTime.utc(2026, 1, 2)),
        isTrue,
      );
    });

    test('missing dates fall back to clock.now()', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('m').doc('c2').set({
        'conversationTitle': 'X',
        'isGroup': false,
      });
      final snap = await fs.collection('m').doc('c2').get();

      final t = DateTime.utc(2026, 6, 1);
      withClock(Clock.fixed(t), () {
        final restored = ConversationMembership.fromFirestore(snap);
        expect(restored.lastActivityAt.isAtSameMomentAs(t), isTrue);
        expect(restored.joinedAt.isAtSameMomentAs(t), isTrue);
      });
    });
  });

  group('equality', () {
    test('is by conversationId only', () {
      final a = ConversationMembership(
        conversationId: 'c1',
        conversationTitle: 'A',
        isGroup: false,
        lastActivityAt: DateTime.utc(2026),
        joinedAt: DateTime.utc(2026),
      );
      final sameId = a.copyWith(conversationTitle: 'Different title');
      expect(a, equals(sameId));
      expect(a.hashCode, sameId.hashCode);

      final otherId = ConversationMembership(
        conversationId: 'c2',
        conversationTitle: 'A',
        isGroup: false,
        lastActivityAt: DateTime.utc(2026),
        joinedAt: DateTime.utc(2026),
      );
      expect(a == otherId, isFalse);
    });
  });
}
