import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Handles validation and audit logging for legacy recipes with missing ownership data.
/// Extracted from FirebaseRecipeRepository to isolate legacy-specific logic that may be
/// deprecated in the future.
class RecipeLegacyValidator {
  final FirebaseFirestore firestore;
  final Future<DocumentSnapshot<Map<String, dynamic>>> Function(String userId, String recipeId)
      getUserRecipeDoc;
  final Future<void> Function({
    required String currentUserId,
    required String resourceOwnerId,
    required String resourceType,
    required String resourceId,
  }) validateOwnership;

  RecipeLegacyValidator({
    required this.firestore,
    required this.getUserRecipeDoc,
    required this.validateOwnership,
  });

  /// Check if a recipe is a legacy recipe with missing ownership data.
  bool isLegacyRecipe(Recipe recipe) {
    // Legacy indicators:
    // 1. No socialData structure at all
    // 2. Empty or null createdBy field
    // 3. Created before social data structure was implemented (before 2022-06-01)
    final hasNoSocialData = recipe.socialData == null;
    final hasEmptyCreatedBy =
        recipe.createdBy == null || recipe.createdBy!.isEmpty;
    final isOldRecipe = recipe.createdAt.isBefore(DateTime(2022, 6, 1));

    final isLegacy = hasNoSocialData || hasEmptyCreatedBy || isOldRecipe;

    if (isLegacy) {
      AppLogger.info(
          '🕰️ Legacy recipe detected: ${recipe.id} - NoSocialData: $hasNoSocialData, EmptyCreatedBy: $hasEmptyCreatedBy, OldRecipe: $isOldRecipe');
    }

    return isLegacy;
  }

  /// Enhanced deletion validation with legacy recipe support.
  Future<bool> validateDeletionWithLegacySupport(
    Recipe recipe,
    String currentUserId,
    String recipeId,
    bool isLegacy,
    String Function(Recipe) getOwnerId,
  ) async {
    try {
      if (!isLegacy) {
        // Standard validation for modern recipes
        final ownerId = getOwnerId(recipe);
        if (ownerId.isEmpty) {
          AppLogger.warning('⚠️ Modern recipe missing owner data: $recipeId');
          return false;
        }

        await validateOwnership(
          currentUserId: currentUserId,
          resourceOwnerId: ownerId,
          resourceType: 'recipe',
          resourceId: recipeId,
        );
        return true;
      } else {
        // Legacy recipe validation with fallback strategies
        return await _validateLegacyDeletion(recipe, currentUserId, recipeId);
      }
    } catch (e) {
      AppLogger.error('❌ Recipe deletion validation failed: $e');
      return false;
    }
  }

  /// Validate deletion for legacy recipes using multiple strategies.
  Future<bool> _validateLegacyDeletion(
    Recipe recipe,
    String currentUserId,
    String recipeId,
  ) async {
    AppLogger.info('🔍 Validating legacy recipe deletion: $recipeId');

    // Strategy 1: Check document path for ownership
    // If recipe is in user's personal collection, they own it
    try {
      final userRecipeDoc = await getUserRecipeDoc(currentUserId, recipeId);

      if (userRecipeDoc.exists) {
        AppLogger.success(
            '✅ Legacy recipe found in user collection - ownership confirmed');
        return true;
      }
    } catch (e) {
      AppLogger.error('❌ Error checking user collection: $e');
    }

    // Strategy 2: For personal recipes, if user can access it, they likely own it
    if (recipe.isPersonal) {
      AppLogger.warning(
          '🔧 Legacy personal recipe - inferring ownership from access');
      return true; // If they can load a personal recipe, they likely own it
    }

    // Strategy 3: Check for any ownership hints in the recipe data
    final hasAnyOwnershipHint = _hasOwnershipHints(recipe, currentUserId);
    if (hasAnyOwnershipHint) {
      AppLogger.warning('🔧 Legacy recipe ownership inferred from hints');
      return true;
    }

    // Strategy 4: Check creation metadata (if available)
    if (await _checkCreationMetadata(recipe, currentUserId)) {
      AppLogger.warning('🔧 Legacy recipe ownership confirmed via metadata');
      return true;
    }

    AppLogger.error(
        '❌ Could not validate ownership for legacy recipe: $recipeId');
    return false;
  }

  /// Check for ownership hints in legacy recipe data.
  bool _hasOwnershipHints(Recipe recipe, String currentUserId) {
    // Look for any field that might indicate ownership

    // Check if imageUrls contain user-specific paths
    if (recipe.imageUrls.isNotEmpty) {
      final hasUserPath =
          recipe.imageUrls.any((url) => url.contains(currentUserId));
      if (hasUserPath) {
        AppLogger.debug('🔍 Found user ID in image paths');
        return true;
      }
    }

    // Check if recipe metadata contains user references
    if (recipe.realtimeData?.lastEditedByUserId == currentUserId) {
      AppLogger.debug('🔍 Found user as last editor');
      return true;
    }

    return false;
  }

  /// Check Firebase document creation metadata for ownership clues.
  Future<bool> _checkCreationMetadata(
      Recipe recipe, String currentUserId) async {
    try {
      // This is a future enhancement - checking Firebase document metadata
      // for now, return false as we don't have access to creation metadata
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Log legacy recipe deletion for audit purposes.
  Future<void> logLegacyDeletion(Recipe recipe, String currentUserId) async {
    try {
      final auditData = {
        'action': 'legacy_recipe_deletion',
        'recipeId': recipe.id,
        'userId': currentUserId,
        'recipeTitle': recipe.title,
        'createdAt': recipe.createdAt.toIso8601String(),
        'legacyReasons': {
          'hasNoSocialData': recipe.socialData == null,
          'hasEmptyCreatedBy':
              recipe.createdBy == null || recipe.createdBy!.isEmpty,
          'isOldRecipe': recipe.createdAt.isBefore(DateTime(2022, 6, 1)),
        },
        'deletedAt': DateTime.now().toIso8601String(),
      };

      // Log to Firebase audit collection for tracking
      await firestore
          .collection('audit_logs')
          .doc('legacy_recipe_deletions')
          .collection('deletions')
          .add(auditData);

      AppLogger.info(
          '📋 Legacy recipe deletion logged for audit: ${recipe.id}');
    } catch (e) {
      AppLogger.error('❌ Failed to log legacy recipe deletion: $e');
      // Don't fail deletion due to logging issues
    }
  }
}
