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
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockNotificationService.sendSilentNotification(
            targetUserIds: any(named: 'targetUserIds'),
            data: any(named: 'data'),
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
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockNotificationService.sendSilentNotification(
            targetUserIds: any(named: 'targetUserIds'),
            data: any(named: 'data'),
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
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockNotificationService.sendSilentNotification(
            targetUserIds: any(named: 'targetUserIds'),
            data: any(named: 'data'),
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

    // BUT-1785 then BUT-1797. The button used to route a group id into
    // removeMember and fail 100% of the time; then it dropped a display LABEL
    // and revoked nothing, because access is decided by memberPermissions alone
    // and nothing recorded whether a member arrived via the group or was invited
    // directly.
    //
    // `socialData.grants` is that provenance, and removeGroup now genuinely
    // revokes. Read its doc comment before extending these tests — in
    // particular, a recipe with NO grants still loses only the label, which is
    // what the first test below pins.
    group('Group Access Removal', () {
      Recipe recipeSharedWithGroups(
        List<String> categoryIds, {
        Map<String, ResourcePermission>? memberPermissions,
        Map<String, List<String>>? grants,
      }) => Recipe(
        core: testCollaborativeRecipe.core,
        type: testCollaborativeRecipe.type,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Recipe Owner',
          memberPermissions:
              memberPermissions ?? {'user_456': ResourcePermission.editor},
          categoryIds: categoryIds,
          grants: grants,
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
        // This fixture records no grants, so nobody is here BECAUSE of group_a
        // and nobody loses access. Not a claim that a real group share leaves
        // its members alone — see the revocation tests below.
        expect(
          updatedRecipe.socialData?.memberPermissions?.keys,
          contains('user_456'),
        );
      });

      test('every cut member is notified, and no retained one is', () async {
        // Every other fixture cuts exactly ONE member, which is the unrealistic
        // shape: a group share exists to reach several people. With a singleton,
        // `removedMemberIds.first`, a `break` after one iteration, and an
        // accumulator that overwrites instead of appending all survive — in the
        // manager AND in the pure algebra underneath it.
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [
            recipeSharedWithGroups(
              ['group_a'],
              memberPermissions: {
                'user_123': ResourcePermission.admin,
                'user_456': ResourcePermission.editor,
                'user_789': ResourcePermission.viewer,
                'user_222': ResourcePermission.editor,
              },
              grants: {
                'user_456': [RecipeSocialData.groupGrant('group_a')],
                'user_789': [RecipeSocialData.groupGrant('group_a')],
                // Retained: a second reason. Must NOT be notified.
                'user_222': [
                  RecipeSocialData.groupGrant('group_a'),
                  RecipeSocialData.directGrant,
                ],
              },
            ),
          ],
        );
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);
        final notified = <List<String>>[];
        when(
          () => mockNotificationService.sendSilentNotification(
            targetUserIds: any(named: 'targetUserIds'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((invocation) async {
          notified.add(
            invocation.namedArguments[#targetUserIds] as List<String>,
          );
        });

        final success = await memberManager.removeGroup(
          recipeId: 'collab_1',
          groupId: 'group_a',
        );

        expect(success, isTrue);
        expect(
          notified,
          unorderedEquals([
            ['user_456'],
            ['user_789'],
          ]),
          reason:
              'both cut members told, and the one who kept access via a direct '
              'share told nothing. The mutants only a MULTI-member fixture can '
              'see are "notify only the first", a break after one iteration, '
              'and an accumulator that overwrites — the retained-for-removed '
              'swap is already caught by the singleton fixtures below',
        );

        // Persistence at N=2 as well, not just the notification: both cut
        // members must actually lose their permission, and the retained one
        // must keep hers. Free, since the recipe is already captured.
        final saved =
            verify(
                  () => mockParentService.updateRecipe(captureAny()),
                ).captured.last
                as Recipe;
        final perms = saved.socialData!.memberPermissions!;
        expect(perms.containsKey('user_456'), isFalse);
        expect(perms.containsKey('user_789'), isFalse);
        expect(perms['user_222'], ResourcePermission.editor);
      });

      test('a failed persist revokes nobody AND notifies nobody', () async {
        // The mutant that matters here is not "return true" — it is the
        // notification loop moving ABOVE the `if (!success)` guard, which tells
        // a member they lost access that was never actually revoked.
        //
        // The failure path is not hypothetical: under BUT-1785 the write seam
        // this stubs really did return false for every collaborative recipe, for
        // months. (BUT-1785's own 100% failure was a group id hitting
        // removeMember's membership guard — a different mechanism, same seam.)
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [
            recipeSharedWithGroups(
              ['group_a'],
              memberPermissions: {
                'user_123': ResourcePermission.admin,
                'user_456': ResourcePermission.editor,
              },
              grants: {
                'user_456': [RecipeSocialData.groupGrant('group_a')],
              },
            ),
          ],
        );
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => false);

        final success = await memberManager.removeGroup(
          recipeId: 'collab_1',
          groupId: 'group_a',
        );

        expect(success, isFalse);
        // Without this the test is satisfiable by never reaching the seam at
        // all (recipe-not-found, group absent, non-owner) — a future guard
        // change would turn it into a tautology while the comment still claimed
        // it killed the loop-above-the-guard mutant.
        verify(() => mockParentService.updateRecipe(any())).called(1);
        verifyNever(
          () => mockNotificationService.sendSilentNotification(
            targetUserIds: any(named: 'targetUserIds'),
            data: any(named: 'data'),
          ),
        );
      });

      test('REVOKES a member whose only grant was that group', () async {
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [
            recipeSharedWithGroups(
              ['group_a'],
              memberPermissions: {
                'user_123': ResourcePermission.admin,
                'user_456': ResourcePermission.editor,
              },
              grants: {
                'user_456': [RecipeSocialData.groupGrant('group_a')],
              },
            ),
          ],
        );
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockNotificationService.sendSilentNotification(
            targetUserIds: any(named: 'targetUserIds'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async {});

        final success = await memberManager.removeGroup(
          recipeId: 'collab_1',
          groupId: 'group_a',
        );

        expect(success, isTrue);
        final updatedRecipe =
            verify(
                  () => mockParentService.updateRecipe(captureAny()),
                ).captured.first
                as Recipe;
        expect(
          updatedRecipe.socialData?.memberPermissions?.containsKey('user_456'),
          isFalse,
          reason: 'the group was their only reason to have access',
        );
        expect(
          updatedRecipe.socialData?.grants?.containsKey('user_456'),
          isFalse,
        );
        expect(updatedRecipe.socialData?.categoryIds, isEmpty);
        verify(
          () => mockNotificationService.sendSilentNotification(
            targetUserIds: ['user_456'],
            data: any(named: 'data'),
          ),
        ).called(1);
      });

      test(
        'a member who ALSO has a direct share keeps access (Malin, 2026-08-03)',
        () async {
          mockParentService.setRecipeState(
            currentUserId: 'user_123',
            recipes: [
              recipeSharedWithGroups(
                ['group_a'],
                memberPermissions: {
                  'user_123': ResourcePermission.admin,
                  'user_456': ResourcePermission.editor,
                },
                grants: {
                  'user_456': [
                    RecipeSocialData.groupGrant('group_a'),
                    RecipeSocialData.directGrant,
                  ],
                },
              ),
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
          final updatedRecipe =
              verify(
                    () => mockParentService.updateRecipe(captureAny()),
                  ).captured.first
                  as Recipe;
          expect(
            updatedRecipe.socialData?.memberPermissions?['user_456'],
            ResourcePermission.editor,
          );
          expect(updatedRecipe.socialData?.grants?['user_456'], [
            RecipeSocialData.directGrant,
          ]);
          // Load-bearing: a positive assertion alone cannot see the fan-out
          // swapped from `removedMemberIds` to `retainedMemberIds`, which would
          // tell someone who KEPT access that they had lost it.
          verifyNever(
            () => mockNotificationService.sendSilentNotification(
              targetUserIds: any(named: 'targetUserIds'),
              data: any(named: 'data'),
            ),
          );
        },
      );

      test(
        'an explicit removal cuts a member who also holds a group grant',
        () async {
          mockParentService.setRecipeState(
            currentUserId: 'user_123',
            recipes: [
              recipeSharedWithGroups(
                ['group_a'],
                memberPermissions: {
                  'user_123': ResourcePermission.admin,
                  'user_456': ResourcePermission.editor,
                },
                grants: {
                  'user_456': [
                    RecipeSocialData.groupGrant('group_a'),
                    RecipeSocialData.directGrant,
                  ],
                },
              ),
            ],
          );
          when(
            () => mockParentService.updateRecipe(any()),
          ).thenAnswer((_) async => true);
          when(
            () => mockNotificationService.sendSilentNotification(
              targetUserIds: any(named: 'targetUserIds'),
              data: any(named: 'data'),
            ),
          ).thenAnswer((_) async {});

          final success = await memberManager.removeMember(
            recipeId: 'collab_1',
            memberId: 'user_456',
          );

          expect(success, isTrue);
          final updatedRecipe =
              verify(
                    () => mockParentService.updateRecipe(captureAny()),
                  ).captured.first
                  as Recipe;
          expect(
            updatedRecipe.socialData?.memberPermissions?.containsKey(
              'user_456',
            ),
            isFalse,
          );
          expect(
            updatedRecipe.socialData?.grants?.containsKey('user_456'),
            isFalse,
            reason:
                'a stale group grant would make a later group-revoke look spent',
          );
        },
      );

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

      // ANTI-HARMONISATION ANCHOR, not a discriminating test. `removeMember`
      // rejects any id absent from `memberPermissions`, so this cannot fail
      // short of someone teaching it a group branch — which is exactly what it
      // exists to stop. Keep it; don't count it as coverage.
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

      test('adding a member records WHY, and erases nobody else\'s', () async {
        // Deleting the `grants:` argument from addMember used to stay green.
        // The consequence is the ticket's core promise inverted: a member
        // invited individually, later swept into a group share, would hold only
        // that group's token — so revoking the group CUTS them.
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [
            Recipe(
              core: testCollaborativeRecipe.core,
              type: testCollaborativeRecipe.type,
              socialData: RecipeSocialData(
                ownerId: 'user_123',
                memberPermissions: const {
                  'user_123': ResourcePermission.admin,
                  'user_456': ResourcePermission.editor,
                },
                grants: {
                  'user_456': [RecipeSocialData.groupGrant('group_a')],
                },
              ),
            ),
          ],
        );
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).thenAnswer((_) async {});

        final success = await memberManager.addMember(
          recipeId: 'collab_1',
          memberId: 'user_999',
          memberDisplayName: 'New Member',
        );

        expect(success, isTrue);
        final saved =
            verify(
                  () => mockParentService.updateRecipe(captureAny()),
                ).captured.first
                as Recipe;
        expect(saved.socialData?.grants?['user_999'], [
          RecipeSocialData.directGrant,
        ]);
        // Seven stubs for this method existed and not one verify, so deleting
        // the notification call left the suite green — a member added to a
        // shared recipe would simply never be told.
        verify(
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: ['user_999'],
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).called(1);
        expect(
          saved.socialData?.grants?['user_456'],
          [RecipeSocialData.groupGrant('group_a')],
          reason: 'an add must not erase anyone else\'s provenance',
        );
      });
    });

    group('Permission Updates', () {
      test('should update member permission successfully', () async {
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockNotificationService.sendSilentNotification(
            targetUserIds: any(named: 'targetUserIds'),
            data: any(named: 'data'),
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

      test('a permission change does not erase anyone\'s grants', () async {
        // BUT-1797, found by review. This method used to rebuild
        // `RecipeSocialData` field by field and enumerate seven of its eight
        // fields — so it DELETED `grants` rather than leaving it alone, because
        // the document is written whole. One permission change then disarmed
        // `removeGroup` for the entire recipe: it took the no-grants branch, cut
        // nobody, and still reported success. The failure this ticket exists to
        // end, resurrected by an unrelated action.
        //
        // No fixture in the Permission Updates group carried `grants`, which is
        // exactly why every suite stayed green over it.
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [
            Recipe(
              core: testCollaborativeRecipe.core,
              type: testCollaborativeRecipe.type,
              socialData: RecipeSocialData(
                ownerId: 'user_123',
                memberPermissions: const {
                  'user_123': ResourcePermission.admin,
                  'user_789': ResourcePermission.viewer,
                },
                categoryIds: const ['group_a'],
                grants: {
                  'user_789': [
                    RecipeSocialData.groupGrant('group_a'),
                    RecipeSocialData.directGrant,
                  ],
                },
              ),
            ),
          ],
        );
        when(
          () => mockParentService.updateRecipe(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockNotificationService.sendSilentNotification(
            targetUserIds: any(named: 'targetUserIds'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async {});

        final success = await memberManager.updateMemberPermission(
          recipeId: 'collab_1',
          memberId: 'user_789',
          newPermission: ResourcePermission.editor,
        );

        expect(success, isTrue);
        final updatedRecipe =
            verify(
                  () => mockParentService.updateRecipe(captureAny()),
                ).captured.first
                as Recipe;
        expect(
          updatedRecipe.socialData?.grants?['user_789'],
          [
            RecipeSocialData.groupGrant('group_a'),
            RecipeSocialData.directGrant,
          ],
          reason:
              'provenance is not a permission — changing one is not a '
              'reason to erase the other',
        );
        expect(
          updatedRecipe.socialData?.memberPermissions?['user_789'],
          ResourcePermission.editor,
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
