// lib/models/social/activity_feed_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/social/activity_engagement.dart';
import 'package:butlery/models/social/activity_type.dart';

// Export dependencies so consumers can use ActivityType and ActivityEngagement
export 'package:butlery/models/social/activity_engagement.dart';
export 'package:butlery/models/social/activity_type.dart';

/// Activity feed item for social streams with engagement metrics and privacy controls.
/// ```dart
/// final a = ActivityFeedItem.create(userId: uid, type: ActivityType.recipeCreated,
///   targetId: rid, targetTitle: 'Köttbullar', visibility: ['close_friends']);
class ActivityFeedItem {
  /// Unique identifier for this activity
  final String id;

  /// User who performed the activity
  final String userId;

  /// Display name of user who performed the activity
  final String userDisplayName;

  /// User's avatar URL (for display optimization)
  final String? userAvatarUrl;

  /// Type of activity performed
  final ActivityType type;

  /// ID of the target content (recipe, menu, comment, etc.)
  final String targetId;

  /// Type of target content for proper handling
  final String targetType;

  /// Display title of the target content
  final String targetTitle;

  /// URL for target content image (recipes, menus)
  final String? targetImageUrl;

  /// Parent content ID (for comments, replies, etc.)
  final String? parentId;

  /// Parent content type (for nested activities)
  final String? parentType;

  /// When this activity occurred
  final DateTime timestamp;

  /// Friend categories that can see this activity
  final List<String> visibility;

  /// Activity-specific metadata (reaction type, share targets, etc.)
  final Map<String, dynamic> metadata;

  /// Engagement metrics for this activity
  final ActivityEngagement engagement;

  const ActivityFeedItem({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    this.userAvatarUrl,
    required this.type,
    required this.targetId,
    required this.targetType,
    required this.targetTitle,
    this.targetImageUrl,
    this.parentId,
    this.parentType,
    required this.timestamp,
    required this.visibility,
    required this.metadata,
    required this.engagement,
  });

  /// Create new activity with auto-generated ID and current timestamp
  factory ActivityFeedItem.create({
    required String userId,
    required String userDisplayName,
    String? userAvatarUrl,
    required ActivityType type,
    required String targetId,
    required String targetType,
    required String targetTitle,
    String? targetImageUrl,
    String? parentId,
    String? parentType,
    List<String>? visibility,
    Map<String, dynamic>? metadata,
  }) {
    return ActivityFeedItem(
      id: _generateActivityId(),
      userId: userId,
      userDisplayName: userDisplayName,
      userAvatarUrl: userAvatarUrl,
      type: type,
      targetId: targetId,
      targetType: targetType,
      targetTitle: targetTitle,
      targetImageUrl: targetImageUrl,
      parentId: parentId,
      parentType: parentType,
      timestamp: DateTime.now(),
      visibility: visibility ?? ['all_friends'],
      metadata: metadata ?? {},
      engagement: ActivityEngagement.empty(),
    );
  }

  /// Generate unique activity ID with timestamp
  static int _idCounter = 0;
  static String _generateActivityId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = now.microsecond;
    _idCounter++;
    return 'activity_${timestamp}_${random}_$_idCounter';
  }

  /// Create from Firestore document
  factory ActivityFeedItem.fromFirestore(String id, Map<String, dynamic> data) {
    return ActivityFeedItem(
      id: id,
      userId: SerializationUtils.safeString(data, 'userId'),
      userDisplayName: SerializationUtils.safeString(data, 'userDisplayName',
          defaultValue: 'Okänd användare'),
      userAvatarUrl:
          SerializationUtils.safeNullableString(data, 'userAvatarUrl'),
      type: ActivityType.fromKey(
          SerializationUtils.safeString(data, 'type', defaultValue: 'unknown')),
      targetId: SerializationUtils.safeString(data, 'targetId'),
      targetType: SerializationUtils.safeString(data, 'targetType'),
      targetTitle: SerializationUtils.safeString(data, 'targetTitle'),
      targetImageUrl:
          SerializationUtils.safeNullableString(data, 'targetImageUrl'),
      parentId: SerializationUtils.safeNullableString(data, 'parentId'),
      parentType: SerializationUtils.safeNullableString(data, 'parentType'),
      timestamp: SerializationUtils.safeRequiredDateTime(data, 'timestamp'),
      visibility: SerializationUtils.safeStringList(data, 'visibility',
          defaultValue: ['all_friends']),
      metadata: SerializationUtils.safeMap(data, 'metadata'),
      engagement: ActivityEngagement.fromFirestore(
          SerializationUtils.safeMap(data, 'engagement')),
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userAvatarUrl': userAvatarUrl,
      'type': type.key,
      'targetId': targetId,
      'targetType': targetType,
      'targetTitle': targetTitle,
      'targetImageUrl': targetImageUrl,
      'parentId': parentId,
      'parentType': parentType,
      'timestamp': Timestamp.fromDate(timestamp),
      'visibility': visibility,
      'metadata': metadata,
      'engagement': engagement.toFirestore(),
    };
  }

  /// Convert to JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userAvatarUrl': userAvatarUrl,
      'type': type.key,
      'targetId': targetId,
      'targetType': targetType,
      'targetTitle': targetTitle,
      'targetImageUrl': targetImageUrl,
      'parentId': parentId,
      'parentType': parentType,
      'timestamp': timestamp.toIso8601String(),
      'visibility': visibility,
      'metadata': metadata,
      'engagement': engagement.toJson(),
    };
  }

  /// Create from JSON format
  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) {
    // Ensure metadata is properly typed
    final metadata = json['metadata'];
    final Map<String, dynamic> typedMetadata;
    if (metadata == null) {
      typedMetadata = {};
    } else if (metadata is Map<String, dynamic>) {
      typedMetadata = metadata;
    } else {
      typedMetadata = Map<String, dynamic>.from(metadata as Map);
    }

    // Ensure engagement is properly typed
    final engagement = json['engagement'];
    final Map<String, dynamic> typedEngagement;
    if (engagement == null) {
      typedEngagement = {};
    } else if (engagement is Map<String, dynamic>) {
      typedEngagement = engagement;
    } else {
      typedEngagement = Map<String, dynamic>.from(engagement as Map);
    }

    return ActivityFeedItem(
      id: json['id'] as String,
      userId: (json['userId'] as String?).orEmpty(),
      userDisplayName:
          (json['userDisplayName'] as String?).orDefault('Okänd användare'),
      userAvatarUrl: json['userAvatarUrl'] as String?,
      type:
          ActivityType.fromKey((json['type'] as String?).orDefault('unknown')),
      targetId: (json['targetId'] as String?).orEmpty(),
      targetType: (json['targetType'] as String?).orEmpty(),
      targetTitle: (json['targetTitle'] as String?).orEmpty(),
      targetImageUrl: json['targetImageUrl'] as String?,
      parentId: json['parentId'] as String?,
      parentType: json['parentType'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      visibility:
          (json['visibility'] as List?)?.cast<String>() ?? ['all_friends'],
      metadata: typedMetadata,
      engagement: ActivityEngagement.fromJson(typedEngagement),
    );
  }

  /// Create updated copy with new engagement
  ActivityFeedItem copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? userAvatarUrl,
    ActivityType? type,
    String? targetId,
    String? targetType,
    String? targetTitle,
    String? targetImageUrl,
    String? parentId,
    String? parentType,
    DateTime? timestamp,
    List<String>? visibility,
    Map<String, dynamic>? metadata,
    ActivityEngagement? engagement,
  }) {
    return ActivityFeedItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      targetTitle: targetTitle ?? this.targetTitle,
      targetImageUrl: targetImageUrl ?? this.targetImageUrl,
      parentId: parentId ?? this.parentId,
      parentType: parentType ?? this.parentType,
      timestamp: timestamp ?? this.timestamp,
      visibility: visibility ?? this.visibility,
      metadata: metadata ?? this.metadata,
      engagement: engagement ?? this.engagement,
    );
  }

  /// Get human-readable time since activity
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} dagar sedan';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} timmar sedan';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minuter sedan';
    } else {
      return 'Nyss';
    }
  }

  /// Get activity description in Swedish
  String get description {
    switch (type) {
      case ActivityType.recipeCreated:
        return 'skapade ett recept';
      case ActivityType.recipeShared:
        return 'delade ett recept';
      case ActivityType.recipeRated:
        final rating = (metadata['rating'] as int?).orZero();
        return 'betygsatte ett recept ($rating⭐)';
      case ActivityType.commentAdded:
        return 'kommenterade ett recept';
      case ActivityType.reactionAdded:
        final reaction = (metadata['reactionType'] as String?).orEmpty();
        return 'reagerade på ett recept ($reaction)';
      case ActivityType.menuCreated:
        return 'skapade en meny';
      case ActivityType.menuShared:
        return 'delade en meny';
      case ActivityType.shoppingListCreated:
        return 'skapade en inköpslista';
      case ActivityType.shoppingListShared:
        return 'delade en inköpslista';
      case ActivityType.groupJoined:
        return 'gick med i en grupp';
      case ActivityType.achievementUnlocked:
        final achievement = (metadata['achievementName'] as String?).orEmpty();
        return 'låste upp en bedrift: $achievement';
      default:
        return 'gjorde något';
    }
  }

  /// Check if activity is visible to specific friend categories
  bool isVisibleTo(List<String> userFriendCategories) {
    if (visibility.contains('all_friends')) return true;
    if (visibility.contains('public')) return true;

    return visibility
        .any((category) => userFriendCategories.contains(category));
  }

  /// Get age of this activity
  Duration get age => DateTime.now().difference(timestamp);

  /// Check if activity is recent (within last 24 hours)
  bool get isRecent => age.inHours < 24;

  /// Check if activity is new (within last hour)
  bool get isNew => age.inMinutes < 60;

  @override
  String toString() {
    return 'ActivityFeedItem(id: $id, userId: $userId, type: ${type.key}, targetId: $targetId, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityFeedItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
