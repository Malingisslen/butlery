import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/social/activity_feed_item.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/content_reaction.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'package:butlery/models/social/reaction_statistics.dart';
import 'package:butlery/models/user_profile.dart';

/// Factory for creating test social data
class SocialFactory {
  static int _commentIdCounter = 0;
  static int _activityIdCounter = 0;
  static int _requestIdCounter = 0;
  static int _categoryIdCounter = 0;
  static int _reactionIdCounter = 0;

  /// Create a test recipe comment
  static RecipeComment createComment({
    String? id,
    String? recipeId,
    String? userId, // Keep for backward compatibility
    String? authorId,
    String? userDisplayName, // Keep for backward compatibility
    String? authorDisplayName,
    String? userPhotoUrl, // Keep for backward compatibility
    String? authorAvatarUrl,
    String? comment, // Keep for backward compatibility
    String? text,
    DateTime? timestamp, // Keep for backward compatibility
    DateTime? createdAt,
    DateTime? editedAt,
    int likes = 0, // Keep for backward compatibility - now used as likesCount
    int? likesCount,
    bool isEdited = false, // Keep for backward compatibility
    String? replyToCommentId, // Keep for backward compatibility
    String? parentCommentId,
    int replyCount = 0,
    bool isDeleted = false,
  }) {
    // Map old parameters to new ones for backward compatibility
    final actualAuthorId = authorId ?? userId ?? 'user_test';
    final actualAuthorDisplayName =
        authorDisplayName ?? userDisplayName ?? 'Test User';
    final actualAuthorAvatarUrl = authorAvatarUrl ?? userPhotoUrl;
    final actualText = text ?? comment ?? 'This is a test comment';
    final actualCreatedAt = createdAt ?? timestamp ?? DateTime.now();
    final actualEditedAt = editedAt ?? (isEdited ? DateTime.now() : null);
    final actualParentCommentId = parentCommentId ?? replyToCommentId;
    final actualLikesCount = likesCount ?? likes;

    return RecipeComment(
      id: id ?? 'comment_${_commentIdCounter++}',
      recipeId: recipeId ?? 'recipe_test',
      authorId: actualAuthorId,
      authorDisplayName: actualAuthorDisplayName,
      authorAvatarUrl: actualAuthorAvatarUrl,
      text: actualText,
      createdAt: actualCreatedAt,
      editedAt: actualEditedAt,
      likesCount: actualLikesCount,
      parentCommentId: actualParentCommentId,
      replyCount: replyCount,
      isDeleted: isDeleted,
    );
  }

  /// Create a test activity feed item
  static ActivityFeedItem createActivityFeedItem({
    String? id,
    String? userId,
    String? userDisplayName,
    String? userAvatarUrl,
    ActivityType? type,
    String? targetId,
    String? targetType,
    String? targetTitle,
    String? targetImageUrl,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    List<String>? visibility,
    ActivityVisibility? visibilityLevel,
    ActivityEngagement? engagement,
  }) {
    return ActivityFeedItem(
      id: id ?? 'activity_${_activityIdCounter++}',
      userId: userId ?? 'user_test',
      userDisplayName: userDisplayName ?? 'Test User',
      userAvatarUrl: userAvatarUrl,
      type: type ?? ActivityType.recipeCreated,
      targetId: targetId ?? 'target_test',
      targetType: targetType ?? 'recipe',
      targetTitle: targetTitle ?? 'Test Recipe',
      targetImageUrl: targetImageUrl,
      parentId: null,
      parentType: null,
      timestamp: timestamp ?? DateTime.now(),
      visibility: visibility ?? ['public'],
      visibilityLevel: visibilityLevel ?? ActivityVisibility.public,
      metadata: metadata ?? {},
      engagement: engagement ??
          const ActivityEngagement(likes: 0, comments: 0, shares: 0, views: 0),
    );
  }

  /// Create a test friend request
  static FriendRequest createFriendRequest({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? fromUserName,
    String? fromUserEmail,
    String? fromUserPhotoUrl,
    String? toUserName,
    String? toUserEmail,
    String? status,
    DateTime? sentAt,
    DateTime? respondedAt,
    String? message,
  }) {
    return FriendRequest(
      id: id ?? 'request_${_requestIdCounter++}',
      fromUserId: fromUserId ?? 'from_user_test',
      toUserId: toUserId ?? 'to_user_test',
      status: status != null
          ? FriendRequestStatus.values.firstWhere((s) => s.name == status,
              orElse: () => FriendRequestStatus.pending)
          : FriendRequestStatus.pending,
      sentAt: sentAt ?? DateTime.now(),
      respondedAt: respondedAt,
      message: message,
    );
  }

  /// Create a test friend category
  static FriendCategory createFriendCategory({
    String? id,
    String? name,
    String? emoji,
    String? description,
    List<String>? memberIds,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    bool isDefault = false,
  }) {
    return FriendCategory(
      id: id ?? 'category_${_categoryIdCounter++}',
      ownerId: createdBy ?? 'user_test',
      name: name ?? 'Test Category',
      emoji: emoji ?? '👥',
      description: description ?? 'Test category description',
      friendUserIds: memberIds ?? [],
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      sortOrder: sortOrder ?? 0,
      isDefault: isDefault,
    );
  }

  /// Create a test content reaction
  static ContentReaction createReaction({
    String? id,
    String? userId,
    String? contentId,
    String? contentType,
    ReactionType? reactionType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContentReaction(
      id: id ?? 'reaction_${_reactionIdCounter++}',
      userId: userId ?? 'user_test',
      contentId: contentId ?? 'content_test',
      contentType: contentType ?? 'recipe',
      reactionType: reactionType ?? ReactionType.like,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt,
    );
  }

  /// Create test reaction statistics
  static ReactionStatistics createReactionStatistics({
    String? contentId,
    String? contentType,
    Map<ReactionType, int>? reactionCounts,
    Map<String, ReactionType>? userReactions,
    int? totalCount,
    DateTime? lastUpdated,
  }) {
    final counts = reactionCounts ??
        {
          ReactionType.like: 5,
          ReactionType.love: 3,
          ReactionType.delicious: 2,
        };

    return ReactionStatistics.fromCounts(
      counts,
      contentId: contentId ?? 'content_test',
      contentType: contentType ?? 'recipe',
    );
  }

  /// Create a test user profile
  static UserProfile createUserProfile({
    String? uid,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool isSearchable = true,
    bool allowEmailSearch = false,
    int publicRecipeCount = 0,
    int friendsCount = 0,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool isOnline = false,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    bool notificationsEnabled = true,
  }) {
    return UserProfile(
      uid: uid ?? 'user_test',
      email: email ?? 'test@example.com',
      displayName: displayName ?? 'Test User',
      avatarUrl: avatarUrl,
      isSearchable: isSearchable,
      allowEmailSearch: allowEmailSearch,
      publicRecipeCount: publicRecipeCount,
      friendsCount: friendsCount,
      joinedAt: joinedAt ?? DateTime.now(),
      lastActiveAt: lastActiveAt ?? DateTime.now(),
      isOnline: isOnline,
      fcmToken: fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt,
      notificationsEnabled: notificationsEnabled,
    );
  }

  /// Create a list of test comments
  static List<RecipeComment> createCommentList({
    int count = 3,
    String? recipeId,
  }) {
    return List.generate(
      count,
      (index) => createComment(
        id: 'comment_$index',
        recipeId: recipeId ?? 'recipe_test',
        userId: 'user_$index',
        userDisplayName: 'User $index',
        comment: 'Test comment $index',
        timestamp: DateTime.now().subtract(Duration(hours: index)),
        likes: index * 2,
      ),
    );
  }

  /// Create a list of test activity feed items
  static List<ActivityFeedItem> createActivityFeedList({
    int count = 5,
    String? userId,
  }) {
    final targetTypes = ['recipe', 'menu', 'user', 'comment', 'list'];

    return List.generate(
      count,
      (index) => createActivityFeedItem(
        id: 'activity_$index',
        userId: userId ?? 'user_$index',
        userDisplayName: 'User $index',
        type: ActivityType.values[index % ActivityType.values.length],
        targetType: targetTypes[index % targetTypes.length],
        targetTitle: 'Target $index',
        timestamp: DateTime.now().subtract(Duration(hours: index)),
      ),
    );
  }

  /// Create a list of test friend requests
  static List<FriendRequest> createFriendRequestList({
    int count = 3,
    String? toUserId,
  }) {
    return List.generate(
      count,
      (index) => createFriendRequest(
        id: 'request_$index',
        fromUserId: 'from_user_$index',
        toUserId: toUserId ?? 'to_user_test',
        fromUserName: 'From User $index',
        fromUserEmail: 'from$index@test.com',
        status: index == 0 ? 'pending' : (index == 1 ? 'accepted' : 'rejected'),
        sentAt: DateTime.now().subtract(Duration(days: index)),
      ),
    );
  }

  /// Create a group activity data entry matching GroupActivityTimeline structure
  static Map<String, dynamic> createGroupActivityData({
    String type = 'recipe',
    String action = 'shared_to_group',
    String title = 'Test Recipe',
    String ownerName = 'Test User',
    String? ownerAvatarUrl,
    DateTime? sharedAt,
    String? groupName,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'type': type,
      'action': action,
      'title': title,
      'ownerName': ownerName,
      'ownerAvatarUrl': ownerAvatarUrl,
      'sharedAt': sharedAt ?? DateTime.now(),
      'groupName': groupName ?? 'Test Group',
      'metadata': metadata,
    };
  }

  /// Create a list of group activity data entries
  static List<Map<String, dynamic>> createGroupActivityList({
    int count = 3,
    bool includeVariety = true,
  }) {
    if (!includeVariety) {
      return List.generate(
          count,
          (index) => createGroupActivityData(
                title: 'Activity ${index + 1}',
                ownerName: 'User ${index + 1}',
                sharedAt: DateTime.now().subtract(Duration(hours: index)),
              ));
    }

    final activities = <Map<String, dynamic>>[];
    final activityTypes = ['recipe', 'menu', 'shopping_list'];
    final actions = ['shared_to_group', 'commented', 'liked'];
    final swedishTitles = [
      'Köttbullar med gräddsås',
      'Veckans meny',
      'Inköpslista för helgen'
    ];

    for (int i = 0; i < count; i++) {
      final type = activityTypes[i % activityTypes.length];
      final action = actions[i % actions.length];
      final title = i < swedishTitles.length
          ? swedishTitles[i]
          : 'Test ${type.replaceAll('_', ' ')} ${i + 1}';

      final activity = createGroupActivityData(
        type: type,
        action: action,
        title: title,
        ownerName: 'Användare ${i + 1}',
        ownerAvatarUrl: i % 2 == 0 ? 'https://example.com/avatar_$i.jpg' : null,
        sharedAt: DateTime.now().subtract(Duration(hours: i, minutes: i * 15)),
        metadata: _createTestMetadata(type, i),
      );

      activities.add(activity);
    }

    return activities;
  }

  /// Create test metadata for different activity types
  static Map<String, dynamic>? _createTestMetadata(String type, int index) {
    switch (type) {
      case 'recipe':
        return index % 3 == 0
            ? {
                'description': 'En klassisk svensk rätt med hemlagad smak',
                'totalRecipes': 1,
              }
            : null;
      case 'menu':
        return index % 2 == 0
            ? {
                'description': 'Planerad meny för hela veckan',
                'totalRecipes': 5 + index,
              }
            : null;
      case 'shopping_list':
        return {
          'description': 'Inköpslista för helgens middag',
          'totalItems': 8 + index * 2,
        };
      default:
        return null;
    }
  }

  /// Reset all counters (useful for test isolation)
  static void resetCounters() {
    _commentIdCounter = 0;
    _activityIdCounter = 0;
    _requestIdCounter = 0;
    _categoryIdCounter = 0;
    _reactionIdCounter = 0;
  }
}
