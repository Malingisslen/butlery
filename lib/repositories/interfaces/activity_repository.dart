// lib/repositories/interfaces/activity_repository.dart

import 'package:butlery/models/social/activity_feed_item.dart';

/// Repository interface for social activity feed management
///
/// This interface provides comprehensive activity tracking and feed functionality
/// following established repository patterns from the existing codebase. It supports
/// activity creation, querying, engagement tracking, and privacy controls with
/// performance optimization through bulk operations and real-time streams.
///
/// **Architecture Integration:**
/// - Follows BaseFirebaseRepository patterns with permission validation
/// - Integrates with PermissionValidationMixin for security
/// - Supports bulk operations for feed performance optimization
/// - Provides real-time streams for live activity updates
/// - Uses consistent error handling and logging patterns
///
/// **Activity Management:**
/// - Activity creation and tracking across all content types
/// - Friend-based activity filtering with privacy controls
/// - Engagement metrics tracking (likes, comments, shares, views)
/// - Activity aggregation and feed generation
/// - Performance optimization through caching and pagination
///
/// **Privacy Features:**
/// - Friend category-based visibility control
/// - User privacy preference enforcement
/// - Activity type filtering and blocking
/// - Content-specific privacy inheritance
///
/// **Usage Examples:**
/// ```dart
/// final activityRepo = ServiceLocator.get<ActivityRepository>();
/// 
/// // Create activity when user creates recipe
/// await activityRepo.createActivity(
///   ActivityFeedItem.create(
///     userId: 'user123',
///     type: ActivityType.recipeCreated,
///     targetId: 'recipe456',
///     targetType: 'recipe',
///     targetTitle: 'Köttbullar med potatismos',
///   ),
/// );
/// 
/// // Get friend activity feed
/// final activities = await activityRepo.getFriendActivityFeed(
///   userId: 'user123',
///   limit: 20,
/// );
/// ```
abstract class ActivityRepository {
  // ===== ACTIVITY OPERATIONS =====

  /// Create new activity in the feed
  /// 
  /// Records user activity with proper privacy controls and engagement tracking.
  /// Implements validation to prevent spam and ensure data consistency.
  /// 
  /// [activity] Complete activity item with user, target, and metadata
  /// 
  /// Throws [PermissionDeniedException] if user lacks activity creation permissions
  /// Throws [ValidationException] for invalid activity data or spam detection
  Future<void> createActivity(ActivityFeedItem activity);

  /// Create multiple activities in batch for performance
  /// 
  /// Efficient bulk operation for activity creation during batch operations
  /// like importing recipes or bulk sharing activities.
  /// 
  /// [activities] List of activities to create atomically
  /// 
  /// Returns count of successfully created activities
  Future<int> createBulkActivities(List<ActivityFeedItem> activities);

  /// Update activity engagement metrics
  /// 
  /// Updates engagement counters when users interact with activities.
  /// Supports atomic increments for concurrent engagement tracking.
  /// 
  /// [activityId] ID of activity to update
  /// [engagement] New engagement metrics
  /// 
  /// Throws [ResourceNotFoundException] if activity doesn't exist
  Future<void> updateActivityEngagement(String activityId, ActivityEngagement engagement);

  /// Delete activity from feed
  /// 
  /// Removes activity with proper authorization checks. Only activity owner
  /// or authorized moderators can delete activities.
  /// 
  /// [activityId] ID of activity to delete
  /// [userId] ID of user requesting deletion
  /// 
  /// Throws [PermissionDeniedException] if user cannot delete activity
  Future<void> deleteActivity(String activityId, String userId);

  // ===== FEED QUERIES =====

  /// Get friend activity feed for user
  /// 
  /// Retrieves activities from user's friends with privacy filtering and
  /// engagement optimization. Results are ordered by timestamp and relevance.
  /// 
  /// [userId] ID of user requesting feed
  /// [limit] Maximum number of activities to return (default: 20)
  /// [offset] Pagination offset for additional activities
  /// [friendCategories] Optional filter for specific friend categories
  /// 
  /// Returns list of activities visible to user based on friend relationships
  Future<List<ActivityFeedItem>> getFriendActivityFeed({
    required String userId,
    int limit = 20,
    int offset = 0,
    List<String>? friendCategories,
  });

  /// Get real-time friend activity feed stream
  /// 
  /// Live stream of friend activities for real-time feed updates.
  /// Implements efficient filtering and batching for optimal performance.
  /// 
  /// [userId] ID of user requesting feed stream
  /// [limit] Maximum number of activities in stream (default: 50)
  /// [friendCategories] Optional filter for specific friend categories
  /// 
  /// Returns stream of activity updates with real-time changes
  Stream<List<ActivityFeedItem>> getFriendActivityFeedStream({
    required String userId,
    int limit = 50,
    List<String>? friendCategories,
  });

  /// Get user's own activity history
  /// 
  /// Retrieves user's personal activity history for profile display
  /// and activity management. Includes all activity types and engagement.
  /// 
  /// [userId] ID of user whose activities to retrieve
  /// [limit] Maximum number of activities to return (default: 50)
  /// [activityTypes] Optional filter for specific activity types
  /// 
  /// Returns list of user's activities ordered by timestamp
  Future<List<ActivityFeedItem>> getUserActivities({
    required String userId,
    int limit = 50,
    List<ActivityType>? activityTypes,
  });

  /// Get activities for specific content
  /// 
  /// Retrieves all activities related to specific content item.
  /// Used for content activity timelines and engagement tracking.
  /// 
  /// [contentId] ID of content to get activities for
  /// [contentType] Type of content ('recipe', 'menu', etc.)
  /// [limit] Maximum number of activities to return (default: 100)
  /// 
  /// Returns list of activities related to the content
  Future<List<ActivityFeedItem>> getContentActivities({
    required String contentId,
    required String contentType,
    int limit = 100,
  });

  /// Search activities by content or user
  /// 
  /// Full-text search across activity content and user information.
  /// Supports filtering by activity type, date range, and engagement.
  /// 
  /// [query] Search query string
  /// [userId] Optional filter for specific user's activities
  /// [activityTypes] Optional filter for specific activity types
  /// [dateRange] Optional date range for activity filtering
  /// [limit] Maximum number of results (default: 50)
  /// 
  /// Returns list of matching activities ordered by relevance
  Future<List<ActivityFeedItem>> searchActivities({
    required String query,
    String? userId,
    List<ActivityType>? activityTypes,
    DateTimeRange? dateRange,
    int limit = 50,
  });

  // ===== ANALYTICS OPERATIONS =====

  /// Get activity statistics for user
  /// 
  /// Comprehensive activity analytics including creation counts,
  /// engagement metrics, and trending content analysis.
  /// 
  /// [userId] ID of user to analyze
  /// [timeRange] Time period for analysis (default: 30 days)
  /// 
  /// Returns activity statistics and engagement metrics
  Future<Map<String, dynamic>> getUserActivityStatistics({
    required String userId,
    Duration timeRange = const Duration(days: 30),
  });

  /// Get trending activities
  /// 
  /// Identifies trending activities based on engagement velocity,
  /// reaction diversity, and viral coefficient calculation.
  /// 
  /// [timeWindow] Time window for trend analysis (default: 24 hours)
  /// [limit] Maximum number of trending activities (default: 20)
  /// [activityTypes] Optional filter for specific activity types
  /// 
  /// Returns list of trending activities with engagement scores
  Future<List<ActivityFeedItem>> getTrendingActivities({
    Duration timeWindow = const Duration(hours: 24),
    int limit = 20,
    List<ActivityType>? activityTypes,
  });

  /// Get activity engagement analytics
  /// 
  /// Detailed engagement analysis for activity performance tracking.
  /// Provides metrics for content creators and community managers.
  /// 
  /// [activityId] ID of activity to analyze
  /// 
  /// Returns detailed engagement metrics and interaction patterns
  Future<Map<String, dynamic>> getActivityEngagementAnalytics(String activityId);

  // ===== FEED MANAGEMENT =====

  /// Get recommended activities for user
  /// 
  /// AI-powered activity recommendations based on user preferences,
  /// friend interactions, and content similarity analysis.
  /// 
  /// [userId] ID of user to generate recommendations for
  /// [limit] Maximum number of recommendations (default: 10)
  /// [excludeTypes] Activity types to exclude from recommendations
  /// 
  /// Returns list of recommended activities with relevance scores
  Future<List<ActivityFeedItem>> getRecommendedActivities({
    required String userId,
    int limit = 10,
    List<ActivityType>? excludeTypes,
  });

  /// Mark activities as seen by user
  /// 
  /// Updates activity view tracking for engagement analytics and
  /// feed optimization. Prevents re-showing seen activities.
  /// 
  /// [userId] ID of user who viewed activities
  /// [activityIds] List of activity IDs that were viewed
  /// 
  /// Returns count of activities successfully marked as seen
  Future<int> markActivitiesAsSeen({
    required String userId,
    required List<String> activityIds,
  });

  /// Get unseen activity count for user
  /// 
  /// Efficient count query for displaying notification badges
  /// and feed freshness indicators without loading full activities.
  /// 
  /// [userId] ID of user to check unseen activities for
  /// [friendCategories] Optional filter for specific friend categories
  /// 
  /// Returns count of unseen activities in user's feed
  Future<int> getUnseenActivityCount({
    required String userId,
    List<String>? friendCategories,
  });

  // ===== PRIVACY OPERATIONS =====

  /// Update activity visibility
  /// 
  /// Allows users to modify activity visibility after creation.
  /// Supports granular privacy control and retroactive changes.
  /// 
  /// [activityId] ID of activity to update
  /// [userId] ID of user requesting update (must be activity owner)
  /// [visibility] New visibility settings
  /// 
  /// Throws [PermissionDeniedException] if user doesn't own activity
  Future<void> updateActivityVisibility({
    required String activityId,
    required String userId,
    required List<String> visibility,
  });

  /// Hide activity from user's feed
  /// 
  /// Allows users to hide specific activities from their feed without
  /// affecting the activity for other users. Used for content filtering.
  /// 
  /// [userId] ID of user hiding the activity
  /// [activityId] ID of activity to hide
  /// 
  /// Returns true if activity was successfully hidden
  Future<bool> hideActivityFromUser({
    required String userId,
    required String activityId,
  });

  /// Block activity type for user
  /// 
  /// Allows users to block specific activity types from appearing
  /// in their feed. Supports fine-grained activity type filtering.
  /// 
  /// [userId] ID of user setting the block
  /// [activityType] Type of activity to block
  /// 
  /// Returns true if activity type was successfully blocked
  Future<bool> blockActivityType({
    required String userId,
    required ActivityType activityType,
  });

  // ===== MODERATION OPERATIONS =====

  /// Flag activity for moderation
  /// 
  /// Community reporting system for inappropriate activities.
  /// Integrates with existing moderation workflows and notification systems.
  /// 
  /// [activityId] ID of activity being reported
  /// [reporterId] ID of user making the report
  /// [reason] Reason for reporting the activity
  /// [details] Additional details about the report
  /// 
  /// Returns report ID for tracking and follow-up
  Future<String> flagActivity({
    required String activityId,
    required String reporterId,
    required String reason,
    String? details,
  });

  /// Get flagged activities for moderation
  /// 
  /// Administrative query for moderation teams to review reported
  /// activities and take appropriate action.
  /// 
  /// [status] Filter by moderation status (pending, reviewed, resolved)
  /// [limit] Maximum number of flagged activities (default: 50)
  /// 
  /// Returns list of flagged activities with report details
  Future<List<Map<String, dynamic>>> getFlaggedActivities({
    String? status,
    int limit = 50,
  });

  /// Resolve activity flag
  /// 
  /// Administrative operation to resolve reported activities.
  /// Updates moderation status and takes appropriate action.
  /// 
  /// [flagId] ID of the flag/report to resolve
  /// [moderatorId] ID of moderator resolving the flag
  /// [action] Action taken (approved, removed, warned)
  /// [notes] Moderation notes for audit trail
  /// 
  /// Returns true if flag was successfully resolved
  Future<bool> resolveActivityFlag({
    required String flagId,
    required String moderatorId,
    required String action,
    String? notes,
  });
}

/// Date range class for activity filtering
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  const DateTimeRange({
    required this.start,
    required this.end,
  });

  /// Create range for last N days
  factory DateTimeRange.lastDays(int days) {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    return DateTimeRange(start: start, end: end);
  }

  /// Create range for current week
  factory DateTimeRange.thisWeek() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final start = now.subtract(Duration(days: weekday - 1));
    final end = start.add(const Duration(days: 6));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day, 23, 59, 59),
    );
  }

  /// Create range for current month
  factory DateTimeRange.thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  /// Check if date is within this range
  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }

  /// Get duration of this range
  Duration get duration => end.difference(start);

  @override
  String toString() => 'DateTimeRange(${start.toIso8601String()} - ${end.toIso8601String()})';
}