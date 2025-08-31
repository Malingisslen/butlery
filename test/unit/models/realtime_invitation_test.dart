// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/invitations/realtime_invitation.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'helpers/model_test_base.dart';

// Helper to create test InvitationTarget
InvitationTarget _createTestTarget({
  InvitationTargetType type = InvitationTargetType.individual,
  String? targetId,
  String? displayName,
}) {
  return InvitationTarget(
    type: type,
    targetId: targetId ?? 'target_123',
    displayName: displayName ?? 'Test User',
    imageOrEmoji: type == InvitationTargetType.group ? '👥' : null,
    memberCount: type == InvitationTargetType.group ? 5 : null,
    memberIds: type == InvitationTargetType.group 
        ? ['user1', 'user2', 'user3', 'user4', 'user5'] 
        : null,
  );
}

void main() {
  ModelTestBase.testModelGroup('RealtimeInvitation', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final target = _createTestTarget();
        final invitation = RealtimeInvitation(
          id: 'inv_123',
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Köttbullar',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Anna Andersson',
          target: target,
        );

        expect(invitation.id, equals('inv_123'));
        expect(invitation.resourceType, equals(RealtimeResourceType.recipe));
        expect(invitation.resourceId, equals('recipe_456'));
        expect(invitation.resourceTitle, equals('Köttbullar'));
        expect(invitation.fromUserId, equals('user_789'));
        expect(invitation.fromUserDisplayName, equals('Anna Andersson'));
        expect(invitation.target, equals(target));
        expect(invitation.status, equals(RealtimeInvitationStatus.pending));
        expect(invitation.permissionLevel, equals('editor')); // Default
        expect(invitation.metadata, isEmpty);
      });

      test('should create with all parameters', () {
        final target = _createTestTarget();
        final sentAt = DateTime.now().subtract(const Duration(hours: 2));
        final respondedAt = DateTime.now();
        final expiresAt = DateTime.now().add(const Duration(days: 3));
        final metadata = {'extra': 'data'};

        final invitation = RealtimeInvitation(
          id: 'inv_123',
          resourceType: RealtimeResourceType.menu,
          resourceId: 'menu_456',
          resourceTitle: 'Veckans meny',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Erik Eriksson',
          target: target,
          status: RealtimeInvitationStatus.accepted,
          sentAt: sentAt,
          respondedAt: respondedAt,
          expiresAt: expiresAt,
          message: 'Vill du planera menyn?',
          permissionLevel: 'viewer',
          metadata: metadata,
        );

        expect(invitation.status, equals(RealtimeInvitationStatus.accepted));
        expect(invitation.sentAt, equals(sentAt));
        expect(invitation.respondedAt, equals(respondedAt));
        expect(invitation.expiresAt, equals(expiresAt));
        expect(invitation.message, equals('Vill du planera menyn?'));
        expect(invitation.permissionLevel, equals('viewer'));
        expect(invitation.metadata, equals(metadata));
      });

      test('should auto-generate ID when not provided', () {
        final target = _createTestTarget();
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test Recipe',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test User',
          target: target,
        );

        expect(invitation.id, isNotEmpty);
        expect(invitation.id.length, equals(36)); // UUID v4 format
      });

      test('should set default expiration to 7 days', () {
        final now = DateTime.now();
        final target = _createTestTarget();
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test Recipe',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test User',
          target: target,
        );

        final difference = invitation.expiresAt.difference(now);
        expect(difference.inDays, greaterThanOrEqualTo(6));
        expect(difference.inDays, lessThanOrEqualTo(7));
      });
    });

    group('Factory Methods', () {
      test('should create with factory create method', () {
        final target = _createTestTarget();
        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.shoppingList,
          resourceId: 'list_456',
          resourceTitle: 'Veckohandling',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Anna Andersson',
          target: target,
        );

        expect(invitation.id, isNotEmpty);
        expect(invitation.resourceType, equals(RealtimeResourceType.shoppingList));
        expect(invitation.status, equals(RealtimeInvitationStatus.pending));
        expect(invitation.permissionLevel, equals('editor'));
      });

      test('should create with custom expiration duration', () {
        final target = _createTestTarget();
        final now = DateTime.now();
        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test Recipe',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test User',
          target: target,
          expiresIn: const Duration(days: 3),
        );

        final difference = invitation.expiresAt.difference(now);
        expect(difference.inDays, greaterThanOrEqualTo(2));
        expect(difference.inDays, lessThanOrEqualTo(3));
      });

      test('should create with personal message', () {
        final target = _createTestTarget();
        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.menu,
          resourceId: 'menu_456',
          resourceTitle: 'Veckans meny',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Erik Eriksson',
          target: target,
          message: 'Hej! Ska vi planera veckan tillsammans?',
          permissionLevel: 'viewer',
        );

        expect(invitation.message, equals('Hej! Ska vi planera veckan tillsammans?'));
        expect(invitation.permissionLevel, equals('viewer'));
      });
    });

    group('Status Management', () {
      late RealtimeInvitation baseInvitation;

      setUp(() {
        baseInvitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test Recipe',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test User',
          target: _createTestTarget(),
        );
      });

      test('should accept invitation', () {
        final accepted = baseInvitation.accept();

        expect(accepted.status, equals(RealtimeInvitationStatus.accepted));
        expect(accepted.respondedAt, isNotNull);
        expect(accepted.id, equals(baseInvitation.id));
      });

      test('should reject invitation', () {
        final rejected = baseInvitation.reject();

        expect(rejected.status, equals(RealtimeInvitationStatus.rejected));
        expect(rejected.respondedAt, isNotNull);
        expect(rejected.id, equals(baseInvitation.id));
      });

      test('should cancel invitation', () {
        final cancelled = baseInvitation.cancel();

        expect(cancelled.status, equals(RealtimeInvitationStatus.cancelled));
        expect(cancelled.respondedAt, isNotNull);
        expect(cancelled.id, equals(baseInvitation.id));
      });

      test('should expire invitation', () {
        final expired = baseInvitation.expire();

        expect(expired.status, equals(RealtimeInvitationStatus.expired));
        expect(expired.respondedAt, isNotNull);
        expect(expired.id, equals(baseInvitation.id));
      });

      test('should check pending status correctly', () {
        expect(baseInvitation.isPending, isTrue);
        expect(baseInvitation.canRespond, isTrue);

        final accepted = baseInvitation.accept();
        expect(accepted.isPending, isFalse);
        expect(accepted.canRespond, isFalse);
      });

      test('should check expiration correctly', () {
        final expired = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test Recipe',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test User',
          target: _createTestTarget(),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(expired.isExpired, isTrue);
        expect(expired.isPending, isFalse);
        expect(expired.canRespond, isFalse);
      });

      test('should detect expiration from status', () {
        final expired = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test Recipe',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test User',
          target: _createTestTarget(),
          status: RealtimeInvitationStatus.expired,
          expiresAt: DateTime.now().add(const Duration(days: 3)), // Still has time
        );

        expect(expired.isExpired, isTrue);
      });

      test('should check all status getters', () {
        expect(baseInvitation.isAccepted, isFalse);
        expect(baseInvitation.isRejected, isFalse);
        expect(baseInvitation.isCancelled, isFalse);
        expect(baseInvitation.isResponded, isFalse);

        final accepted = baseInvitation.accept();
        expect(accepted.isAccepted, isTrue);
        expect(accepted.isResponded, isTrue);

        final rejected = baseInvitation.reject();
        expect(rejected.isRejected, isTrue);
        expect(rejected.isResponded, isTrue);

        final cancelled = baseInvitation.cancel();
        expect(cancelled.isCancelled, isTrue);
        expect(cancelled.isResponded, isTrue);
      });
    });

    group('Resource Types', () {
      test('should handle recipe resource type', () {
        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Köttbullar',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Anna',
          target: _createTestTarget(),
        );

        expect(invitation.resourceIcon, equals('🍳'));
        expect(invitation.notificationTitle, equals('Inbjudan till recept'));
        expect(invitation.shortDescription, equals('Recept: Köttbullar'));
      });

      test('should handle menu resource type', () {
        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.menu,
          resourceId: 'menu_456',
          resourceTitle: 'Veckans meny',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Erik',
          target: _createTestTarget(),
        );

        expect(invitation.resourceIcon, equals('📋'));
        expect(invitation.notificationTitle, equals('Inbjudan till meny'));
        expect(invitation.shortDescription, equals('Meny: Veckans meny'));
      });

      test('should handle shopping list resource type', () {
        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.shoppingList,
          resourceId: 'list_456',
          resourceTitle: 'Veckohandling',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Maria',
          target: _createTestTarget(),
        );

        expect(invitation.resourceIcon, equals('🛒'));
        expect(invitation.notificationTitle, equals('Inbjudan till inköpslista'));
        expect(invitation.shortDescription, equals('Inköpslista: Veckohandling'));
      });
    });

    group('Swedish Localization - Time', () {
      test('should show "Nu" for recent invitation', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          sentAt: DateTime.now(),
        );

        expect(invitation.timeAgoText, equals('Nu'));
      });

      test('should show minutes for recent time', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          sentAt: DateTime.now().subtract(const Duration(minutes: 45)),
        );

        expect(invitation.timeAgoText, equals('45 min sedan'));
      });

      test('should show hours for same day', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          sentAt: DateTime.now().subtract(const Duration(hours: 3)),
        );

        expect(invitation.timeAgoText, equals('3 tim sedan'));
      });

      test('should show days for recent days', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          sentAt: DateTime.now().subtract(const Duration(days: 5)),
        );

        expect(invitation.timeAgoText, equals('5 dagar sedan'));
      });

      test('should show weeks for old invitations', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          sentAt: DateTime.now().subtract(const Duration(days: 21)),
        );

        expect(invitation.timeAgoText, equals('3 veckor sedan'));
      });
    });

    group('Swedish Localization - Expiration', () {
      test('should show "Utgången" for expired', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(invitation.expiresInText, equals('Utgången'));
      });

      test('should show days remaining', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          expiresAt: DateTime.now().add(const Duration(days: 4)),
        );

        expect(invitation.expiresInText, equals('4 dagar kvar'));
      });

      test('should show hours remaining', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          expiresAt: DateTime.now().add(const Duration(hours: 8)),
        );

        expect(invitation.expiresInText, equals('8 timmar kvar'));
      });

      test('should show "Går ut snart" for imminent expiry', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          expiresAt: DateTime.now().add(const Duration(seconds: 45)),
        );

        expect(invitation.expiresInText, equals('Går ut snart'));
      });

      test('should detect expiresSoon correctly', () {
        final soonExpiring = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          expiresAt: DateTime.now().add(const Duration(hours: 12)),
        );

        final notSoonExpiring = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          expiresAt: DateTime.now().add(const Duration(days: 3)),
        );

        expect(soonExpiring.expiresSoon, isTrue);
        expect(notSoonExpiring.expiresSoon, isFalse);
      });
    });

    group('Notification Text', () {
      test('should generate notification for individual target', () {
        final target = _createTestTarget(
          type: InvitationTargetType.individual,
          displayName: 'Erik Eriksson',
        );

        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Köttbullar',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Anna Andersson',
          target: target,
        );

        expect(invitation.notificationDescription,
            equals('Anna Andersson bjöd in dig till gemensam recept: "Köttbullar"'));
      });

      test('should generate notification for group target', () {
        final target = _createTestTarget(
          type: InvitationTargetType.group,
          displayName: 'Matlagningsgruppen',
        );

        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.menu,
          resourceId: 'menu_456',
          resourceTitle: 'Veckans meny',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Erik Eriksson',
          target: target,
        );

        expect(invitation.notificationDescription,
            equals('Erik Eriksson bjöd in gruppen "Matlagningsgruppen" till gemensam meny: "Veckans meny"'));
      });
    });

    group('Status Display', () {
      test('should show correct status icons', () {
        final pending = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'r1',
          resourceTitle: 'Test',
          fromUserId: 'u1',
          fromUserDisplayName: 'User',
          target: _createTestTarget(),
        );

        expect(pending.statusIcon, equals('⏳'));

        final expired = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'r1',
          resourceTitle: 'Test',
          fromUserId: 'u1',
          fromUserDisplayName: 'User',
          target: _createTestTarget(),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(expired.statusIcon, equals('⏰'));

        final accepted = pending.accept();
        expect(accepted.statusIcon, equals('✅'));

        final rejected = pending.reject();
        expect(rejected.statusIcon, equals('❌'));

        final cancelled = pending.cancel();
        expect(cancelled.statusIcon, equals('🚫'));
      });

      test('should show correct status text in Swedish', () {
        final pending = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'r1',
          resourceTitle: 'Test',
          fromUserId: 'u1',
          fromUserDisplayName: 'User',
          target: _createTestTarget(),
        );

        expect(pending.statusText, equals('Väntande'));

        final accepted = pending.accept();
        expect(accepted.statusText, equals('Accepterad'));

        final rejected = pending.reject();
        expect(rejected.statusText, equals('Avvisad'));

        final cancelled = pending.cancel();
        expect(cancelled.statusText, equals('Avbruten'));

        final expired = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'r1',
          resourceTitle: 'Test',
          fromUserId: 'u1',
          fromUserDisplayName: 'User',
          target: _createTestTarget(),
          status: RealtimeInvitationStatus.expired,
        );
        expect(expired.statusText, equals('Utgången'));
      });
    });

    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        final now = DateTime.now();
        final target = _createTestTarget();
        final invitation = RealtimeInvitation(
          id: 'inv_123',
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Köttbullar',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Anna Andersson',
          target: target,
          sentAt: now,
          message: 'Test message',
          permissionLevel: 'editor',
          metadata: {'key': 'value'},
        );

        final data = invitation.toFirestore();

        expect(data['resourceType'], equals('recipe'));
        expect(data['resourceId'], equals('recipe_456'));
        expect(data['resourceTitle'], equals('Köttbullar'));
        expect(data['fromUserId'], equals('user_789'));
        expect(data['fromUserDisplayName'], equals('Anna Andersson'));
        expect(data['status'], equals('pending'));
        expect(data['message'], equals('Test message'));
        expect(data['permissionLevel'], equals('editor'));
        expect(data['metadata'], equals({'key': 'value'}));
        expect(data['target'], isNotNull);
        expect(data['sentAt'], equals(now));
        expect(data['expiresAt'], isNotNull);
      });

      test('should deserialize from Firestore data', () {
        final now = DateTime.now();
        final data = {
          'resourceType': 'menu',
          'resourceId': 'menu_456',
          'resourceTitle': 'Veckans meny',
          'fromUserId': 'user_789',
          'fromUserDisplayName': 'Erik Eriksson',
          'target': {
            'type': 'individual',
            'targetId': 'target_123',
            'displayName': 'Test User',
          },
          'status': 'accepted',
          'sentAt': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
          'respondedAt': Timestamp.fromDate(now),
          'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 5))),
          'message': 'Test',
          'permissionLevel': 'viewer',
          'metadata': {'extra': 'data'},
        };

        final invitation = RealtimeInvitation.fromMap('inv_123', data);

        expect(invitation.id, equals('inv_123'));
        expect(invitation.resourceType, equals(RealtimeResourceType.menu));
        expect(invitation.resourceId, equals('menu_456'));
        expect(invitation.resourceTitle, equals('Veckans meny'));
        expect(invitation.status, equals(RealtimeInvitationStatus.accepted));
        expect(invitation.message, equals('Test'));
        expect(invitation.permissionLevel, equals('viewer'));
        expect(invitation.metadata['extra'], equals('data'));
      });

      test('should handle missing optional fields', () {
        final data = {
          'resourceType': 'recipe',
          'resourceId': 'recipe_456',
          'fromUserId': 'user_789',
          'target': {
            'type': 'individual',
            'targetId': 'target_123',
            'displayName': 'Test User',
          },
        };

        final invitation = RealtimeInvitation.fromMap('inv_123', data);

        expect(invitation.resourceTitle, equals('')); // Default empty
        expect(invitation.fromUserDisplayName, equals('')); // Default empty
        expect(invitation.status, equals(RealtimeInvitationStatus.pending));
        expect(invitation.message, isNull);
        expect(invitation.permissionLevel, equals('editor')); // Default
        expect(invitation.metadata, isEmpty);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON', () {
        final now = DateTime.now();
        final target = _createTestTarget();
        final invitation = RealtimeInvitation(
          id: 'inv_123',
          resourceType: RealtimeResourceType.shoppingList,
          resourceId: 'list_456',
          resourceTitle: 'Veckohandling',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Maria',
          target: target,
          sentAt: now,
        );

        final json = invitation.toJson();

        expect(json['id'], equals('inv_123'));
        expect(json['resourceType'], equals('shopping_list'));
        expect(json['resourceId'], equals('list_456'));
        expect(json['resourceTitle'], equals('Veckohandling'));
        expect(json['status'], equals('pending'));
        expect(json['sentAt'], equals(now.toIso8601String()));
      });

      test('should deserialize from JSON', () {
        final now = DateTime.now();
        final json = {
          'id': 'inv_123',
          'resourceType': 'recipe',
          'resourceId': 'recipe_456',
          'resourceTitle': 'Köttbullar',
          'fromUserId': 'user_789',
          'fromUserDisplayName': 'Anna',
          'target': {
            'type': 'group',
            'targetId': 'group_123',
            'displayName': 'Matgruppen',
          },
          'status': 'rejected',
          'sentAt': now.toIso8601String(),
          'respondedAt': now.toIso8601String(),
          'expiresAt': now.add(const Duration(days: 3)).toIso8601String(),
          'message': 'Test message',
          'permissionLevel': 'viewer',
          'metadata': {'test': 'data'},
        };

        final invitation = RealtimeInvitation.fromJson(json);

        expect(invitation.id, equals('inv_123'));
        expect(invitation.resourceType, equals(RealtimeResourceType.recipe));
        expect(invitation.status, equals(RealtimeInvitationStatus.rejected));
        expect(invitation.message, equals('Test message'));
        expect(invitation.permissionLevel, equals('viewer'));
        expect(invitation.metadata['test'], equals('data'));
      });

      test('should round-trip JSON serialization', () {
        final original = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.menu,
          resourceId: 'menu_456',
          resourceTitle: 'Test Menu åäö',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Åsa Öberg',
          target: _createTestTarget(),
          message: 'Hej! Vill du äta räksmörgås?',
        );

        final json = original.toJson();
        final restored = RealtimeInvitation.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.resourceType, equals(original.resourceType));
        expect(restored.resourceTitle, equals(original.resourceTitle));
        expect(restored.fromUserDisplayName, equals(original.fromUserDisplayName));
        expect(restored.message, equals(original.message));
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        final original = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Original Title',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test User',
          target: _createTestTarget(),
          message: 'Original message',
        );

        final copied = original.copyWith(
          resourceTitle: 'New Title',
          status: RealtimeInvitationStatus.accepted,
          message: 'New message',
        );

        expect(copied.resourceTitle, equals('New Title'));
        expect(copied.status, equals(RealtimeInvitationStatus.accepted));
        expect(copied.message, equals('New message'));
        expect(copied.id, equals(original.id)); // ID preserved
        expect(copied.resourceId, equals(original.resourceId)); // Unchanged preserved
      });

      test('should preserve original values when not specified', () {
        final original = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.menu,
          resourceId: 'menu_456',
          resourceTitle: 'Test Menu',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test User',
          target: _createTestTarget(),
          message: 'Test message',
          permissionLevel: 'viewer',
        );

        final copied = original.copyWith();

        expect(copied.id, equals(original.id));
        expect(copied.resourceTitle, equals(original.resourceTitle));
        expect(copied.message, equals(original.message));
        expect(copied.permissionLevel, equals(original.permissionLevel));
      });
    });

    group('Object Methods', () {
      test('should provide meaningful toString', () {
        final target = _createTestTarget(displayName: 'Erik Eriksson');
        final invitation = RealtimeInvitation(
          id: 'inv_123',
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Köttbullar',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Anna Andersson',
          target: target,
        );

        final str = invitation.toString();
        expect(str, contains('inv_123'));
        expect(str, contains('recipe'));
        expect(str, contains('recipe_456'));
        expect(str, contains('Anna Andersson'));
        expect(str, contains('Erik Eriksson'));
      });

      test('should implement equality based on ID', () {
        final target = _createTestTarget();
        final invitation1 = RealtimeInvitation(
          id: 'inv_123',
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Recipe 1',
          fromUserId: 'user_789',
          fromUserDisplayName: 'User 1',
          target: target,
        );

        final invitation2 = RealtimeInvitation(
          id: 'inv_123',
          resourceType: RealtimeResourceType.menu,
          resourceId: 'menu_999',
          resourceTitle: 'Menu 2',
          fromUserId: 'user_xxx',
          fromUserDisplayName: 'User 2',
          target: target,
        );

        final invitation3 = RealtimeInvitation(
          id: 'inv_999',
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Recipe 1',
          fromUserId: 'user_789',
          fromUserDisplayName: 'User 1',
          target: target,
        );

        expect(invitation1, equals(invitation2)); // Same ID
        expect(invitation1, isNot(equals(invitation3))); // Different ID
      });

      test('should implement hashCode based on ID', () {
        final target = _createTestTarget();
        final invitation1 = RealtimeInvitation(
          id: 'inv_123',
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'User',
          target: target,
        );

        final invitation2 = RealtimeInvitation(
          id: 'inv_123',
          resourceType: RealtimeResourceType.menu,
          resourceId: 'different',
          resourceTitle: 'Different',
          fromUserId: 'different',
          fromUserDisplayName: 'Different',
          target: _createTestTarget(displayName: 'Different User'),
        );

        expect(invitation1.hashCode, equals(invitation2.hashCode));
      });
    });

    group('Edge Cases', () {
      test('should handle different target types', () {
        final individualTarget = _createTestTarget(
          type: InvitationTargetType.individual,
          displayName: 'Anna Andersson',
        );

        final groupTarget = _createTestTarget(
          type: InvitationTargetType.group,
          displayName: 'Matlagningsgruppen',
        );

        final individualInvitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Erik',
          target: individualTarget,
        );

        final groupInvitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Erik',
          target: groupTarget,
        );

        expect(individualInvitation.notificationDescription, contains('bjöd in dig'));
        expect(groupInvitation.notificationDescription, contains('bjöd in gruppen'));
      });

      test('should handle empty metadata', () {
        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
        );

        expect(invitation.metadata, isEmpty);
        
        final withMetadata = invitation.copyWith(
          metadata: {'key': 'value'},
        );
        
        expect(withMetadata.metadata, equals({'key': 'value'}));
      });

      test('should handle Swedish characters in all fields', () {
        final target = _createTestTarget(displayName: 'Åsa Öberg');
        final invitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Räksmörgås',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Örjan Åkesson',
          target: target,
          message: 'Hej! Vill du äta räksmörgås tillsammans?',
        );

        expect(invitation.resourceTitle, equals('Räksmörgås'));
        expect(invitation.fromUserDisplayName, equals('Örjan Åkesson'));
        expect(invitation.message, contains('räksmörgås'));
        expect(invitation.target.displayName, equals('Åsa Öberg'));
      });

      test('should handle already expired invitation', () {
        final invitation = RealtimeInvitation(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(invitation.isExpired, isTrue);
        expect(invitation.isPending, isFalse);
        expect(invitation.canRespond, isFalse);
        expect(invitation.expiresInText, equals('Utgången'));
      });

      test('should handle permission levels', () {
        final editorInvitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          permissionLevel: 'editor',
        );

        final viewerInvitation = RealtimeInvitation.create(
          resourceType: RealtimeResourceType.recipe,
          resourceId: 'recipe_456',
          resourceTitle: 'Test',
          fromUserId: 'user_789',
          fromUserDisplayName: 'Test',
          target: _createTestTarget(),
          permissionLevel: 'viewer',
        );

        expect(editorInvitation.permissionLevel, equals('editor'));
        expect(viewerInvitation.permissionLevel, equals('viewer'));
      });

      test('should handle timestamp parsing variations', () {
        final now = DateTime.now();
        
        // Test with DateTime object
        final data1 = {
          'resourceType': 'recipe',
          'resourceId': 'recipe_456',
          'fromUserId': 'user_789',
          'target': {
            'type': 'individual',
            'targetId': 'target_123',
            'displayName': 'Test User',
          },
          'sentAt': now,
        };
        
        final invitation1 = RealtimeInvitation.fromMap('inv_123', data1);
        expect(invitation1.sentAt, equals(now));

        // Test with milliseconds
        final data2 = {
          'resourceType': 'recipe',
          'resourceId': 'recipe_456',
          'fromUserId': 'user_789',
          'target': {
            'type': 'individual',
            'targetId': 'target_123',
            'displayName': 'Test User',
          },
          'sentAt': now.millisecondsSinceEpoch,
        };
        
        final invitation2 = RealtimeInvitation.fromMap('inv_123', data2);
        expect(invitation2.sentAt.millisecondsSinceEpoch, 
            equals(now.millisecondsSinceEpoch));
      });
    });

    group('StringExtension', () {
      test('should capitalize first letter', () {
        expect('hello'.capitalizeFirst(), equals('Hello'));
        expect('HELLO'.capitalizeFirst(), equals('HELLO'));
        expect(''.capitalizeFirst(), equals(''));
        expect('h'.capitalizeFirst(), equals('H'));
        expect('åsa'.capitalizeFirst(), equals('Åsa'));
      });
    });
  });
}