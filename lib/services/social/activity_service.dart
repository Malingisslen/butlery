// lib/services/social/activity_service.dart

import 'dart:async';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/repositories/interfaces/activity_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth_repo;
import 'package:butlery/models/social/activity_feed_item.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/services/social/helpers/activity_cache_helper.dart';

/// Social activity service for tracking and feed generation.
///
/// Manages activity tracking, personalized feeds, privacy controls, and real-time updates with caching.
class ActivityService extends BaseService with StreamManagementMixin {
  final ActivityRepository _activityRepository;
  final auth_repo.AuthRepository _authRepository;

  @override
  String get serviceName => 'ActivityService';

  // Activity caching for performance optimization
  final Map<String, List<ActivityFeedItem>> _feedCache = {};
  final Map<String, StreamSubscription> _feedStreams = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  ActivityService({
    required ActivityRepository activityRepository,
    required auth_repo.AuthRepository authRepository,
  }) : _activityRepository = activityRepository,
       _authRepository = authRepository;


  Future<void> trackRecipeCreated({
    required String recipeId,
    required String recipeTitle,
    String? recipeImageUrl,
    List<String>? visibility,
  }) async {
    await _trackGenericActivity(
      type: ActivityType.recipeCreated,
      targetId: recipeId,
      targetType: 'recipe',
      targetTitle: recipeTitle,
      targetImageUrl: recipeImageUrl,
      visibility: visibility,
      operationName: 'Track recipe created',
    );
  }

  Future<void> trackRecipeShared({
    required String recipeId,
    required String recipeTitle,
    String? recipeImageUrl,
    required List<String> sharedWith,
    List<String>? visibility,
  }) async {
    await _trackGenericActivity(
      type: ActivityType.recipeShared,
      targetId: recipeId,
      targetType: 'recipe',
      targetTitle: recipeTitle,
      targetImageUrl: recipeImageUrl,
      visibility: visibility,
      metadata: {
        'sharedWith': sharedWith,
        'shareCount': sharedWith.length,
      },
      operationName: 'Track recipe shared',
    );
  }

  Future<void> trackRecipeRated({
    required String recipeId,
    required String recipeTitle,
    String? recipeImageUrl,
    required int rating,
    List<String>? visibility,
  }) async {
    await _trackGenericActivity(
      type: ActivityType.recipeRated,
      targetId: recipeId,
      targetType: 'recipe',
      targetTitle: recipeTitle,
      targetImageUrl: recipeImageUrl,
      visibility: visibility,
      metadata: {
        'rating': rating,
        'maxRating': 5,
      },
      operationName: 'Track recipe rated',
    );
  }

  Future<void> trackCommentAdded({
    required String contentId,
    required String contentType,
    required String contentTitle,
    String? contentImageUrl,
    String? commentId,
    String? parentCommentId,
    List<String>? visibility,
  }) async {
    await _trackGenericActivity(
      type: ActivityType.commentAdded,
      targetId: contentId,
      targetType: contentType,
      targetTitle: contentTitle,
      targetImageUrl: contentImageUrl,
      visibility: visibility,
      metadata: {
        'commentId': commentId,
        'parentCommentId': parentCommentId,
        'isReply': parentCommentId != null,
      },
      operationName: 'Track comment added',
    );
  }

  Future<void> trackReactionAdded({
    required String contentId,
    required String contentType,
    required String contentTitle,
    String? contentImageUrl,
    required String reactionType,
    List<String>? visibility,
  }) async {
    await _trackGenericActivity(
      type: ActivityType.reactionAdded,
      targetId: contentId,
      targetType: contentType,
      targetTitle: contentTitle,
      targetImageUrl: contentImageUrl,
      visibility: visibility,
      metadata: {
        'reactionType': reactionType,
      },
      operationName: 'Track reaction added',
    );
  }

  Future<void> trackMenuCreated({
    required String menuId,
    required String menuTitle,
    List<String>? visibility,
  }) async {
    await _trackGenericActivity(
      type: ActivityType.menuCreated,
      targetId: menuId,
      targetType: 'menu',
      targetTitle: menuTitle,
      visibility: visibility,
      operationName: 'Track menu created',
    );
  }

  Future<void> trackShoppingListCreated({
    required String listId,
    required String listTitle,
    List<String>? visibility,
  }) async {
    await _trackGenericActivity(
      type: ActivityType.shoppingListCreated,
      targetId: listId,
      targetType: 'shopping_list',
      targetTitle: listTitle,
      visibility: visibility,
      operationName: 'Track shopping list created',
    );
  }


  Future<List<ActivityFeedItem>> getFriendActivityFeed({
    int limit = 20,
    int offset = 0,
    List<String>? friendCategories,
  }) async {
    final result = await executeServiceOperation(
      () async {
        final currentUser = _authRepository.currentUser;
        if (currentUser == null) {
          throw AuthenticationException('User must be authenticated to get activity feed');
        }

        final cacheKey = ActivityCacheHelper.getFeedCacheKey(currentUser.uid, friendCategories);

        // Check cache first
        if (ActivityCacheHelper.isCacheValid(cacheKey, _cacheTimestamps) && offset == 0) {
          final cachedFeed = _feedCache[cacheKey];
          if (cachedFeed != null) {
            return cachedFeed.take(limit).toList();
          }
        }

        final activities = await _activityRepository.getFriendActivityFeed(
          userId: currentUser.uid,
          limit: limit,
          offset: offset,
          friendCategories: friendCategories,
        );

        // Cache the results if it's the first page
        if (offset == 0) {
          _feedCache[cacheKey] = activities;
          _cacheTimestamps[cacheKey] = DateTime.now();
          ActivityCacheHelper.cleanupCache(_feedCache, _cacheTimestamps);
        }

        return activities;
      },
      operationName: 'Get friend activity feed',
      requiresAuth: true,
      requiresNetwork: true,
    );
    
    return result ?? [];
  }

  Stream<List<ActivityFeedItem>> getActivityFeedStream({
    int limit = 50,
    List<String>? friendCategories,
  }) {
    final currentUser = _authRepository.currentUser;
    if (currentUser == null) {
      AppLogger.warning('User not authenticated for activity feed stream');
      return const Stream.empty();
    }

    final streamKey = ActivityCacheHelper.getFeedCacheKey(currentUser.uid, friendCategories);
    
    // Close existing stream if any
    _feedStreams[streamKey]?.cancel();
    
    final stream = _activityRepository.getFriendActivityFeedStream(
      userId: currentUser.uid,
      limit: limit,
      friendCategories: friendCategories,
    );

    // Cache updates from the stream
    _feedStreams[streamKey] = stream.listen((activities) {
      _feedCache[streamKey] = activities;
      _cacheTimestamps[streamKey] = DateTime.now();
    });

    return stream;
  }

  Future<List<ActivityFeedItem>> getUserActivities({
    String? userId,
    int limit = 50,
    List<ActivityType>? activityTypes,
  }) async {
    final result = await executeServiceOperation(
      () async {
        final currentUser = _authRepository.currentUser;
        if (currentUser == null) {
          throw AuthenticationException('User must be authenticated to get activities');
        }

        final targetUserId = userId ?? currentUser.uid;
        
        return await _activityRepository.getUserActivities(
          userId: targetUserId,
          limit: limit,
          activityTypes: activityTypes,
        );
      },
      operationName: 'Get user activities',
      requiresAuth: true,
      requiresNetwork: true,
    );
    
    return result ?? [];
  }

  Future<List<ActivityFeedItem>> getTrendingActivities({
    Duration timeWindow = const Duration(hours: 24),
    int limit = 20,
    List<ActivityType>? activityTypes,
  }) async {
    final result = await executeServiceOperation(
      () async {
        return await _activityRepository.getTrendingActivities(
          timeWindow: timeWindow,
          limit: limit,
          activityTypes: activityTypes,
        );
      },
      operationName: 'Get trending activities',
      requiresAuth: false,
      requiresNetwork: true,
    );
    
    return result ?? [];
  }

  Future<int> getUnseenActivityCount({
    List<String>? friendCategories,
  }) async {
    final result = await executeServiceOperation(
      () async {
        final currentUser = _authRepository.currentUser;
        if (currentUser == null) {
          throw AuthenticationException('User must be authenticated to get unseen count');
        }

        return await _activityRepository.getUnseenActivityCount(
          userId: currentUser.uid,
          friendCategories: friendCategories,
        );
      },
      operationName: 'Get unseen activity count',
      requiresAuth: true,
      requiresNetwork: true,
    );
    
    return result ?? 0;
  }

  Future<void> markActivitiesAsSeen(List<String> activityIds) async {
    await executeServiceOperation(
      () async {
        final currentUser = _authRepository.currentUser;
        if (currentUser == null) {
          throw AuthenticationException('User must be authenticated to mark activities as seen');
        }

        await _activityRepository.markActivitiesAsSeen(
          userId: currentUser.uid,
          activityIds: activityIds,
        );

        // Invalidate cache after marking as seen
        ActivityCacheHelper.invalidateCache(currentUser.uid, _feedCache, _cacheTimestamps);
      },
      operationName: 'Mark activities as seen',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }


  Future<void> hideActivity(String activityId) async {
    await executeServiceOperation(
      () async {
        final currentUser = _authRepository.currentUser;
        if (currentUser == null) {
          throw AuthenticationException('User must be authenticated to hide activities');
        }

        await _activityRepository.hideActivityFromUser(
          userId: currentUser.uid,
          activityId: activityId,
        );

        ActivityCacheHelper.invalidateCache(currentUser.uid, _feedCache, _cacheTimestamps);
        AppLogger.debug('Activity hidden: $activityId');
      },
      operationName: 'Hide activity',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  Future<void> blockActivityType(ActivityType activityType) async {
    await executeServiceOperation(
      () async {
        final currentUser = _authRepository.currentUser;
        if (currentUser == null) {
          throw AuthenticationException('User must be authenticated to block activity types');
        }

        await _activityRepository.blockActivityType(
          userId: currentUser.uid,
          activityType: activityType,
        );

        ActivityCacheHelper.invalidateCache(currentUser.uid, _feedCache, _cacheTimestamps);
        AppLogger.debug('Activity type blocked: ${activityType.key}');
      },
      operationName: 'Block activity type',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }


  Future<void> _trackGenericActivity({
    required ActivityType type,
    required String targetId,
    required String targetType,
    required String targetTitle,
    String? targetImageUrl,
    List<String>? visibility,
    Map<String, dynamic>? metadata,
    required String operationName,
  }) async {
    await executeServiceOperation(
      () async {
        final currentUser = _authRepository.currentUser;
        if (currentUser == null) {
          throw AuthenticationException('User must be authenticated to track activity');
        }

        final activity = ActivityFeedItem.create(
          userId: currentUser.uid,
          userDisplayName: currentUser.displayName ?? 'Okänd användare',
          userAvatarUrl: currentUser.photoURL,
          type: type,
          targetId: targetId,
          targetType: targetType,
          targetTitle: targetTitle,
          targetImageUrl: targetImageUrl,
          visibility: visibility ?? ['all_friends'],
          metadata: metadata ?? {},
        );

        await _activityRepository.createActivity(activity);
        ActivityCacheHelper.invalidateCache(currentUser.uid, _feedCache, _cacheTimestamps);

        AppLogger.debug('Activity tracked: ${type.key} for $targetType:$targetId');
      },
      operationName: operationName,
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  @override
  Future<void> dispose() async {
    // Cancel all active streams
    for (final subscription in _feedStreams.values) {
      await subscription.cancel();
    }
    _feedStreams.clear();
    
    // Clear caches
    _feedCache.clear();
    _cacheTimestamps.clear();
    
    await super.dispose();
  }
}