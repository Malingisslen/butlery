// lib/services/unified/operations/modules/rating_notifications.dart

import 'package:intl/intl.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_ownership.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/notification_helper.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_translations.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/notifications/recipe_activity_strategies.dart';

/// Focused module for rating notifications
/// This module handles ONLY rating-related notifications:
/// - Rating notifications to recipe owners
/// - Rating milestone notifications
/// - Rating summary notifications
/// - Notification formatting and targeting
/// ❌ DOES NOT CONTAIN: Rating operations, statistics, social metrics, engagement calculations
class RatingNotifications {
  /// Send notification when recipe receives a rating
  static Future<void> sendRatingNotification({
    required NotificationService? notificationService,
    required Recipe recipe,
    required double rating,
    required String raterName,
    String? review,
  }) async {
    final stars = '★' * rating.round();
    final ownerId = recipe.ownerUid;

    if (ownerId != null) {
      String message(AppLocalizations l) =>
          review?.isNotEmpty == true && review != null
          ? '$raterName: ${_truncateReview(review)}'
          : l.notificationRatingReceived(raterName, stars);

      await NotificationHelper.sendImmediateSafely(
        notificationService: notificationService,
        operationName: 'Send rating notification to recipe owner',
        targetUserIds: [ownerId],
        strategy: RecipeActivityStrategies.ratingNotice,
        variables: {
          'recipeName': recipe.core.title,
          'message': message(AppLocale.current),
        },
        variablesByLocale: localizedVariables(
          (l) => {'message': message(l)},
        ),
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
    }
  }

  /// Send milestone notification for rating achievements
  static Future<void> sendRatingMilestoneNotification({
    required NotificationService? notificationService,
    required Recipe recipe,
    required int totalRatings,
    required double averageRating,
  }) async {
    final ownerId = recipe.ownerUid;
    if (ownerId == null) return;

    // Check if this is a milestone worth celebrating
    final milestone = _getRatingMilestone(totalRatings, averageRating);
    if (milestone == null) return;
    final message = milestone['message'] as String Function(AppLocalizations);

    await NotificationHelper.sendImmediateSafely(
      notificationService: notificationService,
      operationName: 'Send rating milestone notification: ${milestone['type']}',
      targetUserIds: [ownerId],
      strategy: RecipeActivityStrategies.ratingNotice,
      variables: {
        'recipeName': recipe.core.title,
        'message': message(AppLocale.current),
      },
      variablesByLocale: localizedVariables((l) => {'message': message(l)}),
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
  }

  /// Send rating summary notification (weekly/monthly)
  static Future<void> sendRatingSummaryNotification({
    required NotificationService? notificationService,
    required String userId,
    required List<Map<String, dynamic>> recipeRatingSummaries,
    required String period, // 'weekly' or 'monthly'
  }) async {
    if (recipeRatingSummaries.isEmpty) return;

    final totalNewRatings = recipeRatingSummaries.fold<int>(
      0,
      (sum, summary) => sum + (summary['newRatings'] as int),
    );

    if (totalNewRatings == 0) return;

    final topRecipe = recipeRatingSummaries.firstWhere(
      (s) => (s['newRatings'] as int) > 0,
    );
    String summary(AppLocalizations l) =>
        _generateRatingSummaryText(l, recipeRatingSummaries, period);

    await NotificationHelper.sendImmediateSafely(
      notificationService: notificationService,
      operationName: 'Send $period rating summary notification',
      targetUserIds: [userId],
      strategy: RecipeActivityStrategies.ratingNotice,
      variables: {
        'recipeName': topRecipe['recipeName'] as String,
        'message': summary(AppLocale.current),
      },
      variablesByLocale: localizedVariables((l) => {'message': summary(l)}),
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
  }

  /// Send notification for first rating received
  static Future<void> sendFirstRatingNotification({
    required NotificationService? notificationService,
    required Recipe recipe,
    required double rating,
    required String raterName,
    String? review,
  }) async {
    final ownerId = recipe.ownerUid;
    if (ownerId == null) return;

    final stars = '★' * rating.round();
    String message(AppLocalizations l) => review?.isNotEmpty == true
        ? l.notificationRatingFirstReview(raterName, _truncateReview(review!))
        : l.notificationRatingFirstRating(raterName, stars);

    await NotificationHelper.sendImmediateSafely(
      notificationService: notificationService,
      operationName: 'Send first rating notification',
      targetUserIds: [ownerId],
      strategy: RecipeActivityStrategies.ratingNotice,
      variables: {
        'recipeName': recipe.core.title,
        'message': message(AppLocale.current),
      },
      variablesByLocale: localizedVariables((l) => {'message': message(l)}),
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
  }

  /// Get rating milestone information
  static Map<String, dynamic>? _getRatingMilestone(
    int totalRatings,
    double averageRating,
  ) {
    // Rating count milestones
    if (totalRatings == 5) {
      return {
        'type': 'first_five_ratings',
        'message': (AppLocalizations l) =>
            l.notificationRatingMilestoneCount(5),
      };
    } else if (totalRatings == 10) {
      return {
        'type': 'ten_ratings',
        'message': (AppLocalizations l) =>
            l.notificationRatingMilestoneCount(10),
      };
    } else if (totalRatings == 25) {
      return {
        'type': 'twenty_five_ratings',
        'message': (AppLocalizations l) =>
            l.notificationRatingMilestoneCount(25),
      };
    } else if (totalRatings == 50) {
      return {
        'type': 'fifty_ratings',
        'message': (AppLocalizations l) =>
            l.notificationRatingMilestoneCount(50),
      };
    }

    // Quality milestones (only if enough ratings)
    if (totalRatings >= 5) {
      if (averageRating >= 4.8) {
        return {
          'type': 'excellent_rating',
          'message': (AppLocalizations l) =>
              l.notificationRatingMilestoneAverage(
                _oneDecimal(l, averageRating),
              ),
        };
      } else if (averageRating >= 4.5) {
        return {
          'type': 'great_rating',
          'message': (AppLocalizations l) =>
              l.notificationRatingMilestoneAverage(
                _oneDecimal(l, averageRating),
              ),
        };
      }
    }

    return null;
  }

  /// Generate rating summary text
  static String _generateRatingSummaryText(
    AppLocalizations l,
    List<Map<String, dynamic>> summaries,
    String period,
  ) {
    final totalNewRatings = summaries.fold<int>(
      0,
      (sum, summary) => sum + (summary['newRatings'] as int),
    );

    final recipesWithRatings = summaries
        .where((s) => (s['newRatings'] as int) > 0)
        .length;

    if (recipesWithRatings == 1) {
      final recipe = summaries.firstWhere((s) => (s['newRatings'] as int) > 0);
      return l.notificationRatingSingle(
        recipe['recipeName'] as String,
        recipe['newRatings'] as int,
        period,
      );
    } else {
      return l.notificationRatingMultiple(
        totalNewRatings,
        recipesWithRatings,
        period,
      );
    }
  }

  static String _oneDecimal(AppLocalizations l, double value) =>
      NumberFormat('0.0', l.localeName).format(value);

  /// Truncate review text for notifications
  static String _truncateReview(String review, {int maxLength = 50}) {
    if (review.length <= maxLength) return review;
    return '${review.substring(0, maxLength)}...';
  }

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

      AppLogger.info(
        '📬 Sent ${ratingsByRecipe.length} batched rating notifications',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to send batched rating notifications', e);
    }
  }

  /// Send notification for multiple ratings on same recipe
  static Future<void> _sendBatchRatingNotification({
    required NotificationService? notificationService,
    required String userId,
    required Recipe recipe,
    required List<Map<String, dynamic>> ratings,
  }) async {
    final ratingCount = ratings.length;
    final averageRating =
        ratings.fold<double>(0.0, (sum, r) => sum + (r['rating'] as double)) /
        ratingCount.toDouble();

    String message(AppLocalizations l) => l.notificationRatingBatch(
      ratingCount,
      _oneDecimal(l, averageRating),
    );

    await NotificationHelper.sendImmediateSafely(
      notificationService: notificationService,
      operationName: 'Send batch rating notification for $ratingCount ratings',
      targetUserIds: [userId],
      strategy: RecipeActivityStrategies.ratingNotice,
      variables: {
        'recipeName': recipe.core.title,
        'message': message(AppLocale.current),
      },
      variablesByLocale: localizedVariables((l) => {'message': message(l)}),
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
  }

  /// Check if user wants rating notifications
  static bool shouldSendRatingNotification({
    required Recipe recipe,
    required String raterUserId,
  }) {
    final ownerId = recipe.ownerUid;

    // Don't notify if rating own recipe
    if (ownerId == raterUserId) return false;

    // Don't notify for personal recipes from non-members
    if (recipe.isPersonal) return false;

    // For collaborative recipes, check if rater is a member
    if (recipe.isCollaborative) {
      return recipe.socialData?.memberPermissions?.containsKey(raterUserId) ??
          false;
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
