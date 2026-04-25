import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
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

  /// Once-per-user `first_friend` milestone (BUT-593). Dedupes via a
  /// SharedPreferences flag keyed by uid. Returns true if the milestone fired.
  Future<bool> logFirstFriendIfMilestone({
    required String? userId,
    DateTime? joinedAt,
  }) async {
    return _logFirstSocialMilestone(
      userId: userId,
      joinedAt: joinedAt,
      eventName: 'first_friend',
      userPropertyName: 'has_friend',
      prefsPrefix: _firstFriendPrefsPrefix,
    );
  }

  /// Once-per-user `first_comment` milestone (BUT-593). Dedupes via a
  /// SharedPreferences flag keyed by uid. Returns true if the milestone fired.
  Future<bool> logFirstCommentIfMilestone({
    required String? userId,
    DateTime? joinedAt,
  }) async {
    return _logFirstSocialMilestone(
      userId: userId,
      joinedAt: joinedAt,
      eventName: 'first_comment',
      userPropertyName: 'has_commented',
      prefsPrefix: _firstCommentPrefsPrefix,
    );
  }

  /// Once-per-user `first_group` milestone (BUT-593). Fires on whichever
  /// happens first: `group_created` or `group_joined`. Dedupes via a
  /// SharedPreferences flag keyed by uid. Returns true if the milestone fired.
  Future<bool> logFirstGroupIfMilestone({
    required String? userId,
    DateTime? joinedAt,
  }) async {
    return _logFirstSocialMilestone(
      userId: userId,
      joinedAt: joinedAt,
      eventName: 'first_group',
      userPropertyName: 'has_group',
      prefsPrefix: _firstGroupPrefsPrefix,
    );
  }

  /// Shared milestone helper for the three social activation events. They all
  /// share the same shape (no extra payload beyond `minutes_since_signup`),
  /// so collapsing them avoids three near-identical copies of A1's pattern.
  Future<bool> _logFirstSocialMilestone({
    required String? userId,
    required DateTime? joinedAt,
    required String eventName,
    required String userPropertyName,
    required String prefsPrefix,
  }) async {
    if (userId == null || userId.isEmpty) return false;
    if (!await hasAnalyticsConsent()) return false;

    final prefs = await _tryGetPrefs(eventName);
    if (prefs == null) return false;

    final key = '$prefsPrefix$userId';
    if (prefs.getBool(key) == true) return false;

    final params = <String, Object>{};
    if (joinedAt != null) {
      params['minutes_since_signup'] =
          DateTime.now().difference(joinedAt).inMinutes;
    }

    await repository.logEvent(name: eventName, parameters: params);
    await repository.setUserProperty(name: userPropertyName, value: 'true');
    await prefs.setBool(key, true);
    return true;
  }

  Future<SharedPreferences?> _tryGetPrefs(String eventName) async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.warning(
        '$eventName milestone: SharedPreferences unavailable ($e); skipping',
      );
      return null;
    }
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
