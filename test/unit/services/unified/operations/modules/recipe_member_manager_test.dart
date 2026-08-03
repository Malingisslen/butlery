/// Unit tests for RecipeMemberManager
///
/// Tests collaborative recipe membership management including
/// adding/removing members, permission updates, and member queries.
library;

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
      await BaseUnitTest.setupUnit();
      registerFallbackValue(NotificationStrategy.recipeShared);
      registerFallbackValue(ResourcePermission.viewer);
      registerFallbackValue(
        Recipe(
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
        ),
      );
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockParentService = MockUnifiedRecipeService();
      mockNotificationService = MockNotificationService();

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

      // Use setRecipeState instead of when() for concrete getters
      mockParentService.setRecipeState(
        currentUserId: 'user_123',
        currentUserDisplayName: 'Current User',
        recipes: [testCollaborativeRecipe, testPersonalRecipe],
      );

      memberManager = RecipeMemberManager(
        getCurrentUserId: () => mockParentService.currentUserId,
        getCurrentUserDisplayName: () =>
            mockParentService.currentUserDisplayName,
        getRecipes: () => mockParentService.recipes,
        updateRecipe: (recipe) => mockParentService.updateRecipe(recipe),
        notificationService: mockNotificationService,
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Member Addition', () {
      test('should add new member successfully', () async {
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});

        final success = await memberManager.addMember(
          recipeId: 'collab_1',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
          permission: ResourcePermission.editor,
        );

        expect(success, isTrue);
        final captured = verify(
          () => mockParentService.updateRecipe(captureAny()),
        ).captured;
        final updatedRecipe = captured.first as Recipe;
        expect(
          updatedRecipe.socialData?.memberPermissions?['user_999'],
          equals(ResourcePermission.editor),
        );
      });

      test('should use default viewer permission when not specified', () async {
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});

        final success = await memberManager.addMember(
          recipeId: 'collab_1',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
        );

        expect(success, isTrue);
        final captured = verify(
          () => mockParentService.updateRecipe(captureAny()),
        ).captured;
        final updatedRecipe = captured.first as Recipe;
        expect(
          updatedRecipe.socialData?.memberPermissions?['user_999'],
          equals(ResourcePermission.viewer),
        );
      });

      test('should fail when recipe not found', () async {
        final success = await memberManager.addMember(
          recipeId: 'nonexistent',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
        );
        expect(success, isFalse);
        verifyNever(() => mockParentService.updateRecipe(any()));
      });

      test('should fail when recipe not collaborative', () async {
        final success = await memberManager.addMember(
          recipeId: 'personal_1',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
        );
        expect(success, isFalse);
      });

      test('should fail when member already exists', () async {
        final success = await memberManager.addMember(
          recipeId: 'collab_1',
          memberId: 'user_456',
          memberDisplayName: 'Existing Member',
        );
        expect(success, isFalse);
      });

      test('should fail when user lacks permission to invite', () async {
        // Viewer cannot invite
        mockParentService.setRecipeState(
          currentUserId: 'user_789',
          currentUserDisplayName: 'Viewer User',
          recipes: [testCollaborativeRecipe, testPersonalRecipe],
        );

        final success = await memberManager.addMember(
          recipeId: 'collab_1',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
        );
        expect(success, isFalse);
      });
    });

    group('Member Removal', () {
      test('should remove member successfully', () async {
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});

        final success = await memberManager.removeMember(
          recipeId: 'collab_1',
          memberId: 'user_456',
        );

        expect(success, isTrue);
        final captured = verify(
          () => mockParentService.updateRecipe(captureAny()),
        ).captured;
        final updatedRecipe = captured.first as Recipe;
        expect(
          updatedRecipe.socialData?.memberPermissions?.containsKey('user_456'),
          isFalse,
        );
      });

      test('should prevent owner from being removed', () async {
        final recipeWithOwner = Recipe(
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
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [recipeWithOwner],
        );

        final success = await memberManager.removeMember(
          recipeId: 'collab_1',
          memberId: 'user_123',
        );
        expect(success, isFalse);
      });

      test('should fail when member not found', () async {
        final success = await memberManager.removeMember(
          recipeId: 'collab_1',
          memberId: 'user_999',
        );
        expect(success, isFalse);
      });
    });

    // BUT-1785: group sharees are recorded in socialData.categoryIds, never in
    // memberPermissions, so the sharing panel's revoke button used to route
    // them into removeMember and fail 100% of the time.
    //
    // Read `RecipeMemberManager.removeGroup`'s own doc before extending these:
    // removing the category id drops a LABEL and revokes no access, because
    // access is decided by memberPermissions alone. The assertion below that
    // memberPermissions survives is pinning THAT — a deliberately incomplete
    // semantics whose honesty lives in the UI copy
    // (`recipeSharingRevokeGroupSuccess`), not a claim that the group's members
    // have lost access. Full revocation is escalated to Malin; it needs
    // group-vs-direct provenance that no document currently records.
    group('Group Access Removal', () {
      Recipe recipeSharedWithGroups(List<String> categoryIds) => Recipe(
        core: testCollaborativeRecipe.core,
        type: testCollaborativeRecipe.type,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Recipe Owner',
          memberPermissions: {'user_456': ResourcePermission.editor},
          categoryIds: categoryIds,
        ),
      );

      test('removes the group id from categoryIds and persists', () async {
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [
            recipeSharedWithGroups(['group_a', 'group_b']),
          ],
        );
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);

        final success = await memberManager.removeGroup(
          recipeId: 'collab_1',
          groupId: 'group_a',
        );

        expect(success, isTrue);
        final captured = verify(
          () => mockParentService.updateRecipe(captureAny()),
        ).captured;
        final updatedRecipe = captured.first as Recipe;
        expect(updatedRecipe.socialData?.categoryIds, ['group_b']);
        // Individually-shared friends are untouched — they stay revocable
        // one by one in the same panel.
        expect(
          updatedRecipe.socialData?.memberPermissions?.keys,
          contains('user_456'),
        );
      });

      test('fails without persisting when the group is not shared', () async {
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [
            recipeSharedWithGroups(['group_a']),
          ],
        );

        final success = await memberManager.removeGroup(
          recipeId: 'collab_1',
          groupId: 'group_zzz',
        );

        expect(success, isFalse);
        verifyNever(() => mockParentService.updateRecipe(any()));
      });

      test('fails for a non-owner who cannot manage members', () async {
        mockParentService.setRecipeState(
          currentUserId: 'user_456',
          recipes: [
            recipeSharedWithGroups(['group_a']),
          ],
        );

        final success = await memberManager.removeGroup(
          recipeId: 'collab_1',
          groupId: 'group_a',
        );

        expect(success, isFalse);
        verifyNever(() => mockParentService.updateRecipe(any()));
      });

      test('a group id sent to removeMember still fails (the bug)', () async {
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [
            recipeSharedWithGroups(['group_a']),
          ],
        );

        final success = await memberManager.removeMember(
          recipeId: 'collab_1',
          memberId: 'group_a',
        );

        expect(success, isFalse);
      });
    });

    group('Permission Updates', () {
      test('should update member permission successfully', () async {
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNotificationService.sendBatchableNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
          ),
        ).thenAnswer((_) async {});

        final success = await memberManager.updateMemberPermission(
          recipeId: 'collab_1',
          memberId: 'user_789',
          newPermission: ResourcePermission.editor,
        );

        expect(success, isTrue);
        final captured = verify(
          () => mockParentService.updateRecipe(captureAny()),
        ).captured;
        final updatedRecipe = captured.first as Recipe;
        expect(
          updatedRecipe.socialData?.memberPermissions?['user_789'],
          equals(ResourcePermission.editor),
        );
      });

      test('should prevent changing owner permission', () async {
        final recipeWithOwner = Recipe(
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
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [recipeWithOwner],
        );

        final success = await memberManager.updateMemberPermission(
          recipeId: 'collab_1',
          memberId: 'user_123',
          newPermission: ResourcePermission.editor,
        );
        expect(success, isFalse);
      });

      test('should fail when user lacks permission', () async {
        // Editor cannot change others' permissions
        mockParentService.setRecipeState(
          currentUserId: 'user_456',
          currentUserDisplayName: 'Editor User',
          recipes: [testCollaborativeRecipe, testPersonalRecipe],
        );

        final success = await memberManager.updateMemberPermission(
          recipeId: 'collab_1',
          memberId: 'user_789',
          newPermission: ResourcePermission.admin,
        );
        expect(success, isFalse);
      });
    });

    group('Member Queries', () {
      test('should get all members', () async {
        final members = await memberManager.getRecipeMembers('collab_1');
        // Owner + 2 members
        expect(members.length, equals(3));
        expect(members.any((m) => m['userId'] == 'user_123'), isTrue);
        expect(members.any((m) => m['userId'] == 'user_456'), isTrue);
        expect(members.any((m) => m['userId'] == 'user_789'), isTrue);
      });

      test('should get member statistics', () async {
        final stats = memberManager.getMemberStatistics('collab_1');
        expect(stats['total_members'], equals(3)); // owner + 2 members
        expect(stats['has_editors'], isTrue);
        expect(stats['permission_breakdown'], isA<Map>());
      });
    });

    group('Invitation Management', () {
      test('should check if current user can invite members', () async {
        final canInvite = memberManager.canInviteMembers('collab_1');
        expect(canInvite, isTrue);
      });

      test('should respect invitation settings', () async {
        final restrictedRecipe = Recipe(
          core: testCollaborativeRecipe.core,
          type: testCollaborativeRecipe.type,
          socialData: RecipeSocialData(
            ownerId: 'user_456',
            ownerDisplayName: 'Other Owner',
            memberPermissions: {
              'user_123': ResourcePermission.viewer,
            },
            allowMemberInvites: false,
          ),
        );
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [restrictedRecipe],
        );

        final canInvite = memberManager.canInviteMembers('collab_1');
        expect(canInvite, isFalse);
      });
    });
  });
}
