// lib/models/social/reactions.dart

/// Universal content reactions system for social engagement
/// 
/// This barrel file exports all reaction-related models, types, and utilities
/// for comprehensive content engagement across the application. The system
/// provides rich reaction types beyond simple likes, with analytics, 
/// real-time updates, and content-aware filtering.
///
/// **Core Components:**
/// - [ReactionType] - Enumeration of available reaction types
/// - [ContentReaction] - Individual reaction model with user attribution
/// - [ReactionStatistics] - Aggregated analytics and engagement metrics
///
/// **Usage Examples:**
/// ```dart
/// import 'package:butlery/models/social/reactions.dart';
/// 
/// // Create a reaction
/// final reaction = ContentReaction.create(
///   contentId: 'recipe_123',
///   contentType: 'recipe',
///   userId: 'user_456',
///   reactionType: ReactionType.delicious,
/// );
/// 
/// // Get reaction statistics
/// final stats = ReactionStatistics.fromCounts({
///   ReactionType.like: 15,
///   ReactionType.delicious: 8,
/// }, contentId: 'recipe_123', contentType: 'recipe');
/// ```

export 'reaction_type.dart';
export 'content_reaction.dart';
export 'reaction_statistics.dart';