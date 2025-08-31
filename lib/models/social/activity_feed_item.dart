// lib/models/social/activity_feed_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Activity feed item model for social activity streams
///
/// This model represents individual activities in friend activity feeds, building on the
/// existing activity tracking patterns from the discovery dashboard. It provides comprehensive
/// activity data with engagement metrics, privacy controls, and real-time updates.
///
/// **Architecture Integration:**
/// - Extends existing activity patterns from FriendActivitySection
/// - Integrates with friend relationship system for privacy control
/// - Supports all content types (recipes, menus, shopping lists, comments)
/// - Provides engagement metrics for social interactions
///
/// **Activity Types:**
/// - Content creation (recipes, menus, shopping lists)
/// - Social interactions (comments, reactions, sharing)
/// - Collaborative activities (group sharing, invitations)
/// - Achievement activities (milestones, badges)
///
/// **Privacy Features:**
/// - Friend category visibility control
/// - Content-specific privacy settings
/// - User-controlled activity sharing preferences
/// - Granular activity type filtering
///
/// **Usage Examples:**
/// ```dart
/// // Recipe creation activity
/// final recipeActivity = ActivityFeedItem.create(
///   userId: 'user123',
///   type: ActivityType.recipeCreated,
///   targetId: 'recipe456',
///   targetTitle: 'Köttbullar med potatismos',
///   visibility: ['close_friends', 'family'],
/// );
/// 
/// // Social interaction activity
/// final commentActivity = ActivityFeedItem.create(
///   userId: 'user123',
///   type: ActivityType.commentAdded,
///   targetId: 'recipe456',
///   targetTitle: 'Köttbullar med potatismos',
///   parentId: 'comment789',
/// );
/// ```
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
      userId: data['userId'] as String? ?? '',
      userDisplayName: data['userDisplayName'] as String? ?? 'Okänd användare',
      userAvatarUrl: data['userAvatarUrl'] as String?,
      type: ActivityType.fromKey(data['type'] as String? ?? 'unknown'),
      targetId: data['targetId'] as String? ?? '',
      targetType: data['targetType'] as String? ?? '',
      targetTitle: data['targetTitle'] as String? ?? '',
      targetImageUrl: data['targetImageUrl'] as String?,
      parentId: data['parentId'] as String?,
      parentType: data['parentType'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      visibility: (data['visibility'] as List?)?.cast<String>() ?? ['all_friends'],
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      engagement: ActivityEngagement.fromFirestore(data['engagement'] as Map<String, dynamic>? ?? {}),
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
      userId: json['userId'] as String? ?? '',
      userDisplayName: json['userDisplayName'] as String? ?? 'Okänd användare',
      userAvatarUrl: json['userAvatarUrl'] as String?,
      type: ActivityType.fromKey(json['type'] as String? ?? 'unknown'),
      targetId: json['targetId'] as String? ?? '',
      targetType: json['targetType'] as String? ?? '',
      targetTitle: json['targetTitle'] as String? ?? '',
      targetImageUrl: json['targetImageUrl'] as String?,
      parentId: json['parentId'] as String?,
      parentType: json['parentType'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      visibility: (json['visibility'] as List?)?.cast<String>() ?? ['all_friends'],
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
        final rating = metadata['rating'] as int? ?? 0;
        return 'betygsatte ett recept ($rating⭐)';
      case ActivityType.commentAdded:
        return 'kommenterade ett recept';
      case ActivityType.reactionAdded:
        final reaction = metadata['reactionType'] as String? ?? '';
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
        final achievement = metadata['achievementName'] as String? ?? '';
        return 'låste upp en bedrift: $achievement';
      default:
        return 'gjorde något';
    }
  }

  /// Check if activity is visible to specific friend categories
  bool isVisibleTo(List<String> userFriendCategories) {
    if (visibility.contains('all_friends')) return true;
    if (visibility.contains('public')) return true;
    
    return visibility.any((category) => userFriendCategories.contains(category));
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

/// Activity engagement metrics for social interactions
class ActivityEngagement {
  /// Number of likes/reactions on this activity
  final int likes;
  
  /// Number of comments on this activity
  final int comments;
  
  /// Number of shares of this activity
  final int shares;
  
  /// Number of views of this activity
  final int views;

  const ActivityEngagement({
    required this.likes,
    required this.comments,
    required this.shares,
    required this.views,
  });

  /// Create empty engagement metrics
  factory ActivityEngagement.empty() {
    return const ActivityEngagement(
      likes: 0,
      comments: 0,
      shares: 0,
      views: 0,
    );
  }

  /// Create from Firestore data
  factory ActivityEngagement.fromFirestore(Map<String, dynamic> data) {
    return ActivityEngagement(
      likes: data['likes'] as int? ?? 0,
      comments: data['comments'] as int? ?? 0,
      shares: data['shares'] as int? ?? 0,
      views: data['views'] as int? ?? 0,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'views': views,
    };
  }

  /// Convert to JSON format
  Map<String, dynamic> toJson() {
    return {
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'views': views,
    };
  }

  /// Create from JSON format
  factory ActivityEngagement.fromJson(Map<String, dynamic> json) {
    return ActivityEngagement(
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
    );
  }

  /// Get total engagement count
  int get totalEngagement => likes + comments + shares;

  /// Check if activity has any engagement
  bool get hasEngagement => totalEngagement > 0;

  /// Create copy with updated metrics
  ActivityEngagement copyWith({
    int? likes,
    int? comments,
    int? shares,
    int? views,
  }) {
    return ActivityEngagement(
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views ?? this.views,
    );
  }
}

/// Enumeration of activity types for social feeds
enum ActivityType {
  // Content creation activities
  recipeCreated('recipe_created', '👨‍🍳 Recept skapat'),
  menuCreated('menu_created', '📋 Meny skapad'),
  shoppingListCreated('shopping_list_created', '🛒 Inköpslista skapad'),
  
  // Sharing activities
  recipeShared('recipe_shared', '📤 Recept delat'),
  menuShared('menu_shared', '📤 Meny delad'),
  shoppingListShared('shopping_list_shared', '📤 Inköpslista delad'),
  
  // Social interaction activities
  commentAdded('comment_added', '💬 Kommentar'),
  reactionAdded('reaction_added', '❤️ Reaktion'),
  recipeRated('recipe_rated', '⭐ Betyg'),
  
  // Collaborative activities
  groupJoined('group_joined', '👥 Gick med i grupp'),
  invitationSent('invitation_sent', '📩 Inbjudan skickad'),
  invitationAccepted('invitation_accepted', '✅ Inbjudan accepterad'),
  
  // Achievement activities
  achievementUnlocked('achievement_unlocked', '🏆 Bedrift'),
  milestoneReached('milestone_reached', '🎯 Milstolpe'),
  
  // Unknown/fallback
  unknown('unknown', '❓ Okänd aktivitet');

  const ActivityType(this.key, this.displayName);

  /// Database key for storage
  final String key;
  
  /// Swedish display name for UI
  final String displayName;

  /// Get ActivityType from database key
  static ActivityType fromKey(String key) {
    return ActivityType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => ActivityType.unknown,
    );
  }

  /// Get content creation activity types
  static List<ActivityType> get contentTypes => [
    ActivityType.recipeCreated,
    ActivityType.menuCreated,
    ActivityType.shoppingListCreated,
  ];

  /// Get social interaction activity types
  static List<ActivityType> get socialTypes => [
    ActivityType.commentAdded,
    ActivityType.reactionAdded,
    ActivityType.recipeRated,
  ];

  /// Get sharing activity types
  static List<ActivityType> get sharingTypes => [
    ActivityType.recipeShared,
    ActivityType.menuShared,
    ActivityType.shoppingListShared,
  ];

  @override
  String toString() => key;
}