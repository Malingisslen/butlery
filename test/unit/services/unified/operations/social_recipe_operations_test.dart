/// Unit tests for SocialRecipeOperations sub-modules
///
/// SocialRecipeOperations cannot be constructed in unit tests because its
/// constructor creates RecipeSharingManager which calls
/// `ServiceLocator.get<FirestoreRepository>()` at construction time.
///
/// Instead we test the independently-constructible modules:
/// 1. RecipePermissionHelper — pure permission logic
/// 2. RecipeDiscoveryService — in-memory recipe filtering
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';

import '../../../../infrastructure/builders/recipe_builder.dart';

Recipe _buildCollaborative({
  required String ownerId,
  Map<String, ResourcePermission>? memberPermissions,
  List<String>? categoryIds,
  bool allowMemberInvites = true,
}) {
  return RecipeBuilder()
      .asCollaborative()
      .withSocialData(RecipeSocialData(
        ownerId: ownerId,
        ownerDisplayName: 'Owner',
        memberPermissions: memberPermissions ?? {},
        allowMemberInvites: allowMemberInvites,
        categoryIds: categoryIds,
      ))
      .build();
}

void main() {
  // -----------------------------------------------------------------------
  // RecipePermissionHelper
  // -----------------------------------------------------------------------
  group('RecipePermissionHelper', () {
    late RecipePermissionHelper helper;

    setUp(() {
      helper = RecipePermissionHelper(
        getCurrentUserId: () => 'current-user',
      );
    });

    group('canViewRecipe', () {
      test('owner can view own personal recipe', () {
        final recipe = RecipeBuilder().withCreatedBy('current-user').build();
        expect(helper.canViewRecipe(recipe), isTrue);
      });

      test('non-owner cannot view personal recipe', () {
        final recipe = RecipeBuilder().withCreatedBy('other-user').build();
        expect(helper.canViewRecipe(recipe), isFalse);
      });

      test('member can view collaborative recipe', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.viewer,
          },
        );
        expect(helper.canViewRecipe(recipe), isTrue);
      });

      test('non-member cannot view collaborative recipe', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {'someone-else': ResourcePermission.viewer},
        );
        expect(helper.canViewRecipe(recipe), isFalse);
      });

      test('returns false when user is not logged in', () {
        final noAuth = RecipePermissionHelper(getCurrentUserId: () => null);
        final recipe = RecipeBuilder().build();
        expect(noAuth.canViewRecipe(recipe), isFalse);
      });
    });

    group('canEditRecipe', () {
      test('owner can edit own recipe', () {
        final recipe = RecipeBuilder().withCreatedBy('current-user').build();
        expect(helper.canEditRecipe(recipe), isTrue);
      });

      test('editor member can edit collaborative recipe', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.editor,
          },
        );
        expect(helper.canEditRecipe(recipe), isTrue);
      });

      test('viewer member cannot edit collaborative recipe', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.viewer,
          },
        );
        expect(helper.canEditRecipe(recipe), isFalse);
      });

      test('admin member can edit collaborative recipe', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.admin,
          },
        );
        expect(helper.canEditRecipe(recipe), isTrue);
      });
    });

    group('canDeleteRecipe', () {
      test('owner can delete own recipe', () {
        final recipe = RecipeBuilder().withCreatedBy('current-user').build();
        expect(helper.canDeleteRecipe(recipe), isTrue);
      });

      test('non-owner cannot delete recipe', () {
        final recipe = RecipeBuilder().withCreatedBy('other-user').build();
        expect(helper.canDeleteRecipe(recipe), isFalse);
      });
    });

    group('canManageMembers', () {
      test('returns false for personal recipes', () {
        final recipe = RecipeBuilder().withCreatedBy('current-user').build();
        expect(helper.canManageMembers(recipe), isFalse);
      });

      test('owner of collaborative recipe can manage members', () {
        final recipe = _buildCollaborative(ownerId: 'current-user');
        expect(helper.canManageMembers(recipe), isTrue);
      });

      test('admin member can manage members', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.admin,
          },
        );
        expect(helper.canManageMembers(recipe), isTrue);
      });

      test('editor member cannot manage members', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.editor,
          },
        );
        expect(helper.canManageMembers(recipe), isFalse);
      });
    });

    group('canCommentOnRecipe', () {
      test('owner can comment on own personal recipe', () {
        final recipe = RecipeBuilder().withCreatedBy('current-user').build();
        expect(helper.canCommentOnRecipe(recipe), isTrue);
      });

      test('non-owner cannot comment on personal recipe', () {
        final recipe = RecipeBuilder().withCreatedBy('other-user').build();
        expect(helper.canCommentOnRecipe(recipe), isFalse);
      });

      test('member can comment on collaborative recipe', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.viewer,
          },
        );
        expect(helper.canCommentOnRecipe(recipe), isTrue);
      });
    });

    group('canRateRecipe', () {
      test('cannot rate own recipe', () {
        final recipe = _buildCollaborative(ownerId: 'current-user');
        expect(helper.canRateRecipe(recipe), isFalse);
      });

      test('member can rate collaborative recipe of another owner', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.viewer,
          },
        );
        expect(helper.canRateRecipe(recipe), isTrue);
      });

      test('cannot rate personal recipe of another user', () {
        final recipe = RecipeBuilder().withCreatedBy('other-user').build();
        expect(helper.canRateRecipe(recipe), isFalse);
      });
    });

    group('getUserPermission', () {
      test('owner gets owner permission', () {
        final recipe = _buildCollaborative(ownerId: 'current-user');
        expect(helper.getUserPermission(recipe, 'current-user'),
            ResourcePermission.owner);
      });

      test('member gets their assigned permission', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.editor,
          },
        );
        expect(helper.getUserPermission(recipe, 'current-user'),
            ResourcePermission.editor);
      });

      test('non-member gets read permission', () {
        final recipe = _buildCollaborative(ownerId: 'other-owner');
        expect(helper.getUserPermission(recipe, 'stranger'),
            ResourcePermission.read);
      });
    });

    group('checkLegacyPermission', () {
      test('maps view action to canViewRecipe', () {
        final recipe = RecipeBuilder().withCreatedBy('current-user').build();
        expect(helper.checkLegacyPermission(recipe, 'current-user', 'view'),
            isTrue);
      });

      test('maps edit action to canEditRecipe', () {
        final recipe = RecipeBuilder().withCreatedBy('current-user').build();
        expect(helper.checkLegacyPermission(recipe, 'current-user', 'edit'),
            isTrue);
      });

      test('returns false for unknown action', () {
        final recipe = RecipeBuilder().withCreatedBy('current-user').build();
        expect(helper.checkLegacyPermission(recipe, 'current-user', 'fly'),
            isFalse);
      });
    });

    group('canInviteMembers', () {
      test('owner can invite even when allowMemberInvites is true', () {
        final recipe = _buildCollaborative(
          ownerId: 'current-user',
          allowMemberInvites: true,
        );
        expect(helper.canInviteMembers(recipe), isTrue);
      });

      test('returns false when allowMemberInvites is false and not owner', () {
        final recipe = _buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.editor,
          },
          allowMemberInvites: false,
        );
        expect(helper.canInviteMembers(recipe), isFalse);
      });
    });
  });

  // -----------------------------------------------------------------------
  // RecipeDiscoveryService
  // -----------------------------------------------------------------------
  group('RecipeDiscoveryService', () {
    late RecipeDiscoveryService discovery;
    late List<Recipe> recipes;

    setUp(() {
      recipes = [];
      discovery = RecipeDiscoveryService(
        getCurrentUserId: () => 'current-user',
        getRecipes: () => recipes,
      );
    });

    group('getCollaborativeRecipes', () {
      test('returns collaborative recipes where user is owner', () async {
        recipes.addAll([
          _buildCollaborative(ownerId: 'current-user'),
          RecipeBuilder().withCreatedBy('current-user').build(), // personal
        ]);

        final result = await discovery.getCollaborativeRecipes();

        expect(result.length, 1);
        expect(result.first.isCollaborative, isTrue);
      });

      test('returns collaborative recipes where user is member', () async {
        recipes.add(_buildCollaborative(
          ownerId: 'other-owner',
          memberPermissions: {
            'current-user': ResourcePermission.viewer,
          },
        ));

        final result = await discovery.getCollaborativeRecipes();
        expect(result.length, 1);
      });

      test('filters by category', () async {
        recipes.addAll([
          _buildCollaborative(
            ownerId: 'current-user',
            categoryIds: ['dinner'],
          ),
          _buildCollaborative(
            ownerId: 'current-user',
            categoryIds: ['dessert'],
          ),
        ]);

        final result = await discovery.getCollaborativeRecipes(
          categoryFilter: ['dinner'],
        );
        expect(result.length, 1);
      });

      test('filters by search query on title', () async {
        final r = RecipeBuilder()
            .asCollaborative()
            .withTitle('Pannkakor')
            .withSocialData(RecipeSocialData(
              ownerId: 'current-user',
              ownerDisplayName: 'Owner',
            ))
            .build();
        recipes.add(r);

        final result = await discovery.getCollaborativeRecipes(
          searchQuery: 'pannkakor',
        );
        expect(result.length, 1);
      });

      test('returns empty list when not authenticated', () async {
        final noAuthDiscovery = RecipeDiscoveryService(
          getCurrentUserId: () => null,
          getRecipes: () => recipes,
        );
        recipes.add(_buildCollaborative(ownerId: 'someone'));

        final result = await noAuthDiscovery.getCollaborativeRecipes();
        expect(result, isEmpty);
      });
    });

    group('getSharedWithMe', () {
      test('returns collaborative recipes where user is member but not owner',
          () async {
        recipes.addAll([
          _buildCollaborative(
            ownerId: 'other-owner',
            memberPermissions: {
              'current-user': ResourcePermission.viewer,
            },
          ),
          _buildCollaborative(
              ownerId: 'current-user'), // own, not "shared with me"
        ]);

        final result = await discovery.getSharedWithMe();
        expect(result.length, 1);
      });
    });

    group('getSharedByMe', () {
      test('returns collaborative recipes where user is owner', () async {
        recipes.addAll([
          _buildCollaborative(
            ownerId: 'current-user',
            memberPermissions: {
              'member-1': ResourcePermission.viewer,
            },
          ),
          _buildCollaborative(ownerId: 'other-owner'),
        ]);

        final result = await discovery.getSharedByMe();
        // Should include ones user owns that are collaborative
        expect(
            result.every((r) =>
                (r.socialData?.ownerId ?? r.createdBy) == 'current-user'),
            isTrue);
      });
    });

    group('getDiscoveryStatistics', () {
      test('returns statistics map', () {
        recipes.addAll([
          _buildCollaborative(ownerId: 'current-user'),
          _buildCollaborative(
            ownerId: 'other',
            memberPermissions: {'current-user': ResourcePermission.viewer},
          ),
          RecipeBuilder().withCreatedBy('current-user').build(),
        ]);

        final stats = discovery.getDiscoveryStatistics();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('total_recipes'), isTrue);
        expect(stats['total_recipes'], 3);
      });
    });
  });
}
