import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks social interaction analytics events
class SocialEventsTracker extends BaseTracker {
  SocialEventsTracker({required super.repository});

  /// Log friend request sent
  Future<void> logFriendRequestSent({
    required String recipientId,
    String? source,
  }) async {
    await logEvent(
      name: 'friend_request_sent',
      parameters: {
        'recipient_id': recipientId,
        if (source != null) 'source': source,
      },
    );
  }

  /// Log friend request accepted
  Future<void> logFriendRequestAccepted({required String senderId}) async {
    await logEvent(
      name: 'friend_request_accepted',
      parameters: {'sender_id': senderId},
    );
  }

  /// Log comment created
  Future<void> logCommentCreated({
    required String recipeId,
    required int commentLength,
  }) async {
    await logEvent(
      name: 'comment_created',
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
      name: 'recipe_rated',
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
      name: 'group_created',
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
      name: 'group_joined',
      parameters: {
        'group_id': groupId,
        'source': source,
      },
    );
  }

  /// Log content shared to group
  Future<void> logContentSharedToGroup({
    required String groupId,
    required String contentType,
  }) async {
    await logEvent(
      name: 'content_shared_to_group',
      parameters: {
        'group_id': groupId,
        'content_type': contentType,
      },
    );
  }

  /// Log friend removed
  Future<void> logFriendRemoved({required String friendId}) async {
    await logEvent(
      name: 'friend_removed',
      parameters: {'friend_id': friendId},
    );
  }

  /// Log friend request rejected
  Future<void> logFriendRequestRejected({required String senderId}) async {
    await logEvent(
      name: 'friend_request_rejected',
      parameters: {'sender_id': senderId},
    );
  }

  /// Log friend request cancelled
  Future<void> logFriendRequestCancelled({required String recipientId}) async {
    await logEvent(
      name: 'friend_request_cancelled',
      parameters: {'recipient_id': recipientId},
    );
  }

  /// Log user blocked
  Future<void> logUserBlocked({required String blockedUserId}) async {
    await logEvent(
      name: 'user_blocked',
      parameters: {'blocked_user_id': blockedUserId},
    );
  }

  /// Log user unblocked
  Future<void> logUserUnblocked({required String unblockedUserId}) async {
    await logEvent(
      name: 'user_unblocked',
      parameters: {'unblocked_user_id': unblockedUserId},
    );
  }

  /// Log message sent
  Future<void> logMessageSent({
    required String conversationId,
    required String messageType,
  }) async {
    await logEvent(
      name: 'message_sent',
      parameters: {
        'conversation_id': conversationId,
        'message_type': messageType,
      },
    );
  }

  /// Log group left
  Future<void> logGroupLeft({required String groupId}) async {
    await logEvent(
      name: 'group_left',
      parameters: {'group_id': groupId},
    );
  }

  /// Log group deleted
  Future<void> logGroupDeleted({required String groupId}) async {
    await logEvent(
      name: 'group_deleted',
      parameters: {'group_id': groupId},
    );
  }

  /// Log content unshared
  Future<void> logContentUnshared({
    required String contentId,
    required String contentType,
  }) async {
    await logEvent(
      name: 'content_unshared',
      parameters: {
        'content_id': contentId,
        'content_type': contentType,
      },
    );
  }
}
