/// Unit tests for SocialRequest (friend + group-invitation unified model).
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/friend_request.dart' show FriendRequestStatus;
import 'package:butlery/models/group_invitation.dart'
    show GroupInvitationStatus;
import 'package:butlery/models/social_request.dart';

void main() {
  group('friend-request factory', () {
    test('builds with type=friend and 7-day expiry', () {
      withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () {
        final r = SocialRequest.friendRequest(
          fromUserId: 'alice',
          toUserId: 'bob',
        );
        expect(r.type, SocialRequestType.friend);
        expect(r.status, SocialRequestStatus.pending);
        expect(r.fromUserId, 'alice');
        expect(r.toUserId, 'bob');
        expect(r.expiresAt, DateTime.utc(2026, 1, 8));
        // No group fields
        expect(r.groupId, isNull);
        expect(r.groupName, isNull);
      });
    });

    test('generates non-empty UUID id', () {
      final r = SocialRequest.friendRequest(fromUserId: 'a', toUserId: 'b');
      expect(r.id, isNotEmpty);
    });
  });

  group('group-invitation factory', () {
    test('builds with type=groupInvitation and stores group fields', () {
      withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () {
        final r = SocialRequest.groupInvitation(
          fromUserId: 'alice',
          toUserId: 'bob',
          groupId: 'g1',
          groupName: 'Squad',
          groupEmoji: '👥',
          fromUserName: 'Alice',
        );
        expect(r.type, SocialRequestType.groupInvitation);
        expect(r.groupId, 'g1');
        expect(r.groupName, 'Squad');
        expect(r.groupEmoji, '👥');
        expect(r.fromUserName, 'Alice');
        expect(r.expiresAt, DateTime.utc(2026, 1, 8));
      });
    });
  });

  group('serialization round-trip', () {
    test('round-trips a friend request', () {
      final original = SocialRequest.friendRequest(
        fromUserId: 'alice',
        toUserId: 'bob',
        message: 'Hej!',
      );
      final restored = SocialRequest.fromMap(
        original.id,
        original.toFirestore(),
      );
      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.fromUserId, original.fromUserId);
      expect(restored.toUserId, original.toUserId);
      expect(restored.message, original.message);
      expect(restored.status, original.status);
      // Timestamps round-trip through AppTimestamp's UTC normalization.
      expect(restored.sentAt.toUtc(), original.sentAt.toUtc());
      expect(restored.expiresAt.toUtc(), original.expiresAt.toUtc());
    });

    test('round-trips a group invitation with all group fields', () {
      final original = SocialRequest.groupInvitation(
        fromUserId: 'alice',
        toUserId: 'bob',
        groupId: 'g1',
        groupName: 'Squad',
        groupEmoji: '👥',
        fromUserName: 'Alice',
      );
      final restored = SocialRequest.fromMap(
        original.id,
        original.toFirestore(),
      );
      expect(restored.type, SocialRequestType.groupInvitation);
      expect(restored.groupId, 'g1');
      expect(restored.groupName, 'Squad');
      expect(restored.groupEmoji, '👥');
      expect(restored.fromUserName, 'Alice');
    });

    test('toFirestore omits group fields when null (friend request)', () {
      final r = SocialRequest.friendRequest(fromUserId: 'a', toUserId: 'b');
      final payload = r.toFirestore();
      expect(payload.containsKey('groupId'), isFalse);
      expect(payload.containsKey('groupName'), isFalse);
      expect(payload.containsKey('groupEmoji'), isFalse);
      expect(payload.containsKey('fromUserName'), isFalse);
    });

    test('fromMap unknown type → friend (safe enum fallback)', () {
      final r = SocialRequest.fromMap('id', {
        'type': 'something-new',
        'fromUserId': 'a',
        'toUserId': 'b',
        'status': 'pending',
      });
      expect(r.type, SocialRequestType.friend);
    });

    test('fromMap unknown status → pending (safe enum fallback)', () {
      final r = SocialRequest.fromMap('id', {
        'type': 'friend',
        'fromUserId': 'a',
        'toUserId': 'b',
        'status': 'huh',
      });
      expect(r.status, SocialRequestStatus.pending);
    });
  });

  group('predicates', () {
    test('isPending only when status == pending', () {
      final pending = SocialRequest.friendRequest(
        fromUserId: 'a',
        toUserId: 'b',
      );
      expect(pending.isPending, isTrue);

      final accepted = pending.copyWith(status: SocialRequestStatus.accepted);
      expect(accepted.isPending, isFalse);
    });

    test('isExpired true when status==expired OR now > expiresAt', () {
      // Explicit expired status
      final r1 = SocialRequest.friendRequest(
        fromUserId: 'a',
        toUserId: 'b',
      ).copyWith(status: SocialRequestStatus.expired);
      expect(r1.isExpired, isTrue);

      // Time-based expiry — clock past expiresAt
      withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () {
        final r = SocialRequest.friendRequest(fromUserId: 'a', toUserId: 'b');
        // Inside expiry window
        expect(r.isExpired, isFalse);

        withClock(Clock.fixed(DateTime.utc(2026, 1, 10)), () {
          expect(r.isExpired, isTrue);
        });
      });
    });

    test('isFriendRequest + isGroupInvitation discriminators', () {
      final friend = SocialRequest.friendRequest(
        fromUserId: 'a',
        toUserId: 'b',
      );
      expect(friend.isFriendRequest, isTrue);
      expect(friend.isGroupInvitation, isFalse);

      final invite = SocialRequest.groupInvitation(
        fromUserId: 'a',
        toUserId: 'b',
        groupId: 'g',
        groupName: 'Sq',
        groupEmoji: 'X',
        fromUserName: 'A',
      );
      expect(invite.isFriendRequest, isFalse);
      expect(invite.isGroupInvitation, isTrue);
    });
  });

  group('legacy converters', () {
    test('toFriendRequest maps status by name', () {
      final r = SocialRequest.friendRequest(
        fromUserId: 'alice',
        toUserId: 'bob',
      ).copyWith(status: SocialRequestStatus.accepted);
      final fr = r.toFriendRequest();
      expect(fr.id, r.id);
      expect(fr.fromUserId, 'alice');
      expect(fr.toUserId, 'bob');
      expect(fr.status, FriendRequestStatus.accepted);
    });

    test('toGroupInvitation maps status + group fields', () {
      final r = SocialRequest.groupInvitation(
        fromUserId: 'alice',
        toUserId: 'bob',
        groupId: 'g1',
        groupName: 'Squad',
        groupEmoji: '👥',
        fromUserName: 'Alice',
      ).copyWith(status: SocialRequestStatus.rejected);

      final gi = r.toGroupInvitation();
      expect(gi.id, r.id);
      expect(gi.groupId, 'g1');
      expect(gi.groupName, 'Squad');
      expect(gi.groupEmoji, '👥');
      expect(gi.fromUserName, 'Alice');
      expect(gi.status, GroupInvitationStatus.rejected);
    });

    test(
      'toGroupInvitation falls back to "" / "👥" when group fields null',
      () {
        // Construct a friend-typed request and convert — fields are null.
        final r = SocialRequest.friendRequest(fromUserId: 'a', toUserId: 'b');
        final gi = r.toGroupInvitation();
        expect(gi.groupId, '');
        expect(gi.groupName, '');
        expect(gi.groupEmoji, '👥');
        expect(gi.fromUserName, '');
      },
    );
  });

  group('equality + hash', () {
    test('id-only equality', () {
      final a = SocialRequest.friendRequest(fromUserId: 'a', toUserId: 'b');
      final b = SocialRequest(
        id: a.id,
        type: SocialRequestType.groupInvitation, // different type
        fromUserId: 'x', // different fields
        toUserId: 'y',
        sentAt: DateTime.utc(2026, 1, 1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different id → unequal', () {
      final a = SocialRequest.friendRequest(fromUserId: 'a', toUserId: 'b');
      final b = SocialRequest.friendRequest(fromUserId: 'a', toUserId: 'b');
      expect(a, isNot(b)); // different UUIDs
    });

    test('identical short-circuit', () {
      final r = SocialRequest.friendRequest(fromUserId: 'a', toUserId: 'b');
      expect(r == r, isTrue);
    });
  });

  test('toString includes id + type + fromUser + toUser + status', () {
    final r = SocialRequest.friendRequest(fromUserId: 'alice', toUserId: 'bob');
    final s = r.toString();
    expect(s, contains(r.id));
    expect(s, contains('alice'));
    expect(s, contains('bob'));
    expect(s, contains('pending'));
  });
}
