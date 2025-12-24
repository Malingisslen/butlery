// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'helpers/model_test_base.dart';

// Concrete test implementation of RealtimeResource for testing
class TestRealtimeResource extends RealtimeResource {
  final String testContent;

  TestRealtimeResource({
    required super.id,
    required super.type,
    required super.ownerId,
    required super.ownerDisplayName,
    required super.participants,
    super.participantIds,
    super.createdAt,
    super.lastEditedAt,
    required super.lastEditedBy,
    required super.lastEditedByDisplayName,
    super.editCount,
    super.isActive,
    super.metadata,
    this.testContent = 'test content',
  });

  @override
  RealtimeResource copyWithMetadata({
    Map<String, ResourcePermission>? participants,
    List<String>? participantIds,
    DateTime? lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    int? editCount,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return TestRealtimeResource(
      id: id,
      type: type,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants ?? this.participants,
      participantIds: participantIds ?? this.participantIds,
      createdAt: createdAt,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedByDisplayName:
          lastEditedByDisplayName ?? this.lastEditedByDisplayName,
      editCount: editCount ?? this.editCount,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      testContent: testContent,
    );
  }

  @override
  Map<String, dynamic> serializeContent() {
    return {
      'testContent': testContent,
    };
  }
}

void main() {
  ModelTestBase.testModelGroup('RealtimeResource', () {
    group('RealtimeResourceType', () {
      test('should create from string values', () {
        expect(RealtimeResourceType.fromString('recipe'),
            equals(RealtimeResourceType.recipe));
        expect(RealtimeResourceType.fromString('menu'),
            equals(RealtimeResourceType.menu));
        expect(RealtimeResourceType.fromString('shopping_list'),
            equals(RealtimeResourceType.shoppingList));
      });

      test('should throw on unknown type', () {
        expect(
          () => RealtimeResourceType.fromString('invalid'),
          throwsArgumentError,
        );
      });

      test('should provide Swedish display names', () {
        expect(RealtimeResourceType.recipe.displayName, equals('Recept'));
        expect(RealtimeResourceType.menu.displayName, equals('Meny'));
        expect(RealtimeResourceType.shoppingList.displayName,
            equals('Inköpslista'));
      });

      test('should provide emoji icons', () {
        expect(RealtimeResourceType.recipe.icon, equals('🍳'));
        expect(RealtimeResourceType.menu.icon, equals('📋'));
        expect(RealtimeResourceType.shoppingList.icon, equals('🛒'));
      });

      test('should convert to string value', () {
        expect(RealtimeResourceType.recipe.toString(), equals('recipe'));
        expect(RealtimeResourceType.menu.toString(), equals('menu'));
        expect(RealtimeResourceType.shoppingList.toString(),
            equals('shopping_list'));
      });
    });

    group('Construction', () {
      test('should create with required parameters', () {
        final participants = {
          'user_456': ResourcePermission.editor,
          'user_789': ResourcePermission.viewer,
        };

        final resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: participants,
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna Andersson',
        );

        expect(resource.id, equals('resource_123'));
        expect(resource.type, equals(RealtimeResourceType.recipe));
        expect(resource.ownerId, equals('user_123'));
        expect(resource.ownerDisplayName, equals('Anna Andersson'));
        expect(resource.participants, equals(participants));
        expect(resource.lastEditedBy, equals('user_123'));
        expect(resource.editCount, equals(0));
        expect(resource.isActive, isTrue);
        expect(resource.metadata, isEmpty);
      });

      test('should create with all parameters', () {
        final createdAt = DateTime(2025, 1, 1);
        final lastEditedAt = DateTime(2025, 1, 2);
        final metadata = {
          'version': '1.0',
          'tags': ['test']
        };

        final resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.menu,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: {},
          createdAt: createdAt,
          lastEditedAt: lastEditedAt,
          lastEditedBy: 'user_456',
          lastEditedByDisplayName: 'Erik Eriksson',
          editCount: 5,
          isActive: false,
          metadata: metadata,
        );

        expect(resource.createdAt, equals(createdAt));
        expect(resource.lastEditedAt, equals(lastEditedAt));
        expect(resource.editCount, equals(5));
        expect(resource.isActive, isFalse);
        expect(resource.metadata, equals(metadata));
      });

      test('should use current time for timestamps if not provided', () {
        final before = DateTime.now();

        final resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
        );

        final after = DateTime.now();

        expect(
            resource.createdAt.isAfter(before) ||
                resource.createdAt.isAtSameMomentAs(before),
            isTrue);
        expect(
            resource.createdAt.isBefore(after) ||
                resource.createdAt.isAtSameMomentAs(after),
            isTrue);
        expect(
            resource.lastEditedAt.isAfter(before) ||
                resource.lastEditedAt.isAtSameMomentAs(before),
            isTrue);
        expect(
            resource.lastEditedAt.isBefore(after) ||
                resource.lastEditedAt.isAtSameMomentAs(after),
            isTrue);
      });
    });

    group('Permission Checking', () {
      late TestRealtimeResource resource;

      setUp(() {
        resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_owner',
          ownerDisplayName: 'Owner',
          participants: {
            'user_owner': ResourcePermission.owner,
            'user_admin': ResourcePermission.admin,
            'user_editor': ResourcePermission.editor,
            'user_viewer': ResourcePermission.viewer,
          },
          lastEditedBy: 'user_owner',
          lastEditedByDisplayName: 'Owner',
        );
      });

      test('should check if user is owner', () {
        expect(resource.isOwner('user_owner'), isTrue);
        expect(resource.isOwner('user_editor'), isFalse);
        expect(resource.isOwner('user_unknown'), isFalse);
      });

      test('should check if user is participant', () {
        expect(resource.isParticipant('user_owner'), isTrue);
        expect(resource.isParticipant('user_editor'), isTrue);
        expect(resource.isParticipant('user_viewer'), isTrue);
        expect(resource.isParticipant('user_unknown'), isFalse);
      });

      test('should check if user can edit', () {
        expect(resource.canUserEdit('user_owner'), isTrue);
        expect(resource.canUserEdit('user_admin'), isTrue);
        expect(resource.canUserEdit('user_editor'), isTrue);
        expect(resource.canUserEdit('user_viewer'), isFalse);
        expect(resource.canUserEdit('user_unknown'), isFalse);
      });

      test('should check if user can delete', () {
        expect(resource.canUserDelete('user_owner'), isTrue);
        expect(resource.canUserDelete('user_admin'), isFalse);
        expect(resource.canUserDelete('user_editor'), isFalse);
        expect(resource.canUserDelete('user_viewer'), isFalse);
      });

      test('should check if user can manage permissions', () {
        expect(resource.canUserManagePermissions('user_owner'), isTrue);
        expect(resource.canUserManagePermissions('user_admin'), isFalse);
        expect(resource.canUserManagePermissions('user_editor'), isFalse);
        expect(resource.canUserManagePermissions('user_viewer'), isFalse);
      });

      test('should check if user can invite others', () {
        expect(resource.canUserInvite('user_owner'), isTrue);
        expect(resource.canUserInvite('user_admin'), isTrue);
        expect(resource.canUserInvite('user_editor'), isFalse);
        expect(resource.canUserInvite('user_viewer'), isFalse);
      });

      test('should check if user can leave', () {
        expect(
            resource.canUserLeave('user_owner'), isFalse); // Owner cannot leave
        expect(resource.canUserLeave('user_admin'), isTrue);
        expect(resource.canUserLeave('user_editor'), isTrue);
        expect(resource.canUserLeave('user_viewer'), isTrue);
        expect(resource.canUserLeave('user_unknown'),
            isFalse); // Not a participant
      });

      test('should handle owner not in participants map', () {
        // Some resources don't include owner in participants
        final resourceWithoutOwnerInMap = TestRealtimeResource(
          id: 'resource_456',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_owner',
          ownerDisplayName: 'Owner',
          participants: {
            'user_editor': ResourcePermission.editor,
          },
          lastEditedBy: 'user_owner',
          lastEditedByDisplayName: 'Owner',
        );

        // Owner should still have permissions even if not in participants
        expect(resourceWithoutOwnerInMap.isOwner('user_owner'), isTrue);
        expect(resourceWithoutOwnerInMap.canUserEdit('user_owner'), isTrue);
        expect(resourceWithoutOwnerInMap.canUserDelete('user_owner'), isTrue);
        expect(resourceWithoutOwnerInMap.canUserManagePermissions('user_owner'),
            isTrue);
        expect(resourceWithoutOwnerInMap.canUserInvite('user_owner'), isTrue);
      });

      test('should validate hasPermission method', () {
        // Owner has all permissions
        expect(resource.hasPermission('user_owner', ResourcePermission.viewer),
            isTrue);
        expect(resource.hasPermission('user_owner', ResourcePermission.editor),
            isTrue);
        expect(resource.hasPermission('user_owner', ResourcePermission.admin),
            isTrue);
        expect(resource.hasPermission('user_owner', ResourcePermission.owner),
            isTrue);

        // Editor has editor and viewer permissions
        expect(resource.hasPermission('user_editor', ResourcePermission.viewer),
            isTrue);
        expect(resource.hasPermission('user_editor', ResourcePermission.editor),
            isTrue);
        expect(resource.hasPermission('user_editor', ResourcePermission.admin),
            isFalse);
        expect(resource.hasPermission('user_editor', ResourcePermission.owner),
            isFalse);

        // Viewer only has viewer permission
        expect(resource.hasPermission('user_viewer', ResourcePermission.viewer),
            isTrue);
        expect(resource.hasPermission('user_viewer', ResourcePermission.editor),
            isFalse);
        expect(resource.hasPermission('user_viewer', ResourcePermission.admin),
            isFalse);

        // Unknown user has no permissions
        expect(
            resource.hasPermission('user_unknown', ResourcePermission.viewer),
            isFalse);
      });
    });

    group('Statistics', () {
      late TestRealtimeResource resource;

      setUp(() {
        resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_owner',
          ownerDisplayName: 'Owner',
          participants: {
            'user_owner': ResourcePermission.owner,
            'user_admin': ResourcePermission.admin,
            'user_editor1': ResourcePermission.editor,
            'user_editor2': ResourcePermission.editor,
            'user_viewer1': ResourcePermission.viewer,
            'user_viewer2': ResourcePermission.viewer,
            'user_viewer3': ResourcePermission.viewer,
          },
          lastEditedBy: 'user_owner',
          lastEditedByDisplayName: 'Owner',
        );
      });

      test('should count participants', () {
        expect(resource.participantCount, equals(7));
        expect(resource.collaboratorCount, equals(6)); // Excludes owner
        expect(resource.hasCollaborators, isTrue);
      });

      test('should count by permission type', () {
        expect(resource.editorCount, equals(4)); // owner + admin + 2 editors
        expect(resource.viewerCount, equals(3));
      });

      test('should get user IDs by permission', () {
        expect(
            resource.editorIds,
            containsAll(
                ['user_owner', 'user_admin', 'user_editor1', 'user_editor2']));
        expect(resource.viewerIds,
            containsAll(['user_viewer1', 'user_viewer2', 'user_viewer3']));
      });

      test('should filter participants by permission', () {
        final owners = resource.owners;
        expect(owners.length, equals(1));
        expect(owners.containsKey('user_owner'), isTrue);

        final editors = resource.editors;
        expect(editors.length, equals(2));
        expect(editors.containsKey('user_editor1'), isTrue);
        expect(editors.containsKey('user_editor2'), isTrue);

        final viewers = resource.viewers;
        expect(viewers.length, equals(3));
      });

      test('should check if resource is empty', () {
        expect(resource.isEmpty, isTrue); // editCount = 0

        final editedResource = resource.copyWithMetadata(editCount: 5);
        expect(editedResource.isEmpty, isFalse);
      });
    });

    group('Time Helpers', () {
      test('should calculate time since last edit', () {
        final resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedAt: DateTime.now().subtract(Duration(hours: 2)),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
        );

        expect(resource.timeSinceLastEdit.inHours, equals(2));
      });

      test('should format last edited time ago', () {
        // Just now
        var resource = _createResourceWithLastEdit(DateTime.now());
        expect(resource.lastEditedTimeAgo, equals('Just nu'));

        // 30 minutes ago
        resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(minutes: 30)));
        expect(resource.lastEditedTimeAgo, equals('30 min sedan'));

        // 2 hours ago
        resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(hours: 2)));
        expect(resource.lastEditedTimeAgo, equals('2 tim sedan'));

        // 3 days ago
        resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(days: 3)));
        expect(resource.lastEditedTimeAgo, equals('3 dagar sedan'));

        // 2 weeks ago
        resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(days: 14)));
        expect(resource.lastEditedTimeAgo, equals('2 veckor sedan'));
      });

      test('should check recent activity', () {
        var resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(minutes: 30)));
        expect(resource.hasRecentActivity, isTrue);

        resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(hours: 2)));
        expect(resource.hasRecentActivity, isFalse);
      });

      test('should check weekly activity', () {
        var resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(days: 3)));
        expect(resource.hasWeeklyActivity, isTrue);

        resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(days: 8)));
        expect(resource.hasWeeklyActivity, isFalse);
      });

      test('should check if changed since timestamp', () {
        final resource = _createResourceWithLastEdit(DateTime(2025, 1, 2));

        expect(resource.hasChangedSince(DateTime(2025, 1, 1)), isTrue);
        expect(resource.hasChangedSince(DateTime(2025, 1, 3)), isFalse);
      });

      test('should get activity text', () {
        var resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(minutes: 30)));
        expect(resource.activityText, equals('Aktiv nu'));

        resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(days: 3)));
        expect(resource.activityText, equals('Aktiv denna veckan'));

        resource = _createResourceWithLastEdit(
            DateTime.now().subtract(Duration(days: 10)));
        expect(resource.activityText, equals('Inaktiv'));
      });

      test('should get changes summary', () {
        var resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: {},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna Andersson',
          editCount: 0,
        );
        expect(
            resource.getChangesSummary(), equals('Skapades av Anna Andersson'));

        resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: {},
          lastEditedAt: DateTime.now().subtract(Duration(hours: 2)),
          lastEditedBy: 'user_456',
          lastEditedByDisplayName: 'Erik Eriksson',
          editCount: 5,
        );
        expect(resource.getChangesSummary(),
            contains('Senast redigerad av Erik Eriksson'));
        expect(resource.getChangesSummary(), contains('tim sedan'));
      });
    });

    group('Permission Text', () {
      test('should get Swedish permission text', () {
        final resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_owner',
          ownerDisplayName: 'Owner',
          participants: {
            'user_owner': ResourcePermission.owner,
            'user_admin': ResourcePermission.admin,
            'user_editor': ResourcePermission.editor,
            'user_writer': ResourcePermission.write,
            'user_viewer': ResourcePermission.viewer,
            'user_reader': ResourcePermission.read,
          },
          lastEditedBy: 'user_owner',
          lastEditedByDisplayName: 'Owner',
        );

        expect(resource.getUserPermissionText('user_owner'), equals('Ägare'));
        expect(resource.getUserPermissionText('user_admin'),
            equals('Administratör'));
        expect(resource.getUserPermissionText('user_editor'),
            equals('Redigerare'));
        expect(
            resource.getUserPermissionText('user_writer'), equals('Skrivare'));
        expect(resource.getUserPermissionText('user_viewer'),
            equals('Betraktare'));
        expect(resource.getUserPermissionText('user_reader'), equals('Läsare'));
        expect(resource.getUserPermissionText('user_unknown'), isNull);
      });
    });

    group('Participant Management', () {
      late TestRealtimeResource resource;

      setUp(() {
        resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_owner',
          ownerDisplayName: 'Owner',
          participants: {
            'user_owner': ResourcePermission.owner,
            'user_editor': ResourcePermission.editor,
          },
          lastEditedBy: 'user_owner',
          lastEditedByDisplayName: 'Owner',
          editCount: 5,
        );
      });

      test('should add participant', () {
        final updated = resource.addParticipant(
          'user_viewer',
          'New Viewer',
          ResourcePermission.viewer,
        ) as TestRealtimeResource;

        expect(updated.participants['user_viewer'],
            equals(ResourcePermission.viewer));
        expect(updated.participantCount, equals(3));
        expect(updated.editCount, equals(6));
        expect(updated.lastEditedBy, equals('user_owner'));
      });

      test('should remove participant', () {
        final updated =
            resource.removeParticipant('user_editor') as TestRealtimeResource;

        expect(updated.participants.containsKey('user_editor'), isFalse);
        expect(updated.participantCount, equals(1));
        expect(updated.editCount, equals(6));
      });

      test('should throw when removing owner', () {
        expect(
          () => resource.removeParticipant('user_owner'),
          throwsArgumentError,
        );
      });

      test('should update participant permission', () {
        final updated = resource.updateParticipantPermission(
          'user_editor',
          ResourcePermission.admin,
        ) as TestRealtimeResource;

        expect(updated.participants['user_editor'],
            equals(ResourcePermission.admin));
        expect(updated.editCount, equals(6));
      });

      test('should throw when changing owner permission to non-owner', () {
        expect(
          () => resource.updateParticipantPermission(
              'user_owner', ResourcePermission.editor),
          throwsArgumentError,
        );
      });
    });

    group('Metadata Operations', () {
      late TestRealtimeResource resource;

      setUp(() {
        resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
          editCount: 5,
          isActive: true,
        );
      });

      test('should mark as edited by user', () {
        final updated = resource.markEditedBy('user_456', 'Erik Eriksson')
            as TestRealtimeResource;

        expect(updated.lastEditedBy, equals('user_456'));
        expect(updated.lastEditedByDisplayName, equals('Erik Eriksson'));
        expect(updated.editCount, equals(6));
      });

      test('should archive resource', () {
        final archived = resource.archive() as TestRealtimeResource;

        expect(archived.isActive, isFalse);
        expect(archived.editCount, equals(6));
      });

      test('should reactivate resource', () {
        final archived = resource.archive() as TestRealtimeResource;
        final reactivated = archived.reactivate() as TestRealtimeResource;

        expect(reactivated.isActive, isTrue);
        expect(reactivated.editCount, equals(7));
      });
    });

    group('Serialization', () {
      late TestRealtimeResource resource;

      setUp(() {
        resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: {
            'user_456': ResourcePermission.editor,
            'user_789': ResourcePermission.viewer,
          },
          createdAt: DateTime(2025, 1, 1),
          lastEditedAt: DateTime(2025, 1, 2),
          lastEditedBy: 'user_456',
          lastEditedByDisplayName: 'Erik Eriksson',
          editCount: 3,
          isActive: true,
          metadata: {'version': '1.0'},
          testContent: 'Test data',
        );
      });

      test('should serialize to Firestore metadata', () {
        final metadata = resource.toFirestoreMetadata();

        expect(metadata['type'], equals('recipe'));
        expect(metadata['ownerId'], equals('user_123'));
        expect(metadata['ownerDisplayName'], equals('Anna Andersson'));
        expect(metadata['participants']['user_456'], equals('editor'));
        expect(metadata['participants']['user_789'], equals('viewer'));
        expect(metadata['createdAt'], isA<Timestamp>());
        expect(metadata['lastEditedAt'], isA<Timestamp>());
        expect(metadata['lastEditedBy'], equals('user_456'));
        expect(metadata['lastEditedByDisplayName'], equals('Erik Eriksson'));
        expect(metadata['editCount'], equals(3));
        expect(metadata['isActive'], isTrue);
        expect(metadata['metadata'], equals({'version': '1.0'}));
      });

      test('should serialize complete to Firestore', () {
        final firestore = resource.toFirestore();

        // Should include all metadata
        expect(firestore['type'], equals('recipe'));
        expect(firestore['ownerId'], equals('user_123'));

        // Should include content
        expect(firestore['testContent'], equals('Test data'));
      });

      test('should serialize to JSON metadata', () {
        final json = resource.toJsonMetadata();

        expect(json['id'], equals('resource_123'));
        expect(json['type'], equals('recipe'));
        expect(json['ownerId'], equals('user_123'));
        expect(json['participants']['user_456'], equals('editor'));
        expect(json['createdAt'], equals('2025-01-01T00:00:00.000'));
        expect(json['lastEditedAt'], equals('2025-01-02T00:00:00.000'));
        expect(json['editCount'], equals(3));
      });

      test('should parse Firestore metadata', () {
        final firestoreData = {
          'type': 'menu',
          'ownerId': 'user_123',
          'ownerDisplayName': 'Anna',
          'participants': {
            'user_456': 'editor',
            'user_789': 'viewer',
          },
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'lastEditedAt': Timestamp.fromDate(DateTime(2025, 1, 2)),
          'lastEditedBy': 'user_456',
          'lastEditedByDisplayName': 'Erik',
          'editCount': 5,
          'isActive': false,
          'metadata': {'test': true},
        };

        final parsed =
            RealtimeResource.parseFirestoreMetadata(firestoreData, 'doc_123');

        expect(parsed['id'], equals('doc_123'));
        expect(parsed['type'], equals(RealtimeResourceType.menu));
        expect(parsed['ownerId'], equals('user_123'));
        expect(parsed['ownerDisplayName'], equals('Anna'));
        expect(parsed['participants']['user_456'],
            equals(ResourcePermission.editor));
        expect(parsed['participants']['user_789'],
            equals(ResourcePermission.viewer));
        expect(parsed['createdAt'], equals(DateTime(2025, 1, 1)));
        expect(parsed['lastEditedAt'], equals(DateTime(2025, 1, 2)));
        expect(parsed['editCount'], equals(5));
        expect(parsed['isActive'], isFalse);
        expect(parsed['metadata'], equals({'test': true}));
      });

      test('should handle missing fields when parsing', () {
        final parsed = RealtimeResource.parseFirestoreMetadata({}, 'doc_123');

        expect(parsed['id'], equals('doc_123'));
        expect(parsed['type'], equals(RealtimeResourceType.recipe)); // Default
        expect(parsed['ownerId'], equals(''));
        expect(parsed['participants'], isEmpty);
        expect(parsed['editCount'], equals(0));
        expect(parsed['isActive'], isTrue);
        expect(parsed['metadata'], isEmpty);
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when ID and type match', () {
        final resource1 = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
        );

        final resource2 = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'different_user',
          ownerDisplayName: 'Different',
          participants: {'user_999': ResourcePermission.admin},
          lastEditedBy: 'user_999',
          lastEditedByDisplayName: 'Other',
          editCount: 100,
        );

        expect(resource1, equals(resource2));
        expect(resource1.hashCode, equals(resource2.hashCode));
      });

      test('should not be equal when ID differs', () {
        final resource1 = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
        );

        final resource2 = TestRealtimeResource(
          id: 'resource_456',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
        );

        expect(resource1, isNot(equals(resource2)));
      });

      test('should not be equal when type differs', () {
        final resource1 = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
        );

        final resource2 = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.menu,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
        );

        expect(resource1, isNot(equals(resource2)));
      });
    });

    group('Edge Cases', () {
      test('should handle empty participants', () {
        final resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
        );

        expect(resource.participantCount, equals(0));
        expect(resource.hasCollaborators, isFalse);
        expect(resource.editorIds, isEmpty);
        expect(resource.viewerIds, isEmpty);
      });

      test('should handle very old last edit time', () {
        final resource = TestRealtimeResource(
          id: 'resource_123',
          type: RealtimeResourceType.recipe,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          lastEditedAt: DateTime.now().subtract(Duration(days: 365)),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
        );

        expect(resource.lastEditedTimeAgo, contains('veckor sedan'));
        expect(resource.hasRecentActivity, isFalse);
        expect(resource.hasWeeklyActivity, isFalse);
        expect(resource.activityText, equals('Inaktiv'));
      });

      test('should handle invalid permission in parseFirestoreMetadata', () {
        final firestoreData = {
          'participants': {
            'user_123': 'editor',
            'user_456': 'invalid_permission',
            'user_789': 'viewer',
          },
        };

        final parsed =
            RealtimeResource.parseFirestoreMetadata(firestoreData, 'doc_123');
        final participants =
            parsed['participants'] as Map<String, ResourcePermission>;

        expect(participants['user_123'], equals(ResourcePermission.editor));
        // Invalid permission defaults to viewer
        expect(participants['user_456'], equals(ResourcePermission.viewer));
        expect(participants['user_789'], equals(ResourcePermission.viewer));
      });
    });
  });
}

// Helper function to create resource with specific last edit time
TestRealtimeResource _createResourceWithLastEdit(DateTime lastEditedAt) {
  return TestRealtimeResource(
    id: 'resource_123',
    type: RealtimeResourceType.recipe,
    ownerId: 'user_123',
    ownerDisplayName: 'Anna',
    participants: {},
    lastEditedAt: lastEditedAt,
    lastEditedBy: 'user_123',
    lastEditedByDisplayName: 'Anna',
  );
}
