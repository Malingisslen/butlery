// lib/services/unified/operations/modules/social_engagement_metrics.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Focused module for social engagement metrics
/// 
/// This module handles ONLY social engagement calculations:
/// - Recipe engagement scoring and levels
/// - User social statistics and reach
/// - Social activity metrics
/// - Engagement trend analysis
/// 
/// ❌ DOES NOT CONTAIN: Rating operations, statistics aggregation, notifications, top-rated queries
class SocialEngagementMetrics {

  // ===== RECIPE ENGAGEMENT METRICS =====

  /// Calculate social engagement metrics for a recipe
  static Map<String, dynamic> calculateRecipeEngagement(Recipe recipe) {
    try {
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
          .difference(recipe.core.updatedAt)
          .inDays;
      if (daysSinceLastEdit <= 7) {
        engagementScore += (7 - daysSinceLastEdit) * 5;
      }

      // Recipe complexity (ingredients/instructions) contributes
      engagementScore += recipe.core.ingredients.length * 2;
      engagementScore += recipe.core.instructions.length * 3;

      // Recipe completeness factor
      final completenessScore = _calculateRecipeCompleteness(recipe);
      engagementScore += completenessScore * 5;

      metrics['engagement_score'] = engagementScore.round();

      // Calculate engagement level
      metrics['engagement_level'] = _getEngagementLevel(engagementScore);

      // Add detailed engagement factors
      metrics['engagement_factors'] = {
        'member_contribution': recipe.isCollaborative 
            ? (recipe.socialData?.memberPermissions?.length ?? 0) * 10 
            : 0,
        'recency_contribution': daysSinceLastEdit <= 7 
            ? (7 - daysSinceLastEdit) * 5 
            : 0,
        'content_contribution': (recipe.core.ingredients.length * 2) + 
                               (recipe.core.instructions.length * 3),
        'completeness_contribution': completenessScore * 5,
      };

      return metrics;
    } catch (e) {
      AppLogger.error('❌ Failed to calculate recipe engagement', e);
      return {
        'engagement_score': 0,
        'engagement_level': 'low',
        'member_count': 1,
        'is_collaborative': false,
        'sharing_enabled': false,
      };
    }
  }

  /// Calculate recipe completeness score (0-1)
  static double _calculateRecipeCompleteness(Recipe recipe) {
    double score = 0.0;
    
    // Title (required, so always 1)
    score += 1.0;
    
    // Ingredients
    if (recipe.core.ingredients.isNotEmpty) score += 1.0;
    
    // Instructions
    if (recipe.core.instructions.isNotEmpty) score += 1.0;
    
    // Time information
    if (recipe.core.timeMinutes != null && recipe.core.timeMinutes! > 0) score += 0.5;
    
    // Portions information
    if (recipe.core.portions != null && recipe.core.portions! > 0) score += 0.5;
    
    // Images
    if (recipe.core.imageUrls.isNotEmpty) score += 1.0;
    
    // Description or notes
    if (recipe.core.description.isNotEmpty) score += 0.5;
    
    // Tags or categories
    if (recipe.core.tags?.isNotEmpty == true) score += 0.5;
    
    // Max possible score is 6.0
    return (score / 6.0).clamp(0.0, 1.0);
  }

  /// Get engagement level from score
  static String _getEngagementLevel(double score) {
    if (score >= 100) return 'high';
    if (score >= 50) return 'medium';
    return 'low';
  }

  // ===== USER SOCIAL STATISTICS =====

  /// Calculate comprehensive user social statistics
  static Future<Map<String, dynamic>> calculateUserSocialStats({
    required FirebaseFirestore firestore,
    required String userId,
    required List<Recipe> userRecipes,
  }) async {
    try {
      AppLogger.debug('📊 Calculating social stats for user $userId');

      final collaborativeRecipes = userRecipes.where((r) => r.isCollaborative).toList();
      
      // Calculate basic metrics
      var totalSocialReach = 0;
      var totalEngagementScore = 0.0;
      var highEngagementRecipes = 0;
      
      for (final recipe in userRecipes) {
        // Add to social reach if collaborative
        if (recipe.isCollaborative) {
          totalSocialReach += recipe.socialData?.memberPermissions?.length ?? 0;
        }
        
        // Calculate engagement for this recipe
        final engagement = calculateRecipeEngagement(recipe);
        final engagementScore = engagement['engagement_score'] as int? ?? 0;
        totalEngagementScore += engagementScore;
        
        if (engagement['engagement_level'] == 'high') {
          highEngagementRecipes++;
        }
      }

      // Calculate ratings received and given
      final ratingsData = await _calculateUserRatingStats(firestore, userId, userRecipes);

      // Calculate social engagement trends
      final engagementTrends = _calculateEngagementTrends(userRecipes);

      return {
        'total_recipes': userRecipes.length,
        'collaborative_recipes': collaborativeRecipes.length,
        'personal_recipes': userRecipes.length - collaborativeRecipes.length,
        'social_reach': totalSocialReach,
        'average_engagement_score': userRecipes.isNotEmpty 
            ? (totalEngagementScore / userRecipes.length).round()
            : 0,
        'high_engagement_recipes': highEngagementRecipes,
        'collaboration_rate': userRecipes.isNotEmpty 
            ? ((collaborativeRecipes.length / userRecipes.length) * 100).round()
            : 0,
        'ratings_received': ratingsData['received_count'],
        'ratings_given': ratingsData['given_count'],
        'average_rating_received': ratingsData['average_received'],
        'engagement_trends': engagementTrends,
        'social_activity_level': _getUserSocialActivityLevel(
          totalSocialReach, 
          collaborativeRecipes.length,
          ratingsData['given_count'] as int,
        ),
      };
    } catch (e) {
      AppLogger.error('❌ Failed to calculate user social statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  /// Calculate user rating statistics
  static Future<Map<String, dynamic>> _calculateUserRatingStats(
    FirebaseFirestore firestore,
    String userId, 
    List<Recipe> userRecipes,
  ) async {
    try {
      var totalRatingsReceived = 0;
      var totalRatingSum = 0.0;

      // Calculate ratings received on user's recipes
      for (final recipe in userRecipes) {
        final ratingsSnapshot = await firestore
            .collection('recipe_ratings')
            .where('recipeId', isEqualTo: recipe.id)
            .get();

        for (final ratingDoc in ratingsSnapshot.docs) {
          final rating = ratingDoc.data()['rating'] as double;
          totalRatingsReceived++;
          totalRatingSum += rating;
        }
      }

      // Calculate ratings given by user
      final givenRatingsSnapshot = await firestore
          .collection('recipe_ratings')
          .where('userId', isEqualTo: userId)
          .get();

      final totalRatingsGiven = givenRatingsSnapshot.docs.length;

      // Calculate average rating received
      final averageRatingReceived = totalRatingsReceived > 0 
          ? (totalRatingSum / totalRatingsReceived * 10).round() / 10 
          : 0.0;

      return {
        'received_count': totalRatingsReceived,
        'given_count': totalRatingsGiven,
        'average_received': averageRatingReceived,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to calculate user rating stats', e);
      return {
        'received_count': 0,
        'given_count': 0,
        'average_received': 0.0,
      };
    }
  }

  /// Calculate engagement trends for user's recipes
  static Map<String, dynamic> _calculateEngagementTrends(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return {
        'trend': 'stable',
        'recent_activity': 0,
        'activity_increase': false,
      };
    }

    final now = DateTime.now();
    var recentActivity = 0;
    var olderActivity = 0;

    for (final recipe in recipes) {
      final daysSinceUpdate = now.difference(recipe.core.updatedAt).inDays;
      
      if (daysSinceUpdate <= 30) {
        recentActivity++;
      } else if (daysSinceUpdate <= 90) {
        olderActivity++;
      }
    }

    // Calculate trend
    String trend = 'stable';
    bool activityIncrease = false;

    if (recentActivity > olderActivity * 1.5) {
      trend = 'increasing';
      activityIncrease = true;
    } else if (recentActivity < olderActivity * 0.5) {
      trend = 'decreasing';
    }

    return {
      'trend': trend,
      'recent_activity': recentActivity,
      'older_activity': olderActivity,
      'activity_increase': activityIncrease,
    };
  }

  /// Get user's social activity level
  static String _getUserSocialActivityLevel(int socialReach, int collaborativeRecipes, int ratingsGiven) {
    final activityScore = (socialReach * 2) + (collaborativeRecipes * 5) + ratingsGiven;
    
    if (activityScore >= 50) return 'high';
    if (activityScore >= 20) return 'medium';
    return 'low';
  }

  // ===== ENGAGEMENT ANALYSIS =====

  /// Get top engaging recipes from a list
  static List<Map<String, dynamic>> getTopEngagingRecipes({
    required List<Recipe> recipes,
    int limit = 10,
    String? currentUserId,
  }) {
    try {
      AppLogger.debug('🏆 Finding top engaging recipes from ${recipes.length} recipes');

      final recipeEngagements = <Map<String, dynamic>>[];

      for (final recipe in recipes) {
        // Check access if currentUserId provided
        if (currentUserId != null && !_hasAccessToRecipe(recipe, currentUserId)) {
          continue;
        }

        final engagement = calculateRecipeEngagement(recipe);
        recipeEngagements.add({
          'recipe': recipe,
          'engagement_score': engagement['engagement_score'],
          'engagement_level': engagement['engagement_level'],
          'member_count': engagement['member_count'],
          'engagement_details': engagement,
        });
      }

      // Sort by engagement score (descending)
      recipeEngagements.sort((a, b) => 
          (b['engagement_score'] as int).compareTo(a['engagement_score'] as int));

      final result = recipeEngagements.take(limit).toList();
      AppLogger.debug('✅ Found ${result.length} top engaging recipes');
      
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get top engaging recipes', e);
      return [];
    }
  }

  /// Check if user has access to recipe for engagement viewing
  static bool _hasAccessToRecipe(Recipe recipe, String currentUserId) {
    // Always can view own recipes
    final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
    if (ownerId == currentUserId) return true;

    // For personal recipes, only owner has access
    if (recipe.isPersonal) return false;

    // For collaborative recipes, members have access
    if (recipe.isCollaborative) {
      return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ?? false;
    }

    return false;
  }

  /// Calculate engagement velocity (change over time)
  static Map<String, dynamic> calculateEngagementVelocity({
    required Recipe recipe,
    required List<Map<String, dynamic>> historicalData,
  }) {
    try {
      final currentEngagement = calculateRecipeEngagement(recipe);
      final currentScore = currentEngagement['engagement_score'] as int;

      if (historicalData.isEmpty) {
        return {
          'velocity': 0.0,
          'trend': 'stable',
          'current_score': currentScore,
          'previous_score': currentScore,
        };
      }

      // Get most recent historical score
      final previousScore = historicalData.last['engagement_score'] as int? ?? currentScore;
      final velocity = (currentScore - previousScore).toDouble();

      String trend = 'stable';
      if (velocity > 10) {
        trend = 'increasing';
      } else if (velocity < -10) {
        trend = 'decreasing';
      }

      return {
        'velocity': velocity,
        'trend': trend,
        'current_score': currentScore,
        'previous_score': previousScore,
        'change_percentage': previousScore > 0 
            ? ((velocity / previousScore) * 100).round()
            : 0,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to calculate engagement velocity', e);
      return {
        'velocity': 0.0,
        'trend': 'stable',
        'current_score': 0,
        'previous_score': 0,
      };
    }
  }

  // ===== ENGAGEMENT INSIGHTS =====

  /// Get engagement insights for a recipe
  static Map<String, dynamic> getEngagementInsights(Recipe recipe) {
    final engagement = calculateRecipeEngagement(recipe);
    final insights = <String>[];
    final recommendations = <String>[];

    final engagementScore = engagement['engagement_score'] as int;
    final memberCount = engagement['member_count'] as int;
    final isCollaborative = engagement['is_collaborative'] as bool;

    // Generate insights
    if (engagementScore >= 100) {
      insights.add('This recipe has exceptional engagement');
    } else if (engagementScore >= 50) {
      insights.add('This recipe has good engagement');
    } else {
      insights.add('This recipe has room for engagement improvement');
    }

    if (isCollaborative && memberCount > 5) {
      insights.add('Large collaborative team indicates high interest');
    }

    // Generate recommendations
    if (!isCollaborative) {
      recommendations.add('Consider making this recipe collaborative to increase engagement');
    }

    if (recipe.core.imageUrls.isEmpty) {
      recommendations.add('Add images to make the recipe more engaging');
    }

    if (recipe.core.instructions.length < 3) {
      recommendations.add('Add more detailed instructions to improve completeness');
    }

    return {
      'insights': insights,
      'recommendations': recommendations,
      'engagement_level': engagement['engagement_level'],
      'improvement_potential': engagementScore < 50 ? 'high' : 'low',
    };
  }

  /// Compare engagement between recipes
  static Map<String, dynamic> compareRecipeEngagement(Recipe recipe1, Recipe recipe2) {
    final engagement1 = calculateRecipeEngagement(recipe1);
    final engagement2 = calculateRecipeEngagement(recipe2);

    final score1 = engagement1['engagement_score'] as int;
    final score2 = engagement2['engagement_score'] as int;

    return {
      'recipe1_score': score1,
      'recipe2_score': score2,
      'difference': score1 - score2,
      'winner': score1 > score2 ? 'recipe1' : (score2 > score1 ? 'recipe2' : 'tie'),
      'percentage_difference': score2 > 0 
          ? (((score1 - score2) / score2) * 100).round()
          : 0,
      'engagement_gap': (score1 - score2).abs(),
    };
  }
}