import 'package:butlery/models/social/content_reaction.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'package:butlery/models/social/reaction_statistics.dart';

/// Repository interface for universal content reaction management.
abstract class ReactionsRepository {
  /// Add or update user reaction to content.
  Future<void> addReaction({
    required String contentId,
    required String contentType,
    required String userId,
    required ReactionType reactionType,
  });

  /// Remove user reaction from content.
  Future<void> removeReaction({
    required String contentId,
    required String contentType,
    required String userId,
    required ReactionType reactionType,
  });

  /// Toggle user reaction on content.
  Future<ContentReaction?> toggleReaction({
    required String contentId,
    required String contentType,
    required String userId,
    required ReactionType reactionType,
  });

  /// Remove all user reactions from content.
  Future<int> removeAllUserReactions({
    required String contentId,
    required String contentType,
    required String userId,
  });

  /// Get all user reactions for specific content.
  Future<List<ContentReaction>> getUserReactions({
    required String contentId,
    required String contentType,
    required String userId,
  });

  /// Get user's specific reaction type for content.
  Future<ContentReaction?> getUserReaction({
    required String contentId,
    required String contentType,
    required String userId,
    required ReactionType reactionType,
  });

  /// Check if user has any reaction on content.
  Future<bool> hasUserReacted({
    required String contentId,
    required String contentType,
    required String userId,
  });

  /// Get all reactions for specific content.
  Future<List<ContentReaction>> getContentReactions({
    required String contentId,
    required String contentType,
    int limit = 100,
  });

  /// Get reaction statistics for content.
  Future<ReactionStatistics?> getReactionStatistics({
    required String contentId,
    required String contentType,
  });

  /// Get real-time reaction statistics stream.
  Stream<ReactionStatistics> getReactionStatisticsStream({
    required String contentId,
    required String contentType,
  });

  /// Get bulk reaction statistics for multiple content items.
  Future<Map<String, ReactionStatistics>> getBulkReactionStatistics({
    required List<String> contentIds,
    required String contentType,
  });

  /// Get reaction count for specific type.
  Future<int> getReactionCount({
    required String contentId,
    required String contentType,
    required ReactionType reactionType,
  });

  /// Get trending content by reaction engagement.
  Future<List<String>> getTrendingContent({
    required String contentType,
    Duration timeWindow = const Duration(days: 7),
    int limit = 50,
  });

  /// Get user's reaction history.
  Future<List<ContentReaction>> getUserReactionHistory({
    required String userId,
    String? contentType,
    int limit = 100,
  });

  /// Get reaction diversity metrics for content.
  Future<Map<String, dynamic>> getReactionDiversityMetrics({
    required String contentId,
    required String contentType,
  });

  /// Remove all reactions from content.
  Future<int> removeAllContentReactions({
    required String contentId,
    required String contentType,
    String? reason,
  });

  /// Block user reactions on content.
  Future<void> blockUserReactions({
    required String contentId,
    required String contentType,
    required String userId,
    String? reason,
  });
}