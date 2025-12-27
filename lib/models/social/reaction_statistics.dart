// lib/models/social/reaction_statistics.dart

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/social/reaction_type.dart';

/// Comprehensive reaction statistics model for content engagement analytics
/// This model provides detailed analytics for content reactions following the established
/// patterns from RatingStatistics. It supports real-time updates, performance optimization
/// through caching, and comprehensive engagement metrics for content creators and moderators.
/// **Analytics Capabilities:**
/// - Individual reaction type counts for detailed breakdown
/// - Total engagement metrics for overall performance
/// - User-specific reaction tracking for personalized experiences
/// - Top reactions identification for UI optimization
/// - Engagement trends and velocity tracking
/// **Performance Features:**
/// - Efficient count aggregation for UI display
/// - Bulk statistics operations for performance
/// - Cache-friendly structure for real-time updates
/// - Minimal data transfer for mobile optimization
/// **Usage Examples:**
/// ```dart
/// // Display reaction summary
/// final stats = ReactionStatistics.fromCounts({
///   ReactionType.like: 15,
///   ReactionType.delicious: 8,
///   ReactionType.creative: 3,
/// });
/// print('Total reactions: ${stats.totalCount}');
/// print('Top reaction: ${stats.topReaction?.displayText}');
/// ```
class ReactionStatistics {
  /// Map of reaction types to their counts
  final Map<ReactionType, int> reactionCounts;

  /// Count of unique users who have reacted (denormalized for performance)
  /// Individual user reactions are tracked in subcollection: content_reactions/{contentId}/users/{userId}
  final int userReactionCount;

  /// When these statistics were last updated
  final DateTime lastUpdated;

  /// Content ID these statistics belong to
  final String contentId;

  /// Content type these statistics belong to
  final String contentType;

  const ReactionStatistics({
    required this.reactionCounts,
    this.userReactionCount = 0,
    required this.lastUpdated,
    required this.contentId,
    required this.contentType,
  });

  /// Create empty statistics for new content
  factory ReactionStatistics.empty({
    required String contentId,
    required String contentType,
  }) {
    return ReactionStatistics(
      reactionCounts: {},
      userReactionCount: 0,
      lastUpdated: DateTime.now(),
      contentId: contentId,
      contentType: contentType,
    );
  }

  /// Create from reaction counts map
  factory ReactionStatistics.fromCounts(
    Map<ReactionType, int> counts, {
    required String contentId,
    required String contentType,
    int userReactionCount = 0,
  }) {
    return ReactionStatistics(
      reactionCounts: Map.from(counts),
      userReactionCount: userReactionCount,
      lastUpdated: DateTime.now(),
      contentId: contentId,
      contentType: contentType,
    );
  }

  /// Create from Firestore document
  factory ReactionStatistics.fromFirestore(
      String contentId, String contentType, Map<String, dynamic> data) {
    final Map<ReactionType, int> counts = {};

    // Parse reaction counts from Firestore data
    final countsData = SerializationUtils.safeMap(data, 'reactionCounts');
    for (final entry in countsData.entries) {
      try {
        // Check if this is a valid reaction type key
        final validKey =
            ReactionType.values.any((type) => type.key == entry.key);
        if (!validKey) {
          // Skip invalid reaction types for forward compatibility
          continue;
        }

        final reactionType = ReactionType.fromKey(entry.key);
        final count = entry.value as int? ?? 0;
        if (count > 0) {
          counts[reactionType] = count;
        }
      } catch (e) {
        // Skip invalid reaction types for forward compatibility
        continue;
      }
    }

    return ReactionStatistics(
      reactionCounts: counts,
      userReactionCount: SerializationUtils.safeInt(data, 'userReactionCount'),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        SerializationUtils.safeInt(data, 'lastUpdated',
            defaultValue: DateTime.now().millisecondsSinceEpoch),
      ),
      contentId: contentId,
      contentType: contentType,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    final Map<String, int> countsMap = {};
    for (final entry in reactionCounts.entries) {
      countsMap[entry.key.key] = entry.value;
    }

    return {
      'reactionCounts': countsMap,
      'userReactionCount': userReactionCount,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'contentId': contentId,
      'contentType': contentType,
    };
  }

  /// Get total reaction count across all types
  int get totalCount =>
      reactionCounts.values.fold(0, (sum, count) => sum + count);

  /// Get count for specific reaction type
  int getCount(ReactionType type) => reactionCounts[type] ?? 0;

  /// Get most popular reaction type
  ReactionType? get topReaction {
    if (reactionCounts.isEmpty) return null;

    var maxCount = 0;
    ReactionType? topType;

    for (final entry in reactionCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        topType = entry.key;
      }
    }

    return topType;
  }

  /// Get top N reaction types by count
  List<MapEntry<ReactionType, int>> getTopReactions(int limit) {
    final entries = reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(limit).toList();
  }

  /// Check if any users have reacted (use repository for specific user check)
  /// For user-specific check, query: content_reactions/{contentId}/users/{userId}
  bool get hasAnyUserReacted => userReactionCount > 0;

  /// Get reaction types that have counts
  List<ReactionType> get activeReactionTypes => reactionCounts.keys.toList();

  /// Check if content has any reactions
  bool get hasReactions => totalCount > 0;

  /// Get percentage breakdown of reactions
  Map<ReactionType, double> get reactionPercentages {
    if (totalCount == 0) return {};

    final Map<ReactionType, double> percentages = {};
    for (final entry in reactionCounts.entries) {
      percentages[entry.key] = (entry.value / totalCount) * 100;
    }
    return percentages;
  }

  /// Create updated copy with new counts
  ReactionStatistics copyWith({
    Map<ReactionType, int>? reactionCounts,
    int? userReactionCount,
    DateTime? lastUpdated,
    String? contentId,
    String? contentType,
  }) {
    return ReactionStatistics(
      reactionCounts: reactionCounts ?? Map.from(this.reactionCounts),
      userReactionCount: userReactionCount ?? this.userReactionCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
    );
  }

  /// Update reaction counts (for repository use)
  /// Note: User tracking is handled by repository via subcollection
  ReactionStatistics incrementReaction(ReactionType type,
      {bool isNewUser = false}) {
    final newCounts = Map<ReactionType, int>.from(reactionCounts);
    newCounts[type] = (newCounts[type] ?? 0) + 1;

    return copyWith(
      reactionCounts: newCounts,
      userReactionCount: isNewUser ? userReactionCount + 1 : userReactionCount,
      lastUpdated: DateTime.now(),
    );
  }

  /// Decrement reaction counts (for repository use)
  /// Note: User tracking is handled by repository via subcollection
  ReactionStatistics decrementReaction(ReactionType type,
      {bool wasLastReaction = false}) {
    final newCounts = Map<ReactionType, int>.from(reactionCounts);
    final currentCount = newCounts[type] ?? 0;

    if (currentCount > 1) {
      newCounts[type] = currentCount - 1;
    } else {
      newCounts.remove(type);
    }

    return copyWith(
      reactionCounts: newCounts,
      userReactionCount: wasLastReaction && userReactionCount > 0
          ? userReactionCount - 1
          : userReactionCount,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ReactionStatistics(contentId: $contentId, contentType: $contentType, totalCount: $totalCount, topReaction: ${topReaction?.key})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReactionStatistics &&
        other.contentId == contentId &&
        other.contentType == contentType;
  }

  @override
  int get hashCode => Object.hash(contentId, contentType);
}
