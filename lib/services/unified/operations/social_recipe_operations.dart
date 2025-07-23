/// 🔍 AI INFO BLOCK:
/// Component: Social Recipe Operations - Feature interface for social recipe functionality
/// File: lib/services/unified/operations/social_recipe_operations.dart
/// Quick Guide: Handles all social recipe operations like sharing, comments, and social features
/// Dependencies IN: UnifiedRecipeService, UnifiedRecipe model, SocialRecipeService logic
/// Dependencies OUT: Used by ViewModels for social recipe operations
/// Data flow: ViewModels -> SocialRecipeOperations -> UnifiedRecipeService -> Firebase
/// State management: Delegates to parent UnifiedRecipeService
/// Purpose: Separate social recipe concerns from unified service
/// Common issues: Permission validation, member management, sharing logic
/// Test coverage: Unit tests for sharing and social operations
/// Performance: Real-time updates for shared recipes
/// Analytics: Recipe sharing events, member activity
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedRecipeService, Social ViewModels, Friend services
/// Used in phases: Phase 5 - Service Consolidation

import '../../../models/recipe_unified.dart';
import '../../../models/permissions/resource_permission.dart';
import '../../../models/recipe_comment.dart';
import '../../../core/utils/logger.dart';
import '../../permission_service.dart';
import '../../../core/injection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../notifications/notification_service.dart';
import '../../notifications/notification_types.dart';

/// Social recipe operations feature interface
/// 
/// Handles all operations related to social recipe features:
/// - Recipe sharing and collaboration invitations
/// - Member management for collaborative recipes
/// - Recipe comments and social interactions
/// - Social discovery and recommendations
/// - Integration with legacy social recipe service
class SocialRecipeOperations {
  final dynamic _parent; // UnifiedRecipeService
  late final NotificationService? _notificationService;

  SocialRecipeOperations(this._parent) {
    // Initialize notification service if user is authenticated
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId != null) {
        _notificationService = NotificationService(
          firestore: _parent._firestore,
          userId: currentUserId,
        );
        _notificationService?.initialize();
      } else {
        _notificationService = null;
      }
    } catch (e) {
      AppLogger.warning('⚠️ Could not initialize notification service: $e');
      _notificationService = null;
    }
  }

  // ===== RECIPE SHARING =====

  /// Share a personal recipe with other users
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
      final personalRecipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isPersonal)
          .firstOrNull;
      
      if (personalRecipe == null) {
        AppLogger.error('Cannot share recipe: Recipe not found or not personal');
        return null;
      }

      // Create collaborative version
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

      // Send notifications to all members
      if (collaborativeRecipeId != null) {
        await _sendRecipeSharedNotifications(
          recipeId: collaborativeRecipeId,
          recipeTitle: personalRecipe.title,
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
        );
      }

      return collaborativeRecipeId;
    } catch (e) {
      AppLogger.error('Failed to share recipe', e);
      return null;
    }
  }

  /// Convert collaborative recipe back to personal
  Future<String?> makeRecipePersonal(String collaborativeRecipeId) async {
    try {
      final collaborativeRecipe = _parent.recipes
          .where((r) => r.id == collaborativeRecipeId && r.isCollaborative)
          .firstOrNull;
      
      if (collaborativeRecipe == null) {
        AppLogger.error('Cannot convert recipe: Recipe not found or not collaborative');
        return null;
      }

      // Check if user is owner
      if (collaborativeRecipe.socialData?.ownerId != _parent.currentUserId) {
        AppLogger.error('Cannot convert recipe: User is not owner');
        return null;
      }

      // Create personal version
      final personalRecipeId = await _parent.createPersonalRecipe(
        title: collaborativeRecipe.title,
        description: collaborativeRecipe.description,
        ingredients: collaborativeRecipe.ingredients,
        instructions: collaborativeRecipe.instructions,
        imageUrls: collaborativeRecipe.imageUrls,
        mealType: collaborativeRecipe.mealType,
        portions: collaborativeRecipe.portions,
        timeMinutes: collaborativeRecipe.timeMinutes,
        rating: collaborativeRecipe.rating,
        tags: collaborativeRecipe.tags,
        sourceUrl: '${collaborativeRecipe.sourceUrl} (konverterat från kollaborativt)',
      );

      // Delete collaborative version
      if (personalRecipeId != null) {
        await _parent.deleteRecipe(collaborativeRecipeId);
      }

      return personalRecipeId;
    } catch (e) {
      AppLogger.error('Failed to make recipe personal', e);
      return null;
    }
  }

  // ===== MEMBER MANAGEMENT =====

  /// Add member to collaborative recipe
  Future<bool> addMember({
    required String recipeId,
    required String userId,
    required String userDisplayName,
    ResourcePermission permission = ResourcePermission.editor,
  }) async {
    try {
      final success = await _parent.addMemberToRecipe(recipeId, userId, permission);
      
      // Send notification to the added member
      if (success) {
        await _sendMemberAddedNotification(
          recipeId: recipeId,
          addedUserId: userId,
          addedUserDisplayName: userDisplayName,
        );
      }
      
      return success;
    } catch (e) {
      AppLogger.error('Failed to add member to recipe', e);
      return false;
    }
  }

  /// Remove member from collaborative recipe
  Future<bool> removeMember({
    required String recipeId,
    required String userId,
  }) async {
    try {
      return await _parent.removeMemberFromRecipe(recipeId, userId);
    } catch (e) {
      AppLogger.error('Failed to remove member from recipe', e);
      return false;
    }
  }

  /// Update member permission
  Future<bool> updateMemberPermission({
    required String recipeId,
    required String userId,
    required ResourcePermission permission,
  }) async {
    try {
      return await _parent.updateMemberPermission(recipeId, userId, permission);
    } catch (e) {
      AppLogger.error('Failed to update member permission', e);
      return false;
    }
  }

  /// Get all members of a collaborative recipe
  Map<String, ResourcePermission> getRecipeMembers(String recipeId) {
    final recipe = _parent.recipes
        .where((r) => r.id == recipeId && r.isCollaborative)
        .firstOrNull;
    
    return recipe?.socialData?.memberPermissions ?? {};
  }

  /// Check if user can invite members to recipe
  bool canInviteMembers(String recipeId) {
    final recipe = _parent.recipes
        .where((r) => r.id == recipeId && r.isCollaborative)
        .firstOrNull;
    
    if (recipe == null) return false;
    
    return recipe.socialData?.allowMemberInvites == true && 
           _parent.currentUserId != null &&
           sl<PermissionService>().canManageRecipeMembers(recipeId);
  }

  // ===== SOCIAL DISCOVERY =====

  /// Get all collaborative recipes current user is member of
  List<Recipe> getCollaborativeRecipes() {
    return _parent.collaborativeRecipes;
  }

  /// Get recipes shared with current user
  List<Recipe> getSharedWithMe() {
    if (!sl<PermissionService>().isAuthenticated) return [];
    
    return _parent.collaborativeRecipes
        .where((r) => r.socialData?.ownerId != _parent.currentUserId)
        .toList();
  }

  /// Get recipes owned by current user that are shared
  List<Recipe> getSharedByMe() {
    if (!sl<PermissionService>().isAuthenticated) return [];
    
    return _parent.collaborativeRecipes
        .where((r) => sl<PermissionService>().isRecipeOwner(r.id))
        .toList();
  }

  /// Get recipes by specific user (if accessible)
  List<Recipe> getRecipesByUser(String userId) {
    if (!sl<PermissionService>().isAuthenticated) return [];
    
    return _parent.recipes
        .where((r) => sl<PermissionService>().isOwner(r.socialData?.ownerId ?? r.core.createdBy) && 
          sl<PermissionService>().canViewRecipe(r.id))
        .toList();
  }

  // ===== RECIPE COMMENTS =====

  /// Add comment to recipe
  Future<bool> addComment({
    required String recipeId,
    required String comment,
    String? parentCommentId,
  }) async {
    if (!sl<PermissionService>().isAuthenticated) {
      AppLogger.warning('User must be logged in to comment');
      return false;
    }

    if (comment.trim().isEmpty) {
      AppLogger.warning('Comment text cannot be empty');
      return false;
    }

    try {
      final currentUser = sl<PermissionService>().currentUser;
      if (currentUser == null) return false;

      final recipeComment = RecipeComment.create(
        recipeId: recipeId,
        authorId: currentUser.uid,
        authorDisplayName: currentUser.displayName,
        authorAvatarUrl: currentUser.avatarUrl,
        text: comment.trim(),
        parentCommentId: parentCommentId,
      );

      // Save to Firestore
      await _parent._firestore
          .collection('recipeComments')
          .doc(recipeComment.id)
          .set(recipeComment.toFirestore());

      // If this is a reply, update parent comment's reply count
      if (parentCommentId != null) {
        await _incrementReplyCount(parentCommentId);
      }

      // Send notification for new comment
      await _sendCommentNotification(recipeComment);

      AppLogger.success('✅ Comment added successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to add comment', e);
      return false;
    }
  }

  /// Get comments for recipe
  Future<List<RecipeComment>> getComments(String recipeId) async {
    try {
      final querySnapshot = await _parent._firestore
          .collection('recipeComments')
          .where('recipeId', isEqualTo: recipeId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: false)
          .get();

      final comments = querySnapshot.docs
          .map((doc) => RecipeComment.fromFirestore(doc))
          .toList();

      AppLogger.debug('Loaded ${comments.length} comments for recipe $recipeId');
      return comments;
    } catch (e) {
      AppLogger.error('Failed to get comments', e);
      return [];
    }
  }

  /// Edit comment
  Future<bool> editComment(String commentId, String newText) async {
    if (!sl<PermissionService>().isAuthenticated) {
      AppLogger.warning('User must be logged in to edit comment');
      return false;
    }

    if (newText.trim().isEmpty) {
      AppLogger.warning('Comment text cannot be empty');
      return false;
    }

    try {
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      // Get comment to verify ownership
      final commentDoc = await _parent._firestore
          .collection('recipeComments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        AppLogger.warning('Comment not found: $commentId');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);
      
      if (!comment.canBeEditedBy(currentUserId)) {
        AppLogger.warning('User cannot edit this comment');
        return false;
      }

      // Update comment
      final updatedComment = comment.edit(newText.trim());
      await _parent._firestore
          .collection('recipeComments')
          .doc(commentId)
          .update({
        'text': updatedComment.text,
        'editedAt': updatedComment.editedAt != null 
          ? Timestamp.fromDate(updatedComment.editedAt!) 
          : null,
      });

      AppLogger.success('✅ Comment edited successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to edit comment', e);
      return false;
    }
  }

  /// Delete comment
  Future<bool> deleteComment(String commentId) async {
    if (!sl<PermissionService>().isAuthenticated) {
      AppLogger.warning('User must be logged in to delete comment');
      return false;
    }

    try {
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      // Get comment to verify ownership
      final commentDoc = await _parent._firestore
          .collection('recipeComments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        AppLogger.warning('Comment not found: $commentId');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);
      
      if (!comment.canBeEditedBy(currentUserId) && 
          !sl<PermissionService>().isRecipeOwner(comment.recipeId)) {
        AppLogger.warning('User cannot delete this comment');
        return false;
      }

      // Soft delete comment
      final deletedComment = comment.delete();
      await _parent._firestore
          .collection('recipeComments')
          .doc(commentId)
          .update({
        'text': deletedComment.text,
        'isDeleted': true,
      });

      AppLogger.success('✅ Comment deleted successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete comment', e);
      return false;
    }
  }

  /// Toggle like on comment
  Future<bool> toggleCommentLike(String commentId) async {
    if (!sl<PermissionService>().isAuthenticated) {
      AppLogger.warning('User must be logged in to like comment');
      return false;
    }

    try {
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      // Get current comment
      final commentDoc = await _parent._firestore
          .collection('recipeComments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        AppLogger.warning('Comment not found: $commentId');
        return false;
      }

      final comment = RecipeComment.fromFirestore(commentDoc);
      
      if (comment.isDeleted) {
        AppLogger.warning('Cannot like deleted comment');
        return false;
      }

      // Toggle like
      final updatedComment = comment.isLikedBy(currentUserId)
          ? comment.removeLike(currentUserId)
          : comment.addLike(currentUserId);

      await _parent._firestore
          .collection('recipeComments')
          .doc(commentId)
          .update({
        'likedByUserIds': updatedComment.likedByUserIds,
      });

      AppLogger.success('✅ Comment like toggled successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to toggle comment like', e);
      return false;
    }
  }

  /// Stream comments for recipe (real-time)
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    return _parent._firestore
        .collection('recipeComments')
        .where('recipeId', isEqualTo: recipeId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecipeComment.fromFirestore(doc))
            .toList());
  }

  /// Helper: Increment reply count for parent comment
  Future<void> _incrementReplyCount(String parentCommentId) async {
    await _parent._firestore
        .collection('recipeComments')
        .doc(parentCommentId)
        .update({
      'replyCount': FieldValue.increment(1),
    });
  }

  // ===== RECIPE RATING & SOCIAL STATS =====

  /// Rate a recipe
  Future<bool> rateRecipe({
    required String recipeId,
    required double rating,
  }) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;

      // For collaborative recipes, we might want to track individual ratings
      // For now, update the recipe's rating
      return await _parent.updateRecipeContent(
        recipeId: recipeId,
        rating: rating,
      );
    } catch (e) {
      AppLogger.error('Failed to rate recipe', e);
      return false;
    }
  }

  /// Get social stats for recipe
  Map<String, dynamic> getRecipeStats(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return {};

    return {
      'memberCount': recipe.isCollaborative ? (recipe.socialData?.memberPermissions?.length ?? 1) : 1,
      'lastActivity': recipe.updatedAt,
      'lastEditedBy': recipe.realtimeData?.lastEditedByDisplayName ?? 'Unknown',
      'viewsCount': 0, // To be implemented
      'rating': recipe.rating,
      'isCollaborative': recipe.isCollaborative,
      'allowGuestViewing': recipe.isCollaborative ? (recipe.socialData?.allowGuestViewing ?? false) : false,
    };
  }

  // ===== LEGACY COMPATIBILITY =====

  /// Convert to legacy SharedRecipe format
  List<Map<String, dynamic>> getLegacySharedRecipes() {
    try {
      return getSharedWithMe().map((recipe) {
        return {
          'id': recipe.id,
          'title': recipe.title,
          'description': recipe.description,
          'ownerId': recipe.socialData?.ownerId ?? recipe.core.createdBy,
          'ownerDisplayName': recipe.socialData?.ownerDisplayName ?? 'Unknown',
          'sharedAt': recipe.createdAt.toIso8601String(),
          'permissions': {_parent.currentUserId!: 'view'}, // Simplified
          'recipe': recipe.toJson(),
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get legacy shared recipes', e);
      return [];
    }
  }

  /// Mark shared recipe as viewed (legacy compatibility)
  Future<void> markSharedRecipeAsViewed(String recipeId) async {
    try {
      // This would update view tracking
      AppLogger.info('Marking recipe $recipeId as viewed');
    } catch (e) {
      AppLogger.error('Failed to mark recipe as viewed', e);
    }
  }

  // ===== PERMISSION HELPERS =====

  /// Check if current user can edit recipe
  bool canEdit(String recipeId) {
    return sl<PermissionService>().canEditRecipe(recipeId);
  }

  /// Check if current user can view recipe
  bool canView(String recipeId) {
    return sl<PermissionService>().canViewRecipe(recipeId);
  }

  /// Check if current user can manage members
  bool canManageMembers(String recipeId) {
    return sl<PermissionService>().canInviteToRecipe(recipeId);
  }

  /// Check if current user can delete recipe
  bool canDelete(String recipeId) {
    return sl<PermissionService>().canDeleteRecipe(recipeId);
  }

  // ===== NOTIFICATION HELPERS =====

  /// Send notifications when recipe is shared with members
  Future<void> _sendRecipeSharedNotifications({
    required String recipeId,
    required String recipeTitle,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
  }) async {
    if (_notificationService == null) {
      AppLogger.debug('Notification service not available - skipping recipe shared notifications');
      return;
    }

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null) return;

    try {
      // Send notification to each member
      for (final memberId in memberIds) {
        if (memberId == currentUserId) continue; // Don't notify the owner

        await _notificationService.sendImmediateNotification(
          targetUserIds: [memberId],
          strategy: NotificationStrategy.recipeShared,
          variables: {
            'senderName': currentUserDisplayName,
            'recipeName': recipeTitle,
          },
          additionalData: {
            'recipeId': recipeId,
            'sharerUserId': currentUserId,
            'memberDisplayName': memberDisplayNames[memberId] ?? 'Unknown',
          },
        );
      }

      AppLogger.success('Recipe shared notifications sent to ${memberIds.length} members');
    } catch (e) {
      AppLogger.warning('Failed to send recipe shared notifications: $e');
    }
  }

  /// Send notification when member is added to collaborative recipe
  Future<void> _sendMemberAddedNotification({
    required String recipeId,
    required String addedUserId,
    required String addedUserDisplayName,
  }) async {
    if (_notificationService == null) {
      AppLogger.debug('Notification service not available - skipping member added notification');
      return;
    }

    final currentUserId = _parent.currentUserId;
    final currentUserDisplayName = _parent.currentUserDisplayName ?? 'Unknown User';

    if (currentUserId == null || addedUserId == currentUserId) return;

    // Get recipe title for notification
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    final recipeTitle = recipe?.title ?? 'Unknown Recipe';

    try {
      await _notificationService.sendImmediateNotification(
        targetUserIds: [addedUserId],
        strategy: NotificationStrategy.collaborationInvite,
        variables: {
          'senderName': currentUserDisplayName,
          'resourceName': recipeTitle,
        },
        additionalData: {
          'recipeId': recipeId,
          'inviterUserId': currentUserId,
          'inviteeDisplayName': addedUserDisplayName,
        },
      );

      AppLogger.success('Member added notification sent to $addedUserDisplayName');
    } catch (e) {
      AppLogger.warning('Failed to send member added notification: $e');
    }
  }

  /// Send notification when comment is added to recipe
  Future<void> _sendCommentNotification(RecipeComment comment) async {
    if (_notificationService == null) {
      AppLogger.debug('Notification service not available - skipping comment notification');
      return;
    }

    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return;

    // Get recipe to find owner and members
    final recipe = _parent.recipes.where((r) => r.id == comment.recipeId).firstOrNull;
    if (recipe == null) return;

    try {
      final notificationTargets = <String>{};

      // Notify recipe owner if comment is not from owner
      final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
      if (ownerId != currentUserId) {
        notificationTargets.add(ownerId);
      }

      // Notify all collaborative members (except commenter)
      if (recipe.isCollaborative && recipe.socialData?.memberPermissions != null) {
        for (final memberId in recipe.socialData!.memberPermissions!.keys) {
          if (memberId != currentUserId) {
            notificationTargets.add(memberId);
          }
        }
      }

      // Send notifications to all targets using batchable notification
      for (final targetUserId in notificationTargets) {
        await _notificationService.sendBatchableNotification(
          targetUserIds: [targetUserId],
          strategy: NotificationStrategy.recipeComment,
          variables: {
            'count': '1', // Individual comment count, will be batched
          },
          additionalData: {
            'recipeId': comment.recipeId,
            'recipeTitle': recipe.title,
            'commentId': comment.id,
            'commenterUserId': comment.authorId,
            'commenterDisplayName': comment.authorDisplayName,
            'commentText': comment.text.length > 100 
                ? '${comment.text.substring(0, 100)}...' 
                : comment.text,
            'isReply': comment.parentCommentId != null,
          },
        );
      }

      AppLogger.success('Comment notifications sent to ${notificationTargets.length} recipients');
    } catch (e) {
      AppLogger.warning('Failed to send comment notification: $e');
    }
  }
}

// RecipePermission is now imported from ../types/recipe_types.dart