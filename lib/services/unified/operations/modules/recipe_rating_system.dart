// lib/services/unified/operations/modules/recipe_rating_system.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/recipe_unified.dart';
import '../../../../core/utils/logger.dart';

/// Focused module for recipe rating system
/// 
/// This module handles ONLY recipe rating operations:
/// - Recipe rating creation and validation
/// - User rating queries and management
/// - Rating permission checking
/// - Individual rating data operations
/// 
/// ❌ DOES NOT CONTAIN: Statistics aggregation, social metrics, notifications, top-rated queries
class RecipeRatingSystem {
  static const String _ratingsCollection = 'recipe_ratings';

  // ===== RATING OPERATIONS =====

  /// Rate a recipe with validation
  static Future<bool> rateRecipe({
    required FirebaseFirestore firestore,
    required String recipeId,
    required double rating,
    required String currentUserId,
    required String currentUserDisplayName,
    String? review,
    required bool Function(Recipe) canRateValidator,
    required Recipe? Function(String) recipeGetter,
  }) async {
    try {
      AppLogger.info('⭐ Rating recipe $recipeId with $rating stars');

      if (rating < 1.0 || rating > 5.0) {
        AppLogger.error('❌ Rating must be between 1.0 and 5.0');
        return false;
      }

      // Find the recipe
      final recipe = recipeGetter(recipeId);
      if (recipe == null) {
        AppLogger.error('❌ Cannot rate recipe: Recipe not found');
        return false;
      }

      // Check if user has permission to rate this recipe
      if (!canRateValidator(recipe)) {
        AppLogger.error('❌ User does not have permission to rate this recipe');
        return false;
      }

      // Create or update rating
      final ratingId = '${recipeId}_$currentUserId';
      final ratingData = {
        'recipeId': recipeId,
        'userId': currentUserId,
        'userDisplayName': currentUserDisplayName,
        'rating': rating,
        'review': review?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .set(ratingData, SetOptions(merge: true));

      AppLogger.success('✅ Recipe rated successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to rate recipe', e);
      return false;
    }
  }

  /// Get user's rating for a specific recipe
  static Future<Map<String, dynamic>?> getUserRating({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String userId,
  }) async {
    try {
      final ratingId = '${recipeId}_$userId';
      final ratingDoc = await firestore
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

  /// Get all ratings for a recipe
  static Future<List<Map<String, dynamic>>> getRecipeRatings({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    try {
      AppLogger.debug('📊 Getting ratings for recipe $recipeId');

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
          'updatedAt': data['updatedAt'],
        };
      }).toList();

      AppLogger.debug('📋 Found ${ratings.length} ratings');
      return ratings;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipe ratings', e);
      return [];
    }
  }

  /// Update existing rating
  static Future<bool> updateRating({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String userId,
    required double rating,
    String? review,
  }) async {
    try {
      AppLogger.info('✏️ Updating rating for recipe $recipeId');

      if (rating < 1.0 || rating > 5.0) {
        AppLogger.error('❌ Rating must be between 1.0 and 5.0');
        return false;
      }

      final ratingId = '${recipeId}_$userId';
      
      // Check if rating exists
      final ratingDoc = await firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .get();

      if (!ratingDoc.exists) {
        AppLogger.error('❌ Cannot update: Rating not found');
        return false;
      }

      // Update rating
      await firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .update({
        'rating': rating,
        'review': review?.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('✅ Rating updated successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to update rating', e);
      return false;
    }
  }

  /// Delete user's rating for a recipe
  static Future<bool> deleteRating({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String userId,
  }) async {
    try {
      AppLogger.info('🗑️ Deleting rating for recipe $recipeId');

      final ratingId = '${recipeId}_$userId';
      await firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .delete();

      AppLogger.success('✅ Rating deleted successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to delete rating', e);
      return false;
    }
  }

  // ===== RATING QUERIES =====

  /// Get rating count for a recipe
  static Future<int> getRatingCount({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    try {
      final ratingsSnapshot = await firestore
          .collection(_ratingsCollection)
          .where('recipeId', isEqualTo: recipeId)
          .get();

      return ratingsSnapshot.docs.length;
    } catch (e) {
      AppLogger.error('❌ Failed to get rating count', e);
      return 0;
    }
  }

  /// Check if user has rated a recipe
  static Future<bool> hasUserRated({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String userId,
  }) async {
    try {
      final ratingId = '${recipeId}_$userId';
      final ratingDoc = await firestore
          .collection(_ratingsCollection)
          .doc(ratingId)
          .get();

      return ratingDoc.exists;
    } catch (e) {
      AppLogger.error('❌ Failed to check if user has rated', e);
      return false;
    }
  }

  /// Get ratings given by a specific user
  static Future<List<Map<String, dynamic>>> getUserGivenRatings({
    required FirebaseFirestore firestore,
    required String userId,
    int? limit,
  }) async {
    try {
      AppLogger.debug('📊 Getting ratings given by user $userId');

      Query query = firestore
          .collection(_ratingsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final ratings = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'recipeId': data['recipeId'],
          'rating': data['rating'],
          'review': data['review'],
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
        };
      }).toList();

      AppLogger.debug('📋 Found ${ratings.length} ratings given by user');
      return ratings;
    } catch (e) {
      AppLogger.error('❌ Failed to get user given ratings', e);
      return [];
    }
  }

  /// Get ratings received for user's recipes
  static Future<List<Map<String, dynamic>>> getUserReceivedRatings({
    required FirebaseFirestore firestore,
    required List<String> userRecipeIds,
    int? limit,
  }) async {
    try {
      AppLogger.debug('📊 Getting ratings received for ${userRecipeIds.length} recipes');

      final allRatings = <Map<String, dynamic>>[];

      // Process in batches to avoid Firestore query limits
      const batchSize = 10;
      for (int i = 0; i < userRecipeIds.length; i += batchSize) {
        final batch = userRecipeIds.skip(i).take(batchSize).toList();
        
        final batchRatings = await firestore
            .collection(_ratingsCollection)
            .where('recipeId', whereIn: batch)
            .get();

        for (final doc in batchRatings.docs) {
          final data = doc.data();
          allRatings.add({
            'recipeId': data['recipeId'],
            'userId': data['userId'],
            'userDisplayName': data['userDisplayName'],
            'rating': data['rating'],
            'review': data['review'],
            'createdAt': data['createdAt'],
          });
        }
      }

      // Sort by creation date (most recent first)
      allRatings.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      // Apply limit if specified
      final result = limit != null 
          ? allRatings.take(limit).toList()
          : allRatings;

      AppLogger.debug('📋 Found ${result.length} ratings received');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get user received ratings', e);
      return [];
    }
  }

  // ===== RATING VALIDATION =====

  /// Validate rating value
  static bool isValidRating(double rating) {
    return rating >= 1.0 && rating <= 5.0;
  }

  /// Validate review content
  static bool isValidReview(String? review) {
    if (review == null) return true; // Reviews are optional
    final trimmed = review.trim();
    return trimmed.length <= 1000; // Max 1000 characters
  }

  /// Sanitize review content
  static String? sanitizeReview(String? review) {
    if (review == null) return null;
    final trimmed = review.trim();
    if (trimmed.isEmpty) return null;
    
    // Basic sanitization - remove excessive whitespace
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  // ===== PERMISSION HELPERS =====

  /// Check if user can rate a specific recipe
  static bool canUserRateRecipe({
    required Recipe recipe,
    required String? currentUserId,
  }) {
    if (currentUserId == null) return false;

    // Can't rate own recipe
    final ownerId = recipe.socialData?.ownerId ?? recipe.core.createdBy;
    if (ownerId == currentUserId) return false;

    // For personal recipes, can't rate unless you're the owner (already excluded above)
    if (recipe.isPersonal) return false;

    // For collaborative recipes, must be a member
    if (recipe.isCollaborative) {
      return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ?? false;
    }

    return false;
  }

  /// Check if user can view recipe's ratings
  static bool canUserViewRatings({
    required Recipe recipe,
    required String? currentUserId,
  }) {
    if (currentUserId == null) return false;

    // Always can view own recipes' ratings
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

  /// Check if user can edit/delete their rating
  static bool canUserEditRating({
    required String ratingUserId,
    required String? currentUserId,
  }) {
    return currentUserId != null && ratingUserId == currentUserId;
  }

  // ===== RATING UTILITIES =====

  /// Format rating for display
  static String formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }

  /// Get star representation of rating
  static String getStarRepresentation(double rating) {
    final fullStars = rating.floor();
    final hasHalfStar = (rating - fullStars) >= 0.5;
    
    String stars = '⭐' * fullStars;
    if (hasHalfStar && fullStars < 5) {
      stars += '✨'; // Half star representation
    }
    
    return stars;
  }

  /// Get rating category
  static String getRatingCategory(double rating) {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 4.0) return 'Very Good';
    if (rating >= 3.5) return 'Good';
    if (rating >= 3.0) return 'Average';
    if (rating >= 2.0) return 'Below Average';
    return 'Poor';
  }

  /// Check if rating is recent
  static bool isRecentRating(Timestamp? createdAt, {int daysThreshold = 7}) {
    if (createdAt == null) return false;
    
    final now = DateTime.now();
    final ratingDate = createdAt.toDate();
    final daysDifference = now.difference(ratingDate).inDays;
    
    return daysDifference <= daysThreshold;
  }
}