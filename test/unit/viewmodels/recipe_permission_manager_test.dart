// test/unit/viewmodels/recipe_permission_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecipePermissionManager - Ultrathink Enhanced Tests', () {
    late RecipePermissionManager permissionManager;
    late FakePermissionService mockPermissionService;

    // Test data
    const testRecipeId = 'recipe_123';
    const testUserId = 'user_456';
    const testCurrentUserId = 'current_user_789';
    const testPermission = 'test_permission';

    setUpAll(() async {
      await TestServiceLocator.initialize();
    });

    setUp(() {
      mockPermissionService = FakePermissionService();

      // Configure default permission service state using ultrathink state configuration
      mockPermissionService.setPermissionState(
        currentUserId: testCurrentUserId,
        userDisplayName: 'Test User',
        isAuthenticated: true,
        defaultHasPermission: true,
        permissions: {
          testRecipeId: {
            ResourcePermission.owner: true,
            ResourcePermission.editor: true,
            ResourcePermission.viewer: true,
          }
        },
      );

      permissionManager = RecipePermissionManager(
        permissionService: mockPermissionService,
      );
    });

    tearDown(() async {
      permissionManager.dispose();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
    });

    group('Initialization and Recipe ID Management', () {
      test('should initialize with no recipe ID set', () {
        // Assert
        expect(permissionManager, isNotNull);
        // Cannot test _recipeId directly as it's private, but behavior tests will verify
      });

      test('should set recipe ID successfully', () {
        // Act
        permissionManager.setRecipeId(testRecipeId);

        // Assert - verify through behavior that recipe ID was set
        // Since we can't access _recipeId directly, we test through getters that depend on it
        expect(permissionManager.canShare,
            isTrue); // Should be true for existing recipe with owner permissions
      });

      test('should clear recipe ID when set to null', () {
        // Arrange
        permissionManager.setRecipeId(testRecipeId);

        // Act
        permissionManager.setRecipeId(null);

        // Assert - verify through behavior that recipe ID was cleared
        expect(permissionManager.canShare,
            isFalse); // Should be false for null recipe ID
      });

      test('should handle multiple recipe ID changes', () {
        // Arrange
        const firstRecipeId = 'recipe_first';
        const secondRecipeId = 'recipe_second';

        // Act & Assert - first recipe
        permissionManager.setRecipeId(firstRecipeId);
        expect(permissionManager.canEdit,
            isTrue); // Assuming authenticated user has edit permissions

        // Act & Assert - second recipe
        permissionManager.setRecipeId(secondRecipeId);
        expect(permissionManager.canEdit,
            isTrue); // Should work for second recipe too

        // Act & Assert - clear recipe
        permissionManager.setRecipeId(null);
        expect(permissionManager.canEdit,
            isTrue); // Should be true for new recipe creation (null ID)
      });
    });

    group('Basic Permission Checks', () {
      test('should check generic permission correctly when authenticated', () {
        // Act
        final hasPermission = permissionManager.hasPermission(testPermission);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should deny generic permission when not authenticated', () {
        // Arrange - reconfigure as unauthenticated
        mockPermissionService.setPermissionState(
          currentUserId: null,
          isAuthenticated: false,
          defaultHasPermission: false,
        );

        // Act
        final hasPermission = permissionManager.hasPermission(testPermission);

        // Assert
        expect(hasPermission, isFalse);
      });

      test('should check recipe edit permission correctly', () {
        // Act
        final canEdit = permissionManager.canEditRecipe(testRecipeId);

        // Assert
        expect(canEdit, isTrue);
      });

      test('should deny recipe edit permission when not authorized', () {
        // Arrange - reconfigure with no edit permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
            }
          },
        );

        // Act
        final canEdit = permissionManager.canEditRecipe(testRecipeId);

        // Assert
        expect(canEdit, isFalse);
      });

      test('should check member invitation permission correctly', () {
        // Act
        final canInvite = permissionManager.canInviteMembers(testRecipeId);

        // Assert
        expect(canInvite, isTrue);
      });

      test('should deny member invitation when not authorized', () {
        // Arrange - reconfigure with no invitation permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.viewer: true,
              ResourcePermission.admin: false,
              ResourcePermission.owner: false,
            }
          },
        );

        // Act
        final canInvite = permissionManager.canInviteMembers(testRecipeId);

        // Assert
        expect(canInvite, isFalse);
      });

      test('should check member management permission correctly', () {
        // Act
        final canManage = permissionManager.canManageMembers(testRecipeId);

        // Assert
        expect(canManage, isTrue);
      });

      test('should deny member management when not owner', () {
        // Arrange - reconfigure as non-owner
        mockPermissionService.setPermissionState(
          currentUserId: 'different_user',
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.editor: true,
              ResourcePermission.owner: false,
            }
          },
        );

        // Act
        final canManage = permissionManager.canManageMembers(testRecipeId);

        // Assert
        expect(canManage, isFalse);
      });

      test('should handle empty recipe ID for edit permission', () {
        // Act
        final canEdit = permissionManager.canEditRecipe('');

        // Assert
        expect(canEdit, isFalse); // Should deny permission for empty recipe ID
      });

      test('should handle null-like recipe ID for edit permission', () {
        // Act
        final canEdit = permissionManager.canEditRecipe('   '); // Whitespace

        // Assert
        expect(canEdit, isTrue); // Should handle gracefully
      });
    });

    group('UI State Permission Getters - New Recipe Creation', () {
      test(
          'should allow all permissions for new recipe creation (null recipe ID)',
          () {
        // Arrange - ensure no recipe ID is set
        permissionManager.setRecipeId(null);

        // Act & Assert
        expect(permissionManager.canEdit,
            isTrue); // New recipe creation always allows editing
        expect(permissionManager.canView,
            isTrue); // New recipe creation always allows viewing
        expect(permissionManager.isOwner,
            isTrue); // User is owner of new recipe during creation

        // These should be false for null recipe ID
        expect(permissionManager.canShare,
            isFalse); // Cannot share non-existent recipe
        expect(permissionManager.canInvite,
            isFalse); // Cannot invite to non-existent recipe
        expect(permissionManager.canDelete,
            isFalse); // Cannot delete non-existent recipe
      });
    });

    group('UI State Permission Getters - Existing Recipe', () {
      setUp(() {
        permissionManager.setRecipeId(testRecipeId);
      });

      test('should check edit permission for existing recipe', () {
        // Act
        final canEdit = permissionManager.canEdit;

        // Assert
        expect(canEdit, isTrue);
      });

      test(
          'should deny edit permission when not authorized for existing recipe',
          () {
        // Arrange - reconfigure with no edit permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
            }
          },
        );

        // Act
        final canEdit = permissionManager.canEdit;

        // Assert
        expect(canEdit, isFalse);
      });

      test('should check view permission for existing recipe', () {
        // Act
        final canView = permissionManager.canView;

        // Assert
        expect(canView, isTrue);
      });

      test(
          'should deny view permission when not authorized for existing recipe',
          () {
        // Arrange - reconfigure with no view permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.viewer: false,
            }
          },
        );

        // Act
        final canView = permissionManager.canView;

        // Assert
        expect(canView, isFalse);
      });

      test('should check share permission for existing recipe', () {
        // Act
        final canShare = permissionManager.canShare;

        // Assert
        expect(canShare, isTrue);
      });

      test('should deny share permission when not owner of existing recipe',
          () {
        // Arrange - reconfigure as non-owner
        mockPermissionService.setPermissionState(
          currentUserId: 'different_user',
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.editor: true,
              ResourcePermission.owner: false,
            }
          },
        );

        // Act
        final canShare = permissionManager.canShare;

        // Assert
        expect(canShare, isFalse);
      });

      test('should check invite permission for existing recipe', () {
        // Act
        final canInvite = permissionManager.canInvite;

        // Assert
        expect(canInvite, isTrue);
      });

      test(
          'should deny invite permission when not authorized for existing recipe',
          () {
        // Arrange - reconfigure with no invitation permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.viewer: true,
              ResourcePermission.admin: false,
              ResourcePermission.owner: false,
            }
          },
        );

        // Act
        final canInvite = permissionManager.canInvite;

        // Assert
        expect(canInvite, isFalse);
      });

      test('should check delete permission for existing recipe', () {
        // Act
        final canDelete = permissionManager.canDelete;

        // Assert
        expect(canDelete, isTrue);
      });

      test('should deny delete permission when not owner of existing recipe',
          () {
        // Arrange - reconfigure as non-owner
        mockPermissionService.setPermissionState(
          currentUserId: 'different_user',
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.editor: true,
              ResourcePermission.owner: false,
            }
          },
        );

        // Act
        final canDelete = permissionManager.canDelete;

        // Assert
        expect(canDelete, isFalse);
      });

      test('should check owner status for existing recipe', () {
        // Act
        final isOwner = permissionManager.isOwner;

        // Assert
        expect(isOwner, isTrue);
      });

      test('should deny owner status when not owner of existing recipe', () {
        // Arrange - reconfigure as non-owner
        mockPermissionService.setPermissionState(
          currentUserId: 'different_user',
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.editor: true,
              ResourcePermission.owner: false,
            }
          },
        );

        // Act
        final isOwner = permissionManager.isOwner;

        // Assert
        expect(isOwner, isFalse);
      });

      test('should check general permissions availability', () {
        // Act
        final hasPermissions = permissionManager.hasPermissions;

        // Assert
        expect(hasPermissions, isTrue);
      });

      test('should deny general permissions when not authenticated', () {
        // Arrange - reconfigure as unauthenticated
        mockPermissionService.setPermissionState(
          currentUserId: null,
          isAuthenticated: false,
          defaultHasPermission: false,
        );

        // Act
        final hasPermissions = permissionManager.hasPermissions;

        // Assert
        expect(hasPermissions, isFalse);
      });
    });

    group('Edit Mode Properties', () {
      test('should return edit mode string correctly', () {
        // Act
        final editMode = permissionManager.editMode;

        // Assert
        expect(editMode, equals('edit'));
      });

      test('should return edit mode enum correctly', () {
        // Act
        final editModeEnum = permissionManager.editModeEnum;

        // Assert
        expect(editModeEnum, equals(EditMode.edit));
      });

      test('should maintain consistent edit mode values', () {
        // Act
        final editModeString = permissionManager.editMode;
        final editModeEnumValue = permissionManager.editModeEnum;

        // Assert - both should represent the same concept
        expect(editModeString, isA<String>());
        expect(editModeEnumValue, isA<EditMode>());
        expect(editModeString, equals('edit'));
        expect(editModeEnumValue, equals(EditMode.edit));
      });

      test('should handle multiple access to edit mode properties', () {
        // Act - multiple accesses
        final mode1 = permissionManager.editMode;
        final mode2 = permissionManager.editMode;
        final enum1 = permissionManager.editModeEnum;
        final enum2 = permissionManager.editModeEnum;

        // Assert - should be consistent
        expect(mode1, equals(mode2));
        expect(enum1, equals(enum2));
        expect(mode1, equals('edit'));
        expect(enum1, equals(EditMode.edit));
      });
    });

    group('Permission Management Operations', () {
      test('should update user permission successfully when authorized', () {
        // Act
        final result = permissionManager.updateUserPermission(
            testRecipeId, testUserId, 'editor');

        // Assert
        expect(result, isTrue);
      });

      test('should deny permission update when not owner', () {
        // Arrange - reconfigure as non-owner
        mockPermissionService.setPermissionState(
          currentUserId: 'different_user',
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.editor: true,
              ResourcePermission.owner: false,
            }
          },
        );

        // Act
        final result = permissionManager.updateUserPermission(
            testRecipeId, testUserId, 'editor');

        // Assert
        expect(result, isFalse);
      });

      test('should handle different permission types in update', () {
        final permissions = ['viewer', 'editor', 'admin', 'owner'];

        for (final permission in permissions) {
          // Act
          final result = permissionManager.updateUserPermission(
              testRecipeId, testUserId, permission);

          // Assert
          expect(result, isTrue,
              reason: 'Should update permission to $permission');
        }
      });

      test('should handle null permission in update gracefully', () {
        // Act
        final result = permissionManager.updateUserPermission(
            testRecipeId, testUserId, null);

        // Assert
        expect(result, isTrue); // Should not crash and return success
      });

      test('should handle empty recipe ID in permission update', () {
        // Act
        final result =
            permissionManager.updateUserPermission('', testUserId, 'editor');

        // Assert
        expect(result, isFalse); // Should fail for empty recipe ID
      });

      test('should handle empty user ID in permission update', () {
        // Act
        final result =
            permissionManager.updateUserPermission(testRecipeId, '', 'editor');

        // Assert
        expect(result, isTrue); // Current implementation allows empty user ID
      });

      test('should share recipe with user successfully', () {
        // Act
        final result = permissionManager.shareRecipeWithUser(
            testRecipeId, testUserId, 'viewer');

        // Assert
        expect(result, isTrue);
      });

      test('should handle different sharing permissions', () {
        final permissions = ['viewer', 'editor', 'admin'];

        for (final permission in permissions) {
          // Act
          final result = permissionManager.shareRecipeWithUser(
              testRecipeId, testUserId, permission);

          // Assert
          expect(result, isTrue,
              reason: 'Should share with $permission permission');
        }
      });

      test('should handle null values in recipe sharing', () {
        // Act & Assert
        expect(permissionManager.shareRecipeWithUser('', testUserId, 'viewer'),
            isTrue);
        expect(
            permissionManager.shareRecipeWithUser(testRecipeId, '', 'viewer'),
            isTrue);
        expect(
            permissionManager.shareRecipeWithUser(
                testRecipeId, testUserId, null),
            isTrue);
        expect(
            permissionManager.shareRecipeWithUser(testRecipeId, testUserId, ''),
            isTrue);
      });
    });

    group('Action and Field Validation', () {
      test('should allow all actions by default', () {
        final actions = [
          'create',
          'edit',
          'delete',
          'share',
          'invite',
          'comment',
          'rate'
        ];

        for (final action in actions) {
          // Act
          final canPerform = permissionManager.canPerformAction(action);

          // Assert
          expect(canPerform, isTrue, reason: 'Should allow $action action');
        }
      });

      test('should handle empty and null actions', () {
        // Act & Assert
        expect(permissionManager.canPerformAction(''), isTrue);
        expect(permissionManager.canPerformAction(' '), isTrue); // Whitespace
      });

      test('should allow editing all fields by default', () {
        final fields = [
          'title',
          'description',
          'ingredients',
          'instructions',
          'tags',
          'image'
        ];

        for (final field in fields) {
          // Act
          final canEdit = permissionManager.canEditField(field);

          // Assert
          expect(canEdit, isTrue, reason: 'Should allow editing $field field');
        }
      });

      test('should handle empty and null field names', () {
        // Act & Assert
        expect(permissionManager.canEditField(''), isTrue);
        expect(permissionManager.canEditField(' '), isTrue); // Whitespace
      });

      test('should handle special characters in action names', () {
        final specialActions = [
          'action-with-dash',
          'action_with_underscore',
          'action.with.dots'
        ];

        for (final action in specialActions) {
          // Act
          final canPerform = permissionManager.canPerformAction(action);

          // Assert
          expect(canPerform, isTrue,
              reason: 'Should handle special action: $action');
        }
      });

      test('should handle special characters in field names', () {
        final specialFields = [
          'field-with-dash',
          'field_with_underscore',
          'field.with.dots'
        ];

        for (final field in specialFields) {
          // Act
          final canEdit = permissionManager.canEditField(field);

          // Assert
          expect(canEdit, isTrue,
              reason: 'Should handle special field: $field');
        }
      });
    });

    group('Listener Management', () {
      test('should add listener without throwing', () {
        // Arrange
        void testListener() {}

        // Act & Assert - should not throw
        expect(
            () => permissionManager.addListener(testListener), returnsNormally);
      });

      test('should remove listener without throwing', () {
        // Arrange
        void testListener() {}
        permissionManager.addListener(testListener);

        // Act & Assert - should not throw
        expect(() => permissionManager.removeListener(testListener),
            returnsNormally);
      });

      test('should handle null listener in add', () {
        // Act & Assert - should not throw
        expect(() => permissionManager.addListener(null), returnsNormally);
      });

      test('should handle null listener in remove', () {
        // Act & Assert - should not throw
        expect(() => permissionManager.removeListener(null), returnsNormally);
      });

      test('should handle multiple listeners', () {
        // Arrange
        void listener1() {}
        void listener2() {}
        void listener3() {}

        // Act & Assert - should not throw
        expect(() {
          permissionManager.addListener(listener1);
          permissionManager.addListener(listener2);
          permissionManager.addListener(listener3);
        }, returnsNormally);

        expect(() {
          permissionManager.removeListener(listener1);
          permissionManager.removeListener(listener2);
          permissionManager.removeListener(listener3);
        }, returnsNormally);
      });

      test('should handle removing non-existent listener', () {
        // Arrange
        void nonExistentListener() {}

        // Act & Assert - should not throw
        expect(() => permissionManager.removeListener(nonExistentListener),
            returnsNormally);
      });

      test('should handle duplicate listener additions', () {
        // Arrange
        void duplicateListener() {}

        // Act & Assert - should not throw
        expect(() {
          permissionManager.addListener(duplicateListener);
          permissionManager.addListener(duplicateListener); // Duplicate
          permissionManager.addListener(duplicateListener); // Another duplicate
        }, returnsNormally);
      });
    });

    group('Lifecycle Methods', () {
      test('should load permissions without throwing', () async {
        // Act & Assert - should not throw
        await expectLater(permissionManager.loadPermissions(), completes);
      });

      test('should check permissions without throwing', () {
        // Act & Assert - should not throw
        expect(() => permissionManager.checkPermissions(), returnsNormally);
      });

      test('should dispose without throwing', () {
        // Act & Assert - should not throw
        expect(() => permissionManager.dispose(), returnsNormally);
      });

      test('should handle multiple dispose calls', () {
        // Act & Assert - should not throw on multiple calls
        expect(() {
          permissionManager.dispose();
          permissionManager.dispose();
          permissionManager.dispose();
        }, returnsNormally);
      });

      test('should handle multiple loadPermissions calls', () async {
        // Act & Assert - should not throw on multiple calls
        await expectLater(permissionManager.loadPermissions(), completes);
        await expectLater(permissionManager.loadPermissions(), completes);
        await expectLater(permissionManager.loadPermissions(), completes);
      });

      test('should handle multiple checkPermissions calls', () {
        // Act & Assert - should not throw on multiple calls
        expect(() {
          permissionManager.checkPermissions();
          permissionManager.checkPermissions();
          permissionManager.checkPermissions();
        }, returnsNormally);
      });

      test('should handle operations after dispose', () {
        // Arrange
        permissionManager.dispose();

        // Act & Assert - should not throw even after disposal
        expect(() => permissionManager.hasPermission('test'), returnsNormally);
        expect(() => permissionManager.canEditRecipe(testRecipeId),
            returnsNormally);
        expect(
            () => permissionManager.setRecipeId(testRecipeId), returnsNormally);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle extremely long recipe IDs', () {
        // Arrange
        final longRecipeId = 'recipe_${'x' * 1000}'; // Very long ID

        // Act & Assert - should not crash
        expect(
            () => permissionManager.setRecipeId(longRecipeId), returnsNormally);
        expect(() => permissionManager.canEditRecipe(longRecipeId),
            returnsNormally);
        expect(() => permissionManager.canInviteMembers(longRecipeId),
            returnsNormally);
      });

      test('should handle special characters in recipe IDs', () {
        final specialIds = [
          'recipe-with-dashes',
          'recipe_with_underscores',
          'recipe.with.dots',
          'recipe@with@symbols',
          'recipe with spaces',
          'recipe/with/slashes',
        ];

        for (final recipeId in specialIds) {
          // Act & Assert - should not crash
          expect(
              () => permissionManager.setRecipeId(recipeId), returnsNormally);
          expect(
              () => permissionManager.canEditRecipe(recipeId), returnsNormally);
        }
      });

      test('should handle unicode characters in recipe IDs', () {
        final unicodeIds = [
          'recipe_ñáéíóú',
          'recipe_中文',
          'recipe_🍕🥘',
          'recipe_العربية',
        ];

        for (final recipeId in unicodeIds) {
          // Act & Assert - should not crash
          expect(
              () => permissionManager.setRecipeId(recipeId), returnsNormally);
          expect(
              () => permissionManager.canEditRecipe(recipeId), returnsNormally);
        }
      });

      test('should handle permission service edge cases gracefully', () {
        // Arrange - test with extreme values that might cause issues
        final extremeIds = ['', '   ', 'very_long_id_${'x' * 1000}'];

        for (final extremeId in extremeIds) {
          // Act & Assert - should not crash with extreme values
          expect(() => permissionManager.canEditRecipe(extremeId),
              returnsNormally);
          expect(() => permissionManager.canInviteMembers(extremeId),
              returnsNormally);
          expect(() => permissionManager.canManageMembers(extremeId),
              returnsNormally);
        }
      });

      test('should maintain state consistency across operations', () {
        // Arrange & Act - perform multiple state changes
        permissionManager.setRecipeId(testRecipeId);
        final canEdit1 = permissionManager.canEdit;
        final canShare1 = permissionManager.canShare;

        permissionManager.setRecipeId(null);
        final canEdit2 = permissionManager.canEdit;
        final canShare2 = permissionManager.canShare;

        permissionManager.setRecipeId(testRecipeId);
        final canEdit3 = permissionManager.canEdit;
        final canShare3 = permissionManager.canShare;

        // Assert - state should be consistent for same conditions
        expect(
            canEdit1,
            equals(
                canEdit3)); // Same recipe ID should give same edit permission
        expect(
            canShare1,
            equals(
                canShare3)); // Same recipe ID should give same share permission
        expect(canEdit2,
            isTrue); // Null recipe ID should allow editing (new recipe)
        expect(canShare2, isFalse); // Null recipe ID should not allow sharing
      });
    });

    group('Integration Scenarios', () {
      test('should handle complete permission workflow for new recipe', () {
        // Act & Assert - Complete workflow for new recipe

        // 1. Start with new recipe (null ID)
        permissionManager.setRecipeId(null);
        expect(permissionManager.canEdit, isTrue);
        expect(permissionManager.canView, isTrue);
        expect(permissionManager.isOwner, isTrue);
        expect(permissionManager.canShare, isFalse);
        expect(permissionManager.canInvite, isFalse);
        expect(permissionManager.canDelete, isFalse);

        // 2. Save recipe (gets an ID)
        permissionManager.setRecipeId(testRecipeId);
        expect(permissionManager.canEdit, isTrue);
        expect(permissionManager.canView, isTrue);
        expect(permissionManager.isOwner, isTrue);
        expect(permissionManager.canShare, isTrue);
        expect(permissionManager.canInvite, isTrue);
        expect(permissionManager.canDelete, isTrue);

        // 3. Perform operations
        expect(permissionManager.canPerformAction('edit'), isTrue);
        expect(permissionManager.canEditField('title'), isTrue);
        expect(
            permissionManager.updateUserPermission(
                testRecipeId, testUserId, 'editor'),
            isTrue);
        expect(
            permissionManager.shareRecipeWithUser(
                testRecipeId, testUserId, 'viewer'),
            isTrue);
      });

      test(
          'should handle complete permission workflow for existing recipe as owner',
          () {
        // Arrange
        permissionManager.setRecipeId(testRecipeId);

        // Act & Assert - Complete workflow as owner
        expect(permissionManager.canEdit, isTrue);
        expect(permissionManager.canView, isTrue);
        expect(permissionManager.canShare, isTrue);
        expect(permissionManager.canInvite, isTrue);
        expect(permissionManager.canDelete, isTrue);
        expect(permissionManager.isOwner, isTrue);
        expect(permissionManager.hasPermissions, isTrue);
        expect(permissionManager.canManageMembers(testRecipeId), isTrue);
        expect(permissionManager.canEditRecipe(testRecipeId), isTrue);
        expect(permissionManager.canInviteMembers(testRecipeId), isTrue);
      });

      test(
          'should handle complete permission workflow for existing recipe as editor',
          () {
        // Arrange - configure as editor (not owner)
        mockPermissionService.setPermissionState(
          currentUserId: 'editor_user',
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.editor: true,
              ResourcePermission.viewer: true,
              ResourcePermission.owner: false,
            }
          },
        );
        permissionManager.setRecipeId(testRecipeId);

        // Act & Assert - Complete workflow as editor
        expect(permissionManager.canEdit, isTrue);
        expect(permissionManager.canView, isTrue);
        expect(permissionManager.canShare, isFalse); // Not owner
        expect(permissionManager.canInvite, isTrue); // Editors can invite
        expect(permissionManager.canDelete, isFalse); // Not owner
        expect(permissionManager.isOwner, isFalse);
        expect(permissionManager.hasPermissions, isTrue);
        expect(permissionManager.canManageMembers(testRecipeId),
            isFalse); // Not owner
        expect(permissionManager.canEditRecipe(testRecipeId), isTrue);
        expect(permissionManager.canInviteMembers(testRecipeId),
            isTrue); // Editors can invite
        expect(
            permissionManager.updateUserPermission(
                testRecipeId, testUserId, 'viewer'),
            isFalse); // Not owner
      });

      test(
          'should handle complete permission workflow for existing recipe as viewer',
          () {
        // Arrange - configure as viewer only
        mockPermissionService.setPermissionState(
          currentUserId: 'viewer_user',
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
              ResourcePermission.owner: false,
            }
          },
        );
        permissionManager.setRecipeId(testRecipeId);

        // Act & Assert - Complete workflow as viewer
        expect(permissionManager.canEdit, isFalse);
        expect(permissionManager.canView, isTrue);
        expect(permissionManager.canShare, isFalse);
        expect(permissionManager.canInvite, isFalse);
        expect(permissionManager.canDelete, isFalse);
        expect(permissionManager.isOwner, isFalse);
        expect(permissionManager.hasPermissions, isTrue);
        expect(permissionManager.canManageMembers(testRecipeId), isFalse);
        expect(permissionManager.canEditRecipe(testRecipeId), isFalse);
        expect(permissionManager.canInviteMembers(testRecipeId), isFalse);
        expect(
            permissionManager.updateUserPermission(
                testRecipeId, testUserId, 'viewer'),
            isFalse);
      });

      test('should handle permission changes during recipe lifecycle', () {
        // Start as owner
        permissionManager.setRecipeId(testRecipeId);
        expect(permissionManager.canEdit, isTrue);
        expect(permissionManager.canDelete, isTrue);

        // Simulate permission change to editor
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.editor: true,
              ResourcePermission.owner: false,
            }
          },
        );

        // Should reflect new permissions
        expect(permissionManager.canEdit, isTrue);
        expect(permissionManager.canDelete, isFalse); // No longer owner
        expect(permissionManager.canShare, isFalse); // No longer owner

        // Simulate permission change to viewer
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testRecipeId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
              ResourcePermission.owner: false,
            }
          },
        );

        // Should reflect viewer permissions
        expect(permissionManager.canEdit, isFalse);
        expect(permissionManager.canView, isTrue);
        expect(permissionManager.canDelete, isFalse);
        expect(permissionManager.canShare, isFalse);
      });
    });
  });
}
