/// Metadata model for social interaction tracking (likes, ratings, etc.).
/// Represents a user's social interaction with content (liking, rating, etc.).
/// Used by BaseSocialInteractionRepository to track social engagement.
/// Stored in subcollections: {parent_collection}/{resource_id}/interactions/{user_id}
/// **Use Cases:**
/// - Recipe comments: Track likes on comments
/// - Menu collaboration: Track likes on menus
/// - Ratings: Track user ratings and reviews
/// - Social content: Track any like/favorite interactions

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

class InteractionMetadata {
  final String userId;
  final DateTime interactedAt;
  final String interactionType; // 'like', 'rating', 'favorite', etc.
  final double? value; // Optional numeric value (e.g., rating score 1-5)
  final String? comment; // Optional text comment

  InteractionMetadata({
    required this.userId,
    required this.interactedAt,
    required this.interactionType,
    this.value,
    this.comment,
  });

  /// Create InteractionMetadata from Firestore document
  factory InteractionMetadata.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return InteractionMetadata(
      userId: SerializationUtils.safeString(data, 'userId'),
      interactedAt: SerializationUtils.safeRequiredDateTime(data, 'timestamp'),
      interactionType: SerializationUtils.safeString(data, 'interactionType'),
      value: SerializationUtils.safeNullableDouble(data, 'value'),
      comment: SerializationUtils.safeNullableString(data, 'comment'),
    );
  }

  /// Convert InteractionMetadata to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'timestamp': DateTime.now(),
      'interactionType': interactionType,
      if (value != null) 'value': value,
      if (comment != null) 'comment': comment,
    };
  }

  @override
  String toString() =>
      'InteractionMetadata(userId: $userId, type: $interactionType, interactedAt: $interactedAt, value: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InteractionMetadata &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          interactedAt == other.interactedAt &&
          interactionType == other.interactionType &&
          value == other.value &&
          comment == other.comment;

  @override
  int get hashCode =>
      userId.hashCode ^
      interactedAt.hashCode ^
      interactionType.hashCode ^
      value.hashCode ^
      comment.hashCode;
}
