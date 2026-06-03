// lib/services/unified/modules/social_recipe/social_recipe_creation_service.dart

import 'dart:async';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
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
  })  : _getCurrentUserId = getCurrentUserId,
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

      // Add initial members with default permissions
      if (initialMembers != null) {
        for (final memberId in initialMembers) {
          permissions[memberId] =
              initialPermissions?[memberId] ?? ResourcePermission.editor;
        }
      }

      // Apply permissions and mark for tagging by the RetaggingScheduler
      final recipeWithPermissions = newRecipe.copyWith(
        tagResult: TagResult.pending(),
        socialData: newRecipe.socialData?.copyWith(
          memberPermissions: permissions,
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
          '✅ Collaborative recipe created: ${recipeWithPermissions.id}');

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
        message ?? 'Operation completed successfully');
  }

  /// Create failure result for operations
  RecipeOperationResult createFailureResult(String error) {
    return RecipeOperationResult.failure(error);
  }
}
