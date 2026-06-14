/// Service for emitting and fetching social activity feed events.
library;

import 'package:flutter/foundation.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';

class ActivityFeedService extends BaseService {
  final ActivityEventRepository _repository;

  ActivityFeedService({required ActivityEventRepository repository})
      : _repository = repository;

  @override
  String get serviceName => 'ActivityFeedService';

  /// BUT-1220: fires exactly once, the first time this user actually broadcasts
  /// an activity event, so the UI can surface a one-time "your friends can now
  /// see your activity" hint. Listeners reset it after showing the hint. The
  /// durable once-only guard is [UserProfile.hasSeenActivityFeedHint]; this
  /// notifier is the in-session trigger.
  final ValueNotifier<bool> firstEventHint = ValueNotifier<bool>(false);

  /// Fire-and-forget: emit an activity event visible to the actor's friends.
  /// Never throws — logs a warning on failure.
  Future<void> emitEvent(
    ActivityEventType type,
    String recipeId,
    String recipeTitle, {
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final permissionService = ServiceLocator.get<PermissionService>();
      final userService = ServiceLocator.get<UserService>();

      final userId = permissionService.currentUserId;
      if (userId == null) return;

      final profile = userService.currentUserProfile;
      final displayName = profile?.displayName ?? '?';

      // BUT-906: respect the user's activity-broadcast master opt-out.
      // Fire-and-forget, so a disabled feed silently skips the emit.
      if (profile?.shareActivityToFeed == false) return;

      // BUT-1220: under the master toggle, respect the per-event-type opt-out.
      // An absent entry counts as enabled, so legacy/unset profiles broadcast
      // every type exactly as before.
      if (profile != null && !profile.isActivityEventTypeEnabled(type.name)) {
        return;
      }

      final event = ActivityEvent.create(
        actorId: userId,
        actorDisplayName: displayName,
        type: type,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        extraData: extraData,
      );

      await _repository.addEvent(event);

      // BUT-1220: first successful broadcast → trigger the one-time hint and
      // persist the durable flag so it never fires again. Best-effort: a failed
      // flag write must not break the emit, hence the inner guard.
      if (profile != null && !profile.hasSeenActivityFeedHint) {
        firstEventHint.value = true;
        await userService.markActivityFeedHintSeen();
      }
    } catch (e) {
      AppLogger.warning('Failed to emit activity event: $e');
    }
  }

  /// Fetch the activity feed for the current user's friends.
  Future<List<ActivityEvent>> fetchFeed({
    int limit = 20,
    DateTime? before,
  }) async {
    return await executeServiceOperation<List<ActivityEvent>>(
          () async {
            final permissionService = ServiceLocator.get<PermissionService>();
            final friendsRepo = ServiceLocator.get<FriendsRepository>();

            final userId = permissionService.currentUserId;
            if (userId == null) return [];

            final friendIds = await friendsRepo.fetchFriendIds(userId);
            if (friendIds.isEmpty) return [];

            return await _repository.fetchFriendActivity(
              friendIds: friendIds,
              limit: limit,
              before: before,
            );
          },
          operationName: 'fetchFeed',
          defaultValue: [],
        ) ??
        [];
  }
}
