// lib/repositories/interfaces/reactions_repository.dart

import 'package:butlery/models/social/content_reaction.dart';
import 'package:butlery/models/social/reaction_type.dart';
import 'package:butlery/models/social/reaction_statistics.dart';

/// Repository interface for universal content reaction management
///
/// This interface provides comprehensive reaction functionality following established
/// repository patterns from the existing codebase. It supports all content types with
/// consistent operations, bulk processing for performance, and real-time updates for
/// optimal user experience.
///
/// **Architecture Integration:**
/// - Follows BaseFirebaseRepository patterns with permission validation
/// - Integrates with PermissionValidationMixin for security
/// - Supports bulk operations for UI performance optimization
/// - Provides real-time streams for live reaction updates
/// - Uses consistent error handling and logging patterns
///
/// **Content Type Support:**
/// - Recipes: Full reaction support with food-specific types
/// - Comments: Social engagement reactions for discussions
/// - Menus: Planning and utility reactions for meal organization
/// - Shopping Lists: Practical reactions for list utility
/// - User Profiles: Social appreciation reactions
/// - Extensible for future content types
///
/// **Performance Features:**
/// - Bulk statistics operations for list views
/// - Efficient user reaction queries for personalization
/// - Real-time reaction streams with minimal data transfer
/// - Optimized counting and aggregation operations
///
/// **Usage Examples:**
/// ```dart
/// final reactionsRepo = ServiceLocator.get<ReactionsRepository>();
/// 
/// // Toggle user reaction
/// await reactionsRepo.toggleReaction(
///   contentId: 'recipe_123',
///   contentType: 'recipe',
///   userId: 'user_456',
///   reactionType: ReactionType.delicious,
/// );
/// 
/// // Get live reaction counts
/// reactionsRepo.getReactionStatisticsStream('recipe_123', 'recipe')
///   .listen((stats) => updateUI(stats));
/// ```
abstract class ReactionsRepository {
  // ===== REACTION OPERATIONS =====

  /// Add or update user reaction to content
  /// 
  /// Creates new reaction or updates existing reaction type for the user.
  /// Implements optimistic updates with rollback capability for UI responsiveness.
  /// 
  /// [contentId] Unique identifier of content being reacted to
  /// [contentType] Type of content ('recipe', 'comment', 'menu', etc.)
  /// [userId] ID of user creating the reaction
  /// [reactionType] Type of reaction being expressed
  /// 
  /// Throws [PermissionDeniedException] if user lacks reaction permissions
  /// Throws [ValidationException] for invalid content or reaction types
  Future<void> addReaction({
    required String contentId,
    required String contentType,
    required String userId,
    required ReactionType reactionType,
  });

  /// Remove user reaction from content
  /// 
  /// Removes specific reaction type from user's reactions on the content.
  /// Handles cleanup of empty reaction records and statistics updates.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content being unreacted
  /// [userId] ID of user removing the reaction  
  /// [reactionType] Type of reaction being removed
  /// 
  /// Throws [PermissionDeniedException] if user cannot modify reaction
  /// Throws [ResourceNotFoundException] if reaction doesn't exist
  Future<void> removeReaction({
    required String contentId,
    required String contentType,
    required String userId,
    required ReactionType reactionType,
  });

  /// Toggle user reaction on content
  /// 
  /// Intelligent toggle that adds reaction if not present, removes if same type,
  /// or updates if different type. Provides optimal UX for reaction interactions.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content being reacted to
  /// [userId] ID of user toggling the reaction
  /// [reactionType] Type of reaction being toggled
  /// 
  /// Returns the final reaction state after toggle operation
  /// Throws [PermissionDeniedException] for unauthorized operations
  Future<ContentReaction?> toggleReaction({
    required String contentId,
    required String contentType,
    required String userId,
    required ReactionType reactionType,
  });

  /// Remove all user reactions from content
  /// 
  /// Bulk removal operation for clearing all of a user's reactions.
  /// Useful for content moderation and user preference changes.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// [userId] ID of user whose reactions to remove
  /// 
  /// Returns count of reactions removed
  Future<int> removeAllUserReactions({
    required String contentId,
    required String contentType,
    required String userId,
  });

  // ===== QUERY OPERATIONS =====

  /// Get all user reactions for specific content
  /// 
  /// Retrieves complete reaction list for user on content. Enables
  /// UI to show active reaction states and reaction history.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// [userId] ID of user whose reactions to retrieve
  /// 
  /// Returns list of user's reactions on the content
  Future<List<ContentReaction>> getUserReactions({
    required String contentId,
    required String contentType,
    required String userId,
  });

  /// Get user's specific reaction type for content
  /// 
  /// Optimized query for checking if user has reacted with specific type.
  /// Used for UI state management and reaction button display.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// [userId] ID of user
  /// [reactionType] Type of reaction to check for
  /// 
  /// Returns reaction if exists, null otherwise
  Future<ContentReaction?> getUserReaction({
    required String contentId,
    required String contentType,
    required String userId,
    required ReactionType reactionType,
  });

  /// Check if user has any reaction on content
  /// 
  /// Efficient boolean check for reaction existence. Optimized for
  /// permission checks and UI state determination.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// [userId] ID of user to check
  /// 
  /// Returns true if user has reacted, false otherwise
  Future<bool> hasUserReacted({
    required String contentId,
    required String contentType,
    required String userId,
  });

  /// Get all reactions for specific content
  /// 
  /// Administrative query for content moderation and analytics.
  /// Returns complete reaction history with user attribution.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// [limit] Maximum number of reactions to return (default: 100)
  /// 
  /// Returns list of all reactions on the content
  Future<List<ContentReaction>> getContentReactions({
    required String contentId,
    required String contentType,
    int limit = 100,
  });

  // ===== STATISTICS OPERATIONS =====

  /// Get reaction statistics for content
  /// 
  /// Comprehensive analytics including counts, percentages, and trends.
  /// Optimized for UI display and performance with cached aggregations.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// 
  /// Returns complete reaction statistics or null if no reactions
  Future<ReactionStatistics?> getReactionStatistics({
    required String contentId,
    required String contentType,
  });

  /// Get real-time reaction statistics stream
  /// 
  /// Live updates for reaction counts and user interactions.
  /// Essential for real-time social features and engagement tracking.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// 
  /// Returns stream of reaction statistics updates
  Stream<ReactionStatistics> getReactionStatisticsStream({
    required String contentId,
    required String contentType,
  });

  /// Get bulk reaction statistics for multiple content items
  /// 
  /// Performance-optimized bulk query for list views and feeds.
  /// Reduces database roundtrips and improves user experience.
  /// 
  /// [contentIds] List of content identifiers
  /// [contentType] Type of all content items (must be same type)
  /// 
  /// Returns map of content ID to reaction statistics
  Future<Map<String, ReactionStatistics>> getBulkReactionStatistics({
    required List<String> contentIds,
    required String contentType,
  });

  /// Get reaction count for specific type
  /// 
  /// Optimized query for single reaction type counting.
  /// Used for displaying specific reaction counts in UI.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// [reactionType] Type of reaction to count
  /// 
  /// Returns count of specified reactions
  Future<int> getReactionCount({
    required String contentId,
    required String contentType,
    required ReactionType reactionType,
  });

  // ===== ANALYTICS OPERATIONS =====

  /// Get trending content by reaction engagement
  /// 
  /// Analytics query for content discovery and recommendation systems.
  /// Considers reaction velocity, diversity, and recency for ranking.
  /// 
  /// [contentType] Type of content to analyze
  /// [timeWindow] Time window for trend analysis (default: 7 days)
  /// [limit] Maximum number of trending items (default: 50)
  /// 
  /// Returns list of trending content IDs with engagement scores
  Future<List<String>> getTrendingContent({
    required String contentType,
    Duration timeWindow = const Duration(days: 7),
    int limit = 50,
  });

  /// Get user's reaction history
  /// 
  /// Comprehensive user activity tracking for personalization and analytics.
  /// Enables recommendation systems and user behavior analysis.
  /// 
  /// [userId] ID of user whose history to retrieve
  /// [contentType] Optional filter for specific content type
  /// [limit] Maximum number of reactions to return (default: 100)
  /// 
  /// Returns list of user's recent reactions
  Future<List<ContentReaction>> getUserReactionHistory({
    required String userId,
    String? contentType,
    int limit = 100,
  });

  /// Get reaction diversity metrics for content
  /// 
  /// Advanced analytics for content quality assessment.
  /// Measures reaction type distribution and engagement patterns.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// 
  /// Returns diversity score and reaction type distribution
  Future<Map<String, dynamic>> getReactionDiversityMetrics({
    required String contentId,
    required String contentType,
  });

  // ===== MODERATION OPERATIONS =====

  /// Remove all reactions from content
  /// 
  /// Administrative operation for content moderation.
  /// Used when content is flagged or requires reaction reset.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// [reason] Reason for reaction removal (for audit trail)
  /// 
  /// Returns count of reactions removed
  Future<int> removeAllContentReactions({
    required String contentId,
    required String contentType,
    String? reason,
  });

  /// Block user reactions on content
  /// 
  /// Moderation tool for preventing specific users from reacting.
  /// Maintains user engagement while enforcing community standards.
  /// 
  /// [contentId] Unique identifier of content
  /// [contentType] Type of content
  /// [userId] ID of user to block
  /// [reason] Reason for blocking (for audit trail)
  Future<void> blockUserReactions({
    required String contentId,
    required String contentType,
    required String userId,
    String? reason,
  });
}