import 'package:butlery/core/l10n/app_locale.dart';

/// Comprehensive notification type system defining intelligent delivery strategies and priority management for cooking-focused notifications.
/// This system implements sophisticated notification categorization with intelligent delivery strategies based on user
/// interaction patterns and cooking workflow optimization. It provides comprehensive notification type definitions that
/// balance user engagement with notification fatigue prevention through smart batching, priority management, and
/// context-aware delivery timing for optimal cooking and social experience.
/// **Notification Delivery Strategies:**
/// The system implements five core delivery strategies optimized for cooking and social interactions:
/// - **IMMEDIATE**: Real-time notifications for critical social interactions requiring instant attention
/// - **BATCHABLE**: Smart grouping for similar actions preventing notification spam while maintaining engagement
/// - **SILENT**: Background data synchronization without user interruption for seamless experience
/// - **DIGEST**: Periodic summaries providing curated activity overviews on user-defined schedules
/// - **OPTIONAL**: User-configurable notifications with sensible defaults respecting user preferences
/// **Priority Management System:**
/// Four-tier priority system ensuring appropriate notification urgency and delivery timing:
/// - **Critical**: Immediate delivery for friend requests, direct recipe shares, and collaboration invites
/// - **High**: Prioritized delivery for comments, cooking collaborations, and social interactions
/// - **Medium**: Standard delivery for activity updates, likes, and general social engagement
/// - **Low**: Background delivery for digest summaries, optional features, and non-urgent content
/// **Cooking-Focused Optimization:**
/// - Respects cooking time constraints with intelligent timing
/// - Batches similar cooking-related notifications to prevent interruption during meal preparation
/// - Provides context-aware delivery based on user's cooking schedule and meal planning activities
/// - Integrates with quiet hours and do-not-disturb preferences for optimal user experience
/// **Usage Examples:**
/// ```dart
/// // Define notification with appropriate type and priority
/// final notification = NotificationConfig(
///   type: NotificationType.immediate,
///   priority: NotificationPriority.critical,
///   category: 'recipe_shared',
/// );
/// // Check if notification should be batched
/// if (notification.type == NotificationType.batchable) {
///   await batchManager.addToBatch(notification);
/// } else {
///   await deliveryManager.sendImmediate(notification);
/// }
/// ```

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
  critical, // Friend requests, direct shares
  high, // Comments, collaboration
  medium, // Activity updates, likes
  low, // Digest summaries, optional features
}

enum NotificationCategory {
  friends, // Friend system interactions
  recipes, // Recipe sharing and collaboration
  collaboration, // Real-time editing and presence
  shopping, // Shopping list sharing and updates
  messaging, // Direct messages and conversations
  social, // General social activity
  system, // App updates and maintenance
}

/// Notification delivery strategy configuration
class NotificationStrategy {
  final NotificationType type;
  final NotificationPriority priority;
  final NotificationCategory category;
  final Duration? batchWindow; // For batchable notifications
  final int? maxBatchSize; // Maximum notifications to batch
  final bool requiresInternet; // Whether to queue offline
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

  /// Collaboration disabled - immediate notification when collaboration is turned off
  static const collaborationDisabled = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.collaboration,
    localization: {
      'title_sv': 'Samarbete inaktiverat',
      'title_en': 'Collaboration disabled',
      'body_sv': '{disablerName} inaktiverade samarbete för "{recipeTitle}"',
      'body_en': '{disablerName} disabled collaboration for "{recipeTitle}"',
    },
  );

  /// Added to collaboration - immediate notification when invited to collaborate
  static const addedToCollaboration = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.collaboration,
    localization: {
      'title_sv': 'Tillagd i samarbete',
      'title_en': 'Added to collaboration',
      'body_sv': '{adderName} la till dig i "{recipeTitle}"',
      'body_en': '{adderName} added you to "{recipeTitle}"',
    },
  );

  /// Removed from collaboration - immediate notification when removed
  static const removedFromCollaboration = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.collaboration,
    localization: {
      'title_sv': 'Borttagen från samarbete',
      'title_en': 'Removed from collaboration',
      'body_sv': '{removerName} tog bort dig från "{recipeTitle}"',
      'body_en': '{removerName} removed you from "{recipeTitle}"',
    },
  );

  /// Tag shared - immediate notification when someone shares a personal tag
  static const tagShared = NotificationStrategy(
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.recipes,
    localization: {
      'title_sv': 'Tagg delad med dig',
      'title_en': 'Tag shared with you',
      'body_sv': '{senderName} delade taggen "{tagName}" med dig',
      'body_en': '{senderName} shared the tag "{tagName}" with you',
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
    final titleTemplate = strategy.localization['title_sv'] ??
        AppLocale.current.notificationDefaultTitle;
    final bodyTemplate = strategy.localization['body_sv'] ??
        AppLocale.current.notificationDefaultBody;

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
  static NotificationAction get acceptFriend => NotificationAction(
        id: 'accept_friend',
        title: AppLocale.current.notificationActionAccept,
      );

  /// Decline friend request action
  static NotificationAction get declineFriend => NotificationAction(
        id: 'decline_friend',
        title: AppLocale.current.notificationActionDecline,
      );

  /// View recipe action
  static NotificationAction get viewRecipe => NotificationAction(
        id: 'view_recipe',
        title: AppLocale.current.notificationActionViewRecipe,
      );

  /// Join collaboration action
  static NotificationAction get joinCollaboration => NotificationAction(
        id: 'join_collaboration',
        title: AppLocale.current.notificationActionJoin,
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
      return AppLocale.current.notificationBatchComments(notifications.length);
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
