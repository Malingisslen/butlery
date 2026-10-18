import 'package:clock/clock.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/notifications/notification_translations.dart';
import 'package:butlery/services/notifications/notification_types.dart';

/// Template for notification content
class NotificationTemplate {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? imageUrl;
  final List<NotificationAction>? actions;

  /// The same push per language; null for a push built before this existed.
  final Map<String, NotificationText>? translations;

  const NotificationTemplate({
    required this.title,
    required this.body,
    required this.data,
    this.imageUrl,
    this.actions,
    this.translations,
  });

  /// The destination of a batch of [items]: theirs when they all share one,
  /// otherwise home rather than one arbitrary item's screen. A template stored
  /// before BUT-2400 carries no route, which also lands home.
  static Map<String, String> batchDestination(
    List<NotificationTemplate> items,
  ) {
    final first = items.first.data;
    final route = first['route'];
    final shared =
        route is String &&
        items.every(
          (n) =>
              n.data['route'] == route &&
              n.data['targetId'] == first['targetId'],
        );
    final type = first['notificationType'];
    return {
      'route': shared ? route : NotificationRoutes.home,
      'targetId': shared ? (first['targetId']?.toString()).orEmpty() : '',
      'notificationType': type is String && type.isNotEmpty ? type : 'batched',
    };
  }

  /// Create from strategy with variable substitution
  factory NotificationTemplate.fromStrategy(
    NotificationStrategy strategy,
    Map<String, String> variables, {
    LocalizedVariables? variablesByLocale,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) {
    final translations = translateStrategy(
      strategy,
      variables,
      variablesByLocale: variablesByLocale,
    );
    final sv = translations['sv']!;

    // Build data payload
    final data = <String, dynamic>{
      'type': strategy.type.toString(),
      'priority': strategy.priority.toString(),
      'category': strategy.category.toString(),
      'timestamp': clock.now().toIso8601String(),
      ...?additionalData,
      ...strategy.deepLinkData(additionalData),
    };

    return NotificationTemplate(
      title: sv.title,
      body: sv.body,
      data: data,
      imageUrl: imageUrl,
      actions: actions,
      translations: translations,
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
