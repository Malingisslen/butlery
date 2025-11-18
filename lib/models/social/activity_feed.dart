// lib/models/social/activity_feed.dart

/// Social activity feed system for friend activity streams
/// This barrel file exports all activity feed related models, types, and utilities
/// for comprehensive social activity tracking and feed generation. The system
/// provides rich activity types, engagement metrics, and privacy controls.
/// **Core Components:**
/// - [ActivityFeedItem] - Individual activity model with engagement tracking
/// - [ActivityType] - Enumeration of all supported activity types
/// - [ActivityEngagement] - Engagement metrics for social interactions
/// **Usage Examples:**
/// ```dart
/// import 'package:butlery/models/social/activity_feed.dart';
/// // Create a recipe creation activity
/// final activity = ActivityFeedItem.create(
///   userId: 'user123',
///   userDisplayName: 'Anna Andersson',
///   type: ActivityType.recipeCreated,
///   targetId: 'recipe456',
///   targetType: 'recipe',
///   targetTitle: 'Köttbullar med potatismos',
///   visibility: ['close_friends', 'family'],
/// );
/// // Track engagement
/// final engagement = ActivityEngagement(
///   likes: 15,
///   comments: 3,
///   shares: 2,
///   views: 45,
/// );
/// ```

export 'activity_feed_item.dart';