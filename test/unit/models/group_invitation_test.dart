// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/group_invitation.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('GroupInvitation', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Matlagningsgruppen',
          groupEmoji: '👨‍🍳',
          fromUserId: 'user_789',
          fromUserName: 'Anna Andersson',
          toUserId: 'user_abc',
        );

        expect(invitation.id, equals('inv_123'));
        expect(invitation.groupId, equals('group_456'));
        expect(invitation.groupName, equals('Matlagningsgruppen'));
        expect(invitation.groupEmoji, equals('👨‍🍳'));
        expect(invitation.fromUserId, equals('user_789'));
        expect(invitation.fromUserName, equals('Anna Andersson'));
        expect(invitation.toUserId, equals('user_abc'));
        expect(invitation.status, equals(GroupInvitationStatus.pending));
        expect(invitation.respondedAt, isNull);
        expect(invitation.personalMessage, isNull);
      });

      test('should create with all parameters', () {
        final sentAt = DateTime.now().subtract(const Duration(hours: 2));
        final respondedAt = DateTime.now();
        final expiresAt = DateTime.now().add(const Duration(days: 5));

        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Bakningsgruppen',
          groupEmoji: '🍞',
          fromUserId: 'user_789',
          fromUserName: 'Erik Eriksson',
          toUserId: 'user_abc',
          status: GroupInvitationStatus.accepted,
          sentAt: sentAt,
          respondedAt: respondedAt,
          personalMessage: 'Vill du vara med och baka?',
          expiresAt: expiresAt,
        );

        expect(invitation.status, equals(GroupInvitationStatus.accepted));
        expect(invitation.sentAt, equals(sentAt));
        expect(invitation.respondedAt, equals(respondedAt));
        expect(invitation.personalMessage, equals('Vill du vara med och baka?'));
        expect(invitation.expiresAt, equals(expiresAt));
      });

      test('should set default expiration to 7 days', () {
        final now = DateTime.now();
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
        );

        final difference = invitation.expiresAt.difference(now);
        expect(difference.inDays, greaterThanOrEqualTo(6));
        expect(difference.inDays, lessThanOrEqualTo(7));
      });

      test('should set default sentAt to current time', () {
        final before = DateTime.now();
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
        );
        final after = DateTime.now();

        expect(invitation.sentAt.isAfter(before) || invitation.sentAt.isAtSameMomentAs(before), isTrue);
        expect(invitation.sentAt.isBefore(after) || invitation.sentAt.isAtSameMomentAs(after), isTrue);
      });
    });

    group('Factory Methods', () {
      test('should create with auto-generated ID', () {
        final invitation = GroupInvitation.create(
          groupId: 'group_456',
          groupName: 'Matlagningsgruppen',
          groupEmoji: '👨‍🍳',
          fromUserId: 'user_789',
          fromUserName: 'Anna Andersson',
          toUserId: 'user_abc',
        );

        expect(invitation.id, isNotEmpty);
        expect(invitation.id.length, equals(36)); // UUID v4 format
        expect(invitation.status, equals(GroupInvitationStatus.pending));
      });

      test('should create with personal message', () {
        final invitation = GroupInvitation.create(
          groupId: 'group_456',
          groupName: 'Bakningsgruppen',
          groupEmoji: '🍞',
          fromUserId: 'user_789',
          fromUserName: 'Erik Eriksson',
          toUserId: 'user_abc',
          personalMessage: 'Hej! Vill du vara med i vår bakningsgrupp?',
        );

        expect(invitation.personalMessage, equals('Hej! Vill du vara med i vår bakningsgrupp?'));
      });
    });

    group('Status Management', () {
      late GroupInvitation baseInvitation;

      setUp(() {
        baseInvitation = GroupInvitation.create(
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
        );
      });

      test('should accept invitation', () {
        final before = DateTime.now();
        final accepted = baseInvitation.accept();
        final after = DateTime.now();

        expect(accepted.status, equals(GroupInvitationStatus.accepted));
        expect(accepted.respondedAt, isNotNull);
        expect(accepted.respondedAt!.isAfter(before) || accepted.respondedAt!.isAtSameMomentAs(before), isTrue);
        expect(accepted.respondedAt!.isBefore(after) || accepted.respondedAt!.isAtSameMomentAs(after), isTrue);
        expect(accepted.id, equals(baseInvitation.id)); // Immutability check
      });

      test('should reject invitation', () {
        final rejected = baseInvitation.reject();

        expect(rejected.status, equals(GroupInvitationStatus.rejected));
        expect(rejected.respondedAt, isNotNull);
        expect(rejected.id, equals(baseInvitation.id));
      });

      test('should cancel invitation', () {
        final cancelled = baseInvitation.cancel();

        expect(cancelled.status, equals(GroupInvitationStatus.cancelled));
        expect(cancelled.respondedAt, isNotNull);
        expect(cancelled.id, equals(baseInvitation.id));
      });

      test('should check pending status correctly', () {
        expect(baseInvitation.isPending, isTrue);

        final accepted = baseInvitation.accept();
        expect(accepted.isPending, isFalse);

        final rejected = baseInvitation.reject();
        expect(rejected.isPending, isFalse);
      });

      test('should check accepted status', () {
        expect(baseInvitation.isAccepted, isFalse);

        final accepted = baseInvitation.accept();
        expect(accepted.isAccepted, isTrue);
      });

      test('should check rejected status', () {
        expect(baseInvitation.isRejected, isFalse);

        final rejected = baseInvitation.reject();
        expect(rejected.isRejected, isTrue);
      });

      test('should check cancelled status', () {
        expect(baseInvitation.isCancelled, isFalse);

        final cancelled = baseInvitation.cancel();
        expect(cancelled.isCancelled, isTrue);
      });

      test('should check completed status', () {
        expect(baseInvitation.isCompleted, isFalse);

        final accepted = baseInvitation.accept();
        expect(accepted.isCompleted, isTrue);

        final rejected = baseInvitation.reject();
        expect(rejected.isCompleted, isTrue);
      });
    });

    group('Expiration Handling', () {
      test('should detect expired invitation', () {
        final expired = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(expired.isExpired, isTrue);
        expect(expired.isPending, isFalse); // Pending checks expiration
      });

      test('should detect non-expired invitation', () {
        final valid = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          expiresAt: DateTime.now().add(const Duration(days: 3)),
        );

        expect(valid.isExpired, isFalse);
        expect(valid.isPending, isTrue);
      });

      test('should detect expired status enum', () {
        final expired = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          status: GroupInvitationStatus.expired,
          expiresAt: DateTime.now().add(const Duration(days: 3)), // Still has time
        );

        expect(expired.isExpired, isTrue);
      });
    });

    group('Swedish Localization - Time Ago', () {
      test('should show "Nu" for recent invitation', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          sentAt: DateTime.now(),
        );

        expect(invitation.timeAgoText, equals('Nu'));
      });

      test('should show minutes for recent time', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          sentAt: DateTime.now().subtract(const Duration(minutes: 30)),
        );

        expect(invitation.timeAgoText, equals('30 min sedan'));
      });

      test('should show hours for same day', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          sentAt: DateTime.now().subtract(const Duration(hours: 5)),
        );

        expect(invitation.timeAgoText, equals('5 tim sedan'));
      });

      test('should show days for recent days', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          sentAt: DateTime.now().subtract(const Duration(days: 3)),
        );

        expect(invitation.timeAgoText, equals('3 dagar sedan'));
      });

      test('should show weeks for old invitations', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          sentAt: DateTime.now().subtract(const Duration(days: 14)),
        );

        expect(invitation.timeAgoText, equals('2 veckor sedan'));
      });
    });

    group('Swedish Localization - Expires In', () {
      test('should show "Utgången" for expired', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(invitation.expiresInText, equals('Utgången'));
      });

      test('should show days remaining', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          expiresAt: DateTime.now().add(const Duration(days: 5)),
        );

        expect(invitation.expiresInText, equals('5 dagar kvar'));
      });

      test('should show hours remaining', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          expiresAt: DateTime.now().add(const Duration(hours: 12)),
        );

        expect(invitation.expiresInText, equals('12 timmar kvar'));
      });

      test('should show minutes remaining', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          expiresAt: DateTime.now().add(const Duration(minutes: 45)),
        );

        expect(invitation.expiresInText, equals('45 minuter kvar'));
      });

      test('should show "Går ut snart" for imminent expiry', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          expiresAt: DateTime.now().add(const Duration(seconds: 30)),
        );

        expect(invitation.expiresInText, equals('Går ut snart'));
      });
    });

    group('Notification Text', () {
      test('should generate notification without personal message', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Matlagningsgruppen',
          groupEmoji: '👨‍🍳',
          fromUserId: 'user_789',
          fromUserName: 'Anna Andersson',
          toUserId: 'user_abc',
        );

        expect(invitation.notificationText,
            equals('Anna Andersson bjöd in dig till gruppen 👨‍🍳 Matlagningsgruppen'));
      });

      test('should generate notification with personal message', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Matlagningsgruppen',
          groupEmoji: '👨‍🍳',
          fromUserId: 'user_789',
          fromUserName: 'Anna Andersson',
          toUserId: 'user_abc',
          personalMessage: 'Vill du laga mat tillsammans?',
        );

        expect(invitation.notificationText,
            equals('Anna Andersson bjöd in dig till gruppen 👨‍🍳 Matlagningsgruppen: "Vill du laga mat tillsammans?"'));
      });

      test('should generate short notification text', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Matlagningsgruppen',
          groupEmoji: '👨‍🍳',
          fromUserId: 'user_789',
          fromUserName: 'Anna Andersson',
          toUserId: 'user_abc',
        );

        expect(invitation.shortNotificationText,
            equals('Anna Andersson → 👨‍🍳 Matlagningsgruppen'));
      });
    });

    group('Status Display', () {
      test('should return correct status color for pending', () {
        final pending = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
        );

        expect(pending.statusColorName, equals('primary'));
      });

      test('should return warning color for expired pending', () {
        final expired = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(expired.statusColorName, equals('warning'));
      });

      test('should return success color for accepted', () {
        final accepted = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          status: GroupInvitationStatus.accepted,
        );

        expect(accepted.statusColorName, equals('success'));
      });

      test('should return error color for rejected and cancelled', () {
        final rejected = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          status: GroupInvitationStatus.rejected,
        );

        final cancelled = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          status: GroupInvitationStatus.cancelled,
        );

        expect(rejected.statusColorName, equals('error'));
        expect(cancelled.statusColorName, equals('error'));
      });

      test('should return correct status text in Swedish', () {
        final pending = GroupInvitation.create(
          groupId: 'g1',
          groupName: 'Test',
          groupEmoji: '👥',
          fromUserId: 'u1',
          fromUserName: 'User',
          toUserId: 'u2',
        );

        expect(pending.statusText, equals('Väntande'));

        final accepted = pending.accept();
        expect(accepted.statusText, equals('Accepterad'));

        final rejected = pending.reject();
        expect(rejected.statusText, equals('Avvisad'));

        final cancelled = pending.cancel();
        expect(cancelled.statusText, equals('Avbruten'));

        final expired = GroupInvitation(
          id: 'inv_123',
          groupId: 'g1',
          groupName: 'Test',
          groupEmoji: '👥',
          fromUserId: 'u1',
          fromUserName: 'User',
          toUserId: 'u2',
          status: GroupInvitationStatus.expired,
        );
        expect(expired.statusText, equals('Utgången'));
      });
    });

    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        final now = DateTime.now();
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Matlagningsgruppen',
          groupEmoji: '👨‍🍳',
          fromUserId: 'user_789',
          fromUserName: 'Anna Andersson',
          toUserId: 'user_abc',
          status: GroupInvitationStatus.pending,
          sentAt: now,
          personalMessage: 'Test message',
          expiresAt: now.add(const Duration(days: 7)),
        );

        final data = invitation.toFirestore();

        expect(data['groupId'], equals('group_456'));
        expect(data['groupName'], equals('Matlagningsgruppen'));
        expect(data['groupEmoji'], equals('👨‍🍳'));
        expect(data['fromUserId'], equals('user_789'));
        expect(data['fromUserName'], equals('Anna Andersson'));
        expect(data['toUserId'], equals('user_abc'));
        expect(data['status'], equals('pending'));
        expect(data['personalMessage'], equals('Test message'));
        expect(data['respondedAt'], isNull);
        expect(data['sentAt'], isNotNull);
        expect(data['expiresAt'], isNotNull);
      });

      test('should deserialize from Firestore data', () {
        final now = DateTime.now();
        final data = {
          'groupId': 'group_456',
          'groupName': 'Bakningsgruppen',
          'groupEmoji': '🍞',
          'fromUserId': 'user_789',
          'fromUserName': 'Erik Eriksson',
          'toUserId': 'user_abc',
          'status': 'accepted',
          'sentAt': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
          'respondedAt': Timestamp.fromDate(now),
          'personalMessage': 'Vill du baka?',
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 5))),
        };

        final invitation = GroupInvitation.fromMap('inv_123', data);

        expect(invitation.id, equals('inv_123'));
        expect(invitation.groupId, equals('group_456'));
        expect(invitation.groupName, equals('Bakningsgruppen'));
        expect(invitation.groupEmoji, equals('🍞'));
        expect(invitation.fromUserId, equals('user_789'));
        expect(invitation.fromUserName, equals('Erik Eriksson'));
        expect(invitation.toUserId, equals('user_abc'));
        expect(invitation.status, equals(GroupInvitationStatus.accepted));
        expect(invitation.personalMessage, equals('Vill du baka?'));
        expect(invitation.respondedAt, isNotNull);
      });

      test('should handle missing optional fields', () {
        final data = {
          'groupId': 'group_456',
          'groupName': 'Test Group',
          'fromUserId': 'user_789',
          'fromUserName': 'Test User',
          'toUserId': 'user_abc',
        };

        final invitation = GroupInvitation.fromMap('inv_123', data);

        expect(invitation.groupEmoji, equals('👥')); // Default emoji
        expect(invitation.status, equals(GroupInvitationStatus.pending)); // Default status
        expect(invitation.personalMessage, isNull);
        expect(invitation.respondedAt, isNull);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON', () {
        final now = DateTime.now();
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Matlagningsgruppen',
          groupEmoji: '👨‍🍳',
          fromUserId: 'user_789',
          fromUserName: 'Anna Andersson',
          toUserId: 'user_abc',
          sentAt: now,
        );

        final json = invitation.toJson();

        expect(json['id'], equals('inv_123'));
        expect(json['groupId'], equals('group_456'));
        expect(json['groupName'], equals('Matlagningsgruppen'));
        expect(json['groupEmoji'], equals('👨‍🍳'));
        expect(json['status'], equals('pending'));
      });

      test('should deserialize from JSON', () {
        final now = DateTime.now();
        final json = {
          'id': 'inv_123',
          'groupId': 'group_456',
          'groupName': 'Bakningsgruppen',
          'groupEmoji': '🍞',
          'fromUserId': 'user_789',
          'fromUserName': 'Erik Eriksson',
          'toUserId': 'user_abc',
          'status': 'accepted',
          'sentAt': now.toIso8601String(),
          'respondedAt': now.toIso8601String(),
          'personalMessage': 'Test',
          'expiresAt': now.add(const Duration(days: 5)).toIso8601String(),
        };

        final invitation = GroupInvitation.fromJson(json);

        expect(invitation.id, equals('inv_123'));
        expect(invitation.groupName, equals('Bakningsgruppen'));
        expect(invitation.status, equals(GroupInvitationStatus.accepted));
        expect(invitation.personalMessage, equals('Test'));
      });

      test('should round-trip JSON serialization', () {
        final original = GroupInvitation.create(
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '🎯',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          personalMessage: 'Test message with åäö',
        );

        final json = original.toJson();
        final restored = GroupInvitation.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.groupName, equals(original.groupName));
        expect(restored.groupEmoji, equals(original.groupEmoji));
        expect(restored.personalMessage, equals(original.personalMessage));
        expect(restored.status, equals(original.status));
      });
    });

    group('copyWith', () {
      test('should copy with new status', () {
        final original = GroupInvitation.create(
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
        );

        final copied = original.copyWith(status: GroupInvitationStatus.accepted);

        expect(copied.status, equals(GroupInvitationStatus.accepted));
        expect(copied.id, equals(original.id));
        expect(copied.groupName, equals(original.groupName));
      });

      test('should copy with responded at', () {
        final original = GroupInvitation.create(
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
        );

        final respondedAt = DateTime.now();
        final copied = original.copyWith(respondedAt: respondedAt);

        expect(copied.respondedAt, equals(respondedAt));
        expect(copied.id, equals(original.id));
      });

      test('should preserve original values when not specified', () {
        final original = GroupInvitation.create(
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          personalMessage: 'Original message',
        );

        final copied = original.copyWith();

        expect(copied.id, equals(original.id));
        expect(copied.groupName, equals(original.groupName));
        expect(copied.personalMessage, equals(original.personalMessage));
        expect(copied.status, equals(original.status));
      });
    });

    group('Object Methods', () {
      test('should provide meaningful toString', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Matlagningsgruppen',
          groupEmoji: '👨‍🍳',
          fromUserId: 'user_789',
          fromUserName: 'Anna Andersson',
          toUserId: 'user_abc',
        );

        final str = invitation.toString();
        expect(str, contains('inv_123'));
        expect(str, contains('Matlagningsgruppen'));
        expect(str, contains('Anna Andersson'));
        expect(str, contains('user_abc'));
        expect(str, contains('pending'));
      });

      test('should implement equality based on ID', () {
        final invitation1 = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Group 1',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'User 1',
          toUserId: 'user_abc',
        );

        final invitation2 = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_999',
          groupName: 'Group 2',
          groupEmoji: '🎯',
          fromUserId: 'user_xxx',
          fromUserName: 'User 2',
          toUserId: 'user_yyy',
        );

        final invitation3 = GroupInvitation(
          id: 'inv_999',
          groupId: 'group_456',
          groupName: 'Group 1',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'User 1',
          toUserId: 'user_abc',
        );

        expect(invitation1, equals(invitation2)); // Same ID
        expect(invitation1, isNot(equals(invitation3))); // Different ID
      });

      test('should implement hashCode based on ID', () {
        final invitation1 = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'User',
          toUserId: 'user_abc',
        );

        final invitation2 = GroupInvitation(
          id: 'inv_123',
          groupId: 'different',
          groupName: 'Different',
          groupEmoji: '🎯',
          fromUserId: 'different',
          fromUserName: 'Different',
          toUserId: 'different',
        );

        expect(invitation1.hashCode, equals(invitation2.hashCode));
      });
    });

    group('Edge Cases', () {
      test('should handle empty personal message', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          personalMessage: '',
        );

        // Empty message should not be included in notification
        expect(invitation.notificationText, 
            equals('Test User bjöd in dig till gruppen 👥 Test Group'));
      });

      test('should handle very long group names', () {
        final longName = 'A' * 200;
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: longName,
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
        );

        expect(invitation.groupName, equals(longName));
        expect(invitation.shortNotificationText, contains(longName));
      });

      test('should handle Swedish characters in all text fields', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Räksmörgås-gruppen',
          groupEmoji: '🦐',
          fromUserId: 'user_789',
          fromUserName: 'Åsa Öberg',
          toUserId: 'user_abc',
          personalMessage: 'Hej! Vill du äta räksmörgås tillsammans?',
        );

        expect(invitation.groupName, equals('Räksmörgås-gruppen'));
        expect(invitation.fromUserName, equals('Åsa Öberg'));
        expect(invitation.personalMessage, contains('räksmörgås'));
      });

      test('should handle already expired invitation on creation', () {
        final invitation = GroupInvitation(
          id: 'inv_123',
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(invitation.isExpired, isTrue);
        expect(invitation.isPending, isFalse);
        expect(invitation.expiresInText, equals('Utgången'));
      });

      test('should handle concurrent status updates', () {
        final invitation = GroupInvitation.create(
          groupId: 'group_456',
          groupName: 'Test Group',
          groupEmoji: '👥',
          fromUserId: 'user_789',
          fromUserName: 'Test User',
          toUserId: 'user_abc',
        );

        final accepted = invitation.accept();
        final rejected = invitation.reject();
        final cancelled = invitation.cancel();

        // All should have different statuses but same base ID
        expect(accepted.status, equals(GroupInvitationStatus.accepted));
        expect(rejected.status, equals(GroupInvitationStatus.rejected));
        expect(cancelled.status, equals(GroupInvitationStatus.cancelled));
        expect(accepted.id, equals(invitation.id));
        expect(rejected.id, equals(invitation.id));
        expect(cancelled.id, equals(invitation.id));
      });

      test('should handle timestamp parsing variations', () {
        final now = DateTime.now();
        
        // Test with DateTime object
        final data1 = {
          'groupId': 'group_456',
          'groupName': 'Test',
          'fromUserId': 'user_789',
          'fromUserName': 'User',
          'toUserId': 'user_abc',
          'sentAt': now,
        };
        
        final invitation1 = GroupInvitation.fromMap('inv_123', data1);
        expect(invitation1.sentAt, equals(now));

        // Test with timestamp map (Firestore format)
        final data2 = {
          'groupId': 'group_456',
          'groupName': 'Test',
          'fromUserId': 'user_789',
          'fromUserName': 'User',
          'toUserId': 'user_abc',
          'sentAt': {
            'seconds': now.millisecondsSinceEpoch ~/ 1000,
            'nanoseconds': (now.millisecondsSinceEpoch % 1000) * 1000000,
          },
        };
        
        final invitation2 = GroupInvitation.fromMap('inv_123', data2);
        expect(invitation2.sentAt.millisecondsSinceEpoch ~/ 1000,
            equals(now.millisecondsSinceEpoch ~/ 1000));
      });
    });
  });
}