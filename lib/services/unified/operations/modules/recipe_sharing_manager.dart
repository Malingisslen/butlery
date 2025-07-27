// lib/services/unified/operations/modules/recipe_sharing_manager.dart

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';

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
  final dynamic _parent; // UnifiedRecipeService
  final NotificationService? _notificationService;

  RecipeSharingManager(this._parent, this._notificationService);

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

      // Find the personal recipe to share
      final personalRecipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isPersonal)
          .firstOrNull;
      
      if (personalRecipe == null) {
        AppLogger.error('❌ Cannot share recipe: Recipe not found or not personal');
        return null;
      }

      AppLogger.info('📋 Found personal recipe: ${personalRecipe.title}');

      // Create collaborative version with all recipe data
      final collaborativeRecipeId = await _parent.createCollaborativeRecipe(
        title: personalRecipe.title,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
        description: personalRecipe.description,
        ingredients: personalRecipe.ingredients,
        instructions: personalRecipe.instructions,
        imageUrls: personalRecipe.imageUrls,
        mealType: personalRecipe.mealType,
        portions: personalRecipe.portions,
        timeMinutes: personalRecipe.timeMinutes,
        rating: personalRecipe.rating,
        tags: personalRecipe.tags,
        sourceUrl: personalRecipe.sourceUrl,
        descriptionCollaborative: collaborativeDescription,
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: allowMemberInvites,
        categoryIds: categoryIds,
      );

      if (collaborativeRecipeId == null) {
        AppLogger.error('❌ Failed to create collaborative recipe');
        return null;
      }

      AppLogger.success('✅ Created collaborative recipe: $collaborativeRecipeId');

      // Send sharing notifications to all members
      await _sendSharingNotifications(
        collaborativeRecipeId: collaborativeRecipeId,
        recipeTitle: personalRecipe.title,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
      );

      AppLogger.success('✅ Recipe sharing completed successfully');
      return collaborativeRecipeId;
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
      AppLogger.info('🔄 Converting collaborative recipe to personal: $collaborativeRecipeId');

      // Find the collaborative recipe
      final collaborativeRecipe = _parent.recipes
          .where((r) => r.id == collaborativeRecipeId && r.isCollaborative)
          .firstOrNull;
      
      if (collaborativeRecipe == null) {
        AppLogger.error('❌ Cannot convert recipe: Collaborative recipe not found');
        return null;
      }

      AppLogger.info('📋 Found collaborative recipe: ${collaborativeRecipe.title}');

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
    if (_notificationService == null) {
      AppLogger.warning('⚠️ No notification service available, skipping sharing notifications');
      return;
    }

    try {
      AppLogger.info('📬 Sending sharing notifications to ${memberIds.length} members');

      // Get current user display name for notification
      final currentUserId = _parent.currentUserId;
      final currentUserName = _parent.currentUserDisplayName ?? 'En vän';

      // Send notifications to all invited members
      await _notificationService.sendImmediateNotification(
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

      AppLogger.success('✅ Sharing notifications sent successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to send sharing notifications', e);
      // Don't rethrow - sharing succeeded even if notifications failed
    }
  }

  /// Send notification when recipe sharing is enabled for existing recipe
  Future<void> sendCollaborationEnabledNotification({
    required String recipeId,
    required String recipeTitle,
    required List<String> memberIds,
  }) async {
    if (_notificationService == null) return;

    try {
      final currentUserName = _parent.currentUserDisplayName ?? 'En användare';

      await _notificationService.sendImmediateNotification(
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

      AppLogger.info('📬 Sent collaboration enabled notifications');
    } catch (e) {
      AppLogger.error('❌ Failed to send collaboration enabled notification', e);
    }
  }

  // ===== HELPER METHODS =====

  /// Duplicate a personal recipe (used internally)
  Future<String?> _duplicatePersonalRecipe({
    required String recipeId,
    String? newTitle,
  }) async {
    try {
      final originalRecipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isPersonal)
          .firstOrNull;
      
      if (originalRecipe == null) {
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
      final userRecipes = _parent.recipes.where((r) => 
          r.userId == _parent.currentUserId).toList();

      final personalRecipes = userRecipes.where((r) => r.isPersonal).length;
      final collaborativeRecipes = userRecipes.where((r) => r.isCollaborative).length;
      final sharedRecipes = userRecipes.where((r) => 
          r.isCollaborative && (r.memberIds?.isNotEmpty ?? false)).length;

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
}