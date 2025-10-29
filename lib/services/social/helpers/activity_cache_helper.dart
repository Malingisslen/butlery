// lib/services/social/helpers/activity_cache_helper.dart

import 'package:butlery/models/social/activity_feed_item.dart';

/// Helper for activity feed caching operations.
///
/// Manages cache keys, validation, invalidation, and cleanup with configurable timeouts.
class ActivityCacheHelper {
  static const Duration cacheTimeout = Duration(minutes: 5);
  static const int maxCacheSize = 100;

  /// Generate cache key for user feed with optional friend categories
  static String getFeedCacheKey(String userId, List<String>? friendCategories) {
    final categories = friendCategories?.join(',') ?? 'all';
    return '${userId}_$categories';
  }

  /// Check if cache entry is still valid based on timestamp
  static bool isCacheValid(
    String cacheKey,
    Map<String, DateTime> cacheTimestamps,
  ) {
    final timestamp = cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < cacheTimeout;
  }

  /// Invalidate all cache entries for a specific user
  static void invalidateCache(
    String userId,
    Map<String, List<ActivityFeedItem>> feedCache,
    Map<String, DateTime> cacheTimestamps,
  ) {
    final keysToRemove = feedCache.keys
        .where((key) => key.startsWith(userId))
        .toList();

    for (final key in keysToRemove) {
      feedCache.remove(key);
      cacheTimestamps.remove(key);
    }
  }

  /// Clean up oldest cache entries when max size exceeded
  static void cleanupCache(
    Map<String, List<ActivityFeedItem>> feedCache,
    Map<String, DateTime> cacheTimestamps,
  ) {
    if (feedCache.length <= maxCacheSize) return;

    // Remove oldest cache entries
    final sortedEntries = cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final entriesToRemove = sortedEntries.take(feedCache.length - maxCacheSize);
    for (final entry in entriesToRemove) {
      feedCache.remove(entry.key);
      cacheTimestamps.remove(entry.key);
    }
  }
}
