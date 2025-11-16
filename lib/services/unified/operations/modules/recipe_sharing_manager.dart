// lib/services/unified/operations/modules/recipe_sharing_manager.dart

// ignore: unused_import
import 'package:collection/collection.dart'; // Needed for .firstOrNull on dynamic _parent fields
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/notification_helper.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firestore_repository.dart';

/// Focused module for recipe sharing and collaboration setup
///
/// This module handles ONLY recipe sharing responsibilities:
/// - Converting personal recipes to collaborative format
/// - Converting collaborative recipes back to personal format
/// - Share state management and validation
/// - Basic sharing notifications and member alerts
/// - Share metadata and collaboration settings
///
/// ❌ DOES NOT CONTAIN: Member management, comments, discovery, ratings, permissions
class RecipeSharingManager {
  final UnifiedRecipeService _parent;
  final NotificationService? _notificationService;
  final FirestoreRepository _firestoreRepository;

  RecipeSharingManager(
    this._parent,
    this._notificationService, {
    FirestoreRepository? firestoreRepository,
  }) : _firestoreRepository =
            firestoreRepository ?? ServiceLocator.get<FirestoreRepository>();

  // ===== RECIPE SHARING CONVERSION =====

  /// Share a personal recipe with other users (convert to collaborative)
  ///
  /// Main entry point for recipe sharing - converts personal recipe to collaborative format
  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    try {
      AppLogger.info('🔄 Starting recipe share process for recipe: $recipeId');

      // Find the recipe to share (personal OR collaborative)
      dynamic recipeToShare;
      bool isAlreadyCollaborative = false;

      try {
        // Try personal recipe first
        recipeToShare =
            _parent.recipes.firstWhere((r) => r.id == recipeId && r.isPersonal);
        AppLogger.info('📋 Found personal recipe: ${recipeToShare.title}');
      } catch (e) {
        // If not personal, try collaborative
        try {
          recipeToShare = _parent.recipes
              .firstWhere((r) => r.id == recipeId && r.isCollaborative);
          isAlreadyCollaborative = true;
          AppLogger.info(
              '📋 Found collaborative recipe: ${recipeToShare.title}');
        } catch (e2) {
          AppLogger.error('❌ Recipe not found: $recipeId');
          return null;
        }
      }

      String finalRecipeId;

      if (isAlreadyCollaborative) {
        // For collaborative recipes, just sync to shared_recipes collection
        AppLogger.info('🔄 Re-sharing collaborative recipe to group');
        await _syncCollaborativeRecipeToSharedCollection(
          recipe: recipeToShare,
          memberIds: memberIds,
        );
        finalRecipeId = recipeId;
        AppLogger.success('✅ Collaborative recipe synced to shared collection');
      } else {
        // Create collaborative version for personal recipes
        finalRecipeId = await _parent.createCollaborativeRecipe(
              title: recipeToShare.title,
              memberIds: memberIds,
              description: recipeToShare.description,
              ingredients: recipeToShare.ingredients,
              instructions: recipeToShare.instructions,
              imageUrls: recipeToShare.imageUrls,
              mealType: recipeToShare.mealType,
              portions: recipeToShare.portions,
              timeMinutes: recipeToShare.timeMinutes,
              rating: recipeToShare.rating,
              tags: recipeToShare.tags,
              sourceUrl: recipeToShare.sourceUrl,
              descriptionCollaborative: collaborativeDescription,
              allowGuestViewing: allowGuestViewing,
              allowMemberInvites: allowMemberInvites,
              categoryIds: categoryIds,
            ) ??
            '';

        if (finalRecipeId.isEmpty) {
          AppLogger.error('❌ Failed to create collaborative recipe');
          return null;
        }

        AppLogger.success('✅ Created collaborative recipe: $finalRecipeId');

        // Write to shared_recipes collection for group discoverability
        await _writeToSharedRecipesCollection(
          recipeId: finalRecipeId,
          recipeTitle: recipeToShare.title,
          memberIds: memberIds,
          recipeData: recipeToShare,
        );
      }

      // Send sharing notifications to all members
      await _sendSharingNotifications(
        collaborativeRecipeId: finalRecipeId,
        recipeTitle: recipeToShare.title,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
      );

      AppLogger.success('✅ Recipe sharing completed successfully');
      return finalRecipeId;
    } catch (e) {
      AppLogger.error('❌ Failed to share recipe', e);
      return null;
    }
  }

  /// Convert collaborative recipe back to personal format
  ///
  /// Allows users to take ownership of collaborative recipes as personal copies
  Future<String?> makeRecipePersonal({
    required String collaborativeRecipeId,
    String? newTitle,
  }) async {
    try {
      AppLogger.info(
          '🔄 Converting collaborative recipe to personal: $collaborativeRecipeId');

      // Find the collaborative recipe
      dynamic collaborativeRecipe;
      try {
        collaborativeRecipe = _parent.recipes.firstWhere(
            (r) => r.id == collaborativeRecipeId && r.isCollaborative);
      } catch (e) {
        AppLogger.error(
            '❌ Cannot convert recipe: Collaborative recipe not found');
        return null;
      }

      AppLogger.info(
          '📋 Found collaborative recipe: ${collaborativeRecipe.title}');

      // Create personal copy with new title if provided
      final personalRecipeId = await _parent.createPersonalRecipe(
        title: newTitle ?? '${collaborativeRecipe.title} (Min kopia)',
        description: collaborativeRecipe.description,
        ingredients: collaborativeRecipe.ingredients,
        instructions: collaborativeRecipe.instructions,
        imageUrls: collaborativeRecipe.imageUrls,
        mealType: collaborativeRecipe.mealType,
        portions: collaborativeRecipe.portions,
        timeMinutes: collaborativeRecipe.timeMinutes,
        rating: collaborativeRecipe.rating,
        tags: collaborativeRecipe.tags,
        sourceUrl: collaborativeRecipe.sourceUrl,
      );

      if (personalRecipeId == null) {
        AppLogger.error('❌ Failed to create personal copy of recipe');
        return null;
      }

      AppLogger.success('✅ Created personal copy: $personalRecipeId');

      // Log the conversion for analytics
      _logRecipeConversion(
        originalId: collaborativeRecipeId,
        newId: personalRecipeId,
        conversionType: 'collaborative_to_personal',
      );

      return personalRecipeId;
    } catch (e) {
      AppLogger.error('❌ Failed to convert recipe to personal', e);
      return null;
    }
  }

  /// Duplicate personal recipe for sharing (creates copy before conversion)
  ///
  /// Useful when user wants to keep original personal recipe and share a copy
  Future<String?> duplicateAndShareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? newTitle,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    try {
      AppLogger.info('🔄 Duplicating and sharing recipe: $recipeId');

      // First, create a duplicate of the personal recipe
      final duplicateId = await _duplicatePersonalRecipe(
        recipeId: recipeId,
        newTitle: newTitle,
      );

      if (duplicateId == null) {
        AppLogger.error('❌ Failed to duplicate recipe for sharing');
        return null;
      }

      // Then share the duplicate
      return await shareRecipe(
        recipeId: duplicateId,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
        collaborativeDescription: collaborativeDescription,
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: allowMemberInvites,
        categoryIds: categoryIds,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to duplicate and share recipe', e);
      return null;
    }
  }

  // ===== SHARING NOTIFICATIONS =====

  /// Send sharing notifications to all members
  Future<void> _sendSharingNotifications({
    required String collaborativeRecipeId,
    required String recipeTitle,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
  }) async {
    AppLogger.info(
        '📬 Sending sharing notifications to ${memberIds.length} members');

    // Get current user display name for notification
    final currentUserId = _parent.currentUserId;
    final currentUserName = _parent.currentUserDisplayName ?? 'En vän';

    // Send notifications to all invited members using safe helper
    await NotificationHelper.sendImmediateSafely(
      notificationService: _notificationService,
      operationName: 'Send recipe sharing notifications',
      targetUserIds: memberIds,
      strategy: NotificationStrategy.recipeShared,
      variables: {
        'senderName': currentUserName,
        'recipeName': recipeTitle,
      },
      additionalData: {
        'collaborativeRecipeId': collaborativeRecipeId,
        'action': 'recipe_shared',
        'senderUserId': currentUserId,
      },
      actions: [
        NotificationAction.viewRecipe,
      ],
    );
  }

  /// Send notification when recipe sharing is enabled for existing recipe
  Future<void> sendCollaborationEnabledNotification({
    required String recipeId,
    required String recipeTitle,
    required List<String> memberIds,
  }) async {
    final currentUserName = _parent.currentUserDisplayName ?? 'En användare';

    await NotificationHelper.sendImmediateSafely(
      notificationService: _notificationService,
      operationName: 'Send collaboration enabled notification',
      targetUserIds: memberIds,
      strategy: NotificationStrategy.collaborationEnabled,
      variables: {
        'enablerName': currentUserName,
        'recipeTitle': recipeTitle,
      },
      additionalData: {
        'recipeId': recipeId,
        'action': 'collaboration_enabled',
      },
    );
  }

  // ===== HELPER METHODS =====

  /// Duplicate a personal recipe (used internally)
  Future<String?> _duplicatePersonalRecipe({
    required String recipeId,
    String? newTitle,
  }) async {
    try {
      dynamic originalRecipe;
      try {
        originalRecipe =
            _parent.recipes.firstWhere((r) => r.id == recipeId && r.isPersonal);
      } catch (e) {
        AppLogger.error('❌ Cannot duplicate: Recipe not found');
        return null;
      }

      return await _parent.createPersonalRecipe(
        title: newTitle ?? '${originalRecipe.title} (Kopia)',
        description: originalRecipe.description,
        ingredients: originalRecipe.ingredients,
        instructions: originalRecipe.instructions,
        imageUrls: originalRecipe.imageUrls,
        mealType: originalRecipe.mealType,
        portions: originalRecipe.portions,
        timeMinutes: originalRecipe.timeMinutes,
        rating: originalRecipe.rating,
        tags: originalRecipe.tags,
        sourceUrl: originalRecipe.sourceUrl,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to duplicate recipe', e);
      return null;
    }
  }

  /// Validate sharing parameters
  bool validateSharingParams({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
  }) {
    if (recipeId.isEmpty) {
      AppLogger.error('❌ Recipe ID cannot be empty');
      return false;
    }

    if (memberIds.isEmpty) {
      AppLogger.error('❌ Must specify at least one member to share with');
      return false;
    }

    if (memberIds.length != memberDisplayNames.length) {
      AppLogger.error('❌ Member IDs and display names count mismatch');
      return false;
    }

    // Check for duplicate member IDs
    if (memberIds.toSet().length != memberIds.length) {
      AppLogger.error('❌ Duplicate member IDs in sharing list');
      return false;
    }

    return true;
  }

  /// Sync collaborative recipe to shared_recipes collection
  /// Used when re-sharing an already collaborative recipe
  Future<void> _syncCollaborativeRecipeToSharedCollection({
    required dynamic recipe,
    required List<String> memberIds,
  }) async {
    try {
      AppLogger.info('🔄 Syncing collaborative recipe to shared collection');

      // Get existing members from recipe permissions
      final existingMembers =
          recipe.socialData?.memberPermissions?.keys.toList() ?? [];

      // Write to shared_recipes collection with all members included
      await _writeToSharedRecipesCollection(
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        memberIds: [
          ...existingMembers,
          ...memberIds
        ], // Combine existing + new members
        recipeData: recipe,
      );

      AppLogger.success('✅ Collaborative recipe synced to shared collection');
    } catch (e) {
      AppLogger.error('❌ Failed to sync collaborative recipe', e);
      rethrow;
    }
  }

  /// Log recipe conversion for analytics
  void _logRecipeConversion({
    required String originalId,
    required String newId,
    required String conversionType,
  }) {
    try {
      AppLogger.info('📊 Recipe conversion logged: $conversionType');
      // This could be expanded to send analytics events
      // Analytics.logEvent('recipe_conversion', {
      //   'originalId': originalId,
      //   'newId': newId,
      //   'type': conversionType,
      //   'userId': _parent.currentUserId,
      // });
    } catch (e) {
      AppLogger.warning('⚠️ Failed to log recipe conversion: $e');
    }
  }

  /// Get sharing statistics for current user
  Map<String, dynamic> getSharingStats() {
    try {
      final userRecipes = _parent.recipes
          .where((r) => r.createdBy == _parent.currentUserId)
          .toList();

      final personalRecipes = userRecipes.where((r) => r.isPersonal).length;
      final collaborativeRecipes =
          userRecipes.where((r) => r.isCollaborative).length;
      final sharedRecipes = userRecipes
          .where((r) =>
              r.isCollaborative &&
              (r.socialData?.memberPermissions?.isNotEmpty ?? false))
          .length;

      return {
        'total_recipes': userRecipes.length,
        'personal_recipes': personalRecipes,
        'collaborative_recipes': collaborativeRecipes,
        'shared_recipes': sharedRecipes,
        'sharing_ratio': userRecipes.isNotEmpty
            ? (sharedRecipes / userRecipes.length * 100).round()
            : 0,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get sharing stats', e);
      return {'error': 'Failed to calculate stats'};
    }
  }

  /// Write to shared_recipes collection for group discoverability
  /// This allows groups to query and discover shared recipes in their feed
  Future<void> _writeToSharedRecipesCollection({
    required String recipeId,
    required String recipeTitle,
    required List<String> memberIds,
    required dynamic recipeData,
  }) async {
    try {
      final permissionService = ServiceLocator.get<PermissionService>();

      final currentUserId = permissionService.currentUserId;
      if (currentUserId == null) {
        AppLogger.warning(
            'Cannot write to shared_recipes: No authenticated user');
        return;
      }

      // Ensure owner is included in sharedWithUserIds along with members
      final allUserIds = {currentUserId, ...memberIds}.toList();

      await _firestoreRepository
          .collection('shared_recipes')
          .doc(recipeId)
          .set({
        'recipeId': recipeId,
        'title': recipeTitle,
        'description': recipeData.description ?? '',
        'sharedByUserId': currentUserId,
        'sharedByDisplayName':
            permissionService.currentUser?.displayName ?? 'Unknown',
        'sharedByAvatarUrl': permissionService.currentUser?.avatarUrl,
        'sharedWithUserIds': allUserIds,
        'sharedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'imageUrl': recipeData.imageUrls?.isNotEmpty == true
            ? recipeData.imageUrls.first
            : null,
        'mealType': recipeData.mealType ?? '',
      }, SetOptions(merge: true));

      AppLogger.debug(
          '✅ Recipe written to shared_recipes collection for group discovery');
    } catch (e) {
      AppLogger.warning('Failed to write to shared_recipes collection: $e');
      // Don't fail the whole sharing operation if this fails
    }
  }
}
