import 'package:butlery/models/social/activity_feed_item.dart';

/// Repository interface for social activity feed management.
abstract class ActivityRepository {
  /// Create new activity in the feed.
  Future<void> createActivity(ActivityFeedItem activity);

  /// Create multiple activities in batch for performance.
  Future<int> createBulkActivities(List<ActivityFeedItem> activities);

  /// Update activity engagement metrics.
  Future<void> updateActivityEngagement(String activityId, ActivityEngagement engagement);

  /// Delete activity from feed.
  Future<void> deleteActivity(String activityId, String userId);

  /// Get friend activity feed for user.
  Future<List<ActivityFeedItem>> getFriendActivityFeed({
    required String userId,
    int limit = 20,
    int offset = 0,
    List<String>? friendCategories,
  });

  /// Get real-time friend activity feed stream.
  Stream<List<ActivityFeedItem>> getFriendActivityFeedStream({
    required String userId,
    int limit = 50,
    List<String>? friendCategories,
  });

  /// Get user's own activity history.
  Future<List<ActivityFeedItem>> getUserActivities({
    required String userId,
    int limit = 50,
    List<ActivityType>? activityTypes,
  });

  /// Get activities for specific content.
  Future<List<ActivityFeedItem>> getContentActivities({
    required String contentId,
    required String contentType,
    int limit = 100,
  });

  /// Search activities by content or user.
  Future<List<ActivityFeedItem>> searchActivities({
    required String query,
    String? userId,
    List<ActivityType>? activityTypes,
    DateTimeRange? dateRange,
    int limit = 50,
  });

  /// Get activity statistics for user.
  Future<Map<String, dynamic>> getUserActivityStatistics({
    required String userId,
    Duration timeRange = const Duration(days: 30),
  });

  /// Get trending activities.
  Future<List<ActivityFeedItem>> getTrendingActivities({
    Duration timeWindow = const Duration(hours: 24),
    int limit = 20,
    List<ActivityType>? activityTypes,
  });

  /// Get activity engagement analytics.
  Future<Map<String, dynamic>> getActivityEngagementAnalytics(String activityId);

  /// Get recommended activities for user.
  Future<List<ActivityFeedItem>> getRecommendedActivities({
    required String userId,
    int limit = 10,
    List<ActivityType>? excludeTypes,
  });

  /// Mark activities as seen by user.
  Future<int> markActivitiesAsSeen({
    required String userId,
    required List<String> activityIds,
  });

  /// Get unseen activity count for user.
  Future<int> getUnseenActivityCount({
    required String userId,
    List<String>? friendCategories,
  });

  /// Update activity visibility.
  Future<void> updateActivityVisibility({
    required String activityId,
    required String userId,
    required List<String> visibility,
  });

  /// Hide activity from user's feed.
  Future<bool> hideActivityFromUser({
    required String userId,
    required String activityId,
  });

  /// Block activity type for user.
  Future<bool> blockActivityType({
    required String userId,
    required ActivityType activityType,
  });

  /// Flag activity for moderation.
  Future<String> flagActivity({
    required String activityId,
    required String reporterId,
    required String reason,
    String? details,
  });

  /// Get flagged activities for moderation.
  Future<List<Map<String, dynamic>>> getFlaggedActivities({
    String? status,
    int limit = 50,
  });

  /// Resolve activity flag.
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