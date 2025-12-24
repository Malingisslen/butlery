import 'package:butlery/core/utils/serialization_utils.dart';

/// Feedback types for recommendations
enum FeedbackType {
  like,
  dismiss,
  save,
  notInterested,
}

/// Recommendation types
enum RecommendationType {
  similarToShared,
  trendingForYou,
  basedOnFriends,
  seasonal,
  dietaryPreference,
  quickMeal,
  weekendSpecial,
}

/// Recommendation model
class Recommendation {
  final String id;
  final String contentId;
  final String contentType; // 'recipe', 'menu', 'shopping_list'
  final String title;
  final String description;
  final String reason;
  final RecommendationType type;
  double score; // 0.0 - 1.0 relevance score
  final String? imageUrl;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  bool isDismissed;
  bool isLiked;

  Recommendation({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.title,
    required this.description,
    required this.reason,
    required this.type,
    required this.score,
    this.imageUrl,
    this.metadata,
    DateTime? createdAt,
    this.isDismissed = false,
    this.isLiked = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contentId': contentId,
      'contentType': contentType,
      'title': title,
      'description': description,
      'reason': reason,
      'type': _getTypeString(type),
      'score': score,
      'imageUrl': imageUrl,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'isDismissed': isDismissed,
      'isLiked': isLiked,
    };
  }

  factory Recommendation.fromMap(Map<String, dynamic> map) {
    return Recommendation(
      id: SerializationUtils.safeString(map, 'id'),
      contentId: SerializationUtils.safeString(map, 'contentId'),
      contentType: SerializationUtils.safeString(map, 'contentType'),
      title: SerializationUtils.safeString(map, 'title'),
      description: SerializationUtils.safeString(map, 'description'),
      reason: SerializationUtils.safeString(map, 'reason'),
      type: _parseType(SerializationUtils.safeString(map, 'type')),
      score: SerializationUtils.safeDouble(map, 'score'),
      imageUrl: SerializationUtils.safeNullableString(map, 'imageUrl'),
      metadata: SerializationUtils.safeNullableMap(map, 'metadata'),
      createdAt:
          SerializationUtils.safeDateTime(map, 'createdAt') ?? DateTime.now(),
      isDismissed:
          SerializationUtils.safeBool(map, 'isDismissed', defaultValue: false),
      isLiked: SerializationUtils.safeBool(map, 'isLiked', defaultValue: false),
    );
  }

  static String _getTypeString(RecommendationType type) {
    switch (type) {
      case RecommendationType.similarToShared:
        return 'similar_to_shared';
      case RecommendationType.trendingForYou:
        return 'trending_for_you';
      case RecommendationType.basedOnFriends:
        return 'based_on_friends';
      case RecommendationType.seasonal:
        return 'seasonal';
      case RecommendationType.dietaryPreference:
        return 'dietary_preference';
      case RecommendationType.quickMeal:
        return 'quick_meal';
      case RecommendationType.weekendSpecial:
        return 'weekend_special';
    }
  }

  static RecommendationType _parseType(String typeString) {
    switch (typeString) {
      case 'similar_to_shared':
        return RecommendationType.similarToShared;
      case 'trending_for_you':
        return RecommendationType.trendingForYou;
      case 'based_on_friends':
        return RecommendationType.basedOnFriends;
      case 'seasonal':
        return RecommendationType.seasonal;
      case 'dietary_preference':
        return RecommendationType.dietaryPreference;
      case 'quick_meal':
        return RecommendationType.quickMeal;
      case 'weekend_special':
        return RecommendationType.weekendSpecial;
      default:
        return RecommendationType.trendingForYou;
    }
  }
}
