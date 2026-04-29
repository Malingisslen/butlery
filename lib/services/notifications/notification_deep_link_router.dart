/// Routes incoming push-notification taps to the right screen (BUT-641).
///
/// Cloud Functions stamps every outgoing FCM payload with `route`,
/// `targetId`, and `notificationType`. The client side has to:
/// 1. Pull those three fields out of the FCM `RemoteMessage.data` map.
/// 2. Translate `route` to a navigator action with `targetId` as argument.
/// 3. Be tolerant of legacy in-flight notifications without `route` — those
///    just open the app to the home screen instead of crashing.
/// 4. Log `notification_opened` analytics so push CTR is measurable.
///
/// **Why a separate class instead of a lambda in main.dart:** the lambda
/// approach (which is what BUT-641 replaces) has no analytics and no
/// missing-route handling. Putting the routing in a class lets us test it
/// without spinning up a full Flutter binding.
///
/// **Route constants live here** so the Cloud Functions agent has one
/// canonical list to align outgoing payloads against. If you add a route,
/// add the constant AND the case in [route]. If a Cloud Functions sender
/// uses a string not in [NotificationRoutes.all], the router falls back to
/// home + logs `notification_payload_unknown_route` so the drift surfaces
/// in analytics.
library;

import 'package:flutter/widgets.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';

/// Notification payload route strings. These MUST stay in sync with the
/// strings the Cloud Functions sender (`functions/src/notifications/`)
/// emits in the FCM `data.route` field.
abstract final class NotificationRoutes {
  /// Recipe detail. `targetId` = recipeId.
  static const String recipe = '/recipe';

  /// Friend request inbox. `targetId` ignored (the inbox is the recipient).
  static const String friendRequest = '/friend_request';

  /// Recipe detail with comment thread auto-scrolled. `targetId` = recipeId.
  static const String commentThread = '/comment_thread';

  /// Active cooking session. `targetId` = sessionId (group id).
  static const String cookingSession = '/cooking_session';

  /// Menu voting screen. `targetId` ignored.
  static const String menuVoting = '/menu_voting';

  /// Re-engagement / "we miss you" deep links — always land on home.
  /// `targetId` ignored.
  static const String winback = '/winback';

  /// All known route strings. Used by tests and by the unknown-route guard.
  static const Set<String> all = <String>{
    recipe,
    friendRequest,
    commentThread,
    cookingSession,
    menuVoting,
    winback,
  };
}

/// Handles a notification tap by navigating using [navigator] and logging
/// a `notification_opened` analytics event.
class NotificationDeepLinkRouter {
  final NavigatorState? Function() _navigatorResolver;
  final AnalyticsService? Function() _analyticsResolver;

  NotificationDeepLinkRouter({
    required NavigatorState? Function() navigatorResolver,
    required AnalyticsService? Function() analyticsResolver,
  })  : _navigatorResolver = navigatorResolver,
        _analyticsResolver = analyticsResolver;

  /// Entry point matching `NotificationService.onNotificationTapped`.
  ///
  /// `route` may be null/empty — this happens for notifications queued
  /// before BUT-641 server-side rolled out. `data` carries `targetId`
  /// (under the `'id'` key, which is what `NotificationService` already
  /// stamps) plus, when present, the original `notificationType` for
  /// analytics attribution.
  void handle(String? route, Map<String, String?> data) {
    final navigator = _navigatorResolver();
    final analytics = _analyticsResolver();
    final targetId = data['id'];
    final notificationType = data['notificationType'];

    if (route == null || route.isEmpty) {
      AppLogger.info(
          '🔔 Notification tap with no route — defaulting to home screen');
      _logEvent(
        analytics,
        name: AnalyticsEvents.notificationPayloadMissingRoute,
        notificationType: notificationType,
      );
      _goHome(navigator);
      return;
    }

    if (!NotificationRoutes.all.contains(route)) {
      AppLogger.warning(
          '🔔 Notification tap with unknown route "$route" — defaulting to home');
      _logEvent(
        analytics,
        name: AnalyticsEvents.notificationPayloadUnknownRoute,
        route: route,
        notificationType: notificationType,
      );
      _goHome(navigator);
      return;
    }

    _logEvent(
      analytics,
      name: AnalyticsEvents.notificationOpened,
      route: route,
      notificationType: notificationType,
    );

    if (navigator == null) {
      // Navigator not available yet — extremely early app start. The
      // analytics event still went out so push CTR is captured. Log loud
      // so we notice if this happens repeatedly (it shouldn't — main.dart
      // wires the router after navigator is built).
      AppLogger.warning(
          '🔔 Notification tap "$route" arrived before navigator was ready');
      return;
    }

    switch (route) {
      case NotificationRoutes.recipe:
        if (_isNonEmpty(targetId)) {
          // Recipe detail uses Routes.receptDetalj. The screen accepts
          // either a Recipe object or a recipe-id string under the 'id'
          // key — we pass the data map verbatim and let the route handler
          // decide which path to take.
          navigator.pushNamed(Routes.receptDetalj, arguments: data);
        } else {
          // Without an id we can't resolve a recipe — go home rather than
          // pushing a broken detail screen.
          _goHome(navigator);
        }
        break;
      case NotificationRoutes.commentThread:
        if (_isNonEmpty(targetId)) {
          // Reuse the recipe detail route; the receiving widget reads
          // `scrollToComments` from arguments to auto-expand the thread.
          navigator.pushNamed(
            Routes.receptDetalj,
            arguments: <String, dynamic>{
              'id': targetId,
              'scrollToComments': true,
            },
          );
        } else {
          _goHome(navigator);
        }
        break;
      case NotificationRoutes.friendRequest:
        navigator.pushNamed(Routes.friendRequests);
        break;
      case NotificationRoutes.cookingSession:
        if (_isNonEmpty(targetId)) {
          navigator.pushNamed(Routes.cookingMode, arguments: data);
        } else {
          _goHome(navigator);
        }
        break;
      case NotificationRoutes.menuVoting:
        // Menu voting is a section of the realtime menu screen. The
        // realtime menu route accepts an optional initial-tab argument.
        navigator.pushNamed(Routes.realtimeMenu, arguments: data);
        break;
      case NotificationRoutes.winback:
        _goHome(navigator);
        break;
    }
  }

  void _goHome(NavigatorState? navigator) {
    if (navigator == null) return;
    // pushNamedAndRemoveUntil so deep-link traversal doesn't pile screens
    // on the back stack when a user re-enters the app via push.
    navigator.pushNamedAndRemoveUntil(Routes.home, (route) => false);
  }

  void _logEvent(
    AnalyticsService? analytics, {
    required String name,
    String? route,
    String? notificationType,
  }) {
    if (analytics == null) return;
    final params = <String, Object>{};
    if (route != null) params['route'] = route;
    if (notificationType != null) params['notificationType'] = notificationType;
    // Best-effort — never let analytics errors propagate up over a real
    // navigation failure.
    try {
      analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      AppLogger.debug('NotificationDeepLinkRouter: analytics path failed: $e');
    }
  }

  static bool _isNonEmpty(String? s) => s != null && s.isNotEmpty;
}
