// test/unit/services/unified/operations/realtime_recipe/collaboration_management_module_test.dart
//
// Intent-Test Sprint Batch 14 — CollaborationManagementModule
//
// Behaviours covered (the "Samarbete" toggle: owner-gate and no data loss):
//   - enableCollaborativeEditing — happy path captures correct args
//   - enableCollaborativeEditing — already-collaborative short-circuits without
//     calling createCollaborativeRecipe (no duplicate-recipe bug)
//   - enableCollaborativeEditing — non-owner is rejected (owner-gate)
//   - enableCollaborativeEditing — empty member list rejected
//   - enableCollaborativeEditing — recipe not found returns false
//   - enableCollaborativeEditing — createCollaborativeRecipe returning null
//     does NOT delete the personal recipe (atomicity-ish guard)
//   - disableCollaborativeEditing — non-owner rejected
//   - disableCollaborativeEditing — createPersonalRecipe failure preserves
//     the collaborative recipe (no orphaned delete)

import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
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

      // Production ServiceLocator bridge (per knowledge file pattern)
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());

      mockParentService.setRecipeState(
        currentUserId: 'user_owner',
        recipes: [personalRecipe, collaborativeRecipe],
      );

      module = CollaborationManagementModule(
        getRecipes: () => mockParentService.recipes,
        createCollaborativeRecipe: mockParentService.createCollaborativeRecipe,
        createPersonalRecipe: mockParentService.createPersonalRecipe,
        deleteRecipe: mockParentService.deleteRecipe,
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
  });
}
