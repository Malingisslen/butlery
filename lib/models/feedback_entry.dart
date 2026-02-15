/// Model representing a user-submitted beta feedback entry.

import 'package:butlery/core/utils/serialization_utils.dart';

/// Category of feedback being submitted.
enum FeedbackCategory { bug, featureRequest, general }

/// A single feedback submission from a beta user.
class FeedbackEntry {
  final String id;
  final String userId;
  final FeedbackCategory category;
  final String description;
  final String? email;
  final String? screenshotUrl;
  final List<Map<String, dynamic>> recentInteractions;
  final DateTime createdAt;
  final String? deviceInfo;

  FeedbackEntry({
    required this.id,
    required this.userId,
    required this.category,
    required this.description,
    this.email,
    this.screenshotUrl,
    required this.recentInteractions,
    required this.createdAt,
    this.deviceInfo,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'category': category.name,
        'description': description,
        'email': email,
        'screenshotUrl': screenshotUrl,
        'recentInteractions': recentInteractions,
        'createdAt': createdAt.toIso8601String(),
        'deviceInfo': deviceInfo,
      };

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    return FeedbackEntry(
      id: SerializationUtils.safeString(map, 'id'),
      userId: SerializationUtils.safeString(map, 'userId'),
      category: _categoryFromString(
        SerializationUtils.safeString(map, 'category', defaultValue: 'general'),
      ),
      description: SerializationUtils.safeString(map, 'description'),
      email: SerializationUtils.safeNullableString(map, 'email'),
      screenshotUrl:
          SerializationUtils.safeNullableString(map, 'screenshotUrl'),
      recentInteractions: SerializationUtils.safeList<Map<String, dynamic>>(
        map,
        'recentInteractions',
        (item) => item is Map<String, dynamic> ? item : <String, dynamic>{},
      ),
      createdAt: SerializationUtils.safeRequiredDateTime(map, 'createdAt'),
      deviceInfo: SerializationUtils.safeNullableString(map, 'deviceInfo'),
    );
  }

  static FeedbackCategory _categoryFromString(String value) {
    switch (value) {
      case 'bug':
        return FeedbackCategory.bug;
      case 'featureRequest':
        return FeedbackCategory.featureRequest;
      default:
        return FeedbackCategory.general;
    }
  }
}
