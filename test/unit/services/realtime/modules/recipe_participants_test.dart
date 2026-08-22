import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/realtime/modules/recipe_participants.dart';
import 'package:butlery/services/realtime/modules/recipe_content_operations.dart'; // For RecipeOperationError
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/builders/realtime_recipe_builder.dart';

void main() {
  group('RecipeParticipants', () {
    late RealtimeRecipeBuilder recipeBuilder;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      recipeBuilder = RealtimeRecipeBuilder();
    });

    tearDown(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Collaboration Management', () {
      test('should add collaborator with editor permission', () {
        // Arrange
        final recipe = recipeBuilder.build();
        const userId = 'editor_123';

        // Act
        final updated = RecipeParticipants.addParticipant(
          recipe,
          userId: userId,
          userDisplayName: 'Editor User',
          permission: ResourcePermission.editor,
        );

        // Assert
        expect(updated.participants[userId], ResourcePermission.editor);
        expect(
          updated.participants.length,
          1,
        ); // Only new editor (owner not in participants)
      });

      test('should add collaborator with viewer permission', () {
        // Arrange
        final recipe = recipeBuilder.build();
        const userId = 'viewer_456';

        // Act
        final updated = RecipeParticipants.addParticipant(
          recipe,
          userId: userId,
          userDisplayName: 'Viewer User',
          permission: ResourcePermission.viewer,
        );

        // Assert
        expect(updated.participants[userId], ResourcePermission.viewer);
      });

      test('should remove collaborator successfully', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('collab_123', ResourcePermission.editor)
            .withParticipant('collab_456', ResourcePermission.viewer)
            .build();

        // Act
        final updated = RecipeParticipants.removeParticipant(
          recipe,
          userId: 'collab_123',
        );

        // Assert
        expect(updated.participants.containsKey('collab_123'), false);
        expect(updated.participants.containsKey('collab_456'), true);
      });

      test('should prevent owner removal', () {
        // Arrange
        final recipe = recipeBuilder
            .withOwner('owner_123', 'Recipe Owner')
            .build();

        // Act & Assert
        expect(
          () => RecipeParticipants.removeParticipant(
            recipe,
            userId: 'owner_123',
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should update collaborator permissions', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('user_123', ResourcePermission.viewer)
            .build();

        // Act
        final updated = RecipeParticipants.updateParticipantPermission(
          recipe,
          userId: 'user_123',
          newPermission: ResourcePermission.editor,
        );

        // Assert
        expect(updated.participants['user_123'], ResourcePermission.editor);
      });

      test('should handle duplicate collaborator gracefully', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('existing_user', ResourcePermission.viewer)
            .build();

        // Act & Assert - Adding same user should throw
        expect(
          () => RecipeParticipants.addParticipant(
            recipe,
            userId: 'existing_user',
            userDisplayName: 'Existing User',
            permission: ResourcePermission.editor,
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should enforce maximum collaborator limit', () {
        // Arrange
        var recipe = recipeBuilder.build();

        // Add many collaborators (owner not in participants)
        for (int i = 0; i < 50; i++) {
          recipe = RecipeParticipants.addParticipant(
            recipe,
            userId: 'user_$i',
            userDisplayName: 'User $i',
            permission: ResourcePermission.viewer,
          );
        }

        // Act & Assert - Should prevent adding more
        expect(
          () => RecipeParticipants.addParticipant(
            recipe,
            userId: 'user_51',
            userDisplayName: 'User 51',
            permission: ResourcePermission.viewer,
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });
    });

    group('Access Control', () {
      test('should check view permissions correctly', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('viewer_123', ResourcePermission.viewer)
            .withParticipant('editor_456', ResourcePermission.editor)
            .build();

        // Act & Assert
        expect(RecipeParticipants.canUserView(recipe, 'owner_123'), true);
        expect(RecipeParticipants.canUserView(recipe, 'viewer_123'), true);
        expect(RecipeParticipants.canUserView(recipe, 'editor_456'), true);
        expect(RecipeParticipants.canUserView(recipe, 'unknown_user'), false);
      });

      test('should check edit permissions correctly', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('viewer_123', ResourcePermission.viewer)
            .withParticipant('editor_456', ResourcePermission.editor)
            .build();

        // Act & Assert
        expect(RecipeParticipants.canUserEdit(recipe, 'owner_123'), true);
        expect(RecipeParticipants.canUserEdit(recipe, 'editor_456'), true);
        expect(RecipeParticipants.canUserEdit(recipe, 'viewer_123'), false);
        expect(RecipeParticipants.canUserEdit(recipe, 'unknown_user'), false);
      });

      test('should check invitation privileges', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('editor_123', ResourcePermission.editor)
            .withParticipant('viewer_456', ResourcePermission.viewer)
            .build();

        // Act & Assert
        expect(RecipeParticipants.canUserInvite(recipe, 'owner_123'), true);
        expect(
          RecipeParticipants.canUserInvite(recipe, 'editor_123'),
          false,
        ); // Only admin/owner can invite
        expect(RecipeParticipants.canUserInvite(recipe, 'viewer_456'), false);
      });

      test('should check admin rights', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('editor_123', ResourcePermission.editor)
            .build();

        // Act & Assert
        expect(
          RecipeParticipants.canUserManagePermissions(recipe, 'owner_123'),
          true,
        );
        expect(
          RecipeParticipants.canUserManagePermissions(recipe, 'editor_123'),
          false,
        );
      });

      test('should validate permission hierarchy', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('viewer', ResourcePermission.viewer)
            .withParticipant('editor', ResourcePermission.editor)
            .build();

        // Act & Assert - Viewer < Editor < Owner
        expect(RecipeParticipants.canUserView(recipe, 'viewer'), true);
        expect(RecipeParticipants.canUserEdit(recipe, 'viewer'), false);
        expect(RecipeParticipants.canUserView(recipe, 'editor'), true);
        expect(RecipeParticipants.canUserEdit(recipe, 'editor'), true);
      });

      test('should handle anonymous user access', () {
        // Arrange
        final recipe = recipeBuilder.build();

        // Act & Assert
        expect(RecipeParticipants.canUserView(recipe, ''), false);
        expect(RecipeParticipants.canUserEdit(recipe, ''), false);
        expect(RecipeParticipants.canUserInvite(recipe, ''), false);
      });

      test('should recognize owner override permissions', () {
        // Arrange
        final recipe = recipeBuilder
            .withOwner('super_owner', 'Owner Name')
            .build();

        // Act & Assert - Owner has all permissions via isOwner check
        expect(RecipeParticipants.canUserView(recipe, 'super_owner'), true);
        expect(RecipeParticipants.canUserEdit(recipe, 'super_owner'), true);
        expect(
          RecipeParticipants.canUserInvite(recipe, 'super_owner'),
          true,
        ); // Owner can invite
        expect(
          RecipeParticipants.canUserManagePermissions(recipe, 'super_owner'),
          true,
        ); // Owner can manage
      });

      test('should validate permission inheritance', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('editor_123', ResourcePermission.editor)
            .build();

        // Act & Assert - Editor inherits viewer permissions
        expect(RecipeParticipants.canUserView(recipe, 'editor_123'), true);
        expect(RecipeParticipants.canUserEdit(recipe, 'editor_123'), true);
        expect(
          RecipeParticipants.canUserInvite(recipe, 'editor_123'),
          false,
        ); // Only admin/owner can invite
        expect(
          RecipeParticipants.canUserManagePermissions(recipe, 'editor_123'),
          false,
        );
      });
    });

    group('Collaboration Status', () {
      test('should generate collaboration status string', () {
        // Arrange
        final recipe = recipeBuilder.asCollaborativeSwedishDinner().build();

        // Act
        final status = RecipeParticipants.getCollaborationStatus(recipe);

        // Assert
        expect(
          status,
          anyOf(contains('Kollaborativt'), contains('redigerare')),
        );
      });

      test('should provide complete collaboration info', () {
        // Arrange
        final recipe = recipeBuilder
            .withParticipant('editor_1', ResourcePermission.editor)
            .withParticipant('editor_2', ResourcePermission.editor)
            .withParticipant('viewer_1', ResourcePermission.viewer)
            .build();

        // Act
        final info = RecipeParticipants.getCollaborationInfo(recipe);

        // Assert
        expect(
          info['participantCount'],
          3,
        ); // 3 participants (owner not in participants map)
        expect(info['editorCount'], 2);
        expect(info['viewerCount'], 1);
        expect(info['isCollaborative'], true);
      });

      test('should suggest permissions for new users', () {
        // Arrange
        // Recipes not needed for this test - getSuggestedPermissionForNewParticipant is static

        // Act
        final smallSuggestion =
            RecipeParticipants.getSuggestedPermissionForNewParticipant();
        final largeSuggestion =
            RecipeParticipants.getSuggestedPermissionForNewParticipant();

        // Assert
        expect(smallSuggestion, ResourcePermission.viewer); // Default is viewer
        expect(largeSuggestion, ResourcePermission.viewer); // Same default
      });

      test('should handle empty collaborator scenarios', () {
        // Arrange
        final recipe = recipeBuilder.build(); // Only owner

        // Act
        final status = RecipeParticipants.getCollaborationStatus(recipe);
        final info = RecipeParticipants.getCollaborationInfo(recipe);

        // Assert - Owner not in participants map, so private recipe
        expect(status, 'Privat recept');
        expect(
          info['participantCount'],
          0,
        ); // No participants (owner not counted)
        expect(info['isCollaborative'], false);
      });
    });

    group('Error Handling', () {
      test('should validate user ID not empty', () {
        // Arrange
        final recipe = recipeBuilder.build();

        // Act & Assert
        expect(
          () => RecipeParticipants.addParticipant(
            recipe,
            userId: '',
            userDisplayName: 'Empty ID User',
            permission: ResourcePermission.editor,
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should handle invalid user operations', () {
        // Arrange
        final recipe = recipeBuilder.build();

        // Act & Assert - Update non-existent user
        expect(
          () => RecipeParticipants.updateParticipantPermission(
            recipe,
            userId: 'non_existent',
            newPermission: ResourcePermission.editor,
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should prevent permission violations', () {
        // Arrange
        final recipe = recipeBuilder.withOwner('owner_456', 'Owner').build();

        // Act & Assert - Can't change owner permission
        expect(
          () => RecipeParticipants.updateParticipantPermission(
            recipe,
            userId: 'owner_456',
            newPermission: ResourcePermission.editor,
          ),
          throwsA(isA<RecipeOperationError>()),
        );
      });

      test('should enforce owner protection', () {
        // Arrange
        final recipe = recipeBuilder
            .withOwner('protected_owner', 'Protected')
            .withParticipant('user_123', ResourcePermission.editor)
            .build();

        // Act - Updating to owner permission is allowed by the service
        final updated = RecipeParticipants.updateParticipantPermission(
          recipe,
          userId: 'user_123',
          newPermission: ResourcePermission.owner,
        );

        // Assert - Permission was updated
        expect(updated.participants['user_123'], ResourcePermission.owner);
      });

      test('should provide error messages in Swedish', () {
        // Arrange
        final recipe = recipeBuilder
            .withOwner('owner_123', 'Test Owner')
            .build();

        // Act & Assert - RecipeParticipants checks owner BEFORE participant check
        try {
          RecipeParticipants.removeParticipant(recipe, userId: 'owner_123');
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<RecipeOperationError>());
          final error = e as RecipeOperationError;
          // Owner check comes first, so get owner error
          expect(error.message, 'Kan inte ta bort receptägaren');
        }
      });

      // BUT-1915. The twin of the menu leak, one module away and the same
      // shape: `RecipeOperationError` carries the message into `toString()`,
      // and `AppLogger.error` hands the object to Crashlytics unaltered on a
      // phone. Found by the Localization/i18n stakeholder review, which noted
      // the menu ticket named only its own file.
      //
      // A real Firebase uid is 28 characters. A short fixture id would prove
      // nothing, because `LogSanitizer.maskUserId` returns anything of 8
      // characters or fewer unchanged.
      group('raw user id never reaches the exception (BUT-1915)', () {
        const realisticUid = 'aBcDeFgHiJkLmNoPqRsTuVwXyZ01';

        test('removeParticipant masks the id in message and toString', () {
          final recipe = recipeBuilder
              .withOwner('owner_123', 'Recipe Owner')
              .build();

          try {
            RecipeParticipants.removeParticipant(recipe, userId: realisticUid);
            fail('Should have thrown');
          } catch (e) {
            final error = e as RecipeOperationError;
            expect(error.message, isNot(contains(realisticUid)));
            expect(error.toString(), isNot(contains(realisticUid)));
            expect(error.message, contains('aBcDeFgH...'));
          }
        });

        test(
          'updateParticipantPermission masks the id in message and toString',
          () {
            final recipe = recipeBuilder
                .withOwner('owner_123', 'Recipe Owner')
                .build();

            try {
              RecipeParticipants.updateParticipantPermission(
                recipe,
                userId: realisticUid,
                newPermission: ResourcePermission.editor,
              );
              fail('Should have thrown');
            } catch (e) {
              final error = e as RecipeOperationError;
              expect(error.message, isNot(contains(realisticUid)));
              expect(error.toString(), isNot(contains(realisticUid)));
              expect(error.message, contains('aBcDeFgH...'));
            }
          },
        );
        // The display-name twin, same sink, found by the code-reviewer gate on
        // this diff. `LogSanitizer.maskIdentifiers` never runs on this
        // path: `_sanitizeForCrashlytics` masks the message STRING handed to
        // `AppLogger.error`, while `_logToCrashlytics` passes the exception
        // OBJECT to `recordError` untouched. So the name left the phone in
        // cleartext while the `AppLogger.info` line below masked it.
        test('addParticipant masks an existing participant display name', () {
          const displayName = 'Annika Bergström';
          final recipe = RecipeParticipants.addParticipant(
            recipeBuilder.withOwner('owner_123', 'Recipe Owner').build(),
            userId: realisticUid,
            userDisplayName: displayName,
            permission: ResourcePermission.editor,
          );

          try {
            RecipeParticipants.addParticipant(
              recipe,
              userId: realisticUid,
              userDisplayName: displayName,
              permission: ResourcePermission.viewer,
            );
            fail('Should have thrown');
          } catch (e) {
            final error = e as RecipeOperationError;
            expect(error.message, isNot(contains(displayName)));
            expect(error.toString(), isNot(contains(displayName)));
            expect(error.message, contains('An***'));
            // Without this, a mask that elided only the GIVEN name
            // ('An*** Bergström') satisfies every other assertion here.
            expect(error.message, isNot(contains('Bergström')));
          }
        });
      });
    });
  });
}
