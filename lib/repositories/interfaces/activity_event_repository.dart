import 'package:butlery/models/social/activity_event.dart';

/// Repository interface for social activity events.
abstract class ActivityEventRepository {
  /// Write a new activity event.
  Future<void> addEvent(ActivityEvent event);

  /// Fetch recent activity from a set of friends, paginated by timestamp.
  Future<List<ActivityEvent>> fetchFriendActivity({
    required List<String> friendIds,
    int limit = 20,
    DateTime? before,
  });

  /// Get all events by a specific user (for GDPR export).
  Future<List<ActivityEvent>> getEventsByUser(String userId);

  /// Delete all events by a specific user (for GDPR deletion).
  Future<int> deleteAllByUser(String userId);

  /// Export all activity events authored by [userId] for GDPR Article 20.
  /// Returns raw `{id, data}` shapes. Implementations MUST validate the
  /// caller owns [userId].
  Future<List<Map<String, dynamic>>> exportEventsByUser(
    String userId, {
    int maxDocuments = 1000,
  });
}
