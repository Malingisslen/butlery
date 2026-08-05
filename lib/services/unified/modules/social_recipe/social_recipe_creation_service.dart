// lib/services/unified/modules/social_recipe/social_recipe_creation_service.dart

import 'dart:async';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/operations/modules/recipe_share_grants.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

/// Social Recipe Creation Service
/// Handles ONLY the creation of collaborative recipes and related setup operations.
/// This includes initial recipe creation, setting up permissions, and initial sharing.
class SocialRecipeCreationService extends BaseService with UserContextMixin {
  @override
  String get serviceName => 'SocialRecipeCreationService';

  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final void Function(String) _setError;
  final Future<bool> Function(Recipe) _saveRecipe;
  final void Function() _notifyListeners;

  SocialRecipeCreationService({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
    required Future<bool> Function(Recipe) saveRecipe,
  }) : _getCurrentUserId = getCurrentUserId,
       _getCurrentUserDisplayName = getCurrentUserDisplayName,
       _setError = setError,
       _notifyListeners = notifyListeners,
       _saveRecipe = saveRecipe {
    // Set the user ID provider for the mixin
    setUserIdProvider(getCurrentUserId);
  }

  /// Creates a new collaborative recipe with initial sharing settings
  Future<String?> createCollaborativeRecipe({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
    List<String>? initialMembers,
    Map<String, ResourcePermission>? initialPermissions,
    String? description,
    int? portions,
    int? cookingTime,
    List<String>? personalTagIds,
    List<String>? categoryIds,
  }) async {
    try {
      AppLogger.info('🤝 Creating collaborative recipe: $title');

      final currentUserId = _getCurrentUserId();
      final currentUserDisplayName = _getCurrentUserDisplayName();

      if (currentUserId == null) {
        _handleError('User not authenticated');
        return null;
      }

      if (!validateCollaborativeRecipeData(
        title: title,
        ingredients: ingredients,
        instructions: instructions,
      )) {
        _handleError('Invalid recipe data provided');
        return null;
      }

      // Create base recipe structure using factory
      final newRecipe = RecipeFactory.createCollaborative(
        title: title,
        ingredients: ingredients,
        instructions: instructions,
        mealType: 'Middag', // Default meal type
        ownerId: currentUserId,
        ownerDisplayName:
            currentUserDisplayName ?? AppLocale.current.displayUnknownUser,
        description: description.orEmpty(),
        portions: portions,
        timeMinutes: cookingTime,
        personalTagIds: personalTagIds ?? [],
        memberPermissions: {},
      );

      // Set up initial permissions
      final permissions = <String, ResourcePermission>{
        currentUserId: ResourcePermission.admin, // Creator gets admin
      };

      // Add initial members with default permissions.
      //
      // The creator is skipped, and that guard is load-bearing twice over. Every
      // friend category is created with its owner already in `friendUserIds`
      // (friend_categories_operations.dart), and the group-share caller passes
      // `targetGroup.friendUserIds` straight through — so the creator is in this
      // list on the ordinary path, not an exotic one. Without the skip the loop
      // overwrote the `admin` entry set just above with `editor`, DEMOTING the
      // owner of their own recipe, and then recorded them a revocable grant. The
      // sibling path guards the same way (`allMemberIds.remove(currentUserId)`).
      if (initialMembers != null) {
        for (final memberId in initialMembers) {
          if (memberId == currentUserId) continue;
          permissions[memberId] =
              initialPermissions?[memberId] ?? ResourcePermission.editor;
        }
      }

      // BUT-1797: record WHY each member is here, at the moment access is
      // granted. Members reached through a group carry that group's token, so
      // the share can later be revoked for exactly those people; a share with no
      // group behind it is direct. The creator gets no grant — an owner is not a
      // sharee and is never revocable — which the skip above now actually
      // delivers rather than merely asserting.
      final groupIds = categoryIds ?? const <String>[];
      var grants = <String, List<String>>{};
      for (final memberId in initialMembers ?? const <String>[]) {
        if (memberId == currentUserId) continue;
        if (groupIds.isEmpty) {
          grants = RecipeShareGrants.add(
            grants,
            memberId,
            RecipeSocialData.directGrant,
          );
          continue;
        }
        for (final groupId in groupIds) {
          grants = RecipeShareGrants.add(
            grants,
            memberId,
            RecipeSocialData.groupGrant(groupId),
          );
        }
      }

      // Apply permissions and mark for tagging by the RetaggingScheduler
      final recipeWithPermissions = newRecipe.copyWith(
        tagResult: TagResult.pending(),
        socialData: newRecipe.socialData?.copyWith(
          memberPermissions: permissions,
          // Derived from the grants written, not from `groupIds` — a group whose
          // roster is only the creator grants nobody, and the raw id would put a
          // revoke row in the panel that matches no member.
          categoryIds: RecipeShareGrants.mergeCategoryIds(null, grants),
          grants: grants.isEmpty ? null : grants,
        ),
      );

      // Save recipe
      final success = await _saveRecipe(recipeWithPermissions);
      if (!success) {
        _handleError('Failed to save collaborative recipe');
        return null;
      }

      _notifyListeners();
      AppLogger.success(
        '✅ Collaborative recipe created: ${recipeWithPermissions.id}',
      );

      return recipeWithPermissions.id;
    } catch (e) {
      AppLogger.error('Failed to create collaborative recipe', e);
      _handleError('Failed to create collaborative recipe: $e');
      return null;
    }
  }

  /// Validates collaborative recipe data before creation
  bool validateCollaborativeRecipeData({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
  }) {
    if (title.trim().isEmpty) {
      _handleError('Recipe title cannot be empty');
      return false;
    }

    if (ingredients.isEmpty) {
      _handleError('Recipe must have at least one ingredient');
      return false;
    }

    if (instructions.isEmpty) {
      _handleError('Recipe must have at least one instruction');
      return false;
    }

    // Validate individual ingredients
    for (final ingredient in ingredients) {
      if (ingredient.trim().isEmpty) {
        _handleError('Ingredients cannot be empty');
        return false;
      }
    }

    // Validate individual instructions
    for (final instruction in instructions) {
      if (instruction.trim().isEmpty) {
        _handleError('Instructions cannot be empty');
        return false;
      }
    }

    return true;
  }

  /// Helper method for error handling
  void _handleError(String message) {
    AppLogger.error('❌ SocialRecipeCreationService: $message');
    _setError(message);
  }

  /// Create success result for operations
  RecipeOperationResult createSuccessResult([String? message]) {
    return RecipeOperationResult.success(
      message ?? 'Operation completed successfully',
    );
  }

  /// Create failure result for operations
  RecipeOperationResult createFailureResult(String error) {
    return RecipeOperationResult.failure(error);
  }
}
