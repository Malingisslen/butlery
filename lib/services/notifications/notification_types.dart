import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/notifications/notification_routes.dart';

export 'package:butlery/services/notifications/notification_routes.dart';
export 'package:butlery/services/notifications/notification_template.dart';

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

/// FCM payload type identifiers used in notification data['type'].
abstract final class NotificationPayloadType {
  static const String friendRequest = 'friend_request';
  static const String recipeShared = 'recipe_shared';
  static const String collaborationInvite = 'collaboration_invite';
  static const String recipeComment = 'recipe_comment';
  // First-class FCM payload type so receivers can route taps into the
  // ping ack flow instead of borrowing the friend_request handler.
  static const String ping = 'ping';
  // Recipe-share request from a friend asking the owner to share a recipe.
  static const String recipeShareRequest = 'recipe_share_request';
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

  /// Analytics tag the server and `recordNotificationOpened` attribute by.
  final String notificationType;

  /// Where a tap on this push lands.
  final NotificationDestination destination;

  const NotificationStrategy({
    required this.notificationType,
    required this.destination,
    required this.type,
    required this.priority,
    required this.category,
    this.batchWindow,
    this.maxBatchSize,
    this.requiresInternet = true,
    this.localization = const {},
  });

  /// The same strategy with text built at send time.
  NotificationStrategy withLocalization(Map<String, String> localization) =>
      NotificationStrategy(
        notificationType: notificationType,
        destination: destination,
        type: type,
        priority: priority,
        category: category,
        batchWindow: batchWindow,
        maxBatchSize: maxBatchSize,
        requiresInternet: requiresInternet,
        localization: localization,
      );

  /// The three fields `sendNotification` refuses a push without (BUT-641,
  /// BUT-2400). Spread LAST into a payload so they win over `additionalData`,
  /// as they do on the server.
  Map<String, String> deepLinkData(Map<String, dynamic>? additionalData) {
    final key = destination.targetIdKey;
    final String? targetId = key == null
        ? null
        : additionalData?[key]?.toString();
    return {
      'route': destination.route,
      'targetId': targetId.orEmpty(),
      'notificationType': notificationType,
    };
  }

  /// Friend request sent/received - immediate attention required
  static const friendRequest = NotificationStrategy(
    notificationType: 'friend_request_received',
    destination: NotificationDestination(
      NotificationRoutes.friendRequest,
      targetIdKey: 'requestId',
    ),
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
    notificationType: 'recipe_shared',
    destination: NotificationDestination(
      NotificationRoutes.recipe,
      targetIdKey: 'collaborativeRecipeId',
    ),
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.recipes,
    localization: {
      'title_sv': 'Nytt recept delat',
      'title_en': 'Recipe shared with you',
      'body_sv': '{senderName} delade ”{recipeName}” med dig',
      'body_en': '{senderName} shared “{recipeName}” with you',
    },
  );

  /// Someone posted a cooking photo on a recipe you own
  static const cookSnapAdded = NotificationStrategy(
    notificationType: 'cook_snap_added',
    destination: NotificationDestination(
      NotificationRoutes.recipe,
      targetIdKey: 'recipeId',
    ),
    type: NotificationType.batchable,
    priority: NotificationPriority.medium,
    category: NotificationCategory.recipes,
    batchWindow: Duration(minutes: 5),
    maxBatchSize: 5,
    localization: {
      'title_sv': 'Nytt matfoto',
      'title_en': 'New cooking photo',
      'body_sv': '{senderName} lagade ”{recipeName}”',
      'body_en': '{senderName} cooked “{recipeName}”',
    },
  );

  /// Recipe comments - can be batched to prevent spam
  static const recipeComment = NotificationStrategy(
    notificationType: 'comment_posted',
    destination: NotificationDestination(
      NotificationRoutes.commentThread,
      targetIdKey: 'recipeId',
    ),
    type: NotificationType.batchable,
    priority: NotificationPriority.medium,
    category: NotificationCategory.recipes,
    batchWindow: Duration(minutes: 5),
    maxBatchSize: 5,
    localization: {
      'title_sv': 'Ny kommentar',
      'title_en': 'New comment',
      'body_sv': '{commenterName} kommenterade {recipeName}: {commentPreview}',
      'body_en': '{commenterName} commented on {recipeName}: {commentPreview}',
    },
  );

  /// Real-time collaboration invitation - immediate for active sessions
  static const collaborationInvite = NotificationStrategy(
    notificationType: 'collaboration_invite',
    destination: NotificationDestination(
      NotificationRoutes.recipe,
      targetIdKey: 'recipeId',
    ),
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.collaboration,
    localization: {
      'title_sv': 'Samarbetsinbjudan',
      'title_en': 'Collaboration invite',
      'body_sv': '{senderName} bjuder in dig att redigera ”{resourceName}”',
      'body_en': '{senderName} invited you to edit “{resourceName}”',
    },
  );

  /// Shopping list updates - silent sync with periodic summary
  static const shoppingListUpdate = NotificationStrategy(
    notificationType: 'shopping_list_update',
    destination: NotificationDestination(NotificationRoutes.home),
    type: NotificationType.silent,
    priority: NotificationPriority.low,
    category: NotificationCategory.shopping,
    requiresInternet: false,
  );

  /// Daily activity digest - scheduled periodic summary
  static const activityDigest = NotificationStrategy(
    notificationType: 'activity_digest',
    destination: NotificationDestination(NotificationRoutes.home),
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
    notificationType: 'friend_online',
    destination: NotificationDestination(NotificationRoutes.friends),
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
    notificationType: 'friend_request_accepted',
    destination: NotificationDestination(NotificationRoutes.friends),
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

  /// Collaboration enabled - immediate notification for new feature
  static const collaborationEnabled = NotificationStrategy(
    notificationType: 'collaboration_enabled',
    destination: NotificationDestination(
      NotificationRoutes.recipe,
      targetIdKey: 'recipeId',
    ),
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.collaboration,
    localization: {
      'title_sv': 'Samarbete aktiverat',
      'title_en': 'Collaboration enabled',
      'body_sv': '{enablerName} aktiverade samarbete för ”{recipeTitle}”',
      'body_en': '{enablerName} enabled collaboration for “{recipeTitle}”',
    },
  );

  // Ping strategies (nudge / timer-alert / help-me). Same shape — only
  // localization differs — so the recipient sees ping copy instead of
  // borrowing the friend-request wording.
  static const pingNudge = NotificationStrategy(
    notificationType: 'ping',
    destination: NotificationDestination(
      NotificationRoutes.group,
      targetIdKey: 'groupId',
    ),
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.social,
    localization: {
      'title_sv': 'Knuff från {senderName}',
      'title_en': 'Nudge from {senderName}',
      'body_sv': '{senderName} puttar på dig',
      'body_en': '{senderName} is nudging you',
    },
  );

  static const pingTimerAlert = NotificationStrategy(
    notificationType: 'ping',
    destination: NotificationDestination(
      NotificationRoutes.group,
      targetIdKey: 'groupId',
    ),
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.social,
    localization: {
      'title_sv': 'Timer-alarm från {senderName}',
      'title_en': 'Timer alert from {senderName}',
      'body_sv': 'Tid att kolla på maten',
      'body_en': 'Time to check on the food',
    },
  );

  static const pingHelpMe = NotificationStrategy(
    notificationType: 'ping',
    destination: NotificationDestination(
      NotificationRoutes.group,
      targetIdKey: 'groupId',
    ),
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.social,
    localization: {
      'title_sv': '{senderName} behöver hjälp',
      'title_en': '{senderName} needs help',
      'body_sv': 'Tryck för att svara',
      'body_en': 'Tap to respond',
    },
  );

  /// A chat message. The caller writes the title and body.
  static const chatMessage = NotificationStrategy(
    notificationType: 'new_message',
    destination: NotificationDestination(
      NotificationRoutes.conversation,
      targetIdKey: 'conversationId',
    ),
    type: NotificationType.immediate,
    priority: NotificationPriority.high,
    category: NotificationCategory.messaging,
    localization: {
      'title_sv': '{title}',
      'title_en': '{title}',
      'body_sv': '{body}',
      'body_en': '{body}',
    },
  );

  /// A friend asks the owner to share a recipe. The text is built at send
  /// time with [withLocalization].
  static const recipeShareRequest = NotificationStrategy(
    notificationType: NotificationPayloadType.recipeShareRequest,
    destination: NotificationDestination(
      NotificationRoutes.recipe,
      targetIdKey: 'recipeId',
    ),
    type: NotificationType.immediate,
    priority: NotificationPriority.critical,
    category: NotificationCategory.friends,
  );

  /// Sent silently to a member removed from a shared recipe.
  static const memberRemoved = NotificationStrategy(
    notificationType: 'member_removed',
    destination: NotificationDestination(
      NotificationRoutes.recipe,
      targetIdKey: 'recipeId',
    ),
    type: NotificationType.silent,
    priority: NotificationPriority.low,
    category: NotificationCategory.collaboration,
  );

  /// Every strategy above, for the payload contract test.
  static const List<NotificationStrategy> all = [
    friendRequest,
    recipeShared,
    cookSnapAdded,
    recipeComment,
    collaborationInvite,
    shoppingListUpdate,
    activityDigest,
    friendOnline,
    friendRequestAccepted,
    collaborationEnabled,
    pingNudge,
    pingTimerAlert,
    pingHelpMe,
    chatMessage,
    recipeShareRequest,
    memberRemoved,
  ];
}
