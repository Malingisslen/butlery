/// Model representing a user-submitted beta feedback entry.

import 'package:butlery/core/utils/serialization_utils.dart';

/// Category of feedback being submitted.
enum FeedbackCategory { bug, featureRequest, general }

/// Triage state of a feedback entry, set by an admin in the dashboard.
/// New submissions default to [newReport]; existing docs without the field
/// read as [newReport] (lazy-compat, no backfill).
///
/// [wireName] is the persisted Firestore value ('new' | 'triaged' |
/// 'resolved') — kept stable so it never depends on the Dart enum name.
enum FeedbackStatus {
  newReport('new'),
  triaged('triaged'),
  resolved('resolved')
  ;

  const FeedbackStatus(this.wireName);

  final String wireName;

  static FeedbackStatus fromWire(String value) {
    for (final status in FeedbackStatus.values) {
      if (status.wireName == value) return status;
    }
    return FeedbackStatus.newReport;
  }
}

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
  final FeedbackStatus status;

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
    this.status = FeedbackStatus.newReport,
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
    'status': status.wireName,
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
      screenshotUrl: SerializationUtils.safeNullableString(
        map,
        'screenshotUrl',
      ),
      recentInteractions: SerializationUtils.safeList<Map<String, dynamic>>(
        map,
        'recentInteractions',
        (item) => item is Map<String, dynamic> ? item : <String, dynamic>{},
      ),
      createdAt: SerializationUtils.safeRequiredDateTime(map, 'createdAt'),
      deviceInfo: SerializationUtils.safeNullableString(map, 'deviceInfo'),
      status: FeedbackStatus.fromWire(
        SerializationUtils.safeString(map, 'status', defaultValue: 'new'),
      ),
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
