// lib/services/social/activity_service.dart

import 'dart:async';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/repositories/interfaces/activity_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth_repo;
import 'package:butlery/models/social/activity_feed_item.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Universal activity service providing comprehensive social activity feed functionality
///
/// This service manages activity tracking and feed generation across all content types
/// with sophisticated privacy controls, engagement tracking, and real-time updates. It
/// follows the established BaseService architecture for consistent error handling and
/// logging while providing optimized performance through intelligent caching and
/// bulk operations.
///
/// **Architecture Integration:**
/// - Extends BaseService for consistent service patterns and error handling
/// - Uses ActivityRepository interface for flexible backend implementations
/// - Integrates with AuthRepository for user authentication and permission validation
/// - Coordinates with existing social services for comprehensive activity tracking
/// - Implements dependency injection through service locator for decoupled architecture
///
/// **Activity Tracking Features:**
/// - **Universal Activity Creation**: Records activities across all content types
/// - **Friend-Based Feeds**: Generates personalized feeds based on friend relationships
/// - **Privacy Controls**: Granular visibility control with friend category filtering
/// - **Real-time Updates**: Live activity streams with efficient change notification
/// - **Engagement Metrics**: Comprehensive interaction tracking and analytics
/// - **Performance Optimization**: Intelligent caching and bulk operations
///
/// **Feed Generation Features:**
/// - **Personalized Feeds**: AI-powered activity relevance and friend prioritization
/// - **Content Filtering**: Activity type filtering and user preference enforcement
/// - **Trending Activities**: Engagement-based trending content identification
/// - **Privacy Enforcement**: Automatic friend category and visibility validation
/// - **Performance Optimization**: Pagination, caching, and bulk loading
///
/// **Usage Examples:**
/// ```dart
/// final activityService = ActivityService(
///   activityRepository: ServiceLocator.get<ActivityRepository>(),
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// 
/// // Track recipe creation activity
/// await activityService.trackRecipeCreated(
///   recipeId: 'recipe123',
///   recipeTitle: 'Köttbullar med potatismos',
///   visibility: ['close_friends', 'family'],
/// );
/// 
/// // Get personalized activity feed
/// final activities = await activityService.getFriendActivityFeed(limit: 20);
/// 
/// // Get real-time activity updates
/// activityService.getActivityFeedStream().listen((activities) {
///   updateFeedUI(activities);
/// });
/// ```
class ActivityService extends BaseService {
  final ActivityRepository _activityRepository;
  final auth_repo.AuthRepository _authRepository;

  @override
  String get serviceName => 'ActivityService';

  // Activity caching for performance optimization
  final Map<String, List<ActivityFeedItem>> _feedCache = {};
  final Map<String, StreamSubscription> _feedStreams = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Cache configuration
  static const Duration _cacheTimeout = Duration(minutes: 5);
  static const int _maxCacheSize = 100;

  ActivityService({
    required ActivityRepository activityRepository,
    required auth_repo.AuthRepository authRepository,
  }) : _activityRepository = activityRepository,
       _authRepository = authRepository;

  // ===== ACTIVITY TRACKING OPERATIONS =====

  /// Track recipe creation activity
  Future<void> trackRecipeCreated({
    required String recipeId,
    required String recipeTitle,
    String? recipeImageUrl,
    List<String>? visibility,
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
          type: ActivityType.recipeCreated,
          targetId: recipeId,
          targetType: 'recipe',
          targetTitle: recipeTitle,
          targetImageUrl: recipeImageUrl,
          visibility: visibility ?? ['all_friends'],
        );

        await _activityRepository.createActivity(activity);
        _invalidateCache(currentUser.uid);
        
        AppLogger.debug('Recipe creation activity tracked: $recipeId');
      },
      operationName: 'Track recipe created',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  /// Track recipe sharing activity
  Future<void> trackRecipeShared({
    required String recipeId,
    required String recipeTitle,
    String? recipeImageUrl,
    required List<String> sharedWith,
    List<String>? visibility,
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
          type: ActivityType.recipeShared,
          targetId: recipeId,
          targetType: 'recipe',
          targetTitle: recipeTitle,
          targetImageUrl: recipeImageUrl,
          visibility: visibility ?? ['all_friends'],
          metadata: {
            'sharedWith': sharedWith,
            'shareCount': sharedWith.length,
          },
        );

        await _activityRepository.createActivity(activity);
        _invalidateCache(currentUser.uid);
        
        AppLogger.debug('Recipe sharing activity tracked: $recipeId shared with ${sharedWith.length} users');
      },
      operationName: 'Track recipe shared',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  /// Track recipe rating activity
  Future<void> trackRecipeRated({
    required String recipeId,
    required String recipeTitle,
    String? recipeImageUrl,
    required int rating,
    List<String>? visibility,
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
          type: ActivityType.recipeRated,
          targetId: recipeId,
          targetType: 'recipe',
          targetTitle: recipeTitle,
          targetImageUrl: recipeImageUrl,
          visibility: visibility ?? ['all_friends'],
          metadata: {
            'rating': rating,
            'maxRating': 5,
          },
        );

        await _activityRepository.createActivity(activity);
        _invalidateCache(currentUser.uid);
        
        AppLogger.debug('Recipe rating activity tracked: $recipeId rated $rating stars');
      },
      operationName: 'Track recipe rated',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  /// Track comment added activity
  Future<void> trackCommentAdded({
    required String contentId,
    required String contentType,
    required String contentTitle,
    String? contentImageUrl,
    String? commentId,
    String? parentCommentId,
    List<String>? visibility,
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
          type: ActivityType.commentAdded,
          targetId: contentId,
          targetType: contentType,
          targetTitle: contentTitle,
          targetImageUrl: contentImageUrl,
          parentId: commentId,
          parentType: 'comment',
          visibility: visibility ?? ['all_friends'],
          metadata: {
            'commentId': commentId,
            'parentCommentId': parentCommentId,
            'isReply': parentCommentId != null,
          },
        );

        await _activityRepository.createActivity(activity);
        _invalidateCache(currentUser.uid);
        
        AppLogger.debug('Comment activity tracked: comment on $contentType:$contentId');
      },
      operationName: 'Track comment added',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  /// Track reaction added activity
  Future<void> trackReactionAdded({
    required String contentId,
    required String contentType,
    required String contentTitle,
    String? contentImageUrl,
    required String reactionType,
    List<String>? visibility,
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
          type: ActivityType.reactionAdded,
          targetId: contentId,
          targetType: contentType,
          targetTitle: contentTitle,
          targetImageUrl: contentImageUrl,
          visibility: visibility ?? ['all_friends'],
          metadata: {
            'reactionType': reactionType,
          },
        );

        await _activityRepository.createActivity(activity);
        _invalidateCache(currentUser.uid);
        
        AppLogger.debug('Reaction activity tracked: $reactionType on $contentType:$contentId');
      },
      operationName: 'Track reaction added',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  /// Track menu creation activity
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

  /// Track shopping list creation activity
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

  // ===== FEED OPERATIONS =====

  /// Get personalized friend activity feed
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

        final cacheKey = _getFeedCacheKey(currentUser.uid, friendCategories);
        
        // Check cache first
        if (_isCacheValid(cacheKey) && offset == 0) {
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
          _cleanupCache();
        }

        return activities;
      },
      operationName: 'Get friend activity feed',
      requiresAuth: true,
      requiresNetwork: true,
    );
    
    return result ?? [];
  }

  /// Get real-time activity feed stream
  Stream<List<ActivityFeedItem>> getActivityFeedStream({
    int limit = 50,
    List<String>? friendCategories,
  }) {
    final currentUser = _authRepository.currentUser;
    if (currentUser == null) {
      AppLogger.warning('User not authenticated for activity feed stream');
      return const Stream.empty();
    }

    final streamKey = _getFeedCacheKey(currentUser.uid, friendCategories);
    
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

  /// Get user's own activity history
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

  /// Get trending activities
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

  /// Get unseen activity count
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

  /// Mark activities as seen
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
        _invalidateCache(currentUser.uid);
      },
      operationName: 'Mark activities as seen',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  // ===== PRIVACY OPERATIONS =====

  /// Hide activity from user's feed
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
        
        _invalidateCache(currentUser.uid);
        AppLogger.debug('Activity hidden: $activityId');
      },
      operationName: 'Hide activity',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  /// Block activity type for current user
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
        
        _invalidateCache(currentUser.uid);
        AppLogger.debug('Activity type blocked: ${activityType.key}');
      },
      operationName: 'Block activity type',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Generic activity tracking method
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
        _invalidateCache(currentUser.uid);
        
        AppLogger.debug('Activity tracked: ${type.key} for $targetType:$targetId');
      },
      operationName: operationName,
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  String _getFeedCacheKey(String userId, List<String>? friendCategories) {
    final categories = friendCategories?.join(',') ?? 'all';
    return '${userId}_$categories';
  }

  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheTimeout;
  }

  void _invalidateCache(String userId) {
    final keysToRemove = _feedCache.keys
        .where((key) => key.startsWith(userId))
        .toList();
    
    for (final key in keysToRemove) {
      _feedCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  void _cleanupCache() {
    if (_feedCache.length <= _maxCacheSize) return;
    
    // Remove oldest cache entries
    final sortedEntries = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    final entriesToRemove = sortedEntries.take(_feedCache.length - _maxCacheSize);
    for (final entry in entriesToRemove) {
      _feedCache.remove(entry.key);
      _cacheTimestamps.remove(entry.key);
    }
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