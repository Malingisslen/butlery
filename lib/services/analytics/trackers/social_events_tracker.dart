import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks social interaction analytics events
class SocialEventsTracker extends BaseTracker {
  SocialEventsTracker({required super.repository});

  /// Per-install dedupe keys for the once-per-user social milestones (BUT-593).
  /// Suffixed with the user uid so household devices don't cross-fire.
  static const String _firstFriendPrefsPrefix = 'has_friend_v1_';
  static const String _firstCommentPrefsPrefix = 'has_commented_v1_';
  static const String _firstGroupPrefsPrefix = 'has_group_v1_';

  /// Log friend request sent
  Future<void> logFriendRequestSent({
    required String recipientId,
    String? source,
  }) async {
    await logEvent(
      name: AnalyticsEvents.friendRequestSent,
      parameters: {
        'recipient_id': recipientId,
        if (source != null) 'source': source,
      },
    );
  }

  /// Log friend request accepted
  Future<void> logFriendRequestAccepted({required String senderId}) async {
    await logEvent(
      name: AnalyticsEvents.friendRequestAccepted,
      parameters: {'sender_id': senderId},
    );
  }

  /// Log comment created
  Future<void> logCommentCreated({
    required String recipeId,
    required int commentLength,
  }) async {
    await logEvent(
      name: AnalyticsEvents.commentCreated,
      parameters: {'recipe_id': recipeId, 'comment_length': commentLength},
    );
  }

  /// Log recipe rated
  Future<void> logRecipeRated({
    required String recipeId,
    required int rating,
    int? previousRating,
  }) async {
    await logEvent(
      name: AnalyticsEvents.recipeRated,
      parameters: {
        'recipe_id': recipeId,
        'rating': rating,
        if (previousRating != null) 'previous_rating': previousRating,
      },
    );
  }

  /// Log group created
  Future<void> logGroupCreated({
    required String groupId,
    required String groupType,
    int memberCount = 0,
  }) async {
    await logEvent(
      name: AnalyticsEvents.groupCreated,
      parameters: {
        'group_id': groupId,
        'group_type': groupType,
        'member_count': memberCount,
      },
    );
  }

  /// Log group joined
  Future<void> logGroupJoined({
    required String groupId,
    required String source,
  }) async {
    await logEvent(
      name: AnalyticsEvents.groupJoined,
      parameters: {
        'group_id': groupId,
        'source': source,
      },
    );
  }

  /// Once-per-user `first_friend` milestone (BUT-593). Returns true if fired.
  Future<bool> logFirstFriendIfMilestone({
    required String? userId,
    DateTime? joinedAt,
  }) async {
    return fireOnceMilestone(
      userId: userId,
      prefsPrefix: _firstFriendPrefsPrefix,
      eventName: AnalyticsEvents.firstFriend,
      userPropertyName: AnalyticsUserProperties.hasFriend,
      joinedAt: joinedAt,
    );
  }

  /// Once-per-user `first_comment` milestone (BUT-593). Returns true if fired.
  Future<bool> logFirstCommentIfMilestone({
    required String? userId,
    DateTime? joinedAt,
  }) async {
    return fireOnceMilestone(
      userId: userId,
      prefsPrefix: _firstCommentPrefsPrefix,
      eventName: AnalyticsEvents.firstComment,
      userPropertyName: AnalyticsUserProperties.hasCommented,
      joinedAt: joinedAt,
    );
  }

  /// Once-per-user `first_group` milestone (BUT-593). Fires on whichever
  /// happens first: `group_created` or `group_joined`. Returns true if fired.
  Future<bool> logFirstGroupIfMilestone({
    required String? userId,
    DateTime? joinedAt,
  }) async {
    return fireOnceMilestone(
      userId: userId,
      prefsPrefix: _firstGroupPrefsPrefix,
      eventName: AnalyticsEvents.firstGroup,
      userPropertyName: AnalyticsUserProperties.hasGroup,
      joinedAt: joinedAt,
    );
  }

  /// Log content shared to group
  Future<void> logContentSharedToGroup({
    required String groupId,
    required String contentType,
  }) async {
    await logEvent(
      name: AnalyticsEvents.contentSharedToGroup,
      parameters: {
        'group_id': groupId,
        'content_type': contentType,
      },
    );
  }

  /// Log friend removed
  Future<void> logFriendRemoved({required String friendId}) async {
    await logEvent(
      name: AnalyticsEvents.friendRemoved,
      parameters: {'friend_id': friendId},
    );
  }

  /// Log friend request rejected
  Future<void> logFriendRequestRejected({required String senderId}) async {
    await logEvent(
      name: AnalyticsEvents.friendRequestRejected,
      parameters: {'sender_id': senderId},
    );
  }

  /// Log friend request cancelled
  Future<void> logFriendRequestCancelled({required String recipientId}) async {
    await logEvent(
      name: AnalyticsEvents.friendRequestCancelled,
      parameters: {'recipient_id': recipientId},
    );
  }

  /// Log user blocked
  Future<void> logUserBlocked({required String blockedUserId}) async {
    await logEvent(
      name: AnalyticsEvents.userBlocked,
      parameters: {'blocked_user_id': blockedUserId},
    );
  }

  /// Log user unblocked
  Future<void> logUserUnblocked({required String unblockedUserId}) async {
    await logEvent(
      name: AnalyticsEvents.userUnblocked,
      parameters: {'unblocked_user_id': unblockedUserId},
    );
  }

  /// Log message sent
  Future<void> logMessageSent({
    required String conversationId,
    required String messageType,
  }) async {
    await logEvent(
      name: AnalyticsEvents.messageSent,
      parameters: {
        'conversation_id': conversationId,
        'message_type': messageType,
      },
    );
  }

  /// Log group left
  Future<void> logGroupLeft({required String groupId}) async {
    await logEvent(
      name: AnalyticsEvents.groupLeft,
      parameters: {'group_id': groupId},
    );
  }

  /// Log group deleted
  Future<void> logGroupDeleted({required String groupId}) async {
    await logEvent(
      name: AnalyticsEvents.groupDeleted,
      parameters: {'group_id': groupId},
    );
  }

  /// Log content unshared
  Future<void> logContentUnshared({
    required String contentId,
    required String contentType,
  }) async {
    await logEvent(
      name: AnalyticsEvents.contentUnshared,
      parameters: {
        'content_id': contentId,
        'content_type': contentType,
      },
    );
  }
}
