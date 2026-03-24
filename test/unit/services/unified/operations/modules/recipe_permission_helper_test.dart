// test/unit/services/unified/operations/modules/recipe_permission_helper_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
// RecipeSocialData is part of recipe_unified.dart, already imported
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RecipePermissionHelper', () {
    late MockUnifiedRecipeService mockParentService;
    late RecipePermissionHelper helper;
    late Recipe testPersonalRecipe;
    late Recipe testCollaborativeRecipe;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(ResourcePermission.read);
      registerFallbackValue(RecipeBuilder().build());
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mock parent service
      mockParentService = MockUnifiedRecipeService();

      // Create helper instance
      helper = RecipePermissionHelper(
        getCurrentUserId: () => mockParentService.currentUserId,
      );

      // Create test data
      testPersonalRecipe = Recipe(
        core: RecipeCore(
          id: 'personal_recipe_1',
          title: 'Test Personal Recipe',
          description: 'A test personal recipe',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
          mealType: 'Middag',
          createdBy: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          memberPermissions: {},
        ),
      );

      testCollaborativeRecipe = Recipe(
        core: RecipeCore(
          id: 'collab_recipe_1',
          title: 'Test Collaborative Recipe',
          description: 'A test collaborative recipe',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
          mealType: 'Middag',
          createdBy: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          memberPermissions: {
            'user_123': ResourcePermission.owner,
            'user_456': ResourcePermission.editor,
            'user_789': ResourcePermission.viewer,
            'user_admin': ResourcePermission.admin,
          },
          allowMemberInvites: true,
          allowGuestViewing: false,
        ),
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('View Permissions', () {
      test('should allow owner to view their personal recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_123');

        // Act
        final canView = helper.canViewRecipe(testPersonalRecipe);

        // Assert
        expect(canView, isTrue);
      });

      test('should not allow others to view personal recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act
        final canView = helper.canViewRecipe(testPersonalRecipe);

        // Assert
        expect(canView, isFalse);
      });

      test('should allow members to view collaborative recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act
        final canView = helper.canViewRecipe(testCollaborativeRecipe);

        // Assert
        expect(canView, isTrue);
      });

      test('should not allow non-members to view collaborative recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_999');

        // Act
        final canView = helper.canViewRecipe(testCollaborativeRecipe);

        // Assert
        expect(canView, isFalse);
      });

      test('should return false when user is not authenticated', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: null);

        // Act
        final canView = helper.canViewRecipe(testCollaborativeRecipe);

        // Assert
        expect(canView, isFalse);
      });
    });

    group('Edit Permissions', () {
      test('should allow owner to edit their recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_123');

        // Act
        final canEdit = helper.canEditRecipe(testCollaborativeRecipe);

        // Assert
        expect(canEdit, isTrue);
      });

      test('should allow editor to edit collaborative recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act
        final canEdit = helper.canEditRecipe(testCollaborativeRecipe);

        // Assert
        expect(canEdit, isTrue);
      });

      test('should allow admin to edit collaborative recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_admin');

        // Act
        final canEdit = helper.canEditRecipe(testCollaborativeRecipe);

        // Assert
        expect(canEdit, isTrue);
      });

      test('should not allow viewer to edit collaborative recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_789');

        // Act
        final canEdit = helper.canEditRecipe(testCollaborativeRecipe);

        // Assert
        expect(canEdit, isFalse);
      });
    });

    group('Delete Permissions', () {
      test('should only allow owner to delete recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_123');

        // Act
        final canDelete = helper.canDeleteRecipe(testCollaborativeRecipe);

        // Assert
        expect(canDelete, isTrue);
      });

      test('should not allow admin to delete recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_admin');

        // Act
        final canDelete = helper.canDeleteRecipe(testCollaborativeRecipe);

        // Assert
        expect(canDelete, isFalse);
      });
    });

    group('Member Management Permissions', () {
      test('should allow owner to manage members', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_123');

        // Act
        final canManage = helper.canManageMembers(testCollaborativeRecipe);

        // Assert
        expect(canManage, isTrue);
      });

      test('should allow admin to manage members', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_admin');

        // Act
        final canManage = helper.canManageMembers(testCollaborativeRecipe);

        // Assert
        expect(canManage, isTrue);
      });

      test('should not allow editor to manage members', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act
        final canManage = helper.canManageMembers(testCollaborativeRecipe);

        // Assert
        expect(canManage, isFalse);
      });

      test('should return false for personal recipes', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_123');

        // Act
        final canManage = helper.canManageMembers(testPersonalRecipe);

        // Assert
        expect(canManage, isFalse);
      });
    });

    group('Invitation Permissions', () {
      test('should allow owner to invite members', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_123');

        // Act
        final canInvite = helper.canInviteMembers(testCollaborativeRecipe);

        // Assert
        expect(canInvite, isTrue);
      });

      test('should allow editor to invite members when allowed', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act
        final canInvite = helper.canInviteMembers(testCollaborativeRecipe);

        // Assert
        expect(canInvite, isTrue);
      });

      test('should not allow invites when disabled', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');
        final restrictedRecipe = Recipe(
          core: RecipeCore(
            id: 'restricted_recipe',
            title: 'Restricted Recipe',
            description: 'A restricted recipe',
            ingredients: ['ingredient 1'],
            instructions: ['step 1'],
            mealType: 'Middag',
            createdBy: 'user_123',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            ownerId: 'user_123',
            memberPermissions: {'user_456': ResourcePermission.editor},
            allowMemberInvites: false,
          ),
        );

        // Act
        final canInvite = helper.canInviteMembers(restrictedRecipe);

        // Assert
        expect(canInvite, isFalse);
      });
    });

    group('Comment and Rating Permissions', () {
      test('should allow members to comment on collaborative recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act
        final canComment = helper.canCommentOnRecipe(testCollaborativeRecipe);

        // Assert
        expect(canComment, isTrue);
      });

      test('should only allow owner to comment on personal recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_123');

        // Act
        final canComment = helper.canCommentOnRecipe(testPersonalRecipe);

        // Assert
        expect(canComment, isTrue);
      });

      test('should allow members to rate but not owner', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act
        final canRate = helper.canRateRecipe(testCollaborativeRecipe);

        // Assert
        expect(canRate, isTrue);
      });

      test('should not allow owner to rate their own recipe', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_123');

        // Act
        final canRate = helper.canRateRecipe(testCollaborativeRecipe);

        // Assert
        expect(canRate, isFalse);
      });
    });

    group('Permission Level Determination', () {
      test('should return correct permission level for owner', () {
        // Act
        final permission =
            helper.getUserPermission(testCollaborativeRecipe, 'user_123');

        // Assert
        expect(permission, equals(ResourcePermission.owner));
      });

      test('should return correct permission level for editor', () {
        // Act
        final permission =
            helper.getUserPermission(testCollaborativeRecipe, 'user_456');

        // Assert
        expect(permission, equals(ResourcePermission.editor));
      });

      test('should return viewer permission for explicit viewer', () {
        // Act
        final permission =
            helper.getUserPermission(testCollaborativeRecipe, 'user_789');

        // Assert
        expect(permission, equals(ResourcePermission.viewer));
      });

      test('should check minimum permission correctly', () {
        // Act
        final hasEditor = helper.hasMinimumPermission(
            testCollaborativeRecipe, 'user_456', ResourcePermission.editor);
        final hasAdmin = helper.hasMinimumPermission(
            testCollaborativeRecipe, 'user_456', ResourcePermission.admin);

        // Assert
        expect(hasEditor, isTrue);
        expect(hasAdmin, isFalse);
      });
    });

    group('Legacy Compatibility', () {
      test('should map legacy actions correctly', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act & Assert
        expect(
            helper.checkLegacyPermission(
                testCollaborativeRecipe, 'user_456', 'view'),
            isTrue);
        expect(
            helper.checkLegacyPermission(
                testCollaborativeRecipe, 'user_456', 'edit'),
            isTrue);
        expect(
            helper.checkLegacyPermission(
                testCollaborativeRecipe, 'user_456', 'delete'),
            isFalse);
        expect(
            helper.checkLegacyPermission(
                testCollaborativeRecipe, 'user_456', 'comment'),
            isTrue);
      });

      test('should parse legacy permission strings', () {
        // Act & Assert
        expect(helper.parseLegacyPermission('owner'),
            equals(ResourcePermission.owner));
        expect(helper.parseLegacyPermission('admin'),
            equals(ResourcePermission.admin));
        expect(helper.parseLegacyPermission('editor'),
            equals(ResourcePermission.editor));
        expect(helper.parseLegacyPermission('viewer'),
            equals(ResourcePermission.viewer));
        expect(helper.parseLegacyPermission('unknown'),
            equals(ResourcePermission.read));
        expect(helper.parseLegacyPermission(null),
            equals(ResourcePermission.read));
      });
    });

    group('Permission Utilities', () {
      test('should get permission description in Swedish', () {
        // Act & Assert
        expect(helper.getPermissionDescription(ResourcePermission.owner),
            equals('Ägare av recept'));
        expect(helper.getPermissionDescription(ResourcePermission.admin),
            equals('Kan hantera medlemmar'));
        expect(helper.getPermissionDescription(ResourcePermission.editor),
            equals('Kan redigera recept'));
        expect(helper.getPermissionDescription(ResourcePermission.viewer),
            equals('Kan visa recept'));
        expect(helper.getPermissionDescription(ResourcePermission.read),
            equals('Ingen åtkomst'));
      });

      test('should get available actions for user', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act
        final actions =
            helper.getAvailableActions(testCollaborativeRecipe, 'user_456');

        // Assert
        expect(actions, contains('view'));
        expect(actions, contains('edit'));
        expect(actions, contains('comment'));
        expect(actions, contains('rate'));
        expect(actions, contains('invite'));
        expect(actions, isNot(contains('delete')));
        expect(actions, isNot(contains('manage_members')));
      });

      test('should check guest viewing permission', () {
        // Act
        final allowsGuest = helper.allowsGuestViewing(testCollaborativeRecipe);

        // Assert
        expect(allowsGuest, isFalse);
      });

      test('should generate permission summary', () {
        // Arrange
        mockParentService.setRecipeState(currentUserId: 'user_456');

        // Act
        final summary =
            helper.getPermissionSummary(testCollaborativeRecipe, 'user_456');

        // Assert
        expect(summary['user_id'], equals('user_456'));
        expect(summary['recipe_id'], equals('collab_recipe_1'));
        expect(summary['recipe_type'], equals('collaborative'));
        expect(summary['user_permission'], equals('editor'));
        expect(summary['is_owner'], isFalse);
        expect(summary['is_member'], isTrue);
        expect(summary['available_actions'], isA<List<String>>());
        expect(summary['allows_guest_viewing'], isFalse);
      });
    });

    group('Performance and Concurrency', () {
      test('should handle large permission matrix efficiently', () {
        // Arrange
        when(() => mockParentService.currentUserId).thenReturn('user_perf');

        // Create recipe with many members
        final largeRecipe = RecipeBuilder()
            .withId('large_1')
            .asCollaborative()
            .withSocialData(
              RecipeSocialData(
                ownerId: 'user_owner',
                memberPermissions: Map.fromEntries(
                  List.generate(
                      100,
                      (i) => MapEntry(
                          'user_$i',
                          i % 3 == 0
                              ? ResourcePermission.admin
                              : i % 2 == 0
                                  ? ResourcePermission.editor
                                  : ResourcePermission.viewer)),
                ),
              ),
            )
            .build();

        // Act
        final stopwatch = Stopwatch()..start();
        final permission = helper.getUserPermission(largeRecipe, 'user_50');
        helper.canEditRecipe(largeRecipe);
        helper.getPermissionSummary(largeRecipe, 'user_50');
        stopwatch.stop();

        // Assert
        expect(permission, isA<ResourcePermission>());
        expect(
            stopwatch.elapsedMilliseconds, lessThan(10)); // Should be very fast
      });

      test('should handle concurrent permission operations', () async {
        // Arrange
        when(() => mockParentService.currentUserId)
            .thenReturn('user_concurrent');

        // Act
        final operations = [
          Future(() => helper.canViewRecipe(testCollaborativeRecipe)),
          Future(() => helper.canEditRecipe(testCollaborativeRecipe)),
          Future(() => helper.canDeleteRecipe(testCollaborativeRecipe)),
          Future(() => helper.canManageMembers(testCollaborativeRecipe)),
          Future(() => helper.canInviteMembers(testCollaborativeRecipe)),
          Future(() => helper.getUserPermission(
              testCollaborativeRecipe, 'user_concurrent')),
        ];

        // Assert
        await expectLater(
          Future.wait(operations),
          completes,
        );
      });
    });
  });
}
