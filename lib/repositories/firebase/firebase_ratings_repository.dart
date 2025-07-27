// lib/repositories/firebase/firebase_ratings_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Firebase implementation of RatingsRepository
class FirebaseRatingsRepository extends BaseFirebaseRepository<RecipeRating>
    implements RatingsRepository {
  
  FirebaseRatingsRepository({
    super.firestore,
    required super.authRepository,
  });

  @override
  String get collectionName => 'recipe_ratings';

  @override
  RecipeRating fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      RecipeRating.fromFirestore(doc.data()!, doc.id);

  @override
  Map<String, dynamic> toFirestore(RecipeRating entity) => entity.toFirestore();

  @override
  String getId(RecipeRating entity) => entity.id;

  // ===== SPECIALIZED RATING OPERATIONS =====

  @override
  Future<void> rateRecipe({
    required String recipeId,
    required String userId,
    required double rating,
    String? review,
  }) async {
    // Validate user is rating with their own account
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'rate recipe',
    );
    
    // Validate rating range
    if (rating < 1 || rating > 5) {
      throw SecurityViolationException(
        'Rating must be between 1 and 5',
        details: 'Rating was: $rating',
      );
    }
    
    final ratingId = '${recipeId}_$userId';
    await collection.doc(ratingId).set({
      'recipeId': recipeId,
      'userId': userId,
      'rating': rating,
      'review': review,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update recipe statistics
    await _updateRecipeRatingStatistics(recipeId);
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_rating',
      operation: 'create',
      granted: true,
      details: 'Recipe: $recipeId, Rating: $rating',
    );
  }

  @override
  Future<void> updateRating({
    required String recipeId,
    required String userId,
    required double rating,
    String? review,
  }) async {
    // Validate user is updating their own rating
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update rating',
    );
    
    // Validate rating range
    if (rating < 1 || rating > 5) {
      throw SecurityViolationException(
        'Rating must be between 1 and 5',
        details: 'Rating was: $rating',
      );
    }
    
    final ratingId = '${recipeId}_$userId';
    
    // Verify rating exists
    final doc = await getDocumentWithPermissionCheck(
      docRef: collection.doc(ratingId),
      currentUserId: currentUser,
      resourceType: 'recipe_rating',
    );
    
    if (!doc.exists) {
      throw ResourceNotFoundException(
        'Rating not found',
        resourceType: 'recipe_rating',
        resourceId: ratingId,
      );
    }
    
    await collection.doc(ratingId).update({
      'rating': rating,
      'review': review,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update recipe statistics
    await _updateRecipeRatingStatistics(recipeId);
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_rating',
      operation: 'update',
      granted: true,
      details: 'Recipe: $recipeId, Rating: $rating',
    );
  }

  @override
  Future<void> removeRating(String recipeId, String userId) async {
    // Validate user is removing their own rating
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'remove rating',
    );
    
    final ratingId = '${recipeId}_$userId';
    
    // Verify rating exists
    final doc = await getDocumentWithPermissionCheck(
      docRef: collection.doc(ratingId),
      currentUserId: currentUser,
      resourceType: 'recipe_rating',
    );
    
    if (!doc.exists) {
      throw ResourceNotFoundException(
        'Rating not found',
        resourceType: 'recipe_rating',
        resourceId: ratingId,
      );
    }
    
    await collection.doc(ratingId).delete();

    // Update recipe statistics
    await _updateRecipeRatingStatistics(recipeId);
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'recipe_rating',
      operation: 'delete',
      granted: true,
      details: 'Recipe: $recipeId',
    );
  }

  @override
  Future<RecipeRating?> getUserRating(String recipeId, String userId) async {
    final ratingId = '${recipeId}_$userId';
    final doc = await collection.doc(ratingId).get();
    
    if (!doc.exists) return null;
    return fromFirestore(doc);
  }

  @override
  Future<List<RecipeRating>> getRecipeRatings(String recipeId) async {
    final querySnapshot = await collection
        .where('recipeId', isEqualTo: recipeId)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => fromFirestore(doc))
        .toList();
  }

  @override
  Future<RatingStatistics> getRatingStatistics(String recipeId) async {
    final ratingsQuery = await collection
        .where('recipeId', isEqualTo: recipeId)
        .get();

    final ratings = ratingsQuery.docs
        .map((doc) => fromFirestore(doc))
        .toList();

    return _calculateRatingStatistics(recipeId, ratings);
  }

  @override
  Future<Map<String, RatingStatistics>> getBulkRatingStatistics(List<String> recipeIds) async {
    final Map<String, RatingStatistics> results = {};

    // Process in batches of 10 (Firestore limit for 'in' queries)
    for (int i = 0; i < recipeIds.length; i += 10) {
      final batch = recipeIds.skip(i).take(10).toList();
      
      final ratingsQuery = await collection
          .where('recipeId', whereIn: batch)
          .get();

      final ratingsByRecipe = <String, List<RecipeRating>>{};
      
      for (final doc in ratingsQuery.docs) {
        final rating = fromFirestore(doc);
        ratingsByRecipe.putIfAbsent(rating.recipeId, () => []).add(rating);
      }

      for (final recipeId in batch) {
        final ratings = ratingsByRecipe[recipeId] ?? [];
        results[recipeId] = _calculateRatingStatistics(recipeId, ratings);
      }
    }

    return results;
  }

  @override
  Stream<RatingStatistics> getRatingStatisticsStream(String recipeId) {
    return collection
        .where('recipeId', isEqualTo: recipeId)
        .snapshots()
        .map((snapshot) {
          final ratings = snapshot.docs
              .map((doc) => fromFirestore(doc))
              .toList();
          return _calculateRatingStatistics(recipeId, ratings);
        });
  }

  @override
  Future<List<RecipeRating>> getUserRatings(String userId) async {
    final querySnapshot = await collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => fromFirestore(doc))
        .toList();
  }

  // ===== PRIVATE HELPER METHODS =====

  RatingStatistics _calculateRatingStatistics(String recipeId, List<RecipeRating> ratings) {
    if (ratings.isEmpty) {
      return RatingStatistics(
        recipeId: recipeId,
        averageRating: 0.0,
        totalRatings: 0,
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
    }

    final totalRating = ratings.fold<double>(0, (total, rating) => total + rating.rating);
    final averageRating = totalRating / ratings.length;

    final Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    DateTime? lastRatedAt;

    for (final rating in ratings) {
      final stars = rating.rating.round().clamp(1, 5);
      distribution[stars] = (distribution[stars] ?? 0) + 1;
      
      if (lastRatedAt == null || rating.createdAt.isAfter(lastRatedAt)) {
        lastRatedAt = rating.createdAt;
      }
    }

    return RatingStatistics(
      recipeId: recipeId,
      averageRating: averageRating,
      totalRatings: ratings.length,
      ratingDistribution: distribution,
      lastRatedAt: lastRatedAt,
    );
  }

  Future<void> _updateRecipeRatingStatistics(String recipeId) async {
    // This could update a separate statistics document for performance
    // For now, statistics are calculated on-demand
    // In production, consider maintaining denormalized stats
  }
}