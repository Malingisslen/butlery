// lib/services/notifications/notification_types.dart

/// Notification system types and strategies for Butlery app
/// 
/// Defines different notification delivery strategies based on user interaction patterns:
/// - IMMEDIATE: Real-time notifications for critical social interactions
/// - BATCHABLE: Smart grouping for similar actions to prevent spam
/// - SILENT: Background data sync without user interruption
/// - DIGEST: Periodic summaries for activity feeds
/// - OPTIONAL: User-configurable notifications with defaults

enum NotificationType {
  /// Real-time notifications that require immediate user attention
  /// Examples: Friend requests, direct recipe shares, collaboration invites
  immediate,
  
  /// Notifications that can be intelligently grouped to prevent spam
  /// Examples: Multiple comments, likes, activity updates from same user
  batchable,
  
  /// Background data updates without user notification
  /// Examples: Recipe sync, shopping list item updates, presence updates
  silent,
  
  /// Periodic summaries sent on schedule (daily/weekly)
  /// Examples: Friend activity digest, recipe recommendations, trends
  digest,
  
  /// User can choose to enable/disable, with sensible defaults
  /// Examples: Friends coming online, profile milestones, achievements
  optional,
}

enum NotificationPriority {
  critical,  // Friend requests, direct shares
  high,      // Comments, collaboration
  medium,    // Activity updates, likes
  low,       // Digest summaries, optional features
}

enum NotificationCategory {
  friends,           // Friend system interactions
  recipes,           // Recipe sharing and collaboration
  collaboration,     // Real-time editing and presence
  shopping,          // Shopping list sharing and updates
  social,            // General social activity
  system,            // App updates and maintenance
}

/// Notification delivery strategy configuration
class NotificationStrategy {
  final NotificationType type;
  final NotificationPriority priority;
  final NotificationCategory category;
  final Duration? batchWindow;  // For batchable notifications
  final int? maxBatchSize;      // Maximum notifications to batch
  final bool requiresInternet;  // Whether to queue offline
  final Map<String, String> localization; // Swedish/English templates

  const NotificationStrategy({
    required this.type,
    required this.priority,
    required this.category,
    this.batchWindow,
    this.maxBatchSize,
    this.requiresInternet = true,
    this.localization = const {},
  });

  /// Friend request sent/received - immediate attention required
  static const friendRequest = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.critical,
    category: NotificationCategory.friends,
    localization: {
      'title_sv': 'Ny vänskapsförfrågan',
      'title_en': 'New friend request',
      'body_sv': '{senderName} vill bli vän med dig',
      'body_en': '{senderName} wants to be your friend',
    },
  );

  /// Recipe shared directly with user - immediate notification
  static const recipeShared = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.recipes,
    localization: {
      'title_sv': 'Nytt recept delat',
      'title_en': 'Recipe shared with you',
      'body_sv': '{senderName} delade "{recipeName}" med dig',
      'body_en': '{senderName} shared "{recipeName}" with you',
    },
  );

  /// Recipe comments - can be batched to prevent spam
  static const recipeComment = NotificationStrategy(
    type: NotificationType.batchable,
    priority: NotificationPriority.medium,
    category: NotificationCategory.recipes,
    batchWindow: Duration(minutes: 5),
    maxBatchSize: 5,
    localization: {
      'title_sv': 'Nya kommentarer',
      'title_en': 'New comments',
      'body_sv': '{count} nya kommentarer på dina recept',
      'body_en': '{count} new comments on your recipes',
    },
  );

  /// Real-time collaboration invitation - immediate for active sessions
  static const collaborationInvite = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.collaboration,
    localization: {
      'title_sv': 'Samarbetsinbjudan',
      'title_en': 'Collaboration invite',
      'body_sv': '{senderName} bjuder in dig att redigera "{resourceName}"',
      'body_en': '{senderName} invited you to edit "{resourceName}"',
    },
  );

  /// Shopping list updates - silent sync with periodic summary
  static const shoppingListUpdate = NotificationStrategy(
    type: NotificationType.silent,
    priority: NotificationPriority.low,
    category: NotificationCategory.shopping,
    requiresInternet: false,
  );

  /// Daily activity digest - scheduled periodic summary
  static const activityDigest = NotificationStrategy(
    type: NotificationType.digest,
    priority: NotificationPriority.low,
    category: NotificationCategory.social,
    localization: {
      'title_sv': 'Dagens aktivitet',
      'title_en': 'Daily activity',
      'body_sv': 'Se vad dina vänner lagat idag',
      'body_en': 'See what your friends cooked today',
    },
  );

  /// Friend online status - optional user preference
  static const friendOnline = NotificationStrategy(
    type: NotificationType.optional,
    priority: NotificationPriority.low,
    category: NotificationCategory.friends,
    localization: {
      'title_sv': 'Vän online',
      'title_en': 'Friend online',
      'body_sv': '{friendName} är nu online',
      'body_en': '{friendName} is now online',
    },
  );

  /// Friend request accepted - immediate feedback
  static const friendRequestAccepted = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.friends,
    localization: {
      'title_sv': 'Vänskapsförfrågan accepterad',
      'title_en': 'Friend request accepted',
      'body_sv': '{acceptorName} accepterade din vänskapsförfrågan',
      'body_en': '{acceptorName} accepted your friend request',
    },
  );

  /// Collaboration joined - silent notification for presence
  static const collaborationJoined = NotificationStrategy(
    type: NotificationType.silent,
    priority: NotificationPriority.low,
    category: NotificationCategory.collaboration,
    requiresInternet: false,
  );

  /// Collaboration left - silent notification for presence
  static const collaborationLeft = NotificationStrategy(
    type: NotificationType.silent,
    priority: NotificationPriority.low,
    category: NotificationCategory.collaboration,
    requiresInternet: false,
  );

  /// Real-time edit notification - silent for live collaboration
  static const realtimeEdit = NotificationStrategy(
    type: NotificationType.silent,
    priority: NotificationPriority.low,
    category: NotificationCategory.collaboration,
    requiresInternet: false,
  );

  /// Collaboration enabled - immediate notification for new feature
  static const collaborationEnabled = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.collaboration,
    localization: {
      'title_sv': 'Samarbete aktiverat',
      'title_en': 'Collaboration enabled',
      'body_sv': '{enablerName} aktiverade samarbete för "{recipeTitle}"',
      'body_en': '{enablerName} enabled collaboration for "{recipeTitle}"',
    },
  );
}

/// Template for notification content
class NotificationTemplate {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? imageUrl;
  final List<NotificationAction>? actions;

  const NotificationTemplate({
    required this.title,
    required this.body,
    required this.data,
    this.imageUrl,
    this.actions,
  });

  /// Create from strategy with variable substitution
  factory NotificationTemplate.fromStrategy(
    NotificationStrategy strategy,
    Map<String, String> variables, {
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) {
    // Use Swedish by default (app is primarily Swedish)
    final titleTemplate = strategy.localization['title_sv'] ?? 'Ny aktivitet';
    final bodyTemplate = strategy.localization['body_sv'] ?? 'Du har ny aktivitet i Butlery';

    // Substitute variables in templates
    String title = titleTemplate;
    String body = bodyTemplate;
    
    variables.forEach((key, value) {
      title = title.replaceAll('{$key}', value);
      body = body.replaceAll('{$key}', value);
    });

    // Build data payload
    final data = <String, dynamic>{
      'type': strategy.type.toString(),
      'priority': strategy.priority.toString(),
      'category': strategy.category.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      ...?additionalData,
    };

    return NotificationTemplate(
      title: title,
      body: body,
      data: data,
      imageUrl: imageUrl,
      actions: actions,
    );
  }
}

/// Action buttons for notifications (Android)
class NotificationAction {
  final String id;
  final String title;
  final Map<String, dynamic>? data;

  const NotificationAction({
    required this.id,
    required this.title,
    this.data,
  });

  /// Accept friend request action
  static const acceptFriend = NotificationAction(
    id: 'accept_friend',
    title: 'Acceptera',
  );

  /// Decline friend request action
  static const declineFriend = NotificationAction(
    id: 'decline_friend', 
    title: 'Avvisa',
  );

  /// View recipe action
  static const viewRecipe = NotificationAction(
    id: 'view_recipe',
    title: 'Visa recept',
  );

  /// Join collaboration action
  static const joinCollaboration = NotificationAction(
    id: 'join_collaboration',
    title: 'Gå med',
  );
}

/// Notification batching configuration
class BatchingConfig {
  final Duration window;
  final int maxSize;
  final String Function(List<NotificationTemplate>) contentBuilder;

  const BatchingConfig({
    required this.window,
    required this.maxSize,
    required this.contentBuilder,
  });

  /// Default batching for recipe comments
  static final recipeComments = BatchingConfig(
    window: const Duration(minutes: 5),
    maxSize: 5,
    contentBuilder: (notifications) {
      if (notifications.length == 1) {
        return notifications.first.body;
      }
      return '${notifications.length} nya kommentarer på dina recept';
    },
  );

  /// Default batching for recipe likes
  static final recipeLikes = BatchingConfig(
    window: const Duration(minutes: 10),
    maxSize: 10,
    contentBuilder: (notifications) {
      if (notifications.length == 1) {
        return notifications.first.body;
      }
      return '${notifications.length} personer gillade dina recept';
    },
  );
}