/// Unit tests for SocialRecipePermissionService - Handles recipe permission validation
///
/// Tests permission operations including:
/// - Edit permission checks
/// - Member management permission checks
/// - View permission checks
/// - Permission level queries
/// - Guest and invite settings
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_permission_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

// Test infrastructure
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('SocialRecipePermissionService', () {
    late SocialRecipePermissionService permissionService;
    late Map<String, Recipe> recipeStorage;

    setUpAll(() {
      // Register fallback values
      registerFallbackValue(ResourcePermission.viewer);
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Reset test state
      recipeStorage = {};

      // Create test recipes
      const ownerId = 'owner-123';
      const editorId = 'editor-456';
      const viewerId = 'viewer-789';
      const adminId = 'admin-111';

      // Personal recipe
      final personalRecipe = RecipeFactory.buildPersonal(
        id: 'personal-recipe-1',
        title: 'Personal Recipe',
        createdBy: ownerId,
      );

      // Collaborative recipe with various permissions
      final collaborativeRecipe = Recipe(
        core: RecipeCore(
          id: 'collab-recipe-1',
          title: 'Collaborative Recipe',
          description: 'A shared recipe',
          ingredients: ['Ingredient 1'],
          instructions: ['Step 1'],
          mealType: 'Dinner',
          createdBy: ownerId,
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: ownerId,
          ownerDisplayName: 'Recipe Owner',
          memberPermissions: {
            ownerId: ResourcePermission.admin,
            adminId: ResourcePermission.admin,
            editorId: ResourcePermission.editor,
            viewerId: ResourcePermission.viewer,
          },
          allowGuestViewing: false,
          allowMemberInvites: true,
        ),
      );

      // Collaborative recipe with guest viewing
      final publicCollabRecipe = Recipe(
        core: RecipeCore(
          id: 'public-collab-1',
          title: 'Public Collaborative Recipe',
          description: 'A publicly viewable recipe',
          ingredients: ['Ingredient 1'],
          instructions: ['Step 1'],
          mealType: 'Lunch',
          createdBy: ownerId,
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: ownerId,
          ownerDisplayName: 'Recipe Owner',
          memberPermissions: {
            ownerId: ResourcePermission.admin,
            editorId: ResourcePermission.editor,
          },
          allowGuestViewing: true,
          allowMemberInvites: false,
        ),
      );

      recipeStorage['personal-recipe-1'] = personalRecipe;
      recipeStorage['collab-recipe-1'] = collaborativeRecipe;
      recipeStorage['public-collab-1'] = publicCollabRecipe;

      // Create service
      permissionService = SocialRecipePermissionService(
        getRecipe: (id) async => recipeStorage[id],
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Edit Permissions', () {
      test('should allow owner to edit personal recipe', () async {
        // Act
        final canEdit = await permissionService.canEditRecipe(
            'personal-recipe-1', 'owner-123');

        // Assert
        expect(canEdit, isTrue);
      });

      test('should deny non-owner to edit personal recipe', () async {
        // Act
        final canEdit = await permissionService.canEditRecipe(
            'personal-recipe-1', 'other-user');

        // Assert
        expect(canEdit, isFalse);
      });

      test('should allow admin to edit collaborative recipe', () async {
        // Act
        final ownerCanEdit = await permissionService.canEditRecipe(
            'collab-recipe-1', 'owner-123');
        final adminCanEdit = await permissionService.canEditRecipe(
            'collab-recipe-1', 'admin-111');

        // Assert
        expect(ownerCanEdit, isTrue);
        expect(adminCanEdit, isTrue);
      });

      test('should allow editor to edit collaborative recipe', () async {
        // Act
        final canEdit = await permissionService.canEditRecipe(
            'collab-recipe-1', 'editor-456');

        // Assert
        expect(canEdit, isTrue);
      });

      test('should deny viewer to edit collaborative recipe', () async {
        // Act
        final canEdit = await permissionService.canEditRecipe(
            'collab-recipe-1', 'viewer-789');

        // Assert
        expect(canEdit, isFalse);
      });

      test('should deny non-member to edit collaborative recipe', () async {
        // Act
        final canEdit = await permissionService.canEditRecipe(
            'collab-recipe-1', 'non-member-999');

        // Assert
        expect(canEdit, isFalse);
      });

      test('should return false for non-existent recipe', () async {
        // Act
        final canEdit =
            await permissionService.canEditRecipe('non-existent', 'owner-123');

        // Assert
        expect(canEdit, isFalse);
      });
    });

    group('Member Management Permissions', () {
      test('should allow owner to manage members', () async {
        // Act
        final canManage = await permissionService.canManageRecipeMembers(
            'collab-recipe-1', 'owner-123');

        // Assert
        expect(canManage, isTrue);
      });

      test('should allow admin to manage members', () async {
        // Act
        final canManage = await permissionService.canManageRecipeMembers(
            'collab-recipe-1', 'admin-111');

        // Assert
        expect(canManage, isTrue);
      });

      test('should deny editor to manage members', () async {
        // Act
        final canManage = await permissionService.canManageRecipeMembers(
            'collab-recipe-1', 'editor-456');

        // Assert
        expect(canManage, isFalse);
      });

      test('should deny viewer to manage members', () async {
        // Act
        final canManage = await permissionService.canManageRecipeMembers(
            'collab-recipe-1', 'viewer-789');

        // Assert
        expect(canManage, isFalse);
      });

      test('should return false for personal recipe', () async {
        // Act
        final canManage = await permissionService.canManageRecipeMembers(
            'personal-recipe-1', 'owner-123');

        // Assert
        expect(canManage, isFalse);
      });
    });

    group('View Permissions', () {
      test('should allow owner to view personal recipe', () async {
        // Act
        final canView = await permissionService.canViewRecipe(
            'personal-recipe-1', 'owner-123');

        // Assert
        expect(canView, isTrue);
      });

      test('should deny non-owner to view personal recipe', () async {
        // Act
        final canView = await permissionService.canViewRecipe(
            'personal-recipe-1', 'other-user');

        // Assert
        expect(canView, isFalse);
      });

      test('should allow all members to view collaborative recipe', () async {
        // Act
        final ownerCanView = await permissionService.canViewRecipe(
            'collab-recipe-1', 'owner-123');
        final adminCanView = await permissionService.canViewRecipe(
            'collab-recipe-1', 'admin-111');
        final editorCanView = await permissionService.canViewRecipe(
            'collab-recipe-1', 'editor-456');
        final viewerCanView = await permissionService.canViewRecipe(
            'collab-recipe-1', 'viewer-789');

        // Assert
        expect(ownerCanView, isTrue);
        expect(adminCanView, isTrue);
        expect(editorCanView, isTrue);
        expect(viewerCanView, isTrue);
      });

      test('should deny non-member to view private collaborative recipe',
          () async {
        // Act
        final canView = await permissionService.canViewRecipe(
            'collab-recipe-1', 'non-member-999');

        // Assert
        expect(canView, isFalse);
      });

      test('should allow guest to view public collaborative recipe', () async {
        // Act
        final canView = await permissionService.canViewRecipe(
            'public-collab-1', 'guest-user');

        // Assert
        expect(canView, isTrue);
      });
    });

    group('Permission Level Queries', () {
      test('should return correct permission level for owner', () async {
        // Act
        final permission = await permissionService.getUserPermissionForRecipe(
            'collab-recipe-1', 'owner-123');

        // Assert
        expect(permission, equals(ResourcePermission.admin));
      });

      test('should return correct permission level for admin', () async {
        // Act
        final permission = await permissionService.getUserPermissionForRecipe(
            'collab-recipe-1', 'admin-111');

        // Assert
        expect(permission, equals(ResourcePermission.admin));
      });

      test('should return correct permission level for editor', () async {
        // Act
        final permission = await permissionService.getUserPermissionForRecipe(
            'collab-recipe-1', 'editor-456');

        // Assert
        expect(permission, equals(ResourcePermission.editor));
      });

      test('should return correct permission level for viewer', () async {
        // Act
        final permission = await permissionService.getUserPermissionForRecipe(
            'collab-recipe-1', 'viewer-789');

        // Assert
        expect(permission, equals(ResourcePermission.viewer));
      });

      test('should return null for non-member', () async {
        // Act
        final permission = await permissionService.getUserPermissionForRecipe(
            'collab-recipe-1', 'non-member-999');

        // Assert
        expect(permission, isNull);
      });

      test('should return admin for personal recipe owner', () async {
        // Act
        final permission = await permissionService.getUserPermissionForRecipe(
            'personal-recipe-1', 'owner-123');

        // Assert
        expect(permission, equals(ResourcePermission.admin));
      });

      test('should return null for non-owner of personal recipe', () async {
        // Act
        final permission = await permissionService.getUserPermissionForRecipe(
            'personal-recipe-1', 'other-user');

        // Assert
        expect(permission, isNull);
      });
    });

    group('Admin Permission Checks', () {
      test('should confirm owner has admin permission', () async {
        // Act
        final hasAdmin = await permissionService.hasAdminPermission(
            'collab-recipe-1', 'owner-123');

        // Assert
        expect(hasAdmin, isTrue);
      });

      test('should confirm admin user has admin permission', () async {
        // Act
        final hasAdmin = await permissionService.hasAdminPermission(
            'collab-recipe-1', 'admin-111');

        // Assert
        expect(hasAdmin, isTrue);
      });

      test('should deny editor has admin permission', () async {
        // Act
        final hasAdmin = await permissionService.hasAdminPermission(
            'collab-recipe-1', 'editor-456');

        // Assert
        expect(hasAdmin, isFalse);
      });

      test('should deny viewer has admin permission', () async {
        // Act
        final hasAdmin = await permissionService.hasAdminPermission(
            'collab-recipe-1', 'viewer-789');

        // Assert
        expect(hasAdmin, isFalse);
      });
    });

    group('Share Permissions', () {
      test('should allow owner to share recipe', () async {
        // Act
        final canShare = await permissionService.canShareRecipe(
            'collab-recipe-1', 'owner-123');

        // Assert
        expect(canShare, isTrue);
      });

      test('should allow admin to share when member invites allowed', () async {
        // Act
        final canShare = await permissionService.canShareRecipe(
            'collab-recipe-1', 'admin-111');

        // Assert
        expect(canShare, isTrue);
      });

      test('should allow editor to share when member invites allowed',
          () async {
        // Act
        final canShare = await permissionService.canShareRecipe(
            'collab-recipe-1', 'editor-456');

        // Assert
        expect(canShare, isTrue);
      });

      test('should deny viewer to share recipe', () async {
        // Act
        final canShare = await permissionService.canShareRecipe(
            'collab-recipe-1', 'viewer-789');

        // Assert
        expect(canShare, isFalse);
      });

      test('should deny sharing when member invites disabled', () async {
        // Act
        final canShare = await permissionService.canShareRecipe(
            'public-collab-1', 'editor-456');

        // Assert
        expect(canShare, isFalse);
      });

      test('should always allow owner to share even when invites disabled',
          () async {
        // Act
        final canShare = await permissionService.canShareRecipe(
            'public-collab-1', 'owner-123');

        // Assert
        expect(canShare, isTrue);
      });
    });

    group('Users With Permission Queries', () {
      test('should return all users with admin permission', () async {
        // Act
        final admins = await permissionService.getUsersWithPermission(
            'collab-recipe-1', ResourcePermission.admin);

        // Assert
        expect(admins, isNotEmpty);
        expect(admins.length, equals(2)); // Owner and admin
        expect(admins, contains('owner-123'));
        expect(admins, contains('admin-111'));
      });

      test('should return all users with editor permission', () async {
        // Act
        final editors = await permissionService.getUsersWithPermission(
            'collab-recipe-1', ResourcePermission.editor);

        // Assert
        expect(editors, isNotEmpty);
        expect(editors.length, equals(1));
        expect(editors, contains('editor-456'));
      });

      test('should return all users with viewer permission', () async {
        // Act
        final viewers = await permissionService.getUsersWithPermission(
            'collab-recipe-1', ResourcePermission.viewer);

        // Assert
        expect(viewers, isNotEmpty);
        expect(viewers.length, equals(1));
        expect(viewers, contains('viewer-789'));
      });

      test('should return empty list for personal recipe', () async {
        // Act
        final users = await permissionService.getUsersWithPermission(
            'personal-recipe-1', ResourcePermission.admin);

        // Assert
        expect(users, isEmpty);
      });

      test('should return empty list for non-existent recipe', () async {
        // Act
        final users = await permissionService.getUsersWithPermission(
            'non-existent', ResourcePermission.admin);

        // Assert
        expect(users, isEmpty);
      });
    });

    group('Guest and Invite Settings', () {
      test('should check guest viewing correctly', () async {
        // Act
        final allowsGuest1 =
            await permissionService.allowsGuestViewing('collab-recipe-1');
        final allowsGuest2 =
            await permissionService.allowsGuestViewing('public-collab-1');

        // Assert
        expect(allowsGuest1, isFalse);
        expect(allowsGuest2, isTrue);
      });

      test('should check member invites correctly', () async {
        // Act
        final allowsInvites1 =
            await permissionService.allowsMemberInvites('collab-recipe-1');
        final allowsInvites2 =
            await permissionService.allowsMemberInvites('public-collab-1');

        // Assert
        expect(allowsInvites1, isTrue);
        expect(allowsInvites2, isFalse);
      });

      test('should return false for personal recipe guest viewing', () async {
        // Act
        final allowsGuest =
            await permissionService.allowsGuestViewing('personal-recipe-1');

        // Assert
        expect(allowsGuest, isFalse);
      });

      test('should return false for personal recipe member invites', () async {
        // Act
        final allowsInvites =
            await permissionService.allowsMemberInvites('personal-recipe-1');

        // Assert
        expect(allowsInvites, isFalse);
      });

      test('should return false for non-existent recipe', () async {
        // Act
        final allowsGuest =
            await permissionService.allowsGuestViewing('non-existent');
        final allowsInvites =
            await permissionService.allowsMemberInvites('non-existent');

        // Assert
        expect(allowsGuest, isFalse);
        expect(allowsInvites, isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle recipe not found gracefully', () async {
        // Act
        final canEdit =
            await permissionService.canEditRecipe('non-existent', 'user-123');
        final canManage = await permissionService.canManageRecipeMembers(
            'non-existent', 'user-123');
        final canView =
            await permissionService.canViewRecipe('non-existent', 'user-123');
        final permission = await permissionService.getUserPermissionForRecipe(
            'non-existent', 'user-123');
        final hasAdmin = await permissionService.hasAdminPermission(
            'non-existent', 'user-123');
        final canShare =
            await permissionService.canShareRecipe('non-existent', 'user-123');

        // Assert
        expect(canEdit, isFalse);
        expect(canManage, isFalse);
        expect(canView, isFalse);
        expect(permission, isNull);
        expect(hasAdmin, isFalse);
        expect(canShare, isFalse);
      });

      test('should handle exceptions in getRecipe', () async {
        // Arrange
        final errorService = SocialRecipePermissionService(
          getRecipe: (id) async => throw Exception('Database error'),
        );

        // Act
        final canEdit =
            await errorService.canEditRecipe('recipe-1', 'user-123');
        final canManage =
            await errorService.canManageRecipeMembers('recipe-1', 'user-123');
        final canView =
            await errorService.canViewRecipe('recipe-1', 'user-123');
        final permission = await errorService.getUserPermissionForRecipe(
            'recipe-1', 'user-123');
        final hasAdmin =
            await errorService.hasAdminPermission('recipe-1', 'user-123');
        final canShare =
            await errorService.canShareRecipe('recipe-1', 'user-123');
        final users = await errorService.getUsersWithPermission(
            'recipe-1', ResourcePermission.admin);
        final allowsGuest = await errorService.allowsGuestViewing('recipe-1');
        final allowsInvites =
            await errorService.allowsMemberInvites('recipe-1');

        // Assert - All should return safe defaults
        expect(canEdit, isFalse);
        expect(canManage, isFalse);
        expect(canView, isFalse);
        expect(permission, isNull);
        expect(hasAdmin, isFalse);
        expect(canShare, isFalse);
        expect(users, isEmpty);
        expect(allowsGuest, isFalse);
        expect(allowsInvites, isFalse);
      });
    });
  });
}
