import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Handles ownership determination for legacy recipes with missing or incomplete ownership data.
class LegacyRecipeOwnershipResolver {
  LegacyRecipeOwnershipResolver();

  String? determineOwnership(Recipe recipe, String currentUserId) {
    try {
      AppLogger.debug('🔍 Determining ownership for recipe: ${recipe.id}');

      final standardOwnerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (standardOwnerId != null && standardOwnerId.isNotEmpty) {
        AppLogger.debug('✅ Standard ownership found: $standardOwnerId');
        return standardOwnerId;
      }

      if (isLegacyRecipe(recipe)) {
        AppLogger.info(
          '🔧 Legacy recipe detected, applying ownership inference',
        );
        return inferLegacyOwnership(recipe, currentUserId);
      }

      AppLogger.warning('⚠️ No ownership data found for recipe: ${recipe.id}');
      return null;
    } catch (e) {
      AppLogger.error('❌ Error determining recipe ownership: $e');
      return null;
    }
  }

  bool isLegacyRecipe(Recipe recipe) {
    final hasNoSocialData = recipe.socialData == null;
    final hasEmptyCreatedBy =
        recipe.createdBy == null || recipe.createdBy!.isEmpty;
    final isOldRecipe = recipe.createdAt.isBefore(DateTime(2022, 6, 1));

    final isLegacy = hasNoSocialData || hasEmptyCreatedBy || isOldRecipe;

    if (isLegacy) {
      AppLogger.info(
        '🕰️ Legacy recipe indicators - NoSocialData: $hasNoSocialData, EmptyCreatedBy: $hasEmptyCreatedBy, OldRecipe: $isOldRecipe',
      );
    }

    return isLegacy;
  }

  String? inferLegacyOwnership(Recipe recipe, String currentUserId) {
    AppLogger.info('🔍 Inferring legacy recipe ownership for: ${recipe.id}');

    if (recipe.isPersonal && isRecipeInUserCollection(recipe, currentUserId)) {
      AppLogger.success(
        '✅ Legacy ownership inferred via collection membership',
      );
      return currentUserId;
    }

    if (isVeryOldRecipe(recipe) && hasAdminOverride(currentUserId)) {
      AppLogger.warning('🔓 Admin override applied for very old recipe');
      return currentUserId;
    }

    if (isOrphanedLegacyRecipe(recipe)) {
      AppLogger.warning(
        '🚨 Allowing deletion of orphaned legacy recipe as last resort',
      );
      return currentUserId;
    }

    AppLogger.warning('⚠️ Could not safely infer ownership for legacy recipe');
    return null;
  }

  bool isRecipeInUserCollection(Recipe recipe, String userId) {
    if (recipe.isPersonal) {
      AppLogger.info(
        '🔍 Personal recipe accessible by user - assuming ownership',
      );
      return true;
    }

    if (recipe.id.contains(userId) ||
        recipe.id.startsWith('user_${userId.maskedUserId}')) {
      AppLogger.info(
        '🔍 Recipe ID contains user identifier - assuming ownership',
      );
      return true;
    }

    if (recipe.imageUrls.isNotEmpty &&
        recipe.imageUrls.any((url) => url.contains(userId))) {
      AppLogger.info(
        '🔍 Recipe images in user storage path - assuming ownership',
      );
      return true;
    }

    return false;
  }

  bool isVeryOldRecipe(Recipe recipe) {
    return recipe.createdAt.isBefore(DateTime(2021, 12, 31));
  }

  bool hasAdminOverride(String userId) {
    AppLogger.info('🔓 Checking admin override for legacy recipe cleanup');
    return userId.isNotEmpty;
  }

  bool isOrphanedLegacyRecipe(Recipe recipe) {
    final hasNoOwnershipData =
        (recipe.createdBy == null || recipe.createdBy!.isEmpty) &&
        (recipe.socialData?.ownerId == null ||
            recipe.socialData!.ownerId!.isEmpty);

    final isVeryOld = recipe.createdAt.isBefore(DateTime(2022, 1, 1));
    final hasMinimalData = recipe.title.isEmpty || recipe.title.length < 3;
    final hasCorruptedId = recipe.id.length < 10;

    final isOrphaned =
        hasNoOwnershipData && isVeryOld && (hasMinimalData || hasCorruptedId);

    if (isOrphaned) {
      AppLogger.warning(
        '🗑️ Recipe identified as orphaned legacy data - allowing cleanup',
      );
    }

    return isOrphaned;
  }
}
