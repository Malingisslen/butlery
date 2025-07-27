// lib/services/unified/operations/modules/rating_notifications.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';

/// Focused module for rating notifications
/// 
/// This module handles ONLY rating-related notifications:
/// - Rating notifications to recipe owners
/// - Rating milestone notifications
/// - Rating summary notifications
/// - Notification formatting and targeting
/// 
/// ❌ DOES NOT CONTAIN: Rating operations, statistics, social metrics, engagement calculations
class RatingNotifications {

  // ===== RATING NOTIFICATIONS =====

  /// Send notification when recipe receives a rating
  static Future<void> sendRatingNotification({
    required NotificationService? notificationService,
    required Recipe recipe,
    required double rating,
    required String raterName,
    String? review,
  }) async {
    if (notificationService == null) {
      AppLogger.debug('📋 No notification service available');
      return;
    }

    try {
      final stars = '⭐' * rating.round();
      final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;

      if (ownerId != null) {
        await notificationService.sendImmediateNotification(
          targetUserIds: [ownerId],
          strategy: NotificationStrategy.recipeComment, // Reuse comment strategy for ratings
          variables: {
            'commenterName': raterName,
            'recipeName': recipe.core.title,
            'commentPreview': review?.isNotEmpty == true && review != null
                ? (review.length > 50 
                    ? '${review.substring(0, 50)}...'
                    : review)
                : 'Betygsatte ditt recept $stars',
          },
          additionalData: {
            'recipeId': recipe.id,
            'action': 'recipe_rated',
            'rating': rating,
            'hasReview': review?.isNotEmpty ?? false,
            'raterName': raterName,
          },
          actions: [
            NotificationAction.viewRecipe,
          ],
        );

        AppLogger.info('📬 Sent rating notification to recipe owner');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to send rating notification', e);
    }
  }

  /// Send milestone notification for rating achievements
  static Future<void> sendRatingMilestoneNotification({
    required NotificationService? notificationService,
    required Recipe recipe,
    required int totalRatings,
    required double averageRating,
  }) async {
    if (notificationService == null) return;

    try {
      final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
      if (ownerId == null) return;

      // Check if this is a milestone worth celebrating
      final milestone = _getRatingMilestone(totalRatings, averageRating);
      if (milestone == null) return;

      await notificationService.sendImmediateNotification(
        targetUserIds: [ownerId],
        strategy: NotificationStrategy.recipeComment, // Reuse comment strategy
        variables: {
          'commenterName': 'Butlery',
          'recipeName': recipe.core.title,
          'commentPreview': milestone['message'] as String,
        },
        additionalData: {
          'recipeId': recipe.id,
          'action': 'rating_milestone',
          'milestone_type': milestone['type'],
          'total_ratings': totalRatings,
          'average_rating': averageRating,
        },
        actions: [
          NotificationAction.viewRecipe,
        ],
      );

      AppLogger.info('📬 Sent rating milestone notification: ${milestone['type']}');
    } catch (e) {
      AppLogger.error('❌ Failed to send rating milestone notification', e);
    }
  }

  /// Send rating summary notification (weekly/monthly)
  static Future<void> sendRatingSummaryNotification({
    required NotificationService? notificationService,
    required String userId,
    required List<Map<String, dynamic>> recipeRatingSummaries,
    required String period, // 'weekly' or 'monthly'
  }) async {
    if (notificationService == null || recipeRatingSummaries.isEmpty) return;

    try {
      final totalNewRatings = recipeRatingSummaries.fold<int>(
        0, (sum, summary) => sum + (summary['newRatings'] as int)
      );

      if (totalNewRatings == 0) return;

      final topRecipe = recipeRatingSummaries.first;
      final summary = _generateRatingSummaryText(recipeRatingSummaries, period);

      await notificationService.sendImmediateNotification(
        targetUserIds: [userId],
        strategy: NotificationStrategy.recipeComment, // Reuse comment strategy
        variables: {
          'commenterName': 'Butlery',
          'recipeName': topRecipe['recipeName'] as String,
          'commentPreview': summary,
        },
        additionalData: {
          'action': 'rating_summary',
          'period': period,
          'total_new_ratings': totalNewRatings,
          'recipes_count': recipeRatingSummaries.length,
        },
        actions: [
          NotificationAction.viewRecipe,
        ],
      );

      AppLogger.info('📬 Sent $period rating summary notification');
    } catch (e) {
      AppLogger.error('❌ Failed to send rating summary notification', e);
    }
  }

  /// Send notification for first rating received
  static Future<void> sendFirstRatingNotification({
    required NotificationService? notificationService,
    required Recipe recipe,
    required double rating,
    required String raterName,
    String? review,
  }) async {
    if (notificationService == null) return;

    try {
      final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
      if (ownerId == null) return;

      final stars = '⭐' * rating.round();
      final message = review?.isNotEmpty == true
          ? 'Fick sin första recension från $raterName: "${_truncateReview(review!)}"'
          : 'Fick sitt första betyg från $raterName: $stars';

      await notificationService.sendImmediateNotification(
        targetUserIds: [ownerId],
        strategy: NotificationStrategy.recipeComment,
        variables: {
          'commenterName': 'Butlery',
          'recipeName': recipe.core.title,
          'commentPreview': '🎉 Grattis! Ditt recept "$message"',
        },
        additionalData: {
          'recipeId': recipe.id,
          'action': 'first_rating',
          'rating': rating,
          'raterName': raterName,
          'hasReview': review?.isNotEmpty ?? false,
        },
        actions: [
          NotificationAction.viewRecipe,
        ],
      );

      AppLogger.info('📬 Sent first rating notification');
    } catch (e) {
      AppLogger.error('❌ Failed to send first rating notification', e);
    }
  }

  // ===== NOTIFICATION HELPERS =====

  /// Get rating milestone information
  static Map<String, dynamic>? _getRatingMilestone(int totalRatings, double averageRating) {
    // Rating count milestones
    if (totalRatings == 5) {
      return {
        'type': 'first_five_ratings',
        'message': '🎉 Ditt recept har fått 5 betyg!',
      };
    } else if (totalRatings == 10) {
      return {
        'type': 'ten_ratings',
        'message': '🌟 Fantastiskt! Ditt recept har fått 10 betyg!',
      };
    } else if (totalRatings == 25) {
      return {
        'type': 'twenty_five_ratings',
        'message': '🏆 Imponerande! Ditt recept har fått 25 betyg!',
      };
    } else if (totalRatings == 50) {
      return {
        'type': 'fifty_ratings',
        'message': '🎊 Otroligt! Ditt recept har fått 50 betyg!',
      };
    }

    // Quality milestones (only if enough ratings)
    if (totalRatings >= 5) {
      if (averageRating >= 4.8) {
        return {
          'type': 'excellent_rating',
          'message': '⭐ Enastående! Ditt recept har ${averageRating.toStringAsFixed(1)} i genomsnittsbetyg!',
        };
      } else if (averageRating >= 4.5) {
        return {
          'type': 'great_rating',
          'message': '🌟 Fantastiskt! Ditt recept har ${averageRating.toStringAsFixed(1)} i genomsnittsbetyg!',
        };
      }
    }

    return null;
  }

  /// Generate rating summary text
  static String _generateRatingSummaryText(List<Map<String, dynamic>> summaries, String period) {
    final totalNewRatings = summaries.fold<int>(
      0, (sum, summary) => sum + (summary['newRatings'] as int)
    );

    final recipesWithRatings = summaries.where((s) => (s['newRatings'] as int) > 0).length;

    if (recipesWithRatings == 1) {
      final recipe = summaries.first;
      return 'Ditt recept "${recipe['recipeName']}" fick ${recipe['newRatings']} nya betyg denna $period!';
    } else {
      return 'Dina recept fick totalt $totalNewRatings nya betyg på $recipesWithRatings recept denna $period!';
    }
  }

  /// Truncate review text for notifications
  static String _truncateReview(String review, {int maxLength = 50}) {
    if (review.length <= maxLength) return review;
    return '${review.substring(0, maxLength)}...';
  }

  // ===== NOTIFICATION BATCHING =====

  /// Send batched rating notifications to avoid spam
  static Future<void> sendBatchedRatingNotifications({
    required NotificationService? notificationService,
    required String userId,
    required List<Map<String, dynamic>> pendingRatings,
  }) async {
    if (notificationService == null || pendingRatings.isEmpty) return;

    try {
      // Group by recipe
      final ratingsByRecipe = <String, List<Map<String, dynamic>>>{};
      for (final rating in pendingRatings) {
        final recipeId = rating['recipeId'] as String;
        ratingsByRecipe.putIfAbsent(recipeId, () => []).add(rating);
      }

      // Send batched notifications for each recipe
      for (final entry in ratingsByRecipe.entries) {
        final ratings = entry.value;
        
        if (ratings.length == 1) {
          // Single rating - send individual notification
          final rating = ratings.first;
          await sendRatingNotification(
            notificationService: notificationService,
            recipe: rating['recipe'] as Recipe,
            rating: rating['rating'] as double,
            raterName: rating['raterName'] as String,
            review: rating['review'] as String?,
          );
        } else {
          // Multiple ratings - send batch notification
          await _sendBatchRatingNotification(
            notificationService: notificationService,
            userId: userId,
            recipe: ratings.first['recipe'] as Recipe,
            ratings: ratings,
          );
        }
      }

      AppLogger.info('📬 Sent ${ratingsByRecipe.length} batched rating notifications');
    } catch (e) {
      AppLogger.error('❌ Failed to send batched rating notifications', e);
    }
  }

  /// Send notification for multiple ratings on same recipe
  static Future<void> _sendBatchRatingNotification({
    required NotificationService notificationService,
    required String userId,
    required Recipe recipe,
    required List<Map<String, dynamic>> ratings,
  }) async {
    try {
      final ratingCount = ratings.length;
      final averageRating = ratings.fold<double>(
        0.0, (sum, r) => sum + (r['rating'] as double)
      ) / ratingCount;

      final message = ratingCount == 2 
          ? 'Ditt recept fick 2 nya betyg!'
          : 'Ditt recept fick $ratingCount nya betyg! Genomsnitt: ${averageRating.toStringAsFixed(1)} ⭐';

      await notificationService.sendImmediateNotification(
        targetUserIds: [userId],
        strategy: NotificationStrategy.recipeComment,
        variables: {
          'commenterName': 'Butlery',
          'recipeName': recipe.core.title,
          'commentPreview': message,
        },
        additionalData: {
          'recipeId': recipe.id,
          'action': 'batch_ratings',
          'rating_count': ratingCount,
          'average_rating': averageRating,
        },
        actions: [
          NotificationAction.viewRecipe,
        ],
      );

      AppLogger.info('📬 Sent batch rating notification for $ratingCount ratings');
    } catch (e) {
      AppLogger.error('❌ Failed to send batch rating notification', e);
    }
  }

  // ===== NOTIFICATION PREFERENCES =====

  /// Check if user wants rating notifications
  static bool shouldSendRatingNotification({
    required Recipe recipe,
    required String raterUserId,
  }) {
    final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
    
    // Don't notify if rating own recipe
    if (ownerId == raterUserId) return false;
    
    // Don't notify for personal recipes from non-members
    if (recipe.isPersonal) return false;
    
    // For collaborative recipes, check if rater is a member
    if (recipe.isCollaborative) {
      return recipe.socialData?.memberPermissions?.containsKey(raterUserId) ?? false;
    }
    
    return false;
  }

  /// Get notification delay for batching
  static Duration getRatingNotificationDelay({
    required Recipe recipe,
    required bool isFirstRating,
  }) {
    // Send first ratings immediately
    if (isFirstRating) return Duration.zero;
    
    // Batch notifications for popular recipes
    if (recipe.isCollaborative) {
      final memberCount = recipe.socialData?.memberPermissions?.length ?? 0;
      if (memberCount > 10) {
        return const Duration(minutes: 30); // Batch for 30 minutes
      } else if (memberCount > 5) {
        return const Duration(minutes: 15); // Batch for 15 minutes
      }
    }
    
    // Send personal recipe ratings after short delay
    return const Duration(minutes: 5);
  }

  /// Generate notification batch key
  static String generateRatingNotificationBatchKey({
    required String recipeId,
    required String userId,
  }) {
    return 'rating_${recipeId}_$userId';
  }
}