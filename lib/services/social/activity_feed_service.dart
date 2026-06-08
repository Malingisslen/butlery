/// Service for emitting and fetching social activity feed events.
library;

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

      final displayName = userService.currentUserProfile?.displayName ?? '?';

      // BUT-906: respect the user's activity-broadcast opt-out. Fire-and-forget,
      // so a disabled feed silently skips the emit.
      if (userService.currentUserProfile?.shareActivityToFeed == false) return;

      final event = ActivityEvent.create(
        actorId: userId,
        actorDisplayName: displayName,
        type: type,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        extraData: extraData,
      );

      await _repository.addEvent(event);
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
