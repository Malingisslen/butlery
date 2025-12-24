// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/realtime/realtime_participants.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RealtimeParticipants', () {
    group('Participant Management', () {
      test('should add participant with permission', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
          'user_editor': ResourcePermission.editor,
        };

        final updated = RealtimeParticipants.addParticipant(
          participants,
          'user_viewer',
          ResourcePermission.viewer,
        );

        expect(updated['user_viewer'], equals(ResourcePermission.viewer));
        expect(updated.length, equals(3));
        // Original map should not be modified
        expect(participants.length, equals(2));
      });

      test('should remove participant', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
          'user_editor': ResourcePermission.editor,
          'user_viewer': ResourcePermission.viewer,
        };

        final updated = RealtimeParticipants.removeParticipant(
          participants,
          'user_viewer',
        );

        expect(updated.containsKey('user_viewer'), isFalse);
        expect(updated.length, equals(2));
        // Original map unchanged
        expect(participants.length, equals(3));
      });

      test('should update participant permission', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
          'user_editor': ResourcePermission.editor,
        };

        final updated = RealtimeParticipants.updateParticipantPermission(
          participants,
          'user_editor',
          ResourcePermission.admin,
        );

        expect(updated['user_editor'], equals(ResourcePermission.admin));
        // Original unchanged
        expect(participants['user_editor'], equals(ResourcePermission.editor));
      });

      test('should throw when updating non-existent participant', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
        };

        expect(
          () => RealtimeParticipants.updateParticipantPermission(
            participants,
            'user_unknown',
            ResourcePermission.editor,
          ),
          throwsArgumentError,
        );
      });

      test('should bulk add participants', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
        };

        final newParticipants = {
          'user_editor1': ResourcePermission.editor,
          'user_editor2': ResourcePermission.editor,
          'user_viewer': ResourcePermission.viewer,
        };

        final updated = RealtimeParticipants.addParticipants(
          participants,
          newParticipants,
        );

        expect(updated.length, equals(4));
        expect(updated['user_editor1'], equals(ResourcePermission.editor));
        expect(updated['user_editor2'], equals(ResourcePermission.editor));
        expect(updated['user_viewer'], equals(ResourcePermission.viewer));
      });

      test('should bulk remove participants', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
          'user_editor1': ResourcePermission.editor,
          'user_editor2': ResourcePermission.editor,
          'user_viewer': ResourcePermission.viewer,
        };

        final updated = RealtimeParticipants.removeParticipants(
          participants,
          ['user_editor1', 'user_viewer'],
        );

        expect(updated.length, equals(2));
        expect(updated.containsKey('user_editor1'), isFalse);
        expect(updated.containsKey('user_viewer'), isFalse);
        expect(updated.containsKey('user_owner'), isTrue);
        expect(updated.containsKey('user_editor2'), isTrue);
      });
    });

    group('Permission Validation', () {
      late Map<String, ResourcePermission> participants;

      setUp(() {
        participants = {
          'user_owner': ResourcePermission.owner,
          'user_admin': ResourcePermission.admin,
          'user_editor': ResourcePermission.editor,
          'user_viewer': ResourcePermission.viewer,
        };
      });

      test('should check if user has permission', () {
        expect(
          RealtimeParticipants.hasPermission(
            participants,
            'user_owner',
            ResourcePermission.viewer,
          ),
          isTrue,
        );

        expect(
          RealtimeParticipants.hasPermission(
            participants,
            'user_editor',
            ResourcePermission.editor,
          ),
          isTrue,
        );

        expect(
          RealtimeParticipants.hasPermission(
            participants,
            'user_viewer',
            ResourcePermission.editor,
          ),
          isFalse,
        );

        expect(
          RealtimeParticipants.hasPermission(
            participants,
            'user_unknown',
            ResourcePermission.viewer,
          ),
          isFalse,
        );
      });

      test('should check if user can edit', () {
        expect(
            RealtimeParticipants.canEdit(participants, 'user_owner'), isTrue);
        expect(
            RealtimeParticipants.canEdit(participants, 'user_admin'), isTrue);
        expect(
            RealtimeParticipants.canEdit(participants, 'user_editor'), isTrue);
        expect(
            RealtimeParticipants.canEdit(participants, 'user_viewer'), isFalse);
        expect(RealtimeParticipants.canEdit(participants, 'user_unknown'),
            isFalse);
      });

      test('should check if user can view', () {
        expect(
            RealtimeParticipants.canView(participants, 'user_owner'), isTrue);
        expect(
            RealtimeParticipants.canView(participants, 'user_viewer'), isTrue);
        expect(RealtimeParticipants.canView(participants, 'user_unknown'),
            isFalse);
      });

      test('should check if user is owner', () {
        expect(
            RealtimeParticipants.isOwner(participants, 'user_owner'), isTrue);
        expect(
            RealtimeParticipants.isOwner(participants, 'user_admin'), isFalse);
        expect(RealtimeParticipants.isOwner(participants, 'user_unknown'),
            isFalse);
      });

      test('should check if user is admin', () {
        expect(
            RealtimeParticipants.isAdmin(participants, 'user_owner'), isTrue);
        expect(
            RealtimeParticipants.isAdmin(participants, 'user_admin'), isTrue);
        expect(
            RealtimeParticipants.isAdmin(participants, 'user_editor'), isFalse);
      });

      test('should validate permission change', () {
        // Owner can change any permission
        expect(
          RealtimeParticipants.canChangePermission(
            participants,
            'user_owner',
            'user_editor',
            ResourcePermission.admin,
          ),
          isTrue,
        );

        // Admin can change permissions below admin
        expect(
          RealtimeParticipants.canChangePermission(
            participants,
            'user_admin',
            'user_viewer',
            ResourcePermission.editor,
          ),
          isTrue,
        );

        // Admin cannot promote to admin or owner
        expect(
          RealtimeParticipants.canChangePermission(
            participants,
            'user_admin',
            'user_viewer',
            ResourcePermission.admin,
          ),
          isFalse,
        );

        // Only owner can change owner permissions
        expect(
          RealtimeParticipants.canChangePermission(
            participants,
            'user_admin',
            'user_owner',
            ResourcePermission.editor,
          ),
          isFalse,
        );

        // Editor cannot change permissions
        expect(
          RealtimeParticipants.canChangePermission(
            participants,
            'user_editor',
            'user_viewer',
            ResourcePermission.editor,
          ),
          isFalse,
        );
      });
    });

    group('Participant Analytics', () {
      test('should get participant statistics', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
          'user_admin': ResourcePermission.admin,
          'user_editor1': ResourcePermission.editor,
          'user_editor2': ResourcePermission.write, // Legacy permission
          'user_viewer1': ResourcePermission.viewer,
          'user_viewer2': ResourcePermission.read, // Legacy permission
        };

        final stats = RealtimeParticipants.getParticipantStats(participants);

        expect(stats['total'], equals(6));
        expect(stats['owners'], equals(1));
        expect(stats['admins'], equals(1));
        expect(stats['editors'], equals(2)); // Includes write permission
        expect(stats['viewers'], equals(2)); // Includes read permission
      });

      test('should get participants by permission', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
          'user_editor1': ResourcePermission.editor,
          'user_editor2': ResourcePermission.editor,
          'user_viewer': ResourcePermission.viewer,
        };

        final editors = RealtimeParticipants.getParticipantsByPermission(
          participants,
          ResourcePermission.editor,
        );

        expect(editors.length, equals(2));
        expect(editors, containsAll(['user_editor1', 'user_editor2']));
      });

      test('should get all editors including higher permissions', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
          'user_admin': ResourcePermission.admin,
          'user_editor': ResourcePermission.editor,
          'user_viewer': ResourcePermission.viewer,
        };

        final editors = RealtimeParticipants.getAllEditors(participants);

        expect(editors.length, equals(3));
        expect(
            editors, containsAll(['user_owner', 'user_admin', 'user_editor']));
        expect(editors, isNot(contains('user_viewer')));
      });

      test('should calculate collaboration level', () {
        // Single user = 0
        var participants = {'user_owner': ResourcePermission.owner};
        expect(RealtimeParticipants.getCollaborationLevel(participants),
            equals(0));

        // Two users, both editors = high collaboration
        participants = {
          'user_owner': ResourcePermission.owner,
          'user_editor': ResourcePermission.editor,
        };
        var level = RealtimeParticipants.getCollaborationLevel(participants);
        expect(level, greaterThan(0));

        // Many users, mixed permissions
        participants = {
          'user_owner': ResourcePermission.owner,
          'user_admin': ResourcePermission.admin,
          'user_editor1': ResourcePermission.editor,
          'user_editor2': ResourcePermission.editor,
          'user_viewer1': ResourcePermission.viewer,
          'user_viewer2': ResourcePermission.viewer,
        };
        level = RealtimeParticipants.getCollaborationLevel(participants);
        expect(
            level, greaterThan(30)); // Good collaboration with multiple editors
        expect(level, lessThanOrEqualTo(100));
      });
    });

    group('Participant Validation', () {
      test('should validate participants structure', () {
        // Valid - has owner
        var participants = {
          'user_owner': ResourcePermission.owner,
          'user_editor': ResourcePermission.editor,
        };
        expect(RealtimeParticipants.isValidParticipants(participants), isTrue);

        // Invalid - no owner
        participants = {
          'user_admin': ResourcePermission.admin,
          'user_editor': ResourcePermission.editor,
        };
        expect(RealtimeParticipants.isValidParticipants(participants), isFalse);

        // Invalid - empty
        expect(RealtimeParticipants.isValidParticipants({}), isFalse);

        // Invalid - empty user ID
        participants = {
          'user_owner': ResourcePermission.owner,
          '': ResourcePermission.editor,
        };
        expect(RealtimeParticipants.isValidParticipants(participants), isFalse);
      });

      test('should sanitize participants map', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
          '  user_editor  ': ResourcePermission.editor,
          '': ResourcePermission.viewer, // Should be removed
          '   ': ResourcePermission.admin, // Should be removed
        };

        final sanitized =
            RealtimeParticipants.sanitizeParticipants(participants);

        expect(sanitized.length, equals(2));
        expect(sanitized['user_owner'], equals(ResourcePermission.owner));
        expect(sanitized['user_editor'], equals(ResourcePermission.editor));
        expect(sanitized.containsKey(''), isFalse);
      });

      test('should ensure owner exists', () {
        final participants = {
          'user_editor': ResourcePermission.editor,
          'user_viewer': ResourcePermission.viewer,
        };

        final updated = RealtimeParticipants.ensureOwner(
          participants,
          'user_owner',
        );

        expect(updated['user_owner'], equals(ResourcePermission.owner));
        expect(updated.length, equals(3));

        // Should overwrite if owner exists with different permission
        final participants2 = {
          'user_owner': ResourcePermission.editor,
          'user_viewer': ResourcePermission.viewer,
        };

        final updated2 = RealtimeParticipants.ensureOwner(
          participants2,
          'user_owner',
        );

        expect(updated2['user_owner'], equals(ResourcePermission.owner));
      });
    });

    group('Permission Utilities', () {
      test('should get highest permission for user across multiple maps', () {
        final list = [
          {'user_123': ResourcePermission.viewer},
          {'user_123': ResourcePermission.editor},
          {'user_123': ResourcePermission.admin},
        ];

        final highest = RealtimeParticipants.getHighestPermission(
          list,
          'user_123',
        );

        expect(highest, equals(ResourcePermission.admin));

        // User not in any map
        final noPerm = RealtimeParticipants.getHighestPermission(
          list,
          'user_unknown',
        );
        expect(noPerm, isNull);
      });

      test('should merge participant maps taking highest permission', () {
        final list = [
          {
            'user_123': ResourcePermission.viewer,
            'user_456': ResourcePermission.editor,
          },
          {
            'user_123': ResourcePermission.admin,
            'user_789': ResourcePermission.viewer,
          },
          {
            'user_456': ResourcePermission.owner,
            'user_789': ResourcePermission.editor,
          },
        ];

        final merged = RealtimeParticipants.mergeParticipants(list);

        expect(merged['user_123'], equals(ResourcePermission.admin));
        expect(merged['user_456'], equals(ResourcePermission.owner));
        expect(merged['user_789'], equals(ResourcePermission.editor));
        expect(merged.length, equals(3));
      });

      test('should create default participants excluding owner from map', () {
        final participants = RealtimeParticipants.createDefaultParticipants(
          ownerId: 'user_owner',
          editorIds: [
            'user_editor1',
            'user_editor2',
            'user_owner'
          ], // Owner should be excluded
          viewerIds: [
            'user_viewer1',
            'user_editor1'
          ], // Duplicate should keep higher permission
        );

        // Owner is NOT in participants map
        expect(participants.containsKey('user_owner'), isFalse);
        expect(participants['user_editor1'], equals(ResourcePermission.editor));
        expect(participants['user_editor2'], equals(ResourcePermission.editor));
        expect(participants['user_viewer1'], equals(ResourcePermission.viewer));
        expect(participants.length, equals(3));
      });
    });

    group('Permission Queries', () {
      late Map<String, ResourcePermission> participants;

      setUp(() {
        participants = {
          'user_owner': ResourcePermission.owner,
          'user_admin': ResourcePermission.admin,
          'user_editor1': ResourcePermission.editor,
          'user_editor2': ResourcePermission.editor,
          'user_viewer1': ResourcePermission.viewer,
          'user_viewer2': ResourcePermission.viewer,
        };
      });

      test('should find participants with exact permission', () {
        final editors = RealtimeParticipants.findParticipants(
          participants,
          exactPermission: ResourcePermission.editor,
        );

        expect(editors.length, equals(2));
        expect(editors, containsAll(['user_editor1', 'user_editor2']));
      });

      test('should find participants with minimum permission', () {
        final canEdit = RealtimeParticipants.findParticipants(
          participants,
          minPermission: ResourcePermission.editor,
        );

        expect(canEdit.length, equals(4)); // owner, admin, 2 editors
        expect(
            canEdit,
            containsAll(
                ['user_owner', 'user_admin', 'user_editor1', 'user_editor2']));
      });

      test('should find participants with maximum permission', () {
        final limited = RealtimeParticipants.findParticipants(
          participants,
          maxPermission: ResourcePermission.editor,
        );

        expect(limited.length, equals(4)); // 2 editors, 2 viewers
        expect(
            limited,
            containsAll([
              'user_editor1',
              'user_editor2',
              'user_viewer1',
              'user_viewer2'
            ]));
      });

      test('should count participants by criteria', () {
        expect(
          RealtimeParticipants.countParticipants(
            participants,
            exactPermission: ResourcePermission.viewer,
          ),
          equals(2),
        );

        expect(
          RealtimeParticipants.countParticipants(
            participants,
            minPermission: ResourcePermission.admin,
          ),
          equals(2), // owner and admin
        );
      });
    });

    group('Edge Cases', () {
      test('should handle empty participants map', () {
        final empty = <String, ResourcePermission>{};

        expect(RealtimeParticipants.getParticipantStats(empty)['total'],
            equals(0));
        expect(RealtimeParticipants.getAllEditors(empty), isEmpty);
        expect(RealtimeParticipants.getCollaborationLevel(empty), equals(0));
        expect(RealtimeParticipants.isValidParticipants(empty), isFalse);
      });

      test('should handle legacy permissions correctly', () {
        final participants = {
          'user_write': ResourcePermission.write,
          'user_read': ResourcePermission.read,
        };

        expect(
            RealtimeParticipants.canEdit(participants, 'user_write'), isTrue);
        expect(RealtimeParticipants.canView(participants, 'user_read'), isTrue);

        final stats = RealtimeParticipants.getParticipantStats(participants);
        expect(stats['editors'], equals(1)); // write counts as editor
        expect(stats['viewers'], equals(1)); // read counts as viewer
      });

      test('should handle permission level ordering', () {
        final participants = {
          'user_owner': ResourcePermission.owner,
          'user_admin': ResourcePermission.admin,
          'user_editor': ResourcePermission.editor,
          'user_viewer': ResourcePermission.viewer,
        };

        // Owner > Admin > Editor > Viewer
        expect(
          RealtimeParticipants.hasPermission(
              participants, 'user_owner', ResourcePermission.admin),
          isTrue,
        );
        expect(
          RealtimeParticipants.hasPermission(
              participants, 'user_admin', ResourcePermission.owner),
          isFalse,
        );
        expect(
          RealtimeParticipants.hasPermission(
              participants, 'user_editor', ResourcePermission.viewer),
          isTrue,
        );
      });
    });
  });
}
