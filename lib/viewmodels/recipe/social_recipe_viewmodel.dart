// lib/viewmodels/recipe/social_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/logging_utils.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/permission_service.dart' as perm;

/// Social Recipe ViewModel
/// 
/// Handles ONLY social recipe operations and collaboration features.
/// This includes collaborative recipe creation, sharing, member management, and permissions.
class SocialRecipeViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService = sl<UnifiedRecipeService>();

  String get serviceName => 'SocialRecipeViewModel';

  // ===== GETTERS =====

  List<Recipe> get collaborativeRecipes => _recipeService.collaborativeRecipes;
  bool get hasCollaborativeRecipes => collaborativeRecipes.isNotEmpty;
  int get collaborativeRecipeCount => collaborativeRecipes.length;

  String? get currentUserId => _recipeService.currentUserId;
  String? get currentUserDisplayName => _recipeService.currentUserDisplayName;

  // ===== COLLABORATIVE RECIPE CREATION =====

  Future<bool> createCollaborativeRecipe({
    required String name,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
    String? descriptionCollaborative,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    // Use ValidationUtils for consistent validation
    final nameError = ValidationUtils.validateRecipeName(name);
    if (nameError != null) return false;
    
    if (!ValidationUtils.hasItems(memberIds)) return false;

    return await safeExecute(
      () => LoggingUtils.loggedCreate(
        'Collaborative Recipe',
        () async {
          final recipeId = await _recipeService.createCollaborativeRecipe(
            title: name.trim(),
            memberIds: memberIds,
            description: description,
            ingredients: ingredients,
            instructions: instructions,
            imageUrls: imageUrls,
            mealType: mealType,
            portions: portions,
            timeMinutes: timeMinutes,
            rating: rating,
            tags: tags,
            sourceUrl: sourceUrl,
            descriptionCollaborative: descriptionCollaborative,
            allowGuestViewing: allowGuestViewing,
            allowMemberInvites: allowMemberInvites,
            categoryIds: categoryIds,
          );

          return recipeId != null;
        },
        metadata: {'member_count': memberIds.length, 'meal_type': mealType},
      ),
      operationName: 'Create Collaborative Recipe',
      defaultValue: false,
    ) ?? false;
  }

  // ===== RECIPE SHARING =====

  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    // Validate inputs using ValidationUtils
    if (ValidationUtils.isNullOrEmpty(recipeId) || !ValidationUtils.hasItems(memberIds)) {
      return null;
    }

    return await LoggingUtils.loggedOperation(
      'Share Recipe',
      () => _recipeService.social.shareRecipe(
        recipeId: recipeId,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
        collaborativeDescription: collaborativeDescription,
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: allowMemberInvites,
        categoryIds: categoryIds,
      ),
      metadata: {'recipe_id': recipeId, 'member_count': memberIds.length},
    );
  }

  Future<String?> makeRecipePersonal(String collaborativeRecipeId) async {
    if (ValidationUtils.isNullOrEmpty(collaborativeRecipeId)) return null;

    return await LoggingUtils.loggedOperation(
      'Convert Recipe to Personal',
      () => _recipeService.social.makeRecipePersonal(
        collaborativeRecipeId: collaborativeRecipeId,
      ),
      metadata: {'recipe_id': collaborativeRecipeId},
    );
  }

  // ===== MEMBER MANAGEMENT =====

  Future<bool> addMemberToRecipe(
      String recipeId, String userId, String userDisplayName, 
      {ResourcePermission permission = ResourcePermission.editor}) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(userId)) {
      return false;
    }

    return await LoggingUtils.loggedUpdate(
      'Recipe Member',
      () => _recipeService.addMemberToRecipe(recipeId, userId, permission),
      itemId: recipeId,
      metadata: {'user_id': userId, 'permission': permission.name},
    );
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(userId)) {
      return false;
    }

    return await LoggingUtils.loggedDelete(
      'Recipe Member',
      () => _recipeService.removeMemberFromRecipe(recipeId, userId),
      itemId: recipeId,
      metadata: {'user_id': userId},
    );
  }

  Future<bool> updateMemberPermission(
      String recipeId, String userId, ResourcePermission permission) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(userId)) {
      return false;
    }

    return await LoggingUtils.loggedUpdate(
      'Recipe Member Permission',
      () => _recipeService.updateMemberPermission(recipeId, userId, permission),
      itemId: recipeId,
      metadata: {'user_id': userId, 'permission': permission.name},
    );
  }

  // ===== PERMISSION CHECKS =====

  bool canManageRecipeMembers(String recipeId) {
    return sl<perm.PermissionService>().canInviteToRecipe(recipeId);
  }

  bool canInviteMembers(String recipeId) {
    return _recipeService.social.canInviteMembers(recipeId);
  }

  Map<String, ResourcePermission> getRecipeMembers(String recipeId) {
    final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
    return recipe?.socialData?.memberPermissions ?? {};
  }

  // ===== RECIPE QUERIES =====

  List<Recipe> getSharedWithMe() {
    return collaborativeRecipes.where((recipe) => 
      recipe.isShared && 
      recipe.socialData?.ownerId != currentUserId
    ).toList();
  }

  List<Recipe> getSharedByMe() {
    return collaborativeRecipes.where((recipe) => 
      recipe.isShared && 
      recipe.socialData?.ownerId == currentUserId
    ).toList();
  }

  Recipe? getCollaborativeRecipeById(String id) {
    return collaborativeRecipes.where((r) => r.id == id).firstOrNull;
  }

  List<Recipe> getCollaborativeRecipesByMealType(String mealType) {
    return collaborativeRecipes.where((r) => r.mealType == mealType).toList();
  }

  List<Recipe> getCollaborativeRecipesByTag(String tag) {
    return collaborativeRecipes.where((r) => r.tags?.contains(tag) ?? false).toList();
  }

  List<Recipe> searchCollaborativeRecipes(String query) {
    if (query.trim().isEmpty) return collaborativeRecipes;

    final lowercaseQuery = query.toLowerCase();
    return collaborativeRecipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowercaseQuery) ||
          recipe.description.toLowerCase().contains(lowercaseQuery) ||
          recipe.ingredients.any((ingredient) =>
              ingredient.toLowerCase().contains(lowercaseQuery)) ||
          recipe.instructions.any((instruction) =>
              instruction.toLowerCase().contains(lowercaseQuery)) ||
          (recipe.tags
                  ?.any((tag) => tag.toLowerCase().contains(lowercaseQuery)) ??
              false);
    }).toList();
  }

  // ===== COLLABORATION INSIGHTS =====

  Map<String, int> getCollaborationStats() {
    int totalMembers = 0;
    int totalRecipesOwned = 0;
    int totalRecipesShared = 0;
    final Set<String> uniqueCollaborators = {};

    for (final recipe in collaborativeRecipes) {
      if (recipe.socialData != null) {
        final memberCount = recipe.socialData!.memberPermissions?.length ?? 0;
        totalMembers += memberCount;
        
        if (recipe.socialData!.ownerId == currentUserId) {
          totalRecipesOwned++;
        } else {
          totalRecipesShared++;
        }

        // Track unique collaborators
        recipe.socialData!.memberPermissions?.keys.forEach((memberId) {
          if (memberId != currentUserId) {
            uniqueCollaborators.add(memberId);
          }
        });
      }
    }

    return {
      'totalCollaborativeRecipes': collaborativeRecipeCount,
      'recipesOwned': totalRecipesOwned,
      'recipesSharedWithMe': totalRecipesShared,
      'totalMembers': totalMembers,
      'uniqueCollaborators': uniqueCollaborators.length,
    };
  }

  Map<String, List<Recipe>> getRecipesByCollaborator() {
    final Map<String, List<Recipe>> collaboratorRecipes = {};

    for (final recipe in collaborativeRecipes) {
      if (recipe.socialData?.memberPermissions != null) {
        recipe.socialData!.memberPermissions!.forEach((memberId, permission) {
          if (memberId != currentUserId) {
            collaboratorRecipes.putIfAbsent(memberId, () => []).add(recipe);
          }
        });
      }
    }

    return collaboratorRecipes;
  }

  List<String> getMostActiveCollaborators({int limit = 10}) {
    final collaboratorCounts = <String, int>{};

    for (final recipe in collaborativeRecipes) {
      if (recipe.socialData?.memberPermissions != null) {
        for (final memberId in recipe.socialData!.memberPermissions!.keys) {
          if (memberId != currentUserId) {
            collaboratorCounts[memberId] = (collaboratorCounts[memberId] ?? 0) + 1;
          }
        }
      }
    }

    final sortedCollaborators = collaboratorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCollaborators
        .take(limit)
        .map((entry) => entry.key)
        .toList();
  }

  // ===== ANALYTICS =====

  Map<String, int> getCollaborativeMealTypeCounts() {
    final mealTypeCounts = <String, int>{};
    for (final recipe in collaborativeRecipes) {
      mealTypeCounts[recipe.mealType] = (mealTypeCounts[recipe.mealType] ?? 0) + 1;
    }
    return mealTypeCounts;
  }

  Map<String, int> getCollaborativeTagCounts() {
    final tagCounts = <String, int>{};
    for (final recipe in collaborativeRecipes) {
      if (recipe.tags != null) {
        for (final tag in recipe.tags!) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
    }
    return tagCounts;
  }
}