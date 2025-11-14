import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository interface for recipe rating operations
abstract class RatingsRepository extends Repository<RecipeRating> {
  /// Rate a recipe
  Future<void> rateRecipe({
    required String recipeId,
    required String userId,
    required double rating,
    String? review,
  });

  /// Update an existing rating
  Future<void> updateRating({
    required String recipeId,
    required String userId,
    required double rating,
    String? review,
  });

  /// Remove a rating
  Future<void> removeRating(String recipeId, String userId);

  /// Get user's rating for a recipe
  Future<RecipeRating?> getUserRating(String recipeId, String userId);

  /// Get ratings for a recipe with pagination support
  ///
  /// **Pagination Support (Issue #007 Fix):**
  /// - [limit] Maximum number of ratings to return (default: 100, max: 1000)
  /// - [startAfter] Document snapshot to start after for cursor-based pagination
  ///
  /// **Performance:** O(limit) instead of O(N) - prevents timeouts at 10K+ ratings
  Future<List<RecipeRating>> getRecipeRatings(
    String recipeId, {
    int limit = 100,
    DocumentSnapshot? startAfter,
  });

  /// Get rating statistics for a recipe
  Future<RatingStatistics> getRatingStatistics(String recipeId);

  /// Get rating statistics for multiple recipes
  Future<Map<String, RatingStatistics>> getBulkRatingStatistics(
      List<String> recipeIds);

  /// Get ratings stream for real-time updates
  Stream<RatingStatistics> getRatingStatisticsStream(String recipeId);

  /// Get user's ratings across all recipes
  Future<List<RecipeRating>> getUserRatings(String userId);
}

/// Individual recipe rating
class RecipeRating {
  final String id;
  final String recipeId;
  final String userId;
  final double rating;
  final String? review;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecipeRating({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'recipeId': recipeId,
        'userId': userId,
        'rating': rating,
        'review': review,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory RecipeRating.fromFirestore(Map<String, dynamic> data, String id) =>
      RecipeRating(
        id: id,
        recipeId: data['recipeId'] ?? '',
        userId: data['userId'] ?? '',
        rating: (data['rating'] ?? 0.0).toDouble(),
        review: data['review'],
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt:
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

/// Rating statistics for a recipe
class RatingStatistics {
  final String recipeId;
  final double averageRating;
  final int totalRatings;
  final Map<int, int> ratingDistribution; // star rating -> count
  final DateTime? lastRatedAt;

  RatingStatistics({
    required this.recipeId,
    required this.averageRating,
    required this.totalRatings,
    required this.ratingDistribution,
    this.lastRatedAt,
  });

  /// Get percentage distribution of ratings
  Map<int, double> get percentageDistribution {
    if (totalRatings == 0) return {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    return ratingDistribution.map(
      (stars, ratingCount) =>
          MapEntry(stars, (ratingCount / totalRatings) * 100),
    );
  }

  /// Get display-friendly average rating
  String get displayRating => averageRating.toStringAsFixed(1);
}
