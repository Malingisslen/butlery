// test/unit/services/unified/operations/modules/recipe_member_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/recipe_member_manager.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('RecipeMemberManager', () {
    late MockUnifiedRecipeService mockParentService;
    late MockNotificationService mockNotificationService;
    late RecipeMemberManager memberManager;
    late Recipe testCollaborativeRecipe;
    late Recipe testPersonalRecipe;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(NotificationStrategy.recipeShared);
      registerFallbackValue(ResourcePermission.viewer);
      registerFallbackValue(Recipe(
        core: RecipeCore(
          id: 'test',
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks
      mockParentService = MockUnifiedRecipeService();
      mockNotificationService = MockNotificationService();

      // Create member manager instance
      memberManager =
          RecipeMemberManager(mockParentService, mockNotificationService);

      // Create test data
      testCollaborativeRecipe = Recipe(
        core: RecipeCore(
          id: 'collab_1',
          title: 'Team Recipe',
          description: 'A collaborative recipe',
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
          ownerDisplayName: 'Recipe Owner',
          memberPermissions: {
            'user_456': ResourcePermission.editor,
            'user_789': ResourcePermission.viewer,
          },
          allowGuestViewing: false,
          allowMemberInvites: true,
        ),
      );

      testPersonalRecipe = Recipe(
        core: RecipeCore(
          id: 'personal_1',
          title: 'Personal Recipe',
          description: 'A personal recipe',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
          mealType: 'Middag',
          createdBy: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
      );

      // Configure mocks
      when(() => mockParentService.currentUserId).thenReturn('user_123');
      when(() => mockParentService.currentUserDisplayName)
          .thenReturn('Current User');
      when(() => mockParentService.recipes).thenReturn([
        testCollaborativeRecipe,
        testPersonalRecipe,
      ]);
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Member Addition', () {
      test('should add new member successfully', () async {
        // Arrange
        when(() => mockParentService.updateRecipe(any()))
            .thenAnswer((_) async => true);
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenAnswer((_) async {});

        // Act
        final success = await memberManager.addMember(
          recipeId: 'collab_1',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
          permission: ResourcePermission.editor,
        );

        // Assert
        expect(success, isTrue);

        final captured =
            verify(() => mockParentService.updateRecipe(captureAny())).captured;
        final updatedRecipe = captured.first as Recipe;
        expect(updatedRecipe.socialData?.memberPermissions?['user_999'],
            equals(ResourcePermission.editor));

        verify(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: ['user_999'],
              strategy: NotificationStrategy.recipeShared,
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).called(1);
      });

      test('should use default viewer permission when not specified', () async {
        // Arrange
        when(() => mockParentService.updateRecipe(any()))
            .thenAnswer((_) async => true);
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenAnswer((_) async {});

        // Act
        final success = await memberManager.addMember(
          recipeId: 'collab_1',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
        );

        // Assert
        expect(success, isTrue);

        final captured =
            verify(() => mockParentService.updateRecipe(captureAny())).captured;
        final updatedRecipe = captured.first as Recipe;
        expect(updatedRecipe.socialData?.memberPermissions?['user_999'],
            equals(ResourcePermission.viewer));
      });

      test('should fail when recipe not found', () async {
        // Act
        final success = await memberManager.addMember(
          recipeId: 'nonexistent',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
        );

        // Assert
        expect(success, isFalse);
        verifyNever(() => mockParentService.updateRecipe(any()));
      });

      test('should fail when recipe not collaborative', () async {
        // Act
        final success = await memberManager.addMember(
          recipeId: 'personal_1',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
        );

        // Assert
        expect(success, isFalse);
      });

      test('should fail when member already exists', () async {
        // Act
        final success = await memberManager.addMember(
          recipeId: 'collab_1',
          memberId: 'user_456', // Already a member
          memberDisplayName: 'Existing Member',
        );

        // Assert
        expect(success, isFalse);
      });

      test('should fail when user lacks permission to invite', () async {
        // Arrange
        when(() => mockParentService.currentUserId)
            .thenReturn('user_789'); // Viewer

        // Act
        final success = await memberManager.addMember(
          recipeId: 'collab_1',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
        );

        // Assert
        expect(success, isFalse);
      });
    });

    group('Member Removal', () {
      test('should remove member successfully', () async {
        // Arrange
        when(() => mockParentService.updateRecipe(any()))
            .thenAnswer((_) async => true);
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenAnswer((_) async {});

        // Act
        final success = await memberManager.removeMember(
          recipeId: 'collab_1',
          memberId: 'user_456',
        );

        // Assert
        expect(success, isTrue);

        final captured =
            verify(() => mockParentService.updateRecipe(captureAny())).captured;
        final updatedRecipe = captured.first as Recipe;
        expect(
            updatedRecipe.socialData?.memberPermissions
                ?.containsKey('user_456'),
            isFalse);

        verify(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: ['user_456'],
              strategy:
                  NotificationStrategy.recipeShared, // Using available strategy
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).called(1);
      });

      test('should prevent owner from being removed', () async {
        // Arrange
        final recipeWithOwnerInMembers = Recipe(
          core: testCollaborativeRecipe.core,
          type: testCollaborativeRecipe.type,
          socialData: RecipeSocialData(
            ownerId: 'user_123',
            ownerDisplayName: 'Owner',
            memberPermissions: {
              'user_123': ResourcePermission.owner, // Owner in members
              'user_456': ResourcePermission.editor,
            },
          ),
        );

        when(() => mockParentService.recipes)
            .thenReturn([recipeWithOwnerInMembers]);

        // Act
        final success = await memberManager.removeMember(
          recipeId: 'collab_1',
          memberId: 'user_123',
        );

        // Assert
        expect(success, isFalse);
      });

      test('should fail when member not found', () async {
        // Act
        final success = await memberManager.removeMember(
          recipeId: 'collab_1',
          memberId: 'user_999', // Not a member
        );

        // Assert
        expect(success, isFalse);
      });
    });

    group('Permission Updates', () {
      test('should update member permission successfully', () async {
        // Arrange
        when(() => mockParentService.updateRecipe(any()))
            .thenAnswer((_) async => true);
        when(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).thenAnswer((_) async {});

        // Act
        final success = await memberManager.updateMemberPermission(
          recipeId: 'collab_1',
          memberId: 'user_789',
          newPermission: ResourcePermission.editor,
        );

        // Assert
        expect(success, isTrue);

        final captured =
            verify(() => mockParentService.updateRecipe(captureAny())).captured;
        final updatedRecipe = captured.first as Recipe;
        expect(updatedRecipe.socialData?.memberPermissions?['user_789'],
            equals(ResourcePermission.editor));

        verify(() => mockNotificationService.sendBatchableNotification(
              targetUserIds: ['user_789'],
              strategy:
                  NotificationStrategy.recipeShared, // Using available strategy
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
            )).called(1);
      });

      test('should prevent changing owner permission', () async {
        // Arrange
        final recipeWithOwnerInMembers = Recipe(
          core: testCollaborativeRecipe.core,
          type: testCollaborativeRecipe.type,
          socialData: RecipeSocialData(
            ownerId: 'user_123',
            ownerDisplayName: 'Owner',
            memberPermissions: {
              'user_123': ResourcePermission.owner,
              'user_456': ResourcePermission.editor,
            },
          ),
        );

        when(() => mockParentService.recipes)
            .thenReturn([recipeWithOwnerInMembers]);

        // Act
        final success = await memberManager.updateMemberPermission(
          recipeId: 'collab_1',
          memberId: 'user_123',
          newPermission: ResourcePermission.editor,
        );

        // Assert
        expect(success, isFalse);
      });

      test('should fail when user lacks permission', () async {
        // Arrange
        when(() => mockParentService.currentUserId)
            .thenReturn('user_456'); // Editor

        // Act
        final success = await memberManager.updateMemberPermission(
          recipeId: 'collab_1',
          memberId: 'user_789',
          newPermission: ResourcePermission.admin,
        );

        // Assert
        expect(success, isFalse);
      });
    });

    group('Member Queries', () {
      test('should get all members', () async {
        // Act
        final members = await memberManager.getRecipeMembers('collab_1');

        // Assert
        expect(members.length, equals(3)); // Owner + 2 members
        expect(members.any((m) => m['userId'] == 'user_123'), isTrue);
        expect(members.any((m) => m['userId'] == 'user_456'), isTrue);
        expect(members.any((m) => m['userId'] == 'user_789'), isTrue);
      });

      test('should get member statistics', () async {
        // Act
        final stats = memberManager.getMemberStatistics('collab_1');

        // Assert
        expect(stats['totalMembers'], equals(3)); // Owner + 2 members
        expect(stats['editors'], equals(1));
        expect(stats['viewers'], equals(1));
      });
    });

    group('Invitation Management', () {
      test('should check if current user can invite members', () async {
        // Act - Method checks current user permissions
        final canInvite = memberManager.canInviteMembers('collab_1');

        // Assert
        expect(canInvite, isTrue); // Current user is owner
      });

      test('should respect invitation settings', () async {
        // Arrange
        final restrictedRecipe = Recipe(
          core: testCollaborativeRecipe.core,
          type: testCollaborativeRecipe.type,
          socialData: RecipeSocialData(
            ownerId: 'user_456', // Different owner
            ownerDisplayName: 'Other Owner',
            memberPermissions: {
              'user_123': ResourcePermission.viewer, // Current user is viewer
            },
            allowMemberInvites: false, // Disabled
          ),
        );

        when(() => mockParentService.recipes).thenReturn([restrictedRecipe]);

        // Act
        final canInvite = memberManager.canInviteMembers('collab_1');

        // Assert
        expect(canInvite, isFalse);
      });
    });

    // Bulk operations are not implemented in the actual RecipeMemberManager class
  });
}
