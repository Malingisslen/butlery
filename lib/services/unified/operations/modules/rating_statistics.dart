// lib/services/unified/operations/modules/rating_statistics.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Focused module for rating statistics and aggregation
/// 
/// This module handles ONLY rating statistics operations:
/// - Rating statistics calculation and aggregation
/// - Rating distribution analysis
/// - Top-rated recipe queries and ranking
/// - Rating aggregate management
/// 
/// ❌ DOES NOT CONTAIN: Individual rating operations, social metrics, notifications, engagement scoring
class RatingStatistics {
  static const String _ratingsCollection = 'recipe_ratings';
  static const String _socialStatsCollection = 'recipe_social_stats';

  // ===== RATING STATISTICS CALCULATION =====

  /// Calculate comprehensive rating statistics
  static Map<String, dynamic> calculateRatingStatistics(List<Map<String, dynamic>> ratings) {
    if (ratings.isEmpty) {
      return {
        'count': 0,
        'average': 0.0,
        'distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        'reviews': [],
        'recent_reviews': [],
        'review_count': 0,
        'review_percentage': 0,
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

  /// Get comprehensive recipe statistics with ratings
  static Future<Map<String, dynamic>> getRecipeStatistics({
    required FirebaseFirestore firestore,
    required String recipeId,
    required Recipe recipe,
  }) async {
    try {
      AppLogger.debug('📊 Getting comprehensive statistics for recipe $recipeId');

      // Get all ratings for this recipe
      final ratingsSnapshot = await firestore
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

      // Calculate rating statistics
      final ratingStats = calculateRatingStatistics(ratings);

      // Combine recipe info with statistics
      final result = {
        'recipe': {
          'id': recipe.id,
          'title': recipe.core.title,
          'owner': recipe.socialData?.ownerDisplayName ?? 'Unknown',
          'isCollaborative': recipe.isCollaborative,
          'memberCount': (recipe.socialData?.memberPermissions?.length ?? 0) + 1,
          'createdAt': recipe.core.createdAt.toIso8601String(),
          'updatedAt': recipe.core.updatedAt.toIso8601String(),
        },
        'ratings': ratingStats,
      };

      AppLogger.debug('📋 Generated comprehensive recipe statistics');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipe statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  // ===== RATING AGGREGATION =====

  /// Update aggregated rating for recipe
  static Future<void> updateRecipeRatingAggregate({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    try {
      AppLogger.debug('📊 Updating rating aggregate for recipe $recipeId');

      // Get all ratings for the recipe
      final ratingsSnapshot = await firestore
          .collection(_ratingsCollection)
          .where('recipeId', isEqualTo: recipeId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        // No ratings, remove aggregate
        await firestore
            .collection(_socialStatsCollection)
            .doc(recipeId)
            .delete();
        AppLogger.debug('📋 Removed rating aggregate (no ratings)');
        return;
      }

      final ratings = ratingsSnapshot.docs.map((doc) => doc.data()).toList();
      final stats = calculateRatingStatistics(ratings);

      // Store aggregate data
      await firestore
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

      AppLogger.debug('✅ Updated rating aggregate for recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Failed to update rating aggregate', e);
      rethrow;
    }
  }

  /// Get cached rating aggregate
  static Future<Map<String, dynamic>?> getCachedRatingAggregate({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    try {
      final doc = await firestore
          .collection(_socialStatsCollection)
          .doc(recipeId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'count': data['ratingCount'] ?? 0,
        'average': data['averageRating'] ?? 0.0,
        'distribution': data['ratingDistribution'] ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        'review_count': data['reviewCount'] ?? 0,
        'last_updated': data['lastUpdated'],
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get cached rating aggregate', e);
      return null;
    }
  }

  // ===== TOP-RATED QUERIES =====

  /// Get top-rated recipes with filtering
  static Future<List<Map<String, dynamic>>> getTopRatedRecipes({
    required FirebaseFirestore firestore,
    required List<Recipe> accessibleRecipes,
    int limit = 10,
    double minRating = 4.0,
    int minRatingCount = 3,
  }) async {
    try {
      AppLogger.info('🏆 Getting top-rated recipes (${accessibleRecipes.length} candidates)');

      final recipeStats = <Map<String, dynamic>>[];
      
      // ✅ PERFORMANCE FIX: Batch query cached stats instead of N+1 queries
      // First, try to get cached stats for all recipes in batches
      final cachedStatsMap = await _batchGetCachedRatingAggregates(
        firestore: firestore,
        recipeIds: accessibleRecipes.map((r) => r.id).toList(),
      );
      
      for (final recipe in accessibleRecipes) {
        Map<String, dynamic> ratingStats;
        final cachedStats = cachedStatsMap[recipe.id];
        
        if (cachedStats != null) {
          ratingStats = cachedStats;
        } else {
          // Calculate fresh stats only for uncached recipes
          final fullStats = await getRecipeStatistics(
            firestore: firestore,
            recipeId: recipe.id,
            recipe: recipe,
          );
          
          if (fullStats.containsKey('error')) continue;
          ratingStats = fullStats['ratings'] as Map<String, dynamic>;
        }

        final averageRating = ratingStats['average'] as double? ?? 0.0;
        final ratingCount = ratingStats['count'] as int? ?? 0;

        if (averageRating >= minRating && ratingCount >= minRatingCount) {
          recipeStats.add({
            'recipe': recipe,
            'averageRating': averageRating,
            'ratingCount': ratingCount,
            'ratingStats': ratingStats,
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

  /// Get recipes by rating range
  static Future<List<Map<String, dynamic>>> getRecipesByRatingRange({
    required List<Recipe> recipes,
    required double minRating,
    required double maxRating,
    required Future<Map<String, dynamic>> Function(String) statsGetter,
  }) async {
    try {
      final filteredRecipes = <Map<String, dynamic>>[];

      for (final recipe in recipes) {
        final stats = await statsGetter(recipe.id);
        if (stats.containsKey('error')) continue;

        final ratingStats = stats['ratings'] as Map<String, dynamic>?;
        if (ratingStats == null) continue;

        final averageRating = ratingStats['average'] as double? ?? 0.0;
        
        if (averageRating >= minRating && averageRating <= maxRating) {
          filteredRecipes.add({
            'recipe': recipe,
            'averageRating': averageRating,
            'ratingCount': ratingStats['count'] ?? 0,
            'stats': stats,
          });
        }
      }

      // Sort by rating descending
      filteredRecipes.sort((a, b) => 
          (b['averageRating'] as double).compareTo(a['averageRating'] as double));

      return filteredRecipes;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipes by rating range', e);
      return [];
    }
  }

  // ===== RATING DISTRIBUTION ANALYSIS =====

  /// Analyze rating distribution patterns
  static Map<String, dynamic> analyzeRatingDistribution(Map<int, int> distribution) {
    final totalRatings = distribution.values.fold<int>(0, (total, itemCount) => total + itemCount);
    
    if (totalRatings == 0) {
      return {
        'pattern': 'no_ratings',
        'skew': 'none',
        'dominant_rating': 0,
        'distribution_type': 'empty',
      };
    }

    // Calculate percentages
    final percentages = <int, double>{};
    for (final entry in distribution.entries) {
      percentages[entry.key] = (entry.value / totalRatings) * 100;
    }

    // Find dominant rating
    final dominantEntry = distribution.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    final dominantRating = dominantEntry.key;
    final dominantPercentage = percentages[dominantRating]!;

    // Determine distribution pattern
    String pattern;
    if (dominantPercentage >= 60) {
      pattern = 'highly_concentrated';
    } else if (dominantPercentage >= 40) {
      pattern = 'concentrated';
    } else {
      pattern = 'distributed';
    }

    // Determine skew
    final highRatings = (distribution[4] ?? 0) + (distribution[5] ?? 0);
    final lowRatings = (distribution[1] ?? 0) + (distribution[2] ?? 0);
    // final midRatings = distribution[3] ?? 0; // Currently unused

    String skew;
    if (highRatings > lowRatings * 1.5) {
      skew = 'positive'; // Skewed toward high ratings
    } else if (lowRatings > highRatings * 1.5) {
      skew = 'negative'; // Skewed toward low ratings
    } else {
      skew = 'balanced';
    }

    // Determine distribution type
    String distributionType;
    if (dominantRating >= 4) {
      distributionType = 'high_quality';
    } else if (dominantRating <= 2) {
      distributionType = 'low_quality';
    } else {
      distributionType = 'average_quality';
    }

    return {
      'pattern': pattern,
      'skew': skew,
      'dominant_rating': dominantRating,
      'dominant_percentage': dominantPercentage.round(),
      'distribution_type': distributionType,
      'percentages': percentages,
      'total_ratings': totalRatings,
      'high_ratings_percentage': ((highRatings / totalRatings) * 100).round(),
      'low_ratings_percentage': ((lowRatings / totalRatings) * 100).round(),
    };
  }

  /// Get rating trends over time
  static Map<String, dynamic> calculateRatingTrends(List<Map<String, dynamic>> ratings) {
    if (ratings.length < 2) {
      return {
        'trend': 'insufficient_data',
        'direction': 'stable',
        'recent_average': 0.0,
        'older_average': 0.0,
      };
    }

    // Sort by creation date
    final sortedRatings = List<Map<String, dynamic>>.from(ratings);
    sortedRatings.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    // Split into older and recent ratings
    final splitPoint = (sortedRatings.length * 0.6).round();
    final olderRatings = sortedRatings.take(splitPoint).toList();
    final recentRatings = sortedRatings.skip(splitPoint).toList();

    // Calculate averages
    final olderAverage = olderRatings.isEmpty ? 0.0 :
        olderRatings.fold<double>(0.0, (total, r) => total + (r['rating'] as double)) / olderRatings.length;
    
    final recentAverage = recentRatings.isEmpty ? 0.0 :
        recentRatings.fold<double>(0.0, (total, r) => total + (r['rating'] as double)) / recentRatings.length;

    // Determine trend direction
    String direction;
    String trend;
    
    final difference = recentAverage - olderAverage;
    if (difference.abs() < 0.2) {
      direction = 'stable';
      trend = 'consistent';
    } else if (difference > 0) {
      direction = 'improving';
      trend = difference > 0.5 ? 'strongly_improving' : 'slightly_improving';
    } else {
      direction = 'declining';
      trend = difference < -0.5 ? 'strongly_declining' : 'slightly_declining';
    }

    return {
      'trend': trend,
      'direction': direction,
      'recent_average': double.parse(recentAverage.toStringAsFixed(1)),
      'older_average': double.parse(olderAverage.toStringAsFixed(1)),
      'difference': double.parse(difference.toStringAsFixed(1)),
      'recent_count': recentRatings.length,
      'older_count': olderRatings.length,
    };
  }

  // ===== BATCH OPERATIONS =====

  /// Batch get cached rating aggregates for multiple recipes
  /// ✅ PERFORMANCE FIX: Reduces N+1 queries to batch queries
  static Future<Map<String, Map<String, dynamic>>> _batchGetCachedRatingAggregates({
    required FirebaseFirestore firestore,
    required List<String> recipeIds,
  }) async {
    final results = <String, Map<String, dynamic>>{};
    
    if (recipeIds.isEmpty) return results;
    
    // Firestore allows max 10 documents in whereIn query
    const batchSize = 10;
    
    for (int i = 0; i < recipeIds.length; i += batchSize) {
      final batch = recipeIds.skip(i).take(batchSize).toList();
      
      try {
        final querySnapshot = await firestore
            .collection(_socialStatsCollection)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
            
        for (final doc in querySnapshot.docs) {
          if (doc.exists) {
            final data = doc.data();
            results[doc.id] = {
              'count': data['ratingCount'] ?? 0,
              'average': data['averageRating'] ?? 0.0,
              'distribution': data['ratingDistribution'] ?? {},
            };
          }
        }
      } catch (e) {
        AppLogger.error('Failed to batch get cached rating aggregates for batch: $batch', e);
        // Continue with other batches
      }
    }
    
    return results;
  }

  /// Update multiple recipe rating aggregates
  static Future<void> updateMultipleRatingAggregates({
    required FirebaseFirestore firestore,
    required List<String> recipeIds,
  }) async {
    try {
      AppLogger.info('📊 Updating ${recipeIds.length} rating aggregates');

      final futures = recipeIds.map((recipeId) => 
        updateRecipeRatingAggregate(
          firestore: firestore,
          recipeId: recipeId,
        )
      );

      await Future.wait(futures);
      AppLogger.success('✅ Updated ${recipeIds.length} rating aggregates');
    } catch (e) {
      AppLogger.error('❌ Failed to update multiple rating aggregates', e);
      rethrow;
    }
  }

  /// Get rating statistics for multiple recipes
  static Future<Map<String, Map<String, dynamic>>> getMultipleRecipeStatistics({
    required FirebaseFirestore firestore,
    required Map<String, Recipe> recipeMap,
  }) async {
    try {
      final results = <String, Map<String, dynamic>>{};

      final futures = recipeMap.entries.map((entry) async {
        final stats = await getRecipeStatistics(
          firestore: firestore,
          recipeId: entry.key,
          recipe: entry.value,
        );
        return MapEntry(entry.key, stats);
      });

      final statsList = await Future.wait(futures);
      
      for (final entry in statsList) {
        results[entry.key] = entry.value;
      }

      return results;
    } catch (e) {
      AppLogger.error('❌ Failed to get multiple recipe statistics', e);
      return {};
    }
  }
}