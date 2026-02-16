// lib/services/unified/operations/modules/comment_notifications.dart

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/notification_helper.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';

/// Focused module for comment notification system
/// This module handles ONLY comment-related notifications:
/// - New comment notifications to recipe members
/// - Mention notifications in comments
/// - Reply notifications to parent comment authors
/// - Notification targeting and batching
/// ❌ DOES NOT CONTAIN: Comment content, likes, CRUD operations, statistics
class CommentNotifications {
  /// Send notifications for new comments
  static Future<void> sendCommentNotifications({
    required NotificationService? notificationService,
    required Recipe recipe,
    required RecipeComment comment,
    List<String>? mentions,
  }) async {
    // Collect notification targets (recipe members excluding commenter)
    final targetUserIds = _collectNotificationTargets(
      recipe: recipe,
      comment: comment,
      mentions: mentions,
    );

    if (targetUserIds.isEmpty) {
      AppLogger.debug('📋 No users to notify for comment');
      return;
    }

    AppLogger.info(
        '📬 Sending comment notifications to ${targetUserIds.length} users');

    // Send comment notification (batchable to prevent spam)
    await NotificationHelper.sendBatchableSafely(
      notificationService: notificationService,
      operationName: 'Send comment notifications',
      targetUserIds: targetUserIds,
      strategy: NotificationStrategy.recipeComment,
      variables: {
        'commenterName': comment.authorDisplayName,
        'recipeName': recipe.title,
        'commentPreview': _truncateComment(comment.text),
      },
      additionalData: {
        'recipeId': recipe.id,
        'commentId': comment.id,
        'action': 'comment_added',
        'commenterId': comment.authorId,
      },
    );
  }

  /// Send notifications for comment replies
  static Future<void> sendReplyNotifications({
    required NotificationService? notificationService,
    required Recipe recipe,
    required RecipeComment reply,
    required RecipeComment parentComment,
  }) async {
    // Don't notify if replying to own comment
    if (reply.authorId == parentComment.authorId) {
      AppLogger.debug(
          '📋 Skipping reply notification (replying to own comment)');
      return;
    }

    // Send reply notification to parent comment author
    await NotificationHelper.sendBatchableSafely(
      notificationService: notificationService,
      operationName:
          'Send reply notification to ${parentComment.authorDisplayName}',
      targetUserIds: [parentComment.authorId],
      strategy: NotificationStrategy.recipeComment,
      variables: {
        'replierName': reply.authorDisplayName,
        'recipeName': recipe.title,
        'replyPreview': _truncateComment(reply.text),
        'originalCommentPreview': _truncateComment(parentComment.text),
      },
      additionalData: {
        'recipeId': recipe.id,
        'commentId': reply.id,
        'parentCommentId': parentComment.id,
        'action': 'comment_reply',
        'replierId': reply.authorId,
      },
    );
  }

  /// Send notifications for comment mentions
  static Future<void> sendMentionNotifications({
    required NotificationService? notificationService,
    required Recipe recipe,
    required RecipeComment comment,
    required List<String> mentionedUserIds,
  }) async {
    if (mentionedUserIds.isEmpty) {
      return;
    }

    // Filter out the commenter from mentions
    final targetUserIds =
        mentionedUserIds.where((userId) => userId != comment.authorId).toList();

    if (targetUserIds.isEmpty) {
      AppLogger.debug('📋 No users to notify for mentions');
      return;
    }

    AppLogger.info(
        '📬 Sending mention notifications to ${targetUserIds.length} users');

    // Send mention notifications
    await NotificationHelper.sendBatchableSafely(
      notificationService: notificationService,
      operationName: 'Send mention notifications',
      targetUserIds: targetUserIds,
      strategy: NotificationStrategy.recipeComment,
      variables: {
        'mentionerName': comment.authorDisplayName,
        'recipeName': recipe.title,
        'commentPreview': _truncateComment(comment.text),
      },
      additionalData: {
        'recipeId': recipe.id,
        'commentId': comment.id,
        'action': 'comment_mention',
        'mentionerId': comment.authorId,
      },
    );
  }

  /// Send notifications for comment likes
  static Future<void> sendLikeNotifications({
    required NotificationService? notificationService,
    required Recipe recipe,
    required RecipeComment comment,
    required String likerUserId,
    required String likerDisplayName,
  }) async {
    // Don't notify if liking own comment
    if (likerUserId == comment.authorId) {
      AppLogger.debug('📋 Skipping like notification (liking own comment)');
      return;
    }

    // Send like notification to comment author
    await NotificationHelper.sendBatchableSafely(
      notificationService: notificationService,
      operationName: 'Send like notification to ${comment.authorDisplayName}',
      targetUserIds: [comment.authorId],
      strategy: NotificationStrategy.recipeComment,
      variables: {
        'likerName': likerDisplayName,
        'recipeName': recipe.title,
        'commentPreview': _truncateComment(comment.text),
      },
      additionalData: {
        'recipeId': recipe.id,
        'commentId': comment.id,
        'action': 'comment_like',
        'likerId': likerUserId,
      },
    );
  }

  /// Collect all users who should be notified about a comment
  static List<String> _collectNotificationTargets({
    required Recipe recipe,
    required RecipeComment comment,
    List<String>? mentions,
  }) {
    final targetUserIds = <String>[];

    // Add recipe owner
    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId != null && ownerId != comment.authorId) {
      targetUserIds.add(ownerId);
    }

    // Add recipe members
    final memberIds = recipe.socialData?.memberPermissions?.keys ?? [];
    for (final memberId in memberIds) {
      if (memberId != comment.authorId && !targetUserIds.contains(memberId)) {
        targetUserIds.add(memberId);
      }
    }

    // Add mentioned users
    if (mentions != null) {
      for (final mentionedUserId in mentions) {
        if (mentionedUserId != comment.authorId &&
            !targetUserIds.contains(mentionedUserId)) {
          targetUserIds.add(mentionedUserId);
        }
      }
    }

    return targetUserIds;
  }

  /// Get notification preferences for recipe interactions
  static Map<String, bool> getRecipeNotificationPreferences(Recipe recipe) {
    return {
      'allowCommentNotifications': recipe.isCollaborative || recipe.isPersonal,
      'allowReplyNotifications': true,
      'allowMentionNotifications': true,
      'allowLikeNotifications': recipe.isCollaborative,
      'batchNotifications':
          recipe.isCollaborative, // Batch for collaborative recipes
    };
  }

  /// Check if user should receive comment notifications for recipe
  static bool shouldReceiveCommentNotifications({
    required Recipe recipe,
    required String userId,
  }) {
    // Personal recipes: only owner receives notifications
    if (recipe.isPersonal) {
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      return ownerId == userId;
    }

    // Collaborative recipes: owner and members receive notifications
    if (recipe.isCollaborative) {
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == userId) return true;
      return recipe.socialData?.memberPermissions?.containsKey(userId) ?? false;
    }

    return false;
  }

  /// Truncate comment for notification preview
  static String _truncateComment(String content, {int maxLength = 50}) {
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}...';
  }

  /// Get notification summary for multiple comments
  static String getMultiCommentNotificationSummary({
    required List<RecipeComment> comments,
    required String recipeName,
  }) {
    if (comments.isEmpty) return '';

    final l = AppLocale.current;
    if (comments.length == 1) {
      final comment = comments.first;
      return l.notificationCommentSingle(comment.authorDisplayName, recipeName);
    }

    final uniqueCommenters = comments.map((c) => c.authorDisplayName).toSet();
    if (uniqueCommenters.length == 1) {
      return l.notificationCommentMultipleSameAuthor(
          uniqueCommenters.first, comments.length, recipeName);
    }

    return l.notificationCommentMultipleAuthors(
        uniqueCommenters.length, comments.length, recipeName);
  }

  /// Generate notification batch key for comment notifications
  static String generateNotificationBatchKey({
    required String recipeId,
    required String userId,
  }) {
    return 'recipe_comment_${recipeId}_$userId';
  }

  /// Check if notification should be batched
  static bool shouldBatchNotification({
    required Recipe recipe,
    required String notificationType,
  }) {
    // Batch notifications for collaborative recipes to prevent spam
    if (!recipe.isCollaborative) return false;

    switch (notificationType) {
      case 'comment':
      case 'reply':
        return true;
      case 'mention':
      case 'like':
        return false;
      default:
        return false;
    }
  }

  /// Get notification delay for batching (in seconds)
  static int getNotificationBatchDelay({
    required Recipe recipe,
    required String notificationType,
  }) {
    if (!recipe.isCollaborative) return 0;

    switch (notificationType) {
      case 'comment':
        return 300; // 5 minutes
      case 'reply':
        return 60; // 1 minute
      default:
        return 0;
    }
  }
}
