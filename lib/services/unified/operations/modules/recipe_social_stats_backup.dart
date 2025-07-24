// lib/services/unified/operations/modules/recipe_social_stats.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/recipe_unified.dart';
import '../../../../core/utils/logger.dart';
import '../../../notifications/notification_service.dart';
import '../../../notifications/notification_types.dart';

/// Focused module for recipe rating, statistics, and social metrics
/// 
/// This module handles ONLY social statistics responsibilities:
/// - Recipe rating and review system
/// - Social engagement metrics and analytics
/// - Recipe popularity and trending calculations
/// - User interaction statistics
/// - Social performance tracking
/// - Rating aggregation and display
/// 
/// ❌ DOES NOT CONTAIN: Recipe sharing, member management, comments, discovery, permissions
class RecipeSocialStats {
  final dynamic _parent; // UnifiedRecipeService
  final FirebaseFirestore _firestore;
  final NotificationService? _notificationService;

  // Collections
  static const String _ratingsCollection = 'recipe_ratings';
  static const String _socialStatsCollection = 'recipe_social_stats';

  RecipeSocialStats(this._parent, this._firestore, this._notificationService);

  // ===== RECIPE RATING SYSTEM =====

  /// Rate a recipe
  /// 
  /// Allows users to rate recipes they have access to (1-5 stars)
  Future<bool> rateRecipe({
    required String recipeId,
    required double rating,
    String? review,
  }) async {
    try {
      AppLogger.info('⭐ Rating recipe $recipeId with $rating stars');

      if (rating < 1.0 || rating > 5.0) {
        AppLogger.error('❌ Rating must be between 1.0 and 5.0');
        return false;
      }

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        AppLogger.error('❌ User must be logged in to rate recipes');
        return false;
      }

      // Find the recipe
      final recipe = _parent.recipes
          .where((r) => r.id == recipeId)
          .firstOrNull;
      
      if (recipe == null) {
        AppLogger.error('❌ Cannot rate recipe: Recipe not found');
        return false;
      }

      // Check if user has access to rate this recipe
      if (!_canRateRecipe(recipe)) {
        AppLogger.error('❌ User does not have permission to rate this recipe');
        return false;
      }

      // Create or update rating
      final ratingId = '${recipeId}_$currentUserId';
      final ratingData = {
        'recipeId': recipeId,
        'userId': currentUserId,
        'userDisplayName': _parent.currentUserDisplayName ?? 'Okänd användare',
        'rating': rating,
        'review': review?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .set(ratingData, SetOptions(merge: true));

      AppLogger.success('✅ Recipe rated successfully');

      // Update aggregated rating for the recipe
      await _updateRecipeRatingAggregate(recipeId);

      // Send notification to recipe owner (if not rating own recipe)
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId != currentUserId) {
        await _sendRatingNotification(
          recipe: recipe,
          rating: rating,
          review: review,
        );
      }

      // Log rating for analytics
      _logRatingAction(
        recipeId: recipeId,
        rating: rating,
        hasReview: review?.isNotEmpty ?? false,
      );

      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to rate recipe', e);
      return false;
    }
  }

  /// Get recipe rating statistics
  /// 
  /// Returns comprehensive rating data including average, distribution, and reviews
  Future<Map<String, dynamic>> getRecipeStats(String recipeId) async {
    try {
      AppLogger.debug('📊 Getting recipe statistics for $recipeId');

      final recipe = _parent.recipes
          .where((r) => r.id == recipeId)
          .firstOrNull;
      
      if (recipe == null) {
        AppLogger.warning('⚠️ Recipe not found for statistics');
        return {'error': 'Recipe not found'};
      }

      // Get all ratings for this recipe
      final ratingsSnapshot = await _firestore
          .collection(_ratingsCollection)
          .where('recipeId', isEqualTo: recipeId)
          .get();

      final ratings = ratingsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': data['userId'],
          'userDisplayName': data['userDisplayName'],
          'rating': data['rating'],
          'review': data['review'],
          'createdAt': data['createdAt'],
        };
      }).toList();

      // Calculate statistics
      final stats = _calculateRatingStatistics(ratings);

      // Add social engagement metrics
      final socialMetrics = await _calculateSocialMetrics(recipeId);

      // Combine recipe info with statistics
      final result = {
        'recipe': {
          'id': recipe.id,
          'title': recipe.title,
          'owner': recipe.socialData?.ownerDisplayName ?? 'Unknown',
          'isCollaborative': recipe.isCollaborative,
          'memberCount': (recipe.socialData?.memberPermissions?.length ?? 0) + 1,
          'createdAt': recipe.createdAt.toIso8601String(),
        },
        'ratings': stats,
        'social': socialMetrics,
      };

      AppLogger.debug('📋 Generated comprehensive recipe statistics');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipe statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  /// Get user's rating for a specific recipe
  Future<Map<String, dynamic>?> getUserRating(String recipeId) async {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return null;

      final ratingId = '${recipeId}_$currentUserId';
      final ratingDoc = await _firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .get();

      if (!ratingDoc.exists) return null;

      final data = ratingDoc.data()!;
      return {
        'rating': data['rating'],
        'review': data['review'],
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get user rating', e);
      return null;
    }
  }

  /// Get top-rated recipes
  Future<List<Map<String, dynamic>>> getTopRatedRecipes({
    int limit = 10,
    double minRating = 4.0,
    int minRatingCount = 3,
  }) async {
    try {
      AppLogger.info('🏆 Getting top-rated recipes');

      // Get all accessible recipes
      final allRecipes = _parent.recipes as List<Recipe>;
      final accessibleRecipes = allRecipes.where((recipe) {
        return _hasAccessToRecipe(recipe);
      }).toList();

      // Get rating stats for each recipe
      final recipeStats = <Map<String, dynamic>>[];
      
      for (final recipe in accessibleRecipes) {
        final stats = await getRecipeStats(recipe.id);
        if (stats.containsKey('error')) continue;

        final ratings = stats['ratings'] as Map<String, dynamic>;
        final averageRating = ratings['average'] as double? ?? 0.0;
        final ratingCount = ratings['count'] as int? ?? 0;

        if (averageRating >= minRating && ratingCount >= minRatingCount) {
          recipeStats.add({
            'recipe': recipe,
            'averageRating': averageRating,
            'ratingCount': ratingCount,
            'stats': stats,
          });
        }
      }

      // Sort by rating (descending) and then by rating count
      recipeStats.sort((a, b) {
        final ratingComparison = (b['averageRating'] as double)
            .compareTo(a['averageRating'] as double);
        
        if (ratingComparison != 0) return ratingComparison;
        
        return (b['ratingCount'] as int).compareTo(a['ratingCount'] as int);
      });

      // Apply limit and return
      final result = recipeStats.take(limit).toList();
      
      AppLogger.success('✅ Found ${result.length} top-rated recipes');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get top-rated recipes', e);
      return [];
    }
  }

  // ===== SOCIAL ENGAGEMENT METRICS =====

  /// Calculate social engagement metrics for a recipe
  Future<Map<String, dynamic>> _calculateSocialMetrics(String recipeId) async {
    try {
      final recipe = _parent.recipes
          .where((r) => r.id == recipeId)
          .firstOrNull;
      
      if (recipe == null) return {};

      // Basic social metrics
      final metrics = <String, dynamic>{
        'member_count': recipe.isCollaborative 
            ? (recipe.socialData?.memberPermissions?.length ?? 0) + 1 
            : 1,
        'is_collaborative': recipe.isCollaborative,
        'sharing_enabled': recipe.isCollaborative,
      };

      // Calculate engagement score based on various factors
      var engagementScore = 0.0;

      // Member count contributes to engagement
      if (recipe.isCollaborative) {
        final memberCount = recipe.socialData?.memberPermissions?.length ?? 0;
        engagementScore += memberCount * 10;
      }

      // Recent activity contributes to engagement
      final daysSinceLastEdit = DateTime.now()
          .difference(recipe.updatedAt)
          .inDays;
      if (daysSinceLastEdit <= 7) {
        engagementScore += (7 - daysSinceLastEdit) * 5;
      }

      // Recipe complexity (ingredients/instructions) contributes
      engagementScore += recipe.ingredients.length * 2;
      engagementScore += recipe.instructions.length * 3;

      metrics['engagement_score'] = engagementScore.round();

      // Calculate engagement level
      if (engagementScore >= 100) {
        metrics['engagement_level'] = 'high';
      } else if (engagementScore >= 50) {
        metrics['engagement_level'] = 'medium';
      } else {
        metrics['engagement_level'] = 'low';
      }

      return metrics;
    } catch (e) {
      AppLogger.error('❌ Failed to calculate social metrics', e);
      return {};
    }
  }

  /// Get social statistics for user
  Future<Map<String, dynamic>> getUserSocialStats() async {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        return {'error': 'No current user'};
      }

      // Get user's recipes
      final allRecipes = _parent.recipes as List<Recipe>;
      final userRecipes = allRecipes.where((r) {
        final ownerId = r.socialData?.ownerId ?? r.createdBy;
        return ownerId == currentUserId;
      }).toList();

      var totalRatingsReceived = 0;
      var totalRatingsGiven = 0;
      var averageRatingReceived = 0.0;
      var totalRatingSum = 0.0;

      // Calculate ratings received on user's recipes
      var recipesWithRatings = 0;
      for (final recipe in userRecipes) {
        final ratingsSnapshot = await _firestore
            .collection(_ratingsCollection)
            .where('recipeId', isEqualTo: recipe.id)
            .get();

        if (ratingsSnapshot.docs.isNotEmpty) {
          recipesWithRatings++;
        }

        for (final ratingDoc in ratingsSnapshot.docs) {
          final rating = ratingDoc.data()['rating'] as double;
          totalRatingsReceived++;
          totalRatingSum += rating;
        }
      }

      // Calculate ratings given by user
      final givenRatingsSnapshot = await _firestore
          .collection(_ratingsCollection)
          .where('userId', isEqualTo: currentUserId)
          .get();

      totalRatingsGiven = givenRatingsSnapshot.docs.length;

      // Calculate average rating received
      if (totalRatingsReceived > 0) {
        averageRatingReceived = totalRatingSum / totalRatingsReceived;
      }

      // Calculate social reach (total members across all collaborative recipes)
      var totalSocialReach = 0;
      final collaborativeRecipes = userRecipes.where((r) => r.isCollaborative).toList();
      for (final recipe in collaborativeRecipes) {
        totalSocialReach += recipe.socialData?.memberPermissions?.length ?? 0;
      }

      return {
        'total_recipes': userRecipes.length,
        'collaborative_recipes': collaborativeRecipes.length,
        'ratings_received': totalRatingsReceived,
        'ratings_given': totalRatingsGiven,
        'average_rating_received': (averageRatingReceived * 10).round() / 10, // Round to 1 decimal
        'social_reach': totalSocialReach,
        'recipes_with_ratings': recipesWithRatings,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get user social statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  // ===== RATING CALCULATIONS =====

  /// Calculate comprehensive rating statistics
  Map<String, dynamic> _calculateRatingStatistics(List<Map<String, dynamic>> ratings) {
    if (ratings.isEmpty) {
      return {
        'count': 0,
        'average': 0.0,
        'distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        'reviews': [],
        'recent_reviews': [],
      };
    }

    // Calculate average
    final totalRating = ratings.fold<double>(
      0.0, (total, rating) => total + (rating['rating'] as double)
    );
    final average = totalRating / ratings.length;

    // Calculate distribution
    final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final rating in ratings) {
      final starRating = (rating['rating'] as double).round();
      distribution[starRating] = distribution[starRating]! + 1;
    }

    // Get reviews (ratings with text)
    final reviews = ratings
        .where((rating) => rating['review'] != null && 
                          (rating['review'] as String).trim().isNotEmpty)
        .toList();

    // Sort reviews by date (most recent first)
    reviews.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    // Get recent reviews (last 5)
    final recentReviews = reviews.take(5).toList();

    return {
      'count': ratings.length,
      'average': double.parse(average.toStringAsFixed(1)),
      'distribution': distribution,
      'reviews': reviews,
      'recent_reviews': recentReviews,
      'review_count': reviews.length,
      'review_percentage': ratings.isNotEmpty 
          ? ((reviews.length / ratings.length) * 100).round()
          : 0,
    };
  }

  /// Update aggregated rating for recipe
  Future<void> _updateRecipeRatingAggregate(String recipeId) async {
    try {
      // Get all ratings for the recipe
      final ratingsSnapshot = await _firestore
          .collection(_ratingsCollection)
          .where('recipeId', isEqualTo: recipeId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        // No ratings, remove aggregate
        await _firestore
            .collection(_socialStatsCollection)
            .doc(recipeId)
            .delete();
        return;
      }

      final ratings = ratingsSnapshot.docs.map((doc) => doc.data()).toList();
      final stats = _calculateRatingStatistics(ratings);

      // Store aggregate data
      await _firestore
          .collection(_socialStatsCollection)
          .doc(recipeId)
          .set({
        'recipeId': recipeId,
        'ratingCount': stats['count'],
        'averageRating': stats['average'],
        'ratingDistribution': stats['distribution'],
        'reviewCount': stats['review_count'],
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.debug('📊 Updated rating aggregate for recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Failed to update rating aggregate', e);
    }
  }

  // ===== NOTIFICATIONS =====

  /// Send notification when recipe receives a rating
  Future<void> _sendRatingNotification({
    required Recipe recipe,
    required double rating,
    String? review,
  }) async {
    if (_notificationService == null) return;

    try {
      final currentUserName = _parent.currentUserDisplayName ?? 'En användare';
      final stars = '⭐' * rating.round();
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;

      if (ownerId != null) {
        await _notificationService.sendImmediateNotification(
          targetUserIds: [ownerId],
        strategy: NotificationStrategy.recipeComment, // Reuse comment strategy for ratings
        variables: {
          'commenterName': currentUserName,
          'recipeName': recipe.title,
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

  // ===== PERMISSION HELPERS =====

  /// Check if user can rate a recipe
  bool _canRateRecipe(Recipe recipe) {
    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return false;

    // Can't rate own recipe
    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId == currentUserId) return false;

    // For personal recipes, can't rate unless you're the owner (already excluded above)
    if (recipe.isPersonal) return false;

    // For collaborative recipes, must be a member
    if (recipe.isCollaborative) {
      return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ?? false;
    }

    return false;
  }

  /// Check if user has access to view recipe stats
  bool _hasAccessToRecipe(Recipe recipe) {
    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return false;

    // Always can view own recipes
    final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
    if (ownerId == currentUserId) return true;

    // For personal recipes, only owner has access
    if (recipe.isPersonal) return false;

    // For collaborative recipes, members have access
    if (recipe.isCollaborative) {
      return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ?? false;
    }

    return false;
  }

  // ===== ANALYTICS =====

  /// Log rating action for analytics
  void _logRatingAction({
    required String recipeId,
    required double rating,
    required bool hasReview,
  }) {
    try {
      AppLogger.info('📊 Rating action logged: $rating stars');
      // Future analytics implementation would log detailed data:
      // final logData = {
      //   'recipeId': recipeId,
      //   'rating': rating,
      //   'hasReview': hasReview,
      //   'userId': _parent.currentUserId,
      //   'timestamp': DateTime.now().toIso8601String(),
      // };
      // Analytics.logEvent('recipe_rated', logData);
    } catch (e) {
      AppLogger.warning('⚠️ Failed to log rating action: $e');
    }
  }
}