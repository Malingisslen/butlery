// lib/repositories/firebase/firebase_recipe_ownership_resolver.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/core/utils/logger.dart';

/// Production implementation of [RecipeOwnershipResolver].
///
/// Resolves the denormalized ownership snapshot for a recipe so the comment
/// doc can carry `recipeOwnerId` + `sharedWithUserIds`. Security rules use
/// these denorm fields to allow reads without an N+1 recipe lookup.
///
/// **Resolution strategy:**
/// 1. Fetch the [Recipe] via the injected [getRecipe] callback (typically
///    routed through `SocialRecipeCoordinator.getRecipe`).
/// 2. **Personal recipes** (`!isCollaborative`): owner = `createdBy`, no
///    explicit shares — author of the comment can read their own comments
///    on their own recipe via the author-only fallback rule branch.
/// 3. **Collaborative recipes**: owner = `socialData.ownerId`, shared list
///    = members from `socialData.memberPermissions.keys` (every member can
///    read; admin/editor can also write).
///
/// **Failure modes** (all return null — comment writes without denorm
/// fields and rules degrade to author-only read for that row):
/// - Recipe not found / unreadable.
/// - Recipe present but missing `socialData` AND `createdBy` (legacy
///   orphan — see `LegacyRecipeOwnershipResolver` for the deletion-side
///   counterpart; for comment-write we don't try to infer ownership).
class FirebaseRecipeOwnershipResolver {
  final Future<Recipe?> Function(String recipeId) _getRecipe;

  FirebaseRecipeOwnershipResolver({
    required Future<Recipe?> Function(String recipeId) getRecipe,
  }) : _getRecipe = getRecipe;

  /// Resolve the ownership snapshot. Returns null if the recipe is missing
  /// or has no usable ownership data — caller (FirebaseCommentsRepository)
  /// treats null as "skip denormalization, write the comment without the
  /// fields, fall back to author-only read".
  Future<RecipeOwnershipSnapshot?> resolve(String recipeId) async {
    try {
      final recipe = await _getRecipe(recipeId);
      if (recipe == null) {
        AppLogger.debug(
          '[RecipeOwnershipResolver] recipe $recipeId not found — '
          'comment denorm skipped',
        );
        return null;
      }

      final ownerId = _resolveOwnerId(recipe);
      if (ownerId == null || ownerId.isEmpty) {
        AppLogger.warning(
          '[RecipeOwnershipResolver] recipe $recipeId has no resolvable '
          'owner — comment denorm skipped',
        );
        return null;
      }

      final sharedIds = _resolveSharedIds(recipe);

      return RecipeOwnershipSnapshot(
        recipeOwnerId: ownerId,
        sharedWithUserIds: sharedIds,
      );
    } catch (e) {
      AppLogger.warning(
        '[RecipeOwnershipResolver] resolve failed for recipe $recipeId: $e',
      );
      return null;
    }
  }

  /// `socialData.ownerId` for collaborative recipes; `createdBy` for
  /// personal recipes. We deliberately do NOT call into
  /// [LegacyRecipeOwnershipResolver] here — comment writes shouldn't
  /// trigger ownership inference; missing-owner is a clear signal to
  /// degrade to author-only read.
  String? _resolveOwnerId(Recipe recipe) {
    if (recipe.isCollaborative) {
      final socialOwner = recipe.socialData?.ownerId;
      if (socialOwner != null && socialOwner.isNotEmpty) {
        return socialOwner;
      }
    }
    return recipe.createdBy;
  }

  /// All explicit members for collaborative recipes; empty for personal.
  /// Includes any permission level (viewer / editor / admin) — security
  /// rules' read predicate accepts any membership for read.
  List<String> _resolveSharedIds(Recipe recipe) {
    if (!recipe.isCollaborative) return const <String>[];
    final permissions = recipe.socialData?.memberPermissions;
    if (permissions == null || permissions.isEmpty) return const <String>[];
    // Filter out the owner — they're already in `recipeOwnerId` and the
    // rule's owner-branch handles them. Keeps the array minimal.
    final ownerId = recipe.socialData?.ownerId;
    return permissions.keys
        .where((uid) =>
            uid.isNotEmpty &&
            uid != ownerId &&
            _isReadablePermission(permissions[uid]))
        .toList();
  }

  bool _isReadablePermission(ResourcePermission? permission) {
    // Every assigned permission level grants read; null means no entry.
    return permission != null;
  }
}
