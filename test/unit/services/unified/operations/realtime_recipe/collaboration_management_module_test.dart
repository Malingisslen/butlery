// test/unit/services/unified/operations/realtime_recipe/collaboration_management_module_test.dart
//
// Intent-Test Sprint Batch 14 — CollaborationManagementModule
//
// Behaviours covered (one test per behaviour, focused on owner-gate, fresh-read
// race, and — since BUT-1797 — grant provenance):
//   - enableCollaborativeEditing — happy path captures correct args
//   - enableCollaborativeEditing — already-collaborative short-circuits without
//     calling createCollaborativeRecipe (no duplicate-recipe bug)
//   - enableCollaborativeEditing — non-owner is rejected (owner-gate)
//   - enableCollaborativeEditing — empty member list rejected
//   - enableCollaborativeEditing — recipe not found returns false
//   - enableCollaborativeEditing — createCollaborativeRecipe returning null
//     does NOT delete the personal recipe (atomicity-ish guard)
//   - BUT-1797 grant provenance: an added collaborator is recorded as `direct`,
//     a removed one loses their whole entry, a permission update that
//     INTRODUCES a member records a reason for them while leaving everyone
//     else's untouched, and transferOwnership records one for the DEMOTED
//     outgoing owner (whose access stops coming from ownership).
//   - disableCollaborativeEditing — non-owner rejected
//   - disableCollaborativeEditing — createPersonalRecipe failure preserves
//     the collaborative recipe (no orphaned delete)
//   - canEnableCollaboration / canDisableCollaboration — owner-gate truth table
//   - addCollaborators — only owner can add (owner-gate)
//   - addCollaborators — non-collaborative recipe rejected
//   - addCollaborators — empty member list rejected
//   - addCollaborators — fresh-read pattern: uses repo.read result, not local
//     stale recipe (race-resistant write — pins BUT-1108 sibling axis)
//   - addCollaborators — does NOT duplicate existing members
//   - addCollaborators — assigns ResourcePermission.editor to new members
//   - removeCollaborators — owner-gate
//   - removeCollaborators — owner-self-removal is forbidden (last-admin guard)
//   - removeCollaborators — actually drops the member from the persisted map
//   - updateMemberPermissions — owner-gate
//   - updateMemberPermissions — invalid permission string rejected before write
//   - updateMemberPermissions — 'admin' maps to owner enum (privilege escalation
//     surface — this is the contract)
//   - transferOwnership — owner-gate
//   - transferOwnership — new owner must already be a member (no silent grant)
//   - transferOwnership — same-owner is no-op success (no write)
//   - transferOwnership — demotes old owner to editor + elevates new owner +
//     updates ownerId in a SINGLE update call (atomicity)
//   - leaveCollaboration — owner cannot leave (must transfer first)
//   - leaveCollaboration — unauthenticated user rejected
//   - leaveCollaboration — non-owner member can leave
//   - getCollaborationDetails — returns {} for non-collaborative recipe
//   - getCollaborationStatus — surfaces userRole, member count, hasRealtimeService
//   - validateCollaborationSettings — 20-member ceiling
//   - isWithinCollaborationLimits — additionalMembers respects 20 ceiling
//
// NOT covered here, stated so the list above is not read as exhaustive: no test
// stages a throwing collaborator, so the delete-before-validation class is
// unguarded in this file — `setCollaborativeState` has no throwing mode to
// stage it with.

import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/collaboration_management_module.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../../test_support/base_unit_test.dart';

void main() {
  group('CollaborationManagementModule', () {
    late MockUnifiedRecipeService mockParentService;
    late MockRealtimeSyncService mockRealtimeSyncService;
    late MockRecipeRepository mockRecipeRepository;
    late FakePermissionService fakePermissionService;
    late CollaborationManagementModule module;

    late Recipe personalRecipe;
    late Recipe collaborativeRecipe;

    /// A collaborative recipe fixture whose `categoryIds` is DERIVED from the
    /// group tokens in [grants], so the helper cannot stage a pair production
    /// never writes.
    ///
    /// Every production writer sets both fields in one expression. A fixture
    /// carrying `group:x` with no `categoryIds` looks harmless here — the token
    /// is only an untouched control — but `RecipeMemberManager.removeGroup`
    /// returns false BEFORE doing anything when `categoryIds` lacks the group,
    /// so a revoke test built on that shape would pass while exercising nothing.
    /// That trap has been sprung in this repo before.
    Recipe collabWith({
      String id = 'collab_1',
      required String ownerId,
      Map<String, ResourcePermission>? members,
      Map<String, List<String>>? grants,
    }) {
      final derivedCategoryIds = <String>{
        for (final tokens in grants?.values ?? const <List<String>>[])
          for (final token in tokens)
            if (token.startsWith('group:') && token.length > 'group:'.length)
              token.substring('group:'.length),
      };
      return RecipeBuilder()
          .withId(id)
          .withTitle('Shared Soup')
          .withCreatedBy(ownerId)
          .asCollaborative()
          .withSocialData(
            RecipeSocialData(
              ownerId: ownerId,
              ownerDisplayName: 'Owner',
              memberPermissions:
                  members ??
                  {
                    ownerId: ResourcePermission.owner,
                    'editor_user': ResourcePermission.editor,
                  },
              grants: grants,
              categoryIds: derivedCategoryIds.isEmpty
                  ? null
                  : derivedCategoryIds.toList(),
            ),
          )
          .build();
    }

    setUpAll(() {
      registerFallbackValue(<String>[]);
      registerFallbackValue(
        UserProfile(
          uid: 'test',
          email: 't@example.com',
          displayName: 'T',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );
      // Fallback for Recipe arg passed to repo.update
      registerFallbackValue(RecipeBuilder().withId('_fallback').build());
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      mockParentService = MockUnifiedRecipeService();
      mockRealtimeSyncService = MockRealtimeSyncService();

      personalRecipe = RecipeBuilder()
          .withId('recipe_personal')
          .withTitle('My Personal Recipe')
          .withCreatedBy('user_owner')
          .build();

      collaborativeRecipe = collabWith(
        id: 'recipe_collab',
        ownerId: 'user_owner',
        members: {
          'user_owner': ResourcePermission.owner,
          'editor_user': ResourcePermission.editor,
        },
      );

      fakePermissionService =
          TestServiceLocator.get<PermissionService>() as FakePermissionService;
      fakePermissionService.setPermissionState(
        defaultHasPermission: true,
        currentUserId: 'user_owner',
      );

      mockRecipeRepository =
          TestServiceLocator.get<RecipeRepository>() as MockRecipeRepository;

      // Production ServiceLocator bridge (per knowledge file pattern)
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());

      mockParentService.setRecipeState(
        currentUserId: 'user_owner',
        recipes: [personalRecipe, collaborativeRecipe],
      );

      module = CollaborationManagementModule(
        getCurrentUserId: () => mockParentService.currentUserId,
        getRecipes: () => mockParentService.recipes,
        createCollaborativeRecipe: mockParentService.createCollaborativeRecipe,
        createPersonalRecipe: mockParentService.createPersonalRecipe,
        deleteRecipe: mockParentService.deleteRecipe,
        realtimeSyncService: mockRealtimeSyncService,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    // ------------------------------------------------------------------
    // enableCollaborativeEditing
    // ------------------------------------------------------------------
    group('enableCollaborativeEditing', () {
      /// Proves: happy path forwards the recipe's content + members to
      /// createCollaborativeRecipe and then deletes the original personal
      /// recipe. Catches bugs where args are swapped or deletion is skipped.
      test(
        'captures correct args and deletes original personal recipe',
        () async {
          mockParentService.setCollaborativeState(shouldSucceed: true);
          when(
            () => mockParentService.deleteRecipe('recipe_personal'),
          ).thenAnswer((_) async => true);

          final result = await module.enableCollaborativeEditing(
            'recipe_personal',
            ['friend_a', 'friend_b'],
          );

          expect(result, isTrue);
          expect(
            mockParentService.createCollaborativeRecipeCalls,
            hasLength(1),
          );
          final call = mockParentService.createCollaborativeRecipeCalls.first;
          expect(call['title'], 'My Personal Recipe');
          expect(call['memberIds'], ['friend_a', 'friend_b']);
          verify(
            () => mockParentService.deleteRecipe('recipe_personal'),
          ).called(1);
        },
      );

      /// Proves: re-enabling on an already-collaborative recipe must NOT
      /// create a duplicate collaborative recipe. Catches the bug class
      /// "idempotency check happens after the create call".
      test(
        'already-collaborative short-circuits with no create call',
        () async {
          final result = await module.enableCollaborativeEditing(
            'recipe_collab',
            ['friend_a'],
          );

          expect(result, isTrue);
          expect(mockParentService.createCollaborativeRecipeCalls, isEmpty);
          verifyNever(() => mockParentService.deleteRecipe(any()));
        },
      );

      /// SECURITY: only the recipe owner may enable collaboration. A bug
      /// here means any user with read access could convert someone else's
      /// recipe into a collaborative one and inject themselves as a member.
      test('rejects non-owner attempts (owner-gate)', () async {
        fakePermissionService.setPermissionState(
          defaultHasPermission: false,
          currentUserId: 'user_attacker',
        );

        final result = await module.enableCollaborativeEditing(
          'recipe_personal',
          ['user_attacker'],
        );

        expect(result, isFalse);
        expect(mockParentService.createCollaborativeRecipeCalls, isEmpty);
        verifyNever(() => mockParentService.deleteRecipe(any()));
      });

      /// Empty memberIds must reject — creating a collaborative recipe
      /// with no members is a degenerate state.
      test('rejects empty member list', () async {
        final result = await module.enableCollaborativeEditing(
          'recipe_personal',
          [],
        );
        expect(result, isFalse);
        expect(mockParentService.createCollaborativeRecipeCalls, isEmpty);
      });

      /// Recipe-not-found returns false without surprising side effects.
      test('returns false when recipe id is unknown', () async {
        final result = await module.enableCollaborativeEditing(
          'does_not_exist',
          ['friend_a'],
        );
        expect(result, isFalse);
        expect(mockParentService.createCollaborativeRecipeCalls, isEmpty);
      });

      /// CRITICAL: if createCollaborativeRecipe returns null (failure),
      /// the personal recipe MUST NOT be deleted. Otherwise data loss.
      test(
        'does not delete personal recipe when create returns null',
        () async {
          mockParentService.setCollaborativeState(shouldSucceed: false);

          final result = await module.enableCollaborativeEditing(
            'recipe_personal',
            ['friend_a'],
          );

          expect(result, isFalse);
          verifyNever(() => mockParentService.deleteRecipe(any()));
        },
      );
    });

    // ------------------------------------------------------------------
    // disableCollaborativeEditing
    // ------------------------------------------------------------------
    group('disableCollaborativeEditing', () {
      /// Owner-gate on the reverse direction. Non-owner cannot convert
      /// a shared recipe back to personal (which would remove access for
      /// every other collaborator).
      test('rejects non-owner attempts', () async {
        fakePermissionService.setPermissionState(
          defaultHasPermission: false,
          currentUserId: 'editor_user',
        );

        final result = await module.disableCollaborativeEditing(
          'recipe_collab',
        );

        expect(result, isFalse);
        verifyNever(() => mockParentService.deleteRecipe(any()));
      });

      /// If createPersonalRecipe returns null, the collaborative recipe
      /// must remain — otherwise members lose access to data with no
      /// surviving copy.
      test(
        'does not delete collaborative recipe when create returns null',
        () async {
          when(
            () => mockParentService.createPersonalRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              imageUrls: any(named: 'imageUrls'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              rating: any(named: 'rating'),
              personalTagIds: any(named: 'personalTagIds'),
              sourceUrl: any(named: 'sourceUrl'),
            ),
          ).thenAnswer((_) async => null);

          final result = await module.disableCollaborativeEditing(
            'recipe_collab',
          );

          expect(result, isFalse);
          verifyNever(() => mockParentService.deleteRecipe(any()));
        },
      );

      /// Non-collaborative recipe → returns true as no-op (idempotent).
      test('returns true (no-op) when already personal', () async {
        final result = await module.disableCollaborativeEditing(
          'recipe_personal',
        );
        expect(result, isTrue);
      });
    });

    // ------------------------------------------------------------------
    // canEnableCollaboration / canDisableCollaboration truth table
    // ------------------------------------------------------------------
    group('can-* gates', () {
      test('canEnableCollaboration true only for owned personal recipe', () {
        expect(module.canEnableCollaboration('recipe_personal'), isTrue);
        expect(module.canEnableCollaboration('recipe_collab'), isFalse);
        expect(module.canEnableCollaboration('missing'), isFalse);
      });

      test(
        'canDisableCollaboration true only for owned collaborative recipe',
        () {
          expect(module.canDisableCollaboration('recipe_collab'), isTrue);
          expect(module.canDisableCollaboration('recipe_personal'), isFalse);
          expect(module.canDisableCollaboration('missing'), isFalse);
        },
      );

      test('non-owner sees false on both gates', () {
        fakePermissionService.setPermissionState(
          defaultHasPermission: false,
          currentUserId: 'someone_else',
        );
        expect(module.canEnableCollaboration('recipe_personal'), isFalse);
        expect(module.canDisableCollaboration('recipe_collab'), isFalse);
      });
    });

    // ------------------------------------------------------------------
    // addCollaborators
    // ------------------------------------------------------------------
    group('addCollaborators', () {
      /// SECURITY: only owner may add collaborators. Otherwise an editor
      /// could expand the membership behind the owner's back.
      test('rejects non-owner attempts', () async {
        fakePermissionService.setPermissionState(
          defaultHasPermission: false,
          currentUserId: 'editor_user',
        );

        final result = await module.addCollaborators('recipe_collab', [
          'new_user',
        ]);

        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      test('rejects when recipe is not collaborative', () async {
        final result = await module.addCollaborators('recipe_personal', [
          'friend_a',
        ]);
        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      test('rejects empty member list', () async {
        final result = await module.addCollaborators('recipe_collab', []);
        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      /// RACE-RESISTANCE: addCollaborators reads a FRESH copy of the recipe
      /// from the repository before writing. The local recipe list could
      /// be stale (concurrent edit). Pins the contract that the write is
      /// based on the persisted state. Sibling axis of BUT-1108.
      test(
        'uses fresh repo.read for the merge, not stale local recipe',
        () async {
          // Local list has the "old" members. Fresh repo read returns a
          // different membership (simulating a concurrent change someone
          // else just persisted). The final update must include the FRESH
          // members + the new one, not the local stale members.
          final freshCollab = collabWith(
            id: 'recipe_collab',
            ownerId: 'user_owner',
            members: {
              'user_owner': ResourcePermission.owner,
              'editor_user': ResourcePermission.editor,
              'concurrent_add': ResourcePermission.editor, // came in via race
            },
          );

          when(
            () => mockRecipeRepository.read('recipe_collab'),
          ).thenAnswer((_) async => freshCollab);
          when(
            () => mockRecipeRepository.update(any()),
          ).thenAnswer((_) async => true);

          final result = await module.addCollaborators('recipe_collab', [
            'brand_new',
          ]);

          expect(result, isTrue);
          final captured =
              verify(
                    () => mockRecipeRepository.update(captureAny()),
                  ).captured.single
                  as Recipe;
          final perms = captured.socialData!.memberPermissions!;
          expect(
            perms.keys,
            containsAll([
              'user_owner',
              'editor_user',
              'concurrent_add',
              'brand_new',
            ]),
          );
          expect(perms['brand_new'], ResourcePermission.editor);
          // Crucially: the concurrent add was preserved (proves fresh read)
          expect(perms['concurrent_add'], ResourcePermission.editor);
        },
      );

      /// Already-members must be filtered out — adding a redundant entry
      /// could silently downgrade a higher permission to editor.
      test('does not overwrite existing member permissions', () async {
        // Pre-existing editor_user already in members map as editor;
        // calling addCollaborators with that id must NOT touch their entry.
        final freshCollab = collabWith(
          id: 'recipe_collab',
          ownerId: 'user_owner',
          members: {
            'user_owner': ResourcePermission.owner,
            'editor_user': ResourcePermission.editor,
          },
        );
        when(
          () => mockRecipeRepository.read('recipe_collab'),
        ).thenAnswer((_) async => freshCollab);

        // Branch: when ALL provided ids are already members, the module
        // short-circuits as a warning and DOES NOT call update.
        final result = await module.addCollaborators('recipe_collab', [
          'editor_user',
        ]);

        expect(result, isTrue);
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      /// BUT-1797. This module is one of the membership writers, and every one
      /// has to record WHY access was granted or a later group revoke cuts
      /// someone who was invited individually — the one outcome Malin's
      /// 2026-08-03 decision forbids.
      ///
      /// Dropping the `grants:` argument reddens the FIRST assertion only: the
      /// new member gets no reason at all. It cannot redden the second, because
      /// `copyWith` PRESERVES a field it is not given — measured, not assumed.
      /// The erasing failure was a different mutant in a different file: the
      /// field-by-field rebuild in `recipe_member_manager.updateMemberPermission`
      /// that enumerated seven of eight fields.
      ///
      /// The second assertion still earns its place — it guards a refactor back
      /// to that enumerating shape, and a `RecipeShareGrants.add` that returned a
      /// fresh single-entry map instead of a copy.
      test('a collaborator added here is recorded as a DIRECT grant', () async {
        final freshCollab = collabWith(
          id: 'recipe_collab',
          ownerId: 'user_owner',
          members: {
            'user_owner': ResourcePermission.owner,
            'friend_of_group': ResourcePermission.editor,
          },
          grants: {
            'friend_of_group': [RecipeSocialData.groupGrant('grp_fam')],
          },
        );
        when(
          () => mockRecipeRepository.read('recipe_collab'),
        ).thenAnswer((_) async => freshCollab);
        when(
          () => mockRecipeRepository.update(any()),
        ).thenAnswer((_) async => true);

        final result = await module.addCollaborators('recipe_collab', [
          'brand_new',
        ]);

        expect(result, isTrue);
        final captured =
            verify(
                  () => mockRecipeRepository.update(captureAny()),
                ).captured.single
                as Recipe;
        expect(captured.socialData!.grants!['brand_new'], [
          RecipeSocialData.directGrant,
        ]);
        expect(
          captured.socialData!.grants!['friend_of_group'],
          [RecipeSocialData.groupGrant('grp_fam')],
          reason: 'an add must not erase anyone else\'s provenance',
        );
      });
    });

    // ------------------------------------------------------------------
    // removeCollaborators
    // ------------------------------------------------------------------
    group('removeCollaborators', () {
      test('rejects non-owner attempts', () async {
        fakePermissionService.setPermissionState(
          defaultHasPermission: false,
          currentUserId: 'editor_user',
        );

        final result = await module.removeCollaborators('recipe_collab', [
          'editor_user',
        ]);

        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      /// CRITICAL: the owner must NEVER be removed via removeCollaborators.
      /// Removing the owner would orphan the recipe (no admin left).
      test('refuses to remove the owner', () async {
        when(() => mockRecipeRepository.read(any())).thenAnswer(
          (_) async => collaborativeRecipe,
        ); // shouldn't even get called
        when(
          () => mockRecipeRepository.update(any()),
        ).thenAnswer((_) async => true);

        final result = await module.removeCollaborators('recipe_collab', [
          'user_owner',
        ]);

        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      /// Confirms the persisted map actually loses the removed user.
      test('drops removed member from persisted membership map', () async {
        final fresh = collabWith(
          id: 'recipe_collab',
          ownerId: 'user_owner',
          members: {
            'user_owner': ResourcePermission.owner,
            'editor_user': ResourcePermission.editor,
            'goodbye': ResourcePermission.viewer,
          },
        );
        when(
          () => mockRecipeRepository.read('recipe_collab'),
        ).thenAnswer((_) async => fresh);
        when(
          () => mockRecipeRepository.update(any()),
        ).thenAnswer((_) async => true);

        final result = await module.removeCollaborators('recipe_collab', [
          'goodbye',
        ]);

        expect(result, isTrue);
        final captured =
            verify(
                  () => mockRecipeRepository.update(captureAny()),
                ).captured.single
                as Recipe;
        expect(
          captured.socialData!.memberPermissions!.keys,
          isNot(contains('goodbye')),
        );
        // Owner and other editor preserved
        expect(
          captured.socialData!.memberPermissions!.keys,
          containsAll(['user_owner', 'editor_user']),
        );
      });

      /// BUT-1797. An explicit removal overrides every reason at once, so the
      /// whole entry goes. A stale group grant left behind would make a later
      /// `removeGroup` count `goodbye` among the members it cut and send them a
      /// second "you lost access" notification for access they no longer had.
      /// `goodbye` deliberately holds TWO reasons, so dropping only the direct
      /// one is not enough to pass.
      test('an explicit removal drops every grant the member held', () async {
        final fresh = collabWith(
          id: 'recipe_collab',
          ownerId: 'user_owner',
          members: {
            'user_owner': ResourcePermission.owner,
            'editor_user': ResourcePermission.editor,
            'goodbye': ResourcePermission.viewer,
          },
          grants: {
            'goodbye': [
              RecipeSocialData.groupGrant('grp_fam'),
              RecipeSocialData.directGrant,
            ],
            'editor_user': [RecipeSocialData.directGrant],
          },
        );
        when(
          () => mockRecipeRepository.read('recipe_collab'),
        ).thenAnswer((_) async => fresh);
        when(
          () => mockRecipeRepository.update(any()),
        ).thenAnswer((_) async => true);

        final result = await module.removeCollaborators('recipe_collab', [
          'goodbye',
        ]);

        expect(result, isTrue);
        final captured =
            verify(
                  () => mockRecipeRepository.update(captureAny()),
                ).captured.single
                as Recipe;
        expect(captured.socialData!.grants!.containsKey('goodbye'), isFalse);
        expect(
          captured.socialData!.grants!['editor_user'],
          [
            RecipeSocialData.directGrant,
          ],
          reason: 'a removal touches nobody else\'s provenance',
        );
      });
    });

    // ------------------------------------------------------------------
    // updateMemberPermissions
    // ------------------------------------------------------------------
    group('updateMemberPermissions', () {
      test('rejects non-owner attempts', () async {
        fakePermissionService.setPermissionState(
          defaultHasPermission: false,
          currentUserId: 'editor_user',
        );

        final result = await module.updateMemberPermissions('recipe_collab', {
          'editor_user': 'admin',
        });

        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      /// SECURITY: an invalid permission string must short-circuit BEFORE
      /// any repo write. Otherwise a typo silently downgrades to viewer.
      test('rejects invalid permission string before any repo write', () async {
        final result = await module.updateMemberPermissions('recipe_collab', {
          'editor_user': 'super-admin',
        });

        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.read(any()));
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      /// CONTRACT (privilege-escalation surface): the string 'admin' maps
      /// to ResourcePermission.owner inside the module. This is dangerous
      /// and worth pinning — if anyone changes this mapping silently, the
      /// test fails, forcing review.
      test(
        "'admin' permission string is mapped to ResourcePermission.owner",
        () async {
          final fresh = collabWith(
            id: 'recipe_collab',
            ownerId: 'user_owner',
            members: {
              'user_owner': ResourcePermission.owner,
              'editor_user': ResourcePermission.editor,
            },
          );
          when(
            () => mockRecipeRepository.read('recipe_collab'),
          ).thenAnswer((_) async => fresh);
          when(
            () => mockRecipeRepository.update(any()),
          ).thenAnswer((_) async => true);

          final result = await module.updateMemberPermissions('recipe_collab', {
            'editor_user': 'admin',
          });

          expect(result, isTrue);
          final captured =
              verify(
                    () => mockRecipeRepository.update(captureAny()),
                  ).captured.single
                  as Recipe;
          expect(
            captured.socialData!.memberPermissions!['editor_user'],
            ResourcePermission.owner,
          );
        },
      );

      /// BUT-1797. This method is named "update", but it writes with `addAll`,
      /// so a uid that is not yet a member is INTRODUCED by it — another way
      /// into `memberPermissions`, despite the name. A member created here without a recorded
      /// reason is cut the first time a group they were later swept into is
      /// revoked, which is exactly what the decision forbids.
      ///
      /// The fixture names one existing member and one stranger, so both sides
      /// of the `containsKey` skip are exercised at once: dropping the guard
      /// stacks a spurious 'direct' onto editor_user's group reason, and
      /// dropping the loop leaves the stranger with no reason at all.
      test(
        'a permission update that INTRODUCES a member records why',
        () async {
          final fresh = collabWith(
            id: 'recipe_collab',
            ownerId: 'user_owner',
            members: {
              'user_owner': ResourcePermission.owner,
              'editor_user': ResourcePermission.editor,
            },
            grants: {
              'editor_user': [RecipeSocialData.groupGrant('grp_fam')],
            },
          );
          when(
            () => mockRecipeRepository.read('recipe_collab'),
          ).thenAnswer((_) async => fresh);
          when(
            () => mockRecipeRepository.update(any()),
          ).thenAnswer((_) async => true);

          final result = await module.updateMemberPermissions('recipe_collab', {
            'editor_user': 'admin',
            'stranger': 'edit',
          });

          expect(result, isTrue);
          final captured =
              verify(
                    () => mockRecipeRepository.update(captureAny()),
                  ).captured.single
                  as Recipe;
          expect(captured.socialData!.grants!['stranger'], [
            RecipeSocialData.directGrant,
          ]);
          expect(
            captured.socialData!.grants!['editor_user'],
            [RecipeSocialData.groupGrant('grp_fam')],
            reason:
                'an existing member already has a reason — a permission change '
                'is not a second one, and stacking it would survive the revoke '
                'that was meant to undo it',
          );
        },
      );

      test('rejects empty permission map', () async {
        final result = await module.updateMemberPermissions(
          'recipe_collab',
          {},
        );
        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.update(any()));
      });
    });

    // ------------------------------------------------------------------
    // transferOwnership
    // ------------------------------------------------------------------
    group('transferOwnership', () {
      test('rejects non-owner attempts', () async {
        fakePermissionService.setPermissionState(
          defaultHasPermission: false,
          currentUserId: 'editor_user',
        );

        final result = await module.transferOwnership(
          'recipe_collab',
          'editor_user',
        );

        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      /// SECURITY: new owner must already be a member. Otherwise the
      /// current owner could "transfer" to an arbitrary uid and lose all
      /// admin access while granting it to someone never invited.
      test('refuses to transfer to a non-member', () async {
        final result = await module.transferOwnership(
          'recipe_collab',
          'rando_uid',
        );

        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.read(any()));
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      test(
        'returns true (no-op) when newOwnerId equals current ownerId',
        () async {
          final result = await module.transferOwnership(
            'recipe_collab',
            'user_owner',
          );

          expect(result, isTrue);
          verifyNever(() => mockRecipeRepository.update(any()));
        },
      );

      /// ATOMICITY contract: ownerId + memberPermissions are written in a
      /// SINGLE update call (not two). Catches a refactor that splits the
      /// transfer into "set new owner" then "demote old owner" — a window
      /// where both/neither holds owner permission.
      test(
        'demotes old owner to editor, promotes new owner, single repo.update',
        () async {
          final fresh = collabWith(
            id: 'recipe_collab',
            ownerId: 'user_owner',
            members: {
              'user_owner': ResourcePermission.owner,
              'editor_user': ResourcePermission.editor,
            },
          );
          when(
            () => mockRecipeRepository.read('recipe_collab'),
          ).thenAnswer((_) async => fresh);
          when(
            () => mockRecipeRepository.update(any()),
          ).thenAnswer((_) async => true);

          final result = await module.transferOwnership(
            'recipe_collab',
            'editor_user',
          );

          expect(result, isTrue);
          final captured = verify(
            () => mockRecipeRepository.update(captureAny()),
          ).captured;
          expect(
            captured.length,
            1,
            reason: 'transfer must be a single atomic update',
          );
          final updatedRecipe = captured.single as Recipe;
          expect(updatedRecipe.socialData!.ownerId, 'editor_user');
          expect(
            updatedRecipe.socialData!.memberPermissions!['editor_user'],
            ResourcePermission.owner,
          );
          expect(
            updatedRecipe.socialData!.memberPermissions!['user_owner'],
            ResourcePermission.editor,
          );
        },
      );

      /// BUT-1797, the writer this module gained last: a transfer is the one
      /// place where access that came from OWNERSHIP — which needs no recorded
      /// reason — is converted into an ordinary membership entry. Without a
      /// grant written here, the person who created the recipe is the one
      /// member holding a permission and no reason, so the first revoke of a
      /// group they were later swept into cuts them out of their own recipe.
      test('the demoted owner gets a reason for the access they keep', () async {
        final fresh = collabWith(
          id: 'recipe_collab',
          ownerId: 'user_owner',
          members: {
            'user_owner': ResourcePermission.owner,
            'editor_user': ResourcePermission.editor,
          },
          grants: {
            'editor_user': [RecipeSocialData.groupGrant('grp_fam')],
          },
        );
        when(
          () => mockRecipeRepository.read('recipe_collab'),
        ).thenAnswer((_) async => fresh);
        when(
          () => mockRecipeRepository.update(any()),
        ).thenAnswer((_) async => true);

        await module.transferOwnership('recipe_collab', 'editor_user');

        final captured =
            verify(
                  () => mockRecipeRepository.update(captureAny()),
                ).captured.single
                as Recipe;
        expect(captured.socialData!.grants!['user_owner'], [
          RecipeSocialData.directGrant,
        ]);
        expect(
          captured.socialData!.grants!['editor_user'],
          [RecipeSocialData.groupGrant('grp_fam')],
          reason:
              'control: the incoming owner keeps the provenance they already '
              'had — a transfer records one reason, it does not rewrite the map',
        );
      });
    });

    // ------------------------------------------------------------------
    // leaveCollaboration
    // ------------------------------------------------------------------
    group('leaveCollaboration', () {
      /// CRITICAL: owner cannot leave without transferring ownership.
      /// Otherwise the recipe loses its admin and can never be managed.
      test('owner cannot leave (must transfer first)', () async {
        // user_owner is the current user AND the owner
        final result = await module.leaveCollaboration('recipe_collab');
        expect(result, isFalse);
        verifyNever(() => mockRecipeRepository.update(any()));
      });

      test('unauthenticated user rejected', () async {
        mockParentService.setRecipeState(
          currentUserId: null,
          recipes: [collaborativeRecipe],
        );

        final result = await module.leaveCollaboration('recipe_collab');
        expect(result, isFalse);
      });

      /// Non-owner member can leave → behaves like removeCollaborators for
      /// themselves.
      test('non-owner member successfully leaves', () async {
        mockParentService.setRecipeState(
          currentUserId: 'editor_user',
          recipes: [collaborativeRecipe],
        );
        final fresh = collabWith(
          id: 'recipe_collab',
          ownerId: 'user_owner',
          members: {
            'user_owner': ResourcePermission.owner,
            'editor_user': ResourcePermission.editor,
          },
        );
        when(
          () => mockRecipeRepository.read('recipe_collab'),
        ).thenAnswer((_) async => fresh);
        when(
          () => mockRecipeRepository.update(any()),
        ).thenAnswer((_) async => true);

        final result = await module.leaveCollaboration('recipe_collab');

        expect(result, isTrue);
        final captured =
            verify(
                  () => mockRecipeRepository.update(captureAny()),
                ).captured.single
                as Recipe;
        expect(
          captured.socialData!.memberPermissions!.keys,
          isNot(contains('editor_user')),
        );
        expect(
          captured.socialData!.memberPermissions!.keys,
          contains('user_owner'),
        );
      });
    });

    // ------------------------------------------------------------------
    // Read-only inspection
    // ------------------------------------------------------------------
    group('getCollaborationDetails / getCollaborationStatus', () {
      test('details returns {} for non-collaborative recipe', () {
        expect(module.getCollaborationDetails('recipe_personal'), isEmpty);
        expect(module.getCollaborationDetails('missing'), isEmpty);
      });

      test('details surfaces ownerId + memberCount + canManage flag', () {
        final details = module.getCollaborationDetails('recipe_collab');
        expect(details['isCollaborative'], isTrue);
        expect(details['ownerId'], 'user_owner');
        expect(details['memberCount'], 2);
        expect(details['canManage'], isTrue);
      });

      test('status surfaces userRole for current user as owner', () {
        final status = module.getCollaborationStatus('recipe_collab');
        expect(status['exists'], isTrue);
        expect(status['isCollaborative'], isTrue);
        expect(status['memberCount'], 2);
        expect(status['userRole'], 'owner');
        expect(status['hasRealtimeService'], isTrue);
      });

      test(
        'status returns userRole=editor when current user is editor member',
        () {
          mockParentService.setRecipeState(
            currentUserId: 'editor_user',
            recipes: [collaborativeRecipe],
          );
          final status = module.getCollaborationStatus('recipe_collab');
          expect(status['userRole'], 'editor');
        },
      );

      test('status returns userRole=none for missing/unauthenticated', () {
        mockParentService.setRecipeState(
          currentUserId: null,
          recipes: [collaborativeRecipe],
        );
        final status = module.getCollaborationStatus('recipe_collab');
        expect(status['userRole'], 'none');
      });
    });

    // ------------------------------------------------------------------
    // validateCollaborationSettings / isWithinCollaborationLimits
    // ------------------------------------------------------------------
    group('limits and validation', () {
      /// 20-member ceiling is a real cost/abuse guard. Pin it.
      test('validateCollaborationSettings flags >20 members', () {
        final tooMany = List.generate(21, (i) => 'u$i');
        final errors = module.validateCollaborationSettings(memberIds: tooMany);
        expect(errors['members'], contains('20'));
      });

      test('validateCollaborationSettings flags empty member list', () {
        final errors = module.validateCollaborationSettings(memberIds: []);
        expect(errors['members'], isNotNull);
      });

      test('validateCollaborationSettings flags invalid permission value', () {
        final errors = module.validateCollaborationSettings(
          memberIds: ['u1'],
          memberPermissions: {'u1': 'super-admin'},
        );
        expect(errors['permission_u1'], contains('super-admin'));
      });

      test('isWithinCollaborationLimits respects the 20-member ceiling', () {
        // collaborativeRecipe seeded with 2 members; +18 = 20 → OK; +19 → too many
        expect(module.isWithinCollaborationLimits('recipe_collab', 18), isTrue);
        expect(
          module.isWithinCollaborationLimits('recipe_collab', 19),
          isFalse,
        );
      });

      test('isWithinCollaborationLimits returns false for unknown recipe', () {
        expect(module.isWithinCollaborationLimits('missing', 0), isFalse);
      });
    });
  });
}
