import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks social interaction analytics events
class SocialEventsTracker extends BaseTracker {
  SocialEventsTracker({required super.repository});

  /// Log friend request sent
  Future<void> logFriendRequestSent({
    required String recipientId,
    String? source,
  }) async {
    if (!await hasAnalyticsConsent()) return;
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
    if (!await hasAnalyticsConsent()) return;
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
    if (!await hasAnalyticsConsent()) return;
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
    if (!await hasAnalyticsConsent()) return;
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
    if (!await hasAnalyticsConsent()) return;
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
    if (!await hasAnalyticsConsent()) return;
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
    if (!await hasAnalyticsConsent()) return;
    await logEvent(
      name: 'content_shared_to_group',
      parameters: {
        'group_id': groupId,
        'content_type': contentType,
      },
    );
  }
}
