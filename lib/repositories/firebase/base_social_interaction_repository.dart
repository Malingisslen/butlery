/// Specialized metadata repository for social interaction tracking (likes, ratings, etc.).
/// Extends BaseMetadataRepository to provide convenient methods for tracking
/// social interactions like likes, ratings, and favorites.
/// **Use Cases:**
/// - Recipe comments: Track likes on comments
/// - Menu collaboration: Track likes on menus
/// - Ratings: Track user ratings and reviews
/// - Social content: Track any like/favorite interactions
/// **Usage Example:**
/// ```dart
/// class CommentLikeRepository extends BaseSocialInteractionRepository {
///   CommentLikeRepository({
///     required super.authRepository,
///     super.auditRepository,
///   });
///   @override
///   String get parentCollectionName => 'recipe_comments';
///   @override
///   Future<bool> validateMetadataAccess(String userId, String resourceId) async {
///     // User can like if they can read the comment
///     final comment = await _commentRepository.read(resourceId);
///     return comment != null;
///   }
/// }
/// ```

import 'package:butlery/repositories/firebase/base_metadata_repository.dart';
import 'package:butlery/models/metadata/interaction_metadata.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Base repository for social interaction metadata operations.
/// Provides convenient methods for tracking likes, ratings, and other social interactions.
/// Metadata stored in subcollections: {parent_collection}/{resource_id}/interactions/{user_id}
abstract class BaseSocialInteractionRepository
    extends BaseMetadataRepository<InteractionMetadata> {
  BaseSocialInteractionRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  /// The metadata type for interaction tracking
  @override
  String get metadataType => 'interaction';

  /// Convert Firestore document to InteractionMetadata
  @override
  InteractionMetadata fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return InteractionMetadata.fromFirestore(doc);
  }

  /// Convert InteractionMetadata to Firestore data
  @override
  Map<String, dynamic> toFirestore(InteractionMetadata metadata) {
    return metadata.toFirestore();
  }

  /// Toggle like on content (like if not liked, unlike if liked).
  /// [resourceId] ID of the content being liked/unliked
  /// [cachedCountField] Optional field name for cached like count in parent document
  /// **Security**: Validates metadata access and enforces self-annotation
  /// **Audit**: Logs like/unlike operation to FirebaseAuditRepository (GDPR Article 30)
  /// **Use Case**: User clicks like button on comment → toggle like and update count
  Future<void> toggleLike(
    String resourceId, {
    String cachedCountField = 'likeCount',
  }) async {
    final userId = requireCurrentUserId();
    final hasLiked = await hasMetadata(resourceId, userId);

    if (hasLiked) {
      // Unlike
      await removeMetadata(resourceId, userId);
      await incrementParentField(resourceId, cachedCountField, amount: -1);
    } else {
      // Like
      await addMetadata(
        resourceId,
        userId,
        additionalData: {
          'interactionType': 'like',
        },
      );
      await incrementParentField(resourceId, cachedCountField, amount: 1);
    }
  }

  /// Check if the current user has liked the content.
  /// [resourceId] ID of the content to check
  /// Returns true if the current user has liked the content, false otherwise
  /// **Note**: No permission validation (existence check is non-sensitive)
  Future<bool> hasLiked(String resourceId) async {
    final userId = requireCurrentUserId();
    return await hasMetadata(resourceId, userId);
  }

  /// Get the interaction metadata for the current user.
  /// [resourceId] ID of the content
  /// Returns InteractionMetadata if exists, null otherwise
  /// **Security**: Validates metadata access before returning data
  Future<InteractionMetadata?> getUserInteraction(String resourceId) async {
    final userId = requireCurrentUserId();
    return await getMetadata(resourceId, userId);
  }

  /// Get all interactions for the content.
  /// [resourceId] ID of the content
  /// Returns list of InteractionMetadata for all interactions
  /// **Security**: Validates metadata access before returning data
  /// **Use Case**: Display all ratings for a recipe
  Future<List<InteractionMetadata>> getInteractions(String resourceId) async {
    return await getMetadataForResource(resourceId);
  }

  /// Get the number of interactions.
  /// [resourceId] ID of the content
  /// Returns count of interactions
  /// **Security**: Validates metadata access before returning count
  /// **Use Case**: Display like count, rating count
  Future<int> getInteractionCount(String resourceId) async {
    return await getMetadataCount(resourceId);
  }

  /// Get interactions filtered by type.
  /// [resourceId] ID of the content
  /// [interactionType] Filter by interaction type ('like', 'rating', 'favorite')
  /// Returns list of InteractionMetadata matching the type
  /// **Security**: Validates metadata access before returning data
  /// **Use Case**: Get only ratings (exclude likes)
  Future<List<InteractionMetadata>> getInteractionsByType(
    String resourceId,
    String interactionType,
  ) async {
    final allInteractions = await getInteractions(resourceId);
    return allInteractions
        .where((i) => i.interactionType == interactionType)
        .toList();
  }

  /// Calculate average rating from rating interactions.
  /// [resourceId] ID of the content
  /// Returns average rating value, or null if no ratings exist
  /// **Security**: Validates metadata access before calculating
  /// **Use Case**: Display "4.5 stars (12 ratings)"
  Future<double?> calculateAverageRating(String resourceId) async {
    final ratings = await getInteractionsByType(resourceId, 'rating');

    if (ratings.isEmpty) {
      return null;
    }

    final total = ratings.fold<double>(
      0.0,
      (acc, rating) => acc + (rating.value ?? 0.0),
    );

    return total / ratings.length;
  }
}
