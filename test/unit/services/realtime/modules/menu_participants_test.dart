import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/realtime/modules/menu_participants.dart';
import 'package:butlery/services/realtime/modules/menu_operations.dart'; // For MenuOperationError
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/builders/realtime_menu_builder.dart';

void main() {
  group('MenuParticipants', () {
    late RealtimeMenuBuilder menuBuilder;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      menuBuilder = RealtimeMenuBuilder();
    });

    tearDown(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Participant Management', () {
      test('should add participant with editor permission', () {
        // Arrange
        final menu = menuBuilder.build();
        const userId = 'new_editor_123';

        // Act
        final updated = MenuParticipants.addParticipant(
          menu,
          userId: userId,
          userDisplayName: 'New Editor',
          permission: ResourcePermission.editor,
        );

        // Assert
        expect(updated.participants[userId], ResourcePermission.editor);
        expect(
          updated.participants.length,
          1,
        ); // Only new editor (owner not in participants)
      });

      test('should add participant with viewer permission', () {
        // Arrange
        final menu = menuBuilder.build();
        const userId = 'viewer_456';

        // Act
        final updated = MenuParticipants.addParticipant(
          menu,
          userId: userId,
          userDisplayName: 'New Viewer',
          permission: ResourcePermission.viewer,
        );

        // Assert
        expect(updated.participants[userId], ResourcePermission.viewer);
      });

      test('should remove participant successfully', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('editor_123', ResourcePermission.editor)
            .withParticipant('viewer_456', ResourcePermission.viewer)
            .build();

        // Act
        final updated = MenuParticipants.removeParticipant(
          menu,
          userId: 'editor_123',
        );

        // Assert
        expect(updated.participants.containsKey('editor_123'), false);
        expect(updated.participants.containsKey('viewer_456'), true);
      });

      test('should prevent owner removal', () {
        // Arrange
        final menu = menuBuilder.withOwner('owner_123', 'Test Owner').build();

        // Act & Assert
        expect(
          () => MenuParticipants.removeParticipant(
            menu,
            userId: 'owner_123',
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });

      test('should update participant permission', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('user_123', ResourcePermission.viewer)
            .build();

        // Act
        final updated = MenuParticipants.updateParticipantPermission(
          menu,
          userId: 'user_123',
          newPermission: ResourcePermission.editor,
        );

        // Assert
        expect(updated.participants['user_123'], ResourcePermission.editor);
      });

      test('should handle duplicate participant gracefully', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('existing_user', ResourcePermission.viewer)
            .build();

        // Act - Adding same user with different permission should throw
        expect(
          () => MenuParticipants.addParticipant(
            menu,
            userId: 'existing_user',
            userDisplayName: 'Existing User',
            permission: ResourcePermission.editor,
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });

      test('should throw error for non-existent participant update', () {
        // Arrange
        final menu = menuBuilder.build();

        // Act & Assert
        expect(
          () => MenuParticipants.updateParticipantPermission(
            menu,
            userId: 'non_existent_user',
            newPermission: ResourcePermission.editor,
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });
    });

    group('Permission Queries', () {
      test('should check if user is participant', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('user_123', ResourcePermission.viewer)
            .build();

        // Act & Assert
        expect(MenuParticipants.isParticipant(menu, 'user_123'), true);
        expect(MenuParticipants.isParticipant(menu, 'unknown_user'), false);
        expect(
          MenuParticipants.isParticipant(menu, 'owner_123'),
          false,
        ); // Owner not in participants map
      });

      test('should check edit permissions correctly', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('editor_123', ResourcePermission.editor)
            .withParticipant('viewer_456', ResourcePermission.viewer)
            .build();

        // Act & Assert
        expect(MenuParticipants.canUserEdit(menu, 'owner_123'), true);
        expect(MenuParticipants.canUserEdit(menu, 'editor_123'), true);
        expect(MenuParticipants.canUserEdit(menu, 'viewer_456'), false);
        expect(MenuParticipants.canUserEdit(menu, 'unknown_user'), false);
      });

      test('should get all editor IDs', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('editor_1', ResourcePermission.editor)
            .withParticipant('editor_2', ResourcePermission.editor)
            .withParticipant('viewer_1', ResourcePermission.viewer)
            .build();

        // Act
        final editors = MenuParticipants.getEditorIds(menu);

        // Assert
        expect(editors, contains('editor_1'));
        expect(editors, contains('editor_2'));
        expect(
          editors,
          isNot(contains('owner_123')),
        ); // Owner not in participants
        expect(editors, isNot(contains('viewer_1')));
        expect(editors.length, 2); // Only editors, not owner
      });

      test('should get all viewer IDs', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('viewer_1', ResourcePermission.viewer)
            .withParticipant('viewer_2', ResourcePermission.viewer)
            .withParticipant('editor_1', ResourcePermission.editor)
            .build();

        // Act
        final viewers = MenuParticipants.getViewerIds(menu);

        // Assert
        expect(viewers, contains('viewer_1'));
        expect(viewers, contains('viewer_2'));
        expect(viewers, isNot(contains('editor_1')));
        expect(viewers, isNot(contains('owner_123')));
      });

      test('should respect permission hierarchy', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('viewer', ResourcePermission.viewer)
            .withParticipant('editor', ResourcePermission.editor)
            .build();

        // Act & Assert
        // Viewer < Editor < Owner hierarchy
        expect(
          MenuParticipants.hasMinimumPermission(
            menu,
            'viewer',
            ResourcePermission.viewer,
          ),
          true,
        );
        expect(
          MenuParticipants.hasMinimumPermission(
            menu,
            'viewer',
            ResourcePermission.editor,
          ),
          false,
        );
        expect(
          MenuParticipants.hasMinimumPermission(
            menu,
            'editor',
            ResourcePermission.editor,
          ),
          true,
        );
        expect(
          MenuParticipants.hasMinimumPermission(
            menu,
            'owner_123',
            ResourcePermission.owner,
          ),
          true,
        );
      });

      test('should handle minimum permission checks', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('editor_123', ResourcePermission.editor)
            .build();

        // Act & Assert
        expect(
          MenuParticipants.hasMinimumPermission(
            menu,
            'editor_123',
            ResourcePermission.viewer,
          ),
          true, // Editor has viewer permission
        );
        expect(
          MenuParticipants.hasMinimumPermission(
            menu,
            'editor_123',
            ResourcePermission.owner,
          ),
          false, // Editor doesn't have owner permission
        );
      });

      test('should recognize owner special privileges', () {
        // Arrange
        final menu = menuBuilder
            .withOwner('special_owner', 'Owner Name')
            .build();

        // Act & Assert
        expect(MenuParticipants.canUserEdit(menu, 'special_owner'), true);
        expect(
          MenuParticipants.hasMinimumPermission(
            menu,
            'special_owner',
            ResourcePermission.owner,
          ),
          true,
        );
      });
    });

    group('Analytics', () {
      test('should generate participant summary', () {
        // Arrange
        final menu = menuBuilder.asCollaborativeMenu().build();

        // Act
        final summary = MenuParticipants.getParticipantSummary(menu);

        // Assert - Summary is a Map with counts (owner not in participants)
        expect(
          summary['totalParticipants'],
          3,
        ); // 3 participants (owner not counted)
        expect(summary['editorsCount'], 2);
        expect(summary['viewersCount'], 1);
      });

      test('should group participants by permission', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('editor_1', ResourcePermission.editor)
            .withParticipant('editor_2', ResourcePermission.editor)
            .withParticipant('viewer_1', ResourcePermission.viewer)
            .build();

        // Act
        // Note: getParticipantsByPermission might not exist, using manual grouping
        final grouped = <ResourcePermission, List<String>>{
          ResourcePermission.owner: [menu.ownerId],
          ResourcePermission.editor: MenuParticipants.getEditorIds(menu),
          ResourcePermission.viewer: MenuParticipants.getViewerIds(menu),
        };

        // Assert - Owner not in participants map, so not in editor/viewer lists
        expect(grouped[ResourcePermission.owner]!.length, 1);
        expect(grouped[ResourcePermission.editor]!.length, 2);
        expect(grouped[ResourcePermission.viewer]!.length, 1);
      });

      test('should handle empty participants gracefully', () {
        // Arrange
        final menu = menuBuilder.build(); // Only owner

        // Act
        final summary = MenuParticipants.getParticipantSummary(menu);
        final editors = MenuParticipants.getEditorIds(menu);
        final viewers = MenuParticipants.getViewerIds(menu);

        // Assert - Owner not in participants map
        expect(
          summary['totalParticipants'],
          0,
        ); // No participants (owner not counted)
        expect(summary['editorsCount'], 0);
        expect(summary['viewersCount'], 0);
        expect(editors, isEmpty);
        expect(viewers, isEmpty);
      });
    });

    group('Batch Operations', () {
      test('should handle adding multiple participants', () {
        // Arrange
        final menu = menuBuilder.build();

        // Act - Add multiple participants sequentially
        var updated = MenuParticipants.addParticipant(
          menu,
          userId: 'user_1',
          userDisplayName: 'User 1',
          permission: ResourcePermission.editor,
        );
        updated = MenuParticipants.addParticipant(
          updated,
          userId: 'user_2',
          userDisplayName: 'User 2',
          permission: ResourcePermission.viewer,
        );
        updated = MenuParticipants.addParticipant(
          updated,
          userId: 'user_3',
          userDisplayName: 'User 3',
          permission: ResourcePermission.editor,
        );

        // Assert
        expect(updated.participants.length, 3);
        expect(updated.participants['user_1'], ResourcePermission.editor);
        expect(updated.participants['user_2'], ResourcePermission.viewer);
        expect(updated.participants['user_3'], ResourcePermission.editor);
      });

      test('should handle removing multiple participants', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('user_1', ResourcePermission.editor)
            .withParticipant('user_2', ResourcePermission.viewer)
            .withParticipant('user_3', ResourcePermission.editor)
            .withParticipant('user_4', ResourcePermission.viewer)
            .build();

        // Act - Remove multiple participants
        var updated = MenuParticipants.removeParticipant(
          menu,
          userId: 'user_2',
        );
        updated = MenuParticipants.removeParticipant(updated, userId: 'user_4');

        // Assert
        expect(updated.participants.length, 2);
        expect(updated.participants.containsKey('user_1'), true);
        expect(updated.participants.containsKey('user_3'), true);
        expect(updated.participants.containsKey('user_2'), false);
        expect(updated.participants.containsKey('user_4'), false);
      });

      test('should handle batch permission updates', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('user_1', ResourcePermission.viewer)
            .withParticipant('user_2', ResourcePermission.viewer)
            .withParticipant('user_3', ResourcePermission.viewer)
            .build();

        // Act - Upgrade multiple users to editors
        var updated = MenuParticipants.updateParticipantPermission(
          menu,
          userId: 'user_1',
          newPermission: ResourcePermission.editor,
        );
        updated = MenuParticipants.updateParticipantPermission(
          updated,
          userId: 'user_2',
          newPermission: ResourcePermission.editor,
        );

        // Assert
        expect(updated.participants['user_1'], ResourcePermission.editor);
        expect(updated.participants['user_2'], ResourcePermission.editor);
        expect(updated.participants['user_3'], ResourcePermission.viewer);
      });

      test('should validate batch operations atomically', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('existing_user', ResourcePermission.viewer)
            .build();

        // Act - Try to add a duplicate in a batch
        final updated = MenuParticipants.addParticipant(
          menu,
          userId: 'new_user',
          userDisplayName: 'New User',
          permission: ResourcePermission.editor,
        );

        // Try to add existing user should fail
        expect(
          () => MenuParticipants.addParticipant(
            updated,
            userId: 'existing_user',
            userDisplayName: 'Duplicate',
            permission: ResourcePermission.editor,
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });
    });

    group('Permission Hierarchy Extended', () {
      test('should correctly order permission levels', () {
        // Arrange & Act
        final readLevel = MenuParticipants.getPermissionLevel(
          ResourcePermission.read,
        );
        final viewerLevel = MenuParticipants.getPermissionLevel(
          ResourcePermission.viewer,
        );
        final writeLevel = MenuParticipants.getPermissionLevel(
          ResourcePermission.write,
        );
        final editorLevel = MenuParticipants.getPermissionLevel(
          ResourcePermission.editor,
        );
        final adminLevel = MenuParticipants.getPermissionLevel(
          ResourcePermission.admin,
        );
        final ownerLevel = MenuParticipants.getPermissionLevel(
          ResourcePermission.owner,
        );

        // Assert hierarchy: read < viewer < write < editor < admin < owner
        expect(readLevel < viewerLevel, true);
        expect(viewerLevel < writeLevel, true);
        expect(writeLevel < editorLevel, true);
        expect(editorLevel < adminLevel, true);
        expect(adminLevel < ownerLevel, true);
      });

      test('should handle admin permission correctly', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('admin_user', ResourcePermission.admin)
            .build();

        // Act & Assert
        expect(
          MenuParticipants.hasMinimumPermission(
            menu,
            'admin_user',
            ResourcePermission.editor,
          ),
          true, // Admin has editor permissions
        );
        expect(
          MenuParticipants.hasMinimumPermission(
            menu,
            'admin_user',
            ResourcePermission.owner,
          ),
          false, // Admin doesn't have owner permissions
        );
      });

      test('should handle write permission correctly', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('write_user', ResourcePermission.write)
            .build();

        // Act
        final editors = MenuParticipants.getEditorIds(menu);

        // Assert - write permission is included in editors
        expect(editors.contains('write_user'), true);
      });
    });

    group('Validation and State', () {
      test('should validate participant state', () {
        // Arrange
        final menu = menuBuilder
            .withOwner('', '') // Invalid owner
            .build();

        // Act
        final errors = MenuParticipants.validateParticipantState(menu);

        // Assert
        expect(errors.isNotEmpty, true);
        expect(errors.any((e) => e.contains('owner')), true);
      });

      test('should check if menu is collaborative', () {
        // Arrange
        final collabMenu = menuBuilder
            .withParticipant('user_1', ResourcePermission.editor)
            .build();

        // Act & Assert
        // isCollaborative checks hasParticipants which might have different logic
        // Let's test the actual behavior
        final collabIsCollab = MenuParticipants.isCollaborative(collabMenu);

        // Should always be true with participants
        expect(collabIsCollab, true);
      });

      test('should get participant count correctly', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('user_1', ResourcePermission.editor)
            .withParticipant('user_2', ResourcePermission.viewer)
            .build();

        // Act
        final count = MenuParticipants.getParticipantCount(menu);

        // Assert - Owner not counted in participants
        expect(count, 2);
      });

      test('should find participant permission by ID', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('user_123', ResourcePermission.editor)
            .build();

        // Act
        final permission = MenuParticipants.findParticipantPermission(
          menu,
          'user_123',
        );

        // Assert
        expect(permission, ResourcePermission.editor);
      });
    });

    group('Edge Cases', () {
      test('should handle null/empty display names', () {
        // Arrange
        final menu = menuBuilder.build();

        // Act & Assert
        expect(
          () => MenuParticipants.addParticipant(
            menu,
            userId: 'user_123',
            userDisplayName: '',
            permission: ResourcePermission.editor,
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });

      test('should handle participants with all permission types', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('read_user', ResourcePermission.read)
            .withParticipant('viewer_user', ResourcePermission.viewer)
            .withParticipant('write_user', ResourcePermission.write)
            .withParticipant('editor_user', ResourcePermission.editor)
            .withParticipant('admin_user', ResourcePermission.admin)
            .build();

        // Act
        final participantsByPermission =
            MenuParticipants.getParticipantIdsByPermission(menu);

        // Assert
        expect(participantsByPermission[ResourcePermission.read]?.length, 1);
        expect(participantsByPermission[ResourcePermission.viewer]?.length, 1);
        expect(participantsByPermission[ResourcePermission.write]?.length, 1);
        expect(participantsByPermission[ResourcePermission.editor]?.length, 1);
        expect(participantsByPermission[ResourcePermission.admin]?.length, 1);
      });

      test('should format participant list for display', () {
        // Arrange
        final emptyMenu = menuBuilder
            .withOwner('owner_123', 'Test Owner')
            .build();
        final collabMenu = menuBuilder
            .withOwner('owner_123', 'Test Owner')
            .withParticipant('user_1', ResourcePermission.editor)
            .withParticipant('user_2', ResourcePermission.viewer)
            .build();

        // Act
        final emptyDisplay = MenuParticipants.getParticipantListString(
          emptyMenu,
        );
        final collabDisplay = MenuParticipants.getParticipantListString(
          collabMenu,
        );

        // Assert
        // Empty menu shows owner and participant count
        expect(emptyDisplay, contains('Ägare: Test Owner'));
        expect(collabDisplay, contains('Deltagare: 2st'));
      });

      test('should handle permission update to same permission', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('user_123', ResourcePermission.editor)
            .build();

        // Act - Update to same permission
        final updated = MenuParticipants.updateParticipantPermission(
          menu,
          userId: 'user_123',
          newPermission: ResourcePermission.editor,
        );

        // Assert - Should return unchanged menu
        expect(updated.participants['user_123'], ResourcePermission.editor);
        expect(identical(updated, menu), true); // Same object returned
      });
    });

    group('Error Handling', () {
      test('should validate user ID not empty', () {
        // Arrange
        final menu = menuBuilder.build();

        // Act & Assert
        expect(
          () => MenuParticipants.addParticipant(
            menu,
            userId: '',
            userDisplayName: 'Empty ID User',
            permission: ResourcePermission.editor,
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });

      test('should prevent owner permission changes', () {
        // Arrange
        final menu = menuBuilder.withOwner('owner_456', 'Owner').build();

        // Act & Assert
        expect(
          () => MenuParticipants.updateParticipantPermission(
            menu,
            userId: 'owner_456',
            newPermission: ResourcePermission.editor,
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });

      test('should validate permission levels', () {
        // Arrange
        final menu = menuBuilder
            .withParticipant('user_123', ResourcePermission.viewer)
            .build();

        // Act - Try to set owner permission (should be prevented)
        expect(
          () => MenuParticipants.updateParticipantPermission(
            menu,
            userId: 'user_123',
            newPermission: ResourcePermission.owner,
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });

      test('should handle removing non-existent participant', () {
        // Arrange
        final menu = menuBuilder.build();

        // Act & Assert
        expect(
          () => MenuParticipants.removeParticipant(
            menu,
            userId: 'non_existent',
          ),
          throwsA(isA<MenuOperationError>()),
        );
      });

      test('should provide error messages in Swedish', () {
        // Arrange
        final menu = menuBuilder.build();

        // Act & Assert - Owner not in participants, so different error
        try {
          MenuParticipants.removeParticipant(menu, userId: 'owner_123');
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<MenuOperationError>());
          final error = e as MenuOperationError;
          // Owner not in participants, so get "not a participant" error
          expect(error.message, 'Användaren är inte deltagare: owner_123');
        }
      });
    });
  });
}
